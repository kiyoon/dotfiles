local ls = require "luasnip"
local fmt = require("luasnip.extras.fmt").fmt
local extras = require "luasnip.extras"
local l = extras.lambda
local i = ls.insert_node
local c = ls.choice_node

local s = ls.snippet
local sn = ls.snippet_node
local t = ls.text_node

-- require snippets
return {
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
  -- add which-key.nvim names
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
  s("fo", {
    t "for ",
    c(1, {
      sn(nil, { i(1, "k"), t ", ", i(2, "v"), t " in ", t "pairs", t "(", i(3), t ")" }),
      sn(nil, { i(1, "k"), t ", ", i(2, "v"), t " in ", t "ipairs", t "(", i(3), t ")" }),
      sn(nil, { i(1, "i"), t " = ", i(2), t ", ", i(3) }),
    }),
    t { " do", "\t" },
    i(0),
    t { "", "end" },
  }),
}
