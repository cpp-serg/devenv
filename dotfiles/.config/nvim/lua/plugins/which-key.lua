return { -- Useful plugin to show you pending keybinds.
    'folke/which-key.nvim',
    event = 'VimEnter', -- Sets the loading event to 'VimEnter'
    init = function()
        vim.o.timeout = true
        vim.o.timeoutlen = 2000
    end,
    opts = {
        preset = 'helix',
        delay = 1000,
    },
}
