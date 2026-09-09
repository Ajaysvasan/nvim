-- lua/ajay/options.lua
--
-- The old file set most of these twice (two configs concatenated). Notably
-- `wrap` was set true then false, and `clipboard` was set twice. Merged.

local opt = vim.opt

-- ── Mason binaries on PATH ────────────────────────────────────────
-- This is the ONLY thing mason contributes at runtime: everything it
-- installs (language servers, prettier, stylua, black, debug adapters)
-- lands in one bin directory that has to be on PATH for conform, nvim-dap
-- and vim.lsp to find it.
--
-- `require("mason").setup()` used to do this as a side effect, which meant
-- paying for the whole package registry (~13ms) on every startup just to
-- get one PATH entry. Doing it here directly means mason itself only has
-- to load when something actually needs INSTALLING -- see lua/ajay/lsp.lua.
--
-- Guarded so it stays idempotent if mason does load later and prepends
-- the same directory again.
local mason_bin = vim.fn.stdpath("data") .. "/mason/bin"
if not (vim.env.PATH or ""):find(mason_bin, 1, true) then
  vim.env.PATH = mason_bin .. ":" .. (vim.env.PATH or "")
end

-- ── Skip the :python3 / :ruby provider scan ────────────────────────
-- MEASURED BUG: opening ANY .py or .rb file pays for Neovim's built-in
-- remote-plugin host detection, whether or not anything in this config
-- actually needs it.
--
-- Core's ftplugin/python.vim and ftplugin/ruby.vim both do
-- `has('python3')` / `has('ruby')` to pick an omnifunc, and has() for
-- those two names is special-cased: it does not just check a flag, it
-- RUNS provider#{python3,ruby}#Detect() -- which walks PATH for every
-- candidate interpreter and execs each one to verify pynvim / neovim-ruby
-- is importable. Measured on this machine, opening one .py file:
--   ~55-65ms on a warm run, up to 730ms cold (this PATH has several
--   python3 candidates -- Homebrew, pyenv shims, etc. -- each spawning a
--   full interpreter to test).
--
-- None of this config's Python tooling is a pynvim remote-plugin host:
-- pyright, debugpy, black and isort are all independent LSP/DAP/CLI
-- subprocesses. The only thing that legitimately needs :python3 is
-- molten-nvim, and only when vim.g.enable_notebook is true -- so keep the
-- provider live (but point it at ONE interpreter instead of letting it
-- scan) in that case, and switch it off entirely otherwise. Ruby has no
-- consumer here either way.
if vim.g.enable_notebook then
  local py3 = vim.fn.exepath("python3")
  if py3 ~= "" then
    vim.g.python3_host_prog = py3
  end
else
  vim.g.loaded_python3_provider = 0
end
vim.g.loaded_ruby_provider = 0

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
-- X11. Checked AFTER Wayland on purpose: XWayland sets DISPLAY too, so a
-- Wayland session would otherwise match here and route the clipboard
-- through the compatibility layer instead of the native one.
--
-- Order within X11 (xsel before xclip) and the flags below are Neovim's
-- own, from runtime/autoload/provider/clipboard.vim -- this pins WHICH
-- tool gets picked without changing the behaviour you already have.
-- `--nodetach` / `-quiet` matter: both keep the process alive to own the
-- selection, which is what cache_enabled = 1 then manages.
elseif vim.env.DISPLAY and vim.fn.executable("xsel") == 1 then
  vim.g.clipboard = {
    name = "xsel",
    copy = { ["+"] = "xsel --nodetach -i -b", ["*"] = "xsel --nodetach -i -p" },
    paste = { ["+"] = "xsel -o -b", ["*"] = "xsel -o -p" },
    cache_enabled = 1,
  }
elseif vim.env.DISPLAY and vim.fn.executable("xclip") == 1 then
  vim.g.clipboard = {
    name = "xclip",
    copy = {
      ["+"] = "xclip -quiet -i -selection clipboard",
      ["*"] = "xclip -quiet -i -selection primary",
    },
    paste = {
      ["+"] = "xclip -o -selection clipboard",
      ["*"] = "xclip -o -selection primary",
    },
    cache_enabled = 1,
  }
end
-- No branch matched (bare TTY, SSH with no forwarding, tmux-only)? Then
-- vim.g.clipboard stays nil and Neovim's own detection runs, which also
-- covers the OSC 52 and tmux fallbacks this block does not try to.

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
  -- mkview/loadview do FILE I/O on every buffer switch. On a big file that
  -- is exactly the latency ajay/bigfile.lua exists to avoid, and a view
  -- file for a huge buffer is itself huge.
  if vim.b.bigfile then
    return false
  end
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
