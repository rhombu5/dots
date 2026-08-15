---
name: reset
description: Session-boundary checkpoint before a /clear (or compact) — run the /ready capture gate in full, fix what's mechanically fixable, then write a burn-after-reading handoff file and put its @path on the clipboard, ending with a single go/no-go verdict for clearing. Runs ONLY when the user literally types /reset; never self-invoked — when a boundary looks imminent, remind the user to run it, don't run it for them.
---

# reset — capture everything, hand off, clear-ready

> **Typed-invocation only.** Runs solely when the owner literally types `/reset`. Never
> self-invoke; when context is filling up or the owner mentions clearing/compacting, the move is
> a ONE-LINE reminder to run `/reset` — not running it unbidden.

The successor session starts with NOTHING but the system prompt, CLAUDE.md files, the memory
index, and whatever the owner pastes. This skill's job is making that enough.

## Step 1 — the /ready gate, in full

Run the `/ready` skill exactly as written: both questions, verdicts first, mechanical gaps fixed
silently on the spot. Do not paraphrase or abbreviate it — its sweep is the capture guarantee.

Gaps that need the owner's word do NOT block the rest of this skill: list them in the /ready
output as usual AND carry each one into the handoff's open-items section, so the answer can
arrive on either side of the boundary without being lost.

## Step 2 — the handoff file

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
- **Owner rulings of this session** — the do-not-re-ask list, each in one line.
- **Queue** — what runs next and its go-signal.
- **Open items awaiting the owner's word** — the Step-1 carryovers.
- **Protocol reminders** — only the ones a fresh session gets wrong without them.

## Step 3 — clipboard

Copy the handoff's **@-mention path** (e.g. `@/home/tom/di.handoff.md`) to the clipboard via
`fnc_copy_to_clipboard`, so the owner's first paste in the fresh session pulls the file in. If
the fnclaude tool is unavailable, say so and print the @path to copy by hand.

## Step 4 — one verdict line

End with exactly one of:

- `RESET-READY — handoff on clipboard; clear when you like.`
- `RESET-READY with <n> open owner words — they ride the handoff; answer before or after.`

There is no blocked verdict: the skill's job is to make clearing safe, and by this line it has
either done so or said precisely what rides along. Then stop — no new work after the verdict.

## Clear vs compact

The artifact serves both boundaries. When asked which to use: the curated handoff plus a green
gate makes `/clear` strictly better (auto-summaries are lossy about live agents and eat fresh-
window headroom); `/compact` remains the fallback when the owner wants to cut a boundary WITHOUT
running this ritual.
