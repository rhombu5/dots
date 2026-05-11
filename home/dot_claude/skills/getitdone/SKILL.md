---
name: getitdone
description: Like /done, but resolves every obvious item itself and only reports what's left. Use when the user says "just finish it", "wrap it up", "tie up loose ends and tell me what's stuck", "do the obvious cleanup and report what's blocking", or any variant where they want the cleanup *done* rather than itemized. If they're asking for a checkpoint to review themselves, use /done instead.
---

# Get it done

This is `/done` with the obvious items resolved instead of just listed. Same checklist, same scope rules, different posture: act on the safe stuff, surface only what needs a human decision.

## How to run it

1. **Load the canonical checklist** by reading `~/.claude/skills/done/SKILL.md`. That file is the source of truth — walk every item it defines, in order, with the exact same scope and N/A rules. Do not maintain a parallel checklist here; if `/done` evolves, `/getitdone` automatically inherits the change.

2. **For each item**, evaluate as `/done` would: ✓ clear / ✗ outstanding / ⚠ N/A. Apply `/done`'s scope discipline strictly:
   - Only items the session actually touched are in scope.
   - "We didn't touch that" → ⚠ N/A with one word of justification, not investigation.
   - Don't run repo-wide test suites, don't audit pre-existing memory, don't read READMEs you didn't change. The wrap-up is for *this session's work*, not the project's overall health.

3. **For each ✗ or surprising ⚠**, decide: is the resolution obvious *and* safe *and* in scope?
   - **Yes** → fix it now without asking. Track what you fixed for the report.
   - **No** → leave it; surface it in the report.

4. **Re-walk only the items you touched** to confirm the fix landed. If a fix exposed a new ✗ (a commit triggered CI, an apply revealed drift), bring that into the report too.

5. **Report only what's left** — the residual ✗ / ⚠ items that still need a decision. Plus a one-line "fixed:" trailer summarizing what got resolved silently.

## What counts as "obvious"

Bias toward action when the move is **reversible, in scope, and matches what the user clearly wants** for this session. Examples — none of these is mandatory; act only when the item is genuinely outstanding from this session's work:

- **Uncommitted changes that are this session's work** → stage path-scoped, commit atomically with a message inferred from the diff. Push if the feature is complete (per user prefs: push on feature completion).
- **Orphan handoff/scratch files this session created** and no longer needs → delete.
- **Memory entries that should be saved** based on what surfaced this session → save them. Don't invent — only what genuinely came up.
- **Stale memory entries this session contradicted** → update or remove the affected ones.
- **`chezmoi re-add` / `chezmoi apply` parity** when a live edit this session has an obvious chezmoi-source counterpart → reconcile.
- **TaskList items this session left in non-`completed` state** for work that's actually finished → mark `completed`. For tasks that turned out unnecessary or got superseded → `delete`. **Leave nothing in `pending` or `in_progress`** — the user sees those as not-crossed-out items in the task UI, which reads as unfinished work.
- **Background shells you started that have already completed** → fold their output into the work (or dismiss it), then move on. Don't leave finished-but-unread shells dangling in the status bar. If a shell is still genuinely running and its result is needed: you're *not done* — keep working. If it's running but no longer needed: kill it.
- **`arch-setup` mirror commits** for one-off system changes the session made → write and push them.

If a category above doesn't apply to this session, **don't go looking for work in it.** No session has all of them; many sessions have none.

## What does NOT count as "obvious"

Stop and report — never silently fix:

- **Failing tests, type errors, lint errors** — could indicate a real bug; user decides whether to chase or punt.
- **CI red on a pushed commit** — same.
- **Doc drift** — wording is a judgment call; don't rewrite README sections unprompted.
- **Pre-existing uncommitted changes you didn't make this session** — never touch.
- **Anything destructive on shared state**: force-push, branch deletion, history rewrites, `git reset --hard`, dropping uncommitted work.
- **Anything outside this session's scope** — even if you spot it, it's not yours to fix here. Surface it as an FYI at most.
- **Sensitive content in a diff** — flag it; the user decides whether to redact, rotate, or ship.
- **Anything you'd need to ask "should I…?" about** — the asking is the signal it's not obvious.

When unsure whether an item is obvious, default to surfacing it. The cost of leaving a fix for the user is one extra exchange; the cost of an unwanted action can be real work.

## Output shape

```
fixed: committed + pushed dots (chezmoi parity for keybindings.json); marked 2 TaskList items complete; saved 1 memory about <topic>

still outstanding:
 2. Correctness gates   ✗ vitest: 1 failure in <file> — looks like a real regression, take a look
 8. CI green            ⚠ PR #42 still running, check back in ~2min
```

If nothing is outstanding, say so plainly: **"all green — done."** Drop the "fixed:" trailer if nothing got fixed.
