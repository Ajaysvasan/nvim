# `dap.lua` — debugging

[nvim-dap](https://github.com/mfussenegger/nvim-dap) with dap-ui, virtual text,
and mason-nvim-dap. Covers **Python, JavaScript/TypeScript, Go, C, C++, Rust and
Java**.

Loads on any `<leader>d*` key, `<F5>`–`<F8>`, or `:DapContinue` / `:DapNew`.

## Adapters installed by mason-nvim-dap

| Adapter | Covers |
|---|---|
| `debugpy` | Python |
| `js-debug-adapter` | Node, TypeScript, Jest |
| `chrome-debug-adapter` | Frontend debugging in Chrome |
| `codelldb` | C, C++, Rust |
| `delve` | Go |

Java is **not** listed — nvim-jdtls registers the Java adapter itself via
`jdtls.setup_dap()`. Adding `dap.adapters.java` here would conflict.

`automatic_installation = true`, `handlers = {}` (default handlers; per-language
configuration is overridden explicitly below in the file).

## Signs

From [`icons.lua`](icons.md): breakpoint, conditional breakpoint, log point,
stopped, rejected. The stopped line is highlighted with a custom `DapStoppedLine`
group (`bg = #2d3149`).

Like [lsp.lua](lsp.md) and [neotree.lua](neotree.md), the require is a
**soft dependency** — `pcall(require, "ajay.icons")` with an inline ASCII
fallback table (`B` `C` `L` `>` `X` for signs, `||` `>` `I` `O` `U` `<` for the
dap-ui controls). A missing icons file never costs you a debugger.

## dap-ui layout

| Panel | Elements | Size |
|---|---|---|
| **Left sidebar** | scopes (40%), watches (25%), breakpoints (20%), stacks (15%) | 40 columns |
| **Bottom** | REPL (50%), console (50%) | 12 rows |

Opens automatically on `event_initialized`, closes on `event_terminated` and
`event_exited` — you never manage the windows manually.

Floating windows close with `q` or `<Esc>`. Control-button icons come from
`icons.dap` — they were all empty strings before, so every dap-ui control button
rendered blank.

### dap-ui element mappings

Inside the scopes/watches/breakpoints panels:

| Key | Action |
|---|---|
| `<CR>` or double-click | Expand/collapse |
| `o` | Open |
| `d` | Remove |
| `e` | Edit value |
| `r` | Send to REPL |
| `t` | Toggle |

## Virtual text

`nvim-dap-virtual-text` shows variable values inline next to the code.

| Setting | Value | Why |
|---|---|---|
| `highlight_changed_variables` | `true` | Changed values stand out — the point of stepping |
| `highlight_new_as_changed` | `false` | A newly-scoped variable isn't a change |
| `show_stop_reason` | `true` | Says *why* execution stopped (breakpoint / exception / step) |
| `only_first_definition` | `true` | One annotation per variable, not one per reference |
| `virt_text_pos` | `"inline"` on 0.10+, else `"eol"` | Inline reads like an IDE; `eol` is the pre-0.10 fallback |
| `all_frames` | `false` | Only the current frame, otherwise the whole call stack annotates at once |

## Language configurations

### Python
`nvim-dap-python`, pointed at Mason's bundled debugpy venv
(`mason/packages/debugpy/venv/bin/python`), falling back to `python3`.
`test_runner = "pytest"`. Auto-detects the active virtualenv.

A full manual fallback config exists if `nvim-dap-python` isn't installed:
*Launch file*, *Launch with args*, *Attach remote (debugpy)* on port 5678, with
`VIRTUAL_ENV` / `CONDA_DEFAULT_ENV` detection.

### JavaScript / TypeScript
`pwa-node` and `pwa-chrome` adapters, both run as servers against Mason's
`js-debug-adapter`. The same five configurations are registered for
`javascript`, `typescript`, `javascriptreact` and `typescriptreact`:

1. **Launch Node (current file)** — with source maps, excluding `node_modules`
2. **Attach to Node process** — interactive process picker
3. **Debug Jest tests** — `jest --runInBand` in an integrated terminal
4. **Launch Chrome (localhost:3000)** — `webRoot` at the workspace folder
5. **Launch with ts-node** — `node --loader ts-node/esm`

### Go
`nvim-dap-go` with `dlv`, 20-second initialize timeout, plus an extra "Attach
remote" configuration. Manual fallback covers Debug, Debug test, Debug package,
and Attach to process.

### C / C++ / Rust
`codelldb`, pointed at Mason's raw extension binary
(`mason/packages/codelldb/extension/adapter/codelldb`).

- **C/C++**: *Launch (codelldb)* prompting for the executable path with file
  completion, and *Attach to process*.
- **Rust**: *Debug Rust binary* — reads `cargo metadata --format-version 1
  --no-deps` to pre-fill the path to `target/debug/`, falling back to
  `cwd/target/debug/`. Plus *Debug Rust test* via `cargo test --no-run --lib`.

### Java
Only an *Attach to remote JVM* configuration (`127.0.0.1:5005`) is defined here.
Launch configurations come from jdtls itself. To debug a Spring Boot app:
start it with
`-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=5005`, then
`<leader>dc` and pick "Attach to remote JVM".

## `.vscode/launch.json` support

If `<cwd>/.vscode/launch.json` exists, it is loaded automatically via
`dap.ext.vscode.load_launchjs()`, with a type map translating VS Code's adapter
names (`node`, `node2`, `pwa-node`, `pwa-chrome`, `python`, `cppdbg`, `codelldb`,
`go`, `java`) to the right filetypes. Project-local debug configs work without
any conversion.

## Keymaps

### Session control

| Key | Action |
|---|---|
| `<leader>dc` | Continue / start a session |
| `<leader>dq` | Terminate |
| `<leader>dr` | Restart |
| `<leader>dp` | Pause |

### Stepping — F-keys, matching VS Code / JetBrains

| Key | Action |
|---|---|
| `<F5>` | Continue |
| `<F6>` | Step over |
| `<F7>` | Step into |
| `<F8>` | Step out |
| `<F9>` | Step back (adapters that support reverse debugging) |
| `<F10>` | Run to cursor |

### Breakpoints

| Key | Action |
|---|---|
| `<leader>db` | Toggle breakpoint |
| `<leader>dB` | Conditional breakpoint — prompts for the condition |
| `<leader>dl` | Log point — prompts for a message, logs without stopping |
| `<leader>dC` | Clear all breakpoints |

### Inspecting

| Key | Mode | Action |
|---|---|---|
| `<leader>du` | n | Toggle the dap-ui |
| `<leader>de` | n | Evaluate an expression (opens a float you can type into) |
| `<leader>de` | v | Evaluate the selection |
| `<leader>dK` | n | Hover the value under the cursor |
| `<leader>df` | n | Floating stack frames |
| `<leader>ds` | n | Floating scopes |
| `<leader>dR` | n | Toggle the REPL in a vsplit |

### Python tests

| Key | Mode | Action |
|---|---|---|
| `<leader>dtn` | n | Debug the test method under the cursor |
| `<leader>dtc` | n | Debug the test class |
| `<leader>dts` | v | Debug the selected code |

### Help

| Key | Action |
|---|---|
| `<leader>d?` | Print the whole DAP keymap reference as a notification |

## Telescope integration

`telescope-dap.nvim` loads with the DAP spec and registers the `dap` extension
(via `pcall`), giving you `:Telescope dap commands`, `dap configurations`,
`dap list_breakpoints`, `dap variables` and `dap frames`.

## Typical session

1. `<leader>db` on the line you care about
2. `<leader>dc`, pick a configuration from the list
3. dap-ui opens automatically
4. `<F6>` / `<F7>` to step, `<leader>dK` to peek at a value
5. `<leader>dq` to stop — the UI closes itself
