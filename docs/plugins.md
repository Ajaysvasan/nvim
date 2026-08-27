# `plugins.lua` — the lazy.nvim spec

The single source of truth for **what** is installed and **when** it loads.
48 plugins, pinned by commit in `lazy-lock.json`.

## Bootstrap

If `~/.local/share/nvim/lazy/lazy.nvim` does not exist, the file clones it
(`--branch=stable`, `--filter=blob:none`) and prepends it to the runtimepath.
Nothing to install by hand.

## `setup_module()` — why it exists

```lua
local function setup_module(name) ... end
```

Calling `require("x").setup()` directly gives you **"attempt to index a boolean
value"** when a module is truncated or fails to return its table — a message
that says nothing about which file or why.

Lua sets `package.loaded[name] = true` when a chunk runs to completion without
returning anything, so a file missing its trailing `return M` (or cut short by a
partial copy/paste) produces exactly that error. `setup_module()` distinguishes
three failure modes and names the file in each:

1. `require` itself failed → shows the traceback
2. loaded but returned a non-table → tells you the file is truncated and prints
   the `tail -3` command to confirm
3. table with no `setup()` function → says so

## Load triggers

| Plugin | Trigger | Why |
|---|---|---|
| `catppuccin/nvim` | `lazy = false`, `priority = 1000` | A colorscheme must be loaded and applied before anything renders |
| `goolord/alpha-nvim` | `VimEnter` | Start screen only matters at launch |
| `neo-tree.nvim` | `cmd = Neotree`, `keys = <C-n>` | |
| `telescope.nvim` | `cmd = Telescope` + the `<leader>f` keys | |
| `mason.nvim` | `cmd = Mason*`, `build = :MasonUpdate` | Only needed when you open the UI or something needs installing |
| `mason-lspconfig.nvim` | `lazy = true` — no trigger | Pulled in by `lsp.lua` only when a server is missing |
| `mason-tool-installer.nvim` | `lazy = true` — no trigger | Same |
| `nvim-lspconfig` | `BufReadPre`, `BufNewFile` | The earliest point a server could be needed |
| `nvim-jdtls` | `ft = java` | |
| `nvim-cmp` | `InsertEnter`, `CmdlineEnter` | Completion can't be needed before you start typing |
| `copilot.lua` | `cmd = Copilot`, `InsertEnter` | |
| `nvim-treesitter` | **`lazy = false`**, `branch = "main"`, `build = :TSUpdate` | On the `main` branch highlighting is started by a `FileType` autocmd that `treesitter.lua` registers, so the plugin must be loaded **before** the first `FileType` event rather than by it |
| `conform.nvim` | `BufWritePre`, `cmd = ConformInfo/Format`, `<leader>lf` | Format-on-save is the only thing that needs it early |
| `gitsigns.nvim` | `BufReadPre`, `BufNewFile` | |
| `lazygit.nvim` | `cmd = LazyGit*`, `<leader>gg` / `<leader>gf` | |
| `nvim-dap` | `<leader>d*` keys, `<F5>`–`<F8>`, `cmd = Dap*` | |
| `harpoon` | `<leader>a`, `<leader>he`, `<leader>hh` | |
| `lualine.nvim` | `VeryLazy` | Statusline can appear a frame late |
| `nvim-autopairs` | `InsertEnter` | |
| `indent-blankline` | `BufReadPost`, `BufNewFile` | |
| `Comment.nvim` | `BufReadPost`, `BufNewFile` | |
| `undotree` | `cmd = Undotree*`, `<leader>u` | |
| `nvim-emmet` | `ft = html, css, jsx, tsx, vue, svelte` | |
| `rainbow-delimiters.nvim` | `BufReadPost`, `BufNewFile` | |
| jupytext / image.nvim / molten | `enabled = vim.g.enable_notebook` | Opt-in, see [jupyter.md](jupyter.md) |

## Fixes baked into the spec

These are the non-obvious bits — each one was a real breakage:

**Mason is no longer a dependency of `nvim-lspconfig`.** This is the single
biggest startup saving in the config. lazy.nvim loads a plugin's `dependencies`
*before* the plugin itself, so listing mason there meant mason's `opts` ran — a
full `require("mason").setup()` — on `BufReadPre`, costing ~13 ms of every
startup that opened a file. `nvim-lspconfig`'s dependency list is now just
`cmp-nvim-lsp`, and the mason plugins are standalone `lazy = true` specs that
[`lsp.lua`](lsp.md#mason-on-demand) requires on demand.

**Mason repos unified.** Everything is `mason-org/*` now. The old spec mixed
`williamboman/mason.nvim` and `mason-org/mason.nvim`, which makes lazy.nvim try
to clone two different repos into the same `~/.local/share/nvim/lazy/mason.nvim`
directory.

**`telescope-fzf-native` declared exactly once.** It used to be listed twice
inside the same `dependencies` table, so the spec *without* `build = "make"`
could win and the C extension never got compiled. It is also guarded by:

```lua
cond = function()
  return vim.fn.executable("make") == 1 and vim.fn.executable("cc") == 1
end
```

so on a machine with no toolchain the extension is skipped rather than failing
the whole Telescope install.

**LuaSnip's `jsregexp` build is conditional** on the same toolchain check.

**Treesitter moved to `branch = "main"`.** It was pinned to `master` with the
comment *"main is the rewrite, incompatible API"* — right for Neovim 0.10/0.11,
wrong for 0.12. On 0.12 master's `query_predicates` break on markdown fenced code
blocks with `attempt to call method 'range' (a nil value)`, and **master is frozen
upstream so no fix is coming**. Full explanation in [treesitter.md](treesitter.md).

**`nvim-treesitter-textobjects` is a declared dependency, also on `branch = "main"`.**
Both must be on the same branch — the two APIs are not interchangeable. Without
the dependency, `treesitter.lua`'s textobjects block is skipped.

**`springboot` is wired to the jdtls spec.** The old `init.lua` did
`require("ajay.springboot")`, which only returns the module table — `setup()`
was never called, so `:SpringBootRun` and `<leader>sr` never existed.

**nvim-dap declared once.** The old file declared it twice at the top level with
two different `config` functions.

**`nvim-ts-context-commentstring` sets `vim.g.skip_ts_context_commentstring_module = true`
in `init`.** That skips the plugin's own autocmd, because Comment.nvim's
`pre_hook` calls it directly. Without it you pay the cost twice.

## lazy.nvim options

| Option | Value | Why |
|---|---|---|
| `install.colorscheme` | `{ "catppuccin" }` | The install screen uses the real theme |
| `checker.enabled` | `false` | No background update checks — no surprise network calls at startup |
| `change_detection.notify` | `false` | Editing the config shouldn't pop a notification |
| `rocks.enabled` / `rocks.hererocks` | `= vim.g.enable_notebook` | Only bootstrap luarocks when the notebook stack is actually on |
| `performance.rtp.disabled_plugins` | `gzip`, `tarPlugin`, `tohtml`, `tutor`, `zipPlugin`, `netrwPlugin`, and conditionally `rplugin` | Shaves startup. **`rplugin` is only disabled when notebooks are OFF** — molten-nvim is a Python remote plugin and needs the rplugin host, so disabling it would break `:MoltenInit` silently. |

## Full plugin list

<details>
<summary>48 plugins</summary>

Comment.nvim, LuaSnip, alpha-nvim, catppuccin, cmp-buffer, cmp-nvim-lsp,
cmp-path, cmp_luasnip, conform.nvim, copilot-cmp, copilot.lua,
friendly-snippets, gitsigns.nvim, harpoon, image.nvim, indent-blankline.nvim,
jupytext.nvim, lazy.nvim, lazygit.nvim, lualine.nvim, mason-lspconfig.nvim,
mason-nvim-dap.nvim, mason-tool-installer.nvim, mason.nvim, molten-nvim,
neo-tree.nvim, nui.nvim, nvim-autopairs, nvim-cmp, nvim-dap, nvim-dap-go,
nvim-dap-python, nvim-dap-ui, nvim-dap-virtual-text, nvim-emmet, nvim-jdtls,
nvim-lspconfig, nvim-nio, nvim-treesitter, nvim-treesitter-textobjects,
nvim-ts-context-commentstring, nvim-web-devicons, plenary.nvim,
rainbow-delimiters.nvim, telescope-dap.nvim, telescope-fzf-native.nvim,
telescope.nvim, undotree

</details>

## Keymaps

The `keys = { ... }` entries in this file are **lazy-load triggers only** — they
declare the key and a description so lazy.nvim knows when to load the plugin.
The real mapping is defined in the plugin's module. The one exception is
`<leader>u` (undotree) and `<leader>xe` (emmet), which are defined inline
because those plugins have no module file.

| Key | Action | Defined |
|---|---|---|
| `<leader>u` | Toggle undo tree | inline in the spec |
| `<leader>xe` | Emmet: wrap with abbreviation (n, v) | inline in the spec |
