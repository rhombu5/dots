local function gh(repo) return 'https://github.com/' .. repo end

-- [[ Formatting ]]
vim.pack.add { gh 'stevearc/conform.nvim' }
-- Formatters keyed by filetype. Conform runs the listed formatters in order;
-- prettier only ever touches the current file (not the whole tree), so it stays
-- snappy even in large TS monorepos.
local formatters_by_ft = {
  lua = { 'stylua' },
  go = { 'goimports', 'gofumpt' },
  python = { 'ruff_organize_imports', 'ruff_format' },
  c = { 'clang-format' },
  cpp = { 'clang-format' },
  sh = { 'shfmt' },
  bash = { 'shfmt' },
  -- prettier handles the web/data formats
  javascript = { 'prettier' },
  javascriptreact = { 'prettier' },
  typescript = { 'prettier' },
  typescriptreact = { 'prettier' },
  vue = { 'prettier' },
  css = { 'prettier' },
  scss = { 'prettier' },
  less = { 'prettier' },
  html = { 'prettier' },
  json = { 'prettier' },
  jsonc = { 'prettier' },
  yaml = { 'prettier' },
  markdown = { 'prettier' },
  -- rust is formatted by rust-analyzer via the LSP fallback below.
}

require('conform').setup {
  notify_on_error = false,
  formatters_by_ft = formatters_by_ft,
  format_on_save = function(bufnr)
    -- Don't block the save if a formatter hangs; keep the timeout generous
    -- enough for prettier on a cold start but short enough to not feel janky.
    if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then return end
    if not formatters_by_ft[vim.bo[bufnr].filetype] then return end
    return { timeout_ms = 2000, lsp_format = 'fallback' }
  end,
  default_format_opts = {
    lsp_format = 'fallback', -- Use configured formatters; fall back to LSP formatting (e.g. rust-analyzer).
  },
}

-- Toggle format-on-save (global). Buffer-local `vim.b.disable_autoformat` also works.
vim.api.nvim_create_user_command('FormatToggle', function()
  vim.g.disable_autoformat = not vim.g.disable_autoformat
  vim.notify('Format-on-save ' .. (vim.g.disable_autoformat and 'disabled' or 'enabled'))
end, { desc = 'Toggle format-on-save' })

vim.keymap.set({ 'n', 'v' }, '<leader>f', function() require('conform').format { async = true } end, { desc = '[F]ormat buffer' })

-- vim: ts=2 sts=2 sw=2 et
