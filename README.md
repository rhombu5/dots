# dots — chezmoi source tree

Cross-platform dotfiles managed by [chezmoi](https://chezmoi.io). Currently
covers an Arch + Hyprland desktop on Metis (the Dell 7786). WSL and Windows
hosts will land here in subsequent commits, differentiated via chezmoi's
templating (`{{ if eq .chezmoi.os "windows" }}` etc.) and `.chezmoiignore`.

Theme system is **matugen** (Material You from wallpaper) — no Catppuccin.

System-level Arch install (boot, LUKS, TPM, PAM, packages, services) is in
the companion repo
**[fnrhombus/arch-setup](https://github.com/fnrhombus/arch-setup)** — its
`postinstall.sh §13` clones this repo and applies it.

## Bootstrap

On a fresh machine:

```sh
chezmoi init --apply rhombu5/dots
```

Then theme-render once so the matugen-derived palettes exist on disk:

```sh
~/.local/bin/wallpaper-rotate --first
```

## Layout

The chezmoi source state lives under `home/` (redirected via
`.chezmoiroot`); everything at the repo root (this `README.md`,
`docs/`, `.github/`, `package.json`, `.githooks/`) is repo metadata that
chezmoi never applies.

```
home/dot_config/             → ~/.config/
home/dot_local/bin/          → ~/.local/bin/   (helper scripts)
home/dot_local/share/        → ~/.local/share/ (wallpapers, applications, user-dirs/)
home/dot_config/systemd/user/ → user-level systemd units
home/dot_claude/             → ~/.claude/      (Claude Code global config)
home/dot_zshrc, dot_zprofile, dot_zshenv, dot_zsh_aliases, dot_zshrc.d/
home/dot_p10k.zsh, dot_tmux.conf, dot_gitconfig
home/private_dot_ssh/        → ~/.ssh/   (mode 0700; bw-agent + host shortcuts)
home/symlink_{docs,dl,pics}  → short symlinks into ~/.local/share/user-dirs/
```

## What's in here

Comprehensive inventory of everything chezmoi applies. System-level pieces
(packages, services, `/etc/`, PAM, TPM, boot) live in
[arch-setup](https://github.com/fnrhombus/arch-setup#what-gets-set-up).

### Hyprland desktop

- **`hypr/`** — split-file Hyprland config
  - `hyprland.conf` — entry point; sources fragments below
  - `monitors.conf`, `workspaces.conf`, `input.conf`, `decoration.conf`,
    `animations.conf`, `borders.conf`, `binds.conf`, `scrolling.conf`,
    `plugins.conf`, `exec.conf`
  - `hypridle.conf` — idle/lock/dpms timing
  - `hyprlock.conf` — lock screen
  - `post-plugins.d/{hyprgrass,hyprspace}.conf` — plugin-specific config
  - `runtime-layouts.conf` — written by `hypr-layout-toggle`, persists per-workspace dwindle/scrolling state
  - `runtime-monitors.conf` — written by `hypr-lid-sync`, persists the clamshell eDP-1 disable across `hyprctl reload`
- **`waybar/`** — status bar (`config.jsonc`, `style.css`, custom `modules/network.sh` and `modules/theme-toggle.sh`)
- **`swaync/`** — notification centre (`config.json`, matugen-themed `style.css`)
- **`fuzzel/`** — application launcher (`fuzzel.ini`)
- **`wleave/`** — power menu (`layout.json`)
- **`xdg-desktop-portal/`** — `hyprland-portals.conf` for portal backend selection

### Wallpaper / per-workspace theming

- **`matugen/`** — Material You palette generator
  - `config.toml` — pipeline definition with 15+ component templates
  - `templates/` — output templates for ghostty, helix, yazi, zathura, gtk3/4, qt5/6, tmux, regreet, hyprlock, and shared accent (`shared-accent.{css,conf,ini}`)
- **`themes/`** — static base + matugen-rendered accent files; pill-mode workspace indicator variants (bold / subtle / layered)
- **`hyprmural/`** — per-workspace wallpaper config + accent extraction pipeline. `hyprmural.conf` runs in randomize mode (fresh shuffle each session, in-place reshuffle on `Super+Shift+W`); `hook.sh` chains `accent.py` (per-window border colors) and `pill-accents.py` (waybar workspace pills, derived from `$XDG_RUNTIME_DIR/hyprmural/assignments.json`); `vibrant.py` is the shared swatch extractor.
- **`qt5ct/`, `qt6ct/`** — Qt 5/6 style + palette integration

### Apps

| Dir | App | Notes |
|---|---|---|
| `ghostty/` | Ghostty terminal | Theme via `themes/create_matugen` (live-reload via SIGUSR2) |
| `helix/` | Helix editor | `config.toml`; theme `~/.config/helix/themes/matugen.toml` |
| `nvim/` | Neovim editor | kickstart-modular base (`vim.pack` + Mason); `tsgo` primary TS LSP with dormant `vtsls` fallback (`.nvim-ts-node` sentinel, `<leader>ts` toggle); conform format-on-save; motion-learning plugins (hardtime, precognition, flash, vim-be-good) |
| `yazi/` | Yazi file manager | Opener rules for helix / xdg-open / nautilus / mpv / imv / zathura |
| `imv/` | Image viewer | Vim-style bindings |
| `zathura/` | PDF/document viewer | Sources matugen colour fragment |
| `remmina/` | RDP client | `Callisto.remmina` profile for the home server |

### Helper scripts (`~/.local/bin/`)

**Hyprland UX**
- `hypr-cheatsheet` — fuzzel-launched searchable keybind reference (reads live via `hyprctl`)
- `hypr-edge-nav` — geometry-aware focus / window-move with workspace escalation
- `hypr-layout-{floating,tiling,tabbed}` — re-arrange all windows in current workspace
- `hypr-layout-toggle` — flip active workspace between dwindle and scrolling (per-workspace persistent state)
- `hypr-panel-toggle` — toggle waybar visibility; recovers from crash or detached-surfaces lock/unlock state
- `waybar-healthcheck` — probe waybar's layer surfaces; used by hypridle's `unlock_cmd` to self-heal post-unlock
- `hypr-plugins-on-login` — load Hyprland plugins + their post-plugins.d configs (idempotent)
- `if-tilemode`, `if-scrollmode` — conditional dispatchers (only run if active workspace matches layout)
- `validate-hypr-binds` — parse `binds.conf` + fragments for duplicates and unknown dispatchers (chezmoi pre-apply hook + CI)

**Hardware / 2-in-1**
- `lid-handler` — custom lid-close behaviour (hibernate, or disable eDP-1 on AC + external monitor)
- `hypr-lid-sync` — regenerate `runtime-monitors.conf` from lid + external-monitor truth (called by `lid-handler` and `hypr-plugins-on-login`)
- `tablet-mode-toggle` — flip kbd / touchpad / OSK for tablet folding
- `tablet-mode-watcher` — poll IIO hinge-angle sensor; calls toggle at 180° crossings (systemd user service)
- `display-watchdog` — Hyprland blackout-recovery daemon (extracted-repo candidate — see `project_display_watchdog.md`)

**Theme / wallpaper**
- `theme-toggle` — flip dark / light, re-run matugen, broadcast via gsettings
- `wallpaper-rotate` — pick next wallpaper, set via awww, regenerate matugen palette

**System helpers**
- `claude-askpass` — `SUDO_ASKPASS` helper that pulls password from Bitwarden (unattended `sudo -A`)
- `sudonf` — sudo wrapper with desktop notification while waiting for auth
- `control-panel` — fuzzel-launched system settings menu (display, wifi, bluetooth, sound, theme, wallpaper, power, lock, pacseek)

### systemd user services / timers (`~/.config/systemd/user/`)

| Unit | Triggers when |
|---|---|
| `hyprland-session.target` | Hyprland session boot — bound to `graphical-session.target` |
| `tablet-mode-watcher.service` | Hinge-angle polling daemon; restarts on failure |
| `hyprmural.service` | Per-workspace wallpaper layer (`Restart=always`, journald logging) |
| `hypridle.service` | Upstream unit + drop-in raising `Restart=on-failure` → `Restart=always` (silent exits observed; idle daemon must not stay dead) |
| `waybar.service` | Upstream unit + drop-ins (`ExecStartPre=sleep 1.5`, `Restart=always`, flap-cap; `MemoryMax=512M` + `MemorySwapMax=256M` + `OOMPolicy=kill` after the 2026-07 leak incidents) — auto-respawn on GdkMonitor UAF crashes (Waybar #3530/#4361) and on OOM-kill at the cap |
| `cliphist.service` | Upstream unit (`wl-paste --watch cliphist store`) — clipboard history |
| `swayosd-server.service` | OSD server for volume / brightness / capslock keys |
| `iio-hyprland.service` | IIO sensor → Hyprland transform daemon (auto-rotate) |
| `display-watchdog.service` | Lid-aware blackout-recovery watchdog |
| `wallpaper-rotate.service` | One-shot rotation + matugen regen (requires `WAYLAND_DISPLAY`) |
| `wallpaper-rotate.timer` | Static (no `[Install]`); rotation is user-initiated only — Super+Shift+W, control-panel, or manual `wallpaper-rotate`. Re-arm by restoring `[Install] WantedBy=timers.target` |
| `dropbox.service` | After `graphical-session`; no-op until cloud-storage-auth planter links account |
| `rclone-gdrive-bisync.service` | Bidirectional `gdrive:` ↔ `~/gdrive` (resilient + max-delete safeguard; filter excludes Google Photos videos via `~/.config/rclone/gdrive-filters.txt`) |
| `rclone-gdrive-bisync.timer` | Every 5 min, 2 min boot delay, 30 s randomization |
| `rclone-dropbox-claude-bisync.service` | Bidirectional `dropbox:.claude` ↔ `~/.claude` (memory + plans only, scoped via `~/.config/rclone/claude-filters.txt`) |
| `rclone-dropbox-claude-bisync.timer` | Every 5 min, 2 min boot delay, 30 s randomization |

### Shell environment

- **`dot_zshenv`** — sourced by every zsh; routes `SSH_AUTH_SOCK` to the Bitwarden agent if present
- **`dot_zprofile`** — login-shell hook on `tty1`: `exec uwsm start hyprland-uwsm.desktop` (falls back to bare Hyprland if uwsm missing)
- **`dot_zshrc`** — interactive shell setup
  - zgenom plugin manager + powerlevel10k instant prompt
  - 100 k history, dedupe + sharing
  - fzf-tab completion
  - Plugins: ohmyzsh (sudo, colored-man-pages, extract, command-not-found, docker, docker-compose, npm, pip, dotnet), fast-syntax-highlighting, zsh-autosuggestions, zsh-history-substring-search, zsh-completions, fzf-tab, fzf-zsh-plugin, powerlevel10k
  - Tool inits: mise, zoxide, direnv
- **`dot_zsh_aliases`** — navigation (`..`, `...`), `ls`/`ll`/`la`/`lt` via eza, `cat` via bat, `fnc` shortcut for `fnclaude`
- **`dot_zshrc.d/`** — modular drop-in fragments
  - `arch-bootstrap-runner.zsh` — fires `~/.local/share/arch-setup-bootstraps/*.sh` planters on first interactive shell, then self-removes the marker
- **`dot_p10k.zsh`** — Powerlevel10k rainbow / 2-line prompt
- **`dot_tmux.conf`** — `Ctrl+a` prefix, mouse, 50 k history, focus-events on (Helix), RGB override for Ghostty, splits open in CWD, matugen colours
- **`dot_gitconfig`** — pulls in `~/.gitconfig.local` for the per-host user identity / signing key
- **`private_dot_ssh/private_config`** — `~/.ssh/config` (mode 0600 in mode 0700 dir); `Host *` wildcard wires `IdentityAgent ~/.bitwarden-ssh-agent.sock` + per-host shortcuts (`Host callisto` → `thoma@callisto.rhombus.rocks`)

### Claude Code (`~/.claude/`)

- **`CLAUDE.md`** — global rules: when-in-doubt-discuss, 5-attempt loop, context-file loading, commit-attribution policy
- **`CLAUDE.linux.md`** — Arch / pacman / AUR / systemd / FHS / sudo / polkit / chezmoi guidance
- **`CLAUDE.git.md`** — clone / push / PR conventions, repo directory layout, GitHub org selection
- **`settings.json`** — harness config (effort level, push notifications, additional working dirs)

### fnclaude (`~/.config/fnclaude/`)

- **`noop/CLAUDE.local.md`** — user overlay for fnclaude's noop landing zone (the global handoff harness for queries with no project context). The base `CLAUDE.md` and `handoff.template.md` are embedded in the [fnclaude binary](https://github.com/fnrhombus/fnclaude) and lazy-seeded into this dir; only the `.local.md` overlay is dots-managed. See [`docs/noop.md`](docs/noop.md).

### File layout (`~/.local/share/`)

- **`user-dirs/`** — XDG directories live here (Documents, Downloads, Pictures, Music, Videos, Projects, Desktop, Public, Templates) — see [`docs/xdg-user-dirs.md`](docs/xdg-user-dirs.md)
- **`applications/callisto-rdp.desktop`** — Remmina launcher for the Callisto RDP host
- **`wallpapers/`** — 24 curated wallpapers (Arch logo variants, Linux landscapes, memes)
- **`doc/display-watchdog/README.md`** — display-watchdog architecture notes

Symlinks at the home root for the three frequent ones:

- `~/docs` → `~/.local/share/user-dirs/Documents`
- `~/dl` → `~/.local/share/user-dirs/Downloads`
- `~/pics` → `~/.local/share/user-dirs/Pictures`

## Layout decisions

- [`xdg-user-dirs.md`](docs/xdg-user-dirs.md) — the freedesktop user-dirs
  (Desktop / Documents / Downloads / …) live under
  `~/.local/share/user-dirs/`, with short symlinks `~/docs`, `~/dl`,
  `~/pics` for the three frequent ones.
- [`noop.md`](docs/noop.md) — `fnclaude` with no path lands in
  `~/.config/fnclaude/noop/`, where the binary-embedded base `CLAUDE.md`
  (plus this dots repo's `CLAUDE.local.md` overlay) puts claude in
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
