-- config/cmp.lua
local cmp_ok, cmp = pcall(require, "cmp")
if not cmp_ok then
  return
end

local luasnip_ok, luasnip = pcall(require, "luasnip")
if not luasnip_ok then
  return
end

-- Load friendly snippets
require("luasnip.loaders.from_vscode").lazy_load()

-- Custom HTML boilerplate snippet
luasnip.add_snippets("html", {
  luasnip.snippet("!", {
    luasnip.text_node({
      "<!DOCTYPE html>",
      '<html lang="en">',
      "<head>",
      '    <meta charset="UTF-8">',
      '    <meta name="viewport" content="width=device-width, initial-scale=1.0">',
      "    <title>",
    }),
    luasnip.insert_node(1, "Document"),
    luasnip.text_node({
      "</title>",
      "</head>",
      "<body>",
      "    ",
    }),
    luasnip.insert_node(0),
    luasnip.text_node({
      "",
      "</body>",
      "</html>",
    }),
  }),
})

-- Custom Java class boilerplate snippet
luasnip.add_snippets("java", {
  luasnip.snippet("!", {
    luasnip.text_node("public class "),
    luasnip.insert_node(1, "Main"),
    luasnip.text_node({
      " {",
      "    public static void main(String[] args) {",
      "        ",
    }),
    luasnip.insert_node(0),
    luasnip.text_node({
      "",
      "    }",
      "}",
    }),
  }),
})

-- JSX/TSX div snippets
local jsx_snippets = {
  luasnip.snippet("div", {
    luasnip.text_node("<div>"),
    luasnip.insert_node(0),
    luasnip.text_node("</div>"),
  }),
  luasnip.snippet("divc", {
    luasnip.text_node('<div className="'),
    luasnip.insert_node(1),
    luasnip.text_node('">'),
    luasnip.insert_node(0),
    luasnip.text_node("</div>"),
  }),
  luasnip.snippet("span", {
    luasnip.text_node("<span>"),
    luasnip.insert_node(0),
    luasnip.text_node("</span>"),
  }),
  luasnip.snippet("p", {
    luasnip.text_node("<p>"),
    luasnip.insert_node(0),
    luasnip.text_node("</p>"),
  }),
  luasnip.snippet("h1", {
    luasnip.text_node("<h1>"),
    luasnip.insert_node(0),
    luasnip.text_node("</h1>"),
  }),
  luasnip.snippet("h2", {
    luasnip.text_node("<h2>"),
    luasnip.insert_node(0),
    luasnip.text_node("</h2>"),
  }),
  luasnip.snippet("button", {
    luasnip.text_node("<button>"),
    luasnip.insert_node(0),
    luasnip.text_node("</button>"),
  }),
  luasnip.snippet("input", {
    luasnip.text_node('<input type="'),
    luasnip.insert_node(1, "text"),
    luasnip.text_node('" />'),
  }),
}

luasnip.add_snippets("javascriptreact", jsx_snippets)
luasnip.add_snippets("typescriptreact", jsx_snippets)
luasnip.add_snippets("javascript", jsx_snippets)
luasnip.add_snippets("typescript", jsx_snippets)

cmp.setup({
  -- ── PERF ─────────────────────────────────────────────────────────
  -- Completion is the hottest path in the editor: it runs on nearly every
  -- keystroke in insert mode. Defaults are tuned for small buffers; Java
  -- and Spring produce candidate lists in the thousands, where the cost is
  -- dominated by SORTING and RENDERING entries you will never scroll to.
  performance = {
    debounce = 30, -- was 60: time from keystroke to asking sources
    throttle = 20, -- was 30: min gap between filter/sort passes
    -- Stop waiting on a slow source rather than stalling the menu. jdtls
    -- can take seconds on a cold project; the menu should show whatever
    -- the fast sources returned instead of hanging.
    fetching_timeout = 200, -- was 500
    max_view_entries = 30, -- was 200: render cost is per visible entry
  },

  -- Do not open the menu at all for a bare `.` or a single character in a
  -- huge candidate set -- wait until there is something to filter on.
  completion = {
    keyword_length = 1,
  },

  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },

  window = {
    completion = cmp.config.window.bordered(),
    documentation = cmp.config.window.bordered(),
  },

  mapping = cmp.mapping.preset.insert({
    ["<C-b>"] = cmp.mapping.scroll_docs(-4),
    ["<C-f>"] = cmp.mapping.scroll_docs(4),
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<C-e>"] = cmp.mapping.abort(),
    ["<CR>"] = cmp.mapping.confirm({ select = true }),

    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_next_item()
      elseif luasnip.expand_or_locally_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end, { "i", "s" }),

    ["<S-Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { "i", "s" }),
  }),

  sources = cmp.config.sources({
    { name = "copilot", priority = 1100 }, -- AI suggestions first!
    { name = "nvim_lsp", priority = 1000 },
    { name = "luasnip", priority = 750 },
    { name = "path", priority = 500 },
    {
      name = "buffer",
      priority = 250,
      keyword_length = 3,
      option = {
        -- Default is the current buffer only. Indexing every listed buffer
        -- is a common "make it smarter" tweak that quietly turns into a
        -- full re-scan of every open file; cap it at what is VISIBLE so a
        -- session with 30 buffers open does not pay for all of them.
        get_bufnrs = function()
          local bufs = {}
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            -- Skip anything big enough that scanning it would stutter.
            if not vim.b[buf].bigfile then
              bufs[buf] = true
            end
          end
          return vim.tbl_keys(bufs)
        end,
      },
    },
  }),

  formatting = {
    format = function(entry, vim_item)
      vim_item.menu = ({
        copilot = "[AI]",
        nvim_lsp = "[LSP]",
        luasnip = "[Snip]",
        buffer = "[Buf]",
        path = "[Path]",
      })[entry.source.name]
      return vim_item
    end,
  },
})
