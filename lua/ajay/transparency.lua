-- lua/ajay/transparency.lua
--
-- Toggle a transparent background, so the terminal's own background
-- (wallpaper, blur, whatever) shows through Neovim.
--
-- REWRITTEN. The old version had two problems:
--
--  1. It hand-listed ~20 highlight groups and cleared `guibg` on each
--     (Normal, NormalFloat, NeoTree*, Telescope*, WhichKeyFloat...). That
--     list drifts out of date the moment you add a plugin, and it fights
--     `:colorscheme`, which resets every group.
--  2. Turning transparency OFF restored a hardcoded `guibg=#1e1e1e`, which
--     is not a Catppuccin Frappe colour. Toggling off left you with a
--     background that did not match the theme.
--
-- Catppuccin already implements this properly via `transparent_background`.
-- So this module just flips a global and re-applies the colorscheme, and
-- the theme handles every group it knows about -- including ones added
-- later.
--
-- It does NOT change your appearance at load time. Transparency starts
-- off; nothing happens until you press <leader>tt.

local M = {}

local function apply()
  -- Re-run colorscheme.lua from scratch so catppuccin.setup() sees the new
  -- flag. Clearing the package cache is what makes the re-require actually
  -- execute rather than return the cached module.
  package.loaded["ajay.colorscheme"] = nil
  local ok, err = pcall(require, "ajay.colorscheme")
  if not ok then
    vim.notify("Failed to re-apply colorscheme:\n" .. tostring(err), vim.log.levels.ERROR)
    return false
  end
  return true
end

function M.toggle()
  vim.g.transparent_background = not vim.g.transparent_background
  if not apply() then
    -- Roll back so the flag never disagrees with what is on screen.
    vim.g.transparent_background = not vim.g.transparent_background
    return
  end
  vim.notify(
    "Transparency: " .. (vim.g.transparent_background and "ON" or "OFF"),
    vim.log.levels.INFO,
    { title = "transparency" }
  )
end

function M.setup()
  -- Registration only. No highlight changes, no notification at startup.
  vim.api.nvim_create_user_command("ToggleTransparency", M.toggle, {
    desc = "Toggle transparent background",
  })

  vim.keymap.set("n", "<leader>tt", M.toggle, {
    desc = "Toggle transparency",
    silent = true,
  })
end

return M
