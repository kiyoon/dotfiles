local ls = require "luasnip"
local i = ls.insert_node
local func_node = ls.function_node

local s = ls.snippet
local t = ls.text_node

local function read_from_url(url)
  -- curl without progress bar
  local content = vim.fn.system("curl -s " .. url)
  -- local content = vim.fn.system("curl " .. url)
  -- split by newline
  local split_content = vim.fn.split(content, "\n")
  return split_content
end

local function find_python_first_party_modules()
  -- find src/module_name in git root

  local git_root = vim.fn.systemlist "git rev-parse --show-toplevel"
  if #git_root == 0 then
    return nil
  end
  git_root = git_root[1]

  local src_dir = git_root .. "/src"
  if vim.fn.isdirectory(src_dir) == 0 then
    return nil
  end

  local modules = {}
  local function find_modules(dir)
    local files = vim.fn.readdir(dir)
    for _, file in ipairs(files) do
      local path = dir .. "/" .. file
      local stat = vim.loop.fs_stat(path)
      if stat.type == "directory" then
        -- no egg-info
        if file:match "%.egg%-info$" == nil then
          modules[#modules + 1] = file
        end
      end
    end
  end
  find_modules(src_dir)

  if #modules == 0 then
    return nil
  end

  return modules
end

local function find_first_party_module()
  local modules = find_python_first_party_modules()
  if modules == nil then
    return nil
  end
  return modules[1]
end

return {
  s("li(", {
    t { "logger.info(" },
    i(1, "message"),
    t { [[)]] },
    i(0),
  }),
  s("ld(", {
    t { "logger.debug(" },
    i(1, "message"),
    t { [[)]] },
    i(0),
  }),
  s("lw(", {
    t { "logger.warning(" },
    i(1, "message"),
    t { [[)]] },
    i(0),
  }),
  s("le(", {
    t { "logger.error(" },
    i(1, "message"),
    t { [[)]] },
    i(0),
  }),
  s("lc(", {
    t { "logger.critical(" },
    i(1, "message"),
    t { [[)]] },
    i(0),
  }),
  s("lee(", {
    t { "logger.exception(" },
    i(1, "message"),
    t { [[)]] },
    i(0),
  }),

  s("li", {
    t { "logger.info" },
  }),
  s("ld", {
    t { "logger.debug" },
  }),
  s("lw", {
    t { "logger.warning" },
  }),
  s("le", {
    t { "logger.error" },
  }),
  s("lc", {
    t { "logger.critical" },
  }),
  s("lee", {
    t { "logger.exception" },
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
      "import rich.traceback",
      "",
      "rich.traceback.install(show_locals=True)",
      "",
      "import logging",
      "",
      "from ",
    },
    func_node(find_first_party_module, {}),
    t {
      ".utils import setup_logging",
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
      "\t\tsetup_logging()",
      "\t\tmain()",
      "\texcept Exception:",
      "\t\t" .. [[logger.exception("Exception occurred")]],
      "",
    },
    i(0),
  }),
  s("argparse", {
    func_node(function()
      local content =
        read_from_url "https://gist.githubusercontent.com/kiyoon/bd5334f03136bad752b358f71fc00eca/raw/argparse_example.py"
      return content
    end, {}),
  }),
  s("config", {
    func_node(function()
      local content =
        read_from_url "https://gist.githubusercontent.com/kiyoon/19eea0ea71228ac0f519319ac380ab13/raw/config.py"
      return content
    end, {}),
  }),
  s("sp", {
    t { "str | PathLike" },
  }),
  s("spn", {
    t { "str | PathLike | None" },
  }),
  s("mkdir", {
    t { "mkdir(parents=True, exist_ok=True)" },
  }),
}
