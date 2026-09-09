# `conform.lua` — formatting

[conform.nvim](https://github.com/stevearc/conform.nvim). **The only formatter
in this config.** `null-ls.lua` and `autoformat.lua` were superseded and have
been deleted — see [inactive-modules.md](inactive-modules.md) for why.

Loads on `BufWritePre`, `:ConformInfo`, `:Format`, or `<leader>lf`.

## Formatters by filetype

| Filetype | Formatter |
|---|---|
| `lua` | `stylua` |
| `python` | `isort` then `black` (imports sorted first, then reformat) |
| `javascript`, `javascriptreact`, `typescript`, `typescriptreact` | `prettier` |
| `html`, **`htmlangular`**, `css`, `scss`, `json`, `jsonc`, `yaml`, `markdown` | `prettier` |
| `c`, `cpp` | `clang_format` |
| `java` | `google-java-format` |
| `sh`, `bash` | `shfmt` |

### Why `htmlangular` is listed separately

Angular templates are their **own filetype**, so the `html` entry never reached
them — `<leader>lf` and format-on-save were both silent no-ops in every
`.component.html`.

Plain `prettier` is enough; no `--parser angular` needed. Its html parser
already handles `*ngIf`, `[(ngModel)]`, `(click)`, `{{ interpolation }}` and
Angular 17 `@if` / `@for` control-flow blocks — verified byte-identical output
between the two parsers on all of them.

All of these are installed by `mason-tool-installer` — see [lsp.md](lsp.md).

## Format on save

`format_on_save` is a **function**, not a table, so it can bail out:

```lua
if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then return end
return { timeout_ms = 3000, lsp_format = "fallback" }
```

- Two kill switches, combined with **OR**: global (`vim.g`) and per-buffer
  (`vim.b`). See [precedence](#precedence-the-global-is-a-master-switch).
- `lsp_format = "fallback"` — if no formatter is configured for the filetype,
  fall back to the LSP's own formatter. This is the modern spelling;
  `lsp_fallback = true` is the legacy name conform maps to it internally, written
  out here so it doesn't silently change meaning when the shim goes.
- `timeout_ms = 3000` — `google-java-format` on a large file is slow enough to
  need it

### Precedence: the global is a master switch

The two flags are **not** independent in effect. `format_on_save` returns early
if *either* is set, so:

| Global | Buffer | Saves format? |
|---|---|---|
| ENABLED | ENABLED | **yes** |
| **DISABLED** | ENABLED | no — global wins |
| **DISABLED** | DISABLED | no |
| ENABLED | **DISABLED** | no — buffer excluded |

Turning the global off does **not** change `vim.b.disable_autoformat` — that
variable stays exactly as it was. But nothing formats while the global is off,
whatever any buffer says. Consequently, `:ToggleFormatOnSaveBuffer` to *enable* a
buffer while the global is off changes nothing observable, so it warns you:

```
✓ Format on save (buffer): ENABLED
  ...but format-on-save is still OFF globally, so this buffer
  will NOT format. Use <leader>tf / :ToggleFormatOnSave.
```

For the same reason `:FormatStatus` reports the **effective** answer, not just
the two flags — printing `Global: DISABLED / Buffer: ENABLED` side by side reads
like the buffer will format, and it will not:

```
Format on save:
  Global : DISABLED ✗  (saved on disk: disabled)
  Buffer : ENABLED ✓  (this session only)

  On save here: WILL NOT FORMAT — the global switch overrides the buffer
```

### The global toggle is remembered across restarts

`vim.g.disable_autoformat` is a plain global, so it used to die with the
session: you turned format-on-save off, quit, reopened, and it was **silently
back on**. That is the worst possible shape for this switch — you turn it off
precisely because a formatter is mangling a file, and the next time you open
that file it mangles it again on the first save.

The global preference is now written to
`stdpath("data")/format_on_save_state`, restored at the top of `M.setup()`, and
reported by `:FormatStatus`:

```
Format on save:
  Global: DISABLED ✗  (saved on disk: disabled)
  Buffer: ENABLED ✓  (this session only)
```

Same one-word-state-file pattern as the Copilot toggle in
[copilot.md](copilot.md), and stored under `stdpath("data")` — **outside this
git repo** — so the preference follows the machine, not the config.

**Only the global toggle persists.** `:ToggleFormatOnSaveBuffer` deliberately
does not: a buffer is a session-scoped thing, and a per-file exception that
silently outlived the session would be much harder to notice than to just set
again.

> Restoring inside `M.setup()` is safe even though this module is lazy-loaded on
> `BufWritePre`. lazy.nvim loads the plugin and runs its `config` first, *then*
> replays the event to the now-loaded plugin — so the flag is already correct
> before conform's own `BufWritePre` handler asks for it.

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
| `:ToggleFormatOnSave` | Global toggle — **persisted**, survives a restart |
| `:ToggleFormatOnSaveBuffer` | Buffer-local toggle — this session only |
| `:FormatStatus` | Report both toggle states, and the value saved on disk |
| `:ConformInfo` | conform's own diagnostic view (plugin built-in) |

## Related

- [lsp.md](lsp.md) — `ts_ls` formatting is disabled so prettier owns JS/TS
- [jdtls.md](jdtls.md) — Java imports
