# Documentation index

One page per module in `lua/ajay/`. Each page covers **what the module does**,
**which settings are enabled and why**, and **every keymap it defines**.

## Start here

- **[keymap-reference.md](keymap-reference.md)** — the complete cheat sheet, every mapping in one table
- **[commands.md](commands.md)** — every custom `:Command` this config defines

## Core

| Page | Module | What it covers |
|---|---|---|
| [init.md](init.md) | `init.lua` | Entry point, leader keys, feature flags |
| [options.md](options.md) | `options.lua` | Editor settings, clipboard, fold/cursor persistence |
| [keymaps.md](keymaps.md) | `keymaps.lua` | Plugin-free mappings: windows, motion, run-file, CMake |
| [bigfile.md](bigfile.md) | `bigfile.lua` | Large-file protection — loaded eagerly, before plugins |
| [compat.md](compat.md) | `compat.lua` | Running one config on both Neovim 0.11 and 0.12 |
| [plugins.md](plugins.md) | `plugins.lua` | The lazy.nvim spec and every load trigger |

## UI

| Page | Module | What it covers |
|---|---|---|
| [colorscheme.md](colorscheme.md) | `colorscheme.lua` | Catppuccin + integrations |
| [dashboard.md](dashboard.md) | `dashboard.lua` | alpha-nvim start screen |
| [neotree.md](neotree.md) | `neotree.lua` | File explorer |
| [icons.md](icons.md) | `icons.lua` | Nerd Font glyphs defined by codepoint |
| [transparency.md](transparency.md) | `transparency.lua` | Transparent-background toggle |
| [qol.md](qol.md) | `plugins.lua` inline | lualine, autopairs, indent guides, undotree, emmet, rainbow delimiters |

## Editing & language support

| Page | Module | What it covers |
|---|---|---|
| [lsp.md](lsp.md) | `lsp.lua` | Mason, servers, diagnostics, shared `LspAttach`, CodeLens |
| [cmp.md](cmp.md) | `cmp.lua` | Completion, LuaSnip, custom snippets |
| [copilot.md](copilot.md) | `copilot.lua` | GitHub Copilot with persisted on/off |
| [treesitter.md](treesitter.md) | `treesitter.lua` | Highlighting, indent, textobjects (`main` branch) |
| [conform.md](conform.md) | `conform.lua` | Formatting and format-on-save |
| [comment.md](comment.md) | `comment.lua` | Comment toggling and the `Ctrl+/` story |
| [telescope.md](telescope.md) | `telescope.lua` | Fuzzy finder and all `<leader>f` mappings |
| [harpoon.md](harpoon.md) | `harpoon.lua` | Quick file marks |

## Git

| Page | Module | What it covers |
|---|---|---|
| [gitsigns.md](gitsigns.md) | `gitsigns.lua` | Gutter signs, hunk staging, blame |
| [lazygit.md](lazygit.md) | `lazygit.lua` | LazyGit floating window |

## Debugging

| Page | Module | What it covers |
|---|---|---|
| [dap.md](dap.md) | `dap.lua` | Python, JS/TS, Go, C/C++, Rust, Java debugging |

## Java / Spring Boot

| Page | Module | What it covers |
|---|---|---|
| [jdtls.md](jdtls.md) | `jdtls.lua` | JDK discovery, Lombok, workspaces, Java refactors |
| [springboot.md](springboot.md) | `springboot.lua` | Spring Initializr, run/build/test |
| [java-creator.md](java-creator.md) | `java-creator.lua` | IntelliJ-style new-file GUI, 13 templates |

## Optional / diagnostic

| Page | Module | What it covers |
|---|---|---|
| [jupyter.md](jupyter.md) | `jupyter.lua` | Molten notebook cells (opt-in) |
| [doctor.md](doctor.md) | `doctor.lua` | `:AjayDoctor` |
| [performance.md](performance.md) | — | Every speed decision in one place: startup, navigation, responsiveness |
| [inactive-modules.md](inactive-modules.md) | — | Record of removed modules (`autoformat.lua`, `null-ls.lua`) and why |
