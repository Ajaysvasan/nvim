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
| `<leader>sx` | Stop any running task | `jobstop` on every live task |

### Tasks run in a terminal buffer, not `:!`

These used to run through `vim.cmd("!" .. cmd)`. `:!` is **synchronous** —
measured, `:!sleep 3` returns after 3.2 s while the same command in a terminal
returns in 0.1 s. For `mvn test` that is merely annoying; for `:SpringBootRun`,
which starts a server that lives until you stop it, it meant **Neovim was frozen
for the entire life of the application**.

It was also the wrong place to send logs. `:!` output goes to the message area,
not a buffer, so a Spring Boot startup trace or a stack trace could not be
scrolled, searched with `/`, yanked, or sent to the quickfix list. A terminal
buffer gives you all of that. (The rest of the config already did this — the
`<leader>rp` / `<leader>rj` run-file keymaps in [keymaps.md](keymaps.md) have
always used `split | terminal`; these commands were simply inconsistent.)

`jobstart()` is called in **list form with `cwd`**, not as a shell string, so
there is no `cd … &&` prefix to quote and no `escape(cmd, "%#")` dance — a
project path containing a space or a `%` cannot break or silently misfire.

**Window behaviour:**

- The task opens in a bottom split, named `spring-boot://<project>/<task>`.
- It opens in **normal mode**, so you can scroll and search the log immediately
  without pressing `<C-\><C-n>` first.
- A **finished** task's window is recycled by the next task, and its buffer
  wiped — otherwise every run left another dead terminal in `:ls`.
- A **running** task keeps its window; a new task opens its own split. Recycling
  it would kill your running application as a side effect of asking for
  something unrelated.

> ⚠️ Because these are real background jobs now, a Spring Boot app **keeps
> running** if you just close its window — and an orphaned app still holds port
> 8080, which resurfaces as a baffling "port already in use" on the next
> `:SpringBootRun`. Use `<leader>sx` / `:SpringBootStop`.

> The terminal remembers its project on the buffer (`b:springboot_root`). Without
> that, the *second* command was broken: after the first one the current buffer
> is the terminal, and `project_root()` searching upward from
> `spring-boot://demo/run` found nothing — so `:SpringBootTest` right after
> `:SpringBootRun` reported "this does not look like a Maven or Gradle project"
> while sitting inside the project.

## Commands

| Command | Equivalent |
|---|---|
| `:SpringBootCreate` | `<leader>sc` |
| `:SpringBootRun` | `<leader>sr` |
| `:SpringBootBuild` | `<leader>sb` |
| `:SpringBootTest` | `<leader>st` |
| `:SpringBootStop` | `<leader>sx` — stop every running Spring Boot task |

## Debugging a Spring Boot app

`springboot.lua` doesn't wire up debugging. Start the app with the JDWP agent:

```bash
./mvnw spring-boot:run -Dspring-boot.run.jvmArguments="-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=5005"
```

then `<leader>dc` in Neovim and pick **Attach to remote JVM** — see
[dap.md](dap.md).

## Reading the logs

The task terminal is a normal buffer, so `/`, `?`, `n`, `G` and `y` all work on
it. Beyond that:

- **Log files** (`*.log`, and rotated `*.log.1` / `*.log.2024-01-01`) get syntax
  highlighting from `log-highlight.nvim` — ERROR maps to `ErrorMsg`, WARN to
  `WarningMsg`, timestamps, IPs and quoted strings each get their own group.
  Neovim detects **nothing** for `.log` on its own, so the filetype rule that
  makes this work is registered in [plugins.md](plugins.md).
- **Grep a log into the quickfix list** with `<leader>fg`, then `<C-q>` in the
  Telescope prompt — see [telescope.md](telescope.md).

## Related

- [jdtls.md](jdtls.md) — the language server, with Spring-aware completion
  favourites and the `jakarta` import group
- [java-creator.md](java-creator.md) — templates for `@Service`, `@Repository`,
  `@RestController` etc. (currently not loaded)
