# `copilot.lua` — GitHub Copilot

[copilot.lua](https://github.com/zbirenbaum/copilot.lua) plus
[copilot-cmp](https://github.com/zbirenbaum/copilot-cmp). Loads on `InsertEnter`
or `:Copilot`.

**Requires Node.js > 18** and a GitHub Copilot subscription. Authenticate once
with `:Copilot auth`.

## Persisted on/off state — the interesting part

Copilot's own `:Copilot disable` does not survive a restart, and
`:Copilot toggle` only attaches/detaches the **current buffer**, not the client.

This module solves both:

- State is written to `stdpath("data") .. "/copilot_enabled_state"` — outside the
  config repo, so it survives restarts and reboots and never shows up in `git status`.
- `copilot.setup()` always starts the client, so immediately after setup the
  module reads the saved state and, if it says `disabled`, tears the client back
  down. Copilot comes up off even on a fresh launch.
- `:CopilotToggle` uses `Copilot enable` / `Copilot disable` — the **whole
  client**, not one buffer — and writes the new choice to disk.

Default when no state file exists: **enabled**.

## Settings and why

### Inline suggestions

| Setting | Value | Why |
|---|---|---|
| `suggestion.enabled` | `true` | Ghost-text suggestions as you type |
| `auto_trigger` | `true` | No key needed to ask for a suggestion |
| `debounce` | `75` ms | Fast enough to feel live, slow enough not to fire on every keystroke of a long word |
| `accept_word` / `accept_line` | `false` | Deliberately off — partial accepts encourage skimming instead of reading the whole suggestion |

### Panel

`enabled` with `auto_refresh`, positioned at the **bottom** taking `0.4` of the
screen — multiple alternative completions at once, rather than one ghost line.

### Filetypes where Copilot is disabled

`yaml`, `markdown`, `help`, `gitcommit`, `gitrebase`, `hgcommit`, `svn`, `cvs`,
and `["."]` (files with no extension).

The reasoning: prose and config files are where Copilot's suggestions are least
useful and most distracting, and `gitcommit` in particular is where you least
want a machine writing the message.

### nvim-cmp integration

`copilot_cmp.setup()` registers Copilot as a cmp source. It's given
**priority 1100** in [cmp.lua](cmp.md), above LSP — so AI suggestions appear at
the top of the completion menu as `[AI]` entries.

That means suggestions reach you two ways: as ghost text (accept with `<M-l>`)
and as menu entries (accept with `<CR>`).

## Keymaps

### Global (normal mode)

| Key | Action |
|---|---|
| `<leader>ct` | Toggle Copilot globally — **persisted across restarts** |
| `<leader>cs` | `:Copilot status` |
| `<leader>cp` | `:Copilot panel` |

### Inline suggestion (insert mode)

| Key | Action |
|---|---|
| `<M-l>` | Accept the current suggestion (Alt+l — the VS Code `Tab` equivalent) |
| `<M-]>` | Next suggestion |
| `<M-[>` | Previous suggestion |
| `<C-]>` | Dismiss |

### Inside the panel

| Key | Action |
|---|---|
| `[[` | Previous suggestion |
| `]]` | Next suggestion |
| `<CR>` | Accept |
| `gr` | Refresh |
| `<M-CR>` | Open panel |

> ⚠️ `<leader>cc` (block comment, [comment.md](comment.md)) and `<leader>cl`
> (LSP code lens, [lsp.md](lsp.md)) share the `<leader>c` prefix with these, plus
> `<leader>cb`/`<leader>cr` for CMake. They're all distinct two-key sequences, so
> they coexist — but `<leader>c` is the busiest prefix in the config.

## Commands

| Command | Action |
|---|---|
| `:CopilotToggle` | Enable/disable globally, persisted |
| `:CopilotStatus` | Show status |
| `:Copilot auth` | Sign in (plugin built-in) |
