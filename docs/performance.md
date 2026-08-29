# Performance

Every speed decision in the config, in one place. Three separate concerns:
**startup**, **navigation**, and **responsiveness while typing**.

## Startup, measured

`nvim --headless --startuptime`, median of 9 warm runs:

| Scenario | Originally | Now |
|---|---|---|
| `nvim` (no file) | ~19.5 ms | **15.4 ms** |
| `nvim <file>` | ~53.5 ms | **32.8 ms** |
| `nvim Main.java` (in a Maven project) | 762 ms | **196 ms** |

Re-measured after the language-server fixes (`angularls` and
`emmet_language_server` added, `eslint_d` dropped): **unchanged**. Enabling a
server costs nothing at startup — `vim.lsp.enable()` only registers it, and the
client is not started until a matching buffer opens.

## Responsiveness, measured

The numbers people actually feel. Same machine, warm caches:

| What | Time | Notes |
|---|---|---|
| Typing, per keystroke | **0.007 ms** | Normal-size file |
| Typing, per keystroke | **0.435 ms** | Inside a 5 000-line file |
| Typing brackets/quotes | **0.011 ms** | Exercises nvim-autopairs |
| Cursor move `j` | **0.002 ms** | 5 000-line file |
| Random jump + `zz` | **0.003 ms** | 5 000-line file |
| Buffer switch `:bnext` | **0.30 ms** | Small buffers |
| Buffer switch `:bnext` | **3.24 ms** | With a 5 000-line buffer in the ring |
| Treesitter incremental reparse | **1.44 ms** median, 2.19 ms worst | After an edit, 5 000 lines |
| Treesitter **first** parse | **142.8 ms** | One-time per buffer, 5 000 lines |

### The JDK scan was the worst offender — 762 ms → 196 ms

Found by benchmarking, not by reading code, and it had been there the whole
time. [`jdtls.lua`](jdtls.md#jdk-discovery) probes for installed JDKs by
shelling out: `/usr/libexec/java_home -V`, plus `java -version` for each
candidate it cannot version any other way. **`java -version` costs ~150 ms** —
it boots a JVM to print one line.

Three separate callers need that list, and it cached nothing, so opening a
single Java file ran the whole probe **four times**:

| | Before | After |
|---|---|---|
| Subprocesses per Java buffer | 13 | **4** |
| `nvim Main.java` | 762 ms | **196 ms** |

The fix is one memo: the set of installed JDKs cannot change while Neovim is
running. `:JdtlsRescanJDKs` busts it if you install one mid-session. Verified
identical behaviour afterwards — same launcher (Zulu 21), same runtimes
(JavaSE-21, JavaSE-17), JDK 26 still correctly excluded by `MAX_EE`.

**The lesson generalises:** anything calling `vim.fn.system()` on a buffer event
should be assumed to run more often than you think, and cached unless the answer
can actually change between calls.

### Opening files: cold vs warm

The one number that looks alarming and is not. Each language pays a **once per
session** cost the first time you open a file of that type — lazy.nvim loading
its plugins plus the treesitter parser `.so`. Every file after that is cheap.

Measured in a **separate nvim instance per language**, so no ordering bias:

| Language | Cold (1st of session) | Warm (every one after) |
|---|---|---|
| TypeScript | 91.6 ms | **3.1 ms** |
| TSX | 110.7 ms | **4.0 ms** |
| HTML | 24.7 ms | — |
| CSS / SCSS | 24.2 ms | **5.3 ms** |
| Python | 93.6 ms | — |
| C++ | 126.0 ms | — |

**Navigation is not slow — first contact is.** If you measure by opening one
file of each type in one session you will read the cold column and conclude the
config is sluggish; open a second file of the same type and it is 3–5 ms.

### LSP attach does not block

Time from buffer open to each client attaching:

| File | Buffer open | Clients attach at |
|---|---|---|
| `a.ts` | 93.7 ms | `ts_ls` @ 189 ms |
| `App.tsx` | 135.4 ms | `emmet_language_server` @ 217 ms, `ts_ls` @ 221 ms |
| `i.html` | 34.2 ms | `emmet_language_server` @ 132 ms, `html` @ 295 ms |
| `s.scss` | 35.3 ms | `emmet_language_server` @ 115 ms, `cssls` @ 196 ms |
| `m.py` | 145.2 ms | `pyright` @ 246 ms |
| `m.cpp` | 147.2 ms | `clangd` @ 206 ms |

Attach happens **after** the buffer is open and editable — it is asynchronous,
and the editor is responsive throughout. This is why adding two servers changed
nothing: an A/B with `emmet_language_server` and `angularls` disabled put the
difference **inside the ±2 ms noise floor** on every filetype tested.

> **Measurement caveat.** All of the above is `--headless`, which has no
> redraw. Keystroke and cursor figures are the cost of *processing* input, not
> of painting a frame — they are a lower bound on what you perceive, and
> scrolling cost cannot be measured this way at all. They are still the right
> numbers for comparing config changes against each other, which is what they
> are used for here.

---

## Startup

### Mason loads on demand, not at startup — ~12 ms

The big one. `mason.nvim`, `mason-lspconfig` and `mason-tool-installer` used to
be `dependencies` of `nvim-lspconfig`, and lazy.nvim loads dependencies *before*
the plugin — so a full `require("mason").setup()` ran on `BufReadPre`, building
the whole package registry, on every launch that opened a file.

Nothing about *running* a server needs it. All Mason contributes at runtime is
its `bin` directory on `PATH`. So:

1. [`options.lua`](options.md) puts that directory on `PATH` in one line.
2. [`lsp.lua`](lsp.md#mason-on-demand) stats each server/tool binary, enables
   what is present with `vim.lsp.enable()`, and only loads Mason when something
   is **missing** — scheduled off the first draw.

On a fully-installed machine **Mason never loads at all**. `:MasonSync` forces
the install pass by hand.

### Catppuccin plugin auto-detection off — ~2.9 ms

`auto_integrations` scans every installed plugin on every startup to guess which
integrations to enable. On this config it found exactly one thing the explicit
list did not already cover (`rainbow_delimiters`), now listed by hand. See
[colorscheme.md](colorscheme.md) for the trade-off.

### Treesitter installs only what is missing — ~1 ms, plus a lot of I/O

`ts.install()` on the full list ran inline at every launch. It is now
`vim.schedule`d, guarded on the `tree-sitter` CLI existing, and diffed against
`get_installed()` so it asks for nothing when everything is present.

> Without that CLI guard, a machine missing the binary **re-downloads all 22
> grammars on every single startup** and only then fails at the compile step.
> That was happening here. See [treesitter.md](treesitter.md).

### What is left

Roughly irreducible: lazy.nvim parsing 48 specs (~2.8 ms), Neovim's own
`ftplugin/lua.lua` (~2.3 ms), gitsigns attaching (~2.3 ms), catppuccin applying
(~2.3 ms).

---

## Navigation

### Telescope drives `fd` and `rg` explicitly

`find_files` is given an explicit `fd` command with `--type f --hidden --follow
--strip-cwd-prefix` and `--exclude` for `.git`, `node_modules`, `target`,
`build`, `dist`, `__pycache__`.

The point is *where* the filtering happens: `fd` applies excludes and reads
`.gitignore` in Rust, before results ever reach Lua. Letting them through and
matching `file_ignore_patterns` per result — the default path — is strictly more
work. There is a fallback if `fd` is absent, so the config still works, just
slower.

`live_grep` / `grep_string` get explicit `vimgrep_arguments` with
`--smart-case` (matching the editor's `ignorecase` + `smartcase`) and `--trim`,
which keeps deeply indented matches readable in a narrow results pane.

`telescope-fzf-native` is compiled (`libfzf.so`) and overrides both the generic
and file sorters — that is the native fuzzy matcher rather than the Lua one.

### Buffer switching

[`options.lua`](options.md)'s `mkview`/`loadview` autocmds persist folds and
cursor position, but they do **file I/O on every buffer switch**. They are scoped
to real, writable files *and* skip `vim.b.bigfile` buffers.

Measured cost: **0.30 ms** per switch, rising to **3.24 ms** once a 5 000-line
buffer is in the ring — see [Responsiveness, measured](#responsiveness-measured).

### Large files

[`bigfile.lua`](bigfile.md) is the whole story — a 1 MB / 2000-column gate that
switches off treesitter, regex syntax, LSP, codelens, git signs, indent guides,
format-on-save, undofile and `relativenumber`.

---

## Responsiveness while typing

### CodeLens no longer refreshes by hand — the biggest Java win

The config used to drive codelens refreshes from
`BufEnter` + `InsertLeave` + `BufWritePost` plus a deferred 800 ms kick, via
`vim.lsp.codelens.refresh()`.

All of it was redundant *and* actively harmful. Neovim 0.12 refreshes code
lenses itself: the codelens provider does `nvim_buf_attach{on_lines, on_reload}`
and issues its own internally-debounced request. The manual autocmds were
stacking **extra project-wide round trips** on top — and for jdtls each one
resolves references across the whole project, the single most expensive thing an
LSP does here. `InsertLeave` fires constantly.

It is now one call on attach, `vim.lsp.codelens.enable(true, { bufnr = bufnr })`,
matching the inlay-hint line above it. That also removes a deprecation warning:
`refresh()` is deprecated in 0.12 and **removed in 0.13**.

### Completion tuning

Completion runs on nearly every keystroke in insert mode, and Java/Spring
produce candidate lists in the thousands where cost is dominated by sorting and
rendering entries you will never scroll to.

| Setting | Default | Now | Why |
|---|---|---|---|
| `performance.debounce` | 60 | **30** | Keystroke → asking sources |
| `performance.throttle` | 30 | **20** | Min gap between filter/sort passes |
| `performance.fetching_timeout` | 500 | **200** | Stop waiting on a slow source instead of stalling the menu. jdtls can take seconds on a cold project. |
| `performance.max_view_entries` | 200 | **30** | Render cost is per visible entry |

The `buffer` source also keeps `keyword_length = 3` and now indexes only
**visible** buffers, skipping any flagged by [bigfile](bigfile.md) — so a session
with 30 buffers open does not pay to re-scan all of them.

### Diagnostics

`virtual_text` is limited to `severity.min = ERROR` and `update_in_insert` is
`false`, so there is no diagnostic churn mid-word. See [lsp.md](lsp.md).

---

## Measuring it yourself

| Command | Shows |
|---|---|
| `nvim --startuptime /tmp/st.log +q && sort -k2 -rn /tmp/st.log \| head -20` | Where startup time goes. **Note `--startuptime` appends**, so delete the file between runs. |
| `:Lazy profile` | Per-plugin load cost inside lazy.nvim |
| `:TSStatus` | Whether treesitter is actually on for this buffer, and whether parsers conflict |
| `:BigFileStatus` | Whether large-file protection kicked in here |
| `:ConformInfo` | Which formatter runs, and whether it is installed |
| `:checkhealth vim.lsp` | Attached servers and their root dirs |

> **Caveat on headless numbers:** `--headless` does not fire `UIEnter`, so
> `VeryLazy` plugins — lualine here — are not counted. In a real terminal they
> load *after* the first draw, so they do not delay time-to-interactive, but the
> wall-clock total is a little higher.
