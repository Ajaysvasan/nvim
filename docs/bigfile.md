# `bigfile.lua` — large-file protection

Neovim has no built-in protection against opening a file large enough to hang
it. The failure is not a crash — it is a multi-second freeze on **every
keystroke**, because several subsystems each do O(file) work per edit:

| Subsystem | Cost per edit on a huge buffer |
|---|---|
| treesitter | full parse on open, whole tree held in memory |
| LSP | whole-document sync on every change |
| gitsigns | diffs the buffer against the git index |
| indent-blankline | walks the tree for indent guides |
| rainbow-delimiters | a treesitter query over the entire tree |
| codelens | a server round trip per refresh |
| conform | spawns a formatter over the whole buffer on save |

This module turns all of that off above a threshold so the file **opens** and you
can search and edit it. It does not make a huge file feel like a normal one —
nothing can.

## Loaded eagerly, and why

`init.lua` calls `require("ajay.bigfile").setup()` **before** `require("ajay.plugins")`.
Its `BufReadPre` autocmd has to exist before the first file is opened, including
one passed on the command line — registering it from a plugin spec would be too
late for `nvim somehugefile.json`.

## The two gates

| Gate | Threshold | Checked at | Why |
|---|---|---|---|
| **Size** | `M.max_bytes` = 1 MB | `BufReadPre`, via `fs_stat` | Bytes, not lines: a line count needs the file read first, which is part of what is slow. 1 MB is roughly 20–30k lines of ordinary code. |
| **Shape** | `M.max_line_length` = 2000 | `BufReadPost`, first 64 lines | Catches files that are small on disk but pathological in shape — minified JS, one-line JSON, generated SQL. A 313 KB minified bundle trips this even though it is well under the size gate. |

Both set the buffer-local flag `vim.b[buf].bigfile = true`.

## What gets disabled

**Buffer-local options:** `swapfile`, `undofile`, `undolevels = -1` (an undo file
for a huge buffer is itself huge), `foldmethod = manual`, `spell`, `list`, `wrap`,
`cursorline`, `colorcolumn`, and `relativenumber` — which recomputes every visible
line on every cursor move.

**Treesitter** — `vim.treesitter.stop(buf)`, plus
[`treesitter.lua`](treesitter.md)'s `FileType` autocmd returns early on
`vim.b.bigfile`, so a parse is never started in the first place.

**Regex syntax** — `syntax = "off"`. This is re-asserted from a scheduled
`FileType` autocmd, not just at `BufReadPre`. Setting it early alone does not
work: filetype detection fires *afterwards* and the syntax script turns regex
highlighting straight back on. With treesitter already off, that would leave the
**slowest** highlighter running on the **biggest** buffer.

**LSP** — an `LspAttach` autocmd detaches any client that attaches to a bigfile
buffer. Cheaper and more reliable than letting one attach and then tearing it
down mid-session.

**CodeLens** — sets `vim.b[buf].codelens_off`, which [`lsp.lua`](lsp.md) checks
before calling `vim.lsp.codelens.enable()`.

**Format on save** — sets `vim.b[buf].disable_autoformat`, which
[`conform.lua`](conform.md)'s `format_on_save` already honours.

**indent-blankline** — `require("ibl").setup_buffer(buf, { enabled = false })`;
ibl has no buffer flag, so it takes a per-buffer setup call.

**View files** — [`options.lua`](options.md)'s `mkview`/`loadview` autocmds skip
bigfile buffers. They do file I/O on every buffer switch, which is exactly the
latency this module exists to avoid, and a view file for a huge buffer is huge.

**gitsigns** has its own independent size gate — `max_file_length`, set to 20000
lines in [`gitsigns.lua`](gitsigns.md) to roughly match the 1 MB threshold here.

A notification fires once per buffer telling you what was switched off.

## Commands

| Command | Action |
|---|---|
| `:BigFileOff` | Lift the protections for the current buffer — clears the flags, turns syntax and cursorline back on, restarts treesitter. Use when you actually do need highlighting on a big file and are willing to wait. |
| `:BigFileStatus` | Size in MB, line count, whether the buffer is protected, and the current threshold. |

## Tuning

Both thresholds are module fields, so they can be changed without editing the
logic:

```lua
require("ajay.bigfile").max_bytes = 2 * 1024 * 1024  -- 2 MB
require("ajay.bigfile").max_line_length = 5000
```

## Keymaps

None — this module is entirely automatic.
