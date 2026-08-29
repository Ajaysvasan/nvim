-- lua/ajay/icons.lua
--
-- WHY THIS FILE EXISTS
--
-- Nerd Font glyphs live in the Unicode Private Use Area. They survive
-- some copy/paste and encoding pipelines and not others -- several of
-- them were silently stripped to empty strings ("") in this config,
-- which is worse than a visible failure: an empty sign text means the
-- gutter renders nothing at all and no error is raised. Diagnostics
-- just quietly stop showing.
--
-- Defining them by CODEPOINT is immune to that. vim.fn.nr2char builds
-- the character at runtime, so this file is pure ASCII and copies
-- cleanly anywhere.
--
-- Codepoint reference: https://www.nerdfonts.com/cheat-sheet

local M = {}

local nerd = vim.g.have_nerd_font ~= false

-- Build a glyph from a codepoint, or fall back to plain ASCII when
-- vim.g.have_nerd_font is false.
local function g(codepoint, fallback)
  if not nerd then
    return fallback
  end
  return vim.fn.nr2char(codepoint)
end

M.diagnostics = {
  ERROR = g(0xf057, "E"), -- nf-fa-times_circle
  WARN = g(0xf071, "W"), -- nf-fa-warning
  INFO = g(0xf05a, "I"), -- nf-fa-info_circle
  HINT = g(0xf0eb, "H"), -- nf-fa-lightbulb_o
}

M.tree = {
  folder_closed = g(0xf07b, "+"), -- nf-fa-folder
  folder_open = g(0xf07c, "-"), -- nf-fa-folder_open
  folder_empty = g(0xf114, "*"), -- nf-fa-folder_o
  folder_empty_open = g(0xf115, "*"), -- nf-fa-folder_open_o
  default = g(0xf15b, " "), -- nf-fa-file
  expander_collapsed = g(0xf0da, ">"), -- nf-fa-caret_right
  expander_expanded = g(0xf0d7, "v"), -- nf-fa-caret_down
}

M.git = {
  added = g(0xf067, "A"), -- nf-fa-plus
  modified = g(0xf111, "M"), -- nf-fa-circle
  deleted = g(0xf00d, "D"), -- nf-fa-close
  renamed = g(0xf061, "R"), -- nf-fa-arrow_right
  untracked = g(0xf128, "?"), -- nf-fa-question
  ignored = g(0xf05e, "!"), -- nf-fa-ban
  unstaged = g(0xf06a, "U"), -- nf-fa-exclamation_circle
  staged = g(0xf00c, "S"), -- nf-fa-check
  conflict = g(0xf071, "C"), -- nf-fa-warning
}

M.dap = {
  breakpoint = g(0xf111, "B"), -- nf-fa-circle
  breakpoint_condition = g(0xf192, "C"), -- nf-fa-dot_circle_o
  log_point = g(0xf1c9, "L"), -- nf-fa-file_code_o
  stopped = g(0xf04b, ">"), -- nf-fa-play
  rejected = g(0xf00d, "X"), -- nf-fa-close
  pause = g(0xf04c, "||"), -- nf-fa-pause
  play = g(0xf04b, ">"), -- nf-fa-play
  step_into = g(0xf063, "I"), -- nf-fa-arrow_down
  step_over = g(0xf061, "O"), -- nf-fa-arrow_right
  step_out = g(0xf062, "U"), -- nf-fa-arrow_up
  step_back = g(0xf060, "B"), -- nf-fa-arrow_left
  run_last = g(0xf021, "R"), -- nf-fa-refresh
  terminate = g(0xf04d, "T"), -- nf-fa-stop
  disconnect = g(0xf127, "D"), -- nf-fa-chain_broken
}

-- Quick visual check that the font is actually rendering these.
-- :lua require("ajay.icons").preview()
function M.preview()
  local lines =
    { "If any of these are boxes or blanks, the TERMINAL FONT is", "not a Nerd Font. Nothing in Lua can fix that.", "" }
  for _, group in ipairs({ "diagnostics", "tree", "git", "dap" }) do
    table.insert(lines, group .. ":")
    local row = {}
    for name, glyph in pairs(M[group]) do
      table.insert(row, ("%s %s"):format(glyph, name))
    end
    table.sort(row)
    table.insert(lines, "  " .. table.concat(row, "   "))
    table.insert(lines, "")
  end
  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "icons" })
end

return M
