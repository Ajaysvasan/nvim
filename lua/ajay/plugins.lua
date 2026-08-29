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

local notebook = vim.g.enable_notebook == true

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
          .. ("  tail -3 ~/.config/nvim/lua/%s.lua"):format(name:gsub("%%.", "/")),
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
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    config = function()
      require("ajay.colorscheme")
      -- Registers :ToggleTransparency and <leader>tt. Registration only --
      -- it does not change your appearance until you press the key.
      setup_module("ajay.transparency")
    end,
  },

  -- ══════════════════════════════════════════════════════════════════
  -- DASHBOARD
  -- ══════════════════════════════════════════════════════════════════
  {
    "goolord/alpha-nvim",
    event = "VimEnter",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      setup_module("ajay.dashboard")
    end,
  },

  -- ══════════════════════════════════════════════════════════════════
  -- FILE TREE
  -- ══════════════════════════════════════════════════════════════════
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    cmd = "Neotree",
    keys = {
      { "<C-n>", desc = "Toggle/Focus Neo-tree" },
    },
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    config = function()
      setup_module("ajay.neotree")
    end,
  },

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
      -- IntelliJ-style "New Java Class" GUI: <leader>jN / :JavaNew.
      -- Loaded here rather than eagerly -- it is ~1100 lines and only
      -- meaningful once you are in a Java project.
      setup_module("ajay.java-creator")
      -- Spring Boot commands live alongside Java. This is the wiring that
      -- was missing: the old init.lua did `require("ajay.springboot")`,
      -- which only returns the module table -- setup() was never called,
      -- so :SpringBootRun and <leader>sr never existed on either machine.
      setup_module("ajay.springboot")
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
  -- COPILOT
  -- ══════════════════════════════════════════════════════════════════
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    -- InsertEnter covers most of it, but these are normal-mode keys you may
    -- well press before typing anything in a session -- "is Copilot on?"
    -- being the obvious one.
    keys = {
      { "<leader>ct", desc = "Toggle Copilot" },
      { "<leader>cs", desc = "Copilot status" },
      { "<leader>cp", desc = "Copilot panel" },
    },
    config = function()
      setup_module("ajay.copilot")
    end,
  },
  {
    "zbirenbaum/copilot-cmp",
    dependencies = { "zbirenbaum/copilot.lua" },
    event = "InsertEnter",
    config = function()
      require("copilot_cmp").setup()
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
  },

  -- ══════════════════════════════════════════════════════════════════
  -- FORMATTING  (conform only — null-ls and autoformat.lua are gone)
  -- ══════════════════════════════════════════════════════════════════
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo", "Format" },
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
  {
    "kdheepak/lazygit.nvim",
    cmd = { "LazyGit", "LazyGitConfig", "LazyGitCurrentFile", "LazyGitFilter", "LazyGitFilterCurrentFile" },
    keys = {
      { "<leader>gg", desc = "Open LazyGit" },
      { "<leader>gf", desc = "LazyGit current file" },
      { "<leader>gC", desc = "LazyGit config" },
      { "<leader>gl", desc = "LazyGit filter" },
      { "<leader>gL", desc = "LazyGit filter current file" },
    },
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      setup_module("ajay.lazygit")
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
        theme = "catppuccin",
        globalstatus = true,
      },
    },
  },
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = true,
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
    dependencies = {
      -- Makes commenting respect the language UNDER THE CURSOR, not just
      -- the file's filetype. Required for JSX inside .tsx, <script> and
      -- <style> inside .vue/.svelte/.html, etc.
      {
        "JoosepAlviste/nvim-ts-context-commentstring",
        init = function()
          -- Skips the plugin's own autocmd; Comment.nvim's pre_hook calls
          -- it directly. Without this you pay for it twice.
          vim.g.skip_ts_context_commentstring_module = true
        end,
        opts = { enable_autocmd = false },
      },
    },
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
  {
    -- NOT a standalone expander. wrap_with_abbreviation sends an
    -- `emmet/expandAbbreviation` LSP request and silently returns if
    -- nothing answers, so this plugin is inert without
    -- emmet-language-server -- which lsp.lua now installs and enables.
    --
    -- The filetype list is emmet-language-server's own, minus the
    -- templating languages this config has no other support for. It used
    -- to omit htmlangular, scss and less, so the keymap did not even
    -- exist in three filetypes where the server does attach.
    "olrtg/nvim-emmet",
    ft = {
      "html",
      "htmlangular",
      "css",
      "scss",
      "less",
      "javascriptreact",
      "typescriptreact",
      "vue",
      "svelte",
    },
    config = function()
      vim.keymap.set({ "n", "v" }, "<leader>xe", require("nvim-emmet").wrap_with_abbreviation, {
        desc = "Emmet wrap with abbreviation",
      })
    end,
  },

  -- ══════════════════════════════════════════════════════════════════
  -- NOTEBOOK STACK  (opt-in via vim.g.enable_notebook)
  --
  -- image.nvim's `magick` dependency is a LuaRock. lazy.nvim bootstraps
  -- hererocks + luarocks to build it, and that build needs ImageMagick's
  -- C headers. On a fresh macOS box that build fails, and because these
  -- are non-lazy specs the failure blocks startup. Gated off by default.
  -- ══════════════════════════════════════════════════════════════════
  {
    "GCBallesteros/jupytext.nvim",
    enabled = notebook,
    lazy = false, -- must be loaded before a .ipynb is opened
    opts = {
      style = "percent",
      output_extension = "auto",
      force_ft = nil,
      custom_language_formatting = {},
    },
  },
  {
    "3rd/image.nvim",
    enabled = notebook,
    ft = { "markdown", "python", "ipynb" },
    build = false, -- do not let it try a rockspec build
    dependencies = { "leafo/magick" },
    opts = {
      backend = "kitty",
      integrations = {
        markdown = {
          enabled = true,
          clear_in_insert_mode = false,
          download_remote_images = true,
          only_render_image_at_cursor = false,
        },
      },
      max_width_window_percentage = nil,
      max_height_window_percentage = 50,
      kitty_method = "normal",
    },
  },
  {
    "benlubas/molten-nvim",
    enabled = notebook,
    version = "^1.0.0",
    build = ":UpdateRemotePlugins",
    ft = { "python", "ipynb", "markdown" },
    cmd = { "MoltenInit", "MoltenEvaluateLine", "MoltenEvaluateOperator" },
    init = function()
      vim.g.molten_image_provider = "image.nvim"
      vim.g.molten_output_win_max_height = 20
      vim.g.molten_auto_open_output = false
      vim.g.molten_wrap_output = true
      vim.g.molten_virt_text_output = true
    end,
    config = function()
      setup_module("ajay.jupyter")
    end,
  },
}, {
  -- ══════════════════════════════════════════════════════════════════
  -- LAZY.NVIM OPTIONS
  -- ══════════════════════════════════════════════════════════════════
  install = { colorscheme = { "catppuccin" } },
  checker = { enabled = false },
  change_detection = { notify = false },
  rocks = {
    -- Only bootstrap hererocks when the notebook stack is actually on.
    enabled = notebook,
    hererocks = notebook,
  },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
        "netrwPlugin",
        -- "rplugin" is appended below only when notebooks are OFF.
        -- molten-nvim is a Python remote plugin and needs the rplugin
        -- host, so disabling it would break :MoltenInit silently.
        unpack(notebook and {} or { "rplugin" }),
      },
    },
  },
})
