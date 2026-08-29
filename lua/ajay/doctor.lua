-- lua/ajay/doctor.lua
--
-- :AjayDoctor — tells you which layer is actually broken instead of
-- making you guess between "font", "plugin", and "terminal".
--
-- Required from init.lua, costs nothing until you run the command.

local M = {}

local function section(lines, title)
  table.insert(lines, "")
  table.insert(lines, "── " .. title .. " " .. string.rep("─", math.max(50 - #title, 3)))
end

local function report()
  local out = {}
  local v = vim.version()

  section(out, "ENVIRONMENT")
  table.insert(out, ("Neovim      : %d.%d.%d"):format(v.major, v.minor, v.patch))
  table.insert(out, ("OS          : %s"):format((vim.uv or vim.loop).os_uname().sysname))
  table.insert(out, ("Arch        : %s"):format((vim.uv or vim.loop).os_uname().machine))
  table.insert(out, ("TERM        : %s"):format(vim.env.TERM or "(unset)"))
  table.insert(out, ("TERM_PROGRAM: %s"):format(vim.env.TERM_PROGRAM or "(unset)"))
  table.insert(out, ("tmux        : %s"):format(vim.env.TMUX and "YES" or "no"))
  table.insert(out, ("termguicolors: %s"):format(tostring(vim.o.termguicolors)))

  -- ── VERSION COMPAT ──────────────────────────────────────────────
  -- Which arm of lua/ajay/compat.lua this Neovim resolved to. Read this
  -- FIRST when the same config behaves differently on two machines.
  section(out, "VERSION COMPAT")
  local ok_compat, compat = pcall(require, "ajay.compat")
  if not ok_compat then
    table.insert(out, "ajay/compat.lua failed to load: " .. tostring(compat))
  else
    table.insert(out, ("0.11+ : %s    0.12+ : %s"):format(
      compat.at_least("0.11") and "yes" or "NO",
      compat.at_least("0.12") and "yes" or "no"
    ))
    table.insert(out, "")
    table.insert(out, "Probed features (native = used directly, shim = back-filled):")
    for _, feat in ipairs(compat.tracked) do
      table.insert(out, ("  %-28s %s"):format(feat, compat.has[feat] and "native" or "absent -> shim/off"))
    end
  end

  -- ── FONT / ICONS ────────────────────────────────────────────────
  section(out, "NERD FONT")
  table.insert(out, "These should be ICONS, not boxes or blanks:")
  table.insert(out, "  folder    ")
  table.insert(out, "  folder-open ")
  table.insert(out, "  lua       ")
  table.insert(out, "  python    ")
  table.insert(out, "  java      ")
  table.insert(out, "  git       ")
  table.insert(out, "")
  table.insert(out, "If those are BLANK or BOXES -> your terminal font is not a")
  table.insert(out, "Nerd Font. No amount of Lua will fix that; fix the terminal.")

  section(out, "nvim-web-devicons")
  local ok, devicons = pcall(require, "nvim-web-devicons")
  if not ok then
    table.insert(out, "NOT LOADED. Open neo-tree once (<C-n>) and re-run.")
  else
    table.insert(out, "loaded: yes")
    for _, t in ipairs({
      { "init.lua", "lua" },
      { "main.py", "py" },
      { "Main.java", "java" },
      { "App.tsx", "tsx" },
      { "main.cpp", "cpp" },
    }) do
      local icon, hl = devicons.get_icon(t[1], t[2], { default = true })
      table.insert(out, ("  %-12s -> [%s]  hl=%s"):format(t[1], icon or "nil", hl or "nil"))
    end
    table.insert(out, "")
    table.insert(out, "If the bracketed chars above are present here but you see")
    table.insert(out, "nothing in neo-tree, the plugin is fine and it IS the font.")
  end

  -- ── CLIPBOARD ───────────────────────────────────────────────────
  section(out, "CLIPBOARD")
  table.insert(out, ("'clipboard' option : %s"):format(vim.o.clipboard == "" and "(empty)" or vim.o.clipboard))
  if vim.g.clipboard and type(vim.g.clipboard) == "table" then
    table.insert(out, ("g:clipboard        : %s (explicit)"):format(vim.g.clipboard.name or "?"))
  else
    table.insert(out, "g:clipboard        : (auto-detected)")
  end
  for _, exe in ipairs({ "pbcopy", "pbpaste", "xclip", "xsel", "wl-copy" }) do
    if vim.fn.executable(exe) == 1 then
      table.insert(out, ("  found: %-8s %s"):format(exe, vim.fn.exepath(exe)))
    end
  end

  -- Live round-trip test.
  local saved = vim.fn.getreg("+")
  local probe = "ajay-doctor-probe"
  pcall(vim.fn.setreg, "+", probe)
  local readback = vim.fn.getreg("+")
  pcall(vim.fn.setreg, "+", saved)
  table.insert(out, "")
  if readback == probe then
    table.insert(out, "  round-trip: PASS (yank/paste to system clipboard works)")
  else
    table.insert(out, ("  round-trip: FAIL (wrote %q, read back %q)"):format(probe, readback))
    table.insert(out, "  -> run :checkhealth vim.provider for the reason")
  end

  -- ── COMMENT KEYS ────────────────────────────────────────────────
  section(out, "COMMENT")
  table.insert(out, ("commentstring for this buffer: %s"):format(vim.bo.commentstring))
  for _, key in ipairs({ "gcc", "gc", "<C-_>", "<C-/>" }) do
    local m = vim.fn.maparg(key, "n")
    table.insert(out, ("  n %-8s -> %s"):format(key, m ~= "" and m or "(unmapped)"))
  end
  table.insert(out, "")
  table.insert(out, "To find what YOUR terminal sends for Ctrl+/:")
  table.insert(out, "  press i, then Ctrl-V, then Ctrl+/")
  table.insert(out, "  ^_  means <C-_>   (legacy encoding)")
  table.insert(out, "  ^[[47;5u means <C-/> (kitty protocol)")
  table.insert(out, "  nothing at all -> your terminal swallows it; use gcc")

  return out
end

function M.setup()
  vim.api.nvim_create_user_command("AjayDoctor", function()
    local lines = report()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.bo[buf].filetype = "ajaydoctor"

    local width = math.min(80, vim.o.columns - 4)
    local height = math.min(#lines + 2, vim.o.lines - 6)
    vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      width = width,
      height = height,
      row = math.floor((vim.o.lines - height) / 2),
      col = math.floor((vim.o.columns - width) / 2),
      style = "minimal",
      border = "rounded",
      title = " AjayDoctor ",
    })
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf, silent = true })
  end, { desc = "Diagnose font / icon / clipboard / keycode issues" })
end

return M
