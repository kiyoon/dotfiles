-- nvim-cmp setup
local cmp = require("cmp")
local types = require("cmp.types")
local cmp_buffer = require("cmp_buffer")
local luasnip = require("luasnip")
local lspkind = require("lspkind")
local compare = cmp.config.compare

cmp.setup({
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  mapping = {
    ["<C-n>"] = {
      i = cmp.mapping.select_next_item({ behavior = types.cmp.SelectBehavior.Insert }),
    },
    ["<C-p>"] = {
      i = cmp.mapping.select_prev_item({ behavior = types.cmp.SelectBehavior.Insert }),
    },
    ["<C-y>"] = {
      i = cmp.mapping.confirm({ select = false }),
    },
    ["<C-e>"] = {
      i = cmp.mapping.abort(),
    },
    ["<C-f>"] = cmp.mapping.scroll_docs(4),
    ["<C-b>"] = cmp.mapping.scroll_docs(-4),
    -- ["<C-b>"] = cmp.mapping(cmp.mapping.scroll_docs(-1), { "i", "c" }),
    -- ["<C-f>"] = cmp.mapping(cmp.mapping.scroll_docs(1), { "i", "c" }),

    -- ["<C-Space>"] = cmp.mapping.complete(),
    ["<C-Space>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true })
      else
        cmp.complete()
      end
    end, { "i", "s" }),
    -- ["<CR>"] = cmp.mapping.confirm {
    --   behavior = cmp.ConfirmBehavior.Replace,
    --   select = true,
    -- },
    -- ["<Tab>"] = cmp.mapping(function(fallback)
    --   if cmp.visible() then
    --     cmp.select_next_item()
    --   elseif luasnip.expand_or_jumpable() then
    --     luasnip.expand_or_jump()
    --   else
    --     fallback()
    --   end
    -- end, { "i", "s" }),
    -- ["<S-Tab>"] = cmp.mapping(function(fallback)
    --   if cmp.visible() then
    --     cmp.select_prev_item()
    --   elseif luasnip.jumpable(-1) then
    --     luasnip.jump(-1)
    --   else
    --     fallback()
    --   end
    -- end, { "i", "s" }),
  },
  sources = {
    { name = "jupynium", priority = 1000 },
    -- { name = "neopyter", priority = 1000 },
    { name = "lazydev", priority = 600 },
    { name = "nvim_lsp", priority = 500 },
    { name = "luasnip", priority = 10 },
    { name = "path", priority = 9 },
    { name = "emoji", priority = 8 },
    { name = "nerdfont", priority = 7 },
    { name = "buffer", priority = 5 },
    { name = "calc", priority = 3 },
  },
  sorting = {
    priority_weight = 1.0,
    comparators = {
      compare.recently_used,
      compare.score,
      compare.locality,
      compare.offset,
      compare.kind,
      compare.sort_text,
      compare.length,
      compare.order,
      -- function(...)
      --   return cmp_buffer:compare_locality(...)
      -- end,
    },
  },
  formatting = {
    format = lspkind.cmp_format({
      mode = "symbol_text", -- show only symbol annotations
      maxwidth = 50, -- prevent the popup from showing more than provided characters (e.g 50 will not show more than 50 characters)
      ellipsis_char = "...", -- when popup menu exceed maxwidth, the truncated part would show ellipsis_char instead (must define maxwidth first)

      -- The function below will be called before any actual modifications from lspkind
      -- so that you can provide more controls on popup customization. (See [#30](https://github.com/onsails/lspkind-nvim/pull/30))
      before = function(entry, vim_item)
        return vim_item
      end,
      menu = {
        buffer = "[Buffer]",
        nvim_lsp = "[LSP]",
        luasnip = "[LuaSnip]",
        nvim_lua = "[Lua]",
        latex_symbols = "[Latex]",
        jupynium = "[Jupynium]",
        -- neopyter = "[Neopyter]",
        emoji = "[Emoji]",
      },
      -- symbol_map = {
      --   -- specific complete item kind icon
      --   -- brought from neopyter
      --   ["Magic"] = "🪄",
      --   ["Path"] = "📁",
      --   ["Dict key"] = "🔑",
      --   ["Instance"] = "󱃻",
      --   ["Statement"] = "󱇯",
      -- },
    }),
  },
  window = {
    completion = cmp.config.window.bordered(),
    documentation = cmp.config.window.bordered(),
  },
  --- This shows a virtual text similar to copilot
  --- Good if you don't use copilot but using both isn't possible
  -- experimental = {
  --   ghost_text = {
  --     hl_group = "LspCodeLens",
  --   },
  -- },
})

-- transparent popup
vim.o.pumblend = 30

-- brought from neopyter
-- menu item highlight
-- vim.api.nvim_set_hl(0, "CmpItemKindMagic", { bg = "NONE", fg = "#D4D434" })
-- vim.api.nvim_set_hl(0, "CmpItemKindPath", { link = "CmpItemKindFolder" })
-- vim.api.nvim_set_hl(0, "CmpItemKindDictkey", { link = "CmpItemKindKeyword" })
-- vim.api.nvim_set_hl(0, "CmpItemKindInstance", { link = "CmpItemKindVariable" })
-- vim.api.nvim_set_hl(0, "CmpItemKindStatement", { link = "CmpItemKindVariable" })
