# Tom's Claude Code rules

---

> # WHEN IN DOUBT — DISCUSS
>
> **If you are not certain about scope, intent, the right approach, or whether to take an action: stop and ask.** Don't guess. Don't proceed-and-hope. A clarifying question costs nothing; an unwanted edit, commit, push, refactor, or rewrite costs real work. This rule overrides every other instinct toward "just do it."

---

## Never guess

Don't fabricate a theory and act on it as if verified. If something load-bearing is unknown, **ask** — the *WHEN IN DOUBT — DISCUSS* rule above applies.

**Debugging exception:** forming a hypothesis and running a test to confirm or rule it out is the scientific method, not guessing. Theories-to-test are fine; theories-to-act-on are not.

### The 5-attempt loop

**5 attempts is a ceiling, not a quota.** Stop and research as soon as any of these fires — whichever comes first:

- **(a)** you hit the 5-attempt ceiling
- **(b)** you've exhausted what you can try without more information
- **(c)** you notice a knowledge gap that's keeping you from forming a credible attempt — this can fire *before any attempts*, when "I'm about to guess" is the honest description

Every failed attempt is "no progress" in the literal sense; that alone doesn't trigger research. It's the conditions above that do.

**The loop's escape hatch is new context.** Attempts should produce it — error messages, ruled-out hypotheses, observed behavior, related code paths. That new context fuels the next research phase. Each research phase must target what the new context points at specifically: a fresh error names a function to look up; a ruled-out hypothesis narrows the next search. Re-reading already-covered material without a specific pointer isn't research, it's spinning.

**The loop ends when** a round of attempts surfaces no new context, or the new context doesn't point at anything specific to investigate next.

When the loop ends, **give up**:
- **Inside a project:** write or append `blockers.md` at the project root — what you tried, what you learned, what you still don't know. Stop.
- **Outside a project / one-off task:** say so in the response, specifically where you got stuck.

---

When I say **"user prefs"**, I'm referring to *this* file (`~/.claude/CLAUDE.md`), the context-specific `CLAUDE.<context>.md` siblings indexed below, and any `CLAUDE.<context>.local.md` per-machine overrides alongside them.

## Context files

These files live alongside this one at `~/.claude/`. Pull in any `CLAUDE.<context>.local.md` sibling alongside the base file for per-machine overrides that aren't committed to the dotfiles repo.

- [`CLAUDE.linux.md`](CLAUDE.linux.md) — Arch package management, systemd units, FHS/XDG layout, sudo or polkit prompts (use `sudoa` for unattended, `sudonf` for interactive), Bitwarden / `bw` / `secret-tool` / keyring access (you can unlock the vault yourself — never ask the user), anything inside `/etc/` or `/usr/`, or the chezmoi-managed dotfiles workflow that backs `~/.config/`, `~/.local/`, etc.
- [`CLAUDE.git.md`](CLAUDE.git.md) — git operations (clone/push/PR), worktree creation/entry/exit, choosing where on disk a repo should live, or picking the GitHub owner for a new project.

**Loading is just-in-time and deterministic, not heuristic.** When your next tool call matches a trigger row below, `Read` the file before making the call. Once loaded for a session, it stays loaded — the same trigger won't re-fire. The table itself is part of *this* file, so it's already in your context — checking it costs nothing.

| Tool-call trigger | Load |
|---|---|
| You're about to edit a file inside a git repo (`Edit`/`Write`/`MultiEdit`/`NotebookEdit`), OR a `git`/`gh`/`git worktree`/branch-create/PR-open call is coming up | [`CLAUDE.git.md`](CLAUDE.git.md) |
| You're about to touch `/etc/`, `/usr/`, `sudo`, `pacman`/`yay`, `systemctl`, `chezmoi`, Bitwarden/`bw`/`secret-tool`, or do any of the other Arch/Linux-flavored work named in the index above | [`CLAUDE.linux.md`](CLAUDE.linux.md) |

**The trigger is the tool call's *shape*, not how you're framing the task.** "I'm writing some Go code" feels like one job; the moment the next call is going to `Edit` a file inside a git repo, the code-change work has started — load `CLAUDE.git.md` BEFORE that call, not after the PR is open.

**Authoring new context files.** Always create or edit them in the chezmoi source tree at `~/src/dots@rhombu5/home/dot_claude/CLAUDE.<context>.md` — never the live `~/.claude/` copies, since `chezmoi apply` will overwrite them — and run `chezmoi apply` after each change. When you add a new context file, also add a one-line entry to the index above with its trigger conditions so it's discoverable next session.

**Project `CLAUDE.md` files vs. user prefs.** Project `CLAUDE.md` is for project-specific rules — facts and conventions that only apply *here* and would surprise someone coming from a default setup. **Don't restate or paraphrase rules that already live in user prefs.** Don't author git/worktree workflows, commit-attribution rules, pre-commit-hook policy, or anything similar into project files. If a rule is global it belongs in user prefs; if it's a deviation or extension *I* asked for, that belongs in the project file with the deviation called out. When in doubt, leave the project file alone — duplication drifts, contradicts, and (as observed) actively overrides global rules at the call site.

**When user prefs and a project `CLAUDE.md` conflict, user prefs win.** Update the project file (remove or align the duplicate) rather than silently following the project's local recipe. The exception is when I've explicitly told you the project's behavior should override — say so out loud before acting.

## Don't attribute Claude in commits, issues, or PRs

Anything that ends up in a public artifact under my name — git commits, GitHub issues, GitHub PR titles/bodies/comments, code review comments — should not advertise that Claude wrote it. Specifically:

- **No `Co-Authored-By: Claude …` trailer in commit messages.** Commit as me (`fnrhombus` / Thomas Butler) without the bot trailer.
- **No `🤖 Generated with [Claude Code]` footer** in PR descriptions or issue bodies.
- **No "Claude here" / "as an AI" / "happy to" / "I'd love to" filler** in issue or PR text. Write the way I'd write — direct, technical, first-person.
- **Don't sign work as Claude** anywhere a human reader will see it.

Strip Claude attribution by default whenever you're writing something that'll be public and signed as me — I shouldn't have to repeat the rule.

## Commit discipline

- **Commit on task completion.** Never leave a finished task as uncommitted work.
- **Atomic commits** — one logical change per commit. If uncommitted changes span multiple tasks, split them (`git add -p` or path-scoped `git add`).
- **Hierarchy: task → feature.** A *task* is the smallest unit of work — one commit. A *feature* is one or more task commits that together deliver something coherent.
- **Push on feature completion.** All task commits for a feature land first, then push. No partial features in the remote unless I ask.

## All code edits happen in a worktree subagent — HARD RULE

**Default action for any code-change work**: dispatch as `Task` with `isolation: "worktree"`. The trigger is "I'm about to edit code in a project," not "I want to create a worktree." Being already on a branch in the main checkout is the **failure mode this rule prevents**, not a reason to skip it.

**Why**: keeps the parent session responsive (so I can interrupt or ask follow-ups while work runs), parallelises naturally when multiple changes are in flight, gives an atomic checkpoint that's decoupled from the main checkout's state, and matches the shape of work that subagents handle well. CLAUDE.git.md covers the mechanism — branch creation, path templating, post-merge cleanup; this section is the *policy* that makes the mechanism the default rather than an option.

**Opt-out repos (edit in main checkout, no worktree):**

- **`dots`** — chezmoi source has to stay aligned with the live HOME state being managed. A worktree's HEAD diverges from what `chezmoi apply` would compare against; editing chezmoi sources in a worktree breaks the parity loop.
- **`arch-setup`** — system-bootstrap repo whose scripts interact with the current machine. Same coupling to live state; worktree HEAD doesn't match the machine the scripts target.

**Other exceptions**: must be **explicit per-session instruction from me** ("just edit it here", "don't bother with a worktree for this one", or similar direct opt-out). Not "this feels small," not "I'm already in the main checkout," not "it's just one file." If you're choosing to skip the worktree without me having said to, you're doing the wrong thing — say so out loud before acting.

The pattern previously failed twice in one session (PR #68 + the e2e refactor PR #70 both edited in the main checkout); this rule exists to make the default loud and the exception explicit. See `[[feedback-loaded-not-applied]]` for the post-mortem.

## Plan for parallelism — always

Whenever you're about to do non-trivial work, decompose into parallel tracks and dispatch them concurrently. Default to maximum parallelism — multiple subagents on independent slices in a single message, parallel research/lookup calls, side-work in this thread alongside dispatched subagents.

The single exception: if running in parallel would make **total wall-clock time slower** — true sequential dependencies, or merge conflicts at integration that'd take longer to resolve than serialising would have. Serialise that pair; parallelise everything else.

**Wall-clock parity sub-exception (short tasks).** When each task in the set is short enough that serialising N items into one subagent finishes in roughly the same wall-clock as the slowest parallel item would have anyway, serialise. Firing 4 parallel subagents that each pay ~50K of cold-start framing for ~5 minutes of work — when one subagent could process all 4 serially in 6-8 minutes — trades quota for noise that wasn't moving the wall-clock needle. Rule of thumb: if a single subagent's total serial wall-clock is within ~5 minutes of the max-parallel wall-clock, prefer one. If each item is a 20+ minute task, the framing dilutes and parallel wins again.

The trigger isn't "is this big enough to need parallelism" — it's "is there any independent work I could be doing at the same time?" If yes, do it. Apply this in *planning*, not just at dispatch time: when laying out the next several steps, identify the parallelism shape first — what can run concurrently, what truly has to wait. Then fire the concurrent set in one message.

## Run `/getitdone` when you think you're done

Whenever you reach a point where you'd otherwise report a task as finished, **run `/getitdone` first**. It handles the obvious cleanup itself (commit/push, dots/arch-setup parity, orphan check) and reports only what's actually stuck — don't substitute your own end-of-task summary.

**The trigger is *response-terminal finality*** — a closing line like "Done.", "All set.", "Finished.", "Wrapped up.", "All green.", or any concluding phrase that effectively says "nothing more for me to do here." It fires **per task closure, not per session** — even if you already ran `/getitdone` earlier this session, the next wrap-up moment needs another one.

**Not a trigger**: "done" mid-thought ("I'm done reading the file, now I'll edit it"), referring to a sub-step that has more work after it, or future/conditional state ("when CI is done"). The signal is finality at the *end* of the message — the word in isolation doesn't fire it.

## Every Monitor needs a hard timeout + in-script wedge detection

This applies to *every* Monitor you launch, not just CI/PR watches. Two layers, both required:

1. **Harness `timeout_ms`** — the backstop. Cap the whole watch at something concrete (the tool's max is 60 min). Don't use `persistent: true` unless the watch is genuinely session-length AND you've also added wedge detection inside the script.
2. **In-script wedge detection** — the diagnostic. Track a `last_change` timestamp; if no state change has been observed for N minutes (10–15 is a reasonable default), emit a `WEDGE` line and exit non-zero. The harness timeout would also eventually fire, but in-script wedge detection trips sooner and gives me a clear "what's stuck" line instead of "watch silently ended."

Silence is not progress. A grep that only matches the happy path looks identical to "still running" when the job has crashloop'd. Cover failure/cancellation/timeout signatures explicitly in the same alternation. See also the `feedback_monitor_wedge_detection` project memory.

## Monitor every CI run and PR you push

When you push a branch, open a PR, or trigger a workflow that gates downstream automation (release-please, AUR publish, deploys), **arm a Monitor in the same turn** — don't open it and walk away.

- **Cover the full chain, not just the immediate run.** For fnclaude that means PR test → auto-merge → release-please PR → release-please merge → release.yml → AUR index → installable version. Each transition is a state change worth emitting. The monitor should end only when the *final* state is reached (installed/deployed), not at an intermediate "READY" marker.
- **Emit on every terminal state, not just success.** Failure, cancellation, `timed_out` — all should produce events.
- **PushNotification on outcomes that change what I'd do next** — a failed test on a PR I just opened, a wedge alert, the final installed/deployed signal. Routine in-progress status lines don't need a push.

If you discover mid-task that you should have been monitoring and weren't (e.g. you find a release already shipped while you were doing something else), say so plainly and start the Monitor immediately for whatever stage is still live.

## "How hard is X?" — frame the answer for *us*, not a solo human

When I ask how hard / how big / how long / how much work / what's the effort / how many turns / how many days/weeks / what would it take — or any other variant of "estimate this task" — account for the fact that I'm doing it *with you*. A bare "X days" in human-typing units mis-prices the work. Always include:

- **Turn count** — roughly how many prompt + tool-use round-trips
- **Context shape** — order-of-magnitude per turn; flag anything that'll burn cache hard (e.g. spelunking 200k of unfamiliar source)
- **Wall-clock total** — your work time *plus* my read/decide latency between turns
- **Risk surface** — irreversible ops, sudo, other-human-in-the-loop deps, anything that breaks the "Claude just does it" assumption

**Wrong shape:** "~1–2 weeks for a quality v1." **Right shape:** "~50–100 turns + half-a-day wall-clock + low risk; main risk is renderer scope creep." The bare-duration form is the failure mode this rule exists to prevent — always reach for the four-axis form instead.

To make the shape concrete: "rename a function across 30 files" is an hour solo, ~5 turns + 10 minutes with you. "Refactor the renderer to be per-monitor" is a day solo, ~40 turns + 3–4 hours with you once review time stacks up.

## Subagent model selection

**Right-size the model to the task.** Opus is the default for the main thread, but if a smaller model can do the work at the same or better quality with lower token cost, dispatch a subagent on that model. Don't burn opus on work a smaller model handles equivalently.

Concrete cases:

- **Prose-shaped work** — rewriting, summarizing, drafting docs / issues / PR bodies / commit messages / runbook entries / sections of `CLAUDE.md` itself, comparing wordings → **sonnet**, even when the user asked for it directly. Sonnet's prose is reliably tighter than opus's.
- **Mechanical / scripted work** — bulk renaming, simple refactors with a clear pattern, format conversion, straightforward file scans → **haiku** is often enough. Try it; if quality drops, escalate.

Substance, structure, and tricky design decisions stay on **opus** — only the *execution* gets handed off. Pattern: opus decides *what*, subagent does the *how*.

Subagent prompts should include the substance, the style/format constraints, and (where useful) pointers to sibling docs or files to mirror tone from. Return ready-to-drop-in output.

## Teams mode is on — `SendMessage` works mid-flight

`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set in my env and in `~/.claude/settings.json`. Subagents you spawn are teammates: `SendMessage(to: <agentId>, message: …)` delivers to a *running* agent at its next turn boundary, not only "after it completes."

**When you need to extend or correct a running agent's scope, try `SendMessage` before `TaskStop` + redispatch.** Killing throws away the agent's work-in-progress (context already built, files already read, code already drafted). Kill-and-redispatch is the *fallback* for when the scope change is incompatible with what's already been written — not the default.

The `SendMessage` tool's docstring still leans on "resume a completed background agent" framing in some forms — that's the non-teams default. With teams mode on, mid-flight delivery works; the tooling description hasn't caught up.

## Don't echo subagent return messages

When a subagent finishes, its final message is delivered to me directly as a task notification — I can read it. **Don't re-summarize it in your next response.** Echo-summaries are pure duplication: same content I just read, billed twice. Acknowledge completion in a single line ("PR #42 in flight" / "rejected — schema cost too high") and move to the next action, not a paragraph rephrasing what the subagent said.

Exception: if the subagent surfaced something genuinely action-shaped (a blocker, a critical finding, a request for direction), call that out explicitly so I don't miss it inside a routine-looking notification. Routine "done, here's the URL" reports stay as the task notification; your next message picks up from there.

## Disruptive testing requires explicit hands-off confirmation

Any time you're about to do testing that **interrupts what I'm doing** — switching workspaces, rearranging windows, moving the mouse or keyboard focus, sending input events, taking over the foreground — **tell me what you're going to do and wait for confirmation before beginning.** Don't bury the side effect in a "let me just check this" framing.

A purely visual change behind my work (e.g. a background-layer wallpaper surface, a system-tray icon) does *not* count — paint freely. Read-only inspection (querying state, reading files, running validators) also doesn't need confirmation. The bar is **"is it pulling my attention or my hands away from what I'm working on?"** — if yes, ask.

**Why this matters:** if you're testing window/workspace/input behaviour and I'm using the machine at the same time, my keystrokes and clicks contaminate your readings — you'll see state changes I caused, attribute them to your dispatch, and draw the wrong conclusion. Telling me to keep my hands off for the duration is the only way the test gives a clean signal. Don't skip the ask just because the change is small.

## Keep dev tooling project-local

> # NO SYSTEM-WIDE DEVTOOL INSTALLS
>
> **Hard rule.** Compilers, language runtimes, build runners, formatters, linters, and language package managers do **not** go in `/usr/`, `/opt/`, or any system-managed location. **Mise is the path** — per-project (`mise use <tool>@<ver>`), or `mise use --global` if a tool is genuinely cross-project. `cargo install`, `pip install --user`, `npm i -g`, `pacman -S <devtool>`, `yay -S <devtool>`, `brew install <devtool>` — all banned for devtools by default.

### What counts as a "devtool"

Things that build, lint, format, type-check, test, package, or run **your code**: `rust`, `go`, `node`, `python`, `ruby`, `java`, `dotnet`, their toolchain bins (`cargo`, `rustup`, `npm`, `pnpm`, `pip`, `poetry`, `gradle`, `maven`, `bundler`), and dev-time CLIs like `prettier`, `eslint`, `ruff`, `shellcheck`, `pre-commit`, `terraform`, `kubectl`, `helm`.

**Not** devtools: runtime system libs (graphics stack, libc, audio, kernel/compositor-bound bits), end-user CLI utilities (`fd`, `rg`, `bat`, `eza`, `jq`, `fzf`, `tldr`, etc.), and the system shell. Those are correctly system-installed.

### The transitive trap (yay / AUR)

AUR packages frequently declare `rust`, `go`, `npm`, `electron`, `gradle`, etc. as `makedepends`. **`yay -S <pkg>` will pacman-install those system-wide as a side effect and leave them after the build completes** — silently violating this rule.

**Always pass `--rmdeps` to `yay -S`.** It tells makepkg to uninstall build deps once the package itself is installed, leaving only the actual runtime dependencies. Without it, the global rule is broken every time an AUR package needs a compiler.

```sh
yay -S --rmdeps <pkg>     # good — orphans cleaned up automatically
yay -S <pkg>              # forbidden — leaves the compiler globally installed
```

Equivalent at the makepkg level: `makepkg -src` (`-r` removes build deps).

### Translating "install globally" instructions in a project

When something I'm following inside a project — a README, a tutorial, an agent's output, a build doc — calls for `npm i -g <pkg>` / `pnpm add -g <pkg>` / similar, **rewrite to `mise use npm:<pkg>` run from the project root.** That adds the tool to the project's `mise.toml` (creating one if absent), putting it on PATH only inside this directory — preserves the "make this tool available here" intent without spilling into global state. Works the same for pnpm-installable packages since both pull from the npm registry.

Use `mise use -g npm:<pkg>` only when the tool genuinely belongs across projects, not as the default. The escape hatch below still applies for cases where neither form works.

### Escape hatch — "the alternative is unacceptable"

There are real cases where system-wide is the only option:

- The tool only ships as a system package (no upstream binary release, no language registry version).
- The tool **is** a system component that happens to be devtool-shaped (`pkgconf`, `bash`, the system git you use for `cd`-time hooks).
- The per-project install would itself break something load-bearing (e.g. nested mise managing the same binary mise is shimming).

When you think the escape hatch applies, **say so out loud** before acting: *"X needs to go system-wide because Y — confirm?"* Wait for confirmation. Don't just `pacman -S` and explain in the summary.

### Why I care

Past project experiments leak forward. A system-wide `rust` installed five months ago as a build dep for Edge is still there, frozen at whatever version was current then, silently used by every project that doesn't pin its own. Mise gives per-project pinning that travels with the repo and has a clean uninstall path. System installs do neither.

## Project memory lives in `~/.claude/projects/`

Claude Code's auto-memory files belong at `~/.claude/projects/<encoded-cwd>/memory/` — the path Claude Code computes from the session's CWD. Write there directly; no symlinks, no per-repo bookkeeping.

**Don't put memory in `<project-root>/.claude/memory/`.** Earlier policy was to keep memory in-tree so it travelled with the repo. In practice that fragmented memory across many trees, required a per-machine symlink rebuild after every clone, and still didn't give cross-machine continuity (each machine had its own clone path). Cross-machine durability now comes from Dropbox-syncing `~/.claude/projects/`, not from in-tree storage.

**The project is still the project the work is about, not the CWD.** A session may start in one repo and end up doing work in another. Sort each memory file into the `~/.claude/projects/<encoded-cwd>/memory/` whose CWD matches the project it actually describes — not the launch directory. If a session is doing work on `dots` from a CWD inside `arch-setup`, write that memory under the dots-encoded path.

Stale `<project-root>/.claude/memory/` directories from the old policy should be migrated back to the home-dir path; existing `.gitignore` rules for `/.claude/memory/` can stay (harmless when the directory is absent).
