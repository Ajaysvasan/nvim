# `transparency.lua` — transparent background toggle

Lets your terminal's own background — wallpaper, blur, whatever — show through
Neovim. **Off by default**; nothing changes until you press `<leader>tt`.

Registered from the colorscheme spec in `plugins.lua`, so it is available from
the moment the colorscheme loads. Setup is registration only (one command, one
keymap) — it costs effectively nothing at startup.

## How it works

```lua
vim.g.transparent_background = not vim.g.transparent_background
require("ajay.colorscheme").reapply()
```

`reapply()` rebuilds the theme with the new flag — VS Code Dark+ takes it as its
native `transparent` option — and then refreshes lualine. See
[colorscheme.md](colorscheme.md).

The theme is **rebuilt**, not patched, because themes bake the transparency
choice in at `setup()` time. Letting the theme do it also covers every highlight
group it owns, including ones plugins add later — unlike clearing `guibg` on a
hand-written list of groups, which drifts out of date and is undone by the next
`:colorscheme`.

If the rebuild fails, the flag is rolled back so it never disagrees with what is
on screen.

## Keymaps

| Key | Action |
|---|---|
| `<leader>tt` | Toggle transparency |

`<leader>t` is the toggle prefix, shared with [conform](conform.md) (`tf` `tF`
`ts` `ti`), [gitsigns](gitsigns.md) (`tb` `td`) and [bigfile](bigfile.md)
(`tB`). No conflict.

## Commands

| Command | Action |
|---|---|
| `:ToggleTransparency` | Same as `<leader>tt` |

## Notes

- Your terminal must itself be transparent for this to be visible. Neovim can
  only decline to paint a background; it cannot make the terminal see-through.
- The setting does not persist across restarts. To start transparent every time,
  set `vim.g.transparent_background = true` in [`options.lua`](options.md) — it
  is read when the colorscheme loads.
