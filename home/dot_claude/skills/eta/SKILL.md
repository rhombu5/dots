---
name: eta
description: Answers how long the outstanding work will take, as a bare timespan and nothing else. Triggered by /eta, optionally with an argument naming what to estimate.
---

# eta — the timespan, nothing else

Answer with **just the total timespan**. One line. No breakdown, no per-item table, no caveats,
no restating what is running, no offer to elaborate.

    Roughly 15–25 minutes.

That is the entire reply.

## Scope

`/eta` with no argument estimates everything currently outstanding — work in flight plus whatever
is queued behind it. An argument narrows it to that subject (`/eta the benchmark`), and only that
subject is estimated.

## Estimating

Cover the whole span from now until the named work is done, including the parts that are not
compute: agents still running, gates and test suites, the reviews and rulings that follow, and the
owner's own read-and-decide latency between turns where that is genuinely on the path.

Give a range, not a point. The range should be honest about the spread — a narrow range asserts a
confidence estimates of this kind rarely earn.

If the work is genuinely unbounded, or is blocked on someone else, say so in the same single line
rather than inventing a number: `Blocked on your ruling — no estimate.`

## Why it is bare

The number is being asked for so a decision can be made in a second: wait, or go do something
else. Any prose around it defeats that.
