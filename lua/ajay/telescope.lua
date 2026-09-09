-- lua/ajay/telescope.lua

local M = {}

function M.setup()
  local telescope = require("telescope")
  local actions = require("telescope.actions")
  local action_layout = require("telescope.actions.layout")
  local builtin = require("telescope.builtin")

  -- ── PERF ─────────────────────────────────────────────────────────
  -- Telescope's default file finder shells out to `find` and its default
  -- grep re-derives ripgrep args each call. Both `fd` and `rg` are hard
  -- requirements of this config anyway (see README), so name them
  -- explicitly and hand them the flags that matter -- with a fallback so
  -- a machine missing them still works, just slower.
  local has_fd = vim.fn.executable("fd") == 1 or vim.fn.executable("fdfind") == 1
  local fd_bin = vim.fn.executable("fd") == 1 and "fd" or "fdfind"

  local find_command = has_fd
      and {
        fd_bin,
        "--type",
        "f",
        "--hidden",
        "--follow",
        "--strip-cwd-prefix",
        -- fd reads .gitignore itself, in Rust, before results ever
        -- reach Lua. That is strictly cheaper than letting them
        -- through and matching file_ignore_patterns per result.
        "--exclude",
        ".git",
        "--exclude",
        "node_modules",
        "--exclude",
        "target",
        "--exclude",
        "build",
        "--exclude",
        "dist",
        "--exclude",
        "__pycache__",
      }
    or nil

  telescope.setup({
    defaults = {
      prompt_prefix = " 🔍 ",
      selection_caret = " ➤ ",
      path_display = { "truncate" },

      -- ── PREVIEW SIZE ─────────────────────────────────────────────
      --
      -- The default preview is far too narrow to read code in, and the
      -- reason is not obvious: telescope's `preview_width` default is not
      -- a percentage, it is a FUNCTION, and it is applied to the WINDOW
      -- width -- which is itself only 0.8 of the screen:
      --
      --   cols < 150 -> floor(cols * 0.4)
      --   cols < 200 -> 80   (fixed)
      --   else       -> 120  (fixed)
      --
      -- So on a 120-column terminal the window is 96 columns and the
      -- preview gets floor(96 * 0.4) = 38 COLUMNS. Almost every line of
      -- real code wraps or truncates at that width, which is exactly why
      -- live_grep felt unusable for anything but one-line matches. Even
      -- on a very wide terminal it is capped at a fixed 120 columns.
      --
      -- Set explicitly instead: a near-full-screen window, and a preview
      -- that is a true fraction of it and keeps scaling with the terminal.
      --
      --   120 cols -> window 114, preview ~68   (was 38)
      --   160 cols -> window 152, preview ~91   (was 51)
      --   200 cols -> window 190, preview ~114  (was 80)
      --
      -- Applied to `defaults`, so every picker WITH a previewer benefits
      -- (live_grep, grep_string, oldfiles, diagnostics, help_tags...).
      -- The pickers below that set `theme = "dropdown"` / `"cursor"` are
      -- unaffected: a theme overrides layout_strategy and layout_config,
      -- and those pickers have `previewer = false` anyway.
      layout_strategy = "horizontal",
      layout_config = {
        width = 0.95,
        height = 0.95,
        horizontal = {
          preview_width = 0.6,
          prompt_position = "bottom",
        },
        -- Used by the <C-l> layout toggle in `mappings` below. Vertical
        -- gives the preview the FULL window width, which is the better
        -- shape for long lines -- nothing truncates.
        vertical = {
          preview_height = 0.6,
          mirror = false,
        },
      },
      -- Explicit rg invocation for live_grep / grep_string. --smart-case
      -- matches the editor's ignorecase+smartcase, and --trim keeps
      -- deeply indented matches readable in a narrow results pane.
      vimgrep_arguments = {
        "rg",
        "--color=never",
        "--no-heading",
        "--with-filename",
        "--line-number",
        "--column",
        "--smart-case",
        "--trim",
      },
      file_ignore_patterns = {
        "node_modules",
        ".git/",
        "dist/",
        "build/",
        "target/",
        "*.class",
        "__pycache__",
        "*.pyc",
      },
      mappings = {
        i = {
          ["<C-j>"] = actions.move_selection_next,
          ["<C-k>"] = actions.move_selection_previous,
          ["<C-q>"] = actions.send_to_qflist + actions.open_qflist,
          ["<C-x>"] = actions.delete_buffer,
          ["<esc>"] = actions.close,
          -- <C-o> = "orientation": cycle horizontal <-> vertical without
          -- leaving the picker. Vertical hands the preview the FULL window
          -- width, so a long line of code reads end to end instead of
          -- truncating -- worth a key rather than a permanent choice,
          -- because the same search wants a different shape depending on
          -- how wide the code is.
          --
          -- <C-o> specifically because telescope's own defaults already
          -- claim nearly every other control key in the prompt: <C-l> is
          -- complete_tag, <C-p> is move_selection_previous, <C-k>/<C-f>
          -- scroll the preview, <C-v>/<C-x>/<C-t> open splits. <C-o> and
          -- <C-y> are the only obvious ones left, and neither is bound in
          -- insert OR normal mode. Press <C-/> in any picker to see the
          -- full live list.
          ["<C-o>"] = action_layout.cycle_layout_next,
        },
        n = {
          ["q"] = actions.close,
          ["<C-x>"] = actions.delete_buffer,
          ["<C-o>"] = action_layout.cycle_layout_next,
        },
      },
    },
    pickers = {
      find_files = {
        theme = "dropdown",
        previewer = false,
        hidden = true,
        find_command = find_command,
      },
      buffers = {
        theme = "dropdown",
        previewer = false,
        initial_mode = "normal",
        mappings = {
          i = {
            ["<C-d>"] = actions.delete_buffer,
          },
          n = {
            ["dd"] = actions.delete_buffer,
          },
        },
      },
      git_branches = {
        theme = "dropdown",
        previewer = false,
      },
      lsp_references = {
        theme = "cursor",
        initial_mode = "normal",
      },
      lsp_definitions = {
        theme = "cursor",
        initial_mode = "normal",
      },
      lsp_document_symbols = {
        theme = "dropdown",
      },
      lsp_workspace_symbols = {
        theme = "dropdown",
      },
    },
    extensions = {
      fzf = {
        fuzzy = true,
        override_generic_sorter = true,
        override_file_sorter = true,
        case_mode = "smart_case",
      },
    },
  })

  -- Load extensions
  pcall(telescope.load_extension, "fzf")

  -- ============================================================
  -- KEYMAPS
  -- ============================================================

  -- File Navigation
  vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Find files" })
  vim.keymap.set("n", "<leader>fa", function()
    builtin.find_files({ hidden = true, no_ignore = true })
  end, { desc = "Find all files (including hidden)" })
  vim.keymap.set("n", "<leader>fr", builtin.oldfiles, { desc = "Recent files" })

  -- Search Content
  vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Live grep" })
  vim.keymap.set("n", "<leader>fw", builtin.grep_string, { desc = "Find word under cursor" })
  vim.keymap.set("n", "<leader>fs", function()
    builtin.grep_string({ search = vim.fn.input("Grep > ") })
  end, { desc = "Search string" })

  -- Buffer Management
  vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Find buffers" })
  vim.keymap.set("n", "<leader><leader>", builtin.buffers, { desc = "Quick buffer switch" })

  -- LSP & Symbols
  vim.keymap.set("n", "<leader>fd", builtin.lsp_document_symbols, { desc = "Document symbols" })
  vim.keymap.set("n", "<leader>fD", builtin.lsp_workspace_symbols, { desc = "Workspace symbols" })
  vim.keymap.set("n", "<leader>fi", builtin.lsp_implementations, { desc = "Implementations" })
  vim.keymap.set("n", "<leader>fR", builtin.lsp_references, { desc = "References" })

  -- Diagnostics
  vim.keymap.set("n", "<leader>fe", builtin.diagnostics, { desc = "Diagnostics (all)" })
  vim.keymap.set("n", "<leader>fE", function()
    builtin.diagnostics({ bufnr = 0 })
  end, { desc = "Diagnostics (current buffer)" })

  -- Git
  vim.keymap.set("n", "<leader>gc", builtin.git_commits, { desc = "Git commits" })
  vim.keymap.set("n", "<leader>gb", builtin.git_branches, { desc = "Git branches" })
  vim.keymap.set("n", "<leader>gs", builtin.git_status, { desc = "Git status" })
  vim.keymap.set("n", "<leader>gS", builtin.git_stash, { desc = "Git stash" })

  -- TODOs & Comments
  vim.keymap.set("n", "<leader>ft", function()
    builtin.grep_string({
      search = "TODO|FIXME|NOTE|HACK|PERF|WARNING",
      use_regex = true,
    })
  end, { desc = "Find TODOs/FIXMEs" })

  -- Neovim Internals
  vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Help tags" })
  vim.keymap.set("n", "<leader>fk", builtin.keymaps, { desc = "Keymaps" })
  vim.keymap.set("n", "<leader>fc", builtin.commands, { desc = "Commands" })
  vim.keymap.set("n", "<leader>fC", builtin.colorscheme, { desc = "Colorschemes" })
  vim.keymap.set("n", "<leader>fm", builtin.marks, { desc = "Marks" })
  vim.keymap.set("n", "<leader>fj", builtin.jumplist, { desc = "Jumplist" })
  vim.keymap.set("n", "<leader>fq", builtin.quickfix, { desc = "Quickfix" })
  vim.keymap.set("n", "<leader>fl", builtin.loclist, { desc = "Location list" })

  -- Search in current buffer
  vim.keymap.set("n", "<leader>/", builtin.current_buffer_fuzzy_find, { desc = "Fuzzy find in buffer" })

  -- Resume last picker
  vim.keymap.set("n", "<leader>fp", builtin.resume, { desc = "Resume last picker" })
end

return M
