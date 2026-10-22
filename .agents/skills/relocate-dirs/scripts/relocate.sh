#!/usr/bin/env bash
# Relocate directory trees under $HOME, then repair everything that recorded
# their absolute paths. The workflow around it is in ../SKILL.md.
#
#   relocate.sh --map OLD=NEW [--map ...] [opts]           dry run: preflight + plan
#   relocate.sh --map OLD=NEW [--map ...] [opts] --apply   back up, move, repair, verify
#   relocate.sh --map OLD=NEW [--map ...] --stale          build state to rebuild after --apply
#   relocate.sh --rollback <backup dir>                    undo an --apply (complete or partial)
#   relocate.sh --map OLD=NEW [--map ...] --preview < text  print text as the rewrite would leave it
#
# opts: --retarget FILE  also rewrite exact references to a nested OLD in FILE
#       --root PATH      extra file or dir to search for text references
#       --skip PREFIX    never rewrite text files under PREFIX
#
# NEW inside OLD (~/repos=~/repos/work) moves OLD's children into NEW and leaves
# OLD itself in place, so exact references to OLD stay unless --retarget names
# the file. Otherwise OLD is renamed to NEW. An OLD that does not exist only has
# its references rewritten. Maps apply in the order given; the longest OLD wins.
#
# Linux only (reads /proc). Run from a plain shell at ~ with herdr and every
# coding agent on the host stopped.
set -euo pipefail

H=$HOME
PI_SESS=${PI_CODING_AGENT_DIR:-$H/.pi/agent}/sessions
CFG=${XDG_CONFIG_HOME:-$H/.config}

say() { printf '%s\n' "$*"; }
section() { printf '\n== %s\n' "$*"; }
progress() {
  [[ -n ${BK:-} ]] && printf '%s %s\n' "$(date +%T)" "$*" >>"$BK/progress.log"
  say "  [$*]"
  # Test hook: simulate a crash right after a phase to exercise partial rollback.
  if [[ ${MIGRATE_FAIL_AFTER:-} == "$*" ]]; then
    say "  [injected failure]"
    exit 3
  fi
}
die() { printf '%s\n' "$*" >&2; exit 2; }

abspath() {
  local p=$1
  # shellcheck disable=SC2088
  case $p in "~") p=$H ;; "~/"*) p=$H/${p#"~/"} ;; esac
  while [[ $p == */ && $p != / ]]; do p=${p%/}; done
  [[ $p == /* ]] || die "not an absolute path: $1"
  printf '%s\n' "$p"
}

MODE=dry
OLDS=() NEWS=() NEST=() RETARGET=() EXTRA_ROOTS=() SKIPS=("$H/.dots/.agents")
while (($#)); do
  case $1 in
    --map)
      [[ ${2:-} == *=* ]] || die "--map needs OLD=NEW"
      OLDS+=("$(abspath "${2%%=*}")"); NEWS+=("$(abspath "${2#*=}")"); shift 2 ;;
    --retarget) RETARGET+=("$(abspath "${2:?--retarget needs a file}")"); shift 2 ;;
    --root) EXTRA_ROOTS+=("$(abspath "${2:?--root needs a path}")"); shift 2 ;;
    --skip) SKIPS+=("$(abspath "${2:?--skip needs a prefix}")"); shift 2 ;;
    --apply) MODE=apply; shift ;;
    --stale) MODE=stale; shift ;;
    --preview) MODE=preview; shift ;;
    --rollback) MODE=rollback; BK=$(abspath "${2:?--rollback needs a backup dir}"); shift 2 ;;
    *) die "unknown argument: $1" ;;
  esac
done

if [[ $MODE == rollback ]]; then
  [[ -f $BK/maps.tsv && -f $BK/files.txt ]] || die "not a backup dir: $BK"
  while IFS=$'\t' read -r o n x; do OLDS+=("$o"); NEWS+=("$n"); NEST+=("$x"); done <"$BK/maps.tsv"
else
  ((${#OLDS[@]})) || die "at least one --map OLD=NEW is required"
  for i in "${!OLDS[@]}"; do
    o=${OLDS[i]} n=${NEWS[i]}
    [[ $o != "$n" ]] || die "OLD and NEW are the same: $o"
    case $o/ in "$n"/*) die "NEW must not contain OLD: $o -> $n" ;; esac
    case $n in "$o"/*) NEST+=(1) ;; *) NEST+=(0) ;; esac
  done
fi

# Map indices, longest OLD first, so ~/repos/github wins over ~/repos.
mapfile -t ORDER < <(for i in "${!OLDS[@]}"; do printf '%d\t%d\n' "${#OLDS[i]}" "$i"; done | sort -rn | cut -f2)
MAPS_TSV=$(for i in "${!OLDS[@]}"; do printf '%s\t%s\t%s\n' "${OLDS[i]}" "${NEWS[i]}" "${NEST[i]}"; done)
SCAN_ROOTS=()
for o in "${OLDS[@]}"; do [[ -d $o ]] && SCAN_ROOTS+=("$o"); done
NEW_ROOTS=()
for i in "${!OLDS[@]}"; do [[ -d ${NEWS[i]} ]] && NEW_ROOTS+=("${NEWS[i]}"); done

# Maps an absolute path to its new location; prints nothing when the path does
# not move (outside every OLD, already new, or a nested OLD itself).
map_path() {
  local p=$1 i o n
  for n in "${NEWS[@]}"; do case $p in "$n" | "$n"/*) return 0 ;; esac; done
  for i in "${ORDER[@]}"; do
    o=${OLDS[i]} n=${NEWS[i]}
    case $p in
      "$o"/*) printf '%s\n' "$n${p#"$o"}"; return 0 ;;
      "$o") ((NEST[i])) || printf '%s\n' "$n"; return 0 ;;
    esac
  done
}

# One rewriting engine for every textual form of a path: absolute, ~, $HOME and
# ${HOME} spellings, Claude Code's project dir encoding (every non-alphanumeric
# becomes -) and pi's session dir encoding (--path-with-dashes--). Modes:
#   check FILE...             print the files a rewrite would change
#   apply FILE...             rewrite in place
#   checkfield KEY FILE...    like check, only inside JSON string values of KEY
#   field KEY FILE...         like apply, only inside JSON string values of KEY
#   names                     rewrite stdin lines (dir basenames) to stdout
# MIG_EXACT=1 treats nested maps like renames, so the OLD itself maps too.
# shellcheck disable=SC2016
ENGINE='
use strict; use warnings;
my $H = $ENV{MIG_H};
my $exact = $ENV{MIG_EXACT} ? 1 : 0;
my (@forms, %new);
sub cenc { my $s = shift; $s =~ s/[^A-Za-z0-9]/-/g; $s }
sub penc { my $s = shift; $s =~ s{^/}{}; $s =~ s{[/\\:]}{-}g; "--$s" }
for my $line (split /\n/, $ENV{MIG_MAPS}) {
  next unless length $line;
  my ($o, $n, $nest) = split /\t/, $line;
  $nest = 0 if $exact;
  my @pairs = (["p", $o, $n]);
  if (index($o, "$H/") == 0 && index($n, "$H/") == 0) {
    push @pairs, map { ["p", $_ . substr($o, length $H), $_ . substr($n, length $H)] } "~", q($HOME), q(${HOME});
  }
  push @pairs, ["c", cenc($o), cenc($n)], ["i", penc($o), penc($n)];
  for (@pairs) { my ($k, $of, $nf) = @$_; push @forms, [$k, $of, $nf, $nest]; push @{$new{$k}}, $nf }
}
my %before = (p => qr{(?<![A-Za-z0-9._~/\$-])}, c => qr{(?<![A-Za-z0-9-])}, i => qr{(?<![A-Za-z0-9.-])});
my %after = (
  p => [qr{(?=/|[^A-Za-z0-9._-]|\z)}, qr{(?=/)}],
  c => [qr{(?=-|[^A-Za-z0-9-]|\z)}, qr{(?=-)}],
  i => [qr{(?=-)}, qr{(?=-(?!-))}],
);
my %endnew = (p => qr{\A(?:/|[^A-Za-z0-9._-]|\z)}, c => qr{\A(?:-|[^A-Za-z0-9-]|\z)}, i => qr{\A-});
for (@forms) { my ($k, $of, undef, $nest) = @$_; $_->[4] = qr{$before{$k}\Q$of\E$after{$k}[$nest]} }
@forms = sort { length $b->[1] <=> length $a->[1] } @forms;
# The text at $at already matched old form $of; it counts as new only through a
# new form that $of does not itself start with (encodings that turn . into -
# make ~/x/a and ~/x/a.b look like a prefix pair).
sub is_new {
  my ($k, $s, $at, $of) = @_;
  for my $nf (@{$new{$k}}) {
    next if index($of, $nf) == 0;
    next unless substr($s, $at, length $nf) eq $nf;
    return 1 if substr($s, $at + length $nf) =~ $endnew{$k};
  }
  0
}
sub rw {
  my $s = shift;
  for my $f (@forms) {
    my ($k, $of, $nf, undef, $re) = @$f;
    my $src = $s;
    $s =~ s{$re}{is_new($k, $src, $-[0], $of) ? $of : $nf}ge;
  }
  $s
}
sub fieldrw { my ($key, $l) = @_; $l =~ s{("\Q$key\E":")((?:[^"\\]|\\.)*)}{$1 . rw($2)}ge; $l }
my $mode = shift @ARGV;
if ($mode eq "names") { while (my $l = <STDIN>) { chomp $l; print rw($l), "\n" } exit 0 }
my $key = $mode =~ /field$/ ? shift @ARGV : undef;
my $tr = sub { defined $key ? fieldrw($key, $_[0]) : rw($_[0]) };
if ($mode eq "check" || $mode eq "checkfield") {
  for my $f (@ARGV) {
    open my $fh, "<", $f or next;
    while (my $l = <$fh>) { if ($tr->($l) ne $l) { print "$f\n"; last } }
  }
  exit 0;
}
if ($mode eq "apply" || $mode eq "field") {
  $^I = "";
  while (my $l = <ARGV>) { print $tr->($l) }
  exit 0;
}
die "unknown mode $mode\n";
'
eng() { MIG_H=$H MIG_MAPS=$MAPS_TSV perl -e "$ENGINE" -- "$@"; }

# Fixed strings that every old textual form starts with; a cheap prefilter
# before the engine decides.
old_needles() {
  local o r
  for o in "${OLDS[@]}"; do
    printf -- '-e\n%s\n' "$o"
    if [[ $o == "$H"/* ]]; then
      r=${o#"$H"}
      printf -- '-e\n%s\n' "~$r" "\$HOME$r" "\${HOME}$r"
    fi
    r=${o#/}
    printf -- '-e\n%s\n' "${o//[^a-zA-Z0-9]/-}" "--${r//[\/:]/-}"
  done
}

skipped() {
  local s
  for s in "${SKIPS[@]}"; do case $1 in "$s" | "$s"/*) return 0 ;; esac; done
  return 1
}

preflight() {
  section "preflight"
  local blocked=0 i o n p pid cwd exe cmd why
  for i in "${!OLDS[@]}"; do
    o=${OLDS[i]} n=${NEWS[i]}
    if [[ -e $o ]]; then how=$( ((NEST[i])) && echo "children move into NEW" || echo "rename"); else how="text references only"; fi
    say "  $o -> $n ($how)"
  done
  if [[ $MODE != rollback ]]; then
    for n in "${NEWS[@]}"; do [[ -e $n ]] && { say "  $n already exists"; blocked=1; }; done
    ((${#SCAN_ROOTS[@]})) || { say "  no OLD exists; nothing to move"; }
  fi
  for o in "${OLDS[@]}" "${NEWS[@]}"; do
    case $PWD/ in "$o"/*) say "  cwd $PWD is inside a moved tree; cd ~ first"; blocked=1; break ;; esac
  done
  if [[ -z ${MIGRATE_SKIP_PROCESS_CHECK:-} ]]; then
    for p in /proc/[0-9]*; do
      pid=${p#/proc/}
      [[ $pid == "$$" || $pid == "$PPID" ]] && continue
      cwd=$(readlink "$p/cwd" 2>/dev/null) || continue
      exe=$(readlink "$p/exe" 2>/dev/null) || exe=
      cmd=$(tr '\0' ' ' <"$p/cmdline" 2>/dev/null | cut -c1-100) || cmd=
      why=
      for o in "${OLDS[@]}" "${NEWS[@]}"; do case $cwd/ in "$o"/*) why="cwd $cwd" ;; esac; done
      case $exe in */claude/versions/* | */herdr | */codex | */kimi) why=${why:-"writes agent state"} ;; esac
      case $cmd in *claude-code* | *@openai/codex* | *pi-coding-agent* | "herdr "*) why=${why:-"writes agent state"} ;; esac
      [[ -n $why ]] && { say "  pid $pid ($why): $cmd"; blocked=1; }
    done
  fi
  if ((blocked)); then
    say "  -> blocked"
    [[ $MODE == dry ]] || exit 1
  else
    say "  ok"
  fi
}

envrc_allow() {
  (cd "${1%/.envrc}" && direnv allow) 2>/dev/null || say "  direnv allow failed: $1"
}

# Reads or rewrites the single string field of jj's per-repo config metadata.
jj_meta() {
  python3 - "$@" <<'PY'
import sys
f = sys.argv[1]
b = open(f, "rb").read()
assert b[0] == 10, "unexpected tag"
n = s = 0; i = 1
while True:
    c = b[i]; n |= (c & 127) << s; i += 1; s += 7
    if c < 128: break
assert i + n == len(b), "unexpected trailing bytes"
if len(sys.argv) == 2:
    print(b[i:].decode()); sys.exit()
enc = sys.argv[2].encode(); ln = len(enc); v = bytearray()
while True:
    if ln < 128: v.append(ln); break
    v.append((ln & 127) | 128); ln >>= 7
open(f, "wb").write(bytes([10]) + bytes(v) + enc)
PY
}

# jj's workspace_store/index (one entry per workspace: name, path relative to
# the repo's .jj/repo dir). Prints the paths, or rewrites the ones given as
# OLD NEW pairs while copying every other byte.
jj_ws_index() {
  python3 - "$@" <<'PY'
import sys
f = sys.argv[1]; pairs = dict(zip(sys.argv[2::2], sys.argv[3::2]))
b = open(f, "rb").read()
def varint(b, i):
    n = s = 0
    while True:
        c = b[i]; n |= (c & 127) << s; i += 1; s += 7
        if c < 128: return n, i
def enc(n):
    v = bytearray()
    while True:
        if n < 128: v.append(n); return bytes(v)
        v.append((n & 127) | 128); n >>= 7
def fields(b):
    i = 0
    while i < len(b):
        key, i = varint(b, i)
        if key & 7 != 2: raise SystemExit("unexpected wire type in " + f)
        n, i = varint(b, i); yield key, b[i:i + n]; i += n
out = bytearray(); paths = []
for key, val in fields(b):
    if key != 10: raise SystemExit("unexpected top-level field in " + f)
    entry = bytearray()
    for k2, v2 in fields(val):
        if k2 == 18:
            p = v2.decode(); paths.append(p); v2 = pairs.get(p, p).encode()
        entry += enc(k2) + enc(len(v2)) + v2
    out += enc(10) + enc(len(entry)) + entry
if not pairs:
    print("\n".join(paths)); sys.exit()
open(f, "wb").write(bytes(out))
PY
}

# Where a jj pointer must point after the move; prints the new value only when
# it changes. $1 = dir the value is relative to, $2 = stored value.
jj_repoint() {
  local dir=$1 val=$2 tgt ndir ntgt nval
  if [[ $val == /* ]]; then tgt=$val; else tgt=$(realpath -m "$dir/$val"); fi
  ndir=$(map_path "$dir"); ndir=${ndir:-$dir}
  ntgt=$(map_path "$tgt"); ntgt=${ntgt:-$tgt}
  [[ $ndir == "$dir" && $ntgt == "$tgt" ]] && return 0
  if [[ $val == /* ]]; then nval=$ntgt; else nval=$(realpath -m --relative-to="$ndir" "$ntgt"); fi
  [[ $nval != "$val" ]] && printf '%s\n' "$nval"
  return 0
}

# pi refuses to resume a session whose header cwd is missing. Only line 1 is
# touched, and the mtime is kept so pi's recent-session order does not change.
pi_header_swap() {
  local f=$1 ref
  ref=$(mktemp)
  touch -r "$f" "$ref"
  PI_FROM=$2 PI_TO=$3 perl -pi -e 's/"cwd":"\Q$ENV{PI_FROM}\E"/"cwd":"$ENV{PI_TO}"/ if $. == 1' "$f"
  touch -r "$ref" "$f"
  rm -f "$ref"
}

# Pairs each basename in a dir with its rewritten name: "<old dir>\t<new dir>".
renamed_dirs() {
  local dir=$1 names
  [[ -d $dir ]] || return 0
  names=$(fd -HI -t d -d 1 . "$dir" -x basename {} | sort)
  [[ -n $names ]] || return 0
  paste <(printf '%s\n' "$names") <(printf '%s\n' "$names" | eng names) |
    while IFS=$'\t' read -r a b; do [[ $a != "$b" ]] && printf '%s\t%s\n' "$dir/$a" "$dir/$b"; done || true
}

plan() {
  section "git worktrees (bare and non-bare)"
  WT_ROWS=() # "<main git dir>\t<worktree dir>" in the old layout
  local f main wt g
  mapfile -t WT_ROWS < <({
    # Worktree records inside main repos that live in a moved tree.
    fd -HI -t f -d 8 '^gitdir$' "${SCAN_ROOTS[@]}" -E node_modules 2>/dev/null | rg '/worktrees/[^/]+/gitdir$' |
      while IFS= read -r f; do
        wt=$(<"$f"); printf '%s\t%s\n' "${f%/worktrees/*}" "${wt%/.git}"
      done
    # Worktrees inside a moved tree whose main repo is anywhere.
    fd -HI -t f -d 8 '^\.git$' "${SCAN_ROOTS[@]}" -E node_modules 2>/dev/null |
      while IFS= read -r f; do
        g=$(sed -n 's/^gitdir: //p' "$f"); [[ $g == */worktrees/* ]] || continue
        [[ $g == /* ]] || g=$(cd "${f%/.git}" && realpath -m "$g")
        printf '%s\t%s\n' "${g%/worktrees/*}" "${f%/.git}"
      done
  } | sort -u | while IFS=$'\t' read -r main wt; do
    [[ -n $(map_path "$main") || -n $(map_path "$wt") ]] && printf '%s\t%s\n' "$main" "$wt"
  done || true)
  say "  ${#WT_ROWS[@]} worktree(s)"

  # direnv hashes the .envrc path as found, so a symlinked one (mkws carries them)
  # needs its own allowance; ask direnv instead of reading its allow files.
  section "direnv allowances"
  ENVRCS=()
  if command -v direnv >/dev/null && ((${#SCAN_ROOTS[@]})); then
    mapfile -t ENVRCS < <(fd -HI -t f -t l '^\.envrc$' "${SCAN_ROOTS[@]}" -E node_modules 2>/dev/null |
      while IFS= read -r f; do
        [[ -n $(map_path "$f") ]] || continue
        [[ $(cd "${f%/.envrc}" && direnv status --json 2>/dev/null | jq -r '.state.foundRC.allowed // empty') == 0 ]] &&
          printf '%s\n' "$f"
      done | sort -u)
  fi
  say "  ${#ENVRCS[@]} .envrc file(s)"

  section "absolute symlinks into the moved trees"
  mapfile -t LINKS < <({
    ((${#SCAN_ROOTS[@]})) && fd -HI -t l . "${SCAN_ROOTS[@]}" -E node_modules -E .direnv -E target 2>/dev/null
    fd -HI -t l -d 6 . "$H" -E node_modules -E .cache -E go -E .cargo -E .rustup -E .local/share/pnpm 2>/dev/null
  } | while IFS= read -r f; do
    [[ -n $(map_path "$(readlink "$f")") ]] && printf '%s\n' "$f"
  done | sort -u)
  say "  ${#LINKS[@]} symlink(s)"

  section "jj per-repo config metadata"
  JJMETA=()
  for f in "$CFG"/jj/repos/*/metadata.binpb; do
    [[ -f $f ]] || continue
    main=$(jj_meta "$f" 2>/dev/null) || { say "  skip (unexpected format): $f"; continue; }
    [[ -n $(map_path "$main") ]] && JJMETA+=("$f")
  done
  say "  ${#JJMETA[@]} file(s)"

  # A secondary jj workspace points at its repo through .jj/repo, and the repo
  # lists its workspaces in workspace_store/index; both hold relative paths that
  # break when only one side moves.
  section "jj workspace pointers"
  JJREPO=() JJIDX=() # "<file>\t<new value>" / "<index file>\t<old path>\t<new path>"
  local v nv row
  while IFS= read -r f; do
    v=$(<"$f"); nv=$(jj_repoint "${f%/repo}" "$v")
    [[ -n $nv ]] && JJREPO+=("$f"$'\t'"$nv")
  done < <({
    ((${#SCAN_ROOTS[@]})) && fd -HI -t f -d 8 --full-path '/\.jj/repo$' "${SCAN_ROOTS[@]}" -E node_modules 2>/dev/null
    fd -HI -t f -d 7 --full-path '/\.jj/repo$' "$H" -E node_modules -E .cache -E go -E .cargo -E .rustup 2>/dev/null
  } | sort -u)
  while IFS= read -r f; do
    while IFS= read -r v; do
      [[ -n $v ]] || continue
      nv=$(jj_repoint "${f%/workspace_store/index}" "$v")
      [[ -n $nv ]] && JJIDX+=("$f"$'\t'"$v"$'\t'"$nv")
    done < <(jj_ws_index "$f" 2>/dev/null || say "  skip (unexpected format): $f" >&2)
  done < <({
    ((${#SCAN_ROOTS[@]})) && fd -HI -t f -d 9 --full-path '/\.jj/repo/workspace_store/index$' "${SCAN_ROOTS[@]}" -E node_modules 2>/dev/null
    fd -HI -t f -d 8 --full-path '/\.jj/repo/workspace_store/index$' "$H" -E node_modules -E .cache -E go -E .cargo -E .rustup 2>/dev/null
  } | sort -u)
  say "  ${#JJREPO[@]} workspace pointer(s), ${#JJIDX[@]} workspace index entr(ies)"
  for row in "${JJREPO[@]}" "${JJIDX[@]}"; do say "    ${row//$'\t'/ -> }"; done

  section "Claude Code project dirs"
  mapfile -t CPROJ_ROWS < <(renamed_dirs "$H/.claude/projects")
  local row
  for row in "${CPROJ_ROWS[@]}"; do
    [[ -e ${row#*$'\t'} ]] && die "Claude project dir collision: ${row#*$'\t'}"
  done
  say "  ${#CPROJ_ROWS[@]} dir(s)"

  # herdr resumes pi by session file path, and the text rewrite maps that path to
  # the new dir name, so the dirs and headers must follow.
  section "pi session dirs"
  mapfile -t PI_ROWS < <(renamed_dirs "$PI_SESS")
  PI_HEADERS=() # "<session file in old dir>\t<old cwd>\t<new cwd>"
  local cwd ncwd
  for row in "${PI_ROWS[@]}"; do
    [[ -e ${row#*$'\t'} ]] && die "pi session dir collision: ${row#*$'\t'}"
    for f in "${row%%$'\t'*}"/*.jsonl; do
      [[ -f $f ]] || continue
      cwd=$(head -n1 "$f" | jq -r '.cwd // empty' 2>/dev/null) || continue
      ncwd=$(map_path "$cwd")
      [[ -n $ncwd ]] && PI_HEADERS+=("$f"$'\t'"$cwd"$'\t'"$ncwd")
    done
  done
  say "  ${#PI_ROWS[@]} dir(s), ${#PI_HEADERS[@]} session header(s)"

  section "text files mentioning old paths"
  local roots=("$H/.claude.json" "$H/.claude/daemon" "$H/.claude/settings.json" "$H/.claude/settings.local.json"
    "$H/.codex/config.toml" "$CFG" "$H/.agents" "$H/.dots" "$H/.work.zsh" "$H/.kimi" "$H/.pi/agent" "${EXTRA_ROOTS[@]}")
  local d existing=()
  for d in "$H"/.claude/projects/*/memory; do [[ -d $d ]] && roots+=("$d"); done
  for d in "${roots[@]}"; do [[ -e $d ]] && existing+=("$d"); done
  local needles
  mapfile -t needles < <(old_needles)
  mapfile -t TEXTS < <(rg -l -F --hidden --no-ignore "${needles[@]}" \
    -g '!**/.git/**' -g '!**/node_modules/**' -g '!**/sessions/**' -g '!**/*.jsonl' -g '!**/history*' \
    -g '!**/backups/**' -g '!**/*.sqlite*' -g '!**/*.binpb' "${existing[@]}" 2>/dev/null | sort -u |
    while IFS= read -r f; do skipped "$f" || printf '%s\n' "$f"; done |
    { mapfile -t c; ((${#c[@]})) && eng check "${c[@]}"; } || true)
  RTEXTS=()
  for f in "${RETARGET[@]}"; do
    [[ -f $f ]] || die "--retarget file not found: $f"
    [[ -n $(MIG_EXACT=1 eng check "$f") ]] && RTEXTS+=("$f")
  done
  # Drop retargeted files from the plain rewrite; they get the exact one.
  local t keep=()
  for t in "${TEXTS[@]}"; do
    for f in "${RTEXTS[@]}"; do [[ $t == "$f" ]] && continue 2; done
    keep+=("$t")
  done
  TEXTS=("${keep[@]}")
  say "  ${#TEXTS[@]} file(s), ${#RTEXTS[@]} retargeted; under ~/.dots:"
  for f in "${TEXTS[@]}" "${RTEXTS[@]}"; do [[ $f == "$H/.dots/"* ]] && say "    ${f#"$H"/}"; done

  # Exact references to a nested OLD (e.g. jj's --when.repositories = ["~/repos"])
  # are ambiguous: the dir itself stays. List them so a human decides.
  local i o hints
  for i in "${!OLDS[@]}"; do
    ((NEST[i])) || continue
    o=${OLDS[i]}
    hints=$(rg -l -P --hidden --no-ignore "(?<![A-Za-z0-9._~/\$-])(\Q$o\E|~\Q${o#"$H"}\E)(?![A-Za-z0-9._/-])" \
      -g '!**/*.jsonl' -g '!**/history*' "$CFG" "$H/.dots" "$H/.work.zsh" "$H/.gitconfig" 2>/dev/null |
      while IFS= read -r f; do skipped "$f" || printf '%s\n' "$f"; done || true)
    if [[ -n $hints ]]; then
      say "  exact references to $o (unchanged unless passed with --retarget):"
      printf '%s\n' "$hints" | sed 's/^/    /'
    fi
  done

  section "Claude Code prompt history"
  HISTS=()
  [[ -f $H/.claude/history.jsonl && -n $(eng checkfield project "$H/.claude/history.jsonl") ]] &&
    HISTS+=("$H/.claude/history.jsonl")
  say "  ${#HISTS[@]} file(s)"
  return 0
}

backup() {
  BK=$H/relocate-backup-$(date +%Y%m%d-%H%M%S)
  mkdir -p "$BK/files"
  section "backup -> $BK"
  printf '%s\n' "$MAPS_TSV" >"$BK/maps.tsv"
  printf '%s\n' "${WT_ROWS[@]}" >"$BK/worktrees.tsv"
  printf '%s\n' "${ENVRCS[@]}" >"$BK/envrcs.txt"
  printf '%s\n' "${CPROJ_ROWS[@]}" >"$BK/claude-projects.tsv"
  printf '%s\n' "${PI_ROWS[@]}" >"$BK/pi-sessions.tsv"
  printf '%s\n' "${PI_HEADERS[@]}" >"$BK/pi-headers.tsv"
  : >"$BK/created-dirs.txt"
  : >"$BK/moved.txt"
  local f
  for f in "${LINKS[@]}"; do printf '%s\t%s\n' "$f" "$(readlink "$f")"; done >"$BK/symlinks.tsv"
  local row all=("${TEXTS[@]}" "${RTEXTS[@]}" "${JJMETA[@]}" "${HISTS[@]}")
  for row in "${JJREPO[@]}" "${JJIDX[@]}"; do all+=("${row%%$'\t'*}"); done
  mapfile -t all < <(printf '%s\n' "${all[@]}" | awk 'NF && !seen[$0]++')
  for f in "${all[@]}"; do cp -a --parents "$f" "$BK/files/"; done
  printf '%s\n' "${all[@]}" >"$BK/files.txt"
  progress "backup done"
}

apply() {
  section "move"
  local i o n c x keep top
  for i in "${!OLDS[@]}"; do
    o=${OLDS[i]} n=${NEWS[i]}
    [[ -e $o ]] || continue
    printf '%s\n' "$i" >>"$BK/moved.txt"
    if ((NEST[i])); then
      mkdir "$n"
      while IFS= read -r -d '' c; do
        keep=0
        for x in "${NEWS[@]}"; do case $x in "$c" | "$c"/*) keep=1 ;; esac; done
        ((keep)) || mv -t "$n" "$c"
      done < <(find "$o" -mindepth 1 -maxdepth 1 -print0)
    else
      top=$(dirname "$n")
      while [[ ! -e $(dirname "$top") ]]; do top=$(dirname "$top"); done
      [[ -e $top ]] || printf '%s\n' "$top" >>"$BK/created-dirs.txt"
      mkdir -p "$(dirname "$n")"
      mv "$o" "$n"
    fi
  done
  progress "move done"

  section "repair"
  local row f t nf wts
  while IFS=$'\t' read -r f t; do
    [[ -n $f ]] || continue
    nf=$(map_path "$f"); nf=${nf:-$f}
    ln -sfn "$(map_path "$t")" "$nf"
  done <"$BK/symlinks.tsv"
  progress "symlinks done"
  declare -A by_git
  for row in "${WT_ROWS[@]}"; do
    f=${row%%$'\t'*} t=${row#*$'\t'}
    nf=$(map_path "$f"); x=$(map_path "$t")
    by_git[${nf:-$f}]+="${x:-$t}"$'\n'
  done
  for f in "${!by_git[@]}"; do
    mapfile -t wts <<<"${by_git[$f]%$'\n'}"
    git --git-dir="$f" worktree repair "${wts[@]}" >/dev/null
  done
  progress "git worktree repair done"
  for f in "${JJMETA[@]}"; do jj_meta "$f" "$(map_path "$(jj_meta "$f")")"; done
  for row in "${JJREPO[@]}"; do
    f=${row%%$'\t'*}; nf=$(map_path "$f")
    printf '%s' "${row#*$'\t'}" >"${nf:-$f}"
  done
  for row in "${JJIDX[@]}"; do
    IFS=$'\t' read -r f o n <<<"$row"
    nf=$(map_path "$f"); jj_ws_index "${nf:-$f}" "$o" "$n"
  done
  progress "jj metadata done"
  ((${#TEXTS[@]})) && eng apply "${TEXTS[@]}"
  ((${#RTEXTS[@]})) && MIG_EXACT=1 eng apply "${RTEXTS[@]}"
  progress "text rewrite done"
  ((${#HISTS[@]})) && eng field project "${HISTS[@]}"
  progress "prompt history done"
  for row in "${CPROJ_ROWS[@]}"; do mv "${row%%$'\t'*}" "${row#*$'\t'}"; done
  progress "claude project dirs done"
  for row in "${PI_HEADERS[@]}"; do
    IFS=$'\t' read -r f o n <<<"$row"
    pi_header_swap "$f" "$o" "$n"
  done
  for row in "${PI_ROWS[@]}"; do mv "${row%%$'\t'*}" "${row#*$'\t'}"; done
  progress "pi session dirs done"
  for f in "${ENVRCS[@]}"; do envrc_allow "$(map_path "$f")"; done
  progress "direnv done"
}

rollback() {
  section "rollback from $BK"
  progress "rollback start"
  local o n f t i c wts
  while IFS=$'\t' read -r o n; do
    if [[ -n $o && -d $n && ! -e $o ]]; then mv "$n" "$o"; fi
  done <"$BK/claude-projects.tsv"
  progress "claude project dirs restored"
  while IFS=$'\t' read -r o n; do
    if [[ -n $o && -d $n && ! -e $o ]]; then mv "$n" "$o"; fi
  done <"$BK/pi-sessions.tsv"
  while IFS=$'\t' read -r f o n; do
    if [[ -n $f && -f $f ]]; then pi_header_swap "$f" "$n" "$o"; fi
  done <"$BK/pi-headers.tsv"
  progress "pi session dirs restored"
  # Only maps that actually moved, newest first; text-only maps share a NEW with
  # a real one and must not move it back.
  while IFS= read -r i; do
    [[ -n $i ]] || continue
    o=${OLDS[i]} n=${NEWS[i]}
    [[ -d $n ]] || continue
    if ((NEST[i])); then
      while IFS= read -r -d '' c; do mv -t "$o" "$c"; done < <(find "$n" -mindepth 1 -maxdepth 1 -print0)
      rmdir "$n"
    elif [[ ! -e $o ]]; then
      mv "$n" "$o"
    fi
  done < <(tac "$BK/moved.txt")
  while IFS= read -r f; do
    if [[ -n $f && -d $f ]]; then rmdir -p --ignore-fail-on-non-empty "$f" 2>/dev/null || true; fi
  done < <(tac "$BK/created-dirs.txt")
  progress "moves reverted"
  # Files go back after the moves so that ones inside moved trees (jj workspace
  # pointers) land in their original location.
  while IFS= read -r f; do
    [[ -n $f ]] && cp -a "$BK/files$f" "$f"
  done <"$BK/files.txt"
  progress "files restored"
  while IFS=$'\t' read -r f t; do
    [[ -n $f ]] && ln -sfn "$t" "$f"
  done <"$BK/symlinks.tsv"
  progress "symlinks restored"
  declare -A by_git
  while IFS=$'\t' read -r f t; do
    [[ -n $f ]] && by_git[$f]+="$t"$'\n'
  done <"$BK/worktrees.tsv"
  for f in "${!by_git[@]}"; do
    mapfile -t wts <<<"${by_git[$f]%$'\n'}"
    git --git-dir="$f" worktree repair "${wts[@]}" >/dev/null
  done
  progress "git worktree repair done"
  while IFS= read -r f; do
    [[ -n $f ]] && envrc_allow "$f"
  done <"$BK/envrcs.txt"
  progress "rollback done"
}

verify() {
  section "verify"
  local bad=0 row g wt f t left x
  for row in "${WT_ROWS[@]}"; do
    g=$(map_path "${row%%$'\t'*}"); g=${g:-${row%%$'\t'*}}
    wt=$(map_path "${row#*$'\t'}"); wt=${wt:-${row#*$'\t'}}
    git -C "$wt" status --porcelain >/dev/null 2>&1 || { say "  broken worktree: $wt"; bad=1; }
    git --git-dir="$g" worktree list --porcelain | rg -q '^prunable' && { say "  prunable worktree under $g"; bad=1; }
  done
  left=$(fd -HI -t l -d 6 . "$H" -E node_modules -E .cache -E go -E .cargo -E .rustup -E .local/share/pnpm 2>/dev/null |
    while IFS= read -r f; do [[ -n $(map_path "$(readlink "$f")") ]] && echo "$f"; done || true)
  [[ -n $left ]] && { say "  symlinks still pointing at old paths:"; say "$left"; bad=1; }
  for row in "${JJREPO[@]}"; do
    f=${row%%$'\t'*}; x=$(map_path "$f"); f=${x:-$f}
    t=$(<"$f"); [[ $t == /* ]] || t=${f%/repo}/$t
    [[ -d $t ]] || { say "  jj workspace points at a missing repo: $f"; bad=1; }
  done
  local texts=("${TEXTS[@]}")
  ((${#texts[@]})) && left=$(eng check "${texts[@]}") && [[ -n $left ]] && { say "  text still at old paths:"; say "$left"; bad=1; }
  ((${#RTEXTS[@]})) && left=$(MIG_EXACT=1 eng check "${RTEXTS[@]}") && [[ -n $left ]] && { say "  retargeted text still at old paths:"; say "$left"; bad=1; }
  for f in "${HISTS[@]}"; do
    [[ -n $(eng checkfield project "$f") ]] && { say "  prompt history still at old paths: $f"; bad=1; }
  done
  for row in "${PI_ROWS[@]}"; do
    for f in "${row#*$'\t'}"/*.jsonl; do
      [[ -f $f ]] || continue
      x=$(head -n1 "$f" | jq -r '.cwd // empty')
      [[ -n $x && -n $(map_path "$x") ]] && { say "  pi header still at old path: $f"; bad=1; }
    done
  done
  f=$CFG/herdr/session.json
  if [[ -f $f ]]; then
    while IFS= read -r t; do
      [[ -e $t ]] || { say "  herdr resumes a missing session file: $t"; bad=1; }
    done < <(jq -r '.. | .agent_session? | select(.kind? == "path") | .value' "$f")
  fi
  ((bad)) && say "  FAILED" || say "  ok"
  return $bad
}

# Succeeds when any file under $1 still holds an old path.
stale_files() {
  local hits
  [[ -d $1 ]] || return 1
  mapfile -t hits < <(rg -l -F --hidden --no-ignore "${needles[@]}" "$1" 2>/dev/null || true)
  ((${#hits[@]})) && [[ -n $(eng check "${hits[@]}") ]]
}

# Build state that baked absolute paths in and must be regenerated, with the
# nearest project root to run the package manager from.
stale() {
  section "path-baked build state under the new trees"
  ((${#NEW_ROOTS[@]})) || { say "  no NEW exists yet; run --apply first"; return 0; }
  local needles d r o
  mapfile -t needles < <(for o in "${OLDS[@]}"; do printf -- '-e\n%s/\n' "$o"; done)
  # --no-ignore matters: uv drops a "*" .gitignore inside every .venv.
  {
    fd -HI -t d '^\.bin$' "${NEW_ROOTS[@]}" -E .pnpm -E .git -E .jj -E target -E .direnv 2>/dev/null |
      while IFS= read -r d; do
        d=${d%/}
        stale_files "$d" || continue
        r=$d
        while [[ $r != / ]]; do
          r=$(dirname "$r")
          if [[ -f $r/pnpm-lock.yaml || -f $r/package-lock.json || -f $r/yarn.lock || -f $r/bun.lock || -f $r/bun.lockb ]]; then break; fi
        done
        printf 'node\t%s\n' "$r"
      done
    fd -HI -t d '^\.venv$' "${NEW_ROOTS[@]}" -E node_modules 2>/dev/null |
      while IFS= read -r d; do
        d=${d%/}
        if stale_files "$d/bin"; then printf 'venv\t%s\n' "${d%/.venv}"; fi
      done
  } | sort -u
  return 0
}

# Read-only modes skip the preflight: --stale runs after the move, when every
# NEW exists.
case $MODE in
  preview) eng names; exit 0 ;;
  stale) stale; exit 0 ;;
esac
preflight
if [[ $MODE == rollback ]]; then
  rollback
  exit 0
fi
plan
if [[ $MODE == dry ]]; then
  section "dry run only; rerun with --apply"
  exit 0
fi
backup
apply
if verify; then progress "verify ok"; else progress "verify FAILED"; fi
say "
Backup kept at $BK. Next: --stale to list build state to rebuild (see SKILL.md)."
