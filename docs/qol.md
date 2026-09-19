# Quality-of-life plugins

Four plugins configured inline in `plugins.lua` — small enough that they don't
need their own module file. (glance.nvim is inline too; it is documented with
the LSP keys that drive it, in [lsp.md](lsp.md#find-usages-glance).)

## lualine.nvim — statusline

Loads on `VeryLazy` (the statusline can appear a frame late).

| Setting | Value | Why |
|---|---|---|
| `icons_enabled` | `vim.g.have_nerd_font ~= false` | Follows the global font flag — falls back to text-only on a machine without a patched font |
| `theme` | `colorscheme.lualine_theme()` | Asks [colorscheme.lua](colorscheme.md) rather than hardcoding a name, so changing the theme is one edit in one place. A wrong name is not an error: lualine silently falls back to `auto` and warns on every launch. |
| `globalstatus` | `true` | **One statusline for the whole window**, not one per split. With the DAP panels open, per-split statuslines waste rows and repeat the same information. |

Everything else is lualine's default section layout.

**Keymaps:** none.

## indent-blankline.nvim (ibl)

Loads on `BufReadPost` / `BufNewFile`, `main = "ibl"`, `opts = {}` (defaults).

Draws a vertical guide at each indent level. Useful in deeply nested Java and
C++ where the brace that closes a block is far off screen.

**Keymaps:** none.

## undotree

Loads on `:UndotreeToggle` / `:UndotreeShow` or `<leader>u`.

Visualises Neovim's undo **tree** — not a linear history. When you undo a few
steps and then type something new, the old branch isn't lost; undotree is how you
get back to it.

This only works because `options.lua` sets `undofile = true`, so history persists
across restarts. See [options.md](options.md).

| Key | Action |
|---|---|
| `<leader>u` | Toggle the undo tree panel |

Inside the panel: `j`/`k` to move between states, `<CR>` to jump to one, `q` to
close.

## rainbow-delimiters.nvim

Loads on `BufReadPost` / `BufNewFile`.

Colours matching bracket pairs by nesting depth using treesitter's parse tree —
so a `}` is visibly the partner of a specific `{`. Works in every language with a
treesitter parser installed; see [treesitter.md](treesitter.md).

### Size gate — it was the single worst performance bug in this config

**Skipped on buffers over 5000 lines**, and on any buffer `bigfile.lua` has
flagged. Set via the plugin's own `vim.g.rainbow_delimiters.condition` hook in
the spec's `init`.

Without the gate, rainbow-delimiters attaches to **any** buffer with a treesitter
parser, at **any** size — it ships no size limit of its own — and its `attach()`
calls:

```lua
parser:parse(nil)     -- nil range = parse the ENTIRE buffer, synchronously
```

That is the one thing treesitter normally avoids. The highlighter parses only the
**visible range** and extends lazily. Rainbow forces the whole file through the
parser in one blocking call, then walks the resulting tree to place an extmark on
every delimiter — and re-runs the query on every change.

Measured on kafka's `GroupMetadataManagerTest.java` (1.42 MB, 30,692 lines):

| | wall | user CPU | peak RSS | typing median |
|---|---|---|---|---|
| before | 2.09 s | 1.90 s | 159 MB | 5.9 ms |
| after | **0.20 s** | **0.07 s** | **41 MB** | **0.99 ms** |

Cost tracks **delimiter density**, not file size — a 0.83 MB C lookup table is
free, a 1.42 MB deeply-nested Java test file is not — so the gate counts lines,
not bytes. Measured deltas on real kafka files: ~0 at 1k lines, +90 ms at 2.4k,
+220 ms at 3.3k, +1220 ms at 13.8k, +2130 ms at 30.7k.

Only `condition` is set. rainbow falls back to its own defaults for
`strategy` / `query` / `priority` / `highlight` (see `get_nested` in its
`config.lua`), so nothing else is clobbered. Verified: rainbow still attaches
normally at 227, 3332 and 4687 lines, and is skipped at 13,840 and 30,692.

> This is also why [bigfile.md](bigfile.md)'s thresholds looked fine in synthetic
> testing and not on real code. Synthetic files were regular and shallow;
> rainbow's cost is in nesting.

**Keymaps:** none.
