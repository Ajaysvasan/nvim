# `springboot.lua` — Spring Boot helpers

Four thin wrappers around Spring Initializr and the Maven/Gradle wrappers. No
plugin dependency — pure Lua and shell-outs.

Loaded from the `nvim-jdtls` spec (`ft = "java"`), so Spring commands appear as
soon as you open a Java file.

> **Fix:** the old `init.lua` did `require("ajay.springboot")`, which only
> returns the module table — `setup()` was never called, so `:SpringBootRun` and
> `<leader>sr` never existed on either machine. It's now wired into the jdtls
> spec's `config()`.

## Build-tool detection

Every run/build/test function checks for `pom.xml` in the current directory:

```lua
local build_tool = vim.fn.filereadable("pom.xml") == 1 and "maven" or "gradle"
```

Present → Maven; absent → assume Gradle. It always uses the **wrappers**
(`./mvnw`, `./gradlew`), never a globally installed `mvn`/`gradle`, so the
project's pinned build-tool version is what runs.

> This means the commands must be invoked with Neovim's cwd at the project root.
> Use `:cd` or launch `nvim` from there.

## Project creation

`:SpringBootCreate` prompts for:

| Prompt | Default |
|---|---|
| Project name | *(required, empty is rejected)* |
| Group ID | `com.example` |
| Artifact ID | the project name |
| Java version | `17` |
| Build tool | `maven` |
| Dependencies (comma-separated) | `web,devtools` |

It then builds a `https://start.spring.io/starter.zip` URL with those values
(Boot version pinned to `3.2.0`, language `java`, package name
`<groupId>.<artifactId>`), `curl`s it to `/tmp`, `unzip`s it into a directory
named after the project, and deletes the zip. Every step checks
`vim.v.shell_error` and reports failure.

**Requires `curl` and `unzip` on `PATH`, and network access.**

Dependency ids are the Spring Initializr ids — `web`, `data-jpa`, `h2`,
`security`, `lombok`, `validation`, `actuator`, `postgresql`, etc.

After creation it reminds you to `:cd <project>`.

> To change the Boot version, edit the `bootVersion=3.2.0` string in
> `M.create_project()`.

## Keymaps

| Key | Action | Runs |
|---|---|---|
| `<leader>sc` | Create a new Spring Boot project | Spring Initializr |
| `<leader>sr` | Run the application | `./mvnw spring-boot:run` or `./gradlew bootRun` |
| `<leader>sb` | Build | `./mvnw clean install` or `./gradlew build` |
| `<leader>st` | Run tests | `./mvnw test` or `./gradlew test` |

Run/build/test use `:!` (a blocking shell command), not a terminal split — output
appears in the message area and Neovim waits for the process. For a long-running
`bootRun`, `:split | terminal ./mvnw spring-boot:run` is more comfortable.

## Commands

| Command | Equivalent |
|---|---|
| `:SpringBootCreate` | `<leader>sc` |
| `:SpringBootRun` | `<leader>sr` |
| `:SpringBootBuild` | `<leader>sb` |
| `:SpringBootTest` | `<leader>st` |

## Debugging a Spring Boot app

`springboot.lua` doesn't wire up debugging. Start the app with the JDWP agent:

```bash
./mvnw spring-boot:run -Dspring-boot.run.jvmArguments="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=5005"
```

then `<leader>dc` in Neovim and pick **Attach to remote JVM** — see
[dap.md](dap.md).

## Related

- [jdtls.md](jdtls.md) — the language server, with Spring-aware completion
  favourites and the `jakarta` import group
- [java-creator.md](java-creator.md) — templates for `@Service`, `@Repository`,
  `@RestController` etc. (currently not loaded)
