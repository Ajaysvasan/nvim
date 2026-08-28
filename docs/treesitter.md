# `treesitter.lua` — syntax, indent, textobjects

[nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) on the
**`main` branch**. Loaded eagerly (`lazy = false`).

> ## ⚠️ Rewritten for the `main` branch
>
> This config was previously pinned to `branch = "master"` with the comment
> *"main is the rewrite, incompatible API"*. That was right for Neovim 0.10/0.11
> and **wrong for 0.12**.
>
> On 0.12, master's `query_predicates.lua` calls `get_node_text()` on a value
> that is no longer a node, and the markdown query's
> `(#set! conceal_lines "")` directive on fenced-code-block delimiters trips it
> on every render. That is the
>
> ```
> attempt to call method 'range' (a nil value)
> ```
>
> error you hit opening `README.md` — a file full of ``` blocks.
>
> It is a known upstream break (nvim-treesitter #8618, #8636; neovim #39032)
> with **no fix coming on master, because master is frozen**. `main` is the
> supported branch for 0.11+.

## What changed in the API

| master (old) | main (now) |
|---|---|
| `require("nvim-treesitter.configs").setup{...}` | Gone entirely |
| Parsers via `ensure_installed` in that table | `require("nvim-treesitter").install{...}` |
| Highlighting automatic | **You call `vim.treesitter.start()` per buffer** |
| Indent enabled by a config flag | Opt-in per buffer via `indentexpr` |
| `incremental_selection` keymaps table | **Removed — no built-in replacement** |
| `textobjects` keymaps table | You bind the selection function yourself |

### Why the plugin is now `lazy = false`

On `main`, highlighting is started by a `FileType` autocmd that this module
registers. The plugin therefore has to be **loaded before the first `FileType`
event**, not by it — which is what `event = { "BufReadPost", "BufNewFile" }`
used to do. Loading it lazily would mean the autocmd registers too late to
highlight the first file you open.

## ⚠️ The `tree-sitter` CLI is now required

The `main` branch **shells out to the `tree-sitter` binary** to compile parsers.
A C compiler alone is no longer enough, which it was on `master`. Without the
CLI, every parser build fails:

```
Error during "tree-sitter build": ENOENT: no such file or directory (cmd): 'tree-sitter'
```

and you get **no treesitter highlighting at all** — Neovim silently falls back
to regex syntax. Worse, `install()` retries on every startup, so it re-downloads
all 22 grammars each launch and fails at the compile step each time.

```bash
brew install tree-sitter            # macOS
npm install -g tree-sitter-cli      # anywhere with npm
```

Then `:TSReset` and restart.

## Installed parsers

`c`, `cpp`, `python`, `java`, `javascript`, `typescript`, `tsx`, `html`, `css`,
**`scss`**, **`angular`**, `json`, `lua`, `luadoc`, `bash`, `markdown`,
`markdown_inline`, `vim`, `vimdoc`, `regex`, `query`, **`xml`**, **`yaml`**,
**`properties`**

`xml`, `yaml` and `properties` are Java-motivated: `xml` for `pom.xml`, `yaml`
for `application.yml`, `properties` for `application.properties`.

`scss` and `angular` close two gaps where a filetype the config otherwise
supports fully was silently falling back to regex syntax:

| Parser | Why it was missing | What it fixes |
|---|---|---|
| `scss` | `css` was listed, `scss` was not — but they are **separate parsers**, not one language | `.scss` files, which conform already formats and `cssls` already attaches to |
| `angular` | `.component.html` resolves to filetype `htmlangular`, which maps to language **`angular`**, not `html` | Angular templates — see [lsp.md](lsp.md#angularls--root_markers-is-not-a-gate) |

**A filetype is not a language.** `vim.treesitter.language.get_lang(ft)` does the
translation, and `htmlangular → angular` is the case that catches people out:
adding `html` to the list does nothing for Angular templates. Check with
`:TSStatus`, which prints both.

`markdown_inline` is separate from `markdown` and required for inline code spans,
links and emphasis to highlight. `vim` + `vimdoc` + `query` + `luadoc` make
editing this config itself pleasant.

## The parser directory is pinned

```lua
local install_dir = vim.fn.stdpath("data") .. "/site"
ts.setup({ install_dir = install_dir })
```

Set explicitly so it is a **known path you can wipe**.

Stale parsers are the usual cause of `attempt to call method 'range'`: a parser
built against an older grammar lacks nodes the newer query expects, the capture
resolves to `nil`, and a directive then calls a method on it. **Switching plugin
branches does not rebuild parsers** — which is exactly the situation this config
is now in, so run `:TSReset` once after this change.

Both `ts.setup()` and `ts.install()` are wrapped in `pcall`, and the initial
`require` warns and returns rather than erroring.

**`ts.install()` is scheduled and heavily guarded.** Three things, in order:

1. **Scheduled**, so neither the check nor any download happens before the editor
   is interactive. Highlighting is driven by the `FileType` autocmd below, which
   already `pcall`s around a parser that is still installing.
2. **Guarded on the `tree-sitter` CLI existing.** Without it, `install()` still
   downloads all 22 grammars and *only then* fails at the compile step — on every
   single startup. That is a pile of network jobs and a wall of errors for work
   that cannot possibly succeed. Now it checks, says something actionable once,
   and does nothing.
3. **Diffed against `get_installed()`**, so it only asks for parsers that are
   actually missing. `install()` on the full list is not free even when
   everything is present, and this runs at every launch.

## Highlighting — the `FileType` autocmd

In the `ajay_treesitter` group, for every buffer:

1. Skip buffers with an empty filetype
2. Resolve the language with `vim.treesitter.language.get_lang(ft)`
3. Skip if the language is in `vim.g.ts_disabled_langs`
4. `pcall(vim.treesitter.start, buf, lang)` — **`pcall` because
   `vim.treesitter.start()` throws when the parser isn't installed yet**, which
   is normal on first launch while `install()` is still running. Without the
   guard you get an error on every buffer.
5. Set treesitter indent — but only conditionally, see below

### The escape hatch

```lua
-- in options.lua
vim.g.ts_disabled_langs = { markdown = true, markdown_inline = true }
```

Skips treesitter for those languages and falls back to Vim's regex syntax.
Useful when an upstream parser/query combination is broken — markdown with
fenced code blocks has been the recurring one on Neovim 0.12.

### Indent

```lua
if ft ~= "java" and vim.bo[buf].indentexpr == "" then
  vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
end
```

Two guards, both deliberate:

- **`indentexpr == ""`** — only set it where nothing better already is. An
  ftplugin or a language server that provides its own indentation wins.
- **`ft ~= "java"`** — Java is excluded outright. jdtls provides its own
  indentation and the two disagree about continuation lines and annotations.

## Textobjects

Also a different API on `main`: no keymaps table, you bind the selection function
yourself. Guarded by `pcall` so a missing textobjects plugin doesn't break
highlighting.

`lookahead = true` — if the cursor isn't inside a function/class, it jumps
forward to the next one rather than failing.

| Textobject | Selects |
|---|---|
| `af` | A function, including its signature and braces |
| `if` | Just the function body |
| `ac` | A class, including its declaration |
| `ic` | Just the class body |
| `aa` | A parameter, including the comma |
| `ia` | Just the parameter |

Mapped in `x` and `o` mode, so they work with any operator: `daf` delete a
function, `yic` yank a class body, `cia` change a parameter, `vaf` select a
function.

## ⚠️ Incremental selection is gone

`gnn` / `grn` / `grc` / `grm` **no longer exist**. Incremental selection was
removed in the `main` rewrite and there is **no built-in replacement in 0.12**.
This is flagged here rather than silently dropped.

If you relied on it, the closest substitutes are the textobjects above
(`vaf`, `vac`, `vaa`) or a plugin like
[nvim-treesitter/nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects)'s
`swap`/`move` modules.

## Commands

| Command | Action |
|---|---|
| `:TSReset` | **Delete every installed parser** from the pinned `install_dir`, then tell you to restart so they rebuild. Faster than remembering the path, and the path always matches because it's set in this file. Also prints a `find` command to check for stray `.so` files elsewhere. |
| `:TSStatus` | For the current buffer: filetype, resolved language, whether highlighting is actually ON, whether the language is in `ts_disabled_langs`, and **every `parser/<lang>.so` found on the runtimepath with its build date** — more than one means a conflict, which is the other classic source of `range` errors. |
| `:TSUpdate` / `:TSInstall` | Plugin built-ins |

**When something breaks, run `:TSStatus` first.** It distinguishes "no parser",
"parser disabled", and "two conflicting parsers" — three problems with very
similar symptoms.

## Big files

[`bigfile.lua`](bigfile.md) sets `vim.b[buf].bigfile` on files large enough that
a full parse would freeze the editor, and the `FileType` autocmd above returns
early on it — so treesitter never starts there at all.

## Related plugins

**`rainbow-delimiters.nvim`** loads on `BufReadPost` / `BufNewFile` with no
configuration — it colours matching bracket pairs by nesting depth using
treesitter's parse tree.

**`nvim-ts-context-commentstring`** is a dependency of Comment.nvim, not of
treesitter — see [comment.md](comment.md).

## Keymaps

Only the six textobjects above. Incremental selection is gone.
