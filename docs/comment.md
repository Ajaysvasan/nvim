# `comment.lua` — commenting

[Comment.nvim](https://github.com/numToStr/Comment.nvim) with
[nvim-ts-context-commentstring](https://github.com/JoosepAlviste/nvim-ts-context-commentstring).

## Why this broke on the Mac

The old config did this:

```lua
toggler  = { line = '<C-_>', block = '<C-S-_>' },
opleader = { line = '<C-_>', block = '<C-S-_>' },
```

`toggler` and `opleader` are **not "extra keys" — they replace the defaults.**
Setting them to `<C-_>` deleted `gcc` and `gc` entirely. So the only way to
comment anything was `Ctrl+/`, and if the terminal didn't deliver that exact
byte, you had no comment mapping at all.

**On Linux**, `Ctrl+/` sends `0x1F`, which Neovim reads as `<C-_>`. That's the
legacy encoding, and it's why it worked there.

**On macOS it depends entirely on the terminal:**

| Terminal | What `Ctrl+/` sends |
|---|---|
| Kitty / Ghostty / WezTerm | A CSI-u sequence Neovim reads as `<C-/>` — **not** `<C-_>` |
| Terminal.app | Nothing at all |
| iTerm2 | `0x1F` only if the profile is in legacy mode |

Setting the same key as *both* `toggler` and `opleader` is also ambiguous:
Comment.nvim registers the same LHS as both a toggle and an operator, the
operator wins, and a single press just sits waiting for a motion.

**The fix:** `gcc` / `gc` are back as the primary — they work in every terminal
on every OS. `Ctrl+/` is layered on top as a convenience, mapped in all three
encodings, in normal + visual + insert mode.

## Filetype-aware commentstring

`ts_context_commentstring` is wired in through Comment.nvim's `pre_hook`, which
makes commenting respect the **language under the cursor**, not just the file's
filetype.

Without it, Comment.nvim uses `vim.bo.commentstring`, which for a `.tsx` file is
always `// %s` — so commenting a JSX block gives you broken syntax instead of
`{/* … */}`. Same problem in `.vue`, `.svelte`, `.html` with embedded
`<script>`/`<style>`, and `.astro`.

The plugin's own autocmd is skipped
(`vim.g.skip_ts_context_commentstring_module = true` in the plugin spec) because
the `pre_hook` calls it directly — otherwise you pay for it twice.

## Comment.nvim settings

| Setting | Value | Why |
|---|---|---|
| `padding` | `true` | A space between the comment marker and the text |
| `sticky` | `true` | Cursor stays where it was after commenting |
| `ignore` | `"^$"` | Blank lines inside a commented range are left alone |
| `mappings.basic` / `extra` | `true` | Both mapping sets registered |

## commentstring gap-fill

An autocmd in the `ajay_commentstring` group sets `commentstring` for filetypes
where Neovim's bundled ftplugins are missing or wrong:

| Filetype | Set to | Why |
|---|---|---|
| `c`, `cpp`, `cs`, `java` | `// %s` | C ships as `/* %s */`, which **doesn't nest** — commenting a range that already contains a block comment produces broken code |
| `json`, `jsonc` | `// %s` | jsonc-style, valid in `tsconfig.json` and `launch.json` |
| `sql` | `-- %s` | |
| `gitignore`, `dockerfile`, `conf`, `hyprlang` | `# %s` | No ftplugin ships one |
| `kdl`, `prisma` | `// %s` | |

Treesitter context handles the embedded-language cases; this handles plain
filetypes that just have no ftplugin.

## Keymaps

### Primary — work everywhere

| Key | Mode | Action |
|---|---|---|
| `gcc` | n | Toggle line comment |
| `gbc` | n | Toggle block comment |
| `gc{motion}` | n | Comment operator — `gcap`, `gc3j`, `gcG` |
| `gb{motion}` | n | Block comment operator |
| `gc` | v | Toggle comment on the selection |
| `gb` | v | Block-comment the selection |
| `gcO` | n | Insert a comment on the line **above** and enter insert mode |
| `gco` | n | Insert a comment on the line **below** |
| `gcA` | n | Append a comment at end of line |

### Ctrl+/ convenience layer

Mapped in three encodings — `<C-_>`, `<C-/>`, `<C-Bslash>` — so whichever one
your terminal actually produces will hit; the others are inert.

| Key | Mode | Action |
|---|---|---|
| `Ctrl+/` | n | Toggle comment on the current line |
| `Ctrl+/` | v | Toggle comment on the selection |
| `Ctrl+/` | i | Comment the line you're typing on **and stay in insert** — the bit VS Code does that plain `gcc` can't |

### Block comment

| Key | Mode | Action |
|---|---|---|
| `<leader>cc` | n | Toggle block comment on the current line |
| `<leader>cc` | v | Block-comment the selection |

> `<C-S-/>` is **not** mapped. It is not distinguishable from `<C-/>` in most
> terminals — Ctrl+Shift+/ is Ctrl+? and collapses to the same byte. The old
> config mapped it anyway, which is why it never fired. Use `gbc` / `gb{motion}`.

## Finding out what your terminal sends

```
press i, then Ctrl-V, then Ctrl+/
  ^_          → <C-_>   (legacy encoding)
  ^[[47;5u    → <C-/>   (kitty protocol)
  nothing     → your terminal swallows it; use gcc
```

`:AjayDoctor` prints this, plus the current `commentstring` and what each of
`gcc`, `gc`, `<C-_>`, `<C-/>` is actually mapped to.
