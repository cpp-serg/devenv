return {
    { 'nvim-lua/plenary.nvim' }, -- Utilities widely used in other plugins

    -- icons
    { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    { 'echasnovski/mini.icons', version = false },

    { 'tpope/vim-sleuth' }, -- Detect tabstop and shiftwidth automatically
    { 'tpope/vim-fugitive',          enabled = not vim.g.vscode, },

    { 'folke/neoconf.nvim', cmd = 'Neoconf' },
    { 'folke/neodev.nvim'},
    { 'folke/trouble.nvim',    enabled = not vim.g.vscode },

    { 'rhysd/vim-clang-format'},
    -- { 'SmiteshP/nvim-navic', opts = { lsp = { auto_attach = true, preference = nil, }, } },
}
