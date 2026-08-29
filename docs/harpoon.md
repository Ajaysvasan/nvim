# `harpoon.lua` — quick file marks

[harpoon](https://github.com/ThePrimeagen/harpoon), `branch = harpoon2`.

Pin the handful of files you're actually working in, then jump between them with
a single chord — no fuzzy searching, no buffer list to scan.

## Settings and why

| Setting | Value | Why |
|---|---|---|
| `save_on_toggle` | `false` | Opening the quick menu doesn't rewrite the list |
| `sync_on_ui_close` | `true` | Edits made *in* the quick menu (reorder, delete lines) persist when you close it |
| `key` | `vim.uv.cwd()` | The mark list is **per working directory**, so each project keeps its own set |

## Fixes in this file

- harpoon2 renamed `list:append()` to `list:add()`. The old call worked on the
  pinned commit and errors on newer ones. The code calls
  `(list.add or list.append)(list)` so both work.
- `vim.loop` → `vim.uv` (`vim.loop` is deprecated).
- `<leader>hp` collided with gitsigns' `preview_hunk`, so harpoon prev/next moved
  to `<leader>hk` / `<leader>hj`.
- `<leader>a` warns instead of erroring when the current buffer has no file path.

## Keymaps

| Key | Action |
|---|---|
| `<leader>a` | Add the current file to the list (notifies with the filename) |
| `<leader>he` | Toggle the quick menu — edit the list directly as text |
| `<leader>hh` | Browse the list in a Telescope picker, with file preview |
| `<leader>hx` | Remove the current file from the list |
| `<leader>hc` | Clear the whole list |
| `<leader>hj` | Jump to the next file in the list |
| `<leader>hk` | Jump to the previous file |
| `<leader>1` … `<leader>5` | Jump directly to slot 1–5 — **works in every terminal** |
| `<A-1>` … `<A-5>` | Same, for terminals that deliver Alt as a modifier |

> **These were `<C-1>`–`<C-5>`, and were broken two ways:**
>
> 1. The `keys = {}` lazy-load triggers in `plugins.lua` declared
>    `<A-1>`–`<A-5>`, so the keys actually mapped were not the keys lazy.nvim
>    was watching for. They only existed once harpoon had been loaded by some
>    *other* trigger.
> 2. Most terminals send no distinct byte for `Ctrl+<digit>` — it collapses to
>    the plain digit. So even once loaded, the mapping was frequently dead. Same
>    class of problem as `Ctrl+/` in [comment.md](comment.md).
>
> Fixed the same way comment.lua handles it: a primary binding that works
> everywhere (`<leader>1`–`<leader>5`), plus a convenience layer (`<A-1>`–`<A-5>`)
> for terminals that deliver Alt — Kitty, WezTerm, Ghostty, or Terminal.app with
> "Use Option as Meta key". Both sets are declared in the spec's `keys`, so the
> lazy-load trigger fires either way.

## The `<leader>h` prefix is shared

`<leader>h` is used by **both** harpoon and [gitsigns](gitsigns.md). Current
split:

| Harpoon | Gitsigns |
|---|---|
| `hx` `hc` `he` `hh` `hj` `hk` | `hs` `hr` `hS` `hu` `hR` `hp` `hb` `hd` `hD` |

There is no longer an overlap. There used to be: harpoon's "remove file" was
also on `<leader>hd`, which gitsigns claims for "diff this". Gitsigns sets its
mappings buffer-locally in `on_attach`, and a buffer-local mapping **beats** a
global one — so harpoon's remove was dead in every git-tracked file, which is
most files you open. It only ever worked outside a repo.

Gitsigns kept `<leader>hd` (it is the one that actually fired); harpoon's remove
moved to `<leader>hx`.
