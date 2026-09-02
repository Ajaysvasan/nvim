-- lua/ajay/dashboard.lua — alpha-nvim start screen
--
-- Rewritten to be plain. What used to be here: nine large ASCII art
-- logos picked at random, a boxed title line per logo, and a random
-- quote in the footer. All of it is gone -- one static wordmark, the
-- working directory, the button list, and a startup line.
--
-- What is deliberately kept:
--   * the same buttons, in the same order, with the same shortcuts, so
--     nothing you already press changes,
--   * the FileType cleanup, without which the alpha buffer inherits the
--     editing UI (numbers, sign column, statusline) and the layout sits
--     off-centre.

local M = {}

-- 50 columns wide, which is exactly alpha's default button width, so the
-- wordmark and the button block share an edge.
local header = {
  [[███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗]],
  [[████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║]],
  [[██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║]],
  [[██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║]],
  [[██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║]],
  [[╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝]],
}

-- ── Highlights ─────────────────────────────────────────────────────
--
-- Derived from groups every colorscheme defines rather than hardcoded
-- hex, so the dashboard follows the theme instead of fighting it.
--
-- Re-applied on ColorScheme: `:colorscheme` runs `:highlight clear`,
-- which wipes anything set with nvim_set_hl. The old file set its
-- colours once at VimEnter, so switching colorscheme left the dashboard
-- on default highlights until restart.
local function fg(group, fallback)
  local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = group, link = false })
  if ok and hl and hl.fg then
    return ("#%06x"):format(hl.fg)
  end
  return fallback
end

local function set_highlights()
  vim.api.nvim_set_hl(0, "DashHeader", { fg = fg("Function", "#82AAFF"), bold = true })
  vim.api.nvim_set_hl(0, "DashSubtitle", { fg = fg("Comment", "#546E7A") })
  vim.api.nvim_set_hl(0, "DashButton", { fg = fg("Normal", "#C6D0F5") })
  vim.api.nvim_set_hl(0, "DashShortcut", { fg = fg("Keyword", "#C792EA"), bold = true })
  vim.api.nvim_set_hl(0, "DashFooter", { fg = fg("Comment", "#546E7A") })
end

-- ── Footer ─────────────────────────────────────────────────────────
local function stats_line()
  local ok, lazy = pcall(require, "lazy")
  if not ok then
    return ""
  end
  local ok_stats, s = pcall(lazy.stats)
  if not ok_stats then
    return ""
  end
  local line = ("%d plugins  ·  %d loaded"):format(s.count, s.loaded)
  if s.startuptime and s.startuptime > 0 then
    line = line .. ("  ·  %.0f ms"):format(s.startuptime)
  end
  return line
end

function M.setup()
  local alpha_ok, alpha = pcall(require, "alpha")
  if not alpha_ok then
    vim.notify("[dashboard] alpha-nvim not found — run :Lazy sync", vim.log.levels.WARN)
    return
  end

  local dashboard = require("alpha.themes.dashboard")

  dashboard.section.header.val = header
  dashboard.section.header.opts.hl = "DashHeader"

  local subtitle = {
    type = "text",
    val = { vim.fn.fnamemodify(vim.fn.getcwd(), ":~") },
    opts = { position = "center", hl = "DashSubtitle" },
  }

  -- FIX: the highlight has to go on each BUTTON, not on the group.
  --
  -- The old file set `section.buttons.opts.hl` / `.opts.hl_shortcut`,
  -- which alpha ignores: layout_element.group only propagates an
  -- `opts.inherit` TABLE to its children, never `opts.hl`. So DashButton
  -- and DashShortcut were defined and never used -- the buttons rendered
  -- as plain Normal text with alpha's built-in "Keyword" shortcuts.
  local function button(sc, txt, cmd)
    local b = dashboard.button(sc, txt, cmd)
    b.opts.hl = "DashButton"
    b.opts.hl_shortcut = "DashShortcut"
    return b
  end

  -- NOTE: there used to be a "Sessions" button here calling
  -- require('persistence').load(). persistence.nvim is not in the plugin
  -- list, so pressing it raised "module 'persistence' not found". Removed
  -- rather than left as a trap; if you want session restore, add
  -- folke/persistence.nvim to plugins.lua and put the button back.
  dashboard.section.buttons.val = {
    button("SPC f f", "󰍉  Find File", "<cmd>Telescope find_files<CR>"),
    button("SPC f r", "  Recent Files", "<cmd>Telescope oldfiles<CR>"),
    button("SPC f g", "  Live Grep", "<cmd>Telescope live_grep<CR>"),
    button("SPC f b", "  Buffers", "<cmd>Telescope buffers<CR>"),
    button("SPC g s", "  Git Status", "<cmd>Telescope git_status<CR>"),
    -- WAS `<cmd>LspInfo<CR>`, which is dead on Neovim 0.12.
    --
    -- :LspInfo is not a core command, it comes from nvim-lspconfig --
    -- and lspconfig's plugin file opens with `if vim.fn.exists(':lsp')
    -- == 2 then return end`. Neovim 0.12 ships a built-in :lsp, so
    -- lspconfig bails out and defines NOTHING: no LspInfo, no LspLog,
    -- no LspStart/Stop/Restart. On 0.11 they all exist. This button
    -- therefore worked on one machine and errored on the other.
    --
    -- :checkhealth vim.lsp is what LspInfo is an alias FOR on 0.11, and
    -- it is core on both versions, so it needs no compat branch.
    button("SPC l  ", "  LSP Info", "<cmd>checkhealth vim.lsp<CR>"),
    button("n      ", "  New File", "<cmd>ene <BAR> startinsert<CR>"),
    button("c      ", "  Neovim Config", "<cmd>e ~/.config/nvim/init.lua<CR>"),
    button("l      ", "󰒲  Lazy", "<cmd>Lazy<CR>"),
    button("m      ", "  Mason", "<cmd>Mason<CR>"),
    button("q      ", "  Quit", "<cmd>qa<CR>"),
  }

  -- alpha's default is a blank line between every button. With eleven of
  -- them that alone is 21 rows, and the whole screen came to 35 -- taller
  -- than an 80x24 terminal, so the footer and the last buttons scrolled
  -- off. Packed, the layout is 23 rows and fits.
  dashboard.section.buttons.opts.spacing = 0

  dashboard.section.footer.val = { stats_line() }
  dashboard.section.footer.opts.hl = "DashFooter"

  dashboard.opts.layout = {
    { type = "padding", val = 1 },
    dashboard.section.header,
    { type = "padding", val = 1 },
    subtitle,
    { type = "padding", val = 1 },
    dashboard.section.buttons,
    { type = "padding", val = 1 },
    dashboard.section.footer,
  }

  set_highlights()
  alpha.setup(dashboard.opts)

  vim.api.nvim_create_augroup("ajay_dashboard", { clear = true })

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = "ajay_dashboard",
    callback = set_highlights,
  })

  -- lazy.nvim fills in startuptime from its own UIEnter handler, and
  -- whether that runs before or after this VimEnter config is not
  -- guaranteed. Redraw from both, so the number is right either way --
  -- the redraw is a no-op once the buffer is gone.
  local function refresh_footer()
    dashboard.section.footer.val = { stats_line() }
    if vim.bo.filetype == "alpha" then
      pcall(vim.cmd, "AlphaRedraw")
    end
  end

  vim.schedule(refresh_footer)
  vim.api.nvim_create_autocmd("UIEnter", {
    group = "ajay_dashboard",
    once = true,
    callback = function()
      vim.schedule(refresh_footer)
    end,
  })

  -- Strip the editing UI so the layout sits on a clean canvas.
  vim.api.nvim_create_autocmd("FileType", {
    group = "ajay_dashboard",
    pattern = "alpha",
    callback = function()
      vim.opt_local.foldenable = false
      vim.opt_local.number = false
      vim.opt_local.relativenumber = false
      vim.opt_local.signcolumn = "no"
      vim.opt_local.cursorline = false
      vim.opt_local.statusline = " "
      vim.opt_local.list = false
    end,
  })
end

return M
