local url_utils = require("kiyoon.utils.url")
local ls = require("luasnip")
local fmt = require("luasnip.extras.fmt").fmt
local extras = require("luasnip.extras")
local l = extras.lambda
local i = ls.insert_node
local c = ls.choice_node
local func_node = ls.function_node

local s = ls.snippet
local sn = ls.snippet_node
local t = ls.text_node

-- require snippets
return {
  s(
    "rq",
    fmt(
      [[
      local {module} = require("{1}")
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
  s(
    "pprint",
    fmt(
      [[
      vim.print({1})
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
        wk.add {{
          {{"{}", group = "{}" }},
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
    t("for "),
    c(1, {
      sn(nil, { i(1, "k"), t(", "), i(2, "v"), t(" in "), t("pairs"), t("("), i(3), t(")") }),
      sn(nil, { i(1, "k"), t(", "), i(2, "v"), t(" in "), t("ipairs"), t("("), i(3), t(")") }),
      sn(nil, { i(1, "i"), t(" = "), i(2), t(", "), i(3) }),
    }),
    t({ " do", "\t" }),
    i(0),
    t({ "", "end" }),
  }),
  -- lazy.nvim
  s("cfun", {
    t({ "config = function()", "\t" }),
    i(1),
    t({ "", "end," }),
    i(0),
  }),
  s("ifun", {
    t({ "init = function()", "\t" }),
    i(1),
    t({ "", "end," }),
    i(0),
  }),
  s("depe", {
    t({ "dependencies = {", "\t" }),
    i(1),
    t({ "", "}," }),
    i(0),
  }),
  s('{""}', {
    t({ "{", '\t"' }),
    c(1, {
      sn(nil, { i(1, " "), t({ '"', "}" }) }),
      sn(nil, { i(1, " "), t({ '"', "}," }) }),
    }),
    i(0),
  }),

  -- nvim-notify
  s(
    "noti",
    fmt(
      [[
          vim.notify(<1>, "info", {
            title = "My Plugin",
            on_open = function(win)
              local buf = vim.api.nvim_win_get_buf(win)
              vim.api.nvim_buf_set_option(buf, "filetype", "python")
            end,
          })
      ]],
      {
        i(1, "Message"),
      },
      { delimiters = "<>" }
    )
  ),
  s("repro", {
    func_node(function()
      local content = url_utils.read_from_url(
        "https://gist.githubusercontent.com/kiyoon/20475c74cbfcbe530af07a40332b1c57/raw/bb12990e9f331849b7266c70030ec457da2ed1a1/repro.lua"
      )
      return content
    end, {}),
  }),
}
