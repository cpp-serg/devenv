local M = {}

local function yank_range(start_line, end_line)
    local path = vim.fn.expand('%:.')
    local lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
    local header
    if start_line == end_line then
        header = path .. '#L' .. start_line
    else
        header = path .. '#L' .. start_line .. '-' .. end_line
    end
    vim.fn.setreg('+', header)
    vim.highlight.range(0, vim.api.nvim_create_namespace('yank_ref'), 'IncSearch', { start_line - 1, 0 }, { end_line - 1, vim.v.maxcol }, {})
    vim.defer_fn(function()
        vim.api.nvim_buf_clear_namespace(0, vim.api.nvim_create_namespace('yank_ref'), 0, -1)
    end, 250)
    vim.notify('Yanked ref: ' .. header, vim.log.levels.INFO)
end

--- Operatorfunc callback: called after a motion or from visual mode.
function M.operatorfunc(motion_type)
    local save = vim.fn.winsaveview()
    local start_line = vim.fn.line("'[")
    local end_line = vim.fn.line("']")
    yank_range(start_line, end_line)
    vim.fn.winrestview(save)
end

--- Entry point for normal mode: sets operatorfunc and triggers g@
function M.yank_operator()
    vim.o.operatorfunc = "v:lua.require'usr.yank_ref'.operatorfunc"
    return 'g@'
end

--- Entry point for visual mode
function M.yank_visual()
    local start_line = vim.fn.line("'<")
    local end_line = vim.fn.line("'>")
    yank_range(start_line, end_line)
end

--- Yank current line (for <leader>yryr or <leader>yr_ convenience)
function M.yank_line()
    local lnum = vim.fn.line('.')
    yank_range(lnum, lnum)
end

return M
