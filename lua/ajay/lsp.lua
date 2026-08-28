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
  -- Angular. filetypes = typescript, html, typescriptreact, htmlangular;
  -- root_markers = angular.json / nx.json, so it starts ONLY inside an
  -- actual Angular workspace and stays out of the way in every other
  -- TypeScript project. Without it a .component.html gets the generic
  -- html server, which has never heard of *ngIf, [(ngModel)] or @if.
  "angularls",
  -- Emmet. nvim-emmet (<leader>xe) is not a standalone expander -- it
  -- sends emmet/expandAbbreviation over LSP and does NOTHING if no server
  -- answers. That keymap was silently dead until this server existed.
  "emmet_language_server",
}

local ensure_tools = {
  "prettier",
  -- eslint_d was here. Nothing used it: it is a daemon for nvim-lint /
  -- null-ls, and this config has neither -- ESLint diagnostics come from
  -- the `eslint` language server above, and fixes from LspEslintFixAll on
  -- BufWritePre. Keeping it meant a package to install and update that
  -- could never affect the editor.
  "clang-format",
  "black",
  "isort",
  "stylua",
  "google-java-format",
  "shfmt",
}

-- Deliberately NOT called at load time -- see "Mason, on demand" at the
-- bottom of this file. Building the mason registry costs ~12ms on every
-- startup that opens a file, to do work that only matters when something
-- actually needs installing.
local function setup_mason()
  require("mason").setup({ ui = { border = "rounded" } })

  local mlc_ok, mlc = pcall(require, "mason-lspconfig")
  if mlc_ok then
    mlc.setup({
      ensure_installed = ensure_servers,
      -- mason-lspconfig v2 renamed this. `automatic_installation` is a
      -- no-op now; `automatic_enable` is what calls vim.lsp.enable() for
      -- you, and it is what picks a server up once it has been installed.
      -- jdtls is excluded because nvim-jdtls owns it.
      automatic_enable = { exclude = { "jdtls" } },
    })
  end

  local mti_ok, mti = pcall(require, "mason-tool-installer")
  if mti_ok then
    mti.setup({
      ensure_installed = ensure_tools,
      auto_update = false, -- was true: this fires a network job on every start
      run_on_start = true,
    })
  end
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

-- angularls ships `root_markers = { "angular.json", "nx.json" }`, which is
-- NOT a gate. When no marker matches, vim.lsp leaves root_dir nil and
-- starts the server anyway in single-file mode -- so a plain React or
-- Node project was spawning an ngserver process for every .ts, .tsx and
-- .html buffer it opened.
--
-- A root_dir FUNCTION is the actual gate: the client only starts if
-- on_dir() is called, so returning without calling it means "not an
-- Angular workspace, do not start".
vim.lsp.config("angularls", {
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local start = fname ~= "" and fname or vim.fn.getcwd()
    local root = vim.fs.root(start, { "angular.json", "nx.json" })
    if root then
      on_dir(root)
    end
  end,
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
    -- line above each class and method. jdtls.lua sets
    -- implementationsCodeLens.enabled and referencesCodeLens.enabled, so
    -- the server publishes them.
    --
    -- PERF + DEPRECATION. This used to drive refreshes by hand from
    -- BufEnter/InsertLeave/BufWritePost plus a deferred 800ms kick, via
    -- vim.lsp.codelens.refresh(). All of that is now redundant AND
    -- actively harmful:
    --
    --   * Neovim 0.12 refreshes code lenses itself. The codelens provider
    --     does nvim_buf_attach{on_lines, on_reload} and issues its own
    --     internally-debounced request, so our autocmds were stacking
    --     EXTRA project-wide round trips on top of the ones Neovim was
    --     already making. For jdtls each of those resolves references
    --     across the whole project -- it is the single most expensive
    --     thing an LSP does here, and InsertLeave fires constantly.
    --   * vim.lsp.codelens.refresh() is deprecated in 0.12 and REMOVED in
    --     0.13. It printed a deprecation warning on every attach.
    --
    -- One call, same shape as inlay hints above, and Neovim owns the
    -- lifecycle. Skipped entirely on big files (see ajay/bigfile.lua).
    if client:supports_method("textDocument/codeLens") then
      if not vim.g.codelens_off and not vim.b[bufnr].codelens_off then
        vim.lsp.codelens.enable(true, { bufnr = bufnr })
      end
      map("n", "<leader>cl", vim.lsp.codelens.run, "Run code lens under cursor")
    end
  end,
})

vim.api.nvim_create_user_command("ToggleCodeLens", function()
  local buf = vim.api.nvim_get_current_buf()
  -- enable/is_enabled, not refresh/clear: same 0.12 API as above.
  local on = vim.lsp.codelens.is_enabled({ bufnr = buf })
  vim.g.codelens_off = on
  vim.lsp.codelens.enable(not on, { bufnr = buf })
  vim.notify("CodeLens: " .. (on and "OFF" or "ON"), on and vim.log.levels.WARN or vim.log.levels.INFO)
end, { desc = "Toggle reference/implementation counts" })

vim.api.nvim_create_user_command("ToggleInlayHints", function()
  local buf = vim.api.nvim_get_current_buf()
  local on = vim.lsp.inlay_hint.is_enabled({ bufnr = buf })
  vim.lsp.inlay_hint.enable(not on, { bufnr = buf })
  vim.notify("Inlay hints: " .. (on and "OFF" or "ON"), vim.log.levels.INFO)
end, { desc = "Toggle inlay hints" })

-- ══════════════════════════════════════════════════════════════════
-- MASON, ON DEMAND
-- ══════════════════════════════════════════════════════════════════
--
-- The old flow: build the mason registry on every startup, let
-- mason-lspconfig work out what is installed, and have it call
-- vim.lsp.enable() for us. Correct, but it paid full registry cost every
-- single launch to answer a question that is almost always "everything is
-- already installed, do nothing". It was ~12ms of a ~40ms startup.
--
-- The new flow inverts it:
--
--   1. Ask the cheap question first -- is each server/tool binary on PATH?
--      That is a filesystem stat, not a registry build. options.lua has
--      already put mason's bin directory on PATH, so mason-installed
--      binaries resolve without mason being loaded at all.
--   2. Enable the servers that are present. vim.lsp.enable() is all that
--      is needed on 0.11+; nvim-lspconfig ships cmd/root_markers for every
--      server in its own lsp/ directory.
--   3. Only if something is MISSING, load mason and let it install --
--      scheduled onto the main loop so it never blocks the first draw.
--      mason-lspconfig's automatic_enable then picks up whatever it
--      installs, so a fresh machine still converges without a restart.
--
-- Net effect: on a machine where everything is installed, mason is never
-- loaded at all unless you ask for it with :Mason or :MasonSync.

-- Node-based servers do NOT ship `cmd` as a table. nvim-lspconfig gives
-- them a FUNCTION so it can prefer a project-local
-- node_modules/.bin/<server> over the global one:
--
--   cmd = function(dispatchers, config)
--     local cmd = 'typescript-language-server'
--     if (config or {}).root_dir then ... prefer local ... end
--     return vim.lsp.rpc.start({ cmd, '--stdio' }, dispatchers)
--   end
--
-- There is no cmd[1] to read, and calling the function to find out would
-- SPAWN the server. Every one of these closures falls back to a fixed
-- global binary name, so name them here. Getting this wrong is silent:
-- the server is simply never enabled and nothing is logged.
local fallback_bin = {
  ts_ls = "typescript-language-server",
  eslint = "vscode-eslint-language-server",
  html = "vscode-html-language-server",
  cssls = "vscode-css-language-server",
  tailwindcss = "tailwindcss-language-server",
  angularls = "ngserver",
  jdtls = "jdtls",
}

-- The binary that actually has to exist for a server to start, read from
-- the config nvim-lspconfig ships wherever that is possible.
local function server_bin(name)
  local ok, cfg = pcall(function()
    return vim.lsp.config[name]
  end)
  local cmd = ok and cfg and cfg.cmd
  if type(cmd) == "table" then
    return cmd[1]
  end
  return fallback_bin[name]
end

local ready, missing, unknown = {}, false, {}

for _, name in ipairs(ensure_servers) do
  local bin = server_bin(name)
  if bin == nil then
    -- A server whose cmd we cannot introspect and that is not in
    -- fallback_bin. Previously this branch silently did nothing, which is
    -- exactly how ts_ls/eslint/html/cssls/tailwindcss ended up disabled
    -- for weeks without a single error message. Say so instead.
    table.insert(unknown, name)
  elseif vim.fn.executable(bin) ~= 1 then
    missing = true
  elseif name ~= "jdtls" then
    -- jdtls is INSTALLED by mason but STARTED by nvim-jdtls, which builds
    -- its own cmd with the Lombok javaagent and a per-project workspace.
    -- Enabling it here would race a second, misconfigured client.
    table.insert(ready, name)
  end
end

if not missing then
  for _, tool in ipairs(ensure_tools) do
    if vim.fn.executable(tool) ~= 1 then
      missing = true
      break
    end
  end
end

if #ready > 0 then
  vim.lsp.enable(ready)
end

if missing then
  vim.schedule(setup_mason)
end

if #unknown > 0 then
  vim.schedule(function()
    vim.notify(
      "Cannot determine the binary for: "
        .. table.concat(unknown, ", ")
        .. "\nThese servers were NOT enabled. Add them to `fallback_bin` in lua/ajay/lsp.lua.",
      vim.log.levels.WARN,
      { title = "lsp" }
    )
  end)
end

-- Force the install pass without waiting to notice something is missing.
-- Useful right after editing ensure_servers / ensure_tools above.
vim.api.nvim_create_user_command("MasonSync", function()
  setup_mason()
  vim.notify("Mason loaded - installing anything missing.", vim.log.levels.INFO)
end, { desc = "Load mason and install any missing LSP servers / tools" })
