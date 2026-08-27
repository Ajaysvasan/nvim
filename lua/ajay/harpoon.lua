-- lua/ajay/harpoon.lua
--
-- Pulled out of plugins.lua so the spec stays readable.
--
-- FIXES:
--  * harpoon2 renamed `list:append()` to `list:add()`. The old call worked
--    on the commit your Linux box had pinned and errors on newer ones.
--  * `vim.loop` -> `vim.uv` (vim.loop is deprecated).
--  * <leader>hp collided with gitsigns' preview_hunk. Harpoon prev/next
--    moved to <leader>hk / <leader>hj.

local M = {}

function M.setup()
  local harpoon = require("harpoon")

  harpoon:setup({
    settings = {
      save_on_toggle = false,
      sync_on_ui_close = true,
      key = function()
        return (vim.uv or vim.loop).cwd()
      end,
    },
  })

  local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { desc = desc })
  end

  map("<leader>a", function()
    if vim.fn.expand("%:p") == "" then
      vim.notify("No file to add", vim.log.levels.WARN)
      return
    end
    local list = harpoon:list();
    (list.add or list.append)(list)
    vim.notify("Added to Harpoon: " .. vim.fn.expand("%:t"), vim.log.levels.INFO)
  end, "Harpoon add file")

  map("<leader>hd", function()
    harpoon:list():remove()
    vim.notify("Removed from Harpoon", vim.log.levels.INFO)
  end, "Harpoon remove file")

  map("<leader>hc", function()
    harpoon:list():clear()
    vim.notify("Cleared Harpoon list", vim.log.levels.INFO)
  end, "Harpoon clear all")

  map("<leader>he", function()
    harpoon.ui:toggle_quick_menu(harpoon:list())
  end, "Harpoon quick menu")

  map("<leader>hh", function()
    local conf = require("telescope.config").values
    local file_paths = {}
    for _, item in ipairs(harpoon:list().items) do
      table.insert(file_paths, item.value)
    end

    require("telescope.pickers")
      .new({}, {
        prompt_title = "Harpoon",
        finder = require("telescope.finders").new_table({ results = file_paths }),
        previewer = conf.file_previewer({}),
        sorter = conf.generic_sorter({}),
      })
      :find()
  end, "Harpoon telescope")

  map("<leader>hj", function()
    harpoon:list():next()
  end, "Harpoon next")

  map("<leader>hk", function()
    harpoon:list():prev()
  end, "Harpoon prev")

  for i = 1, 5 do
    map("<C-" .. i .. ">", function()
      harpoon:list():select(i)
    end, "Harpoon select " .. i)
  end
end

return M
