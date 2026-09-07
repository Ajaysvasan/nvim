# Quality-of-life plugins

Five plugins configured inline in `plugins.lua` — small enough that they don't
need their own module file.

## lualine.nvim — statusline

Loads on `VeryLazy` (the statusline can appear a frame late).

| Setting | Value | Why |
|---|---|---|
| `icons_enabled` | `vim.g.have_nerd_font ~= false` | Follows the global font flag — falls back to text-only on a machine without a patched font |
| `theme` | `"catppuccin-frappe"` | Matches [the colorscheme](colorscheme.md). **Was `"catppuccin"`, which does not exist** — catppuccin ships one lualine theme per flavour (`catppuccin-latte/-frappe/-macchiato/-mocha`, plus `catppuccin-nvim`) and no bare `catppuccin`. lualine silently fell back to `auto` and warned *"There are some issues with your config. Run `:LualineNotices`"* on every launch. Change this whenever you change the flavour in `colorscheme.lua`. |
| `globalstatus` | `true` | **One statusline for the whole window**, not one per split. With a file tree and a DAP panel open, per-split statuslines waste three rows and repeat the same information. |

Everything else is lualine's default section layout.

**Keymaps:** none.

## nvim-autopairs

Loads on `InsertEnter`, `config = true` (plugin defaults).

Inserts the closing bracket/quote as you type the opening one, and skips over the
closing one if you type it yourself. It integrates with nvim-cmp out of the box
so confirming a function completion adds the parentheses.

**Keymaps:** none — it works on the characters you already type.

## indent-blankline.nvim (ibl)

Loads on `BufReadPost` / `BufNewFile`, `main = "ibl"`, `opts = {}` (defaults).

Draws a vertical guide at each indent level. Useful in deeply nested Java and
JSX where the brace that closes a block is far off screen.

Catppuccin themes it via the `indent_blankline` integration.

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

## nvim-emmet

Loads on `ft = html, htmlangular, css, scss, less, javascriptreact,
typescriptreact, vue, svelte`.

| Key | Mode | Action |
|---|---|---|
| `<leader>xe` | n, v | Wrap the selection with an Emmet abbreviation |

Select some text, press `<leader>xe`, type something like `div.card>ul>li*3`, and
it expands around the selection.

### It needs a language server

**nvim-emmet is not a standalone expander.** `wrap_with_abbreviation` sends an
`emmet/expandAbbreviation` **LSP request** and silently returns if nothing
answers — no error, no message, the key just does nothing.

That is exactly what happened until `emmet_language_server` was added to
`ensure_servers` in [lsp.md](lsp.md): the plugin was installed, the keymap was
mapped, and `<leader>xe` had never once worked.

The filetype list above is `emmet-language-server`'s own, minus templating
languages this config has no other support for. It previously omitted
`htmlangular`, `scss` and `less` — three filetypes where the server *does*
attach but the keymap did not even exist.

> `<leader>x` is otherwise the LSP diagnostics prefix (`<leader>xd`, `<leader>xq`
> — see [lsp.md](lsp.md)), and `<leader>x` alone is "save and quit" from
> [keymaps.md](keymaps.md). All three are distinct sequences, but note that the
> bare `<leader>x` save-and-quit will wait `timeoutlen` in emmet filetypes before
> firing.

## rainbow-delimiters.nvim

Loads on `BufReadPost` / `BufNewFile` with no configuration.

Colours matching bracket pairs by nesting depth using treesitter's parse tree —
so a `}` is visibly the partner of a specific `{`. Works in every language with a
treesitter parser installed; see [treesitter.md](treesitter.md).

**Keymaps:** none.
