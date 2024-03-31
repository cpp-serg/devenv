return {
  'lukas-reineke/indent-blankline.nvim',
  enabled = false,
  main = "ibl",
  config = function()
    local highlight = {
      "CursorColumn",
      "Whitespace",
    }
    require('ibl').setup({
      indent = {
        char = "▏"
        -- char = "▏" -- "│ │▏┊
      },
      scope = {
        show_start = true,
        show_end = false,
        highlight = highlight,
      },
      -- whitespace = {
      --   highlight = highlight,
      --   remove_blankline_trail = false,
      -- },
    })
  end,
}
