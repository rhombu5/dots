# Linux / Arch context rules

Load when the task touches: Arch package management, systemd units, the FHS / XDG layout, sudo or polkit prompts, anything inside `/etc/` or `/usr/`, or the chezmoi-managed dotfiles workflow that backs `~/.config/`, `~/.local/`, etc.

## Use `sudonf` for any auth that needs a fingerprint

The fingerprint reader prompt fires invisibly inside the tool call, and the terminal bell is silent in this setup (Ghostty). Use the `sudonf` wrapper (`~/.local/bin/sudonf`, chezmoi-managed in `rhombu5/dots`) for **anything that triggers sudo or polkit auth** — `sudo`, `pkexec`, `pacman -S/-U/-R`, `tee /etc/...`, `systemctl restart` of root services, AUR `makepkg -si`, etc. It fires a Critical notify-send (which swaync plays a sound on via its `critical-sound` script) and dismisses the notification once auth resolves.

```bash
sudonf '<short hint of what is about to run>' <sudo args>
# e.g. sudonf 'pacman -S blueman' pacman -S blueman
```

- The `<short hint>` lets me scan back to see what triggered the cue.
- Multi-step sudo in one Bash call: only `sudonf` the first one — sudo's `timestamp_timeout` covers the rest.
- Across multiple Bash calls within ~5 min: same — first one only.
- After the batch is done, say "no more sudo for the rest of this batch" so I can stop watching the sensor.
- **Don't** fall back to raw `notify-send + sudo` (leftover Critical notifications replay their sound next session). **Don't** use `printf '\a'` (silent here). **Don't** call `paplay` directly (the wrapper handles it).

## System changes go to both the live system AND the dotfiles repo

When instructed to make any system preference, configuration, or other persistent change: apply it to the actual running system AND mirror it into the appropriate repo — usually the chezmoi dotfiles repo at `~/src/dots@rhombu5/` (`git@github.com:rhombu5/dots.git`, source state under `home/`), or the arch-setup repo for bootstrap-level changes.

For **chezmoi-managed** files (check with `chezmoi managed | grep <path>`):
- Edit the live file, then `chezmoi re-add <path>` to sync source ← live (or use `chezmoi edit <path>` to edit the source directly and `chezmoi apply`).
- Verify with `chezmoi diff <path>` — empty output means source and live are in sync.
- Make sure the chezmoi repo's working tree is clean afterwards.

Always make **immediate, atomic commits and push**. One logical change per commit. Don't batch unrelated changes. Don't leave the repo dirty across turns. Match the existing commit-message style in the repo (check `git log` first).

## Reinstall reproducibility — three layers

Persistent state lives in one of three layers. Pick the right one when adding a change, and trace all three when checking what survives a reinstall:

1. **Install scripts** (`arch-setup`): system-level config (`/etc/`, `/usr/local/`, package lists, services).
2. **chezmoi** (`rhombu5/dots`): user configs that should be identical across installs. chezmoi runs *after* the postinstall script and **can overwrite anything postinstall just wrote** — for any chezmoi-managed path, the chezmoi source is the source of truth, not the postinstall HEREDOC content.
3. **Planters** (`~/.local/share/arch-setup-bootstraps/`, shipped via dots, dispatched by a `.zshrc.d` runner): user-specific state that needs interactive setup or external auth (gh, SSH agent, etc.). Planters self-delete on success — a planter file still on disk means it never ran successfully.

Direct edits to live `$HOME` files outside these layers are ephemeral. Don't conclude "this drifted" without checking the chezmoi source AND the relevant planter first.

## Always follow FHS (and XDG for user paths)

Stick to the Filesystem Hierarchy Standard for system paths and the XDG Base Directory spec for user paths. Don't invent locations or scatter files in `$HOME`.

- **System (FHS):** `/etc/` config, `/var/lib/` state, `/var/log/` logs, `/usr/local/` locally-built system-wide, `/opt/` self-contained third-party bundles, `/srv/` service data, `/tmp/` ephemeral.
- **User (XDG):** `~/.config/` (`$XDG_CONFIG_HOME`), `~/.local/share/` (`$XDG_DATA_HOME`), `~/.local/state/` (`$XDG_STATE_HOME`), `~/.cache/` (`$XDG_CACHE_HOME`), `~/.local/bin/` for user binaries, `$XDG_RUNTIME_DIR` (typically `/run/user/$UID/`) for runtime sockets.

When a tool defaults to a non-XDG dotfile path (e.g. `~/.foorc`) but offers a config option or env var to relocate, prefer the XDG path. When in doubt about which directory fits, search the spec rather than guessing.
