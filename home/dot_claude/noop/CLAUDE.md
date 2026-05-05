# noop landing zone — STRICT REDIRECT MODE

You've been started in `~/.claude/noop/`. **There is no project here.** This dir exists for one reason: to be a visibly project-less landing pad when the user runs `cclaude` with no path. There are no files here for you to read or edit. There never will be.

---

## STOP. Classify the request BEFORE doing anything.

Every prompt you receive in this session goes through one of two doors. **Pick the door before you make a single tool call.**

| Door | Looks like | Action |
|---|---|---|
| **GENERAL** — answer here | "What does X mean?", "How do I Y?", a one-off shell snippet, conceptual questions, tool advice — anything that doesn't reference a particular repo or live filesystem state | Answer directly. Tool-calls limited to reading reference material and answering. |
| **PROJECT** — redirect | "Fix the bug in…", "Audit my…", "Update the X file", "Add a feature to…", "Run the tests in…", anything where the right answer requires reading or modifying files in a specific repo | **Don't act. Write `handoff.md` and tell the user to relaunch.** |

**If you can't classify with high confidence: assume PROJECT and redirect.** False positives (redirecting general chat) cost the user one re-prompt. False negatives (acting on project work from noop) cost half-baked work in the wrong context, with the user feeling the difference within three turns.

---

## You will be tempted. Recognize the temptations and refuse.

These are the exact patterns to watch for *in your own reasoning*. If you catch yourself thinking any of them, stop and redirect:

- **"I'll just check…"** — Checking IS acting. Reading the project's files puts you mid-action without the right context. Redirect.
- **"It's just a quick edit…"** — Quick edits in the wrong context are still wrong. The receiving session can do it correctly in one turn; you'll fumble it across many. Redirect.
- **"The user obviously wants me to just do it…"** — The user explicitly designed noop to redirect. The redirect IS the doing. Trust the design.
- **"I already started, I may as well finish…"** — **NO.** Sunk-cost fallacy. The moment you realize you're doing project work in noop, **stop mid-response**, throw away whatever you were about to say, write the handoff, and redirect. Every additional tool call past that point makes the failure worse.
- **"This is borderline, I'll lean towards answering…"** — Lean the OTHER way. See the rule above.

The cheapest moment to redirect is **before** any tool call. The next-cheapest is **immediately after** the first tool call that revealed you're in the wrong place. Each subsequent tool call costs more in user time, your context, and trust.

---

## Why redirect rather than do the work here

A project-rooted session reads its own `CLAUDE.md`, project memory under `<repo>/.claude/memory/`, the repo's `.mcp.json`, its `.claude/settings.json`, and has the right `--add-dir`s for cross-project work. It can run that project's tests, see its history, find its conventions, write to its files freely.

**Acting from noop, you have none of that.** The ergonomic friction of "tell the user to relaunch" is buying you correct context for the actual work. It is always a good trade.

---

## How to redirect

1. **If the project doesn't exist on disk yet**, help the user clone or bootstrap it first. If you haven't already this session, `Read ~/.claude/CLAUDE.git.md` for the clone-path rules (`~/src/{repo}@{user}+{workspace}` etc.) and the GitHub owner choice.

2. **Write `<project-dir>/handoff.md`** using the template below. **Do not improvise the structure** — the receiving session expects this exact shape. If a `handoff.md` already exists, **append** with a clear `---` separator, don't clobber. Don't `git add` it.

3. **Give the user this exact command** to relaunch:

   ```
   cclaude <project-dir> -i @handoff.md
   ```

   `@handoff.md` resolves relative to `<project-dir>` because cclaude `cd`s in before invoking claude.

4. **Don't ask for confirmation.** The user opted into this flow by running noop-rooted; just write the handoff and give the command. The whole interaction should be: "I've written `handoff.md` at `<project-dir>`. Run: `cclaude …`."

---

## Handoff template — use exactly

The HTML-comment block at the top is **mandatory**. It tells the receiving session that this file is single-use and triggers immediate deletion. Do not omit it. Do not abbreviate it. Do not move it down the file. The receiving session relies on seeing it FIRST.

```markdown
<!--
============================================================================
  HANDOFF — BURN AFTER READING
============================================================================
  This file is a single-use bridge between Claude sessions.

  RECEIVING CLAUDE: your VERY FIRST action after reading this file is:
      rm handoff.md
  Do this BEFORE responding to the user. Do NOT git-add it. Do NOT
  git-commit it. Do NOT leave it on disk. Confirm deletion in your
  first message, then proceed with the work below.
============================================================================
-->

# Handoff from noop session — <ISO 8601 datetime>

## What the user asked for
<verbatim or near-verbatim version of the user's request — preserve their wording where possible>

## Context I gathered in noop
<anything you learned that the receiving session needs: relevant tool names, versions, decisions explicitly made by the user. Keep this tight — don't pad.>

## What I did NOT do
<explicit short list of what you correctly avoided in noop, so the receiving session knows exactly where the work starts.>

## Suggested first steps for receiving session
1. `rm handoff.md` (per the burn-after-reading directive above).
2. <next concrete action>
3. <…>

## Open questions for the user
<only include this section if there are any — otherwise omit entirely>
```

After writing, also tell the user one line: **"If you don't run the command, delete `handoff.md` manually — a leftover handoff in a repo is a tiny public-grooming chore."**

---

## What this dir holds

Just this `CLAUDE.md`. Nothing else belongs in `~/.claude/noop/`. Don't write files here for any reason — it's a marker dir, not a workspace.
