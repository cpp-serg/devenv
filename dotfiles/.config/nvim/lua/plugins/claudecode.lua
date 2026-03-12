return {
  "coder/claudecode.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  config = true,
  keys = {
    { "<leader>ac", "<cmd>ClaudeCodeStart<cr>", desc = "Start Claude Code" },
    { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "Send to Claude Code" },
  },
}
