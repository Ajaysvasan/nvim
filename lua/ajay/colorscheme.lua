-- lua/ajay/colorscheme.lua
--
-- ONE theme: VS Code Dark+ (Mofiqul/vscode.nvim).
--
-- This was a registry with a switcher (:Theme, :ThemeNext, <leader>tc /
-- <leader>tn, and the choice persisted to stdpath("data")/colorscheme_state).
-- That is gone: three themes were installed and eagerly loaded to support
-- switching that never happened in practice.
--
-- SWITCHING THEMES
--   1. In plugins.lua, uncomment the theme's entry in the colorscheme spec's
--      `dependencies` (and comment out vscode.nvim if you want it gone), then
--      :Lazy sync.
--   2. Below, comment out apply_theme's body and uncomment the block for the
--      theme you want.
--   3. Point M.lualine_theme() at the matching lualine theme name.
--
-- Both halves are needed: step 1 puts the plugin on the runtimepath, step 2
-- calls into it.

local M = {}

-- ── TRANSPARENCY ──────────────────────────────────────────────────
--
-- vscode.nvim implements transparency itself, so apply_theme() just passes
-- the flag down. strip_backgrounds() is the FALLBACK for a theme that does
-- not (darcula is one) -- kept because switching to such a theme otherwise
-- silently breaks <leader>tt.
--
-- Note what it is *not*: not the hand-written list of ~20 highlight groups
-- this config deleted once already, which drifted out of date the moment a
-- plugin was added. It COMPUTES the set instead -- every group whose
-- background currently equals Normal's background is, by definition, a group
-- painting the editor background, so clearing it is correct no matter which
-- plugin defined it.
local function strip_backgrounds()
  local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
  local bg = normal and normal.bg
  if not bg then
    return
  end
  for name, hl in pairs(vim.api.nvim_get_hl(0, {})) do
    -- Linked groups inherit from their target; re-setting them here would
    -- break the link and freeze them at today's colours.
    if hl.link == nil and hl.bg == bg then
      hl.bg = nil
      pcall(vim.api.nvim_set_hl, 0, name, hl)
    end
  end
  normal.bg = nil
  pcall(vim.api.nvim_set_hl, 0, "Normal", normal)
end

--- Build and activate the theme. `transparent` is read fresh each call
--- because most themes bake the choice in at setup() time.
--- @param transparent boolean
local function apply_theme(transparent)
  require("vscode").setup({
    style = "dark",
    transparent = transparent,
    italic_comments = true,
    disable_nvimtree_bg = true,
    -- BUG FIX (vscode.nvim's, worked around here). Its config.setup() does
    --
    --   if config.opts.transparent then
    --     config.opts.color_overrides.vscBack = 'NONE'
    --   end
    --
    -- and never clears vscBack when transparent goes back to false. Worse,
    -- it builds config.opts with a SHALLOW vim.tbl_extend, so when we pass
    -- no color_overrides that table IS the plugin's own `defaults` table --
    -- the write poisons defaults for the rest of the session, and every
    -- later setup() call inherits vscBack = 'NONE'.
    --
    -- Symptom: <leader>tt turned transparency ON fine and could never turn
    -- it back OFF. The background stayed cleared until you restarted.
    --
    -- Passing a FRESH table each call keeps the plugin's mutation scoped to
    -- this call and leaves `defaults` alone.
    color_overrides = {},
  })
  vim.cmd.colorscheme("vscode")

  -- ── IntelliJ Darcula ──────────────────────────────────────────────
  -- Plugin: { "xiantang/darcula-dark.nvim", lazy = false }
  -- lualine theme: "auto" (ships none of its own; "auto" derives one from
  -- the active highlight groups, which tracks it correctly).
  -- NOTE: no native transparency -- uncomment the strip_backgrounds() call
  -- at the bottom of this function too.
  --
  -- require("darcula").setup({
  --   opt = {
  --     integrations = {
  --       telescope = true,
  --       lualine = true,
  --       nvim_cmp = true,
  --       dap_nvim = true,
  --       lsp_semantics_token = true,
  --     },
  --   },
  -- })
  -- vim.cmd.colorscheme("darcula-dark")

  -- ── Catppuccin Frappe ─────────────────────────────────────────────
  -- Plugin: { "catppuccin/nvim", name = "catppuccin", lazy = false }
  -- lualine theme: "catppuccin-frappe"
  -- Has native transparency.
  --
  -- PERF NOTE if you re-enable it: leave auto_integrations = false. It
  -- scans every installed plugin to guess which integrations to enable --
  -- ~2.9 ms of eager startup to find exactly one thing the explicit list
  -- did not already cover. TRADE-OFF: a newly installed plugin is not
  -- themed automatically; add it to the list by hand.
  --
  -- require("catppuccin").setup({
  --   flavour = "frappe",
  --   background = { light = "latte", dark = "mocha" },
  --   transparent_background = transparent,
  --   float = { transparent = transparent, solid = false },
  --   term_colors = true,
  --   styles = { comments = { "italic" }, conditionals = { "italic" } },
  --   auto_integrations = false,
  --   integrations = {
  --     rainbow_delimiters = true,
  --     cmp = true,
  --     gitsigns = true,
  --     telescope = { enabled = true },
  --     treesitter = true,
  --     harpoon = true,
  --     dap = true,
  --     dap_ui = true,
  --     indent_blankline = { enabled = true },
  --     mason = true,
  --     native_lsp = { enabled = true },
  --     which_key = true,
  --     notify = false,
  --     mini = { enabled = true, indentscope_color = "" },
  --   },
  -- })
  -- vim.cmd.colorscheme("catppuccin-frappe")

  -- Only for a theme WITHOUT native transparency (e.g. darcula):
  -- if transparent then strip_backgrounds() end
end

--- The lualine theme for the active colorscheme. Read by plugins.lua for the
--- first draw, before this module's setup() has necessarily run -- so it must
--- not depend on any state set up here.
--- @return string
function M.lualine_theme()
  return "vscode"
end

-- lualine caches its options, so rebuilding the theme has to re-run setup.
-- The options here must mirror the lualine spec in plugins.lua -- passing
-- only `theme` would reset icons_enabled and globalstatus to lualine's
-- defaults.
--
-- Only if lualine is ALREADY loaded. BUG this fixes: lualine's spec is
-- `event = "VeryLazy"`, and calling require("lualine") here forces lazy.nvim
-- to load it there and then -- ~3.1 ms of eager startup for a statusline
-- explicitly allowed to appear a frame late. Skipping is safe because the
-- lualine spec already asks this module for the right theme, so it comes up
-- correct on VeryLazy. This refresh only matters after a transparency
-- toggle, which by definition happens once lualine is up.
local function refresh_lualine()
  if not package.loaded["lualine"] then
    return
  end
  local ok, lualine = pcall(require, "lualine")
  if not ok then
    return
  end
  pcall(lualine.setup, {
    options = {
      icons_enabled = vim.g.have_nerd_font ~= false,
      theme = M.lualine_theme(),
      globalstatus = true,
    },
  })
end

--- Re-apply the theme. Used by transparency.lua after it flips
--- vim.g.transparent_background -- the theme has to be rebuilt for the new
--- value, since it bakes transparency in at setup() time.
--- @return boolean ok
function M.reapply()
  local ok, err = pcall(apply_theme, vim.g.transparent_background == true)
  if not ok then
    vim.notify("Failed to apply colorscheme:\n" .. tostring(err), vim.log.levels.ERROR)
    return false
  end
  refresh_lualine()
  return true
end

function M.setup()
  M.reapply()
end

return M
