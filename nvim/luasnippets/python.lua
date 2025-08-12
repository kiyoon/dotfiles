local python_utils = require("python_import.utils")
local url_utils = require("kiyoon.utils.url")
local ls = require("luasnip")
local i = ls.insert_node
local func_node = ls.function_node

local s = ls.snippet
local t = ls.text_node

local function find_first_party_module()
  local modules = python_utils.get_cached_first_party_modules()
  if modules == nil then
    return nil
  end
  return modules[1]
end

return {
  -- dictionary
  s({ trig = "[[", wordTrig = false }, {
    t({ '["' }),
    i(1),
    t({ '"]' }),
    i(0),
  }),

  -- logging
  s("li(", {
    t({ "logger.info(" }),
    i(1, "message"),
    t({ [[)]] }),
    i(0),
  }),
  s("ld(", {
    t({ "logger.debug(" }),
    i(1, "message"),
    t({ [[)]] }),
    i(0),
  }),
  s("lw(", {
    t({ "logger.warning(" }),
    i(1, "message"),
    t({ [[)]] }),
    i(0),
  }),
  s("le(", {
    t({ "logger.error(" }),
    i(1, "message"),
    t({ [[)]] }),
    i(0),
  }),
  s("lc(", {
    t({ "logger.critical(" }),
    i(1, "message"),
    t({ [[)]] }),
    i(0),
  }),
  s("lee(", {
    t({ "logger.exception(" }),
    i(1, "message"),
    t({ [[)]] }),
    i(0),
  }),

  s("li", {
    t({ "logger.info" }),
  }),
  s("ld", {
    t({ "logger.debug" }),
  }),
  s("lw", {
    t({ "logger.warning" }),
  }),
  s("le", {
    t({ "logger.error" }),
  }),
  s("lc", {
    t({ "logger.critical" }),
  }),
  s("lee", {
    t({ "logger.exception" }),
  }),

  -- Jupynium markdown cell
  s("md", {
    t({ "# %% [md]", [["""]], "" }),
    i(1),
    t({ "", [["""]], "" }),
    i(0),
  }),

  s("main", {
    t({
      "def main():",
      "\t",
    }),
    i(1, "pass"),
    t({
      "",
      "",
      "",
      [[if __name__ == "__main__":]],
      "\tmain()",
      "",
    }),
    i(0),
  }),

  s("logmain", {
    t({
      "import rich.traceback",
      "",
      "rich.traceback.install(show_locals=True)",
      "",
      "import logging",
      "",
      "from ",
    }),
    func_node(find_first_party_module, {}),
    t({
      ".utils import setup_logging",
      "",
      "logger = logging.getLogger(__name__)",
      "",
      "",
      [[def main():]],
      "\t",
    }),
    i(1, "pass"),
    t({
      "",
      "",
      "",
      [[if __name__ == "__main__":]],
      "\ttry:",
      "\t\tsetup_logging()",
      "\t\tmain()",
      "\texcept Exception:",
      "\t\t" .. [[logger.exception("Exception occurred")]],
      "",
    }),
    i(0),
  }),
  -- s("argparse", {
  --   func_node(function()
  --     local content =
  --       read_from_url "https://gist.githubusercontent.com/kiyoon/bd5334f03136bad752b358f71fc00eca/raw/argparse_example.py"
  --     return content
  --   end, {}),
  -- }),
  s("config", {
    func_node(function()
      local content = url_utils.read_from_url(
        "https://gist.githubusercontent.com/kiyoon/19eea0ea71228ac0f519319ac380ab13/raw/config.py"
      )
      return content
    end, {}),
  }),
  s("mkdir", {
    t({ "mkdir(parents=True, exist_ok=True)" }),
  }),
  s("sdir", {
    t({ "SCRIPT_DIR = Path(__file__).resolve().parent" }),
  }),

  -- Typing
  s("sp", {
    t({ "str | PathLike" }),
  }),
  s("spn", {
    t({ "str | PathLike | None" }),
  }),

  -- Comments
  s("fo", {
    t({ "# fmt: on" }),
  }),
  s("ff", {
    t({ "# fmt: off" }),
  }),

  -- PEP 723 inline script metadata
  -- https://peps.python.org/pep-0723/
  s("script", {
    t({ "# /// script", [[# requires-python = ">=3.]] }),
    i(1, "12"),
    t({ [["]], "# dependencies = [", [[#    "]] }),
    i(2, "requests"),
    t({ [[",]], "# ]", "# ///", "" }),
    i(0),
  }),
}
