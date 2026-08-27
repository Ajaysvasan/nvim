# `telescope.lua` — fuzzy finder

[telescope.nvim](https://github.com/nvim-telescope/telescope.nvim). Owns the
entire `<leader>f` namespace plus the Git pickers.

## Settings and why

### Defaults

| Setting | Value | Why |
|---|---|---|
| `prompt_prefix` | ` 🔍 ` | |
| `selection_caret` | ` ➤ ` | |
| `path_display` | `{ "truncate" }` | Truncates from the left, so the filename stays visible on long paths |
| `file_ignore_patterns` | `node_modules`, `.git/`, `dist/`, `build/`, `target/`, `*.class`, `__pycache__`, `*.pyc` | Build output and dependency trees swamp results otherwise. `target/` and `*.class` matter specifically for the Java/Maven workflow. Note the tree still *shows* these — this only filters search. |

### Insert-mode mappings inside a picker

| Key | Action | Why |
|---|---|---|
| `<C-j>` | Next result | Move the selection without leaving the home row or exiting insert |
| `<C-k>` | Previous result | |
| `<C-q>` | Send to quickfix and open it | Turns a search into a work list |
| `<C-x>` | Delete buffer | |
| `<Esc>` | Close | One press closes instead of dropping to normal mode |

### Normal-mode mappings inside a picker

| Key | Action |
|---|---|
| `q` | Close |
| `<C-x>` | Delete buffer |
| `dd` | Delete buffer (buffers picker only) |

### Per-picker themes

| Picker | Theme | Why |
|---|---|---|
| `find_files` | `dropdown`, no previewer, `hidden = true` | You already know what the file is; the preview just costs time |
| `buffers` | `dropdown`, no previewer, `initial_mode = "normal"` | Starting in normal mode means `dd` closes a buffer immediately |
| `git_branches` | `dropdown`, no previewer | |
| `lsp_references` / `lsp_definitions` | `cursor` theme, `initial_mode = "normal"` | Opens right at the cursor — the results are about the symbol you're on |
| `lsp_document_symbols` / `lsp_workspace_symbols` | `dropdown` | |

### fzf-native

`fzf` extension is loaded with `pcall` so a machine without a compiler still
gets a working Telescope (just with the slower Lua sorter). Configured with
`fuzzy = true`, overriding both the generic and file sorters, `case_mode = "smart_case"`.

## Keymaps

### File navigation

| Key | Action |
|---|---|
| `<leader>ff` | Find files |
| `<leader>fa` | Find **all** files (hidden + gitignored) |
| `<leader>fr` | Recent files (oldfiles) |

### Search content

| Key | Action |
|---|---|
| `<leader>fg` | Live grep |
| `<leader>fw` | Grep the word under the cursor |
| `<leader>fs` | Grep a string you're prompted for |
| `<leader>ft` | Find `TODO` / `FIXME` / `NOTE` / `HACK` / `PERF` / `WARNING` |
| `<leader>/` | Fuzzy find within the current buffer |

### Buffers

| Key | Action |
|---|---|
| `<leader>fb` | Buffers |
| `<leader><leader>` | Quick buffer switch (same picker, faster to reach) |

### LSP and symbols

| Key | Action |
|---|---|
| `<leader>fd` | Document symbols |
| `<leader>fD` | Workspace symbols |
| `<leader>fi` | Implementations |
| `<leader>fR` | References |

### Diagnostics

| Key | Action |
|---|---|
| `<leader>fe` | Diagnostics — all buffers |
| `<leader>fE` | Diagnostics — current buffer only |

### Git

| Key | Action |
|---|---|
| `<leader>gc` | Git commits |
| `<leader>gb` | Git branches |
| `<leader>gs` | Git status |
| `<leader>gS` | Git stash |

> ⚠️ **Collision:** `<leader>gc` is also mapped to `:LazyGitConfig` in
> [lazygit.lua](lazygit.md). Both modules define it globally; whichever loads
> last wins. Since Telescope loads on a `<leader>f` key and lazygit on
> `<leader>gg`, the winner depends on which you press first in a session.

### Neovim internals

| Key | Action |
|---|---|
| `<leader>fh` | Help tags |
| `<leader>fk` | Keymaps — **the fastest way to answer "what was that key again?"** |
| `<leader>fc` | Commands |
| `<leader>fC` | Colorschemes (live preview) |
| `<leader>fm` | Marks |
| `<leader>fj` | Jumplist |
| `<leader>fq` | Quickfix |
| `<leader>fl` | Location list |
| `<leader>fp` | Resume the last picker where you left it |

## Extensions

- **fzf-native** — loaded here
- **telescope-dap** — loaded by the DAP spec in `plugins.lua`, see [dap.md](dap.md)
