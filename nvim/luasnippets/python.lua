local ls = require "luasnip"
local i = ls.insert_node

local s = ls.snippet
local t = ls.text_node

return {
  s("li", {
    t { "logger.info(" },
    i(1, "message"),
    t { [[)]] },
    i(0),
  }),
  s("ld", {
    t { "logger.debug(" },
    i(1, "message"),
    t { [[)]] },
    i(0),
  }),
  s("lw", {
    t { "logger.warning(" },
    i(1, "message"),
    t { [[)]] },
    i(0),
  }),
  s("le", {
    t { "logger.error(" },
    i(1, "message"),
    t { [[)]] },
    i(0),
  }),
  s("lc", {
    t { "logger.critical(" },
    i(1, "message"),
    t { [[)]] },
    i(0),
  }),
  s("lee", {
    t { "logger.exception(" },
    i(1, "message"),
    t { [[)]] },
    i(0),
  }),

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
  s("logmain", {
    t {
      "from rich.traceback import install",
      "",
      "install(show_locals=True)",
      "",
      "import logging",
      "",
      "logger = logging.getLogger(__name__)",
      "",
      "",
      [[def main():]],
      "\t",
    },
    i(1, "pass"),
    t {
      "",
      "",
      "",
      [[if __name__ == "__main__":]],
      "\ttry:",
      "\t\tmain()",
      "\texcept Exception:",
      "\t\t" .. [[logger.exception("Exception occurred")]],
      "",
    },
    i(0),
  }),
}
