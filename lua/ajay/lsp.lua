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
--  5. Removed the custom `LspRestart` command.
--
--     CORRECTION: the note here used to say "0.11 ships one". It does not
--     — nvim-lspconfig does. And lspconfig's plugin file starts with
--     `if vim.fn.exists(':lsp') == 2 then return end`, so on 0.12, where
--     Neovim ships a built-in :lsp, lspconfig defines none of LspInfo,
--     LspLog, LspStart, LspStop or LspRestart.
--
--     So the command names differ by version, and neither is ours to
--     define:
--       0.11 :  :LspRestart   :LspInfo   :LspLog    (from lspconfig)
--       0.12 :  :lsp restart  :checkhealth vim.lsp  (core, `:h :lsp`)
--
--     :checkhealth vim.lsp works on BOTH — it is what LspInfo aliases to
--     on 0.11 — so prefer it over the version-specific names.

-- ── Diagnostics ────────────────────────────────────────────────────
-- Glyphs come from ajay.icons, which builds them from codepoints rather
-- than embedding the characters. The literals that used to be here were
-- stripped to empty strings somewhere in a copy, and an empty sign text
-- renders NOTHING in the gutter without raising an error -- diagnostics
-- silently stop appearing.
-- Soft dependency on purpose. lsp.lua drives EVERY language server, so a
-- missing ajay/icons.lua must not take all of them down -- it should cost
-- you pretty gutter symbols, nothing more.
-- Resolves the 0.11 / 0.12 API differences once. See lua/ajay/compat.lua.
local compat = require("ajay.compat")

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
  "gopls",
  -- rust_analyzer is NEW on this branch. The full config never had Rust
  -- support at all, so "keep the Rust LSP" meant adding one.
  "rust_analyzer",
  -- lua_ls is not one of the target languages. It is here to keep THIS
  -- config editable: completion on the vim.* API, and the `vim` global
  -- declared so it is not an undefined variable in every file.
  "lua_ls",
}

local ensure_tools = {
  -- prettier went with the web stack: nothing left here is a filetype it
  -- formats.
  "clang-format",
  "black",
  "isort",
  "stylua",
  "google-java-format",
  "shfmt",
  -- goimports first (adds/removes imports, and runs gofmt itself), then
  -- gofumpt (a stricter gofmt superset) -- same import-fixer-then-formatter
  -- shape as isort+black above.
  "goimports",
  "gofumpt",
  -- ruff. Not a replacement for isort+black -- conform.lua picks BETWEEN
  -- them per project: a project whose pyproject.toml declares [tool.ruff]
  -- gets ruff, everything else keeps isort+black. pytorch is the live
  -- example. Without this installed, detection would find the preference
  -- and be unable to honour it.
  "ruff",
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

vim.lsp.config("gopls", {
  settings = {
    gopls = {
      staticcheck = true,
      analyses = {
        unusedparams = true,
        shadow = true,
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

-- ── Neovim 0.11's built-in gr* maps ────────────────────────────────
--
-- 0.11 added a global LSP mapping family in runtime/lua/vim/_defaults.lua:
--
--   grn  rename          gra  code action      grr  references
--   gri  implementation  grt  type definition  grx  run code lens
--
-- Every one of those is ALREADY mapped somewhere in this config, by an
-- older and shorter binding:
--
--   grr -> gr          gri -> gi          grt -> gt
--   grn -> <leader>rn  gra -> <leader>ca  grx -> <leader>cl
--
-- So they add nothing -- and they cost something real. `gr` (go to
-- references) is a complete mapping AND the prefix of all six, which
-- makes it ambiguous: Neovim cannot jump until 'timeoutlen' expires, so
-- every single "find references" sat for 400ms first. On a Java project
-- that is one of the most-pressed keys there is.
--
-- Deleting the redundant defaults restores an instant `gr` and loses no
-- functionality. pcall'd individually because the exact set differs
-- between 0.11 and 0.12, and a missing one must not abort the rest.
--
-- Want them back? Delete this loop -- the built-ins return on restart.
for _, lhs in ipairs({ "grn", "gra", "grr", "gri", "grt", "grx" }) do
  pcall(vim.keymap.del, "n", lhs)
end

-- ── Shared attach behaviour ────────────────────────────────────────
vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("ajay_lsp_attach", { clear = true }),
  callback = function(ev)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if not client then
      return
    end
    local bufnr = ev.buf

    -- ── DEAD KEYMAPS ON BIG FILES ────────────────────────────────
    --
    -- BUG: pressing gd in a large file gave
    --   vim.lsp: method "textDocument/definition" is not supported by
    --   any server activated for this buffer
    --
    -- bigfile.lua detaches the LSP from oversized buffers, but it does so
    -- from its own LspAttach handler via vim.schedule -- i.e. DEFERRED.
    -- This handler runs synchronously in the same event, so the order was:
    --
    --   1. server attaches
    --   2. bigfile schedules a detach
    --   3. this handler maps gd / gr / K / <leader>l*   <- still here
    --   4. the scheduled detach runs, client is gone
    --
    -- leaving every LSP keymap pointing at a client that no longer
    -- exists. Reproduced on pytorch's common_methods_invocations.py
    -- (1.3 MB): bigfile=true, clients=0, and gd/gr/K all still mapped.
    --
    -- Mapping nothing is the right fix rather than unmapping later: with
    -- no buffer-local gd, `gd` falls back to Vim's own "go to local
    -- declaration", which is a sensible thing to have in a huge file and
    -- costs nothing. Same shape as the guard at the top of
    -- start_jdtls() in jdtls.lua.
    --
    -- :BigFile re-attaches and this handler runs again, so the keymaps
    -- come back with the client.
    --
    -- Gated on `bigfile_no_lsp`, NOT `bigfile`. A merely large file keeps
    -- its language server now -- LSP runs out of process and does not block
    -- redraw, so it is the last thing that should go. Only the extreme
    -- tiers (> lsp_max_bytes, or a pathological single-line file) detach,
    -- and only those should skip the keymaps.
    if vim.b[bufnr].bigfile_no_lsp then
      return
    end

    local function map(mode, lhs, rhs, desc)
      vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
    end

    -- Navigation
    map("n", "gd", vim.lsp.buf.definition, "Go to definition")
    map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")

    -- ── FIND USAGES, IntelliJ-style ──────────────────────────────
    --
    -- `vim.lsp.buf.references()` sends results to the QUICKFIX LIST: a
    -- flat file:line list with no preview, so answering "is this the
    -- usage I want?" means jumping to each one and jumping back. That is
    -- the gap against IntelliJ's Find Usages (Alt+F7), which shows the
    -- list and the code side by side.
    --
    -- glance renders a results list next to a live preview -- move down
    -- the list and the preview follows, <CR> jumps, <Esc> leaves without
    -- moving the cursor at all.
    --
    -- gd stays a DIRECT jump on purpose. It is the hot path (IntelliJ's
    -- Ctrl+B) and opening a preview UI to show one destination is
    -- friction; <leader>lp is there when you want to peek instead.
    --
    -- Falls back to the built-in handler if glance is unavailable, so a
    -- failed plugin install degrades to the old behaviour rather than
    -- leaving `gr` dead.
    local function glance(method, fallback)
      return function()
        if not pcall(vim.cmd, "Glance " .. method) then
          fallback()
        end
      end
    end

    map("n", "gr", glance("references", vim.lsp.buf.references), "Find usages (list + preview)")
    map("n", "gi", glance("implementations", vim.lsp.buf.implementation), "Go to implementation (preview)")
    map("n", "gt", vim.lsp.buf.type_definition, "Go to type definition")
    -- Peek the definition without leaving this buffer -- IntelliJ's
    -- Ctrl+Shift+I. Lives under <leader>l with the rest of the LSP group;
    -- `gp` would have been the obvious key and is a built-in paste motion.
    map("n", "<leader>lp", glance("definitions", vim.lsp.buf.definition), "Peek definition")

    -- Docs
    map("n", "K", vim.lsp.buf.hover, "Hover documentation")
    -- COLLISION FIX: this was <C-k>, which keymaps.lua maps globally to
    -- "window up". Buffer-local mappings WIN over global ones, so the
    -- moment any language server attached, Ctrl-k stopped moving between
    -- splits -- in every code buffer, which is most of them. Window
    -- navigation is muscle memory; signature help is not, so signature
    -- help moves.
    --
    -- Nothing is lost: Neovim already binds <C-s> in INSERT mode to
    -- signature help by default on both 0.11 and 0.12, which is where you
    -- actually want it (mid-call, typing arguments). gK is the normal-mode
    -- companion, matching the built-in gr* LSP mappings in style.
    map("n", "gK", vim.lsp.buf.signature_help, "Signature help")

    -- Actions
    map("n", "<leader>rn", vim.lsp.buf.rename, "Rename symbol")
    map({ "n", "v" }, "<leader>ca", vim.lsp.buf.code_action, "Code action")

    -- ── THE TIMEOUTLEN BUG, TWICE ────────────────────────────────
    --
    -- These used to live on <leader>x* (diagnostics) and <leader>w*
    -- (workspace folders). Both prefixes were ALREADY COMPLETE mappings
    -- in keymaps.lua:
    --
    --   <leader>w  ->  :w<CR>    save file
    --   <leader>x  ->  :wq<CR>   save and quit
    --
    -- A mapping that is both complete AND the prefix of a longer one is
    -- ambiguous, so Neovim cannot act on it until 'timeoutlen' expires.
    -- Registering <leader>wa/wr/wl buffer-locally meant that in EVERY
    -- buffer a language server attached to -- i.e. every code file --
    -- pressing <leader>w sat there for 400ms before saving. Same for
    -- <leader>x, which also collides with <leader>xe (emmet).
    --
    -- This is the exact bug keymaps.lua documents fixing for <leader>h,
    -- reintroduced from the other direction: there the prefix was moved,
    -- here the CHILDREN are, because save/save-and-quit are the two most
    -- pressed keys in the config and must stay instant.
    --
    -- Everything language-server-ish now lives under <leader>l, which was
    -- free apart from <leader>lf (format, conform.lua) and is not itself
    -- a mapping -- so nothing here is ambiguous with anything.
    --
    --   <leader>lf   format          (conform.lua)
    --   <leader>ld   show diagnostic
    --   <leader>lq   diagnostic list
    --   <leader>lw{a,r,l}  workspace folder add/remove/list
    map("n", "[d", function()
      vim.diagnostic.jump({ count = -1, float = true })
    end, "Previous diagnostic")
    map("n", "]d", function()
      vim.diagnostic.jump({ count = 1, float = true })
    end, "Next diagnostic")
    map("n", "<leader>ld", vim.diagnostic.open_float, "Show diagnostic")
    map("n", "<leader>lq", vim.diagnostic.setloclist, "Diagnostic list")

    -- Workspace
    map("n", "<leader>lwa", vim.lsp.buf.add_workspace_folder, "Add workspace folder")
    map("n", "<leader>lwr", vim.lsp.buf.remove_workspace_folder, "Remove workspace folder")
    map("n", "<leader>lwl", function()
      print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, "List workspace folders")

    -- Same move for gopls — conform/goimports+gofumpt owns Go formatting,
    -- so gopls's own (plain gofmt-equivalent) formatter should never be
    -- what a stray vim.lsp.buf.format() call reaches for instead.
    if client.name == "gopls" then
      client.server_capabilities.documentFormattingProvider = false
      client.server_capabilities.documentRangeFormattingProvider = false
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
    --   * Neovim 0.12 refreshes code lenses itself (on 0.11 it does
    --     not, which is exactly what compat.codelens back-fills). The codelens provider
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
    -- lifecycle. Skipped on protected buffers (see ajay/bigfile.lua).
    if client:supports_method("textDocument/codeLens") then
      if not vim.g.codelens_off and not vim.b[bufnr].codelens_off then
        -- compat.codelens, not vim.lsp.codelens: on 0.12 this IS
        -- vim.lsp.codelens.enable; on 0.11, where that function does not
        -- exist yet, the shim drives refresh() from autocmds instead.
        compat.codelens.enable(true, { bufnr = bufnr })
      end
      map("n", "<leader>cl", vim.lsp.codelens.run, "Run code lens under cursor")
    end
  end,
})

vim.api.nvim_create_user_command("ToggleCodeLens", function()
  local buf = vim.api.nvim_get_current_buf()
  -- enable/is_enabled, not refresh/clear: same 0.12 API as above,
  -- reached through the shim so this works on 0.11 too.
  local on = compat.codelens.is_enabled({ bufnr = buf })
  vim.g.codelens_off = on
  compat.codelens.enable(not on, { bufnr = buf })
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
  -- Only jdtls still needs an entry. Every other server that shipped a
  -- `cmd` FUNCTION rather than a table (ts_ls, eslint, html, cssls,
  -- tailwindcss, angularls) belonged to the web stack and is gone;
  -- pyright, clangd, gopls, rust_analyzer and lua_ls all ship a plain
  -- `cmd` table that server_bin() reads directly.
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
