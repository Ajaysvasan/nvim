# ajay's Neovim configuration



A Lua-based Neovim config built around [lazy.nvim](https://github.com/folke/lazy.nvim),
with first-class support for **Java / Spring Boot**, **C/C++**, **Python**,
**JavaScript / TypeScript / React**, and an optional **Jupyter notebook** stack.

It is a personal config, but it is written to be portable: every module is
defensive about missing binaries, both macOS and Linux paths are handled
explicitly, and there is a built-in `:AjayDoctor` command that tells you which
layer (font, terminal, plugin, clipboard) is actually broken instead of making
you guess.

---

## What this is

|                       |                                                                                                 |
| --------------------- | ----------------------------------------------------------------------------------------------- |
| **Entry point**       | `init.lua` — sets leader keys, two feature flags, requires three modules                        |
| **Plugin manager**    | lazy.nvim, bootstrapped automatically on first launch                                           |
| **Plugin spec**       | `lua/ajay/plugins.lua` — the single source of truth for _what_ is installed and _when_ it loads |
| **Per-plugin config** | `lua/ajay/<name>.lua` — one file per plugin, each returning a module with `setup()`             |
| **Plugin count**      | 48 plugins pinned in `lazy-lock.json`                                                           |
| **Colorscheme**       | Catppuccin (Frappé flavour)                                                                     |
| **Leader key**        | `<Space>` (both `mapleader` and `maplocalleader`)                                               |

### Design rules this config follows

1. **`keymaps.lua` holds only plugin-free mappings.** Anything that touches a
   plugin lives in that plugin's module, so lazy.nvim's `keys =` lazy-load
   triggers actually fire.
2. **Everything is lazy** except the colorscheme. Plugins load on an event,
   command, keymap, or filetype.
3. **Icons are defined by codepoint**, not by literal glyph (`lua/ajay/icons.lua`).
   Nerd Font glyphs live in the Unicode Private Use Area and get silently
   stripped by some copy/paste pipelines — an empty sign renders _nothing_ with
   no error. Building them with `nr2char` makes this file pure ASCII.
4. **Modules are loaded through a `setup_module()` wrapper** that reports the
   file name and reason when a module fails to load, instead of Lua's useless
   "attempt to index a boolean value".
5. **Nothing crashes startup.** Every optional dependency is behind `pcall` or
   an `executable()` check.

---

## Directory layout

Every file below links to its own documentation page.

```
~/.config/nvim/
├── init.lua
├── lazy-lock.json
├── README.md
├── docs/
└── lua/ajay/
```

### Core

| File | Docs | What it does |
|---|---|---|
| `init.lua` | **[docs/init.md](docs/init.md)** | Entry point: leader keys, feature flags, 3 requires |
| `lua/ajay/plugins.lua` | **[docs/plugins.md](docs/plugins.md)** | lazy.nvim spec — every plugin and its load trigger |
| `lua/ajay/options.lua` | **[docs/options.md](docs/options.md)** | `vim.opt` settings, clipboard, fold/cursor persistence |
| `lua/ajay/keymaps.lua` | **[docs/keymaps.md](docs/keymaps.md)** | Plugin-free keymaps only |
| `lua/ajay/bigfile.lua` | **[docs/bigfile.md](docs/bigfile.md)** | Large-file protection — loaded eagerly, before plugins |

### UI

| File | Docs | What it does |
|---|---|---|
| `lua/ajay/colorscheme.lua` | **[docs/colorscheme.md](docs/colorscheme.md)** | Catppuccin (Frappé) + integrations |
| `lua/ajay/dashboard.lua` | **[docs/dashboard.md](docs/dashboard.md)** | alpha-nvim start screen |
| `lua/ajay/neotree.lua` | **[docs/neotree.md](docs/neotree.md)** | File explorer |
| `lua/ajay/icons.lua` | **[docs/icons.md](docs/icons.md)** | Nerd Font glyphs defined by codepoint |
| `lua/ajay/transparency.lua` | **[docs/transparency.md](docs/transparency.md)** | Transparent-background toggle (`<leader>tt`) |
| *(inline in `plugins.lua`)* | **[docs/qol.md](docs/qol.md)** | lualine, autopairs, indent guides, undotree, emmet, rainbow delimiters |

### Editing and language support

| File | Docs | What it does |
|---|---|---|
| `lua/ajay/lsp.lua` | **[docs/lsp.md](docs/lsp.md)** | Mason, servers, diagnostics, shared `LspAttach`, CodeLens |
| `lua/ajay/cmp.lua` | **[docs/cmp.md](docs/cmp.md)** | Completion, LuaSnip, custom snippets |
| `lua/ajay/copilot.lua` | **[docs/copilot.md](docs/copilot.md)** | GitHub Copilot with persisted on/off state |
| `lua/ajay/treesitter.lua` | **[docs/treesitter.md](docs/treesitter.md)** | Highlighting, indent, textobjects (`main` branch) |
| `lua/ajay/conform.lua` | **[docs/conform.md](docs/conform.md)** | Formatting and format-on-save |
| `lua/ajay/comment.lua` | **[docs/comment.md](docs/comment.md)** | Comment toggling and the `Ctrl+/` story |
| `lua/ajay/telescope.lua` | **[docs/telescope.md](docs/telescope.md)** | Fuzzy finder, all `<leader>f` mappings |
| `lua/ajay/harpoon.lua` | **[docs/harpoon.md](docs/harpoon.md)** | Quick file marks |

### Git

| File | Docs | What it does |
|---|---|---|
| `lua/ajay/gitsigns.lua` | **[docs/gitsigns.md](docs/gitsigns.md)** | Gutter signs, hunk staging, blame |
| `lua/ajay/lazygit.lua` | **[docs/lazygit.md](docs/lazygit.md)** | LazyGit floating window |

### Debugging

| File | Docs | What it does |
|---|---|---|
| `lua/ajay/dap.lua` | **[docs/dap.md](docs/dap.md)** | Python, JS/TS, Go, C/C++, Rust, Java |

### Java / Spring Boot

| File | Docs | What it does |
|---|---|---|
| `lua/ajay/jdtls.lua` | **[docs/jdtls.md](docs/jdtls.md)** | JDK discovery, Lombok, workspaces, Java refactors |
| `lua/ajay/springboot.lua` | **[docs/springboot.md](docs/springboot.md)** | Spring Initializr, run/build/test |
| `lua/ajay/java-creator.lua` | **[docs/java-creator.md](docs/java-creator.md)** | IntelliJ-style new-file GUI, 13 templates (`<leader>jN`) |

### Optional and diagnostic

| File | Docs | What it does |
|---|---|---|
| `lua/ajay/jupyter.lua` | **[docs/jupyter.md](docs/jupyter.md)** | Molten notebook cells — *opt-in* |
| `lua/ajay/doctor.lua` | **[docs/doctor.md](docs/doctor.md)** | `:AjayDoctor` |


### Cross-cutting reference

| Page | Contents |
|---|---|
| **[docs/keymap-reference.md](docs/keymap-reference.md)** | Every mapping in the config, grouped by prefix |
| **[docs/commands.md](docs/commands.md)** | Every custom `:Command` |
| **[docs/performance.md](docs/performance.md)** | Every speed decision: startup, navigation, responsiveness |
| **[docs/inactive-modules.md](docs/inactive-modules.md)** | Record of removed modules and why |

Full per-file documentation lives in **[`docs/`](docs/README.md)**.

---

## Feature flags

Set these at the top of `init.lua`:

| Flag                    | Default | Effect                                                                                                                                                                                   |
| ----------------------- | ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `vim.g.have_nerd_font`  | `true`  | Set `false` on a terminal without a patched font. Icons degrade to ASCII instead of showing tofu boxes.                                                                                  |
| `vim.g.enable_notebook` | `false` | Turns on the molten + image.nvim + jupytext stack. Off by default because it pulls in luarocks/hererocks/ImageMagick and is the most common source of build failures on a fresh machine. |

Two more optional escape hatches, both set in `options.lua` and neither on by
default:

```lua
-- If JDK auto-detection picks the wrong Java (see docs/jdtls.md)
vim.g.jdtls_java_home = "/Library/Java/JavaVirtualMachines/zulu-21.jdk/Contents/Home"

-- Skip treesitter for a language and fall back to Vim regex syntax
-- (see docs/treesitter.md)
vim.g.ts_disabled_langs = { markdown = true, markdown_inline = true }
```

---

## Requirements

### Required — nothing works properly without these

| Tool                                                 | Why                                                                                                                                                                                                                               | Minimum   |
| ---------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- |
| **Neovim**                                           | The config uses the 0.11+ LSP API (`vim.lsp.config`, `vim.diagnostic.jump`, `client:supports_method()`). It will throw errors on 0.10 and older.                                                                                  | **0.11+** |
| **git**                                              | lazy.nvim bootstraps itself and clones every plugin                                                                                                                                                                               | any       |
| **A C compiler** (`cc` / `clang` / `gcc`) + **make** | Builds `telescope-fzf-native`, LuaSnip's `jsregexp`, and treesitter parsers. Without it the config still starts — those pieces disable themselves — but fuzzy matching is slower and `auto_install` for parsers turns itself off. | any       |
| **A Nerd Font** in your _terminal profile_           | Every icon in the tree, statusline, gutter, and dashboard. This is a terminal setting, not a Neovim setting — no Lua can fix a wrong terminal font.                                                                               | v3+       |
| **`tree-sitter` CLI** | **Required to build treesitter parsers.** nvim-treesitter's `main` branch shells out to the `tree-sitter` binary to compile every parser — a C compiler alone is no longer enough, unlike on the old `master` branch. Without it you get **no syntax highlighting at all** and a wall of `Error during "tree-sitter build" ... ENOENT: 'tree-sitter'` on startup. | any |
| **ripgrep** (`rg`)                                   | Telescope `live_grep` and `grep_string`                                                                                                                                                                                           | any       |
| **fd**                                               | Faster Telescope file finding (optional but strongly recommended)                                                                                                                                                                 | any       |
| **Node.js**                                          | Copilot requires Node **> 18**. Also needed by `js-debug-adapter` and by Mason for every JS-based LSP (`ts_ls`, `html`, `cssls`, `tailwindcss`, `eslint`).                                                                        | **18+**   |
| **Python 3** + `pynvim`                              | Neovim's Python provider; required by molten if you enable notebooks                                                                                                                                                              | 3.9+      |
| **unzip**                                            | Used by `jdtls.lua` to read the jdtls MANIFEST, and by `springboot.lua` to unpack Spring Initializr downloads                                                                                                                     | any       |
| **curl**                                             | Spring Initializr downloads                                                                                                                                                                                                       | any       |

### Language-specific — install only what you use

| Language               | Needs                                                                                                                                                                                                |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Java / Spring Boot** | A **JDK 21+** to _run_ jdtls (your project can still target 8/11/17 — see [docs/jdtls.md](docs/jdtls.md)). Plus Maven or Gradle (the wrappers `mvnw`/`gradlew` are enough). Optionally `lombok.jar`. |
| **C / C++**            | `clangd` (via Mason), `g++`/`clang++`, `cmake` for the `<leader>cb` build map, `codelldb` (via Mason) for debugging                                                                                  |
| **Python**             | `python3`, `debugpy` (via Mason), `pytest` if you use the DAP test maps                                                                                                                              |
| **JS / TS / React**    | Node 18+, `npm`. LSPs and `js-debug-adapter` come from Mason.                                                                                                                                        |
| **Go**                 | Go toolchain + `dlv` (Mason installs `delve`)                                                                                                                                                        |
| **Rust**               | `cargo`, `codelldb` (via Mason)                                                                                                                                                                      |
| **Git UI**             | `lazygit` binary on `PATH` for `<leader>gg`                                                                                                                                                          |
| **Notebooks** (opt-in) | `ImageMagick`, `jupytext`, `pynvim`, `jupyter_client`, a Kitty-graphics-capable terminal (Kitty, WezTerm, Ghostty)                                                                                   |

### Installed automatically by Mason

You do not install these by hand. On first launch Mason fetches them:

**LSP servers:** `clangd`, `pyright`, `jdtls`, `ts_ls`, `eslint`, `html`,
`cssls`, `lua_ls`, `tailwindcss`

**Formatters/tools:** `prettier`, `eslint_d`, `clang-format`, `black`, `isort`,
`stylua`, `google-java-format`, `shfmt`

**DAP adapters:** `debugpy`, `js-debug-adapter`, `chrome-debug-adapter`,
`codelldb`, `delve`

> Mason installs into `~/.local/share/nvim/mason/`. It needs Node, Python and a
> JDK present for the servers written in those languages.

---

## Setup — macOS

```bash
# 1. Homebrew, if you don't have it
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Core
brew install neovim git ripgrep fd node python3 lazygit unzip curl cmake tree-sitter

# 3. Compiler toolchain (needed for telescope-fzf-native + treesitter parsers)
xcode-select --install

# 4. A Nerd Font
brew install --cask font-jetbrains-mono-nerd-font
#    …then set it as the font in your TERMINAL's profile settings.

# 5. Java — a JDK 21 to run jdtls. Your projects can still target 17.
brew install --cask zulu@21
#    (or: brew install openjdk@21)

# 6. Python provider
python3 -m pip install --user pynvim

# 7. Optional: Lombok, if you use @Data / @Getter in Spring Boot projects
mkdir -p ~/.local/share/lombok
curl -L -o ~/.local/share/lombok/lombok.jar https://projectlombok.org/downloads/lombok.jar

# 8. Clone this config
git clone <your-repo-url> ~/.config/nvim

# 9. First launch — lazy.nvim bootstraps, Mason installs everything.
nvim
```

**macOS notes**

- The clipboard provider is pinned explicitly to `pbcopy`/`pbpaste` in
  `options.lua`. Auto-detection is order-dependent and Mason prepends its own
  `bin` to `PATH`, which is how a yank silently stops working.
- JDK discovery uses `/usr/libexec/java_home -V`, which finds Zulu, Temurin,
  Corretto, GraalVM and Microsoft builds regardless of vendor, plus SDKMAN,
  jenv, asdf and mise installs.
- `Ctrl+/` for commenting only works in terminals that speak the kitty keyboard
  protocol (Kitty, WezTerm, Ghostty) or iTerm2 in legacy mode. Terminal.app
  sends nothing at all. **`gcc` and `gc{motion}` always work** — use those.

## Setup — Linux

```bash
# ── Debian / Ubuntu ────────────────────────────────────────────────
# Distro Neovim is usually too old. Use the AppImage or the PPA.
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage
chmod +x nvim-linux-x86_64.appimage
sudo mv nvim-linux-x86_64.appimage /usr/local/bin/nvim

sudo apt update
sudo apt install -y git ripgrep fd-find build-essential cmake unzip curl python3-pip
# fd is called fdfind on Debian:
ln -s "$(which fdfind)" ~/.local/bin/fd

# Node 18+ (distro node is often 12/16)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# tree-sitter CLI — REQUIRED to build parsers on the `main` branch.
# Not in most distro repos; npm is the easiest source.
sudo npm install -g tree-sitter-cli

# JDK 21 to run jdtls
sudo apt install -y openjdk-21-jdk

# lazygit
LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": *"v\K[^"]*')
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf lazygit.tar.gz lazygit && sudo install lazygit /usr/local/bin && rm lazygit lazygit.tar.gz

# Python provider
python3 -m pip install --user pynvim

# ── Arch ───────────────────────────────────────────────────────────
sudo pacman -S neovim git ripgrep fd base-devel cmake unzip curl \
               nodejs npm python-pynvim jdk21-openjdk lazygit tree-sitter-cli

# ── Fedora ─────────────────────────────────────────────────────────
sudo dnf install -y neovim git ripgrep fd-find gcc gcc-c++ make cmake unzip curl \
                    nodejs java-21-openjdk-devel lazygit
sudo npm install -g tree-sitter-cli
python3 -m pip install --user pynvim
```

Then, on any distro:

```bash
# Nerd Font
mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts
curl -fLO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
unzip -o JetBrainsMono.zip && fc-cache -fv
#   …then set it as the font in your TERMINAL's profile settings.

# Optional: Lombok for Spring Boot projects
mkdir -p ~/.local/share/lombok
curl -L -o ~/.local/share/lombok/lombok.jar https://projectlombok.org/downloads/lombok.jar

# Clone and launch
git clone <your-repo-url> ~/.config/nvim
nvim
```

**Linux notes**

- On Wayland, install `wl-clipboard` — `options.lua` detects it and pins the
  provider explicitly. On X11, install `xclip` or `xsel` and Neovim's
  auto-detection handles it.
- JDK discovery globs `/usr/lib/jvm/*` plus SDKMAN / jenv / asdf / mise paths.
- `Ctrl+/` sends `0x1F` (`<C-_>`) on most Linux terminals, so it works out of
  the box here.

## Optional: enabling the Jupyter notebook stack

This is **off by default**. It needs extra system packages and a terminal that
supports the Kitty graphics protocol.

```bash
# macOS
brew install imagemagick
pip3 install --user jupytext pynvim jupyter_client ipykernel

# Debian/Ubuntu
sudo apt install -y libmagickwand-dev imagemagick
pip3 install --user jupytext pynvim jupyter_client ipykernel
```

Then set `vim.g.enable_notebook = true` in `init.lua`, restart, and run
`:Lazy sync` followed by `:UpdateRemotePlugins`. See
[docs/jupyter.md](docs/jupyter.md).

---

## First launch — what to expect

1. lazy.nvim clones itself, then clones all 48 plugins. Takes a few minutes.
2. `telescope-fzf-native` compiles (skipped silently if you have no compiler).
3. Mason installs the LSP servers, formatters and DAP adapters listed above.
   Watch progress with `:Mason`.
4. Treesitter compiles parsers for the 22 configured languages into
   `~/.local/share/nvim/site/parser`.
5. Restart Neovim once everything settles.

> **Upgrading an existing install?** This config moved nvim-treesitter from the
> frozen `master` branch to `main`. Switching branches does **not** rebuild
> parsers, and stale ones cause `attempt to call method 'range' (a nil value)`.
> Run `:TSReset` once and restart.

## Verifying the install

| Command                                | Checks                                                                                                                                         |
| -------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `:AjayDoctor`                          | Nerd Font rendering, devicons, clipboard round-trip, `Ctrl+/` keycode, terminal identification. **Run this first when something looks wrong.** |
| `:checkhealth`                         | Neovim's own providers (Node, Python, clipboard)                                                                                               |
| `:Lazy`                                | Plugin install/load state and startup profile                                                                                                  |
| `:Mason`                               | LSP/formatter/DAP install state                                                                                                                |
| `:ConformInfo`                         | Which formatter will run on this buffer                                                                                                        |
| `:LspInfo`                             | Which servers are attached and their root dir                                                                                                  |
| `:JdtlsLog`                            | The Eclipse-side jdtls log — where the real Java errors hide                                                                                   |
| `:lua require("ajay.icons").preview()` | Renders every glyph the config uses                                                                                                            |

## Troubleshooting

| Symptom                                    | Likely cause                                                                                                     |
| ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------- |
| Boxes or blanks instead of icons           | Terminal font is not a Nerd Font. Fix the terminal profile, not Neovim. Confirm with `:AjayDoctor`.              |
| Yank doesn't reach the system clipboard    | Missing provider. Run `:checkhealth vim.provider`. On Wayland install `wl-clipboard`.                            |
| `Ctrl+/` does nothing                      | Your terminal swallows it. Use `gcc` / `gc{motion}` / `gbc`. See [docs/comment.md](docs/comment.md).             |
| Java shows "cannot find symbol: getName()" | Lombok jar not found. See [docs/jdtls.md](docs/jdtls.md).                                                        |
| jdtls exits with code 13                   | Wrong JVM version running the server. `:AjayDoctor`, then install JDK 21.                                        |
| `attempt to index a boolean value`         | A module file is truncated and missing its trailing `return M`. The `setup_module()` wrapper reports which file. |
| Treesitter compile errors                  | No C compiler. Install `build-essential` / Xcode CLT.                                                            |
| `Error during "tree-sitter build" ... ENOENT: 'tree-sitter'` on every startup, and nothing is highlighted | The `tree-sitter` CLI is missing. `brew install tree-sitter`, or `npm install -g tree-sitter-cli`. Required by nvim-treesitter's `main` branch — a C compiler is no longer sufficient. |

---

## Startup performance

Measured with `nvim --headless --startuptime`, median of 7 warm runs:

| Scenario | Originally | Now |
|---|---|---|
| `nvim` with no file | ~19.5 ms | **~18.5 ms** |
| `nvim <file>` (LSP + git + treesitter + completion wired up) | ~53.5 ms | **~32 ms** |
| `nvim Main.java` | — | **~36 ms** |

The config is also tuned for **navigation** and **typing responsiveness**, not
just boot: Telescope drives `fd`/`rg` directly so filtering happens in Rust
rather than Lua, completion is tuned for the thousand-candidate lists Java and
Spring produce, CodeLens no longer fires redundant project-wide LSP round trips
on every `InsertLeave`, and [`bigfile.lua`](docs/bigfile.md) stops a large file
from freezing the editor.

**Full rationale for every decision, and how to reverse any of them, is in
[docs/performance.md](docs/performance.md).**

> **Caveat on the numbers:** `--headless` does not fire `UIEnter`, so plugins on
> the `VeryLazy` event — lualine here — are not included. In a real terminal they
> load *after* the first draw, so they do not delay time-to-interactive, but the
> wall-clock total is a little higher.

---

## Documentation index

Every module has its own page under [`docs/`](docs/README.md), covering what it
does, which settings are enabled and **why**, and every keymap it defines.

- [docs/README.md](docs/README.md) — index of all module pages
- [Full keymap cheat sheet](docs/keymap-reference.md)
- [Every custom command](docs/commands.md)

Or jump straight to a file from the [directory layout](#directory-layout) tables
above.
