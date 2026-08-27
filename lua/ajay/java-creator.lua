-- java-creator.lua
-- IntelliJ-style Java file creation with floating GUI
-- Flow: pick directory -> pick type -> name it -> create
-- Drop in: lua/ajay/java-creator.lua
-- Require in init.lua: require("ajay.java-creator")

local M = {}

-- ─────────────────────────────────────────────────────────────
--  TEMPLATES
-- ─────────────────────────────────────────────────────────────

local templates = {
	Class = function(pkg, name)
		return string.format(
			[[package %s;

public class %s {

    public %s() {
    }
}
]],
			pkg,
			name,
			name
		)
	end,

	Interface = function(pkg, name)
		return string.format(
			[[package %s;

public interface %s {

}
]],
			pkg,
			name
		)
	end,

	Enum = function(pkg, name)
		return string.format(
			[[package %s;

public enum %s {

    ;

    %s() {
    }
}
]],
			pkg,
			name,
			name
		)
	end,

	["Abstract Class"] = function(pkg, name)
		return string.format(
			[[package %s;

public abstract class %s {

    public %s() {
    }
}
]],
			pkg,
			name,
			name
		)
	end,

	["Record"] = function(pkg, name)
		return string.format(
			[[package %s;

public record %s() {

}
]],
			pkg,
			name
		)
	end,

	Annotation = function(pkg, name)
		return string.format(
			[[package %s;

import java.lang.annotation.*;

@Retention(RetentionPolicy.RUNTIME)
@Target(ElementType.TYPE)
public @interface %s {

}
]],
			pkg,
			name
		)
	end,

	["Spring @Service"] = function(pkg, name)
		return string.format(
			[[package %s;

import org.springframework.stereotype.Service;

@Service
public class %s {

    public %s() {
    }
}
]],
			pkg,
			name,
			name
		)
	end,

	["Spring @Repository"] = function(pkg, name)
		return string.format(
			[[package %s;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface %s extends JpaRepository<Object, Long> {

}
]],
			pkg,
			name
		)
	end,

	["Spring @Controller"] = function(pkg, name)
		return string.format(
			[[package %s;

import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestMapping;

@Controller
@RequestMapping("/%s")
public class %s {

    public %s() {
    }
}
]],
			pkg,
			name:lower(),
			name,
			name
		)
	end,

	["Spring @RestController"] = function(pkg, name)
		return string.format(
			[[package %s;

import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/%s")
public class %s {

    public %s() {
    }
}
]],
			pkg,
			name:lower():gsub("controller", ""),
			name,
			name
		)
	end,

	["Spring @Component"] = function(pkg, name)
		return string.format(
			[[package %s;

import org.springframework.stereotype.Component;

@Component
public class %s {

    public %s() {
    }
}
]],
			pkg,
			name,
			name
		)
	end,

	["Spring @Configuration"] = function(pkg, name)
		return string.format(
			[[package %s;

import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Bean;

@Configuration
public class %s {

}
]],
			pkg,
			name
		)
	end,

	["JPA @Entity"] = function(pkg, name)
		return string.format(
			[[package %s;

import jakarta.persistence.*;

@Entity
@Table(name = "%s")
public class %s {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    public %s() {
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }
}
]],
			pkg,
			name:lower(),
			name,
			name
		)
	end,

	["DTO / Record"] = function(pkg, name)
		return string.format(
			[[package %s;

public record %s(
    // Add fields here
) {

}
]],
			pkg,
			name
		)
	end,

	["Exception"] = function(pkg, name)
		return string.format(
			[[package %s;

public class %s extends RuntimeException {

    public %s(String message) {
        super(message);
    }

    public %s(String message, Throwable cause) {
        super(message, cause);
    }
}
]],
			pkg,
			name,
			name,
			name
		)
	end,

	["Test (JUnit 5)"] = function(pkg, name)
		return string.format(
			[[package %s;

import org.junit.jupiter.api.*;
import static org.junit.jupiter.api.Assertions.*;

class %s {

    @BeforeEach
    void setUp() {
    }

    @Test
    void testExample() {
        // TODO: implement test
    }
}
]],
			pkg,
			name
		)
	end,
}

local TEMPLATE_KEYS = {
	"Class",
	"Interface",
	"Enum",
	"Abstract Class",
	"Record",
	"Annotation",
	"Spring @Service",
	"Spring @Repository",
	"Spring @RestController",
	"Spring @Controller",
	"Spring @Component",
	"Spring @Configuration",
	"JPA @Entity",
	"DTO / Record",
	"Exception",
	"Test (JUnit 5)",
}

-- ─────────────────────────────────────────────────────────────
--  HELPERS
-- ─────────────────────────────────────────────────────────────

local function infer_package(dir)
	local markers = { "src/main/java", "src/test/java" }
	for _, marker in ipairs(markers) do
		local idx = dir:find(marker, 1, true)
		if idx then
			local after = dir:sub(idx + #marker + 1)
			return (after:gsub("/", "."):gsub("^%.", ""):gsub("%.$", ""))
		end
	end
	local parts = {}
	for seg in dir:gmatch("[^/]+") do
		table.insert(parts, seg)
	end
	if #parts >= 2 then
		return parts[#parts - 1] .. "." .. parts[#parts]
	end
	return "com.example"
end

--- Best-effort starting directory: neo-tree node, else current buffer dir, else cwd.
--- Wrapped entirely in pcall so a neo-tree API mismatch can NEVER abort the GUI.
local function get_initial_dir()
	local ok, dir = pcall(function()
		local manager_ok, manager = pcall(require, "neo-tree.sources.manager")
		if manager_ok then
			local nt_state = manager.get_state("filesystem")
			if nt_state and nt_state.tree then
				local node = nt_state.tree:get_node()
				if node then
					local path = node.path or (node.get_id and node:get_id())
					if path then
						local stat = vim.loop.fs_stat(path)
						if stat then
							return stat.type == "directory" and path or vim.fn.fnamemodify(path, ":h")
						end
					end
				end
			end
		end
		local buf_path = vim.api.nvim_buf_get_name(0)
		if buf_path ~= "" then
			local stat = vim.loop.fs_stat(buf_path)
			if stat and stat.type == "file" then
				return vim.fn.fnamemodify(buf_path, ":h")
			end
		end
		return vim.fn.getcwd()
	end)
	if ok and dir and dir ~= "" then
		return dir
	end
	return vim.fn.getcwd()
end

--- List subdirectories of `dir` (sorted, dotfiles excluded except "..").
--- Returns entries, and a second value indicating whether the scan itself
--- failed (e.g. permission denied) so callers can show a real error
--- instead of silently presenting "no subdirectories".
local function list_subdirs(dir)
	local entries = {}
	local fd = vim.loop.fs_scandir(dir)
	if not fd then
		return entries, true -- scan_failed = true
	end
	while true do
		local name, ftype = vim.loop.fs_scandir_next(fd)
		if not name then
			break
		end
		if ftype == "directory" and not name:match("^%.") then
			table.insert(entries, name)
		end
	end
	table.sort(entries, function(a, b)
		return a:lower() < b:lower()
	end)
	return entries, false
end

local function path_join(a, b)
	if a:sub(-1) == "/" then
		return a .. b
	end
	return a .. "/" .. b
end

local function path_parent(dir)
	local trimmed = dir:gsub("/+$", "")
	local parent = vim.fn.fnamemodify(trimmed, ":h")
	if parent == "" then
		return "/"
	end
	return parent
end

-- ─────────────────────────────────────────────────────────────
--  SHARED FLOAT UTILITIES
-- ─────────────────────────────────────────────────────────────

local function create_buf(lines, modifiable)
	local buf = vim.api.nvim_create_buf(false, true)
	if lines then
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	end
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
	vim.api.nvim_set_option_value("modifiable", modifiable or false, { buf = buf })
	return buf
end

local function open_float(buf, opts)
	local ok, win = pcall(vim.api.nvim_open_win, buf, false, opts)
	if not ok then
		vim.notify("java-creator: failed to open float: " .. tostring(win), vim.log.levels.ERROR)
		return nil
	end
	pcall(vim.api.nvim_set_option_value, "winhl", "Normal:NormalFloat,FloatBorder:FloatBorder", { win = win })
	pcall(vim.api.nvim_set_option_value, "number", false, { win = win })
	pcall(vim.api.nvim_set_option_value, "signcolumn", "no", { win = win })
	return win
end

local function safe_highlight(buf, hl, line, col_start, col_end)
	if not (buf and vim.api.nvim_buf_is_valid(buf)) then
		return
	end
	local count = vim.api.nvim_buf_line_count(buf)
	if line < 0 or line >= count then
		return
	end
	pcall(vim.api.nvim_buf_add_highlight, buf, -1, hl, line, col_start, col_end)
end

local function map(buf, mode, lhs, fn)
	pcall(vim.keymap.set, mode, lhs, fn, { buffer = buf, silent = true, nowait = true })
end

local function screen_dims()
	local ui = vim.api.nvim_list_uis()[1]
	if ui then
		return ui.width, ui.height
	end
	return vim.o.columns, vim.o.lines
end

-- ═════════════════════════════════════════════════════════════
--  STATE (single shared table for both stages)
-- ═════════════════════════════════════════════════════════════

local state = {
	-- directory picker
	dir_win = nil,
	dir_buf = nil,
	path_win = nil,
	path_buf = nil,
	help_win = nil,
	help_buf = nil,
	current_dir = nil,
	entries = {},
	scan_failed = false,
	selected_entry = 1,

	-- type/name picker
	main_win = nil,
	main_buf = nil,
	type_win = nil,
	type_buf = nil,
	name_win = nil,
	name_buf = nil,
	pkg_win = nil,
	pkg_buf = nil,
	info_win = nil,
	selected_type = 1,
	package = "",
	target_dir = "",

	owned_wins = {},
	stage = nil, -- "dir" | "type"
	original_win = nil,
}

local function close_all(on_complete)
	-- Set stage to nil immediately to prevent any re-entrant autocmd calls.
	state.stage = nil
	-- Always leave insert mode first. If we close our floats while the
	-- editor is still in insert mode (e.g. a scheduled callback closes
	-- mid-edit), Neovim keeps "-- INSERT --" active against whatever
	-- buffer/window becomes current next, which feels like a stuck UI.
	pcall(vim.cmd, "stopinsert")
	vim.schedule(function()
		pcall(vim.api.nvim_del_augroup_by_name, "JavaCreatorClose")
		state.owned_wins = {}
		local wins = {
			state.dir_win,
			state.path_win,
			state.help_win,
			state.main_win,
			state.type_win,
			state.name_win,
			state.pkg_win,
			state.info_win,
		}
		for _, w in ipairs(wins) do
			if w and vim.api.nvim_win_is_valid(w) then
				pcall(vim.api.nvim_win_close, w, true)
			end
		end
		state.dir_win, state.path_win, state.help_win = nil, nil, nil
		state.main_win, state.type_win, state.name_win, state.pkg_win, state.info_win = nil, nil, nil, nil, nil

		if state.original_win and vim.api.nvim_win_is_valid(state.original_win) then
			pcall(vim.api.nvim_set_current_win, state.original_win)
		end

		if type(on_complete) == "function" then
			vim.schedule(on_complete)
		end
	end)
end

-- ═════════════════════════════════════════════════════════════
--  STAGE 1 — DIRECTORY PICKER
-- ═════════════════════════════════════════════════════════════

local function render_dir_list()
	if not (state.dir_buf and vim.api.nvim_buf_is_valid(state.dir_buf)) then
		return
	end
	vim.api.nvim_set_option_value("modifiable", true, { buf = state.dir_buf })

	-- Build every line fresh from source data (name + selection state).
	-- Never re-parse a previously rendered line: the "▸ " marker is a
	-- multi-byte UTF-8 glyph, so byte-slicing a line that already has it
	-- (the old approach) corrupts subsequent renders.
	local raw_labels = { "..  (up a level)" }
	for _, name in ipairs(state.entries) do
		table.insert(raw_labels, name .. "/")
	end
	if state.scan_failed then
		table.insert(raw_labels, "⚠  cannot read this directory (permission denied?)")
	elseif #state.entries == 0 then
		table.insert(raw_labels, "(no subdirectories)")
	end

	local lines = {}
	for i, label in ipairs(raw_labels) do
		lines[i] = (i == state.selected_entry and "▸ " or "  ") .. label
	end
	vim.api.nvim_buf_set_lines(state.dir_buf, 0, -1, false, lines)

	vim.api.nvim_set_option_value("modifiable", false, { buf = state.dir_buf })

	if state.dir_win and vim.api.nvim_win_is_valid(state.dir_win) then
		pcall(vim.api.nvim_win_set_cursor, state.dir_win, { state.selected_entry, 0 })
	end

	-- update path bar
	if state.path_buf and vim.api.nvim_buf_is_valid(state.path_buf) then
		vim.api.nvim_set_option_value("modifiable", true, { buf = state.path_buf })
		vim.api.nvim_buf_set_lines(state.path_buf, 0, -1, false, { " " .. state.current_dir })
		vim.api.nvim_set_option_value("modifiable", false, { buf = state.path_buf })
	end
end

local function dir_refresh(new_dir)
	state.current_dir = new_dir
	state.entries, state.scan_failed = list_subdirs(new_dir)
	state.selected_entry = 1
	render_dir_list()
end

-- forward declarations (must stay `local` and be ASSIGNED later with
-- `open_type_stage = function(...)`, never `function open_type_stage(...)`,
-- or Lua creates a brand-new global and this upvalue stays nil forever)
local open_type_stage
local open_dir_stage

local function dir_navigate(delta)
	local max = #state.entries + 1 -- +1 for ".."
	state.selected_entry = math.max(1, math.min(max, state.selected_entry + delta))
	render_dir_list()
end

local function dir_enter()
	if state.selected_entry == 1 then
		dir_refresh(path_parent(state.current_dir))
	else
		local name = state.entries[state.selected_entry - 1]
		if name then
			dir_refresh(path_join(state.current_dir, name))
		end
	end
end

local function dir_confirm_here()
	if state.scan_failed then
		vim.notify("⚠  Can't use this directory — it isn't readable (permission denied?)", vim.log.levels.WARN)
		return
	end
	local chosen = state.current_dir
	close_all(function()
		open_type_stage(chosen)
	end)
end

open_dir_stage = function(start_dir)
	state.stage = "dir"

	local screen_w, screen_h = screen_dims()
	local w, h = 64, 22
	local row = math.floor((screen_h - h) / 2)
	local col = math.floor((screen_w - w) / 2)

	-- path bar
	state.path_buf = create_buf({ " " .. start_dir }, false)
	state.path_win = open_float(state.path_buf, {
		relative = "editor",
		row = row,
		col = col,
		width = w,
		height = 1,
		style = "minimal",
		border = "rounded",
		title = " Current Directory ",
		title_pos = "center",
		focusable = false,
		zindex = 60,
	})
	safe_highlight(state.path_buf, "Directory", 0, 0, -1)

	-- directory list
	local list_h = h - 4
	state.dir_buf = create_buf({}, false)
	state.dir_win = open_float(state.dir_buf, {
		relative = "editor",
		row = row + 2,
		col = col,
		width = w,
		height = list_h,
		style = "minimal",
		border = "single",
		title = " Browse (Enter=open, l=select here) ",
		title_pos = "center",
		focusable = true,
		zindex = 60,
	})
	if state.dir_win then
		pcall(vim.api.nvim_set_option_value, "cursorline", true, { win = state.dir_win })
	end

	-- help bar
	state.help_buf = create_buf({
		" j/k move   Enter open dir   l/<S-CR> select this dir   Esc close",
	}, false)
	state.help_win = open_float(state.help_buf, {
		relative = "editor",
		row = row + 2 + list_h,
		col = col,
		width = w,
		height = 1,
		style = "minimal",
		border = "single",
		title = "",
		focusable = false,
		zindex = 60,
	})
	safe_highlight(state.help_buf, "Comment", 0, 0, -1)

	state.owned_wins = {
		[state.path_win] = true,
		[state.dir_win] = true,
		[state.help_win] = true,
	}

	if state.dir_win then
		vim.api.nvim_set_current_win(state.dir_win)
	end

	dir_refresh(start_dir)

	if state.dir_buf then
		map(state.dir_buf, "n", "j", function()
			dir_navigate(1)
		end)
		map(state.dir_buf, "n", "k", function()
			dir_navigate(-1)
		end)
		map(state.dir_buf, "n", "<Down>", function()
			dir_navigate(1)
		end)
		map(state.dir_buf, "n", "<Up>", function()
			dir_navigate(-1)
		end)
		map(state.dir_buf, "n", "<CR>", dir_enter)
		map(state.dir_buf, "n", "l", dir_confirm_here)
		map(state.dir_buf, "n", "<S-CR>", dir_confirm_here)
		map(state.dir_buf, "n", "h", function()
			dir_refresh(path_parent(state.current_dir))
		end)
		map(state.dir_buf, "n", "<Esc>", close_all)
		map(state.dir_buf, "n", "q", close_all)
	end

	local group = vim.api.nvim_create_augroup("JavaCreatorClose", { clear = true })
	vim.api.nvim_create_autocmd("WinLeave", {
		group = group,
		callback = function()
			vim.schedule(function()
				if state.stage ~= "dir" then
					return
				end
				local cur = vim.api.nvim_get_current_win()
				if not state.owned_wins[cur] then
					close_all()
				end
			end)
		end,
	})
end

-- ═════════════════════════════════════════════════════════════
--  STAGE 2 — TYPE + NAME PICKER
-- ═════════════════════════════════════════════════════════════

local function render_type_list()
	if not (state.type_buf and vim.api.nvim_buf_is_valid(state.type_buf)) then
		return
	end
	vim.api.nvim_set_option_value("modifiable", true, { buf = state.type_buf })
	local lines = {}
	for i, key in ipairs(TEMPLATE_KEYS) do
		lines[i] = (i == state.selected_type and "  ▸ " or "    ") .. key
	end
	vim.api.nvim_buf_set_lines(state.type_buf, 0, -1, false, lines)
	if state.type_win and vim.api.nvim_win_is_valid(state.type_win) then
		pcall(vim.api.nvim_win_set_cursor, state.type_win, { state.selected_type, 0 })
	end
	vim.api.nvim_set_option_value("modifiable", false, { buf = state.type_buf })
end

local function focus_insert(win)
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_set_current_win(win)
		vim.cmd("startinsert!")
	end
end

local function switch_to_insert(target_win)
	vim.cmd("stopinsert")
	vim.schedule(function()
		focus_insert(target_win)
	end)
end

local function switch_to_type_list()
	vim.cmd("stopinsert")
	vim.schedule(function()
		if state.type_win and vim.api.nvim_win_is_valid(state.type_win) then
			vim.api.nvim_set_current_win(state.type_win)
		end
	end)
end

local function create_file()
	local name = vim.trim((vim.api.nvim_buf_get_lines(state.name_buf, 0, 1, false)[1] or ""))
	local pkg = vim.trim((vim.api.nvim_buf_get_lines(state.pkg_buf, 0, 1, false)[1] or ""))

	if name == "" then
		vim.notify("⚠  Class name cannot be empty", vim.log.levels.WARN)
		vim.schedule(function()
			focus_insert(state.name_win)
		end)
		return
	end

	if pkg == "" then
		pkg = state.package
	end
	name = name:gsub("%.java$", "")

	local tpl_key = TEMPLATE_KEYS[state.selected_type]
	local tpl_fn = templates[tpl_key]
	if not tpl_fn then
		vim.notify("Unknown template: " .. tostring(tpl_key), vim.log.levels.ERROR)
		return
	end

	local filepath = path_join(state.target_dir, name .. ".java")

	if vim.loop.fs_stat(filepath) then
		vim.notify("⚠  File already exists: " .. filepath, vim.log.levels.WARN)
		return
	end

	local fd = io.open(filepath, "w")
	if not fd then
		vim.notify("❌ Could not write: " .. filepath, vim.log.levels.ERROR)
		return
	end
	fd:write(tpl_fn(pkg, name))
	fd:close()

	close_all(function()
		-- Open directly in the current/last active normal window, not in a leftover float
		vim.cmd("edit " .. vim.fn.fnameescape(filepath))
		local line_count = vim.api.nvim_buf_line_count(0)
		vim.api.nvim_win_set_cursor(0, { math.max(1, line_count - 1), 0 })
		vim.notify("✅ Created " .. tpl_key .. ": " .. name .. ".java  →  " .. filepath, vim.log.levels.INFO)
	end)
end

open_type_stage = function(target_dir)
	state.stage = "type"
	state.target_dir = target_dir
	state.package = infer_package(target_dir)
	state.selected_type = 1

	local screen_w, screen_h = screen_dims()
	local main_w, main_h = 72, 28
	local main_row = math.floor((screen_h - main_h) / 2)
	local main_col = math.floor((screen_w - main_w) / 2)

	-- Truncate long paths so the header line never exceeds main_w and
	-- wrap/overflow the fixed-width box (which would visually break the
	-- border on the line below it).
	local header_prefix = "  ☕  New Java File   →   "
	local max_dir_len = math.max(8, main_w - #header_prefix - 2)
	local display_dir = target_dir
	if #display_dir > max_dir_len then
		display_dir = "…" .. display_dir:sub(-(max_dir_len - 1))
	end

	state.main_buf = create_buf({
		header_prefix .. display_dir,
		"────────────────────────────────────────────────────────────────────",
		"  j/k navigate   CR confirm/create   Tab next field   Esc back/close",
		"────────────────────────────────────────────────────────────────────",
	}, false)
	safe_highlight(state.main_buf, "Title", 0, 0, -1)
	safe_highlight(state.main_buf, "Comment", 2, 0, -1)

	state.main_win = open_float(state.main_buf, {
		relative = "editor",
		row = main_row,
		col = main_col,
		width = main_w,
		height = main_h,
		style = "minimal",
		border = "rounded",
		title = " ☕ Java File Creator ",
		title_pos = "center",
		zindex = 50,
		focusable = false,
	})

	local type_w, type_h = 26, #TEMPLATE_KEYS
	local type_row, type_col = main_row + 5, main_col + 2

	local type_lines = {}
	for i, key in ipairs(TEMPLATE_KEYS) do
		type_lines[i] = (i == 1 and "  ▸ " or "    ") .. key
	end
	state.type_buf = create_buf(type_lines, false)
	state.type_win = open_float(state.type_buf, {
		relative = "editor",
		row = type_row,
		col = type_col,
		width = type_w,
		height = type_h,
		style = "minimal",
		border = "single",
		title = " Type ",
		title_pos = "center",
		focusable = true,
		zindex = 60,
	})
	if state.type_win then
		pcall(vim.api.nvim_set_option_value, "cursorline", true, { win = state.type_win })
	end

	local input_col = main_col + type_w + 5
	local input_w = main_w - type_w - 9

	state.name_buf = create_buf({ "" }, true)
	state.name_win = open_float(state.name_buf, {
		relative = "editor",
		row = type_row,
		col = input_col,
		width = input_w,
		height = 1,
		style = "minimal",
		border = "single",
		title = " Class Name ",
		title_pos = "center",
		focusable = true,
		zindex = 60,
	})

	state.pkg_buf = create_buf({ state.package }, true)
	state.pkg_win = open_float(state.pkg_buf, {
		relative = "editor",
		row = type_row + 3,
		col = input_col,
		width = input_w,
		height = 1,
		style = "minimal",
		border = "single",
		title = " Package ",
		title_pos = "center",
		focusable = true,
		zindex = 60,
	})

	local info_dir = target_dir
	local info_max_len = math.max(8, input_w - #"  Dir → " - 1)
	if #info_dir > info_max_len then
		info_dir = "…" .. info_dir:sub(-(info_max_len - 1))
	end

	local info_buf = create_buf({
		"",
		"  Dir → " .. info_dir,
		"",
		"  CR on type list → jump to Class Name",
		"  Tab in any input → switch Name ↔ Package",
		"  CR  in any input → create file",
		"  Esc in input → back to type list",
		"  Esc on type list → close",
	}, false)
	state.info_win = open_float(info_buf, {
		relative = "editor",
		row = type_row + 6,
		col = input_col,
		width = input_w,
		height = 7,
		style = "minimal",
		border = "single",
		title = " Info ",
		title_pos = "center",
		focusable = false,
		zindex = 60,
	})
	for _, l in ipairs({ 1, 3, 4, 5, 6, 7 }) do
		safe_highlight(info_buf, "Comment", l, 0, -1)
	end

	state.owned_wins = {
		[state.main_win] = true,
		[state.type_win] = true,
		[state.name_win] = true,
		[state.pkg_win] = true,
		[state.info_win] = true,
	}

	if state.type_win then
		vim.api.nvim_set_current_win(state.type_win)
	end

	local function navigate(delta)
		state.selected_type = math.max(1, math.min(#TEMPLATE_KEYS, state.selected_type + delta))
		render_type_list()
	end

	map(state.type_buf, "n", "j", function()
		navigate(1)
	end)
	map(state.type_buf, "n", "k", function()
		navigate(-1)
	end)
	map(state.type_buf, "n", "<Down>", function()
		navigate(1)
	end)
	map(state.type_buf, "n", "<Up>", function()
		navigate(-1)
	end)
	map(state.type_buf, "n", "<CR>", function()
		vim.schedule(function()
			focus_insert(state.name_win)
		end)
	end)
	map(state.type_buf, "n", "<Tab>", function()
		vim.schedule(function()
			focus_insert(state.name_win)
		end)
	end)
	map(state.type_buf, "n", "<Esc>", close_all)
	map(state.type_buf, "n", "q", close_all)
	-- go back to directory picker
	map(state.type_buf, "n", "b", function()
		local cur_dir = state.target_dir
		close_all(function()
			open_dir_stage(cur_dir)
		end)
	end)

	map(state.name_buf, "i", "<CR>", function()
		vim.cmd("stopinsert")
		vim.schedule(create_file)
	end)
	map(state.name_buf, "n", "<CR>", create_file)
	map(state.name_buf, "i", "<Tab>", function()
		switch_to_insert(state.pkg_win)
	end)
	map(state.name_buf, "n", "<Tab>", function()
		vim.schedule(function()
			focus_insert(state.pkg_win)
		end)
	end)
	map(state.name_buf, "i", "<Esc>", switch_to_type_list)
	map(state.name_buf, "n", "<Esc>", function()
		if state.type_win and vim.api.nvim_win_is_valid(state.type_win) then
			vim.api.nvim_set_current_win(state.type_win)
		end
	end)

	map(state.pkg_buf, "i", "<CR>", function()
		vim.cmd("stopinsert")
		vim.schedule(create_file)
	end)
	map(state.pkg_buf, "n", "<CR>", create_file)
	map(state.pkg_buf, "i", "<Tab>", function()
		switch_to_insert(state.name_win)
	end)
	map(state.pkg_buf, "n", "<Tab>", function()
		vim.schedule(function()
			focus_insert(state.name_win)
		end)
	end)
	map(state.pkg_buf, "i", "<Esc>", switch_to_type_list)
	map(state.pkg_buf, "n", "<Esc>", function()
		if state.type_win and vim.api.nvim_win_is_valid(state.type_win) then
			vim.api.nvim_set_current_win(state.type_win)
		end
	end)

	local group = vim.api.nvim_create_augroup("JavaCreatorClose", { clear = true })
	vim.api.nvim_create_autocmd("WinLeave", {
		group = group,
		callback = function()
			vim.schedule(function()
				if state.stage ~= "type" then
					return
				end
				local cur = vim.api.nvim_get_current_win()
				if not state.owned_wins[cur] then
					close_all()
				end
			end)
		end,
	})
end

-- ═════════════════════════════════════════════════════════════
--  ENTRY POINT
-- ═════════════════════════════════════════════════════════════

function M.open()
	if state.stage then
		close_all()
		return
	end
	state.original_win = vim.api.nvim_get_current_win()
	close_all(function()
		local ok, err = pcall(function()
			open_dir_stage(get_initial_dir())
		end)
		if not ok then
			close_all()
			vim.notify("java-creator failed to open: " .. tostring(err), vim.log.levels.ERROR)
		end
	end)
end

vim.keymap.set("n", "<leader>jn", M.open, {
	desc = "Java: New file (IntelliJ-style)",
	silent = true,
})

vim.api.nvim_create_user_command("JavaNew", M.open, {
	desc = "Open Java file creator GUI",
})

return M
