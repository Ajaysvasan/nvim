-- lua/ajay/lsp.lua
--
-- Rewritten for the Neovim 0.11+ LSP API. Key fixes:
--
--  1. `client.supports_method(...)` (dot) -> `client:supports_method(...)` (colon)
--     The dot form is deprecated in 0.11 and REMOVED in 0.12. Homebrew's
--     Neovim is almost always newer than what a distro repo ships, so this
--     is the single most likely source of the "ton of errors" on the Mac.
--  2. One `LspAttach` autocmd instead of an `on_attach` copy-pasted into
--     every server table.
--  3. Only override what needs overriding. nvim-lspconfig ships `cmd` and
--     `root_markers` for every one of these servers in its own `lsp/`
--     directory; hardcoding `cmd` meant a Mason-installed binary that
--     wasn't on PATH yet would silently fail to start.
--  4. `vim.diagnostic.goto_next/goto_prev` -> `vim.diagnostic.jump`.
--  5. Removed the custom `LspRestart` command — 0.11 ships one, and
--     redefining it shadowed the built-in.

-- ── Diagnostics ────────────────────────────────────────────────────
-- Glyphs come from ajay.icons, which builds them from codepoints rather
-- than embedding the characters. The literals that used to be here were
-- stripped to empty strings somewhere in a copy, and an empty sign text
-- renders NOTHING in the gutter without raising an error -- diagnostics
-- silently stop appearing.
-- Soft dependency on purpose. lsp.lua drives EVERY language server, so a
-- missing ajay/icons.lua must not take all of them down -- it should cost
-- you pretty gutter symbols, nothing more.
local ok_icons, icons = pcall(require, "ajay.icons")
if not ok_icons then
  icons = { diagnostics = { ERROR = "E", WARN = "W", INFO = "I", HINT = "H" } }
  vim.schedule(function()
    vim.notify("ajay/icons.lua not found - using ASCII diagnostic signs", vim.log.levels.WARN)
  end)
end

vim.diagnostic.config({
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = icons.diagnostics.ERROR,
      [vim.diagnostic.severity.WARN] = icons.diagnostics.WARN,
      [vim.diagnostic.severity.HINT] = icons.diagnostics.HINT,
      [vim.diagnostic.severity.INFO] = icons.diagnostics.INFO,
    },
  },
  virtual_text = {
    severity = { min = vim.diagnostic.severity.ERROR },
    spacing = 2,
  },
  float = { border = "rounded", source = true },
  severity_sort = true,
  update_in_insert = false,
})

-- ── Mason ──────────────────────────────────────────────────────────
local ensure_servers = {
  "pyright",
  "clangd",
  "jdtls",
  "ts_ls",
  "eslint",
  "html",
  "cssls",
  "lua_ls",
  "tailwindcss",
}

local ensure_tools = {
  "prettier",
  "eslint_d",
  "clang-format",
  "black",
  "isort",
  "stylua",
  "google-java-format",
  "shfmt",
}

require("mason").setup({ ui = { border = "rounded" } })

require("mason-lspconfig").setup({
  ensure_installed = ensure_servers,
  -- mason-lspconfig v2 renamed this. `automatic_installation` is a no-op
  -- now; `automatic_enable` is what calls vim.lsp.enable() for you.
  -- jdtls is excluded because nvim-jdtls owns it.
  automatic_enable = { exclude = { "jdtls" } },
})

local mti_ok, mti = pcall(require, "mason-tool-installer")
if mti_ok then
  mti.setup({
    ensure_installed = ensure_tools,
    auto_update = false, -- was true: this fires a network job on every start
    run_on_start = true,
  })
end

-- ── Capabilities ───────────────────────────────────────────────────
local capabilities = vim.lsp.protocol.make_client_capabilities()
local cmp_ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
if cmp_ok then
  capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
end

-- Applies to every server, including ones Mason enables automatically.
vim.lsp.config("*", { capabilities = capabilities })

-- ── Per-server overrides ───────────────────────────────────────────
vim.lsp.config("clangd", {
  cmd = {
    "clangd",
    "--background-index",
    "--clang-tidy",
    "--completion-style=detailed",
    "--header-insertion=iwyu",
  },
})

vim.lsp.config("pyright", {
  settings = {
    python = {
      analysis = {
        typeCheckingMode = "basic",
        useLibraryCodeForTypes = true,
        autoSearchPaths = true,
        diagnosticMode = "workspace",
      },
    },
  },
})

vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      runtime = { version = "LuaJIT" },
      diagnostics = { globals = { "vim" } },
      workspace = {
        library = vim.api.nvim_get_runtime_file("", true),
        checkThirdParty = false,
      },
      telemetry = { enable = false },
    },
  },
})

vim.lsp.config("tailwindcss", {
  settings = {
    tailwindCSS = {
      classAttributes = { "class", "className", "classList", "ngClass" },
      lint = {
        cssConflict = "warning",
        invalidApply = "error",
        invalidConfigPath = "error",
        invalidScreen = "error",
        invalidTailwindDirective = "error",
        invalidVariant = "error",
        recommendedVariantOrder = "warning",
      },
      validate = true,
    },
  },
})

-- ── Shared attach behaviour ────────────────────────────────────────
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("ajay_lsp_attach", { clear = true }),
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client then
      return
    end
    local bufnr = ev.buf

    local function map(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
    end

    -- Navigation
    map("n", "gd", vim.lsp.buf.definition, "Go to definition")
    map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
    map("n", "gr", vim.lsp.buf.references, "Go to references")
    map("n", "gi", vim.lsp.buf.implementation, "Go to implementation")
    map("n", "gt", vim.lsp.buf.type_definition, "Go to type definition")

    -- Docs
    map("n", "K", vim.lsp.buf.hover, "Hover documentation")
    map("n", "<C-k>", vim.lsp.buf.signature_help, "Signature help")

    -- Actions
    map("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
    map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")

    -- Diagnostics. The old config put these on <leader>e / <leader>q,
    -- which shadowed `:q<CR>` from keymaps.lua inside every LSP buffer,
    -- and the whole <leader>d prefix belongs to nvim-dap. Moved to <leader>x.
    map("n", "[d", function()
      vim.diagnostic.jump({ count = -1, float = true })
    end, "Previous diagnostic")
    map("n", "]d", function()
      vim.diagnostic.jump({ count = 1, float = true })
    end, "Next diagnostic")
    map("n", "<leader>xd", vim.diagnostic.open_float, "Show diagnostic")
    map("n", "<leader>xq", vim.diagnostic.setloclist, "Diagnostic list")

    -- Workspace
    map("n", "<leader>wa", vim.lsp.buf.add_workspace_folder, "Add workspace folder")
    map("n", "<leader>wr", vim.lsp.buf.remove_workspace_folder, "Remove workspace folder")
    map("n", "<leader>wl", function()
      print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, "List workspace folders")

    -- tsserver formatting off — conform/prettier owns JS/TS.
    if client.name == "ts_ls" then
      client.server_capabilities.documentFormattingProvider = false
      client.server_capabilities.documentRangeFormattingProvider = false
    end

    -- ESLint auto-fix on save
    if client.name == "eslint" then
      vim.api.nvim_create_autocmd("BufWritePre", {
        buffer = bufnr,
        callback = function()
          pcall(vim.cmd, "LspEslintFixAll")
        end,
      })
    end

    -- Inlay hints. Colon call form — required on 0.11+.
    if client:supports_method("textDocument/inlayHint") then
      vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
    end

    -- CodeLens: the IntelliJ-style "3 references / 2 implementations"
    -- line above each class and method.
    --
    -- jdtls.lua sets implementationsCodeLens.enabled and
    -- referencesCodeLens.enabled, so the server PUBLISHES them. But
    -- Neovim does not render code lenses on its own -- nothing appears
    -- until something calls vim.lsp.codelens.refresh(). Neither your
    -- original config nor my rewrite ever did, so those two settings
    -- have been switched on and doing nothing this whole time.
    if client:supports_method("textDocument/codeLens") then
      local group = vim.api.nvim_create_augroup("ajay_codelens_" .. bufnr, { clear = true })

      -- Deliberately NOT on CursorHold: for jdtls every refresh is a
      -- round trip that resolves references across the whole project.
      -- On these events it stays responsive.
      vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave", "BufWritePost" }, {
        group = group,
        buffer = bufnr,
        callback = function()
          if not vim.g.codelens_off then
            vim.lsp.codelens.refresh({ bufnr = bufnr })
          end
        end,
      })

      -- The server usually can't answer at attach time; jdtls in
      -- particular needs the project imported first.
      vim.defer_fn(function()
        if vim.api.nvim_buf_is_valid(bufnr) and not vim.g.codelens_off then
          vim.lsp.codelens.refresh({ bufnr = bufnr })
        end
      end, 800)

      map("n", "<leader>cl", vim.lsp.codelens.run, "Run code lens under cursor")
    end
  end,
})

vim.api.nvim_create_user_command("ToggleCodeLens", function()
  local buf = vim.api.nvim_get_current_buf()
  if vim.g.codelens_off then
    vim.g.codelens_off = false
    vim.lsp.codelens.refresh({ bufnr = buf })
    vim.notify("CodeLens: ON", vim.log.levels.INFO)
  else
    vim.g.codelens_off = true
    vim.lsp.codelens.clear(nil, buf)
    vim.notify("CodeLens: OFF", vim.log.levels.WARN)
  end
end, { desc = "Toggle reference/implementation counts" })

vim.api.nvim_create_user_command("ToggleInlayHints", function()
  local buf = vim.api.nvim_get_current_buf()
  local on = vim.lsp.inlay_hint.is_enabled({ bufnr = buf })
  vim.lsp.inlay_hint.enable(not on, { bufnr = buf })
  vim.notify("Inlay hints: " .. (on and "OFF" or "ON"), vim.log.levels.INFO)
end, { desc = "Toggle inlay hints" })
