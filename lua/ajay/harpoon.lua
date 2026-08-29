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

  -- COLLISION FIX: this was <leader>hd, which gitsigns also maps -- to
  -- "Diff this", from its on_attach, so BUFFER-LOCALLY. A buffer-local
  -- mapping beats a global one, which means this harpoon binding was
  -- dead in every file gitsigns attaches to: i.e. every file in a git
  -- repo. It only ever worked outside one.
  --
  -- gitsigns keeps <leader>hd. It is the mapping that actually functions
  -- today, so moving it would break working muscle memory to fix a
  -- binding that never fired. <leader>hx here instead ("x" = remove).
  map("<leader>hx", function()
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

  -- ── Direct slot jumps ────────────────────────────────────────────
  -- These were <C-1>..<C-5>, which had TWO problems:
  --
  --  1. The plugin spec declared <A-1>..<A-5> as the lazy-load `keys`
  --     trigger, so the keys that were actually mapped here were not the
  --     keys lazy.nvim was watching for. They only existed once harpoon
  --     had been loaded by some OTHER trigger (<leader>a, <leader>he...).
  --  2. Most terminals do not send a distinct byte for Ctrl+<digit> at
  --     all -- it collapses to the plain digit. So even once loaded, the
  --     mapping was frequently dead. Same class of problem as Ctrl+/ in
  --     comment.lua.
  --
  -- Fixed the same way comment.lua handles it: a primary binding that
  -- works in EVERY terminal, plus a convenience layer for the ones that
  -- deliver Alt properly. Both are declared in the spec's `keys`.
  for i = 1, 5 do
    local function select_slot()
      harpoon:list():select(i)
    end
    -- Always works, every terminal, every OS.
    map("<leader>" .. i, select_slot, "Harpoon slot " .. i)
    -- Convenience. Needs a terminal that sends Alt as a modifier
    -- (Kitty/WezTerm/Ghostty, or Terminal.app with "Use Option as Meta").
    map("<A-" .. i .. ">", select_slot, "Harpoon slot " .. i)
  end
end

return M
