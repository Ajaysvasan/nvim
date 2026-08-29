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

-- BUG FIX (mine): the first version of this only looked at Homebrew's
-- openjdk@N formula paths plus a glob over /Library/Java/JavaVirtualMachines
-- with a fragile version regex. That silently misses:
--   * Azul Zulu, Temurin, Corretto, GraalVM, Microsoft builds
--   * SDKMAN, jenv, asdf and mise installs (all outside /Library)
--   * anything whose directory name doesn't match my regex
-- Switching your runtime from Homebrew OpenJDK to Zulu was enough to make
-- the detection blind, which is why it reported "Found Java 17" from the
-- PATH fallback instead of finding your 21.
--
-- The authoritative source on macOS is /usr/libexec/java_home. It knows
-- about every properly installed JDK regardless of vendor.
--
-- Escape hatch: set vim.g.jdtls_java_home to a JDK home path in
-- options.lua and everything below is skipped.

local SEARCH_VERSIONS = { 25, 24, 23, 22, 21, 17, 11, 8 }

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
  -- Handles both "1.8.0_402" and "21.0.3"
  local major = out:match('version "1%.(%d+)') or out:match('version "(%d+)')
  return tonumber(major)
end

-- MEMOISED, and it has to be. This function shells out: one
-- `/usr/libexec/java_home -V`, plus a `java -version` per candidate whose
-- version cannot be read any other way. On this machine a single call was
-- 1 java_home + 2 java spawns, and `java -version` costs ~150 ms because it
-- boots a JVM to print one line.
--
-- It is called from detect_runtimes(), launcher_java() and :AjayDoctor, so an
-- uncached version ran the whole probe FOUR times per Java buffer opened --
-- 13 subprocesses, ~760 ms of blocking work before the file was editable, and
-- all four passes returned exactly the same answer.
--
-- The set of installed JDKs does not change while Neovim is running. Cache it
-- for the session; :JdtlsRescanJDKs busts it after installing a new JDK.
local cached_jdks = nil

local function java_home_candidates()
  if cached_jdks then
    return cached_jdks
  end

  local c = {}
  local seen = {}

  local function add(ver, home)
    if not home or home == "" then
      return
    end
    if vim.fn.executable(home .. "/bin/java") ~= 1 then
      return
    end

    -- Dedupe on the RESOLVED path, not the literal one. On a Linux distro
    -- /usr/lib/jvm is mostly symlinks: here 16 entries -- java, java-21,
    -- java-21-openjdk, java-openjdk, jre, jre-21, jre-21-openjdk, ... --
    -- resolve to just 3 real JDKs. Keying on the literal path counted each
    -- alias separately, so the same JDK was probe_version()'d up to five
    -- times (a JVM spawn each) and :JdtlsRescanJDKs printed 16 lines of
    -- mostly the same thing.
    local real = (vim.uv or vim.loop).fs_realpath(home) or home
    if seen[real] then
      return
    end
    seen[real] = true

    -- JDK or JRE? `bin/java` alone does not tell you: a headless JRE has
    -- it too. It matters because detect_runtimes() below feeds these to
    -- Eclipse as `java.configuration.runtimes`, and Eclipse needs a JDK
    -- there -- a JRE has no compiler and no src.zip, so a project pinned
    -- to that release gets unresolved JDK symbols and no source
    -- navigation into the standard library.
    --
    -- This is not hypothetical on Fedora: java-25-openjdk, jre-25,
    -- jre-25-openjdk and jre-openjdk are ALL javac-less here, so 25 had
    -- no JDK at all and the runtime entry pointed at a JRE.
    local has_javac = vim.fn.executable(home .. "/bin/javac") == 1

    -- Store the RESOLVED path, not the alias that happened to be globbed
    -- first. Otherwise the winner of the dedupe is an arbitrary symlink
    -- name, and reports read absurdly: /usr/lib/jvm/java-25 is a symlink
    -- to java-latest-openjdk, so it shows as "ver=26 java-25".
    --
    -- Trust the binary over the directory name. Vendor dir naming is not
    -- something to parse: zulu-21.jdk, temurin-21.jdk, jdk-21.0.3+9,
    -- graalvm-community-openjdk-21... all differ.
    table.insert(c, { ver or probe_version(real) or 0, real, has_javac })
  end

  -- Explicit override always wins.
  if vim.g.jdtls_java_home then
    add(nil, vim.fn.expand(vim.g.jdtls_java_home))
  end

  if vim.fn.has("mac") == 1 then
    -- Enumerate with -V rather than probing `-v <N>` for a hardcoded list
    -- of versions. My previous attempt asked only about 8/11/17/21..25,
    -- so a JDK 26 install was invisible to it. Parsing the full listing
    -- means new Java releases need no code change here.
    -- NOTE: -V writes to stderr, hence the 2>&1.
    if vim.fn.executable("/usr/libexec/java_home") == 1 then
      local listing = vim.fn.system("/usr/libexec/java_home -V 2>&1")
      for line in vim.gsplit(listing, "\n", { trimempty = true }) do
        local ver, home = line:match("^%s*([%d][%d%._]*)%s.*%s(/.+)$")
        if ver and home then
          local major = ver:match("^1%%.(%d+)") or ver:match("^(%d+)")
          add(tonumber(major), home)
        end
      end
    end
    -- Homebrew formula installs are NOT bundles and java_home misses them.
    for _, v in ipairs(SEARCH_VERSIONS) do
      add(v, ("/opt/homebrew/opt/openjdk@%d/libexec/openjdk.jdk/Contents/Home"):format(v))
      add(v, ("/usr/local/opt/openjdk@%d/libexec/openjdk.jdk/Contents/Home"):format(v))
    end
    add(nil, "/opt/homebrew/opt/openjdk/libexec/openjdk.jdk/Contents/Home")
    for _, dir in ipairs(vim.fn.glob("/Library/Java/JavaVirtualMachines/*/Contents/Home", true, true)) do
      add(nil, dir)
    end
  else
    for _, dir in ipairs(vim.fn.glob("/usr/lib/jvm/*", true, true)) do
      add(nil, dir)
    end
  end

  -- Version managers, both platforms. These live in $HOME and are
  -- invisible to java_home and to any /usr or /Library glob.
  local vm_globs = {
    "~/.sdkman/candidates/java/*",
    "~/.jenv/versions/*",
    "~/.asdf/installs/java/*",
    "~/.local/share/mise/installs/java/*",
  }
  for _, g in ipairs(vm_globs) do
    for _, dir in ipairs(vim.fn.glob(vim.fn.expand(g), true, true)) do
      add(nil, dir)
      -- SDKMAN on macOS sometimes nests the bundle layout.
      add(nil, dir .. "/Contents/Home")
    end
  end

  -- Whatever JAVA_HOME points at, last.
  if vim.env.JAVA_HOME then
    add(nil, vim.env.JAVA_HOME)
  end

  cached_jdks = c
  return c
end

-- Exposed so :AjayDoctor can show exactly what was found.
M.detected_jdks = java_home_candidates

-- Drop the cache above. Needed only after installing or removing a JDK
-- mid-session -- otherwise the scan result is stable for the whole session.
vim.api.nvim_create_user_command("JdtlsRescanJDKs", function()
  cached_jdks = nil
  local found = java_home_candidates()
  local lines = {}
  for _, e in ipairs(found) do
    -- JDK vs JRE is shown because only a JDK can serve as an Eclipse
    -- runtime. A version that lists only JRE here is a version your
    -- projects cannot compile against, however many entries it has.
    table.insert(lines, ("  %-4s %-4s %s"):format(e[1], e[3] and "JDK" or "JRE", e[2]))
  end
  vim.notify(
    ("Rescanned. %d JVM%s found (unique real paths):\n%s"):format(
      #found,
      #found == 1 and "" or "s",
      table.concat(lines, "\n")
    ),
    vim.log.levels.INFO,
    { title = "jdtls" }
  )
end, { desc = "Re-scan installed JDKs (after installing a new one)" })

-- Every JDK we can find, as jdtls `runtimes` entries. This is what lets
-- you run jdtls on 21 while a project still compiles against 17.
-- Eclipse only recognises execution environments it ships definitions
-- for. Handing jdtls a "JavaSE-26" it has never heard of makes it log a
-- config error and ignore the whole runtimes block -- including the
-- entries that WERE valid. Capped accordingly; raise MAX_EE when jdtls
-- gains support for a newer release.
local MAX_EE = 25

local function detect_runtimes()
  local seen, runtimes = {}, {}
  for _, entry in ipairs(java_home_candidates()) do
    local ver, path, has_javac = entry[1], entry[2], entry[3]
    -- has_javac is the important condition: a JRE is not a valid Eclipse
    -- runtime. Without this check the FIRST candidate for a version won,
    -- JRE or not, purely on glob order -- which on this machine handed
    -- JavaSE-25 a compiler-less /usr/lib/jvm/java-25-openjdk.
    if ver and ver >= 8 and ver <= MAX_EE and has_javac and vim.fn.isdirectory(path) == 1 and not seen[ver] then
      seen[ver] = true
      table.insert(runtimes, {
        name = ver <= 8 and "JavaSE-1.8" or ("JavaSE-" .. ver),
        path = path,
      })
    end
  end
  return runtimes
end

-- The JDK that RUNS jdtls.
--
-- BUG FIX (mine): the first version of this picked the HIGHEST JDK >= 21
-- it could find. That's wrong. Eclipse JDT LS is built against a specific
-- LTS and its OSGi runtime rejects JVMs newer than it supports -- the
-- launcher then aborts with exit code 13 before any LSP traffic happens.
-- If you have JDK 24/25 installed, "highest wins" hands jdtls a JVM it
-- refuses to run on.
--
-- Preference order is now: 21 (the LTS jdtls targets), then 23, 22, then
-- newer only as a last resort. Your PROJECT's Java version is unaffected
-- by this -- that's driven by `runtimes` below.
-- Ask the INSTALLED jdtls what it needs, instead of hardcoding a version
-- list that goes stale every six months.
--
-- Every OSGi bundle declares its minimum execution environment in its
-- MANIFEST.MF, either as Bundle-RequiredExecutionEnvironment or as an
-- osgi.ee Require-Capability filter. Reading it from the jar means that
-- when Mason upgrades jdtls and the requirement moves from 21 to 25,
-- this picks that up with no edit here.
local FALLBACK_MIN = 21
local cached_min = nil

local function jdtls_required_java()
  if cached_min then
    return cached_min
  end
  cached_min = FALLBACK_MIN

  local jar = vim.fn.glob(mason_root .. "/jdtls/plugins/org.eclipse.jdt.ls.core_*.jar", true, true)[1]
  if not jar or vim.fn.executable("unzip") ~= 1 then
    return cached_min
  end

  local mf = vim.fn.system({ "unzip", "-p", jar, "META-INF/MANIFEST.MF" })
  if vim.v.shell_error ~= 0 then
    return cached_min
  end

  -- MANIFEST.MF wraps at 72 bytes and continues lines with a single
  -- leading space. Unfold before matching or the version can be split
  -- across two lines.
  mf = mf:gsub("\r\n", "\n"):gsub("\n ", "")

  local ee = mf:match("Bundle%-RequiredExecutionEnvironment:%s*JavaSE%-([%d%.]+)")
    or mf:match("osgi%%.ee=JavaSE.-version=([%d%.]+)")

  if ee then
    local major = ee:match("^1%%.(%d+)") or ee:match("^(%d+)")
    if tonumber(major) then
      cached_min = tonumber(major)
    end
  end
  return cached_min
end

local function launcher_java()
  local min = jdtls_required_java()

  local by_version = {}
  for _, entry in ipairs(java_home_candidates()) do
    local ver, path = entry[1], entry[2]
    if ver and ver > 0 and not by_version[ver] and vim.fn.executable(path .. "/bin/java") == 1 then
      by_version[ver] = path .. "/bin/java"
    end
  end

  -- Lowest version at or above the declared minimum. Closest to what
  -- jdtls was actually built and tested against; picking the newest JDK
  -- on the machine is how you end up on a release whose OSGi runtime
  -- jdtls refuses to boot on (exit code 13, clean-looking stderr).
  local usable = {}
  for ver in pairs(by_version) do
    if ver >= min then
      table.insert(usable, ver)
    end
  end
  table.sort(usable)

  if #usable > 0 then
    local ver = usable[1]
    -- More than two releases past the minimum is worth flagging: jdtls
    -- almost certainly predates it.
    if ver > min + 2 then
      notify_once(
        "untested-jdk",
        table.concat({
          ("Running jdtls on Java %d, but it only requires %d."):format(ver, min),
          "",
          "No closer version is installed. jdtls may refuse to boot on a",
          "release this new -- that shows up as 'exit code 13' with",
          "nothing useful in lsp.log.",
          "",
          ("If Java breaks, install %d alongside what you have:"):format(min),
          ("  brew install --cask zulu@%d"):format(min),
          "",
          "They coexist fine; your default `java` is unaffected.",
        }, "\n"),
        vim.log.levels.WARN
      )
    end
    return by_version[ver]
  end
  -- No JDK 21+ anywhere. Do NOT fall back to `java` on PATH and let the
  -- server die -- that produces "exit code 13" with a clean-looking
  -- stderr, because the real UnsupportedClassVersionError happens inside
  -- OSGi bundle activation and only lands in the workspace .metadata/.log.
  -- Fail here with something you can act on instead.
  if vim.fn.executable("java") == 1 then
    local out = vim.fn.system({ "java", "-version" })
    local major = tonumber(out:match('version "(%d+)'))
    if major and major < jdtls_required_java() then
      -- NOTE: :format() only applies to the string literal it is called
      -- on. The previous version chained `.. "...%d..."` AFTER the
      -- format call, so that second %d was never substituted and printed
      -- literally. Build the whole message first, then format once.
      local min = jdtls_required_java()
      local lines = {
        ("jdtls needs JDK %d+ to run. `java` on PATH is %d."):format(min, major),
        "",
        "JDKs I could find on this machine:",
      }
      local found = java_home_candidates()
      if #found == 0 then
        table.insert(lines, "  (none)")
      end
      for _, entry in ipairs(found) do
        table.insert(lines, ("  Java %-3s  %s"):format(entry[1] > 0 and entry[1] or "?", entry[2]))
      end
      vim.list_extend(lines, {
        "",
        ("Your project can still target %d -- this is only the JVM"):format(major),
        "that runs the language server.",
        "",
        ("  brew install --cask zulu@%d     (or: brew install openjdk@%d)"):format(min, min),
        "",
        "Already have a new enough JDK that isn't listed? Point at it directly:",
        ('  vim.g.jdtls_java_home = "/path/to/jdk-%d/Contents/Home"'):format(min),
        "",
        "Run :AjayDoctor for the full list.",
      })
      notify_once("wrong-jdk", table.concat(lines, "\n"), vim.log.levels.ERROR)
      return nil
    end
  end
  return nil
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

local function start_jdtls()
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
    "-Dlog.level=ALL",
    "-Xmx2g",
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
  else
    notify_once(
      "no-lombok",
      "Lombok jar not found. If this project uses @Data/@Getter, jdtls will\n"
        .. "report 'cannot find symbol' for generated methods even though Maven builds.\n"
        .. "Fix: mkdir -p ~/.local/share/lombok && curl -L -o ~/.local/share/lombok/lombok.jar \\\n"
        .. "     https://projectlombok.org/downloads/lombok.jar",
      vim.log.levels.WARN
    )
  end

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
    init_options = {
      bundles = collect_bundles(),
      extendedClientCapabilities = extended,
    },
    settings = {
      java = {
        eclipse = { downloadSources = true },
        maven = { downloadSources = true },
        configuration = {
          updateBuildConfiguration = "interactive",
          -- Populated from whatever JDKs actually exist on THIS machine.
          -- Empty here meant jdtls assumed its own runtime for every
          -- project, so a Boot 3 app targeting 17 running under 21 threw
          -- compliance errors that looked like broken code.
          runtimes = detect_runtimes(),
        },
        implementationsCodeLens = { enabled = true },
        referencesCodeLens = { enabled = true },
        references = { includeDecompiledSources = true },
        format = { enabled = true },
        signatureHelp = { enabled = true, description = { enabled = true } },
        contentProvider = { preferred = "fernflower" },
        import = {
          gradle = { enabled = true, wrapper = { enabled = true } },
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
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "java",
    callback = start_jdtls,
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
