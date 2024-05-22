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
      local git_root = vim.fs.root(0, ".git")
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
      tqdm = "tqdm",
      EasyDict = "easydict",
      stringify_unsupported = "neptune.utils",
      Console = "rich.console",
      Table = "rich.table",
      Progress = "rich.progress",
      Traceback = "rich.traceback",
      Theme = "rich.theme",
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

    local function get_python_import(statement)
      if statement == nil then
        return nil
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

      if python_import_as[statement] ~= nil then
        return { "import " .. python_import_as[statement] .. " as " .. statement }
      end

      if python_import_from[statement] ~= nil then
        return { "from " .. python_import_from[statement] .. " import " .. statement }
      end

      return { "import " .. statement }
    end

    local function add_python_import(module)
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

      import_statements = get_python_import(module)
      assert(import_statements ~= nil)

      vim.api.nvim_buf_set_lines(0, line_number - 1, line_number - 1, false, import_statements)

      return line_number, import_statements
    end

    local function add_python_import_current_word()
      local module = get_current_word()
      -- local module = vim.fn.expand "<cword>"
      return add_python_import(module)
    end

    local function add_python_import_current_selection()
      vim.cmd [[normal! "sy]]
      return add_python_import(vim.fn.getreg "s")
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
        vim.notify(import_statements, "info", {
          title = "Python import added at line " .. line_number,
          on_open = function(win)
            local buf = vim.api.nvim_win_get_buf(win)
            vim.api.nvim_buf_call(buf, function()
              vim.api.nvim_cmd({ cmd = "setfiletype", args = { "python" } }, {})
            end)
          end,
        })
      end
    end, { silent = true, desc = "Add python import" })
    vim.keymap.set("x", "<M-CR>", function()
      local line_number, import_statements = add_python_import_current_selection()
      if line_number ~= nil then
        vim.notify(import_statements, "info", {
          title = "Python import added at line " .. line_number,
          on_open = function(win)
            local buf = vim.api.nvim_win_get_buf(win)
            vim.api.nvim_buf_call(buf, function()
              vim.api.nvim_cmd({ cmd = "setfiletype", args = { "python" } }, {})
            end)
          end,
        })
      end
    end, { silent = true, desc = "Add python import" })

    vim.keymap.set({ "n" }, "<space>tr", function()
      local statements = { "import rich.traceback", "", "rich.traceback.install(show_locals=True)", "" }

      local line_number = find_first_python_import()
      if line_number == nil then
        line_number = find_python_after_module_docstring()
        if line_number == nil then
          line_number = 1
        end
      else
        -- first import found. Check if rich traceback already installed
        local lines = vim.api.nvim_buf_get_lines(0, line_number - 1, line_number - 1 + 3, false)
        if lines[1] == statements[1] and lines[2] == statements[2] and lines[3] == statements[3] then
          vim.notify("Rich traceback already installed", "info", {
            title = "Python auto import",
          })
          return
        end
      end

      vim.api.nvim_buf_set_lines(0, line_number - 1, line_number - 1, false, statements)
      vim.notify(statements, "info", {
        title = "Rich traceback install added at line " .. line_number,
        on_open = function(win)
          local buf = vim.api.nvim_win_get_buf(win)
          vim.api.nvim_buf_call(buf, function()
            vim.api.nvim_cmd({ cmd = "setfiletype", args = { "python" } }, {})
          end)
        end,
      })
    end, { silent = true, desc = "Add rich traceback install" })
  end,
})
