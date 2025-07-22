local isSpPrivate = vim.fn.filereadable('~/.sp-private-host') == 1
-- disable netrw at the very start of init.lua, so nvim-tree takes care of file navigation
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.env.LANG = 'en_US.UTF-8'
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

vim.diagnostic.config({virtual_lines = true})

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

vim.diagnostic.config({virtual_lines = true})
local function ToggleVirtualLines()
    vim.diagnostic.config({virtual_lines = not vim.diagnostic.config().virtual_lines})
end

local function FormatCurrentLine()
    vim.lsp.buf.format({
        range = {
            ["start"] = { vim.fn.line('.'), 1 },
            ["end"]   = { vim.fn.line('.'), 1 },
        }
    })
end

-- stylua: ignore
local function SetKeymap()
    local standalone = not vim.g.vscode

    local whichKey = standalone and require('which-key') or nil
    local teleBuiltin = standalone and require('telescope.builtin') or nil
    local gitSigns = standalone and require('gitsigns.actions') or nil
    local harpoonMarks = standalone and require('harpoon.mark') or nil

    local addGroup = function(spec)
        if whichKey then whichKey.add({ spec }) end
    end

    local addKey = vim.keymap.set

    addGroup { "<leader>c", group = "[C]ode" }
    addGroup { "<leader>d", group = "[D]ocument" }
    addGroup { "<leader>r", group = "[R]ename" }
    addGroup { "<leader>s", group = "[S]earch" }
    addGroup { "<leader>w", group = "[W]orkspace" }

    -- [[ Basic Keymaps ]]
    addKey('n', '<leader>CC', '<cmd>e ~/.config/nvim/init.lua<cr>', { desc = 'Edit nvim init' })

    -- Clear hlsearch on pressing <Esc> in normal mode
    addKey('n', '<Esc>', '<cmd>nohlsearch<cr>')

    addKey('n', '<C-n>'        , '<cmd>NvimTreeToggle<cr>')
    addKey('n', '<Tab>'        , '<cmd>e #<cr>')
    addKey('n', '<leader>x'    , '<cmd>bdelete<cr>')
    addKey('n', '<leader>X'    , '<cmd>bdelete!<cr>')
    addKey('n', '<leader>bO'   , '<cmd>BufferLineCloseOthers<cr>')

    -- Diagnostic keymaps
    addKey('n', '[d'       , vim.diagnostic.goto_prev , { desc = 'Go to previous [D]iagnostic message' })
    addKey('n', ']d'       , vim.diagnostic.goto_next , { desc = 'Go to next [D]iagnostic message' })
    addKey('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Show diagnostic [E]rror messages' })
    addKey('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

    if isSpPrivate then
        -- Disable arrow keys in normal mode
        addKey('n', '<left>' , '<cmd>echo "Use h to move!!"<cr>')
        addKey('n', '<right>', '<cmd>echo "Use l to move!!"<cr>')
        addKey('n', '<up>'   , '<cmd>echo "Use k to move!!"<cr>')
        addKey('n', '<down>' , '<cmd>echo "Use j to move!!"<cr>')
    else
        -- print hint, but do not disable
        addKey('n', '<left>' , '<cmd>echo "Use h to move!!"<cr>h')
        addKey('n', '<right>', '<cmd>echo "Use l to move!!"<cr>l')
        addKey('n', '<up>'   , '<cmd>echo "Use k to move!!"<cr>k')
        addKey('n', '<down>' , '<cmd>echo "Use j to move!!"<cr>j')
    end

    -- Keybinds to make split navigation easier.
    --  Use CTRL+<hjkl> to switch between windows
    --
    --  See `:help wincmd` for a list of all window commands
    addKey('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
    addKey('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
    addKey('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
    addKey('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

    if standalone then
        addKey('n', '<leader>ff'      , teleBuiltin.find_files                     , { desc = 'File search' })
        addKey('n', '<leader>gr'      , teleBuiltin.grep_string                    , { desc = 'Grep over current string' })
        addKey('n', '<leader>fg'      , teleBuiltin.live_grep                      , { desc = 'Live grep' })
        addKey('n', '<leader>bb'      , teleBuiltin.buffers                        , { desc = 'Telescope buffers' })
        addKey('n', '<leader>qq'      , teleBuiltin.quickfix                       , { desc = 'Telescope quickfix' })

        addKey('n', '<leader>ss'      , teleBuiltin.lsp_document_symbols           , { desc = 'Telescope document symbols' })
        addKey('n', '<leader>sw'      , teleBuiltin.lsp_workspace_symbols          , { desc = 'Telescope workspace symbols' })
        addKey('n', 'gR'              , teleBuiltin.lsp_references                 , { desc = 'Telescope references' })
    end

    addKey('n', 'gr'              , '<cmd>Glance references<CR>'               , { desc = 'Glance references' })

    if standalone then
        addKey('n', '<leader>dd'      , teleBuiltin.diagnostics                    , { desc = 'Telescope workspace diagnostic' })
        addKey('n', '<leader>gb'      , teleBuiltin.git_branches                   , { desc = 'Telescope git branches' })
        addKey('n', '<leader><leader>', teleBuiltin.resume                         , { desc = 'Resume last Telescope session' })

        addKey('n', '<leader>th'      , '<cmd>Themery<cr>'                         , { desc = 'Themery' })
    end

    addKey('n', '<leader>o'       , vim.cmd.only                               , { desc = 'Leave only current window' })

    -- Plug 'p00f/clangd_extensions.nvim'
    addKey('n', '<leader>hh'      , '<cmd>LspClangdSwitchSourceHeader<cr>'        , { desc = 'Switch cpp/h' })
    addKey('n', '<leader>rr'      , vim.lsp.buf.rename                         , { desc = 'Rename current symbol' })
    addKey('n', '<leader>ii'      , ToggleInlineHints                          , { desc = 'Toggle inlay hints' })

    -- Git stuff
    addKey('n', '<leader>gg'      , '<cmd>0G<cr>'                              , { desc = 'Fugitive' })

    if standalone then
        addKey('n', '<leader>gs'      , teleBuiltin.git_status                     , { desc = 'Telescope git status' })
        addKey('n', '<leader>gB'      , gitSigns.toggle_current_line_blame         , { desc = 'Toggle current line blame' })
        addKey('n', '<leader>gS'      , gitSigns.stage_hunk                        , { desc = 'Stage current hunk' })
        addKey('n', 'gp'              , gitSigns.preview_hunk                      , { desc = 'Preview hunk' })
        addKey('n', '<leader>nh'      , gitSigns.next_hunk                         , { desc = 'Next hunk' })
        addKey('n', '<leader>ph'      , gitSigns.prev_hunk                         , { desc = 'Previous hunk' })
        addKey('n', '<leader>gR'      , gitSigns.reset_hunk                        , { desc = 'Reset hunk' })
    end

    addKey('n', '<C-K>'           , FormatCurrentLine                          , { desc = 'Apply ClangFormat' })
    addKey('v', '<C-K>'           , vim.lsp.buf.format                         , { desc = 'Apply ClangFormat' })

    addKey('n', '<leader>ll'      , ToggleLinesOnOff                           , { desc = 'Toggle lines on off' })
    addKey('n', '<leader>lr'      , '<cmd>set relativenumber!<cr>'             , { desc = 'Toggle relativenuber' })
    addKey('n', '<leader>`'       , '<cmd>cn<cr>'                              , { desc = 'Next error' })
    addKey('n', '<leader>m'       , '<cmd>wa<cr><cmd>make -C build/current<cr>', { desc = 'Build current config' })
    addKey('n', '<leader>M'       , '<cmd>wa<cr><cmd>terminal ./build.sh --no-unittests <cr>'  , { desc = 'Build current config in terminal' })
    addKey('n', '<leader>D'       , '<cmd>wa<cr><cmd>terminal ./build.sh --no-unittests && deploy-to<cr>'  , { desc = 'Build current config in terminal and deploy to remote host' })

    if standalone then
        addKey('n', '<leader>ha'      , harpoonMarks.add_file                      , { desc = 'Harpoon add file' })
        addKey('n', '<leader>hl'      , '<cmd>Telescope harpoon marks<cr>'         , { desc = 'Harpoon telescope' })
        addKey('n', '<leader>ha'      , harpoonMarks.add_file                      , { desc = 'Harpoon add file' })
    end
    addKey('n', '<leader>hl'      , '<cmd>Telescope harpoon marks<cr>'         , { desc = 'Harpoon telescope' })

    addKey('n', '<leader>tt'      , '<cmd>TSContextToggle<cr>'                 , { desc = 'Toggle Tresitter context' })
    addKey('n', '<leader>vl'      , ToggleVirtualLines                        , { desc = 'Toggle virtual lines' })
end

SetKeymap()
