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

-- ══════════════════════════════════════════════════════════════════
-- PROJECT-AWARE FORMATTER DETECTION
-- ══════════════════════════════════════════════════════════════════
--
-- THE BUG THIS FIXES, demonstrated:
--
--   a project's .prettierrc:  { "singleQuote": true, "semi": false }
--   prettier on its own    ->  const greeting = 'hello'
--   this config, before    ->  const greeting = "hello";
--
-- `prepend_args` are passed on the COMMAND LINE, and CLI flags beat a
-- config file for every formatter here. So the personal style defaults
-- below -- --single-quote false, --tab-width 2, --indent-type Spaces --
-- silently overrode whatever the project asked for. On a shared repo that
-- means every save rewrites files to one developer's taste, producing
-- diff noise and failing the project's own lint job.
--
-- Two things are detected, and they are different questions:
--
--   1. WHICH TOOL does this project use?  (ruff vs black, biome vs
--      prettier) -- answered by which config files exist.
--   2. Does the project STATE ITS OWN STYLE?  If yes, pass no style
--      flags at all and let the tool read the project's config.
--
-- Deliberately NOT detected: spotless and checkstyle (kafka uses both).
-- They are Gradle/Maven plugins, not CLIs -- `./gradlew spotlessApply`
-- takes seconds and would make every save unusable. google-java-format
-- is the closest fast equivalent and stays the Java formatter.

--- Nearest file matching any of `names`, searching upward from `dir`.
--- @param dir string
--- @param names string[]
--- @return string|nil
local function find_up(dir, names)
  return vim.fs.find(names, { upward = true, path = dir, type = "file" })[1]
end

-- Contents of config files already read, keyed by path. pyproject.toml is
-- inspected twice (once for ruff, once for black) and pytorch's is large,
-- so without this a cold detection read the same file twice -- and every
-- sibling directory in the project read it again. Cleared alongside
-- detect_cache.
local read_cache = {}

local function read_file(path)
  local hit = read_cache[path]
  if hit ~= nil then
    return hit
  end
  local body = ""
  local fh = io.open(path, "r")
  if fh then
    body = fh:read("*a") or ""
    fh:close()
  end
  read_cache[path] = body
  return body
end

--- Whether a file contains a pattern. Used to read intent out of a
--- shared config file (pyproject.toml, package.json) rather than merely
--- noting that the file exists -- pyproject.toml is present in nearly
--- every Python project and says nothing on its own.
local function file_matches(path, pattern)
  if not path then
    return false
  end
  return read_file(path):find(pattern) ~= nil
end

--- Does the nearest pyproject.toml declare a [tool.<section>] table?
local function pyproject_declares(dir, section)
  return file_matches(find_up(dir, { "pyproject.toml" }), "%[tool%." .. section .. "[%.%]]")
end

local function has_exe(name)
  return vim.fn.executable(name) == 1
end

-- Detection touches the filesystem, and format_on_save runs on EVERY
-- write, so results are cached per directory. Cleared by :FormatDetect!
-- and on DirChanged -- adding a .prettierrc mid-session is rare enough
-- to want an explicit bust rather than a stat on every save.
local detect_cache = {}

--- @param dir string
--- @return table
local function detect(dir)
  local cached = detect_cache[dir]
  if cached then
    return cached
  end

  local d = {}

  -- ── Does the project state its own style? ──
  d.prettier_config = find_up(dir, {
    ".prettierrc",
    ".prettierrc.json",
    ".prettierrc.yml",
    ".prettierrc.yaml",
    ".prettierrc.json5",
    ".prettierrc.js",
    ".prettierrc.cjs",
    ".prettierrc.mjs",
    ".prettierrc.toml",
    "prettier.config.js",
    "prettier.config.cjs",
    "prettier.config.mjs",
    "prettier.config.ts",
  }) ~= nil
  -- A "prettier" key in package.json is equally authoritative.
  if not d.prettier_config then
    d.prettier_config = file_matches(find_up(dir, { "package.json" }), '"prettier"%s*:')
  end

  d.stylua_config = find_up(dir, { "stylua.toml", ".stylua.toml" }) ~= nil
  d.black_config = pyproject_declares(dir, "black")
  d.clang_format_config = find_up(dir, { ".clang-format" }) ~= nil
  d.editorconfig = find_up(dir, { ".editorconfig" }) ~= nil

  -- ── Which tool? ──
  --
  -- Gated on the binary actually existing. Selecting a formatter that is
  -- not installed would make conform report "formatter unavailable" and
  -- silently fall through to the LSP -- worse than just using the
  -- default. `*_wanted` records the project's preference regardless, so
  -- :FormatDetect can tell you what to install.
  d.ruff_wanted = find_up(dir, { "ruff.toml", ".ruff.toml" }) ~= nil or pyproject_declares(dir, "ruff")
  d.python_tool = (d.ruff_wanted and has_exe("ruff")) and "ruff" or "black"

  d.biome_wanted = find_up(dir, { "biome.json", "biome.jsonc" }) ~= nil
  d.web_tool = (d.biome_wanted and has_exe("biome")) and "biome" or "prettier"

  detect_cache[dir] = d
  return d
end

--- Detection for a buffer, by its directory.
--- @param bufnr? integer
--- @return table
local function detect_buf(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(bufnr)
  local dir = name ~= "" and vim.fs.dirname(name) or ((vim.uv or vim.loop).cwd())
  return detect(dir)
end

--- Style flags to use only when the project has NOT stated its own.
--- @param key string field on the detection table
--- @param args string[]
--- @return fun(self: table, ctx: table): string[]
local function style_unless_project_config(key, args)
  return function(_, ctx)
    if detect(ctx.dirname)[key] then
      return {}
    end
    return args
  end
end

M.detect_buf = detect_buf

--- A formatter binary, preferring the project's virtualenv.
--- @param name string
--- @return string|fun(self: table, ctx: table): string
local function venv_bin(name)
  local ok, cutil = pcall(require, "conform.util")
  if not ok then
    return name
  end
  return cutil.find_executable({
    ".venv/bin/" .. name,
    "venv/bin/" .. name,
    "env/bin/" .. name,
  }, name)
end

--- Shared by every filetype biome is able to handle.
local function web_formatters(bufnr)
  if detect_buf(bufnr).web_tool == "biome" then
    return { "biome" }
  end
  return { "prettier" }
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

      -- Python -- ruff when the project asks for it, else isort+black.
      -- pytorch is the live example: its pyproject.toml declares
      -- [tool.ruff] and [tool.ruff.format], so running black there would
      -- be the wrong tool entirely.
      python = function(bufnr)
        if detect_buf(bufnr).python_tool == "ruff" then
          -- Same import-fixer-then-formatter shape as isort+black.
          return { "ruff_organize_imports", "ruff_format" }
        end
        return { "isort", "black" }
      end,

      -- JavaScript/TypeScript -- biome when the project has biome.json,
      -- else prettier.
      --
      -- Only these filetypes are routed through biome detection. biome
      -- does not handle html, scss, yaml or markdown at all, so those
      -- stay on prettier unconditionally below -- handing biome a file it
      -- cannot parse would fail the format rather than fall back.
      javascript = web_formatters,
      javascriptreact = web_formatters,
      typescript = web_formatters,
      typescriptreact = web_formatters,

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
      json = web_formatters,
      jsonc = web_formatters,
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
      -- Every `prepend_args` below is now CONDITIONAL. These are personal
      -- style defaults for a project that has not said what it wants; the
      -- moment a project states its own style, we pass nothing and let the
      -- tool read the project's config. See the detection block above for
      -- why: CLI flags beat config files, so unconditional args silently
      -- overrode .prettierrc / stylua.toml / [tool.black].
      stylua = {
        prepend_args = style_unless_project_config(
          "stylua_config",
          { "--indent-type", "Spaces", "--indent-width", "2" }
        ),
      },
      prettier = {
        -- prettier already resolves node_modules/.bin/prettier itself
        -- (conform.util.from_node_modules), so a project pinning
        -- prettier@2 is formatted by prettier@2, not the global one.
        prepend_args = style_unless_project_config("prettier_config", {
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
        }),
      },

      -- Python tools resolve from the project's virtualenv first.
      --
      -- Unlike prettier, conform ships these with a bare `command =
      -- "black"`, so a project pinning black 23 in .venv was formatted by
      -- whatever Mason installed globally -- and black's output changes
      -- between majors (string normalisation, the magic trailing comma).
      -- Falls back to the global binary when there is no venv.
      black = {
        command = venv_bin("black"),
        prepend_args = style_unless_project_config("black_config", { "--line-length", "88" }),
      },
      isort = { command = venv_bin("isort") },
      ruff_format = { command = venv_bin("ruff") },
      ruff_organize_imports = { command = venv_bin("ruff") },

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
      --
      -- These two stay UNCONDITIONAL, unlike the style args above. They
      -- are not a style preference -- they stop google-java-format from
      -- fighting jdtls over imports, which it would do in every project
      -- regardless of what that project's config says.
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

    local names = {}
    for _, f in ipairs(require("conform").list_formatters(0)) do
      names[#names + 1] = f.name .. (f.available and "" or " (UNAVAILABLE)")
    end

    local status = string.format(
      "Format on save:\n  Global : %s  (saved on disk: %s)\n  Buffer : %s  (this session only)\n\n  On save here: %s\n  Using       : %s",
      global and "ENABLED ✓" or "DISABLED ✗",
      read_state() and "enabled" or "disabled",
      buffer and "ENABLED ✓" or "DISABLED ✗",
      eff and "WILL FORMAT" or ("WILL NOT FORMAT — " .. why),
      #names > 0 and table.concat(names, ", ") or "(none - LSP fallback).  :FormatDetect for detail"
    )
    vim.notify(status, eff and vim.log.levels.INFO or vim.log.levels.WARN)
  end, { desc = "Show format on save status" })

  -- Show what was detected for this buffer, and why.
  --
  -- Needed because the whole point of detection is that it is INVISIBLE
  -- when it works -- without this there is no way to answer "why did that
  -- save use black instead of ruff?" short of reading the source.
  vim.api.nvim_create_user_command("FormatDetect", function(a)
    if a.bang then
      detect_cache, read_cache = {}, {}
    end
    local d = detect_buf(0)
    local names = {}
    for _, f in ipairs(require("conform").list_formatters(0)) do
      names[#names + 1] = f.name .. (f.available and "" or " (UNAVAILABLE)")
    end

    local lines = {
      "Formatters for this buffer:",
      "  " .. (#names > 0 and table.concat(names, ", ") or "(none - falls back to the LSP)"),
      "",
      "Detected in this project:",
      ("  python tool : %s%s"):format(d.python_tool, d.ruff_wanted and "   [project asks for ruff]" or ""),
      ("  web tool    : %s%s"):format(d.web_tool, d.biome_wanted and "   [project asks for biome]" or ""),
      "",
      "Project states its own style (we pass no style flags):",
      ("  prettier    : %s"):format(d.prettier_config and "yes" or "no"),
      ("  stylua      : %s"):format(d.stylua_config and "yes" or "no"),
      ("  black       : %s"):format(d.black_config and "yes" or "no"),
      ("  clang-format: %s"):format(d.clang_format_config and "yes" or "no"),
      ("  .editorconfig: %s"):format(d.editorconfig and "yes" or "no"),
    }

    -- The case worth shouting about: the project wants a tool that is not
    -- installed, so we quietly used the fallback instead.
    local level = vim.log.levels.INFO
    if d.ruff_wanted and d.python_tool ~= "ruff" then
      lines[#lines + 1] = ""
      lines[#lines + 1] = "! This project wants ruff, but ruff is not installed."
      lines[#lines + 1] = "  Using isort+black instead.  Fix: :MasonInstall ruff"
      level = vim.log.levels.WARN
    end
    if d.biome_wanted and d.web_tool ~= "biome" then
      lines[#lines + 1] = ""
      lines[#lines + 1] = "! This project wants biome, but biome is not installed."
      lines[#lines + 1] = "  Using prettier instead.  Fix: :MasonInstall biome"
      level = vim.log.levels.WARN
    end
    lines[#lines + 1] = ""
    lines[#lines + 1] = "(:FormatDetect! re-scans, after adding a config file)"

    vim.notify(table.concat(lines, "\n"), level, { title = "conform" })
  end, { bang = true, desc = "Show which formatters this project resolves to, and why" })

  -- A new directory is a new project: re-detect rather than serve a
  -- cached answer from the previous one.
  vim.api.nvim_create_autocmd("DirChanged", {
    group = vim.api.nvim_create_augroup("ajay_conform_detect", { clear = true }),
    callback = function()
      detect_cache, read_cache = {}, {}
    end,
  })

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
