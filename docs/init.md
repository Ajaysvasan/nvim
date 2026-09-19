# `init.lua` — entry point

The smallest file in the config: a version check, three globals, and five
`require`s.

## What it does

```lua
if vim.fn.has("nvim-0.11") ~= 1 then
  -- print an actionable error and stop
  return
end

vim.g.mapleader      = " "
vim.g.maplocalleader = " "
vim.g.have_nerd_font = true

require("ajay.options")
require("ajay.keymaps")
require("ajay.bigfile").setup()

require("ajay.plugins")

require("ajay.doctor").setup()
```

## Settings and why

| Setting | Value | Why |
|---|---|---|
| Version check | Neovim **0.11+** | Below 0.11 the config does not degrade, it crashes: `lsp.lua` calls `vim.lsp.config()` at module scope, which does not exist, and you get a bare traceback that says nothing about the real problem. The check uses nothing newer than 0.5, so it can actually run and print on the versions it rejects. Distro repos run years behind (Debian 12 ships 0.7), so "broken on the new machine" is usually an old package. |
| `mapleader` | `<Space>` | The most reachable key on both hands, and unused in normal mode. Every custom mapping in this config sits under it. |
| `maplocalleader` | `<Space>` | Set to the same key deliberately — this config does not use buffer-local leader chords, so keeping them identical avoids a second mental namespace. |
| `have_nerd_font` | `true` | Read by `icons.lua`, lualine and which-key. Setting it `false` makes every glyph fall back to plain ASCII so a machine without a patched font degrades instead of showing tofu boxes. |

## Load order and why it matters

1. **`options`** first — it must run before plugins so that `termguicolors`
   is on when the colorscheme loads. It also puts mason's `bin` directory on
   `PATH`, which everything else depends on to find its binaries.
2. **`keymaps`** second — plugin-free mappings, no dependencies.
3. **`bigfile`** third — **must be before `plugins`**. Its `BufReadPre` autocmd
   has to exist before the first file is opened, including one passed on the
   command line; registering it from a plugin spec would be too late for
   `nvim somehugefile.json`. See [bigfile.md](bigfile.md).
4. **`plugins`** fourth — bootstraps lazy.nvim and hands over control. Every
   remaining module is loaded by a plugin spec, not from here.
5. **`doctor`** last — only registers the `:AjayDoctor` command. Costs nothing
   until you actually invoke it.

Only these modules load eagerly. Everything else is owned by the spec in
[`plugins.lua`](plugins.md) and loads on an event, command, key, or filetype.

## Keymaps

None defined here. See [keymaps.md](keymaps.md).

## Related

- [options.md](options.md)
- [keymaps.md](keymaps.md)
- [plugins.md](plugins.md)
- [doctor.md](doctor.md)
