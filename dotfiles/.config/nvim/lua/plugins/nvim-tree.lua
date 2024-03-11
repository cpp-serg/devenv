return {
    'nvim-tree/nvim-tree.lua',
    dependencies = {
        'nvim-tree/nvim-web-devicons',
    },
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
}
