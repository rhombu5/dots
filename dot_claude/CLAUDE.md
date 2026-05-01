# Tom's Claude Code rules

## System changes go to both the live system AND the dotfiles repo

When instructed to make any system preference, configuration, or other persistent change: apply it to the actual running system AND mirror it into the appropriate repo — usually the chezmoi dotfiles repo at `~/.local/share/chezmoi` (`git@github.com:rhombu5/dots.git`), or the arch-setup repo for bootstrap-level changes.

For **chezmoi-managed** files (check with `chezmoi managed | grep <path>`):
- Edit the live file, then `chezmoi re-add <path>` to sync source ← live (or use `chezmoi edit <path>` to edit the source directly and `chezmoi apply`).
- Verify with `chezmoi diff <path>` — empty output means source and live are in sync.
- Make sure the chezmoi repo's working tree is clean afterwards.

Always make **immediate, atomic commits and push**. One logical change per commit. Don't batch unrelated changes. Don't leave the repo dirty across turns. Match the existing commit-message style in the repo (check `git log` first).

## Repo clone paths and naming

**Folder name (hard rule):** `{repo}@{user}+{workspace}` — drop the `+{workspace}` suffix when there is no workspace. The `@user` part is **always** included so forks and upstreams of same-named repos can coexist.

**Parent directory** — pick by what the repo *is to me*, not by taste. The axis is: do I edit it, do I build it for myself, or am I just running it?

- **`~/src/`** — code I edit or could commit to. Personal projects, forks I'm working on, anything where I'm a contributor. Default for "I'm hacking on this."
- **`~/.local/src/`** — third-party source I'm cloning to build/install at user scope (analog of `/usr/local/src/` for $HOME). I'm a *user* of it, not an editor. Use when upstream's pattern is "git clone && make install" and the build artifact lands in `~/.local/`. Keeps `~/src/` from filling up with build trees I never touch.
- **`/opt/<vendor>/`** — pre-built third-party application bundles installed system-wide (FHS convention: one self-contained dir per product). Rare for raw clones; usually only when upstream ships a tarball you'd otherwise extract there.
- **`/tmp/`** — throwaway exploration. Use `mktemp -d` so concurrent clones don't collide.

If you can't tell which category the repo falls into → **ask me** before cloning.

## Always clone via SSH

Use `git@<host>:<user>/<repo>.git` URLs, never `https://`. The SSH agent is Bitwarden Desktop (socket at `~/.bitwarden-ssh-agent.sock`); if a non-interactive shell doesn't have `SSH_AUTH_SOCK` set, prepend `SSH_AUTH_SOCK=$HOME/.bitwarden-ssh-agent.sock` to the git command — don't bypass signing.
