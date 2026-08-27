# `cmp.lua` — completion

[nvim-cmp](https://github.com/hrsh7th/nvim-cmp) with LuaSnip. Loads on
`InsertEnter` / `CmdlineEnter`.

The whole file is guarded: if either `cmp` or `luasnip` fails to `require`, it
returns silently rather than erroring at every keystroke.

## Sources and priority

Listed highest-priority first — this order is the config's opinion about what
you most likely want:

| Source | Priority | Menu tag | Why |
|---|---|---|---|
| `copilot` | 1100 | `[AI]` | AI suggestions surface above everything else |
| `nvim_lsp` | 1000 | `[LSP]` | The type-correct answers |
| `luasnip` | 750 | `[Snip]` | Snippets below real symbols so they don't hijack a name you're typing |
| `path` | 500 | `[Path]` | |
| `buffer` | 250 | `[Buf]` | Lowest, and `keyword_length = 3` — plain word matches only kick in after 3 characters, otherwise they flood the menu |

The `buffer` source also has a custom `get_bufnrs` that indexes only **visible**
buffers, and skips anything [bigfile](bigfile.md) has flagged. cmp's default is
the current buffer only; widening it to every *listed* buffer is a common "make
it smarter" tweak that quietly turns into a full re-scan of every open file. This
caps it at what is on screen, so a session with 30 buffers open does not pay for
all of them.

The `formatting.format` function writes those bracketed tags into the menu
column so you can see at a glance where a suggestion came from.

## Performance tuning

Completion is the hottest path in the editor — it runs on nearly every keystroke
in insert mode. The defaults are tuned for small buffers; Java and Spring produce
candidate lists in the thousands, where cost is dominated by **sorting and
rendering entries you will never scroll to**.

| Setting | Default | Here | Why |
|---|---|---|---|
| `performance.debounce` | 60 | **30** | Time from keystroke to asking sources |
| `performance.throttle` | 30 | **20** | Minimum gap between filter/sort passes |
| `performance.fetching_timeout` | 500 | **200** | Stop waiting on a slow source rather than stalling the menu. jdtls can take seconds on a cold project; the menu should show what the fast sources returned. |
| `performance.max_view_entries` | 200 | **30** | Render cost is per *visible* entry |

## Windows

Both the completion menu and the documentation window use
`cmp.config.window.bordered()`, matching the rounded borders used elsewhere.

## Keymaps (insert mode, inside the completion menu)

| Key | Action |
|---|---|
| `<C-b>` | Scroll docs up 4 lines |
| `<C-f>` | Scroll docs down 4 lines |
| `<C-Space>` | Trigger completion manually |
| `<C-e>` | Abort |
| `<CR>` | Confirm the selected entry (`select = true` — confirms the first entry even if you never moved) |
| `<Tab>` | Menu visible → next item · else in a snippet → jump to next placeholder · else → fall through to a literal tab |
| `<S-Tab>` | Menu visible → previous item · else in a snippet → jump back · else → fall through |

`<Tab>`/`<S-Tab>` are mapped in both insert (`i`) and select (`s`) mode so
snippet placeholder jumping works while text is selected.

> Copilot has its own separate accept key, `<M-l>` — see [copilot.md](copilot.md).
> Copilot suggestions appear *both* as ghost text (accept with `<M-l>`) and as
> `[AI]` entries in this menu (accept with `<CR>`).

## Snippets

`friendly-snippets` is lazy-loaded via
`require("luasnip.loaders.from_vscode").lazy_load()` — that's the community
snippet collection for every language.

On top of that, this file defines its own:

### HTML — `!`
Full HTML5 boilerplate: doctype, `lang="en"`, charset, viewport meta, a
`<title>` placeholder, and the cursor landing inside `<body>`.

### Java — `!`
`public class <Name>` with a `main` method, cursor inside it.

### JSX/TSX — registered for `javascriptreact`, `typescriptreact`, `javascript`, `typescript`

| Trigger | Expands to |
|---|---|
| `div` | `<div>…</div>` |
| `divc` | `<div className="…">…</div>` |
| `span` | `<span>…</span>` |
| `p` | `<p>…</p>` |
| `h1` | `<h1>…</h1>` |
| `h2` | `<h2>…</h2>` |
| `button` | `<button>…</button>` |
| `input` | `<input type="text" />` |

## Related

- [copilot.md](copilot.md) — the `copilot` source is registered by `copilot-cmp`
- [lsp.md](lsp.md) — `cmp_nvim_lsp.default_capabilities()` is what tells servers
  this client supports snippets and additional text edits
