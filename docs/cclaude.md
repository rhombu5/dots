# `cclaude` — multi-root Claude Code launcher

Zsh function in [`dot_zsh_aliases`](../dot_zsh_aliases). Wraps `claude` so a
single invocation can span several project roots, auto-loading each root's
`.mcp.json` and `.claude/settings.json`.

Everything after the leading paths is passed straight through to `claude`
verbatim — cclaude does **not** parse `claude`'s own flags or their
arguments, so things like `--name fubar`, `-p "..."`, `--allowedTools …`
work exactly as documented for `claude`.

## Usage

```
cclaude <primary-path> [extra-path ...] [cclaude-flag ...] [claude-flag ...]
```

Argument order:

1. **Leading positional paths.** The first is `cd`ed into (in a subshell)
   before `claude` runs and becomes its primary working directory. Each
   remaining path is passed as `--add-dir <path>`. **If no path is given**,
   cclaude defaults to `~/src/noop/` — the [noop landing zone](#noop-default)
   for general questions and one-off instructions.
2. **Everything else** is forwarded to `claude` unchanged, *minus*
   cclaude's own flags. The path region ends at the first token starting
   with `-`; positional tokens after that go through to `claude` as-is
   (claude will treat a trailing bareword as the initial prompt — see
   `-i/--init` below for the unambiguous form).

## cclaude's own flags

| Flag                              | Effect                                                          |
|-----------------------------------|-----------------------------------------------------------------|
| `-m`, `--no-mcp`                  | Skip per-extra `--mcp-config` auto-injection.                   |
| `-s`, `--no-settings`             | Skip per-extra `--settings` auto-injection.                     |
| `-i <prompt>`, `--init <prompt>`  | Send `<prompt>` as the initial user message in the new session. |

cclaude consumes these and strips them from the args before invoking
`claude`.

`-i/--init` exists because cclaude reserves the leading positional slots
for paths — a "naked" trailing string after paths would be misread as
another path. With `-i` the prompt is unambiguous, and cclaude appends it
as a positional to `claude` after all flags.

## Auto-injection (per *extra* path only)

For each path beyond the first, the wrapper adds:

| If this file exists                  | The wrapper adds                          |
|--------------------------------------|-------------------------------------------|
| `<extra>/.mcp.json`                  | `--mcp-config <extra>/.mcp.json`          |
| `<extra>/.claude/settings.json`      | `--settings <extra>/.claude/settings.json`|

The primary path is *not* scanned — `claude` already picks up its own
project config natively when launched from that directory.

`--setting-sources` is incompatible with `--settings`; if you pass
`--setting-sources …` in the passthrough args, cclaude suppresses its
auto-`--settings` injection so `claude` doesn't error.

### Multi-root `CLAUDE.md` loading

By default, `claude` only reads `CLAUDE.md` from its primary working
directory. The global setting
`CLAUDE_CODE_ADDITIONAL_DIRECTORIES_CLAUDE_MD=1` (set in
`~/.claude/settings.json` under `env`) tells `claude` to also load
`CLAUDE.md` from every `--add-dir`'d root, so each extra path's
project rules apply alongside the primary's. cclaude doesn't pass
this flag itself — it inherits from the global config — but the
behavior is the natural complement to multi-root sessions and is
worth knowing about when you compose them.

## Always passed

`claude` is always invoked with `--dangerously-skip-permissions` — this
wrapper is for trusted local roots only.

## Example

```sh
cclaude ~/src/arch-setup@fnrhombus ~/src/dots@rhombu5 \
        --name "metis-housekeeping" \
        -i "audit the postinstall script for drift since last reinstall"
```

→ `cd ~/src/arch-setup@fnrhombus`, then:

```
claude --dangerously-skip-permissions \
  --add-dir    ~/src/dots@rhombu5 \
  --mcp-config ~/src/dots@rhombu5/.mcp.json             # if present
  --settings   ~/src/dots@rhombu5/.claude/settings.json # if present
  --name       "metis-housekeeping" \
  "audit the postinstall script for drift since last reinstall"
```

So the session is rooted in `arch-setup`, can read/write `dots`, runs
under the named conversation `metis-housekeeping`, and opens with the
provided initial prompt.

## noop default

`cclaude` with no positional path lands in `~/src/noop/`. That directory
holds a [`CLAUDE.md`](../home/src/noop/CLAUDE.md) telling Claude it's
been started outside any project and that project-specific work should
be redirected — Claude offers to write a `handoff.md` in the right repo
and then suggests the user relaunch with:

```
cclaude <project-dir> -i @handoff.md
```

So a bare `cclaude` becomes "open Claude for general chat" without
contaminating any project's tree. The dir + its `CLAUDE.md` are
chezmoi-managed under `home/src/noop/` so they survive a reinstall.

## Notes

- The `cd` happens in a subshell, so your interactive shell's `$PWD` is
  unchanged after `claude` exits.
- Order matters: the **first** token starting with `-` ends the leading
  path region. Put all your paths up front.
- cclaude flags can appear anywhere *after* the leading paths and are
  always stripped before invocation.
