# Removed modules and plugins

Everything in `lua/ajay/` is **loaded**, and every plugin in `plugins.lua` is in
use. This page is the one record of what was taken out and why, so it does not
get re-added by accident. The code is recoverable from git history.

## Modules

| File | Why it went |
|---|---|
| `autoformat.lua` | Superseded by [conform](conform.md). It also defined `:ToggleFormatOnSave`, `<leader>tf`, `<leader>ts` and `<leader>ti`, which all belong to conform — loading both meant one silently shadowed the other — and it used the dot-form `client.supports_method()`, removed in Neovim 0.12. |
| `null-ls.lua` | null-ls is archived upstream, conform covers formatting, and its formatter arguments contradicted conform's, so running both flipped style back and forth on alternate saves. |
| `dashboard.lua` | alpha-nvim start screen. Plain `nvim` opens an empty buffer. |
| `neotree.lua` | File tree. netrw, built into Neovim, is the directory browser (`:Ex`). |
| `lazygit.lua` | LazyGit floating window (`<leader>gg`). |
| `copilot.lua` | Copilot suggestions and the `copilot-cmp` source. |
| `jupyter.lua` | molten + image.nvim + jupytext notebook stack, and the `vim.g.enable_notebook` flag. Needed luarocks, ImageMagick and the Python provider. |
| `springboot.lua` | Spring Initializr project creation and run/build/test commands. |
| `java-creator.lua` | IntelliJ-style "new Java class" dialog (~1,100 lines). |
| `tscontext.lua` | nvim-treesitter-context sticky header and nvim-navic winbar breadcrumb. |

## Plugins with no module file

| Plugin | Why it went |
|---|---|
| catppuccin, darcula-dark.nvim | Three themes were installed and eagerly loaded for a switcher that was not used. One theme remains — see [colorscheme.md](colorscheme.md). |
| nvim-autopairs | Auto-pairing guesses wrong when typing into existing code, and "type the closing character to skip over it" silently swallows keystrokes. Typing both halves is predictable. |
| persistence.nvim | [harpoon](harpoon.md) already persists the working set, per cwd. |
| log-highlight.nvim | Syntax highlighting for `.log` files. |
| nvim-ts-context-commentstring | Only useful for embedded languages — JSX in `.tsx`, `<script>` in `.html`. With the web stack gone, every remaining filetype gets the same result from its plain `commentstring`. |

## The web stack

JavaScript, TypeScript, React, Angular, HTML and CSS support was removed as a
whole:

- **Language servers:** `ts_ls`, `eslint`, `html`, `cssls`, `tailwindcss`,
  `angularls`, `emmet_language_server`, and `lemminx` (XML).
- **Formatting:** prettier and biome, and their per-project detection in
  conform.
- **Treesitter parsers:** javascript, typescript, tsx, html, css, scss, angular.
- **Debugging:** the `pwa-node` / `pwa-chrome` adapters and the Node, Jest and
  Chrome launch configurations.
- **Snippets:** the HTML `!` boilerplate and the JSX tag snippets.
- **Plugins:** nvim-emmet.

To bring a language back, follow [api.md](api.md)'s recipe for adding one.

> **If a removed server still attaches** after pulling this config onto a
> machine that had the old one: `lsp.lua` only enables the servers listed in its
> `ensure_servers`, so it will not — but the Mason packages are still on disk.
> Remove them with `:MasonUninstall <name>`.
