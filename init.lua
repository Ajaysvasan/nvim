-- ~/.config/nvim/init.lua
--
-- Only three things load eagerly now. Everything else is owned by the
-- plugin spec in lua/ajay/plugins.lua and loads on an event/cmd/key/ft.

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
require("ajay.plugins")

-- Registers :AjayDoctor. Cheap — nothing runs until you invoke it.
require("ajay.doctor").setup()
