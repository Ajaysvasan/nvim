# `jdtls.lua` — Java language server

[nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls) driving Eclipse JDT
Language Server. Loads on `ft = java`.

This is the most involved module in the config. It handles JDK discovery across
vendors and version managers, Lombok, per-project workspaces, and the debug/test
bundles.

## Load timing

`M.setup()` does two things:

1. Registers a `FileType java` autocmd for **subsequent** buffers
2. Calls `start_jdtls()` directly if the current buffer is already Java

Both are needed. With `ft = "java"` in the spec, by the time lazy loads the
plugin the `FileType` event has **already fired** — an autocmd registered in
`config()` is too late to catch the buffer that triggered the load, so jdtls
never started on the first Java file you opened.

## JDK discovery

**`$JAVA_HOME` is the source of truth.** Set it in your shell, restart Neovim,
done.

This used to be the most complicated part of the file: it enumerated every JDK
on the machine (`java_home -V`, a `java -version` spawn per candidate, plus
Homebrew / SDKMAN / jenv / asdf / mise globs), cached the result to disk keyed
on the jdtls jar filename, and unzipped the server's OSGi manifest to discover
its minimum version. Roughly 490 lines, all of it answering one question —
*"which JVM runs jdtls?"* — which is not the question you actually care about.

### The two questions

They get conflated constantly, and keeping them apart is what makes the simple
version correct:

| Question | Answered by | Typical value |
|---|---|---|
| Which JDK does my **project** compile against? | `$JAVA_HOME` | whatever the project needs |
| Which JVM **runs the language server**? | jdtls's own requirement | 21+ |

The second is not a preference. jdtls's bundle manifest declares
`Require-Capability: osgi.ee;filter:="(&(osgi.ee=JavaSE)(version=21))"`, and on
an older JVM the OSGi container refuses to resolve the bundle. You do not get a
clear error: the launcher dies during bundle activation and surfaces as **exit
code 13** with clean-looking stderr, the real `UnsupportedClassVersionError`
landing only in the workspace `.metadata/.log`.

### What actually happens

1. **Project runtime** — `$JAVA_HOME` is handed to Eclipse as the single
   `java.configuration.runtimes` entry (`JavaSE-17` → that path). It must have a
   `bin/javac`; a JRE is not a valid Eclipse runtime.
2. **Server JVM** — `$JAVA_HOME` if it is 21 or newer. Otherwise one call to
   `/usr/libexec/java_home -v 21`, then `-v 21+` if that finds nothing.

Running the server on a different JVM from the one your project targets is
normal and fully supported — that split is exactly what the `runtimes` table
exists for, and it happens **silently**.

> It used to print a one-time message naming both JVMs. That was removed: on a
> machine whose `$JAVA_HOME` is an older LTS the condition is permanent and
> correct, so the message reported normal operation on every single session.
> To see which JVM was chosen, run `:AjayDoctor` or
> `:lua vim.print(require("ajay.jdtls").detected_jdks())`.

> **On this machine:** `$JAVA_HOME` is Zulu 17, so kafka compiles against
> `JavaSE-17`, and the server runs on Zulu 21. Verified end to end.

## Startup is quiet

Opening a Java file used to flash 6–8 lines past the command line:

```
Init...
0% Starting Java Language Server
45% Starting Java Language Server
OK
100% Starting Java Language Server
Ready
ServiceReady
```

None of it is actionable. It comes from **nvim-jdtls' own default
`language/status` handler** (`setup.lua`, the `status_callback` local), which
does a raw `:echohl Function | echo "<message>" | echohl None` for every status
notification the server sends.

`setup.lua` resolves it as `config.handlers["language/status"] or
status_callback`, so this config supplies its own no-op handler and the noisy
default never runs. The progress percentages go through the same channel, so
they stop too.

**Nothing is lost.** nvim-jdtls *wraps* whatever handler you pass — its own
`ServiceReady` work (fetching `org.eclipse.jdt.ls.core.sourcePaths`) lives in
the wrapper, outside the handler, so silencing the echo does not disable it.
Verified after the change: go-to-definition resolves, cross-module references
return 2886 results on kafka, diagnostics populate.

Real problems still surface — they arrive via `window/showMessage` and the
diagnostics pipeline, not `language/status`. Set `vim.g.jdtls_debug = true` to
route status notifications to `vim.notify` at DEBUG level instead of dropping
them.

### Why `-v 21` before `-v 21+`

`java_home -v 21` returns exactly the 21.x JDK; `-v 21+` returns the **newest**
at or above 21. Asking for the exact version first is deliberate: jdtls is built
against one LTS, and Eclipse's OSGi runtime can reject a JVM newer than it knows
about — the same exit-code-13 failure as above.

Measured on this machine with a full launcher invocation: **Java 17 cannot boot
jdtls; 21 and 26 both can.** So "newest" would work here today — but that is
luck, not a guarantee, and it costs three lines to prefer the version jdtls
actually targets.

### Escape hatch

```lua
vim.g.jdtls_java_home = "/path/to/jdk-21/Contents/Home"
```

Set that in `options.lua` and it overrides `$JAVA_HOME` for **both** roles.

### What went away with the old scanner

`:JdtlsRescanJDKs` (there is no cache left to bust), the on-disk probe cache at
`stdpath("cache")/ajay-jdtls-probe.json`, the manifest-reading minimum-version
lookup, and multi-runtime detection. If you need several runtimes registered at
once — one project on 8, another on 21 — that is the feature this trade gave up;
switch `$JAVA_HOME` per project instead.


### `M.incubator_hint`

A decoder for the "Using incubator modules" line jdtls prints on startup — often
the only clue in `lsp.log` about which JVM actually launched:

| Modules present | JDK |
|---|---|
| `jdk.incubator.foreign` + `vector` | 17/18 — too old |
| `jdk.incubator.concurrent` + `vector` | 19/20 — too old |
| `jdk.incubator.vector` only | 21+ — good |

## Lombok

Searched in order: `mason/packages/jdtls/lombok.jar`,
`~/.local/share/lombok/lombok.jar`, then the newest
`~/.m2/repository/org/projectlombok/lombok/*/lombok-*.jar`.

If found, it is added as `-javaagent:` **on the jdtls JVM itself, before `-jar`**.
That ordering is required — as a plain classpath entry it does nothing.

**No warning is printed when the jar is missing** — opening a file should not
lecture you about a dependency you may not need. The failure is visible in the
buffer anyway: without it, jdtls doesn't see Lombok-generated methods, so you get
**"cannot find symbol: getName()"** on every `@Data` entity while Maven builds
fine. That is the classic "my Spring Boot setup is broken" symptom.

If missing, a one-time warning prints the exact `curl` command to fix it.

## Root detection

Markers, in order:

```
mvnw, gradlew, pom.xml, build.gradle, build.gradle.kts,
settings.gradle, settings.gradle.kts, .git
```

> **Fixed bug:** `.git` used to be **first**. In any repo where the git root
> isn't the Maven module root, jdtls attached to the wrong directory and reported
> a permanently incomplete classpath with no Spring symbols. `.git` is now last.

## Workspaces

One workspace per project at
`stdpath("data")/jdtls-workspace/<project-name>`, where `<project-name>` comes
from the **resolved root**, not `getcwd()`.

> **Fixed bug:** using `getcwd()` meant two projects opened from the same parent
> directory shared one jdtls workspace and corrupted each other's index.

## Bundles (debug + test)

Globbed directly from Mason:

- `java-debug-adapter/extension/server/com.microsoft.java.debug.plugin-*.jar`
- `java-test/extension/server/*.jar` — **excluding** the
  `runner-jar-with-dependencies.jar`, which must not go in bundles

> **Fixed bug:** the old code used `pkg:get_install_path()`, which mason 2.0
> removed. It was wrapped in `pcall`, so it failed **silently** — no debug or
> test bundles loaded, meaning `<leader>jt` and Java debugging quietly did nothing.

Install them with `:MasonInstall java-debug-adapter java-test`.

## JVM arguments

```
-Xmx2g
--add-modules=ALL-SYSTEM
--add-opens java.base/java.util=ALL-UNNAMED
--add-opens java.base/java.lang=ALL-UNNAMED
```

2GB heap is enough for a mid-size Spring Boot project; the `--add-opens` flags
are required for jdtls to run on modern JDKs with the module system enforced.

## Java settings and why

| Setting | Value | Why |
|---|---|---|
| `eclipse.downloadSources`, `maven.downloadSources` | `true` | `gd` into a library shows real source, not decompiled bytecode |
| `updateBuildConfiguration` | `"interactive"` | Asks before re-importing after a `pom.xml` change, rather than re-indexing on every keystroke |
| `configuration.runtimes` | auto-detected | **Was empty**, so jdtls assumed its own runtime for every project — a Boot 3 app targeting 17 running under 21 threw compliance errors that looked like broken code. Now populated from whatever JDKs exist on this machine, capped at `JavaSE-25` (`MAX_EE`) because Eclipse only recognises execution environments it ships definitions for; an unknown `JavaSE-26` makes jdtls log a config error and **ignore the whole runtimes block**, including valid entries |
| `implementationsCodeLens` / `referencesCodeLens` | `enabled` | The IntelliJ-style counts above each class/method. See [lsp.md](lsp.md) — these only *publish*; Neovim has to call `codelens.refresh()`, which `lsp.lua` now does |
| `references.includeDecompiledSources` | `true` | `gr` finds usages inside dependencies |
| `contentProvider.preferred` | `"fernflower"` | Better decompiler output than the default |
| `signatureHelp` with `description` | `enabled` | Parameter docs while typing arguments |
| `completion.favoriteStaticMembers` | Spring, JUnit 5, Mockito, `Objects`, `Collectors` | These get suggested and auto-imported without typing the class first — `run(` completes to `SpringApplication.run` |
| `completion.filteredTypes` | `com.sun.*`, `io.micrometer.shaded.*`, `java.awt.*`, `jdk.*`, `sun.*` | Internal and shaded classes never appear in completion. Without this, `List` offers `java.awt.List`. |
| `completion.importOrder` | `java`, `javax`, `jakarta`, `org`, `com` | **`jakarta` added** — Spring Boot 3 moved off `javax` entirely, so without it your `jakarta.*` imports sort into the wrong group on every organize-imports |
| `sources.organizeImports.starThreshold` | `9999` | Never collapse to a wildcard import |
| `codeGeneration` | `useBlocks`, `hashCodeEquals` with Java 7 `Objects` + `instanceof`, custom `toString` template | Generated code matches modern Java style |

## Keymaps

Buffer-local, registered in `on_attach`. **Only Java-specific bindings live
here** — `gd`, `gr`, `K`, `<leader>rn`, `<leader>ca` come from the shared
`LspAttach` in [lsp.md](lsp.md), and `<leader>lf` belongs to
[conform](conform.md).

| Key | Mode | Action |
|---|---|---|
| `<leader>jo` | n | **Organize imports** — the correct way to clean imports; `google-java-format` is deliberately prevented from touching them |
| `<leader>jv` | n | Extract variable |
| `<leader>jv` | v | Extract variable from selection |
| `<leader>jc` | n | Extract constant |
| `<leader>jc` | v | Extract constant from selection |
| `<leader>jm` | v | Extract method from selection |
| `<leader>jt` | n | Run/debug the test class |
| `<leader>jn` | n | Run/debug the nearest test method |
| `<leader>ju` | n | `:JdtUpdateConfig` — re-read `pom.xml`/`build.gradle` after adding a dependency |

`jdtls.setup_dap({ hotcodereplace = "auto" })` is called on attach, so
[DAP](dap.md) keymaps work in Java too, with hot code replace during a session.

> `<leader>jn` used to collide with a new-Java-file GUI module. That module is
> gone on this branch, so `<leader>jn` is unambiguously "test nearest method".

## Commands

| Command | Action |
|---|---|
| `:JdtlsLog` | Open **this project's** Eclipse-side log (`.metadata/.log`) in a new tab, scrolled to the bottom. This is where "it worked yesterday" answers live: OOM kills, classpath resolution failures and Maven import errors are logged here and **nowhere** in Neovim's `:messages`. |
| `:JdtlsWipeWorkspace` | Delete this project's jdtls workspace. The fix for stale classpath errors that survive a restart. Re-indexes on next launch. |
| `:JdtUpdateConfig` | Plugin built-in — re-import the build config |

## Troubleshooting

| Symptom | Cause |
|---|---|
| "cannot find symbol: getName()" on a `@Data` class | Lombok jar missing |
| Everything red, "incomplete classpath" | Wrong root detected, or the project never imported. Try `:JdtlsWipeWorkspace` then restart. |
| Server exits with code 13 | Wrong JVM version. Run `:AjayDoctor`, install JDK 21. |
| `<leader>jt` does nothing | `java-test` bundle not installed — `:MasonInstall java-test` |
| Imports keep disappearing on save | Should be fixed — check that `conform.lua` still has the `--skip-removing-unused-imports` args |


## Memory and CPU

Opening a Java file in a large Gradle project used to consume **gigabytes**.
Measured on kafka, and the cause was not where it looked.

### It was mostly the Gradle daemon, not jdtls

jdtls imports a Gradle project through the Tooling API, which starts a
**separate Gradle daemon JVM**. Measured on kafka with the original config:

| Process | Peak | At rest | After Neovim exits |
|---|---|---|---|
| **Gradle daemon** | **2046 MB** | **1785 MB** at 0% CPU | **still running** |
| jdtls itself | 1673 MB | 1431 MB for a full minute | exits |

The daemon inherits its JVM args from the **project's** `gradle.properties`, and
kafka's says:

```properties
org.gradle.jvmargs=-Xmx4g -Xss4m -XX:+UseParallelGC
```

So it had a 4 GB ceiling and no reason to give anything back — and it outlived
the editor, because Gradle daemons idle for **three hours** by default.

Two settings fix this, both scoped to **jdtls's import only** — the project's
`gradle.properties` is untouched, so `./gradlew build` in a terminal still gets
its full 4 GB. A real build should be allowed to be fast; a background
model-import for an editor should not cost 2 GB.

- **`java.import.gradle.jvmArguments`** — caps the daemon's heap and makes it
  collect (`-Xmx1g`, `GCTimeRatio=4`).
- **`java.import.gradle.arguments = "--no-daemon"`** — the Tooling API then uses
  a *single-use* daemon, so the JVM stops idling for Gradle's default three
  hours. Costs a slower re-import, which is fine: `updateBuildConfiguration` is
  `"interactive"`, so re-imports happen when you ask, not on every keystroke.

| | Before | After |
|---|---|---|
| Gradle JVM, at rest | 1785 MB | **34 MB** |
| Still there after Neovim exits | 1785 MB | **33 MB** |

Verified the import still succeeds: **0 OOM errors, 71 Gradle projects
imported** on kafka from a wiped workspace.

### The second half: lazy GC

jdtls's own heap showed the same shape — 1431 MB sitting at **0% CPU** for a
minute. The JVM's default `GCTimeRatio` is 99, meaning "spend at most 1% of
time collecting": a throughput setting for a server, not for an editor sidecar.
Given a 4 GB ceiling it simply never collected.

```
-Xms100m -Xmx2g
-XX:+UseParallelGC -XX:GCTimeRatio=4 -XX:AdaptiveSizePolicyWeight=90
-Dsun.zip.disableMemoryMapping=true
```

`GCTimeRatio=4` permits up to 20% of time in GC. `disableMemoryMapping` matters
because jdtls opens hundreds of jars and mmap'ing them inflates RSS for no gain.

After: jdtls decays to **57 MB** instead of holding 1431.

**Together, at idle: ~3.2 GB → ~90 MB.**

### What is *not* fixed: the import peak

jdtls still reaches ~1.4 GB **while importing and indexing**. That is real work —
building the model for 71 Gradle projects — and it lasts a minute or two, not
indefinitely.

Lowering `-Xmx` further does not help, and that was measured rather than
assumed. At `-Xmx1g` a cold kafka import sat pinned at **1.0–1.2 GB RSS for
196 s and had still not finished**: the heap was permanently full, so the JVM
spent its time collecting instead of working. At 2g the same import finished by
~126 s and then fell to 47 MB. Squeezing the ceiling traded a slightly lower
peak for a much longer, hotter import — so 2g stays.

> **`-Xmx` went 4g → 2g, and the history matters.** It was raised to 4g earlier
> because 2g hit an `OutOfMemoryError` on kafka. That OOM was *not* a sizing
> problem — it was the duplicate-server bug (two jdtls processes writing one
> workspace), which is fixed. The ceiling was treating a symptom.

### Other settings changed

| Setting | Now | Why |
|---|---|---|
| `-Dlog.level` | `WARNING` (was `ALL`) | Maximum verbosity wrote every debug message for the whole indexing run. `vim.g.jdtls_debug = true` restores it. |
| `eclipse`/`maven.downloadSources` | `false` | Downloads and indexes source jars for **every** dependency, up front. `includeDecompiledSources` still gives you readable code on `gd` into a library. `vim.g.jdtls_download_sources = true` restores it. |
| `referencesCodeLens` | `false` | A reference count on every method is a **project-wide search per method**, recomputed as you scroll. `implementationsCodeLens` stays — it is a type-hierarchy lookup and far cheaper. `vim.g.jdtls_references_codelens = true` restores it. |
| `maxConcurrentBuilds` | `1` | The background compiler would otherwise saturate every core on a 20-module build. |

### Escape hatches

| Variable | Default | Effect |
|---|---|---|
| `vim.g.jdtls_max_heap` | `"2g"` | jdtls's own `-Xmx` |
| `vim.g.jdtls_gradle_max_heap` | `"1g"` | The Gradle daemon's `-Xmx` |
| `vim.g.jdtls_gradle_idle_ms` | `900000` | Daemon idle timeout (15 min; Gradle's default is 3 h) |
| `vim.g.jdtls_debug` | `false` | `-Dlog.level=ALL` |
| `vim.g.jdtls_download_sources` | `false` | Dependency source jars |
| `vim.g.jdtls_references_codelens` | `false` | Reference counts |

Verified after the change: attach 4.6 s, diagnostics 7.2 s, cross-module
`gd` resolves, completion returns results. No functionality lost.

### The other language servers are fine

Measured on the same machine, same projects:

| Server | Project | RSS | Verdict |
|---|---|---|---|
| `pyright` | pytorch | **42 MB** | Fine, even with `diagnosticMode = "workspace"` |
| `clangd` | linux kernel | **27–47 MB** | Fine |
| `gopls` | — | — | Single process, no build daemon; nothing equivalent to spawn |
| `lemminx` | — | — | The Mason build is a **native GraalVM binary**, not a JVM |

**jdtls was the only offender**, and the JVM/daemon architecture is why: it is
the only server here that starts a second JVM whose heap is configured by the
project rather than by this config.
