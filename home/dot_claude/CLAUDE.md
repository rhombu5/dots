# Tom's Claude Code rules

---

> # WHEN IN DOUBT — DISCUSS
>
> **If you are not certain about scope, intent, the right approach, or whether to take an action: stop and ask.** Don't guess. Don't proceed-and-hope. A clarifying question costs nothing; an unwanted edit, commit, push, refactor, or rewrite costs real work. This rule overrides every other instinct toward "just do it."

---

When I say **"user prefs"**, I'm referring to *this* file (`~/.claude/CLAUDE.md`).

## Don't attribute Claude in commits, issues, or PRs

Anything that ends up in a public artifact under my name — git commits, GitHub issues, GitHub PR titles/bodies/comments, code review comments — should not advertise that Claude wrote it. Specifically:

- **No `Co-Authored-By: Claude …` trailer in commit messages.** Commit as me (`fnrhombus` / Thomas Butler) without the bot trailer.
- **No `🤖 Generated with [Claude Code]` footer** in PR descriptions or issue bodies.
- **No "Claude here" / "as an AI" / "happy to" / "I'd love to" filler** in issue or PR text. Write the way I'd write — direct, technical, first-person.
- **Don't sign work as Claude** anywhere a human reader will see it.

This applies even if I don't repeat the instruction every time. If you're about to write something that will be public and signed as me, strip Claude attribution by default.

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

## Disruptive testing requires explicit hands-off confirmation

Any time you're about to do testing where I need to stay hands off — switching workspaces, rearranging windows, moving the mouse, sending input events, anything that visibly changes my screen or interrupts what I'm doing — **tell me what you're going to do and wait for confirmation before beginning.** Don't bury the side effect in a "let me just check this" framing. Read-only inspection (querying state, reading files, running validators) does not need confirmation. Anything that perturbs my live session does.

**Why this matters:** if you're testing window/workspace/input behaviour and I'm using the machine at the same time, my keystrokes and clicks contaminate your readings — you'll see state changes I caused, attribute them to your dispatch, and draw the wrong conclusion. Telling me to keep my hands off for the duration is the only way the test gives a clean signal. Don't skip the ask just because the change is small.

## System changes go to both the live system AND the dotfiles repo

When instructed to make any system preference, configuration, or other persistent change: apply it to the actual running system AND mirror it into the appropriate repo — usually the chezmoi dotfiles repo at `~/.local/share/chezmoi` (`git@github.com:rhombu5/dots.git`), or the arch-setup repo for bootstrap-level changes.

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

## Repo clone paths and naming

**Folder name (hard rule):** `{repo}@{user}+{workspace}` — drop the `+{workspace}` suffix when there is no workspace. The `@user` part is **always** included so forks and upstreams of same-named repos can coexist.

**Parent directory** — pick by what the repo *is to me*, not by taste. The axis is: do I edit it, do I build it for myself, or am I just running it?

- **`~/src/`** — code I edit or could commit to. Personal projects, forks I'm working on, anything where I'm a contributor. Default for "I'm hacking on this."
- **`~/.local/src/`** — third-party source I'm cloning to build/install at user scope (analog of `/usr/local/src/` for $HOME). I'm a *user* of it, not an editor. Use when upstream's pattern is "git clone && make install" and the build artifact lands in `~/.local/`. Keeps `~/src/` from filling up with build trees I never touch.
- **`/opt/`** — third-party application bundles installed system-wide (FHS convention: one self-contained dir per product). Path is just `/opt/{repo}@{user}+{workspace}` — no `<vendor>` layer, since `@user` already gives the provider namespace FHS wants. Rare for raw clones; usually only when upstream ships a tarball you'd otherwise extract there.
- **`/tmp/`** — throwaway exploration. Use `mktemp -d` so concurrent clones don't collide.

If you can't tell which category the repo falls into → **ask me** before cloning.

## Always clone via SSH

Use `git@<host>:<user>/<repo>.git` URLs, never `https://`. The SSH agent is Bitwarden Desktop (socket at `~/.bitwarden-ssh-agent.sock`); if a non-interactive shell doesn't have `SSH_AUTH_SOCK` set, prepend `SSH_AUTH_SOCK=$HOME/.bitwarden-ssh-agent.sock` to the git command — don't bypass signing.

## New projects follow the same clone-path rules

When asked to start a new project (anything I might eventually push to GitHub), pick its directory using the same `{repo}@{user}+{workspace}` rule and the same `~/src/` vs `~/.local/src/` vs `/opt/` axis as for clones. Decide the GitHub owner *up front* — see the next section — so the folder name reflects where it'll live.

## My GitHub user/orgs

| Owner | Use for | Notes |
|---|---|---|
| **`fnrhombus`** | My current personal username. Published or anticipated-published projects. | Default for "I expect this to have value to other people." |
| **`rhombu5`** | Personal projects not intended to be useful to anyone else. | Default for dotfiles, machine-specific scripts, throwaways. |
| **`rhom6us`** | An old username turned org. Holds projects I'm undecided about, kept so old links keep resolving. | **Never place anything new here.** |
| **`rhombus-redux`** | React/Flux tooling. | Don't use unless I tell you to. |
| **`rhombus-toolkit`** | General tooling projects. | Don't use unless I tell you to. |
| **`rewso`** | A company I used to work for. | **Never use.** |

`fnrhombus/arch-setup` properly belongs under `rhombu5` — it's an oversight on my part that I'll fix eventually. Don't pattern-match off that location when picking owners for new repos.

> **Self-cleanup directive (Claude):** if you ever notice that `arch-setup` is no longer at `github.com:fnrhombus/arch-setup` (e.g. the remote has been moved to `rhombu5/arch-setup`, or the local checkout's `git remote -v` reflects the move), delete *both* the preceding paragraph about the misplacement *and* this directive itself in the same commit. Goal: this whole call-out evaporates the moment it's no longer true.

## Project memory lives in the project tree

When working inside a git repo, Claude's auto-memory files belong in `<project-root>/.claude/memory/`, not the per-session home-dir path (`~/.claude/projects/<encoded-cwd>/memory/`). Reasons:

- Memory travels with the repo across reinstalls, machines, and worktrees.
- Each repo's learnings stay scoped to that repo — no leakage from one project's gotchas into another project's session.
- The project-root path is stable; the home-dir path is encoded from the absolute CWD and breaks if the repo moves.

**The project is the project the work is about, not the CWD.** A session may start in one repo and end up doing work in another (e.g., started in `arch-setup` but the user asks for changes in `dots`). Sort each memory file into the `.claude/memory/` of the project it actually describes, not the launch directory. If a single memory genuinely spans projects, route it to the more affected one.

Claude Code's hardcoded home-dir path is reconciled with this via a **symlink**: `~/.claude/projects/<encoded-cwd>/memory` → `<project-root>/.claude/memory/`. Both paths resolve to the same files. The symlink itself is per-machine (lives under `~/.claude/`, not the repo); set it up after cloning a project on a new machine.

**Commit policy is per-repo:**
- **Public repos** (most things under `fnrhombus`): `.gitignore` `/.claude/memory/`. Memories often contain tenant IDs, internal endpoints, or other identifiers safer kept local.
- **Private repos** (most things under `rhombu5`): commit memory files. They're part of the project's institutional knowledge.

When in doubt, gitignore — easier to opt-in to commit later than to redact a public commit.
