-- lua/ajay/colorscheme.lua
--
-- A theme REGISTRY and switcher, not a single hardcoded colorscheme.
--
-- This used to be a Shape B module that ran catppuccin.setup() and called
-- vim.cmd.colorscheme("catppuccin-frappe") at require time. Switching meant
-- editing the file. It is now a Shape A module (see docs/api.md) exposing
-- apply/cycle/pick, and your choice is remembered across restarts using the
-- same one-word-state-file pattern as the Copilot and format-on-save
-- toggles.
--
-- ADDING A THEME
--   1. add the plugin as a dependency of the catppuccin spec in plugins.lua
--      (dependencies, not a sibling spec -- see the note there about load
--      order),
--   2. add an entry to M.themes below.
-- Nothing else needs to change: lualine, transparency, the picker and the
-- persisted state all read from that table.

local M = {}

local state_file = vim.fn.stdpath("data") .. "/colorscheme_state"

-- ── TRANSPARENCY ──────────────────────────────────────────────────
--
-- Themes that implement it themselves say so with `native_transparency`;
-- they get told, and they do the right thing for every group they own.
--
-- For themes that do NOT (darcula), this is the fallback. Note what it is
-- *not*: it is not the hand-written list of ~20 highlight groups this
-- config deleted once already, which drifted out of date the moment a
-- plugin was added. It COMPUTES the set instead -- every group whose
-- background currently equals Normal's background is, by definition, a
-- group painting the editor background, so clearing it is correct no
-- matter which plugin defined it.
local function strip_backgrounds()
  local normal = vim.api.nvim_get_hl(0, { name = "Normal" })
  local bg = normal and normal.bg
  if not bg then
    return
  end
  for name, hl in pairs(vim.api.nvim_get_hl(0, {})) do
    -- Linked groups inherit from their target; re-setting them here would
    -- break the link and freeze them at today's colours.
    if hl.link == nil and hl.bg == bg then
      hl.bg = nil
      pcall(vim.api.nvim_set_hl, 0, name, hl)
    end
  end
  normal.bg = nil
  pcall(vim.api.nvim_set_hl, 0, "Normal", normal)
end

-- ── REGISTRY ──────────────────────────────────────────────────────
M.themes = {
  {
    name = "vscode",
    label = "VS Code Dark+",
    lualine = "vscode",
    native_transparency = true,
    apply = function(transparent)
      require("vscode").setup({
        style = "dark",
        transparent = transparent,
        italic_comments = true,
        -- neo-tree/nvim-tree keep the editor background instead of a
        -- slightly different panel colour -- closer to VS Code, and it
        -- matters more once transparency is on.
        disable_nvimtree_bg = true,
      })
      vim.cmd.colorscheme("vscode")
    end,
  },
  {
    name = "darcula",
    label = "IntelliJ Darcula",
    -- Ships no lualine theme of its own; "auto" derives one from the
    -- active highlight groups, which tracks the theme correctly.
    lualine = "auto",
    native_transparency = false,
    apply = function()
      require("darcula").setup({
        opt = {
          integrations = {
            telescope = true,
            lualine = true,
            nvim_cmp = true,
            dap_nvim = true,
            lsp_semantics_token = true,
          },
        },
      })
      vim.cmd.colorscheme("darcula-dark")
    end,
  },
  {
    name = "catppuccin",
    label = "Catppuccin Frappe",
    lualine = "catppuccin-frappe",
    native_transparency = true,
    apply = function(transparent)
      require("catppuccin").setup({
        flavour = "frappe",
        background = { light = "latte", dark = "mocha" },
        transparent_background = transparent,
        float = { transparent = transparent, solid = false },
        term_colors = true,
        dim_inactive = { enabled = false, shade = "dark", percentage = 0.15 },
        no_italic = false,
        no_bold = false,
        no_underline = false,
        styles = { comments = { "italic" }, conditionals = { "italic" } },
        color_overrides = {},
        custom_highlights = {},
        -- PERF: auto_integrations scans every installed plugin to guess
        -- which integrations to enable -- ~2.9ms of eager startup to find
        -- exactly one thing the explicit list below did not already cover.
        -- Listed by hand instead, scan off. TRADE-OFF: a newly installed
        -- plugin is no longer themed automatically; add it here.
        auto_integrations = false,
        integrations = {
          rainbow_delimiters = true,
          cmp = true,
          gitsigns = true,
          neotree = true,
          telescope = { enabled = true },
          treesitter = true,
          harpoon = true,
          alpha = true,
          dap = true,
          dap_ui = true,
          indent_blankline = { enabled = true },
          mason = true,
          native_lsp = { enabled = true },
          notify = false,
          mini = { enabled = true, indentscope_color = "" },
        },
      })
      vim.cmd.colorscheme("catppuccin-frappe")
    end,
  },
}

M.default = "vscode"

local function find(name)
  for _, t in ipairs(M.themes) do
    if t.name == name then
      return t
    end
  end
end

-- ── PERSISTENCE ───────────────────────────────────────────────────
local function read_state()
  local f = io.open(state_file, "r")
  if not f then
    return M.default
  end
  local name = (f:read("*a") or ""):gsub("%s+", "")
  f:close()
  -- A theme removed from the registry must not brick startup.
  return find(name) and name or M.default
end

local function write_state(name)
  local f = io.open(state_file, "w")
  if f then
    f:write(name)
    f:close()
  end
end

--- The lualine theme for the active colorscheme. Read by plugins.lua for
--- the first draw, before this module's setup() has necessarily run.
--- @return string
function M.lualine_theme()
  local t = find(read_state())
  return t and t.lualine or "auto"
end

--- Name of the currently active theme.
--- @return string
function M.current()
  return vim.g.ajay_theme or read_state()
end

-- lualine caches its options, so a theme switch has to re-run setup. The
-- options here must mirror the lualine spec in plugins.lua -- passing only
-- `theme` would reset icons_enabled and globalstatus to lualine's defaults.
local function refresh_lualine(theme)
  local ok, lualine = pcall(require, "lualine")
  if not ok then
    return
  end
  pcall(lualine.setup, {
    options = {
      icons_enabled = vim.g.have_nerd_font ~= false,
      theme = theme,
      globalstatus = true,
    },
  })
end

--- Apply a theme by name.
--- @param name string
--- @param opts? { silent?: boolean, persist?: boolean }
function M.apply(name, opts)
  opts = opts or {}
  local t = find(name)
  if not t then
    vim.notify("Unknown theme: " .. tostring(name), vim.log.levels.ERROR, { title = "theme" })
    return false
  end

  local transparent = vim.g.transparent_background == true
  local ok, err = pcall(t.apply, transparent)
  if not ok then
    vim.notify(("Failed to apply %s:\n%s"):format(t.label, err), vim.log.levels.ERROR, { title = "theme" })
    return false
  end

  -- Themes without their own transparency support get the computed sweep,
  -- and only when transparency is actually on.
  if transparent and not t.native_transparency then
    pcall(strip_backgrounds)
  end

  vim.g.ajay_theme = name
  refresh_lualine(t.lualine)
  if opts.persist ~= false then
    write_state(name)
  end
  if not opts.silent then
    vim.notify(t.label .. (transparent and "  (transparent)" or ""), vim.log.levels.INFO, { title = "theme" })
  end
  return true
end

--- Re-apply the active theme. Used by transparency.lua after it flips
--- vim.g.transparent_background -- the theme has to be rebuilt for the new
--- value, since most of them bake it in at setup() time.
function M.reapply()
  return M.apply(M.current(), { silent = true, persist = false })
end

--- Cycle to the next theme in the registry.
function M.cycle()
  local cur = M.current()
  for i, t in ipairs(M.themes) do
    if t.name == cur then
      M.apply(M.themes[(i % #M.themes) + 1].name)
      return
    end
  end
  M.apply(M.default)
end

--- Interactive picker (vim.ui.select, so telescope/dressing style it if
--- either is installed).
function M.pick()
  local items, labels = {}, {}
  for _, t in ipairs(M.themes) do
    items[#items + 1] = t.name
    labels[t.name] = t.label .. (t.name == M.current() and "   (current)" or "")
  end
  vim.ui.select(items, {
    prompt = "Colorscheme",
    format_item = function(n)
      return labels[n]
    end,
  }, function(choice)
    if choice then
      M.apply(choice)
    end
  end)
end

function M.setup()
  -- silent: announcing the theme on every startup is noise.
  M.apply(read_state(), { silent = true, persist = false })

  vim.api.nvim_create_user_command("Theme", function(a)
    if a.args ~= "" then
      M.apply(a.args)
    else
      M.pick()
    end
  end, {
    nargs = "?",
    desc = "Pick a colorscheme (remembered across restarts)",
    complete = function()
      local names = {}
      for _, t in ipairs(M.themes) do
        names[#names + 1] = t.name
      end
      return names
    end,
  })

  vim.api.nvim_create_user_command("ThemeNext", M.cycle, { desc = "Cycle to the next colorscheme" })

  vim.keymap.set("n", "<leader>tc", M.pick, { desc = "Choose colorscheme", silent = true })
  vim.keymap.set("n", "<leader>tn", M.cycle, { desc = "Next colorscheme", silent = true })
end

return M
