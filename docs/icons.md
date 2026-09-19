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
fallback — see [lsp.md](lsp.md) and [dap.md](dap.md).
A missing or broken `icons.lua` degrades the UI to ASCII; it never takes down a
language server or the debugger.

| Table           | Consumed by               | Contains                                                                                                                     |
| --------------- | ------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| `M.diagnostics` | [lsp.lua](lsp.md)         | `ERROR` `WARN` `INFO` `HINT` — with ASCII fallbacks `E` `W` `I` `H`                                                          |
| `M.dap`         | [dap.lua](dap.md)         | breakpoint, conditional breakpoint, log point, stopped, rejected, and the dap-ui control buttons (pause/play/step/terminate) |

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
M.dap.watch = g(0xf06e, "W")  -- nf-fa-eye
```

Do **not** paste the literal character — that is the failure mode this file
exists to prevent.

## Keymaps

None.
