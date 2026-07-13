-- config/plugins.lua
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		lazypath,
	})
end

vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
	-- THEMES
	-- { "ellisonleao/gruvbox.nvim", priority = 1000 },
	{ "catppuccin/nvim", name = "catppuccin", priority = 1000 },
	-- {
	-- 	"Mofiqul/vscode.nvim",
	-- 	priority = 1000,
	-- },

	{
		"GCBallesteros/jupytext.nvim",
		config = function()
			require("jupytext").setup({
				style = "percent",
				output_extension = "auto",
				force_ft = nil,
				custom_language_formatting = {},
			})
		end,
	},
	{
		"benlubas/molten-nvim",
		version = "^1.0.0",
		build = ":UpdateRemotePlugins",
		enabled = true,
		init = function()
			vim.g.molten_image_provider = "image.nvim"
			vim.g.molten_output_win_max_height = 20
			vim.g.molten_auto_open_output = false
			vim.g.molten_wrap_output = true
			vim.g.molten_virt_text_output = true
		end,
		config = function()
			require("ajay.jupyter").setup()
		end,
	},
	-- DASHBOARD / STARTUP SCREEN
	{
		"goolord/alpha-nvim",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("ajay.dashboard").setup()
		end,
	},

	{
		"mbbill/undotree",
		config = function()
			vim.keymap.set("n", "<leader>u", vim.cmd.UndotreeToggle, { desc = "Toggle Undo Tree" })
		end,
	},
	{
		"3rd/image.nvim",
		enabled = true, -- Set to true if you want to use real images
		dependencies = {
			"leafo/magick",
		},
		config = function()
			require("image").setup({
				backend = "kitty",
				integrations = {
					markdown = {
						enabled = true,
						clear_in_insert_mode = false,
						download_remote_images = true,
						only_render_image_at_cursor = false,
					},
				},
				max_width = nil,
				max_height = nil,
				max_width_window_percentage = nil,
				max_height_window_percentage = 50,
				kitty_method = "normal",
			})
		end,
	},

	-- AUTOPAIRS
	{ "windwp/nvim-autopairs", config = true },

	-- FILE TREE
	{
		"nvim-neo-tree/neo-tree.nvim",
		branch = "v3.x",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-tree/nvim-web-devicons",
			"MunifTanjim/nui.nvim",
		},
	},

	-- LSP & MASON
	{
		"williamboman/mason.nvim",
		build = ":MasonUpdate",
	},
	{
		"williamboman/mason-lspconfig.nvim",
		dependencies = { "williamboman/mason.nvim" },
	},
	{
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		dependencies = { "williamboman/mason.nvim" },
	},
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			"williamboman/mason.nvim",
			"williamboman/mason-lspconfig.nvim",
		},
	},
	{
		"mfussenegger/nvim-jdtls",
		ft = "java",
		dependencies = { "mfussenegger/nvim-dap" },
		config = function()
			require("ajay.jdtls").setup()
		end,
	},
	-- COMPLETION
	{
		"hrsh7th/nvim-cmp",
		dependencies = {
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-buffer",
			"hrsh7th/cmp-path",
			"L3MON4D3/LuaSnip",
			"saadparwaiz1/cmp_luasnip",
			"rafamadriz/friendly-snippets",
		},
	},

	-- EMMET for HTML/JSX/TSX
	{
		"olrtg/nvim-emmet",
		config = function()
			vim.keymap.set({ "n", "v" }, "<leader>xe", require("nvim-emmet").wrap_with_abbreviation)
		end,
	},

	-- INDENT GUIDES
	{
		"lukas-reineke/indent-blankline.nvim",
		main = "ibl",
		opts = {},
	},

	-- RAINBOW DELIMITERS
	{
		"HiPhish/rainbow-delimiters.nvim",
	},

	-- STATUSLINE
	{ "nvim-lualine/lualine.nvim", config = true },

	-- TREESITTER
	{ "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },

	-- TELESCOPE
	{
		"nvim-telescope/telescope.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-telescope/telescope-fzf-native.nvim",
			{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
		},
		config = function()
			require("ajay.telescope").setup()
		end,
	},

	-- GIT
	{
		"lewis6991/gitsigns.nvim",
		config = function()
			require("ajay.gitsigns").setup()
		end,
	},
	{
		"kdheepak/lazygit.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
		},
		config = function()
			require("ajay.lazygit").setup()
		end,
	},

	-- QUALITY OF LIFE
	{
		"numToStr/Comment.nvim",
		config = function()
			require("ajay.comment").setup()
		end,
	},

	-- AI COPILOT (GitHub Copilot)
	{
		"zbirenbaum/copilot.lua",
		cmd = "Copilot",
		event = "InsertEnter",
		config = function()
			require("ajay.copilot").setup()
		end,
	},
	{
		"zbirenbaum/copilot-cmp",
		dependencies = { "zbirenbaum/copilot.lua" },
		config = function()
			require("copilot_cmp").setup()
		end,
	},

	-- FORMATTING (Better than built-in)
	{
		"stevearc/conform.nvim",
		event = { "BufWritePre" },
		cmd = { "ConformInfo" },
		config = function()
			require("ajay.conform").setup()
		end,
	},

	-- DEBUGGER (DAP)
	{
		"mfussenegger/nvim-dap",
		dependencies = {
			"rcarriga/nvim-dap-ui",
			"nvim-neotest/nvim-nio",
			"theHamsta/nvim-dap-virtual-text",
			"jay-babu/mason-nvim-dap.nvim",
		},
		config = function()
			require("ajay.dap").setup()
		end,
	},
	{
		"rcarriga/nvim-dap-ui",
		dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
	},
	{
		"theHamsta/nvim-dap-virtual-text",
		dependencies = { "mfussenegger/nvim-dap" },
	},
	{
		"jay-babu/mason-nvim-dap.nvim",
		dependencies = { "williamboman/mason.nvim", "mfussenegger/nvim-dap" },
	},
	{
		-- ── Core plugin ─────────────────────────────────────────────────────────────
		"yetone/avante.nvim",

		-- Load on demand — opens instantly on first keymap hit
		event = "VeryLazy",
		lazy = false,

		-- IMPORTANT: never pin to a semver tag — avante moves fast and tags break
		version = false,

		-- Build the native Rust tokenizer (required)
		build = "make",

		-- ── Dependencies ────────────────────────────────────────────────────────────
		dependencies = {
			"nvim-treesitter/nvim-treesitter", -- already in your config
			"stevearc/dressing.nvim", -- polished input/select UI
			"nvim-lua/plenary.nvim", -- already in your config
			"MunifTanjim/nui.nvim", -- UI components

			-- Pretty markdown rendering inside Avante side panels
			{
				"MeanderingProgrammer/render-markdown.nvim",
				opts = {
					file_types = { "markdown", "Avante" },
				},
				ft = { "markdown", "Avante" },
			},

			-- Image paste support — lets you paste screenshots into the chat
			-- Gemini is multimodal, so this pairs perfectly
			{
				"HakonHarnes/img-clip.nvim",
				event = "VeryLazy",
				opts = {
					default = {
						embed_image_as_base64 = false,
						prompt_for_file_name = false,
						drag_and_drop = {
							insert_mode = true,
						},
						-- Required for Avante image pasting on Linux
						use_absolute_path = true,
					},
				},
			},
		},

		-- ── Main opts ───────────────────────────────────────────────────────────────
		opts = {

			-- ── Provider selection ────────────────────────────────────────────────────
			provider = "gemini",

			-- ── Gemini provider config ────────────────────────────────────────────────
			providers = {
				gemini = {
					-- Official v1beta endpoint — DO NOT change unless Google updates it
					endpoint = "https://generativelanguage.googleapis.com/v1beta/models",

					-- Model to use. Options (pick one and uncomment):
					--   "gemini-2.5-pro"        ← best reasoning, slower, higher quota use
					--   "gemini-2.5-flash"      ← fast + smart, great daily driver  ✓
					--   "gemini-2.0-flash"      ← stable, lower latency
					--   "gemini-1.5-pro"        ← 2M context window, good for large codebases
					model = "gemini-2.5-flash",

					-- Request timeout in ms — generous for long generations
					timeout = 60000,

					-- Context window — gemini-2.5-flash supports 1M tokens
					-- Avante uses this to decide how much code context to send
					context_window = 1048576,

					-- Avante reads AVANTE_GEMINI_API_KEY first, then falls back to GEMINI_API_KEY
					-- Both work; scoped key is safer if you have multiple tools using Gemini
					api_key_name = "GEMINI_API_KEY",

					-- Fine-grained generation parameters
					extra_request_body = {
						generationConfig = {
							-- 0.0 = deterministic/precise, 1.0 = creative
							-- 0.3 is good for code: focused but not rigid
							temperature = 0.3,

							-- Nucleus sampling — keep at 0.95 for code tasks
							topP = 0.95,

							-- Hard cap on output tokens per response
							-- Increase if Avante truncates long generations
							maxOutputTokens = 8192,

							-- Candidate count must stay 1 for streaming to work
							candidateCount = 1,
						},

						-- Safety thresholds — relaxed so security research / exploit PoC
						-- code in your kernel / low-level work doesn't get blocked
						-- BLOCK_NONE = never block | BLOCK_ONLY_HIGH = block obvious misuse
						safetySettings = {
							{
								category = "HARM_CATEGORY_HARASSMENT",
								threshold = "BLOCK_ONLY_HIGH",
							},
							{
								category = "HARM_CATEGORY_HATE_SPEECH",
								threshold = "BLOCK_ONLY_HIGH",
							},
							{
								category = "HARM_CATEGORY_SEXUALLY_EXPLICIT",
								threshold = "BLOCK_ONLY_HIGH",
							},
							{
								category = "HARM_CATEGORY_DANGEROUS_CONTENT",
								threshold = "BLOCK_ONLY_HIGH",
							},
						},
					},
				},
			},

			-- ── Behaviour ─────────────────────────────────────────────────────────────
			behaviour = {
				-- Auto-suggestions in the buffer (like Copilot ghost text)
				-- Disable if you already use copilot.lua for inline completions
				-- to avoid two ghost-text providers fighting each other
				auto_suggestions = false,

				-- When true, Avante auto-applies single-hunk diffs without prompting
				auto_apply_diff_after_generation = false,

				-- Jump to the result panel after generating
				auto_set_keymaps = true,

				-- Highlight the code block cursor is on when opening Avante
				auto_set_highlight_group = true,

				-- Support for Copilot as a suggestion source (you have copilot configured)
				support_paste_from_clipboard = false,

				-- Minimise API calls: don't re-send context if window already open
				minimize_diff = true,
			},

			-- ── UI ────────────────────────────────────────────────────────────────────
			windows = {
				-- Position of the Avante panel: "right" | "left" | "top" | "bottom"
				position = "right",

				-- Panel width as % of total editor width
				width = 35,

				-- Sidebar with conversation history
				sidebar_header = {
					enabled = true,
					align = "center",
					rounded = true,
				},

				-- Input prompt area at the bottom of the Avante panel
				input = {
					prefix = "❯ ",
					height = 8,
				},

				edit = {
					border = "rounded",
					start_insert = true,
				},

				ask = {
					floating = false, -- true = ask in a popup; false = in the sidebar
					start_insert = true,
					border = "rounded",
					focus_on_apply = "ours",
				},
			},

			-- ── Highlights ────────────────────────────────────────────────────────────
			-- Integrate with your current colorscheme (gruvbox/catppuccin etc.)
			-- Set to nil to let Avante pick defaults
			highlights = {
				diff = {
					current = "DiffText",
					incoming = "DiffAdd",
				},
			},

			-- ── Diff display ──────────────────────────────────────────────────────────
			diff = {
				autojump = true,
				list_opener = "copen",
				-- "ours" = keep your code | "theirs" = accept AI suggestion
				override_timeoutlen = 500,
			},

			-- ── Hints ─────────────────────────────────────────────────────────────────
			hints = {
				-- Show keybinding hints inside Avante panels
				enabled = true,
			},

			-- ── Repo-map (code indexing for context-aware completions) ─────────────────
			-- Avante can index your entire repo to give Gemini broader context
			-- Very useful for large Spring Boot / TS monorepo projects
			repo_map = {
				ignore_patterns = {
					"%.git",
					"%.worktree",
					"__pycache__",
					"node_modules",
					"target", -- Java/Maven build output
					"build",
					"dist",
					"%.class",
					"%.jar",
					"%.lock",
					"lazy-lock.json",
				},
			},

			-- ── System prompt override ────────────────────────────────────────────────
			-- Tailor the system prompt to your polyglot workflow.
			-- Avante prepends this to every conversation.
			system_prompt = [[
You are an expert software engineer with deep knowledge across:
- Java (Spring Boot, JPA, Maven/Gradle, microservices)
- Python (FastAPI, Django, ML/AI: PyTorch, NumPy, Pandas)
- TypeScript / JavaScript (React, Next.js, Node.js, Express)
- C / C++ (Linux kernel development, systems programming, POSIX APIs, memory management)
- Lua (Neovim plugin development and configuration)
- Shell scripting (Bash, fish)

When helping with code:
1. Prefer idiomatic patterns for the language/framework in use.
2. For C/C++ and kernel work, always consider memory safety, alignment, and undefined behaviour.
3. For Java/Spring Boot, follow layered architecture (Controller → Service → Repository).
4. For TypeScript, use strict types — avoid `any`.
5. For Python AI/ML code, prefer vectorised operations and mention complexity.
6. Always explain non-obvious decisions in a brief inline comment.
7. When refactoring, preserve existing behaviour unless explicitly asked to change it.
8. Output only the code that changes, not the entire file, unless asked.
]],
		},

		-- ── Keymaps (set in config, not opts, so they fire after setup) ─────────────
		config = function(_, opts)
			require("avante").setup(opts)

			-- You can customise these — they mirror your existing leader-based style
			-- <leader>a  → Avante namespace (consistent with your other <leader> maps)

			local map = vim.keymap.set
			local silent = { silent = true, noremap = true }

			-- Open / toggle the Avante sidebar
			map(
				"n",
				"<leader>aa",
				"<cmd>AvanteToggle<CR>",
				vim.tbl_extend("force", silent, { desc = "Avante: Toggle sidebar" })
			)

			-- Ask about selected code (Visual mode)
			map(
				"v",
				"<leader>aa",
				"<cmd>AvanteAsk<CR>",
				vim.tbl_extend("force", silent, { desc = "Avante: Ask about selection" })
			)

			-- Ask a free-form question without selection
			map(
				"n",
				"<leader>aq",
				"<cmd>AvanteAsk<CR>",
				vim.tbl_extend("force", silent, { desc = "Avante: Ask question" })
			)

			-- Explain the code under cursor / selection
			map(
				{ "n", "v" },
				"<leader>ae",
				"<cmd>AvanteEdit<CR>",
				vim.tbl_extend("force", silent, { desc = "Avante: Edit / explain" })
			)

			-- Refresh / re-generate the last response
			map(
				"n",
				"<leader>ar",
				"<cmd>AvanteRefresh<CR>",
				vim.tbl_extend("force", silent, { desc = "Avante: Refresh response" })
			)

			-- Clear chat history and start fresh
			map(
				"n",
				"<leader>ac",
				"<cmd>AvanteClear<CR>",
				vim.tbl_extend("force", silent, { desc = "Avante: Clear chat" })
			)

			-- Cycle through available models on the fly
			map(
				"n",
				"<leader>am",
				"<cmd>AvanteModels<CR>",
				vim.tbl_extend("force", silent, { desc = "Avante: Switch model" })
			)

			-- Switch provider (e.g. switch to Copilot temporarily)
			map(
				"n",
				"<leader>ap",
				"<cmd>AvanteSwitchProvider<CR>",
				vim.tbl_extend("force", silent, { desc = "Avante: Switch provider" })
			)

			-- Quick-focus back to the editor from the Avante panel
			map(
				"n",
				"<leader>af",
				"<cmd>AvanteToggle<CR>",
				vim.tbl_extend("force", silent, { desc = "Avante: Focus toggle" })
			)
		end,
	},
	-- =============================================================================
	-- ADD THESE ENTRIES TO YOUR lua/ajay/plugins.lua (inside your lazy.nvim spec table)
	-- =============================================================================

	-- ── Core DAP ──────────────────────────────────────────────────────────────────
	{
		"mfussenegger/nvim-dap",
		lazy = true, -- loaded on first debug keymap
		dependencies = {

			-- ── UI overlay (VS Code-style panels) ─────────────────────────────────────
			{
				"rcarriga/nvim-dap-ui",
				dependencies = { "nvim-neotest/nvim-nio" },
			},

			-- ── Inline variable values next to code ───────────────────────────────────
			{
				"theHamsta/nvim-dap-virtual-text",
				opts = { enabled = true },
			},

			-- ── Mason adapter auto-installer ──────────────────────────────────────────
			{
				"jay-babu/mason-nvim-dap.nvim",
				dependencies = { "mason-org/mason.nvim" },
			},

			-- ── Language-specific extensions ──────────────────────────────────────────

			-- Python: auto-detects venv, pytest test runner support
			{
				"mfussenegger/nvim-dap-python",
				ft = "python",
			},

			-- Go: wraps delve, debug individual tests from cursor
			{
				"leoluz/nvim-dap-go",
				ft = "go",
			},

			-- Telescope integration: search breakpoints, frames, etc.
			{
				"nvim-telescope/telescope-dap.nvim",
				dependencies = { "nvim-telescope/telescope.nvim" },
				config = function()
					require("telescope").load_extension("dap")
				end,
			},
		},
		-- The actual config lives in lua/ajay/dap.lua (required from init.lua)
		config = function()
			require("ajay.dap")
		end,
	},

	-- HARPOON
	{
		"ThePrimeagen/harpoon",
		branch = "harpoon2",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			local harpoon = require("harpoon")
			harpoon:setup({
				settings = {
					save_on_toggle = false,
					sync_on_ui_close = true,
					key = function()
						return vim.loop.cwd()
					end,
				},
			})

			vim.keymap.set("n", "<leader>a", function()
				local current_file = vim.fn.expand("%:p")
				if current_file == "" then
					vim.notify("No file to add", vim.log.levels.WARN)
					return
				end
				harpoon:list():append()
				vim.notify("Added to Harpoon: " .. vim.fn.expand("%:t"), vim.log.levels.INFO)
			end, { desc = "Harpoon Add File" })

			vim.keymap.set("n", "<leader>dr", function()
				harpoon:list():remove()
				vim.notify("Removed from Harpoon", vim.log.levels.INFO)
			end, { desc = "Harpoon Remove File" })

			vim.keymap.set("n", "<leader>dc", function()
				harpoon:list():clear()
				vim.notify("Cleared Harpoon list", vim.log.levels.INFO)
			end, { desc = "Harpoon Clear All" })

			vim.keymap.set("n", "<leader>hh", function()
				local conf = require("telescope.config").values
				local file_paths = {}
				for _, item in ipairs(harpoon:list().items) do
					table.insert(file_paths, item.value)
				end

				require("telescope.pickers")
					.new({}, {
						prompt_title = "Harpoon",
						finder = require("telescope.finders").new_table({
							results = file_paths,
						}),
						previewer = conf.file_previewer({}),
						sorter = conf.generic_sorter({}),
					})
					:find()
			end, { desc = "Harpoon Telescope" })

			vim.keymap.set("n", "<leader>he", function()
				harpoon.ui:toggle_quick_menu(harpoon:list())
			end, { desc = "Harpoon Quick Menu" })

			vim.keymap.set("n", "<leader>hn", function()
				harpoon:list():next()
			end, { desc = "Harpoon Next" })

			vim.keymap.set("n", "<leader>hp", function()
				harpoon:list():prev()
			end, { desc = "Harpoon Prev" })

			vim.keymap.set("n", "<A-1>", function()
				harpoon:list():select(1)
			end, { desc = "Harpoon Select 1" })

			vim.keymap.set("n", "<A-2>", function()
				harpoon:list():select(2)
			end, { desc = "Harpoon Select 2" })

			vim.keymap.set("n", "<A-3>", function()
				harpoon:list():select(3)
			end, { desc = "Harpoon Select 3" })

			vim.keymap.set("n", "<A-4>", function()
				harpoon:list():select(4)
			end, { desc = "Harpoon Select 4" })

			vim.keymap.set("n", "<A-5>", function()
				harpoon:list():select(5)
			end, { desc = "Harpoon Select 5" })
		end,
	},
})
