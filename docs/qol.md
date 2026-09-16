# Quality-of-life plugins

Four plugins configured inline in `plugins.lua` — small enough that they don't
need their own module file. (`nvim-autopairs` was a fifth and has been
[removed](#no-autopairs--removed-on-purpose).)

## lualine.nvim — statusline

Loads on `VeryLazy` (the statusline can appear a frame late).

| Setting | Value | Why |
|---|---|---|
| `icons_enabled` | `vim.g.have_nerd_font ~= false` | Follows the global font flag — falls back to text-only on a machine without a patched font |
| `theme` | `colorscheme.lualine_theme()` | **Follows the active theme.** The config ships three ([colorscheme.md](colorscheme.md)), so this is no longer a hardcoded name — the spec asks the theme registry, and a mid-session switch re-runs `lualine.setup()`. *Historic bug:* it was once `"catppuccin"`, which is not a lualine theme (catppuccin ships one per flavour), so lualine silently fell back to `auto` and warned on every launch. |
| `globalstatus` | `true` | **One statusline for the whole window**, not one per split. With a file tree and a DAP panel open, per-split statuslines waste three rows and repeat the same information. |

Everything else is lualine's default section layout.

**Keymaps:** none.

## No autopairs — removed on purpose

`nvim-autopairs` used to live here and has been **removed**. Nothing in this
config auto-inserts a closing bracket or quote any more.

Auto-pairing fights you about as often as it helps: it guesses wrong when you
are typing into existing code, and the "type the closing character to skip over
it" behaviour silently swallows keystrokes, which is hard to notice and harder
to undo. Typing both halves yourself is predictable.

Verified after removal: typing `foo("bar` leaves exactly `foo("bar`.

> The `!` HTML/JSX snippets in [cmp.md](cmp.md) still expand to matched tags —
> that is an explicit expansion you ask for by name, not automatic pairing.

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
| `<leader>le` | n, v | Wrap the selection with an Emmet abbreviation |

Select some text, press `<leader>le`, type something like `div.card>ul>li*3`, and
it expands around the selection.

### It needs a language server

**nvim-emmet is not a standalone expander.** `wrap_with_abbreviation` sends an
`emmet/expandAbbreviation` **LSP request** and silently returns if nothing
answers — no error, no message, the key just does nothing.

That is exactly what happened until `emmet_language_server` was added to
`ensure_servers` in [lsp.md](lsp.md): the plugin was installed, the keymap was
mapped, and the emmet key had never once worked.

The filetype list above is `emmet-language-server`'s own, minus templating
languages this config has no other support for. It previously omitted
`htmlangular`, `scss` and `less` — three filetypes where the server *does*
attach but the keymap did not even exist.

> **This key used to be `<leader>xe`, and that was a bug** — one this page
> already described and lived with: `<leader>x` alone is "save and quit" from
> [keymaps.md](keymaps.md), so a *complete* mapping was also the *prefix* of
> `<leader>xe`, and Neovim could not fire it until `timeoutlen` (400ms) expired.
> Every save-and-quit in an emmet filetype stalled.
>
> It is now `<leader>le`, in the `<leader>l` language-server group alongside
> `<leader>lf` (format) and `<leader>ld` / `<leader>lq` (diagnostics — which
> moved off `<leader>x*` for exactly the same reason). `<leader>l` is not itself
> a mapping, so nothing in that group is ambiguous. See [lsp.md](lsp.md).

## rainbow-delimiters.nvim

Loads on `BufReadPost` / `BufNewFile` with no configuration.

Colours matching bracket pairs by nesting depth using treesitter's parse tree —
so a `}` is visibly the partner of a specific `{`. Works in every language with a
treesitter parser installed; see [treesitter.md](treesitter.md).

**Keymaps:** none.
