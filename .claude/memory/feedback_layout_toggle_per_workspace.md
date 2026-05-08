---
name: Layout-toggle binds are per-workspace, not global
description: Super+Alt+S/T/B/F flip the active workspace's layout only; state must persist on that workspace across visits + reloads.
type: feedback
---

**Layout-toggle binds (Super+Alt+S/T/B/F) operate on the active workspace
only, and the chosen layout must persist on that workspace across visits +
reloads + reboots.**

**Why:** During the initial fix for "scroll mode reverts on workspace
switch" (2026-05-02), Claude proposed a global toggle that flipped
`general:layout` and pushed rules to all workspaces. User rejected that
plan with: "I expect Super+Alt+S to apply to the *current* workspace
only, and I expect it to stay that way when I leave and come back to it."

**How to apply:** When designing or editing layout-related dispatchers in
this repo, prefer per-workspace state over global `general:layout`. The
shipped pattern is:

- `~/.local/state/hypr-layout/ws-<id>.mode` — one file per workspace,
  authoritative for that ws's chosen layout (`dwindle` / `scrolling`).
- `~/.config/hypr/runtime-layouts.conf` — generated from the .mode files
  by `hypr-layout-toggle`. Sourced by `hyprland.conf` so the rules
  survive `hyprctl reload` and reboot. Chezmoi-source uses the `create_`
  prefix (`dot_config/hypr/create_runtime-layouts.conf`) so chezmoi
  apply doesn't clobber the runtime-rewritten version.
- The toggle script regenerates the conf file then `hyprctl keyword
  workspace "<id>,layout:<target>"` for live migration of the active ws.

**Hyprland 0.54.3 gotchas learned the hard way:**

- `hyprctl keyword workspace "N,layout:X"` migrates ws N's algorithm
  ONLY when N is the active workspace at the moment of the call. For
  inactive workspaces the rule registers (visible in `hyprctl
  workspaces -j` as `tiledLayout`) but the actual algo pointer doesn't
  flip — and on `dispatch workspace N` the workspace renders as the
  pre-rule layout. So a daemon-driven "re-apply on focus" approach
  doesn't work; the rule has to land before activation OR be in a
  config file that gets read at reload time.
- `hyprctl reload` re-reads disk and discards in-session `hyprctl
  keyword` state. So persistent per-workspace layouts MUST live in a
  sourced config file, not just keyword-pushed.
- Source confirmed in `WorkspaceAlgoMatcher.cpp::tiledAlgoForWorkspace`:
  workspace algo defaults to `general:layout` unless the workspace rule
  has `layout:NAME`. This is the lever.
