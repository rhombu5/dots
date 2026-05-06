# Git / GitHub context rules

## Repo clone paths and naming

**Folder name (hard rule):** `{repo}@{user}+{workspace}` — drop the `+{workspace}` suffix when there is no workspace. The `@user` part is **always** included so forks and upstreams of same-named repos can coexist.

**Parent directory** — pick by what the repo *is to me*, not by taste. The axis is: do I edit it, do I build it for myself, or am I just running it?

- **`~/src/`** — code I edit or could commit to. Personal projects, forks I'm working on, anything where I'm a contributor. Default for "I'm hacking on this."
- **`~/.local/src/`** — third-party source I'm cloning to build/install at user scope (analog of `/usr/local/src/` for $HOME). I'm a *user* of it, not an editor. Use when upstream's pattern is "git clone && make install" and the build artifact lands in `~/.local/`. Keeps `~/src/` from filling up with build trees I never touch.
- **`/opt/`** — third-party application bundles installed system-wide (FHS convention: one self-contained dir per product). Path is just `/opt/{repo}@{user}+{workspace}` — no `<vendor>` layer, since `@user` already gives the provider namespace FHS wants. Rare for raw clones; usually only when upstream ships a tarball you'd otherwise extract there.
- **`/tmp/`** — throwaway exploration. Use `mktemp -d` so concurrent clones don't collide.

If you can't tell which category the repo falls into → **ask me** before cloning.

## Resolving repo short-names to local paths

When I say *"put it in arch-setup"*, *"look in dots"*, *"check the planters in dots"* — I mean the **repo**, not a literal directory at `~/src/arch-setup/` or `~/src/dots/`. Those directories don't exist by convention. The local checkout always follows the `{repo}@{user}+{workspace}` rule above, so resolve like:

- `dots` → `~/src/dots@rhombu5/`
- `arch-setup` → `~/src/arch-setup@fnrhombus/` (currently; will move to `rhombu5/arch-setup` eventually)

If you're unsure or there could be multiple checkouts (forks, worktrees), confirm with:

```sh
ls -d ~/src/<name>@* ~/.local/src/<name>@* 2>/dev/null
```

Multiple hits → ask which one. Zero hits → it's not cloned yet; clone it (or ask) before continuing.

Never assume `~/src/<name>/` (no `@user` suffix) is a valid path — folder names always include the owner.

## Always clone via SSH

Use `git@<host>:<user>/<repo>.git` URLs, never `https://`. The SSH agent is Bitwarden Desktop (socket at `~/.bitwarden-ssh-agent.sock`); if a non-interactive shell doesn't have `SSH_AUTH_SOCK` set, prepend `SSH_AUTH_SOCK=$HOME/.bitwarden-ssh-agent.sock` to the git command — don't bypass signing.

## New projects

Same rules as clones (folder name + parent dir). Pick the GitHub owner from the table below *up front* so the folder name reflects ownership from day one.

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
