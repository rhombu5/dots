---
name: dots
description: Inspect the live system for parity with the dots repo. Verifies every config change is captured in chezmoi source, committed, pushed, or explicitly ignored. Trigger when the user asks "is dots in sync?", "check dots parity", "did I capture that config?", "any chezmoi drift?", "anything missing from dots?" — or otherwise wants a focused audit of the dots/chezmoi loop, narrower than a full `/done` wrap-up.
---

# Dots parity check

A focused inspection of the **live ↔ chezmoi source ↔ remote** loop for the dots repo. Report status for each check; surface every ✗/⚠ as a concrete next action. **Don't fix silently** — the value of this skill is the *list* and the user's decision on each item, not a quiet reconciliation. If they want the obvious stuff resolved, they'll follow up.

**Scope: dots only.** Not arch-setup parity, not tasks, not docs, not CI. For the full session wrap-up, point them at `/done`.

## The invariant being checked

Every config worth keeping is **exactly one** of:

- **Captured** — present in `~/src/dots@rhombu5/` (chezmoi source), committed, and pushed.
- **Explicitly ignored** — matched by `~/src/dots@rhombu5/home/.chezmoiignore` with a clear reason.

And the dots repo working tree is clean, and the local branch is in sync with the remote.

Anything else is drift the user should know about.

## Checks

Use `chezmoi source-path` to locate the source tree dynamically (it resolves to `~/src/dots@rhombu5/home` on this machine, but don't hardcode that — let chezmoi answer).

### 1. Live ↔ source drift

```sh
chezmoi diff
chezmoi status     # verb summary: A/M/R for each path
```

Empty `chezmoi diff` output = live matches source. Any output is drift. `chezmoi status` gives the per-path verb:

- `A` (added) — chezmoi would add a file to live that isn't there yet → source has it, live doesn't → run `chezmoi apply`
- `M` (modified) — file differs → either live was edited (run `chezmoi re-add <path>` to capture) or source was edited (run `chezmoi apply` to push) — read the diff to tell which direction is the deliberate one
- `R` (removed) — chezmoi would remove a file from live → source no longer manages it but live still has it

For each drift entry, decide: was the *live* edit deliberate (→ capture with `chezmoi re-add`), was the *source* edit deliberate (→ push with `chezmoi apply`), or is one side stale crud? **Don't blanket-act** — surface and ask.

### 2. Source uncommitted

```sh
cd "$(chezmoi source-path)/.." && git status --short
```

(The source path is `…/dots@rhombu5/home`; the git repo is one level up.)

Anything listed is unstaged or staged-but-uncommitted in the dots source. Flag each. Distinguish this-session work from pre-existing.

### 3. Source unpushed

```sh
cd "$(chezmoi source-path)/.." && git log --oneline @{u}..HEAD
```

Any commits listed haven't reached the remote. Per user prefs: push on feature completion — a single trailing task commit waiting for a feature to land is fine to flag as such, but a stack of multiple local-only commits is a signal something's mid-flight.

### 4. Unmanaged candidates

```sh
chezmoi unmanaged
```

Lists files in the destination directory that aren't managed *and* aren't matched by `.chezmoiignore`. Skim for things that **should** be captured:

- New files in `~/.config/<app>/` for apps already partially managed in source
- New scripts in `~/.local/bin/`
- New systemd user units in `~/.config/systemd/user/`
- New files whose siblings are already managed in `home/`

For each candidate, three options to surface:
- **Capture** → `chezmoi add <path>` (or `chezmoi re-add` if templating applies)
- **Ignore explicitly** → add a pattern to `~/src/dots@rhombu5/home/.chezmoiignore` with an inline comment explaining *why* — `.chezmoiignore` is documentation of the non-capture decision
- **Leave alone** → it's transient/cache/build cruft that chezmoi shouldn't touch *and* doesn't need a `.chezmoiignore` entry (because it's outside the dirs chezmoi already walks)

The goal isn't to capture everything — it's to make every visible non-capture a *deliberate* one. An entry in `.chezmoiignore` is better than silence: the next audit (or the next Claude session) won't have to re-litigate the same file.

### 5. Ignored: still intentional?

Skim `~/src/dots@rhombu5/home/.chezmoiignore`. For each entry, is it still load-bearing?

- Does the ignored path/glob still exist on this machine?
- Does the reason behind it still apply, or has the underlying app/config moved on?
- Any ignores that look like they're guarding against files that no longer exist, or that you'd now want captured?

Light skim only — don't audit every line. Look for obvious staleness.

## Output shape

Compact checklist, then a next-actions section.

```
1. Live ↔ source drift   ✗ ~/.config/foo/bar.conf modified live, not captured
2. Source uncommitted    ✓ working tree clean
3. Source unpushed       ⚠ 1 commit local-only — push when feature lands
4. Unmanaged candidates  ✗ ~/.local/bin/new-script — capture or ignore?
5. Ignored intentional   ✓ skimmed, all current
```

Then list each ✗ and surprising ⚠ as a concrete next action with the exact command (e.g. `chezmoi re-add ~/.config/foo/bar.conf`), and ask the user how to proceed on each. If everything is clear, say so plainly: **"dots in sync — clean."**
