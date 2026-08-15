---
name: ready
description: Readiness checkpoint before a pause, compact, or handoff. Asks two questions and demands plain verdicts — (1) is anything we discussed missing an explicit owner "yes" while neither ruled out nor tracked on the todo list, and (2) do the task list and every requirement/ruling exist in non-volatile files? Runs ONLY when the user literally types /ready, or as the gate inside a user-typed /go — never self-invoked; natural-language questions ("are we ready", "did I miss anything") do NOT trigger it.
---

# ready — two questions, two plain verdicts

> **Typed-invocation only.** This skill runs solely when the owner literally types `/ready` (or
> as the gate inside a `/go` the owner typed). Never self-invoke it; a natural-language "are we
> ready?" gets an ordinary answer, not this ceremony.

A checkpoint, not a cleanup. Answer BOTH questions, and **lead with the verdict word for each**
— `1: NO GAPS` / `1: GAPS — <n>` and `2: DURABLE` / `2: VOLATILE — <n>` — before any supporting
detail. Verdict words must be SELF-DESCRIBING: a bare YES/NO that only makes sense if the reader
remembers which question it answers fails the skill's whole purpose, same as a buried verdict.

## Question 1 — undecided, unruled, untracked

Sweep the conversation (the whole session, not just the recent stretch) for anything **discussed
at substantive length** that is ALL THREE of:

- never got the owner's **explicit** yes (an implied yes, a principle that merely leans that
  way, or the owner's own proposal left unconfirmed all count as NOT yes — list them),
- not otherwise ruled out or dissolved (a thread that ended because its premise died is dead,
  not pending),
- absent from the todo list AND from any durable record that commits someone to act.

The substantive-length filter guards against noise, never against the owner: an owner work
request (however brief the aside that carried it), a question put TO the owner that he never
answered, and an issue he raised and left open ALL qualify regardless of length.

For each hit, name it, say what one word from the owner resolves it, and either add the task on
the spot (when tracking is the gap) or list it (when the owner's word is the gap). Distinguish
the two — don't ask for words where a task was the missing thing.

## Question 2 — non-volatile capture

Verify the session's load-bearing state survives a compact, a restart, AND a reboot:

- **Task list**: current, statuses honest, every scoped work item's substance recoverable from
  its description or a file it points to (a task whose meaning lives only in conversation
  context is volatile — fix it now).
- **Requirements / rulings / decisions**: every one landed in repo files or decision records
  on real disk. VOLATILE means `/tmp`-class storage: tmpfs scratchpads, session temp dirs,
  conversation context — anything that dies with the machine or the session. On-disk but
  uncommitted is NOT volatile (that's /done's concern, not this one's).
- **Volatile-only artifacts**: anything load-bearing that exists ONLY in `/tmp`, a scratchpad,
  or conversation context gets flagged with where it must move.

Fix silently what is mechanical (writing the missing file, adding the missing task); SURFACE
what needs the owner (uncommitted work in his worktree, a ruling that should become a decision
record).

## Output shape

```
1: GAPS — 2
   - <thing> — needs your word: <the one-worder>
   - <thing> — was untracked; task #N created
2: VOLATILE — 1
   - <ruling/file> lives only in scratchpad — moved to <repo path> / needs commit in <worktree>
```

Clean run: `1: NO GAPS` and `2: DURABLE — survives compact, restart, and reboot`, each with at
most one supporting line.

Then stop. This skill reports readiness; it does not start new work.
