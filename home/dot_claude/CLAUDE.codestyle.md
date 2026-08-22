# Code style — all languages

Principles that apply to every language. Language-specific style lives in its own sibling
(`CLAUDE.typescript.md`, `CLAUDE.go.md`); where a specific file elaborates one of these, the
specific file wins on mechanics.

## The budget is reader frames, not characters

Reading code is a depth-first traversal on a lossy stack: a reader forced to descend into a
callee to learn what it does cannot cheaply restore the frame they left — the place they meant to
return to is simply gone. Every style trade is priced in these frames, not in characters or
repetitions. Terseness rules delete what is derivable *without leaving the frame* (restated
signatures, self-evident comments); naming rules spend characters exactly where the alternative
is leaving it. Same axis as DRY-as-a-trade: minimize total understanding cost.

## The name is the zeroth doc comment

The escalation ladder is name → doc sentence → source, each level existing to spare the reader
the next. A name that fails forces a descent no doc can refund, because by the time the doc
helps, the frame is already lost.

- A member's name states WHAT it does — verb and object together (`buildCallSite`,
  `detectFailure`), never a bare noun or elliptical verb.
- Rarely, if ever, HOW. What-names survive refactors; how-names rot into lies the day the
  implementation changes.
- The unit that must read as a sentence is the *call-site expression*, not the identifier: the
  receiver may supply the noun and the method the verb (`cycleGuard.visiting(x)`), so a field
  holding a device is named for the mechanism it is.
- The boundary of "rarely how": name the how when the how IS the contract a caller's correctness
  depends on (`reverse` vs `toReversed`, `getOrInsertComputed`). A mechanism extracted into a
  named device is a how one level up but a what at its own level — which is exactly how
  mentioning it becomes legal.
