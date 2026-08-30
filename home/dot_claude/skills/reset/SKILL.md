---
name: reset
description: Session-boundary ritual before a /clear (or compact), invoked as /reset <context %> — a cheap band check runs first on every call so frequent status-check invocations just report the %; the /ready capture sweep itself runs at most once per stretch, immediately before the actual clear, autofixing every issue with an obvious solution and /explain-ing the rest to the owner one at a time until fully clear; then JUDGE the timing (the context % governs how long deferring for a cleaner board is safe, weighed against what is actually loaded — reluctant to clear context the successor would immediately have to rebuild, eager to clear once the topic has moved on even at a low %, and the invocation itself is not a nudge toward handing off sooner) and either hand off now or announce a deferral trigger; the handoff is burn-after-reading with its @path on the clipboard. Runs ONLY when the user literally types /reset; never self-invoked — when a boundary looks imminent, remind the user to run it, don't run it for them.
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

**Every call — first or repeat — starts with a cheap band check, not the gate loop.** Place the
given % into Step 2's bands (budget) AND weigh the content axis from Step 2's "Weigh what is in
the window" (live vs. dead against the next item) — both apply on the very first `/reset` of a
stretch, not only on a repeat reaffirming a standing deferral. This is what makes frequent
invocation free: the owner runs `/reset` often purely to have the level reported, and answering
that must never cost a sweep — but a "we're moving to a new topic" alongside the call is exactly
the content axis flipping to dead, and is weighed on that same cheap call, no sweep required to
see it.

- **Comfortably under the no-deferral band, and the content axis still live (or, on a first call,
  no reason yet to call it dead)** — answer in one line (the number, "well within budget") and
  stop: no sweep, no dialog, no handoff composed. The one-liner establishes the deferral on a
  first call, or reaffirms the standing one on a repeat call, with its prior resume trigger still
  holding.
- **Crosses into the no-deferral band, the awaited event's expected remaining cost no longer fits
  under the ceiling, or the content axis is dead** (mostly dead, or the topic has moved on — eager
  even at a small %, per Step 2) — the band check ends here: run the gate loop below, then compose
  and hand off.

**The gate loop runs at most once per stretch, immediately before the compose that ends it** —
whichever call first crosses into it (per the band check above) is the one that runs it: a full
sweep if the loop has never run this stretch, delta-scoped to state created since it last ran
otherwise. Never twice, never skipped when the moment arrives — see the Hard Invariant in Step 2.

## Step 1 — the gate loop: sweep → autofix → dialog → re-sweep

Reached only via the band check above — a first crossing into gate-loop territory, or the
mandatory sweep immediately before compose. Run the `/ready` skill's sweep (both questions,
verdicts first). Then resolve what it found:

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

## Step 2 — timing judgment: the board, the content, and the budget

A boundary minutes away from a naturally cleaner board (a lane's report or merge imminent, a gate
run finishing, one in-flight review about to close) is worth waiting for — a handoff describing
"merged" beats one describing "mid-review". The context % is the budget for that patience:

**The invocation is not a vote on timing.** The owner typed `/reset` to start the ritual, not to
tip the scale toward clearing; defer-vs-now is purely a token-efficiency judgment — re-reading a
large, mostly-live window every turn against the successor re-reading files and re-deriving
reasoning after a clear. Ties resolve on that cost, never on the keystroke. And a low context % is
permission to wait, never by itself a reason to.

**Weigh what is in the window, not just how full it is.** Sort what's loaded by whether it is
load-bearing for the queue's next item — live: files read, designs reasoned out in-conversation,
in-flight agent dialog, rulings; dead: finished topics, abandoned explorations, another project's
files, drafts since superseded. The ratio that matters is against the NEXT item, not the window's
whole history.

- **Mostly live, next item continues the thread → reluctant.** A handoff carries rulings and
  board state cheaply; it cannot carry the loaded files or the thinking behind them — the
  successor pays to re-read and re-derive both the moment it starts. Prefer deferring to a
  CONTENT SEAM: the point where the live context stops being needed (the feature lands, the
  lane's report is consumed, the design gets written down durably). Name the seam as the concrete
  trigger, same as a board event. Content reluctance is a real argument, weighed like an imminent
  board event; it never extends a deferral past the bands' ceiling;
  the owner's "now" still overrides.
- **Mostly dead, or the topic has moved on → eager, even at a small %.** Dead context is paid for
  on every turn — the whole history is re-read through the prefix cache each turn — and it
  dilutes attention; a fresh window plus the handoff is cheaper than carrying it. A low % is never
  by itself a reason to keep going; hand off now.
- **Live but no seam in reach** (budget tight, or the thread is long): shrink the rebuild cost
  instead of waiting — write the in-conversation reasoning down durably (a decision note, task
  substance, a design doc in the repo) so "must re-derive" becomes "must read one file". This is
  an autofix-shaped move; do it, re-sweep, then hand off. The handoff's reload list (Step 3) is
  what makes a modest live set survivable — a small live set is not itself grounds to defer.

The bands assume a 1M-token window (even 10% is serious headroom) and that auto-compact fires
around 99–100% — an auto-compact mid-ritual destroys exactly what this ritual protects, so the
budget must cover the DEFERRED EVENT'S own consumption (a lane report plus its review can be
several percent) plus the delta sweep and compose (~2%), keeping the projected total under ~97%:

- **≥ ~95%** — no deferral. Only the sweep-and-compose itself still fits; do it immediately.
- **~90–95%** — defer only for events expected within a few turns (an imminent lane report, one
  merge), and only ONE such event — and only if its expected consumption keeps the projected
  total under ~97%; when it lands, run the delta sweep and hand off.
- **< ~90%** — free to wait for a natural seam, still naming a concrete trigger; with no seam
  worth naming, hand off now.

Deferring is the skill's decision, announced with the reason and a CONCRETE resume trigger — a
board event or a content seam ("after PR #N merges", "when lane X's report arrives", "once the
renderer design is written into docs/…"). The owner's "now" overrides any deferral.

**The deferred event WILL dirty the sweep — that is expected and planned for.** When the band
check sends a call into the gate loop while the owner is present, that is the moment to harvest
his words: the deferred event's own products rarely need new dialog (its rulings were made before
it was dispatched; its defects get fixed, not adjudicated). On the trigger, the mandatory sweep —
full if the gate loop has never run this stretch, otherwise **delta-scoped** to state created since
it last ran (the event's commits, § entries, task motion, anything its report surfaced) — closes
it out. Then:

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
exists; otherwise `~/<repo>-<branch>-<session-id>.handoff.md`, where `<session-id>` is the first 8
hex characters of `$CLAUDE_CODE_SESSION_ID` — never `<repo>-<branch>` alone or a bare topic name,
either of which any other session or lane working the same repo (same or different branch)
clobbers. Match `/compact`-summary
density — curated, present-tense, zero padding, nothing the successor can cheaply re-derive from
the repo or task store. It must carry:

- **Header**: BURN AFTER READING — absorb, then `rm`. Session-home path and its live quirks
  (stale worktree, isolation-hook workarounds, path traps) stated as standing facts.
- **Board**: current tips/state, what landed this session, gate status.
- **In-flight work with IDENTIFIERS.** Background processes SURVIVE a clear — proven per class
  (2026-08-15 /clear experiment): background shells keep running and stay addressable by their
  pre-clear task ids; persistent monitors keep running AND their notifications deliver into the
  post-clear session; teammates keep running with two-way stale-name `SendMessage` and `TaskStop`
  intact, though `ListAgents` no longer lists them — an empty roster is NOT evidence of death.
  The CONVERSATION about them does not survive — so name every live agent/lane (name + task # +
  branch + worktree path), every background task and monitor (task id + what it watches), every
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
- **Open items awaiting the owner** — every unanswered question, undecided fork, and
  unconfirmed work request still pending at compose time. The clean sweep guarantees each one
  already lives in a tracked task or durable record — this section is the roster POINTING at
  them (one line each, task # or record path), plus the task-store id as queue of record, so
  the successor re-surfaces them (`/askme`) instead of rediscovering them. Empty is a valid
  state; say so explicitly rather than omitting the section.
- **Reload list** — the ORDERED, MINIMAL set of files, docs, and memory entries the successor
  must read before touching the queue's first item; only what was live at compose time, nothing
  dead, nothing cheaply re-derivable from the repo or task store. Where the live context is
  reasoning rather than a file, write it down (into the handoff or a durable note) and list the
  note — never "re-derive X". Empty is a valid state; say so.
- **Queue** — what runs next and its go-signal.
- **Protocol reminders** — only the ones a fresh session gets wrong without them.

## Step 4 — clipboard

Copy the handoff's **@-mention path** (e.g. `@/home/tom/di.handoff.md`) to the clipboard via
`fnc_copy_to_clipboard`, so the owner's first paste in the fresh session pulls the file in. If
the fnclaude tool is unavailable, say so and print the @path to copy by hand.

## Step 5 — one verdict line, unmistakable

End the invocation with exactly one of these, on its own line, as the LAST line of the message:

- `***CLEAR NOW*** — handoff on clipboard; paste it as your first message after clearing.`
- `RESET-DEFERRED — do NOT clear yet; waiting for <trigger> (context <n>%, safe). The go-word follows when it lands.`

**The go-word is a physical signal, not a word — never emit it except as the real verdict.** It is
read by a skimming eye that sees bold capitals and acts. So it must NOT appear anywhere except as
the terminal line of a clean-sweep compose: not in the deferral line, not in a plan or a promise
about what you will say later, not when quoting or recapping an earlier verdict, not in an
explanation of this skill, and not in any partial state. A deferral says **"the go-word"** and
nothing more — writing the phrase itself inside a "do NOT clear yet" line is the exact failure this
rule exists to prevent, because the negation is what gets skimmed past.

The same holds outside this skill: if the owner asks what the verdict was, or you need to discuss
the ritual, refer to it as the go-word. Emitting it is an instruction to clear the session, and it
is never merely a description of one.

A deferred run ends by emitting the go-word line once the trigger lands and Steps 3–4 complete.
There is no blocked state: the Step-1 loop holds in dialog until clear. After the verdict, stop —
no new work.

## Clear vs compact

The artifact serves both boundaries. When asked which to use: the curated handoff plus a clean
gate makes `/clear` strictly better (auto-summaries are lossy about live agents and eat fresh-
window headroom); `/compact` remains the fallback when the owner wants to cut a boundary WITHOUT
running this ritual.
