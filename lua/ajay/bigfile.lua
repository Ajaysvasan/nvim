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
-- part of what is slow.
--
-- 5 MB, raised from 1 MB. MEASURED on this machine (synthetic C, realistic
-- open -- no forced full parse), time to open and be interactive:
--
--   file     full stack   treesitter off   + syntax off
--   1.4 MB     242 ms         107 ms           90 ms
--   4.3 MB     514 ms         124 ms          109 ms
--    10 MB    1047 ms         216 ms          120 ms
--
-- And keystroke latency with treesitter ACTIVE stayed flat at every size:
-- 0.12-0.26 ms median, p95 under 0.7 ms, even on the 10 MB / 175k-line
-- buffer. Treesitter's incremental parse handles big files fine; the whole
-- cost is the initial parse on open.
--
-- So 1 MB was stripping every feature off a file that would have opened in
-- a quarter of a second. At 5 MB the full stack still opens in ~0.6 s,
-- which is the point where a freeze starts to be worth avoiding.
--
-- For scale: 1 of 6767 kafka source files and 112 of 64952 linux source
-- files exceed even the OLD 1 MB gate, so this is a rare path either way --
-- which is exactly why it should not be aggressive.
M.max_bytes = 5 * 1024 * 1024

-- Second, much higher gate. Past this the file is big enough that a
-- language server indexing it is itself a problem, so LSP goes too.
M.lsp_max_bytes = 20 * 1024 * 1024

-- Third gate, for files that are small on disk but pathological in SHAPE
-- (minified JS, one-line JSON, generated SQL). A single enormous line
-- defeats incremental parsing and regex syntax alike, regardless of total
-- size, so this one also turns off LSP.
M.max_line_length = 2000

--- @param buf integer
--- @param drop_lsp boolean  true for the extreme tiers (see thresholds above)
local function disable_for(buf, drop_lsp)
  vim.b[buf].bigfile = true
  -- Separate flag on purpose. `bigfile` means "skip the expensive UI work";
  -- only this one means "no language server". LSP runs out of process and
  -- does not block redraw, so a merely large file keeps completion,
  -- diagnostics and gd/gr -- which is the whole reason this used to be
  -- annoying enough to turn off by hand.
  vim.b[buf].bigfile_no_lsp = drop_lsp or false

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

  -- No notification. Opening a file should not require acknowledging a
  -- message, and the state is visible anyway (no highlighting) and
  -- queryable with :BigFile status.
end

function M.setup()
  local group = vim.api.nvim_create_augroup("ajay_bigfile", { clear = true })

  vim.api.nvim_create_autocmd("BufReadPre", {
    group = group,
    callback = function(args)
      local ok, stats = pcall((vim.uv or vim.loop).fs_stat, args.match)
      if ok and stats and stats.size > M.max_bytes then
        disable_for(args.buf, stats.size > M.lsp_max_bytes)
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
          disable_for(args.buf, true) -- pathological shape: LSP off too
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
      if vim.b[args.buf].bigfile_no_lsp then
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

  --- Lift protections on the current buffer and bring the full stack back.
  local function protect_off(buf, quiet)
    vim.b[buf].bigfile = nil
    vim.b[buf].bigfile_no_lsp = nil
    vim.b[buf].disable_autoformat = nil
    vim.b[buf].codelens_off = nil
    vim.api.nvim_buf_call(buf, function()
      vim.opt_local.syntax = "on"
      vim.opt_local.cursorline = true
    end)
    pcall(vim.treesitter.start, buf)

    -- Re-attach any already-running server that handles this filetype.
    --
    -- Without this you got treesitter back but the buffer stayed
    -- permanently without LSP -- and since lsp.lua skips mapping gd/gr/K on
    -- a protected buffer, without their keymaps too.
    --
    -- Order matters: the flags above are cleared FIRST, so when
    -- buf_attach_client fires LspAttach, lsp.lua sees a normal buffer and
    -- registers the keymaps, while the detach handler above sees the same
    -- and leaves the client alone.
    local ft = vim.bo[buf].filetype
    local reattached = {}
    for _, client in ipairs(vim.lsp.get_clients()) do
      local fts = client.config and client.config.filetypes
      if not fts or vim.tbl_contains(fts, ft) then
        if pcall(vim.lsp.buf_attach_client, buf, client.id) then
          table.insert(reattached, client.name)
        end
      end
    end
    if not quiet then
      vim.notify(
        "Big-file protection OFF for this buffer."
          .. (#reattached > 0 and ("  LSP: " .. table.concat(reattached, ", ")) or ""),
        vim.log.levels.INFO,
        { title = "bigfile" }
      )
    end
  end

  local function status(buf)
    local name = vim.api.nvim_buf_get_name(buf)
    local size = 0
    if name ~= "" then
      local ok, st = pcall((vim.uv or vim.loop).fs_stat, name)
      size = (ok and st) and st.size or 0
    end
    vim.notify(
      ("size      : %.1f MB\nlines     : %d\nprotected : %s\nLSP       : %s\nthresholds: %.0f MB (protect) / %.0f MB (drop LSP)"):format(
        size / 1024 / 1024,
        vim.api.nvim_buf_line_count(buf),
        tostring(vim.b[buf].bigfile == true),
        vim.b[buf].bigfile_no_lsp and "off" or "on",
        M.max_bytes / 1024 / 1024,
        M.lsp_max_bytes / 1024 / 1024
      ),
      vim.log.levels.INFO,
      { title = "bigfile" }
    )
  end

  -- ONE command instead of the old :BigFileOff / :BigFileStatus pair.
  -- Bare `:BigFile` toggles, which is what you actually want when a file
  -- you care about got caught by the gate.
  vim.api.nvim_create_user_command("BigFile", function(a)
    local buf = vim.api.nvim_get_current_buf()
    local arg = (a.args or ""):lower()
    if arg == "status" then
      status(buf)
    elseif arg == "on" then
      disable_for(buf, false)
    elseif arg == "off" then
      protect_off(buf)
    else
      if vim.b[buf].bigfile then
        protect_off(buf)
      else
        disable_for(buf, false)
        vim.notify("Big-file protection ON for this buffer.", vim.log.levels.INFO, { title = "bigfile" })
      end
    end
  end, {
    nargs = "?",
    complete = function()
      return { "on", "off", "status" }
    end,
    desc = "Toggle big-file protection for this buffer (on|off|status)",
  })

  -- <leader>tB, capital. <leader>tb is gitsigns' blame toggle, mapped
  -- buffer-locally in its on_attach -- a buffer-local mapping silently wins
  -- over a global one, so this would have been dead in every git-tracked
  -- file. Same trap that killed harpoon's remove on <leader>hd once.
  vim.keymap.set("n", "<leader>tB", function()
    vim.cmd("BigFile")
  end, { desc = "Toggle big-file protection", silent = true })
end

return M
