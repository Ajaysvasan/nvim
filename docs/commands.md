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
| `:ToggleFormatOnSave` | conform | Global format-on-save toggle |
| `:ToggleFormatOnSaveBuffer` | conform | Buffer-local toggle |
| `:FormatStatus` | conform | Report both toggle states |
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
| `:BigFileStatus` | [bigfile](bigfile.md) | Size, line count, whether protection kicked in, and the current threshold |
| `:BigFileOff` | bigfile | Lift large-file protections for this buffer — restarts treesitter and syntax |

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
| `:JdtlsRescanJDKs` | jdtls | Re-scan installed JDKs. Only needed after installing one mid-session — the scan is cached because it costs ~150 ms per JDK |
| `:JdtUpdateConfig` | jdtls *(plugin built-in)* | Re-import `pom.xml` / `build.gradle` |
| `:SpringBootCreate` | [springboot](springboot.md) | Create a project via Spring Initializr |
| `:SpringBootRun` | springboot | `./mvnw spring-boot:run` / `./gradlew bootRun` |
| `:SpringBootBuild` | springboot | `./mvnw clean install` / `./gradlew build` |
| `:SpringBootTest` | springboot | `./mvnw test` / `./gradlew test` |
| `:JavaNew` | [java-creator](java-creator.md) | New Java file GUI (`<leader>jN`); available once a Java file is open |

## Copilot

| Command | Module | Action |
|---|---|---|
| `:CopilotToggle` | [copilot](copilot.md) | Enable/disable globally, **persisted across restarts** |
| `:CopilotStatus` | copilot | Show status |
| `:Copilot auth` | copilot *(plugin built-in)* | Sign in |

## Notebooks — only when `vim.g.enable_notebook = true`

| Command | Module | Action |
|---|---|---|
| `:NewNotebook [path]` | [jupyter](jupyter.md) | Create a valid blank `.ipynb` and open it |
| `:MoltenInit` | jupyter *(plugin built-in)* | Start the Jupyter kernel |
| `:UpdateRemotePlugins` | *(Neovim built-in)* | Required after installing molten |

## Appearance

| Command | Module | Action |
|---|---|---|
| `:ToggleTransparency` | [transparency](transparency.md) | Toggle transparent background (`<leader>tt`) |

## Plugin-provided commands you'll use often

| Command | Plugin |
|---|---|
| `:Lazy` | lazy.nvim — plugin state, `:Lazy sync`, `:Lazy profile` |
| `:Mason` | mason.nvim — install/update LSPs, formatters, DAP adapters |
| `:Neotree` | neo-tree |
| `:Telescope <picker>` | telescope |
| `:LazyGit` | lazygit.nvim |
| `:Gitsigns toggle_*` | gitsigns — `toggle_signs`, `toggle_numhl`, `toggle_linehl`, `toggle_word_diff` |
| `:UndotreeToggle` | undotree |
| `:DapContinue` / `:DapToggleBreakpoint` / `:DapNew` | nvim-dap |
| `:LspInfo` / `:LspRestart` | Neovim built-in on 0.11+ |
| `:checkhealth` | Neovim built-in |
