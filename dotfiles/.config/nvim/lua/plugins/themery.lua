return {
    'zaldih/themery.nvim',
    dependencies = {
        'loctvl842/monokai-pro.nvim',
        'ellisonleao/gruvbox.nvim',
        'catppuccin/nvim',
    },
    config = function()
        require('themery').setup({
            themes = {
                'catppuccin-latte',
                {
                    name = 'Gruvbox light',
                    colorscheme = 'gruvbox',
                    before = [[vim.opt.background = "light" ]],
                },
                {
                    name = 'Gruvbox dark',
                    colorscheme = 'gruvbox',
                    before = [[ vim.opt.background = "dark" ]],
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
            }, -- Your list of installed colorschemes
            themeConfigFile = '~/.config/nvim/lua/settings/theme.lua', -- Described below
            livePreview = true, -- Apply theme while browsing. Default to true.
        })
        require('settings/theme')
    end,
}
