-- =============================================================================
-- lua/ajay/dap.lua
-- Full-stack DAP configuration
-- Languages: Python, TypeScript/JavaScript, Go, C/C++, Rust, Java
-- =============================================================================

local ok_dap, dap = pcall(require, "dap")
if not ok_dap then
  vim.notify("nvim-dap not found. Make sure it's in your plugins.lua", vim.log.levels.ERROR)
  return
end

local ok_dapui, dapui = pcall(require, "dapui")
local ok_vtext, dap_vtext = pcall(require, "nvim-dap-virtual-text")

-- =============================================================================
-- SIGNS (shown in the gutter)
-- =============================================================================
-- These five survived (they are plain Unicode, not Private Use Area),
-- but routing them through ajay.icons keeps every glyph in one place.
local ok_icons, iconmod = pcall(require, "ajay.icons")
local dapicons = ok_icons and iconmod.dap
  or {
    breakpoint = "B",
    breakpoint_condition = "C",
    log_point = "L",
    stopped = ">",
    rejected = "X",
    pause = "||",
    play = ">",
    step_into = "I",
    step_over = "O",
    step_out = "U",
    step_back = "<",
  }

vim.fn.sign_define("DapBreakpoint", { text = dapicons.breakpoint, texthl = "DiagnosticError", linehl = "", numhl = "" })
vim.fn.sign_define(
  "DapBreakpointCondition",
  { text = dapicons.breakpoint_condition, texthl = "DiagnosticWarn", linehl = "", numhl = "" }
)
vim.fn.sign_define("DapLogPoint", { text = dapicons.log_point, texthl = "DiagnosticInfo", linehl = "", numhl = "" })
vim.fn.sign_define(
  "DapStopped",
  { text = dapicons.stopped, texthl = "DiagnosticOk", linehl = "DapStoppedLine", numhl = "" }
)
vim.fn.sign_define(
  "DapBreakpointRejected",
  { text = dapicons.rejected, texthl = "DiagnosticError", linehl = "", numhl = "" }
)

-- Highlight for the current stopped line
vim.api.nvim_set_hl(0, "DapStoppedLine", { bg = "#2d3149" })

-- =============================================================================
-- DAP-UI SETUP
-- =============================================================================
if ok_dapui then
  dapui.setup({
    icons = { expanded = "▾", collapsed = "▸", current_frame = "▶" },
    mappings = {
      expand = { "<CR>", "<2-LeftMouse>" },
      open = "o",
      remove = "d",
      edit = "e",
      repl = "r",
      toggle = "t",
    },
    element_mappings = {},
    expand_lines = vim.fn.has("nvim-0.7") == 1,
    force_buffers = true,
    layouts = {
      {
        -- Left sidebar: scopes + watches + breakpoints
        elements = {
          { id = "scopes", size = 0.40 },
          { id = "watches", size = 0.25 },
          { id = "breakpoints", size = 0.20 },
          { id = "stacks", size = 0.15 },
        },
        size = 40,
        position = "left",
      },
      {
        -- Bottom: REPL + console
        elements = {
          { id = "repl", size = 0.5 },
          { id = "console", size = 0.5 },
        },
        size = 12,
        position = "bottom",
      },
    },
    controls = {
      enabled = true,
      element = "repl",
      icons = {
        -- These were all empty strings: the glyphs were stripped, so
        -- every dap-ui control button rendered blank.
        pause = dapicons.pause,
        play = dapicons.play,
        step_into = dapicons.step_into,
        step_over = dapicons.step_over,
        step_out = dapicons.step_out,
        step_back = dapicons.step_back,
        run_last = "↺",
        terminate = "□",
        disconnect = "⏏",
      },
    },
    floating = {
      max_height = 0.9,
      max_width = 0.5,
      border = "rounded",
      mappings = { close = { "q", "<Esc>" } },
    },
    render = {
      max_type_length = nil,
      max_value_lines = 100,
      indent = 1,
    },
  })

  -- Auto-open/close DAP UI on session start/end
  dap.listeners.after.event_initialized["dapui_config"] = function()
    dapui.open()
  end
  dap.listeners.before.event_terminated["dapui_config"] = function()
    dapui.close()
  end
  dap.listeners.before.event_exited["dapui_config"] = function()
    dapui.close()
  end
end

-- =============================================================================
-- VIRTUAL TEXT (variable values next to code)
-- =============================================================================
if ok_vtext then
  dap_vtext.setup({
    enabled = true,
    enabled_commands = true,
    highlight_changed_variables = true,
    highlight_new_as_changed = false,
    show_stop_reason = true,
    commented = false,
    only_first_definition = true,
    all_references = false,
    clear_on_continue = false,
    display_callback = function(variable, buf, stackframe, node, options)
      if options.virt_text_pos == "inline" then
        return " = " .. variable.value
      else
        return variable.name .. " = " .. variable.value
      end
    end,
    virt_text_pos = vim.fn.has("nvim-0.10") == 1 and "inline" or "eol",
    all_frames = false,
    virt_lines = false,
    virt_text_win_col = nil,
  })
end

-- =============================================================================
-- MASON-NVIM-DAP (auto-install adapters)
-- =============================================================================
local ok_mason_dap, mason_dap = pcall(require, "mason-nvim-dap")
if ok_mason_dap then
  mason_dap.setup({
    ensure_installed = {
      "python", -- debugpy
      "js", -- js-debug-adapter (TS/JS/Node *and* Chrome)
      "codelldb", -- C / C++ / Rust
      -- Java is handled by nvim-jdtls + java-debug-adapter, see below
      --
      -- Two entries were removed here:
      --
      --   "chrome" -> resolves to the mason package `chrome-debug-adapter`,
      --   the long-superseded standalone adapter. The `pwa-chrome` adapter
      --   this config actually registers below comes out of
      --   js-debug-adapter, which is already in the list. Installing it
      --   fetched a second, unused, unmaintained adapter.
      --
      --   "delve" -> the Go adapter. It needs a Go toolchain to build, so
      --   on a machine without Go the install FAILS, and because it stays
      --   in ensure_installed it is retried on every single DAP load --
      --   "[mason-nvim-dap] installing delve" plus a network job, forever.
      --   dap.configurations.go below is untouched, so `go install
      --   github.com/go-delve/delve/cmd/dlv@latest` still lights it up.
    },
    automatic_installation = true,
    handlers = {}, -- use default handlers; we override per-language below
  })
end

-- =============================================================================
-- PYTHON  (debugpy via mason)
-- =============================================================================
local ok_dap_python, dap_python = pcall(require, "dap-python")
if ok_dap_python then
  -- nvim-dap-python will auto-detect the active venv
  local debugpy_path = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python"
  if vim.fn.executable(debugpy_path) == 0 then
    debugpy_path = "python3" -- fallback to system python
  end
  dap_python.setup(debugpy_path)
  dap_python.test_runner = "pytest"
else
  -- Fallback manual Python config if nvim-dap-python isn't installed
  dap.adapters.python = {
    type = "executable",
    command = vim.fn.stdpath("data") .. "/mason/packages/debugpy/venv/bin/python",
    args = { "-m", "debugpy.adapter" },
  }
  dap.configurations.python = {
    {
      type = "python",
      request = "launch",
      name = "Launch file",
      program = "${file}",
      pythonPath = function()
        local venv = os.getenv("VIRTUAL_ENV")
        if venv then
          return venv .. "/bin/python"
        end
        local conda = os.getenv("CONDA_DEFAULT_ENV")
        if conda then
          return vim.fn.exepath("python")
        end
        return vim.fn.exepath("python3") or "python3"
      end,
    },
    {
      type = "python",
      request = "launch",
      name = "Launch with args",
      program = "${file}",
      args = function()
        local args = vim.fn.input("Args: ")
        return vim.split(args, " ", { trimempty = true })
      end,
    },
    {
      type = "python",
      request = "attach",
      name = "Attach remote (debugpy)",
      connect = { host = "127.0.0.1", port = 5678 },
    },
  }
end

-- =============================================================================
-- JAVASCRIPT / TYPESCRIPT  (js-debug-adapter, covers Node + Chrome)
-- =============================================================================
dap.adapters["pwa-node"] = {
  type = "server",
  host = "localhost",
  port = "${port}",
  executable = {
    command = "node",
    args = {
      vim.fn.stdpath("data") .. "/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js",
      "${port}",
    },
  },
}

dap.adapters["pwa-chrome"] = {
  type = "server",
  host = "localhost",
  port = "${port}",
  executable = {
    command = "node",
    args = {
      vim.fn.stdpath("data") .. "/mason/packages/js-debug-adapter/js-debug/src/dapDebugServer.js",
      "${port}",
    },
  },
}

-- Shared JS/TS configurations
local js_configs = {
  {
    type = "pwa-node",
    request = "launch",
    name = "Launch Node (current file)",
    program = "${file}",
    cwd = "${workspaceFolder}",
    sourceMaps = true,
    resolveSourceMapLocations = { "${workspaceFolder}/**", "!**/node_modules/**" },
  },
  {
    type = "pwa-node",
    request = "attach",
    name = "Attach to Node process",
    processId = require("dap.utils").pick_process,
    cwd = "${workspaceFolder}",
    sourceMaps = true,
  },
  {
    type = "pwa-node",
    request = "launch",
    name = "Debug Jest tests",
    runtimeExecutable = "node",
    runtimeArgs = { "./node_modules/jest/bin/jest.js", "--runInBand" },
    rootPath = "${workspaceFolder}",
    cwd = "${workspaceFolder}",
    console = "integratedTerminal",
    internalConsoleOptions = "neverOpen",
  },
  {
    type = "pwa-chrome",
    request = "launch",
    name = "Launch Chrome (localhost:3000)",
    url = "http://localhost:3000",
    webRoot = "${workspaceFolder}",
    sourceMaps = true,
  },
  {
    type = "pwa-node",
    request = "launch",
    name = "Launch with ts-node",
    runtimeExecutable = "node",
    runtimeArgs = { "--loader", "ts-node/esm" },
    program = "${file}",
    cwd = "${workspaceFolder}",
    sourceMaps = true,
  },
}

for _, lang in ipairs({ "javascript", "typescript", "javascriptreact", "typescriptreact" }) do
  dap.configurations[lang] = js_configs
end

-- =============================================================================
-- GO  (delve)
-- =============================================================================
local ok_dap_go, dap_go = pcall(require, "dap-go")
if ok_dap_go then
  dap_go.setup({
    delve = {
      path = "dlv",
      initialize_timeout_sec = 20,
      port = "${port}",
      args = {},
      build_flags = "",
      detached = vim.fn.has("win32") == 0,
      cwd = nil,
    },
    dap_configurations = {
      {
        type = "go",
        name = "Attach remote",
        mode = "remote",
        request = "attach",
      },
    },
  })
else
  -- Fallback manual Go config
  dap.adapters.delve = {
    type = "server",
    port = "${port}",
    executable = {
      command = "dlv",
      args = { "dap", "-l", "127.0.0.1:${port}" },
    },
  }
  dap.configurations.go = {
    { type = "delve", name = "Debug", request = "launch", program = "${file}" },
    { type = "delve", name = "Debug test", request = "launch", program = "${file}", mode = "test" },
    { type = "delve", name = "Debug package", request = "launch", program = "${workspaceFolder}" },
    {
      type = "delve",
      name = "Attach to process",
      request = "attach",
      mode = "local",
      processId = require("dap.utils").pick_process,
    },
  }
end

-- =============================================================================
-- C / C++ / RUST  (codelldb via mason)
-- =============================================================================
dap.adapters.codelldb = {
  type = "server",
  port = "${port}",
  executable = {
    -- FIX: Point directly to the raw extension binary
    command = vim.fn.stdpath("data") .. "/mason/packages/codelldb/extension/adapter/codelldb",
    args = { "--port", "${port}" },
    -- On Linux, detach the subprocess cleanly
    detached = vim.fn.has("win32") == 0,
  },
}
local lldb_configs = {
  {
    type = "codelldb",
    request = "launch",
    name = "Launch (codelldb)",
    program = function()
      return vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/", "file")
    end,
    cwd = "${workspaceFolder}",
    stopOnEntry = false,
    terminal = "integrated",
  },
  {
    type = "codelldb",
    request = "attach",
    name = "Attach to process",
    pid = require("dap.utils").pick_process,
    cwd = "${workspaceFolder}",
  },
}

dap.configurations.c = lldb_configs
dap.configurations.cpp = lldb_configs
dap.configurations.rust = {
  {
    type = "codelldb",
    request = "launch",
    name = "Debug Rust binary",
    program = function()
      -- Try to find the binary from Cargo metadata
      local metadata = vim.fn.system("cargo metadata --format-version 1 --no-deps 2>/dev/null")
      local ok, data = pcall(vim.fn.json_decode, metadata)
      if ok and data and data.target_directory then
        return vim.fn.input("Executable: ", data.target_directory .. "/debug/", "file")
      end
      return vim.fn.input("Executable: ", vim.fn.getcwd() .. "/target/debug/", "file")
    end,
    cwd = "${workspaceFolder}",
    stopOnEntry = false,
    terminal = "integrated",
  },
  {
    type = "codelldb",
    request = "launch",
    name = "Debug Rust test",
    cargo = {
      args = { "test", "--no-run", "--lib" },
    },
    cwd = "${workspaceFolder}",
    stopOnEntry = false,
  },
}

-- =============================================================================
-- JAVA  (handled by nvim-jdtls — you already have ajay.jdtls)
-- The java-debug-adapter is loaded by jdtls automatically.
-- We just wire up the DAP adapter so keymaps work universally.
-- =============================================================================
-- NOTE: Don't add dap.adapters.java here — nvim-jdtls registers it.
-- If you want explicit configs:
dap.configurations.java = {
  {
    type = "java",
    request = "attach",
    name = "Attach to remote JVM",
    hostName = "127.0.0.1",
    port = 5005,
  },
}

-- =============================================================================
-- .vscode/launch.json support  (load project-local configs automatically)
-- =============================================================================
-- This lets you use .vscode/launch.json files from any project
local vscode_ok, vscode = pcall(require, "dap.ext.vscode")
if vscode_ok then
  local launch = vim.fn.getcwd() .. "/.vscode/launch.json"
  if vim.fn.filereadable(launch) == 1 then
    vscode.load_launchjs(launch, {
      -- Map vscode type strings to our adapter names
      ["node"] = { "javascript", "typescript" },
      ["node2"] = { "javascript", "typescript" },
      ["pwa-node"] = { "javascript", "typescript", "javascriptreact", "typescriptreact" },
      ["pwa-chrome"] = { "javascriptreact", "typescriptreact", "javascript", "typescript" },
      ["python"] = { "python" },
      ["cppdbg"] = { "c", "cpp" },
      ["codelldb"] = { "c", "cpp", "rust" },
      ["go"] = { "go" },
      ["java"] = { "java" },
    })
  end
end

-- =============================================================================
-- KEYMAPS
-- All under <leader>d prefix so they don't clash with your existing maps
-- =============================================================================
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Core session control
map("n", "<leader>dc", dap.continue, vim.tbl_extend("force", opts, { desc = "DAP Continue / Start" }))
map("n", "<leader>dq", dap.terminate, vim.tbl_extend("force", opts, { desc = "DAP Terminate" }))
map("n", "<leader>dr", dap.restart, vim.tbl_extend("force", opts, { desc = "DAP Restart" }))
map("n", "<leader>dp", dap.pause, vim.tbl_extend("force", opts, { desc = "DAP Pause" }))

-- Step controls (F-keys feel natural for stepping, similar to VS Code / JetBrains)
map("n", "<F5>", dap.continue, vim.tbl_extend("force", opts, { desc = "DAP Continue" }))
map("n", "<F6>", dap.step_over, vim.tbl_extend("force", opts, { desc = "DAP Step Over" }))
map("n", "<F7>", dap.step_into, vim.tbl_extend("force", opts, { desc = "DAP Step Into" }))
map("n", "<F8>", dap.step_out, vim.tbl_extend("force", opts, { desc = "DAP Step Out" }))
map("n", "<F9>", dap.step_back, vim.tbl_extend("force", opts, { desc = "DAP Step Back" }))
map("n", "<F10>", dap.run_to_cursor, vim.tbl_extend("force", opts, { desc = "DAP Run to Cursor" }))

-- Breakpoints
map("n", "<leader>db", dap.toggle_breakpoint, vim.tbl_extend("force", opts, { desc = "DAP Toggle Breakpoint" }))
map("n", "<leader>dB", function()
  dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
end, vim.tbl_extend("force", opts, { desc = "DAP Conditional Breakpoint" }))
map("n", "<leader>dl", function()
  dap.set_breakpoint(nil, nil, vim.fn.input("Log point message: "))
end, vim.tbl_extend("force", opts, { desc = "DAP Log Point" }))
map("n", "<leader>dC", dap.clear_breakpoints, vim.tbl_extend("force", opts, { desc = "DAP Clear All Breakpoints" }))

-- REPL
map("n", "<leader>dR", function()
  dap.repl.toggle({}, "vsplit")
end, vim.tbl_extend("force", opts, { desc = "DAP Toggle REPL" }))

-- DAP UI
if ok_dapui then
  map("n", "<leader>du", dapui.toggle, vim.tbl_extend("force", opts, { desc = "DAP UI Toggle" }))
  map("n", "<leader>de", function()
    dapui.eval(nil, { enter = true })
  end, vim.tbl_extend("force", opts, { desc = "DAP Eval expression" }))
  -- Eval in visual mode — select an expression and evaluate it
  map("v", "<leader>de", function()
    dapui.eval()
  end, vim.tbl_extend("force", opts, { desc = "DAP Eval selection" }))
  -- Hover for value under cursor (like a quick peek)
  map("n", "<leader>dK", function()
    require("dap.ui.widgets").hover()
  end, vim.tbl_extend("force", opts, { desc = "DAP Hover Value" }))
  -- Sidebar: frames and scopes floating windows
  map("n", "<leader>df", function()
    local widgets = require("dap.ui.widgets")
    widgets.centered_float(widgets.frames)
  end, vim.tbl_extend("force", opts, { desc = "DAP Frames" }))
  map("n", "<leader>ds", function()
    local widgets = require("dap.ui.widgets")
    widgets.centered_float(widgets.scopes)
  end, vim.tbl_extend("force", opts, { desc = "DAP Scopes" }))
end

-- Python-specific (nvim-dap-python)
if ok_dap_python then
  map("n", "<leader>dtn", function()
    dap_python.test_method()
  end, vim.tbl_extend("force", opts, { desc = "DAP Python: debug test method" }))
  map("n", "<leader>dtc", function()
    dap_python.test_class()
  end, vim.tbl_extend("force", opts, { desc = "DAP Python: debug test class" }))
  map("v", "<leader>dts", function()
    dap_python.debug_selection()
  end, vim.tbl_extend("force", opts, { desc = "DAP Python: debug selection" }))
end

-- =============================================================================
-- KEYMAP REFERENCE  (printed on demand with <leader>d?)
-- =============================================================================
map("n", "<leader>d?", function()
  local keys = {
    "═══════════════ DAP KEYMAPS ═══════════════",
    "  <F5>          Continue / Start",
    "  <F6>          Step Over",
    "  <F7>          Step Into",
    "  <F8>          Step Out",
    "  <F9>          Step Back",
    "  <F10>         Run to Cursor",
    "  <leader>db    Toggle Breakpoint",
    "  <leader>dB    Conditional Breakpoint",
    "  <leader>dl    Log Point",
    "  <leader>dC    Clear All Breakpoints",
    "  <leader>dc    Continue",
    "  <leader>dq    Terminate",
    "  <leader>dr    Restart",
    "  <leader>dp    Pause",
    "  <leader>dR    Toggle REPL",
    "  <leader>du    Toggle DAP UI",
    "  <leader>de    Eval Expression / Selection",
    "  <leader>dK    Hover Value",
    "  <leader>df    Floating Frames",
    "  <leader>ds    Floating Scopes",
    "  <leader>dtn   Python: test method",
    "  <leader>dtc   Python: test class",
    "  <leader>dts   Python: debug selection (visual)",
    "═══════════════════════════════════════════",
  }
  vim.notify(table.concat(keys, "\n"), vim.log.levels.INFO, { title = "DAP Keys" })
end, vim.tbl_extend("force", opts, { desc = "DAP: show keymap reference" }))
