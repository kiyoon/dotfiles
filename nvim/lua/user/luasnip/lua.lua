local ls = require "luasnip"
local fmt = require("luasnip.extras.fmt").fmt
local i = ls.insert_node

local s = ls.snippet

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
