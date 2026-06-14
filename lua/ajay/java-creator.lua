-- java-creator.lua
-- IntelliJ-style Java file creation with floating GUI
-- Drop in: lua/ajay/java-creator.lua
-- Add to init.lua: require("ajay.java-creator")

local M = {}

-- ─────────────────────────────────────────────────────────────
--  TEMPLATES
-- ─────────────────────────────────────────────────────────────

---@param pkg string  e.g. "com.example.service"
---@param name string e.g. "UserService"
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

-- Ordered list for display
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

--- Derive Java package from the file path.
--- Scans upward for src/main/java or src/test/java.
---@param dir string absolute directory path
---@return string package name
local function infer_package(dir)
  local path = dir
  local markers = { "src/main/java", "src/test/java" }
  for _, marker in ipairs(markers) do
    local idx = path:find(marker, 1, true)
    if idx then
      local after = path:sub(idx + #marker + 1)
      return after:gsub("/", "."):gsub("^%.", ""):gsub("%.$", "")
    end
  end
  -- fallback: use last two path segments
  local parts = {}
  for seg in path:gmatch("[^/]+") do
    table.insert(parts, seg)
  end
  if #parts >= 2 then
    return parts[#parts - 1] .. "." .. parts[#parts]
  end
  return "com.example"
end

--- Return the directory of the currently focused buffer/tree node.
---@return string absolute directory
local function get_target_dir()
  -- Try to get from neo-tree if it's open
  local ok, nt_api = pcall(require, "neo-tree.sources.filesystem.lib.file_items")
  if ok then
    -- Attempt to get neo-tree's current node
    local manager_ok, manager = pcall(require, "neo-tree.sources.manager")
    if manager_ok then
      local state = manager.get_state("filesystem")
      if state and state.tree then
        local node = state.tree:get_node()
        if node then
          local path = node.path or node:get_id()
          local stat = vim.loop.fs_stat(path)
          if stat and stat.type == "directory" then
            return path
          elseif stat then
            return vim.fn.fnamemodify(path, ":h")
          end
        end
      end
    end
  end

  -- Fallback: directory of the current buffer
  local buf_path = vim.api.nvim_buf_get_name(0)
  if buf_path ~= "" then
    return vim.fn.fnamemodify(buf_path, ":h")
  end

  -- Last resort: cwd
  return vim.fn.getcwd()
end

-- ─────────────────────────────────────────────────────────────
--  UI STATE
-- ─────────────────────────────────────────────────────────────

local state = {
  win = nil,
  buf = nil,
  -- sub-windows
  type_win = nil,
  type_buf = nil,
  name_win = nil,
  name_buf = nil,
  pkg_win = nil,
  pkg_buf = nil,
  -- current values
  selected_type = 1,
  class_name = "",
  package = "",
  target_dir = "",
}

-- ─────────────────────────────────────────────────────────────
--  WINDOW CREATION
-- ─────────────────────────────────────────────────────────────

local function close_all()
  local wins = { state.win, state.type_win, state.name_win, state.pkg_win }
  for _, w in ipairs(wins) do
    if w and vim.api.nvim_win_is_valid(w) then
      vim.api.nvim_win_close(w, true)
    end
  end
  state.win = nil
  state.type_win = nil
  state.name_win = nil
  state.pkg_win = nil
end

local function create_buf(lines, modifiable)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or {})
  vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
  vim.api.nvim_set_option_value("modifiable", modifiable or false, { buf = buf })
  return buf
end

local function open_float(buf, opts)
  local win = vim.api.nvim_open_win(buf, false, opts)
  vim.api.nvim_set_option_value("winhl", "Normal:NormalFloat,FloatBorder:FloatBorder", { win = win })
  vim.api.nvim_set_option_value("cursorline", true, { win = win })
  vim.api.nvim_set_option_value("number", false, { win = win })
  vim.api.nvim_set_option_value("signcolumn", "no", { win = win })
  return win
end

-- ─────────────────────────────────────────────────────────────
--  RENDER
-- ─────────────────────────────────────────────────────────────

--- Re-draw the type list buffer to show selection highlight
local function render_type_list()
  if not state.type_buf or not vim.api.nvim_buf_is_valid(state.type_buf) then
    return
  end

  vim.api.nvim_set_option_value("modifiable", true, { buf = state.type_buf })

  local lines = {}
  for i, key in ipairs(TEMPLATE_KEYS) do
    if i == state.selected_type then
      lines[i] = "  ▸ " .. key
    else
      lines[i] = "    " .. key
    end
  end
  vim.api.nvim_buf_set_lines(state.type_buf, 0, -1, false, lines)

  -- Move cursor to selected line
  if state.type_win and vim.api.nvim_win_is_valid(state.type_win) then
    vim.api.nvim_win_set_cursor(state.type_win, { state.selected_type, 0 })
  end

  vim.api.nvim_set_option_value("modifiable", false, { buf = state.type_buf })
end

-- ─────────────────────────────────────────────────────────────
--  MAIN OPEN FUNCTION
-- ─────────────────────────────────────────────────────────────

function M.open()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    close_all()
    return
  end

  state.target_dir = get_target_dir()
  state.package = infer_package(state.target_dir)
  state.selected_type = 1
  state.class_name = ""

  local ui = vim.api.nvim_list_uis()[1]
  local screen_w = ui.width
  local screen_h = ui.height

  -- ── Main container window (title bar + backdrop) ──────────
  local main_w = 72
  local main_h = 28
  local main_row = math.floor((screen_h - main_h) / 2)
  local main_col = math.floor((screen_w - main_w) / 2)

  local title_lines = {
    "  ☕  New Java File                                              ",
    "──────────────────────────────────────────────────────────────────",
    "  j/k  navigate    Enter  create    Tab  jump fields    Esc  close",
    "──────────────────────────────────────────────────────────────────",
  }

  state.buf = create_buf(title_lines, false)
  -- Namespace: highlight title
  vim.api.nvim_buf_add_highlight(state.buf, -1, "Title", 0, 0, -1)
  vim.api.nvim_buf_add_highlight(state.buf, -1, "Comment", 2, 0, -1)

  state.win = open_float(state.buf, {
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
  })

  -- ── Type selector (left panel) ────────────────────────────
  local type_w = 26
  local type_h = #TEMPLATE_KEYS
  local type_row = main_row + 5
  local type_col = main_col + 2

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
  vim.api.nvim_set_option_value("cursorline", true, { win = state.type_win })

  -- ── Class name input ──────────────────────────────────────
  local input_col = main_col + type_w + 5
  local input_w = main_w - type_w - 9

  state.name_buf = create_buf({ "" }, true)
  vim.api.nvim_set_option_value("modifiable", true, { buf = state.name_buf })

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

  -- ── Package input ─────────────────────────────────────────
  state.pkg_buf = create_buf({ state.package }, true)
  vim.api.nvim_set_option_value("modifiable", true, { buf = state.pkg_buf })

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

  -- ── Preview label ─────────────────────────────────────────
  local preview_buf = create_buf({
    "",
    "  Directory → " .. state.target_dir,
    "",
    "  Press <CR> in any field to create the file.",
    "  Press <Tab> to switch between Name / Package fields.",
  }, false)

  open_float(preview_buf, {
    relative = "editor",
    row = type_row + 6,
    col = input_col,
    width = input_w,
    height = 5,
    style = "minimal",
    border = "single",
    title = " Info ",
    title_pos = "center",
    focusable = false,
    zindex = 60,
  })
  vim.api.nvim_buf_add_highlight(preview_buf, -1, "Comment", 1, 0, -1)
  vim.api.nvim_buf_add_highlight(preview_buf, -1, "Comment", 3, 0, -1)

  -- ── Focus type list first ─────────────────────────────────
  vim.api.nvim_set_current_win(state.type_win)

  -- ─────────────────────────────────────────────────────────
  --  KEYMAPS — Type list
  -- ─────────────────────────────────────────────────────────

  local function set_map(buf, mode, lhs, fn)
    vim.keymap.set(mode, lhs, fn, { buffer = buf, silent = true, nowait = true })
  end

  local function navigate(delta)
    state.selected_type = math.max(1, math.min(#TEMPLATE_KEYS, state.selected_type + delta))
    render_type_list()
  end

  local function create_file()
    -- Read name and package from their buffers
    local name_lines = vim.api.nvim_buf_get_lines(state.name_buf, 0, 1, false)
    local pkg_lines = vim.api.nvim_buf_get_lines(state.pkg_buf, 0, 1, false)

    local name = vim.trim(name_lines[1] or "")
    local pkg = vim.trim(pkg_lines[1] or state.package)

    if name == "" then
      vim.notify("⚠  Class name cannot be empty", vim.log.levels.WARN)
      vim.api.nvim_set_current_win(state.name_win)
      return
    end

    -- Sanitize: strip .java if user typed it
    name = name:gsub("%.java$", "")

    local tpl_key = TEMPLATE_KEYS[state.selected_type]
    local tpl_fn = templates[tpl_key]
    if not tpl_fn then
      vim.notify("Unknown template: " .. tpl_key, vim.log.levels.ERROR)
      return
    end

    local content = tpl_fn(pkg, name)
    local filepath = state.target_dir .. "/" .. name .. ".java"

    -- Check for existing file
    if vim.loop.fs_stat(filepath) then
      vim.notify("⚠  File already exists: " .. filepath, vim.log.levels.WARN)
      return
    end

    -- Write file
    local fd = io.open(filepath, "w")
    if not fd then
      vim.notify("❌ Could not write to: " .. filepath, vim.log.levels.ERROR)
      return
    end
    fd:write(content)
    fd:close()

    close_all()

    -- Open in new buffer
    vim.cmd("edit " .. vim.fn.fnameescape(filepath))
    -- Position cursor at the right spot (inside class body)
    vim.cmd("normal! G")
    vim.cmd("normal! k")

    vim.notify("✅ Created " .. tpl_key .. ": " .. name .. ".java", vim.log.levels.INFO)
  end

  -- Type list navigation
  set_map(state.type_buf, "n", "j", function()
    navigate(1)
  end)
  set_map(state.type_buf, "n", "k", function()
    navigate(-1)
  end)
  set_map(state.type_buf, "n", "<Down>", function()
    navigate(1)
  end)
  set_map(state.type_buf, "n", "<Up>", function()
    navigate(-1)
  end)
  set_map(state.type_buf, "n", "<CR>", function()
    vim.api.nvim_set_current_win(state.name_win)
    vim.cmd("startinsert!")
  end)
  set_map(state.type_buf, "n", "<Tab>", function()
    vim.api.nvim_set_current_win(state.name_win)
    vim.cmd("startinsert!")
  end)
  set_map(state.type_buf, "n", "<Esc>", close_all)
  set_map(state.type_buf, "n", "q", close_all)

  -- Name input
  set_map(state.name_buf, "i", "<CR>", function()
    vim.cmd("stopinsert")
    create_file()
  end)
  set_map(state.name_buf, "n", "<CR>", create_file)
  set_map(state.name_buf, "i", "<Tab>", function()
    vim.cmd("stopinsert")
    vim.api.nvim_set_current_win(state.pkg_win)
    vim.cmd("startinsert!")
  end)
  set_map(state.name_buf, "n", "<Tab>", function()
    vim.api.nvim_set_current_win(state.pkg_win)
    vim.cmd("startinsert!")
  end)
  set_map(state.name_buf, "i", "<Esc>", function()
    vim.cmd("stopinsert")
    vim.api.nvim_set_current_win(state.type_win)
  end)
  set_map(state.name_buf, "n", "<Esc>", function()
    vim.api.nvim_set_current_win(state.type_win)
  end)

  -- Package input
  set_map(state.pkg_buf, "i", "<CR>", function()
    vim.cmd("stopinsert")
    create_file()
  end)
  set_map(state.pkg_buf, "n", "<CR>", create_file)
  set_map(state.pkg_buf, "i", "<Tab>", function()
    vim.cmd("stopinsert")
    vim.api.nvim_set_current_win(state.name_win)
    vim.cmd("startinsert!")
  end)
  set_map(state.pkg_buf, "n", "<Tab>", function()
    vim.api.nvim_set_current_win(state.name_win)
    vim.cmd("startinsert!")
  end)
  set_map(state.pkg_buf, "i", "<Esc>", function()
    vim.cmd("stopinsert")
    vim.api.nvim_set_current_win(state.type_win)
  end)
  set_map(state.pkg_buf, "n", "<Esc>", function()
    vim.api.nvim_set_current_win(state.type_win)
  end)

  -- Auto-close when any window is left
  local group = vim.api.nvim_create_augroup("JavaCreatorClose", { clear = true })
  vim.api.nvim_create_autocmd("WinLeave", {
    group = group,
    callback = function()
      local cur = vim.api.nvim_get_current_win()
      local managed = { state.type_win, state.name_win, state.pkg_win, state.win }
      for _, w in ipairs(managed) do
        if cur == w then
          return
        end
      end
      close_all()
      vim.api.nvim_del_augroup_by_name("JavaCreatorClose")
    end,
  })
end

-- ─────────────────────────────────────────────────────────────
--  DEFAULT KEYMAP
-- ─────────────────────────────────────────────────────────────

-- <leader>jn  →  New Java file (j=java, n=new)
vim.keymap.set("n", "<leader>jn", M.open, {
  desc = "Java: New file (IntelliJ-style)",
  silent = true,
})

-- Also expose as user command
vim.api.nvim_create_user_command("JavaNew", M.open, {
  desc = "Open Java file creator GUI",
})

return M
