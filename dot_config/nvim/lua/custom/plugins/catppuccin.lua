-- Catppuccin Mocha — matches the Ghostty terminal theme
-- (kickstart's default tokyonight is commented out in lua/plugins.lua)
vim.pack.add { 'https://github.com/catppuccin/nvim' }

require('catppuccin').setup {
  flavour = 'mocha',
}

vim.cmd.colorscheme 'catppuccin-mocha'

-- vim: ts=2 sts=2 sw=2 et
