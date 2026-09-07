# `compat.lua` — one config, two Neovim versions

This config targets the **Neovim 0.12 API**. `compat.lua` lets it run unchanged
on **0.11** by resolving the handful of places where the two versions disagree —
once, at load time, by asking Neovim what it can actually do.

There is no second copy of the config. There is no `nvim11/` directory. Adding a
version fork would double every future edit and guarantee the two halves drift;
this module exists so that never has to happen.

## Capability probes, not version numbers

`vim.fn.has("nvim-0.12")` answers *"which release is this"*. That is not the
question. The question is *"does `vim.lsp.codelens.enable` exist"*, and the two
come apart constantly:

- **0.12 is unreleased.** A nightly stamped `0.12.0-dev` may predate the commit
  that added the function you are about to call.
- **Features land one at a time**, not in a batch on release day. Between two
  nightlies a week apart `has("nvim-0.12")` is identical and the API surface is
  not.
- A distro or Homebrew build can lag or lead the version string.

So `compat.has[...]` reads the real table:

```lua
compat.has["lsp.codelens.enable"]   --> true / false
compat.has["pack"]                  --> vim.pack, 0.12 only
compat.has["text.diff"]             --> vim.text.diff, 0.12 only
```

Results are memoised on first read. This cannot be wrong, and it keeps working
on 0.13 without anyone editing this file.

`compat.at_least("0.12")` still exists for the rare case where there is nothing
to probe — a **behaviour** change with no new symbol attached. Reach for it only
then.

## The four entry points

| Call | Use for |
|---|---|
| `compat.has["path.to.thing"]` | "Does this API exist?" — the primary tool |
| `compat.pick(feat, new, old)` | Choosing between two **values** inline |
| `compat.needs(feat)` | A lazy.nvim `cond` — keep a plugin off the wrong version |
| `compat.codelens` | A **shim**: the 0.12 API, back-filled on 0.11 |

### `pick` — a value that differs

```lua
virt_text_pos = compat.pick("lsp.document_color", "inline", "eol"),
```

Both arms are evaluated, so pass functions if either side is expensive or would
error on the wrong version.

### `needs` — gating a plugin

```lua
{ "some/plugin-that-needs-vim-pack", cond = compat.needs("pack") },
```

Deliberately `cond`, not `enabled`. With `cond` lazy.nvim still **manages** the
plugin — it stays installed and tracked in `lazy-lock.json`, it just never
loads. With `enabled = false` lazy would uninstall it, so switching machines
would churn the lockfile every time.

### Shims — the preferred pattern

A shim presents the **newer** API shape and back-fills it on the older version.
Call sites are written once, against the 0.12 API, and never branch:

```lua
compat.codelens.enable(true, { bufnr = bufnr })
```

On 0.12 that *is* `vim.lsp.codelens.enable`. On 0.11 it is the fallback below.
When 0.11 support is dropped, delete the `else` arm in `compat.lua` and nothing
else in the config changes.

## What actually differs today

Exactly one API, checked by walking every `vim.*` path the config references and
testing each against a real 0.11.6:

### CodeLens lifecycle

**0.12** owns the lifecycle. `vim.lsp.codelens.enable(true, { bufnr })` attaches
to the buffer (`nvim_buf_attach` with `on_lines` / `on_reload`) and issues its
own internally-debounced `textDocument/codeLens` requests.

**0.11** has no lifecycle at all — only `vim.lsp.codelens.refresh()`, a one-shot
request. Something has to decide when to call it, so on 0.11 the shim recreates
the autocmd loop that 0.12 made unnecessary:

| | 0.12 | 0.11 shim |
|---|---|---|
| Refresh driver | Neovim, via buffer attach | `BufEnter`, `InsertLeave`, `BufWritePost` |
| First paint | on attach | deferred 500 ms |
| `is_enabled` | native | `vim.b[bufnr].ajay_codelens_on` |
| Disable | native | clear autocmds + `codelens.clear()` |

Note the direction of the deprecation: `refresh()` is **deprecated in 0.12 and
removed in 0.13**, so the 0.11 arm must never run on 0.12. It cannot — the
capability probe is the gate, and it is chosen at load time.

Enabling twice on the same buffer does not stack two refresh loops; the shim
clears the buffer's autocmds before re-registering.

### Everything else already works on both

`vim.lsp.config`, `vim.lsp.enable`, `vim.diagnostic.jump`, `vim.fs.root`,
`vim.lsp.inlay_hint.enable`, `client:supports_method` (colon form), `vim.hl`,
`winborder` — all present in 0.11. No shim needed, no call site changed.

Genuinely 0.12-only and **not used** by this config: `vim.pack`, `vim.text.diff`,
`vim._extui`, `vim.lsp.document_color`, `vim.lsp.linked_editing_range`,
`vim.lsp.on_type_formatting`. They are listed in `compat.tracked` so
`:AjayDoctor` reports them — the moment you want one, the gate is already there.

## Checking which arm you got

`:AjayDoctor` has a **VERSION COMPAT** section:

```
── VERSION COMPAT ─────────────────────────────
0.11+ : yes    0.12+ : no

Probed features (native = used directly, shim = back-filled):
  lsp.codelens.enable          absent -> shim/off
  lsp.document_color           absent -> shim/off
  pack                         absent -> shim/off
  ...
```

Read this first when the same config behaves differently on two machines.

## Adding a new version-dependent thing

1. **Probe, don't compare versions.** `compat.has["the.exact.api"]`.
2. **Write the call site against the newer API**, then back-fill the older one
   in `compat.lua`. Never the reverse — writing to the old API means every call
   site has to change on the day you drop the old version.
3. **Add the feature to `compat.tracked`** so `:AjayDoctor` reports it.
4. If it is a whole plugin rather than an API, use `cond = compat.needs(...)`.

Dropping 0.11 later is then a single mechanical pass: delete the `else` arms in
`compat.lua`, delete this page. Nothing in `lsp.lua` or any other module moves.
