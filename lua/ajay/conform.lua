-- lua/ajay/conform.lua

local M = {}

-- ── PERSISTED FORMAT-ON-SAVE STATE ────────────────────────────────
--
-- `vim.g.disable_autoformat` is a plain global, so it died with the
-- session: turn format-on-save off, quit, reopen, and it was silently
-- back ON. That is the worst shape for this particular switch -- you
-- turn it off precisely because a formatter is mangling a file, and the
-- next time you open that file it mangles it again on the first save.
--
-- Persisted to disk instead, using the same pattern (and for the same
-- reason) as the Copilot toggle in copilot.lua: a one-word state file
-- under stdpath("data"), i.e. outside this git repo, so the preference
-- follows the machine rather than the config.
--
-- Only the GLOBAL toggle persists. The buffer-local one
-- (:ToggleFormatOnSaveBuffer) deliberately does not -- a buffer is a
-- session-scoped thing, and a per-file exception that silently outlived
-- the session would be far harder to notice than to just set again.
local state_file = vim.fn.stdpath("data") .. "/format_on_save_state"

--- Read the persisted preference.
--- @return boolean enabled true when format-on-save should be ON
local function read_state()
  local f = io.open(state_file, "r")
  if not f then
    return true -- no file yet: default ON, matching the old behaviour
  end
  local content = f:read("*a")
  f:close()
  return content:gsub("%s+", "") ~= "disabled"
end

--- Persist the preference so it survives a restart.
--- @param enabled boolean
local function write_state(enabled)
  local f = io.open(state_file, "w")
  if f then
    f:write(enabled and "enabled" or "disabled")
    f:close()
  end
end

function M.setup()
  -- Restore BEFORE conform.setup() below registers format_on_save.
  --
  -- Safe despite this module being lazy-loaded on BufWritePre: lazy.nvim
  -- loads the plugin and runs this config function first, then replays
  -- the event to the now-loaded plugin -- so the flag is already correct
  -- by the time conform's own BufWritePre handler asks for it. Nothing
  -- else in the config reads vim.g.disable_autoformat before this point.
  vim.g.disable_autoformat = not read_state()

  local conform_ok, conform = pcall(require, "conform")
  if not conform_ok then
    vim.notify("Conform not installed. Run :Lazy sync", vim.log.levels.WARN)
    return
  end

  conform.setup({
    -- Define formatters by filetype
    formatters_by_ft = {
      -- Lua
      lua = { "stylua" },

      -- Python
      python = { "isort", "black" },

      -- JavaScript/TypeScript (IMPORTANT!)
      javascript = { "prettier" },
      javascriptreact = { "prettier" },
      typescript = { "prettier" },
      typescriptreact = { "prettier" },

      -- Web
      html = { "prettier" },
      -- Angular templates are their OWN filetype (htmlangular), so an
      -- `html` entry never reached them -- <leader>lf and format-on-save
      -- were both no-ops in every .component.html. Plain prettier is
      -- enough: its html parser already understands *ngIf, [(ngModel)],
      -- {{ interpolation }} and Angular 17 @if/@for control flow, and
      -- produces byte-identical output to `--parser angular`.
      htmlangular = { "prettier" },
      css = { "prettier" },
      scss = { "prettier" },
      json = { "prettier" },
      jsonc = { "prettier" },
      yaml = { "prettier" },
      markdown = { "prettier" },

      -- C/C++
      c = { "clang_format" },
      cpp = { "clang_format" },

      -- Java
      java = { "google-java-format" },

      -- Shell
      sh = { "shfmt" },
      bash = { "shfmt" },

      -- Go
      go = { "goimports", "gofumpt" },

      -- XML has no entry here on purpose. lemminx (lsp.lua) is a solid
      -- formatter on its own, and format_on_save below already sets
      -- lsp_format = "fallback" -- conform reaches for lemminx automatically
      -- since no formatters_by_ft.xml exists. One less CLI tool to install.
    },

    -- Format on save
    format_on_save = function(bufnr)
      -- Disable with a global or buffer-local variable
      if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
        return
      end

      return {
        timeout_ms = 3000,
        -- `lsp_fallback = true` is the legacy spelling; conform maps it to
        -- this internally. Written out so it doesn't silently change
        -- meaning when the shim eventually goes.
        lsp_format = "fallback",
      }
    end,

    -- Customize formatters
    formatters = {
      stylua = {
        prepend_args = { "--indent-type", "Spaces", "--indent-width", "2" },
      },
      prettier = {
        prepend_args = {
          "--tab-width",
          "2",
          "--use-tabs",
          "false",
          "--single-quote",
          "false",
          "--trailing-comma",
          "es5",
          "--semi",
          "true",
        },
      },
      black = {
        prepend_args = { "--line-length", "88" },
      },

      -- ── THE IMPORT-DELETION FIX ──────────────────────────────────
      --
      -- google-java-format rewrites imports BY DEFAULT. Two separate
      -- behaviours, both on unless you turn them off:
      --   * removes imports it thinks are unused
      --   * re-sorts the remaining ones
      --
      -- The problem is that it does this with NO CLASSPATH, looking at
      -- one file in isolation. It deletes any import whose simple name
      -- it can't find an AST reference to in that single file. It has no
      -- idea what Lombok generates, what a wildcard import pulls in, or
      -- what another module in your project defines.
      --
      -- jdtls has the full project classpath and knows the truth. So on
      -- every save, the dumber tool was overwriting the smarter one.
      --
      -- Sorting is disabled for the same reason: gjf sorts ASCIIbetically
      -- into a single block, while jdtls uses the importOrder you set in
      -- jdtls.lua (java, javax, jakarta, org, com). They disagreed, so
      -- your imports got reshuffled on every write.
      --
      -- Net effect: google-java-format now only touches whitespace and
      -- line breaks. Imports belong to jdtls — use <leader>jo to organize
      -- them deliberately.
      ["google-java-format"] = {
        prepend_args = {
          "--skip-removing-unused-imports",
          "--skip-sorting-imports",
        },
      },
    },
  })

  -- Command to format current buffer
  vim.api.nvim_create_user_command("Format", function(args)
    local range = nil
    if args.count ~= -1 then
      local end_line = vim.api.nvim_buf_get_lines(0, args.line2 - 1, args.line2, true)[1]
      range = {
        start = { args.line1, 0 },
        ["end"] = { args.line2, end_line:len() },
      }
    end
    require("conform").format({ async = true, lsp_format = "fallback", range = range })
  end, { range = true })

  -- Toggle format on save (global) -- and REMEMBER it across restarts.
  vim.api.nvim_create_user_command("ToggleFormatOnSave", function()
    local enabled = vim.g.disable_autoformat == true -- flipping to this
    vim.g.disable_autoformat = not enabled
    write_state(enabled)
    if enabled then
      vim.notify("✓ Format on save: ENABLED (saved)", vim.log.levels.INFO)
    else
      vim.notify("✗ Format on save: DISABLED (saved, survives restart)", vim.log.levels.WARN)
    end
  end, { desc = "Toggle format on save globally, persisted across restarts" })

  -- Toggle format on save for current buffer only.
  --
  -- Note the asymmetry with the global toggle: turning the BUFFER back on
  -- while the GLOBAL is off changes nothing observable, because
  -- format_on_save ORs the two. Say so rather than let it look broken.
  vim.api.nvim_create_user_command("ToggleFormatOnSaveBuffer", function()
    if vim.b.disable_autoformat then
      vim.b.disable_autoformat = false
      if vim.g.disable_autoformat then
        vim.notify(
          "✓ Format on save (buffer): ENABLED\n"
            .. "  ...but format-on-save is still OFF globally, so this buffer\n"
            .. "  will NOT format. Use <leader>tf / :ToggleFormatOnSave.",
          vim.log.levels.WARN
        )
      else
        vim.notify("✓ Format on save (buffer): ENABLED", vim.log.levels.INFO)
      end
    else
      vim.b.disable_autoformat = true
      vim.notify("✗ Format on save (buffer): DISABLED", vim.log.levels.WARN)
    end
  end, { desc = "Toggle format on save for current buffer" })

  -- Show format status.
  --
  -- Reports the EFFECTIVE answer, not just the two flags. format_on_save
  -- above combines them with OR -- `vim.g.disable_autoformat or
  -- vim.b[bufnr].disable_autoformat` -- so the global is a master switch:
  -- with it off, nothing formats no matter what the buffer says.
  --
  -- Printing the two flags side by side without that conclusion was
  -- actively misleading. With the global off it read
  --     Global: DISABLED    Buffer: ENABLED
  -- which looks like this buffer will format. It will not.
  local function effective_state()
    local g_off = vim.g.disable_autoformat == true
    local b_off = vim.b.disable_autoformat == true
    if g_off then
      return false, "the global switch overrides the buffer"
    elseif b_off then
      return false, "this buffer is excluded"
    end
    return true, nil
  end

  vim.api.nvim_create_user_command("FormatStatus", function()
    local global = not vim.g.disable_autoformat
    local buffer = not vim.b.disable_autoformat
    local eff, why = effective_state()

    local status = string.format(
      "Format on save:\n  Global : %s  (saved on disk: %s)\n  Buffer : %s  (this session only)\n\n  On save here: %s",
      global and "ENABLED ✓" or "DISABLED ✗",
      read_state() and "enabled" or "disabled",
      buffer and "ENABLED ✓" or "DISABLED ✗",
      eff and "WILL FORMAT" or ("WILL NOT FORMAT — " .. why)
    )
    vim.notify(status, eff and vim.log.levels.INFO or vim.log.levels.WARN)
  end, { desc = "Show format on save status" })

  -- Keymaps
  vim.keymap.set({ "n", "v" }, "<leader>lf", function()
    require("conform").format({ async = true, lsp_format = "fallback" })
  end, { desc = "Format buffer or range" })

  vim.keymap.set("n", "<leader>tf", ":ToggleFormatOnSave<CR>", {
    desc = "Toggle format on save (global)",
    silent = true,
  })

  vim.keymap.set("n", "<leader>tF", ":ToggleFormatOnSaveBuffer<CR>", {
    desc = "Toggle format on save (buffer)",
    silent = true,
  })
  vim.keymap.set("n", "<leader>ts", ":FormatStatus<CR>", {
    desc = "Format status",
    silent = true,
  })

  vim.keymap.set("n", "<leader>ti", ":ConformInfo<CR>", {
    desc = "Conform info",
    silent = true,
  })
end

return M
