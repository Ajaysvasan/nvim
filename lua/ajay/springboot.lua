-- lua/ajay/springboot.lua

local M = {}

-- ── Project detection ──────────────────────────────────────────────
--
-- BUG FIX. Every command here used to decide the build tool like this:
--
--   local build_tool = vim.fn.filereadable("pom.xml") == 1 and "maven" or "gradle"
--
-- which has three separate problems:
--
--  1. There is no "neither" case. Anything that is not Maven is assumed
--     to be Gradle, so running :SpringBootBuild outside a Java project
--     shells out to ./gradlew and you get
--       /bin/bash: line 1: ./gradlew: No such file or directory
--       shell returned 127
--     instead of being told this is not a Spring Boot project.
--
--  2. `filereadable("pom.xml")` is relative to Neovim's CWD, not to the
--     file you are editing. Open a project from its parent directory and
--     the detection reads the wrong tree.
--
--  3. It assumes the WRAPPER is present. ./mvnw and ./gradlew are not
--     committed in every repo, and a project with pom.xml but no mvnw
--     failed the same 127 way.
--
-- So: search upward from the current file for a real build file, then
-- prefer the wrapper and fall back to whatever is on PATH.
local function project_root()
  local buf = vim.api.nvim_get_current_buf()

  -- A task terminal opened by run() remembers the project it belongs to.
  -- Without this, running a SECOND command was broken: after the first one
  -- the current buffer is the terminal, named "spring-boot://<proj>/run",
  -- and searching upward from dirname() of that is meaningless -- so
  -- :SpringBootTest right after :SpringBootRun reported "this does not look
  -- like a Maven or Gradle project" while sitting inside the project.
  if vim.b[buf].springboot_root then
    return vim.b[buf].springboot_root, vim.b[buf].springboot_tool
  end

  local from = vim.api.nvim_buf_get_name(buf)
  -- Only a real file tells us anything about location. Terminals, help,
  -- neo-tree, alpha and quickfix all have a buftype and either no name or a
  -- synthetic one; searching upward from those is noise, so use the cwd.
  if from == "" or vim.bo[buf].buftype ~= "" then
    from = vim.uv and vim.uv.cwd() or vim.loop.cwd()
  end
  local found = vim.fs.find({ "pom.xml", "build.gradle", "build.gradle.kts" }, {
    upward = true,
    path = vim.fs.dirname(from),
    type = "file",
  })[1]
  if not found then
    return nil, nil
  end
  local root = vim.fs.dirname(found)
  local tool = vim.fs.basename(found) == "pom.xml" and "maven" or "gradle"
  return root, tool
end

-- Wrapper if the project ships one, otherwise the system binary.
--
-- Returns an ABSOLUTE path for the wrapper, not "./mvnw". run() launches via
-- jobstart() in list form, and jobstart resolves argv[0] against NEOVIM's
-- working directory -- the `cwd` option applies to the spawned process, not to
-- finding the executable in the first place. "./mvnw" therefore failed with
--   E475: Invalid value for argument cmd: './mvnw' is not executable
-- whenever Neovim's cwd was not already the project root, which is the normal
-- case when you open a file by path.
local function build_command(root, tool)
  local wrapper = root .. "/" .. (tool == "maven" and "mvnw" or "gradlew")
  if vim.fn.executable(wrapper) == 1 then
    return wrapper
  end
  local system = tool == "maven" and "mvn" or "gradle"
  if vim.fn.executable(system) == 1 then
    return system
  end
  return nil
end

-- Run `args` with the project's build tool, from the project root.
local function run(args, what)
  local root, tool = project_root()
  if not root then
    vim.notify(
      "No pom.xml, build.gradle or build.gradle.kts found above this file.\n"
        .. "This does not look like a Maven or Gradle project.",
      vim.log.levels.ERROR,
      { title = "spring boot" }
    )
    return
  end

  local exe = build_command(root, tool)
  if not exe then
    local sys = tool == "maven" and "mvn" or "gradle"
    vim.notify(
      ("Found a %s project at %s, but no way to build it.\n\n"):format(tool, root)
        .. ("There is no %s wrapper and `%s` is not on PATH."):format(tool, sys),
      vim.log.levels.ERROR,
      { title = "spring boot" }
    )
    return
  end

  -- ── WHY THIS IS A TERMINAL AND NOT `:!` ──────────────────────────
  --
  -- This used to be `vim.cmd("!" .. cmd)`. `:!` is SYNCHRONOUS -- measured,
  -- `:!sleep 3` returns after 3.2s while the same thing in a terminal
  -- returns in 0.1s. For `mvn test` that is merely annoying; for
  -- :SpringBootRun, which starts a server that runs until you stop it, it
  -- meant **Neovim was frozen for the entire life of the application**.
  --
  -- It was also the wrong place to send logs. `:!` output goes to the
  -- message area, not a buffer, so a Spring Boot startup trace or a stack
  -- trace could not be scrolled, searched with `/`, yanked, or sent to
  -- the quickfix list. A terminal buffer gives you all of that for free.
  --
  -- The rest of this config already had it right -- <leader>rp, <leader>rj
  -- and the CMake keymaps in keymaps.lua all use `split | terminal`. These
  -- commands were simply inconsistent with them.
  --
  -- jobstart() in LIST form with `cwd`, rather than a shell string:
  --   * no `cd ... &&` prefix, so nothing to shell-quote
  --   * no `vim.fn.escape(cmd, "%#")` dance for the Ex command line
  --   * a project path containing a space, a quote or a `%` cannot break
  --     or, worse, silently run the wrong command
  local argv = { exe }
  for _, a in ipairs(vim.split(args, "%s+", { trimempty = true })) do
    table.insert(argv, a)
  end

  -- Reuse the window if this project already has a FINISHED Spring Boot
  -- terminal open, instead of stacking a new split every invocation.
  --
  -- "Finished" matters. :SpringBootRun starts a server that lives until you
  -- stop it; if :SpringBootTest then reused that window, replacing the
  -- buffer would kill the running application as a side effect of asking
  -- for something unrelated. So a live task keeps its window and the new
  -- task opens its own split; only a completed one is recycled.
  local function job_alive(b)
    local id = vim.b[b].springboot_job
    return id ~= nil and vim.fn.jobwait({ id }, 0)[1] == -1
  end

  local reuse_win, stale_buf
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    local b = vim.api.nvim_win_get_buf(w)
    if vim.b[b].springboot_task and not job_alive(b) then
      reuse_win, stale_buf = w, b
    end
  end

  if reuse_win then
    vim.api.nvim_set_current_win(reuse_win)
    vim.cmd("enew")
    -- Wipe the finished task's buffer. Without this every run left another
    -- dead terminal behind, cluttering :ls and the <leader>fb picker.
    if stale_buf and vim.api.nvim_buf_is_valid(stale_buf) then
      pcall(vim.api.nvim_buf_delete, stale_buf, { force = true })
    end
  else
    vim.cmd("botright " .. math.max(12, math.floor(vim.o.lines * 0.35)) .. "split")
    vim.cmd("enew")
  end

  local buf = vim.api.nvim_get_current_buf()
  vim.b[buf].springboot_task = what
  -- Remembered so project_root() still works when this terminal is the
  -- current buffer -- i.e. every command after the first one.
  vim.b[buf].springboot_root = root
  vim.b[buf].springboot_tool = tool

  local ok, job = pcall(vim.fn.jobstart, argv, {
    term = true,
    cwd = root,
    on_exit = function(_, code)
      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(buf) then
          return
        end
        vim.notify(
          ("%s %s (exit %d)"):format(what, code == 0 and "finished" or "FAILED", code),
          code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR,
          { title = "spring boot" }
        )
      end)
    end,
  })
  if not ok then
    -- Tear down the split we just opened. Leaving an empty scratch buffer
    -- and a window behind on failure is worse than the failure itself.
    vim.notify("Failed to start: " .. tostring(job), vim.log.levels.ERROR, { title = "spring boot" })
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    return
  end
  -- Recorded so the reuse check above can tell a live task from a finished
  -- one, and so :SpringBootStop has something to signal.
  vim.b[buf].springboot_job = job

  -- Name it so :ls and the bufferline show which task this is, and so the
  -- reuse check above can find it again.
  pcall(vim.api.nvim_buf_set_name, buf, ("spring-boot://%s/%s"):format(vim.fs.basename(root), what:lower()))

  -- Stay in NORMAL mode. A terminal opened straight into insert mode is a
  -- log you cannot scroll or search without first pressing <C-\><C-n>,
  -- and reading the output is the entire point here.
  vim.cmd("stopinsert")
  vim.notify(
    -- basename only: exe is now an absolute path to the wrapper, and the
    -- full path tells you nothing you did not already know.
    ("%s: %s %s  (in %s)"):format(what, vim.fs.basename(exe), args, vim.fs.basename(root)),
    vim.log.levels.INFO,
    { title = "spring boot" }
  )
end

-- Percent-encode a value going into the Initializr query string. Without
-- this, a group id or dependency list containing a space produced a
-- malformed URL and an unhelpful curl failure.
local function urlencode(s)
  return (tostring(s):gsub("[^%w%-%._~]", function(ch)
    return ("%%%02X"):format(ch:byte())
  end))
end

-- Function to create a new Spring Boot project using Spring Initializr
function M.create_project()
  local project_name = vim.fn.input("Project name: ")
  if project_name == "" then
    vim.notify("Project name cannot be empty", vim.log.levels.ERROR)
    return
  end

  local group_id = vim.fn.input("Group ID (com.example): ", "com.example")
  local artifact_id = vim.fn.input("Artifact ID (" .. project_name .. "): ", project_name)
  local java_version = vim.fn.input("Java version (17/21): ", "17")
  local build_tool = vim.fn.input("Build tool (maven/gradle): ", "maven")
  local dependencies = vim.fn.input("Dependencies (comma-separated, e.g., web,data-jpa,h2): ", "web,devtools")

  -- The project name becomes a DIRECTORY and, previously, part of three
  -- unquoted shell commands -- including `rm /tmp/<name>.zip`. A name with
  -- a space merely broke; a name with a shell metacharacter was a command
  -- injection into your own shell. Reject anything that is not a plain
  -- project name rather than trying to quote our way out of it.
  if not project_name:match("^[%w._-]+$") then
    vim.notify(
      "Project name must contain only letters, digits, dot, underscore or dash.",
      vim.log.levels.ERROR,
      { title = "spring boot" }
    )
    return
  end

  if vim.fn.isdirectory(project_name) == 1 then
    vim.notify("./" .. project_name .. " already exists — refusing to overwrite.", vim.log.levels.ERROR)
    return
  end

  -- Construct Spring Initializr URL. Every interpolated value is
  -- percent-encoded: group ids and dependency lists are free text and a
  -- single space used to produce a malformed URL.
  local base_url = "https://start.spring.io/starter.zip"
  local url = string.format(
    "%s?type=%s-project&language=java&bootVersion=3.2.0&groupId=%s&artifactId=%s&name=%s&packageName=%s.%s&javaVersion=%s&dependencies=%s",
    base_url,
    urlencode(build_tool),
    urlencode(group_id),
    urlencode(artifact_id),
    urlencode(project_name),
    urlencode(group_id),
    urlencode(artifact_id),
    urlencode(java_version),
    urlencode(dependencies)
  )

  if vim.fn.executable("curl") ~= 1 or vim.fn.executable("unzip") ~= 1 then
    vim.notify("Needs both `curl` and `unzip` on PATH.", vim.log.levels.ERROR, { title = "spring boot" })
    return
  end

  -- tempname() instead of a guessable /tmp/<name>.zip, and LIST-form
  -- vim.fn.system() throughout so no shell parses any of this.
  local zip = vim.fn.tempname() .. ".zip"
  vim.notify("Downloading Spring Boot project...", vim.log.levels.INFO)

  vim.fn.system({ "curl", "-fsSL", "-o", zip, url })
  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to download project from start.spring.io", vim.log.levels.ERROR)
    vim.fn.delete(zip)
    return
  end

  vim.fn.system({ "unzip", "-q", zip, "-d", project_name })
  if vim.v.shell_error ~= 0 then
    vim.notify("Failed to extract project", vim.log.levels.ERROR)
    vim.fn.delete(zip)
    return
  end

  vim.fn.delete(zip)

  vim.notify("✓ Spring Boot project created: " .. project_name, vim.log.levels.INFO)
  vim.notify("Run :cd " .. project_name .. " to navigate to the project", vim.log.levels.INFO)
end

-- Function to run Spring Boot application
function M.run_app()
  local _, tool = project_root()
  run(tool == "maven" and "spring-boot:run" or "bootRun", "Run")
end

-- Function to build project
function M.build_project()
  local _, tool = project_root()
  run(tool == "maven" and "clean install" or "build", "Build")
end

-- Function to run tests
function M.run_tests()
  run("test", "Test")
end

--- Stop every running Spring Boot task started by this module.
---
--- Needed because these are real background jobs now, not a blocking `:!`.
--- The old `:!` version was stopped with Ctrl-C because it owned the whole
--- editor; a jobstart() task keeps running happily in a hidden buffer, and
--- an orphaned Spring Boot app still holds port 8080 -- which then shows up
--- as a baffling "port already in use" on the next :SpringBootRun.
function M.stop_app()
  local stopped = {}
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and vim.b[b].springboot_job then
      local id = vim.b[b].springboot_job
      if vim.fn.jobwait({ id }, 0)[1] == -1 then
        pcall(vim.fn.jobstop, id)
        table.insert(stopped, vim.b[b].springboot_task or "task")
      end
    end
  end
  if #stopped == 0 then
    vim.notify("No Spring Boot task is running.", vim.log.levels.INFO, { title = "spring boot" })
  else
    vim.notify("Stopped: " .. table.concat(stopped, ", "), vim.log.levels.WARN, { title = "spring boot" })
  end
end

-- Setup user commands
function M.setup()
  vim.api.nvim_create_user_command("SpringBootCreate", M.create_project, {
    desc = "Create new Spring Boot project",
  })
  vim.api.nvim_create_user_command("SpringBootRun", M.run_app, {
    desc = "Run Spring Boot application",
  })
  vim.api.nvim_create_user_command("SpringBootStop", M.stop_app, {
    desc = "Stop any running Spring Boot task",
  })
  vim.api.nvim_create_user_command("SpringBootBuild", M.build_project, {
    desc = "Build Spring Boot project",
  })
  vim.api.nvim_create_user_command("SpringBootTest", M.run_tests, {
    desc = "Run Spring Boot tests",
  })

  -- Keymaps for Spring Boot (using <leader>s prefix)
  vim.keymap.set("n", "<leader>sc", M.create_project, { desc = "Spring Boot: Create Project" })
  vim.keymap.set("n", "<leader>sr", M.run_app, { desc = "Spring Boot: Run App" })
  vim.keymap.set("n", "<leader>sb", M.build_project, { desc = "Spring Boot: Build" })
  vim.keymap.set("n", "<leader>st", M.run_tests, { desc = "Spring Boot: Test" })
  -- <leader>sx = stop. Not <leader>ss: nothing else uses it today, but "s"
  -- doubling up reads as a typo, and "x" is the kill idiom already used by
  -- <leader>hx (harpoon remove).
  vim.keymap.set("n", "<leader>sx", M.stop_app, { desc = "Spring Boot: Stop running task" })
end

return M
