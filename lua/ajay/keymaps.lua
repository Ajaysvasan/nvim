-- lua/ajay/keymaps.lua
--
-- This file was two configs concatenated: <C-h/j/k/l>, <leader>w, <leader>q
-- and the window-nav block were all defined twice, and every Telescope
-- mapping here was redefined again in telescope.lua.
--
-- Rule now: this file only holds mappings that need NO plugin. Anything
-- that touches a plugin lives in that plugin's module, so lazy.nvim's
-- `keys` triggers actually work.

local map = vim.keymap.set

-- ── Files ──────────────────────────────────────────────────────────
map("n", "<leader>w", ":w<CR>", { desc = "Save file" })
map("n", "<leader>q", ":q<CR>", { desc = "Quit" })
map("n", "<leader>x", ":wq<CR>", { desc = "Save and quit" })

-- ── Search ─────────────────────────────────────────────────────────
-- Was <leader>h. That made every <leader>h* mapping (gitsigns hunks,
-- harpoon) sit through the full 'timeoutlen' before firing, because
-- <leader>h was itself a complete mapping. Moved out of the way.
map("n", "<leader>nh", ":nohlsearch<CR>", { desc = "Clear search highlight" })
map("n", "<Esc>", ":noh<CR>", { silent = true, desc = "Clear search" })

-- ── Window navigation ──────────────────────────────────────────────
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })

map("n", "<C-Up>", ":resize +2<CR>", { desc = "Resize up" })
map("n", "<C-Down>", ":resize -2<CR>", { desc = "Resize down" })
map("n", "<C-Left>", ":vertical resize -2<CR>", { desc = "Resize left" })
map("n", "<C-Right>", ":vertical resize +2<CR>", { desc = "Resize right" })

-- ── Motion / editing ───────────────────────────────────────────────
map("n", "H", "^", { desc = "Start of line" })
map("n", "L", "$", { desc = "End of line" })

map("v", "<", "<gv", { desc = "Indent left" })
map("v", ">", ">gv", { desc = "Indent right" })
map("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move text down" })
map("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move text up" })

-- ── Run current file ───────────────────────────────────────────────
-- Paths are shellescape'd now. macOS paths under ~/Library and iCloud
-- contain spaces far more often than anything on your Linux box, and the
-- old unquoted version silently ran the wrong command there.
map("n", "<leader>rc", function()
  local file = vim.fn.shellescape(vim.fn.expand("%"))
  vim.cmd("split | terminal g++ -std=c++17 " .. file .. " -o out && ./out")
end, { desc = "Run C++ file" })

map("n", "<leader>rp", function()
  local file = vim.fn.shellescape(vim.fn.expand("%"))
  vim.cmd("split | terminal python3 " .. file)
end, { desc = "Run Python file" })

map("n", "<leader>rj", function()
  local file = vim.fn.shellescape(vim.fn.expand("%"))
  vim.cmd("split | terminal javac " .. file .. " && java " .. vim.fn.expand("%:r"))
end, { desc = "Run Java file" })

-- ── CMake ──────────────────────────────────────────────────────────
map("n", "<leader>cb", function()
  vim.cmd("split | terminal mkdir -p build && cd build && cmake .. -DCMAKE_BUILD_TYPE=Release && make")
end, { desc = "CMake build (Release)" })

map("n", "<leader>cr", function()
  vim.cmd("split | terminal ./build/" .. vim.fn.fnamemodify(vim.fn.getcwd(), ":t"))
end, { desc = "Run CMake target" })

-- Everything below used to live here and has moved:
--   <leader>f*        -> lua/ajay/telescope.lua
--   <leader>ca, gd, K,
--   <leader>rn,
--   <leader>x{d,q}    -> lua/ajay/lsp.lua (LspAttach, buffer-local)
--   <leader>d*, <F5>+ -> lua/ajay/dap.lua
--   <C-n>             -> lua/ajay/neotree.lua
--   <leader>lf        -> lua/ajay/conform.lua
