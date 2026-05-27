# Linux / Arch context rules

## Two sudo wrappers — pick the right one

The fingerprint reader prompt fires invisibly inside the tool call, and the terminal bell is silent in this setup (Ghostty). Two wrappers cover the cases:

- **`sudoa`** — *unattended.* Pulls the local password from Bitwarden via `~/.local/bin/claude-askpass` and feeds it to `sudo -A`. No prompt, no notification, no swipe. Use this when running a batch where the user can't or shouldn't be at the keyboard.
- **`sudonf`** — *interactive, with audible cue.* Plays a Critical notification + sound (so the user knows to swipe / type) and self-clears the notification when sudo returns.

### When to use which

- **Default to `sudoa`** for any sudo call that doesn't need user input — system inspections, package installs/removes once decided, file writes the user has already approved, batched setup steps. Pre-req: `bwu` once per fresh login (caches the master password in libsecret); after that sudoa is silent forever.
- **Use `sudonf`** when the user is genuinely choosing whether to authenticate — e.g. you're asking them to validate a destructive change *via the auth itself*, or `bwu` hasn't been seeded yet on this login.
- **Don't mix** sudonf and sudoa in one batch. Pick one.

### `sudoa` usage

```bash
sudoa <cmd>     # = SUDO_ASKPASS=~/.local/bin/claude-askpass sudo -A <cmd>
```

If `claude-askpass` errors (master password not cached, vault sync stale, ambiguous Bitwarden item), sudo prints the askpass error to stderr — read it and fix the underlying issue. Common case: tell the user to run `bwu` once.

Trust model: anyone with an unlocked vault can `sudoa`. Same surface as the Bitwarden desktop app's "Unlock with system authentication" toggle.

### `sudonf` usage

```bash
sudonf '<short hint of what is about to run>' <sudo args>
# e.g. sudonf 'pacman -S blueman' pacman -S blueman
```

- The `<short hint>` lets the user scan back to see what triggered the cue.
- Multi-step sudo in one Bash call: only `sudonf` the first one — sudo's `timestamp_timeout` covers the rest.
- Across multiple Bash calls within ~5 min: same — first one only.
- After the batch is done, say "no more sudo for the rest of this batch" so the user can stop watching the sensor.
- **Don't** fall back to raw `notify-send + sudo` (leftover Critical notifications replay their sound next session). **Don't** use `printf '\a'` (silent here). **Don't** call `paplay` directly (the wrapper handles it).

## Bitwarden — you can unlock it yourself, and read items without leaking values

The vault has a wrapper-and-cache pattern set up so Claude can interact with it without round-tripping through the user. Use it instead of asking the user to paste secrets into chat (paste = leak).

**Unlocking.** The `bwu` shell function caches the master password in libsecret on first use; subsequent calls are silent. After `bwu` succeeds, a session token is also cached in libsecret under `service=bitwarden type=session` and exported as `BW_SESSION`.

From within a fresh Bash tool call (where env vars don't persist), fetch the cached session inline:

```bash
SESSION=$(secret-tool lookup service bitwarden type session)
BW_SESSION=$SESSION bw status   # verify still unlocked
```

If the cached session is stale, `bw status` reports `"status":"locked"` — run `bwu` to refresh it, then re-fetch from secret-tool.

**Reading items without leaking values.** Two anti-leak rules:

1. **Inspect structure, not values.** When finding the right item / field, use `jq` projections that show only `id`, `name`, and field *names* — never `.value` or `.login.password` — until you know exactly which field you want.
2. **Pipe values straight into the consuming tool.** Once you've identified the field, fetch and pipe in one shell expression so the secret never appears in tool output:

   ```bash
   SESSION=$(secret-tool lookup service bitwarden type session)
   BW_SESSION=$SESSION bw get item <ITEM_ID> \
     | jq -r '.fields[] | select(.name=="<FIELD>") | .value' \
     | gh secret set <NAME> -R <owner>/<repo>     # gh reads from stdin
   ```

   Don't echo, print, store in a variable that gets logged, or pass it as a `--body=` flag (logged in command line).

**Sync before searching.** `bw list` / `bw get` use the local cache. If the user just added or changed a record, run `bw sync` first or you'll miss the update.

**When to fall back to the user.** Only when libsecret itself is locked (greeter / fresh boot before login) — `secret-tool lookup` returns empty *and* `bwu` would need fresh password entry that no tty in the tool call supports. In that case ask the user to run `bwu` via `!`. Otherwise: just do it.

## System changes go to both the live system AND the dotfiles repo

When instructed to make any system preference, configuration, or other persistent change: apply it to the actual running system AND mirror it into the appropriate repo — usually the chezmoi dotfiles repo at `~/src/dots@rhombu5/` (`git@github.com:rhombu5/dots.git`, source state under `home/`), or the arch-setup repo for bootstrap-level changes.

For **chezmoi-managed** files (check with `chezmoi managed | grep <path>`):
- Edit the live file, then `chezmoi re-add <path>` to sync source ← live (or use `chezmoi edit <path>` to edit the source directly and `chezmoi apply`).
- Verify with `chezmoi diff <path>` — empty output means source and live are in sync.
- Make sure the chezmoi repo's working tree is clean afterwards.

Commit and push cadence inherits from CLAUDE.md's "Commit discipline" — the point here is that the live change and its mirror travel together.

## Reinstall reproducibility — three layers

Persistent state lives in one of three layers. Pick the right one when adding a change, and trace all three when checking what survives a reinstall:

1. **Install scripts** (`arch-setup`): system-level config (`/etc/`, `/usr/local/`, package lists, services).
2. **chezmoi** (`rhombu5/dots`): user configs that should be identical across installs. chezmoi runs *after* the postinstall script and **can overwrite anything postinstall just wrote** — for any chezmoi-managed path, the chezmoi source is the source of truth, not the postinstall HEREDOC content.
3. **Planters** (`~/.local/share/arch-setup-bootstraps/`, source-of-truth at `arch-setup/phase-3-arch-postinstall/planters/`, planted by postinstall §13b, dispatched by the `.zshrc.d/arch-bootstrap-runner.zsh` dispatcher in dots): user-specific state that needs interactive setup or external auth (gh, SSH agent, etc.). Planters self-delete on success — a planter file still on disk means it never ran successfully.

Direct edits to live `$HOME` files outside these layers are ephemeral. Don't conclude "this drifted" without checking the chezmoi source AND the relevant planter first.

## Always follow FHS (and XDG for user paths)

Stick to the Filesystem Hierarchy Standard for system paths and the XDG Base Directory spec for user paths. Don't invent locations or scatter files in `$HOME`.

- **System (FHS):** `/etc/` config, `/var/lib/` state, `/var/log/` logs, `/usr/local/` locally-built system-wide, `/opt/` self-contained third-party bundles, `/srv/` service data, `/tmp/` ephemeral.
- **User (XDG):** `~/.config/` (`$XDG_CONFIG_HOME`), `~/.local/share/` (`$XDG_DATA_HOME`), `~/.local/state/` (`$XDG_STATE_HOME`), `~/.cache/` (`$XDG_CACHE_HOME`), `~/.local/bin/` for user binaries, `$XDG_RUNTIME_DIR` (typically `/run/user/$UID/`) for runtime sockets.

When a tool defaults to a non-XDG dotfile path (e.g. `~/.foorc`) but offers a config option or env var to relocate, prefer the XDG path. When in doubt about which directory fits, check the spec rather than guessing.
