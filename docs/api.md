# API & extension guide

For someone who wants to **use this config and change it** — what the moving
parts are, which knobs are meant to be turned, and which invariants will bite
you if you break them.

New here? Read [init.md](init.md) first for the load order, then this.

---

## 1. Module contract

Everything lives in `lua/ajay/`. There are exactly **two shapes**, and mixing
them up is the most common way to break the config.

### Shape A — `M.setup()` modules (most of them)

Return a table with a `setup` function. They register things (keymaps,
commands, autocmds) but do **nothing** on `require`.

```lua
local M = {}
function M.setup()
  -- keymaps, commands, autocmds
end
return M
```

Loaded from a plugin spec via the `setup_module()` helper in `plugins.lua`:

```lua
config = function()
  setup_module("ajay.telescope")
end,
```

`setup_module()` is not decoration — it turns three silent failures into real
messages: module missing, module returned a non-table (almost always a file
truncated before its `return M`), and module has no `setup`.

### Shape B — side-effect modules

Run their work at `require` time and return nothing. Used where there is no
meaningful "later":

`cmp` · `colorscheme` · `dap` · `keymaps` · `lsp` · `options` · `plugins` · `treesitter`

```lua
config = function()
  require("ajay.lsp")   -- no setup_module(), no .setup()
end,
```

> **Rule:** if a module returns `M`, call it through `setup_module()`. If it does
> not, call `require()` directly. `setup_module()` on a Shape B module reports
> "has no setup() function"; `.setup()` on one errors with "attempt to index a
> boolean value".

---

## 2. Extension points — `vim.g.*`

Set these in `init.lua` **before** `require("ajay.plugins")`.

| Flag | Default | Effect |
|---|---|---|
| `vim.g.have_nerd_font` | `true` | `false` swaps every glyph for ASCII ([icons.md](icons.md)) and disables lualine icons |
| `vim.g.enable_notebook` | `false` | Enables the molten/image.nvim/jupytext stack ([jupyter.md](jupyter.md)). Off by default because it needs luarocks + ImageMagick and is the #1 fresh-machine build failure |
| `vim.g.jdtls_java_home` | *(auto)* | Skip JDK autodetection entirely and use this JDK to run jdtls ([jdtls.md](jdtls.md)) |
| `vim.g.ts_disabled_langs` | `{}` | `{ markdown = true }` falls back to Vim regex syntax for that language ([treesitter.md](treesitter.md)) |
| `vim.g.codelens_off` | `false` | Global CodeLens kill switch (also `:ToggleCodeLens`) |
| `vim.g.disable_autoformat` | *(from disk)* | Global format-on-save kill switch. **Restored from `stdpath("data")/format_on_save_state` at load** — prefer `:ToggleFormatOnSave`, which persists it ([conform.md](conform.md)) |
| `vim.g.transparent_background` | `false` | Driven by `<leader>tt` / `:ToggleTransparency` ([transparency.md](transparency.md)) |

Everything else the config sets (`mapleader`, `clipboard`, `loaded_*_provider`,
`molten_*`, `lazygit_*`) is internal — changing it is fine, but it is
configuration, not an API.

---

## 3. Buffer-local contract — `vim.b.*`

The important cross-module protocol. If you add a feature that does per-buffer
work, **honour `vim.b.bigfile`**.

| Flag | Set by | Read by | Meaning |
|---|---|---|---|
| `vim.b.bigfile` | [bigfile.lua](bigfile.md) at `BufReadPre` | treesitter, lsp, cmp, jdtls, jupyter, options | This buffer is too large for per-keystroke work. **Do nothing expensive.** |
| `vim.b.disable_autoformat` | user / bigfile | conform | Skip format-on-save for this buffer only. **OR'd with the global** — `vim.g.disable_autoformat` wins, so clearing this does not re-enable formatting while the global is off ([conform.md](conform.md)) |
| `vim.b.codelens_off` | bigfile | lsp | Never request code lenses here |
| `vim.b.ajay_codelens_on` | `compat.codelens` | compat internal | 0.11 shim state — do not set by hand |

```lua
-- The pattern every per-buffer feature must follow:
if vim.b[buf].bigfile then return end
```

This is not optional politeness. `bigfile.lua` exists because several
subsystems each do O(file) work *per edit*; one module ignoring the flag is
enough to reintroduce a multi-second freeze on every keystroke.

---

## 4. Recipes

### Add a language

Four files, in this order. Go is the worked example — copy its shape.

**1. Language server** — `lua/ajay/lsp.lua`

```lua
local ensure_servers = { ..., "gopls" }
```

Then *only if it needs it*, add a settings override:

```lua
vim.lsp.config("gopls", { settings = { gopls = { staticcheck = true } } })
```

> **Only override what needs overriding.** nvim-lspconfig already ships `cmd`,
> `filetypes` and `root_markers` for all 414 servers. `ts_ls`, `eslint`, `html`,
> `cssls`, `lemminx` and `emmet_language_server` have **no** override block here
> and work fine. Hardcoding `cmd` is how a Mason binary that is not yet on
> `PATH` silently fails to start.

> ⚠️ **The `fallback_bin` trap.** Startup decides whether a server is installed
> by reading `cmd[1]` from `vim.lsp.config[name]`. Node-based servers ship `cmd`
> as a **function** (so they can prefer a project-local `node_modules/.bin` copy),
> so there is no `cmd[1]` to read. Those must be listed in the `fallback_bin`
> table or they are **never enabled and never installed**, silently. This once
> disabled `ts_ls`, `eslint`, `html`, `cssls` and `tailwindcss` for weeks. A
> startup warning now names any server it cannot resolve — do not ignore it.

**2. Formatter** — `lua/ajay/conform.lua` + `ensure_tools` in `lsp.lua`

```lua
-- conform.lua
go = { "goimports", "gofumpt" },   -- import-fixer first, then formatter
-- lsp.lua
local ensure_tools = { ..., "goimports", "gofumpt" }
```

If the LSP formats well enough, **add nothing** — `format_on_save` sets
`lsp_format = "fallback"`, so any filetype with no `formatters_by_ft` entry uses
its language server automatically. That is exactly why XML has no entry.

If conform *does* own the filetype, disable the server's formatter so a stray
`vim.lsp.buf.format()` cannot fight it:

```lua
if client.name == "gopls" then
  client.server_capabilities.documentFormattingProvider = false
  client.server_capabilities.documentRangeFormattingProvider = false
end
```

**3. Treesitter parser** — `lua/ajay/treesitter.lua`

```lua
local ensure_installed = { ..., "go" }
```

**4. Debug adapter** *(optional)* — `lua/ajay/dap.lua`

`mason-nvim-dap`'s `ensure_installed` takes **its own alias names**, not Mason
package names — `javadbg`, not `java-debug-adapter`. Wrong name = silent no-op.
See `mason-nvim-dap/mappings/source.lua` for the list.

Nothing else is needed: Mason installs on demand the next time a matching file
opens ([lsp.md](lsp.md#mason-on-demand)).

### Add a plugin

```lua
{
  "author/plugin.nvim",
  keys = { "<leader>xx" },     -- see the invariant below
  cmd = { "PluginCommand" },
  config = function()
    setup_module("ajay.myplugin")
  end,
},
```

> ⚠️ **Every lhs your module maps must appear in `keys`, and every command it
> defines must appear in `cmd`.** lazy.nvim only creates a load-trigger for what
> is *listed*. A mapping the module makes but the spec does not name is **dead**
> until something else happens to load the plugin. This has bitten this config
> four separate times — telescope (20 dead maps), harpoon (`<A-n>` vs `<C-n>`),
> and conform twice (`:ToggleFormatOnSave`, then `:FormatStatus`, both `E492`).

### Add a keymap

Put it in the module that owns the feature, never in `keymaps.lua` — that file
is only for mappings needing **no plugin**.

> ⚠️ **Never make a complete mapping the prefix of another.** Neovim cannot act
> on an ambiguous sequence until `timeoutlen` (400 ms) expires. `<leader>w` is
> "save"; adding `<leader>wa` made **every save** in an LSP buffer wait 400 ms.
> Check before adding:
> ```vim
> :verbose nmap <leader>x
> ```
> `<leader>l` is the LSP/format group, `<leader>t` toggles, `<leader>d` DAP —
> see [keymap-reference.md](keymap-reference.md) for the full prefix map.

---

## 5. Public functions

| Module | Function | Use |
|---|---|---|
| `ajay.compat` | `at_least(ver)` | Version gate — prefer `has` |
| | `has[feature]` | **Capability probe**, e.g. `has["lsp.codelens.enable"]` |
| | `pick(feat, a, b)` | Inline two-way value choice |
| | `needs(feat)` | Returns a `cond` function for a lazy spec |
| | `codelens.enable/is_enabled` | 0.11↔0.12 CodeLens shim |
| `ajay.icons` | `diagnostics` `tree` `git` `dap` | Glyph tables, built from codepoints |
| | `preview()` | Render every glyph to check the font |
| `ajay.jdtls` | `detected_jdks()` | Every JDK found, memoised + disk-cached |
| `ajay.java-creator` | `open()` | The new-Java-file GUI |
| `ajay.springboot` | `run_app()` `build_project()` `run_tests()` `create_project()` | |
| `ajay.transparency` | `toggle()` | |
| `ajay.bigfile` | `max_bytes` `max_line_length` | Thresholds — assign to change them |

### Prefer `compat.has` over version numbers

```lua
-- Good: asks what Neovim can actually do
if compat.has["lsp.codelens.enable"] then ... end

-- Bad: 0.12 is a moving target; nightlies disagree with each other
if vim.fn.has("nvim-0.12") == 1 then ... end
```

See [compat.md](compat.md).

---

## 6. Diagnosing your changes

| Command | Answers |
|---|---|
| `:AjayDoctor` | Font, icons, clipboard, keycodes, which compat arm resolved |
| `:checkhealth vim.lsp` | Server attached? (works on 0.11 and 0.12; `:LspInfo` does not) |
| `:Lazy profile` | What each plugin cost at startup |
| `:ConformInfo` | Which formatters conform found for this buffer |
| `:TSStatus` | Parser installed, highlighting on, duplicate parsers |
| `:BigFileStatus` | Is this buffer gated, and why |
| `:FormatStatus` | Format-on-save state, global + buffer + **saved on disk** |
| `:JdtlsLog` | Eclipse-side log — OOMs and classpath failures land here, never in `:messages`. *Java buffers only* |
| `<leader>fk` | Searchable picker of every live mapping |

> Commands registered by a lazy-loaded module only exist once that module has
> loaded. `:JdtlsLog`, `:JavaNew` and `:SpringBoot*` need a **Java buffer open**;
> `:ConformInfo` and `:FormatStatus` load conform on demand via its `cmd` list.

Startup cost:

```bash
nvim --headless --startuptime /tmp/st.log -c 'qa' && sort -k2 -rn /tmp/st.log | head -20
```

See [performance.md](performance.md) for the benchmark methodology, including
why previewer timings **must** be taken in a real terminal — Telescope's
previewer never renders under `--headless`, so a headless run reports zero and
is simply wrong.

---

## 7. Invariants

Break these and something fails *silently*, which is the whole reason they are
written down.

1. **Honour `vim.b.bigfile`** in anything doing per-buffer or per-keystroke work.
2. **Every mapped lhs goes in the spec's `keys`; every command in `cmd`.**
3. **No complete mapping may be the prefix of another** (400 ms `timeoutlen` stall).
4. **Node-based servers need a `fallback_bin` entry**, or they are never enabled.
5. **`mason-nvim-dap` takes its own aliases** (`javadbg`), not Mason package names.
6. **Shape A modules go through `setup_module()`; Shape B through `require()`.**
7. **Forward-declare a `local` that an earlier closure assigns.** A `local`
   declared later in the file is not in scope for a closure defined above it —
   the assignment silently creates a **global** instead. This has happened twice
   here (`open_type_stage` in java-creator, `cached_min` in jdtls).
8. **jdtls is excluded from `automatic_enable`** — nvim-jdtls owns its lifecycle.
   Letting mason-lspconfig also enable it starts two competing clients.
9. **Only override what needs overriding** in `vim.lsp.config`.

---

## Related

- [init.md](init.md) — load order
- [plugins.md](plugins.md) — the full spec list and lazy-loading strategy
- [performance.md](performance.md) — every speed decision, measured
- [keymap-reference.md](keymap-reference.md) — every mapping, by prefix
- [compat.md](compat.md) — the 0.11 / 0.12 differences
