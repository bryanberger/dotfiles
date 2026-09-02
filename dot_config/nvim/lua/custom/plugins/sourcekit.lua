-- Swift: sourcekit-lsp ships with Xcode, so mason can't install it.
-- It stays out of the `servers` table in kickstart/plugins/lspconfig.lua
-- (mason-tool-installer would try to install everything listed there and fail).
-- nvim-lspconfig ships the server definition, so enabling it is all that's needed.
vim.lsp.enable 'sourcekit'

-- vim: ts=2 sts=2 sw=2 et
