# Go context rules

## Toolchain — mise-resolved, pinned local

Go comes from mise only, per the global NO SYSTEM-WIDE DEVTOOLS rule (`~/.claude/CLAUDE.md`).
Resolve the binary via `mise which go`; always set `GOTOOLCHAIN=local` so Go never reaches out and
downloads a different toolchain on its own.

**Fresh worktree/clone gotcha:** mise trust is per-path, so a brand-new worktree carries an
untrusted `mise.toml` — `mise which go` errors and prints **nothing**. Any script keying off that
output must treat empty as a loud failure, not a silent fallback; any agent brief for a fresh
worktree must include `mise trust` before the first build. Observed failure shape: an
empty `TTSC_GO_BINARY`-style pin let a tool fall back to its bundled toolchain against the ambient
`GOROOT` — straight into the version split below.

## The ambient-GOROOT toolchain split

Error signature to recognize on sight, seconds into a build, on every package:

```
compile: version "go1.X" does not match go tool version "go1.Y"
```

Cause: these machines' shells can carry a stale exported `GOROOT` (a `go1.24.x` was observed) that
splits against whatever the mise `go` driver resolves to.

For an ad-hoc command, strip both:

```bash
env -u GOROOT -u GOBIN go build ./...
```

For a build script that constructs an env object, deleting the key from the object is **not**
enough if the object later gets merged over `process.env` — `Object.assign(process.env, env)`
leaves the ambient value standing. Positively re-pin instead: probe the resolved binary's own
`GOROOT` (with `GOROOT` cleared from the *probe's* env, since `go env GOROOT` echoes a set env var
back instead of reporting the binary's real root) and assign that into the env object so the merge
overwrites the stale value:

```ts
const goBin = (await $`mise which go`.text()).trim();
if (!goBin) {
  throw new Error("mise which go returned nothing — run `mise trust`?");
}
const goRoot = (await $`env -u GOROOT ${goBin} env GOROOT`.text()).trim();
Object.assign(process.env, { GOTOOLCHAIN: "local", GOROOT: goRoot });
```

## GOTMPDIR — build scratch never on /tmp

On these machines `/tmp` is tmpfs under a **per-user quota** (observed: 6.16 GiB, 80% of a 7.7G
fs, systemd `usrquota` — invisible until `EDQUOT` since quota-tools isn't installed). A big
`go build` writes GBs of `$WORK` scratch to `$TMPDIR` by default and blows the cap — and a full
`/tmp` quota wedges **every shell machine-wide**, because Claude Code's own Bash output capture
rides `/tmp` too (commands return empty output + exit 1 with no other symptom).

Rule: any project with non-trivial Go builds sets `GOTMPDIR` to a disk-backed dir, created before
use:

```bash
mkdir -p ~/.cache/<project>/gotmp
export GOTMPDIR=~/.cache/<project>/gotmp
```

Give any other big-temp tool in the same pipeline (`TMPDIR`, etc.) the same treatment.

## GOCACHE — one global cache, never per-project

Go's build cache is content-keyed, concurrency-safe, and self-trimming — the default
`~/.cache/go-build` is correct for every project on the machine. Never invent a per-project or
private object cache; each private copy recompiles the whole dependency graph from scratch
(~3 GB per copy was observed).

Some wrapper tools that drive builds (bundlers, transformer hosts) create a **private** `GOCACHE`
only when the env var is unset. Check whether the tool honors an ambient `GOCACHE`, and if so set
it **explicitly** — even to Go's own default path. The assignment is the signal such tools read;
it is not a no-op just because it matches the default.

## Cache placement design rule

- **Content-keyed caches** (object caches, compiled-artifact caches): one shared copy per machine,
  disk-backed.
- **Scratch / per-run working dirs**: isolated per project, worktree, or session — also
  disk-backed, never tmpfs.

A fixed shared path under `/tmp` is the worst of both worlds: cross-session collisions on top of
quota blowouts.
