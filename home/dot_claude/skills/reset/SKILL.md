---
name: reset
description: Session-boundary ritual before a /clear (or compact) — loop the /ready capture sweep, autofixing every issue with an obvious solution and /explain-ing the rest to the owner one at a time, until a sweep comes back fully clear; only then write the burn-after-reading handoff and put its @path on the clipboard. Runs ONLY when the user literally types /reset; never self-invoked — when a boundary looks imminent, remind the user to run it, don't run it for them.
---

# reset — sweep until clear, then hand off

> **Typed-invocation only.** Runs solely when the owner literally types `/reset`. Never
> self-invoke; when context is filling up or the owner mentions clearing/compacting, the move is
> a ONE-LINE reminder to run `/reset` — not running it unbidden.

The successor session starts with NOTHING but the system prompt, CLAUDE.md files, the memory
index, and whatever the owner pastes. This skill's job is making that enough — and it does not
write the handoff until the sweep is genuinely clear.

## Step 1 — the gate loop: sweep → autofix → dialog → re-sweep

Run the `/ready` skill's sweep (both questions, verdicts first). Then resolve what it found:

- **Autofix anything with an OBVIOUS solution** — not just the mechanical (missing task, missing
  file): any issue whose correct resolution is unambiguous gets fixed on the spot and reported in
  one line. If two reasonable resolutions exist, it is not obvious — it goes to dialog.
- **Everything else goes to dialog**: present it via the `/explain` skill — the question first,
  plain prose plus a concrete code snippet where one makes it checkable, ONE item at a time —
  and wait for the owner's answer. Apply the answer (an explicit "skip"/"defer" counts as a
  resolution: record the deferral durably — a task or decision note — so it stops being a gap).
- **Re-run the sweep after every round** of fixes/answers — resolutions create new state, and the
  loop only exits when a FULL sweep comes back `1: NO GAPS` and `2: DURABLE` with nothing fixed
  or asked that round.

## Step 2 — the handoff file (only after a clear sweep)

Write a **burn-after-reading** handoff. Path: reuse the session's established handoff file if one
exists (e.g. `~/di.handoff.md`); otherwise `~/<short-topic>.handoff.md`. Match `/compact`-summary
density — curated, present-tense, zero padding, nothing the successor can cheaply re-derive from
the repo or task store. It must carry:

- **Header**: BURN AFTER READING — absorb, then `rm`. Session-home path and its live quirks
  (stale worktree, isolation-hook workarounds, path traps) stated as standing facts.
- **Board**: current tips/state, what landed this session, gate status.
- **In-flight work with IDENTIFIERS.** Background processes SURVIVE a clear but the conversation
  about them does not — so name every live agent/lane (name + task # + branch + worktree path),
  every background task and monitor (task id + what it watches + where its script lives), every
  reservation (§ numbers, branch names, file locks), and what the successor does when each one
  reports, wedges, or dies. Point at `/powerloss` for identify-by-transcript discipline.
- **Owner rulings of this session** — the do-not-re-ask list, each in one line, deferrals
  included.
- **Queue** — what runs next and its go-signal.
- **Protocol reminders** — only the ones a fresh session gets wrong without them.

## Step 3 — clipboard

Copy the handoff's **@-mention path** (e.g. `@/home/tom/di.handoff.md`) to the clipboard via
`fnc_copy_to_clipboard`, so the owner's first paste in the fresh session pulls the file in. If
the fnclaude tool is unavailable, say so and print the @path to copy by hand.

## Step 4 — one verdict line

End with exactly:

- `RESET-READY — handoff on clipboard; clear when you like.`

There is no other terminal state: the Step-1 loop holds the skill in dialog until clear, so by
this line the boundary is safe. Then stop — no new work after the verdict.

## Clear vs compact

The artifact serves both boundaries. When asked which to use: the curated handoff plus a clean
gate makes `/clear` strictly better (auto-summaries are lossy about live agents and eat fresh-
window headroom); `/compact` remains the fallback when the owner wants to cut a boundary WITHOUT
running this ritual.
