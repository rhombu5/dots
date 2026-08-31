---
name: drain
description: Works through the whole /askme queue in one pass — each open item presented one at a time in /explain's format, auto-advancing to the next as soon as the current one is answered, no "next" required. Triggered by /drain (an optional argument narrows scope the same way it does for /askme).
---

# Drain — clear the /askme queue

Run /askme's selection logic repeatedly, in the same invocation, until the scoped queue is empty.

## Auto-advance — never make the owner say "next"

/askme's one-per-invocation gate exists to stop it from silently skipping ahead across *separate*
invocations while an item sits unanswered. /drain is a single invocation covering the whole
queue: the moment the current item is answered (or explicitly skipped/deferred), immediately
present the next item in the same turn. Don't stop and wait for "next" and don't require the
owner to re-invoke /drain for each item.

An item still gates if the owner hasn't actually answered it — a clarifying question back, a
non-answer, or silence means stay on that item, not advance past it.

## Every item still follows /askme's own rules — don't skip these

These are the two things that keep getting dropped when presenting under /drain specifically, so
restate them here even though /askme already states them:

- **One at a time.** Never batch multiple open items into a single message, even though /drain
  is one continuous invocation. Present item 1, get the answer, present item 2 as a *new*
  message — not a wall of questions up front.
- **Present via /explain's format**: lead with the question in one sentence, plain-language prose
  plus a concrete code snippet wherever code makes the claim checkable, minimal context (no
  history tour), named options + a recommendation if it's a fork, close with what the answer
  unblocks.

Selection ranking and scoping are exactly /askme's: blocking beats important, leverage breaks
ties, age breaks remaining ties; an argument passed to /drain narrows scope the same way an
argument to /askme does.

## Stopping condition

Stop only when the scoped queue is empty — say so in one line. Don't invent an item to keep the
loop going, and don't stop early just because several items have already been cleared this turn.
