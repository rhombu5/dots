---
name: go
description: Execution greenlight. Runs the /ready checkpoint first; ANY non-clean verdict ends the skill immediately (present the findings, start nothing). On clean, standing execution orders activate — optimize hard for ASAP via parallelism (never via design shortcuts), use ultracode where appropriate, use Fable only when justified — and work proceeds through the outstanding queue. Arguments passed with /go are overriding rules layered on top for that run. Use when the user types /go.
---

# go — checkpoint, then execute

## Step 1 — /ready, as a hard gate

Run the `/ready` skill in full, verdicts first. If EITHER verdict is not clean (`1: GAPS` or
`2: NO`), **THE SKILL ENDS HERE**: present /ready's findings and stop — no execution mode, no
new work started. Clean means exactly `1: NO GAPS` and `2: YES`.

## Step 2 — standing orders (activate only on clean)

- **Optimize hard for ASAP** — maximize parallelism: concurrent lanes, batched dispatches,
  side-work while agents run, merge-on-green without asking. ASAP governs wall-clock and
  scheduling, NEVER design choices — correctness rules are untouched by urgency.
- **Use ultracode where appropriate** — multi-agent orchestration for work with that shape;
  say so and skip it where a single focused agent clearly wins.
- **Use Fable only when justified** — reserve the top tier for genuinely hard or interlocked
  slices; tier everything else to sonnet/haiku by task shape.

## Arguments override

Any text passed with `/go` is higher-priority direction layered onto these rules for the run —
an addition, not a replacement.

## Step 3 — execute

Proceed through the outstanding queue on your own judgment under these orders, until blocked on
something only the owner can provide, or done.
