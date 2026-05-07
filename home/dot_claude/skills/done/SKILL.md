---
name: done
description: End-of-session wrap-up checklist. Confirms work is finished, committed, pushed, with no orphans and full parity between live system, dots, and arch-setup. Trigger when the user asks any variant of "are we done?", "is it finished?", "all wrapped up?", "anything left?", "ready to stop?", "good to go?", "can I close this?", "all set?", "loose ends?" — or otherwise signals they're checking whether the session can end.
---

# Done?

Walk this checklist before stopping. For each item: **check, then report status** (✓ clear / ✗ outstanding / ⚠ N/A) with a one-line note. Don't fix anything silently — surface every ✗ or ⚠ for the user to decide.

## 1. Task complete

- Is the thing the user asked for actually done end-to-end? Not "code written" — *done*.
- Any TODOs, stubs, half-implementations, or "I'll come back to this" left in the diff?
- If a UI/feature change: did you actually exercise it, or only type-check it?

## 2. Tasks / workitems

- Run `TaskList`. Any task not in `completed` state?
- Anything you mentally tracked but never put in the task list? Surface it.

## 3. Git: committed

- `git status` in every repo touched this session — clean working tree?
- If there are stray changes: are they yours from this session, or pre-existing? Don't commit pre-existing without asking.
- Commits atomic (one logical change each)? If you batched multiple tasks into one commit, flag it.

## 4. Git: pushed

- `git log @{u}..` in every repo touched — empty?
- If a feature spans multiple commits, all of them landed before pushing? (Per user prefs: push on feature completion, not partial.)
- Any branch that should have a PR but doesn't?

## 5. Orphans

- Files created during the work that aren't referenced anywhere (`handoff.md`, scratch notes, `*.bak`, debug scripts, generated artefacts)?
- Imports/symbols left dead by a refactor?
- Empty directories from moves/renames?
- Memory entries written this session that turned out wrong or stale?

## 6. System parity (Linux machines only)

For every system change made this session, all three states must agree:

- **Live system** — change is applied and working.
- **`dots`** — if it's a user-config / chezmoi-managed file, the change is in `~/src/dots@rhombu5/` and committed + pushed.
- **`arch-setup`** — if it's a package install, service enable, or bootstrap-relevant tweak, mirrored into `~/src/arch-setup@fnrhombus/` and committed + pushed.

Verify with:

- `chezmoi diff` — empty output means dots is in sync with live.
- `git status` + `git log @{u}..` in both `dots` and `arch-setup`.
- For packages: spot-check that anything you `pacman -S`'d this session appears in the arch-setup package list.

⚠ = N/A on non-Linux.

## 7. Anything weird

- Background processes still running you forgot about?
- Sudo state, env vars, or shell mutations that'd surprise the user's next session?
- Open editor windows / dialogs you spawned for testing?

---

## Output shape

Report as a compact checklist:

```
1. Task complete       ✓ feature shipped end-to-end
2. Tasks / workitems   ✓ TaskList empty
3. Committed           ✗ 2 untracked files in dots/
4. Pushed              ✓ both repos up to date
5. Orphans             ⚠ handoff.md still in arch-setup/ — delete?
6. System parity       ✓ live ↔ dots ↔ arch-setup agree
7. Anything weird      ✓
```

Then list the ✗ / ⚠ items as concrete next actions, and ask the user how to proceed. Don't just fix them — the point of this skill is the *checkpoint*, not silent cleanup.
