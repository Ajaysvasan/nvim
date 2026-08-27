# Inactive modules

Files present in `lua/ajay/` that are **not loaded** by `init.lua` or
`plugins.lua`. Nothing in them runs.

They're documented here so it's obvious at a glance what's dead weight, what's
superseded, and what's a feature waiting to be wired up.

| File | Status | Why |
|---|---|---|
| `autoformat.lua` | **Superseded** by conform | LSP-based format-on-save |
| `null-ls.lua` | **Superseded** by conform | null-ls is archived upstream |
| `transparency.lua` | **Available, not wired up** | Transparent background toggle |
| `java-creator.lua` | **Available, not wired up** | See [java-creator.md](java-creator.md) |

---

## `autoformat.lua` — superseded

An LSP-only format-on-save implementation: a `BufWritePre` autocmd calling
`vim.lsp.buf.format()` with a filter for clients supporting
`textDocument/formatting`.

**Why it's gone:** [conform.nvim](conform.md) does the same job better. It runs
real standalone formatters (`prettier`, `black`, `stylua`, `google-java-format`)
rather than whatever the language server happens to offer, with per-formatter
arguments, and still falls back to the LSP via `lsp_format = "fallback"` when no
formatter is configured.

**Do not load it.** Two live problems:

1. It defines `:ToggleFormatOnSave`, `<leader>tf`, `<leader>ts` and `<leader>ti`
   — **all four already belong to conform**. Loading both means one silently
   shadows the other and the toggles stop matching reality.
2. It uses `client.supports_method(...)` — the **dot** form, deprecated in
   Neovim 0.11 and **removed in 0.12**. It would error on every save.

## `null-ls.lua` — superseded

Wired `prettier`, `clang_format`, `black`, `isort`, `stylua` as formatters,
`eslint_d` and `ruff` as diagnostics, and `eslint_d` code actions, through
null-ls's fake-LSP bridge.

**Why it's gone:**

- **null-ls is archived upstream.** The maintained fork is `none-ls.nvim`, and
  neither is in this config's plugin list — so this file would `pcall`-fail and
  return immediately anyway.
- conform covers the formatting half.
- Its prettier args (`--no-semi --single-quote`) **directly contradict** the
  conform config (`--semi true --single-quote false`). Running both would flip
  quote style and semicolons back and forth on alternate saves.
- It registers its own `BufWritePre` format autocmd, a second one competing with
  conform's.

If you want the linting half back (`eslint_d` diagnostics beyond what the
`eslint` LSP gives you, or `ruff` for Python), add
[nvimtools/none-ls.nvim](https://github.com/nvimtools/none-ls.nvim) and strip
this file down to the `diagnostics` and `actions` sources only — leave formatting
to conform.

## `transparency.lua` — available, not wired up

Sets `guibg=NONE` on ~20 highlight groups (Normal, NormalNC, SignColumn,
NormalFloat, FloatBorder, Pmenu, CursorLine, LineNr, Folded, VertSplit,
EndOfBuffer, plus NeoTree*, Telescope* and WhichKeyFloat) so your terminal
background — wallpaper, blur, whatever — shows through Neovim.

Provides `:ToggleTransparency` and `<leader>tt`.

**Two things to know before enabling:**

1. Catppuccin has this built in. Setting `transparent_background = true` in
   [colorscheme.lua](colorscheme.md) is the cleaner route — it handles every
   highlight group the theme defines, not a hand-maintained list of 20, and
   survives a `:colorscheme` reload.
2. This module's "off" state hardcodes `#1e1e1e`, which is **not** a Catppuccin
   Frappé colour. Toggling transparency off gives you a background that doesn't
   match the theme.

### If you still want to load it

```lua
-- in plugins.lua, inside the catppuccin spec's config():
require("ajay.colorscheme")
setup_module("ajay.transparency")
```

It must run **after** the colorscheme, since `:colorscheme` resets every
highlight group.

| Key | Action |
|---|---|
| `<leader>tt` | Toggle transparency |

`<leader>t` is the toggle prefix, shared with conform (`tf` `tF` `ts` `ti`) and
gitsigns (`tb` `td`). `tt` is free.

## `java-creator.lua` — available, not wired up

An IntelliJ-style floating GUI for creating Java files from 13 templates
(Class, Record, Spring `@Service`/`@Repository`/`@RestController`, JPA `@Entity`,
JUnit 5 test, …), with package name inferred from the path.

Fully documented, including how to enable it and the `<leader>jn` collision to
resolve first, in **[java-creator.md](java-creator.md)**.

---

## Cleaning up

If you want these gone rather than documented:

```bash
git rm lua/ajay/autoformat.lua lua/ajay/null-ls.lua
```

Both are strictly superseded and neither would load correctly today. Keep
`transparency.lua` and `java-creator.lua` — they work, they're just not wired in.
