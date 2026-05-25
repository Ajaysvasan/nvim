-- =============================================================================
-- lua/ajay/avante.lua
-- Avante.nvim — Gemini API configuration
-- Drop this file in: ~/.config/nvim/lua/ajay/avante.lua
-- Then add  require("ajay.avante")  to your init.lua
-- =============================================================================
--
-- SETUP (one-time)
-- ─────────────────
--  1. Get your API key → https://aistudio.google.com/app/apikey
--
--  2. Export it in your shell rc (~/.bashrc / ~/.zshrc):
--       export GEMINI_API_KEY="your-key-here"
--
--     Or use the scoped variant (avoids conflicts with other tools):
--       export AVANTE_GEMINI_API_KEY="your-key-here"
--
--  3. Avante needs a native build step. lazy.nvim handles it via `build`,
--     but you can also run manually from the plugin directory:
--       :AvanteBuild        (inside neovim)
--       OR  make            (in the plugin dir)
--
--  4. Required system deps (install once):
--       sudo apt install curl git make gcc   # Debian/Ubuntu
--       brew install curl git make gcc       # macOS
--
-- OPTIONAL BUT RECOMMENDED
-- ─────────────────────────
--  • render-markdown.nvim  → pretty markdown rendering inside Avante panels
--  • img-clip.nvim         → paste images directly into the chat (multimodal!)
--  • copilot.lua           → already in your config; avante can use it too
--
-- =============================================================================

return {
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
		map("n", "<leader>aq", "<cmd>AvanteAsk<CR>", vim.tbl_extend("force", silent, { desc = "Avante: Ask question" }))

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
		map("n", "<leader>ac", "<cmd>AvanteClear<CR>", vim.tbl_extend("force", silent, { desc = "Avante: Clear chat" }))

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
}
