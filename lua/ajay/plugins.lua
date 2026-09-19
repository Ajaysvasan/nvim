-- lua/ajay/plugins.lua
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
end

vim.opt.rtp:prepend(lazypath)

-- Calling require("x").setup() directly gives you "attempt to index a
-- boolean value" when the module is truncated or fails to return its
-- table -- a message that says nothing about which file or why.
--
-- Lua sets package.loaded[name] = true when a chunk runs to completion
-- without returning anything, so a file missing its trailing `return M`
-- (or cut short by a partial copy/paste) produces exactly that.
local function setup_module(name)
  local ok, mod = pcall(require, name)
  if not ok then
    vim.schedule(function()
      vim.notify(("Failed to load %s:\n%s"):format(name, mod), vim.log.levels.ERROR)
    end)
    return
  end
  if type(mod) ~= "table" then
    vim.schedule(function()
      vim.notify(
        ("%s loaded but returned %s, not a table.\n\n"):format(name, type(mod))
          .. "The file is almost certainly truncated. Check that it ends\n"
          .. "with `return M`:\n\n"
          -- BUG FIX: was gsub("%%.", "/") -- "%%" is a literal '%' in a Lua
          -- pattern, so that matched '%' + any char, which a module name
          -- like "ajay.telescope" never has. The gsub did nothing, and this
          -- error message -- shown only when a module is broken, exactly
          -- when you most need the right path -- suggested a nonexistent
          -- file ("lua/ajay.telescope.lua" instead of "lua/ajay/telescope.lua").
          .. ("  tail -3 ~/.config/nvim/lua/%s.lua"):format(name:gsub("%.", "/")),
        vim.log.levels.ERROR
      )
    end)
    return
  end
  if type(mod.setup) ~= "function" then
    vim.schedule(function()
      vim.notify(("%s has no setup() function."):format(name), vim.log.levels.ERROR)
    end)
    return
  end
  mod.setup()
end

require("lazy").setup({
  -- ══════════════════════════════════════════════════════════════════
  -- COLORSCHEME  (must be eager + high priority)
  -- ══════════════════════════════════════════════════════════════════
  -- ONE theme: VS Code Dark+. To switch, see the header of colorscheme.lua.
  {
    "Mofiqul/vscode.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      setup_module("ajay.colorscheme")
      -- Registers :ToggleTransparency and <leader>tt. Registration only --
      -- it does not change your appearance until you press the key.
      setup_module("ajay.transparency")
    end,
  },

  -- No file-tree plugin. netrw (Neovim's built-in) is the directory
  -- browser -- `:Ex` -- which is why it is not in `disabled_plugins` below.

  -- ══════════════════════════════════════════════════════════════════
  -- TELESCOPE
  -- ══════════════════════════════════════════════════════════════════
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    -- EVERY lhs telescope.lua maps has to be listed here. lazy.nvim only
    -- creates a load-trigger for keys named in `keys`; a mapping the module
    -- makes that is NOT named is dead on a fresh session until some OTHER
    -- trigger happens to load the plugin first. Only these five were listed
    -- before, so <leader>fw, <leader>fh, the four <leader>g* git pickers and
    -- fifteen others did nothing until you had already pressed <leader>ff.
    -- Same failure the harpoon spec below documents.
    keys = {
      { "<leader>ff", desc = "Find files" },
      { "<leader>fg", desc = "Live grep" },
      { "<leader>fb", desc = "Buffers" },
      { "<leader><leader>", desc = "Quick buffer switch" },
      { "<leader>/", desc = "Fuzzy find in buffer" },
      -- files / content
      "<leader>fa",
      "<leader>fr",
      "<leader>fw",
      "<leader>fs",
      "<leader>fp",
      -- lsp / symbols / diagnostics
      "<leader>fd",
      "<leader>fD",
      "<leader>fi",
      "<leader>fR",
      "<leader>fe",
      "<leader>fE",
      -- git pickers
      "<leader>gc",
      "<leader>gb",
      "<leader>gs",
      "<leader>gS",
      -- neovim internals
      "<leader>ft",
      "<leader>fh",
      "<leader>fk",
      "<leader>fc",
      "<leader>fC",
      "<leader>fm",
      "<leader>fj",
      "<leader>fq",
      "<leader>fl",
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        -- NOTE: declared exactly once. The old config listed this twice
        -- inside the same dependencies table, which meant the spec without
        -- `build` could win and the C extension never got compiled.
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        -- Skip the extension entirely if there's no working toolchain,
        -- rather than failing the whole telescope install.
        cond = function()
          return vim.fn.executable("make") == 1 and vim.fn.executable("cc") == 1
        end,
      },
    },
    config = function()
      setup_module("ajay.telescope")
    end,
  },

  -- ══════════════════════════════════════════════════════════════════
  -- LSP / MASON
  -- NOTE: everything is `mason-org/*` now. The old spec mixed
  -- `williamboman/mason.nvim` and `mason-org/mason.nvim`, which makes
  -- lazy.nvim try to clone two different repos into the same
  -- `~/.local/share/nvim/lazy/mason.nvim` directory.
  -- ══════════════════════════════════════════════════════════════════
  {
    "mason-org/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonUpdate", "MasonUninstall", "MasonLog" },
    build = ":MasonUpdate",
    opts = { ui = { border = "rounded" } },
  },
  -- PERF: mason-lspconfig and mason-tool-installer are NO LONGER
  -- dependencies of nvim-lspconfig.
  --
  -- lazy.nvim loads a plugin's `dependencies` before the plugin itself, so
  -- listing mason there meant mason.nvim's `opts` ran -- i.e. a full
  -- `require("mason").setup()` -- on BufReadPre, before the first file was
  -- even drawn. Building the package registry pulls in
  -- mason-registry.sources.github and mason-core.package and cost ~13ms of
  -- every startup that opened a file.
  --
  -- None of that is needed to RUN a server: all mason contributes at
  -- runtime is its bin directory on PATH, which options.lua now sets in one
  -- line. Registry work only matters when INSTALLING, so lsp.lua pulls
  -- these in on demand -- see the "Mason, on demand" section there.
  { "mason-org/mason-lspconfig.nvim", lazy = true },
  { "WhoIsSethDaniel/mason-tool-installer.nvim", lazy = true },
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    -- lsp.lua defines these three, and `event` alone does not make an Ex
    -- command exist -- only `cmd` does. Without this they were "E492: Not
    -- an editor command" until a file had been opened.
    --
    -- :MasonSync is the one that actually stung: it is the "go install
    -- whatever tooling is missing" command, so the moment you most want it
    -- is a cold editor with no file open -- exactly where it did not exist.
    -- Same bug as :ToggleFormatOnSave and :FormatStatus in the conform spec.
    cmd = { "MasonSync", "ToggleCodeLens", "ToggleInlayHints" },
    dependencies = { "hrsh7th/cmp-nvim-lsp" },
    config = function()
      require("ajay.lsp")
    end,
  },
  {
    "mfussenegger/nvim-jdtls",
    ft = "java",
    config = function()
      setup_module("ajay.jdtls")
    end,
  },

  -- ══════════════════════════════════════════════════════════════════
  -- COMPLETION
  -- ══════════════════════════════════════════════════════════════════
  {
    "hrsh7th/nvim-cmp",
    event = { "InsertEnter", "CmdlineEnter" },
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      {
        "L3MON4D3/LuaSnip",
        -- jsregexp is optional; only attempt it when a compiler exists.
        build = vim.fn.executable("make") == 1 and vim.fn.executable("cc") == 1 and "make install_jsregexp" or nil,
      },
      "saadparwaiz1/cmp_luasnip",
      "rafamadriz/friendly-snippets",
    },
    config = function()
      require("ajay.cmp")
    end,
  },

  -- ══════════════════════════════════════════════════════════════════
  -- TREESITTER
  -- ══════════════════════════════════════════════════════════════════
  {
    "nvim-treesitter/nvim-treesitter",
    -- WAS branch = "master". On Neovim 0.12 master's query_predicates
    -- break on markdown fenced code blocks:
    --   "attempt to call method 'range' (a nil value)"
    -- master is frozen upstream, so there is no fix coming. `main` is
    -- the supported branch for 0.11+.
    branch = "main",
    -- Loaded eagerly: on main, highlighting is started by a FileType
    -- autocmd that treesitter.lua registers, so the plugin has to be
    -- loaded before the first FileType event rather than by it.
    lazy = false,
    build = ":TSUpdate",
    dependencies = {
      { "nvim-treesitter/nvim-treesitter-textobjects", branch = "main" },
    },
    config = function()
      require("ajay.treesitter")
    end,
  },
  {
    "HiPhish/rainbow-delimiters.nvim",
    event = { "BufReadPost", "BufNewFile" },
    -- `init`, not `config`: this must be set BEFORE the plugin's own
    -- FileType autocmd runs, and that autocmd is registered the moment the
    -- plugin loads.
    init = function()
      -- SIZE GATE. Without this, rainbow-delimiters attaches to any buffer
      -- with a treesitter parser, at any size, and its attach() calls
      --
      --   parser:parse(nil)        -- nil range = parse the WHOLE buffer
      --
      -- which is the one thing treesitter is normally careful never to do.
      -- The highlighter parses only the visible range and extends lazily;
      -- this forces the entire file through the parser synchronously, then
      -- walks the resulting tree to place an extmark on every delimiter.
      --
      -- Measured on kafka's GroupMetadataManagerTest.java (1.42 MB, 30,692
      -- lines): 2.09 s wall / 1.90 s CPU / 159 MB RSS with it, 0.20 s /
      -- 0.07 s / 40 MB without. It also costs ~3.7 ms on EVERY keystroke,
      -- because the query re-runs on change.
      --
      -- Cost tracks delimiter density, so lines is the right proxy, not
      -- bytes: a 0.83 MB C lookup table is free, a 1.42 MB nested Java test
      -- file is not. Measured deltas: ~0 at 1k lines, +90 ms at 2.4k,
      -- +220 ms at 3.3k, +1220 ms at 13.8k, +2130 ms at 30.7k. 5000 keeps
      -- the worst case around a quarter second.
      --
      -- Only `condition` is set. rainbow's config falls back to its own
      -- defaults for strategy/query/priority/highlight (see get_nested in
      -- its config.lua), so this does not clobber anything else.
      vim.g.rainbow_delimiters = {
        condition = function(bufnr)
          -- Protected buffers already skip it via treesitter being stopped,
          -- but say so explicitly rather than relying on that side effect.
          if vim.b[bufnr].bigfile then
            return false
          end
          return vim.api.nvim_buf_line_count(bufnr) <= 5000
        end,
      }
    end,
  },
  -- ══════════════════════════════════════════════════════════════════
  -- FORMATTING  (conform only — null-ls and autoformat.lua are gone)
  -- ══════════════════════════════════════════════════════════════════
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    -- BUG FIX: found benchmarking against kafka. The `keys` entries below
    -- cover <leader>tf/<leader>tF, but lazy only stubs an EX COMMAND from
    -- `cmd`. ToggleFormatOnSave and ToggleFormatOnSaveBuffer were missing
    -- from this list, so typing either by name -- rather than using the
    -- leader keymap -- before ever saving a file threw "E492: Not an
    -- editor command", because conform.nvim (and the commands it defines)
    -- had never been loaded.
    -- FormatStatus was missing here too -- same E492 as the two toggles:
    -- `:FormatStatus` typed by name, before any save, was "Not an editor
    -- command". Every command conform.lua defines must be listed.
    cmd = { "ConformInfo", "Format", "ToggleFormatOnSave", "ToggleFormatOnSaveBuffer", "FormatStatus", "FormatDetect" },
    keys = {
      { "<leader>lf", mode = { "n", "v" }, desc = "Format buffer" },
      -- The toggles conform.lua registers. `event = BufWritePre` only fires
      -- on a SAVE, so without these the toggles did not exist until you had
      -- already written a file -- which is exactly when you want to reach
      -- for "turn format-on-save off".
      { "<leader>tf", desc = "Toggle format on save (global)" },
      { "<leader>tF", desc = "Toggle format on save (buffer)" },
      { "<leader>ts", desc = "Format status" },
      { "<leader>ti", desc = "Conform info" },
    },
    config = function()
      setup_module("ajay.conform")
    end,
  },

  -- ══════════════════════════════════════════════════════════════════
  -- GIT
  -- ══════════════════════════════════════════════════════════════════
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      setup_module("ajay.gitsigns")
    end,
  },

  -- ══════════════════════════════════════════════════════════════════
  -- WHICH-KEY  (prefix hints)
  -- ══════════════════════════════════════════════════════════════════
  -- VeryLazy, not a key trigger: it has to be listening BEFORE you press
  -- a prefix, and lazy-loading it on <leader> would swallow the first
  -- press of the session.
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      setup_module("ajay.whichkey")
    end,
  },

  -- ══════════════════════════════════════════════════════════════════
  -- DEBUGGER  (single spec — the old file declared nvim-dap twice at the
  -- top level with two different `config` functions)
  -- ══════════════════════════════════════════════════════════════════
  {
    "mfussenegger/nvim-dap",
    -- As with telescope above: dap.lua maps 25 keys, only 7 were listed, so
    -- everything from <leader>dB to <leader>d? was unreachable until you had
    -- already hit <leader>db / <leader>dc / <F5>.
    keys = {
      { "<leader>db", desc = "DAP toggle breakpoint" },
      { "<leader>dc", desc = "DAP continue / start" },
      { "<leader>du", desc = "DAP UI toggle" },
      { "<F5>", desc = "DAP continue" },
      { "<F6>", desc = "DAP step over" },
      { "<F7>", desc = "DAP step into" },
      { "<F8>", desc = "DAP step out" },
      { "<F9>", desc = "DAP step back" },
      { "<F10>", desc = "DAP run to cursor" },
      -- breakpoints / session
      "<leader>dB",
      "<leader>dl",
      "<leader>dC",
      "<leader>dr",
      "<leader>dq",
      "<leader>dp",
      "<leader>dR",
      -- inspection (dap-ui). <leader>de is normal AND visual.
      "<leader>ds",
      "<leader>df",
      "<leader>dK",
      { "<leader>de", mode = { "n", "v" }, desc = "DAP eval" },
      -- python test helpers. <leader>dts is visual only.
      "<leader>dtn",
      "<leader>dtc",
      { "<leader>dts", mode = "v", desc = "DAP debug selection" },
      -- keymap reference
      "<leader>d?",
    },
    cmd = { "DapContinue", "DapToggleBreakpoint", "DapNew" },
    dependencies = {
      { "rcarriga/nvim-dap-ui", dependencies = { "nvim-neotest/nvim-nio" } },
      { "theHamsta/nvim-dap-virtual-text", opts = { enabled = true } },
      { "jay-babu/mason-nvim-dap.nvim", dependencies = { "mason-org/mason.nvim" } },
      { "mfussenegger/nvim-dap-python", ft = "python" },
      { "leoluz/nvim-dap-go", ft = "go" },
      {
        "nvim-telescope/telescope-dap.nvim",
        dependencies = { "nvim-telescope/telescope.nvim" },
        config = function()
          pcall(require("telescope").load_extension, "dap")
        end,
      },
    },
    config = function()
      require("ajay.dap")
    end,
  },

  -- ══════════════════════════════════════════════════════════════════
  -- HARPOON
  -- ══════════════════════════════════════════════════════════════════
  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>a", desc = "Harpoon add file" },
      { "<leader>he", desc = "Harpoon quick menu" },
      { "<leader>hh", desc = "Harpoon telescope" },
      -- Must match what harpoon.lua actually maps, or the lazy-load
      -- trigger never fires. It previously declared <A-1>..<A-5> while
      -- the module mapped <C-1>..<C-5>.
      -- The rest of what harpoon.lua maps. These were missing for the same
      -- reason the <A-n>/<C-n> mismatch below was: the list drifted from
      -- the module.
      { "<leader>hx", desc = "Harpoon remove file" },
      { "<leader>hc", desc = "Harpoon clear all" },
      { "<leader>hj", desc = "Harpoon next" },
      { "<leader>hk", desc = "Harpoon prev" },
      { "<leader>1", desc = "Harpoon slot 1" },
      { "<leader>2", desc = "Harpoon slot 2" },
      { "<leader>3", desc = "Harpoon slot 3" },
      { "<leader>4", desc = "Harpoon slot 4" },
      { "<leader>5", desc = "Harpoon slot 5" },
      { "<A-1>", desc = "Harpoon slot 1" },
      { "<A-2>", desc = "Harpoon slot 2" },
      { "<A-3>", desc = "Harpoon slot 3" },
      { "<A-4>", desc = "Harpoon slot 4" },
      { "<A-5>", desc = "Harpoon slot 5" },
    },
    config = function()
      setup_module("ajay.harpoon")
    end,
  },

  -- ══════════════════════════════════════════════════════════════════
  -- QUALITY OF LIFE
  -- ══════════════════════════════════════════════════════════════════
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      options = {
        icons_enabled = vim.g.have_nerd_font ~= false,
        -- Asked of colorscheme.lua so the theme name lives in one place.
        -- A wrong name here is not an error: lualine silently falls back to
        -- `auto` and warns "There are some issues with your config. Run
        -- :LualineNotices" once per launch.
        theme = (function()
          local ok, cs = pcall(require, "ajay.colorscheme")
          return ok and cs.lualine_theme() or "auto"
        end)(),
        globalstatus = true,
      },
    },
  },
  {
    "lukas-reineke/indent-blankline.nvim",
    event = { "BufReadPost", "BufNewFile" },
    main = "ibl",
    opts = {},
  },
  {
    "numToStr/Comment.nvim",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      setup_module("ajay.comment")
    end,
  },
  {
    "mbbill/undotree",
    cmd = { "UndotreeToggle", "UndotreeShow" },
    keys = {
      { "<leader>u", vim.cmd.UndotreeToggle, desc = "Toggle Undo Tree" },
    },
  },
  -- ── IntelliJ-STYLE PEEK / FIND USAGES ─────────────────────────────
  -- `vim.lsp.buf.references()` dumps into the quickfix list: a flat list
  -- of file:line with no preview and no way to see the surrounding code
  -- without leaving where you are. That is the gap against IntelliJ's
  -- Find Usages (Alt+F7) and Quick Definition (Ctrl+Shift+I).
  --
  -- glance gives a results list beside a live preview pane -- move down
  -- the list and the preview follows, press <CR> to jump, <Esc> to leave
  -- without moving at all.
  {
    "dnlhc/glance.nvim",
    cmd = "Glance",
    opts = {
      border = { enable = true, top_char = "─", bottom_char = "─" },
      list = { position = "right", width = 0.33 },
      -- Jump straight there when there is exactly one result and it is
      -- not the symbol under the cursor. Opening a whole preview UI to
      -- show a single destination is friction, not a feature.
      hooks = {
        before_open = function(results, open, jump, method)
          if #results == 1 and method ~= "references" then
            jump(results[1])
          else
            open(results)
          end
        end,
      },
    },
  },
}, {
  -- ══════════════════════════════════════════════════════════════════
  -- LAZY.NVIM OPTIONS
  -- ══════════════════════════════════════════════════════════════════
  install = { colorscheme = { "vscode", "habamax" } },
  checker = { enabled = false },
  change_detection = { notify = false },
  -- No luarocks bootstrap: nothing here needs it.
  rocks = { enabled = false, hererocks = false },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
        -- netrwPlugin stays enabled: it is the directory browser (`:Ex`).
        "rplugin",
      },
    },
  },
})
