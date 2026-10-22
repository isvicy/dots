#!/usr/bin/env bash
# shellcheck disable=SC2088 # a literal ~ is what relocate.sh is meant to receive
# End-to-end test for relocate.sh in a throwaway HOME: full apply + verify,
# rollback to an identical tree, and rollback after a crash at every phase.
#   tests/run.sh [HOME template for mktemp, default /tmp/relocate-test.XXXXXX]
# jj and direnv cases run only when those tools are installed.
set -euo pipefail

SCRIPT=$(cd "$(dirname "$0")/../scripts" && pwd)/relocate.sh
TEMPLATE=${1:-/tmp/relocate-test.XXXXXX}
HAVE_JJ=$(command -v jj >/dev/null && echo 1 || echo 0)
HAVE_DIRENV=$(command -v direnv >/dev/null && echo 1 || echo 0)
FAILS=0
MTIME=1767294245

ok() { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; FAILS=$((FAILS + 1)); }
check() { local name=$1; shift; if "$@" >/dev/null 2>&1; then ok "$name"; else bad "$name"; fi; }
same_tree() {
  local now
  now=$(snap)
  [[ $now == "$1" ]] && return 0
  diff <(printf '%s\n' "$1") <(printf '%s\n' "$now") | head -n 12 | sed 's/^/        /' >&2
  return 1
}

cenc() { printf '%s' "${1//[^a-zA-Z0-9]/-}"; }
penc() { local p=${1#/}; printf -- '--%s--' "${p//\//-}"; }

hrun() { (cd "$H" && env -i HOME="$H" PATH="$PATH" USER="${USER:-t}" MIGRATE_SKIP_PROCESS_CHECK=1 \
  ${MIGRATE_FAIL_AFTER:+MIGRATE_FAIL_AFTER="$MIGRATE_FAIL_AFTER"} "$@"); }
relocate() { hrun bash "$SCRIPT" --map "~/repos=~/repos/work" --map "~/oss=~/repos/oss" \
  --map "~/repos/github=~/repos/oss" --retarget "~/.config/jj/conf.d/local.toml" "$@"; }

fixture() {
  T=$(mktemp -d "$TEMPLATE"); H=$T/home
  mkdir -p "$H"/{repos,oss,playground,.agents/skills,.config/git,.config/jj/conf.d,.config/herdr,.claude/projects}
  local g=(git -c user.name=t -c user.email=test@example.invalid -c init.defaultBranch=main)
  hrun "${g[@]}" init -q repos/plain
  echo hi >"$H/repos/plain/README"
  hrun "${g[@]}" -C repos/plain add README
  hrun "${g[@]}" -C repos/plain commit -qm init
  hrun "${g[@]}" -C repos/plain worktree add -q "$H/repos/plain-feat" -b feat
  hrun "${g[@]}" -C repos/plain worktree add -q "$H/playground/plain-out" -b out
  hrun "${g[@]}" clone -q --bare repos/plain repos/bare.git
  hrun "${g[@]}" -C repos/bare.git worktree add -q "$H/repos/bare.git/main" main
  hrun "${g[@]}" init -q playground/ext
  hrun "${g[@]}" -C playground/ext commit -q --allow-empty -m init
  hrun "${g[@]}" -C playground/ext worktree add -q "$H/repos/ext-wt" -b w
  hrun "${g[@]}" init -q repos/work-foo
  hrun "${g[@]}" init -q oss/bar
  mkdir -p "$H/repos/plain/web/node_modules/.bin" "$H/repos/plain/py/.venv/bin"
  touch "$H/repos/plain/web/pnpm-lock.yaml"
  printf '#!/bin/sh\nexport NODE_PATH="%s/repos/plain/web/node_modules/.pnpm"\n' "$H" >"$H/repos/plain/web/node_modules/.bin/tool"
  printf '#!%s/repos/plain/py/.venv/bin/python\n' "$H" >"$H/repos/plain/py/.venv/bin/tool"
  echo '*' >"$H/repos/plain/py/.venv/.gitignore"
  ln -s "$H/oss/bar" "$H/.agents/skills/bar"
  ln -s "$H/repos/plain/README" "$H/.agents/skills/plain-readme"
  ln -s "$H/repos/plain" "$H/repos/work-foo/link-to-plain"
  if ((HAVE_JJ)); then
    local j=(env XDG_CONFIG_HOME="$H/.config" jj --config user.name=t --config user.email=test@example.invalid)
    mkdir -p "$H/repos/sample.jj"
    hrun "${j[@]}" git init repos/sample.jj/main >/dev/null 2>&1
    (cd "$H/repos/sample.jj/main" && hrun "${j[@]}" -R "$H/repos/sample.jj/main" workspace add "$H/repos/sample.jj/ws2" >/dev/null 2>&1)
    (cd "$H/repos/sample.jj/main" && hrun "${j[@]}" -R "$H/repos/sample.jj/main" workspace add "$H/playground/ws-out" >/dev/null 2>&1)
    hrun "${j[@]}" -R repos/sample.jj/main config set --repo user.email test@example.invalid >/dev/null 2>&1
    hrun "${j[@]}" git init playground/jext >/dev/null 2>&1
    hrun "${j[@]}" -R playground/jext workspace add "$H/repos/jext-ws" >/dev/null 2>&1
  fi
  if ((HAVE_DIRENV)); then
    echo 'export X=1' >"$H/repos/plain/.envrc"
    ln -s "$H/repos/plain/.envrc" "$H/repos/plain-feat/.envrc"
    (cd "$H/repos/plain" && hrun direnv allow "$H/repos/plain") >/dev/null 2>&1
    (cd "$H/repos/plain-feat" && env -i HOME="$H" PATH="$PATH" direnv allow) >/dev/null 2>&1
  fi
  local d
  for d in repos/plain repos/plain-feat repos oss/bar playground; do
    mkdir -p "$H/.claude/projects/$(cenc "$H/$d")"
    echo '{}' >"$H/.claude/projects/$(cenc "$H/$d")/s.jsonl"
  done
  mkdir -p "$H/.claude/projects/$(cenc "$H/repos/plain")/memory"
  printf 'see ~/repos/plain and %s/oss/bar, not ~/repos itself\n' "$H" \
    >"$H/.claude/projects/$(cenc "$H/repos/plain")/memory/MEMORY.md"
  jq -n --arg h "$H" '{projects: {($h + "/repos/plain"): {}, ($h + "/repos"): {}, ($h + "/oss/bar"): {}, ($h + "/playground"): {}}}' \
    >"$H/.claude.json"
  {
    printf '{"display":"cd %s/repos/plain","pastedContents":{},"timestamp":1,"project":"%s/repos/plain","sessionId":"a"}\n' "$H" "$H"
    printf '{"display":"x","pastedContents":{},"timestamp":2,"project":"%s/oss/bar","sessionId":"b"}\n' "$H"
    printf '{"display":"x","pastedContents":{},"timestamp":3,"project":"%s/repos","sessionId":"c"}\n' "$H"
    printf '{"display":"x","pastedContents":{},"timestamp":4,"project":"%s/repos/github/z","sessionId":"d"}\n' "$H"
  } >"$H/.claude/history.jsonl"
  local S=$H/.pi/agent/sessions
  for d in repos/plain repos oss/bar; do
    mkdir -p "$S/$(penc "$H/$d")"
    printf '{"type":"session","cwd":"%s"}\n{"type":"m","text":"%s/%s"}\n' "$H/$d" "$H" "$d" >"$S/$(penc "$H/$d")/s.jsonl"
    touch -d "@$MTIME" "$S/$(penc "$H/$d")/s.jsonl"
  done
  jq -n --arg s "$S/$(penc "$H/repos/plain")/s.jsonl" --arg c "$H/repos/plain" \
    '{workspaces: [{identity_cwd: $c, tabs: [{panes: {"1": {cwd: $c, agent_session: {kind: "path", value: $s}}}}]}]}' \
    >"$H/.config/herdr/session.json"
  printf '[includeIf "gitdir:~/repos/"]\n\tpath = ~/.work.gitconfig\n' >"$H/.config/git/config"
  printf '[[--scope]]\n--when.repositories = ["~/repos"]\n[--scope.user]\nemail = "test@example.invalid"\n' >"$H/.config/jj/conf.d/local.toml"
}

# Content, type and link target of everything under HOME, minus state that
# commands refresh on their own (git index stat cache, direnv allow records).
snap() {
  (cd "$H" && find . \( -path './relocate-backup-*' -o -path './.local/share/direnv' \) -prune -o -print | sort |
    while IFS= read -r f; do
      case $f in */.git/index | */.git/worktrees/*/index | *.git/worktrees/*/index | ./repos/bare.git/index) continue ;; esac
      if [[ -L $f ]]; then echo "L $f $(readlink "$f")"
      elif [[ -f $f ]]; then echo "F $f $(sha256sum <"$f" | cut -c1-16)"
      else echo "D $f"; fi
    done)
}

preview_cases() {
  echo "### rewrite rules (--preview)"
  local h=/home/u got want
  while IFS='|' read -r maps input want; do
    [[ -n $maps ]] || continue
    local args=()
    for m in $maps; do args+=(--map "$m"); done
    got=$(printf '%s\n' "$input" | env HOME=$h bash "$SCRIPT" "${args[@]}" --preview)
    if [[ $got == "$want" ]]; then ok "$input"; else bad "$input -> $got (want $want)"; fi
  done <<'CASES'
~/repos=~/repos/work|/home/u/repos/a/b|/home/u/repos/work/a/b
~/repos=~/repos/work|/home/u/repos|/home/u/repos
~/repos=~/repos/work|"~/repos"|"~/repos"
~/repos=~/repos/work|gitdir:~/repos/|gitdir:~/repos/work/
~/repos=~/repos/work|~/repos/work/a ~/repos/work-foo ~/repos/workshop|~/repos/work/a ~/repos/work/work-foo ~/repos/work/workshop
~/repos=~/repos/work ~/oss=~/repos/oss|~/repos/oss/x $HOME/oss ${HOME}/oss/y|~/repos/oss/x $HOME/repos/oss ${HOME}/repos/oss/y
~/repos=~/repos/work ~/repos/github=~/repos/oss|~/repos/github/z|~/repos/oss/z
~/repos=~/repos/work|-home-u-repos-a-jj-main -home-u-repos -home-u-repos-work-x|-home-u-repos-work-a-jj-main -home-u-repos -home-u-repos-work-x
~/repos=~/repos/work|--home-u-repos-a.jj-main-- --home-u-repos-- --home-u-repos-work-x--|--home-u-repos-work-a.jj-main-- --home-u-repos-- --home-u-repos-work-x--
~/oss=~/repos/oss|/s/--home-u-oss--/a projects/-home-u-oss-bar|/s/--home-u-repos-oss--/a projects/-home-u-repos-oss-bar
~/x/sample.jj=~/x/sample|-home-u-x-sample-jj-main ~/x/sample.jj/a ~/x/sample.jjx|-home-u-x-sample-main ~/x/sample/a ~/x/sample.jjx
~/repos=~/repos/work|/mnt/home/u/repos/x file~/repos/x|/mnt/home/u/repos/x file~/repos/x
CASES
}

full_run() {
  echo "### full apply ($TEMPLATE)"
  fixture
  local before out W=$H/repos/work
  before=$(snap)
  out=$(relocate 2>&1) || true
  check "dry run lists a jj exact reference hint or retarget" grep -q 'retargeted' <<<"$out"
  out=$(relocate --apply 2>&1) || { echo "$out" | tail -20; }
  check "verify ok" grep -q '\[verify ok\]' <<<"$out"
  check "repos holds only oss and work" test "$(ls "$H/repos" | tr '\n' ' ')" = "oss work "
  check "~/oss removed" test ! -e "$H/oss"
  check "plain worktree (sibling)" git -C "$W/plain-feat" rev-parse --git-dir
  check "worktree outside moved tree" git -C "$H/playground/plain-out" rev-parse --git-dir
  check "worktree inside, main outside" git -C "$W/ext-wt" rev-parse --git-dir
  check "bare repo worktree" git -C "$W/bare.git/main" rev-parse --git-dir
  check "no prunable worktrees" bash -c "! { git -C '$W/plain' worktree list --porcelain; git --git-dir='$W/bare.git' worktree list --porcelain; git -C '$H/playground/ext' worktree list --porcelain; } | grep -q prunable"
  check "work-foo nested under work" test -d "$W/work-foo/.git"
  check "symlink into oss" test "$(readlink "$H/.agents/skills/bar")" = "$H/repos/oss/bar"
  check "symlink inside moved tree" test "$(readlink "$W/work-foo/link-to-plain")" = "$W/plain"
  check "Claude dirs renamed" test -d "$H/.claude/projects/$(cenc "$W/plain")" -a -d "$H/.claude/projects/$(cenc "$H/repos/oss/bar")"
  check "Claude dir of ~/repos itself kept" test -d "$H/.claude/projects/$(cenc "$H/repos")"
  check ".claude.json keys" test "$(jq -r '.projects | keys | join(" ")' "$H/.claude.json")" = "$H/playground $H/repos $H/repos/oss/bar $W/plain"
  check "memory rewritten" grep -q "see ~/repos/work/plain and $H/repos/oss/bar, not ~/repos itself" "$H/.claude/projects/$(cenc "$W/plain")/memory/MEMORY.md"
  check "history project fields" test "$(jq -r .project "$H/.claude/history.jsonl" | tr '\n' ' ')" = "$W/plain $H/repos/oss/bar $H/repos $H/repos/oss/z "
  check "history display kept" grep -q "\"display\":\"cd $H/repos/plain\"" "$H/.claude/history.jsonl"
  local S=$H/.pi/agent/sessions
  check "pi dir + header" test "$(head -n1 "$S/$(penc "$W/plain")/s.jsonl" | jq -r .cwd)" = "$W/plain"
  check "pi body kept" grep -q "\"text\":\"$H/repos/plain\"" "$S/$(penc "$W/plain")/s.jsonl"
  check "pi mtime kept" test "$(stat -c %Y "$S/$(penc "$W/plain")/s.jsonl")" = "$MTIME"
  check "pi dir of ~/repos itself kept" test -d "$S/$(penc "$H/repos")"
  check "herdr pi path exists" test -f "$(jq -r '.. | .agent_session? | select(.) | .value' "$H/.config/herdr/session.json")"
  check "git includeIf" grep -q 'gitdir:~/repos/work/' "$H/.config/git/config"
  check "jj when (retarget)" grep -q '\["~/repos/work"\]' "$H/.config/jj/conf.d/local.toml"
  if ((HAVE_JJ)); then
    local j=(env -i HOME="$H" PATH="$PATH" XDG_CONFIG_HOME="$H/.config" jj --ignore-working-copy)
    check "jj secondary workspace" "${j[@]}" -R "$W/sample.jj/ws2" log -r @ --no-graph -T 'change_id'
    check "jj workspace outside moved tree" "${j[@]}" -R "$H/playground/ws-out" log -r @ --no-graph -T 'change_id'
    check "jj workspace inside, repo outside" "${j[@]}" -R "$W/jext-ws" log -r @ --no-graph -T 'change_id'
    check "jj repo config metadata" test "$("${j[@]}" -R "$W/sample.jj/main" config get user.email)" = "test@example.invalid"
  fi
  if ((HAVE_DIRENV)); then
    check "direnv allowed" test "$(cd "$W/plain" && env -i HOME="$H" PATH="$PATH" direnv status --json | jq .state.foundRC.allowed)" = 0
    check "direnv allowed (symlinked .envrc)" test "$(cd "$W/plain-feat" && env -i HOME="$H" PATH="$PATH" direnv status --json | jq .state.foundRC.allowed)" = 0
  fi
  out=$(relocate --stale 2>&1)
  check "--stale lists node project" grep -qx $'node\t'"$W/plain/web" <<<"$out"
  check "--stale lists venv project (ignored dir)" grep -qx $'venv\t'"$W/plain/py" <<<"$out"
  local bk
  bk=$(ls -d "$H"/relocate-backup-*)
  hrun bash "$SCRIPT" --rollback "$bk" >/dev/null 2>&1
  if same_tree "$before"; then ok "rollback identical"; else bad "rollback identical"; fi
  ((HAVE_JJ)) && check "jj works after rollback" env -i HOME="$H" PATH="$PATH" XDG_CONFIG_HOME="$H/.config" jj --ignore-working-copy -R "$H/playground/ws-out" log -r @ --no-graph -T 'change_id'
  rm -rf "$T"
}

partial_runs() {
  echo "### crash after each phase, then rollback"
  local phase before bk
  for phase in "backup done" "move done" "symlinks done" "git worktree repair done" "jj metadata done" \
    "text rewrite done" "prompt history done" "claude project dirs done" "pi session dirs done" "direnv done"; do
    fixture
    before=$(snap)
    MIGRATE_FAIL_AFTER=$phase relocate --apply >/dev/null 2>&1 || true
    bk=$(ls -d "$H"/relocate-backup-*)
    hrun bash "$SCRIPT" --rollback "$bk" >/dev/null 2>&1
    if same_tree "$before"; then ok "rollback after: $phase"; else bad "rollback after: $phase"; fi
    rm -rf "$T"
  done
}

echo "jj: $HAVE_JJ, direnv: $HAVE_DIRENV"
preview_cases
full_run
partial_runs
echo
((FAILS)) && { echo "$FAILS check(s) failed"; exit 1; }
echo "all checks passed"
