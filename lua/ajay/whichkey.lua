-- which-key.nvim -- shows the available continuations after a prefix key.
--
-- This config has a deep <leader> tree (see docs/keymap-reference.md) and
-- which-key is the in-editor version of that page: press <Space> and wait,
-- and the groups below label what each branch is for.
--
-- WHY THE GROUP LABELS ARE HAND-WRITTEN
--
-- which-key reads the `desc` of every mapping automatically, so individual
-- keys need nothing here. What it CANNOT infer is what a *prefix* means:
-- `<leader>h` is not a mapping, it is a container for two unrelated things
-- (git hunks and harpoon), and without a label it shows up as a bare "+8
-- keys". The `spec` below only names containers.
--
-- WHY delay IS NOT timeoutlen
--
-- `timeoutlen` (400ms here) decides how long Neovim waits before giving up
-- on a longer mapping -- it changes which mapping FIRES. which-key's
-- `delay` only decides when the popup is DRAWN. They are independent, and
-- setting delay below timeoutlen is what makes the popup useful: it appears
-- while you can still act on it, and dismisses the moment you finish the
-- chord. Nothing here changes which keys resolve or how fast.

local M = {}

function M.setup()
  local ok, wk = pcall(require, "which-key")
  if not ok then
    vim.notify("which-key not installed. Run :Lazy sync", vim.log.levels.WARN)
    return
  end

  wk.setup({
    preset = "helix",
    -- Comfortably under timeoutlen (400) so the popup is a hint you can
    -- still act on rather than a report of what you just missed.
    delay = 300,
    -- The `keys` table here is which-key's own icon/label config, not
    -- mappings. Disabling the icon set keeps the popup readable on a
    -- terminal without a Nerd Font, matching vim.g.have_nerd_font.
    icons = {
      mappings = vim.g.have_nerd_font ~= false,
      rules = false,
    },
    spec = {
      { "<leader>a", desc = "Harpoon: add file" },
      { "<leader>c", group = "CMake / code" },
      { "<leader>d", group = "Debug (DAP)" },
      { "<leader>f", group = "Find (Telescope)" },
      { "<leader>g", group = "Git" },
      { "<leader>h", group = "Hunks + Harpoon" },
      { "<leader>j", group = "Java (jdtls)" },
      { "<leader>l", group = "LSP / format" },
      { "<leader>lw", group = "Workspace folders" },
      { "<leader>r", group = "Run / rename" },
      { "<leader>t", group = "Toggles" },
      { "<leader>1", hidden = true },
      { "<leader>2", hidden = true },
      { "<leader>3", hidden = true },
      { "<leader>4", hidden = true },
      { "<leader>5", hidden = true },
      { "g", group = "Goto / comment" },
      { "]", group = "Next" },
      { "[", group = "Previous" },
    },
  })
end

return M
