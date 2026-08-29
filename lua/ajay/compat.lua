-- lua/ajay/compat.lua
--
-- ONE config, TWO Neovim versions. Nothing here is a second copy of the
-- config -- it is the small set of places where 0.11 and 0.12 disagree,
-- resolved once, at load time, by ASKING NEOVIM what it can do.
--
-- ══════════════════════════════════════════════════════════════════
-- WHY CAPABILITY PROBES AND NOT VERSION NUMBERS
-- ══════════════════════════════════════════════════════════════════
--
-- `vim.fn.has("nvim-0.12")` answers "which release is this", which is not
-- the question. The question is "does vim.lsp.codelens.enable exist", and
-- those two come apart constantly:
--
--   * 0.12 is unreleased. A nightly stamped 0.12.0-dev may predate the
--     commit that added the function you are about to call.
--   * Features land on master one at a time, not in a batch on release
--     day. Between two nightlies a week apart, has("nvim-0.12") is
--     identical and the API surface is not.
--   * A distro/Homebrew build can lag or lead the version string.
--
-- So `compat.has[...]` reads the actual table. It cannot be wrong, and it
-- keeps working on 0.13 without anyone editing this file. `compat.at_least`
-- exists for the cases where there is genuinely nothing to probe (a
-- behaviour change with no new symbol), and should be the exception.

local M = {}

-- ── Version gates (use sparingly -- prefer M.has) ──────────────────
function M.at_least(ver)
  return vim.fn.has("nvim-" .. ver) == 1
end

M.version = vim.version()

-- ── Capability probe ───────────────────────────────────────────────
-- compat.has["lsp.codelens.enable"] -> true/false, memoised on first read.
-- Walks the path under `vim`, pcall'd because vim.g/vim.b style proxies
-- throw rather than return nil for some keys.
local function probe(path)
  local cur = vim
  for part in path:gmatch("[^%.]+") do
    local ok, nxt = pcall(function()
      return cur[part]
    end)
    if not ok or nxt == nil then
      -- Not a FIELD -- which is not the same as "not there". Some runtime
      -- features are lazily-required MODULES that never appear on `vim`
      -- until something asks for them; vim._core.ui2, the 0.12 message
      -- UI, is one. A field walk alone reports those absent on the very
      -- version that ships them, so ask the module loader before giving
      -- up. Wrapped in parens: pcall returns (ok, module) and only the
      -- boolean is wanted.
      return (pcall(require, "vim." .. path))
    end
    cur = nxt
  end
  return true
end

M.has = setmetatable({}, {
  __index = function(t, k)
    local v = probe(k)
    rawset(t, k, v)
    return v
  end,
})

-- ── Value picker ───────────────────────────────────────────────────
-- Inline two-way choice for a single VALUE (an option, a string, an opts
-- table). Both arms are evaluated, so pass functions if either side is
-- expensive or would error on the wrong version.
--
--   local pos = compat.pick("lsp.document_color", "inline", "eol")
function M.pick(feature, when_present, when_absent)
  if M.has[feature] then
    return when_present
  end
  return when_absent
end

-- ── lazy.nvim gate ─────────────────────────────────────────────────
-- Drop into a plugin spec to keep a plugin off the version that cannot
-- run it. `cond` (not `enabled`) so lazy still MANAGES the plugin -- it
-- stays installed and lockfile-tracked, it just never loads:
--
--   { "some/plugin", cond = compat.needs("pack") }
function M.needs(feature)
  return function()
    return M.has[feature] == true
  end
end

-- ══════════════════════════════════════════════════════════════════
-- SHIMS
-- ══════════════════════════════════════════════════════════════════
-- Each shim presents the NEWER (0.12) API shape and back-fills it on
-- 0.11. Call sites are written once, against the new API, and never
-- branch. When 0.11 support is dropped, delete the else-arm here and
-- nothing else in the config changes.

-- ── CodeLens ───────────────────────────────────────────────────────
-- The one real divergence in this config.
--
-- 0.12 owns the codelens lifecycle: `vim.lsp.codelens.enable(true, {bufnr})`
-- attaches to the buffer (nvim_buf_attach on_lines/on_reload) and issues
-- its own debounced textDocument/codeLens requests.
--
-- 0.11 has no lifecycle at all -- only `vim.lsp.codelens.refresh()`, a
-- one-shot request. Somebody has to decide when to call it, so on 0.11
-- this shim recreates the autocmd loop 0.12 made unnecessary.
--
-- Note the direction of the deprecation: refresh() is deprecated in 0.12
-- and removed in 0.13, so the 0.11 arm must never run on 0.12. It cannot
-- -- the probe below is the gate.
M.codelens = {}

if M.has["lsp.codelens.enable"] then
  M.codelens.enable = function(enable, opts)
    vim.lsp.codelens.enable(enable, opts)
  end
  M.codelens.is_enabled = function(opts)
    return vim.lsp.codelens.is_enabled(opts)
  end
else
  local group = vim.api.nvim_create_augroup("ajay_codelens_compat", { clear = true })

  M.codelens.is_enabled = function(opts)
    local bufnr = (opts or {}).bufnr or vim.api.nvim_get_current_buf()
    if bufnr == 0 then
      bufnr = vim.api.nvim_get_current_buf()
    end
    return vim.b[bufnr].ajay_codelens_on == true
  end

  M.codelens.enable = function(enable, opts)
    local bufnr = (opts or {}).bufnr or vim.api.nvim_get_current_buf()
    if bufnr == 0 then
      bufnr = vim.api.nvim_get_current_buf()
    end
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    -- Clear this buffer's autocmds either way; enabling twice must not
    -- stack two refresh loops on the same buffer.
    pcall(vim.api.nvim_clear_autocmds, { group = group, buffer = bufnr })

    if enable == false then
      vim.b[bufnr].ajay_codelens_on = false
      vim.lsp.codelens.clear(nil, bufnr)
      return
    end

    vim.b[bufnr].ajay_codelens_on = true
    vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave", "BufWritePost" }, {
      group = group,
      buffer = bufnr,
      callback = function()
        -- Re-read the flag: ToggleCodeLens may have turned it off since.
        if vim.b[bufnr].ajay_codelens_on then
          vim.lsp.codelens.refresh({ bufnr = bufnr })
        end
      end,
    })
    -- First paint. Deferred so it does not run inside LspAttach, where
    -- the server is still mid-handshake and jdtls in particular answers
    -- an immediate codeLens request with an empty list.
    vim.defer_fn(function()
      if vim.api.nvim_buf_is_valid(bufnr) and vim.b[bufnr].ajay_codelens_on then
        vim.lsp.codelens.refresh({ bufnr = bufnr })
      end
    end, 500)
  end
end

-- ── Report line for :AjayDoctor ────────────────────────────────────
-- The features this config actually cares about, and which arm each one
-- resolved to on THIS Neovim. When something behaves differently between
-- your two machines, this is the first thing to read.
M.tracked = {
  "lsp.codelens.enable",
  "lsp.document_color",
  "lsp.linked_editing_range",
  "lsp.on_type_formatting",
  "pack",
  "text.diff",
  -- The 0.12 experimental message UI. It was `vim._extui` while 0.12 was
  -- in development and ships as `vim._core.ui2`, so probing the old name
  -- reported "absent" on the released 0.12 AND on 0.13 -- a doctor giving
  -- a confidently wrong answer is worse than one saying nothing. It is
  -- also require-only, never a field on `vim`, which is why probe() grew
  -- the module-loader fallback above.
  "_core.ui2",
}

return M
