# noop landing zone

A deliberate "general questions only" directory for Claude Code sessions. `fnclaude` (alias `fnc`) with no positional path defaults into `$XDG_CONFIG_HOME/fnclaude/noop/` (typically `~/.config/fnclaude/noop/`), where an auto-loaded `CLAUDE.md` puts claude in **strict redirect mode**: it classifies each user prompt and either answers (general / read-shaped) or writes a handoff file and bounces the user into a project-rooted session (action).

## What it solves

Running bare `claude` from `$HOME` (or anywhere with files around) gives claude no clear signal that you're not working on a particular project. It'll tool-call against whatever it finds. The two failure modes:

- **General questions** ("how do I X?", "what's a Y?") don't need any project context, and Claude wandering through nearby repos to "look around" wastes context and the user's time.
- **Project work in the wrong cwd** produces half-baked output: missing the project's `CLAUDE.md`, missing project memory, missing the `.mcp.json` and `.claude/settings.json`, missing `--add-dir`s for cross-project work. The user feels the difference within three turns.

The noop dir makes the "no project here" signal explicit. The user sees they're in noop; claude reads the noop `CLAUDE.md` and behaves accordingly.

## How `fnclaude` wires it

`fnclaude` resolves the noop dir internally — bare `fnc` becomes `fnc $XDG_CONFIG_HOME/fnclaude/noop` (with `~/.config` as the XDG fallback), then `cd`s in (in a subshell) and exec's claude there. claude's auto-loaded `CLAUDE.md` is the noop one.

The user's pre-`fnclaude` shell cwd is preserved across the subshell `cd` — when they `Ctrl+C Ctrl+C` out of the noop session their shell returns to wherever they started. That's why the relaunch command must use absolute paths (see "Handoff bridge" below).

### Base vs. overlay — ownership split

`fnclaude` embeds the base `CLAUDE.md` and `handoff.template.md` into the binary and lazy-seeds them into the noop dir on each launch that uses the fallback (writing only when the on-disk content differs from embedded, by SHA-256). That means:

- **`CLAUDE.md`** and **`handoff.template.md`** are **fnclaude's territory**, refreshed by each binary release. Direct edits self-heal on the next launch — don't bother. Upstream changes happen in the fnclaude repo's [`src/noop_templates/`](https://github.com/fnrhombus/fnclaude/tree/main/src/noop_templates).
- **`CLAUDE.local.md`** is the **user's territory** — fnclaude never touches it. This is where this dotfile setup keeps personalization (chezmoi-aware user-prefs editing, machine-specific clipboard, mirror conventions). chezmoi-managed at [`home/dot_config/fnclaude/noop/CLAUDE.local.md`](../home/dot_config/fnclaude/noop/CLAUDE.local.md).

Claude Code auto-loads both files when launching in the noop dir; the overlay's rules can extend or override the base's.

## The classifier

The base [`CLAUDE.md`](https://github.com/fnrhombus/fnclaude/blob/main/src/noop_templates/CLAUDE.md) defines a three-bucket classifier that runs **before any tool call**:

| bucket | shape | claude's action |
|---|---|---|
| **A — GENERAL** | conceptual / how-to / one-off; no specific repo named | answer directly, no project tool calls |
| **B — READ-SHAPED PROJECT Q&A** | "what does X do in repo Y?", "where is Z defined?" — reading a repo to *answer*, not modify | answer here, with `Read` allowed (escalate after ~5 file reads) |
| **C — ACTION ON A PROJECT** | "fix X", "add Y", "run tests in Z" — the user wants the repo's state altered | write `handoff.md` in the project, tell the user to relaunch |

A bucket-B thread can shift to bucket C mid-conversation. The rule is to redirect at the *new* turn, not retroactively — the earlier read-only work was the right call when it happened.

The classifier also has a "if you can't classify with high confidence at any step, ask" rule, applying the global *WHEN IN DOUBT — DISCUSS* posture.

**Two scoped exceptions to bucket C:**

1. **User-prefs maintenance** — edits to files under `~/.claude/` (user-level `CLAUDE.md`, its `CLAUDE.<context>.md` siblings, `settings.json`, and noop's own `CLAUDE.local.md` overlay and `handoff.template.md`) are allowed from noop. User prefs are cross-cutting — they belong to every session, not any one project — so a general-chat session is the natural scope. The base `CLAUDE.md` in this dir is **not** in scope (it's fnclaude-owned and read-only). The work flows through the chezmoi source at `~/src/dots@rhombu5/home/dot_claude/` (or `home/dot_config/fnclaude/noop/CLAUDE.local.md` for the overlay), then `chezmoi apply`, then atomic commit + push.
2. **One-off system changes** — installs, system-pref flips, service enables, single-line config snippets are allowed from noop with their mirror commit to `dots`/`arch-setup` done in the same noop session (vs. handing off to a project session). Multi-step refactors of those repos remain bucket C.

Other user-level state (`.zshrc`, hyprland configs, the rest of dotfiles) outside the two exceptions stays bucket C.

## The handoff bridge

When claude classifies bucket C, it writes `<project-dir>/handoff.md` (template: fnclaude-embedded [`handoff.template.md`](https://github.com/fnrhombus/fnclaude/blob/main/src/noop_templates/handoff.template.md)) capturing the user's request, then gives a copy-pasteable command:

```
fnclaude <project-dir-absolute-or-tilde-relative> --name <topic> @handoff.md
```

`@handoff.md` makes claude load the handoff as the initial user message in the new session. `--name` MUST come before `@handoff.md` — fnclaude treats leading non-flag args as paths until it hits the first `-`-prefixed token; putting `--name` first flips the parser into flag mode so `@handoff.md` correctly passes through to claude as the prompt.

The handoff's HTML-comment header instructs the receiving claude that its **very first action** must be `rm handoff.md` — burn after reading. Don't `git add`, don't `git commit`, don't `git ignore` (gitignoring archives the problem instead of solving it). The handoff is single-use; the bridge ends with its deletion.

### Why two paths, two scopes

The relaunch command has two paths that resolve at different times:

- **`<project-dir>`** is shell-resolved at *paste time*, with the user's pre-`fnclaude` shell cwd. That cwd could be anywhere. So `<project-dir>` MUST be absolute or `~`-anchored; never `./foo`, `../foo`, or bare `foo`. The `~` form is portable across Linux/macOS/Windows shells; native absolute paths (`/home/...`, `/Users/...`, `C:\Users\...`) work too if you're certain of the platform.
- **`@handoff.md`** is claude-resolved *after* `fnclaude`'s `cd`, with cwd = `<project-dir>`. So it MUST stay literal `@handoff.md` — making it actually-relative-to-shell-cwd (`@./handoff.md`) only works if the user happens to paste from inside the project, which we can't assume.

## Files in this design

- [`home/dot_config/fnclaude/noop/CLAUDE.local.md`](../home/dot_config/fnclaude/noop/CLAUDE.local.md) — this user's overlay; machine-specific guidance (chezmoi workflow, clipboard utility, sudo aliases, mirror conventions). chezmoi-managed; carved out of the global `**/*.local.md` ignore via a negation in `home/.chezmoiignore`.
- fnclaude's [`src/noop_templates/CLAUDE.md`](https://github.com/fnrhombus/fnclaude/blob/main/src/noop_templates/CLAUDE.md) — the read-only base classifier; lives in the fnclaude binary and is lazy-seeded into the noop dir on each launch.
- fnclaude's [`src/noop_templates/handoff.template.md`](https://github.com/fnrhombus/fnclaude/blob/main/src/noop_templates/handoff.template.md) — the mandatory handoff structure with the burn-after-reading header; also fnclaude-embedded.

## Why no hook-based enforcement

The strict-redirect rules are instruction discipline only. A `PreToolUse` hook *could* block project work from a noop session structurally, but the rule it would need to encode is fiddly: allow `Write` to handoff paths outside noop, allow `Read`/`Glob`/`Grep` everywhere (bucket B reads project files legitimately), block `Edit` and project-mutating `Bash`. Easy to get wrong, and the misclassification cost is low — five minutes of mis-rooted work is recoverable: write the handoff afterwards and relaunch.

If the discipline measurably fails in practice, that's the moment to write the hook, with the actual failure pattern as the spec.
