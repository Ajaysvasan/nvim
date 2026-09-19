# ajay's Neovim configuration

A Lua-based Neovim config built around [lazy.nvim](https://github.com/folke/lazy.nvim),
with language servers, formatting and debugging for **Java**, **C/C++**,
**Python**, **Go** and **Rust**.

It is a personal config, but it is written to be portable: every module is
defensive about missing binaries, both macOS and Linux paths are handled
explicitly, and there is a built-in `:AjayDoctor` command that tells you which
layer (font, terminal, plugin, clipboard) is actually broken instead of making
you guess.

---

## What this is

|                       |                                                                                                 |
| --------------------- | ----------------------------------------------------------------------------------------------- |
| **Entry point**       | `init.lua` — version check, leader keys, one feature flag, five requires                        |
| **Plugin manager**    | lazy.nvim, bootstrapped automatically on first launch                                           |
| **Plugin spec**       | `lua/ajay/plugins.lua` — the single source of truth for _what_ is installed and _when_ it loads |
| **Per-plugin config** | `lua/ajay/<name>.lua` — one file per plugin, each returning a module with `setup()`             |
| **Plugin count**      | 38 plugins pinned in `lazy-lock.json`                                                           |
| **Colorscheme**       | VS Code Dark+                                                                                   |
| **Leader key**        | `<Space>` (both `mapleader` and `maplocalleader`)                                               |

### Design rules this config follows

1. **`keymaps.lua` holds only plugin-free mappings.** Anything that touches a
   plugin lives in that plugin's module, so lazy.nvim's `keys =` lazy-load
   triggers actually fire.
2. **Everything is lazy** except the colorscheme and treesitter. Plugins load on
   an event, command, keymap, or filetype.
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
| `init.lua` | **[docs/init.md](docs/init.md)** | Entry point: version check, leader keys, feature flag, requires |
| `lua/ajay/plugins.lua` | **[docs/plugins.md](docs/plugins.md)** | lazy.nvim spec — every plugin and its load trigger |
| `lua/ajay/options.lua` | **[docs/options.md](docs/options.md)** | `vim.opt` settings, clipboard, fold/cursor persistence |
| `lua/ajay/keymaps.lua` | **[docs/keymaps.md](docs/keymaps.md)** | Plugin-free keymaps only |
| `lua/ajay/bigfile.lua` | **[docs/bigfile.md](docs/bigfile.md)** | Large-file protection — loaded eagerly, before plugins |
| `lua/ajay/compat.lua` | **[docs/compat.md](docs/compat.md)** | One config on both Neovim 0.11 and 0.12 |
| `lua/ajay/whichkey.lua` | **[docs/whichkey.md](docs/whichkey.md)** | which-key prefix hints |

### UI

| File | Docs | What it does |
|---|---|---|
| `lua/ajay/colorscheme.lua` | **[docs/colorscheme.md](docs/colorscheme.md)** | VS Code Dark+, and how to switch themes |
| `lua/ajay/icons.lua` | **[docs/icons.md](docs/icons.md)** | Nerd Font glyphs defined by codepoint |
| `lua/ajay/transparency.lua` | **[docs/transparency.md](docs/transparency.md)** | Transparent-background toggle (`<leader>tt`) |
| *(inline in `plugins.lua`)* | **[docs/qol.md](docs/qol.md)** | lualine, indent guides, undotree, rainbow delimiters |

### Editing and language support

| File | Docs | What it does |
|---|---|---|
| `lua/ajay/lsp.lua` | **[docs/lsp.md](docs/lsp.md)** | Mason, servers, diagnostics, shared `LspAttach`, CodeLens, glance |
| `lua/ajay/cmp.lua` | **[docs/cmp.md](docs/cmp.md)** | Completion, LuaSnip, custom snippets |
| `lua/ajay/treesitter.lua` | **[docs/treesitter.md](docs/treesitter.md)** | Highlighting, indent, textobjects (`main` branch) |
| `lua/ajay/conform.lua` | **[docs/conform.md](docs/conform.md)** | Formatting and format-on-save |
| `lua/ajay/comment.lua` | **[docs/comment.md](docs/comment.md)** | Comment toggling and the `Ctrl+/` story |
| `lua/ajay/telescope.lua` | **[docs/telescope.md](docs/telescope.md)** | Fuzzy finder, all `<leader>f` mappings |
| `lua/ajay/harpoon.lua` | **[docs/harpoon.md](docs/harpoon.md)** | Quick file marks |

### Git

| File | Docs | What it does |
|---|---|---|
| `lua/ajay/gitsigns.lua` | **[docs/gitsigns.md](docs/gitsigns.md)** | Gutter signs, hunk staging, blame |

### Debugging

| File | Docs | What it does |
|---|---|---|
| `lua/ajay/dap.lua` | **[docs/dap.md](docs/dap.md)** | Python, Go, C/C++, Rust, Java |

### Java

| File | Docs | What it does |
|---|---|---|
| `lua/ajay/jdtls.lua` | **[docs/jdtls.md](docs/jdtls.md)** | JDK selection, Lombok, workspaces, Java refactors |

### Diagnostic

| File | Docs | What it does |
|---|---|---|
| `lua/ajay/doctor.lua` | **[docs/doctor.md](docs/doctor.md)** | `:AjayDoctor` |

### Cross-cutting reference

| Page | Contents |
|---|---|
| **[docs/keymap-reference.md](docs/keymap-reference.md)** | Every mapping in the config, grouped by prefix |
| **[docs/commands.md](docs/commands.md)** | Every custom `:Command` |
| **[docs/api.md](docs/api.md)** | Extending the config: module contract, extension points, recipes, invariants |
| **[docs/performance.md](docs/performance.md)** | Every speed decision: startup, navigation, responsiveness |
| **[docs/inactive-modules.md](docs/inactive-modules.md)** | Record of removed modules and plugins, and why |

Full per-file documentation lives in **[`docs/`](docs/README.md)**.

---

## Feature flag

Set at the top of `init.lua`:

| Flag                   | Default | Effect                                                                                                  |
| ---------------------- | ------- | ------------------------------------------------------------------------------------------------------- |
| `vim.g.have_nerd_font` | `true`  | Set `false` on a terminal without a patched font. Icons degrade to ASCII instead of showing tofu boxes. |

Two optional escape hatches, both set in `options.lua` and neither on by
default:

```lua
-- Which JDK runs jdtls, instead of $JAVA_HOME (see docs/jdtls.md)
vim.g.jdtls_java_home = "/usr/lib/jvm/java-21-openjdk"

-- Skip treesitter for a language and fall back to Vim regex syntax
-- (see docs/treesitter.md)
vim.g.ts_disabled_langs = { markdown = true, markdown_inline = true }
```

---

## Requirements

### Required — nothing works properly without these

| Tool                                                 | Why                                                                                                                                                                                                                               | Minimum   |
| ---------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------- |
| **Neovim**                                           | The config uses the 0.11+ LSP API (`vim.lsp.config`, `vim.diagnostic.jump`, `client:supports_method()`). On anything older, `init.lua` prints what to install and stops.                                                          | **0.11+** |
| **git**                                              | lazy.nvim bootstraps itself and clones every plugin                                                                                                                                                                               | any       |
| **A C compiler** (`cc` / `clang` / `gcc`) + **make** | Builds `telescope-fzf-native` and LuaSnip's `jsregexp`. Without it the config still starts — those pieces disable themselves — but fuzzy matching is slower.                                                                      | any       |
| **`tree-sitter` CLI**                                | **Required to build treesitter parsers.** nvim-treesitter's `main` branch shells out to the `tree-sitter` binary to compile every parser — a C compiler alone is not enough. Without it you get **no syntax highlighting at all**. | any       |
| **A Nerd Font** in your _terminal profile_           | Every icon in the statusline, gutter and pickers. This is a terminal setting, not a Neovim setting — no Lua can fix a wrong terminal font.                                                                                        | v3+       |
| **ripgrep** (`rg`)                                   | Telescope `live_grep` and `grep_string`                                                                                                                                                                                           | any       |
| **fd**                                               | Faster Telescope file finding (optional but strongly recommended)                                                                                                                                                                 | any       |
| **Node.js**                                          | Mason installs `pyright` from npm                                                                                                                                                                                                 | 18+       |
| **Python 3** with `venv`                             | Mason installs `black`, `isort` and `debugpy` into Python virtual environments                                                                                                                                                    | 3.9+      |
| **unzip**, **curl**                                  | Mason downloads and extracts packages                                                                                                                                                                                             | any       |

### Language-specific — install only what you use

| Language    | Needs                                                                                                                                                                                                                                                         |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Java**    | A **JDK 21+** to _run_ jdtls — found via `$JAVA_HOME`, else `PATH` and the usual install directories (see [docs/jdtls.md](docs/jdtls.md)). Your project can still target 8/11/17 by setting `$JAVA_HOME` to that JDK. Plus Maven or Gradle (the wrappers `mvnw`/`gradlew` are enough). Optionally `lombok.jar`. |
| **C / C++** | `g++`/`clang++`, `cmake` for the `<leader>cb` build map. `clangd` and `codelldb` come from Mason.                                                                                                                                                              |
| **Python**  | `python3`, `pytest` if you use the DAP test maps. `pyright`, `debugpy`, `black`, `isort` and `ruff` come from Mason.                                                                                                                                          |
| **Go**      | The Go toolchain — Mason builds `gopls`, `goimports` and `gofumpt` with it. **Install `dlv` yourself** (`go install github.com/go-delve/delve/cmd/dlv@latest`) — Mason does not try, because the build fails without Go and it retried forever.              |
| **Rust**    | `cargo` (via `rustup`) — `rust_analyzer` refuses to start without it. `rust-analyzer` and `codelldb` come from Mason.                                                                                                                                          |

### Installed automatically by Mason

You do not install these by hand. The first time you open a file, Mason fetches
whatever is missing:

**LSP servers:** `pyright`, `clangd`, `jdtls`, `gopls`, `rust_analyzer`, `lua_ls`

**Formatters/tools:** `clang-format`, `black`, `isort`, `ruff`, `stylua`,
`google-java-format`, `shfmt`, `goimports`, `gofumpt`

**DAP adapters:** `debugpy`, `codelldb`, `java-debug-adapter`, `java-test`

> Mason installs into `~/.local/share/nvim/mason/`. Only the servers listed
> above are ever enabled, even if Mason has others installed.

---

## Setup — macOS

```bash
# 1. Homebrew, if you don't have it
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Core
brew install neovim git ripgrep fd node python3 unzip curl cmake tree-sitter

# 3. Compiler toolchain (needed for telescope-fzf-native)
xcode-select --install

# 4. A Nerd Font
brew install --cask font-jetbrains-mono-nerd-font
#    …then set it as the font in your TERMINAL's profile settings.

# 5. Java — a JDK 21 to run jdtls. Your projects can still target 17.
brew install --cask zulu@21

# 6. Optional: Lombok, if you use @Data / @Getter
mkdir -p ~/.local/share/lombok
curl -L -o ~/.local/share/lombok/lombok.jar https://projectlombok.org/downloads/lombok.jar

# 7. Clone this config
git clone <your-repo-url> ~/.config/nvim

# 8. First launch — lazy.nvim bootstraps, Mason installs everything.
nvim
```

**macOS notes**

- The clipboard provider is pinned explicitly to `pbcopy`/`pbpaste` in
  `options.lua`. Auto-detection is order-dependent and Mason prepends its own
  `bin` to `PATH`, which is how a yank silently stops working.
- If `$JAVA_HOME` is unset or older than 21, jdtls asks
  `/usr/libexec/java_home` for a JDK 21+.
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
sudo apt install -y git ripgrep fd-find build-essential cmake unzip curl python3-venv
# fd is called fdfind on Debian:
ln -s "$(which fdfind)" ~/.local/bin/fd

# Node 18+ (distro node is often 12/16)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# tree-sitter CLI — REQUIRED to build parsers on the `main` branch.
sudo npm install -g tree-sitter-cli

# JDK 21 to run jdtls
sudo apt install -y openjdk-21-jdk

# ── Arch ───────────────────────────────────────────────────────────
sudo pacman -S neovim git ripgrep fd base-devel cmake unzip curl \
               nodejs npm python jdk21-openjdk tree-sitter-cli

# ── Fedora ─────────────────────────────────────────────────────────
sudo dnf install -y neovim git ripgrep fd-find gcc gcc-c++ make cmake unzip curl \
                    nodejs java-21-openjdk-devel
sudo npm install -g tree-sitter-cli
```

Then, on any distro:

```bash
# Optional: JAVA_HOME. jdtls finds a JDK 21+ on its own, but setting this is
# how you pick which JDK your PROJECT compiles against.
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk

# Nerd Font
mkdir -p ~/.local/share/fonts
cd ~/.local/share/fonts
curl -fLO https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
unzip -o JetBrainsMono.zip && fc-cache -fv
#   …then set it as the font in your TERMINAL's profile settings.

# Optional: Lombok
mkdir -p ~/.local/share/lombok
curl -L -o ~/.local/share/lombok/lombok.jar https://projectlombok.org/downloads/lombok.jar

# Clone and launch
git clone <your-repo-url> ~/.config/nvim
nvim
```

**Linux notes**

- The clipboard provider is pinned explicitly: `wl-copy` on Wayland, then
  `xsel` or `xclip` on X11. Install `wl-clipboard`, or `xsel`/`xclip`. Anything
  else (SSH, tmux) is left to Neovim's auto-detection.
- **jdtls finds a JDK without `$JAVA_HOME`** — it follows `java` on `PATH` and
  looks in `/usr/lib/jvm` and friends. Set `$JAVA_HOME` to choose which JDK your
  project compiles against.
- `Ctrl+/` sends `0x1F` (`<C-_>`) on most Linux terminals, so it works out of
  the box here.

---

## First launch — what to expect

1. lazy.nvim clones itself, then clones all 38 plugins. Takes a few minutes.
2. `telescope-fzf-native` compiles (skipped silently if you have no compiler).
3. Treesitter compiles parsers for the 19 configured languages into
   `~/.local/share/nvim/site/parser`.
4. The first time you open a file, Mason installs the LSP servers, formatters
   and DAP adapters listed above. Watch progress with `:Mason`.
5. Restart Neovim once everything settles.

> **Upgrading an existing install?** This config moved nvim-treesitter from the
> frozen `master` branch to `main`. Switching branches does **not** rebuild
> parsers, and stale ones cause `attempt to call method 'range' (a nil value)`.
> Run `:TSReset` once and restart.

## Verifying the install

| Command                                | Checks                                                                                                                                         |
| -------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `:AjayDoctor`                          | Nerd Font rendering, devicons, clipboard round-trip, `Ctrl+/` keycode, terminal identification. **Run this first when something looks wrong.** |
| `:checkhealth`                         | Neovim's own providers (Node, clipboard, treesitter)                                                                                           |
| `:Lazy`                                | Plugin install/load state and startup profile                                                                                                  |
| `:Mason`                               | LSP/formatter/DAP install state                                                                                                                |
| `:ConformInfo`                         | Which formatter will run on this buffer                                                                                                        |
| `:checkhealth vim.lsp`                 | Which servers are attached and their root dir (`:LspInfo` is a 0.11-only alias; lspconfig does not define it on 0.12)                          |
| `:JdtlsLog`                            | The Eclipse-side jdtls log — where the real Java errors hide                                                                                   |
| `:lua require("ajay.icons").preview()` | Renders every glyph the config uses                                                                                                            |

## Troubleshooting

| Symptom                                    | Likely cause                                                                                                     |
| ------------------------------------------ | ---------------------------------------------------------------------------------------------------------------- |
| Boxes or blanks instead of icons           | Terminal font is not a Nerd Font. Fix the terminal profile, not Neovim. Confirm with `:AjayDoctor`.              |
| Yank doesn't reach the system clipboard    | Missing provider. Run `:checkhealth vim.provider`. Install `wl-clipboard` (Wayland) or `xsel`/`xclip` (X11).     |
| `Ctrl+/` does nothing                      | Your terminal swallows it. Use `gcc` / `gc{motion}` / `gbc`. See [docs/comment.md](docs/comment.md).             |
| "jdtls needs JDK 21+ to run, and none was found" | No JDK 21+ in `$JAVA_HOME`, on `PATH`, or in the usual install directories. Install one, or set `vim.g.jdtls_java_home`. |
| Java shows "cannot find symbol: getName()" | Lombok jar not found. See [docs/jdtls.md](docs/jdtls.md).                                                        |
| jdtls exits with code 13                   | Wrong JVM version running the server. `:AjayDoctor`, then install JDK 21.                                        |
| `[rust_analyzer] cargo not found.`         | No Rust toolchain. `rustup default stable`.                                                                      |
| `attempt to index a boolean value`         | A module file is truncated and missing its trailing `return M`. The `setup_module()` wrapper reports which file. |
| Nothing is highlighted, and `Error during "tree-sitter build" ... ENOENT: 'tree-sitter'` on startup | The `tree-sitter` CLI is missing. `brew install tree-sitter`, or `npm install -g tree-sitter-cli`. |

---

## Startup performance

Measured with `nvim --headless --startuptime`, median of 15 runs:

| Scenario | Time |
|---|---|
| `nvim` with no file | **15.6 ms** |
| `nvim main.py` (LSP + git + treesitter wired up) | **~60 ms** |

## Responsiveness

Boot time is the easy half. The numbers you actually feel:

| What | Time |
|---|---|
| Typing, per keystroke | **0.007 ms** (0.435 ms in a 5 000-line file) |
| Cursor movement, 5 000-line file | **0.002 ms** |
| Buffer switch | **0.30 ms** (3.24 ms with a 5 000-line buffer loaded) |
| Treesitter reparse after an edit | **1.44 ms** |
| Opening a file — 2nd of that language onward | **~2 ms** |
| Opening a file — **1st of that language in the session** | 21–170 ms |

That last row is the only one that looks bad, and it is a **once-per-session,
per-language** cost: lazy.nvim loading that filetype's plugins plus the
treesitter parser. Open a second file of the same language and it drops to ~2 ms.
Language servers attach **asynchronously afterwards**, so they never block the
buffer from being open and editable.

The config is tuned for this, not just boot: Telescope drives `fd`/`rg` directly
so filtering happens in Rust rather than Lua, completion is tuned for the
thousand-candidate lists Java produces, CodeLens no longer fires redundant
project-wide LSP round trips on every `InsertLeave`, and
[`bigfile.lua`](docs/bigfile.md) stops a large file from freezing the editor.

**Full rationale for every decision, and how to reverse any of them, is in
[docs/performance.md](docs/performance.md).**

> **Caveat on the numbers:** `--headless` does not fire `UIEnter`, so plugins on
> the `VeryLazy` event — lualine and which-key here — are not included. In a real
> terminal they load *after* the first draw, so they do not delay
> time-to-interactive, but the wall-clock total is a little higher.

---

## Documentation index

Every module has its own page under [`docs/`](docs/README.md), covering what it
does, which settings are enabled and **why**, and every keymap it defines.

- [docs/README.md](docs/README.md) — index of all module pages
- [Full keymap cheat sheet](docs/keymap-reference.md)
- [Every custom command](docs/commands.md)
- [Extending the config](docs/api.md)

Or jump straight to a file from the [directory layout](#directory-layout) tables
above.
