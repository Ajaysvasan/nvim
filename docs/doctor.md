# `doctor.lua` — `:AjayDoctor`

A single diagnostic command that tells you **which layer is actually broken**
instead of making you guess between "font", "plugin", and "terminal".

Required from `init.lua`, but costs nothing until you invoke it — `M.setup()`
only registers the command.

## Running it

```vim
:AjayDoctor
```

Opens a rounded floating window, centred, max 80 columns. Press `q` to close.

## What it reports

### ENVIRONMENT
Neovim version, OS, architecture, `$TERM`, `$TERM_PROGRAM`, whether you're inside
tmux, and `termguicolors`.

*Why it matters:* `$TERM_PROGRAM` identifies the terminal, which determines what
`Ctrl+/` sends. tmux is worth flagging because it intercepts and re-encodes key
sequences, and can strip 24-bit colour.

### NERD FONT
Prints six glyphs directly. **If those render as boxes or blanks, your terminal
font is not a Nerd Font.** No amount of Lua fixes that — fix the terminal profile.

### nvim-web-devicons
Reports whether devicons loaded, then resolves the icon and highlight group for
`init.lua`, `main.py`, `Main.java`, `App.tsx` and `main.cpp`.

*The key inference:* if the bracketed characters are present **here** but you see
nothing in neo-tree, the plugin is fine and it **is** the font. If devicons isn't
loaded, open neo-tree once with `<C-n>` and re-run.

### CLIPBOARD
- Current `'clipboard'` option value
- Whether `g:clipboard` is explicit (and which provider) or auto-detected
- Every clipboard binary found on `PATH`, with its full `exepath`
- **A live round-trip test**: writes a probe string to the `+` register, reads it
  back, restores the original. Reports PASS/FAIL.

That round-trip is the only thing that actually proves yanking works. On FAIL it
points you at `:checkhealth vim.provider`.

### COMMENT
- The current buffer's `commentstring`
- What `gcc`, `gc`, `<C-_>` and `<C-/>` are actually mapped to in normal mode
- Instructions for discovering what **your** terminal sends:

```
press i, then Ctrl-V, then Ctrl+/
  ^_          → <C-_>   (legacy encoding)
  ^[[47;5u    → <C-/>   (kitty protocol)
  nothing     → your terminal swallows it; use gcc
```

See [comment.md](comment.md) for the full story.

## Related diagnostics

| Command | Covers |
|---|---|
| `:AjayDoctor` | Font, icons, clipboard, keycodes, terminal |
| `:checkhealth` | Neovim's own providers (Node, Python, clipboard, treesitter) |
| `:lua require("ajay.icons").preview()` | Every glyph the config uses |
| `:Lazy` | Plugin load state and startup profile |
| `:Mason` | LSP / formatter / DAP install state |
| `:ConformInfo` | Which formatter runs on this buffer |
| `:checkhealth vim.lsp` | Attached servers and root dirs (`:LspInfo` is a 0.11-only lspconfig alias for it) |
| `:JdtlsLog` | The Eclipse-side Java log |

## Keymaps

None — invoke by command.
