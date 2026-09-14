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
-- Themes that implement transparency natively (VS Code Dark+, Catppuccin)
-- are simply told about it and handle every group they own, including ones
-- added later. For a theme with no such option (Darcula), colorscheme.lua
-- falls back to a COMPUTED sweep -- clearing the background of every group
-- whose background currently matches Normal's -- rather than the
-- hand-written group list described above.
--
-- It does NOT change your appearance at load time. Transparency starts
-- off; nothing happens until you press <leader>tt.

local M = {}

local function apply()
  -- Ask the theme registry to rebuild the ACTIVE theme with the new flag.
  --
  -- This used to wipe package.loaded["ajay.colorscheme"] and re-require it,
  -- which worked only because that module was a side-effect script that ran
  -- catppuccin.setup() at require time. It is a registry now
  -- (docs/colorscheme.md), so re-requiring would just hand back the cached
  -- table and change nothing on screen.
  --
  -- Rebuilding rather than patching highlights is still the right move:
  -- most themes bake the transparency choice in at setup() time, so the
  -- flag has to be read while the theme is being constructed.
  local ok, cs = pcall(require, "ajay.colorscheme")
  if not ok then
    vim.notify("Failed to load the theme registry:\n" .. tostring(cs), vim.log.levels.ERROR)
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
