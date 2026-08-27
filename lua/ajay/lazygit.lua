-- lua/ajay/lazygit.lua

local M = {}

function M.setup()
  -- LazyGit keymaps
  vim.keymap.set("n", "<leader>gg", ":LazyGit<CR>", { 
    desc = "Open LazyGit", 
    silent = true, 
    noremap = true 
  })
  
  -- COLLISION FIX: this was <leader>gc, which telescope.lua also maps to
  -- git_commits. Both are global, so whichever module loaded last silently
  -- won -- and which one that was depended on whether you pressed a
  -- <leader>f key or <leader>gg first in the session.
  --
  -- Telescope keeps <leader>gc: browsing commit history is a daily action,
  -- whereas editing lazygit's own config file is close to never. Moved to
  -- the shifted variant.
  vim.keymap.set("n", "<leader>gC", ":LazyGitConfig<CR>", {
    desc = "LazyGit Config",
    silent = true,
    noremap = true
  })
  
  vim.keymap.set("n", "<leader>gf", ":LazyGitCurrentFile<CR>", { 
    desc = "LazyGit Current File", 
    silent = true, 
    noremap = true 
  })
  
  vim.keymap.set("n", "<leader>gl", ":LazyGitFilter<CR>", { 
    desc = "LazyGit Filter", 
    silent = true, 
    noremap = true 
  })
  
  vim.keymap.set("n", "<leader>gL", ":LazyGitFilterCurrentFile<CR>", { 
    desc = "LazyGit Filter Current File", 
    silent = true, 
    noremap = true 
  })

  -- Configure LazyGit to use a floating window
  vim.g.lazygit_floating_window_winblend = 0
  vim.g.lazygit_floating_window_scaling_factor = 0.9
  vim.g.lazygit_floating_window_border_chars = {'╭','─', '╮', '│', '╯','─', '╰', '│'}
  vim.g.lazygit_floating_window_use_plenary = 0
  vim.g.lazygit_use_neovim_remote = 1
  vim.g.lazygit_use_custom_config_file_path = 0
end

return M
