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
| `transparent_background` | `vim.g.transparent_background == true` | Driven by [transparency.lua](transparency.md), which flips that global and re-requires this file. Defaults to opaque. Using catppuccin's own option means the **theme** decides which groups lose their background — all of them — instead of a hand-maintained list that drifts every time a plugin is added. |
| `float.transparent` | follows the same global | Floating windows stay consistent with the main background |
| `term_colors` | `true` | Recolours the built-in `:terminal`, so `<leader>rp`/`<leader>rc` output matches the theme |
| `dim_inactive` | disabled | Inactive splits stay full-brightness — with a file tree permanently open, dimming is more distracting than helpful |
| `styles.comments` | `italic` | |
| `styles.conditionals` | `italic` | |
| `no_italic` / `no_bold` / `no_underline` | `false` | All text styles allowed |
| `auto_integrations` | **`false`** | **Perf.** Auto-detection scans every installed plugin on every startup to guess which integrations to switch on — ~2.9 ms of eager, unavoidable-position work. On this config it found exactly **one** thing the explicit list below did not already cover (`rainbow_delimiters`), so that is listed by hand and the scan is off. |

## Integrations

Explicitly enabled so each plugin gets proper theme highlights rather than
generic fallbacks:

`cmp`, `gitsigns`, `neotree`, `telescope`, `treesitter`, `harpoon`, `alpha`,
`dap`, `dap_ui`, `indent_blankline`, `mason`, `native_lsp`, `mini`,
**`rainbow_delimiters`**.

`notify` is `false` (nvim-notify is not installed).

> **`default_integrations` was dead config.** The old file set
> `default_integrations = true`, but current catppuccin has no such option — it
> was renamed `auto_integrations`, so the line did nothing and detection ran
> regardless.

> ⚠️ **Trade-off of `auto_integrations = false`:** installing a new plugin no
> longer themes it automatically. If something looks unstyled after adding a
> plugin, add its integration to the list (`:h catppuccin-integrations`) — or set
> `auto_integrations = true` and take the ~2.9 ms back.

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
