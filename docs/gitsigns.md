# `gitsigns.lua` — git gutter and hunk actions

[gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim). Loads on
`BufReadPre` / `BufNewFile`.

## Signs

| State | Sign |
|---|---|
| add | `│` |
| change | `│` |
| delete | `_` |
| topdelete | `‾` |
| changedelete | `~` |
| untracked | `┆` |

These are plain Unicode box-drawing characters, not Nerd Font glyphs, so they
render on any font.

## Settings and why

| Setting | Value | Why |
|---|---|---|
| `signcolumn` | `true` | Signs in the gutter |
| `numhl` / `linehl` / `word_diff` | `false` | All off by default — the gutter alone is enough signal while editing. Each has a `:Gitsigns toggle_*` command when you want it. |
| `watch_gitdir.follow_files` | `true` | Keeps tracking a file across a `git mv` |
| `attach_to_untracked` | `true` | New files get signs too, showing everything as added |
| `current_line_blame` | `false` | Off by default — inline blame on every cursor move is distracting. Toggle with `<leader>tb`. |
| `current_line_blame_opts` | `virt_text` at `eol`, `delay = 1000` | One second before it appears, so moving through a file doesn't flash blame text |
| `current_line_blame_formatter` | `'<author>, <author_time:%Y-%m-%d> - <summary>'` | Who, when, why — in one line |
| `sign_priority` | `6` | Below diagnostic signs, so an LSP error still wins the gutter cell |
| `update_debounce` | `100` ms | |
| `max_file_length` | **`20000`** lines | Above that gitsigns detaches rather than stalling on generated files. Lowered from 40000 to roughly match the 1 MB threshold in [bigfile.lua](bigfile.md) — gitsigns diffs the whole buffer against the git index on every change, so it needs its own gate. |

> **Fixed bug:** `max_file_length` was set **twice** in the same table — `20000`
> near the top and `40000` further down. In a Lua table constructor the *last*
> assignment wins, so the intended 20000 was silently dead and gitsigns was still
> attaching to 40000-line files. It is now set once.
| `preview_config` | rounded border, `relative = "cursor"` | The hunk preview pops up at the cursor, matching the rest of the config's floats |

## Keymaps

All buffer-local, registered in `on_attach` — they only exist in files gitsigns
actually attached to.

### Navigation

| Key | Action |
|---|---|
| `]c` | Next hunk |
| `[c` | Previous hunk |

Both are `expr` mappings that pass through to Vim's built-in `]c`/`[c` when
`&diff` is set, so they still work inside `:diffthis`.

### Staging and resetting

| Key | Mode | Action |
|---|---|---|
| `<leader>hs` | n | Stage the hunk under the cursor |
| `<leader>hs` | v | Stage just the selected lines |
| `<leader>hr` | n | Reset the hunk under the cursor |
| `<leader>hr` | v | Reset just the selected lines |
| `<leader>hS` | n | Stage the whole buffer |
| `<leader>hR` | n | Reset the whole buffer |
| `<leader>hu` | n | Undo the last stage |

### Inspecting

| Key | Action |
|---|---|
| `<leader>hp` | Preview the hunk in a floating window |
| `<leader>hb` | Full blame for the current line |
| `<leader>hd` | Diff this file against the index |
| `<leader>hD` | Diff this file against `HEAD~` |

### Toggles

| Key | Action |
|---|---|
| `<leader>tb` | Toggle inline current-line blame |
| `<leader>td` | Toggle showing deleted lines inline |

### Text object

| Key | Mode | Action |
|---|---|---|
| `ih` | o, x | Select the hunk under the cursor — `dih` discards it, `yih` yanks it |

## Prefix collisions

`<leader>h` is shared with [harpoon](harpoon.md), but the two no longer
overlap. Harpoon's "remove file" used to sit on `<leader>hd` as well; because
gitsigns maps buffer-locally in `on_attach` it silently won inside every
git-tracked file, leaving harpoon's binding dead there. Gitsigns keeps
`<leader>hd`; harpoon's remove moved to `<leader>hx`.

`<leader>tb` / `<leader>td` share the `<leader>t` toggle prefix with conform's
`<leader>tf` / `<leader>tF` / `<leader>ts` / `<leader>ti` and
transparency's `<leader>tt` — all distinct, no conflict.
