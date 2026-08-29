-- lua/ajay/jupyter.lua

local M = {}

-- Percent-format cell marker (what jupytext.nvim uses with style = "percent")
local CELL_MARKER = "^# %%"

-- Returns the [start_line, end_line] of the cell the cursor is currently in
-- (1-indexed, inclusive), based on the nearest `# %%` markers.
local function get_cell_range()
  local cur = vim.fn.line(".")

  local start_line = vim.fn.search(CELL_MARKER, "bcnW")
  if start_line == 0 then
    start_line = 1
  else
    start_line = start_line + 1 -- skip the marker line itself
  end

  local end_line = vim.fn.search(CELL_MARKER, "nW")
  if end_line == 0 then
    end_line = vim.fn.line("$")
  else
    end_line = end_line - 1
  end

  -- restore cursor (search() moves it in some edge cases)
  vim.fn.cursor(cur, 1)

  return start_line, end_line
end

local function run_current_cell()
  local s, e = get_cell_range()
  if s > e then
    vim.notify("Empty cell, nothing to run", vim.log.levels.WARN)
    return
  end
  vim.fn.MoltenEvaluateRange(s, e)
end

local function goto_next_cell()
  vim.fn.search(CELL_MARKER, "W")
end

local function goto_prev_cell()
  vim.fn.search(CELL_MARKER, "bW")
end

-- Insert a new cell below the current one and drop into insert mode,
-- the same as pressing "+" below a cell in VSCode/Jupyter
local function insert_cell_below()
  local _, end_line = get_cell_range()
  vim.fn.append(end_line, { "", "# %%", "" })
  vim.fn.cursor(end_line + 3, 1)
  vim.cmd("startinsert")
end

-- ── Visual notebook UI (VSCode/Colab-style cell chrome) ───────────

local ns_sep = vim.api.nvim_create_namespace("jupyter_cell_sep")
local ns_active = vim.api.nvim_create_namespace("jupyter_active_cell")

local function define_notebook_highlights()
  -- Linked to existing theme groups so it adapts to catppuccin automatically
  vim.api.nvim_set_hl(0, "NotebookCellHeader", { link = "Title", default = true })
  vim.api.nvim_set_hl(0, "NotebookMarkdownHeader", { link = "String", default = true })
  vim.api.nvim_set_hl(0, "NotebookActiveCell", { link = "CursorLine", default = true })
end

local function has_cell_markers(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  for _, line in ipairs(lines) do
    if line:sub(1, 4) == "# %%" then
      return true
    end
  end
  return false
end

-- Draws a labeled divider above every `# %%` marker (Code / Markdown),
-- similar to VSCode's cell toolbar strip
local function draw_cell_separators(bufnr)
  bufnr = bufnr or 0
  vim.api.nvim_buf_clear_namespace(bufnr, ns_sep, 0, -1)
  if not has_cell_markers(bufnr) then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local width = math.max(vim.api.nvim_win_get_width(0) - 4, 20)

  for i, line in ipairs(lines) do
    if line:sub(1, 4) == "# %%" then
      local is_md = line:find("[markdown]", 1, true) ~= nil
      local label = is_md and " Markdown Cell " or " Code Cell "
      local hl = is_md and "NotebookMarkdownHeader" or "NotebookCellHeader"
      local rule = string.rep("─", math.max(width - #label, 4))

      vim.api.nvim_buf_set_extmark(bufnr, ns_sep, i - 1, 0, {
        virt_lines = { { { rule .. label, hl } } },
        virt_lines_above = true,
      })
    end
  end
end

-- Highlights the full range of the cell the cursor is currently in,
-- mimicking VSCode/Colab's "active cell" outline
local function highlight_active_cell()
  local bufnr = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(bufnr, ns_active, 0, -1)
  if not has_cell_markers(bufnr) then
    return
  end

  local s, e = get_cell_range()
  for line = s, e do
    vim.api.nvim_buf_set_extmark(bufnr, ns_active, line - 1, 0, {
      line_hl_group = "NotebookActiveCell",
    })
  end
end

local function setup_notebook_ui()
  define_notebook_highlights()

  vim.api.nvim_create_autocmd({ "BufEnter", "TextChanged", "InsertLeave" }, {
    pattern = { "*.py", "*.ipynb" },
    callback = function(args)
      draw_cell_separators(args.buf)
    end,
  })

  vim.api.nvim_create_autocmd("CursorMoved", {
    pattern = { "*.py", "*.ipynb" },
    callback = highlight_active_cell,
  })

  vim.api.nvim_create_autocmd("ColorScheme", {
    callback = define_notebook_highlights,
  })
end

function M.setup()
  -- Molten (Jupyter kernel) keymaps
  vim.keymap.set("n", "<leader>mi", ":MoltenInit<CR>", {
    desc = "Initialize Molten (Jupyter kernel)",
    silent = true,
  })

  vim.keymap.set("n", "<leader>me", ":MoltenEvaluateOperator<CR>", {
    desc = "Evaluate operator",
    silent = true,
  })

  vim.keymap.set("n", "<leader>ml", ":MoltenEvaluateLine<CR>", {
    desc = "Evaluate line",
    silent = true,
  })

  vim.keymap.set("n", "<leader>mr", ":MoltenReevaluateCell<CR>", {
    desc = "Re-evaluate cell",
    silent = true,
  })

  vim.keymap.set("v", "<leader>me", ":<C-u>MoltenEvaluateVisual<CR>gv", {
    desc = "Evaluate visual selection",
    silent = true,
  })

  vim.keymap.set("n", "<leader>md", ":MoltenDelete<CR>", {
    desc = "Delete Molten cell",
    silent = true,
  })

  vim.keymap.set("n", "<leader>mo", ":MoltenShowOutput<CR>", {
    desc = "Show output",
    silent = true,
  })

  vim.keymap.set("n", "<leader>mh", ":MoltenHideOutput<CR>", {
    desc = "Hide output",
    silent = true,
  })

  vim.keymap.set("n", "<leader>mq", ":MoltenInterrupt<CR>", {
    desc = "Interrupt kernel",
    silent = true,
  })

  -- Run cell and move to next (like Jupyter)
  vim.keymap.set("n", "<leader>mn", function()
    vim.cmd("MoltenEvaluateLine")
    vim.cmd("normal! j")
  end, {
    desc = "Run cell and move to next",
    silent = true,
  })

  -- Run all cells above
  vim.keymap.set("n", "<leader>ma", ":MoltenEvaluateAll<CR>", {
    desc = "Evaluate all cells",
    silent = true,
  })

  -- ── Notebook-cell UX (VSCode-like) ─────────────────────────────
  vim.keymap.set("n", "<leader>mc", run_current_cell, {
    desc = "Run current cell (whole # %% block)",
    silent = true,
  })

  vim.keymap.set("n", "]j", goto_next_cell, {
    desc = "Next notebook cell",
    silent = true,
  })

  vim.keymap.set("n", "[j", goto_prev_cell, {
    desc = "Previous notebook cell",
    silent = true,
  })

  -- Jump between cells that already have Molten output attached
  -- (only works after you've run at least one cell)
  vim.keymap.set("n", "]o", ":MoltenGoto<CR>", {
    desc = "Next evaluated cell",
    silent = true,
  })
  vim.keymap.set("n", "[o", ":MoltenGoto -1<CR>", {
    desc = "Previous evaluated cell",
    silent = true,
  })

  vim.keymap.set("n", "<leader>mb", insert_cell_below, {
    desc = "Insert new cell below",
    silent = true,
  })

  -- Create a brand-new, valid, blank Python notebook and open it
  -- (jupytext needs valid ipynb JSON to convert, so an empty buffer won't work)
  vim.api.nvim_create_user_command("NewNotebook", function(opts)
    local path = opts.args ~= "" and opts.args or vim.fn.input("New notebook path: ")
    if path == "" then
      return
    end
    if not path:match("%.ipynb$") then
      path = path .. ".ipynb"
    end
    local template = [[{
 "cells": [],
 "metadata": {
  "kernelspec": {
   "display_name": "Python 3",
   "language": "python",
   "name": "python3"
  },
  "language_info": {
   "name": "python",
   "version": "3.x"
  }
 },
 "nbformat": 4,
 "nbformat_minor": 5
}]]
    local f = io.open(path, "w")
    if f then
      f:write(template)
      f:close()
      vim.cmd("edit " .. path)
    else
      vim.notify("Could not create " .. path, vim.log.levels.ERROR)
    end
  end, { nargs = "?", desc = "Create a new blank Jupyter notebook" })

  -- Auto-initialize Molten for Python files
  vim.api.nvim_create_autocmd("FileType", {
    pattern = { "python", "markdown" },
    callback = function()
      -- Show helpful message
      vim.notify("Jupyter notebook features available! Use <leader>mi to initialize kernel", vim.log.levels.INFO)
    end,
  })

  vim.notify("✓ Jupyter notebook support configured", vim.log.levels.INFO)

  setup_notebook_ui()
end

return M
