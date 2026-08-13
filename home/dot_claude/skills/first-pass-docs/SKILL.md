---
name: first-pass-docs
description: Audit documentation (doc comments, feature docs, READMEs, decision entries) for first-pass voice — every doc written as if the current design had been reached on the very first pass. Finds and fixes self-history: "previously/no longer/used to/legacy/renamed from/superseded", change narration, and explanations that exist only because an old design once made something an issue. Use when the user asks to "audit the docs", "check for history references", "first-pass the docs", or after a refactor lands. Argument = the doc/package scope; without one, ask.
---

# first-pass-docs — documentation with no memory

Documentation describes the design that exists, as if it had been reached on the very first
pass. A reader must not be able to reconstruct the project's history from its docs.

## What to find

Sweep the scoped docs — TSDoc/doc comments, `docs/**` prose, READMEs, decision entries — for:

1. **Self-history vocabulary**: "previously", "no longer", "used to", "the old X", "renamed
   from", "instead of the former", "legacy", "migrated", "superseded", "retired", "now"
   (when contrasting with an implied before). These are tells, not the test — judge each hit.
2. **Change narration**: any sentence whose subject is the transition rather than the design
   ("X was moved to Y", "this replaces Z", "after the restructure…").
3. **Ghost explanations**: prose explaining why something is a non-issue, where the only reason
   the question arises is that an earlier design made it an issue. An architecture change that
   turned an issue into a non-issue means **no explanation is the best explanation** — delete,
   don't rewrite.

## What is NOT a violation

- Comparisons to **external** prior art or platforms when they justify a present design choice
  in a decision record ("the platform's own `replace` agrees").
- Ordinary temporal words about **runtime** behavior ("the first call parses; repeats hit the
  cache").
- Version-history sections whose entire declared purpose is history (changelogs) — out of scope.

## Fix rule

Rewrite each finding to state the present design on its own terms; when the sentence exists only
to narrate the change, delete it outright. The test for the result: would this sentence have
been written exactly this way had the design been born like this? Report findings per file with
the rewritten (or deleted) form before applying; apply per the invocation's mandate, then run
the repo's formatter on touched files.
