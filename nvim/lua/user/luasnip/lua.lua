local ls = require "luasnip"
local fmt = require("luasnip.extras.fmt").fmt
local extras = require "luasnip.extras"
local l = extras.lambda
local i = ls.insert_node

local s = ls.snippet

-- require snippets
ls.add_snippets("lua", {
  s(
    "rq",
    fmt(
      [[
      local {module} = require "{1}"
    ]],
      {
        i(1, "module"),
        module = l(l._1:gsub("-", "_"):gsub("%.", "_"), 1),
      }
    )
  ),
})

ls.add_snippets("lua", {
  s(
    "prq",
    fmt(
      [[
      local status, {module} = pcall(require, "{1}")
      if not status then
        {2}
      end
    ]],
      {
        i(1, "module"),
        i(2, "return"),
        module = l(l._1:gsub("-", "_"):gsub("%.", "_"), 1),
      }
    )
  ),
})

ls.add_snippets("lua", {
  s(
    "pinsp",
    fmt(
      [[
      print(vim.inspect({1}))
    ]],
      {
        i(1, "data"),
      }
    )
  ),
})

-- add which-key.nvim names
ls.add_snippets("lua", {
  s(
    "wk",
    fmt(
      [[
      local status, wk = pcall(require, "which-key")
      if status then
        wk.register {{
          ["{}"] = {{ name = "{}" }},
        }}
      end
    ]],
      {
        i(1, "<space>"),
        i(2, "Group Name"),
      }
    )
  ),
})
