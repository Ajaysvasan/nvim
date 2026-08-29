# Keymap reference

Every mapping in the config, grouped by prefix. **Leader is `<Space>`.**

Legend: **n** normal · **v** visual · **i** insert · **o** operator-pending ·
**x** visual (charwise) · **s** select

> `<leader>fk` opens a searchable Telescope picker of every active mapping —
> often faster than this page.

---

## Leader prefixes at a glance

| Prefix | Owns |
|---|---|
| `<leader>a` | Harpoon add |
| `<leader>c` | CMake, Copilot, code lens, block comment |
| `<leader>d` | **Debugging (DAP)** |
| `<leader>f` | **Find (Telescope)** |
| `<leader>g` | **Git** — gitsigns/telescope/lazygit |
| `<leader>h` | Git **h**unks (gitsigns) + Harpoon |
| `<leader>j` | **Java** (jdtls) |
| `<leader>l` | LSP/format |
| `<leader>m` | Notebooks (**m**olten) |
| `<leader>n` | `nh` — clear search highlight |
| `<leader>r` | **Run** current file, LSP rename |
| `<leader>s` | **Spring Boot** |
| `<leader>t` | **Toggles** |
| `<leader>u` | Undo tree |
| `<leader>w` | Write, LSP workspace folders |
| `<leader>x` | Save+quit, LSP diagnostics, Emmet |

---

## No prefix — plain keys

| Key | Mode | Action | Source |
|---|---|---|---|
| `<C-n>` | n | Toggle / focus file tree | [neotree](neotree.md) |
| `<C-h>` `<C-j>` `<C-k>` `<C-l>` | n | Focus window left/down/up/right | [keymaps](keymaps.md) |
| `<C-Up>` `<C-Down>` | n | Resize height ±2 | keymaps |
| `<C-Left>` `<C-Right>` | n | Resize width ±2 | keymaps |
| `H` | n | Start of line (`^`) | keymaps |
| `L` | n | End of line (`$`) | keymaps |
| `<` `>` | v | Indent, keeping the selection | keymaps |
| `J` `K` | v | Move the selection down / up | keymaps |
| `<Esc>` | n | Clear search highlight | keymaps |
| `Ctrl+/` | n, v, i | Toggle comment | [comment](comment.md) |

## LSP — buffer-local, only where a server attached

| Key | Mode | Action |
|---|---|---|
| `gd` | n | Go to definition |
| `gD` | n | Go to declaration |
| `gr` | n | Go to references |
| `gi` | n | Go to implementation |
| `gt` | n | Go to type definition |
| `K` | n | Hover documentation |
| `gK` | n | Signature help *(insert-mode `<C-s>` is a Neovim default for the same thing)* |
| `[d` `]d` | n | Previous / next diagnostic |

Source: [lsp.md](lsp.md)

## Comment

| Key | Mode | Action |
|---|---|---|
| `gcc` | n | Toggle line comment |
| `gbc` | n | Toggle block comment |
| `gc{motion}` | n | Comment operator |
| `gb{motion}` | n | Block comment operator |
| `gc` `gb` | v | Toggle on the selection |
| `gcO` `gco` `gcA` | n | Comment above / below / at end of line |

Source: [comment.md](comment.md)

## Treesitter textobjects

| Key | Mode | Action |
|---|---|---|
| `af` / `if` | o, x | A function / function body |
| `ac` / `ic` | o, x | A class / class body |
| `aa` / `ia` | o, x | A parameter / parameter without the comma |

> ⚠️ **Incremental selection (`gnn` `grn` `grc` `grm`) no longer exists.** It was
> removed in the nvim-treesitter `main` rewrite, with no built-in replacement in
> Neovim 0.12. Use `vaf` / `vac` / `vaa` instead.

Source: [treesitter.md](treesitter.md)

## Git hunks — buffer-local

| Key | Mode | Action |
|---|---|---|
| `]c` `[c` | n | Next / previous hunk |
| `ih` | o, x | Select the hunk |

Source: [gitsigns.md](gitsigns.md)

## Notebook cells — only with `enable_notebook`

| Key | Mode | Action |
|---|---|---|
| `]j` `[j` | n | Next / previous cell |
| `]o` `[o` | n | Next / previous **evaluated** cell |

Source: [jupyter.md](jupyter.md)

---

## `<leader>` — files and search

| Key | Mode | Action | Source |
|---|---|---|---|
| `<leader>w` | n | Save | [keymaps](keymaps.md) |
| `<leader>q` | n | Quit | keymaps |
| `<leader>x` | n | Save and quit | keymaps |
| `<leader>nh` | n | Clear search highlight | keymaps |
| `<leader>u` | n | Toggle undo tree | [qol](qol.md) |
| `<leader>/` | n | Fuzzy find in current buffer | [telescope](telescope.md) |
| `<leader><leader>` | n | Quick buffer switch | telescope |

## `<leader>f` — find (Telescope)

| Key | Action |
|---|---|
| `ff` | Find files |
| `fa` | Find all files (hidden + ignored) |
| `fr` | Recent files |
| `fg` | Live grep |
| `fw` | Grep word under cursor |
| `fs` | Grep a prompted string |
| `ft` | Find TODO/FIXME/NOTE/HACK/PERF/WARNING |
| `fb` | Buffers |
| `fd` / `fD` | Document / workspace symbols |
| `fi` | Implementations |
| `fR` | References |
| `fe` / `fE` | Diagnostics — all / current buffer |
| `fh` | Help tags |
| `fk` | **Keymaps** |
| `fc` | Commands |
| `fC` | Colorschemes |
| `fm` | Marks |
| `fj` | Jumplist |
| `fq` / `fl` | Quickfix / location list |
| `fp` | Resume last picker |

Source: [telescope.md](telescope.md)

## `<leader>g` — git

| Key | Action | Source |
|---|---|---|
| `gg` | Open LazyGit | [lazygit](lazygit.md) |
| `gf` | LazyGit — current file | lazygit |
| `gl` / `gL` | LazyGit filter / filter current file | lazygit |
| `gc` | Git commits | telescope |
| `gC` | `:LazyGitConfig` | lazygit |
| `gb` | Git branches | telescope |
| `gs` | Git status | telescope |
| `gS` | Git stash | telescope |

## `<leader>h` — hunks and Harpoon

| Key | Action | Source |
|---|---|---|
| `hs` | Stage hunk (n) / stage selected lines (v) | [gitsigns](gitsigns.md) |
| `hr` | Reset hunk (n) / selected lines (v) | gitsigns |
| `hS` / `hR` | Stage / reset whole buffer | gitsigns |
| `hu` | Undo last stage | gitsigns |
| `hp` | Preview hunk | gitsigns |
| `hb` | Blame line | gitsigns |
| `hd` | Diff this | gitsigns |
| `hx` | Harpoon remove file | [harpoon](harpoon.md) |
| `hD` | Diff against `HEAD~` | gitsigns |
| `he` | Harpoon quick menu | harpoon |
| `hh` | Harpoon in Telescope | harpoon |
| `hc` | Harpoon clear all | harpoon |
| `hj` / `hk` | Harpoon next / previous | harpoon |
| `<leader>a` | Harpoon add current file | harpoon |
| `<leader>1`–`<leader>5` | Jump to Harpoon slot 1–5 (works everywhere) | harpoon |
| `<A-1>`–`<A-5>` | Same, terminals that deliver Alt | harpoon |

## `<leader>d` — debugging

| Key | Mode | Action |
|---|---|---|
| `dc` | n | Continue / start |
| `dq` | n | Terminate |
| `dr` | n | Restart |
| `dp` | n | Pause |
| `db` | n | Toggle breakpoint |
| `dB` | n | Conditional breakpoint |
| `dl` | n | Log point |
| `dC` | n | Clear all breakpoints |
| `du` | n | Toggle DAP UI |
| `de` | n, v | Evaluate expression / selection |
| `dK` | n | Hover value |
| `df` / `ds` | n | Floating frames / scopes |
| `dR` | n | Toggle REPL |
| `dtn` / `dtc` | n | Python: debug test method / class |
| `dts` | v | Python: debug selection |
| `d?` | n | Print the DAP keymap reference |

| F-key | Action |
|---|---|
| `<F5>` | Continue |
| `<F6>` | Step over |
| `<F7>` | Step into |
| `<F8>` | Step out |
| `<F9>` | Step back |
| `<F10>` | Run to cursor |

Source: [dap.md](dap.md)

## `<leader>j` — Java

| Key | Mode | Action |
|---|---|---|
| `jo` | n | Organize imports |
| `jv` | n, v | Extract variable |
| `jc` | n, v | Extract constant |
| `jm` | v | Extract method |
| `jt` | n | Run test class |
| `jn` | n | Run nearest test method |
| `jN` | n | New Java file GUI ([java-creator](java-creator.md)) |
| `ju` | n | Update project config |

Source: [jdtls.md](jdtls.md)

## `<leader>s` — Spring Boot

| Key | Action |
|---|---|
| `sc` | Create project (Spring Initializr) |
| `sr` | Run application |
| `sb` | Build |
| `st` | Run tests |

Source: [springboot.md](springboot.md)

## `<leader>r` — run

| Key | Action | Source |
|---|---|---|
| `rc` | Compile and run the current C++ file | [keymaps](keymaps.md) |
| `rp` | Run the current Python file | keymaps |
| `rj` | Compile and run the current Java file | keymaps |
| `rn` | LSP rename symbol *(buffer-local)* | [lsp](lsp.md) |

## `<leader>c` — CMake, Copilot, code

| Key | Mode | Action | Source |
|---|---|---|---|
| `cb` | n | CMake build (Release) | [keymaps](keymaps.md) |
| `cr` | n | Run the CMake target | keymaps |
| `ct` | n | Toggle Copilot (persisted) | [copilot](copilot.md) |
| `cs` | n | Copilot status | copilot |
| `cp` | n | Copilot panel | copilot |
| `cc` | n, v | Toggle block comment | [comment](comment.md) |
| `cl` | n | Run code lens *(buffer-local)* | [lsp](lsp.md) |
| `ca` | n, v | Code action *(buffer-local)* | lsp |

## `<leader>t` — toggles

| Key | Action | Source |
|---|---|---|
| `tf` | Format on save — global | [conform](conform.md) |
| `tF` | Format on save — buffer | conform |
| `ts` | Format status | conform |
| `ti` | `:ConformInfo` | conform |
| `tb` | Git blame line | [gitsigns](gitsigns.md) |
| `td` | Show deleted lines | gitsigns |
| `tt` | Transparency | [transparency](transparency.md) |

## `<leader>l`, `<leader>w`, `<leader>x`

| Key | Mode | Action | Source |
|---|---|---|---|
| `lf` | n, v | Format buffer / range | [conform](conform.md) |
| `wa` / `wr` / `wl` | n | LSP workspace folder add / remove / list | [lsp](lsp.md) |
| `xd` | n | Show diagnostic under cursor | lsp |
| `xq` | n | Diagnostics to location list | lsp |
| `xe` | n, v | Emmet wrap with abbreviation | [qol](qol.md) |

## `<leader>m` — notebooks *(only with `enable_notebook`)*

| Key | Mode | Action |
|---|---|---|
| `mi` | n | Initialize kernel |
| `mc` | n | Run current cell |
| `ml` | n | Evaluate line |
| `me` | n, v | Evaluate operator / selection |
| `mn` | n | Run line and move down |
| `mr` | n | Re-evaluate cell |
| `ma` | n | Evaluate all cells |
| `mo` / `mh` | n | Show / hide output |
| `md` | n | Delete cell |
| `mq` | n | Interrupt kernel |
| `mb` | n | Insert cell below |

Source: [jupyter.md](jupyter.md)

---

## Completion — insert mode

| Key | Action | Source |
|---|---|---|
| `<Tab>` / `<S-Tab>` | Next/previous item, or jump snippet placeholder | [cmp](cmp.md) |
| `<CR>` | Confirm | cmp |
| `<C-Space>` | Trigger completion | cmp |
| `<C-e>` | Abort | cmp |
| `<C-b>` / `<C-f>` | Scroll docs | cmp |
| `<M-l>` | Accept Copilot ghost text | [copilot](copilot.md) |
| `<M-]>` / `<M-[>` | Next / previous Copilot suggestion | copilot |
| `<C-]>` | Dismiss Copilot | copilot |

## Inside a Telescope picker

| Key | Mode | Action |
|---|---|---|
| `<C-j>` / `<C-k>` | i | Next / previous result |
| `<C-q>` | i | Send to quickfix and open |
| `<C-x>` | i, n | Delete buffer |
| `<Esc>` | i | Close |
| `q` | n | Close |
| `dd` | n | Delete buffer *(buffers picker)* |

Source: [telescope.md](telescope.md)

---

## Known collisions

| Key | Claimed by | Status |
|---|---|---|
| `<leader>gc` | Telescope git commits | **Resolved** — LazyGit config moved to `<leader>gC` |
| `<leader>jn` | jdtls "test nearest" | **Resolved** — java-creator moved to `<leader>jN` |
| `<leader>1`–`<leader>5` | Harpoon slots | **Resolved** — replaced `<C-1>`–`<C-5>`, which most terminals never sent and whose lazy-load trigger did not match |
| `<leader>hd` | Gitsigns "diff this" **and** Harpoon "remove file" | **Resolved** — gitsigns' is buffer-local and silently won in every git-tracked file, so harpoon's remove was dead there. Harpoon moved to `<leader>hx`. |
| `<C-k>` | Window-up **and** LSP signature help | **Resolved** — the buffer-local LSP mapping won in every code buffer, so window-up was broken wherever a server attached. Signature help moved to `gK`. |
| `K` | Move selection up (visual) **and** LSP hover (normal) | Different modes — no actual conflict |
