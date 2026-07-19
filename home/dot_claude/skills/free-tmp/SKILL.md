---
name: free-tmp
description: Safely reclaim tmpfs (/tmp) space — delete stale/orphaned build dirs (go-build*, fnioc-ttsc-*, transient caches) while PRESERVING any dir a build is actively writing. Run before Go-heavy work, or when a tmpfs-pressure alert fires. Triggered by /free-tmp.
---

# Free /tmp

Reclaim tmpfs (`/tmp`) space **safely**. A full tmpfs wedges every shell on the machine at once, so keeping it clear matters — but deleting a directory a build is *actively writing* corrupts that build. The whole job is one judgment: **delete what's stale, preserve what's live.**

## Run this INLINE — never in an agent

The safety call — "is this dir stale, or is a build using it right now?" — needs *this* session's awareness of what's running: which builds/agents are yours, whether a sibling session is mid-build. A dispatched agent is blind to that; it would either delete on naive heuristics (risking a corrupted live build) or need you to pre-compute what to keep — at which point it's just running `rm` for nothing. It's also only a few commands. So do it here, in the main context. A *persistent auto-cleaner* is the actively-dangerous shape — never build that.

## The move

`idle` = nothing written inside in the last ~5 min (so no build is touching it). Delete idle, keep the rest:

```bash
echo "=== /tmp before ==="; df -h /tmp | tail -1
for d in /tmp/go-build* /tmp/fnioc-ttsc-* /tmp/node-compile-cache; do
  [ -e "$d" ] || continue
  if [ -z "$(find "$d" -newermt '-5 minutes' 2>/dev/null | head -1)" ]; then
    rm -rf "$d" 2>/dev/null && echo "removed $(basename "$d") (idle)"
  else
    echo "KEPT $(basename "$d") (active — a build is writing it)"
  fi
done
echo "=== /tmp after ==="; df -h /tmp | tail -1
```

## Judgment beyond the timer

The 5-minute idle test is the floor, not the whole answer. Also **keep** a dir when:

- You *know* a build / agent / sibling-session is in flight that owns it, even if it looks momentarily idle between phases.
- A large, recent (`< ~10 min`) dir *might* be a live run and you're unsure — **keep it.** The cost of leaving `/tmp` at 85% is one more cleanup; the cost of deleting a live build is a corrupted or failed build. When unsure, don't delete.

## What each candidate is

- `go-build*` — Go compiler temp dirs. Go removes them on a clean exit, so an **idle** one is orphaned (a killed/crashed build) → safe.
- `fnioc-ttsc-*` — ttsc e2e working dirs (the std@fnioc repo). Recreated per run, so an idle one is a leftover → safe (the harness rebuilds it).
- `node-compile-cache` and other transient caches — safe only when idle.

Never touch non-transient things: sockets, the `/tmp/claude-*` scratch you're actively using, mounted paths, anything you can't identify as a throwaway build artifact.

## When to run it

- **Proactively**, before dispatching Go-heavy work — the standing `/tmp` hygiene rule (clear stale dirs before a build burst so a wedge can't strand it).
- **Reactively**, when a tmpfs-pressure alert fires. Advisory around ~80%; act decisively at ~88%+ (wedge territory).

## The watch stays separate

This skill *cleans*. If you want continuous alerting, that's a **Monitor** on `df /tmp` that only emits at a threshold and deletes nothing — so the risky deletion always runs here, where the judgment can happen, never as a background auto-deleter.
