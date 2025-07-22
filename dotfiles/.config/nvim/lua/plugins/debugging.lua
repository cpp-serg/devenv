local function SetupKeys(dap)
      -- vim.keymap.set('n', '<F10>', function() require('dap').step_over() end)
      vim.keymap.set('n', '<F11>', dap.step_into, {})
      vim.keymap.set('n', '<F12>', dap.step_out, {})
      vim.keymap.set('n', '<Leader>dt', dap.toggle_breakpoint, {})
      vim.keymap.set('n', '<Leader>dc', dap.continue, {})
end

local function SetupDapUiAutoOpen(dap, dapui)
      dap.listeners.before.attach.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.launch.dapui_config = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated.dapui_config = function()
        dapui.close()
      end
        dap.listeners.before.event_exited.dapui_config = function()
        dapui.close()
      end
end


return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      { import = "plugins.lsp" },
      -- "williamboman/mason.nvim", 
      "jay-babu/mason-nvim-dap.nvim",
      "nvim-neotest/nvim-nio",
      "rcarriga/nvim-dap-ui",
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")

      require("mason-nvim-dap").setup({
        ensure_installed = { "python", "cpptools" },
        automatic_installation = true,
      })

      SetupKeys(dap)
      SetupDapUiAutoOpen(dap, dapui)

      dapui.setup({
        renderer = {
          max_type_length = 0,
        }
      })
      --
      dap.adapters.cppdbg = {
        id = 'cppdbg',
        type = 'executable',
        command = vim.fn.stdpath("data") .. '/mason/packages/cpptools/extension/debugAdapters/bin/OpenDebugAD7',
      }
      dap.configurations.cpp = {
        {
          name = "Launch file",
          type = "cppdbg",
          request = "launch",
          program = './a.out',
          -- program = function()
          --   return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
          -- end,
          cwd = '${workspaceFolder}',
          stopAtEntry = true,
          setupCommands = {
            {
              text = '-enable-pretty-printing',
              description = 'enable pretty printing',
              ignoreFailures = false
            },
          },
        },
        {
          name = "oAttach to process",
          type = "cppdbg",
          request = "attach",
          -- processId = 35340, -- require('dap.utils').pick_process,
          program = function()
             return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
          end,
          -- program = './a.out',
          processId = require('dap.utils').pick_process,
          cwd = '${workspaceFolder}',
          MIMode = 'gdb',            -- or 'lldb' depending on your platform
          -- miDebuggerPath = '/usr/bin/gdb', -- or 'lldb' or custom debugger
          miDebuggerPath = 'gdb', -- or 'lldb' or custom debugger
          setupCommands = {
            {
              text = "-enable-pretty-printing",
              description = "Enable pretty printing",
              ignoreFailures = true
            }
          }
        },
        {
          name = 'Attach to gdbserver :1234',
          type = 'cppdbg',
          request = 'launch',
          MIMode = 'gdb',
          miDebuggerServerAddress = 'localhost:1234',
          miDebuggerPath = '/usr/bin/gdb',
          cwd = '${workspaceFolder}',
          program = function()
            return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
          end,
        },
      }
    dap.configurations.c = dap.configurations.cpp
    end,
  },
}
