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
  transparent_background = false,
  float = { transparent = false, solid = false },
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
  default_integrations = true,
  integrations = {
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
