return { -- Useful plugin to show you pending keybinds.
    'folke/which-key.nvim',
    event = 'VimEnter', -- Sets the loading event to 'VimEnter'
    init = function()
        vim.o.timeout = true
        vim.o.timeoutlen = 2000
    end,
    config = function() -- This is the function that runs, AFTER loading
        require('which-key').setup()

        -- Document existing key chains
        require('which-key').add({
            { "<leader>c",  group = "[C]ode" },
            { "<leader>d",  group = "[D]ocument" },
            { "<leader>r",  group = "[R]ename" },
            { "<leader>s",  group = "[S]earch" },
            { "<leader>w",  group = "[W]orkspace" },
        })
    end,
}
