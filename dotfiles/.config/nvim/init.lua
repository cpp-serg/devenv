-- disable netrw at the very start of your init.lua
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.g.python3_host_prog = '/usr/local/python-3.11.3/bin/python3.11'

vim.g.have_nerd_font = true

-- optionally enable 24-bit colour
vim.opt.termguicolors = true

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

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

vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldtext = "v:lua.vim.treesitter.foldtext()"

vim.opt.foldmethod = "expr"
vim.opt.foldenable = false
vim.opt.foldcolumn = "auto"

vim.opt.hlsearch = true

-- filetype plugin indent on
-- let g:airline_powerline_fonts = 1
-- let g:airline#extensions#tabline#enabled = 1
-- let g:airline#extensions#tagbar#enabled = 1
-- let g:airline#extensions#tagbar#flags = 'f'

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

require('lazy').setup('plugins')
------------------------------------------------------------


-- stylua: ignore
local function SetKeymap()
    -- [[ Basic Keymaps ]]
    --  See `:help vim.keymap.set()`

    -- Clear hlsearch on pressing <Esc> in normal mode
    vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

    vim.keymap.set('n', '<C-n>', '<cmd>NvimTreeToggle<CR>')
    vim.keymap.set('n', '<Tab>', '<cmd>tabn<CR>')

    -- Diagnostic keymaps
    vim.keymap.set('n', '[d'       , vim.diagnostic.goto_prev , { desc = 'Go to previous [D]iagnostic message' })
    vim.keymap.set('n', ']d'       , vim.diagnostic.goto_next , { desc = 'Go to next [D]iagnostic message' })
    vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, { desc = 'Show diagnostic [E]rror messages' })
    vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })

    -- Disable arrow keys in normal mode
    vim.keymap.set('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
    vim.keymap.set('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
    vim.keymap.set('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
    vim.keymap.set('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

    -- Keybinds to make split navigation easier.
    --  Use CTRL+<hjkl> to switch between windows
    --
    --  See `:help wincmd` for a list of all window commands
    vim.keymap.set('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
    vim.keymap.set('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
    vim.keymap.set('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
    vim.keymap.set('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

    local teleBuiltin = require('telescope.builtin')
    vim.keymap.set('n', '<leader>ff'      , teleBuiltin.find_files             , { desc = 'File search' })
    vim.keymap.set('n', '<leader>gr'      , teleBuiltin.grep_string            , { desc = 'Grep over current string' })
    vim.keymap.set('n', '<leader>fg'      , teleBuiltin.live_grep              , { desc = 'Live grep' })
    vim.keymap.set('n', '<leader>gs'      , teleBuiltin.git_status             , { desc = 'Telescope git status' })
    vim.keymap.set('n', '<leader>bb'      , teleBuiltin.buffers                , { desc = 'Telescope buffers' })
    vim.keymap.set('n', '<leader>qq'      , teleBuiltin.quickfix               , { desc = 'Telescope quickfix' })

    vim.keymap.set('n', '<leader>ss'      , teleBuiltin.lsp_document_symbols   , { desc = 'Telescope document symbols' })
    vim.keymap.set('n', '<leader>sw'      , teleBuiltin.lsp_workspace_symbols  , { desc = 'Telescope workspace symbols' })
    vim.keymap.set('n', 'gr'              , teleBuiltin.lsp_references         , { desc = 'Telescope references' })
    vim.keymap.set('n', '<leader>dd'      , teleBuiltin.diagnostics            , { desc = 'Telescope references' })
    vim.keymap.set('n', '<leader><leader>', teleBuiltin.resume                 , { desc = 'Resume last Telescope session' })

    vim.keymap.set('n', '<leader>th'      , '<cmd>Themery<cr>'                 , { desc = 'Themery' })
    vim.keymap.set('n', '<leader>gg'      , '<cmd>G<cr><cmd>only<cr>'          , { desc = 'Fugitive' })
    vim.keymap.set('n', '<leader>o'       , '<cmd>only<cr>'                    , { desc = 'Leave only current window' })
    -- Plug 'p00f/clangd_extensions.nvim'
    vim.keymap.set('n', '<leader>hh'      , '<cmd>ClangdSwitchSourceHeader<cr>', { desc = 'Switch cpp/h' })
    vim.keymap.set('n', '<leader>rr'      , vim.lsp.buf.rename                 , { desc = 'Rename current symbol' })
    vim.keymap.set('n', '<leader>ii'      , ToggleInlineHints                  , { desc = 'Toggle inlay hints' })

    vim.keymap.set('n', '<C-K>'      , '<cmd>.ClangFormat<cr>'                 , { desc = 'Toggle inlay hints' })
    vim.keymap.set('i', '<C-K>'      , '<C-O>:.ClangFormat<cr>'                , { desc = 'Toggle inlay hints' })
    vim.keymap.set('v', '<C-K>'      , '<cmd>\'<,\'>ClangFormat<cr>'           , { desc = 'Toggle inlay hints' })
end

SetKeymap()
