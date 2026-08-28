# `dashboard.lua` — alpha-nvim start screen

The screen you see when you run `nvim` with no file argument. Loads on
`VimEnter`.

## What it does

- Picks a **random ASCII logo** from a built-in collection on every launch, each
  with its own title and highlight group.
- Picks a **random quote**, organised by franchise with character attribution,
  and renders it as the footer.
- Renders a button list, then strips the buffer of line numbers, sign column,
  cursorline, fold column and statusline so the art sits on a clean canvas.
- Seeds `math.randomseed(os.time())` so the logo/quote pair actually differs
  between launches.

## Settings and why

| Setting | Why |
|---|---|
| `pcall(require, "alpha")` guard | Warns and returns instead of erroring if alpha isn't installed yet — a fresh clone shouldn't fail at startup |
| Custom highlight groups (`DashTitle`, `DashButton`, `DashShortcut`, `DashQuote`) | Defined in the file so the dashboard stays legible regardless of colorscheme flavour |
| `FileType alpha` autocmd | Clears `foldenable`, `number`, `relativenumber`, `signcolumn`, `cursorline`, `statusline` and `list` buffer-locally. Without it the alpha buffer inherits the editing UI and the art misaligns. |

## Buttons

These are **dashboard shortcuts**, active only while the alpha buffer is
focused — press the letters shown on the left.

| Shortcut | Action | Runs |
|---|---|---|
| `SPC f f` | Find File | `:Telescope find_files` |
| `SPC f r` | Recent Files | `:Telescope oldfiles` |
| `SPC f g` | Live Grep | `:Telescope live_grep` |
| `SPC f b` | Buffers | `:Telescope buffers` |
| `SPC g s` | Git Status | `:Telescope git_status` |
| `SPC l` | LSP Info | `:LspInfo` |
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

## Layout

```
padding · header (logo) · padding · buttons · padding · footer (quote) · padding
```

## Keymaps

No global keymaps. The button shortcuts above are buffer-local to the alpha
buffer.
