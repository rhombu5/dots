# Response corrections log

Accumulating examples of corrections to *how I (Claude) respond* — form and interaction, **not** task-correctness — so a targeted rule can be synthesized later. Over-explaining is the first category; others will accrue.

Only *corrected* cases land here; the justified responses that drew no complaint never do. So each entry captures the **situation** and my **rationale at the time** — the discriminating signal for a future rule lives in the contrast between "why I thought it was warranted" and why it actually wasn't.

Populated by the `/correction` skill. When a category reaches ~3+ examples, propose a synthesized rule to user prefs (`~/.claude/CLAUDE.md`).

---

<!-- entries appended below, chronological -->

## 2026-07-06 — batched-instead-of-one-at-a-time

- **Situation:** Tom asked me to walk through open GitHub issues "one at a time — explain, get my input, add it as a comment, then move on." We were driving a set of issues toward sign-off.
- **What I did:** Presented three issues (#42, #25, #34) together in a single message, each with a full ME-feature explanation and recommendation, and asked for all three decisions at once.
- **Why I thought it was warranted:** He had just sent one message answering ~20 issues at once, and had said "This is not a strict instruction of what order to explain all the pieces into me." I read the ordering as loose and optimized for fewer round-trips / less wall-clock.
- **Correction:** "now also, i said to go through these ONE AT A TIME."
- **Should have:** Presented exactly ONE issue, gotten his input, committed it (comment + label), then opened the next. "One at a time" was a pacing instruction about interaction rhythm, not just ordering — batching several forks into one reply forces him to context-switch and buries each decision. His own batched answers don't license me to batch my explanations back.

## 2026-07-06 — rubber-stamped-user-proposal

- **Situation:** Driving open issues toward sign-off. On #34, Tom proposed a design — "why don't you have `addOptions<T>` call `add<T>` under the hood… no new transformer — yes?"
- **What I did:** Wrote a confirming comment and applied BOTH `claude-ready` and `signoff`, ratifying his proposal without pressure-testing it. The fatal flaw (type erasure inside a generic wrapper — the transformer can't see a concrete `T` at an internal `add<T>` site) I only surfaced *after* he said "I see why the under-the-hood won't work."
- **Why I thought it was warranted:** His "yes?" read as inviting confirmation, and his prior messages had been decisions/answers, so I treated this as another decision to record rather than a claim to verify. I calibrated scrutiny to his phrasing.
- **Correction:** "everything i said was a proposal, they all need to be thought over. is it a problem just for that one because i said 'yes?' instead of 'agreed?'?"
- **Should have:** Pressure-tested the proposal on its merits — regardless of phrasing or who authored it — surfaced the erasure flaw myself, applied at most `claude-ready` and *only* after that verification, and left `signoff` for his explicit go. The "?"/tone is irrelevant: correctness sets the scrutiny level, not the user's framing or confidence.
