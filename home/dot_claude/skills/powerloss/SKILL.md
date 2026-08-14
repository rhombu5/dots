---
name: powerloss
description: Recover a session's in-flight work after an unexpected hard restart (power outage, hard reboot, OOM-kill, crashed Claude Code process) — repair the git object store, locate surviving agent transcripts / worktrees / task store / team roster, restore them into the restarted process, and resume the lanes without losing their context.
---

# powerloss — resume WIP after an unexpected hard restart

Runbook for the team-lead session that comes back up after the machine (or just the Claude Code
process) died mid-wave with agent lanes in flight. A solo session is the trivial subset — skip the
roster/lane phases.

The governing rule: **everything on disk survived; nothing in memory did. Assess before you write,
and never make an agent start over before proving its context is unrecoverable.**

## Phase 0 — Assess, read-only

- `ListAgents` — expect in-process subagents gone and peer sessions offline; that's the blast
  radius, not the loss. **Zero visible subagents after a session resume is the normal state**, even
  when several were mid-flight: a resume rebuilds the conversation, it never respawns workers. Say
  so up front — the owner seeing an empty agent list will reasonably ask where everyone went.
- **A `/compact` is the soft variant of this assessment** — subagents CAN survive one, but every
  label about them goes stale: `ListAgents` may show a raw id with no name and a reset "started"
  clock, the teammate roster lists long-dead lanes as running, and `TaskStop <name>` can resolve to
  a different agent than the one still executing. Identify a surviving subagent by READING its
  transcript (`tasks/<id>.output` → dispatch prompt + recent tool targets), never by its name,
  description, or start time — and stop it by raw agent id when it must die.
- `git ls-remote origin <each-lane-branch> <base-branch>` — the objective record of what reached
  origin before the cut. A missing lane branch means that lane never pushed, not that its work is
  gone.
- Inspect every lane worktree: `git status --short` + `git log origin/<base>..HEAD`. Dirty files
  and unpushed local commits are the predecessor's surviving work — **never** `reset`, `clean`, or
  `checkout` over them.
- Distrust every render: stale system-reminder task listings show pre-crash state, and
  `$CLAUDE_CODE_SESSION_ID` still shows the resumed conversation's uuid even though the process's
  internal id changed. Verify against the stores on disk, not against what a listing said.

## Phase 1 — Repair the shared git object store FIRST

Power loss mid-write leaves **empty loose objects**; the tell is
`error: object file .git/objects/… is empty` from any git command. Worktree status listings can
render fine while `log`/`rev-parse` fail — repair before any lane runs a git command.

```sh
find <gitdir>/objects -type f -empty -print -delete
git fetch origin <base-branch>        # restores every object that was pushed
git fsck --connectivity-only --no-dangling   # exit 0 = healthy
```

The corruption hits the most recently written objects — usually the local copies of your last
push, which the remote still has. If an **unpushed** commit's object is empty it is gone as a
commit, but its content usually still exists as the worktree's dirty files — check before
declaring loss.

## Phase 2 — Locate the surviving state

Everything is keyed by the DEAD process's internal id (`session-<oldid>`), not by your session
uuid, and the restarted process mints a NEW internal id and fresh empty dirs. "No tasks found" ≠
store lost.

- **Subagent transcripts** (the lanes' full context — brief, progress, findings):
  `~/.claude/projects/<parent-project-slug>/<parent-session-uuid>/subagents/agent-a<name>-<hash>.jsonl`
- **Task store**: `~/.claude/tasks/session-<oldid>/` — numbered task JSONs + `.highwatermark`.
- **Team roster + inboxes**: `~/.claude/teams/session-<oldid>/` — the real roster's `config.json`
  is large (hundreds of KB, every member); a fresh stub is ~500 bytes with only team-lead.

**Every session on the machine restarted at once**, so several fresh `session-*` dirs appear with
near-identical mtimes. Identify YOURS by config content (`cwd`, `leadSessionId`) — never by
"newest" (mis-copying into another session's dir pollutes it and must be undone). The reliable
trick for the task dir: `TaskCreate` a throwaway probe, then
`find ~/.claude/tasks -name "1.json" -newermt "<5 min ago>"` — the dir that gained it is yours.
Delete the probe after the restore.

## Phase 3 — Restore the stores

- **Tasks**: `cp old/[0-9]*.json old/.highwatermark → new-dir/`; verify with `TaskList` (statuses,
  owners, and metadata banks all carry). `.highwatermark` may lag the real max id — harmless, the
  store allocates past existing files; copy it as-is.
- **Roster**: jq-merge the dead lanes' member objects from the old `config.json` into the new
  one's `members` array; copy their inbox files (and team-lead's) into the new `inboxes/`. After
  the graft, `SendMessage` resolves the names again ("No agent named X is reachable" before the
  graft is the roster gap, not proof the agent is unrecoverable).

## Phase 4 — Resume the lanes: a fidelity ladder

Stop at the first rung that works; each rung down loses a little context and costs a little more.

1. **SendMessage resume orders** to the grafted names. Every order restates, per lane: the
   observed worktree state (dirty count + notable files), the no-local-commits / nothing-pushed
   facts, the object-store-repaired notice, the current base tip, and **every standing ledger
   item** — mail queued pre-crash may have died unread, so never assume a pre-crash instruction
   arrived. Add "distrust any remembered gate results — re-run everything before reporting" and
   demand a one-line resumption confirm.
2. **Delivery ≠ revival — and for in-process agents, expect NO revival.** A send landing in the
   inbox proves only that the roster graft worked; a dead in-process agent has no live backend to
   drain its inbox, so rung 1 is a cheap long-shot, not a plan. Arm a short deadman (~10 min
   background sleep) but don't sit on it — the moment there's no plausible revival mechanism (no
   confirmations, agents absent from `ListAgents`), go to rung 3 without waiting out the timer.
3. **Fresh successor spawns.** Brief each to read its predecessor's transcript (the first message
   is the full brief — "follow it as your own"; the rest is progress and findings), treat the
   worktree's dirty state as ground truth, continue — never redo work the tree already holds —
   and confirm takeover in one line BEFORE starting the long work. Include any ledger item issued
   after the original brief: it won't be in the transcript. **Naming**: the grafted roster still
   holds the dead agents' names, so same-name spawns get deduped to suffixed names (`<name>-2`) —
   fine; re-point task ownership to the successor names and address them by those from then on.

## Phase 5 — Re-arm and report

- Background monitors and watches died silently — a "no completion record was found" task
  notification is the tell. Re-arm them against the CURRENT branch/lane set, not the pre-crash one.
- Report: what died, what survived, repairs made, and which rung each lane resumed at.
