---
name: goweb
description: Execution greenlight, cloud edition. Identical to /go — the /ready checkpoint runs LOCALLY first and ANY non-clean verdict ends the skill immediately — except that on clean, execution is dispatched to a CLOUD agent instead of running locally. Before launch it ensures everything the run needs is committed AND pushed, since the cloud agent sees only origin. Standing orders are /go's (ASAP via parallelism, ultracode where appropriate, Fable only when justified); arguments passed with /goweb are overriding rules layered on top for that run. Runs ONLY when the owner literally types /goweb — never self-invoked, never re-run in a loop, never inferred from "proceed"-style language.
---

# goweb — checkpoint locally, execute in the cloud

> **Typed-invocation only.** This skill runs solely when the owner literally types `/goweb`.
> Never self-invoke it, never re-run it in a loop, and never treat "proceed"-style language as an
> invocation. When a greenlight seems warranted, say so and let the owner type it.

## Step 1 — /ready, locally, as a hard gate

Run the `/ready` skill in full, verdicts first, in THIS session against the LOCAL tree. If EITHER
verdict is not clean (`1: GAPS` or `2: VOLATILE`), **THE SKILL ENDS HERE**: present /ready's
findings and stop — no push, no dispatch, no new work started.

## Step 2 — ensure pushed (only on clean)

The cloud agent sees only what is on origin. Before dispatching:

- Commit anything uncommitted that the run needs (the work docs, the task list, the tree state
  the run's own procedure expects) — `--no-verify` is acceptable for a savepoint-class commit.
- Push the branch. Verify the pushed tip (`git ls-remote`) is the commit the run should start
  from, and name that SHA in the dispatch.

If pushing is impossible (no remote, rejected push that can't be resolved mechanically), stop and
present the blocker — never dispatch an agent against a tip that doesn't hold the work.

## Step 3 — standing orders (same as /go)

- **Optimize hard for ASAP** — maximize parallelism: concurrent lanes, batched dispatches,
  side-work while agents run, merge-on-green without asking. ASAP governs wall-clock and
  scheduling, NEVER design choices — correctness rules are untouched by urgency.
- **Use ultracode where appropriate** — multi-agent orchestration for work with that shape;
  say so and skip it where a single focused agent clearly wins.
- **Use Fable only when justified** — reserve the top tier for genuinely hard or interlocked
  slices; tier everything else to sonnet/haiku by task shape.

## Step 4 — dispatch to the cloud

Launch the orchestrator with `Agent(isolation: "remote", …)`, briefed to check out the pushed
branch at the named SHA. Bake the cloud environment's realities into the brief:

- **No user skills or user CLAUDE.md travel** — `/go`, `/ready`, and the owner's global rules do
  not exist there. Whatever gap-handling, halting rules, and conventions the run must honor have
  to live in the repo (an execution doc) or in the dispatch prompt itself.
- **No local-tree visibility** — everything it needs is on origin; it reports back by PUSHING,
  which is also how progress is observed locally.
- **No local credentials** — npm publishes, keyring access, and anything auth-gated on the
  owner's machine are out of the run's reach; scope the brief accordingly.
- **Cold caches** — the sandbox pays first-build costs the local machine wouldn't; don't read
  slow first gates as wedges.

Then arm a LOCAL Monitor on the pushed branch (tip movement per event, wedge alert on prolonged
silence, poll-failure announcements — the standing Monitor rules apply). Remote availability is
gated: if the dispatch is refused, fall back to presenting the blocker — do not silently run the
work locally instead; local execution is what `/go` is for.

## Arguments override

Any text passed with `/goweb` is higher-priority direction layered onto these rules for the run —
an addition, not a replacement.

## Step 5 — while it runs

Stay responsive locally. Relay the orchestrator's task-notification report when it lands; act on
wedge alerts by inspecting before assuming (a quiet stretch may be a legitimate long gate). The
run ends when the orchestrator reports — its report, plus the pushed commits, are the deliverable.
