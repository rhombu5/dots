# Learning Neovim

A practical guide to this Neovim setup. Aimed at an experienced developer who is new to Vim motions — it teaches the *why* behind the keys, not just a dump of bindings. Work through the sections in order the first time; use it as a reference after.

To search all active keymaps from inside Neovim, press `<leader>sk` (Space → s → k). That picker is always more complete than any document.

---

## 1. Orientation — modes and the leader key

Neovim has distinct modes. This is the single most important shift for a developer coming from a modeless editor.

**Normal mode** is where you navigate and issue commands. It is the default, the resting state. Every workflow starts and ends here.

**Insert mode** is where you type text. Enter it with `i` (insert before cursor), `a` (append after), `o` (open a new line below), `O` (above). Press `Esc` to return to Normal.

**Visual mode** selects a range of text. `v` starts character-wise selection, `V` line-wise, `<C-v>` column-wise (block). Once text is selected, an operator acts on it.

**Command mode** is the `:` prompt. `:w` saves, `:q` quits, `:wq` does both, `:e filename` opens a file.

### Mental model

| You want to... | Mode |
|---|---|
| Navigate, jump, run commands | Normal |
| Type text | Insert — enter with `i` / `a` / `o` |
| Select a range and operate | Visual — enter with `v` / `V` / `<C-v>` |
| Run an Ex command or open a file | Command — enter with `:` |

### The leader key

Your leader key is `Space`. Every `<leader>` binding in this guide means Space followed by the listed keys. Four leader groups are registered:

- `<leader>s…` — Search (Telescope pickers)
- `<leader>t…` — Toggle (features on/off)
- `<leader>h…` — Git Hunk (gitsigns actions)
- `gr…` — LSP Actions

### which-key

Press `Space` in Normal mode and pause for a moment. A panel appears listing every leader binding. Press a letter to narrow; press `Esc` to cancel. The timeout is 300 ms — short enough to feel snappy, long enough to read when you need it.

---

## 2. Discovering keymaps — which-key and Telescope

Two tools replace "what was that binding again?":

**which-key** appears automatically mid-chord whenever you pause. It covers every leader group and any other multi-key sequence that has been registered. Use it freely — it is not just for beginners.

**`<leader>sk`** opens a Telescope picker over every active keymap in the session. Fuzzy-search by description or key sequence. This is the canonical lookup; no cheatsheet is more complete.

**`:help {topic}`** is the reference manual. `:help vim.lsp`, `:help motion`, `:help operator` all work. Inside a help page, `<C-]>` follows a tag link; `<C-t>` jumps back.

---

## 3. Your learning path — built-in training

This config ships four learning tools. Use them in order.

### `:Tutor` — start here

Run `:Tutor` your first session. It is Neovim's interactive tutorial — roughly 30 minutes, designed to teach the foundational motions by having you actually do them. Don't skip it; the rest of this booklet assumes you've done it.

### `:VimBeGood` — drill until it's automatic

Once the tutor is done, `:VimBeGood` gives you motion mini-games. Modes include `relative` (reach a line offset using count + `j`/`k`), `whichkey`, and others. Short sessions — five minutes while a build runs — compound quickly.

### `<leader>tH` — hardtime.nvim

hardtime is **on by default**. It watches your editing and nags or briefly blocks when you repeat `j`/`k` or arrow-key presses more than four times in a row. The friction is intentional: it forces you to reach for a better motion rather than hammering the same key.

When hardtime is genuinely blocking a real task, `<leader>tH` toggles it off. Toggle it back on as soon as you're done. The goal is to use that toggle as infrequently as possible.

### `<leader>tp` — precognition.nvim

precognition shows, in real time, which motions are available from your current cursor position: `f` targets on the line, `^`/`$` markers, `%` bracket pairs, section-jump candidates. It renders as subtle inline text — not a popup, just ambient information.

It is on by default while you're learning. `<leader>tp` hides it once you've internalized the motions, or when it's too noisy in a dense file.

### Mental model

| Tool | When to use it |
|---|---|
| `:Tutor` | First session, once |
| `:VimBeGood` | Daily drills, 5–10 min |
| hardtime | Always on; `<leader>tH` only for real tasks |
| precognition | On while learning; `<leader>tp` to hide later |
| flash.nvim | Every session — jump anywhere on screen in ≤4 keys |

---

## 4. Moving around — Vim motions

Efficient Neovim use is mostly efficient motion. Most motions accept a count prefix: `5j` moves down five lines, `3w` advances three words. When hardtime nags you for repeating `j`, that's your cue to use a count or a better motion instead.

### Character and line

| Key | Movement |
|---|---|
| `h` `j` `k` `l` | Left, down, up, right |
| `0` | Start of line |
| `^` | First non-blank character |
| `$` | End of line |
| `gg` | Top of file |
| `G` | Bottom of file |
| `{n}G` | Jump to line *n* (e.g. `42G`) |

### Words

`w` jumps forward to the start of the next word; `e` to the end of the current word or next; `b` backward to the start. Capital `W`, `E`, `B` treat anything non-whitespace as a single WORD — they don't stop at punctuation.

### Screen and scrolling

`<C-d>` and `<C-u>` scroll half a page down and up, keeping the cursor centred. `<C-f>` and `<C-b>` scroll a full page. `zz` re-centres the view on the cursor without moving it — handy after a jump lands the target line at the very top or bottom.

### `f`, `t`, and the find family

`f{char}` jumps forward to the next occurrence of `{char}` on the current line. `t{char}` stops one character *before* it. Capital `F`/`T` go backward. `;` repeats the last find in the same direction; `,` reverses it.

flash.nvim (section 5) transparently extends `f`/`t`/`F`/`T` with visible labels when there are multiple targets — you see a letter next to each candidate and press it to land there directly, without needing `;` chains.

### Searching the whole file

`/{pattern}` searches forward; `?{pattern}` backward. `n` advances to the next match; `N` goes to the previous. Press `Esc` in Normal mode to clear the search highlight.

### `%` and marks

`%` jumps between the bracket, paren, or brace that the cursor is on and its partner. On a `{` it jumps to the matching `}`, and vice versa.

`m{a-z}` sets a named mark at the cursor position; `'{a-z}` jumps back to it. Useful when you need to hop away briefly and come back — set a mark, make your edit elsewhere, return with `'a`.

---

## 5. Long jumps — flash.nvim

For jumps across more than a few lines, flash is faster than any count-prefixed motion.

### `S` — jump anywhere on screen

Press `S` (capital), then type two characters that appear near your target. flash labels every matching position with a letter. Press that letter to jump there instantly. You land in Normal mode, cursor on the target.

The mental model: `S` + what-I-see-near-there + the-label. It is almost always three to four keystrokes to reach anywhere visible on screen.

### Flash and operators

flash works in Operator-pending mode. When you're inside a `d`, `y`, or `c` motion, pressing `S` lets you pick a destination with a label — the operator acts from your cursor to that point. This makes operators reach across the screen without counting lines.

### `r` — remote flash (operator mode)

In Operator-pending mode, `r` (lowercase) is a "remote" flash: it runs an operator at a distant location *without moving your cursor*. Press `y`, then `r`, pick a label, and what's at that label gets yanked — your cursor stays where it was.

---

## 6. Editing — operators, textobjects, and surroundings

### Operators

Operators act on a motion or textobject. The key ones: `d` deletes, `y` yanks (copies), `c` changes (deletes and enters Insert), `>` indents, `<` de-indents, `~` toggles case. Double an operator to act on the whole line: `dd`, `yy`, `cc`. The capital variant acts to end of line: `D`, `C`.

`u` undoes; `<C-r>` redoes. Undo history is persistent — it survives closing and reopening a file.

### Textobjects

Textobjects pair with operators. `i` means *inside* (exclude delimiters); `a` means *around* (include them).

| Motion | Selects |
|---|---|
| `iw` / `aw` | inside/around word |
| `ip` / `ap` | inside/around paragraph |
| `i)` / `a)` | inside/around `()` |
| `i}` / `a}` | inside/around `{}` |
| `i]` / `a]` | inside/around `[]` |
| `i"` / `a"` | inside/around double-quotes |
| `i'` / `a'` | inside/around single-quotes |
| `` i` `` / `` a` `` | inside/around backticks |

So `ci"` changes text inside double quotes, `da)` deletes the whole parenthesised expression including the parens, `yip` yanks the paragraph.

### mini.ai — next-object variants

mini.ai adds `aa` (around next) and `ii` (inside next). These target the *next* occurrence of a textobject from the cursor rather than requiring you to already be inside it. If your cursor sits before a string, `ii"` selects inside the next double-quoted string ahead. Counts work: `2aa)` targets the second paren pair ahead.

### mini.surround — add, delete, replace

| Key sequence | What it does |
|---|---|
| `sa{motion}{char}` | Add surrounding `{char}` around the motion |
| `sd{char}` | Delete surrounding `{char}` |
| `sr{old}{new}` | Replace surrounding `{old}` with `{new}` |

Examples:
- `saiw)` — surround the inner word with `()`
- `sa$"` — surround from cursor to end of line with `""`
- `sd'` — delete surrounding single-quotes
- `sr)"` — replace `()` with `""`

`s` is reserved for mini.surround here, which is why flash's screen-jump lives on capital `S`.

---

## 7. Finding things — Telescope

Telescope is a fuzzy finder that wraps files, grep, buffers, help tags, diagnostics, and more behind one consistent UI. Type to filter; `<C-n>`/`<C-p>` or `↑`/`↓` to move; `Enter` to open; `Esc` or `<C-c>` to cancel. Inside any picker, `<C-/>` (Insert mode) or `?` (Normal mode) shows all Telescope-specific keymaps.

### Files and content

| Key | What it opens |
|---|---|
| `<leader>sf` | Find files (respects `.gitignore`) |
| `<leader>sg` | Live grep — ripgrep across the project |
| `<leader>sw` | Grep the word or selection under the cursor |
| `<leader>s.` | Recently opened files |
| `<leader>sr` | Resume the previous picker |

`<leader>sg` is "I know roughly what I'm looking for." `<leader>sw` is "show me every usage of this symbol" when you want a broader view than LSP references.

### Buffers and in-buffer search

`<leader><leader>` fuzzy-finds your open buffers — faster than `:ls` + `:b N` when you have a dozen files open. `<leader>/` does a fuzzy search inside the current buffer (dropdown overlay, no preview pane), which is quicker than `/` when you want to browse matches visually.

`<leader>s/` live-greps inside only your currently-open buffers.

### Help and meta

| Key | What it opens |
|---|---|
| `<leader>sh` | Neovim help tags |
| `<leader>sk` | All active keymaps |
| `<leader>sd` | Current diagnostics |
| `<leader>sc` | Available commands |
| `<leader>ss` | All Telescope pickers |
| `<leader>sn` | Files in your Neovim config |

When you can't remember a key: `<leader>sk`. When you want a help page: `<leader>sh`. When you want to browse your own config: `<leader>sn`.

---

## 8. Code intelligence — LSP

When you open a file, Neovim attaches the appropriate language server automatically. You get inline diagnostics, go-to-definition, rename-across-files, completions, and more — out of the box for every language Mason manages.

### Navigation

| Key | What it does |
|---|---|
| `grd` | Go to definition |
| `gri` | Go to implementation |
| `grt` | Go to type definition |
| `grr` | Find all references (Telescope list) |
| `grD` | Go to declaration (e.g. a C header) |
| `<C-t>` | Jump back (pop the jump stack) |
| `gO` | List document symbols (Telescope) |
| `gW` | List workspace symbols — whole project (Telescope) |

`grd` takes you into a definition; `<C-t>` brings you back. `grr` opens Telescope — you get every reference and can jump to any one. `gO` is "list all the functions and types in this file."

### Actions

| Key | What it does |
|---|---|
| `grn` | Rename symbol across all files |
| `gra` | Code action (fix or refactor at cursor) |
| `K` | Hover documentation |
| `<leader>f` | Format buffer or selection |
| `<leader>th` | Toggle inlay hints |

`gra` is the "I see a squiggle, fix it for me" key. Place the cursor on an error or warning and press it; the LSP offers its available fixes in a dropdown.

`<leader>th` toggles inlay hints — the greyed-out parameter names and return types that appear next to your code. Useful to turn on when reading unfamiliar code, distracting when you already know the types.

### Diagnostics

Errors and warnings appear as virtual text at the end of lines, and are underlined in the gutter. `[d` jumps to the previous diagnostic; `]d` to the next — and a float automatically opens showing the full message, so you don't need to hover separately.

`<leader>q` sends all diagnostics to the quickfix list, letting you step through them with `:cnext` / `:cprev`. `<leader>sd` opens a Telescope picker over diagnostics so you can jump to a specific error by text.

### Fidget — server status

A small spinner appears in the bottom-right corner while a language server is loading or indexing. That is fidget.nvim. It disappears when the server is idle. On a cold open of a large project, give it a moment to settle before relying on completions.

### Installing servers — `:Mason`

`:Mason` opens the tool manager. `g?` inside it shows help. Move the cursor to any tool and press `i` to install, `u` to update. Mason manages every server except `tsgo` — see the next section.

---

## 9. TypeScript: tsgo and vtsls

Your TypeScript setup has two servers and a deliberate switching mechanism worth understanding.

### tsgo — the default

`tsgo` is TypeScript 7 "Corsa," Microsoft's native Go port of the TypeScript language server. It is dramatically faster than the Node-based server — especially in monorepos — because it runs as a single shared instance rather than one-per-project. For day-to-day work (hover, go-to-def, diagnostics, completions) tsgo handles everything.

tsgo is installed via mise (`mise use -g npm:@typescript/native-preview@beta`), not Mason. This means Neovim must be launched from a mise-activated shell for `tsgo` to be on `PATH`. Open Neovim from your normal terminal — mise activates when the shell starts — rather than from a bare environment. If `tsgo` is missing, Neovim will warn you on startup.

### vtsls — the dormant fallback

`vtsls` (the TypeScript server built on VS Code's engine) stays dormant by default. It covers a few advanced refactors and quick-fixes that tsgo's beta phase doesn't yet handle. The two servers never run simultaneously on the same buffer.

**Whole-project switch**: commit an empty `.nvim-ts-node` file at the project root. Neovim detects it and routes every TS/JS buffer in that project through vtsls instead of tsgo.

**Per-buffer switch**: `<leader>ts` detaches whichever TS server is currently on this buffer and attaches the other, showing a notification confirming the switch. Use this for a one-off rename or refactor, then switch back.

---

## 10. Completion — blink.cmp

Completion suggestions appear automatically as you type in Insert mode. The menu draws from LSP completions, file paths, and snippets.

| Key | Action |
|---|---|
| `<C-n>` / `<C-p>` | Next / previous item |
| `<C-y>` | Accept the selected item |
| `<C-e>` | Dismiss the menu |
| `<C-space>` | Open menu, or open docs if menu is already open |
| `<C-k>` | Toggle function signature help |
| `<Tab>` / `<S-Tab>` | Move between snippet expansion points |

`<C-y>` is the confirm key. It accepts the completion, triggers auto-import if the LSP supports it, and expands any snippet the LSP sent. If you want to keep typing without accepting, just press any other key — the menu updates as you go.

Signature help (`<C-k>`) pops open a panel showing a function's parameters and documentation while your cursor is inside an argument list. It stays visible until you dismiss it or move outside the call.

---

## 11. Formatting, linting, and Git

### Formatting — conform.nvim

Format-on-save is active by default. The formatter used depends on the filetype:

| Filetype | Formatter |
|---|---|
| Lua | stylua |
| Go | goimports → gofumpt |
| Python | ruff (import sort, then format) |
| C / C++ | clang-format |
| Shell | shfmt |
| JS / TS / JSX / TSX / Vue / CSS / SCSS / HTML / JSON / YAML / Markdown | prettier |
| Rust | rust-analyzer (via LSP fallback) |

`<leader>f` triggers formatting manually in Normal or Visual mode. `:FormatToggle` disables format-on-save globally for the session; run it again to re-enable.

### Linting — nvim-lint

Linting runs on save and on FileType events. Two linters augment the LSPs:

- **markdownlint-cli2** for Markdown
- **stylelint** for CSS and SCSS

Shell files get shellcheck diagnostics through the bash-language-server — they show up in the normal diagnostic flow without any extra setup.

### Git — gitsigns

Gitsigns shows per-line change markers in the sign column: `+` for added lines, `~` for changed, `_` / `‾` for deleted. It also lets you act on individual hunks without leaving the editor.

**Navigating hunks:**

`]c` jumps to the next changed hunk; `[c` to the previous. In a diff view these do the native `[c`/`]c`; in a regular buffer they use gitsigns navigation.

**Hunk actions (Normal mode):**

| Key | Action |
|---|---|
| `<leader>hs` | Stage hunk |
| `<leader>hr` | Reset hunk (discard changes) |
| `<leader>hS` | Stage entire buffer |
| `<leader>hR` | Reset entire buffer |
| `<leader>hp` | Preview hunk in a float |
| `<leader>hi` | Preview hunk inline |
| `<leader>hb` | Blame current line (full commit info) |
| `<leader>hd` | Diff this file against the index |
| `<leader>hD` | Diff against the last commit |
| `<leader>hq` | Quickfix list of hunks in this file |
| `<leader>hQ` | Quickfix list of hunks across the whole repo |

In Visual mode, `<leader>hs` and `<leader>hr` act on the selected lines only — useful for staging part of a hunk rather than the whole thing.

**Toggles:** `<leader>tb` toggles per-line blame on every line. `<leader>tw` toggles word-level diff highlighting inside each hunk so you can see exactly which characters changed.

**Git hunk as a textobject:** `ih` selects the current hunk in Operator-pending and Visual mode. `dih` deletes it, `yih` yanks it.

---

## 12. Managing your config

### Treesitter — better syntax and indent

Treesitter provides richer syntax highlighting and smarter indentation than the legacy regex approach. Parsers for common languages (Go, Rust, Python, TypeScript, Lua, and more) are pre-seeded. When you open a file type that doesn't have a parser yet, it auto-installs one — you'll see a brief notification.

### Updating plugins

This config uses Neovim 0.12's built-in `vim.pack` plugin manager. To update all plugins:

```
:lua vim.pack.update()
```

To inspect what would change without downloading:

```
:lua vim.pack.update(nil, { offline = true })
```

Mason-managed tools (LSP servers, formatters, linters) update separately. Open `:Mason`, navigate to a tool, and press `u`.

### Health check — `:checkhealth`

`:checkhealth` runs Neovim's built-in diagnostics: verifies executables are on `PATH`, that plugins are configured correctly, and that your environment is sane. Run it after a fresh install, after a major plugin update, or whenever something feels off. `:checkhealth telescope` or `:checkhealth blink.cmp` targets a specific plugin.

### A note on two heavyweight servers

**lemminx** (XML) and **powershell_es** (PowerShell) are installed by Mason but require external runtimes: lemminx needs a JVM, powershell_es needs .NET. They are listed as installed but inert until those runtimes are present. If you never edit XML or PowerShell, ignore them. If you do, install `jdk-openjdk` (for lemminx) or `dotnet-runtime` (for PowerShell) via pacman.

### The config is yours to read

This is a kickstart-style config: every option lives in a file you own, commented, meant to be read top-to-bottom. `<leader>sn` opens Telescope over every file in the config directory. Start with `lua/options.lua` (editor settings) and `lua/keymaps.lua` (core maps), then browse the plugin files under `lua/kickstart/plugins/`. Your own additions go in `lua/custom/plugins/` — any `.lua` file there is picked up automatically.

---

## 13. Putting it together — three real workflows

### "I opened a TypeScript monorepo and want to rename a symbol across all files"

Open the file containing the symbol. The fidget spinner in the corner will settle once tsgo has finished indexing — on a cold first open of a large monorepo, give it a moment.

Move the cursor onto the symbol name. Press `grn`. A prompt appears; type the new name and `Enter`. The rename propagates across every file in the project. Neovim will ask you to confirm changes in any unloaded buffers — accept.

If `grn` doesn't work (tsgo's beta doesn't cover all refactor cases yet), press `<leader>ts` to switch this buffer to vtsls, retry `grn`, then press `<leader>ts` again to return to tsgo.

### "I'm lost in a big file and want to jump to a specific function"

Press `gO`. A Telescope picker lists every symbol in the current file — functions, types, variables, constants. Fuzzy-type the function name and press `Enter` to jump there.

If you can *see* the target on screen but navigating to it with a count feels imprecise, press `S`, type two characters from that area, and press the label that appears. You're there in under a second.

For a project-wide symbol search — "where is this type defined?" — use `gW` instead of `gO`. Same picker, all files.

### "I want to stage just part of my diff before committing"

Open the changed file. The sign column shows `+` and `~` markers next to every hunk. Navigate hunks with `]c` (next) and `[c` (previous). When you reach the hunk you want, press `<leader>hp` to see a floating diff of just that hunk — confirm it's the right change.

To stage the whole hunk: `<leader>hs`. To stage only specific lines from within it, select them with `V`, then `<leader>hs`.

If a hunk contains a stray debug line you want to drop before committing, `<leader>hr` resets just that hunk to the indexed version without touching anything else.

When you're ready to commit, switch to your terminal — or open one inside Neovim with `:terminal` and return to Normal mode with `<Esc><Esc>`.
