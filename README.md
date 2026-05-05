# dots — chezmoi source tree

Cross-platform dotfiles managed by [chezmoi](https://chezmoi.io). Currently
covers an Arch + Hyprland desktop on Metis (the Dell 7786). WSL and Windows
hosts will land here in subsequent commits, differentiated via chezmoi's
templating (`{{ if eq .chezmoi.os "windows" }}` etc.) and `.chezmoiignore`.

Theme system is **matugen** (Material You from wallpaper) — no Catppuccin.

## Layout (Arch / Hyprland host)

```
dot_config/             → ~/.config/
├── hypr/               → Hyprland: split-file config
├── waybar/             → status bar
├── swaync/             → notification daemon + panel
├── fuzzel/             → app launcher
├── ghostty/            → terminal
├── yazi/, helix/, imv/, zathura/
└── matugen/            → theme generator: config + templates
dot_local/bin/          → ~/.local/bin/   (helper scripts)
dot_local/share/        → ~/.local/share/ (wallpapers, desktop entries)
dot_config/systemd/user/ → user-level systemd units
.chezmoiscripts/        → pre-apply hooks (wallpaper seeding, etc.)
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

Functions defined in [`dot_zsh_aliases`](dot_zsh_aliases) that have enough
surface area to warrant their own page:

- [`cclaude`](docs/cclaude.md) — launch `claude` across multiple project
  roots, auto-loading each root's `.mcp.json` and `.claude/settings.json`.

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
