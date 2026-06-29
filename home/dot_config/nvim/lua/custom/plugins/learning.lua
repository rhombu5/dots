-- Motion-learning / training plugins.
--  Built-in first stop (not a plugin): run `:Tutor` (~30 min) before anything else.
local function gh(repo) return 'https://github.com/' .. repo end

vim.pack.add {
  gh 'ThePrimeagen/vim-be-good', -- `:VimBeGood` — motion drill mini-games
  gh 'MunifTanjim/nui.nvim', -- dependency of hardtime.nvim
  gh 'm4xshen/hardtime.nvim', -- nags/blocks inefficient motions during real edits
  gh 'tris203/precognition.nvim', -- passive hints showing the motions available right now
  gh 'folke/flash.nvim', -- label-jump navigation (also enhances f/t/F/T)
}

-- hardtime: on by default so good habits stick, but deliberately easy to silence.
require('hardtime').setup {
  max_count = 4, -- allow a few repeats of j/k/etc. before nagging
  disable_mouse = false,
}
vim.keymap.set('n', '<leader>tH', function() require('hardtime').toggle() end, { desc = '[T]oggle [H]ardtime (motion nagging)' })

-- precognition: passive motion hints, shown by default while learning.
require('precognition').setup { startVisible = true }
vim.keymap.set('n', '<leader>tp', function() require('precognition').toggle() end, { desc = '[T]oggle [P]recognition hints' })

-- flash: label-jump. `s` is taken by mini.surround, so jump is on `S`.
require('flash').setup {}
vim.keymap.set({ 'n', 'x', 'o' }, 'S', function() require('flash').jump() end, { desc = 'Flash jump' })
vim.keymap.set('o', 'r', function() require('flash').remote() end, { desc = 'Flash remote (operator)' })
