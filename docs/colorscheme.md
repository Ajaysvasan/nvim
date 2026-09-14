# `colorscheme.lua` — themes

A theme **registry** and switcher. Three themes are installed, your choice is
remembered across restarts, and switching is one keypress.

| Theme | `:Theme` name | Background | lualine |
|---|---|---|---|
| **VS Code Dark+** *(default)* | `vscode` | `#1f1f1f` | `vscode` |
| **IntelliJ Darcula** | `darcula` | `#2b2b2b` | `auto` |
| Catppuccin Frappe | `catppuccin` | `#303447` | `catppuccin-frappe` |

## Switching

| Key / command | Action |
|---|---|
| `<leader>tc` | Pick from a list (`vim.ui.select`) |
| `<leader>tn` | Cycle to the next theme |
| `:Theme` | Same picker |
| `:Theme vscode` | Apply directly (tab-completes) |
| `:ThemeNext` | Cycle |

The choice is written to `stdpath("data")/colorscheme_state` — **outside this
git repo**, so it follows the machine rather than the config. Same one-word
state-file pattern as the [Copilot](copilot.md) and
[format-on-save](conform.md) toggles.

A theme name in that file that no longer exists in the registry falls back to
the default instead of failing at startup.

## Why a registry

This file used to be a side-effect script: it ran `catppuccin.setup()` at
require time and ended with `vim.cmd.colorscheme("catppuccin-frappe")`.
Switching meant editing it. It is now a [Shape A module](api.md) exposing
`apply` / `cycle` / `pick` / `current`, and everything else reads from one
table — lualine, transparency, the picker and the persisted state.

### Adding a theme

1. Add the plugin as a **dependency of the catppuccin spec** in
   [plugins.md](plugins.md) — dependencies, not a sibling spec. lazy.nvim
   loads a plugin's dependencies *before* the plugin itself, so the theme is
   on the runtimepath by the time this module's `setup()` runs. As a sibling
   it would need a higher `priority` than catppuccin's 1000, and
   `require(...)` would fail on the first startup after a switch.
2. Add an entry to `M.themes`:

```lua
{
  name = "mytheme",
  label = "My Theme",
  lualine = "mytheme",        -- or "auto" if it ships none
  native_transparency = true, -- does it have its own transparent option?
  apply = function(transparent)
    require("mytheme").setup({ transparent = transparent })
    vim.cmd.colorscheme("mytheme")
  end,
}
```

Nothing else needs changing.

## Transparency

`<leader>tt` still toggles it ([transparency.md](transparency.md)), and it now
works on **all three** themes — verified, `Normal` loses its background on each.

Two mechanisms, picked per theme by `native_transparency`:

- **VS Code Dark+ and Catppuccin** implement it themselves. They are simply
  told, and they handle every group they own, including ones added later.
- **Darcula has no such option.** The fallback **computes** the affected set:
  every highlight group whose background currently equals `Normal`'s is, by
  definition, painting the editor background, so clearing it is correct
  regardless of which plugin defined it. Linked groups are skipped — re-setting
  them would break the link and freeze them at today's colours.

> This is deliberately **not** the hand-written list of ~20 highlight groups
> this config deleted once before. That list drifted out of date the moment a
> plugin was added; a computed set cannot.

Transparency is applied by *rebuilding* the theme rather than patching
highlights after the fact, because most themes bake the choice in at `setup()`
time — the flag has to be read while the theme is being constructed.

## lualine

lualine caches its options, so a switch re-runs `lualine.setup()` with the new
theme. The options passed there mirror the lualine spec in
[plugins.md](plugins.md) — passing only `theme` would silently reset
`icons_enabled` and `globalstatus` to lualine's own defaults.

On the very first draw, before this module's `setup()` has necessarily run,
the lualine spec calls `colorscheme.lualine_theme()`, which reads the persisted
choice directly.

> **Previous bug, still worth knowing:** the lualine theme was once set to
> `"catppuccin"`, which is not a lualine theme — catppuccin ships one file per
> *flavour*. lualine silently fell back to `auto` and warned once per launch.
> Same class as the old `colorscheme("catppuccin-nvim")`, which does not exist
> either and left Neovim on `default`.

## Related

- [transparency.md](transparency.md) — the `<leader>tt` toggle
- [plugins.md](plugins.md) — the specs and load order
- [api.md](api.md) — module shapes, and the rest of the extension points
