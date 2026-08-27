# `jupyter.lua` — notebooks (opt-in)

> ## Off by default
>
> Set `vim.g.enable_notebook = true` in `init.lua` to turn this on.

## Why it is gated

`image.nvim`'s `magick` dependency is a **LuaRock**. lazy.nvim bootstraps
hererocks + luarocks to build it, and that build needs ImageMagick's C headers.
On a fresh macOS box that build fails — and because these are non-lazy specs, the
failure **blocks startup entirely**.

The flag also controls two other things in `plugins.lua`:

- `rocks.enabled` / `rocks.hererocks` — luarocks is only bootstrapped when
  notebooks are on
- `rplugin` stays **enabled** in the runtimepath when notebooks are on.
  molten-nvim is a Python remote plugin and needs the rplugin host; disabling it
  would break `:MoltenInit` silently.

## The stack

| Plugin | Role |
|---|---|
| `jupytext.nvim` | Converts `.ipynb` ⇄ plain Python on open/save. `lazy = false` — it must be loaded **before** a notebook is opened. Style `percent`, so cells are delimited by `# %%`. |
| `molten-nvim` | Runs code against a real Jupyter kernel and displays output. `build = ":UpdateRemotePlugins"`. |
| `image.nvim` | Renders plots and images inline. Backend `kitty`, `build = false` so it never attempts a rockspec build. |

### molten settings (`init` in the spec)

| Setting | Value | Why |
|---|---|---|
| `molten_image_provider` | `"image.nvim"` | Plots render inline instead of opening externally |
| `molten_output_win_max_height` | `20` | Caps output so a long traceback doesn't take the screen |
| `molten_auto_open_output` | `false` | Output doesn't pop up on every evaluation; use `<leader>mo` |
| `molten_wrap_output` | `true` | Long lines wrap in the output window |
| `molten_virt_text_output` | `true` | A compact result appears inline next to the cell |

## System requirements

```bash
# macOS
brew install imagemagick
pip3 install --user jupytext pynvim jupyter_client ipykernel

# Debian/Ubuntu
sudo apt install -y libmagickwand-dev imagemagick
pip3 install --user jupytext pynvim jupyter_client ipykernel
```

**Inline images need a terminal that speaks the Kitty graphics protocol** —
Kitty, WezTerm, or Ghostty. In any other terminal code execution still works;
plots just don't render.

After enabling the flag: restart, `:Lazy sync`, then `:UpdateRemotePlugins`.

## Cell model

Cells are delimited by `# %%` markers (jupytext's `percent` style). `get_cell_range()`
finds the boundaries by searching backward and forward for the nearest markers,
then restores the cursor.

## The visual notebook UI

This is the part that isn't just molten defaults — it recreates VS Code/Colab
cell chrome:

**Labeled dividers.** An extmark with `virt_lines_above` draws a horizontal rule
above every `# %%` marker, labeled `Code Cell` or `Markdown Cell` depending on
whether the marker line contains `[markdown]`. Redrawn on `BufEnter`,
`TextChanged` and `InsertLeave`.

**Active cell highlight.** On `CursorMoved`, every line of the cell you're in gets
`line_hl_group = "NotebookActiveCell"` — the Colab-style outline showing which
cell will run.

**Theme-following highlights.** Three groups are defined with `default = true` and
**linked to existing theme groups**, so they adapt to Catppuccin automatically
and are redefined on `ColorScheme`:

| Group | Linked to |
|---|---|
| `NotebookCellHeader` | `Title` |
| `NotebookMarkdownHeader` | `String` |
| `NotebookActiveCell` | `CursorLine` |

All of it is guarded by `has_cell_markers(bufnr)`, so a plain `.py` file with no
`# %%` markers gets no decoration at all.

## Keymaps

### Kernel

| Key | Action |
|---|---|
| `<leader>mi` | Initialize the kernel (`:MoltenInit`) — **do this first** |
| `<leader>mq` | Interrupt the kernel |

### Running code

| Key | Mode | Action |
|---|---|---|
| `<leader>mc` | n | **Run the current cell** — the whole `# %%` block |
| `<leader>ml` | n | Evaluate the current line |
| `<leader>me` | n | Evaluate an operator/motion |
| `<leader>me` | v | Evaluate the selection |
| `<leader>mn` | n | Run the line and move down |
| `<leader>mr` | n | Re-evaluate the current cell |
| `<leader>ma` | n | Evaluate all cells |

### Output

| Key | Action |
|---|---|
| `<leader>mo` | Show output |
| `<leader>mh` | Hide output |
| `<leader>md` | Delete the Molten cell |

### Navigation

| Key | Action |
|---|---|
| `]j` | Next cell |
| `[j` | Previous cell |
| `]o` | Next **evaluated** cell (only after you've run something) |
| `[o` | Previous evaluated cell |
| `<leader>mb` | Insert a new cell below and enter insert mode |

## Commands

| Command | Action |
|---|---|
| `:NewNotebook [path]` | Create a **valid blank `.ipynb`** and open it. Necessary because jupytext needs valid ipynb JSON to convert — an empty buffer won't work. Appends `.ipynb` if you omit it, prompts for a path if you pass none. |

## Notes

- Opening a `python` or `markdown` file prints a reminder that `<leader>mi`
  initializes the kernel. If you find that noisy, remove the `FileType` autocmd
  at the bottom of `M.setup()`.
- The `<leader>m` prefix is used **only** by this module.
