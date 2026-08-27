# `lsp.lua` — language servers

Mason + mason-lspconfig + nvim-lspconfig, plus one shared `LspAttach` autocmd
that provides every LSP keymap in the config.

> Written for the **Neovim 0.11+ LSP API**. Key changes from the older config:
>
> 1. `client.supports_method(...)` (dot) → `client:supports_method(...)` (colon).
>    The dot form is deprecated in 0.11 and **removed in 0.12**.
> 2. One `LspAttach` autocmd instead of an `on_attach` copy-pasted into every
>    server table.
> 3. Only override what needs overriding — nvim-lspconfig ships `cmd` and
>    `root_markers` for every one of these servers. Hardcoding `cmd` meant a
>    Mason-installed binary that wasn't on `PATH` yet silently failed to start.
> 4. `vim.diagnostic.goto_next/goto_prev` → `vim.diagnostic.jump`.
> 5. Removed the custom `LspRestart` command — 0.11 ships one, and redefining it
>    shadowed the built-in.

## Diagnostics

| Setting | Value | Why |
|---|---|---|
| `signs.text` | Glyphs from [`icons.lua`](icons.md) | Built from codepoints. Literal glyphs here had been stripped to `""`, and an empty sign renders **nothing** with no error — diagnostics just silently stop appearing. |

The `icons` require is a **soft dependency on purpose**:

```lua
local ok_icons, icons = pcall(require, "ajay.icons")
if not ok_icons then
  icons = { diagnostics = { ERROR = "E", WARN = "W", INFO = "I", HINT = "H" } }
  vim.schedule(function() vim.notify("ajay/icons.lua not found - using ASCII diagnostic signs", ...) end)
end
```

`lsp.lua` drives **every** language server, so a missing `ajay/icons.lua` must not
take all of them down — it should cost you pretty gutter symbols, nothing more.
The warning is deferred with `vim.schedule` so it can't abort startup.
| `virtual_text.severity` | `min = ERROR` | Only errors get inline text. Warnings and hints would otherwise cover the code you're reading; they still show in the gutter and on `<leader>xd`. |
| `virtual_text.spacing` | `2` | |
| `float` | `border = "rounded"`, `source = true` | Shows *which* server produced the message — essential when `eslint` and `ts_ls` disagree |
| `severity_sort` | `true` | The worst problem on a line wins the sign |
| `update_in_insert` | `false` | No diagnostic churn while you're mid-word |

## Servers installed by Mason

`clangd`, `pyright`, `jdtls`, `ts_ls`, `eslint`, `html`, `cssls`, `lua_ls`,
`tailwindcss`

`mason-lspconfig` is configured with `automatic_enable = { exclude = { "jdtls" } }`.

- `automatic_enable` is the **v2 name**; `automatic_installation` is a no-op now.
- **jdtls is excluded** because [nvim-jdtls](jdtls.md) owns its lifecycle
  entirely — letting mason-lspconfig also `vim.lsp.enable()` it would start two
  competing clients.

## Tools installed by mason-tool-installer

`prettier`, `eslint_d`, `clang-format`, `black`, `isort`, `stylua`,
`google-java-format`, `shfmt`

| Setting | Value | Why |
|---|---|---|
| `auto_update` | `false` | Was `true` — that fires a network job on **every** start |
| `run_on_start` | `true` | Missing tools get fetched once, at launch |

## Capabilities

```lua
vim.lsp.config("*", { capabilities = capabilities })
```

Built from `make_client_capabilities()` and extended with `cmp_nvim_lsp`'s
(guarded by `pcall`). Applied with the `"*"` wildcard so it reaches **every**
server, including the ones Mason enables automatically.

## Per-server overrides

Only where the defaults aren't right:

### clangd
```
--background-index --clang-tidy --completion-style=detailed --header-insertion=iwyu
```
Background indexing for cross-file navigation, clang-tidy diagnostics inline,
and `iwyu`-style header insertion so it adds the header that actually declares
the symbol.

### pyright
`typeCheckingMode = "basic"` (strict is too noisy on untyped code),
`useLibraryCodeForTypes`, `autoSearchPaths`, `diagnosticMode = "workspace"` so
errors in files you haven't opened still surface.

### lua_ls
`runtime.version = "LuaJIT"`, `diagnostics.globals = { "vim" }` (otherwise every
line of this config is an "undefined global" error), workspace library pointed at
Neovim's runtime files for completion on the `vim.*` API, `checkThirdParty = false`
to stop the "configure workspace?" prompt, telemetry off.

### tailwindcss
`classAttributes` extended to `class`, `className`, `classList`, `ngClass`, plus
the full lint rule set (conflicting classes, invalid `@apply`, variant order).

## The shared `LspAttach` autocmd

Every mapping below is **buffer-local** and only exists in buffers where a
server actually attached.

### Navigation

| Key | Action |
|---|---|
| `gd` | Go to definition |
| `gD` | Go to declaration |
| `gr` | Go to references |
| `gi` | Go to implementation |
| `gt` | Go to type definition |

### Documentation

| Key | Action |
|---|---|
| `K` | Hover documentation |
| `<C-k>` | Signature help |

> ⚠️ `<C-k>` shadows the global "focus window up" mapping from
> [keymaps.md](keymaps.md) inside LSP buffers. Use `<C-w>k` there.

### Actions

| Key | Mode | Action |
|---|---|---|
| `<leader>rn` | n | Rename symbol |
| `<leader>ca` | n, v | Code action |

### Diagnostics

| Key | Action |
|---|---|
| `[d` | Previous diagnostic (with float) |
| `]d` | Next diagnostic (with float) |
| `<leader>xd` | Show diagnostic under cursor |
| `<leader>xq` | Send diagnostics to the location list |

> **Why `<leader>x`:** the old config put these on `<leader>e` / `<leader>q`,
> which shadowed `:q<CR>` from `keymaps.lua` inside every LSP buffer. And the
> whole `<leader>d` prefix belongs to [nvim-dap](dap.md).

### Workspace

| Key | Action |
|---|---|
| `<leader>wa` | Add workspace folder |
| `<leader>wr` | Remove workspace folder |
| `<leader>wl` | List workspace folders |

### CodeLens

| Key | Action |
|---|---|
| `<leader>cl` | Run the code lens under the cursor |

## Per-client behaviour

**`ts_ls` formatting is disabled** (`documentFormattingProvider = false`).
[conform](conform.md) + prettier owns JS/TS formatting; two formatters fighting
over the same buffer produces churn on every save.

**`eslint` auto-fixes on save** via a buffer-local `BufWritePre` autocmd calling
`LspEslintFixAll`, wrapped in `pcall`.

**Inlay hints** are enabled for any server that supports
`textDocument/inlayHint`, using the colon call form required on 0.11+.

**CodeLens** — the IntelliJ-style "3 references / 2 implementations" line above
each class and method. `jdtls.lua` sets `implementationsCodeLens.enabled` and
`referencesCodeLens.enabled` so the server *publishes* them, but **Neovim does
not render code lenses on its own** — nothing appears until something calls
`vim.lsp.codelens.refresh()`. This config wires that up:

- refresh on `BufEnter`, `InsertLeave`, `BufWritePost`
- **deliberately not on `CursorHold`** — for jdtls every refresh is a round trip
  that resolves references across the whole project
- plus one deferred refresh 800ms after attach, because the server usually can't
  answer at attach time (jdtls in particular needs the project imported first)
- all of it gated on `vim.g.codelens_off`

## Commands

| Command | Action |
|---|---|
| `:ToggleCodeLens` | Turn the reference/implementation counts on or off globally |
| `:ToggleInlayHints` | Toggle inlay hints for the current buffer |

## Related

- [cmp.md](cmp.md) — capabilities come from cmp-nvim-lsp
- [jdtls.md](jdtls.md) — Java is handled separately
- [conform.md](conform.md) — formatting, with LSP as the fallback
