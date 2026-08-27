# `java-creator.lua` — IntelliJ-style new-file GUI

> ## ⚠️ Not currently loaded
>
> This file is **not referenced by `init.lua` or `plugins.lua`**. Nothing in it
> runs. See [Enabling it](#enabling-it) below.

A two-stage floating-window GUI for creating Java files, in the shape of
IntelliJ's *New → Java Class* dialog.

## The flow

```
pick directory  →  pick type  →  name it  →  file created and opened
```

**Stage 1 — directory picker.** Starting directory is a best-effort guess:
the selected node in neo-tree, else the current buffer's directory, else `cwd`.
The neo-tree lookup is wrapped entirely in `pcall`, so a neo-tree API mismatch
can never abort the GUI.

**Stage 2 — type + name picker.** Choose a template, type a class name. A
trailing `.java` is stripped if you type one.

## Package inference

The generated `package` line is derived from the path, not asked for:

1. Look for `src/main/java` or `src/test/java` in the directory path; everything
   after it becomes the package, with `/` → `.`
2. Otherwise fall back to the last two path segments joined with `.`
3. Otherwise `com.example`

So `.../src/main/java/com/acme/api/user` → `package com.acme.api.user;`

## Templates

| Template | Generates |
|---|---|
| `Class` | `public class` with a no-arg constructor |
| `Abstract Class` | `public abstract class` |
| `Record` | A Java record |
| `Spring @Service` | `@Service`-annotated class |
| `Spring @Repository` | `@Repository`-annotated class |
| `Spring @Controller` | `@Controller` with request mapping imports |
| `Spring @RestController` | `@RestController` |
| `Spring @Component` | `@Component` |
| `Spring @Configuration` | `@Configuration` |
| `JPA @Entity` | `@Entity` + `@Table(name = "…")` with an id field |
| `DTO / Record` | A record shaped as a data transfer object |
| `Exception` | A custom exception extending `RuntimeException` |
| `Test (JUnit 5)` | A JUnit 5 test class |

## Implementation notes

- All float mappings are set with `pcall(vim.keymap.set, ..., { buffer = buf,
  silent = true, nowait = true })` — `nowait` so single-key navigation doesn't
  wait on `timeoutlen`.
- Stage functions are **forward-declared as `local` and assigned later**
  (`open_type_stage = function(...)`, never `function open_type_stage(...)`) —
  the latter creates a brand-new global and leaves the upvalue `nil` forever.
- `M.open()` toggles: calling it while a stage is open closes everything.
- The whole entry point is wrapped in `pcall` with a cleanup path, so a failure
  never leaves orphan floating windows.

## Keymaps

Registered at file scope — they exist **only if the module is loaded**.

| Key | Action |
|---|---|
| `<leader>jn` | Open the Java file creator |

## Commands

| Command | Action |
|---|---|
| `:JavaNew` | Same as `<leader>jn` |

## Enabling it

Add a `config` call in `plugins.lua` alongside the other Java modules:

```lua
{
  "mfussenegger/nvim-jdtls",
  ft = "java",
  config = function()
    setup_module("ajay.jdtls")
    setup_module("ajay.springboot")
    require("ajay.java-creator")   -- registers <leader>jn and :JavaNew at load
  end,
}
```

Note this module registers its keymap at file scope, so a plain `require` is
enough — it has no `setup()`, which is why `setup_module()` would report
"has no setup() function".

> ⚠️ **Before enabling, resolve the collision:** `<leader>jn` is already mapped
> by [jdtls.lua](jdtls.md) to "test nearest method". jdtls' version is
> buffer-local (registered in `on_attach`), so it would win inside any Java
> buffer — which is exactly where you'd want the file creator. Remap one of them,
> e.g. move the creator to `<leader>jN`.

## Related

- [inactive-modules.md](inactive-modules.md)
- [jdtls.md](jdtls.md)
- [springboot.md](springboot.md)
