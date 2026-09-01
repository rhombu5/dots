# Subagent delegation

Policy for the individual dispatch: which model to hand work to, how to brief it, how to talk to
it while it runs, and what to do with what it returns. Orchestration *economics* — the prefix-cache
model, fan-out cost structure, the design-debate pattern — live in
[`CLAUDE.workflow.md`](CLAUDE.workflow.md); load that one when the question is how to shape a
whole fan-out rather than how to dispatch one agent.

## Subagent model selection

**Right-size the model to the task.** Opus is the default for the main thread; if a smaller model does the work at equal-or-better quality for less, dispatch it there instead.

Concrete cases:

- **Prose-shaped work** — rewriting, summarizing, drafting docs / issues / PR bodies / commit messages / runbook entries / sections of `CLAUDE.md`, comparing wordings → **always dispatch a sonnet subagent**, unless I've explicitly told you otherwise this turn. Sonnet's prose is reliably tighter than opus's. Escape hatch: an instruction like "do this on opus" or "don't delegate this one" — not the request merely being addressed to me.
- **Mechanical / scripted work** — bulk renaming, simple refactors with a clear pattern, format conversion, straightforward file scans → **haiku** is often enough. Try it; escalate if quality drops.
- **Reasoning effort is a second dial, orthogonal to model.** Turn it down for rote mechanical stages, reserve high/max for genuinely hard verify/judge/design steps — effort multiplies output tokens (the `~5×` kind), so low-effort haiku on a rote task is the cheapest cell in the grid.
- **Fable is governed by one invariant: the quota must NOT run dry.** A tier orthogonal to the three above. An autonomous dispatch clears in either of two ways: a stated, extremely strong task justification, or clear quota surplus — the burndown test in `CLAUDE.workflow.md` § "Fable usage" (keep the yellow above the white). Clear surplus justifies the spend on its own, since unused quota expires at reset; tight headroom vetoes regardless of task merit. The quota check isn't `get_usage` (no Fable bucket there) — workflow.md has the real mechanism. A Fable *orchestrator's* own window is Fable spend too: on a Fable main thread, delegate reads/code/prose to cheaper tiers and keep the window lean. When I name `@cheap-fable` explicitly, that's always fine regardless of quota — the gate is only on your own autonomous choice to reach for it.
- **A versioned model id always carries the `[1m]` 1M-context suffix.** Anywhere you write a concrete id rather than an alias — a `Workflow` script's `model`, `--model`, `fnc_set_model`, `settings.json` — spell it `claude-opus-5[1m]`, `claude-opus-4-8[1m]`, `claude-opus-4-6[1m]`, `claude-sonnet-5[1m]`, `claude-fable-5[1m]`. Two exceptions, both verified 2026-08-29 by probing them: `claude-haiku-4-5[1m]` is refused (400, long-context beta not on this subscription) and `claude-sonnet-4-6[1m]` needs usage credits — those two stay bare. The `Agent` tool's `model` field is a fixed enum (`opus`/`sonnet`/`haiku`/`fable`) that can't hold a suffix; leave it alone.

Substance, structure, and tricky design decisions stay on **opus** — only *execution* gets handed off: opus decides *what*, the subagent does the *how*.

Subagent prompts should include the substance, style/format constraints, and pointers to sibling docs/files to mirror tone from. Return ready-to-drop-in output.

## Teams mode is on — `SendMessage` works mid-flight

`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set in my env and in `~/.claude/settings.json`. Subagents you spawn are teammates: `SendMessage(to: <agentId>, message: …)` delivers to a *running* agent at its next turn boundary, not only after it completes.

**To extend or correct a running agent's scope, try `SendMessage` before `TaskStop` + redispatch.** Killing throws away work-in-progress (context built, files read, code drafted); kill-and-redispatch is the fallback only when the scope change is incompatible with what's already written.

The `SendMessage` tool's docstring still leans on "resume a completed background agent" framing — that's the non-teams default. With teams mode on, mid-flight delivery works; the tooling description hasn't caught up.

## Subagents always run silent

**Every subagent prompt must include a run-silent directive** — no narration, no progress prose, no explanations between tool calls; tools and a terse final report only. This goes in the dispatch prompt itself (e.g. a first line like "RUN SILENT: no narration; terse final report only"), every time, for every agent type and model. Narrating agents burn tokens describing work instead of doing it.

## Don't echo subagent return messages

A subagent's final message is delivered to me directly as a task notification — I can read it. **Don't re-summarize it.** Echo-summaries are pure duplication, billed twice. Acknowledge in one line ("PR #42 in flight" / "rejected — schema cost too high") and move on.

Exception: if the subagent surfaced something action-shaped (a blocker, a critical finding, a request for direction), call it out explicitly so I don't miss it inside a routine-looking notification.
