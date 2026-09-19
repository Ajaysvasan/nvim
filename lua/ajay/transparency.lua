-- lua/ajay/transparency.lua
--
-- Toggle a transparent background, so the terminal's own background
-- (wallpaper, blur, whatever) shows through Neovim.
--
-- The theme does the work. VS Code Dark+ has a native `transparent`
-- option, so this module flips a flag and asks colorscheme.lua to rebuild
-- the theme with it. That covers every highlight group the theme owns,
-- including ones plugins add later -- unlike hand-clearing `guibg` on a
-- list of groups, which drifts out of date and is undone by the next
-- `:colorscheme`.
--
-- It does NOT change your appearance at load time. Transparency starts
-- off; nothing happens until you press <leader>tt.

local M = {}

local function apply()
  -- Rebuild the theme with the new flag, rather than patching highlights:
  -- themes bake the transparency choice in at setup() time, so the flag
  -- has to be read while the theme is being constructed.
  local ok, cs = pcall(require, "ajay.colorscheme")
  if not ok then
    vim.notify("Failed to load ajay.colorscheme:\n" .. tostring(cs), vim.log.levels.ERROR)
    return false
  end
  return cs.reapply()
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
