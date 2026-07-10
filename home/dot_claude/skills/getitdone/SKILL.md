---
name: getitdone
description: Like /done, but resolves every obvious item itself and only reports what's left. Use when the user says "just finish it", "wrap it up", "tie up loose ends and tell me what's stuck", "do the obvious cleanup and report what's blocking", or any variant where they want the cleanup *done* rather than itemized. If they're asking for a checkpoint to review themselves, use /done instead.
---

# Get it done

This is `/done` with the obvious items resolved instead of just listed. Same checklist, same scope, different posture: act on the safe stuff, surface only what needs a human decision. `/done`'s session-only scope applies in full here: pre-existing state from other sessions or other work in flight is neither reported **nor fixed** — an out-of-scope item is not a cleanup opportunity, it's someone else's work.

## How to run it

1. **Load the canonical checklist** by reading `~/.claude/skills/done/SKILL.md`. That file is the source of truth — walk every item it defines, in order. Do not maintain a parallel checklist here; if `/done` evolves, `/getitdone` automatically inherits the change.

2. **For each item**, evaluate as `/done` would: ✓ clear or N/A / ✗ outstanding / ⚠ needs a look. N/A items get the check icon, not a warning.

3. **For each ✗ or surprising ⚠**, decide: is the resolution obvious *and* safe?
   - **Yes** → fix it now without asking. Track what you fixed for the report.
   - **No** → leave it; surface it in the report.

4. **Re-walk only the items you touched** to confirm the fix landed. If a fix exposed a new ✗ (a commit triggered CI, an apply revealed drift), bring that into the report too.

5. **Report only what's left** — the residual ✗ / ⚠ items that still need a decision. Plus a one-line "fixed:" trailer summarizing what got resolved silently.

## What counts as "obvious"

Bias toward action when the move is **reversible and matches what the user clearly wants**. Examples — none of these is mandatory; act only when the item is genuinely outstanding:

- **Uncommitted changes** → stage path-scoped, commit atomically with a message inferred from the diff. Push if the feature is complete (per user prefs: push on feature completion).
- **Orphan handoff/scratch files** that are no longer needed → delete.
- **Memory entries that should be saved** based on what surfaced → save them. Don't invent — only what genuinely came up.
- **Stale memory entries** that recent work contradicted → update or remove the affected ones.
- **`chezmoi re-add` / `chezmoi apply` parity** when a live edit has an obvious chezmoi-source counterpart → reconcile.
- **TaskList items left in non-`completed` state** for work that's actually finished → mark `completed`. For tasks that turned out unnecessary or got superseded → `delete`. **Leave nothing in `pending` or `in_progress`** — the user sees those as not-crossed-out items in the task UI, which reads as unfinished work.
- **Background shells you started that have already completed** → fold their output into the work (or dismiss it), then move on. Don't leave finished-but-unread shells dangling in the status bar. If a shell is still genuinely running and its result is needed: you're *not done* — keep working. If it's running but no longer needed: kill it.
- **`arch-setup` mirror commits** for one-off system changes → write and push them.
- **An open PR that is clearly meant to land** — green and mergeable, no review pending, clearly yours — merge it. For a standing automated release PR (release-please, changesets) in a repo whose release flow designates wrap-up as the release point, merge it and monitor the publish chain to its terminal state (artifact published / package installable). **Draft PRs, PRs awaiting review, and conflicted PRs are not obvious to merge — leave and report them.**

## What does NOT count as "obvious"

Stop and report — never silently fix:

- **Failing tests, type errors, lint errors** — could indicate a real bug; user decides whether to chase or punt.
- **CI red on a pushed commit** — same.
- **Doc drift** — wording is a judgment call; don't rewrite README sections unprompted.
- **Pre-existing uncommitted changes you didn't make** — never touch.
- **Anything destructive on shared state**: force-push, branch deletion, history rewrites, `git reset --hard`, dropping uncommitted work.
- **Sensitive content in a diff** — flag it; the user decides whether to redact, rotate, or ship.
- **Anything you'd need to ask "should I…?" about** — the asking is the signal it's not obvious.

When unsure whether an item is obvious, default to surfacing it. The cost of leaving a fix for the user is one extra exchange; the cost of an unwanted action can be real work.

## Output shape

```
fixed: committed + pushed dots (chezmoi parity for keybindings.json); marked 2 TaskList items complete; saved 1 memory about <topic>

still outstanding:
 2. Correctness gates   ✗ vitest: 1 failure in <file> — looks like a real regression, take a look
 8. Open PRs            ✗ PR #43 is a draft — merge when ready?
 9. CI green            ⚠ PR #42 still running, check back in ~2min
```

If nothing is outstanding, say so plainly: **"all green — done."** Drop the "fixed:" trailer if nothing got fixed.
