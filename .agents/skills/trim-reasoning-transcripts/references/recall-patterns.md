# Recall patterns

These probes find candidates for semantic review. They are not a definition or a mechanical deletion list. Every hit requires judgment, and a zero-hit run proves nothing until the pattern has been tested against a known positive.

Adapt paths and exclusions to the repository. Search hidden maintained directories when they contain decision records. Put exclusions after inclusions so later globs cannot re-admit third-party code, generated output, sealed archives, snapshots, fixtures, or this skill's quoted examples.

## English probes

```sh
rg -n --hidden '\(decision \d|\(audit [A-Z]\d|design §|plan §|design ledger|\bP-[A-Z]\b|\bW\d\b|\bT\d\b' <scope> ...
rg -n --hidden -i 'this PR|this branch|this stack|later PR|previous commit|this commit' <scope> ...
rg -n --hidden -i 'used to |no longer|previously|was renamed|was moved' <scope> ...
rg -n --hidden -i '\bv1\b|this cut|\bcut \d|\btoday\b|\bfor now\b|roadmap' <scope> ...
rg -n --hidden -i 'rejected in review|review round|reviewer|as of v\d' <scope> ...
rg -n --hidden -i 'probably |should be enough|should suffice|it simply|is safe —|is safe --' <scope> ...
rg -n --hidden '§\d' <scope> ...
```

## Chinese probes

```sh
rg -n --hidden '设计稿|评审|上一?轮|旧版|老的|不再|以前|本版|遗留|私有' <scope> ...
rg -n --hidden '(^|[^a-zA-Z])端([^a-zA-Z]|$)' <scope> --glob '*.md' ...
```

## Common false positives

- Instrumental "used to", as in "the key used to sign requests", is not temporal change narration.
- Runtime old/new names live objects during replacement or handover.
- Process documentation about pull requests can legitimately say "the PR body"; the problem is one change's vantage in durable product or code prose.
- `/v1/` may be a protocol identifier rather than an indexical version stamp.
- `§N` remains valid when a committed document or external standard owns the numbering.
- Recorded output can legitimately contain "today" or other original voice.
- "Rejected" in the alternatives section of a decision record is the sanctioned genre, not review choreography.

After the probes, read prose-dense files without a keyword in hand. Reviewer-addressed argument, derivation transcripts, and altered modality often have no stable lexical marker.
