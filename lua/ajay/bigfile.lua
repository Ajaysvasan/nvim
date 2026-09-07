-- lua/ajay/bigfile.lua
--
-- Neovim has no built-in protection against opening a file large enough
-- to hang it. The failure is not a crash -- it is a multi-second freeze on
-- every keystroke, because several subsystems each do O(file) work per
-- edit:
--
--   treesitter        full parse on open, tree held in memory
--   LSP               whole-document sync on every change
--   gitsigns          diffs the buffer against the index
--   indent-blankline  walks the tree for indent guides
--   rainbow-delims    a treesitter query over the entire tree
--   codelens          a server round trip per refresh
--   conform           spawns a formatter over the whole buffer on save
--
-- This turns all of that off above a threshold so the file OPENS and you
-- can search and edit it. It does not make a huge file feel like a normal
-- one -- nothing can.
--
-- Buffer-local flag: vim.b[buf].bigfile

local M = {}

-- Bytes, not lines: a line count needs the file read first, which is
-- part of what is slow. 1 MB is roughly 20-30k lines of ordinary code.
M.max_bytes = 1024 * 1024

-- Second gate for files that are small on disk but pathological in shape
-- (minified JS, one-line JSON, generated SQL).
M.max_line_length = 2000

local function disable_for(buf)
  vim.b[buf].bigfile = true

  -- conform already honours this (see conform.lua's format_on_save).
  vim.b[buf].disable_autoformat = true
  -- lsp.lua checks this before scheduling codelens refreshes.
  vim.b[buf].codelens_off = true

  vim.bo[buf].swapfile = false
  vim.bo[buf].undofile = false -- an undo file for a huge buffer is huge
  vim.bo[buf].undolevels = -1

  vim.api.nvim_buf_call(buf, function()
    vim.opt_local.foldmethod = "manual"
    vim.opt_local.spell = false
    vim.opt_local.list = false
    vim.opt_local.wrap = false
    -- relativenumber recomputes every visible line on every cursor move.
    vim.opt_local.relativenumber = false
    vim.opt_local.cursorline = false
    vim.opt_local.colorcolumn = ""
    -- Regex syntax highlighting is worse than treesitter here, not
    -- better. Both off.
    vim.opt_local.syntax = "off"
  end)

  pcall(vim.treesitter.stop, buf)

  -- indent-blankline has no buffer flag; it takes a per-buffer setup.
  pcall(function()
    require("ibl").setup_buffer(buf, { enabled = false })
  end)

  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.notify(
        "Large file: treesitter, LSP, git signs and format-on-save disabled.\n"
          .. "Re-enable for this buffer with :BigFileOff",
        vim.log.levels.WARN,
        { title = "bigfile" }
      )
    end
  end)
end

function M.setup()
  local group = vim.api.nvim_create_augroup("ajay_bigfile", { clear = true })

  vim.api.nvim_create_autocmd("BufReadPre", {
    group = group,
    callback = function(args)
      local ok, stats = pcall((vim.uv or vim.loop).fs_stat, args.match)
      if ok and stats and stats.size > M.max_bytes then
        disable_for(args.buf)
      end
    end,
  })

  -- Shape check, after the file is in memory.
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = group,
    callback = function(args)
      if vim.b[args.buf].bigfile then
        return
      end
      local lines = vim.api.nvim_buf_get_lines(args.buf, 0, 64, false)
      for _, line in ipairs(lines) do
        if #line > M.max_line_length then
          disable_for(args.buf)
          return
        end
      end
    end,
  })

  -- Keep language servers off these buffers. Cheaper and more reliable
  -- than letting one attach and then detaching it.
  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(args)
      if vim.b[args.buf].bigfile then
        vim.schedule(function()
          pcall(vim.lsp.buf_detach_client, args.buf, args.data.client_id)
        end)
      end
    end,
  })

  -- Re-assert `syntax=off` AFTER filetype detection.
  --
  -- disable_for() runs at BufReadPre, before the filetype is known. Setting
  -- syntax there is pointless: filetype detection fires afterwards and the
  -- syntax script turns regex highlighting straight back on. With
  -- treesitter already off, that leaves the SLOWEST highlighter running on
  -- the biggest buffer -- the exact thing this module exists to prevent.
  --
  -- Scheduled inside the FileType callback so it lands after the syntax
  -- autocmds that would otherwise re-enable it.
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    callback = function(args)
      if not vim.b[args.buf].bigfile then
        return
      end
      vim.schedule(function()
        if vim.api.nvim_buf_is_valid(args.buf) and vim.b[args.buf].bigfile then
          vim.bo[args.buf].syntax = "off"
        end
      end)
    end,
  })

  vim.api.nvim_create_user_command("BigFileOff", function()
    local buf = vim.api.nvim_get_current_buf()
    vim.b[buf].bigfile = nil
    vim.b[buf].disable_autoformat = nil
    vim.b[buf].codelens_off = nil
    vim.api.nvim_buf_call(buf, function()
      vim.opt_local.syntax = "on"
      vim.opt_local.cursorline = true
    end)
    pcall(vim.treesitter.start, buf)
    vim.notify("Big-file protections lifted for this buffer.", vim.log.levels.INFO)
  end, { desc = "Re-enable treesitter/LSP on a large buffer" })

  vim.api.nvim_create_user_command("BigFileStatus", function()
    local buf = vim.api.nvim_get_current_buf()
    local name = vim.api.nvim_buf_get_name(buf)
    local size = 0
    if name ~= "" then
      local ok, st = pcall((vim.uv or vim.loop).fs_stat, name)
      size = (ok and st) and st.size or 0
    end
    vim.notify(
      ("size      : %.1f MB\nlines     : %d\nprotected : %s\nthreshold : %.1f MB"):format(
        size / 1024 / 1024,
        vim.api.nvim_buf_line_count(buf),
        tostring(vim.b[buf].bigfile == true),
        M.max_bytes / 1024 / 1024
      ),
      vim.log.levels.INFO,
      { title = "bigfile" }
    )
  end, { desc = "Show big-file status for this buffer" })
end

return M
