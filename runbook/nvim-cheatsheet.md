# nvim cheatsheet

Quick reference for the custom Neovim setup. Paired with `nvim-tutorial.md` (the explainer).

---

## Leader & essentials

Leader key is `<Space>`. which-key popup appears immediately on pause (`delay = 0`) — start a chord and wait to see available completions.

| Key | Action |
|---|---|
| `<Esc>` *(normal)* | Clear search highlights (`nohlsearch`) |
| `<C-h>` / `<C-l>` | Focus left / right window |
| `<C-j>` / `<C-k>` | Focus lower / upper window |
| `<Esc><Esc>` *(terminal)* | Exit terminal mode → normal |
| `<leader>q` | Open diagnostic quickfix list |

**which-key groups:** `<leader>s` Search · `<leader>t` Toggle · `<leader>h` Git Hunk · `gr` LSP Actions

---

## Motion & learning plugins

`s` is claimed by mini.surround, so flash jump lives on `S`.

| Key | Action |
|---|---|
| `S` *(n/x/o)* | Flash label-jump to any visible position |
| `r` *(o)* | Flash remote — apply operator to a remote target |
| `f` / `t` / `F` / `T` | Enhanced with flash labels (jump further via label) |
| `<leader>tH` | Toggle Hardtime motion nagging |
| `<leader>tp` | Toggle Precognition passive motion hints |

```vim
:Tutor          " built-in interactive tutorial (~30 min, start here)
:VimBeGood      " motion drill mini-games (ThePrimeagen)
:Hardtime toggle
:Precognition toggle
```

---

## LSP

Keys active whenever an LSP is attached to the buffer.

| Key | Action |
|---|---|
| `grn` | Rename symbol across files |
| `gra` *(n/x)* | Code action |
| `grD` | Go to declaration (e.g. C header) |
| `grd` | Go to definition *(Telescope)* |
| `grr` | Find references *(Telescope)* |
| `gri` | Go to implementation *(Telescope)* |
| `grt` | Go to type definition *(Telescope)* |
| `gO` | Document symbols picker *(Telescope)* |
| `gW` | Workspace symbols picker *(Telescope)* |
| `K` | Hover documentation *(Neovim default)* |
| `<C-k>` *(insert)* | Toggle signature help *(blink.cmp)* |
| `[d` / `]d` | Prev / next diagnostic; float auto-opens *(Neovim default)* |
| `<leader>q` | Diagnostics → quickfix list |
| `<leader>th` | Toggle inlay hints *(if server supports it)* |
| `<C-t>` | Jump back in tag/location stack *(Neovim default)* |

---

## TypeScript: tsgo ⇄ vtsls

**tsgo** (TS 7 "Corsa", native Go port) is the default — monorepo-aware, single instance. Must be on `PATH` via mise; launch nvim from a mise-activated shell.

**vtsls** is the dormant fallback — richer refactors/quick-fixes for the cases tsgo's beta doesn't cover. Never both at once.

| Method | How |
|---|---|
| Pin project to vtsls | Commit empty `.nvim-ts-node` at project root |
| One-off buffer switch | `<leader>ts` — toggles active server for current buffer only |

```sh
# ensure tsgo is available
mise use -g npm:@typescript/native-preview@beta
```

---

## Find / navigate (Telescope)

| Key | Action |
|---|---|
| `<leader><leader>` | Open buffers |
| `<leader>/` | Fuzzy search current buffer |
| `<leader>sf` | Find files |
| `<leader>sg` | Live grep (project) |
| `<leader>sw` *(n/v)* | Grep word under cursor / selection |
| `<leader>s/` | Live grep in open files only |
| `<leader>sr` | Resume last search |
| `<leader>s.` | Recent files |
| `<leader>sh` | Search `:help` tags |
| `<leader>sk` | Search keymaps |
| `<leader>sc` | Search commands |
| `<leader>sd` | Search diagnostics |
| `<leader>ss` | Pick Telescope picker |
| `<leader>sn` | Find files in nvim config dir |

Inside a Telescope picker: `<C-/>` (insert) or `?` (normal) → show picker keymaps.

---

## Edit: textobjects & surround

### mini.ai textobjects

Standard form: `a{obj}` / `i{obj}`. Next-object variant: `aa{obj}` / `ii{obj}`.

| Object | Matches |
|---|---|
| `)` `]` `}` `>` | Bracket pairs |
| `'` `"` `` ` `` | Quotes |
| `t` | HTML/XML tag |
| `f` | Function call |
| `a` | Argument |

Examples: `va)` select around paren · `yiiq` yank inside next quote · `ci'` change inside quote

### mini.surround (prefix `s`)

| Key | Action |
|---|---|
| `sa{motion}{char}` | Add surrounding — e.g. `saiwb` wraps word in `()` |
| `sd{char}` | Delete surrounding — e.g. `sd'` removes `'…'` |
| `sr{old}{new}` | Replace surrounding — e.g. `sr)"` turns `(…)` → `"…"` |

---

## Completion (blink.cmp)

Using the `default` preset. Sources: LSP · path · LuaSnip snippets.

| Key | Action |
|---|---|
| `<C-y>` | Accept completion (auto-imports + expands snippets) |
| `<C-n>` / `↓` | Select next item |
| `<C-p>` / `↑` | Select previous item |
| `<C-e>` | Hide menu |
| `<C-space>` | Open menu; if already open, open docs |
| `<C-k>` | Toggle signature help |
| `<Tab>` / `<S-Tab>` | Move right / left within snippet expansion |

---

## Format & lint

| Key / Command | Action |
|---|---|
| `<leader>f` *(n/v)* | Format buffer / selection (async) |
| `:FormatToggle` | Toggle format-on-save globally (`vim.g.disable_autoformat`) |
| `vim.b.disable_autoformat = true` | Disable for current buffer only |

**Format-on-save filetypes:**

| Formatter | Filetypes |
|---|---|
| prettier | js · jsx · ts · tsx · vue · css · scss · less · html · json · jsonc · yaml · md |
| stylua | lua |
| gofumpt + goimports | go |
| ruff | python |
| clang-format | c · cpp |
| shfmt | sh · bash |
| rust-analyzer *(LSP fallback)* | rust |

**Linters (nvim-lint):** markdownlint-cli2 (md) · stylelint (css/scss) · shellcheck (via bashls)

---

## Git (gitsigns)

| Key | Action |
|---|---|
| `]c` / `[c` | Next / prev hunk (or diff `]c`/`[c` in diff mode) |
| `<leader>hs` *(n/v)* | Stage hunk / selection |
| `<leader>hr` *(n/v)* | Reset hunk / selection |
| `<leader>hS` | Stage entire buffer |
| `<leader>hR` | Reset entire buffer |
| `<leader>hp` | Preview hunk (floating) |
| `<leader>hi` | Preview hunk inline |
| `<leader>hb` | Blame line (full) |
| `<leader>hd` | Diff against index |
| `<leader>hD` | Diff against last commit (`@`) |
| `<leader>hq` | Hunk quickfix list (current file) |
| `<leader>hQ` | Hunk quickfix list (all repo files) |
| `<leader>tb` | Toggle inline blame |
| `<leader>tw` | Toggle intra-line word diff |
| `ih` *(o/x)* | Hunk text object |

---

## Manage

```vim
:Mason           " manage LSP servers, formatters, linters (g? for help)
:checkhealth     " Neovim + plugin health checks
```

**Plugins use `vim.pack` (Neovim built-in), not lazy.nvim:**

```lua
:lua vim.pack.update()                         -- update all plugins
:lua vim.pack.update(nil, { offline = true })  -- inspect without network
```

Treesitter parsers install automatically on first open of a new filetype. No manual `:TSInstall` needed.

---

## Installed LSP servers

Managed by Mason (`:Mason`). `tsgo` is the exception — installed via mise, not Mason.

| Language(s) | Server(s) |
|---|---|
| Lua | lua_ls |
| TypeScript / JS | tsgo *(primary, mise)* · vtsls *(fallback)* · eslint |
| HTML | html · emmet_language_server |
| CSS / SCSS | cssls · somesass_ls · tailwindcss |
| Vue | vue_ls *(Volar, standalone)* |
| Go | gopls |
| Rust | rust_analyzer |
| Python | basedpyright + ruff |
| C / C++ | clangd |
| Shell | bashls *(+ shellcheck)* · fish_lsp |
| JSON / YAML / TOML | jsonls · yamlls · taplo |
| Markdown | marksman |
| systemd units | systemd_lsp |
| XML | lemminx *(needs JRE)* |
| PowerShell | powershell_es *(needs .NET)* |
