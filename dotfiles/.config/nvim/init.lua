-- disable netrw at the very start of init.lua, so nvim-tree takes care of file navigation
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- User Config
-- ---
vim.g.user = {
  leaderkey = ' ',
  transparent = false,
  event = 'UserGroup',
  config = {
    undodir = vim.fn.stdpath('cache') .. '/undo',
  },
}
vim.api.nvim_create_augroup(vim.g.user.event, {})

vim.g.python3_host_prog = '/usr/local/python-3.11.3/bin/python3.11'

vim.g.have_nerd_font = true

-- optionally enable 24-bit colour
vim.opt.termguicolors = true

vim.g.mapleader = vim.g.user.leaderkey
vim.g.maplocalleader = vim.g.user.leaderkey

vim.g.syntax = 1

vim.wo.number = true
vim.wo.relativenumber = true

vim.opt.tabstop = 4
vim.opt.softtabstop = 0
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.smarttab = true
-- vim.opt.smartindent = true
-- vim.opt.cindent = true

vim.opt.list = true
vim.opt.listchars = { tab = '⇥‧', trail = '˽', extends = '⯈', precedes = '⯇' }

vim.opt.mouse = 'a'
vim.opt.showmode = false
vim.opt.clipboard = 'unnamedplus'

vim.opt.breakindent = true

vim.opt.undofile = true

-- Case-insensitive searching UNLESS \C or capital in search
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Keep signcolumn on by default
vim.opt.signcolumn = 'yes'

-- Decrease update time
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300

-- Configure how new splits should be opened
vim.opt.splitright = true
vim.opt.splitbelow = true

vim.opt.inccommand = 'split'

-- Show which line your cursor is on
vim.opt.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
vim.opt.scrolloff = 5

vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }),
    callback = function()
        vim.highlight.on_yank()
    end,
})

-- Fix user type errors
vim.api.nvim_create_user_command('Q','q',{ desc = 'Quit'})
vim.api.nvim_create_user_command('Qa','qa',{ desc = 'Quit all'})
vim.api.nvim_create_user_command('W','w',{ desc = 'Write'})
vim.api.nvim_create_user_command('Wq','wq',{ desc = 'Write and quit'})
vim.api.nvim_create_user_command('Wa','wa',{ desc = 'Write all'})
vim.api.nvim_create_user_command('Wqa','wqa',{ desc = 'Write all and quit'})
vim.api.nvim_create_user_command('WQ','wq',{ desc = 'Write and quit'})
vim.api.nvim_create_user_command('WQa','wqa',{ desc = 'Write all and quit'})


vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldtext = "v:lua.vim.treesitter.foldtext()"

vim.opt.foldmethod = "expr"
vim.opt.foldenable = false
vim.opt.foldcolumn = "auto"

vim.opt.hlsearch = true

vim.opt.makeprg = 'ninja'


-- [[ Install `lazy.nvim` plugin manager ]]
--    See `:help lazy.nvim.txt` or https://github.com/folke/lazy.nvim for more info
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({
        'git',
        'clone',
        '--filter=blob:none',
        'https://github.com/folke/lazy.nvim.git',
        '--branch=stable', -- latest stable release
        lazypath,
    })
end
vim.opt.rtp:prepend(lazypath)

local lazyConf = {
    ui = not vim.g.have_nerd_font and {} or {
        icons = {
            cmd = " ",
            config = '🛠',
            event = "",
            -- event = '📅',
            ft = '📂',
            init = '⚙',
            import = " ",
            keys = " ",
            lazy = '💤 ',
            loaded = "●",
            not_loaded = "○",
            plugin = '🔌',
            runtime = '💻',
            -- runtime = " ",
            require = "󰢱 ",
            source = " ",
            start = "",
            task = '📌',
            list = {
                "●",
                "➜",
                "★",
                "‒",
            },
        },
    }
}

require('lazy').setup('plugins',lazyConf)
------------------------------------------------------------

-- -- From vim defaults.vim
-- ---
-- When editing a file, always jump to the last known cursor position.
-- Don't do it when the position is invalid, when inside an event handler
-- (happens when dropping a file on gvim) and for a commit message (it's
-- likely a different one than last time).
vim.api.nvim_create_autocmd('BufReadPost', {
    group = vim.g.user.event,
    callback = function(args)
        local valid_line = vim.fn.line([['"]]) >= 1 and vim.fn.line([['"]]) < vim.fn.line('$')
        local commit = vim.b[args.buf].filetype == 'commit'

        if valid_line and not commit then
            vim.cmd([[normal! g`"]])
        end
  end,
})

local function ToggleLinesOnOff()
    vim.wo.number = not vim.wo.number
    vim.wo.relativenumber = not vim.wo.relativenumber
end

-- stylua: ignore
local function SetKeymap()
    -- [[ Basic Keymaps ]]
    --  See `:help vim.keymap.set()`
    vim.keymap.set('n', '<leader>HH'      , '<cmd>e ~/.config/nvim/init.lua<cr>'    , { desc = 'Edit nvim init' })

    -- Clear hlsearch on pressing <Esc> in normal mode
    vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<cr>')

    vim.keymap.set('n', '<C-n>', '<cmd>NvimTreeToggle<cr>')
    vim.keymap.set('n', '<Tab>', '<cmd>e #<cr>')
    vim.keymap.set('n', '<leader>x', '<cmd>bdelete<cr>')
    vim.keymap.set('n', '<leader>X', '<cmd>bdelete!<cr>')
    vim.keymap.set('n', '<leader>bO', '<cmd>BufferLineCloseOthers<cr>')

    -- Diagnostic keymaps
    vim.keymap.set('n', '[d'       , vim.diagnostic.goto_prev , { desc = 'Go to previous [D]iagnostic message' })
    vim.keymap.set('n', ']d'       , vim.diagnostic.goto_next , { desc = 'Go to next [D]iagnostic message' })
    vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Show diagnostic [E]rror messages' })
    vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

    -- Disable arrow keys in normal mode
    vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<cr>')
    vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<cr>')
    vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<cr>')
    vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<cr>')

    -- Keybinds to make split navigation easier.
    --  Use CTRL+<hjkl> to switch between windows
    --
    --  See `:help wincmd` for a list of all window commands
    vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
    vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
    vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
    vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

    local teleBuiltin = require('telescope.builtin')
    local gitSigns = require('gitsigns.actions')
    local harpoonMarks = require('harpoon.mark')

    vim.keymap.set('n', '<leader>ff'      , teleBuiltin.find_files                     , { desc = 'File search' })
    vim.keymap.set('n', '<leader>gr'      , teleBuiltin.grep_string                    , { desc = 'Grep over current string' })
    vim.keymap.set('n', '<leader>fg'      , teleBuiltin.live_grep                      , { desc = 'Live grep' })
    vim.keymap.set('n', '<leader>bb'      , teleBuiltin.buffers                        , { desc = 'Telescope buffers' })
    vim.keymap.set('n', '<leader>qq'      , teleBuiltin.quickfix                       , { desc = 'Telescope quickfix' })

    vim.keymap.set('n', '<leader>ss'      , teleBuiltin.lsp_document_symbols           , { desc = 'Telescope document symbols' })
    vim.keymap.set('n', '<leader>sw'      , teleBuiltin.lsp_workspace_symbols          , { desc = 'Telescope workspace symbols' })
    vim.keymap.set('n', 'gR'              , teleBuiltin.lsp_references                 , { desc = 'Telescope references' })
    vim.keymap.set('n', 'gr'              , '<cmd>Glance references<cr>'               , { desc = 'Glance references' })
    vim.keymap.set('n', '<leader>dd'      , teleBuiltin.diagnostics                    , { desc = 'Telescope references' })
    vim.keymap.set('n', '<leader>gb'      , teleBuiltin.git_branches                   , { desc = 'Telescope references' })
    vim.keymap.set('n', '<leader><leader>', teleBuiltin.resume                         , { desc = 'Resume last Telescope session' })

    vim.keymap.set('n', '<leader>th'      , '<cmd>Themery<cr>'                         , { desc = 'Themery' })
    vim.keymap.set('n', '<leader>o'       , vim.cmd.only                               , { desc = 'Leave only current window' })
    -- Plug 'p00f/clangd_extensions.nvim'
    vim.keymap.set('n', '<leader>hh'      , '<cmd>ClangdSwitchSourceHeader<cr>'        , { desc = 'Switch cpp/h' })
    vim.keymap.set('n', '<leader>rr'      , vim.lsp.buf.rename                         , { desc = 'Rename current symbol' })
    vim.keymap.set('n', '<leader>ii'      , ToggleInlineHints                          , { desc = 'Toggle inlay hints' })

    -- Git stuff
    vim.keymap.set('n', '<leader>gg'      , '<cmd>0G<cr>'                              , { desc = 'Fugitive' })
    vim.keymap.set('n', '<leader>gs'      , teleBuiltin.git_status                     , { desc = 'Telescope git status' })
    vim.keymap.set('n', 'gS'              , gitSigns.stage_hunk                        , { desc = 'Stage current hunk' })
    vim.keymap.set('n', 'gp'              , gitSigns.preview_hunk                      , { desc = 'Preview hunk' })

    vim.keymap.set('n', '<C-K>'           , '<cmd>.ClangFormat<cr>'                    , { desc = 'Apply ClangFormat' })
    vim.keymap.set('i', '<C-K>'           , '<C-O>:.ClangFormat<cr>'                   , { desc = 'Apply ClangFormat' })
    vim.keymap.set('v', '<C-K>'           , '<cmd>\'<,\'>ClangFormat<cr>'              , { desc = 'Apply ClangFormat' })

    vim.keymap.set('n', '<leader>ll'      , ToggleLinesOnOff                           , { desc = 'Toggle lines on off' })
    vim.keymap.set('n', '<leader>lr'      , '<cmd>set relativenumber!<cr>'             , { desc = 'Toggle relativenuber' })
    vim.keymap.set('n', '<leader>`'       , '<cmd>cn<cr>'                              , { desc = 'Next error' })
    vim.keymap.set('n', '<leader>m'       , '<cmd>wa<cr><cmd>make -C build/current<cr>', { desc = 'Build current config' })
    vim.keymap.set('n', '<leader>M'       , '<cmd>wa<cr><cmd>terminal ./build.sh<cr>'  , { desc = 'Build current config in terminal' })

    vim.keymap.set('n', '<leader>ha'      , harpoonMarks.add_file                      , { desc = 'Harpoon add file' })
    vim.keymap.set('n', '<leader>hl'      , '<cmd>Telescope harpoon marks<cr>'         , { desc = 'Harpoon telescope' })

    vim.keymap.set('n', '<leader>tt'      , '<cmd>TSContextToggle<cr>'                 , { desc = 'Toggle Tresitter context' })

end

SetKeymap()
