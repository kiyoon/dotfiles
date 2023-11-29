local ls = require "luasnip"
local i = ls.insert_node

local s = ls.snippet
local t = ls.text_node

return {
  -- Jupynium markdown cell
  s("md", {
    t { "# %% [md]", [["""]], "" },
    i(1),
    t { "", [["""]], "" },
    i(0),
  }),

  -- logger
  s("logger", {
    t { "import logging", "logger = logging.getLogger(__name__)" },
  }),
}
