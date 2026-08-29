# Tom's Claude Code rules

---

> # WHEN IN DOUBT — DISCUSS
>
> **If you are not certain about scope, intent, the right approach, or whether to take an action: stop and ask.** Don't guess. Don't proceed-and-hope. A clarifying question costs nothing; an unwanted edit, commit, push, refactor, or rewrite costs real work. This rule overrides every other instinct toward "just do it."

---

> # PREFER WHAT IS MOST CORRECT
>
> **Prefer what is most CORRECT, not what is quickest or easiest.** When approaches diverge, the deciding axis is correctness — the right abstraction, the right boundary, the design that will still be right later — not the shortest path to something that works. If the correct option costs more turns, more code, or more effort, that's the option. Don't reach for the expedient one and rationalize it; if you're choosing speed over correctness, say so out loud and let me decide.

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

**The loop's escape hatch is new context.** Attempts should produce it — error messages, ruled-out hypotheses, observed behavior, related code paths — which fuels the next research phase, targeted at what the new context points to specifically: a fresh error names a function to look up; a ruled-out hypothesis narrows the next search. Re-reading already-covered material without a specific pointer isn't research, it's spinning.

**The loop ends when** a round of attempts surfaces no new context, or the new context doesn't point at anything specific to investigate next.

When the loop ends, **give up**:
- **Inside a project:** write or append `blockers.md` at the project root — what you tried, what you learned, what you still don't know. Stop.
- **Outside a project / one-off task:** say so in the response, specifically where you got stuck.

---

## Explain code SIMPLY — always prose *and* code

When discussing code — a design, a mechanism, a trade-off, how something works — explain it **simply**: plain-language prose **plus** a small concrete code snippet, never prose alone. The prose says *what it does and why* in ordinary words; the code makes it concrete and checkable — any claim about a mechanism's behavior needs the few lines that show it.

Keep the code itself **legible**: one statement per line, never multiple lambdas stacked on one line, a named `function foo() { … }` over a terse `const foo = () => …` when illustrating. Favor the form that's easiest to follow, even when denser would "work."

---

When I say **"user prefs"**, I'm referring to *this* file (`~/.claude/CLAUDE.md`), the context-specific `CLAUDE.<context>.md` siblings indexed below, and any `CLAUDE.<context>.local.md` per-machine overrides alongside them.

## Reading my modality

How to weigh my phrasing when capturing requirements or deciding what's been ruled:

- **"it could …"** (and kin — "we could …", "maybe …", "alternatively …") — a proposal seeking
  feedback, or a seed idea for a brainstorm. Never capture it as a decision.
- **Affirmative verbs** — "it will …", "it should …", "X is …" — read as prescriptions/requirements.
- **"e.g."** reads as "for example" — illustrative, not exhaustive; the example itself is not
  prescribed, only the thing it illustrates.
- **"i.e."** reads as "in other words" — a restatement of the same content, never additional
  content.

## Context files

These files live alongside this one at `~/.claude/`. Pull in any `CLAUDE.<context>.local.md` sibling alongside the base file for per-machine overrides that aren't committed to the dotfiles repo.

- [`CLAUDE.linux.md`](CLAUDE.linux.md) — Arch package management, systemd units, FHS/XDG layout, sudo or polkit prompts (use `sudoa` for unattended, `sudonf` for interactive), Bitwarden / `bw` / `secret-tool` / keyring access (you can unlock the vault yourself — never ask the user), anything inside `/etc/` or `/usr/`, or the chezmoi-managed dotfiles workflow that backs `~/.config/`, `~/.local/`, etc.
- [`CLAUDE.git.md`](CLAUDE.git.md) — git operations (clone/push/PR), commit conventions (attribution, discipline, signing), worktree creation/entry/exit, choosing where on disk a repo should live, or picking the GitHub owner for a new project.
- [`CLAUDE.codestyle.md`](CLAUDE.codestyle.md) — all-languages code style: the reader-frames budget, what-not-how naming, one-sentence doc comments, accept-permissive/return-expressive, single-use-helper and DRY trade rules, ternary/literal shape.
- [`CLAUDE.codestyle.ts.md`](CLAUDE.codestyle.ts.md) — TypeScript code style — array type syntax, `Func` over lambda types, `#`-fields, truthiness, generators, iterator chains, variance, and more.
- [`CLAUDE.print.md`](CLAUDE.print.md) — printing: driving the HP network laser (`hp_m252dw`) via `lp`/CUPS, the Canon photo printer (incomplete stub), and booklet printing — including the rule that a markdown prints as a folded booklet by default, the imposition pipeline, duplex/fold settings, and wrap-around cover pages.
- [`CLAUDE.go.md`](CLAUDE.go.md) — Go toolchain pinning via mise, the ambient-`GOROOT` version-split failure mode, `GOTMPDIR`/`GOCACHE` placement rules, and the fresh-worktree `mise trust` gotcha.
- [`CLAUDE.workflow.md`](CLAUDE.workflow.md) — cache/token economy of orchestration: the prefix-cache model (per-turn `0.1×` read of the whole growing history, `1.25×` write of the new delta, TTL expiry), cache-hygiene levers (don't churn model/effort/prefix mid-task, compact at boundaries, rewind-not-compact), fan-out cost structure (base context duplicated per agent, thinking conserved only if partitioned), front-load-shared-diverge-late subagent prompt structure, and the design-debate pattern (research → frame slate → propose → iterated attack/rebut → judge) — the default shape for brainstorm/design workflows.

**Loading is just-in-time and deterministic, not heuristic.** When your next tool call matches a trigger row below, `Read` the file before making the call. Once loaded for a session, it stays loaded — the same trigger won't re-fire. The table itself is part of *this* file, so it's already in your context — checking it costs nothing.

| Tool-call trigger | Load |
|---|---|
| You're about to edit a file inside a git repo (`Edit`/`Write`/`MultiEdit`/`NotebookEdit`), OR a `git commit`/push/`gh`/worktree/branch-create/PR-open call is coming up | [`CLAUDE.git.md`](CLAUDE.git.md) |
| You're about to touch `/etc/`, `/usr/`, `sudo`, `pacman`/`yay`, `systemctl`, `chezmoi`, Bitwarden/`bw`/`secret-tool`, or do any of the other Arch/Linux-flavored work named in the index above | [`CLAUDE.linux.md`](CLAUDE.linux.md) |
| You're about to edit source code in ANY language (`Edit`/`Write`/`MultiEdit`/`NotebookEdit` on a code file) | [`CLAUDE.codestyle.md`](CLAUDE.codestyle.md) |
| You're about to edit a TypeScript/TSX file (`.ts`/`.tsx`) — `Edit`/`Write`/`MultiEdit`/`NotebookEdit` | [`CLAUDE.codestyle.ts.md`](CLAUDE.codestyle.ts.md) (with [`CLAUDE.codestyle.md`](CLAUDE.codestyle.md)) |
| You're about to print or drive CUPS (`lp`/`lpr`/`lpstat`/`lpoptions`/`cancel`), or the user asks to print a document — especially a markdown or PDF (which prints as a folded booklet by default) | [`CLAUDE.print.md`](CLAUDE.print.md) |
| You're about to edit a `.go` file, run any `go` command (`build`/`test`/`vet`/`mod`), pin Go in a project's `mise.toml`, or debug a Go toolchain/version/cache error | [`CLAUDE.go.md`](CLAUDE.go.md) |
| You're about to dispatch a parallel subagent fan-out or a `Workflow`, OR switch model/effort mid-session (`fnc_set_model`/`fnc_set_effort`/`/fast`) — anything that multiplies base context or busts a cache layer | [`CLAUDE.workflow.md`](CLAUDE.workflow.md) |

**The trigger is the tool call's *shape*, not how you're framing the task.** "I'm writing some Go code" feels like one job; the moment the next call is going to `Edit` a file inside a git repo, the code-change work has started — load `CLAUDE.git.md` BEFORE that call, not after the PR is open.

**Context-file naming scheme.** Kind-first: `CLAUDE.codestyle.md` is the all-languages style root, `CLAUDE.codestyle.<ext>.md` a per-language style leaf (loaded with the root), and `CLAUDE.<ext>.md` a language's non-codestyle context (toolchain, caches — `CLAUDE.go.md` is the exemplar). Leaves are minted lazily, only when real content exists — never as blank placeholders.

**Authoring new context files.** Always create or edit them in the chezmoi source tree at `~/src/dots@rhombu5/home/dot_claude/CLAUDE.<context>.md` — never the live `~/.claude/` copies, since `chezmoi apply` will overwrite them — and run `chezmoi apply` after each change. When you add a new context file, also add a one-line entry to the index above with its trigger conditions so it's discoverable next session.

**Project `CLAUDE.md` files vs. user prefs.** Project `CLAUDE.md` is for project-specific rules — facts/conventions that only apply *here* and would surprise someone coming from a default setup. **Don't restate or paraphrase rules already in user prefs** — no git/worktree workflows, commit-attribution rules, pre-commit-hook policy, or similar in project files. A global rule belongs in user prefs; a deviation or extension *I* asked for belongs in the project file with the deviation called out. When in doubt, leave the project file alone — duplication drifts, contradicts, and (as observed) actively overrides global rules at the call site.

**When user prefs and a project `CLAUDE.md` conflict, user prefs win.** Update the project file (remove or align the duplicate) rather than silently following the project's local recipe. The exception is when I've explicitly told you the project's behavior should override — say so out loud before acting.

## All code edits happen in a worktree — HARD RULE

**Default action for any code-change work**: the edit happens in a templated worktree. Trigger: "I'm about to edit code in a project," not "I want to create a worktree." Being already on a branch in the main checkout is the failure mode this rule prevents, not a reason to skip it.

> **To put *yourself* into a worktree, use the `EnterWorktree` tool — never `cd` into one** (`cd <worktree>` or `cd <worktree> && cmd`). Categorical tool rule, not a path-style preference — `cd` into non-worktree directories is fine. `git worktree add` to *prepare* a worktree for a subagent to enter is the supported path — that's creating one, not entering it yourself. Mechanics: `CLAUDE.git.md` §"Entering / exiting worktrees".

**Two ways to satisfy the rule, picked by change size:**

- **Trivial (≤~10 LOC — version bump, flag flip, single-key config change):** `EnterWorktree` in the parent session, edit, commit, push, PR, `ExitWorktree`. No subagent — the dispatch framing cost doesn't amortize for a five-second change.
- **Anything larger:** parent creates the worktree first with a chosen branch name, dispatches a subagent **without** `isolation: "worktree"`, agent `cd`s there as its first action. Branch on origin reads `feat-renderer-merge` / `fix-cli-foo` — never `agent-<id>`.

Concrete commands, branch-naming, and the EnterWorktree workflow live in `CLAUDE.git.md`'s "Worktree mechanics" section.

**`isolation: "worktree"` is banned for code-change subagents.** Structural problems: the hook auto-generates an `agent-<id>` workspace name (becomes the branch on origin), the parent can't inject the worktree path into the prompt since it doesn't exist yet, and the agent falls back to the repo path given — the main checkout. Observed in fnclaude@fnclaude: parallel `pr-bound-coder`s dispatched this way leaked into the main checkout. See `[[feedback-pr-bound-coder-worktree-path]]`.

`isolation: "worktree"` *is* acceptable for genuinely ephemeral, no-write exploration — the auto-cleanup-if-no-changes behavior is useful there. If a "research-only" agent ends up writing, it's code-change work and the rules above apply; most research-only agents don't need a worktree at all.

**Why subagent-in-worktree at all**: keeps the parent session responsive (interrupt/follow-up while work runs), parallelises naturally across concurrent changes, gives an atomic checkpoint decoupled from the main checkout's state, and matches the shape of work subagents handle well.

**Opt-out repos (edit in main checkout, no worktree):**

- **`dots`** — chezmoi source must stay aligned with live HOME state; a worktree's HEAD diverges from what `chezmoi apply` compares against, breaking the parity loop.
- **`arch-setup`** — system-bootstrap repo whose scripts interact with the current machine; same live-state coupling.

**Other exceptions**: must be **explicit per-session instruction from me** ("just edit it here", "don't bother with a worktree for this one"). Not "this feels small," not "I'm already in the main checkout," not "it's just one file." Skipping the worktree without that instruction is wrong — say so out loud before acting.

See `[[feedback-loaded-not-applied]]` for the post-mortem on skipping this rule.

## Plan for parallelism — optimize hard, always, for ASAP

**The goal is wall-clock ASAP — optimize parallelism hard for it.** Whenever you're about to do non-trivial work, decompose into parallel tracks and dispatch them concurrently by default: multiple subagents on independent slices in a single message, parallel research/lookup calls, side-work in this thread alongside dispatched subagents. Don't leave independent work sitting serialized when firing it concurrently gets to done sooner.

The single exception: if parallel would make **total wall-clock time slower** — true sequential dependencies, or merge conflicts at integration costlier than serialising. Serialise that pair; parallelise everything else.

**Wall-clock parity sub-exception (short tasks).** When each task is short enough that serialising N items into one subagent finishes in roughly the same wall-clock as the slowest parallel item would anyway, serialise. Firing 4 parallel subagents each paying ~50K cold-start framing for ~5 minutes of work — when one subagent could do all 4 serially in 6-8 minutes — trades quota for no wall-clock gain. Rule of thumb: prefer one subagent if its total serial wall-clock is within ~5 minutes of the max-parallel wall-clock; past 20+ minutes per item, the framing dilutes and parallel wins again.

The trigger isn't "is this big enough" — it's "is there any independent work I could be doing at the same time?" If yes, do it. Apply this in *planning*: when laying out next steps, identify the parallelism shape first, then fire the concurrent set in one message.

## Default to ultracode for non-trivial coding tasks

Treat non-trivial coding work as a standing opt-in to multi-agent orchestration (the `Workflow` tool, i.e. "ultracode") — don't wait for me to type the keyword each time. Trivial edits (single-file, mechanical, ≤~10 LOC — the same bar as the worktree trivial-edit carve-out above) don't need it; use plain tool calls or a lone subagent instead. Load [`CLAUDE.workflow.md`](CLAUDE.workflow.md) first, same as any other `Workflow` dispatch, for the cache/fan-out cost model.

If ultracode feels wrong for a specific task — the work doesn't decompose into independent slices, a single focused agent would clearly beat orchestration overhead, or something else makes it a bad fit — say so out loud and proceed as you see fit instead. This is a default, not a mandate; don't force orchestration onto work that doesn't have the shape for it.

## Run `/getitdone` when you think you're done

Whenever you'd otherwise report a task as finished, **run `/getitdone` first**. It handles the obvious cleanup itself (commit/push, dots/arch-setup parity, orphan check) and reports only what's actually stuck — don't substitute your own end-of-task summary.

**Trigger: response-terminal finality** — a closing line like "Done.", "All set.", "Finished.", "Wrapped up.", "All green.", or any phrase that says "nothing more for me to do here." Fires **per task closure, not per session** — even if you ran `/getitdone` earlier, the next wrap-up moment needs another one.

**Not a trigger**: "done" mid-thought ("I'm done reading the file, now I'll edit it"), a sub-step with more work after it, or future/conditional state ("when CI is done"). The signal is finality at the *end* of the message.

## Every Monitor needs a hard timeout + in-script wedge detection

Applies to *every* Monitor, not just CI/PR watches. Two required layers:

1. **Harness `timeout_ms`** — the backstop. Cap the whole watch at something concrete (tool max: 60 min). Don't use `persistent: true` unless the watch is genuinely session-length AND wedge detection is also added inside the script.
2. **In-script wedge detection** — the diagnostic. Track a `last_change` timestamp; if no state change for N minutes (10–15 default), emit a `WEDGE` line and exit non-zero. The harness timeout also eventually fires, but in-script detection trips sooner with a clear "what's stuck" line instead of "watch silently ended."

Silence is not progress — a grep matching only the happy path looks identical to "still running" when the job crashloop'd. Cover failure/cancellation/timeout signatures explicitly in the same alternation. See also the `feedback_monitor_wedge_detection` project memory.

## Monitor every CI run and PR you push

When you push a branch, open a PR, or trigger a workflow gating downstream automation (release-please, AUR publish, deploys), **arm a Monitor in the same turn** — don't open it and walk away.

- **Cover the full chain, not just the immediate run.** E.g. an AUR-published CLI's chain: PR test → auto-merge → release-please PR → release-please merge → release workflow → AUR index → installable version. Each transition is a state change worth emitting; the monitor ends only at the *final* state (installed/deployed), not an intermediate "READY" marker.
- **Emit on every terminal state, not just success** — failure, cancellation, `timed_out` all produce events.
- **PushNotification on outcomes that change what I'd do next** — a failed test on a PR I just opened, a wedge alert, the final installed/deployed signal. Routine in-progress status lines don't need a push.

If you discover mid-task that you should have been monitoring and weren't, say so plainly and start the Monitor immediately for whatever stage is still live.

## "How hard is X?" — frame the answer for *us*, not a solo human

When I ask how hard / how big / how long / how much work / what's the effort / how many turns / how many days/weeks / what would it take — account for the fact that I'm doing it *with you*; a bare "X days" in human-typing units mis-prices the work. Always include:

- **Turn count** — roughly how many prompt + tool-use round-trips
- **Context shape** — order-of-magnitude per turn; flag anything that'll burn cache hard (e.g. spelunking 200k of unfamiliar source)
- **Wall-clock total** — your work time *plus* my read/decide latency between turns
- **Risk surface** — irreversible ops, sudo, other-human-in-the-loop deps, anything that breaks the "Claude just does it" assumption

**Wrong shape:** "~1–2 weeks for a quality v1." **Right shape:** "~50–100 turns + half-a-day wall-clock + low risk; main risk is renderer scope creep." Always reach for the four-axis form.

Concrete: "rename a function across 30 files" is an hour solo, ~5 turns + 10 minutes with you. "Refactor the renderer to be per-monitor" is a day solo, ~40 turns + 3–4 hours with you once review stacks up.

## Be as token-efficient as possible

**A standing default, not a per-request ask.** The biggest lever: delegate work you'd otherwise do inline on the main (opus) thread to a subagent, so it runs on a cheaper model/lower effort and its context stays out of the main window. The trigger isn't only "this is big" or "this parallelizes" — it's also **"a cheaper tier could do this slice at equal quality."** Hand it off even if you weren't otherwise going to; the saving is itself the reason to delegate. Don't pay opus rates for work sonnet/haiku clears. (Cost structure and per-stage tiering: [`CLAUDE.workflow.md`](CLAUDE.workflow.md).)

Tiering mechanics are in the next section.

## Subagent model selection

**Right-size the model to the task.** Opus is the default for the main thread; if a smaller model does the work at equal-or-better quality for less, dispatch it there instead.

Concrete cases:

- **Prose-shaped work** — rewriting, summarizing, drafting docs / issues / PR bodies / commit messages / runbook entries / sections of `CLAUDE.md`, comparing wordings → **always dispatch a sonnet subagent**, unless I've explicitly told you otherwise this turn. Sonnet's prose is reliably tighter than opus's. Escape hatch: an instruction like "do this on opus" or "don't delegate this one" — not the request merely being addressed to me.
- **Mechanical / scripted work** — bulk renaming, simple refactors with a clear pattern, format conversion, straightforward file scans → **haiku** is often enough. Try it; escalate if quality drops.
- **Reasoning effort is a second dial, orthogonal to model.** Turn it down for rote mechanical stages, reserve high/max for genuinely hard verify/judge/design steps — effort multiplies output tokens (the `~5×` kind), so low-effort haiku on a rote task is the cheapest cell in the grid.
- **Fable is governed by one invariant: the quota must NOT run dry.** A tier orthogonal to the three above. An autonomous dispatch clears in either of two ways: a stated, extremely strong task justification, or clear quota surplus — the burndown test in `CLAUDE.workflow.md` § "Fable usage" (keep the yellow above the white). Clear surplus justifies the spend on its own, since unused quota expires at reset; tight headroom vetoes regardless of task merit. The quota check isn't `get_usage` (no Fable bucket there) — workflow.md has the real mechanism. A Fable *orchestrator's* own window is Fable spend too: on a Fable main thread, delegate reads/code/prose to cheaper tiers and keep the window lean. When I name `@cheap-fable` explicitly, that's always fine regardless of quota — the gate is only on your own autonomous choice to reach for it.

Substance, structure, and tricky design decisions stay on **opus** — only *execution* gets handed off: opus decides *what*, the subagent does the *how*.

Subagent prompts should include the substance, style/format constraints, and pointers to sibling docs/files to mirror tone from. Return ready-to-drop-in output.

## Teams mode is on — `SendMessage` works mid-flight

`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set in my env and in `~/.claude/settings.json`. Subagents you spawn are teammates: `SendMessage(to: <agentId>, message: …)` delivers to a *running* agent at its next turn boundary, not only after it completes.

**To extend or correct a running agent's scope, try `SendMessage` before `TaskStop` + redispatch.** Killing throws away work-in-progress (context built, files read, code drafted); kill-and-redispatch is the fallback only when the scope change is incompatible with what's already written.

The `SendMessage` tool's docstring still leans on "resume a completed background agent" framing — that's the non-teams default. With teams mode on, mid-flight delivery works; the tooling description hasn't caught up.

## Subagents always run silent

**Every subagent prompt must include a run-silent directive** — no narration, no progress prose, no explanations between tool calls; tools and a terse final report only. This goes in the dispatch prompt itself (e.g. a first line like "RUN SILENT: no narration; terse final report only"), every time, for every agent type and model. Narrating agents burn tokens describing work instead of doing it.

## Don't echo subagent return messages

A subagent's final message is delivered to me directly as a task notification — I can read it. **Don't re-summarize it.** Echo-summaries are pure duplication, billed twice. Acknowledge in one line ("PR #42 in flight" / "rejected — schema cost too high") and move on.

Exception: if the subagent surfaced something action-shaped (a blocker, a critical finding, a request for direction), call it out explicitly so I don't miss it inside a routine-looking notification.

## Say what an issue/PR number *is* on first mention

A bare `#123` in isolation is meaningless to me. In **every response**, the first time you cite an issue or PR number, pair it with a few words of what it *is* (e.g. `#180 — the config.json-agnostic consideration`). After that first identification *within the same response*, the bare number is fine to reuse. The requirement resets each response.

**For a worktree expected to eventually merge, get the PR number up front.** Open the draft PR at worktree creation — per `CLAUDE.git.md`'s "open a draft PR immediately" rule — rather than waiting until the work is done, so there's a real number to cite from the first response that touches the branch.

## Disruptive testing requires explicit hands-off confirmation

Any time you're about to do testing that **interrupts what I'm doing** — switching workspaces, rearranging windows, moving mouse/keyboard focus, sending input events, taking over the foreground — **tell me first and wait for confirmation.** Don't bury the side effect in a "let me just check this" framing.

A purely visual change behind my work (e.g. a background wallpaper surface, a tray icon) doesn't count — paint freely. Read-only inspection (querying state, reading files, running validators) also doesn't need confirmation. Bar: **is it pulling my attention or hands away from what I'm working on?** If yes, ask.

**Why:** if I'm using the machine while you test window/workspace/input behavior, my keystrokes and clicks contaminate your readings — you'll misattribute state changes I caused. Keeping my hands off is the only way the test gives a clean signal. Don't skip the ask because the change is small.

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

When something I'm following inside a project — README, tutorial, agent output, build doc — calls for `npm i -g <pkg>` / `pnpm add -g <pkg>` / similar, **rewrite to `mise use npm:<pkg>` run from the project root.** Adds the tool to the project's `mise.toml` (creating one if absent), on PATH only inside this directory — same for pnpm-installable packages (both pull from the npm registry).

Use `mise use -g npm:<pkg>` only when the tool genuinely belongs across projects. The escape hatch below still applies where neither form works.

### When *I* name a package manager, it's shorthand — translate silently

If *I* say "install X with npm" (or pip, cargo, pnpm, `go install`, etc.), treat the named manager as shorthand for "get this tool available," not a literal system-wide install instruction. Do it the mise way — `mise use [-g] <backend>:<pkg>` (per-project by default; `-g` only when genuinely cross-project) — and **just proceed: don't flag the conflict, don't ask, don't narrate the translation.** Generalizes past npm to any package manager I name. (The escape hatch below is the one exception still needing an out-loud confirm.)

### Escape hatch — "the alternative is unacceptable"

Real cases where system-wide is the only option:

- The tool only ships as a system package (no upstream binary release, no language registry version).
- The tool **is** a system component that happens to be devtool-shaped (`pkgconf`, `bash`, the system git used for `cd`-time hooks).
- The per-project install would itself break something load-bearing (e.g. nested mise managing the same binary mise is shimming).

When the escape hatch applies, **say so out loud** before acting: *"X needs to go system-wide because Y — confirm?"* Wait for confirmation. Don't just `pacman -S` and explain in the summary.

### Why I care

Past project experiments leak forward — a system-wide `rust` installed months ago as a build dep is still there, frozen at that version, silently used by every project that doesn't pin its own. Mise gives per-project pinning that travels with the repo and a clean uninstall path; system installs do neither.


## TEMPORARY: opus 5 vs 4.6 A/B — self-erases after the 2026-09-09 verdict

Owner directive 2026-08-27. Applies to EVERY session in every project, silently — woven into
normal work, no narration, no asking. Every trace (this block, the ledger) is removed by the
verdict session.

- **Self-assign the arm when authoring the dispatch — never dispatch bare `opus`.** Any opus-bound
  `Agent`/`Workflow` stage gets an explicit `claude-opus-4-6`/`claude-opus-5` id chosen at write
  time: alternate the two arms, balanced within each consecutive pair of opus dispatches this
  session makes, coin-flip (shell `$RANDOM`) deciding which arm leads each pair. The `PreToolUse`
  hook (`~/.claude/hooks/opus-ab-split.mjs`, wired into `~/.claude/settings.json`'s
  `hooks.PreToolUse`) tracks no arm state of its own — it's a logger plus a forgot-path reminder.
  An explicit id on `Workflow` always passes, silently, logged as-is. A bare `opus` on `Workflow`
  BLOCKS once per script signature with a short reminder of the self-assign scheme and the ledger
  duty; the identical script resubmitted unchanged passes through on the bare alias, logged
  `alias-passthrough`. A bare `opus` on `Agent` never blocks at all — the tool's `model` field is a
  fixed enum that can never carry an explicit id, so blocking would be pure friction; it just
  passes through, logged `alias-passthrough`. Known gap: a `scriptPath`-form `Workflow` call
  (script on disk, not inline) bypasses the hook entirely, untouched and unlogged — acceptable,
  since the ledger entry the orchestrator appends carries the model regardless. Every pass and
  block is logged to `~/.claude/opus-ab/assignments.jsonl`. Never let the experiment change how
  work is briefed, gated, or judged.
- **The ledger duty is triggered, not scheduled: log before you act on the result.** The arrival of
  an opus delegation's result IS the trigger — append its `~/.claude/opus-ab/ledger.jsonl` entry
  `{date, project, model, task, role: author|review|design, overengineering: [instances of making
  things harder than needed — especially satisfying requirements that weren't given: invented
  options or constraints, unrequested defensive branches, speculative generality], defects: [what
  later review/gates caught], notes: [retries, stalls, instruction-following], verdict: 1-5 vs
  the brief}` BEFORE consuming or acting on the report. Clean runs get logged too. At session wrap,
  verify every opus delegation this session made has its line.
- **Verdict**: the FIRST session running at or after 2026-09-09 22:00 local — after confirming
  this block still exists (absence = another session already delivered) — judges via a
  single-agent `Workflow` on model `fable`, effort `xhigh` (`max` if the ledger is large or
  contentious), handing it the complete ledger, and presents the owner a recommendation on
  hard-switching all workflows to opus 4.6, with the evidence. THEN, same session: delete this
  block from `~/src/dots@rhombu5/home/dot_claude/CLAUDE.md`, `chezmoi apply`, commit the removal,
  remove the hook script (`~/.claude/hooks/opus-ab-split.mjs`) and its `hooks.PreToolUse` entry
  from `~/.claude/settings.json`, `rm -rf ~/.claude/opus-ab/`, and trim the experiment paragraph
  (only) from the std@fnioc memory file `feedback-opus5-overengineers.md`.
