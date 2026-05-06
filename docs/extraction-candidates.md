# Extraction candidates

Living list of things inside `rhombu5/dots` and `fnrhombus/arch-setup` that might be worth pulling out as standalone repos. I read this when I'm deciding whether an extraction is actually worth the ceremony.

Criteria for being here: (a) self-contained — no hard dependency on the rest of my config, (b) generically useful — solves a real problem for someone besides me, (c) enough code volume that a repo + README is worth more than a Gist.

---

## Candidates

### display-watchdog — Hyprland blackout recovery daemon

**Location:** `~/.local/bin/display-watchdog` (dots), README at `~/.local/share/doc/display-watchdog/README.md`

**What it is:** Python daemon. Listens on Hyprland's IPC socket for `monitorremoved` / `monitorremovedv2` events; when no monitor with `dpmsStatus=true` remains, runs one of two configurable shell commands depending on lid state. Covers the gap between kanshi/shikane (no lid awareness) and lid scripts (no "external disappeared while internal was already off" awareness).

**Why extract:** Real gap that none of the usual tools fill. Anyone on a Hyprland laptop docked to an external display with the internal DPMS-off hits this. The problem and solution are Hyprland-specific but not machine-specific.

**What's blocking clean extraction:** Almost nothing. The README is already written as a repo root document and declares "Will be MIT on extraction." Needs: a repo, a `pyproject.toml` (currently relies on system Python + `hyprctl` on PATH), and basic CI for the IPC parser. Roughly 1-2 turns of work.

**Status:** Actively used. Nearest-to-extraction-ready of all candidates.

---

### wpws — per-workspace wallpaper + accent daemon

**Location:** `~/.local/bin/wpws`, `~/.config/wpws/config.toml` (dots)

**What it is:** Python daemon. Watches Hyprland IPC for workspace-switch events; on each switch, sets the wallpaper and recomputes the matugen Material You accent for that workspace. Fast-path: PIL-based color extractor for snappy switching. Slow-path: full `matugen image` render for cold starts and theme changes.

**Why extract:** Hyprland has no per-workspace wallpaper concept upstream. The "different wallpaper + matching theme per workspace" idea is novel and the implementation handles both the latency problem (fast-path) and the accuracy problem (slow-path matugen) in a way that isn't obvious.

**What's blocking clean extraction:** Likely hardcoded paths to my matugen template directory and wallpaper pool. Needs: clean CLI args (or a config file) for theme dir and wallpaper-pool dir; possibly factor out the fast-path PIL color extractor as its own importable component so it can be reused or swapped.

**Status:** Actively used. Previously flagged in session memory as an extraction candidate.

---

### claude-askpass — Bitwarden-backed SUDO_ASKPASS helper

**Location:** `~/.local/bin/claude-askpass` (dots)

**What it is:** `SUDO_ASKPASS` helper script. Pulls a Bitwarden vault item's password via `secret-tool lookup` + `bw list items`, prints to stdout. Caller does `SUDO_ASKPASS=~/.local/bin/claude-askpass sudo -A <cmd>`. Designed for unattended sudo from contexts with no tty — Claude Code agents, `systemd --user` units, cron — while keeping the credential in a vault rather than a plaintext file.

**Why extract:** Generic problem: let automation authenticate sudo without a tty AND without a plaintext password file. The SUDO_ASKPASS + libsecret + Bitwarden combination works for any Linux user with a Bitwarden account. No off-the-shelf tool covers this combo.

**What's blocking clean extraction:** Hardcoded filter (`name == "MicrosoftAccount"` + `username == "thomas@butler.software"`). Needs: parameterization via `~/.config/claude-askpass.conf` or CLI args. Optionally: a backend abstraction to support 1Password CLI, `pass`, etc. Small refactor (~30-50 lines). Would naturally ship alongside the `bw`/`bwu` helpers below.

**Status:** Just shipped (2026-05-05). Pairs with the `bw`/`bwu` zsh helpers.

---

### bw / bwu — libsecret-backed Bitwarden CLI unlock helpers

**Location:** `~/.zsh_aliases` (dots), the `bwu()` and `bw()` functions

**What it is:** `bwu` seeds the Bitwarden master password into libsecret on first call (one interactive read, silent forever after via `secret-tool`); subsequent `bw` invocations transparently re-unlock the vault when the session token expires. Mirrors the desktop app's "Unlock with system authentication" toggle but for the CLI.

**Why extract:** The official `bw` CLI requires `bw unlock` every session and prompts for the master password each time. Power users want desktop-app behavior. This is the correct way to wire `bw` into a libsecret-aware desktop — nothing upstream provides it.

**What's blocking clean extraction:** Currently zsh-only (uses zsh-specific syntax in the wrapper). Port to POSIX sh or add a bash variant for broader reach. Ship as `bw-libsecret-helpers` with both shells. Trivial test surface.

**Status:** Actively used; this is the foundation `claude-askpass` builds on.

---

### sudonf — sudo with desktop notification + auto-dismiss

**Location:** `~/.local/bin/sudonf` (dots)

**What it is:** Wraps sudo with a Critical-urgency `notify-send`; on sudo completion, dismisses the notification by ID via D-Bus (`CloseNotification`). Solves the "I can't tell sudo is waiting on a fingerprint swipe" problem when the terminal bell is silent or unavailable.

**Why extract:** Niche but real for any desktop where the terminal bell isn't reliable. `notify-send -p` returns a notification ID; `org.freedesktop.Notifications.CloseNotification` closes it — that's a freedesktop standard that works with mako, dunst, swaync, gnome-shell, kde, all of them. The pattern is generic even though the problem sounds specific.

**What's blocking clean extraction:** Currently coupled to swaync's specific D-Bus name. Refactor to use the freedesktop standard interface (`org.freedesktop.Notifications`, method `CloseNotification`) — small change (~10 lines). After that it runs anywhere.

**Status:** Actively used; the standard sudo wrapper in my Claude Code workflow.

---

### arch-setup-bootstraps — interactive first-login planter framework

**Location:** `phase-3-arch-postinstall/planters/` (source-of-truth in `fnrhombus/arch-setup`), `~/.zshrc.d/arch-bootstrap-runner.zsh` dispatcher (dots), state at `~/.local/share/arch-setup-bootstraps/`

**What it is:** Postinstall §13b copies "planter" shell scripts (one per first-login task — `gh auth`, SSH key registration, etc.) to a per-user state dir. The dispatcher in `.zshrc.d/` runs each planter on the first interactive shell that satisfies the task's requirements; on success the planter self-deletes from the state dir.

**Why extract:** Generic Linux setup problem — "I want my install scripts to be hands-off, but some tasks need an interactive session AND network AND tools that aren't ready until after first login." The "drop a script for the user's first shell to find" pattern is widely applicable beyond Arch.

**What's blocking clean extraction:** Cross-repo split complicates the extraction boundary — `arch-setup` ships the planters, `dots` ships the dispatcher. Clean extraction means either one opinionated combined repo or a lightweight library both sides can consume. Also, current planters embed task-specific logic inline; need a general-purpose planter contract (idempotency semantics, standard exit codes, prompt UX conventions) before the framework is separable from the content.

**Status:** Actively used. The pattern is novel-ish; the implementation is still tangled.

---

## Considered and rejected

- **lid-handler** — too coupled to my specific monitor setup (`eDP-1` + `DP-1` + AC/battery branching). The "logind defers, userland decides" pattern is extractable as an idea, but the specific logic isn't reusable.
- **hyprlock config** — matugen-themed config over upstream hyprlock. No novel logic; just theming.
- **matugen pipeline** — it IS matugen. Nothing to extract; contribute upstream if there's a gap.
- **Hyprland configs** — opinionated personal config. Not a project.
