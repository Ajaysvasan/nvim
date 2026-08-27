# `conform.lua` — formatting

[conform.nvim](https://github.com/stevearc/conform.nvim). **The only formatter
in this config.** `null-ls.lua` and `autoformat.lua` are superseded and not
loaded — see [inactive-modules.md](inactive-modules.md).

Loads on `BufWritePre`, `:ConformInfo`, `:Format`, or `<leader>lf`.

## Formatters by filetype

| Filetype | Formatter |
|---|---|
| `lua` | `stylua` |
| `python` | `isort` then `black` (imports sorted first, then reformat) |
| `javascript`, `javascriptreact`, `typescript`, `typescriptreact` | `prettier` |
| `html`, `css`, `scss`, `json`, `jsonc`, `yaml`, `markdown` | `prettier` |
| `c`, `cpp` | `clang_format` |
| `java` | `google-java-format` |
| `sh`, `bash` | `shfmt` |

All of these are installed by `mason-tool-installer` — see [lsp.md](lsp.md).

## Format on save

`format_on_save` is a **function**, not a table, so it can bail out:

```lua
if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then return end
return { timeout_ms = 3000, lsp_format = "fallback" }
```

- Two independent kill switches: global (`vim.g`) and per-buffer (`vim.b`)
- `lsp_format = "fallback"` — if no formatter is configured for the filetype,
  fall back to the LSP's own formatter. This is the modern spelling;
  `lsp_fallback = true` is the legacy name conform maps to it internally, written
  out here so it doesn't silently change meaning when the shim goes.
- `timeout_ms = 3000` — `google-java-format` on a large file is slow enough to
  need it

## Formatter arguments and why

| Formatter | Args | Why |
|---|---|---|
| `stylua` | `--indent-type Spaces --indent-width 2` | Lua files in this config are 2-space, unlike the global `shiftwidth = 4` |
| `prettier` | `--tab-width 2 --use-tabs false --single-quote false --trailing-comma es5 --semi true` | Web files are 2-space, double-quoted, semicolons on |
| `black` | `--line-length 88` | Black's own default, stated explicitly |
| `google-java-format` | `--skip-removing-unused-imports --skip-sorting-imports` | **See below** |

## The Java import-deletion fix

This is the most important thing in the file.

`google-java-format` rewrites imports **by default** — two separate behaviours,
both on unless disabled:

- removes imports it thinks are unused
- re-sorts the remaining ones

The problem is that it does this **with no classpath, looking at one file in
isolation**. It deletes any import whose simple name it can't find an AST
reference to in that single file. It has no idea what Lombok generates, what a
wildcard import pulls in, or what another module in your project defines.

`jdtls` has the full project classpath and knows the truth. So on every save,
the dumber tool was overwriting the smarter one — imports silently vanishing
from Spring Boot entities.

Sorting is disabled for the same reason: `gjf` sorts ASCIIbetically into a single
block, while jdtls uses the `importOrder` set in [jdtls.lua](jdtls.md) (`java`,
`javax`, `jakarta`, `org`, `com`). They disagreed, so imports got reshuffled on
every write.

**Net effect:** `google-java-format` now only touches whitespace and line breaks.
Imports belong to jdtls — use `<leader>jo` to organize them deliberately.

## Keymaps

| Key | Mode | Action |
|---|---|---|
| `<leader>lf` | n, v | Format buffer, or the visual range |
| `<leader>tf` | n | Toggle format-on-save **globally** |
| `<leader>tF` | n | Toggle format-on-save for the **current buffer only** |
| `<leader>ts` | n | Show format-on-save status (global + buffer) |
| `<leader>ti` | n | `:ConformInfo` — which formatter would run here, and is it installed |

## Commands

| Command | Action |
|---|---|
| `:Format` | Format the buffer, or a `:'<,'>Format` range. Async. |
| `:ToggleFormatOnSave` | Global toggle |
| `:ToggleFormatOnSaveBuffer` | Buffer-local toggle |
| `:FormatStatus` | Report both toggle states |
| `:ConformInfo` | conform's own diagnostic view (plugin built-in) |

## Related

- [lsp.md](lsp.md) — `ts_ls` formatting is disabled so prettier owns JS/TS
- [jdtls.md](jdtls.md) — Java imports
