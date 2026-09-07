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
| `vimgrep_arguments` | explicit `rg` invocation | `--smart-case` matches the editor's own `ignorecase` + `smartcase`; `--trim` keeps deeply indented matches readable in a narrow results pane |

### `find_files` drives `fd` directly

`find_files` is given an explicit `find_command`:

```
fd --type f --hidden --follow --strip-cwd-prefix
   --exclude .git --exclude node_modules --exclude target
   --exclude build --exclude dist --exclude __pycache__
```

The point is **where the filtering happens**. `fd` applies these excludes and
reads `.gitignore` in Rust, before results ever reach Lua. Telescope's default
path shells out to `find` and then matches `file_ignore_patterns` against every
result in Lua — strictly more work for the same outcome.

Guarded: if neither `fd` nor `fdfind` is on `PATH`, `find_command` is left `nil`
and Telescope falls back to its own finder. Still works, just slower.

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

> `<leader>gc` used to collide with `:LazyGitConfig` in
> [lazygit.lua](lazygit.md). Resolved — lazygit's config moved to `<leader>gC`,
> and `<leader>gc` is unambiguously git commits.

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
