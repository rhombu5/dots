---
name: reset
description: Session-boundary ritual before a /clear (or compact), invoked as /reset <context %> — loop the /ready capture sweep, autofixing every issue with an obvious solution and /explain-ing the rest to the owner one at a time until fully clear; then JUDGE the timing (the context % governs how long deferring for a cleaner board is safe) and either hand off now or announce a deferral trigger; the handoff is burn-after-reading with its @path on the clipboard. Runs ONLY when the user literally types /reset; never self-invoked — when a boundary looks imminent, remind the user to run it, don't run it for them.
---

# reset — sweep until clear, judge the timing, then hand off

> **Typed-invocation only.** Runs solely when the owner literally types `/reset`. Never
> self-invoke; when context is filling up or the owner mentions clearing/compacting, the move is
> a ONE-LINE reminder to run `/reset` — not running it unbidden.

The successor session starts with NOTHING but the system prompt, CLAUDE.md files, the memory
index, and whatever the owner pastes. This skill's job is making that enough — and picking the
moment where the handoff describes the cleanest possible board.

## The argument is the current context percentage — required

`/reset <n>` where `<n>` is the context usage the owner reads from his UI. It is the safety
budget for the timing judgment below. If it is missing, ask for it in one line before anything
else — do not guess it and do not skip the timing judgment for lack of it.

**Re-invocation during a deferral is a context update, not a restart.** Re-run only the timing
judgment against the new number, using the same Step-2 bands. Context always grows between
updates — mere consumption within the same band re-affirms the deferral in one line. The
deferral cancels (delta sweep → compose → verdict immediately) only when the new number crosses
into the no-deferral band, or the awaited event's expected remaining cost no longer fits under
that ceiling. The Step-1 gate does not re-run — the trigger's delta sweep already owns new state.

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

## Step 2 — timing judgment: hand off now, or wait for a cleaner board

A boundary minutes away from a naturally cleaner board (a lane's report or merge imminent, a gate
run finishing, one in-flight review about to close) is worth waiting for — a handoff describing
"merged" beats one describing "mid-review". The context % is the budget for that patience:

The bands assume a 1M-token window (even 10% is serious headroom) and that auto-compact fires
around 99–100% — an auto-compact mid-ritual destroys exactly what this ritual protects, so the
budget must cover the DEFERRED EVENT'S own consumption (a lane report plus its review can be
several percent) plus the delta sweep and compose (~2%), keeping the projected total under ~97%:

- **≥ ~95%** — no deferral. Only the sweep-and-compose itself still fits; do it immediately.
- **~90–95%** — defer only for events expected within a few turns (an imminent lane report, one
  merge), and only ONE such event — and only if its expected consumption keeps the projected
  total under ~97%; when it lands, run the delta sweep and hand off.
- **< ~90%** — free to wait for a natural seam, still naming a concrete trigger.

Deferring is the skill's decision, announced with the reason and a CONCRETE resume trigger
("after PR #N merges", "when lane X's report arrives"). The owner's "now" overrides any deferral.

**The deferred event WILL dirty the early sweep — that is expected and planned for.** The Step-1
sweep still runs up front because its dialog needs the owner AT THE KEYBOARD: harvest his words
while he is present, since the deferred event's own products rarely need new ones (its rulings
were made before it was dispatched; its defects get fixed, not adjudicated). On the trigger, a
**delta sweep is mandatory** — both /ready questions, scoped to state created since the early
sweep (the event's commits, § entries, task motion, anything its report surfaced). Then:

- delta clean → proceed to the handoff;
- delta finds an autofixable → fix it, re-sweep, proceed;
- delta finds an owner-word item and the owner responds → dialog as usual;
- delta finds an owner-word item and the owner is away → HOLD (deferred idling is nearly free)
  until he returns or the context ceiling nears. At the ceiling, CONVERT the item into a
  FIRST-ON-OWNER'S-RETURN task carrying its full substance and the exact one-word question —
  tracked-with-substance is precisely what /ready's own untracked test accepts as resolved — then
  re-sweep and proceed. The ruling is still owed, but it is owed from a durable record, not from
  a dying conversation.

**Hard invariant: the handoff is only ever composed immediately after a sweep that came back
clean, with no work in between.** Whatever path led there — straight through, deferral, dialog,
or ceiling-conversion — the compose-and-clipboard step follows a clean sweep in the same breath,
so the owner can clear on the verdict line without re-checking anything.

## Step 3 — the handoff file

Write a **burn-after-reading** handoff. Path: reuse the session's established handoff file if one
exists (e.g. `~/di.handoff.md`); otherwise `~/<short-topic>.handoff.md`. Match `/compact`-summary
density — curated, present-tense, zero padding, nothing the successor can cheaply re-derive from
the repo or task store. It must carry:

- **Header**: BURN AFTER READING — absorb, then `rm`. Session-home path and its live quirks
  (stale worktree, isolation-hook workarounds, path traps) stated as standing facts.
- **Board**: current tips/state, what landed this session, gate status.
- **In-flight work with IDENTIFIERS.** Background processes are EXPECTED to survive a clear
  (proven through /compact; monitors by their own until-session-end contract) but the
  conversation about them does not — so name every live agent/lane (name + task # + branch +
  worktree path), every background task and monitor (task id + what it watches), every
  reservation (§ numbers, branch names, file locks), and what the successor does when each one
  reports, wedges, or dies. Point at `/powerloss` for identify-by-transcript discipline.
- **VERIFY-AND-REBUILD instructions, per background resource.** For each live monitor, shell,
  and agent: a concrete aliveness check (the output file that should be growing, the notification
  that should arrive, the process/worktree evidence to look for) and a rebuild recipe if it is
  dead. A recipe must not depend on tmpfs: scratchpad script paths may be cited for convenience,
  but the recipe carries the script's ESSENCE inline (what it watches, its emit conditions, its
  wedge timeout) so the successor can rewrite it after a reboot. The successor's first act is
  running the aliveness checks and rebuilding what failed.
- **Owner rulings of this session** — the do-not-re-ask list, each in one line, deferrals
  included.
- **Queue** — what runs next and its go-signal.
- **Protocol reminders** — only the ones a fresh session gets wrong without them.

## Step 4 — clipboard

Copy the handoff's **@-mention path** (e.g. `@/home/tom/di.handoff.md`) to the clipboard via
`fnc_copy_to_clipboard`, so the owner's first paste in the fresh session pulls the file in. If
the fnclaude tool is unavailable, say so and print the @path to copy by hand.

## Step 5 — one verdict line, unmistakable

End the invocation with exactly one of these, on its own line, as the LAST line of the message:

- `***CLEAR NOW*** — handoff on clipboard; paste it as your first message after clearing.`
- `RESET-DEFERRED — do NOT clear yet; waiting for <trigger> (context <n>%, safe). ***CLEAR NOW*** follows when it lands.`

`***CLEAR NOW***` is reserved: it appears ONLY as the terminal verdict of a clean-sweep compose,
never in explanation, examples, or partial states — so seeing it means exactly one thing. A
deferred run ends with the `***CLEAR NOW***` line when the trigger lands and Steps 3–4 complete.
There is no blocked state: the Step-1 loop holds in dialog until clear. After the verdict, stop —
no new work.

## Clear vs compact

The artifact serves both boundaries. When asked which to use: the curated handoff plus a clean
gate makes `/clear` strictly better (auto-summaries are lossy about live agents and eat fresh-
window headroom); `/compact` remains the fallback when the owner wants to cut a boundary WITHOUT
running this ritual.
