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
  --
  -- NEATNESS PASS.
  --
  --  1. alpha's dashboard.button() pads every shortcut out to a fixed
  --     50-column card. The longest label here ("  Neovim Config") is 15
  --     columns and every shortcut is 7, so most rows had 30-40 blank
  --     columns of dead space between the label and its key -- a canyon,
  --     not a gap. BUTTON_WIDTH below is sized to the actual content
  --     (longest label + longest shortcut + a fixed breathing margin),
  --     not a number alpha picked for a menu with different labels.
  --  2. Eleven buttons with zero grouping is just a list. They are three
  --     lists -- find things, change/manage things, leave.
  --  3. The whole screen used to be pinned to the top-left of the window:
  --     alpha only centers each line HORIZONTALLY (align_center, per
  --     element); nothing centered the block vertically, so on any
  --     terminal taller than the ~24 rows the content used, everything
  --     sat in a clump near the top with dead space below it. Fixed
  --     below by wrapping the whole layout in one `type = "group"` with
  --     `opts.position = "v_center"` -- alpha's own vertical-centering
  --     mechanism (layout_element.group, alpha.lua ~L377), which shifts
  --     the group down by `(win_height - content_height) / 2` and
  --     re-runs on every resize (alpha redraws on WinResized/VimResized
  --     by default). This is what actually centers it, not a guess at
  --     padding numbers.
  local BUTTON_WIDTH = 40

  local function button(sc, txt, cmd)
    local b = dashboard.button(sc, txt, cmd)
    b.opts.hl = "DashButton"
    b.opts.hl_shortcut = "DashShortcut"
    b.opts.width = BUTTON_WIDTH
    return b
  end

  local function gap()
    return { type = "padding", val = 1 }
  end

  -- NOTE: there used to be a "Sessions" button here calling
  -- require('persistence').load(). persistence.nvim is not in the plugin
  -- list, so pressing it raised "module 'persistence' not found". Removed
  -- rather than left as a trap; if you want session restore, add
  -- folke/persistence.nvim to plugins.lua and put the button back.
  local find_specs = {
    { "SPC f f", "󰍉  Find File", "<cmd>Telescope find_files<CR>" },
    { "SPC f r", "  Recent Files", "<cmd>Telescope oldfiles<CR>" },
    { "SPC f g", "  Live Grep", "<cmd>Telescope live_grep<CR>" },
    { "SPC f b", "  Buffers", "<cmd>Telescope buffers<CR>" },
    { "SPC g s", "  Git Status", "<cmd>Telescope git_status<CR>" },
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
    { "SPC l  ", "  LSP Info", "<cmd>checkhealth vim.lsp<CR>" },
  }

  local manage_specs = {
    { "n      ", "  New File", "<cmd>ene <BAR> startinsert<CR>" },
    { "c      ", "  Neovim Config", "<cmd>e ~/.config/nvim/init.lua<CR>" },
    { "l      ", "󰒲  Lazy", "<cmd>Lazy<CR>" },
    { "m      ", "  Mason", "<cmd>Mason<CR>" },
  }

  -- Leave -- set apart on purpose, the one irreversible action here.
  local leave_specs = {
    { "q      ", "  Quit", "<cmd>qa<CR>" },
  }

  -- `inner` blank rows sit between buttons within a group, `outer` blank
  -- rows sit between groups. Built manually (not alpha's own
  -- opts.spacing, which pads after every item including the last) so the
  -- row count is exact and predictable.
  local function build_buttons(inner, outer)
    local groups = { find_specs, manage_specs, leave_specs }
    local val = {}
    for gi, specs in ipairs(groups) do
      for i, spec in ipairs(specs) do
        if i > 1 then
          for _ = 1, inner do
            val[#val + 1] = gap()
          end
        end
        val[#val + 1] = button(spec[1], spec[2], spec[3])
      end
      if gi < #groups then
        for _ = 1, outer do
          val[#val + 1] = gap()
        end
      end
    end
    return val
  end

  -- Fixed rows outside the button list: 6-line header + 2 padding rows +
  -- 1-line subtitle + 1-line footer = 10, plus whatever the buttons add.
  --
  -- Compact (no gap between buttons, one blank row between groups): 11
  -- buttons + 2 group gaps = 13 rows -> 24 total. This is the size that
  -- used to be hardcoded, chosen to just fit an 80x24 terminal after a
  -- prior regression at 35 rows scrolled the footer off.
  --
  -- Airy (one blank row between every button, two between groups): 11
  -- buttons + 8 inner gaps + 4 outer gaps = 23 rows -> 34 total. This is
  -- what actually fixes "congested" -- six/four buttons sitting flush
  -- against each other read as a solid block. It only renders on a
  -- terminal tall enough to hold it; the v_center wrapper below re-checks
  -- this on every resize, so shrinking the terminal falls back to
  -- compact instead of clipping the airy version.
  dashboard.section.buttons.val = function()
    if vim.api.nvim_win_get_height(0) >= 34 then
      return build_buttons(1, 2)
    end
    return build_buttons(0, 1)
  end
  dashboard.section.buttons.opts.spacing = 0

  dashboard.section.footer.val = { stats_line() }
  dashboard.section.footer.opts.hl = "DashFooter"

  -- Everything lives inside one outer group so `position = "v_center"`
  -- can center the whole block vertically -- see the NEATNESS PASS note
  -- above. Without this wrapper, v_center has nothing to shift as a unit.
  dashboard.opts.layout = {
    {
      type = "group",
      val = {
        dashboard.section.header,
        { type = "padding", val = 1 },
        subtitle,
        { type = "padding", val = 1 },
        dashboard.section.buttons,
        { type = "padding", val = 1 },
        dashboard.section.footer,
      },
      opts = { position = "v_center" },
    },
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
