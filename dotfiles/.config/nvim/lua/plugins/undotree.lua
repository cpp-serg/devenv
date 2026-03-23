return {
    'jiaoshijie/undotree',
    dependencies = 'nvim-lua/plenary.nvim',
    keys = {
        { '<leader>u', function() require('undotree').toggle() end, desc = 'Toggle Undotree' },
    },
    opts = {
        keymaps = {
            ["<tab>"] = "enter_diffbuf",
        },
    },
    config = function(_, opts)
        require('undotree').setup(opts)
        -- The plugin hardcodes 'p' in the preview buffer for switching back.
        -- Add <tab> in the preview buffer via autocmd so it works both ways.
        vim.api.nvim_create_autocmd('FileType', {
            pattern = 'UndotreeDiff',
            callback = function(args)
                vim.keymap.set('n', '<tab>', function()
                    for _, w in ipairs(vim.api.nvim_list_wins()) do
                        if vim.bo[vim.api.nvim_win_get_buf(w)].filetype == 'undotree' then
                            vim.fn.win_gotoid(w)
                            return
                        end
                    end
                end, { buffer = args.buf, noremap = true, silent = true })
            end,
        })
    end,
}
