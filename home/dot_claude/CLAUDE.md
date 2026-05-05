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

When I say **"user prefs"**, I'm referring to *this* file (`~/.claude/CLAUDE.md`) and the context-specific siblings indexed below.

## Context files

When the task touches a domain below, also `Read` the matching file from `~/.claude/`. Pull in any `CLAUDE.<context>.local.md` sibling alongside it — those carry per-machine overrides that aren't committed to the dotfiles repo.

- [`CLAUDE.linux.md`](CLAUDE.linux.md) — Arch/distro tooling: `sudonf` for fingerprint auth, three-layer reinstall reproducibility, FHS/XDG paths, chezmoi workflow.
- [`CLAUDE.git.md`](CLAUDE.git.md) — Git + GitHub: clone-path conventions, SSH-only remotes, GitHub owner/org choice.

**Load on context-shift.** When the task evolves into a domain whose context file hasn't been loaded yet (you started on Linux config and the user pivoted to TypeScript, etc.), `Read` the matching file *now* before continuing. Don't re-check the listing every turn — the index above is always in context, that's enough.

**Authoring new context files.** Always create or edit them in the chezmoi source tree at `~/src/dots@rhombu5/home/dot_claude/CLAUDE.<context>.md` — never the live `~/.claude/` copies, since `chezmoi apply` will overwrite them — and run `chezmoi apply` after each change. When you add a new context file, also add a one-line entry to the index above so it's discoverable next session.

## Don't attribute Claude in commits, issues, or PRs

Anything that ends up in a public artifact under my name — git commits, GitHub issues, GitHub PR titles/bodies/comments, code review comments — should not advertise that Claude wrote it. Specifically:

- **No `Co-Authored-By: Claude …` trailer in commit messages.** Commit as me (`fnrhombus` / Thomas Butler) without the bot trailer.
- **No `🤖 Generated with [Claude Code]` footer** in PR descriptions or issue bodies.
- **No "Claude here" / "as an AI" / "happy to" / "I'd love to" filler** in issue or PR text. Write the way I'd write — direct, technical, first-person.
- **Don't sign work as Claude** anywhere a human reader will see it.

Strip Claude attribution by default whenever you're writing something that'll be public and signed as me — I shouldn't have to repeat the rule.

## Subagent model selection

For prose-shaped subtasks (rewriting, summarizing, drafting docs, comparing wordings), dispatch **sonnet** subagents — its prose is reliably tighter than opus's. Use **opus** to sort out substance, structure, or tricky design decisions first if the task is complicated, then hand the prose execution to sonnet.

## Disruptive testing requires explicit hands-off confirmation

Any time you're about to do testing where I need to stay hands off — switching workspaces, rearranging windows, moving the mouse, sending input events, anything that visibly changes my screen or interrupts what I'm doing — **tell me what you're going to do and wait for confirmation before beginning.** Don't bury the side effect in a "let me just check this" framing. Read-only inspection (querying state, reading files, running validators) does not need confirmation. Anything that perturbs my live session does.

**Why this matters:** if you're testing window/workspace/input behaviour and I'm using the machine at the same time, my keystrokes and clicks contaminate your readings — you'll see state changes I caused, attribute them to your dispatch, and draw the wrong conclusion. Telling me to keep my hands off for the duration is the only way the test gives a clean signal. Don't skip the ask just because the change is small.

## Project memory lives in the project tree

When working inside a git repo, Claude's auto-memory files belong in `<project-root>/.claude/memory/`, not the per-session home-dir path (`~/.claude/projects/<encoded-cwd>/memory/`). Reasons:

- Memory travels with the repo across reinstalls, machines, and worktrees.
- Each repo's learnings stay scoped to that repo — no leakage from one project's gotchas into another project's session.
- The project-root path is stable; the home-dir path is encoded from the absolute CWD and breaks if the repo moves.

**The project is the project the work is about, not the CWD.** A session may start in one repo and end up doing work in another (e.g., started in `arch-setup` but the user asks for changes in `dots`). Sort each memory file into the `.claude/memory/` of the project it actually describes, not the launch directory. If a single memory genuinely spans projects, route it to the more affected one.

Claude Code's hardcoded home-dir path is reconciled with this via a **symlink**: `~/.claude/projects/<encoded-cwd>/memory` → `<project-root>/.claude/memory/`. Both paths resolve to the same files. The symlink itself is per-machine (lives under `~/.claude/`, not the repo); set it up after cloning a project on a new machine.

**Commit policy is per-repo:**
- **Public repos** (most things under `fnrhombus`): `.gitignore` `/.claude/memory/`. Memories often contain tenant IDs, internal endpoints, or other identifiers safer kept local.
- **Private repos** (most things under `rhombu5`): commit memory files. They're part of the project's institutional knowledge.

When in doubt, gitignore — easier to opt-in to commit later than to redact a public commit.
