-- lua/ajay/colorscheme.lua
--
-- FIX: the old file ended with `vim.cmd.colorscheme("catppuccin-nvim")`.
-- That colorscheme does not exist. Catppuccin registers:
--   catppuccin, catppuccin-latte, catppuccin-frappe,
--   catppuccin-macchiato, catppuccin-mocha
-- so the old call raised E185 and Neovim silently fell back to `default`,
-- which is a big part of why the Mac looked wrong.

require("catppuccin").setup({
  flavour = "frappe", -- latte, frappe, macchiato, mocha
  background = { light = "latte", dark = "mocha" },
  -- Driven by ajay/transparency.lua, which flips this global and then
  -- re-requires this file. Using catppuccin's own option means the THEME
  -- decides which groups lose their background -- all of them, correctly --
  -- instead of a hand-maintained list of 20 highlight groups that drifts
  -- every time a plugin is added.
  transparent_background = vim.g.transparent_background == true,
  float = { transparent = vim.g.transparent_background == true, solid = false },
  term_colors = true,
  dim_inactive = { enabled = false, shade = "dark", percentage = 0.15 },
  no_italic = false,
  no_bold = false,
  no_underline = false,
  styles = {
    comments = { "italic" },
    conditionals = { "italic" },
  },
  color_overrides = {},
  custom_highlights = {},
  -- PERF: `default_integrations` is not an option in current catppuccin --
  -- it was renamed `auto_integrations`, so the old line was dead config and
  -- detection ran regardless.
  --
  -- auto_integrations scans every installed plugin to guess which
  -- integrations to switch on. It costs ~2.9ms of eager startup, and on
  -- this config it finds exactly ONE thing the explicit list below did not
  -- already cover: rainbow_delimiters. So it is listed by hand and the scan
  -- is off.
  --
  -- TRADE-OFF: adding a new plugin no longer themes it automatically. If
  -- something looks unstyled after installing a plugin, add its integration
  -- to the list below (`:h catppuccin-integrations`), or flip this back to
  -- true and take the 2.9ms.
  auto_integrations = false,
  integrations = {
    rainbow_delimiters = true, -- was picked up by auto_integrations
    cmp = true,
    gitsigns = true,
    neotree = true, -- was `nvimtree` — you use neo-tree, not nvim-tree,
    -- so the tree never got themed highlights.
    telescope = { enabled = true },
    treesitter = true,
    harpoon = true,
    alpha = true,
    dap = true,
    dap_ui = true,
    indent_blankline = { enabled = true },
    mason = true,
    native_lsp = { enabled = true },
    notify = false,
    mini = { enabled = true, indentscope_color = "" },
  },
})

vim.cmd.colorscheme("catppuccin-frappe")
