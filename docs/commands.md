# Custom commands

Every `:Command` this config defines. Neovim and plugin built-ins are not listed
except where noted.

## Diagnostics

| Command | Module | Action |
|---|---|---|
| `:AjayDoctor` | [doctor](doctor.md) | Font / icon / clipboard / keycode diagnostic in a floating window |

## Formatting

| Command | Module | Action |
|---|---|---|
| `:Format` | [conform](conform.md) | Format the buffer or a `:'<,'>Format` range, async |
| `:ToggleFormatOnSave` | conform | Global format-on-save toggle — **persisted to disk, survives a restart** |
| `:ToggleFormatOnSaveBuffer` | conform | Buffer-local toggle — this session only |
| `:FormatStatus` | conform | Report both toggle states plus the value saved on disk |
| `:FormatDetect` | conform | Which formatters this project resolves to, and why. `!` re-scans after adding a config file |
| `:ConformInfo` | conform *(plugin built-in)* | Which formatter would run here, and is it installed |

## LSP

| Command | Module | Action |
|---|---|---|
| `:ToggleCodeLens` | [lsp](lsp.md) | Turn reference/implementation counts on or off |
| `:ToggleInlayHints` | lsp | Toggle inlay hints for the current buffer |
| `:MasonSync` | lsp | Load mason and install any missing servers/tools. Mason is otherwise **not loaded at all** when everything is present — see [Mason, on demand](lsp.md#mason-on-demand). |

## Large files

| Command | Module | Action |
|---|---|---|
| `:BigFile` | [bigfile](bigfile.md) | **Toggle** large-file protection for this buffer (also `<leader>tb`). `:BigFile on\|off\|status` to be explicit. Turning it off restarts treesitter and syntax and re-attaches the language server. |

## Treesitter

| Command | Module | Action |
|---|---|---|
| `:TSStatus` | [treesitter](treesitter.md) | Filetype, resolved language, whether highlighting is ON, whether the language is disabled, and every `parser/*.so` on the runtimepath with its build date — **more than one means a conflict**. Run this first when highlighting misbehaves. |
| `:TSReset` | treesitter | Delete every installed parser so they rebuild on restart. The fix for stale parsers after a branch switch. |
| `:TSUpdate` / `:TSInstall <lang>` | treesitter *(plugin built-in)* | |

## Java

| Command | Module | Action |
|---|---|---|
| `:JdtlsLog` | [jdtls](jdtls.md) | Open this project's Eclipse-side `.metadata/.log` — where the real Java errors are |
| `:JdtlsWipeWorkspace` | jdtls | Delete this project's jdtls workspace; fixes stale classpath errors |
| `:JdtUpdateConfig` | jdtls *(plugin built-in)* | Re-import `pom.xml` / `build.gradle` |

## Appearance

| Command | Module | Action |
|---|---|---|
| `:ToggleTransparency` | [transparency](transparency.md) | Toggle transparent background (`<leader>tt`) |

## Plugin-provided commands you'll use often

| Command | Plugin |
|---|---|
| `:Lazy` | lazy.nvim — plugin state, `:Lazy sync`, `:Lazy profile` |
| `:Mason` | mason.nvim — install/update LSPs, formatters, DAP adapters |
| `:Explore` / `:Lexplore` | **netrw** — Neovim's built-in file browser |
| `:Telescope <picker>` | telescope |
| `:Gitsigns toggle_*` | gitsigns — `toggle_signs`, `toggle_numhl`, `toggle_linehl`, `toggle_word_diff` |
| `:UndotreeToggle` | undotree |
| `:DapContinue` / `:DapToggleBreakpoint` / `:DapNew` | nvim-dap |
| `:checkhealth vim.lsp` | Neovim built-in — attached servers, root dirs, capabilities |
| `:LspInfo` / `:LspRestart` | **nvim-lspconfig, 0.11 only.** lspconfig skips defining these when Neovim has a built-in `:lsp`, which 0.12 does. On 0.12 use `:checkhealth vim.lsp` and `:lsp restart` (`:h :lsp`). |
| `:checkhealth` | Neovim built-in |
