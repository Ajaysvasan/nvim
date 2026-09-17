# `colorscheme.lua` — the theme

**One theme: VS Code Dark+** ([Mofiqul/vscode.nvim](https://github.com/Mofiqul/vscode.nvim)).

| | |
|---|---|
| Background | `#1f1f1f` |
| lualine theme | `vscode` |
| Load | `lazy = false`, `priority = 1000` — a colorscheme must be applied before anything renders |

## The switcher is gone

This file used to be a **registry** of three themes with `:Theme`,
`:ThemeNext`, `<leader>tc` / `<leader>tn`, and the choice persisted to
`stdpath("data")/colorscheme_state`.

All of it is removed. Three themes were installed and eagerly loaded —
a colorscheme cannot lazy-load without a visible flash — to support switching
that did not happen in practice. Darcula and Catppuccin are commented out in
both `plugins.lua` and this module rather than deleted, so turning one back on
is an uncomment, not an archaeology exercise.

`<leader>fC` still opens Telescope's colorscheme picker with live preview. It
lists whatever is installed and does not persist anything.

## Switching themes

**Two edits, both required.** Step 1 puts the plugin on the runtimepath; step 2
calls into it. Doing only one gets you either a dead `require` or an unused
plugin.

1. In `plugins.lua`, uncomment the theme's entry in the colorscheme spec's
   `dependencies`, then `:Lazy sync`.
2. In `colorscheme.lua`, comment out the `require("vscode")` block in
   `apply_theme()` and uncomment the block for the theme you want.
3. Point `M.lualine_theme()` at the matching lualine theme name — the commented
   blocks each name theirs.

### Why `dependencies` and not a sibling spec

Load order, not tidiness. lazy.nvim loads a plugin's dependencies **before** the
plugin itself, so the theme is on the runtimepath by the time this spec's
`config` calls into `colorscheme.lua`. As a sibling spec it would need a higher
`priority` than this one's 1000, and `require(...)` would fail on the first
startup after a switch.

## Transparency

`<leader>tt` / `:ToggleTransparency` — see [transparency.md](transparency.md).
The flag is read fresh on every rebuild, because vscode.nvim (like most themes)
bakes the choice in at `setup()` time. That is why toggling re-runs the whole
theme rather than patching highlight groups.

> ### Fixed bug: transparency was one-way
>
> `<leader>tt` turned transparency **on** correctly and could never turn it back
> **off** — the background stayed cleared until you restarted Neovim.
>
> The bug is in vscode.nvim. Its `config.setup()` does:
>
> ```lua
> if config.opts.transparent then
>     config.opts.color_overrides.vscBack = 'NONE'
> end
> ```
>
> It sets `vscBack = 'NONE'` when transparent and **never clears it** when
> transparent goes back to `false`. Worse, `config.opts` is built with a
> *shallow* `vim.tbl_extend`, so when the caller passes no `color_overrides`
> that table **is the plugin's own `defaults` table** — the write poisons
> `defaults` for the rest of the session and every later `setup()` call
> inherits `vscBack = 'NONE'`.
>
> Fix: pass a fresh `color_overrides = {}` on every call, which scopes the
> plugin's mutation to that call. Verified toggling on→off→on→off restores the
> background every time.

### `strip_backgrounds()` — the fallback

Kept even though vscode.nvim does not need it, because Darcula does: a theme
with no native transparency support needs its backgrounds cleared by hand.

It **computes** the set rather than hard-coding it. Every highlight group whose
background currently equals `Normal`'s background is, by definition, painting
the editor background, so clearing it is correct no matter which plugin defined
it. Linked groups are skipped — re-setting one would break the link and freeze
it at today's colours.

> This replaced a hand-written list of ~20 groups (`Normal`, `NormalFloat`,
> `SignColumn`, …) that drifted out of date the moment a plugin was added.

## lualine

`M.lualine_theme()` returns `"vscode"`. The lualine spec in `plugins.lua` calls
it for the **first draw**, so it must not depend on anything `setup()` does.

`refresh_lualine()` re-runs `lualine.setup()` after a transparency toggle, and
only if lualine is **already loaded**.

> *Historic bug:* it ran on every apply — including the one at startup — and
> `require("lualine")` forces lazy.nvim to load a plugin whose spec is
> `event = "VeryLazy"`. That cost ~3.1 ms of eager startup for a statusline
> explicitly allowed to appear a frame late. Skipping is safe: the spec already
> asks this module for the right theme, so lualine comes up correct on its own.

> *Historic bug:* the theme name was once `"catppuccin"`, which is not a lualine
> theme — catppuccin ships one file per flavour. lualine silently fell back to
> `auto` and warned on every launch.

## Related

- [transparency.md](transparency.md) — the toggle that calls `reapply()`
- [qol.md](qol.md) — lualine
- [plugins.md](plugins.md) — the spec and its load order
