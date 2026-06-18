# noop overlay — this machine's personalization

Personal additions and refinements to the noop-router instructions that fnclaude injects as its system prompt. Claude Code auto-loads this file from cwd alongside that system prompt; rules here can clarify, scope, or override anything there.

**Edits go here, not in the base.** If you have any reason to want to add a rule, refine an existing one, or capture a machine-specific quirk, this file is the target — the base noop-router prompt is read-only (it ships in the install dir at `/usr/share/fnclaude/prompts/noop-router.md`, root-owned, regenerated on each fnclaude upgrade). The chezmoi source for this overlay is `~/src/dots@rhombu5/home/dot_config/fnclaude/noop/CLAUDE.md`.

---

## User-prefs maintenance — chezmoi specifics

When the base's "user-prefs maintenance" exception applies, this machine uses **chezmoi** as the dotfile manager:

1. **Edit the chezmoi source, not the live file.** The truth is at `~/src/dots@rhombu5/home/dot_claude/<file>`. Editing the live `~/.claude/<file>` directly works once but gets overwritten by the next `chezmoi apply` from any session.
2. **Apply afterwards:** `chezmoi apply ~/.claude/<file>` to sync the live copy. Verify with `chezmoi diff ~/.claude/<file>` (empty output = clean).
3. **Commit and push the `dots` repo** atomically — one logical change per commit, immediately. `Read ~/.claude/CLAUDE.git.md` first if you haven't this session, for the SSH/commit conventions.
4. **If you create a new `CLAUDE.<context>.md`,** add a one-line entry to the *Context files* index in `~/.claude/CLAUDE.md` so it's discoverable next session.

---

## One-off system changes — this machine's mirror targets

The base's "one-off system change" exception talks generically about a dotfile / system-setup repo. Concretely on this machine:

- **User-level dotfiles** live in `dots` (chezmoi-managed). Mirror flow: edit live → `chezmoi re-add <file>` → commit + push.
- **System-level / bootstrap** lives in `arch-setup` — package lists, services, bootstrap scripts. Mirror flow: apply live → update the corresponding file in arch-setup → commit + push.
- **Mirror rule's authoritative source:** [`~/.claude/CLAUDE.linux.md`](../CLAUDE.linux.md). Re-read it if it hasn't loaded this session before making any system-level change.

Sudo aliases on this machine: `sudoa` for unattended (auto-enters password), `sudonf` for interactive. Prefer `sudoa` from a script context; use `sudonf` when the user is at the keyboard.

---

## Clipboard utility on this machine

Wayland — use `wl-copy` for the relaunch-command clipboard step in the base's "How to redirect" section. No need to consult the platform-switcher list there; `wl-copy` is correct here.

---

## Project context-file conventions

The user-level `~/.claude/CLAUDE.md` indexes sibling `CLAUDE.<context>.md` files that should be loaded on context shift. Notable ones:

- `CLAUDE.linux.md` — anything inside `/etc/`, `/usr/`, systemd units, package management, chezmoi-managed dotfiles
- `CLAUDE.git.md` — git operations (clone/push/PR), repo placement on disk, GitHub owner selection

When the base's "How to redirect" step 1 mentions "if your user-level CLAUDE context has clone-path conventions" — yes, it does. That's `~/.claude/CLAUDE.git.md`.

---

## Customization disambiguation — maintainer's special case

You're working with the maintainer of `fnclaude`. When the maintainer asks to change noop-router behavior — add a rule, refine the classifier, tweak a workflow — you can't tell from wording alone whether they mean:

- **(a) Personalize for this machine** — update this overlay (live: `~/.config/fnclaude/noop/CLAUDE.md`, source: `~/src/dots@rhombu5/home/dot_config/fnclaude/noop/CLAUDE.md`). Lands in the next dots commit. Scope: this machine only.
- **(b) Change the binary-shipped default** — update `~/src/fnclaude@fnclaude/prompts/noop-router.md` in the fnclaude repo. Requires feature branch + PR + release cycle. Scope: every fnclaude user on the next release.

> **Active repo:** fnclaude development lives in **`fnclaude@fnclaude`**. The old `fnclaude@fnrhombus` repo is **dead** — don't target it for any fnclaude work or handoff.

The distinction matters because the maintainer wears both hats and the same request shape (*"add a rule that..."*) means different things depending on which hat.

**Default: ask.** Before editing either file, surface the question explicitly: *"Do you want this in your noop overlay (machine-local, dots commit) or in the fnclaude source (ships with the next release)?"* Don't guess from wording alone.

Only one exception: if the change is **obviously and exclusively about this machine** (e.g., the clipboard utility, a path under `~/`, this user's dotfile-manager choice), the overlay is the right place — don't ask. Anything that could plausibly apply to any fnclaude user (classifier rules, handoff conventions, bucket definitions) → ask.
