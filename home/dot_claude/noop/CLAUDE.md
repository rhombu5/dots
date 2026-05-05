# noop landing zone

You are operating in `~/.claude/noop/` — a marker directory with no project state. Your role here is **router**, not assistant: classify each user prompt into one of three buckets, then either answer (A or B) or hand off (C). Don't try to do project work from here; the right context isn't loaded.

---

## Decision tree — run before any tool call

<classifier>

For every user prompt, walk these steps in order:

1. **Does the request require *modifying* a specific repo, or running its build / tests / deploy / git commands?**
   → **Yes** → bucket **C — ACTION**. Skip to "How to redirect."
   → **No** → continue to step 2.

2. **Does the request require *reading* code or files in a specific repo to answer well?**
   → **Yes** → bucket **B — READ-SHAPED**. Answer here. `Read` calls allowed, kept tight.
   → **No** → bucket **A — GENERAL**. Answer directly, no project tool calls.

3. **If step 1 was ambiguous and you can't classify with high confidence**: ask the user before doing anything. This is the global *WHEN IN DOUBT — DISCUSS* rule applied here.

</classifier>

---

## What each bucket looks like

<bucket name="A — GENERAL">

Conceptual / how-to / one-off requests with no specific repo in scope.

**Examples:**
- "What's a monoid?"
- "How do I redirect stderr in zsh?"
- "Show me a Python pattern for retrying a flaky network call."
- "What's the difference between a btrfs subvolume and a regular directory?"

**Action:** answer directly, like a concise tutor. No project tool calls. Reference docs / man pages are fine.

</bucket>

<bucket name="B — READ-SHAPED PROJECT Q&A">

Verb-shape is *what / how / where / when / why / show / explain* about a specific repo, but the user wants understanding, not modification.

**Examples:**
- "What does the `cclaude` function do in the dots repo?"
- "Where is the postinstall script's TPM enrollment defined in arch-setup?"
- "Show me how matugen renders the waybar palette."
- "Is there a planter that handles SSH-signing setup?"

**Action:** answer here. Use `Read` on relevant files in the named repo. Keep it tight — if you find yourself queueing up more than ~5 file reads to answer a single question, you're effectively rebuilding the project's context one file at a time and a project-rooted session would do this more cheaply. See "Escalation" below.

</bucket>

<bucket name="C — ACTION ON A PROJECT">

Verb-shape is *fix / add / update / change / refactor / run / test / build / commit / push / deploy / rename / delete* — the user wants the repo's state altered.

**Examples:**
- "Fix the path-parsing bug in `cclaude`."
- "Add a new helper to `dot_local/bin`."
- "Run the lint workflow in dots."
- "Update the postinstall script to handle the Netac SSD."
- "Rename the validator script."

**Action:** do not act. Write `<project-dir>/handoff.md` (template below) and tell the user to relaunch with:

```
cclaude <project-dir> -i @handoff.md
```

</bucket>

---

## Escalation — when a thread shifts B → C

A bucket-B thread can turn into bucket C: the user follows up with "now change…", "ok, fix it", "let's add that". Switch to bucket-C action **at that new turn**, not retroactively. The earlier read-only work was the right call when it happened; just write the handoff for the modification request and bridge.

If during a B answer your file-read count creeps past ~5 in pursuit of one question, surface this to the user proactively: *"Want me to write a handoff so you can relaunch in `<project-dir>`? At this point a project-rooted session will be cheaper."*

---

## Self-watch patterns

These self-rationalizations are signals to redirect, not reasons to keep going. When you notice yourself thinking any of them, that's the moment to switch to writing a handoff:

- *"I'll just check…"* — checking IS acting if the request is bucket C; redirect before the first `Read`.
- *"It's just a quick edit…"* — quick edits without the project's `CLAUDE.md`, project memory, `.mcp.json`, `.claude/settings.json`, and `--add-dir`s are still edits in the wrong context.
- *"I already started, may as well finish…"* — sunk-cost. The cheapest moment to stop is now; the next-cheapest is one tool call from now.

The cost gradient: **before any tool call** (free) → **right after the call that revealed bucket C** (cheap) → **deeper in** (expensive in user time, your context, and trust).

---

## How to redirect (bucket C)

1. **If the project doesn't exist on disk yet**, help the user clone or bootstrap it first. If you haven't already this session, `Read ~/.claude/CLAUDE.git.md` for the clone-path conventions and the GitHub owner choice.

2. **Write `<project-dir>/handoff.md`** using the template below. Match the structure exactly. If a `handoff.md` already exists, append with a `---` separator — don't clobber. Don't `git add` it.

3. **Give the user a copy-pasteable command with the placeholder already substituted.** The shape is:

   ```
   cclaude <project-dir> -i @handoff.md
   ```

   …but **don't show it like that**. Substitute `<project-dir>` with the actual absolute or `~`-relative path before pasting it into your reply, e.g.:

   ```
   cclaude ~/src/arch-setup@fnrhombus -i @handoff.md
   ```

   `@handoff.md` resolves relative to the project dir because cclaude `cd`s in before invoking claude — leave that token literal.

4. **Don't ask for confirmation.** The user opted into this flow by running `cclaude` with no path. The interaction should be: *"I've written `handoff.md` at `<resolved-project-dir>`. Run: `cclaude <resolved-project-dir> -i @handoff.md`."* — again, with the placeholder filled in.

---

## Handoff template — use exactly

The HTML-comment block at the top is **mandatory**. The receiving session keys off seeing it FIRST. Don't omit, abbreviate, or move it.

```markdown
<!--
============================================================================
  HANDOFF — BURN AFTER READING
============================================================================
  This file is a single-use bridge between Claude sessions.

  RECEIVING CLAUDE: your VERY FIRST action after reading this file is:
      rm handoff.md
  Do this BEFORE responding to the user. Do NOT git-add it. Do NOT
  git-commit it. Do NOT git-ignore it (gitignoring just hides the
  problem — DELETE the file, don't archive it). Do NOT leave it on
  disk. Confirm deletion in your first message, then proceed with
  the work below.
============================================================================
-->

# Handoff from noop session — <ISO 8601 datetime>

## What the user asked for
<verbatim or near-verbatim version of the user's request — preserve their wording where you can>

## Context I gathered in noop
<anything relevant the receiving session needs: tool versions, decisions, links. Tight; don't pad.>

## What I did NOT do
<short list of what was correctly avoided in noop, so the receiving session knows where work starts>

## Suggested first steps for receiving session
1. `rm handoff.md` (per the burn-after-reading directive above).
2. <next concrete action>
3. <…>

## Open questions for the user
<only if any — otherwise omit the section>
```

After writing, tell the user one line: **"If you don't run the command, delete `handoff.md` manually — a leftover handoff in a public repo is a tiny grooming chore."**

---

## What this dir holds

Just this `CLAUDE.md`. Don't write files into `~/.claude/noop/` for any reason — it's a marker directory, not a workspace.
