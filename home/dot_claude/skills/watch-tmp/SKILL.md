---
name: watch-tmp
description: Reclaim tmpfs (/tmp) space. `/watch-tmp` (scoped, the default) cleans only THIS session's own transient build artifacts — its /tmp/<session-id>/ root PLUS other dirs it remembers creating (e.g. go-build*) — safe to run while other sessions are live. `/watch-tmp global` sweeps ALL idle transient dirs regardless of owner, for orphans whose creating session is dead. Run before Go-heavy work or on a tmpfs-pressure alert.
---

# watch-tmp

Reclaim tmpfs (`/tmp`) space. A full tmpfs wedges every shell on the machine at once — but deleting a dir a build is *actively writing* corrupts that build, and with several sessions live, one session's cleanup must not clobber another's. Two modes handle the split.

## Run this INLINE — never in an agent

The safety call needs *this* session's awareness of what it launched and what's running right now. A dispatched agent is blind to that, and it's only a few commands — do it here, in the main context. A *persistent auto-cleaner* is the actively-dangerous shape; never build that.

## Mode 1 — scoped (DEFAULT): clean only what THIS session created

`/watch-tmp` or `/watch-tmp scoped`. Remove only the transient `/tmp` artifacts THIS session owns — safe alongside live sibling sessions, because you never touch anything you didn't make. Clean from **both** sources:

**a) Your session root `/tmp/$CLAUDE_CODE_SESSION_ID/`** (once fnc routes build tmp there). Everything under it is yours — clean its idle entries (idle-checked so you don't nuke your own running build):

```bash
root="/tmp/$CLAUDE_CODE_SESSION_ID"
[ -d "$root" ] && for d in "$root"/*; do
  [ -e "$d" ] || continue
  [ -z "$(find "$d" -newermt '-5 minutes' 2>/dev/null | head -1)" ] && rm -rf "$d" && echo "removed ${d#/tmp/}"
done
```

**b) Other dirs you remember creating that land outside that root.** The big one is `/tmp/go-build*` — the Go compiler writes there by default, unique names per build, so it won't move into your session root just because the scratchpad did. You know which are yours because you launched the builds. **Keep a running note of transient dirs your builds produce** (append their paths to a file in your scratchpad) — that's how the session "remembers"; scoped-clean reads that note. Idle-check each, and **leave any you can't confidently attribute to yourself** — that's a sibling's or an orphan, which is what `global` is for.

Do NOT scope-clean the shared per-suite `fnioc-ttsc-*` e2e dirs: they're reused across runs and sessions at the same path (the std@fnioc #245 reuse bug), so no single session owns them — they're `global`-only.

## Mode 2 — global: sweep ALL idle orphans, whoever made them

`/watch-tmp global` (or `--global`). The owning session of some `/tmp` crap may be **dead** — nobody left to scope-clean it. Removes EVERY idle transient build dir regardless of owner. `idle` is the only safety signal here (there's no owner to ask):

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

Extra caution in global mode: a large, recent (`< ~10 min`) dir might be *another live session's* between-phase build. When unsure, **keep it** — the cost of leaving `/tmp` at 85% is one more cleanup; the cost of deleting a live build is a corrupted or failed build. Never touch sockets, `/tmp/claude-*` scratch roots (they hold session notes/scratch, not build junk), mounted paths, or anything you can't identify as a throwaway build artifact.

## What each candidate is

- `go-build*` — Go compiler temp dirs, uniquely named. Go removes them on a clean exit, so an idle one is orphaned (a killed/crashed build) → safe. Attributes cleanly to a session.
- `fnioc-ttsc-*` — ttsc e2e working dirs (std@fnioc), per-suite and reused across sessions → shared, so `global`-only.
- `node-compile-cache` and other transient caches — idle-only.

## When to run it

- **Proactively** before Go-heavy dispatches (the standing `/tmp` hygiene rule) — scoped, so you clear your own leftovers without touching a sibling's.
- **On a tmpfs-pressure alert** — scoped first; escalate to `global` when pressure persists and you suspect dead-session orphans. Advisory around ~80%; act decisively at ~88%+ (wedge territory).

## The watch stays separate

Despite the name, this skill *cleans* — it doesn't run continuously. Continuous alerting is a **Monitor** on `df /tmp` that only emits at a threshold and deletes nothing, so the risky deletion always runs here, where the judgment can happen, never as a background auto-deleter.
