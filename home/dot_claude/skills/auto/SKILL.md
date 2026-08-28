---
name: auto
description: Enters autonomous mode — work through outstanding tasks on your own, silent until a final report. Triggered by /auto, optionally with arguments giving additional direction for the run.
---

# Auto

Hand-you-the-wheel mode. The owner is instructing you to work through outstanding tasks on your own judgment, without checking in along the way.

> **NOT A LICENSE.** This mode removes the check-in ceremony, never the permission boundary.
> A decision you weren't allowed to make before `/auto` is still not yours to make during it —
> owner-ruled architecture, public API shape, design contracts, anything that would need his
> signoff in normal mode. Autonomy changes *when* you talk to him, not *what* is yours to decide.

## Run silent

No narration, no user-facing status prose, no between-action commentary. Nobody reads that text in real time, so emitting it only spends output tokens for no benefit.

**This applies only to user-facing narration text.** It does NOT suppress or constrain internal thinking/reasoning — that happens either way and costs nothing extra, so think as freely and thoroughly as the task needs. The only thing being cut is the prose you'd otherwise print between tool calls.

## Go as far as you can

Keep working. Don't stop to check in or ask permission for reversible work that follows from the task at hand.

## If blocked, work on something else

When a task is blocked — a dependency isn't ready, an external system is down, or something is genuinely the owner's call to make — set it aside and make progress on something that isn't blocked. Come back to it if it unblocks. **An owner-call fork is a blocked task, full stop** — park it with a note for the report and switch tracks; never resolve it yourself because parking feels like stalling. Where a fix splits into a part that's yours (frequency, naming, placement) and a part that's his (transport, contract, ruled shape), do yours and park his.

## At a fork in the road, make a call

Decide and proceed rather than halting to ask — **for forks that were already yours to decide.** This section grants decisiveness, not jurisdiction: a fork the owner would rule in normal mode goes to "If blocked" above, however reversible the code looks. Reserve halting for the genuinely irreversible or destructive — the kind of action the owner must own.

## One report at the end

At the very end, present ONE report: the blocks you hit and the decisions/calls you made, each with its reasoning. This is the single place narration is wanted, and it should be complete — it's the owner's only window into everything that happened silently during the run.

## Arguments augment the base rules

Any text the owner passes with `/auto <...>` is additional, higher-priority direction layered on top of these rules for that run — not a replacement for them.

## Exit condition

This mode ends and reverts to normal the instant the owner sends any message. Their next prompt is both the exit signal and a fresh instruction.
