# `whichkey.lua` — prefix hints

[which-key.nvim](https://github.com/folke/which-key.nvim). Press a prefix key,
wait a moment, and a popup lists what can follow it.

This is the in-editor version of [keymap-reference.md](keymap-reference.md).
That page is still the complete reference; which-key is what you want when you
have already pressed `<Space>` and cannot remember whether formatting is under
`<leader>l` or `<leader>t`.

## Load timing

`event = "VeryLazy"` — deliberately **not** a key trigger.

Lazy-loading a plugin on `<leader>` would mean the first press of the session is
consumed by loading the plugin rather than being handled by it, so the popup you
were waiting for never appears. `VeryLazy` fires after the UI is up but long
before you press anything, and which-key does no work until a prefix is pressed.

## What is configured, and why

| Setting | Value | Why |
|---|---|---|
| `preset` | `"helix"` | Bottom-anchored, full-width list. The default floats near the cursor, which on a wide split lands the popup over the code you are reading. |
| `delay` | `300` ms | See below |
| `icons.mappings` | follows `vim.g.have_nerd_font` | Matches [icons.md](icons.md) — a terminal without a patched font shows text instead of tofu boxes |
| `icons.rules` | `false` | The rule set guesses an icon per mapping from its description. It guesses badly on this config's descriptions and adds a column of noise. |

### `delay` is not `timeoutlen`

These get confused constantly, and the distinction matters here because this
config [deliberately tuned `timeoutlen`](keymaps.md):

| | Controls | Value here |
|---|---|---|
| `timeoutlen` | How long Neovim waits before giving up on a longer mapping — it decides **which mapping fires** | 400 ms |
| which-key `delay` | When the popup is **drawn** | 300 ms |

They are independent. which-key does not change which keys resolve, or how
fast — installing it cannot introduce a stall. Keeping `delay` comfortably under
`timeoutlen` is what makes the popup useful: it appears while you can still act
on it, and disappears the moment you complete the chord.

## Group labels

which-key reads the `desc` of every mapping automatically, so individual keys
need no configuration here.

What it **cannot** infer is what a *prefix* means. `<leader>h` is not a mapping;
it is a container for two unrelated things (git hunks and harpoon), and with no
label it renders as a bare `+8 keys`. The `spec` table names containers only:

| Prefix | Label |
|---|---|
| `<leader>c` | CMake / code |
| `<leader>d` | Debug (DAP) |
| `<leader>f` | Find (Telescope) |
| `<leader>g` | Git |
| `<leader>h` | Hunks + Harpoon |
| `<leader>j` | Java (jdtls) |
| `<leader>l` | LSP / format |
| `<leader>lw` | Workspace folders |
| `<leader>r` | Run / rename |
| `<leader>t` | Toggles |
| `g` / `]` / `[` | Goto / comment, Next, Previous |

`<leader>1`–`<leader>5` are marked `hidden`. They are the five
[harpoon](harpoon.md) slots — five near-identical rows that would push the
genuinely useful entries off the popup.

## Verifying it

`:checkhealth which-key` does more than check the plugin. It scans your actual
mappings and reports **overlapping** and **duplicate** ones — the same class of
bug this config chased down by hand in
[keymap-reference.md](keymap-reference.md#known-collisions).

Current result on this branch:

```
Checking for issues with your mappings ~
- OK No issues reported

checking for overlapping keymaps ~
- OK No overlapping keymaps found

Checking for duplicate mappings ~
- OK No duplicate mappings found
```

It also warns that `mini.icons` is not installed; `nvim-web-devicons` is, and
which-key uses it. That warning is informational.

## Keymaps

None. which-key adds no mappings of its own — it only observes the ones you
already have.

## Related

- [keymap-reference.md](keymap-reference.md) — the full written reference
- `<leader>fk` — Telescope's searchable keymap picker, better when you want to
  *search* rather than browse a prefix
