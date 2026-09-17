-- lua/ajay/jdtls.lua
--
-- Fixes, in rough order of how much they were hurting you:
--
--  1. LOAD TIMING (my bug). I set the plugin spec to `ft = "java"` and had
--     config() register a `FileType java` autocmd. But by the time lazy
--     loads the plugin on the java filetype, that FileType event has
--     ALREADY fired. The autocmd registered too late to catch the buffer
--     that triggered it, so jdtls never started on the first Java file you
--     opened. Now config() starts jdtls for the current buffer directly
--     AND registers the autocmd for subsequent ones.
--
--  2. LOMBOK. Not configured at all. Spring Boot projects lean on
--     @Data/@Getter/@RequiredArgsConstructor, and without the Lombok
--     javaagent jdtls doesn't see generated methods — you get "cannot find
--     symbol: getName()" on every entity while Maven builds fine. This is
--     the classic "Spring Boot setup is broken" symptom.
--
--  3. MASON 2.0 API. add_bundle_jars() used pkg:get_install_path(), which
--     mason 2.0 removed. It was wrapped in pcall, so it failed SILENTLY --
--     no debug or test bundles loaded, meaning <leader>jt (test class) and
--     Java debugging quietly did nothing. This regressed when I moved you
--     to mason-org/mason.nvim.
--
--  4. ROOT DETECTION. ".git" was first in the marker list, so in any repo
--     where the git root isn't the Maven module root, jdtls attached to
--     the wrong directory and reported an incomplete classpath.
--
--  5. WORKSPACE COLLISION. project_name came from getcwd() rather than the
--     resolved root, so two projects opened from the same parent directory
--     shared one jdtls workspace and corrupted each other's index.
--
--  6. JDK RESOLUTION. cmd used bare "java". jdtls needs JDK 21+ to RUN,
--     independent of what your project targets. And the `runtimes` table
--     was empty with Linux-only example paths commented out -- on macOS
--     there is no /usr/lib/jvm at all.

local M = {}

local mason_root = vim.fn.stdpath("data") .. "/mason/packages"

-- BUG FIX (mine, twice over):
--
-- (a) An ERROR-level vim.notify raised from inside a FileType autocmd
--     ABORTS the autocmd chain. Neovim surfaces it as "Vim(append):<your
--     message>" and the buffer load fails -- which is why neo-tree threw
--     a traceback just trying to open AuthController.java. A diagnostic
--     message should never prevent the file from opening. vim.schedule
--     defers it to the main loop, outside the autocmd.
--
-- (b) Same message shown once per Java file opened is noise. Keyed so
--     each distinct problem reports a single time per session.
local notified = {}

local function notify_once(key, msg, level)
  if notified[key] then
    return
  end
  notified[key] = true
  vim.schedule(function()
    vim.notify(msg, level or vim.log.levels.WARN, { title = "jdtls" })
  end)
end

-- JDK discovery ----------------------------------------------------
--
-- SIMPLIFIED on the minimal branch: $JAVA_HOME is the source of truth.
--
-- This used to enumerate every JDK on the machine (java_home -V, a
-- `java -version` spawn per candidate, Homebrew and SDKMAN globs), cache
-- the result to disk keyed on the jdtls jar name, and read the server's
-- OSGi manifest to discover its minimum version. All of that existed to
-- answer one question -- "which JVM runs jdtls?" -- and it is not the
-- question you actually care about.
--
-- What you care about is which JDK your PROJECT uses, and $JAVA_HOME
-- already says that. So:
--
--   * $JAVA_HOME is the project runtime, handed to Eclipse as
--     `java.configuration.runtimes`. Change it in your shell, restart
--     Neovim, done.
--
--   * jdtls itself needs JDK 21+ to RUN. That is a hard requirement of
--     the server (its manifest declares
--     `osgi.ee=JavaSE, version=21`), not a preference -- on an older JVM
--     the launcher dies inside OSGi bundle activation and you get
--     "exit code 13" with nothing useful in lsp.log.
--
-- So we use $JAVA_HOME when it is new enough, and otherwise fall back to
-- the newest JDK `/usr/libexec/java_home` reports -- ONE subprocess, no
-- caching, no per-JDK probing. Running the server on a different JVM
-- from the one your project targets is normal and supported; that is
-- exactly what the `runtimes` table is for.
--
-- Escape hatch: vim.g.jdtls_java_home overrides both.

-- jdtls's own requirement. Bump only if the server does.
local JDTLS_MIN_JAVA = 21

-- Eclipse only recognises execution environments it ships definitions
-- for. Handing it a "JavaSE-26" it has never heard of makes it log a
-- config error and ignore the whole runtimes block. Raise when jdtls
-- gains support for a newer release.
local MAX_EE = 25

local function trim(x)
  return (x:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function probe_version(home)
  local bin = home .. "/bin/java"
  if vim.fn.executable(bin) ~= 1 then
    return nil
  end
  -- `java -version` writes to stderr, hence 2>&1.
  local out = vim.fn.system(vim.fn.shellescape(bin) .. " -version 2>&1")
  -- Handles both "1.8.0_402" and "21.0.3".
  return tonumber(out:match('version "1%.(%d+)') or out:match('version "(%d+)'))
end

-- Session memo. `probe_version` boots a JVM (~100 ms), and both
-- detect_runtimes() and launcher_java() need the answer -- uncached that is
-- ~120 ms of JVM spawns per Java buffer, all of it returning the same thing.
-- $JAVA_HOME cannot change inside a running Neovim, so one lookup is enough.
-- No disk cache and no :Rescan command: this is cheap enough not to need them.
local memo = {}

--- The JDK $JAVA_HOME points at, or nil.
--- @return string|nil home, number|nil version
local function java_home_jdk()
  if memo.jh ~= nil then
    return memo.jh[1], memo.jh[2]
  end
  local home = vim.g.jdtls_java_home and vim.fn.expand(vim.g.jdtls_java_home) or vim.env.JAVA_HOME
  if not home or home == "" or vim.fn.isdirectory(home) ~= 1 then
    memo.jh = {}
    return nil, nil
  end
  home = home:gsub("/$", "")
  memo.jh = { home, probe_version(home) }
  return memo.jh[1], memo.jh[2]
end

--- A JDK that can run jdtls, or nil. Only called when $JAVA_HOME can't.
---
--- Asks macOS rather than globbing: `java_home -v 21` returns exactly the
--- 21.x JDK, and `-v 21+` returns the NEWEST at or above 21.
---
--- We try the exact version first on purpose. jdtls is built against one
--- LTS, and Eclipse's OSGi runtime can refuse a JVM newer than it knows
--- about -- which surfaces as "exit code 13" with a clean-looking stderr,
--- because the real error happens during bundle activation and only ever
--- lands in the workspace .metadata/.log. Measured on this machine: Java
--- 17 cannot boot it, 21 and 26 both can. 26 working today is luck, not a
--- guarantee, so prefer the version jdtls actually targets.
--- @return string|nil home, number|nil version
local function newest_supported_jdk()
  if vim.fn.executable("/usr/libexec/java_home") ~= 1 then
    return nil, nil
  end
  if memo.alt ~= nil then
    return memo.alt[1], memo.alt[2]
  end
  for _, want in ipairs({ tostring(JDTLS_MIN_JAVA), JDTLS_MIN_JAVA .. "+" }) do
    local home = trim(vim.fn.system({ "/usr/libexec/java_home", "-v", want }))
    if vim.v.shell_error == 0 and home ~= "" and vim.fn.isdirectory(home) == 1 then
      memo.alt = { home, probe_version(home) }
      return memo.alt[1], memo.alt[2]
    end
  end
  memo.alt = {}
  return nil, nil
end

--- `runtimes` for jdtls: what your PROJECT compiles against.
--- Just $JAVA_HOME -- one entry, because one is what you set.
local function detect_runtimes()
  local home, ver = java_home_jdk()
  -- A JRE is not a valid Eclipse runtime; it needs javac.
  if not (home and ver and ver >= 8 and ver <= MAX_EE) then
    return {}
  end
  if vim.fn.executable(home .. "/bin/javac") ~= 1 then
    return {}
  end
  return { {
    name = ver <= 8 and "JavaSE-1.8" or ("JavaSE-" .. ver),
    path = home,
  } }
end

--- The `java` binary that RUNS jdtls. Must be >= JDTLS_MIN_JAVA.
--- @return string|nil
local function launcher_java()
  local home, ver = java_home_jdk()

  if home and ver and ver >= JDTLS_MIN_JAVA then
    return home .. "/bin/java"
  end

  -- $JAVA_HOME is unset, or too old to run the server. Fall back.
  --
  -- SILENT on purpose. This used to announce the split on every session
  -- ("$JAVA_HOME is Java 17, but jdtls needs 21+..."), which is noise: on a
  -- machine whose JAVA_HOME is an older LTS the condition is permanent and
  -- correct, so the message reported normal operation forever. Only genuine
  -- failures below get a notification.
  --
  -- To see which JVM was chosen: :AjayDoctor, or
  --   :lua vim.print(require("ajay.jdtls").detected_jdks())
  local alt, alt_ver = newest_supported_jdk()
  if alt and alt_ver then
    return alt .. "/bin/java"
  end

  -- Nothing usable anywhere. Fail with something actionable rather than
  -- letting the launcher die with a clean-looking "exit code 13".
  notify_once(
    "no-jdk",
    table.concat({
      ("jdtls needs JDK %d+ to run, and none was found."):format(JDTLS_MIN_JAVA),
      "",
      home and ("$JAVA_HOME = " .. home .. (ver and (" (Java %d)"):format(ver) or " (version unreadable)"))
        or "$JAVA_HOME is not set.",
      "",
      ("  brew install --cask zulu@%d"):format(JDTLS_MIN_JAVA),
      "",
      "Or point at one directly:",
      '  vim.g.jdtls_java_home = "/path/to/jdk/Contents/Home"',
    }, "\n"),
    vim.log.levels.ERROR
  )
  return nil
end

--- Every JDK this module knows about. Used by :AjayDoctor.
--- @return table[] list of { version, path, is_launcher }
function M.detected_jdks()
  local out = {}
  local home, ver = java_home_jdk()
  if home then
    table.insert(out, { ver or 0, home, ver ~= nil and ver >= JDTLS_MIN_JAVA })
  end
  if not (ver and ver >= JDTLS_MIN_JAVA) then
    local alt, alt_ver = newest_supported_jdk()
    if alt and alt ~= home then
      table.insert(out, { alt_ver or 0, alt, true })
    end
  end
  return out
end

-- Decode the JDK major version from the incubator-module warning jdtls
-- prints on startup. Handy because the warning is often the ONLY clue in
-- lsp.log about which JVM actually launched:
--   foreign + vector          -> 17 or 18
--   concurrent + vector       -> 19 or 20
--   vector only               -> 21+
M.incubator_hint = [[
lsp.log "Using incubator modules" line decodes to:
  jdk.incubator.foreign    present -> JDK 17/18  (too old for jdtls)
  jdk.incubator.concurrent present -> JDK 19/20  (too old for jdtls)
  jdk.incubator.vector only        -> JDK 21+    (good)
]]

-- Lombok -----------------------------------------------------------

local function find_lombok()
  local jar_paths = {
    mason_root .. "/jdtls/lombok.jar",
    vim.fn.expand("~/.local/share/lombok/lombok.jar"),
  }
  for _, path in ipairs(jar_paths) do
    if vim.fn.filereadable(path) == 1 then
      return path
    end
  end
  local m2 = vim.fn.expand("~/.m2/repository/org/projectlombok/lombok")
  local jars = vim.fn.glob(m2 .. "/*/lombok-*.jar", true, true)
  table.sort(jars)
  if #jars > 0 then
    return jars[#jars]
  end
  return nil
end

-- Bundles (debug + test) -------------------------------------------

local function collect_bundles()
  local bundles = {}
  -- Direct path construction. mason 2.0 dropped pkg:get_install_path(),
  -- and the old pcall around it swallowed the failure without a word.
  local patterns = {
    "/java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar",
    "/java-test/extension/server/*.jar",
  }
  for _, pat in ipairs(patterns) do
    for _, jar in ipairs(vim.fn.glob(mason_root .. pat, true, true)) do
      -- java-test ships a runner jar that must NOT go in bundles
      if not jar:match("runner%-jar%-with%-dependencies%.jar$") then
        table.insert(bundles, jar)
      end
    end
  end
  return bundles
end

-- Main -------------------------------------------------------------

local function start_jdtls(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  -- BUG FIX (found benchmarking against a real multi-module Gradle
  -- project, kafka): bigfile.lua flags oversized buffers at BufReadPre,
  -- then -- once an LSP actually attaches -- detaches it again on
  -- LspAttach. That is one buffer-detach too late for jdtls specifically.
  --
  -- start_or_attach() had already spawned a full JDT LS server and handed
  -- it this project's root_dir before the detach ran, so the server began
  -- importing the whole Gradle build for a file nobody meant to index.
  -- Worse: nvim-jdtls's own reuse check looks at LIVE BUFFER ATTACHMENTS
  -- to decide whether a server for this root_dir is already running. A
  -- client detached-but-not-stopped is invisible to that check, so the
  -- NEXT normal Java file opened in the same project started a SECOND
  -- server against the SAME `-data` workspace directory. Two JDT LS
  -- processes writing the same on-disk index concurrently is how one of
  -- them hit OutOfMemoryError mid-write, corrupted the index file, and
  -- both were then stuck in an infinite reimport-crash loop -- multiple
  -- GB of RAM, no forward progress, workspace unusable until wiped
  -- (:JdtlsWipeWorkspace).
  --
  -- Skip starting jdtls at all when the buffer will be detached, before
  -- any of that can happen, instead of starting it and cleaning up after.
  --
  -- Gated on `bigfile_no_lsp`, not `bigfile`. The failure above is caused
  -- entirely by the DETACH: a client that is detached-but-not-stopped is
  -- invisible to nvim-jdtls's reuse check. A merely large Java file now
  -- keeps its server (bigfile.lua only detaches past lsp_max_bytes, or on a
  -- pathological single-line file), so nothing detaches, no second server
  -- is ever spawned, and the whole failure mode cannot arise. When the flag
  -- IS set the detach does happen -- which is precisely when this guard
  -- needs to fire.
  if vim.b[bufnr].bigfile_no_lsp then
    return
  end

  local jdtls_ok, jdtls = pcall(require, "jdtls")
  if not jdtls_ok then
    notify_once("no-plugin", "nvim-jdtls not available", vim.log.levels.WARN)
    return
  end

  local jdtls_path = mason_root .. "/jdtls"
  if vim.fn.isdirectory(jdtls_path) == 0 then
    notify_once("not-installed", "jdtls not installed - run :MasonInstall jdtls", vim.log.levels.ERROR)
    return
  end

  -- Build markers FIRST, .git LAST. The old order put .git first, which
  -- in any repo whose git root differs from the Maven/Gradle module root
  -- made jdtls index the wrong directory. That shows up as a permanently
  -- "incomplete classpath" and no Spring symbols.
  local root_dir = require("jdtls.setup").find_root({
    "mvnw",
    "gradlew",
    "pom.xml",
    "build.gradle",
    "build.gradle.kts",
    "settings.gradle",
    "settings.gradle.kts",
    ".git",
  })
  if not root_dir or root_dir == "" then
    return
  end

  -- Keyed off the resolved root, not getcwd(). Two projects opened from
  -- the same parent no longer share (and corrupt) one workspace.
  local project_name = vim.fn.fnamemodify(root_dir, ":p:h:t")
  local workspace = vim.fn.stdpath("data") .. "/jdtls-workspace/" .. project_name
  vim.fn.mkdir(workspace, "p")

  local launcher = vim.fn.glob(jdtls_path .. "/plugins/org.eclipse.equinox.launcher_*.jar", true, true)[1]
  if not launcher then
    notify_once("no-launcher", "jdtls launcher jar missing - :MasonInstall jdtls", vim.log.levels.ERROR)
    return
  end

  local os_config = "config_linux"
  if vim.fn.has("mac") == 1 then
    local arch = (vim.uv or vim.loop).os_uname().machine
    os_config = (arch == "arm64" or arch == "aarch64") and "config_mac_arm" or "config_mac"
  elseif vim.fn.has("win32") == 1 then
    os_config = "config_win"
  end
  if vim.fn.isdirectory(jdtls_path .. "/" .. os_config) == 0 then
    for _, alt in ipairs({ "config_mac_arm", "config_mac", "config_linux" }) do
      if vim.fn.isdirectory(jdtls_path .. "/" .. alt) == 1 then
        os_config = alt
        break
      end
    end
  end

  local java_bin = launcher_java()
  if not java_bin then
    notify_once("no-jdk", "No JDK found. brew install openjdk@21", vim.log.levels.ERROR)
    return
  end

  local cmd = {
    java_bin,
    "-Declipse.application=org.eclipse.jdt.ls.core.id1",
    "-Dosgi.bundles.defaultStartLevel=4",
    "-Declipse.product=org.eclipse.jdt.ls.core.product",
    "-Dlog.protocol=true",
    -- WAS "-Dlog.level=ALL", i.e. maximum verbosity, which makes jdtls
    -- write every debug message it has for the whole indexing run. On
    -- kafka that is a large, continuously-appended file and the CPU to
    -- format it, in exchange for output nobody reads unless something is
    -- broken. WARNING keeps the errors that :JdtlsLog exists to show.
    -- Set vim.g.jdtls_debug = true for the old behaviour.
    vim.g.jdtls_debug and "-Dlog.level=ALL" or "-Dlog.level=WARNING",
    -- ── HEAP AND GC ──────────────────────────────────────────────
    --
    -- MEASURED on kafka, warm workspace, with the old "-Xmx4g" and no GC
    -- flags: peak 1673 MB RSS at 277% CPU, then the heap SAT at 1431 MB
    -- for a full minute at 0% CPU before anything was collected.
    --
    -- That idle plateau is the whole problem. The JVM's default
    -- GCTimeRatio is 99, i.e. "spend at most 1% of time collecting" --
    -- tuned for throughput on a server, not for an editor sidecar. Given
    -- a 4 GB ceiling it simply had no reason to give memory back.
    --
    -- History worth keeping: -Xmx was raised to 4g earlier because 2g hit
    -- an OutOfMemoryError on kafka. That OOM was NOT a sizing problem --
    -- it was the duplicate-server bug (two jdtls processes writing one
    -- workspace, see start_jdtls above), which is fixed. The ceiling was
    -- treating a symptom.
    --
    --   GCTimeRatio=4          spend up to 20% of time in GC, not 1%
    --   AdaptiveSizePolicyWeight=90  weight recent behaviour, shrink fast
    --   UseParallelGC          smaller footprint than G1 for this shape
    --   disableMemoryMapping   jdtls opens hundreds of jars; mmap'ing
    --                          them inflates RSS for no gain here
    --   -Xms100m               start small instead of jdtls's own -Xms1G
    --
    -- 2g, not 1g, and that was measured rather than guessed. At -Xmx1g a
    -- cold kafka import sat pinned at 1.0-1.2 GB RSS for 196 s and had
    -- still not finished -- the heap was permanently full, so the JVM
    -- spent its time collecting instead of working. At 2g the same import
    -- finished by ~126 s and then fell to 47 MB. Squeezing the ceiling
    -- traded a slightly lower peak for a much longer, hotter import.
    "-Xms100m",
    "-Xmx" .. (vim.g.jdtls_max_heap or "2g"),
    "-XX:+UseParallelGC",
    "-XX:GCTimeRatio=4",
    "-XX:AdaptiveSizePolicyWeight=90",
    "-Dsun.zip.disableMemoryMapping=true",
    "--add-modules=ALL-SYSTEM",
    "--add-opens",
    "java.base/java.util=ALL-UNNAMED",
    "--add-opens",
    "java.base/java.lang=ALL-UNNAMED",
  }

  -- Lombok must be a javaagent on the jdtls JVM itself, before -jar.
  local lombok = find_lombok()
  if lombok then
    table.insert(cmd, "-javaagent:" .. lombok)
  end
  -- No warning when it is missing. Opening a file should not lecture you
  -- about a jar you may not need: without Lombok, a project that uses
  -- @Data/@Getter reports "cannot find symbol" on the generated methods --
  -- which is a visible diagnostic in the buffer, not a silent failure. If
  -- you hit that, :AjayDoctor and docs/jdtls.md have the one-line fix.

  vim.list_extend(cmd, {
    "-jar",
    launcher,
    "-configuration",
    jdtls_path .. "/" .. os_config,
    "-data",
    workspace,
  })

  local capabilities = vim.lsp.protocol.make_client_capabilities()
  local cmp_ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
  if cmp_ok then
    capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
  end

  local extended = vim.deepcopy(jdtls.extendedClientCapabilities or {})
  extended.resolveAdditionalTextEditsSupport = true

  jdtls.start_or_attach({
    cmd = cmd,
    root_dir = root_dir,
    capabilities = capabilities,
    flags = { allow_incremental_sync = true },

    -- SILENCE THE STARTUP CHATTER.
    --
    -- nvim-jdtls ships a default `language/status` handler (setup.lua, the
    -- `status_callback` local) that does a raw
    --
    --   :echohl Function | echo "<message>" | echohl None
    --
    -- for every status notification jdtls sends -- "Init...", "OK",
    -- "Ready", "ServiceReady", plus a "Starting Java Language Server"
    -- repeat. That is 6-8 lines flashing past on every Java file, reporting
    -- nothing you can act on.
    --
    -- setup.lua does `config.handlers["language/status"] or status_callback`,
    -- so supplying our own REPLACES the noisy default. The important part is
    -- that nvim-jdtls wraps whatever we pass: its own ServiceReady logic
    -- (fetching org.eclipse.jdt.ls.core.sourcePaths) lives in the wrapper,
    -- outside this handler, so silencing the echo does not disable it.
    --
    -- Errors still surface: real failures come through window/showMessage
    -- and the diagnostics pipeline, not through language/status.
    handlers = {
      ["language/status"] = function(_, result)
        -- Record it for :JdtlsLog-style debugging without drawing anything.
        if vim.g.jdtls_debug and result then
          vim.notify(
            ("[jdtls status] %s: %s"):format(tostring(result.type), tostring(result.message)),
            vim.log.levels.DEBUG,
            { title = "jdtls" }
          )
        end
      end,
    },

    init_options = {
      bundles = collect_bundles(),
      extendedClientCapabilities = extended,
    },
    settings = {
      java = {
        -- Source jars for EVERY dependency, downloaded and indexed up
        -- front. On a project with kafka's dependency tree that is a large
        -- share of the 587 MB workspace index and of the memory spent
        -- building it -- paid on every project, whether or not you ever
        -- read a library's source.
        --
        -- Navigation into libraries still works with this off:
        -- includeDecompiledSources below decompiles on demand, so `gd`
        -- into a dependency lands on readable code (without the original
        -- comments). Set vim.g.jdtls_download_sources = true to go back.
        eclipse = { downloadSources = vim.g.jdtls_download_sources == true },
        maven = { downloadSources = vim.g.jdtls_download_sources == true },
        configuration = {
          updateBuildConfiguration = "interactive",
          -- Populated from whatever JDKs actually exist on THIS machine.
          -- Empty here meant jdtls assumed its own runtime for every
          -- project, so a Boot 3 app targeting 17 running under 21 threw
          -- compliance errors that looked like broken code.
          runtimes = detect_runtimes(),
        },
        implementationsCodeLens = { enabled = true },
        -- A reference count on every method means a PROJECT-WIDE search
        -- per method in the visible buffer, recomputed as you scroll.
        -- Implementations are a type-hierarchy lookup and far cheaper, so
        -- that one stays. Set vim.g.jdtls_references_codelens = true if
        -- you want the counts back.
        referencesCodeLens = { enabled = vim.g.jdtls_references_codelens == true },
        -- Cap the background compiler's parallelism. Left at the default
        -- it will happily saturate every core on a 20-module build, which
        -- is what put CPU at 277% in the measurement above.
        maxConcurrentBuilds = 1,
        references = { includeDecompiledSources = true },
        format = { enabled = true },
        signatureHelp = { enabled = true, description = { enabled = true } },
        contentProvider = { preferred = "fernflower" },
        import = {
          gradle = {
            enabled = true,
            wrapper = { enabled = true },
            -- ── THE ACTUAL MEMORY HOG ────────────────────────────
            --
            -- jdtls imports a Gradle project through the Tooling API,
            -- which starts a **separate Gradle daemon JVM**. MEASURED on
            -- kafka: that daemon peaked at 2046 MB, settled at 1785 MB
            -- at 0% CPU, and was STILL RUNNING after Neovim exited.
            -- jdtls's own process, by comparison, settles under 100 MB.
            --
            -- It inherits its JVM args from the PROJECT's
            -- gradle.properties, and kafka's says:
            --     org.gradle.jvmargs=-Xmx4g -Xss4m -XX:+UseParallelGC
            -- so the daemon had a 4 GB ceiling and the same "no reason to
            -- collect" behaviour the main heap had.
            --
            -- These args override that **for jdtls's import only**. The
            -- project's gradle.properties is untouched, so `./gradlew
            -- build` in a terminal still gets the full 4 GB it asks for --
            -- a real build should be allowed to be fast; a background
            -- model-import for an editor should not cost 2 GB.
            --
            -- idletimeout caps how long it lingers afterwards (Gradle's
            -- default is 3 hours).
            -- --no-daemon makes the Tooling API use a SINGLE-USE daemon:
            -- it still forks a JVM to read the build model, but that JVM
            -- exits when the import finishes instead of idling for three
            -- hours. Costs a slower re-import (no warm daemon), which is
            -- fine because updateBuildConfiguration is "interactive" --
            -- re-imports happen when you ask, not on every keystroke.
            arguments = "--no-daemon",
            jvmArguments = table.concat({
              "-Xmx" .. (vim.g.jdtls_gradle_max_heap or "1g"),
              "-Xms100m",
              "-XX:+UseParallelGC",
              "-XX:GCTimeRatio=4",
              "-XX:AdaptiveSizePolicyWeight=90",
              "-Dorg.gradle.daemon.idletimeout=" .. (vim.g.jdtls_gradle_idle_ms or 900000),
            }, " "),
          },
          maven = { enabled = true },
        },
        completion = {
          favoriteStaticMembers = {
            "org.springframework.boot.SpringApplication.run",
            "org.springframework.beans.factory.annotation.Autowired",
            "org.springframework.web.bind.annotation.*",
            "org.springframework.data.jpa.repository.*",
            "org.junit.jupiter.api.Assertions.*",
            "org.junit.jupiter.api.Assumptions.*",
            "org.mockito.Mockito.*",
            "org.mockito.ArgumentMatchers.*",
            "java.util.Objects.requireNonNull",
            "java.util.Objects.requireNonNullElse",
            "java.util.stream.Collectors.*",
          },
          filteredTypes = {
            "com.sun.*",
            "io.micrometer.shaded.*",
            "java.awt.*",
            "jdk.*",
            "sun.*",
          },
          -- jakarta added: Spring Boot 3 moved off javax entirely, so
          -- without it your jakarta.* imports sort into the wrong group
          -- on every organize-imports.
          importOrder = { "java", "javax", "jakarta", "org", "com" },
        },
        sources = {
          organizeImports = { starThreshold = 9999, staticStarThreshold = 9999 },
        },
        codeGeneration = {
          toString = {
            template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}",
          },
          useBlocks = true,
          hashCodeEquals = { useJava7Objects = true, useInstanceof = true },
        },
      },
    },

    on_attach = function(_, bufnr)
      pcall(jdtls.setup_dap, { hotcodereplace = "auto" })

      -- NOTE: the old on_attach re-mapped gd/gr/K/<leader>rn/<leader>ca
      -- and <leader>lf. Those are all handled by the shared LspAttach
      -- autocmd in lsp.lua now, and <leader>lf belongs to conform.
      -- Only Java-specific bindings live here.
      local function map(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
      end

      map("n", "<leader>jo", jdtls.organize_imports, "Java: organize imports")
      map("n", "<leader>jv", jdtls.extract_variable, "Java: extract variable")
      map("v", "<leader>jv", function()
        jdtls.extract_variable(true)
      end, "Java: extract variable")
      map("n", "<leader>jc", jdtls.extract_constant, "Java: extract constant")
      map("v", "<leader>jc", function()
        jdtls.extract_constant(true)
      end, "Java: extract constant")
      map("v", "<leader>jm", function()
        jdtls.extract_method(true)
      end, "Java: extract method")
      map("n", "<leader>jt", jdtls.test_class, "Java: test class")
      map("n", "<leader>jn", jdtls.test_nearest_method, "Java: test nearest method")
      map("n", "<leader>ju", "<cmd>JdtUpdateConfig<CR>", "Java: update project config")
    end,
  })
end

function M.setup()
  local group = vim.api.nvim_create_augroup("ajay_jdtls", { clear = true })

  -- For every Java buffer opened from here on.
  --
  -- Passed as a plain `callback = start_jdtls` before, which handed the
  -- function the autocmd's ARGS TABLE as its bufnr argument, not a
  -- number -- `vim.b[bufnr]` would have errored the moment the bigfile
  -- guard above was added. Needs the explicit wrapper to pass args.buf.
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "java",
    callback = function(args)
      start_jdtls(args.buf)
    end,
  })

  -- And for the buffer that triggered this load in the first place --
  -- its FileType event already fired before lazy pulled the plugin in.
  if vim.bo.filetype == "java" then
    start_jdtls()
  end

  -- Open the Eclipse-side log. This is where "worked yesterday" answers
  -- live: OOM kills, classpath resolution failures, and Maven import
  -- errors are logged here and NOWHERE in Neovim's own :messages.
  vim.api.nvim_create_user_command("JdtlsLog", function()
    local root = require("jdtls.setup").find_root({ "pom.xml", "build.gradle", ".git" })
    local name = vim.fn.fnamemodify(root or vim.fn.getcwd(), ":p:h:t")
    local log = vim.fn.stdpath("data") .. "/jdtls-workspace/" .. name .. "/.metadata/.log"
    if vim.fn.filereadable(log) == 0 then
      vim.notify("No jdtls log yet at:\n" .. log, vim.log.levels.WARN)
      return
    end
    vim.cmd("tabnew " .. vim.fn.fnameescape(log))
    vim.cmd("normal! G")
  end, { desc = "Open this project's jdtls (Eclipse) log" })

  vim.api.nvim_create_user_command("JdtlsWipeWorkspace", function()
    local root = require("jdtls.setup").find_root({ "pom.xml", "build.gradle", ".git" })
    local name = vim.fn.fnamemodify(root or vim.fn.getcwd(), ":p:h:t")
    local ws = vim.fn.stdpath("data") .. "/jdtls-workspace/" .. name
    vim.fn.delete(ws, "rf")
    vim.notify("Wiped jdtls workspace: " .. name .. "\nRestart nvim to re-index.", vim.log.levels.INFO)
  end, { desc = "Delete this project's jdtls workspace (fixes stale classpath errors)" })
end

return M
