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
| `<leader>hd` | Remove the current file from the list |
| `<leader>hc` | Clear the whole list |
| `<leader>hj` | Jump to the next file in the list |
| `<leader>hk` | Jump to the previous file |
| `<C-1>` … `<C-5>` | Jump directly to slot 1–5 |

> ⚠️ **Two things worth knowing about the direct-jump keys:**
>
> 1. The mappings are `<C-1>` … `<C-5>`, but the `keys = {}` lazy-load triggers
>    in `plugins.lua` declare `<A-1>` … `<A-5>`. They disagree. The `<C-n>`
>    mappings only exist once harpoon has been loaded by one of the *other*
>    triggers (`<leader>a`, `<leader>he`, `<leader>hh`) — so add a file first,
>    then the number keys work for the rest of the session.
> 2. Many terminals do not send a distinct byte for `Ctrl+1`–`Ctrl+5` at all.
>    If they do nothing for you, that's the terminal, not the config — use
>    `<leader>he` or change the mapping to `<A-1>` to match the spec.

## The `<leader>h` prefix is shared

`<leader>h` is used by **both** harpoon and [gitsigns](gitsigns.md). Current
split:

| Harpoon | Gitsigns |
|---|---|
| `hd` `hc` `he` `hh` `hj` `hk` | `hs` `hr` `hS` `hu` `hR` `hp` `hb` `hd`* `hD` |

`<leader>hd` is claimed by **both** — harpoon's "remove file" and gitsigns'
"diff this". Gitsigns' version is buffer-local (set in `on_attach`), so **inside
a git-tracked file gitsigns wins**; elsewhere harpoon's applies.
