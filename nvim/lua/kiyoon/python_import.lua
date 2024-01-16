local function find_first_python_empty_line_or_import(max_lines)
  max_lines = max_lines or 50
  local bufnr = vim.fn.bufnr()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, max_lines, false)
  for i, line in ipairs(lines) do
    local node = vim.treesitter.get_node { pos = { i - 1, 0 } }
    if node == nil or node:type() == "module" then
      local stripped = line:match "^%s*(.*)%s*$"
      if stripped == "" then
        return i
      end
    elseif node:type() == "import_statement" or node:type() == "import_from_statement" then
      return i
    end
  end
  return nil
end

local python_import_as = {
  np = "numpy",
  pd = "pandas",
  plt = "matplotlib.pyplot",
  o3d = "open3d",
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

  contextmanager = "contextlib",
  nullcontext = "contextlib",
  closing = "contextlib",
  deepcopy = "copy",
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

  Annotation = "typing",
  Any = "typing",
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
  Union = "typing",
  AbstractSet = "typing",
  ByteString = "typing",
  Container = "typing",
  ContextManager = "typing",
  Hashable = "typing",
  ItemsView = "typing",
  Iterable = "typing",
  Iterator = "typing",
  KeysView = "typing",
  Mapping = "typing",
  MappingView = "typing",
  MutableMapping = "typing",
  MutableSequence = "typing",
  MutableSet = "typing",
  Sequence = "typing",
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
  OrderedDict = "typing",
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

  setup = "setuptools",

  nn = "torch",
  Image = "PIL",
  ImageDraw = "PIL",
  ImageFont = "PIL",
  ImageOps = "PIL",
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
  print(start, finish)
  return line:sub(start + 1, finish - 1)
end

local function get_python_import(statement)
  if statement == nil then
    return nil
  end

  if python_import_as[statement] ~= nil then
    return "import " .. python_import_as[statement] .. " as " .. statement
  end

  if python_import_from[statement] ~= nil then
    return "from " .. python_import_from[statement] .. " import " .. statement
  end

  return "import " .. statement
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

  local line_number = find_first_python_empty_line_or_import()
  if line_number == nil then
    line_number = 1
  end

  local import_statement = get_python_import(module)
  vim.api.nvim_buf_set_lines(0, line_number - 1, line_number - 1, false, { import_statement })

  return line_number, import_statement
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

vim.api.nvim_create_augroup("python_import", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = "python_import",
  pattern = "python",
  callback = function()
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
      local line_number, import_statement = add_python_import_current_word()
      if line_number ~= nil then
        vim.notify(import_statement, "info", {
          title = "Python import added",
          on_open = function(win)
            local buf = vim.api.nvim_win_get_buf(win)
            vim.api.nvim_buf_set_option(buf, "filetype", "python")
          end,
        })
      end
    end, { silent = true, desc = "Add python import" })
    vim.keymap.set("x", "<M-CR>", function()
      local line_number, import_statement = add_python_import_current_selection()
      if line_number ~= nil then
        vim.notify(import_statement, "info", {
          title = "Python import added",
          on_open = function(win)
            local buf = vim.api.nvim_win_get_buf(win)
            vim.api.nvim_buf_set_option(buf, "filetype", "python")
          end,
        })
      end
    end, { silent = true, desc = "Add python import" })
  end,
})