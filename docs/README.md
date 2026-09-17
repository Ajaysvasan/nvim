# Documentation index

> ### You are on the `minimal` branch
>
> This branch strips the config down to a core editing setup. Relative to `main`
> it removes **neo-tree**, **lazygit**, the whole **Jupyter/molten/image.nvim**
> notebook stack, **nvim-autopairs**, **nvim-emmet**, the **web language servers**
> (`ts_ls`, `eslint`, `html`, `cssls`, `tailwindcss`, `angularls`,
> `emmet_language_server`) and the Java IDE-clone modules (`java-creator.lua`,
> `springboot.lua`).
>
> **Kept:** jdtls, DAP, and language servers for Python, Java, C, C++, Go and
> Rust — plus `lua_ls`, without which this config could not be edited comfortably.
> Also removed: **nvim-treesitter-context** + **nvim-navic** (the sticky
> class/method header and the winbar breadcrumb), **log-highlight.nvim**,
> **alpha-nvim** (the start screen), **copilot.lua** + **copilot-cmp** —
> agentic AI work happens in a dedicated tool, not in the editor — and
> **persistence.nvim**, since [harpoon](harpoon.md) already is the working set.
>
> `netrw` is re-enabled to replace neo-tree, `rust`/`rust_analyzer` are new, and
> **which-key** is added.
>
> Pages describing removed modules were deleted. Where a removed plugin still
> explains *why* something is the way it is, the reference is kept as history and
> labelled as such.

One page per module in `lua/ajay/`. Each page covers **what the module does**,
**which settings are enabled and why**, and **every keymap it defines**.

## Start here

- **[keymap-reference.md](keymap-reference.md)** — the complete cheat sheet, every mapping in one table
- **[commands.md](commands.md)** — every custom `:Command` this config defines
- **[api.md](api.md)** — **extending this config**: module contract, `vim.g` /
  `vim.b` extension points, recipes for adding a language / plugin / keymap, and
  the invariants that fail silently if you break them. Start here if you are
  making changes rather than just using it.

## Core

| Page | Module | What it covers |
|---|---|---|
| [init.md](init.md) | `init.lua` | Entry point, leader keys, feature flags |
| [options.md](options.md) | `options.lua` | Editor settings, clipboard, fold/cursor persistence |
| [keymaps.md](keymaps.md) | `keymaps.lua` | Plugin-free mappings: windows, motion, run-file, CMake |
| [whichkey.md](whichkey.md) | `whichkey.lua` | which-key prefix hints, and what `delay` is *not* |
| [bigfile.md](bigfile.md) | `bigfile.lua` | Large-file protection — loaded eagerly, before plugins |
| [compat.md](compat.md) | `compat.lua` | Running one config on both Neovim 0.11 and 0.12 |
| [plugins.md](plugins.md) | `plugins.lua` | The lazy.nvim spec and every load trigger |

## UI

| Page | Module | What it covers |
|---|---|---|
| [colorscheme.md](colorscheme.md) | `colorscheme.lua` | VS Code Dark+; the other themes are commented out, ready to uncomment |
| [icons.md](icons.md) | `icons.lua` | Nerd Font glyphs defined by codepoint |
| [transparency.md](transparency.md) | `transparency.lua` | Transparent-background toggle |
| [qol.md](qol.md) | `plugins.lua` inline | lualine, indent guides, undotree, rainbow delimiters |

## Editing & language support

| Page | Module | What it covers |
|---|---|---|
| [lsp.md](lsp.md) | `lsp.lua` | Mason, servers, diagnostics, shared `LspAttach`, CodeLens |
| [cmp.md](cmp.md) | `cmp.lua` | Completion, LuaSnip, custom snippets |
| [treesitter.md](treesitter.md) | `treesitter.lua` | Highlighting, indent, textobjects (`main` branch) |
| [conform.md](conform.md) | `conform.lua` | Formatting and format-on-save |
| [comment.md](comment.md) | `comment.lua` | Comment toggling and the `Ctrl+/` story |
| [telescope.md](telescope.md) | `telescope.lua` | Fuzzy finder and all `<leader>f` mappings |
| [harpoon.md](harpoon.md) | `harpoon.lua` | Quick file marks |

## Git

| Page | Module | What it covers |
|---|---|---|
| [gitsigns.md](gitsigns.md) | `gitsigns.lua` | Gutter signs, hunk staging, blame |

## Debugging

| Page | Module | What it covers |
|---|---|---|
| [dap.md](dap.md) | `dap.lua` | Python, Go, C/C++, Rust, Java debugging |

## Java

| Page | Module | What it covers |
|---|---|---|
| [jdtls.md](jdtls.md) | `jdtls.lua` | JDK discovery, Lombok, workspaces, Java refactors |

## Optional / diagnostic

| Page | Module | What it covers |
|---|---|---|
| [doctor.md](doctor.md) | `doctor.lua` | `:AjayDoctor` |
| [performance.md](performance.md) | — | Every speed decision in one place: startup, navigation, responsiveness |
| [inactive-modules.md](inactive-modules.md) | — | Record of removed modules (`autoformat.lua`, `null-ls.lua`) and why |
