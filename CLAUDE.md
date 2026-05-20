# CLAUDE.md

Project-level instructions for Claude Code sessions working in this repo.

## What this repo is

The chezmoi source tree for Tom's user-level configuration — Hyprland,
themes, helper scripts, shell environment, app configs. The actual source
state lives under `home/` (redirected via `.chezmoiroot`); everything at the
repo root is repo metadata that chezmoi never applies.

System-level Arch install (boot, LUKS, TPM, packages, services, PAM, `/etc`)
is in the companion repo
**[fnrhombus/arch-setup](https://github.com/fnrhombus/arch-setup)**. If a
proposed change would belong in `/etc/`, `/usr/`, or as a pacman/AUR
package, it goes there — not here.

## Authoring rules

- **Never edit live `~/` files directly.** Always edit the chezmoi source
  under `home/`, then run `chezmoi apply` (or let the user do it). Direct
  edits to `~/.config/...` get clobbered the next time chezmoi runs.
- **Hyprland config is split-file.** `home/dot_config/hypr/hyprland.conf`
  sources fragments (binds, monitors, decoration, animations, etc.). Add
  new keybinds to `binds.conf`, not the entry point.
- **`validate-hypr-binds` is the gate.** The pre-commit hook
  (`.githooks/pre-commit`) and CI (`.github/workflows/lint.yml`) reject
  commits that introduce duplicate `(MOD, KEY)` pairs, unknown
  dispatchers, or malformed `bindd` lines under `dot_config/hypr/`.
- **Theming is matugen, not Catppuccin.** All themed apps source colours
  from matugen-rendered fragments under `~/.config/themes/` or
  app-specific paths. Don't hardcode hex values; add a new template under
  `home/dot_config/matugen/templates/` if a new app needs theming.
- **Shell plugin list is locked** to the set in `home/dot_zshrc`. Mirror
  any plugin change in arch-setup's `wsl-cli-test.sh` so the WSL shakedown
  catches breakage early.

## When `chezmoi verify` fails in pre-commit

The pre-commit hook's `chezmoi verify` check exists to surface
out-of-sync source. It's nearly always one of two cases, both of which
the user will resolve later out-of-band:

1. A parallel Claude session in another worktree has drifted state that
   this session doesn't know about.
2. The user made a live config change and hasn't run `chezmoi re-add` yet.

**On verify failure:**

1. Read the `chezmoi diff` output the hook already printed.
2. Retry the commit with `git commit --no-verify`.
3. **Surface the drifted files in your user-visible response** — a
   short list of paths, one per line. The user acts on the report
   asynchronously. Don't bury the report under a generic "commit
   succeeded" line, and don't try to `chezmoi apply` / `re-add` to
   "fix" the drift yourself — it isn't yours to fix.

This intentionally inverts the hook's own "use `--no-verify` sparingly!"
guidance: for chezmoi verify specifically, `--no-verify` is the default
response and the drift disclosure is what keeps the check useful.

## Conventions

- **Keep the README "What's in here" inventory current.** Whenever you add,
  remove, or rename a config dir under `home/dot_config/`, a helper script
  under `home/dot_local/bin/`, a systemd user unit, a matugen template, or
  any other observable artifact chezmoi applies, update
  [`README.md`](README.md) in the same commit. The README is the
  human-facing index of "what does this dotfile repo ship" — drift makes
  the companion arch-setup README's link to it misleading.
- **chezmoi naming**: `executable_` prefix for executable files, `dot_` for
  files that should be `.`-prefixed at the destination, `private_` for
  files that should be `chmod 600`, `symlink_` for chezmoi-managed
  symlinks. Don't rename without checking the chezmoi docs.
- **Public repo.** Source is public; secrets come from self-hosted
  Vaultwarden via chezmoi `bitwarden` template functions at apply time.
  Never commit a credential, even one for a "test" account.

## Working style

- **Parallelize independent work.** Multiple tool calls with no
  dependencies go in a single message, not serialized turns.
- **Subagent model selection** (mirrors the global rule): prose-shaped
  work — README rewrites, doc drafting, commit messages — runs on Sonnet
  via subagents. Substance and tricky design stay on the main thread.
