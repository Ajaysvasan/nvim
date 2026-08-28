-- lua/ajay/comment.lua
--
-- WHY THIS BROKE ON THE MAC
--
-- The old config did this:
--
--   toggler  = { line = '<C-_>', block = '<C-S-_>' },
--   opleader = { line = '<C-_>', block = '<C-S-_>' },
--
-- `toggler` and `opleader` are not "extra keys" — they REPLACE the
-- defaults. Setting them to <C-_> deleted `gcc` and `gc` entirely. So the
-- only way to comment anything was Ctrl+/, and if the terminal didn't
-- deliver that exact byte, you had no comment mapping at all.
--
-- On Linux, Ctrl+/ sends 0x1F, which Neovim reads as <C-_>. That's the
-- legacy encoding and it's why it worked there.
--
-- On macOS it depends entirely on the terminal:
--   * Kitty / Ghostty / WezTerm (kitty keyboard protocol) send a CSI-u
--     sequence that Neovim reads as <C-/> — NOT <C-_>.
--   * Terminal.app sends nothing at all for Ctrl+/.
--   * iTerm2 sends 0x1F only if the profile is in legacy mode.
--
-- Setting both <C-_> AND <C-_> as toggler and opleader is also ambiguous:
-- Comment.nvim registers the same LHS as both a toggle and an operator,
-- so the operator wins and a single press just waits for a motion.
--
-- FIX: gcc / gc are back as the primary (they work in every terminal on
-- every OS). Ctrl+/ is layered on top as a convenience, mapped in all
-- three encodings, in normal + visual + insert mode.

local M = {}

function M.setup()
  local comment_ok, comment = pcall(require, "Comment")
  if not comment_ok then
    return
  end

  -- Filetype-aware commentstring, including embedded languages.
  -- This is the "comment based on the file I'm on" part: without it,
  -- Comment.nvim uses vim.bo.commentstring, which for a .tsx file is
  -- always `// %s` — so commenting a JSX block gives you broken syntax
  -- instead of `{/* ... */}`. Same problem in .vue, .svelte, .html
  -- with embedded <script>/<style>, and .astro.
  local pre_hook = nil
  local ctx_ok, ctx = pcall(require, "ts_context_commentstring.integrations.comment_nvim")
  if ctx_ok then
    pre_hook = ctx.create_pre_hook()
  end

  comment.setup({
    padding = true,
    sticky = true,
    ignore = "^$",

    -- Defaults restored. gcc = toggle line, gbc = toggle block,
    -- gc{motion} = operator, gc in visual mode.
    toggler = { line = "gcc", block = "gbc" },
    opleader = { line = "gc", block = "gb" },
    extra = { above = "gcO", below = "gco", eol = "gcA" },

    mappings = { basic = true, extra = true },
    pre_hook = pre_hook,
  })

  -- ── Ctrl+/ as a VS Code-style convenience ────────────────────────
  -- Mapped in every encoding a terminal might send. Whichever one your
  -- terminal actually produces will hit; the others are inert.
  local encodings = { "<C-_>", "<C-/>", "<C-Bslash>" }

  for _, key in ipairs(encodings) do
    -- Normal mode: toggle current line
    vim.keymap.set("n", key, "<Plug>(comment_toggle_linewise_current)", {
      desc = "Toggle comment (line)",
    })

    -- Visual mode: toggle selection, then drop back to normal
    vim.keymap.set("x", key, "<Plug>(comment_toggle_linewise_visual)", {
      desc = "Toggle comment (selection)",
    })

    -- Insert mode: comment the line you're typing on, stay in insert.
    -- This is the bit VS Code does that plain gcc can't.
    vim.keymap.set("i", key, function()
      return "<C-o><Plug>(comment_toggle_linewise_current)"
    end, { expr = true, desc = "Toggle comment (line)" })
  end

  -- Block comment. NOTE: <C-S-/> is NOT distinguishable from <C-/> in
  -- most terminals — Ctrl+Shift+/ is Ctrl+? and collapses to the same
  -- byte. The old config mapped it anyway, which is why it never fired.
  -- Use gbc / gb{motion} instead; they always work.
  vim.keymap.set("n", "<leader>cc", "<Plug>(comment_toggle_blockwise_current)", {
    desc = "Toggle block comment",
  })
  vim.keymap.set("x", "<leader>cc", "<Plug>(comment_toggle_blockwise_visual)", {
    desc = "Toggle block comment (selection)",
  })

  -- ── commentstring gap-fill ───────────────────────────────────────
  -- Neovim's bundled ftplugins miss or get these wrong. Treesitter
  -- context handles the embedded-language cases above; this handles
  -- plain filetypes that just have no ftplugin.
  local commentstrings = {
    c = "// %s", -- ships as /* %s */, which doesn't nest
    cpp = "// %s",
    cs = "// %s",
    java = "// %s",
    json = "// %s", -- jsonc-style, valid in tsconfig/launch.json
    jsonc = "// %s",
    sql = "-- %s",
    gitignore = "# %s",
    dockerfile = "# %s",
    conf = "# %s",
    kdl = "// %s",
    prisma = "// %s",
    hyprlang = "# %s",
  }

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("ajay_commentstring", { clear = true }),
    callback = function(ev)
      local cs = commentstrings[vim.bo[ev.buf].filetype]
      if cs then
        vim.bo[ev.buf].commentstring = cs
      end
    end,
  })
end

return M
