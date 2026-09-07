# `transparency.lua` — transparent background toggle

Lets your terminal's own background — wallpaper, blur, whatever — show through
Neovim. **Off by default**; nothing changes until you press `<leader>tt`.

Registered from the catppuccin spec in `plugins.lua`, so it is available from
the moment the colorscheme loads. Setup is registration only (one command, one
keymap) — it costs effectively nothing at startup.

## How it works

```lua
vim.g.transparent_background = not vim.g.transparent_background
package.loaded["ajay.colorscheme"] = nil
require("ajay.colorscheme")
```

[`colorscheme.lua`](colorscheme.md) reads that global:

```lua
transparent_background = vim.g.transparent_background == true,
float = { transparent = vim.g.transparent_background == true, solid = false },
```

Clearing `package.loaded` is what makes the re-`require` actually execute rather
than return the cached module. The re-apply is wrapped in `pcall`, and if it
fails the flag is rolled back so it never disagrees with what is on screen.

## Why it was rewritten

The old version had two real problems:

1. **It hand-listed ~20 highlight groups** (`Normal`, `NormalFloat`, `NeoTree*`,
   `Telescope*`, `WhichKeyFloat`…) and cleared `guibg` on each. That list drifts
   out of date the moment you add a plugin, and it fights `:colorscheme`, which
   resets every group.
2. **Turning transparency off restored a hardcoded `guibg=#1e1e1e`** — which is
   not a Catppuccin Frappé colour. Toggling off left you with a background that
   did not match the theme. (The real Frappé background is `#303447`.)

Catppuccin already implements this properly through `transparent_background`, so
the module now just flips the flag and lets the **theme** decide which groups
lose their background — all of them, correctly, including ones added later.

It was also **not loaded at all** before, so `<leader>tt` did not exist.

## Keymaps

| Key | Action |
|---|---|
| `<leader>tt` | Toggle transparency |

`<leader>t` is the toggle prefix, shared with [conform](conform.md) (`tf` `tF`
`ts` `ti`) and [gitsigns](gitsigns.md) (`tb` `td`). No conflict.

## Commands

| Command | Action |
|---|---|
| `:ToggleTransparency` | Same as `<leader>tt` |

## Notes

- Your terminal must itself be transparent for this to be visible. Neovim can
  only decline to paint a background; it cannot make the terminal see-through.
- The setting does not persist across restarts. To start transparent every time,
  set `vim.g.transparent_background = true` in [`options.lua`](options.md) —
  it is read at colorscheme load.
