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
  local from = vim.api.nvim_buf_get_name(0)
  if from == "" then
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
local function build_command(root, tool)
  local wrapper = root .. "/" .. (tool == "maven" and "mvnw" or "gradlew")
  if vim.fn.executable(wrapper) == 1 then
    return "./" .. (tool == "maven" and "mvnw" or "gradlew")
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

  -- shellescape the root, and escape % and # so Vim does not expand them
  -- as the current/alternate filename inside the `:!` command line.
  local cmd = ("cd %s && %s %s"):format(vim.fn.shellescape(root), exe, args)
  vim.notify(("%s: %s"):format(what, cmd), vim.log.levels.INFO, { title = "spring boot" })
  vim.cmd("!" .. vim.fn.escape(cmd, "%#"))
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

-- Setup user commands
function M.setup()
  vim.api.nvim_create_user_command("SpringBootCreate", M.create_project, {
    desc = "Create new Spring Boot project",
  })
  vim.api.nvim_create_user_command("SpringBootRun", M.run_app, {
    desc = "Run Spring Boot application",
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
end

return M
