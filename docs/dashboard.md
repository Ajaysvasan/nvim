# `dashboard.lua` — alpha-nvim start screen

The screen you see when you run `nvim` with no file argument. Loads on
`VimEnter`.

## What it does

- Renders a static **NEOVIM** wordmark, the working directory, the button list,
  and a one-line startup summary. Nothing is randomised.
- Strips the buffer of line numbers, sign column, cursorline, fold column and
  statusline so the layout sits on a clean canvas.

> **It used to be much louder.** Nine large ASCII-art logos (Devil May Cry,
> Vergil, Naruto, Attack on Titan, Demon Slayer, Dark Souls, One Piece, God of
> War, Cyberpunk) picked at random, a boxed title line per logo, and one of ~45
> character quotes as the footer. All of that is gone. The buttons and their
> shortcuts are unchanged.

## Settings and why

| Setting | Why |
|---|---|
| `pcall(require, "alpha")` guard | Warns and returns instead of erroring if alpha isn't installed yet — a fresh clone shouldn't fail at startup |
| Highlights derived from `Function` / `Comment` / `Normal` / `Keyword` | The dashboard follows whatever colorscheme is active instead of hardcoding hex that fights it. Each has a literal fallback if the group has no `fg`. |
| `ColorScheme` autocmd | `:colorscheme` runs `:highlight clear`, which wipes anything set with `nvim_set_hl`. Without this, switching colorscheme left the dashboard on default highlights until restart. |
| `buttons.opts.spacing = 0` | alpha's default puts a blank line between every button. With eleven buttons that is 21 rows and a 35-row screen — taller than an 80×24 terminal, so the footer scrolled off. Packed, the layout is 23 rows. |
| `FileType alpha` autocmd | Clears `foldenable`, `number`, `relativenumber`, `signcolumn`, `cursorline`, `statusline` and `list` buffer-locally. Without it the alpha buffer inherits the editing UI and the layout misaligns. |

## Highlight groups

| Group | Derived from | Used for |
|---|---|---|
| `DashHeader` | `Function` fg, bold | The wordmark |
| `DashSubtitle` | `Comment` fg | The working directory line |
| `DashButton` | `Normal` fg | Button labels |
| `DashShortcut` | `Keyword` fg, bold | The right-hand shortcut column |
| `DashFooter` | `Comment` fg | The startup line |

> **`DashButton` and `DashShortcut` never actually applied before.** The old
> file set them on `section.buttons.opts`, but alpha's `layout_element.group`
> only propagates an `opts.inherit` *table* to its children — never `opts.hl`.
> The buttons rendered as plain `Normal` with alpha's built-in `Keyword`
> shortcuts. They are now set on each button element, where alpha reads them.

## Buttons

These are **dashboard shortcuts**, active only while the alpha buffer is
focused — press the letters shown on the right.

| Shortcut | Action | Runs |
|---|---|---|
| `SPC f f` | Find File | `:Telescope find_files` |
| `SPC f r` | Recent Files | `:Telescope oldfiles` |
| `SPC f g` | Live Grep | `:Telescope live_grep` |
| `SPC f b` | Buffers | `:Telescope buffers` |
| `SPC g s` | Git Status | `:Telescope git_status` |
| `SPC l` | LSP Info | `:checkhealth vim.lsp` |
| `n` | New File | `:ene | startinsert` |
| `c` | Neovim Config | `:e ~/.config/nvim/init.lua` |
| `l` | Lazy | `:Lazy` |
| `m` | Mason | `:Mason` |
| `q` | Quit | `:qa` |

> **A *Sessions* button used to sit here**, calling
> `require('persistence').load()`. `persistence.nvim` is not in the plugin list,
> so pressing it raised "module 'persistence' not found". It has been removed
> rather than left as a trap. If you want session restore, add
> `folke/persistence.nvim` to `plugins.lua` and put the button back.

The `SPC ...` labels mirror the real global mappings from
[telescope.md](telescope.md) — they work anywhere, not just on the dashboard.

## The footer

`45 plugins  ·  7 loaded  ·  22 ms`, from `require("lazy").stats()`.

lazy.nvim fills in `startuptime` from its own `UIEnter` handler, and whether
that runs before or after this module's `VimEnter` config is not guaranteed. The
footer is therefore refreshed from **both** a `vim.schedule` and a one-shot
`UIEnter` autocmd, redrawing with `:AlphaRedraw`. Both are no-ops once the alpha
buffer is gone.

## Layout

```
padding · header (wordmark) · padding · cwd · padding · buttons · padding · footer (stats)
```

23 rows, so it fits an 80×24 terminal without scrolling.

## Keymaps

No global keymaps. The button shortcuts above are buffer-local to the alpha
buffer.
