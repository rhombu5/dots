# Git / GitHub context rules

## Repo paths

Where things land on disk comes from `~/.claude/settings.json`'s `repoSettings` block:

- `cloneTemplate` — destination for fresh clones. `fnc <ref>` reads this when resolving a repo reference to a path.
- `worktreeTemplate` — destination for worktrees. Claude Code's `--worktree` (via the claude-code-worktree-paths plugin) reads this when creating a worktree.

The schema is documented in the plugin's README. **Don't restate the folder-name pattern** in chat, in commit messages, or in CLAUDE files — point at the templates. The `@owner+workspace` shape is part of the configured templates; if you find yourself spelling it out somewhere else, you're duplicating.

**Per-category placement** (what `cloneTemplate` can't express — it's one default for all clones):

- **`~/src/`** — code I edit or could commit to. Personal projects, forks. The default `cloneTemplate` captures this case.
- **`~/.local/src/`** — third-party source I'm building from upstream's "git clone && make install" flow. I'm a *user* of it, not an editor. Clone manually to this prefix; don't change `cloneTemplate` to handle one-off cases.
- **`/opt/`** — third-party application bundles installed system-wide (FHS convention). Rare for raw clones.
- **`/tmp/`** — throwaway exploration. Use `mktemp -d`.

If you can't tell which category a repo falls into, ask me before cloning.

## Resolving repo short-names

`fnc <name>` is the canonical resolver. It searches my gh-orgs (`gh api /user/orgs`), finds existing clones via `cloneTemplate`, and clones if missing. Prefer that over hand-computing paths.

For ad-hoc inspection without launching claude:

```sh
ls -d ~/src/<name>@* ~/.local/src/<name>@* 2>/dev/null
```

Multiple hits → ask which one. Zero hits → not cloned yet.

## SSH

Use `git@host:user/repo.git` URLs, not `https://`. The SSH agent is Bitwarden Desktop (socket `~/.bitwarden-ssh-agent.sock`); if a non-interactive shell lacks `SSH_AUTH_SOCK`, prepend `SSH_AUTH_SOCK=$HOME/.bitwarden-ssh-agent.sock` to git calls.

`gh repo clone` (used by fnclaude internally) honors `gh config get git_protocol` — set once to `ssh` and forget.

## Entering / exiting worktrees — always use the tools

**HARD RULE**: when claude needs to work in a worktree, use the **`EnterWorktree`** tool to switch in and **`ExitWorktree`** to switch back. Don't `cd <worktree>` via Bash, don't run `git worktree add <path>` directly, don't symlink into one. Reasons:

- `EnterWorktree` updates the session's cwd, so subsequent tool calls, the statusbar, and anything else that reads `workspace.current_dir` reflect that claude is now working in the worktree. A bare `git worktree add` creates the directory but leaves cwd unchanged — the statusbar won't light up the worktree, and downstream code keeps targeting the main checkout.
- `EnterWorktree` creates the worktree at the `repoSettings.worktreeTemplate` path if it doesn't already exist, so the rules from the "Creating worktrees" section below apply automatically — no path math needed at the call site.
- `ExitWorktree` restores the prior cwd cleanly; no manual `cd -` needed.

**Exit as soon as the work in the worktree is done.** Don't linger after the task that needed the worktree completes — call `ExitWorktree` immediately so the statusbar and any tool reading `workspace.current_dir` snap back to the main checkout. Staying parked in a worktree past the task that justified it is a stale cwd waiting to mislead the next thing you do.

`git worktree remove <path>` is still the right call for **cleanup** (e.g., after a PR merges, per the rule near the bottom of this file). That's about deleting the worktree's directory, separate from claude's cwd context.

## Creating worktrees — always via the templated path

**HARD RULE**: when you need to create a worktree, the path comes from `repoSettings.worktreeTemplate`. The claude-code-worktree-paths plugin's `WorktreeCreate` hook computes it — your job is to *invoke the hook*, not to pick the path yourself.

Concretely:

- **`Task` with `isolation: "worktree"`** — fires the hook. Use this for any agent that needs isolation.
- **`claude --worktree <name>`** — fires the hook.
- **`fnc <repo>+<workspace>`** — fnclaude resolves the base repo, passes `--worktree <workspace>` to claude, hook fires.
- **`git worktree add <path>` direct** — does NOT fire the hook. Path is whatever you typed. This is the failure mode.

**Symptoms of doing it wrong**: worktree lands inside the repo at `.claude/worktrees/<name>/` (the plugin's vanilla default) or wherever you typed in `git worktree add`. Both wrong. The user's `worktreeTemplate` defines where worktrees should live — anything that doesn't honor it is a bug.

The hook reports the templated path back in its `hookSpecificOutput.worktreePath`. **Use that returned value** — don't recompute, because the template might reference placeholders (`{host-short}`, `{repo-dir}`, `{clone-path}`) that aren't trivially derivable.

If you find yourself reaching for `git worktree add <path>`, stop and ask: *"Is this a worktree the user expected at the templated location?"* If yes, switch to a hook-firing mechanism. If genuinely no (some specific reason for a one-off path), say so out loud and let the user push back.

## New projects

Same template flow as clones — `cloneTemplate` determines the path, the GitHub owner comes from the table below. Pick the owner up-front so the folder shape is right from day one.

## Template repos

When starting a new repo that fits a published pattern, clone from a template instead of scaffolding from scratch:

- **`fnrhombus/aur-template`** — binary CLIs that publish to GitHub releases + the Arch User Repository. Language-agnostic publish chain (release-please + auto-merge + AUR push); fill in `build.yml` + `test.yml` for the language.
- **`fnrhombus/npm-template`** — npm packages. npm publishing CI + funding config wired up.

Trigger: when I propose work that creates a new GitHub repo, check whether one of these fits and use `gh repo create <new-name> --template <owner>/<template> --public` rather than `git init`. If neither fits cleanly, scaffold from scratch — don't bend one into the other.

After cloning a template, walk any `BURN-AFTER-READING.md` (or similarly-named) one-time setup doc and delete the file once done.

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

## After merging a PR — always clean up the branch and worktree

The moment a PR I opened reaches merged state — whether the merge happened via `gh pr merge`, the GitHub web UI, an auto-merge that resolved while we waited, or any other path — **delete the branch and (if one exists) the worktree without asking.** Don't surface this as a confirm-then-do; just do it. The session should never end with a stale just-merged branch and a worktree directory I have to remember to clean up myself, and I shouldn't have to approve the same three-step cleanup every time.

Execute these top-to-bottom, stopping at the first refusal:

1. **Worktree** (if the branch has one — check `git worktree list`): `git worktree remove <path>`. If the worktree has uncommitted or unpushed work, **refuse to delete it** and tell me what's outstanding — that's not stale, that's lost work waiting to happen. (`ExitWorktree(action: "remove")` is the normal call when the session is currently *in* the worktree; it's what enforces the unpushed-work refusal.)
2. **Local branch**: `git branch -d <branch>` (or `-D` if the local ref isn't fully on the merged target, since the squash/rebase merge style on GitHub will leave the local commits diverged from the merge commit).
3. **Remote branch**: **always verify with `git ls-remote origin <branch>` after the merge**, regardless of what `gh pr merge --delete-branch` or the web UI's auto-delete claim happened. `gh pr merge --rebase --delete-branch` has been observed silently *not* deleting the remote — the merge succeeds but the branch lingers on GitHub at the pre-rebase SHA. If `ls-remote` still shows the ref, run `git push origin --delete <branch>` and re-verify.

Surface what you did in one short line after the fact, not as a question before.
