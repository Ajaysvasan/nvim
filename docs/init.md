# `init.lua` — entry point

The smallest file in the config. It does four things and nothing else.

## What it does

```lua
vim.g.mapleader      = " "
vim.g.maplocalleader = " "
vim.g.have_nerd_font = true
vim.g.enable_notebook = false

require("ajay.options")
require("ajay.keymaps")
require("ajay.plugins")

require("ajay.doctor").setup()
```

## Settings and why

| Setting | Value | Why |
|---|---|---|
| `mapleader` | `<Space>` | The most reachable key on both hands, and unused in normal mode. Every custom mapping in this config sits under it. |
| `maplocalleader` | `<Space>` | Set to the same key deliberately — this config does not use buffer-local leader chords, so keeping them identical avoids a second mental namespace. |
| `have_nerd_font` | `true` | Read by `icons.lua`, `neotree.lua` and lualine. Setting it `false` makes every glyph fall back to plain ASCII so a machine without a patched font degrades instead of showing tofu boxes. |
| `enable_notebook` | `false` | Gates the entire molten + image.nvim + jupytext stack. Off by default because `image.nvim` needs the `magick` LuaRock, which makes lazy.nvim bootstrap hererocks/luarocks and compile against ImageMagick's C headers. On a fresh machine that build fails, and since those specs are non-lazy, the failure blocks startup entirely. |

## Load order and why it matters

1. **`options`** first — it must run before plugins so that `termguicolors`
   is on when the colorscheme loads.
2. **`keymaps`** second — plugin-free mappings, no dependencies.
3. **`plugins`** third — bootstraps lazy.nvim and hands over control. Every
   remaining module is loaded by a plugin spec, not from here.
4. **`doctor`** last — only registers the `:AjayDoctor` command. Costs nothing
   until you actually invoke it.

Only three modules load eagerly. Everything else is owned by the spec in
[`plugins.lua`](plugins.md) and loads on an event, command, key, or filetype.

## Keymaps

None defined here. See [keymaps.md](keymaps.md).

## Related

- [options.md](options.md)
- [keymaps.md](keymaps.md)
- [plugins.md](plugins.md)
- [doctor.md](doctor.md)
