-- lua/ajay/colorscheme.lua
--
-- ONE theme: VS Code Dark+ (Mofiqul/vscode.nvim).
--
-- SWITCHING THEMES
--   1. In plugins.lua, replace the vscode.nvim spec with the theme you want
--      (keep `lazy = false, priority = 1000`), then :Lazy sync.
--   2. Below, replace apply_theme's body with that theme's setup() and
--      `vim.cmd.colorscheme(...)`. Pass `transparent` to its transparency
--      option so <leader>tt keeps working.
--   3. Point M.lualine_theme() at the matching lualine theme name, or
--      "auto" if the theme ships none.

local M = {}

--- Build and activate the theme. `transparent` is read fresh each call
--- because most themes bake the choice in at setup() time.
--- @param transparent boolean
local function apply_theme(transparent)
  require("vscode").setup({
    style = "dark",
    transparent = transparent,
    italic_comments = true,
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
