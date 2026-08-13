---
name: api-audit
description: Audit a library's entire public API surface on three axes — appropriate intellisense doc comments on every exported member, error messages that name the actual problem, and export hygiene (no type exported unless it appears in an exported function's input/output). Use when the user asks for an "API audit", "public surface audit", "intellisense/docs audit", "export audit", or to "clean up the public API". Argument = the package(s) or directory scope; without one, ask. NOT for architecture critique (use /arch-review) or security (use /security-review).
---

# api-audit — the public surface, held to three bars

Audit every **exported** member of the scoped packages. The public surface is the product; hover
text, thrown errors, and the export list are what a consumer actually experiences. Work
package-by-package, and report findings as concrete per-file fix lists before changing anything —
then apply on approval (or immediately, if the invocation said so).

## Axis 1 — intellisense comments: good AND appropriate

Every exported member's hover text must teach a consumer, held to this bar:

- **Entrypoint docs describe the concept, not the mechanics.** A factory/constructor teaches the
  thing it mints; an operation says what it answers and what success carries. Mechanics belong in
  `@remarks` only where a caller acts on them (identity/canonicalization consequences, `@throws`).
- **Written as if the current design were the first pass.** Never refer to how things used to be,
  never describe legacy→current changes, no "no longer"/"previously"/"replaces". An architecture
  change that made an issue a non-issue gets no explanation at all.
- Real TSDoc: `@remarks` for prose, `@throws` where it throws, `@example` where a call shape
  isn't obvious; omit `@param`/`@returns` the signature already states. Trivially-simple members
  get nothing. No engine lore, no restating the member name, no history.
- Verify every behavioral claim against the implementation before writing it.

## Axis 2 — error messages name the actual problem

Audit every thrown/constructed error reachable from the public surface:

- The message states **what is wrong with the input**, names **the offending fragment**, and
  locates it — never the implementation's bookkeeping ("unexpected state", "expected end of
  input"). Test: could a consumer fix their call from the message alone, without opening the
  library source?
- Include what was found, not only what was wanted. Positional errors point at the position.
- A good error message replaces a doc comment; prefer improving the message over documenting the
  failure mode.

## Axis 3 — export hygiene

**HARD RULE: no type is exported unless it is part of an exported function's input or output**
(parameter, return, thrown error, or a type argument a consumer must spell). For each exported
type, find the exported-function signature justifying it; none found ⇒ un-export it (module-local
or internal). Also flag: exported values nothing outside could need, barrels re-exporting
internals, and doc'd members that are not actually reachable from the package entrypoint.

Compute reachability from the package's `exports` map (the published entry), not from what
happens to be importable in-repo.

## Method

1. Enumerate the scope's packages; for each, list the true public surface from its entry barrel.
2. Sweep axis 3 first (the export list defines what axes 1–2 must cover), then 1 and 2 over the
   surviving surface.
3. Deliverable: per-package findings — member, axis, current state, proposed fix — plus the
   un-export list with the justifying-signature check shown. Apply per the invocation's mandate;
   run the repo's format/typecheck gates on every touched package.
