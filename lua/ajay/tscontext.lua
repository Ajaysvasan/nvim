-- lua/ajay/tscontext.lua
--
-- "Where am I?" -- the enclosing class and method, shown two ways.
--
-- 1. WINBAR BREADCRUMB (default, always on)
--    A single dimmed line above the buffer:  KafkaProducer > doSend
--    The winbar is its OWN row, so it hides nothing.
--
-- 2. STICKY CONTEXT (opt-in, <leader>tC)
--    Pins the full signature lines to the top of the window, IntelliJ
--    style, with each line's number.
--
-- Sticky context is OFF by default, and that is the whole point of this
-- split. treesitter-context renders as a FLOAT over the buffer, so the
-- lines it shows necessarily cover the top lines of real code -- measured
-- on KafkaProducer.java, three lines (`this.sender.wakeup();`, `}`,
-- `return result.future;`) were simply not visible while it was on. That
-- is inherent to the design, not a setting, which is why the everyday
-- answer is the winbar and the overlay is something you reach for
-- deliberately when you want the exact signature.

local M = {}

-- ── HIGHLIGHT ─────────────────────────────────────────────────────
--
-- Re-applied on ColorScheme for the same reason dashboard.lua does it:
-- `:colorscheme` runs `:highlight clear`, so anything set once at startup
-- is wiped the moment you switch themes with <leader>tc.
--
-- Derived from the active theme rather than hardcoded, since this config
-- ships three (see colorscheme.md). The context needs to read as "pinned
-- chrome, not code" without being so dim it is unreadable -- CursorLine's
-- background is exactly that contrast, by construction.
local function apply_highlights()
  local function bg_of(group, fallback)
    local hl = vim.api.nvim_get_hl(0, { name = group, link = false })
    return hl and hl.bg or fallback
  end

  local context_bg = bg_of("CursorLine", nil)
  local dim = (vim.api.nvim_get_hl(0, { name = "Comment", link = false }) or {}).fg

  vim.api.nvim_set_hl(0, "TreesitterContext", { bg = context_bg })
  -- Line numbers in the context, dimmed like ordinary LineNr.
  vim.api.nvim_set_hl(0, "TreesitterContextLineNumber", {
    bg = context_bg,
    fg = (vim.api.nvim_get_hl(0, { name = "LineNr", link = false }) or {}).fg,
  })

  -- A thin underline on the LAST context line instead of a full-width
  -- separator row.
  --
  -- The separator was the single most distracting part of the original
  -- setup: a solid ─ rule spanning the window, redrawn every time the
  -- context changed, and costing a whole screen line on top of the pinned
  -- ones. An underline marks the same boundary using no extra row and far
  -- less ink.
  vim.api.nvim_set_hl(0, "TreesitterContextBottom", { underline = true, sp = dim })
  vim.api.nvim_set_hl(0, "TreesitterContextSeparator", { fg = dim })

  -- Winbar: deliberately quiet. The breadcrumb is orientation, not
  -- content -- it should be legible when looked at and invisible when
  -- not. Comment colour is exactly that register, and it tracks whatever
  -- theme is active.
  vim.api.nvim_set_hl(0, "NavicText", { fg = dim })
  vim.api.nvim_set_hl(0, "NavicSeparator", { fg = dim })
  vim.api.nvim_set_hl(0, "WinBar", { fg = dim, bold = false })
  vim.api.nvim_set_hl(0, "WinBarNC", { fg = dim, bold = false })
end

function M.setup()
  local ok, tsc = pcall(require, "treesitter-context")
  if not ok then
    vim.notify("nvim-treesitter-context not available", vim.log.levels.WARN)
    return
  end

  tsc.setup({
    -- OFF by default -- see the note at the top of this file. <leader>tC
    -- turns it on when you want the signature pinned.
    enable = false,

    -- Two is what was actually asked for -- the class and the method --
    -- and a third covers an inner class or a nested function. Beyond that
    -- the header starts competing with the code for attention.
    --
    -- This matters much less now than it did: the context QUERIES are
    -- overridden in queries/<lang>/context.scm to match declarations
    -- only, so if/for/try/switch no longer produce context lines at all.
    -- Before that, a nested loop could stack four levels on its own and
    -- the header churned on every cursor move across a brace -- which is
    -- what made it distracting.
    max_lines = 3,

    -- Which lines to drop when max_lines is exceeded. The DEFAULT is
    -- "outer", which discards the outermost -- i.e. the class, the one
    -- thing most worth keeping. "inner" keeps class and method and drops
    -- the innermost control-flow lines instead, which is the right
    -- trade: you can see the `for` you are inside of, you cannot see the
    -- class name 900 lines above.
    trim_scope = "inner",

    -- Context of the CURSOR line, not of the top visible line -- "what am
    -- I inside of right now" is the question being answered.
    mode = "cursor",

    -- A Java signature often wraps across lines:
    --   public Future<RecordMetadata> send(ProducerRecord<K, V> record,
    --                                      Callback callback) {
    -- Show enough to read the parameters, not the 20 lines the default
    -- would allow. Kept low deliberately: a signature that wraps over
    -- four lines would otherwise fill the header on its own.
    multiline_threshold = 3,

    -- Each context line keeps its own line number, so the header tells
    -- you WHERE the enclosing scope starts, not just what it is.
    line_numbers = true,

    -- In a short split, four pinned lines is most of the window. Below
    -- this height the context is simply not drawn.
    min_window_height = 16,

    -- No separator ROW. TreesitterContextBottom (above) underlines the
    -- last context line instead, which marks the same boundary without
    -- spending a screen line or drawing a full-width rule.
    separator = nil,
    zindex = 20,

    -- INVARIANT (docs/api.md #1): honour vim.b.bigfile.
    --
    -- This runs a treesitter query on every cursor move. bigfile.lua
    -- stops treesitter on oversized buffers precisely to avoid per-move
    -- work like this, so returning false here keeps that promise instead
    -- of quietly reintroducing the cost the gate exists to prevent.
    on_attach = function(buf)
      return not vim.b[buf].bigfile
    end,
  })

  -- ── WINBAR BREADCRUMB ───────────────────────────────────────────
  local ok_navic, navic = pcall(require, "nvim-navic")
  if ok_navic then
    navic.setup({
      highlight = true,
      separator = "  ",
      depth_limit = 4,
      -- Past four levels the breadcrumb is longer than the code it
      -- describes; the innermost scopes are the ones worth keeping.
      depth_limit_indicator = "…",
      lsp = { auto_attach = false }, -- lsp.lua attaches it explicitly
    })
  end

  apply_highlights()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("ajay_tscontext", { clear = true }),
    callback = apply_highlights,
  })

  -- The plugin ships a Lua API only -- enable/disable/toggle/enabled/
  -- go_to_context -- and defines NO user commands of its own. The
  -- :TSContext* names are ours, defined here over that API, which is why
  -- they appear in this plugin's `cmd` list in plugins.lua.
  local function toggle()
    tsc.toggle()
    -- Toggling is silent in the plugin, which is confusing when the
    -- context happened to be empty at the moment you pressed the key --
    -- nothing visibly changes either way.
    vim.notify("Sticky context: " .. (tsc.enabled() and "ON" or "OFF"), vim.log.levels.INFO, { title = "context" })
  end

  vim.api.nvim_create_user_command("TSContextToggle", toggle, { desc = "Toggle sticky context" })
  vim.api.nvim_create_user_command("TSContextEnable", function()
    tsc.enable()
  end, { desc = "Enable sticky context" })
  vim.api.nvim_create_user_command("TSContextDisable", function()
    tsc.disable()
  end, { desc = "Disable sticky context" })

  vim.keymap.set("n", "<leader>tC", toggle, { desc = "Toggle sticky context", silent = true })

  -- Global winbar. The `%{% ... %}` form (note the second %) re-evaluates
  -- the result as statusline format, which is required because navic's
  -- output embeds %#Highlight# groups -- the single-brace form would print
  -- them literally.
  --
  -- Set globally rather than per-window so new splits get it without an
  -- autocmd; M.winbar() returns "" for every buffer where it would be
  -- noise.
  if ok_navic then
    vim.o.winbar = "%{%v:lua.require'ajay.tscontext'.winbar()%}"
  end

  -- Not bound by default, but worth knowing: jumps to the enclosing
  -- context line, i.e. from deep in a method body up to its signature.
  --   :lua require("treesitter-context").go_to_context(1)
  -- Left unbound because every natural key ([c, [[, etc.) is already
  -- taken here -- [c is a gitsigns hunk.
end

--- Winbar content for the current window.
---
--- Returns "" for anything that is not an ordinary file buffer. A global
--- winbar would otherwise draw on neo-tree, the dashboard, terminals and
--- the glance preview, where a breadcrumb is meaningless and costs a row.
--- @return string
function M.winbar()
  local buf = vim.api.nvim_get_current_buf()

  if vim.bo[buf].buftype ~= "" then
    return ""
  end
  local skip = {
    ["neo-tree"] = true,
    ["alpha"] = true,
    ["undotree"] = true,
    ["diff"] = true,
    ["Glance"] = true,
    ["glancelist"] = true,
    ["log"] = true,
  }
  if skip[vim.bo[buf].filetype] then
    return ""
  end
  -- Same big-file promise as everything else in this config: no per-redraw
  -- work on a buffer the gate has flagged.
  if vim.b[buf].bigfile then
    return ""
  end

  local ok, navic = pcall(require, "nvim-navic")
  if not ok or not navic.is_available(buf) then
    return ""
  end
  local loc = navic.get_location({}, buf)
  if loc == nil or loc == "" then
    return ""
  end
  -- Leading space so the breadcrumb does not sit flush against the gutter.
  return " " .. loc
end

return M
