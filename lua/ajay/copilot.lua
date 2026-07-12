-- lua/ajay/copilot.lua

local M = {}

-- Persisted on/off state, stored outside the config repo so it survives
-- Neovim restarts and PC reboots.
local state_file = vim.fn.stdpath("data") .. "/copilot_enabled_state"

local function read_state()
	local f = io.open(state_file, "r")
	if not f then
		return true -- default: enabled
	end
	local content = f:read("*a")
	f:close()
	return content:gsub("%s+", "") ~= "disabled"
end

local function write_state(enabled)
	local f = io.open(state_file, "w")
	if f then
		f:write(enabled and "enabled" or "disabled")
		f:close()
	end
end

function M.setup()
	-- Check if copilot is available
	local copilot_ok, copilot = pcall(require, "copilot")
	if not copilot_ok then
		vim.notify("Copilot not installed", vim.log.levels.WARN)
		return
	end

	-- Setup GitHub Copilot
	copilot.setup({
		panel = {
			enabled = true,
			auto_refresh = true,
			keymap = {
				jump_prev = "[[",
				jump_next = "]]",
				accept = "<CR>",
				refresh = "gr",
				open = "<M-CR>", -- Alt+Enter
			},
			layout = {
				position = "bottom", -- | top | left | right
				ratio = 0.4,
			},
		},
		suggestion = {
			enabled = true,
			auto_trigger = true,
			debounce = 75,
			keymap = {
				accept = "<M-l>", -- Alt+l (like Tab in VS Code)
				accept_word = false,
				accept_line = false,
				next = "<M-]>", -- Alt+]
				prev = "<M-[>", -- Alt+[
				dismiss = "<C-]>", -- Ctrl+]
			},
		},
		filetypes = {
			yaml = false,
			markdown = false,
			help = false,
			gitcommit = false,
			gitrebase = false,
			hgcommit = false,
			svn = false,
			cvs = false,
			["."] = false,
		},
		copilot_node_command = "node", -- Node.js version must be > 18.x
		server_opts_overrides = {},
	})

	-- Setup Copilot CMP source (for nvim-cmp integration)
	local cmp_copilot_ok, copilot_cmp = pcall(require, "copilot_cmp")
	if cmp_copilot_ok then
		copilot_cmp.setup()
	end

	-- Apply the persisted state right after setup. Since copilot.setup()
	-- above always starts the client, if we're saved as "disabled" we tear
	-- it back down immediately so it comes up off, even on a fresh restart.
	if not read_state() then
		vim.cmd("Copilot disable")
	end

	-- Global toggle: uses `Copilot enable`/`Copilot disable` (whole client),
	-- NOT `Copilot toggle` (which only attaches/detaches the current buffer).
	-- Also writes the choice to disk so it persists across restarts/reboots.
	vim.api.nvim_create_user_command("CopilotToggle", function()
		local currently_enabled = read_state()
		if currently_enabled then
			vim.cmd("Copilot disable")
			write_state(false)
			vim.notify("Copilot disabled (globally, persisted)", vim.log.levels.INFO)
		else
			vim.cmd("Copilot enable")
			write_state(true)
			vim.notify("Copilot enabled (globally, persisted)", vim.log.levels.INFO)
		end
	end, { desc = "Toggle GitHub Copilot globally, persisted across restarts" })

	vim.api.nvim_create_user_command("CopilotStatus", function()
		vim.cmd("Copilot status")
	end, { desc = "Show Copilot status" })

	-- Keymaps
	vim.keymap.set("n", "<leader>ct", ":CopilotToggle<CR>", {
		desc = "Toggle Copilot (global, persisted)",
		silent = true,
	})

	vim.keymap.set("n", "<leader>cs", ":Copilot status<CR>", {
		desc = "Copilot status",
		silent = true,
	})

	vim.keymap.set("n", "<leader>cp", ":Copilot panel<CR>", {
		desc = "Copilot panel",
		silent = true,
	})

	vim.notify("✓ GitHub Copilot configured", vim.log.levels.INFO)
end

return M
