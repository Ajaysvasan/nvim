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
| `nvim <file>.java` (in kafka, 6 178 Java files) | 108 ms | **68 ms** |

The kafka row is the newest measurement and came from caching the JDK probe to
disk — see [Then cached to disk](#then-cached-to-disk--108-ms--68-ms-on-kafka).
It is lower than the Maven row above because that 196 ms figure predates the
disk cache.

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

### Readiness on a real monorepo — `~/Documents/kafka`

Synthetic files only tell you so much. Measured against kafka itself (~6 200
Java files, 567 MB, 20+ Gradle modules) with a warm jdtls workspace:

| Milestone | Time |
|---|---|
| Buffer drawn | **108 ms** |
| jdtls attached | 3.0 s |
| First diagnostics | 4.9 s |
| Completion, cold | 98 ms |
| Completion, warm | 34 ms |
| Hover | 151 ms |
| Go to definition | 4 ms |
| 2nd Java file (jdtls warm) | 190 ms |

And the editing path itself, in the same repo:

| What | Time |
|---|---|
| Typing, 1 831-line file | **0.117 ms** avg, 1.85 ms worst |
| Scrolling, 10 073-line file | **0.03 ms** per page |
| Buffer switch (4 buffers, mkview/loadview live) | **0.6 ms** |
| Opening a 30 692-line file | 11 ms — correctly gated by [bigfile](bigfile.md) |

#### Is the ~3 s attach a bottleneck? No — measured, it is 2 s of JVM

The obvious suspicion is that kafka's size causes it. It does not. Attaching to
a **one-file Maven project** was measured for comparison, and then again with
the debug bundles removed, which decomposes the whole number:

| Component | Time | Reducible? |
|---|---|---|
| JVM boot + Eclipse OSGi framework | **~1 950 ms** | No — this is what jdtls *is* |
| 32 `java-debug-adapter` + `java-test` bundle jars | **~417 ms** | Only by giving up `<leader>db` and `<leader>jt` |
| kafka's 6 178 files across 20+ Gradle modules | **~490 ms** | No |
| **Total** | **~2 857 ms** | |

| Project | attach | first diagnostics |
|---|---|---|
| 1 Java file, Maven | 2 367 ms | 3 952 ms |
| 1 Java file, no debug bundles | 1 950 ms | 3 586 ms |
| kafka (6 178 files) | 2 857 ms | 7 889 ms |

So **~68 % of the attach is fixed cost** that no setting in this config touches,
and going from one file to a 6 000-file monorepo adds only ~0.5 s. That is the
opposite of a bottleneck — it is jdtls scaling well.

**Diagnostics** are the part that genuinely scales with project size (3.9 s →
7.9 s), because the classpath for the compilation unit has to be resolved
against every module. Also once per session, and the editor is fully usable
while it happens — see [LSP attach does not block](#lsp-attach-does-not-block).

The 417 ms for bundles is the price of Java debugging working at all; without
them `<leader>db` sets a breakpoint that never binds and `<leader>jt` has
nothing to run. Worth knowing, not worth removing.

> **A number that did not survive re-measurement.** One run showed a 14.4 s cold
> completion and it looked like *the* bottleneck. It did not reproduce — two
> further runs measured 98 ms and 118 ms. It was jdtls doing background work
> after benchmark runs had disturbed the workspace, not a property of the
> config. Recorded here because "measure it twice before you tune it" is the
> actual lesson; nothing was changed on the strength of it.

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

#### Then cached to disk — 108 ms → 68 ms on kafka

Re-measured against a real monorepo (`~/Documents/kafka`, ~6 200 Java files, 20+
Gradle modules) the memo turned out not to be the end of it. It is a *session*
memo, so the probe still ran **once per session**, on the first Java file you
open, and all of it is blocking subprocess work:

| Call | Cost |
|---|---|
| `/usr/libexec/java_home -V` | 41 ms |
| `unzip -p <jdt core jar> META-INF/MANIFEST.MF` | 17 ms |
| `java -version` (per JDK it cannot version otherwise) | 48 ms each |

That is exactly why the **first** Java file measured 108 ms while every one
after it measured 7 ms. The set of installed JDKs changes when you install a
JDK — roughly never — so paying it every session is pure waste.

It is now persisted to `stdpath("cache")/ajay-jdtls-probe.json`. Invalidation is
the whole game, and it is deliberately cheap:

- **Every cached JDK path is re-checked with `executable()`** — an fs stat,
  microseconds, not a subprocess. A JDK you deleted or moved invalidates the
  cache instead of being handed to Eclipse as a runtime that no longer exists.
  `has_javac` is re-stat'd too, since that is what decides whether an entry is a
  valid Eclipse runtime at all.
- **The jdtls jar filename is part of the key**, and it carries the version
  (`org.eclipse.jdt.ls.core_1.60.0.202606262232.jar`), so a Mason upgrade re-reads
  the manifest rather than trusting a stale minimum.
- **`:JdtlsRescanJDKs` deletes the file**, then re-probes.

| | Session memo only | Plus disk cache |
|---|---|---|
| JDK probe | 34.8 ms | **0.2 ms** |
| `nvim <kafka java file>` | 108 ms | **68 ms** |

Verified afterwards: same launcher (Zulu 21), same `-Xmx4g`, exactly one client,
and no new globals leaked into `_G`.

> A latent bug surfaced while doing this. `:JdtlsRescanJDKs` has to reset
> `cached_min`, but that local was declared *further down the file* than the
> command — and a `local` declared later is not in scope for a closure defined
> earlier, so the assignment would have silently created a **global** and never
> cleared the real cache. It is forward-declared now, next to `cached_jdks`.

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

### Navigation, measured on kafka

24 000 files, 6 178 of them Java, 567 MB. The raw tools are the floor Telescope
cannot beat, so both are listed:

| What | Time | Floor (raw tool) |
|---|---|---|
| `find_files` → first 1 000 results | **92 ms** | `fd` = 80 ms |
| `find_files` → fully populated (7 454) | ~4 s (streaming; usable throughout) | |
| `live_grep "KafkaProducer"` → first 50 | **85 ms** | `rg` = 220 ms full scan |
| `live_grep` → settled (606 results) | ~5 s (streaming) | |
| Preview render, per selection move | **2.9 ms** avg, 5.2 ms worst | |
| Neo-tree open at kafka root | **53 ms** | |

Both pickers *stream* — results appear at essentially the speed of `fd`/`rg` and
keep filling while you type, so the "settled" figures are not a wait you feel.

The **53 ms** neo-tree figure is the interesting one: `follow_current_file` is on,
so opening the tree from a file 8 directories deep expands that entire path
(121 rows rendered) rather than just listing the root.

Preview cost was re-checked after `preview_width` was raised to `0.6` (see
[telescope.md](telescope.md)): **2.9 ms**. A wider preview costs nothing extra —
the previewer's work scales with the *lines* it highlights, not the columns.

> Measured in a real terminal, not headless. Telescope's previewer never renders
> under `--headless` because there is no UI to drive it, so a headless run
> reports zero preview cost and is simply wrong.

### Large files

[`bigfile.lua`](bigfile.md) is the whole story — a 1 MB / 2000-column gate that
switches off treesitter, regex syntax, LSP, codelens, git signs, indent guides,
format-on-save, undofile and `relativenumber`.

Confirmed against kafka: a 30 692-line Java file opens in **11 ms** with
treesitter off and no LSP attached, while a 10 073-line file keeps both.

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
