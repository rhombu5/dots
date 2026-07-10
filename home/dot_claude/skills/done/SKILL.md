---
name: done
description: Completeness check that surfaces everything from this session's work not yet finished or landed. Confirms the session's work is committed, pushed, PRs merged, CI green, orphans cleared, and system state in parity. Trigger when the user asks any variant of "are we done?", "is it finished?", "all wrapped up?", "anything left?", "ready to stop?", "good to go?", "can I close this?", "all set?", "loose ends?" — or otherwise signals they're checking whether the session can end.
---

# Done?

Walk this checklist before stopping. For each item: **check, then report status** (✓ clear or N/A / ✗ outstanding / ⚠ needs a look) with a one-line note. N/A items get the check icon — they're not a problem, so don't flag them with a warning. Don't fix anything silently — surface every ✗ or ⚠ for the user to decide.

**Scope: this session only.** Every item below is evaluated against work the *current session* actually did — files touched, commits made, repos worked in, system changes applied. Pre-existing or unrelated state (uncommitted changes that pre-date the session, unpushed commits from other work, dots drift you didn't cause, PRs you didn't open or advance) is **out of scope: omit it from the report entirely** — don't list it as ⚠, don't fold it into a "while I'm here" note. This is a session-wrap checkpoint, not a whole-machine audit; `/dots` owns the machine-wide parity view. If it's genuinely unclear whether something is this session's doing, surface it as a question rather than a finding.

## 1. Task complete

- Is the thing the user asked for actually done end-to-end? Not "code written" — *done*.
- Any TODOs, stubs, half-implementations, or "I'll come back to this" left in the current or unlanded diff?
- If a UI/feature change: did you actually exercise it, or only type-check it?

## 2. Correctness gates

Run only the gates the project already uses, scoped to the diff:

- **Tests** — unit / integration suites green? New code covered?
- **Type-check** — `tsc`, `mypy`, `cargo check`, etc.
- **Lint / format** — eslint, ruff, clippy, prettier, gofmt — clean?
- **Build** — does it actually build / bundle / compile?

Don't invent gates that don't exist. Don't run a full repo-wide suite when only one file changed.

## 3. Docs in sync

- User-facing docs (README, man pages, `--help` text) still match behavior?
- Inline doc comments / docstrings on the touched code still accurate?
- New convention or rule that emerged — does it belong in `CLAUDE.md` (project or user-prefs)?
- Did a config example or quickstart drift?

## 4. Tasks / workitems

- Run `TaskList`. **Every task must be `completed` or `deleted` before reporting done.** Anything in `pending` or `in_progress` is visible to the user as a *not-crossed-out* item in the task UI — that's a direct visual signal of unfinished work, and the user should not see any of them when you wrap up. If a task got abandoned or turned out unnecessary, `delete` it; don't leave it as `pending` to rot.
- Anything you mentally tracked but never put in the task list? Surface it.

## 5. Secrets check

- Anything sensitive in staged or pushed diffs? `.env`, tokens, keys, API secrets, internal hostnames, tenant IDs?
- For the dots/arch-setup split: are private things landing in a private repo (`rhombu5`) and not a public one (`fnrhombus`)?
- Accidentally checked-in build artefacts that might embed secrets?

## 6. Git: committed

- `git status` in every repo this session worked in — clean working tree?
- If there are stray changes: are they from this session, or pre-existing? Pre-existing changes are out of scope — omit them (and certainly never commit them).
- Commits atomic (one logical change each)? If multiple tasks were batched into one commit, flag it.

## 7. Git: pushed

- `git log @{u}..` in every repo this session committed to — empty? Unpushed commits that pre-date the session are out of scope.
- If a feature spans multiple commits, all of them landed before pushing? (Per user prefs: push on feature completion, not partial.)
- Any branch that should have a PR but doesn't?

## 8. Open PRs

- Any open PRs this session created or advanced — including drafts? A draft PR implies unfinished work. A thing cannot be done while a PR is open.
- `gh pr list --state open` to check, then filter to this session's PRs — open PRs from other work don't belong in the report.
- Any in-scope open PR (draft or otherwise) is ✗ outstanding until merged or deliberately closed. ✓ only when all of them are merged (or explicitly closed as won't-fix).

## 9. CI green

- For anything pushed, did remote CI actually pass? `gh pr checks` or equivalent.
- Local clean ≠ remote clean. Don't claim done if CI is still running or red.

## 10. Orphans

- Files created during the work that aren't referenced anywhere (`handoff.md`, scratch notes, `*.bak`, debug scripts, generated artefacts)?
- Imports/symbols left dead by a refactor?
- Empty directories from moves/renames?

## 11. Memory hygiene

- **Stale** — any memory entry that turned out wrong, or that recent work contradicted? Update or remove the affected ones.
- **Missing** — anything notable that came up and should be in memory but isn't? User prefs, project gotchas, surprising behavior, validated approaches. Save it now. Don't invent — only save things that genuinely surfaced.

## 12. System parity (Linux machines only)

For every system change *made this session*, all three states must agree (drift caused by other work is `/dots`'s job, not this checklist's):

- **Live system** — change is applied and working.
- **`dots`** — if it's a user-config / chezmoi-managed file, the change is in `~/src/dots@rhombu5/` and committed + pushed.
- **`arch-setup`** — if it's a package install, service enable, or bootstrap-relevant tweak, mirrored into `~/src/arch-setup@fnrhombus/` and committed + pushed.

Verify with:

- `chezmoi diff` — filter the output to files this session touched; drift elsewhere is out of scope.
- `git status` + `git log @{u}..` in both `dots` and `arch-setup` — again scoped to this session's changes.
- For packages: spot-check that anything you `pacman -S`'d this session appears in the arch-setup package list.

✓ = N/A on non-Linux.

## 13. Anything weird

- **No background shells still running.** Any process you started with `Bash(... run_in_background: true)` — and which is therefore still showing in the **status bar at the bottom of the user's window** — is a direct visual signal of unfinished work. The user should not see any active shell indicator when you wrap up. Either wait for it (if it's near completion), kill it (if its output is no longer needed), or — if it's load-bearing for the task — you're *not done*; keep working until it's finished or explicitly surface it as outstanding.
- Sudo state, env vars, or shell mutations that'd surprise the user's next session?
- Open editor windows / dialogs you spawned for testing?

## 14. Open bugs in the repo

`gh issue list --state open --label bug --limit 10` — any open bug-labeled issues? Two specific cases to flag:

- A bug that recent work might have *introduced* (e.g., a refactor whose blast radius matches the bug report). Don't close out leaving a fresh bug open.
- A bug closely adjacent to what was changed (e.g., you refactored module X and there's an open bug about X's behavior). Worth surfacing as "you were here — want to look?", not silently moving on.

Don't audit every bug in the tracker — that's project health, not session wrap-up. Scope to bugs that touch the area that was worked in.

⚠ when bugs exist that might relate; ✓ when no related bugs (or none open); ✓ N/A if the repo isn't a GitHub repo or doesn't use the `bug` label.

---

## Output shape

Report as a compact checklist:

```
 1. Task complete       ✓ feature shipped end-to-end
 2. Correctness gates   ✓ tsc + eslint + vitest all green
 3. Docs in sync        ⚠ README still shows old flag name
 4. Tasks / workitems   ✓ TaskList empty
 5. Secrets check       ✓ clear
 6. Committed           ✗ 2 untracked files in dots/
 7. Pushed              ✓ both repos up to date
 8. Open PRs            ✗ PR #43 still open (draft)
 9. CI green            ⚠ CI still running on PR #42
10. Orphans             ⚠ handoff.md still in arch-setup/ — delete?
11. Memory hygiene      ✓ saved one project memory; nothing stale
12. System parity       ✓ live ↔ dots ↔ arch-setup agree
13. Anything weird      ✓
14. Open bugs           ⚠ #77 might relate to today's restart work
```

Then list the ✗ / ⚠ items as concrete next actions, and ask the user how to proceed. Don't just fix them — the point of this skill is the *checkpoint*, not silent cleanup.
