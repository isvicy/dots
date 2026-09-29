---
name: trim-reasoning-transcripts
description: Audit or fix durable repository prose that depends on design-session shorthand, pull-request or review vantage, change narration, control-flow walkthroughs, hedged planning residue, authoring-language slips, or unresolvable citations; preserve every load-bearing proposition while rewriting from the repository's current state.
---

# Trim Reasoning Transcripts

Reasoning-transcript leakage is prose whose vantage is the authoring session rather than the maintained artifact: it cites material only that session could see, narrates the change instead of the state, reproduces the derivation instead of the result, or argues with a reviewer who has left. This is a durability problem, not a request to expose or reconstruct hidden reasoning.

The fix is never deletion alone when a passage carries factual clauses. Restate every surviving fact so it stands at the current revision, then remove the transcript around it. Delete a passage outright only when it carries no useful proposition, such as an orphan audit code or narration already obvious from the code.

This skill is guidance, not a script. Pattern searches find candidates; semantic judgment decides what to keep, rewrite, relocate, or delete.

## Inputs and authority

- Require an explicit file, directory, diff, or pull-request scope. Do not infer a repository-wide audit.
- Review and audit requests report findings without editing. Apply changes only when the user explicitly asks to fix, trim, or rewrite.
- Read the repository's instructions, documentation taxonomy, decision-record rules, generation workflow, localization rules, and immutable-history policy before judging prose.
- Exclude third-party or vendored sources, sealed archives, recorded fixtures, snapshots, and other immutable evidence from routine edits. Inspect an exact target only when needed to understand an active citation or when the user explicitly owns and authorizes changing it.
- Treat generated artifacts as derivative. Change their owning source or template, then regenerate.

## The one test

For every suspect passage ask:

> Could a reader at the current revision, with no access to any session transcript, pull-request thread, chat, or uncommitted draft, resolve every reference and verify every claim?

If no, restate the surviving facts from the maintained artifact's vantage and delete the session residue. If yes, the passage clears this skill's resolvability bar—but a current-state README, API document, or code comment may still be the wrong home for a resolvable change story.

## Preserve the complete proposition

Before editing, enumerate every relevant proposition:

- actor and action;
- condition, timing, and ordering;
- modality such as must, may, should, or never;
- negative guarantee and exception;
- ownership, side effect, failure mode, and consequence;
- whether a number is measured, specified, observed, or merely proposed.

Remove adjectives, repetition, narration, and dead citations only when these facts survive. A smaller word count alone is not an improvement. Read [references/examples.md](references/examples.md) before making a borderline or broad cleanup.

## Leakage taxonomy

1. **Dead session citations:** decision ordinals, audit codes, plan sections, phase labels, unnamed RFCs, or "the design ledger" when no committed or otherwise durable owner resolves them.
2. **Pull-request and stack vantage:** "this PR adds", "the previous commit", or "a later change in this stack" in prose intended to outlive that change.
3. **Change narration and indexical versions:** "used to", "no longer", "this cut", "today", or "now" when contrasting repository versions rather than live runtime objects.
4. **Review choreography:** reviewer attributions, review rounds, draft ordinals, and verdicts recorded as who said what rather than the surviving decision and rationale.
5. **Reviewer-addressed justification:** prose arguing that code is safe or correct instead of stating the invariant, precondition, or evidence that makes it so.
6. **Restatement and derivation transcripts:** control-flow narration, test walkthroughs, and proofs of branches already evident in the implementation.
7. **Hedges and planning residue:** "probably fine", "should be enough", or ownerless deferrals. Replace them with the actual bound, failure behavior, or a tracked follow-up.
8. **Authoring-language slips:** untranslated working-language fragments, private-draft separators, and editor notes left in prose of another language.

## What is not leakage

Keep durable, resolvable, and load-bearing material, including:

- issue or task references that remain available at the current revision;
- merged-change citations in document genres that explicitly preserve history, such as decision records and postmortems;
- accurate lint, coverage, type-suppression, or empty-catch justifications;
- present-tense counterfactual regression pins such as "without X, Y happens";
- measured bounds whose provenance explains a constant;
- old/new terminology for simultaneously live runtime objects;
- external standards, specifications, or design artifacts that resolve by stable identifier;
- alternatives and historical evidence in a document whose declared purpose is to retain them.

Resolvability is the test, not the citation's appearance. A friendly-sounding name for an uncommitted document is still dead; a numbered standards section with a stable owner is not.

## Workflow

1. Confirm the scope, write authority, current revision, applicable instructions, and exclusions.
2. Audit read-only first. Use the probes in [references/recall-patterns.md](references/recall-patterns.md), then judge every hit semantically. Also read the densest prose without a pattern in hand; the probes over-match by design and under-match by nature.
3. Classify each candidate as keep, rewrite, relocate, delete, or defer. Do not manufacture edits to satisfy a deletion target.
4. Fix owner-first: source before generated output, canonical text before projections, both sides of maintained translations, and behavior tests or snapshots alongside changed visible strings.
5. Before deleting a clause, compare it with the overcorrection traps in [references/examples.md](references/examples.md). Do not flip an obligation into approval, promote a hypothetical to shipped behavior, delete a true fact, or drop provenance.
6. Re-run the probes, resolve every remaining active citation, and run the repository's narrow checks for the touched surfaces.

Report the inspected scope, changes or findings, deliberate keeps, borderline cases, exclusions, and checks actually run.
