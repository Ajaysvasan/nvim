# `icons.lua` — Nerd Font glyphs by codepoint

## Why this file exists

Nerd Font glyphs live in the Unicode **Private Use Area**. They survive some
copy/paste and encoding pipelines and not others — several of them were silently
stripped to empty strings (`""`) in this config's history.

That is worse than a visible failure: **an empty sign text renders nothing in
the gutter and raises no error.** Diagnostics just quietly stop appearing.

Defining glyphs by **codepoint** is immune to that. `vim.fn.nr2char()` builds the
character at runtime, so this file is pure ASCII and copies cleanly anywhere.

## How it works

```lua
local nerd = vim.g.have_nerd_font ~= false

local function g(codepoint, fallback)
  if not nerd then return fallback end
  return vim.fn.nr2char(codepoint)
end
```

Every glyph carries an ASCII fallback, so setting `vim.g.have_nerd_font = false`
in `init.lua` degrades the whole UI to readable ASCII instead of tofu boxes.

## Exported tables

Every consumer requires this module through `pcall` with its own inline ASCII
fallback — see [lsp.md](lsp.md), [neotree.md](neotree.md), [dap.md](dap.md).
A missing or broken `icons.lua` degrades the UI to ASCII; it never takes down a
language server, the file tree, or the debugger.

| Table | Consumed by | Contains |
|---|---|---|
| `M.diagnostics` | [lsp.lua](lsp.md) | `ERROR` `WARN` `INFO` `HINT` — with ASCII fallbacks `E` `W` `I` `H` |
| `M.tree` | [neotree.lua](neotree.md) | folder open/closed/empty, default file, expander arrows |
| `M.git` | [neotree.lua](neotree.md) | added, modified, deleted, renamed, untracked, ignored, unstaged, staged, conflict |
| `M.dap` | [dap.lua](dap.md) | breakpoint, conditional breakpoint, log point, stopped, rejected, and the dap-ui control buttons (pause/play/step/terminate) |

Each entry is commented with its `nf-fa-*` name from the
[Nerd Fonts cheat sheet](https://www.nerdfonts.com/cheat-sheet).

## `M.preview()`

```vim
:lua require("ajay.icons").preview()
```

Renders every glyph the config uses, grouped by table, in a notification. If any
of them show as boxes or blanks, **the terminal font is not a Nerd Font** —
nothing in Lua can fix that. `:AjayDoctor` runs a version of the same check
alongside the other diagnostics.

## Adding an icon

Look the glyph up on the cheat sheet, take its hex codepoint, and add it with an
ASCII fallback:

```lua
M.tree.symlink = g(0xf0c1, "@")  -- nf-fa-link
```

Do **not** paste the literal character — that is the failure mode this file
exists to prevent.

## Keymaps

None.
