# noop landing zone

A deliberate "general questions only" directory for Claude Code sessions. `cclaude` with no positional path defaults into `~/.claude/noop/`, where an auto-loaded `CLAUDE.md` puts claude in **strict redirect mode**: it classifies each user prompt and either answers (general / read-shaped) or writes a handoff file and bounces the user into a project-rooted session (action).

## What it solves

Running bare `claude` from `$HOME` (or anywhere with files around) gives claude no clear signal that you're not working on a particular project. It'll tool-call against whatever it finds. The two failure modes:

- **General questions** ("how do I X?", "what's a Y?") don't need any project context, and Claude wandering through nearby repos to "look around" wastes context and the user's time.
- **Project work in the wrong cwd** produces half-baked output: missing the project's `CLAUDE.md`, missing project memory, missing the `.mcp.json` and `.claude/settings.json`, missing `--add-dir`s for cross-project work. The user feels the difference within three turns.

The noop dir makes the "no project here" signal explicit. The user sees they're in noop; claude reads the noop `CLAUDE.md` and behaves accordingly.

## How `cclaude` wires it

The `cclaude` function in [`home/dot_zsh_aliases`](../home/dot_zsh_aliases) — full reference: [`docs/cclaude.md`](cclaude.md) — has this default:

```sh
if (( ${#paths[@]} == 0 )); then
    paths=("$HOME/.claude/noop")
fi
```

So bare `cclaude` becomes `cclaude ~/.claude/noop` internally. cclaude `cd`s into noop (in a subshell) and exec's claude there. claude's auto-loaded `CLAUDE.md` is the noop one.

The user's pre-`cclaude` shell cwd is preserved across the subshell `cd` — when they `Ctrl+C` out of the noop session their shell returns to wherever they started. That's why the relaunch command must use absolute paths (see "Handoff bridge" below).

## The classifier

[`home/dot_claude/noop/CLAUDE.md`](../home/dot_claude/noop/CLAUDE.md) defines a three-bucket classifier that runs **before any tool call**:

| bucket | shape | claude's action |
|---|---|---|
| **A — GENERAL** | conceptual / how-to / one-off; no specific repo named | answer directly, no project tool calls |
| **B — READ-SHAPED PROJECT Q&A** | "what does X do in repo Y?", "where is Z defined?" — reading a repo to *answer*, not modify | answer here, with `Read` allowed (escalate after ~5 file reads) |
| **C — ACTION ON A PROJECT** | "fix X", "add Y", "run tests in Z" — the user wants the repo's state altered | write `handoff.md` in the project, tell the user to relaunch |

A bucket-B thread can shift to bucket C mid-conversation. The rule is to redirect at the *new* turn, not retroactively — the earlier read-only work was the right call when it happened.

The classifier also has a step-1 "if you can't classify with high confidence, ask" rule, applying the global *WHEN IN DOUBT — DISCUSS* posture.

## The handoff bridge

When claude classifies bucket C, it writes `<project-dir>/handoff.md` (template: [`home/dot_claude/noop/handoff.template.md`](../home/dot_claude/noop/handoff.template.md)) capturing the user's request, then gives a copy-pasteable command:

```
cclaude <project-dir-absolute-or-tilde-relative> -i @handoff.md
```

`-i @handoff.md` makes claude load the handoff as the initial user message in the new session.

The handoff's HTML-comment header instructs the receiving claude that its **very first action** must be `rm handoff.md` — burn after reading. Don't `git add`, don't `git commit`, don't `git ignore` (gitignoring archives the problem instead of solving it). The handoff is single-use; the bridge ends with its deletion.

### Why two paths, two scopes

The relaunch command has two paths that resolve at different times:

- **`<project-dir>`** is shell-resolved at *paste time*, with the user's pre-`cclaude` shell cwd. That cwd could be anywhere. So `<project-dir>` MUST be absolute or `~`-anchored; never `./foo`, `../foo`, or bare `foo`. The `~` form is portable across Linux/macOS/Windows shells; native absolute paths (`/home/...`, `/Users/...`, `C:\Users\...`) work too if you're certain of the platform.
- **`@handoff.md`** is claude-resolved *after* `cclaude`'s `cd`, with cwd = `<project-dir>`. So it MUST stay literal `@handoff.md` — making it actually-relative-to-shell-cwd (`@./handoff.md`) only works if the user happens to paste from inside the project, which we can't assume.

## Files in this design

- [`home/dot_claude/noop/CLAUDE.md`](../home/dot_claude/noop/CLAUDE.md) — the classifier and behavior rules; auto-loaded when claude launches in `~/.claude/noop/`.
- [`home/dot_claude/noop/handoff.template.md`](../home/dot_claude/noop/handoff.template.md) — the mandatory handoff structure with the burn-after-reading header.
- [`home/dot_zsh_aliases`](../home/dot_zsh_aliases) — `cclaude` function (default-to-noop is in here).
- [`docs/cclaude.md`](cclaude.md) — full `cclaude` reference, including how `-i/--init` interacts with naked-prompt parsing.

## Why no hook-based enforcement

The strict-redirect rules are instruction discipline only. A `PreToolUse` hook *could* block project work from a noop session structurally, but the rule it would need to encode is fiddly: allow `Write` to handoff paths outside noop, allow `Read`/`Glob`/`Grep` everywhere (bucket B reads project files legitimately), block `Edit` and project-mutating `Bash`. Easy to get wrong, and the misclassification cost is low — five minutes of mis-rooted work is recoverable: write the handoff afterwards and relaunch.

If the discipline measurably fails in practice, that's the moment to write the hook, with the actual failure pattern as the spec.
