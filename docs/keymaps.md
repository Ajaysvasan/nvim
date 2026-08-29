# `keymaps.lua` — plugin-free keymaps

## The rule

**This file only holds mappings that need no plugin.** Anything that touches a
plugin lives in that plugin's own module.

That is not a style preference — it is load-bearing. lazy.nvim lazy-loads
plugins via `keys = { ... }` in the spec. If a mapping to a plugin function were
defined here at startup, it would either error (plugin not loaded yet) or force
the plugin to load eagerly, defeating the point.

> **History:** this file used to be two configs concatenated. `<C-h/j/k/l>`,
> `<leader>w`, `<leader>q` and the whole window-nav block were each defined
> twice, and every Telescope mapping here was redefined again in
> `telescope.lua`.

## Files

| Key | Action | Why |
|---|---|---|
| `<leader>w` | `:w` | Save |
| `<leader>q` | `:q` | Quit |
| `<leader>x` | `:wq` | Save and quit |

## Search

| Key | Action | Why |
|---|---|---|
| `<leader>nh` | `:nohlsearch` | Clear search highlight. **Was `<leader>h`** — that made every `<leader>h*` chord (gitsigns hunks, harpoon) sit through the full `timeoutlen` before firing, because `<leader>h` was itself a complete mapping. Moved out of the way. |
| `<Esc>` | `:noh` | Clear search highlight with the key you'd reach for instinctively |

## Window navigation

| Key | Action |
|---|---|
| `<C-h>` | Focus window left |
| `<C-j>` | Focus window down |
| `<C-k>` | Focus window up |
| `<C-l>` | Focus window right |
| `<C-Up>` | Resize +2 rows |
| `<C-Down>` | Resize -2 rows |
| `<C-Left>` | Vertical resize -2 |
| `<C-Right>` | Vertical resize +2 |

> `<C-k>` used to be re-mapped buffer-locally to LSP signature help, which
> beat this global mapping in every buffer with a server attached — i.e. most
> code buffers. Signature help moved to `gK` (see [lsp.md](lsp.md)), so `<C-k>`
> now means "focus window up" everywhere.

## Motion and editing

| Key | Mode | Action | Why |
|---|---|---|---|
| `H` | n | `^` — first non-blank of line | Faster than reaching for `^` |
| `L` | n | `$` — end of line | Same, symmetrical |
| `<` | v | `<gv` | Re-selects after indenting so you can dedent repeatedly |
| `>` | v | `>gv` | Same |
| `J` | v | Move selection down one line | With `=gv` so it re-indents and stays selected |
| `K` | v | Move selection up one line | Same |

## Run current file

Each opens a terminal in a horizontal split.

| Key | Runs |
|---|---|
| `<leader>rc` | `g++ -std=c++17 <file> -o out && ./out` |
| `<leader>rp` | `python3 <file>` |
| `<leader>rj` | `javac <file> && java <basename>` |

All three `shellescape` the path. macOS paths under `~/Library` and iCloud
contain spaces far more often than anything on Linux, and the old unquoted
version silently ran the wrong command there.

## CMake

| Key | Runs |
|---|---|
| `<leader>cb` | `mkdir -p build && cd build && cmake .. -DCMAKE_BUILD_TYPE=Release && make` |
| `<leader>cr` | `./build/<current-directory-name>` — assumes the target is named after the project directory |

## Where the rest went

| Prefix | Now lives in |
|---|---|
| `<leader>f*` | [telescope.lua](telescope.md) |
| `gd`, `gr`, `K`, `<leader>ca`, `<leader>rn`, `<leader>x{d,q}` | [lsp.lua](lsp.md) — buffer-local, via `LspAttach` |
| `<leader>d*`, `<F5>`–`<F10>` | [dap.lua](dap.md) |
| `<C-n>` | [neotree.lua](neotree.md) |
| `<leader>lf` | [conform.lua](conform.md) |
| `<leader>h*` | [gitsigns.lua](gitsigns.md) and [harpoon.lua](harpoon.md) |
| `<leader>g*` | [gitsigns.lua](gitsigns.md), [lazygit.lua](lazygit.md), [telescope.lua](telescope.md) |
| `<leader>j*` | [jdtls.lua](jdtls.md) |
| `<leader>m*` | [jupyter.lua](jupyter.md) |
| `<leader>c{t,s,p}` | [copilot.lua](copilot.md) |
