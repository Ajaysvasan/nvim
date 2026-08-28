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
`tailwindcss`, `angularls`, `emmet_language_server`

| Server | Attaches to | Note |
|---|---|---|
| `angularls` | `typescript`, `html`, `typescriptreact`, `htmlangular` | **Gated to real Angular workspaces**, see below |
| `emmet_language_server` | `html`, `htmlangular`, `css`, `scss`, `less`, `javascriptreact`, `typescriptreact` | Required by [nvim-emmet](plugins.md) — `<leader>xe` is inert without it |

`mason-lspconfig` is configured with `automatic_enable = { exclude = { "jdtls" } }`
— but **only when it is loaded at all**, see [Mason, on demand](#mason-on-demand).

- `automatic_enable` is the **v2 name**; `automatic_installation` is a no-op now.
- **jdtls is excluded** because [nvim-jdtls](jdtls.md) owns its lifecycle
  entirely — letting mason-lspconfig also `vim.lsp.enable()` it would start two
  competing clients.

## Tools installed by mason-tool-installer

`prettier`, `clang-format`, `black`, `isort`, `stylua`, `google-java-format`,
`shfmt`

`eslint_d` used to be in this list and was removed. It is a daemon for
`nvim-lint` / `null-ls`, and this config has neither: ESLint **diagnostics**
come from the `eslint` language server above, and **fixes** from
`LspEslintFixAll` on `BufWritePre`. It was a package to install and keep
updated that could never affect the editor.

| Setting | Value | Why |
|---|---|---|
| `auto_update` | `false` | Was `true` — that fires a network job on **every** start |
| `run_on_start` | `true` | Missing tools get fetched once — but only on a run where mason is loaded at all |

## Mason, on demand

**Mason is not loaded on startup.** This is the single biggest startup saving in
the config (~13 ms off every launch that opens a file).

### Why it used to cost so much

`mason.nvim`, `mason-lspconfig` and `mason-tool-installer` were listed as
`dependencies` of `nvim-lspconfig`. lazy.nvim loads a plugin's dependencies
*before* the plugin itself, so mason's `opts` ran — a full
`require("mason").setup()` — on `BufReadPre`, before the first file was drawn.
Building the package registry pulls in `mason-registry.sources.github` and
`mason-core.package`, and it happened on **every single launch** to answer a
question that is almost always "everything is already installed, do nothing".

### What replaced it

The dependency list on `nvim-lspconfig` is now just `cmp-nvim-lsp`; the three
mason plugins are their own `lazy = true` specs. The flow inverted:

1. **Ask the cheap question first.** Is each server/tool binary on `PATH`? That
   is a filesystem stat, not a registry build. [`options.lua`](options.md) has
   already put mason's `bin` directory on `PATH`, so mason-installed binaries
   resolve *without mason being loaded*.
2. **Enable what is present** with `vim.lsp.enable()`. On 0.11+ that is all you
   need — nvim-lspconfig ships `cmd` and `root_markers` for all 414 servers in
   its own `lsp/` directory, which `vim.lsp.config` reads off the runtimepath.
   The binary each server needs is read from there too, rather than hardcoded.
   **See the trap below — this step is where it bites.**
3. **Only if something is missing**, load mason and let it install — via
   `vim.schedule`, so it never blocks the first draw. `mason-lspconfig`'s
   `automatic_enable` then picks up whatever it installs, so a fresh machine
   still converges on its own without a restart.

### The trap: `cmd` is not always a table

Step 2 asks "what binary does this server need?" and reads `cmd[1]` out of
`vim.lsp.config[name]`. That works for `pyright`, `clangd` and `lua_ls`.

It does **not** work for any Node-based server. nvim-lspconfig gives those a
`cmd` **function**, so it can prefer a project-local copy:

```lua
cmd = function(dispatchers, config)
  local cmd = 'typescript-language-server'
  if (config or {}).root_dir then
    local local_cmd = vim.fs.joinpath(config.root_dir, 'node_modules/.bin', cmd)
    if vim.fn.executable(local_cmd) == 1 then cmd = local_cmd end
  end
  return vim.lsp.rpc.start({ cmd, '--stdio' }, dispatchers)
end
```

There is no `cmd[1]` to read, and calling the function to find out would
**spawn the server**. The first version of this file returned `nil` there and
the loop skipped those servers — it neither enabled them nor marked anything
missing, so mason never loaded to fix it either.

The result was that **`ts_ls`, `eslint`, `html`, `cssls` and `tailwindcss` were
never started at all**: no completion, no diagnostics, no go-to-definition in
any TypeScript, JavaScript, HTML or CSS buffer. Python, C++ and Lua kept
working, because their `cmd` *is* a table — which is exactly why it never
looked broken.

The fix is a `fallback_bin` map naming the global binary each of those closures
falls back to, plus a startup warning listing any server in `ensure_servers`
whose binary still cannot be determined. **This class of failure must never be
silent again** — that is what the warning is for.

```lua
local fallback_bin = {
  ts_ls = "typescript-language-server",
  eslint = "vscode-eslint-language-server",
  html = "vscode-html-language-server",
  cssls = "vscode-css-language-server",
  tailwindcss = "tailwindcss-language-server",
  angularls = "ngserver",
  jdtls = "jdtls",
}
```

If you add a Node-based server to `ensure_servers`, add it here too — or watch
for the warning, which will tell you exactly that.

Net effect: on a machine where everything is installed, **mason is never loaded
at all** unless you ask for it with `:Mason` or `:MasonSync`.

> `jdtls` is deliberately excluded from the `vim.lsp.enable()` list even when
> present. Mason *installs* it, but [nvim-jdtls](jdtls.md) *starts* it, building
> its own `cmd` with the Lombok javaagent and a per-project workspace. Enabling
> it here would race a second, misconfigured client.

### Trade-offs

- Installing a server through the `:Mason` UI mid-session will not auto-enable it
  until the next launch, unless you also run `:MasonSync`.
- A server whose binary exists but is broken is enabled rather than skipped —
  you get the real error instead of silence, which is usually what you want.

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

### angularls — `root_markers` is not a gate

This is the one override that exists to *stop* a server, not configure it.

angularls ships `root_markers = { "angular.json", "nx.json" }`, which reads like
"only start inside an Angular workspace". It isn't. When no marker matches,
`vim.lsp` leaves `root_dir` **nil and starts the server anyway** in single-file
mode — so a plain React or Node project was spawning an `ngserver` process for
every `.ts`, `.tsx` and `.html` buffer opened.

A `root_dir` **function** is the actual gate. The client starts only if
`on_dir()` is called, so returning without calling it means *"not an Angular
workspace, do not start"*:

```lua
vim.lsp.config("angularls", {
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local start = fname ~= "" and fname or vim.fn.getcwd()
    local root = vim.fs.root(start, { "angular.json", "nx.json" })
    if root then
      on_dir(root)
    end
  end,
})
```

Verified both directions: angularls attaches in a project with `angular.json`
and stays out of one without it. **Reach for this pattern for any server whose
`filetypes` are broader than the projects it belongs in.**

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
`referencesCodeLens.enabled` so the server publishes them.

One call on attach, matching the inlay-hint line above it:

```lua
vim.lsp.codelens.enable(true, { bufnr = bufnr })
```

> **This replaced a hand-rolled refresh loop, and it is both a correctness and a
> performance fix.** The config used to drive refreshes from `BufEnter` +
> `InsertLeave` + `BufWritePost` plus a deferred 800 ms kick, via
> `vim.lsp.codelens.refresh()`. All of that is redundant *and* actively harmful:
>
> - **Neovim 0.12 refreshes code lenses itself.** The codelens provider does
>   `nvim_buf_attach{on_lines, on_reload}` and issues its own
>   internally-debounced request. The manual autocmds were stacking **extra
>   project-wide round trips** on top of the ones Neovim was already making —
>   and for jdtls each one resolves references across the entire project, the
>   most expensive thing an LSP does here. `InsertLeave` fires constantly.
> - **`vim.lsp.codelens.refresh()` is deprecated in 0.12 and removed in 0.13.**
>   It printed a deprecation warning on every single LSP attach.

Gated on `vim.g.codelens_off` (global) and `vim.b[bufnr].codelens_off`, which
[bigfile.lua](bigfile.md) sets on large buffers.

## Commands

| Command | Action |
|---|---|
| `:ToggleCodeLens` | Turn the reference/implementation counts on or off (uses `codelens.enable`/`is_enabled`, the 0.12 API) |
| `:ToggleInlayHints` | Toggle inlay hints for the current buffer |
| `:MasonSync` | Load mason and install anything missing, without waiting for it to be noticed. Use after editing `ensure_servers` / `ensure_tools`. |

## Related

- [cmp.md](cmp.md) — capabilities come from cmp-nvim-lsp
- [jdtls.md](jdtls.md) — Java is handled separately
- [conform.md](conform.md) — formatting, with LSP as the fallback
