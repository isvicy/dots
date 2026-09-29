# Reasoning-transcript examples

Use these examples to identify the governing principle, not as text templates.

## Dead citations

### Session ordinal with a durable owner

**Leaked:** "Slash input resolves against the visible catalog (decision 21)."

**Durable:** "Slash input resolves against the visible catalog; see the input-routing decision in `docs/decisions/input-routing.md`."

The ordinal resolves only inside the closed session. The decision name and maintained path resolve at the current revision.

### Session ordinal without an owner

**Leaked:** "The registry rejects duplicate names (decision 7: names are flat, with no namespacing)."

**Durable:** "The registry rejects duplicate names; names are flat, with no namespacing."

Delete the dead citation, not its factual clause.

### Audit and plan codes

**Leaked:** "Rendering is pure: the same snapshot produces the same string (audit R3)."

**Durable:** "Rendering is pure: the same snapshot produces the same string."

An audit code with no maintained audit document carries no proposition.

**Leaked:** "Layering follows design §3.2: `src/core/` is the pure core."

**Durable:** "`src/core/` is the pure core."

A section of an uncommitted draft is dead. A section of a stable external standard or committed document remains citable.

## Pull-request and change vantage

**Leaked:** "This PR adds cursor-based pagination to the session list."

**Durable:** "The session list paginates by cursor."

**Leaked:** "A later PR in this stack adds a remote backend."

**Durable:** "A remote backend can implement this interface without changing the render layer."

Keep the shipped mechanism or extension-point contract. Put pending work in a tracked issue or task.

**Leaked:** "This used to double-encode multibyte labels."

**Durable:** "Without the byte-length guard, multibyte labels double-encode."

A present-tense counterfactual pins the regression without requiring repository archaeology.

## Review choreography

**Leaked:** "Rejected in review: caching the resolved specification. We keep resolution per call."

**Durable in a decision record:** "**Cache the resolved specification.** Rejected: the specification depends on the per-call working directory, so the cache would serve stale roots."

The alternative and rationale survive. The reviewer and review round do not.

**Leaked:** "The cast is safe—the SDK created the object and simply declares its optional fields too loosely."

**Durable:** "The SDK creates this object with every optional field populated; its declared type is looser than the runtime guarantee."

State the invariant a maintainer must preserve. If the code already makes it obvious, delete the comment instead.

## Restatement and derivation

**Leaked:** "First normalize the label, then truncate it, and finally wrap it."

**Durable:** Delete the comment when the adjacent code already expresses those steps.

**Leaked:** "This test creates a session, sends two messages, waits for the reply, and asserts four log entries."

**Durable:** "Two round trips produce four log entries because the projection deduplicates the shared prefix."

Keep only the non-obvious assertion rationale.

## Hedges and planning residue

**Leaked:** "A 64 KiB buffer should be enough for most cases."

**Durable:** "64 KiB holds the largest observed frame (48 KiB) with headroom; a larger frame fails in `decode`."

Replace a guess with the actual basis and failure behavior. If the limit is genuinely unresolved, create a tracked follow-up rather than leaving an ownerless hedge.

## Material to keep

**Keep:** "The cap applies to the complete rendered value, wrappers included (issue #1470 owns the follow-up)."

The issue resolves and owns real deferred work.

**Keep:** `// lint-disable-next-line rule-name -- the one-element literal guarantees index 0.`

Suppression reasons are required prose. Fix a false reason; do not delete a true one.

**Keep:** "Depth cap (measured: 512 nests ≈ 0.15 s synchronously; 4096 blocks the event loop)."

"Measured" is load-bearing provenance for the constant.

**Keep:** "The old connection drains before the new one accepts."

Old and new name simultaneously live runtime objects, not repository versions.

## Overcorrection traps

### Flipping an obligation into approval

**Original:** "These direct registrations are exceptions pending migration to slots."

**Wrong:** "These direct registrations are sanctioned exceptions."

**Right:** Keep the original obligation, or replace it with the repository's tracked migration reference.

"Pending migration" requires future action; "sanctioned" blesses the current state.

### Promoting a hypothetical to shipped behavior

**Original:** "A future IPC shell subclasses the executor and overrides `spawn`."

**Wrong:** "An IPC shell subclasses the executor and overrides `spawn`."

**Right:** "A hypothetical IPC shell—no such implementation currently ships—would subclass the executor and override `spawn`."

Deleting the future marker alone changes the truth value.

### Deleting a true fact with narration

**Original:** "The notice narrates the check order; its text is also the compiler's test input."

**Wrong:** Delete the whole sentence as narration.

**Right:** "The notice text is the compiler's test input."

Delete clauses, not whole sentences, when propositions share a line.

### Dropping provenance while keeping a number

**Original:** "The 4 MiB ceiling is measured: the largest generated module is 3.1 MiB."

**Wrong:** "The ceiling is 4 MiB; the largest generated module is 3.1 MiB."

**Right:** Keep "measured" or another accurate provenance term.

Without provenance, an observation can be mistaken for a definition.
