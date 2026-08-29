-- lua/ajay/treesitter.lua
--
-- REWRITTEN FOR THE `main` BRANCH OF nvim-treesitter.
--
-- I pinned you to `branch = "master"` earlier with the comment "main is
-- the rewrite, incompatible API". That was right for Neovim 0.10/0.11
-- and wrong for 0.12.
--
-- On 0.12, master's lua/nvim-treesitter/query_predicates.lua calls
-- get_node_text() on a value that is no longer a node, and the markdown
-- query's (#set! conceal_lines "") directive on fenced_code_block
-- delimiters trips it on every render. That is the
--   "attempt to call method 'range' (a nil value)"
-- error you hit opening README.md -- a file full of ``` blocks.
--
-- It is a known upstream break (nvim-treesitter #8618, #8636; neovim
-- #39032) with no fix on master, because master is frozen. `main` is the
-- supported branch for 0.11+.
--
-- WHAT CHANGED IN THE API
--   * No more require("nvim-treesitter.configs").setup{...}.
--   * Parsers: require("nvim-treesitter").install{...}
--   * Highlighting is no longer automatic -- you call
--     vim.treesitter.start() per buffer.
--   * Indent is opt-in per buffer via indentexpr.
--   * Incremental selection was REMOVED. gnn/grn/grc/grm are gone; there
--     is no built-in replacement in 0.12. Flagged rather than silently
--     dropped.

local ensure_installed = {
  "c",
  "cpp",
  "python",
  "java",
  "javascript",
  "typescript",
  "tsx",
  "html",
  "css",
  "scss", -- conform formats it and cssls attaches to it; without the
  -- parser scss was the one web filetype falling back to regex syntax
  "angular", -- .component.html resolves to filetype `htmlangular`, which
  -- maps to the `angular` language, NOT `html`
  "json",
  "lua",
  "luadoc",
  "bash",
  "markdown",
  "markdown_inline",
  "vim",
  "vimdoc",
  "regex",
  "query",
  "xml", -- pom.xml
  "yaml", -- application.yml
  "properties", -- application.properties
}

-- Required for its side effect as much as anything: on 0.11 it back-fills
-- `vim.list`, which nvim-treesitter's install path calls and which does not
-- exist before 0.12. Without it, install() throws and NOTHING gets a parser.
require("ajay.compat")

local ok, ts = pcall(require, "nvim-treesitter")
if not ok then
  vim.notify("nvim-treesitter not available", vim.log.levels.WARN)
  return
end

-- Pin the parser directory explicitly so it is a known path you can wipe.
-- Stale parsers are the usual cause of "attempt to call method 'range'":
-- a parser built against an older grammar lacks nodes the newer query
-- expects, the capture resolves to nil, and a directive then calls a
-- method on it. Switching plugin branches does NOT rebuild parsers.
local install_dir = vim.fn.stdpath("data") .. "/site"
pcall(function()
  ts.setup({ install_dir = install_dir })
end)

-- Scheduled, and heavily guarded. Two separate problems this solves:
--
--  1. The `main` branch shells out to the `tree-sitter` CLI to compile
--     every parser -- a C compiler is NOT enough, unlike on `master`.
--     Without that binary, install() still DOWNLOADS all 22 grammars and
--     only then fails at the compile step, on EVERY startup: a pile of
--     network jobs and a wall of errors for work that cannot succeed.
--     Check for it, say something useful once, and do nothing.
--
--  2. Even with the CLI present, install() on the full list is not free,
--     and this runs at every launch. Only ask for what is missing.
--
-- Scheduled so neither the check nor any download happens before the
-- editor is interactive. Highlighting is driven by the FileType autocmd
-- below, which already pcalls around a parser that is still installing.
vim.schedule(function()
  if vim.fn.executable("tree-sitter") ~= 1 then
    vim.notify(
      "tree-sitter CLI not found - no parsers can be built, so there is no\n"
        .. "treesitter highlighting at all.\n\n"
        .. "  brew install tree-sitter        (macOS)\n"
        .. "  npm install -g tree-sitter-cli  (anywhere with npm)\n\n"
        .. "Then restart and run :TSReset.",
      vim.log.levels.WARN,
      { title = "treesitter" }
    )
    return
  end

  -- ── THE "NO HIGHLIGHTING AT ALL" BUG ─────────────────────────────
  --
  -- A language needs TWO things installed, in two different directories:
  --
  --   install_dir/parser/<lang>.so     the compiled grammar
  --   install_dir/queries/<lang>/      the highlight/indent/fold queries
  --
  -- On the `main` branch the plugin ships NO queries of its own (`ls
  -- queries/` in the repo is empty) -- install() fetches both halves.
  --
  -- `ts.get_installed()` with NO ARGUMENT merges those two lists. That is
  -- what this used to call, and it is why every language silently lost
  -- highlighting: a half-finished install left `queries/ecma`,
  -- `queries/jsx` and `queries/html_tags` on disk with an EMPTY parser
  -- directory, the merged list reported those as "installed", and any
  -- language already counted present was never re-attempted.
  --
  -- The failure is invisible rather than loud, because a stale
  -- master-era .so left behind in the PLUGIN's own directory is still on
  -- runtimepath. vim.treesitter.start() finds it, attaches a highlighter,
  -- and succeeds -- against zero queries. Parsed buffer, no captures, no
  -- colour, no error.
  --
  -- So: check the two halves SEPARATELY and require both.
  local function list(kind)
    local ok_l, l = pcall(ts.get_installed, kind)
    local set = {}
    if ok_l then
      for _, lang in ipairs(l) do
        set[lang] = true
      end
    end
    return set
  end

  local have_parser, have_queries = list("parsers"), list("queries")

  local missing = {}
  for _, lang in ipairs(ensure_installed) do
    if not (have_parser[lang] and have_queries[lang]) then
      table.insert(missing, lang)
    end
  end

  if #missing == 0 then
    return
  end

  -- `summary = true` is what :TSInstall passes. Without it this is a
  -- multi-minute background job with NO output whatsoever -- which is the
  -- other half of why the breakage was so hard to place: quit before it
  -- finishes and nothing lands, with nothing on screen to say so.
  vim.notify(
    ("Installing %d treesitter parser%s: %s\n\nHighlighting for these is off until it finishes."):format(
      #missing,
      #missing == 1 and "" or "s",
      table.concat(missing, ", ")
    ),
    vim.log.levels.INFO,
    { title = "treesitter" }
  )

  local ok_task, task = pcall(ts.install, missing, { summary = true })
  if not ok_task then
    vim.notify(
      "treesitter install failed to start:\n" .. tostring(task),
      vim.log.levels.ERROR,
      { title = "treesitter" }
    )
    return
  end

  -- Say so when it lands, and re-highlight what is already open -- the
  -- FileType autocmd below has long since fired for those buffers.
  if type(task) == "table" and type(task.await) == "function" then
    task:await(function(err)
      vim.schedule(function()
        if err then
          vim.notify("treesitter install failed:\n" .. tostring(err), vim.log.levels.ERROR, { title = "treesitter" })
          return
        end
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if vim.api.nvim_buf_is_loaded(buf) and not vim.b[buf].bigfile then
            local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype or "")
            if lang then
              pcall(vim.treesitter.start, buf, lang)
            end
          end
        end
        vim.notify("Treesitter parsers installed. Highlighting is live.", vim.log.levels.INFO, { title = "treesitter" })
      end)
    end)
  end
end)

-- Escape hatch. Set in options.lua to skip treesitter for a language and
-- fall back to Vim's regex syntax, e.g.:
--   vim.g.ts_disabled_langs = { markdown = true, markdown_inline = true }
-- Useful when an upstream parser/query combination is broken; markdown
-- with fenced code blocks has been the recurring one on Neovim 0.12.
local disabled = vim.g.ts_disabled_langs or {}

local group = vim.api.nvim_create_augroup("ajay_treesitter", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  callback = function(args)
    local buf = args.buf
    local ft = vim.bo[buf].filetype
    if ft == "" then
      return
    end

    -- ajay.bigfile sets this on files large enough that a full parse
    -- would freeze the editor.
    if vim.b[buf].bigfile then
      return
    end

    local lang = vim.treesitter.language.get_lang(ft)
    if not lang or disabled[lang] then
      return
    end

    -- vim.treesitter.start() throws when the parser isn't installed yet,
    -- which is normal on first launch while install() is still running.
    -- pcall keeps that from spamming an error on every buffer.
    if not pcall(vim.treesitter.start, buf, lang) then
      return
    end

    -- Treesitter indent, but only where nothing better is already set.
    -- Java is deliberately excluded: jdtls provides its own indentation
    -- and the two disagree about continuation lines and annotations.
    if ft ~= "java" and vim.bo[buf].indentexpr == "" then
      vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
})

-- ── Textobjects ───────────────────────────────────────────────────
-- Also a different API on main: no keymaps table, you bind the
-- selection function yourself.
local tok, textobjects = pcall(require, "nvim-treesitter-textobjects")
if tok then
  textobjects.setup({
    select = { lookahead = true },
  })

  local select = require("nvim-treesitter-textobjects.select")
  local maps = {
    { "af", "@function.outer" },
    { "if", "@function.inner" },
    { "ac", "@class.outer" },
    { "ic", "@class.inner" },
    { "aa", "@parameter.outer" },
    { "ia", "@parameter.inner" },
  }
  for _, m in ipairs(maps) do
    vim.keymap.set({ "x", "o" }, m[1], function()
      select.select_textobject(m[2], "textobjects")
    end, { desc = "Select " .. m[2] })
  end
end

-- Wipe every installed parser and reinstall from scratch. Faster than
-- remembering the path, and the path is set above so this always matches.
vim.api.nvim_create_user_command("TSReset", function()
  local dir = install_dir .. "/parser"
  vim.fn.delete(dir, "rf")
  vim.notify(
    "Deleted "
      .. dir
      .. "\n\nRestart Neovim, then parsers rebuild automatically.\n"
      .. "Also check for strays:  find ~/.local/share/nvim -name '*.so' -path '*parser*'",
    vim.log.levels.INFO,
    { title = "treesitter" }
  )
end, { desc = "Delete all treesitter parsers and reinstall" })

vim.api.nvim_create_user_command("TSStatus", function()
  local buf = vim.api.nvim_get_current_buf()
  local ft = vim.bo[buf].filetype
  local lang = vim.treesitter.language.get_lang(ft)
  local active = vim.treesitter.highlighter.active[buf] ~= nil
  local parsers = {}
  if lang then
    for _, path in ipairs(vim.api.nvim_get_runtime_file("parser/" .. lang .. ".so", true)) do
      table.insert(parsers, ("  %s  (%s)"):format(path, os.date("%Y-%m-%d", vim.fn.getftime(path))))
    end
  end
  vim.notify(
    ("filetype : %s\nlanguage : %s\nhighlight: %s\ndisabled : %s\n\nparser files found (more than one = conflict):\n%s"):format(
      ft,
      lang or "(none)",
      active and "ON" or "OFF",
      lang and tostring(disabled[lang] == true) or "-",
      #parsers > 0 and table.concat(parsers, "\n") or "  (none)"
    ),
    vim.log.levels.INFO,
    { title = "treesitter" }
  )
end, { desc = "Show treesitter status for this buffer" })
