-- lua/ajay/options.lua
--
-- The old file set most of these twice (two configs concatenated). Notably
-- `wrap` was set true then false, and `clipboard` was set twice. Merged.

local opt = vim.opt

-- UI
opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.termguicolors = true
opt.wrap = false
opt.splitbelow = true
opt.splitright = true

-- Indentation
opt.tabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.smartindent = true

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = false

-- Files
opt.undofile = true
opt.backup = false
opt.writebackup = false
opt.swapfile = false

-- Behaviour
opt.mouse = "a"
opt.updatetime = 250
opt.timeoutlen = 400 -- was 300; too tight for <leader>h* / <leader>d* chords

-- ── Clipboard ─────────────────────────────────────────────────────
-- Neovim auto-detects a clipboard provider by probing for pbcopy, xclip,
-- xsel, wl-copy, etc. That probe is order-dependent and picks the FIRST
-- one it finds on PATH. Mason prepends its own bin directory to PATH
-- during setup, and on macOS a Homebrew-installed tool can shadow the
-- system one. Defining vim.g.clipboard explicitly removes the guesswork.
if vim.fn.has("mac") == 1 then
  vim.g.clipboard = {
    name = "pbcopy",
    copy = { ["+"] = "pbcopy", ["*"] = "pbcopy" },
    paste = { ["+"] = "pbpaste", ["*"] = "pbpaste" },
    cache_enabled = 0,
  }
elseif vim.env.WAYLAND_DISPLAY and vim.fn.executable("wl-copy") == 1 then
  vim.g.clipboard = {
    name = "wl-clipboard",
    copy = { ["+"] = "wl-copy", ["*"] = "wl-copy --primary" },
    paste = { ["+"] = "wl-paste --no-newline", ["*"] = "wl-paste --no-newline --primary" },
    cache_enabled = 1,
  }
end

-- Set AFTER startup. Touching 'clipboard' during init forces the provider
-- to spawn immediately, which costs 30-80ms and, on macOS, is the usual
-- reason the first yank of a session silently no-ops.
vim.schedule(function()
  opt.clipboard = "unnamedplus"
end)

-- ── Session view: remember folds and cursor position ──────────────
-- FIX: the old autocmds fired mkview/loadview for every non-empty
-- filetype, which includes plugin scratch buffers. On a fresh machine with
-- no ~/.local/state/nvim/view directory that produced errors on nearly
-- every buffer switch. Now scoped to real, writable files only.
opt.viewoptions = "cursor,folds"

local view_group = vim.api.nvim_create_augroup("ajay_remember_view", { clear = true })

local function is_real_file()
  return vim.bo.buftype == "" and vim.bo.filetype ~= "" and vim.fn.expand("%") ~= "" and not vim.bo.readonly
end

vim.api.nvim_create_autocmd("BufWinLeave", {
  group = view_group,
  pattern = "*",
  callback = function()
    if is_real_file() then
      vim.cmd("silent! mkview")
    end
  end,
})

vim.api.nvim_create_autocmd("BufWinEnter", {
  group = view_group,
  pattern = "*",
  callback = function()
    if is_real_file() then
      vim.cmd("silent! loadview")
    end
  end,
})
