---
name: go
description: Execution greenlight. Runs the /ready checkpoint first; ANY non-clean verdict ends the skill immediately (present the findings, start nothing). On clean, standing execution orders activate — optimize hard for ASAP via parallelism (never via design shortcuts), use ultracode where appropriate, use Fable only when justified — and work proceeds through the outstanding queue. Arguments passed with /go are overriding rules layered on top for that run. Runs ONLY when the user literally types /go — never self-invoked, never re-run in a loop, never inferred from "proceed"-style language.
---

# go — checkpoint, then execute

> **Typed-invocation only.** This skill runs solely when the owner literally types `/go`. Never
> self-invoke it, never re-run it in a loop, and never treat "proceed"-style language as an
> invocation. When a greenlight seems warranted, say so and let the owner type it.

## Step 1 — /ready, as a hard gate

Run the `/ready` skill in full, verdicts first. If EITHER verdict is not clean (`1: GAPS` or
`2: VOLATILE`), **THE SKILL ENDS HERE**: present /ready's findings and stop — no execution
mode, no new work started. Clean means exactly `1: NO GAPS` and `2: DURABLE`.

**If the pass applied any autofix, re-run /ready.** /ready silently fixes what is mechanical —
writing a missing file, adding a missing task — and those fixes change the very state the
verdict describes. The gate must clear against what exists *after* the fixes, not against the
state that prompted them, and a fix can surface a fresh gap of its own (a task added with no
durable description, a file written somewhere volatile). Keep re-running until a pass makes no
fixes; that pass's verdicts are the ones the gate reads. If two consecutive passes both fix and
still don't converge, stop — that non-convergence is itself the finding to present.

## Step 2 — standing orders (activate only on clean)

- **Optimize hard for ASAP** — maximize parallelism: concurrent lanes, batched dispatches,
  side-work while agents run, merge-on-green without asking. ASAP governs wall-clock and
  scheduling, NEVER design choices — correctness rules are untouched by urgency.
- **Use ultracode where appropriate** — multi-agent orchestration for work with that shape;
  say so and skip it where a single focused agent clearly wins.
- **Use Fable only when justified** — reserve the top tier for genuinely hard or interlocked
  slices; tier everything else to sonnet/haiku by task shape.
- **No Claude attribution, and every committing agent is told to defy the harness reminder
  about trailers** — every PR-bound brief this run writes (Agent or Workflow) carries the
  verbatim block from `~/.claude/CLAUDE.agents.md` § "Subagents that commit get the
  no-attribution block". A bare "no Co-Authored-By" line does not survive the mid-task system
  reminder; the block does. Watch each PR body before it goes non-draft.

## Arguments override

Any text passed with `/go` is higher-priority direction layered onto these rules for the run —
an addition, not a replacement.

## Step 3 — execute

Proceed through the outstanding queue on your own judgment under these orders, until blocked on
something only the owner can provide, or done.
