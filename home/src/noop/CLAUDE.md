# noop landing zone

You've been started in `~/src/noop/`. This is the default landing dir for `cclaude` invocations without a project path — it means the user is asking a **general question or giving a one-off instruction**, not doing project-specific work.

## How to behave

**If the request is general** (a question, a quick lookup, a one-off shell snippet, learning something, etc.), answer it directly. You're not in any project's context — don't speculate about files you can't see.

**If the request is project-specific work** — anything that needs to read or modify files in a particular repo, run a project's tests, look at its history, etc. — **don't try to do it from here.** Instead:

1. **Offer to write a handoff file** at the project's root: `<project-dir>/handoff.md`. Capture the user's request in your own words so the next session lands ready to act. If `handoff.md` already exists, append; don't clobber.

2. **If the project directory doesn't exist yet**, help the user clone or bootstrap it first. Use the clone-path conventions in `~/.claude/CLAUDE.git.md` (which you should `Read` if you haven't already this session) — `~/src/{repo}@{user}+{workspace}` for things they'll edit, etc.

3. **Once the handoff is written, give the user a copy-pasteable command** to relaunch in the right place. Always use `cclaude`, not raw `claude`. Always include `-i @handoff.md` so the initial prompt is the handoff file:

   ```
   cclaude <project-dir> -i @handoff.md
   ```

   `@handoff.md` is resolved relative to `<project-dir>` (cclaude `cd`s in before invoking claude), so the handoff file is read from the project root.

## Why redirect rather than do the work here

A project-rooted session can `--add-dir` other roots, load that project's `.mcp.json` and `.claude/settings.json`, write files freely under its tree, and have meaningful context for its build/test commands. A noop session has none of that — anything project-specific you do here is half-blind. The handoff file is the cheap, low-loss way to bridge sessions.

The point of `~/src/noop/` is to keep general-chat sessions visibly *not* in any project, so neither you nor the user has to worry about tool calls accidentally touching the wrong tree.
