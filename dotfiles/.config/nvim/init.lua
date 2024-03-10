vim.g.python3_host_prog = '/usr/local/python-3.11.3/bin/python3.11'

-- local set=vim.opt
-- local g=vim.g

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

-- disable netrw at the very start of your init.lua
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

vim.g.syntax = 1

vim.wo.number = true
vim.wo.relativenumber = true

vim.opt.tabstop = 4
vim.opt.softtabstop = 0
vim.opt.expandtab = true
vim.opt.shiftwidth = 4
vim.opt.smarttab = true

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

-- [[ Basic Keymaps ]]
--  See `:help vim.keymap.set()`

-- Set highlight on search, but clear on pressing <Esc> in normal mode
vim.opt.hlsearch = true
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')
vim.keymap.set('n', '<C-n>', '<cmd>NvimTreeToggle<CR>')
vim.keymap.set('n', '<Tab>', '<cmd>tabn<CR>')

-- Diagnostic keymaps
vim.keymap.set(
    'n',
    '[d',
    vim.diagnostic.goto_prev,
    { desc = 'Go to previous [D]iagnostic message' }
)
vim.keymap.set('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next [D]iagnostic message' })
vim.keymap.set(
    'n',
    '<leader>e',
    vim.diagnostic.open_float,
    { desc = 'Show diagnostic [E]rror messages' }
)
vim.keymap.set(
    'n',
    '<leader>q',
    vim.diagnostic.setloclist,
    { desc = 'Open diagnostic [Q]uickfix list' }
)

-- TIP: Disable arrow keys in normal mode
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

vim.api.nvim_create_autocmd('TextYankPost', {
    desc = 'Highlight when yanking (copying) text',
    group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
    callback = function()
        vim.highlight.on_yank()
    end,
})

-- filetype plugin indent on
-- let g:airline_powerline_fonts = 1
-- let g:airline#extensions#tabline#enabled = 1
-- let g:airline#extensions#tagbar#enabled = 1
-- let g:airline#extensions#tagbar#flags = 'f'
--
-- set mouse=a " Enable mouse
-- set smartcase " Smartcase search
-- set ignorecase " Mostly for wildmenu completion
-- set smartindent
-- set cindent
-- set clipboard+=unnamedplus " to be able to copy-paste from other applications without + and * registers
-- set list
--
-- set tabstop=4
-- set softtabstop=0
-- set expandtab
-- set shiftwidth=4
-- set smarttab

-- optionally enable 24-bit colour
vim.opt.termguicolors = true

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
------------------------------------------------------------

require('lazy').setup({
    'tpope/vim-sleuth', -- Detect tabstop and shiftwidth automatically
    'nvim-lua/plenary.nvim', -- Utilities widely used in other plugins
    { 'folke/neoconf.nvim', cmd = 'Neoconf' },
    { -- Useful plugin to show you pending keybinds.
        'folke/which-key.nvim',
        event = 'VimEnter', -- Sets the loading event to 'VimEnter'
        config = function() -- This is the function that runs, AFTER loading
            require('which-key').setup()

            -- Document existing key chains
            require('which-key').register({
                ['<leader>c'] = { name = '[C]ode', _ = 'which_key_ignore' },
                ['<leader>d'] = { name = '[D]ocument', _ = 'which_key_ignore' },
                ['<leader>r'] = { name = '[R]ename', _ = 'which_key_ignore' },
                ['<leader>s'] = { name = '[S]earch', _ = 'which_key_ignore' },
                ['<leader>w'] = { name = '[W]orkspace', _ = 'which_key_ignore' },
            })
        end,
    },
    { -- Adds git related signs to the gutter, as well as utilities for managing changes
        'lewis6991/gitsigns.nvim',
        opts = {
            signs = {
                add = { text = '+' },
                change = { text = '~' },
                delete = { text = '_' },
                topdelete = { text = '‾' },
                changedelete = { text = '~' },
            },
        },
    },
    {
        'nvim-tree/nvim-tree.lua',
        opts = {
            view = {
                width = 20,
                adaptive_size = true,
            },
            renderer = {
                group_empty = true,
                icons = {
                    show = {
                        git = true,
                        file = true,
                        folder = true,
                        folder_arrow = true,
                    },
                    glyphs = {
                        bookmark = '🔖',
                        folder = {
                            arrow_closed = '⏵',
                            arrow_open = '⏷',
                        },
                        git = {
                            unstaged = '✗',
                            staged = '✓',
                            unmerged = '⌥',
                            renamed = '➜',
                            untracked = '★',
                            deleted = '⊖',
                            ignored = '◌',
                        },
                    },
                },
            },
            git = {
                enable = true,
                ignore = true,
                show_on_dirs = true,
                show_on_open_dirs = true,
                timeout = 400,
            },
            actions = {
                open_file = {
                    quit_on_open = true,
                    resize_window = true,
                    window_picker = {
                        enable = true,
                        picker = 'default',
                        chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890',
                        exclude = {
                            filetype = {
                                'notify',
                                'packer',
                                'qf',
                                'diff',
                                'fugitive',
                                'fugitiveblame',
                            },
                            buftype = { 'nofile', 'terminal', 'help' },
                        },
                    },
                },
            },
        },
    },

    {
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
    },
    'folke/neodev.nvim',

    -- Colors
    'loctvl842/monokai-pro.nvim',
    'ellisonleao/gruvbox.nvim',
    'catppuccin/nvim',
    {
        'zaldih/themery.nvim',
        opts = {
            themes = {
                'catppuccin-latte',
                {
                    name = 'Gruvbox light',
                    colorscheme = 'gruvbox',
                    before = [[
              vim.opt.background = "light"
            ]],
                },
                {
                    name = 'Gruvbox dark',
                    colorscheme = 'gruvbox',
                    before = [[
                vim.opt.background = "dark"
              ]],
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
        },
    },
    { -- LSP Configuration & Plugins
        'neovim/nvim-lspconfig',
        dependencies = {
            -- Automatically install LSPs and related tools to stdpath for neovim
            'williamboman/mason.nvim',
            'williamboman/mason-lspconfig.nvim',
            'WhoIsSethDaniel/mason-tool-installer.nvim',

            -- Useful status updates for LSP.
            -- NOTE: `opts = {}` is the same as calling `require('fidget').setup({})`
            { 'j-hui/fidget.nvim', opts = {} },
        },
        config = function()
            -- Brief Aside: **What is LSP?**
            --
            -- LSP is an acronym you've probably heard, but might not understand what it is.
            --
            -- LSP stands for Language Server Protocol. It's a protocol that helps editors
            -- and language tooling communicate in a standardized fashion.
            --
            -- In general, you have a "server" which is some tool built to understand a particular
            -- language (such as `gopls`, `lua_ls`, `rust_analyzer`, etc). These Language Servers
            -- (sometimes called LSP servers, but that's kind of like ATM Machine) are standalone
            -- processes that communicate with some "client" - in this case, Neovim!
            --
            -- LSP provides Neovim with features like:
            --  - Go to definition
            --  - Find references
            --  - Autocompletion
            --  - Symbol Search
            --  - and more!
            --
            -- Thus, Language Servers are external tools that must be installed separately from
            -- Neovim. This is where `mason` and related plugins come into play.
            --
            -- If you're wondering about lsp vs treesitter, you can check out the wonderfully
            -- and elegantly composed help section, `:help lsp-vs-treesitter`

            --  This function gets run when an LSP attaches to a particular buffer.
            --    That is to say, every time a new file is opened that is associated with
            --    an lsp (for example, opening `main.rs` is associated with `rust_analyzer`) this
            --    function will be executed to configure the current buffer
            vim.api.nvim_create_autocmd('LspAttach', {
                group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
                callback = function(event)
                    -- NOTE: Remember that lua is a real programming language, and as such it is possible
                    -- to define small helper and utility functions so you don't have to repeat yourself
                    -- many times.
                    --
                    -- In this case, we create a function that lets us more easily define mappings specific
                    -- for LSP related items. It sets the mode, buffer and description for us each time.
                    local map = function(keys, func, desc)
                        vim.keymap.set('n', keys, func, {
                            buffer = event.buf,
                            desc = 'LSP: ' .. desc,
                        })
                    end

                    -- Jump to the definition of the word under your cursor.
                    --  This is where a variable was first declared, or where a function is defined, etc.
                    --  To jump back, press <C-T>.
                    map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')

                    -- Find references for the word under your cursor.
                    map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')

                    -- Jump to the implementation of the word under your cursor.
                    --  Useful when your language has ways of declaring types without an actual implementation.
                    map(
                        'gI',
                        require('telescope.builtin').lsp_implementations,
                        '[G]oto [I]mplementation'
                    )

                    -- Jump to the type of the word under your cursor.
                    --  Useful when you're not sure what type a variable is and you want to see
                    --  the definition of its *type*, not where it was *defined*.
                    map(
                        '<leader>D',
                        require('telescope.builtin').lsp_type_definitions,
                        'Type [D]efinition'
                    )

                    -- Fuzzy find all the symbols in your current document.
                    --  Symbols are things like variables, functions, types, etc.
                    map(
                        '<leader>ds',
                        require('telescope.builtin').lsp_document_symbols,
                        '[D]ocument [S]ymbols'
                    )

                    -- Fuzzy find all the symbols in your current workspace
                    --  Similar to document symbols, except searches over your whole project.
                    map(
                        '<leader>ws',
                        require('telescope.builtin').lsp_dynamic_workspace_symbols,
                        '[W]orkspace [S]ymbols'
                    )

                    -- Rename the variable under your cursor
                    --  Most Language Servers support renaming across files, etc.
                    map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')

                    -- Execute a code action, usually your cursor needs to be on top of an error
                    -- or a suggestion from your LSP for this to activate.
                    map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')

                    -- Opens a popup that displays documentation about the word under your cursor
                    --  See `:help K` for why this keymap
                    map('K', vim.lsp.buf.hover, 'Hover Documentation')

                    -- WARN: This is not Goto Definition, this is Goto Declaration.
                    --  For example, in C this would take you to the header
                    map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

                    -- The following two autocommands are used to highlight references of the
                    -- word under your cursor when your cursor rests there for a little while.
                    --    See `:help CursorHold` for information about when this is executed
                    --
                    -- When you move your cursor, the highlights will be cleared (the second autocommand).
                    local client = vim.lsp.get_client_by_id(event.data.client_id)
                    if client and client.server_capabilities.documentHighlightProvider then
                        vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
                            buffer = event.buf,
                            callback = vim.lsp.buf.document_highlight,
                        })

                        vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
                            buffer = event.buf,
                            callback = vim.lsp.buf.clear_references,
                        })
                    end
                end,
            })

            -- LSP servers and clients are able to communicate to each other what features they support.
            --  By default, Neovim doesn't support everything that is in the LSP Specification.
            --  When you add nvim-cmp, luasnip, etc. Neovim now has *more* capabilities.
            --  So, we create new capabilities with nvim cmp, and then broadcast that to the servers.
            local capabilities = vim.lsp.protocol.make_client_capabilities()
            capabilities = vim.tbl_deep_extend(
                'force',
                capabilities,
                require('cmp_nvim_lsp').default_capabilities()
            )

            -- Enable the following language servers
            --  Feel free to add/remove any LSPs that you want here. They will automatically be installed.
            --
            --  Add any additional override configuration in the following tables. Available keys are:
            --  - cmd (table): Override the default command used to start the server
            --  - filetypes (table): Override the default list of associated filetypes for the server
            --  - capabilities (table): Override fields in capabilities. Can be used to disable certain LSP features.
            --  - settings (table): Override the default settings passed when initializing the server.
            --        For example, to see the options for `lua_ls`, you could go to: https://luals.github.io/wiki/settings/
            local servers = {
                clangd = {
                    cmd = {
                        "clangd",
                        "--background-index",
                        "-j=18",     -- number of workers @TODO read system configuration
                        "--all-scopes-completion",
                        -- "--clang-tidy",
                        -- "--compile_args_from=filesystem", -- lsp-> does not come from compie_commands.json
                        "--completion-parse=always",
                        "--completion-style=bundled",
                        "--cross-file-rename",
                        "--debug-origin",
                        "--enable-config", -- clangd 11+ supports reading from .clangd configuration file
                        "--fallback-style=Qt",
                        "--folding-ranges",
                        "--function-arg-placeholders",
                        "--header-insertion=never", -- iwyu
                        "--pch-storage=memory", -- could also be disk
                        "--suggest-missing-includes",
                        -- "--resource-dir="
                        "--log=error",
                        --[[ "--query-driver=/usr/bin/g++", ]]
                    },
                },
                -- gopls = {},
                -- pyright = {},
                -- rust_analyzer = {},
                -- ... etc. See `:help lspconfig-all` for a list of all the pre-configured LSPs
                --
                -- Some languages (like typescript) have entire language plugins that can be useful:
                --    https://github.com/pmizio/typescript-tools.nvim
                --
                -- But for many setups, the LSP (`tsserver`) will work just fine
                -- tsserver = {},
                --

                lua_ls = {
                    -- cmd = {...},
                    -- filetypes { ...},
                    -- capabilities = {},
                    settings = {
                        Lua = {
                            runtime = { version = 'LuaJIT' },
                            workspace = {
                                checkThirdParty = false,
                                -- Tells lua_ls where to find all the Lua files that you have loaded
                                -- for your neovim configuration.
                                library = {
                                    '${3rd}/luv/library',
                                    unpack(vim.api.nvim_get_runtime_file('', true)),
                                },
                                -- If lua_ls is really slow on your computer, you can try this instead:
                                -- library = { vim.env.VIMRUNTIME },
                            },
                            completion = {
                                callSnippet = 'Replace',
                            },
                            -- You can toggle below to ignore Lua_LS's noisy `missing-fields` warnings
                            -- diagnostics = { disable = { 'missing-fields' } },
                        },
                    },
                },
            }

            -- Ensure the servers and tools above are installed
            --  To check the current status of installed tools and/or manually install
            --  other tools, you can run
            --    :Mason
            --
            --  You can press `g?` for help in this menu
            require('mason').setup()

            -- You can add other tools here that you want Mason to install
            -- for you, so that they are available from within Neovim.
            local ensure_installed = vim.tbl_keys(servers or {})
            vim.list_extend(ensure_installed, {
                'stylua', -- Used to format lua code
            })
            require('mason-tool-installer').setup({
                ensure_installed = ensure_installed,
            })

            require('mason-lspconfig').setup({
                handlers = {
                    function(server_name)
                        local server = servers[server_name] or {}
                        -- This handles overriding only values explicitly passed
                        -- by the server configuration above. Useful when disabling
                        -- certain features of an LSP (for example, turning off formatting for tsserver)
                        server.capabilities = vim.tbl_deep_extend(
                            'force',
                            {},
                            capabilities,
                            server.capabilities or {}
                        )
                        require('lspconfig')[server_name].setup(server)
                    end,
                },
            })
        end,
    },
    'nvim-tree/nvim-web-devicons',
    { -- Autoformat
        'stevearc/conform.nvim',
        enabled = false,
        opts = {
            notify_on_error = false,
            format_on_save = {
                timeout_ms = 500,
                lsp_fallback = true,
            },
            formatters_by_ft = {
                lua = { 'stylua' },
                -- sh = { 'beautish' },
                cpp = nil, -- { 'clang_format' },
                -- Conform can also run multiple formatters sequentially
                -- python = { "isort", "black" },
                --
                -- You can use a sub-list to tell conform to run *until* a formatter
                -- is found.
                -- javascript = { { "prettierd", "prettier" } },
            },
        },
    },

    { -- Autocompletion
        'hrsh7th/nvim-cmp',
        event = 'InsertEnter',
        dependencies = {
            -- Snippet Engine & its associated nvim-cmp source
            {
                'L3MON4D3/LuaSnip',
                build = (function()
                    -- Build Step is needed for regex support in snippets
                    -- This step is not supported in many windows environments
                    -- Remove the below condition to re-enable on windows
                    if vim.fn.has('win32') == 1 or vim.fn.executable('make') == 0 then
                        return
                    end
                    return 'make install_jsregexp'
                end)(),
            },
            'saadparwaiz1/cmp_luasnip',

            -- Adds other completion capabilities.
            --  nvim-cmp does not ship with all sources by default. They are split
            --  into multiple repos for maintenance purposes.
            'hrsh7th/cmp-nvim-lsp',
            'hrsh7th/cmp-path',

            -- If you want to add a bunch of pre-configured snippets,
            --    you can use this plugin to help you. It even has snippets
            --    for various frameworks/libraries/etc. but you will have to
            --    set up the ones that are useful for you.
            -- 'rafamadriz/friendly-snippets',
        },
        config = function()
            -- See `:help cmp`
            local cmp = require('cmp')
            local luasnip = require('luasnip')
            luasnip.config.setup({})

            cmp.setup({
                snippet = {
                    expand = function(args)
                        luasnip.lsp_expand(args.body)
                    end,
                },
                completion = { completeopt = 'menu,menuone,noinsert' },

                -- For an understanding of why these mappings were
                -- chosen, you will need to read `:help ins-completion`
                --
                -- No, but seriously. Please read `:help ins-completion`, it is really good!
                mapping = cmp.mapping.preset.insert({
                    -- Select the [n]ext item
                    ['<C-n>'] = cmp.mapping.select_next_item(),
                    -- Select the [p]revious item
                    ['<C-p>'] = cmp.mapping.select_prev_item(),

                    -- Accept ([y]es) the completion.
                    --  This will auto-import if your LSP supports it.
                    --  This will expand snippets if the LSP sent a snippet.
                    ['<C-y>'] = cmp.mapping.confirm({ select = true }),

                    -- Manually trigger a completion from nvim-cmp.
                    --  Generally you don't need this, because nvim-cmp will display
                    --  completions whenever it has completion options available.
                    ['<C-Space>'] = cmp.mapping.complete({}),

                    -- Think of <c-l> as moving to the right of your snippet expansion.
                    --  So if you have a snippet that's like:
                    --  function $name($args)
                    --    $body
                    --  end
                    --
                    -- <c-l> will move you to the right of each of the expansion locations.
                    -- <c-h> is similar, except moving you backwards.
                    ['<C-l>'] = cmp.mapping(function()
                        if luasnip.expand_or_locally_jumpable() then
                            luasnip.expand_or_jump()
                        end
                    end, { 'i', 's' }),
                    ['<C-h>'] = cmp.mapping(function()
                        if luasnip.locally_jumpable(-1) then
                            luasnip.jump(-1)
                        end
                    end, { 'i', 's' }),
                }),
                sources = {
                    { name = 'nvim_lsp' },
                    { name = 'luasnip' },
                    { name = 'path' },
                },
            })
        end,
    },
    { -- Highlight, edit, and navigate code
        'nvim-treesitter/nvim-treesitter',
        build = ':TSUpdate',
        config = function()
            -- [[ Configure Treesitter ]] See `:help nvim-treesitter`

            ---@diagnostic disable-next-line: missing-fields
            require('nvim-treesitter.configs').setup({
                ensure_installed = {
                    'bash',
                    'c',
                    'cmake',
                    'cpp',
                    'dockerfile',
                    'html',
                    'lua',
                    'markdown',
                    'query',
                    'rst',
                    'vim',
                    'vimdoc',
                },
                -- Autoinstall languages that are not installed
                auto_install = true,
                highlight = { enable = true },
                indent = { enable = true },
            })

            -- There are additional nvim-treesitter modules that you can use to interact
            -- with nvim-treesitter. You should go explore a few and see what interests you:
            --
            --    - Incremental selection: Included, see `:help nvim-treesitter-incremental-selection-mod`
            --    - Show your current context: https://github.com/nvim-treesitter/nvim-treesitter-context
            --    - Treesitter + textobjects: https://github.com/nvim-treesitter/nvim-treesitter-textobjects
        end,
    },
    'tpope/vim-fugitive',
    'rhysd/vim-clang-format',
    {
        'neovim/nvim-lspconfig',
        opts = {
            inlay_hints = { enabled = true },
        },
    },
    {
        'nvim-treesitter/nvim-treesitter-textobjects',
        dependencies = { "nvim-treesitter/nvim-treesitter" },
        config = function()
            require('nvim-treesitter.configs').setup({
                modules= {},
                sync_install = false,
                auto_install = false,
                ignore_install = {''},
                ensure_installed = {},
                parser_install_dir = nil,

                textobjects = {
                    select = {
                        enable = true,

                        -- Automatically jump forward to textobj, similar to targets.vim
                        lookahead = true,

                        keymaps = {
                            -- You can use the capture groups defined in textobjects.scm
                            ["af"] = "@function.outer",
                            ["if"] = "@function.inner",
                            ["ac"] = "@class.outer",
                            -- You can optionally set descriptions to the mappings (used in the desc parameter of
                            -- nvim_buf_set_keymap) which plugins like which-key display
                            ["ic"] = { query = "@class.inner", desc = "Select inner part of a class region" },
                            -- You can also use captures from other query groups like `locals.scm`
                            -- ["am"] = { query = "@block.outer", query_group = "locals", desc = "Select language scope" },
                            ["as"] = { query = "@statement.outer",  desc = "Select language statement" },
                            ["ap"] = { query = "@parameter.outer",  desc = "Select language parameter" },
                            ["ab"] = { query = "@block.outer",  desc = "Select language block" },
                        },
                        -- You can choose the select mode (default is charwise 'v')
                        --
                        -- Can also be a function which gets passed a table with the keys
                        -- * query_string: eg '@function.inner'
                        -- * method: eg 'v' or 'o'
                        -- and should return the mode ('v', 'V', or '<c-v>') or a table
                        -- mapping query_strings to modes.
                        selection_modes = {
                            ['@parameter.outer'] = 'v', -- charwise
                            ['@statement.outer'] = 'V', -- charwise
                            ['@function.outer'] = 'V', -- linewise
                            ['@class.outer'] = '<c-v>', -- blockwise
                        },
                        -- If you set this to `true` (default is `false`) then any textobject is
                        -- extended to include preceding or succeeding whitespace. Succeeding
                        -- whitespace has priority in order to act similarly to eg the built-in
                        -- `ap`.
                        --
                        -- Can also be a function which gets passed a table with the keys
                        -- * query_string: eg '@function.inner'
                        -- * selection_mode: eg 'v'
                        -- and should return true or false
                        include_surrounding_whitespace = false,
                    },
                    lsp_interop = {
                        enable = true,
                        border = 'none',
                        floating_preview_opts = {},
                        peek_definition_code = {
                            ["<leader>df"] = "@function.outer",
                            ["<leader>dF"] = "@class.outer",
                        },
                    },
                },
            })
        end
    }

})
-- Load active theme selected and automatically stored by Th
require('settings/theme')

function ToggleInlineHints()
    vim.lsp.inlay_hint.enable(0, not vim.lsp.inlay_hint.is_enabled(0))
end

-- stylua: ignore
local function setKeymap()
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


setKeymap()
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldtext = "v:lua.vim.treesitter.foldtext()"

vim.opt.foldmethod = "expr"
vim.opt.foldenable = false
vim.opt.foldcolumn = "auto"

--local config = require('telescope.config')
