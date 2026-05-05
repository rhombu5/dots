# dots — chezmoi source tree

Cross-platform dotfiles managed by [chezmoi](https://chezmoi.io). Currently
covers an Arch + Hyprland desktop on Metis (the Dell 7786). WSL and Windows
hosts will land here in subsequent commits, differentiated via chezmoi's
templating (`{{ if eq .chezmoi.os "windows" }}` etc.) and `.chezmoiignore`.

Theme system is **matugen** (Material You from wallpaper) — no Catppuccin.

## Layout (Arch / Hyprland host)

The chezmoi source state lives under `home/` (redirected via
`.chezmoiroot`); everything at the repo root (this `README.md`,
`docs/`, `.github/`, `package.json`, etc.) is repo metadata that
chezmoi never applies.

```
home/dot_config/             → ~/.config/
├── hypr/                    → Hyprland: split-file config
├── waybar/                  → status bar
├── swaync/                  → notification daemon + panel
├── fuzzel/                  → app launcher
├── ghostty/                 → terminal
├── yazi/, helix/, imv/, zathura/
└── matugen/                 → theme generator: config + templates
home/dot_local/bin/          → ~/.local/bin/   (helper scripts)
home/dot_local/share/        → ~/.local/share/ (wallpapers, desktop entries, user-dirs/)
home/dot_config/systemd/user/ → user-level systemd units
home/symlink_{docs,dl,pics}  → ~/{docs,dl,pics} → user-dirs subdirs
```

System-level files for the Arch install (greetd, PAM stacks, limine config)
live in [arch-setup](https://github.com/fnrhombus/arch-setup) and are
installed by its `postinstall.sh`, not chezmoi.

## Bootstrap

On a fresh machine:

```sh
chezmoi init --apply rhombu5/dots
```

That clones this repo into `~/.local/share/chezmoi`, then applies it.

After the first apply, theme-render once so the matugen-derived palettes
exist on disk:

```sh
~/.local/bin/wallpaper-rotate --first
```

## Shell helpers

Functions defined in [`home/dot_zsh_aliases`](home/dot_zsh_aliases) that
have enough surface area to warrant their own page:

- [`cclaude`](docs/cclaude.md) — launch `claude` across multiple project
  roots, auto-loading each root's `.mcp.json` and `.claude/settings.json`.

## Layout decisions

- [`xdg-user-dirs.md`](docs/xdg-user-dirs.md) — the freedesktop user-dirs
  (Desktop / Documents / Downloads / …) live under
  `~/.local/share/user-dirs/`, with short symlinks `~/docs`, `~/dl`,
  `~/pics` for the three frequent ones.
- [`noop.md`](docs/noop.md) — `cclaude` with no path lands in
  `~/.claude/noop/`, where the auto-loaded `CLAUDE.md` puts claude in
  strict-redirect mode: general questions answered here, project-specific
  work bridged to a project-rooted session via a burn-after-reading
  `handoff.md` file.

## Secrets

Source repo is public. Anything sensitive is fetched at apply time from
the user's self-hosted Vaultwarden via chezmoi's `bitwarden` template
functions. Set the server first on any new host:

```sh
bw config server https://hass4150.duckdns.org:7277
bw login
```

## Validation

`.githooks/pre-commit` refuses commits that introduce duplicate
`(MOD, KEY)` pairs, unknown dispatchers, or malformed `bindd` lines under
`dot_config/hypr/`. Activate once per fresh checkout:

```sh
git config core.hooksPath .githooks
```

The same validator runs in CI (`.github/workflows/lint.yml`).
