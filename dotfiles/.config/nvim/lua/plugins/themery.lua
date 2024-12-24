OriginalGruvboxDark0 = nil

-- High contrast version of Gruvbox dark
HCGruvboxDark0 = "#101010"

return {
    'zaldih/themery.nvim',
    dependencies = {
        'loctvl842/monokai-pro.nvim',
        'ellisonleao/gruvbox.nvim',
        'catppuccin/nvim',
        'folke/tokyonight.nvim',
        'rose-pine/neovim',
        'rebelot/kanagawa.nvim'
    },

    init = function()
        OriginalGruvboxDark0 = require('gruvbox').palette.dark0
    end,

    config = function()
        require('themery').setup({
            themes = {
                -----------------------------------------------------------------------------------------
                --- Light themes
                'catppuccin-latte',
                'tokyonight-day',
                'rose-pine-dawn',
                'kanagawa-lotus',
                {
                    name = 'Gruvbox light',
                    colorscheme = 'gruvbox',
                    before = [[vim.opt.background = "light" ]],
                },
                {
                    name = 'default light',
                    colorscheme = 'default',
                    before = [[vim.opt.background = "light" ]],
                },
                -----------------------------------------------------------------------------------------
                --- Dark themes
                {
                    name = 'Gruvbox dark',
                    colorscheme = 'gruvbox',
                    before = [[
                        vim.opt.background = "dark"
                        require('gruvbox').palette.dark0 = OriginalGruvboxDark0
                    ]],
                },
                {
                    name = 'Gruvbox dark high contrast',
                    colorscheme = 'gruvbox',
                    before = [[
                        vim.opt.background = "dark"
                        require('gruvbox').palette.dark0 = HCGruvboxDark0
                    ]],
                },
                {
                    name = 'default dark',
                    colorscheme = 'default',
                    before = [[vim.opt.background = "dark" ]],
                },
                'monokai-pro-default',
                'monokai-pro-classic',
                'monokai-pro-machine',
                'monokai-pro-octagon',
                'monokai-pro-ristretto',
                'monokai-pro-spectrum',
                'catppuccin-mocha',
                'catppuccin-frappe',
                'catppuccin-macchiato',
                'tokyonight-moon',
                'tokyonight-night',
                'tokyonight-storm',
                'rose-pine-main',
                'rose-pine-moon',
                'kanagawa-dragon',
                'kanagawa-wave',
            }, -- Your list of installed colorschemes
            livePreview = true, -- Apply theme while browsing. Default to true.
        })
    end,
}
