-- ~/.config/nvim/init.lua
--
-- Only three things load eagerly now. Everything else is owned by the
-- plugin spec in lua/ajay/plugins.lua and loads on an event/cmd/key/ft.

-- ── Minimum version ───────────────────────────────────────────────
-- This config targets 0.11 and 0.12 (see lua/ajay/compat.lua). Below
-- 0.11 it does not degrade, it CRASHES: lua/ajay/lsp.lua calls
-- vim.lsp.config() at module scope and that function does not exist,
-- so you get a bare "attempt to call field 'config' (a nil value)"
-- traceback that says nothing about the real problem.
--
-- Worth a guard rather than a comment because distro repos run years
-- behind -- Debian 12 ships 0.7, Ubuntu 24.04 ships 0.9 -- so "my
-- config is broken on the new box" is usually just an old apt package.
-- Deliberately uses nothing newer than 0.5 so it can actually run and
-- print on the versions it is rejecting.
if vim.fn.has("nvim-0.11") ~= 1 then
  local v = vim.version()
  vim.api.nvim_echo({
    {
      ("This config requires Neovim 0.11+. Found %d.%d.%d.\n\n"):format(v.major, v.minor, v.patch)
        .. "Your package manager is probably behind. Install a current build:\n"
        .. "  macOS  : brew install neovim\n"
        .. "  Linux  : https://github.com/neovim/neovim/releases/latest\n",
      "ErrorMsg",
    },
  }, true, {})
  return
end

vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Set this to false if you're on a terminal without a Nerd Font patched font.
vim.g.have_nerd_font = true

-- Opt-in: notebook stack (molten + image.nvim + jupytext).
-- These pull in luarocks/hererocks/ImageMagick and are the #1 source of
-- build failures on a fresh machine. Turn on only after you've run the
-- brew commands in MAC-SETUP.md.
vim.g.enable_notebook = false

require("ajay.options")
require("ajay.keymaps")
-- Registered before plugins: its BufReadPre autocmd has to exist before
-- the first file is opened, including one passed on the command line.
require("ajay.bigfile").setup()

require("ajay.plugins")

-- Registers :AjayDoctor. Cheap — nothing runs until you invoke it.
require("ajay.doctor").setup()
