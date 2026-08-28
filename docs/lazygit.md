# `lazygit.lua` — LazyGit integration

[lazygit.nvim](https://github.com/kdheepak/lazygit.nvim) — opens the
[lazygit](https://github.com/jesseduffield/lazygit) TUI in a floating window.

**Requires the `lazygit` binary on `PATH`.** Install it with `brew install lazygit`,
`pacman -S lazygit`, or the release tarball (see the main README).

Loads on `<leader>gg` / `<leader>gf` or any `:LazyGit*` command.

## Settings and why

| Setting | Value | Why |
|---|---|---|
| `lazygit_floating_window_winblend` | `0` | No transparency — a git TUI needs to be fully readable |
| `lazygit_floating_window_scaling_factor` | `0.9` | 90% of the screen. Lazygit's four-panel layout needs the room. |
| `lazygit_floating_window_border_chars` | `╭ ─ ╮ │ ╯ ─ ╰ │` | Rounded border, matching every other float in the config |
| `lazygit_floating_window_use_plenary` | `0` | Uses the plugin's own window implementation |
| `lazygit_use_neovim_remote` | `1` | Makes `git commit` inside lazygit open the message in **your current Neovim instance** instead of spawning a nested one. Needs `neovim-remote` (`pip install neovim-remote`) to take effect; harmless without it. |
| `lazygit_use_custom_config_file_path` | `0` | Uses lazygit's normal config location |

## Keymaps

| Key | Action |
|---|---|
| `<leader>gg` | Open LazyGit at the repo root |
| `<leader>gf` | LazyGit filtered to the current file |
| `<leader>gl` | LazyGit filter (log view) |
| `<leader>gL` | LazyGit filter for the current file |
| `<leader>gC` | `:LazyGitConfig` — edit lazygit's own config |

> **Was `<leader>gc`, which collided with [telescope](telescope.md)'s
> `git_commits`.** Both were global, so whichever module loaded last silently
> won — and which one that was depended on whether you pressed a `<leader>f` key
> or `<leader>gg` first in the session. Telescope keeps `<leader>gc`: browsing
> commit history is a daily action, editing lazygit's own config file is close to
> never.

## Commands

Provided by the plugin: `:LazyGit`, `:LazyGitConfig`, `:LazyGitCurrentFile`,
`:LazyGitFilter`, `:LazyGitFilterCurrentFile`.

## When to reach for which

| Task | Tool |
|---|---|
| Stage/reset a single hunk while editing | [gitsigns](gitsigns.md) `<leader>hs` / `<leader>hr` |
| Look at who changed this line | gitsigns `<leader>hb` |
| Search commits/branches/status without leaving the keyboard | [telescope](telescope.md) `<leader>gc` / `<leader>gb` / `<leader>gs` |
| Interactive rebase, cherry-pick, resolve conflicts, push/pull | **lazygit** `<leader>gg` |
