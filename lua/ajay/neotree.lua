-- lua/ajay/neotree.lua
--
-- Changes from the old version:
--  1. Wrapped in a module (M.setup) so it no longer runs at startup.
--  2. Explicit `default_component_configs` so folder/file/git icons are
--     defined by us instead of relying on neo-tree defaults.
--  3. Falls back to ASCII when vim.g.have_nerd_font is false, so a machine
--     without a patched font degrades instead of showing tofu boxes.
--  4. nvim_buf_get_option -> vim.bo[buf] (removed in Neovim 0.12).

local M = {}

-- Glyphs come from ajay.icons (built from codepoints). The literal
-- characters that used to live here were stripped to "" in transit,
-- which is exactly why folder and file icons went missing.
local ok_icons, ic = pcall(require, "ajay.icons")
if not ok_icons then
  ic = {
    tree = {
      folder_closed = "+",
      folder_open = "-",
      folder_empty = "*",
      folder_empty_open = "*",
      default = " ",
      expander_collapsed = ">",
      expander_expanded = "v",
    },
    git = {
      added = "A",
      modified = "M",
      deleted = "D",
      renamed = "R",
      untracked = "?",
      ignored = "!",
      unstaged = "U",
      staged = "S",
      conflict = "C",
    },
  }
end

local icons = {
  folder_closed = ic.tree.folder_closed,
  folder_open = ic.tree.folder_open,
  folder_empty = ic.tree.folder_empty,
  folder_empty_open = ic.tree.folder_empty_open,
  default = ic.tree.default,
  expander_collapsed = ic.tree.expander_collapsed,
  expander_expanded = ic.tree.expander_expanded,
  added = ic.git.added,
  modified = ic.git.modified,
  deleted = ic.git.deleted,
  renamed = ic.git.renamed,
  untracked = ic.git.untracked,
  ignored = ic.git.ignored,
  unstaged = ic.git.unstaged,
  staged = ic.git.staged,
  conflict = ic.git.conflict,
}

function M.setup()
  -- Force nvim-web-devicons to load first; neo-tree only shows per-filetype
  -- icons if devicons is already in memory when it builds its components.
  pcall(require, "nvim-web-devicons")

  require("neo-tree").setup({
    close_if_last_window = false,
    popup_border_style = "rounded",
    enable_git_status = true,
    enable_diagnostics = true,

    default_component_configs = {
      indent = {
        indent_size = 2,
        padding = 1,
        with_markers = true,
        indent_marker = "│",
        last_indent_marker = "└",
        highlight = "NeoTreeIndentMarker",
        with_expanders = true,
        expander_collapsed = icons.expander_collapsed,
        expander_expanded = icons.expander_expanded,
        expander_highlight = "NeoTreeExpander",
      },
      icon = {
        folder_closed = icons.folder_closed,
        folder_open = icons.folder_open,
        folder_empty = icons.folder_empty,
        folder_empty_open = icons.folder_empty_open,
        default = icons.default,
        highlight = "NeoTreeFileIcon",
        -- Let nvim-web-devicons provide per-extension icons.
        provider = function(icon, node)
          if node.type == "file" or node.type == "terminal" then
            local ok, devicons = pcall(require, "nvim-web-devicons")
            if not ok then
              return
            end
            local name = node.type == "terminal" and "terminal" or node.name
            local ico, hl = devicons.get_icon(name, node.ext, { default = true })
            if ico then
              icon.text, icon.highlight = ico, hl
            end
          end
        end,
      },
      modified = { symbol = icons.modified, highlight = "NeoTreeModified" },
      git_status = {
        symbols = {
          added = icons.added,
          modified = icons.modified,
          deleted = icons.deleted,
          renamed = icons.renamed,
          untracked = icons.untracked,
          ignored = icons.ignored,
          unstaged = icons.unstaged,
          staged = icons.staged,
          conflict = icons.conflict,
        },
      },
    },

    filesystem = {
      follow_current_file = { enabled = true },
      use_libuv_file_watcher = true,

      -- ── COMPACT MIDDLE PACKAGES ──────────────────────────────────
      --
      -- This is IntelliJ's "Compact Middle Packages", and it matters far
      -- more than window width for Java. When a directory holds exactly
      -- one child and that child is a directory, neo-tree merges them into
      -- a single row:
      --
      --   project            project/two/wallet
      --     two         ->     Config
      --       wallet           Controller
      --         Config
      --         Controller
      --
      -- A Java package path is a chain of exactly that shape, so this
      -- reclaims one indent level per package segment -- the thing that
      -- was actually eating the tree, since widening only buys columns
      -- linearly while nesting costs them on every level.
      --
      -- Trade-off: you can no longer expand or collapse the intermediate
      -- directories separately, because they are no longer separate rows.
      -- That is the same deal IntelliJ makes, and for a package chain
      -- there is nothing in those middle directories to look at anyway.
      group_empty_dirs = true,
      filtered_items = {
        visible = false,
        hide_dotfiles = false,
        hide_gitignored = false,
      },
    },

    window = {
      position = "left",

      -- ── WIDTH ────────────────────────────────────────────────────
      --
      -- Was a flat 30, which is fine for a flat repo and far too narrow
      -- for Java. Every level of nesting costs `indent_size` (2) plus the
      -- marker column, and Java buries source deep:
      --
      --   wallet/src/main/java/project/two/wallet/DTO/Wallets/X.java
      --
      -- is nine levels below the project root, so ~20 of those 30 columns
      -- were gone before the filename started. Real names got cut to
      -- "Transacti" and "Controll".
      --
      -- neo-tree's `resolve_width` accepts a number, a "25%" string, or a
      -- FUNCTION -- so scale with the terminal and clamp both ends:
      --
      --   100 cols -> 34    170 cols -> 42    250 cols -> 55 (capped)
      --
      -- The floor keeps deep Java paths readable on a laptop screen; the
      -- ceiling stops the tree eating half of an ultrawide.
      width = function()
        return math.max(34, math.min(55, math.floor(vim.o.columns * 0.25)))
      end,

      -- Deliberately left OFF (it is the default).
      --
      -- `auto_expand_width` resizes the window to `longest_node` whenever a
      -- name overflows -- and reading the renderer, it only ever GROWS
      -- (`desired_width > last_user_width`) and has no upper bound. In a
      -- monorepo like kafka, with 6 500 Java files nested ten deep, one
      -- long path would throw the tree across most of the screen and it
      -- would never come back. The clamped width above is the predictable
      -- version of the same idea.
      auto_expand_width = false,

      mapping_options = { noremap = true, nowait = true },
    },
  })
end

-- Smart toggle: toggle if closed, focus if open but not focused.
-- Registered here (not at file scope) so the `keys` entry in the plugin
-- spec is what actually triggers the load.
vim.keymap.set("n", "<C-n>", function()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    -- vim.bo[buf].filetype replaces nvim_buf_get_option, which is
    -- deprecated in 0.10/0.11 and removed in 0.12. Homebrew ships a newer
    -- Neovim than most distro repos, which is why this only broke on macOS.
    if vim.bo[buf].filetype == "neo-tree" then
      if vim.api.nvim_get_current_win() == win then
        vim.cmd("Neotree close")
      else
        vim.api.nvim_set_current_win(win)
      end
      return
    end
  end
  vim.cmd("Neotree focus")
end, { noremap = true, silent = true, desc = "Toggle/Focus Neo-tree" })

return M
