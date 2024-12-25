return {
  "supermaven-inc/supermaven-nvim",
  enabled = not vim.g.vscode,
  config = function()
    require("supermaven-nvim").setup({

      color = {
        suggestion_color = "#afffff",
        cterm = 159,
      },
    })
  end,
}
