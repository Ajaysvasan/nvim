# `options.lua` — editor settings

Everything set with `vim.opt`, plus the clipboard provider and fold/cursor
persistence.

> **History:** this file was previously two configs concatenated. `wrap` was set
> `true` then `false`, and `clipboard` was set twice. It has been merged so each
> option appears exactly once.

## UI

| Option | Value | Why |
|---|---|---|
| `number` | `true` | Absolute line number on the cursor line |
| `relativenumber` | `true` | Relative elsewhere — makes `12j` / `5dd` countable at a glance |
| `cursorline` | `true` | Highlights the current line |
| `signcolumn` | `"yes"` | Always reserved. Without this the text shifts left/right every time a diagnostic or git sign appears. |
| `scrolloff` | `8` | Keeps 8 lines of context above/below the cursor |
| `sidescrolloff` | `8` | Same, horizontally |
| `termguicolors` | `true` | 24-bit colour — required for Catppuccin to look correct |
| `wrap` | `false` | Long lines scroll instead of wrapping |
| `splitbelow` | `true` | New horizontal splits open below, matching how terminals are used here |
| `splitright` | `true` | New vertical splits open right |

## Indentation

| Option | Value | Why |
|---|---|---|
| `tabstop` | `4` | A tab renders as 4 columns |
| `shiftwidth` | `4` | `>>` / `<<` shift by 4 |
| `expandtab` | `true` | Insert spaces, never literal tabs |
| `smartindent` | `true` | Language-aware auto-indent on new lines |

> Per-language formatting is **not** driven by these — [conform](conform.md)
> enforces 2-space indent for Lua and web files via `stylua` and `prettier`.

## Search

| Option | Value | Why |
|---|---|---|
| `ignorecase` | `true` | Case-insensitive by default |
| `smartcase` | `true` | …unless you type a capital, then it becomes case-sensitive |
| `hlsearch` | `false` | No persistent highlight after a search. `<leader>nh` and `<Esc>` clear it anyway if a plugin turns it on. |

## Files

| Option | Value | Why |
|---|---|---|
| `undofile` | `true` | Undo history persists across restarts — this is what makes [undotree](qol.md) useful |
| `backup` | `false` | Git is the backup |
| `writebackup` | `false` | Same |
| `swapfile` | `false` | Avoids the "swap file already exists" prompt after a crash |

## Behaviour

| Option | Value | Why |
|---|---|---|
| `mouse` | `"a"` | Mouse enabled in all modes — useful for resizing splits and scrolling the DAP UI |
| `updatetime` | `250` | Drives `CursorHold`; makes gitsigns blame and LSP hover feel responsive |
| `timeoutlen` | `400` | Was `300`, which was too tight for the `<leader>h*` and `<leader>d*` chords. 400ms leaves room to type a two-key sequence without the prefix firing on its own. |
| `viewoptions` | `"cursor,folds"` | Only cursor position and folds are saved by `mkview` — not local options or window layout, which cause more problems than they solve |

## Mason binaries on `PATH`

```lua
local mason_bin = vim.fn.stdpath("data") .. "/mason/bin"
if not (vim.env.PATH or ""):find(mason_bin, 1, true) then
  vim.env.PATH = mason_bin .. ":" .. (vim.env.PATH or "")
end
```

This one line is the **only** thing mason contributes at runtime. Everything it
installs — language servers, `prettier`, `stylua`, `black`, debug adapters —
lands in that single bin directory, which has to be on `PATH` for conform,
nvim-dap and `vim.lsp` to find it.

`require("mason").setup()` used to do this as a side effect, which meant paying
for the whole package registry (~13 ms) on every startup to get one `PATH`
entry. Doing it here means mason only has to load when something needs
*installing* — see [Mason, on demand](lsp.md#mason-on-demand).

Setting it here rather than in `lsp.lua` also makes it **earlier and more
robust** than before: conform, nvim-dap and jdtls now find mason binaries
regardless of which module happens to load first.

The guard keeps it idempotent if mason does load later and prepends the same
directory again.

## Clipboard — why it is set explicitly

Neovim auto-detects a clipboard provider by probing for `pbcopy`, `xclip`,
`xsel`, `wl-copy` and friends. That probe is **order-dependent and picks the
first match on `PATH`**. Mason prepends its own `bin` directory to `PATH` during
setup, and on macOS a Homebrew tool can shadow the system one. The result is a
yank that silently does nothing.

So the provider is pinned:

- **macOS** → `vim.g.clipboard` set explicitly to `pbcopy` / `pbpaste`,
  `cache_enabled = 0`.
- **Wayland** → `wl-copy` / `wl-paste`, with `*` mapped to the primary
  selection, `cache_enabled = 1`.
- **X11 / anything else** → left to Neovim's auto-detection (install `xclip`
  or `xsel`).

`clipboard = "unnamedplus"` is then applied inside a `vim.schedule()`, **after**
startup. Touching the `clipboard` option during init forces the provider to
spawn immediately, which costs 30–80ms and, on macOS, is the usual reason the
first yank of a session silently no-ops.

Verify it with `:AjayDoctor` — it does a live write/read round-trip through the
`+` register.

## Fold and cursor persistence

Two autocmds in the `ajay_remember_view` group call `mkview` on `BufWinLeave`
and `loadview` on `BufWinEnter`, so folds and cursor position survive closing a
file.

Both are guarded by an `is_real_file()` check:

```lua
vim.bo.buftype == ""          -- not a terminal/quickfix/help buffer
  and vim.bo.filetype ~= ""   -- not an unidentified scratch buffer
  and vim.fn.expand("%") ~= ""-- has a path on disk
  and not vim.bo.readonly
```

Without that guard the autocmds fired for plugin scratch buffers too, which on a
fresh machine with no `~/.local/state/nvim/view` directory produced errors on
nearly every buffer switch.

`is_real_file()` also returns `false` for `vim.b.bigfile` buffers. `mkview` and
`loadview` do **file I/O on every buffer switch** — on a huge file that is exactly
the latency [bigfile.lua](bigfile.md) exists to avoid, and a view file for a huge
buffer is itself huge.

## Optional globals you can set here

`options.lua` is also the intended home for the config's escape-hatch globals.
Neither is set by default:

| Global | Effect |
|---|---|
| `vim.g.jdtls_java_home` | Point [jdtls](jdtls.md) at a specific JDK, skipping all auto-detection |
| `vim.g.ts_disabled_langs` | Skip [treesitter](treesitter.md) for the given languages and fall back to Vim regex syntax, e.g. `{ markdown = true, markdown_inline = true }` |

## Keymaps

None. See [keymaps.md](keymaps.md).
