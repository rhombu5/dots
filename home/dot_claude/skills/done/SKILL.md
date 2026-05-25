---
name: done
description: End-of-session wrap-up checklist. Confirms work is finished, committed, pushed, with no orphans and full parity between live system, dots, and arch-setup. Trigger when the user asks any variant of "are we done?", "is it finished?", "all wrapped up?", "anything left?", "ready to stop?", "good to go?", "can I close this?", "all set?", "loose ends?" — or otherwise signals they're checking whether the session can end.
---

# Done?

Walk this checklist before stopping. For each item: **check, then report status** (✓ clear / ✗ outstanding / ⚠ N/A) with a one-line note. Don't fix anything silently — surface every ✗ or ⚠ for the user to decide.

**Scope: only what this session actually touched.** This is a wrap-up, not an audit. If the session didn't write code, correctness gates are ⚠ N/A — don't run the test suite to be thorough. If no behavior changed, docs are ⚠ N/A — don't go reading the README. If you didn't push, CI is ⚠ N/A. Items only get a ✓ or ✗ when they're *in scope for this session*. The default for "we didn't touch that" is ⚠ N/A with one word of justification, not investigation.

## 1. Task complete

- Is the thing the user asked for actually done end-to-end? Not "code written" — *done*.
- Any TODOs, stubs, half-implementations, or "I'll come back to this" left in the diff?
- If a UI/feature change: did you actually exercise it, or only type-check it?

## 2. Correctness gates

**Only if this session changed code.** Otherwise ⚠ N/A.

Run only the gates the project already uses, scoped to the diff:

- **Tests** — unit / integration suites green? New code covered?
- **Type-check** — `tsc`, `mypy`, `cargo check`, etc.
- **Lint / format** — eslint, ruff, clippy, prettier, gofmt — clean?
- **Build** — does it actually build / bundle / compile?

Don't invent gates that don't exist. Don't run a full repo-wide suite when only one file changed.

## 3. Docs in sync

**Only if this session changed observable behavior or established a new convention.** Otherwise ⚠ N/A.

- User-facing docs (README, man pages, `--help` text) still match the new behavior?
- Inline doc comments / docstrings on the touched code still accurate?
- New convention or rule that emerged — does it belong in `CLAUDE.md` (project or user-prefs)?
- Did a config example or quickstart drift?

## 4. Tasks / workitems

- Run `TaskList`. **Every task must be `completed` or `deleted` before reporting done.** Anything in `pending` or `in_progress` is visible to the user as a *not-crossed-out* item in the task UI — that's a direct visual signal of unfinished work, and the user should not see any of them when you wrap up. If a task got abandoned or turned out unnecessary, `delete` it; don't leave it as `pending` to rot.
- Anything you mentally tracked but never put in the task list? Surface it.

## 5. Secrets check

**Only the diff this session produced.** Don't audit existing repo content.

- Anything sensitive in this session's staged or pushed diff? `.env`, tokens, keys, API secrets, internal hostnames, tenant IDs?
- For the dots/arch-setup split: are private things landing in a private repo (`rhombu5`) and not a public one (`fnrhombus`)?
- Accidentally checked-in build artefacts that might embed secrets?

## 6. Git: committed

- `git status` in every repo touched this session — clean working tree?
- If there are stray changes: are they yours from this session, or pre-existing? Don't commit pre-existing without asking.
- Commits atomic (one logical change each)? If you batched multiple tasks into one commit, flag it.

## 7. Git: pushed

- `git log @{u}..` in every repo touched — empty?
- If a feature spans multiple commits, all of them landed before pushing? (Per user prefs: push on feature completion, not partial.)
- Any branch that should have a PR but doesn't?

## 8. CI green

- For anything pushed this session, did remote CI actually pass? `gh pr checks` or equivalent.
- Local clean ≠ remote clean. Don't claim done if CI is still running or red.

## 9. Orphans

- Files created during the work that aren't referenced anywhere (`handoff.md`, scratch notes, `*.bak`, debug scripts, generated artefacts)?
- Imports/symbols left dead by a refactor?
- Empty directories from moves/renames?

## 10. Memory hygiene

**Scoped to this session only.** Don't audit the existing memory store.

- **Stale** — any memory entry written *this session* that turned out wrong, or any pre-existing memory that this session contradicted? Update or remove the affected ones.
- **Missing** — anything notable that came up *this session* that should be in memory but isn't? User prefs, project gotchas, surprising behavior, validated approaches. Save it now. Don't invent — only save things that genuinely surfaced.

## 11. System parity (Linux machines only)

For every system change made this session, all three states must agree:

- **Live system** — change is applied and working.
- **`dots`** — if it's a user-config / chezmoi-managed file, the change is in `~/src/dots@rhombu5/` and committed + pushed.
- **`arch-setup`** — if it's a package install, service enable, or bootstrap-relevant tweak, mirrored into `~/src/arch-setup@fnrhombus/` and committed + pushed.

Verify with:

- `chezmoi diff` — empty output means dots is in sync with live.
- `git status` + `git log @{u}..` in both `dots` and `arch-setup`.
- For packages: spot-check that anything you `pacman -S`'d this session appears in the arch-setup package list.

⚠ = N/A on non-Linux.

## 12. Anything weird

- **No background shells still running.** Any process you started with `Bash(... run_in_background: true)` — and which is therefore still showing in the **status bar at the bottom of the user's window** — is a direct visual signal of unfinished work. The user should not see any active shell indicator when you wrap up. Either wait for it (if it's near completion), kill it (if its output is no longer needed), or — if it's load-bearing for the task — you're *not done*; keep working until it's finished or explicitly surface it as outstanding.
- Sudo state, env vars, or shell mutations that'd surprise the user's next session?
- Open editor windows / dialogs you spawned for testing?

## 13. Open bugs in the repo

**Only if the session touched code in a GitHub repo.** Otherwise ⚠ N/A.

`gh issue list --state open --label bug --limit 10` — any open bug-labeled issues? Two specific cases to flag:

- A bug that this session might have *introduced* (e.g., a refactor whose blast radius matches the bug report). Don't close out a session leaving a fresh bug you caused open.
- A bug that's been around but is closely adjacent to what this session changed (e.g., you refactored module X and there's an open bug about X's behavior). Worth surfacing as "you were here — want to look?", not silently moving on.

Don't audit every bug in the tracker — that's project health, not session wrap-up. Scope to bugs that touch the area this session worked in.

⚠ when bugs exist that might relate; ✓ when no related bugs (or none open); ⚠ N/A if the repo isn't a GitHub repo or doesn't use the `bug` label.

---

## Output shape

Report as a compact checklist:

```
 1. Task complete       ✓ feature shipped end-to-end
 2. Correctness gates   ✓ tsc + eslint + vitest all green
 3. Docs in sync        ⚠ README still shows old flag name
 4. Tasks / workitems   ✓ TaskList empty
 5. Secrets check       ✓ nothing sensitive in diff
 6. Committed           ✗ 2 untracked files in dots/
 7. Pushed              ✓ both repos up to date
 8. CI green            ⚠ CI still running on PR #42
 9. Orphans             ⚠ handoff.md still in arch-setup/ — delete?
10. Memory hygiene      ✓ saved one project memory; nothing stale
11. System parity       ✓ live ↔ dots ↔ arch-setup agree
12. Anything weird      ✓
13. Open bugs           ⚠ #77 might relate to today's restart work
```

Then list the ✗ / ⚠ items as concrete next actions, and ask the user how to proceed. Don't just fix them — the point of this skill is the *checkpoint*, not silent cleanup.
