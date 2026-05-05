# XDG user-dirs relocation

The freedesktop xdg-user-dirs (Desktop, Documents, Downloads, Music, Pictures, Public, Templates, Videos, Projects) are relocated out of `$HOME` and into a single canonical store under `$XDG_DATA_HOME`. Three of them get short ergonomic symlinks back at the top of `$HOME`.

## Layout

```
~/.local/share/user-dirs/
├── Desktop/        ← XDG_DESKTOP_DIR
├── Documents/      ← XDG_DOCUMENTS_DIR
├── Downloads/      ← XDG_DOWNLOAD_DIR
├── Music/          ← XDG_MUSIC_DIR
├── Pictures/       ← XDG_PICTURES_DIR
├── Projects/       ← XDG_PROJECTS_DIR (non-standard, app-added)
├── Public/         ← XDG_PUBLICSHARE_DIR
├── Templates/      ← XDG_TEMPLATES_DIR
└── Videos/         ← XDG_VIDEOS_DIR

~/docs → ~/.local/share/user-dirs/Documents
~/dl   → ~/.local/share/user-dirs/Downloads
~/pics → ~/.local/share/user-dirs/Pictures
```

## Why

- `$HOME` stays uncluttered: only the three frequently-typed dirs surface as short symlinks.
- The TitleCased canonical names live somewhere XDG-spec-correct (`$XDG_DATA_HOME` is exactly where durable user data goes). No invented top-level dirs.
- Apps that read `XDG_*_DIR` env vars get the canonical absolute paths, so they're stable; the symlinks are pure ergonomics for the human at the shell.
- Music, Videos, and Pictures are candidates for cloud-storage redirection later — when that happens, only the `XDG_<name>_DIR` line in `~/.config/user-dirs.dirs` changes.

## How chezmoi materializes this on a fresh apply

The chezmoi source tree (`home/`) holds:

- `home/dot_config/user-dirs.dirs` — points each `XDG_*_DIR` at its canonical path.
- `home/dot_local/share/user-dirs/<Name>/.keep` — empty placeholder files. Their only purpose is to make git track the otherwise-empty dirs and force chezmoi to materialize them on a fresh apply, so the symlinks don't dangle.
- `home/symlink_docs`, `home/symlink_dl`, `home/symlink_pics` — chezmoi-style symlink declarations.

chezmoi's apply order processes files-and-dirs first, then symlinks. By the time the three symlinks land in `$HOME`, their targets under `~/.local/share/user-dirs/` already exist.

## `xdg-user-dirs-update` is left running

`~/.config/user-dirs.conf` is **not** set to `enabled=False`. The autostart updater keeps running on login as it would anywhere else; it reads the rewritten `user-dirs.dirs`, sees the canonical paths, and does nothing further (it ensures those paths exist, which they do via chezmoi). It does not recreate the original TitleCased dirs at `$HOME` because they aren't in the config anymore.

## Adding new content

Drop files anywhere under `~/.local/share/user-dirs/<Name>/` (or via the symlinks `~/docs`, `~/dl`, `~/pics`). Don't `chezmoi add` user content — the dotfiles repo is for configs and infrastructure, not personal files. The `.keep` markers are the only files chezmoi tracks inside this tree.
