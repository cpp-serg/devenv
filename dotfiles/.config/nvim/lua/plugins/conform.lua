local formatters_by_ft = {
    -- sh = { 'beautish' },
    cpp = nil, -- { 'clang_format' },
    -- Conform can also run multiple formatters sequentially
    -- python = { "isort", "black" },
    --
    -- You can use a sub-list to tell conform to run *until* a formatter
    -- is found.
    -- javascript = { { "prettierd", "prettier" } },
}

if vim.fn.executable('stylua') == 1 then
    formatters_by_ft.lua = { 'stylua' }
end

return { -- Autoformat
    'stevearc/conform.nvim',
    enabled = false,
    opts = {
        notify_on_error = false,
        format_on_save = {
            timeout_ms = 500,
            lsp_fallback = true,
        },
        formatters_by_ft = formatters_by_ft,
        formatters = {
            stylua = {
                -- Apply personal defaults only when the project has no stylua.toml.
                -- If it does, let the project config win (no CLI overrides).
                prepend_args = function(_, ctx)
                    local found = vim.fs.find(
                        { 'stylua.toml', '.stylua.toml' },
                        { upward = true, path = vim.fs.dirname(ctx.filename) }
                    )
                    if #found > 0 then
                        return {}
                    end
                    -- stylua: ignore start
                    return {
                        '--indent-type', 'Spaces',
                        '--indent-width', '4',
                        '--quote-style', 'AutoPreferSingle',
                        '--collapse-simple-statement', 'FunctionOnly',
                    }
                    -- stylua: ignore end
                end,
            },
        },
    },
}
