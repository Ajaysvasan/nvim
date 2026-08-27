# `colorscheme.lua` — Catppuccin

## What it does

Configures and applies [catppuccin/nvim](https://github.com/catppuccin/nvim).
Loaded eagerly (`lazy = false`, `priority = 1000`) — a colorscheme has to be
applied before anything renders.

> **Fix:** the old file ended with `vim.cmd.colorscheme("catppuccin-nvim")`.
> **That colorscheme does not exist.** Catppuccin registers `catppuccin`,
> `catppuccin-latte`, `catppuccin-frappe`, `catppuccin-macchiato` and
> `catppuccin-mocha`. The old call raised `E185` and Neovim silently fell back
> to `default`, which is why the Mac looked wrong.

## Settings and why

| Setting | Value | Why |
|---|---|---|
| `flavour` | `"frappe"` | Mid-dark. Applied explicitly with `vim.cmd.colorscheme("catppuccin-frappe")` at the bottom of the file. |
| `background` | `{ light = "latte", dark = "mocha" }` | Only consulted if you switch to the generic `catppuccin` scheme, which follows `&background` |
| `transparent_background` | `false` | The terminal background is not shown through. See [inactive-modules.md](inactive-modules.md) for the unused `transparency.lua`. |
| `term_colors` | `true` | Recolours the built-in `:terminal`, so `<leader>rp`/`<leader>rc` output matches the theme |
| `dim_inactive` | disabled | Inactive splits stay full-brightness — with a file tree permanently open, dimming is more distracting than helpful |
| `styles.comments` | `italic` | |
| `styles.conditionals` | `italic` | |
| `no_italic` / `no_bold` / `no_underline` | `false` | All text styles allowed |
| `default_integrations` | `true` | Catppuccin themes everything it recognises unless told otherwise |

## Integrations

Explicitly enabled so each plugin gets proper theme highlights rather than
generic fallbacks:

`cmp`, `gitsigns`, `neotree`, `telescope`, `treesitter`, `harpoon`, `alpha`,
`dap`, `dap_ui`, `indent_blankline`, `mason`, `native_lsp`, `mini`.

`notify` is `false` (nvim-notify is not installed).

> **Fix:** the integration key was `nvimtree`, but this config uses **neo-tree**.
> The tree never received themed highlights.

## Changing the theme

Edit two lines in this file — the `flavour` field and the final
`vim.cmd.colorscheme(...)` call — and keep them in sync:

```lua
flavour = "mocha",
...
vim.cmd.colorscheme("catppuccin-mocha")
```

Lualine follows automatically (`theme = "catppuccin"` in `plugins.lua`).

## Keymaps

| Key | Action | Defined in |
|---|---|---|
| `<leader>fC` | Browse and preview colorschemes | [telescope.lua](telescope.md) |
