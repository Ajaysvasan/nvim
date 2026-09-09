# Removed and superseded modules

Everything in `lua/ajay/` is now **loaded**. This page is the record of what was
removed and why, so it does not get re-added by accident.

| File | Fate |
|---|---|
| `autoformat.lua` | **Deleted** — superseded by [conform](conform.md) |
| `null-ls.lua` | **Deleted** — null-ls is archived upstream |
| `transparency.lua` | **Now live** — rewritten, see [transparency.md](transparency.md) |
| `java-creator.lua` | **Now live** — wired to the jdtls spec, see [java-creator.md](java-creator.md) |

Both deletions are recoverable from git:

```bash
git checkout HEAD~1 -- lua/ajay/autoformat.lua
```

---

## `autoformat.lua` — deleted

An LSP-only format-on-save implementation: a `BufWritePre` autocmd calling
`vim.lsp.buf.format()` with a filter for clients supporting
`textDocument/formatting`.

**Why it went.** [conform.nvim](conform.md) does the same job better — real
standalone formatters (`prettier`, `black`, `stylua`, `google-java-format`)
rather than whatever the language server happens to offer, with per-formatter
arguments, and it still falls back to the LSP via `lsp_format = "fallback"`.

It was also not merely redundant but **actively dangerous to load**:

1. It defined `:ToggleFormatOnSave`, `<leader>tf`, `<leader>ts` and `<leader>ti`
   — **all four already belong to conform**. Loading both meant one silently
   shadowed the other and the toggles stopped matching reality.
2. It used `client.supports_method(...)` — the **dot** form, deprecated in
   Neovim 0.11 and **removed in 0.12**. It would have errored on every save.

## `null-ls.lua` — deleted

Wired `prettier`, `clang_format`, `black`, `isort`, `stylua` as formatters,
`eslint_d` and `ruff` as diagnostics, and `eslint_d` code actions, through
null-ls's fake-LSP bridge.

**Why it went:**

- **null-ls is archived upstream.** The maintained fork is `none-ls.nvim`, and
  neither is in the plugin list — so the file would `pcall`-fail and return
  immediately anyway.
- conform covers the formatting half.
- Its prettier args (`--no-semi --single-quote`) **directly contradicted** the
  conform config (`--semi true --single-quote false`). Running both would have
  flipped quote style and semicolons back and forth on alternate saves.
- It registered its own `BufWritePre` format autocmd, competing with conform's.

**If you want the linting half back** — `eslint_d` diagnostics beyond what the
`eslint` LSP gives you, or `ruff` for Python — add
[nvimtools/none-ls.nvim](https://github.com/nvimtools/none-ls.nvim) and register
only the `diagnostics` and `code_actions` sources. Leave formatting to conform.
