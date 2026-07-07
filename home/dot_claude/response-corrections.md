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

## 2026-07-06 — over-explaining

- **Situation:** On #34, Tom prompted verbatim: "oh i see why the under-the-hood won't work. tell me exactly what we're trying to add to di."
- **What I did:** Answered the "what are we adding to di" part, but *also* wrote two+ paragraphs re-explaining **why** the under-the-hood approach fails (the three-way teardown, the type-erasure-inside-the-generic argument) — re-deriving at length the exact point he'd just told me he already had.
- **Why I thought it was warranted:** I read "tell me exactly what we're trying to add to di" as license for a full technical exposition, and — coming right after I'd rubber-stamped #34 — I wanted to demonstrate I now grasped the flaw. I treated his "i see why" as backdrop rather than as an explicit signal to *skip* the why.
- **Correction:** "i had prompted, verbatim: 'oh i see why the under-the-hood won't work' and you responded with two whole paragraphs explaining to me why under-the-hood won't work."
- **Should have:** Answered only the narrow question — the concrete `addFactory` registration, "di needs nothing new; the work is the lowering site" — in a few lines. "I see why X" is a hard signal that X is settled: at most one clause acknowledging it, never a re-derivation. Don't re-explain what the user just said he already knows, and don't over-explain to prove comprehension.

## 2026-07-07 — over-explaining

- **Situation:** Deep in the #36 design discussion (a real architectural linchpin). My responses had become multi-section: bold headers, a table, cascading nested bullets, "honest cost / recommendation / the one thing still yours to call" scaffolding.
- **What I did:** Answered #36 with a long, heavily-formatted wall — headers, a comparison table, nested bullet matrices, several bolded call-outs. A "tl;dr word salad."
- **Why I thought it was warranted:** #36 is a genuine fork with real grounding (ME source + repo reads), so I equated *density of formatting* with *respect for a hard decision*. And he'd earlier said "use prose and examples," which I misread as "add examples on top of the structure" rather than "drop the structure."
- **Correction:** "how many times do i have to tell you, explain simply with prose and examples" / "please end the tl;dr word salads."
- **Should have:** Plain prose — a few short sentences and one small concrete example, no tables, no header scaffolding, no option-matrix bullets. Thoroughness of *thinking* does not require dense *formatting*; state the conclusion and the single example that makes it land, then stop. This is a **repeat** ("prose and examples" said before), so it's a standing style for this user, not a one-off — heavy structure reads as evasive word-salad, not rigor.

## 2026-07-06 — bash-output-into-context

- **Situation:** Cloning the ME reference libs into a sparse-checkout. To confirm the sparse patterns had materialized only the intended dirs, I ran verification commands — `git ls-files src/libraries` and a shell loop listing directories.
- **What I did:** Piped the full listings straight to stdout — 247 lines / ~187KB of raw directory names — which got persisted into context, instead of reducing them to counts in-script.
- **Why I thought it was warranted:** I wanted to eyeball the actual dir names to confirm the sparse-checkout worked and hadn't leaked non-ME libraries. I treated "let me see everything" as the safe, thorough way to verify.
- **Correction:** "you should've scripted that in a way to keep that huge bash output out of context"
- **Should have:** Computed the answer inside the script — `wc -l`, `grep -c`, a spot-check count of files in one expected dir and one non-expected dir — and emitted only the one-line summary (`40 ME dirs, 0 non-ME, System.Text.Json 0 files`). The diagnostic signal (did sparse work?) is a handful of numbers; the raw list is noise that permanently occupies context. Verification output should be reduced to its conclusion in-script, not dumped for me to read.
