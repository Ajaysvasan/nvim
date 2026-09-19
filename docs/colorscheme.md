# `colorscheme.lua` — the theme

**One theme: VS Code Dark+** ([Mofiqul/vscode.nvim](https://github.com/Mofiqul/vscode.nvim)).

| | |
|---|---|
| Background | `#1f1f1f` |
| lualine theme | `vscode` |
| Load | `lazy = false`, `priority = 1000` — a colorscheme must be applied before anything renders |

`<leader>fC` opens Telescope's colorscheme picker with live preview. It lists
whatever is installed and does not persist anything.

## Switching themes

Three edits:

1. In `plugins.lua`, replace the `Mofiqul/vscode.nvim` spec with the theme you
   want. Keep `lazy = false, priority = 1000`, then `:Lazy sync`.
2. In `colorscheme.lua`, replace the body of `apply_theme()` with that theme's
   `setup()` and `vim.cmd.colorscheme(...)`. Pass the `transparent` argument to
   the theme's own transparency option so `<leader>tt` keeps working.
3. Point `M.lualine_theme()` at the matching lualine theme name, or `"auto"` if
   the theme ships none. A wrong name is not an error — lualine silently falls
   back to `auto` and warns *"There are some issues with your config"* on every
   launch.

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

## lualine

`M.lualine_theme()` returns `"vscode"`. The lualine spec in `plugins.lua` calls
it for the **first draw**, so it must not depend on anything `setup()` does.

`refresh_lualine()` re-runs `lualine.setup()` after a transparency toggle, and
only if lualine is **already loaded**. Calling `require("lualine")` any earlier
forces lazy.nvim to load a plugin whose spec is `event = "VeryLazy"` — ~3.1 ms of
eager startup for a statusline explicitly allowed to appear a frame late.

## Related

- [transparency.md](transparency.md) — the toggle that calls `reapply()`
- [qol.md](qol.md) — lualine
- [plugins.md](plugins.md) — the spec and its load order
