---
name: watch-tmp
description: Reclaim tmpfs (/tmp) space AND arm the pressure watch. `/watch-tmp` (scoped, the default) cleans only THIS session's own transient build artifacts — its /tmp/<session-id>/ root PLUS other dirs it remembers creating (e.g. go-build*) — safe to run while other sessions are live, then arms a delete-nothing Monitor on df /tmp that alerts at ~80%/~88%. `/watch-tmp global` sweeps ALL idle transient dirs regardless of owner, for orphans whose creating session is dead. Run before build-heavy work or on a tmpfs-pressure alert.
---

# watch-tmp

Reclaim tmpfs (`/tmp`) space. A full tmpfs wedges every shell on the machine at once — but deleting a dir a build is *actively writing* corrupts that build, and with several sessions live, one session's cleanup must not clobber another's. Two clean modes handle that split, and a third step arms a *watch* so the next pressure spike reaches you instead of wedging silently.

## Run this INLINE — never in an agent

The safety call needs *this* session's awareness of what it launched and what's running right now. A dispatched agent is blind to that, and it's only a few commands — do the **cleaning** here, in the main context. A *persistent auto-**deleter*** is the actively-dangerous shape; never build that — a background process that removes files on its own has no way to know what a live build is mid-write. The pressure **watch** in Mode 3 is the safe counterpart: it only *alerts*, deletes nothing, and hands the deletion back to a judgment-bearing inline run.

## Mode 1 — scoped (DEFAULT): clean only what THIS session created

`/watch-tmp` or `/watch-tmp scoped`. Remove only the transient `/tmp` artifacts THIS session owns — safe alongside live sibling sessions, because you never touch anything you didn't make. Clean from **both** sources:

**a) Your session root `/tmp/$CLAUDE_CODE_SESSION_ID/`** (when build tmp is routed there). Everything under it is yours — clean its idle entries (idle-checked so you don't nuke your own running build):

```bash
root="/tmp/$CLAUDE_CODE_SESSION_ID"
[ -d "$root" ] && for d in "$root"/*; do
  [ -e "$d" ] || continue
  [ -z "$(find "$d" -newermt '-5 minutes' 2>/dev/null | head -1)" ] && rm -rf "$d" && echo "removed ${d#/tmp/}"
done
```

**b) Other dirs you remember creating that land outside that root.** The common one is `/tmp/go-build*` — the Go toolchain writes there by default, unique names per build, so it stays at the `/tmp` root even when your scratch dir doesn't. You know which are yours because you launched the builds. **Keep a running note of transient dirs your builds produce** (append their paths to a file in your scratchpad) — that's how the session "remembers"; scoped-clean reads that note. Idle-check each, and **leave any you can't confidently attribute to yourself** — that's a sibling's or an orphan, which is what `global` is for.

Don't scope-clean a **shared** working dir: some build/test harnesses create a fixed-path, per-suite working dir under `/tmp` and reuse it across runs *and* sessions. No single session owns it, so it can't be attributed — clean those only in `global` mode.

## Mode 2 — global: sweep ALL idle orphans, whoever made them

`/watch-tmp global` (or `--global`). The owning session of some `/tmp` crap may be **dead** — nobody left to scope-clean it. Removes EVERY idle transient build dir regardless of owner. `idle` is the only safety signal here (there's no owner to ask):

```bash
echo "=== /tmp before ==="; df -h /tmp | tail -1
# generic dev-tool temps; add the current project's own transient /tmp working-dir patterns to this list
for d in /tmp/go-build* /tmp/node-compile-cache; do
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
- **Test/e2e harness working dirs** — many projects drop a reusable per-suite dir in `/tmp`; shared across sessions → `global`-only. Learn the current project's pattern and add it to the global list.
- `node-compile-cache` and other transient caches — idle-only.

## When to run it

- **Proactively** before build-heavy dispatches (the standing `/tmp` hygiene habit) — scoped, so you clear your own leftovers without touching a sibling's.
- **On a tmpfs-pressure alert** — scoped first; escalate to `global` when pressure persists and you suspect dead-session orphans. Advisory around ~80%; act decisively at ~88%+ (wedge territory).

## Mode 3 — arm the watch (runs on every invocation)

After cleaning, arm the pressure watch so the *next* spike reaches you instead of wedging every shell in silence. This is what the skill's name promises. It is a **`Monitor`**, not a loop you babysit: a delete-nothing poll of `df /tmp` that emits **only** when the usage band changes (OK → ADVISORY at ~80% → ALERT at ~88%, and back down on recovery). It never removes anything — on an ALERT you come back and run Mode 1/2 inline, where the judgment lives.

Arm exactly one per session. Before arming, check you don't already have a `/tmp` pressure Monitor running (`TaskList`) — re-arming stacks duplicate alerts. If one's already live, skip this step.

```bash
prev="OK"
while true; do
  pct=$(df --output=pcent /tmp 2>/dev/null | tail -1 | tr -dc '0-9')
  # Liveness/wedge guard: df should always answer. If it can't, the watch is broken — say so and exit.
  if [ -z "$pct" ]; then echo "WEDGE: df /tmp returned nothing — pressure watch is blind, exiting"; exit 1; fi
  if   [ "$pct" -ge 88 ]; then band="ALERT";
  elif [ "$pct" -ge 80 ]; then band="ADVISORY";
  else                        band="OK"; fi
  if [ "$band" != "$prev" ]; then echo "/tmp ${pct}% — ${band}"; prev="$band"; fi
  sleep 60
done
```

Arm it with `persistent: true` (a pressure watch is session-length) and `description: "/tmp pressure"`. This satisfies the two-layer Monitor rule in user prefs: the **wedge guard** is the `df`-returns-nothing branch (a threshold alarm's silence is *healthy*, so the guard watches the monitor's own liveness, not the happy path), and `persistent` is the right backstop for a watch meant to live as long as the session. On an ALERT event, don't let the Monitor delete — re-enter this skill inline: scoped first, escalate to `global` if pressure persists.
