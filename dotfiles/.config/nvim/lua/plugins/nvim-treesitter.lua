return { -- Highlight, edit, and navigate code
    {
        'nvim-treesitter/nvim-treesitter',
        build = ':TSUpdate',
        opts = {
            ensure_installed = {
                'bash',
                'c',
                'cmake',
                'cpp',
                'dockerfile',
                'gitcommit',
                'html',
                'lua',
                'python',
                'groovy',
                'markdown',
                'query',
                'rst',
                'vim',
                'vimdoc',
            },
            highlight = { enable = true },
            indent = { enable = true },
        },
        config = function(_, opts)
            require 'nvim-treesitter'.install(opts.ensure_installed)
            vim.api.nvim_create_autocmd('FileType', {
                pattern = opts.ensure_installed,
                callback = function()
                    -- syntax highlighting, provided by Neovim
                    vim.treesitter.start()
                    -- folds, provided by Neovim
                    vim.wo.foldexpr = 'v:lua.vim.treesitter.foldexpr()'
                    vim.wo.foldmethod = 'expr'
                    -- indentation, provided by nvim-treesitter
                    vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
                end,
            })
        end,
    },
    {
        'nvim-treesitter/nvim-treesitter-textobjects',
        branch = "main",
        dependencies = { 'nvim-treesitter/nvim-treesitter' },
        config = function()
            require('nvim-treesitter-textobjects').setup {
                select = {
                    lookahead = true,
                    selection_modes = {
                        ['@parameter.outer'] = 'v',
                        ['@statement.outer'] = 'V',
                        ['@function.outer'] = 'V',
                        ['@class.outer'] = '<c-v>',
                    },
                    include_surrounding_whitespace = false,
                },
            }

            local select = require('nvim-treesitter-textobjects.select').select_textobject
            vim.keymap.set({ 'x', 'o' }, 'af', function() select('@function.outer', 'textobjects') end)
            vim.keymap.set({ 'x', 'o' }, 'if', function() select('@function.inner', 'textobjects') end)
            vim.keymap.set({ 'x', 'o' }, 'ac', function() select('@class.outer', 'textobjects') end)
            vim.keymap.set({ 'x', 'o' }, 'ic', function() select('@class.inner', 'textobjects') end)
            vim.keymap.set({ 'x', 'o' }, 'as', function() select('@statement.outer', 'textobjects') end)
            vim.keymap.set({ 'x', 'o' }, 'ap', function() select('@parameter.outer', 'textobjects') end)
            vim.keymap.set({ 'x', 'o' }, 'ab', function() select('@block.outer', 'textobjects') end)
        end,
    },
}
