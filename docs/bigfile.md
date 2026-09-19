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

## The three gates

| Gate | Threshold | Checked at | Why |
|---|---|---|---|
| **Size** | `M.max_bytes` = **5 MB** | `BufReadPre`, via `fs_stat` | Bytes, not lines: a line count needs the file read first, which is part of what is slow. Turns off the expensive UI work — **LSP stays**. |
| **LSP** | `M.lsp_max_bytes` = **20 MB** | `BufReadPre` | Past this, a language server indexing the file is itself the problem, so it is detached too. |
| **Shape** | `M.max_line_length` = 2000 | `BufReadPost`, first 64 lines | Files small on disk but pathological in shape — minified JS, one-line JSON, generated SQL. A single enormous line defeats incremental parsing and regex syntax alike, so this one drops LSP as well. |

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
lines in [`gitsigns.lua`](gitsigns.md).

A notification fires once per buffer telling you what was switched off.

## Commands and keymaps

| | |
|---|---|
| `:BigFile` | **Toggle** protection for the current buffer |
| `<leader>tB` | Same, as a key |
| `:BigFile on` / `off` | Be explicit instead of toggling |
| `:BigFile status` | Size, line count, whether protected, whether LSP is on, and both thresholds |

Turning it **off** clears the flags, restores syntax and cursorline, restarts
treesitter, and **re-attaches any running language server** for the filetype.

A file you care about getting caught by the gate is the common case, so the bare
command toggles.

> `<leader>tB` is capital on purpose. `<leader>tb` is gitsigns' blame toggle,
> mapped **buffer-locally** in its `on_attach` — and a buffer-local mapping
> silently wins over a global one, so a global `<leader>tb` would have been
> dead in every git-tracked file. Same trap that once killed harpoon's remove
> on `<leader>hd`.

> Without the re-attach, turning protection off would give you treesitter back
> but leave the buffer permanently without LSP — and since `lsp.lua` skips
> mapping `gd`/`gr`/`K` on a detached buffer, without their keymaps too.

## Why 5 MB, and why LSP stays

The threshold used to be **1 MB** and it stripped everything, LSP included.
Measured on this machine (synthetic C, realistic open — no forced full parse):

| file | full stack | treesitter off | + syntax off |
|---|---|---|---|
| 1.4 MB | 242 ms | 107 ms | 90 ms |
| 4.3 MB | 514 ms | 124 ms | 109 ms |
| 10 MB | 1047 ms | 216 ms | 120 ms |

And keystroke latency with treesitter **active** stayed flat at every size —
0.12–0.26 ms median, p95 under 0.7 ms, even on the 10 MB / 175k-line buffer.

Two conclusions:

1. **Treesitter's incremental parse handles big files fine.** The entire cost
   is the initial parse on open, not editing. So the gate should be set where a
   *freeze on open* starts to matter, which is well past 1 MB — at 1.4 MB the
   full stack opened in a quarter of a second and got stripped anyway.
2. **LSP is not what makes it slow.** It runs out of process and never blocks
   redraw. It was the first thing turned off and should have been the last —
   losing `gd`/`gr`/completion is exactly what made this annoying enough to
   disable by hand.

For scale: **1 of 6767** kafka source files and **112 of 64952** linux source
files exceed even the old 1 MB gate, and **0 of 8000** sampled files in either
repo trip the long-line gate. This is a rare path either way, which is the
argument for not making it aggressive.

> The jdtls guard moved to the same flag. Starting jdtls on a protected buffer
> once caused two servers to write one workspace index concurrently — but that
> was triggered by the *detach*, and a merely large Java file is no longer
> detached, so the failure cannot arise. See [jdtls.md](jdtls.md).

## Related: the rainbow-delimiters size gate

Large-file cost is not all governed by this module. `rainbow-delimiters.nvim`
forced a **full synchronous parse of the entire buffer** on attach, at any size,
and `disable_for()` never touched it — it escaped only as a side effect of
`vim.treesitter.stop()`. It is now gated separately at 5000 lines; see
[qol.md](qol.md#size-gate--it-was-the-single-worst-performance-bug-in-this-config).

That cost was **independent of these thresholds**: a 1.42 MB Java file sitting
below the 5 MB gate still paid 2.09 s and 159 MB before the gate was added.

## Tuning

Both thresholds are module fields, so they can be changed without editing the
logic:

```lua
require("ajay.bigfile").max_bytes = 2 * 1024 * 1024  -- 2 MB
require("ajay.bigfile").max_line_length = 5000
```

## Keymaps

None — this module is entirely automatic.
