return {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.5',
    dependencies = {
        'nvim-lua/plenary.nvim',
        { -- If encountering errors, see telescope-fzf-native README for install instructions
            'nvim-telescope/telescope-fzf-native.nvim',

            -- `build` is used to run some command when the plugin is installed/updated.
            -- This is only run then, not every time Neovim starts up.
            build = 'make',

            -- `cond` is a condition used to determine whether this plugin should be
            -- installed and loaded.
            cond = function()
                return vim.fn.executable 'make' == 1
            end,
        },
        { 'nvim-telescope/telescope-ui-select.nvim' },
        { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
    },
    --[[
    opts={
        defaults = {
            layout = 'vertical',
            layout_config={width=0.99,height=0.99},
        },
        pickers = {
            lsp_code_actions = { theme = "cursor" },
        },
    },
    ]]
    config = function()
        require('telescope').setup {
            defaults = {
                layout = 'vertical',
                layout_config={width=0.99,height=0.99},
            },
            pickers = {
                lsp_code_actions = { theme = "cursor" },
            },
            -- You can put your default mappings / updates / etc. in here
        --  All the info you're looking for is in `:help telescope.setup()`
        --
        -- defaults = {
        --   mappings = {
        --     i = { ['<c-enter>'] = 'to_fuzzy_refine' },
        --   },
        -- },
        -- pickers = {}
            extensions = {
              ['ui-select'] = {
                require('telescope.themes').get_dropdown(),
              },
            },
        }

        -- Enable telescope extensions, if they are installed
        pcall(require('telescope').load_extension, 'fzf')
        pcall(require('telescope').load_extension, 'ui-select')
        pcall(require('telescope').load_extension, 'ui-select')
    end
}
