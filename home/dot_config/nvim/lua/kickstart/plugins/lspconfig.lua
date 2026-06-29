local function gh(repo) return 'https://github.com/' .. repo end

-- [[ LSP Configuration ]]
-- Brief aside: **What is LSP?**
--
-- LSP is an initialism you've probably heard, but might not understand what it is.
--
-- LSP stands for Language Server Protocol. It's a protocol that helps editors
-- and language tooling communicate in a standardized fashion.
--
-- In general, you have a "server" which is some tool built to understand a particular
-- language (such as `gopls`, `lua_ls`, `rust_analyzer`, etc.). These Language Servers
-- (sometimes called LSP servers, but that's kind of like ATM Machine) are standalone
-- processes that communicate with some "client" - in this case, Neovim!
--
-- LSP provides Neovim with features like:
--  - Go to definition
--  - Find references
--  - Autocompletion
--  - Symbol Search
--  - and more!
--
-- Thus, Language Servers are external tools that must be installed separately from
-- Neovim. This is where `mason` and related plugins come into play.
--
-- If you're wondering about lsp vs treesitter, you can check out the wonderfully
-- and elegantly composed help section, `:help lsp-vs-treesitter`

-- Useful status updates for LSP.
vim.pack.add { gh 'j-hui/fidget.nvim' }
require('fidget').setup {}

--  This function gets run when an LSP attaches to a particular buffer.
--    That is to say, every time a new file is opened that is associated with
--    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
--    function will be executed to configure the current buffer
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
  callback = function(event)
    -- NOTE: Remember that Lua is a real programming language, and as such it is possible
    -- to define small helper and utility functions so you don't have to repeat yourself.
    --
    -- In this case, we create a function that lets us more easily define mappings specific
    -- for LSP related items. It sets the mode, buffer and description for us each time.
    local map = function(keys, func, desc, mode)
      mode = mode or 'n'
      vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
    end

    -- Rename the variable under your cursor.
    --  Most Language Servers support renaming across files, etc.
    map('grn', vim.lsp.buf.rename, '[R]e[n]ame')

    -- Execute a code action, usually your cursor needs to be on top of an error
    -- or a suggestion from your LSP for this to activate.
    map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })

    -- WARN: This is not Goto Definition, this is Goto Declaration.
    --  For example, in C this would take you to the header.
    map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

    -- The following two autocommands are used to highlight references of the
    -- word under your cursor when your cursor rests there for a little while.
    --    See `:help CursorHold` for information about when this is executed
    --
    -- When you move your cursor, the highlights will be cleared (the second autocommand).
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if client and client:supports_method('textDocument/documentHighlight', event.buf) then
      local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
      vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.document_highlight,
      })

      vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
        buffer = event.buf,
        group = highlight_augroup,
        callback = vim.lsp.buf.clear_references,
      })

      vim.api.nvim_create_autocmd('LspDetach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
        callback = function(event2)
          vim.lsp.buf.clear_references()
          vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
        end,
      })
    end

    -- The following code creates a keymap to toggle inlay hints in your
    -- code, if the language server you are using supports them
    --
    -- This may be unwanted, since they displace some of your code
    if client and client:supports_method('textDocument/inlayHint', event.buf) then
      map('<leader>th', function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }) end, '[T]oggle Inlay [H]ints')
    end
  end,
})

-- Enable the following language servers.
--  Each key is an `nvim-lspconfig` server name; the value overrides/extends the
--  config shipped in that plugin's `lsp/<name>.lua`. They are installed via Mason
--  (mason-tool-installer translates the lspconfig name to the Mason package name)
--  and auto-enabled in the loop below. See `:help lsp-config`.
--
--  NOTE: TypeScript itself is intentionally absent here — `tsgo`/`vtsls` are wired
--  up separately further down (see the tsgo ⇄ vtsls section).
---@type table<string, vim.lsp.Config>
local servers = {
  -- Special Lua config (kept from kickstart): defer formatting to stylua.
  lua_ls = {
    on_init = function(client)
      client.server_capabilities.documentFormattingProvider = false -- Disable formatting (formatting is done by stylua)

      if client.workspace_folders then
        local path = client.workspace_folders[1].name
        if path ~= vim.fn.stdpath 'config' and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc')) then return end
      end

      client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
        runtime = {
          version = 'LuaJIT',
          path = { 'lua/?.lua', 'lua/?/init.lua' },
        },
        workspace = {
          checkThirdParty = false,
          -- NOTE: this is a lot slower and will cause issues when working on your own configuration.
          --  See https://github.com/neovim/nvim-lspconfig/issues/3189
          library = vim.tbl_extend('force', vim.api.nvim_get_runtime_file('', true), {
            '${3rd}/luv/library',
            '${3rd}/busted/library',
          }),
        },
      })
    end,
    ---@type lspconfig.settings.lua_ls
    settings = {
      Lua = {
        format = { enable = false }, -- Disable formatting (formatting is done by stylua)
      },
    },
  },

  -- Web / JS ecosystem.
  eslint = {},
  emmet_language_server = {},
  cssls = {},
  somesass_ls = {},
  tailwindcss = {},
  html = {},
  vue_ls = {}, -- Volar, standalone mode (basic Vue SFC support)

  -- Backend / systems languages.
  gopls = {},
  rust_analyzer = {},
  basedpyright = {},
  clangd = {},

  -- Config / data / shell / misc.
  bashls = {},
  fish_lsp = {},
  jsonls = {},
  yamlls = {},
  taplo = {}, -- TOML
  marksman = {}, -- Markdown
  systemd_lsp = {}, -- systemd unit files
  lemminx = {}, -- XML (JVM-heavy, loads only on .xml)
  powershell_es = {}, -- PowerShell (.NET-heavy, loads only on .ps1)
}

vim.pack.add {
  gh 'neovim/nvim-lspconfig',
  gh 'mason-org/mason.nvim',
  gh 'mason-org/mason-lspconfig.nvim',
  gh 'WhoIsSethDaniel/mason-tool-installer.nvim',
}

-- Automatically install LSPs and related tools to stdpath for Neovim
require('mason').setup {}

-- Mason package list: every server above, plus the dormant `vtsls` fallback and
-- the formatters/linters. mason-tool-installer maps lspconfig names -> Mason names.
--
-- NOTE: `tsgo` is deliberately NOT here — it is installed via mise
--   (`mise use -g npm:@typescript/native-preview@beta`), not Mason, per the
--   no-system-wide-devtools rule. nvim finds it on PATH when launched from a
--   mise-activated shell.
--
-- To inspect/manage installed tools, run `:Mason` (`g?` for help).
local ensure_installed = vim.tbl_keys(servers or {})
vim.list_extend(ensure_installed, {
  'vtsls', -- dormant TypeScript fallback (see tsgo ⇄ vtsls section)
  -- Formatters (driven by conform.nvim)
  'stylua',
  'prettier',
  'gofumpt',
  'goimports',
  'clang-format',
  'shfmt',
  -- Linters: ruff (python, via basedpyright sibling), stylelint + markdownlint-cli2
  -- (via nvim-lint), shellcheck (surfaced by bash-language-server).
  'ruff',
  'stylelint',
  'markdownlint-cli2',
  'shellcheck',
})

require('mason-tool-installer').setup { ensure_installed = ensure_installed }

for name, server in pairs(servers) do
  vim.lsp.config(name, server)
  vim.lsp.enable(name)
end

-- ============================================================================
-- TypeScript: tsgo (primary) ⇄ vtsls (dormant fallback) — never both at once.
-- ============================================================================
--  * tsgo — TypeScript 7 "Corsa", the native Go port of tsserver — is the
--    default and attaches to every JS/TS project. It is monorepo-aware and runs
--    a single instance, which is what we want for the big TS trees.
--  * vtsls stays dormant and only attaches in a project whose root contains the
--    sentinel file `.nvim-ts-node` (commit it to pin that project to vtsls). Use
--    it for the few refactors / quick-fixes / renames tsgo's beta doesn't cover.
--  * `<leader>ts` toggles the active server for the *current buffer* only, for
--    one-offs — it overrides the sentinel for that buffer.
--  Both share the same deno-aware, monorepo-aware root resolution shipped by
--  nvim-lspconfig; we only graft the sentinel decision on top.
local TS_SENTINEL = '.nvim-ts-node'

-- Capture the shipped root_dir resolvers BEFORE overriding them, so the gate
-- reuses their (deno-aware, lockfile-based) logic and only adds the sentinel.
local tsgo_root = vim.lsp.config.tsgo.root_dir
local vtsls_root = vim.lsp.config.vtsls.root_dir

local function project_uses_vtsls(dir) return vim.uv.fs_stat(vim.fs.joinpath(dir, TS_SENTINEL)) ~= nil end

-- Wrap a shipped root_dir so it only resolves when this buffer should use
-- `server`. A per-buffer override (set by the toggle) wins; else the sentinel.
local function gated_root(default_root, server)
  return function(bufnr, on_dir)
    default_root(bufnr, function(dir)
      local chosen = vim.b[bufnr].ts_server or (project_uses_vtsls(dir) and 'vtsls' or 'tsgo')
      if chosen == server then on_dir(dir) end
    end)
  end
end

vim.lsp.config('tsgo', { root_dir = gated_root(tsgo_root, 'tsgo') })
vim.lsp.config('vtsls', { root_dir = gated_root(vtsls_root, 'vtsls') })
vim.lsp.enable { 'tsgo', 'vtsls' }

if vim.fn.executable 'tsgo' == 0 then
  vim.schedule(function()
    vim.notify(
      'tsgo not on PATH — run `mise use -g npm:@typescript/native-preview@beta`, or launch nvim from a mise-activated shell.',
      vim.log.levels.WARN
    )
  end)
end

-- One-off, per-buffer switch between tsgo and vtsls.
local function toggle_ts_server()
  local bufnr = vim.api.nvim_get_current_buf()
  local active
  for _, c in ipairs(vim.lsp.get_clients { bufnr = bufnr }) do
    if c.name == 'tsgo' or c.name == 'vtsls' then active = c.name end
  end
  active = active or vim.b[bufnr].ts_server or 'tsgo'
  local target = active == 'tsgo' and 'vtsls' or 'tsgo'
  vim.b[bufnr].ts_server = target

  -- Detach whichever TS server is currently on this buffer.
  for _, c in ipairs(vim.lsp.get_clients { bufnr = bufnr }) do
    if c.name == 'tsgo' or c.name == 'vtsls' then vim.lsp.buf_detach_client(bufnr, c.id) end
  end

  -- Start the target on this buffer with a concrete root.
  local cfg = vim.deepcopy(vim.lsp.config[target])
  cfg.name = target
  cfg.root_dir = vim.fs.root(bufnr, { 'tsconfig.json', 'jsconfig.json', 'package.json', '.git' }) or vim.fn.getcwd()
  vim.lsp.start(cfg, { bufnr = bufnr })
  vim.notify('TypeScript LSP → ' .. target)
end
vim.keymap.set('n', '<leader>ts', toggle_ts_server, { desc = '[T]oggle TypeScript [S]erver (tsgo ⇄ vtsls, buffer)' })

-- vim: ts=2 sts=2 sw=2 et
