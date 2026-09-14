# `neotree.lua` — file explorer

[neo-tree.nvim](https://github.com/nvim-neo-tree/neo-tree.nvim) v3, loaded on
`:Neotree` or `<C-n>`.

## Settings and why

| Setting | Value | Why |
|---|---|---|
| `close_if_last_window` | `false` | Closing your last file shouldn't also close Neovim |
| `popup_border_style` | `"rounded"` | Matches the borders used by Mason, Telescope pickers, conform and `:AjayDoctor` |
| `enable_git_status` | `true` | Git state shown per file in the tree |
| `enable_diagnostics` | `true` | LSP errors/warnings propagate up to parent folders |
| `filesystem.follow_current_file` | `enabled` | The tree reveals and highlights the file you're editing |
| `filesystem.use_libuv_file_watcher` | `true` | Files created outside Neovim appear without a manual refresh — cheaper than polling |
| `filtered_items.hide_dotfiles` | `false` | Dotfiles visible: this *is* a dotfiles repo |
| `filtered_items.hide_gitignored` | `false` | `target/`, `node_modules/` etc. stay visible — Telescope filters them out for searching, the tree still shows them |
| `window.position` | `left` | |
| `window.width` | **function**, clamped `34`–`55` | See [Width](#width-and-java-depth) — a flat `30` was unusable for Java |
| `window.auto_expand_width` | `false` | Deliberately off — it only ever *grows*, with no upper bound |
| `filesystem.group_empty_dirs` | `true` | IntelliJ's "Compact Middle Packages" — see below |
| `mapping_options` | `noremap`, `nowait` | `nowait` stops single-key tree mappings waiting on `timeoutlen` |

## Width, and Java depth

The tree was a flat **30 columns**, which is fine for a shallow repo and
unusable for Java. Every level of nesting costs `indent_size` (2) plus a marker
column, and Java buries source deep:

```
wallet/src/main/java/project/two/wallet/DTO/Wallets/WalletBalanceRequest.java
```

That is nine levels below the project root, so ~20 of the 30 columns were gone
before the filename even started. Real names rendered as `Transacti` and
`Controll`.

**Two changes, and the second matters more than the first.**

### 1. A clamped, proportional width

`resolve_width` accepts a number, a `"25%"` string, or a **function**, so the
width scales with the terminal and is clamped at both ends:

| Terminal | Tree | Code gets |
|---|---|---|
| 100 cols | 34 | 66 |
| 170 cols | 42 | 128 |
| 250 cols | 55 | 195 |

The floor keeps deep Java paths readable on a laptop; the ceiling stops the tree
eating half an ultrawide.

> `auto_expand_width` looks like the obvious answer and is a trap. Reading the
> renderer, it resizes to `longest_node` whenever a name overflows, it only ever
> **grows** (`desired_width > last_user_width`), and it has **no upper bound**.
> In kafka — 6 500 Java files nested ten deep — a single long path would throw
> the tree across most of the screen and never give it back.

### 2. Compact middle packages

`group_empty_dirs = true` is IntelliJ's *Compact Middle Packages*. When a
directory holds exactly one child and that child is a directory, the two merge
into a single row:

```
project                     project/two/wallet
  two              ->         Config
    wallet                    Controller
      Config
      Controller
```

A Java package path is a chain of exactly that shape, so this reclaims **one
indent level per package segment**. That is the thing that was actually eating
the tree — widening buys columns linearly, while nesting spends them on every
level.

Measured on `learning/backend`, the file that previously truncated to
`WalletBalanceReques` now fits in full; on kafka, `java/org/apache/kafka`
collapses from four rows to one.

**Trade-off:** the intermediate directories are no longer separate rows, so you
cannot expand or collapse them individually. That is the same deal IntelliJ
makes, and there is nothing inside a package chain to look at anyway.

## Icons

All glyphs come from [`icons.lua`](icons.md), built from codepoints. The literal
characters that used to live here were stripped to `""` in transit, which is
exactly why folder and file icons went missing.

The require is a **soft dependency**: `pcall(require, "ajay.icons")`, with a
complete inline ASCII fallback table (`+` `-` `*` for folders, `A` `M` `D` `R`
for git states) if the module is missing. A missing icons file costs you glyphs,
not a working file tree.

Indent guides use `│` and `└`; expanders use the caret glyphs from `icons.tree`.

**Per-filetype icons** come from `nvim-web-devicons` through a custom `provider`
function on the `icon` component, which looks up `get_icon(name, ext)` for file
and terminal nodes. `M.setup()` also does a `pcall(require, "nvim-web-devicons")`
first — neo-tree only shows per-filetype icons if devicons is already in memory
when it builds its components.

## The `<C-n>` smart toggle

Not a plain toggle. It walks every window looking for one with
`filetype == "neo-tree"`:

- **Tree open and focused** → close it
- **Tree open but not focused** → jump to it
- **Tree closed** → `:Neotree focus`

So the same key both reveals and dismisses, and never leaves you fighting to get
the cursor into the tree.

The mapping is registered at **file scope**, not inside `M.setup()`, so the
`keys = { "<C-n>" }` entry in the plugin spec is what actually triggers the load.

> **Fix:** the buffer filetype is read with `vim.bo[buf].filetype`, not
> `nvim_buf_get_option` — the latter is deprecated in 0.10/0.11 and **removed in
> 0.12**. Homebrew ships a newer Neovim than most distro repos, which is why this
> only ever broke on macOS.

## Keymaps

| Key | Mode | Action |
|---|---|---|
| `<C-n>` | n | Toggle / focus Neo-tree |

Inside the tree, neo-tree's own default mappings apply — press `?` for the full
list. Common ones: `a` add, `d` delete, `r` rename, `c` copy, `m` move,
`H` toggle hidden, `<CR>` open, `S` open in split, `s` open in vsplit.
