# display-watchdog

Tiny Python daemon that recovers Hyprland from total display blackout. Listens on the compositor's IPC for monitor-removal events; when the last usable monitor goes dark, runs one of two configurable shell commands depending on laptop-lid state.

## The problem

On a laptop docked to an external display with the internal panel DPMS-off (or `monitor=NAME,disable`d), unplugging or powering off the external leaves you with no usable display. Hyprland doesn't auto-recover. Existing tools handle related cases but not this one:

- **kanshi**, **shikane**, **HyprDynamicMonitors** — apply monitor profiles based on which outputs are attached. They could enable the internal display when externals disappear, but they have no notion of lid state, so they'd un-blank the internal panel even when the lid is closed.
- **Hyprland binddl + lid scripts** — handle the lid-switch event, but never the external-disappears-while-internal-is-already-off event.

This daemon fills that gap.

## Behavior

On every `monitorremoved` / `monitorremovedv2` event from Hyprland's IPC:

1. Re-evaluate state via `hyprctl monitors -j`.
2. Count monitors with `dpmsStatus=true`. (Disabled monitors are absent from this list, so they correctly count as zero.)
3. If none → blackout. Read `/proc/acpi/button/lid/*/state`:
   - **closed** → run `--lid-closed-action`
   - **open** (or no lid sensor) → run `--lid-open-action`

Recovery commands are fire-and-forget (`Popen` with `sh -c`). The daemon doesn't wait or retry.

## Usage

```sh
display-watchdog \
    --lid-open-action 'hyprctl reload && hyprctl dispatch dpms on eDP-1' \
    --lid-closed-action 'systemctl hibernate'
```

Run as `exec-once` from your Hyprland config so it starts with each session.

### Why the example `--lid-open-action` does both `reload` and `dpms on`

Defense-in-depth: `hyprctl reload` re-applies your `monitor=` rules from disk, which re-enables an internal display that's been disabled (not just DPMS-off). The subsequent `dpms on` covers the common case where the panel was just DPMS-off. Either path to blackout is recovered.

If you're sure the internal panel is only ever DPMS-off (never disabled), `hyprctl dispatch dpms on eDP-1` alone suffices.

### Options

| Flag | Required | Description |
|---|---|---|
| `--lid-open-action CMD` | yes | Shell command to run on blackout with lid open. |
| `--lid-closed-action CMD` | yes | Shell command to run on blackout with lid closed. |
| `-v`, `--verbose` | no | Log every monitor event (default: only blackouts). |

## Multi-external setups

Blackout requires **all** externals to drop. Re-evaluating state on each `monitorremoved` handles arbitrarily many externals — disconnecting one while another remains on simply fails the "any usable monitor" check and no-ops.

## Limitations

- **Hyprland-specific.** Uses Hyprland's IPC socket protocol. A sway/wlroots-generic version would need an adapter for `swayipc` events.
- **DPMS-off via `hyprctl dispatch dpms off NAME` does not fire `monitorremoved`.** That means manually DPMS-ing your only external display via hyprctl won't trigger recovery. The common cases — power button, cable yank, monitor sleep — *do* trigger hot-unplug at the kernel level, which Hyprland surfaces as `monitorremoved`.

## How it survives hibernate

The daemon's IPC connection is preserved across `systemctl hibernate` (process state is restored along with the rest of the kernel). Hyprland is the same process, the socket is the same FD, the daemon picks up where it left off when the system resumes.

If Hyprland itself restarts, the socket dies and the daemon exits. Your session manager should respawn it — `exec-once` does so on next session start.

## Requirements

- Python 3.9+ (stdlib only).
- Hyprland with IPC enabled (default).
- For the hibernate path: a working `systemctl hibernate` (swap large enough, resume offset configured, etc.).

## License

Will be MIT on extraction. Currently lives inside [rhombu5/dots](https://github.com/rhombu5/dots) as a chezmoi-managed user binary; this README is structured to be the repo root's README on extraction.
