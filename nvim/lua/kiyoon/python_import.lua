local status, notify = pcall(require, "notify")
if not status then
  notify = function(message, level, opts) end
end

vim.api.nvim_create_augroup("python_import", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = "python_import",
  pattern = "python",
  callback = function()
    local function find_python_after_module_docstring(max_lines)
      max_lines = max_lines or 50
      local bufnr = vim.fn.bufnr()
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, max_lines, false)
      for i, line in ipairs(lines) do
        local node = vim.treesitter.get_node { pos = { i - 1, 0 } }
        -- if node == nil or node:type() == "module" then
        --   local stripped = line:match "^%s*(.*)%s*$"
        --   if stripped == "" then
        --     return i
        --   end
        -- elseif node:type() == "import_statement" or node:type() == "import_from_statement" then
        --   return i
        if
          node ~= nil
          and node:type() ~= "comment"
          and node:type() ~= "string"
          and node:type() ~= "string_start"
          and node:type() ~= "string_content"
          and node:type() ~= "string_end"
        then
          return i
        end
      end
      return nil
    end

    local function find_first_python_import(max_lines)
      max_lines = max_lines or 50
      local bufnr = vim.fn.bufnr()
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, max_lines, false)
      for i, line in ipairs(lines) do
        local node = vim.treesitter.get_node { pos = { i - 1, 0 } }
        if node ~= nil and (node:type() == "import_statement" or node:type() == "import_from_statement") then
          -- additional check whether the node is top-level.
          -- if not, it's probably an import inside a function
          if node:parent():type() == "module" then
            return i
          end
        end
      end
      return nil
    end

    local function find_last_python_import(max_lines)
      max_lines = max_lines or 50
      local bufnr = vim.fn.bufnr()
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, max_lines, false)
      -- iterate backwards
      for i = #lines, 1, -1 do
        local node = vim.treesitter.get_node { pos = { i - 1, 0 } }
        if node ~= nil and (node:type() == "import_statement" or node:type() == "import_from_statement") then
          -- additional check whether the node is top-level.
          -- if not, it's probably an import inside a function
          if node:parent():type() == "module" then
            return i
          end
        end
      end
      return nil
    end

    local function find_python_first_party_modules()
      -- find src/module_name in git root

      -- local git_root = vim.fn.systemlist "git rev-parse --show-toplevel"
      local git_root = vim.fs.root(0, { ".git", "pyproject.toml" })
      if git_root == nil then
        return nil
      end

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

    -- If nothing is found, it will return `import ..` anyway.
    -- However, it might take some time to search the candidate,
    -- so we define a list of common imports here.
    local python_import = {
      "pickle",
      "os",
      "sys",
      "re",
      "json",
      "time",
      "datetime",
      "random",
      "math",
      "importlib",
      "argparse",
      "shutil",
      "copy",
      "dataclasses",
      "enum",
      "functools",
      "glob",
      "itertools",
      "pathlib",
      "pprint",
      "abc",
      "contextlib",
      "collections",
      "io",
      "multiprocessing",
      "typing",
      "typing_extensions",
      "setuptools",

      -- third-party
      "PIL",
      "tqdm",
      "easydict",
      "rich",
      "selenium",
      "neptune",
      "torch",
    }

    local is_python_import = {}
    for _, v in ipairs(python_import) do
      is_python_import[v] = true
    end

    local python_import_as = {
      mp = "multiprocessing",
      np = "numpy",
      pd = "pandas",
      pl = "polars",
      plt = "matplotlib.pyplot",
      o3d = "open3d",
      F = "torch.nn.functional",
      tf = "tensorflow",
      nx = "networkx",
      rx = "rustworkx",
    }

    local python_import_from = {
      ABC = "abc",
      ABCMeta = "abc",
      abstractclassmethod = "abc",
      abstractmethod = "abc",
      abstractproperty = "abc",
      abstractstaticmethod = "abc",

      ArgumentParser = "argparse",
      ArgumentError = "argparse",
      ArgumentTypeError = "argparse",
      HelpFormatter = "argparse",
      ArgumentDefaultsHelpFormatter = "argparse",
      RawDescriptionHelpFormatter = "argparse",
      RawTextHelpFormatter = "argparse",
      MetavarTypeHelpFormatter = "argparse",
      Namespace = "argparse",

      copy2 = "shutil",
      contextmanager = "contextlib",
      nullcontext = "contextlib",
      closing = "contextlib",
      deepcopy = "copy",

      OrderedDict = "collections",
      namedtuple = "collections",
      defaultdict = "collections",

      Iterable = "collections.abc",
      Sequence = "collections.abc",

      date = "datetime",
      -- datetime = "datetime",
      timezone = "datetime",

      dataclass = "dataclasses",
      field = "dataclasses",
      fields = "dataclasses",
      asdict = "dataclasses",
      astuple = "dataclasses",
      is_dataclass = "dataclasses",
      make_dataclass = "dataclasses",
      Enum = "enum",
      EnumMeta = "enum",
      Flag = "enum",
      IntEnum = "enum",
      IntFlag = "enum",

      update_wrapper = "functools",
      wraps = "functools",
      WRAPPER_ASSIGNMENTS = "functools",
      WRAPPER_UPDATES = "functools",
      total_ordering = "functools",
      cache = "functools",
      cmp_to_key = "functools",
      lru_cache = "functools",
      reduce = "functools",
      partial = "functools",
      partialmethod = "functools",
      singledispatch = "functools",
      singledispatchmethod = "functools",
      cached_property = "functools",

      glob = "glob",
      iglob = "glob",

      Pool = "multiprocessing",
      Process = "multiprocessing",
      Queue = "multiprocessing",
      RawValue = "multiprocessing",
      Semaphore = "multiprocessing",
      Value = "multiprocessing",

      import_module = "importlib",
      invalidate_caches = "importlib",
      reload = "importlib",

      BlockingIOError = "io",
      IOBase = "io",
      RawIOBase = "io",
      FileIO = "io",
      BytesIO = "io",
      StringIO = "io",
      BufferedIOBase = "io",
      BufferedReader = "io",
      BufferedWriter = "io",
      TextIOBase = "io",
      TextIOWrapper = "io",

      accumulate = "itertools",
      chain = "itertools",
      combinations = "itertools",
      combinations_with_replacement = "itertools",
      compress = "itertools",
      count = "itertools",
      cycle = "itertools",
      dropwhile = "itertools",
      filterfalse = "itertools",
      groupby = "itertools",
      islice = "itertools",
      pairwise = "itertools",
      permutations = "itertools",
      product = "itertools",
      ["repeat"] = "itertools",
      starmap = "itertools",
      takewhile = "itertools",
      tee = "itertools",
      zip_longest = "itertools",

      PathLike = "os",

      PurePath = "pathlib",
      PurePosixPath = "pathlib",
      PureWindowsPath = "pathlib",
      Path = "pathlib",
      PosixPath = "pathlib",
      WindowsPath = "pathlib",

      pprint = "pprint",
      pformat = "pprint",
      isreadable = "pprint",
      isrecursive = "pprint",
      saferepr = "pprint",
      PrettyPrinter = "pprint",
      pp = "pprint",

      Annotated = "typing",
      Annotation = "typing",
      Any = "typing", -- when you don't know the type
      Incomplete = "typing", -- alias for Any, but indicates that the type hint should be completed later
      Callable = "typing",
      ClassVar = "typing",
      Concatenate = "typing",
      Final = "typing",
      ForwardRef = "typing",
      Generic = "typing",
      Literal = "typing",
      Optional = "typing",
      ParamSpec = "typing",
      Protocol = "typing",
      Tuple = "typing",
      Type = "typing",
      TypeVar = "typing",
      TYPE_CHECKING = "typing",
      Union = "typing",
      AbstractSet = "typing",
      ByteString = "typing",
      Container = "typing",
      ContextManager = "typing",
      Hashable = "typing",
      ItemsView = "typing",
      Iterator = "typing",
      KeysView = "typing",
      Mapping = "typing",
      MappingView = "typing",
      MutableMapping = "typing",
      MutableSequence = "typing",
      MutableSet = "typing",
      Sized = "typing",
      ValuesView = "typing",
      Awaitable = "typing",
      AsyncIterator = "typing",
      AsyncIterable = "typing",
      Coroutine = "typing",
      Collection = "typing",
      AsyncGenerator = "typing",
      AsyncContextManager = "typing",
      Reversible = "typing",
      SupportsAbs = "typing",
      SupportsBytes = "typing",
      SupportsComplex = "typing",
      SupportsFloat = "typing",
      SupportsIndex = "typing",
      SupportsInt = "typing",
      SupportsRound = "typing",
      ChainMap = "typing",
      Counter = "typing",
      Deque = "typing",
      Dict = "typing",
      DefaultDict = "typing",
      List = "typing",
      Set = "typing",
      FrozenSet = "typing",
      NamedTuple = "typing",
      TypedDict = "typing",
      Generator = "typing",
      BinaryIO = "typing",
      IO = "typing",
      Match = "typing",
      Pattern = "typing",
      TextIO = "typing",
      AnyStr = "typing",
      NewType = "typing",
      NoReturn = "typing",
      ParamSpecArgs = "typing",
      ParamSpecKwargs = "typing",
      Text = "typing",
      TypeAlias = "typing",
      TypeGuard = "typing",
      override = "typing",
      overload = "typing",

      deprecated = "typing_extensions",

      setup = "setuptools",

      nn = "torch",
      Image = "PIL",
      ImageDraw = "PIL",
      ImageFont = "PIL",
      ImageOps = "PIL",
      tqdm = "tqdm.auto",
      EasyDict = "easydict",
      stringify_unsupported = "neptune.utils",
      Console = "rich.console",
      Table = "rich.table",
      Progress = "rich.progress",
      Traceback = "rich.traceback",
      Theme = "rich.theme",
      WebDriver = "selenium.webdriver.remote.webdriver",
    }

    local python_keywords = {
      "False",
      "None",
      "True",
      "and",
      "as",
      "assert",
      "async",
      "await",
      "break",
      "class",
      "continue",
      "def",
      "del",
      "elif",
      "else",
      "except",
      "finally",
      "for",
      "from",
      "global",
      "if",
      "import",
      "in",
      "is",
      "lambda",
      "nonlocal",
      "not",
      "or",
      "pass",
      "raise",
      "return",
      "try",
      "while",
      "with",
      "yield",
      "NotImplemented",
    }

    -- not a keyword, but a builtin
    -- https://docs.python.org/3/library/functions.html
    local python_builtins = {
      "abs",
      "aiter",
      "all",
      "anext",
      "any",
      "ascii",
      "bin",
      "bool",
      "breakpoint",
      "bytearray",
      "bytes",
      "callable",
      "chr",
      "classmethod",
      "compile",
      "complex",
      "delattr",
      "dict",
      "dir",
      "divmod",
      "enumerate",
      "eval",
      "exec",
      "filter",
      "float",
      "format",
      "frozenset",
      "getattr",
      "globals",
      "hasattr",
      "hash",
      "help",
      "hex",
      "id",
      "input",
      "int",
      "isinstance",
      "issubclass",
      "iter",
      "len",
      "list",
      "locals",
      "map",
      "max",
      "memoryview",
      "min",
      "next",
      "object",
      "oct",
      "open",
      "ord",
      "pow",
      "print",
      "property",
      "range",
      "repr",
      "reversed",
      "round",
      "set",
      "setattr",
      "slice",
      "sorted",
      "staticmethod",
      "str",
      "sum",
      "super",
      "tuple",
      "type",
      "vars",
      "zip",
      "__import__",
      "_",
    }

    local ban_from_import = {}
    for _, v in ipairs(python_keywords) do
      ban_from_import[v] = true
    end
    for _, v in ipairs(python_builtins) do
      ban_from_import[v] = true
    end

    local function get_current_word()
      local line = vim.fn.getline "."
      local col = vim.fn.col "."
      local mode = vim.fn.mode "."
      if mode == "i" then
        -- insert mode has cursor one char to the right
        col = col - 1
      end
      local finish = line:find("[^a-zA-Z0-9_]", col)
      -- look forward
      while finish == col do
        col = col + 1
        finish = line:find("[^a-zA-Z0-9_]", col)
      end

      if finish == nil then
        finish = #line + 1
      end
      local start = vim.fn.match(line:sub(1, col), [[\k*$]])
      return line:sub(start + 1, finish - 1)
    end

    local first_party_modules = find_python_first_party_modules()

    ---@param statement string
    ---@param ts_node TSNode?
    ---@return string[]?
    local function get_python_import(statement, ts_node)
      if statement == nil then
        return nil
      end

      if ts_node ~= nil then
        -- check if currently on
        -- class Data(torch.utils.data.Dataset):
        -- then import torch.utils.data

        -- (class_definition ; [9, 0] - [10, 8]
        --   name: (identifier) ; [9, 6] - [9, 10]
        --   superclasses: (argument_list ; [9, 10] - [9, 36]
        --     (attribute ; [9, 11] - [9, 35]
        --       object: (attribute ; [9, 11] - [9, 27]
        --         object: (attribute ; [9, 11] - [9, 22]
        --           object: (identifier) ; [9, 11] - [9, 16]
        --           attribute: (identifier)) ; [9, 17] - [9, 22]
        --         attribute: (identifier)) ; [9, 23] - [9, 27]
        --       attribute: (identifier))) ; [9, 28] - [9, 35]
        --   body: (block ; [10, 4] - [10, 8]
        --     (pass_statement))) ; [10, 4] - [10, 8]

        if ts_node:type() == "identifier" then
          -- climb up until we find argument_list
          local parent = ts_node:parent()
          while parent ~= nil and parent:type() ~= "argument_list" do
            parent = parent:parent()
          end

          if parent ~= nil and parent:type() == "argument_list" then
            local superclasses_text = vim.treesitter.get_node_text(parent, 0)
            -- print(superclasses_text)  -- (torch.utils.data.Dataset)
            if superclasses_text:match "^%(torch%.utils%.data%." then
              return { "import torch.utils.data" }
            end
          end
        end
      end

      if statement == "logger" then
        return { "import logging", "", "logger = logging.getLogger(__name__)" }
      end

      -- extend from .. import *
      if first_party_modules ~= nil then
        local first_module = first_party_modules[1]
        -- if statement ends with _DIR, import from the first module (from project import PROJECT_DIR)
        if statement:match "_DIR$" then
          return { "from " .. first_module .. " import " .. statement }
        elseif statement == "setup_logging" then
          return { "from " .. first_module .. ".utils.log import setup_logging" }
        end
      end

      if is_python_import[statement] then
        return { "import " .. statement }
      end

      if python_import_as[statement] ~= nil then
        return { "import " .. python_import_as[statement] .. " as " .. statement }
      end

      if python_import_from[statement] ~= nil then
        return { "from " .. python_import_from[statement] .. " import " .. statement }
      end

      -- Can't find from pre-defined tables.
      -- Search the project directory for the import statements
      -- Sorted from the most frequently used
      -- e.g. 00020:import ABCD

      local project_root = vim.fs.root(0, { ".git", "pyproject.toml" })
      if project_root ~= nil then
        local find_import_outputs = vim.api.nvim_exec(
          [[w !/usr/bin/python3 ~/.config/nvim/find_python_import_in_project.py count ']]
            .. project_root
            .. [[' ']]
            .. statement
            .. [[']],
          { output = true }
        )

        if find_import_outputs ~= nil then
          -- strip
          find_import_outputs = find_import_outputs:gsub("^\n", "")
          -- find_import_outputs = find_import_outputs:match "^%s*(.*)%s*$"
          -- strip trailing newline
          find_import_outputs = find_import_outputs:gsub("\n$", "")
          -- find_import_outputs = find_import_outputs:match "^%s*(.*)%s*$"

          if find_import_outputs ~= "" then
            local find_import_outputs_split = vim.split(find_import_outputs, "\n")
            -- print(#find_import_outputs_split)
            if #find_import_outputs_split == 1 then
              local import_statement = { find_import_outputs_split[1]:sub(7) } -- remove the count
              return import_statement
            end

            local outputs_to_inputlist = {}
            for i, v in ipairs(find_import_outputs_split) do
              local count = tonumber(v:sub(1, 5))
              local import_statement = v:sub(7) -- remove the count

              outputs_to_inputlist[i] = string.format("%d. count %d: %s", i, count, import_statement)
            end

            local choice = vim.fn.inputlist(outputs_to_inputlist)
            if choice == 0 then
              return nil
            end

            local import_statement = find_import_outputs_split[choice]:sub(7) -- remove the count
            return { import_statement }
          end
        end
      end

      return { "import " .. statement }
    end

    ---@param module string
    ---@param ts_node TSNode?
    ---@return integer?, string[]?
    local function add_python_import(module, ts_node)
      -- strip
      module = module:match "^%s*(.*)%s*$"
      if module == "" then
        return nil
      end
      if ban_from_import[module] then
        return nil
      end

      local import_statements = nil
      -- prefer to add after last import
      local line_number = find_last_python_import()
      if line_number == nil then
        -- if no import, add to first empty line
        line_number = find_python_after_module_docstring()
        if line_number == nil then
          line_number = 1
        end
      else
        line_number = line_number + 1 -- add after last import
      end

      import_statements = get_python_import(module, ts_node)
      if import_statements == nil then
        notify("No import statement found or it was aborted, for `" .. module .. "`", "warn", {
          title = "Python auto import",
          on_open = function(win)
            local buf = vim.api.nvim_win_get_buf(win)
            vim.bo[buf].filetype = "markdown"
          end,
        })
        return nil, nil
      end

      vim.api.nvim_buf_set_lines(0, line_number - 1, line_number - 1, false, import_statements)

      return line_number, import_statements
    end

    local function add_python_import_current_word()
      local module = get_current_word()
      local node = require("wookayin.utils.ts_utils").get_node_at_cursor()
      -- local module = vim.fn.expand "<cword>"
      return add_python_import(module, node)
    end

    local function add_python_import_current_selection()
      vim.cmd [[normal! "sy]]
      local node = require("wookayin.utils.ts_utils").get_node_at_cursor()
      return add_python_import(vim.fn.getreg "s", node)
    end

    vim.keymap.set("n", "<leader>i", function()
      local line_number, _ = add_python_import_current_word()
      if line_number ~= nil then
        vim.cmd([[normal! ]] .. line_number .. [[G0]])
      end
    end, { silent = true, desc = "Add python import and move cursor" })
    vim.keymap.set("x", "<leader>i", function()
      local line_number, _ = add_python_import_current_selection()
      if line_number ~= nil then
        vim.cmd([[normal! ]] .. line_number .. [[G0]])
      end
    end, { silent = true, desc = "Add python import and move cursor" })

    vim.keymap.set({ "n", "i" }, "<M-CR>", function()
      local line_number, import_statements = add_python_import_current_word()
      if line_number ~= nil then
        notify(import_statements, "info", {
          title = "Python import added at line " .. line_number,
          on_open = function(win)
            local buf = vim.api.nvim_win_get_buf(win)
            vim.bo[buf].filetype = "python"
          end,
        })
      end
    end, { silent = true, desc = "Add python import" })
    vim.keymap.set("x", "<M-CR>", function()
      local line_number, import_statements = add_python_import_current_selection()
      if line_number ~= nil then
        notify(import_statements, "info", {
          title = "Python import added at line " .. line_number,
          on_open = function(win)
            local buf = vim.api.nvim_win_get_buf(win)
            vim.bo[buf].filetype = "python"
          end,
        })
      end
    end, { silent = true, desc = "Add python import" })

    vim.keymap.set({ "n" }, "<space>tr", function()
      local statements = { "import rich.traceback", "", "rich.traceback.install(show_locals=True)", "" }

      local line_number = find_first_python_import() ---@type integer | nil

      if line_number == nil then
        line_number = find_python_after_module_docstring()
        if line_number == nil then
          line_number = 1
        end
      else
        -- first import found. Check if rich traceback already installed
        local lines = vim.api.nvim_buf_get_lines(0, line_number - 1, line_number - 1 + 3, false)
        if lines[1] == statements[1] and lines[2] == statements[2] and lines[3] == statements[3] then
          notify("Rich traceback already installed", "info", {
            title = "Python auto import",
          })
          return
        end
      end

      vim.api.nvim_buf_set_lines(0, line_number - 1, line_number - 1, false, statements)
      notify(statements, "info", {
        title = "Rich traceback install added at line " .. line_number,
        on_open = function(win)
          local buf = vim.api.nvim_win_get_buf(win)
          vim.bo[buf].filetype = "python"
        end,
      })
    end, { silent = true, desc = "Add rich traceback install" })
  end,
})

M = {}

---WIP
---Given we already know the row and col of the module name (e.g. using ruff we found "np")
---This will return the whole import statement (e.g. "import numpy as np")
---We assume that there is only one import statement for that name in the file
---@param file_path string
---@param row integer
---@param col integer
---@param name string
---@return string?
local open_python_file_and_get_import = function(file_path, row, col, name)
  local buffers = vim.api.nvim_list_bufs()
  vim.print(buffers)
  file_path = file_path or "/Users/kiyoon/project/dti-db-curation/tools/process_dtc.py" -- open file silently
  name = name or "refine_assay_format"
  row = row or 6
  col = col or 4

  -- 이렇게 하면 파일이 열려있을 경우 swap error가 발생함
  local bufnr = vim.fn.bufadd(file_path)

  -- Open file but ignore swap error. We're going to open it read-only
  -- local bufnr = vim.api.nvim_create_buf(true, false)
  -- vim.api.nvim_buf_call(bufnr, function()
  --   -- vim.bo[bufnr].swapfile = false
  --   -- vim.bo[bufnr].modifiable = false
  --   -- vim.bo[bufnr].readonly = true
  --   -- vim.bo[bufnr].bufhidden = "wipe"
  --   -- vim.bo[bufnr].buftype = "nofile"
  --   vim.api.nvim_command("edit " .. file_path)
  -- end)

  -- get all buffers
  local buffers = vim.api.nvim_list_bufs()
  vim.print(buffers)

  -- get treesitter node
  vim.treesitter.get_parser(bufnr, "python"):parse()
  local node = vim.treesitter.get_node { bufnr = bufnr, pos = { row, col } }
  vim.print(node:range())
  vim.print(node:type())

  if node == nil or node:type() ~= "identifier" then
    -- remove buffer
    vim.api.nvim_buf_delete(bufnr, { force = true })
    return nil
  end

  -- climb up until we find import_statement or import_from_statement
  local import_node = node
  while
    import_node ~= nil
    and import_node:type() ~= "import_statement"
    and import_node:type() ~= "import_from_statement"
  do
    import_node = import_node:parent()
  end

  if import_node == nil then
    -- not an import statement
    return nil
  end

  local parent_node = node:parent()
  if parent_node == nil then
    -- remove buffer
    vim.api.nvim_buf_delete(bufnr, { force = true })
    return nil
  end

  if parent_node:type() == "aliased_import" then
    -- import .. as ..
    --
    -- (import_statement ; [15, 0] - [15, 18]
    --   name: (aliased_import ; [15, 7] - [15, 18]
    --     name: (dotted_name ; [15, 7] - [15, 12]
    --       (identifier)) ; [15, 7] - [15, 12]
    --     alias: (identifier))) ; [15, 16] - [15, 18]

    -- from .. import .. as ..

    -- (import_from_statement ; [2, 0] - [7, 1]
    --   module_name: (dotted_name ; [2, 5] - [2, 40]
    --     (identifier) ; [2, 5] - [2, 20]
    --     (identifier) ; [2, 21] - [2, 27]
    --     (identifier) ; [2, 28] - [2, 31]
    --     (identifier)) ; [2, 32] - [2, 40]
    --   name: (dotted_name ; [3, 4] - [3, 25]
    --     (identifier)) ; [3, 4] - [3, 25]
    --   name: (dotted_name ; [4, 4] - [4, 30]
    --     (identifier)) ; [4, 4] - [4, 30]
    --   name: (dotted_name ; [5, 4] - [5, 17]
    --     (identifier)) ; [5, 4] - [5, 17]
    --   name: (aliased_import ; [6, 4] - [6, 32]
    --     name: (dotted_name ; [6, 4] - [6, 25]
    --       (identifier)) ; [6, 4] - [6, 25]
    --     alias: (identifier))) ; [6, 29] - [6, 32]

    local grandparent_node = parent_node:parent()
    if grandparent_node == "import_statement" then
      -- import .. as ..
      local import_name = vim.treesitter.get_node_text(parent_node:child(1), bufnr)
      local import_as = vim.treesitter.get_node_text(parent_node:child(2), bufnr)
      return "import " .. import_name .. " as " .. import_as
    elseif grandparent_node == "import_from_statement" then
      -- from .. import .. as ..
      local import_from = vim.treesitter.get_node_text(grandparent_node:child(1), bufnr)
      local import_name = vim.treesitter.get_node_text(parent_node:child(1), bufnr)
      local import_as = vim.treesitter.get_node_text(parent_node:child(2), bufnr)
      return "from " .. import_from .. " import " .. import_name .. " as " .. import_as
    end
  elseif parent_node:type() == "import_statement" then
    -- import ..
    local import_name = vim.treesitter.get_node_text(node, bufnr)
    return "import " .. import_name
  elseif parent_node:type() == "import_from_statement" then
    -- from .. import ..
    local import_from = vim.treesitter.get_node_text(parent_node:child(1), bufnr)
    local import_name = vim.treesitter.get_node_text(node, bufnr)
    return "from " .. import_from .. " import " .. import_name
  else
    return nil
  end

  -- if import_node:type() == "import_statement" then
  --   if node:parent():type() == "aliased_import" then
  --   end
  --   if import_node:child(1):child(2) ~= nil then
  --     -- import .. as ..
  --     local import_name = vim.treesitter.get_node_text(import_node:child(1):child(1), bufnr)
  --     local import_as = vim.treesitter.get_node_text(import_node:child(1):child(2), bufnr)
  --     return "import " .. import_name .. " as " .. import_as
  --   else
  --     local import_name = vim.treesitter.get_node_text(import_node:child(1):child(1), bufnr)
  --     return "import " .. import_name
  --   end
  -- elseif import_node:type() == "import_from_statement" then
  --   local import_name = import_node:child(1):child(1):text()
  --   local import_as = import_node:child(3):child(1):text()
  --   return "from " .. import_name .. " import " .. import_as
  -- end

  -- remove buffer
  vim.api.nvim_buf_delete(bufnr, { force = true })
end

local function get_current_word()
  local line = vim.fn.getline "."
  local col = vim.fn.col "."
  local mode = vim.fn.mode "."
  if mode == "i" then
    -- insert mode has cursor one char to the right
    col = col - 1
  end
  local finish = line:find("[^a-zA-Z0-9_]", col)
  -- look forward
  while finish == col do
    col = col + 1
    finish = line:find("[^a-zA-Z0-9_]", col)
  end

  if finish == nil then
    finish = #line + 1
  end
  local start = vim.fn.match(line:sub(1, col), [[\k*$]])
  return line:sub(start + 1, finish - 1)
end

M.find_import_counts_in_project = function()
  local current_file = vim.fn.expand "%"
  local current_word = get_current_word()
  local git_root = vim.fs.root(0, { ".git", "pyproject.toml" })
  if git_root == nil then
    return nil
  end

  local bufnr = 0

  -- HACK: the `:w !rg` command will change the last paste register
  -- so we need to save it and restore it after the command
  local last_paste_start_line = vim.fn.line "'["
  local last_paste_start_col = vim.fn.col "'["
  local last_paste_end_line = vim.fn.line "']"
  local last_paste_end_col = vim.fn.col "']"

  local rg_outputs = vim.api.nvim_exec(
    [[w !find ']] .. git_root .. [[' -name '*.py' -type f | xargs rg --json ']] .. current_word .. [[']],
    { output = true }
  )
  print(rg_outputs)

  -- restore the last paste register
  vim.fn.setpos("'[", { bufnr, last_paste_start_line, last_paste_start_col, 0 })
  vim.fn.setpos("']", { bufnr, last_paste_end_line, last_paste_end_col, 0 })

  assert(rg_outputs ~= nil)
  local rg_outputs_split = vim.split(rg_outputs, "\n")

  for _, line in ipairs(rg_outputs_split) do
    local status, rg_output = pcall(vim.json.decode, line)

    if not status then
      goto continue
    end

    local type = rg_output["type"]
    -- type: "begin", "match", "end"
    if type == "match" then
      local data = rg_output["data"]
      local file = data["path"]["text"]
      local line_number = data["line_number"] - 1 ---@type integer
      -- local lines = data["lines"]["text"]
      local col = data["submatches"][1]["start"] - 1 ---@type integer

      if file == current_file then
        goto continue
      end

      local import_statement = open_python_file_and_get_import(file, line_number, col, current_word)
      if import_statement == nil then
        goto continue
      end

      notify(import_statement, "info", {
        title = "Python import found in " .. file,
        on_open = function(win)
          local buf = vim.api.nvim_win_get_buf(win)
          vim.bo[buf].filetype = "python"
        end,
      })

      ::continue::
    end

    ::continue::
  end
end

return M
