return {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.5',
    dependencies = { 'nvim-lua/plenary.nvim' },
    opts={
        defaults = {
            layout = 'vertical',
            layout_config={width=0.99,height=0.99},
        },
        pickers = {
            lsp_code_actions = { theme = "cursor" },
        },
    },
}
