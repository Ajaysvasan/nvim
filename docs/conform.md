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

## Project-aware formatter detection

The formatter table below is the **fallback**, not the whole story. What
actually runs is resolved per project, answering two separate questions.

### 1. Which tool does this project use?

| Filetype | Project has | Runs |
|---|---|---|
| `python` | `[tool.ruff]` in `pyproject.toml`, or `ruff.toml` | `ruff_organize_imports` + `ruff_format` |
| `python` | anything else | `isort` + `black` |
| `js`/`ts`/`jsx`/`tsx`/`json` | `biome.json` | `biome` |
| `js`/`ts`/`jsx`/`tsx`/`json` | anything else | `prettier` |

pytorch is the live example: its `pyproject.toml` declares `[tool.ruff]` and
`[tool.ruff.format]`, so running black there would be the wrong tool entirely.

Only those filetypes route through biome detection — biome cannot parse `html`,
`scss`, `yaml` or `markdown`, so those stay on prettier unconditionally.

> **Detection never selects a tool that is not installed.** Doing so would make
> conform report "formatter unavailable" and silently fall through to the LSP,
> which is worse than using the default. If a project wants a tool you do not
> have, the fallback runs and `:FormatDetect` tells you what to install.

### 2. Does the project state its own style?

**This half was a real bug.** `prepend_args` are passed on the **command line**,
and CLI flags beat a config file for every formatter here. So the personal
defaults in this file silently overrode whatever the project asked for:

| | |
|---|---|
| project's `.prettierrc` | `{ "singleQuote": true, "semi": false }` |
| prettier on its own | `const greeting = 'hello'` |
| **this config, before** | `const greeting = "hello";` |

On a shared repo that means every save rewrites files to one developer's taste —
diff noise, and a failing lint job in the project's own CI.

Style flags are now **conditional**. When the project has its own config, we
pass nothing and let the tool read it:

| Formatter | Suppressed when the project has |
|---|---|
| `prettier` | any `.prettierrc*` / `prettier.config.*`, or a `"prettier"` key in `package.json` |
| `stylua` | `stylua.toml` / `.stylua.toml` |
| `black` | `[tool.black]` in `pyproject.toml` |
| `clang_format` | — never had args; `.clang-format` was always honoured |

Verified: with a project `stylua.toml` asking for tabs, formatting produces
tabs; with none, it produces this config's 2-space default. Same for prettier
in both directions.

> `google-java-format`'s two flags stay **unconditional**, unlike the rest.
> `--skip-removing-unused-imports` and `--skip-sorting-imports` are not a style
> preference — they stop it fighting jdtls over imports, which it would do in
> any project regardless of that project's config. See
> [the import-deletion fix](#the-java-import-deletion-fix).

### Project-local binaries

A pinned formatter version matters: black's output changes between majors
(string normalisation, the magic trailing comma), as does prettier's.

- **prettier** — conform already resolves `node_modules/.bin/prettier` itself,
  so a project pinning prettier 2 is formatted by prettier 2.
- **black / isort / ruff** — conform ships these with a bare `command`, so they
  used whatever Mason installed globally. They now resolve from the project's
  virtualenv first (`.venv/bin`, `venv/bin`, `env/bin`), falling back to the
  global binary.

### Seeing what was detected

`:FormatDetect` reports which formatters this buffer resolves to and why —
detection is invisible when it works, so without this there is no way to answer
"why did that save use black instead of ruff?".

```
Formatters for this buffer:
  isort, black

Detected in this project:
  python tool : black   [project asks for ruff]
  web tool    : prettier

Project states its own style (we pass no style flags):
  prettier    : no
  stylua      : no
  ...

! This project wants ruff, but ruff is not installed.
  Using isort+black instead.  Fix: :MasonInstall ruff
```

`:FormatDetect!` re-scans after you add a config file. Results are cached per
directory — `format_on_save` runs on every write, so detection must not stat the
filesystem each time — and the cache is also cleared on `DirChanged`.

`:FormatStatus` shows the resolved formatter list too.

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
