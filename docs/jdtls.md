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

Two separate questions, often confused:

- **Which JDK runs jdtls?** Must be recent (21+ currently) — this is a property
  of Eclipse JDT LS, not your code.
- **Which JDK does your project target?** Anything from 8 up. Set independently
  via the `runtimes` table.

### Where it looks

| Source | Platform |
|---|---|
| `vim.g.jdtls_java_home` | Both — **always wins** |
| `/usr/libexec/java_home -V` | macOS — the authoritative source, knows every properly installed JDK regardless of vendor |
| `/opt/homebrew/opt/openjdk@N/...` and `/usr/local/opt/...` | macOS — Homebrew *formula* installs are not bundles and `java_home` misses them |
| `/Library/Java/JavaVirtualMachines/*/Contents/Home` | macOS |
| `/usr/lib/jvm/*` | Linux |
| `~/.sdkman/candidates/java/*` | Both |
| `~/.jenv/versions/*` | Both |
| `~/.asdf/installs/java/*` | Both |
| `~/.local/share/mise/installs/java/*` | Both |
| `$JAVA_HOME` | Both — checked last |

Every candidate's version is read by **running `java -version`**, not by parsing
the directory name. Vendor naming is not something to parse: `zulu-21.jdk`,
`temurin-21.jdk`, `jdk-21.0.3+9`, `graalvm-community-openjdk-21` all differ.

> **Fixed bug:** an earlier version only checked Homebrew `openjdk@N` paths plus
> a fragile regex over `/Library`. It silently missed Zulu, Temurin, Corretto,
> GraalVM, Microsoft builds, and every version manager. Switching from Homebrew
> OpenJDK to Zulu was enough to blind it.
>
> **Second fixed bug:** it probed `java_home -v <N>` for a hardcoded list, so a
> JDK 26 install was invisible. Now it parses the full `-V` listing, so new Java
> releases need no code change.

### Escape hatch

```lua
vim.g.jdtls_java_home = "/path/to/jdk-21/Contents/Home"
```

Set that in `options.lua` and all detection is skipped.

### Which JDK is chosen to run the server

The **lowest installed version at or above the declared minimum** — not the
highest.

> **Fixed bug:** the first version picked the highest JDK ≥ 21. That's wrong.
> Eclipse JDT LS is built against a specific LTS and its OSGi runtime **rejects
> JVMs newer than it supports** — the launcher aborts with **exit code 13**
> before any LSP traffic happens, with clean-looking stderr. If you have JDK
> 24/25 installed, "highest wins" hands jdtls a JVM it refuses to run on.

The minimum is not hardcoded. Every OSGi bundle declares its minimum execution
environment in `META-INF/MANIFEST.MF`, either as
`Bundle-RequiredExecutionEnvironment` or an `osgi.ee` `Require-Capability`
filter. This module **unzips the installed `org.eclipse.jdt.ls.core_*.jar` and
reads it**, so when Mason upgrades jdtls and the requirement moves from 21 to 25,
this picks it up with no edit. `FALLBACK_MIN = 21` if the jar or `unzip` is
missing.

If the chosen JDK is more than two releases past the minimum, you get a one-time
warning suggesting `brew install --cask zulu@<min>`.

If no JDK at or above the minimum exists, the module **refuses to start rather
than falling back to `java` on PATH** — that path produces "exit code 13" with a
clean-looking stderr, because the real `UnsupportedClassVersionError` happens
inside OSGi bundle activation and only lands in the workspace `.metadata/.log`.
Instead you get an actionable error listing every JDK found and the exact brew
command to fix it.

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

Without it, jdtls doesn't see Lombok-generated methods, so you get
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

> `<leader>jn` used to collide with `java-creator.lua`'s new-file GUI. Resolved —
> jdtls keeps `<leader>jn`, the creator moved to `<leader>jN`. See
> [java-creator.md](java-creator.md).

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
