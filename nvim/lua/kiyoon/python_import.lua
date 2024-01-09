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

  nn = "torch",
  Image = "PIL",
  ImageDraw = "PIL",
  ImageFont = "PIL",
  ImageOps = "PIL",
}

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
  local line_number = find_first_python_empty_line_or_import()
  if line_number == nil then
    line_number = 1
  end

  vim.api.nvim_buf_set_lines(0, line_number - 1, line_number - 1, false, { get_python_import(module) })

  return line_number
end

local function add_python_import_current_word()
  local module = vim.fn.expand "<cword>"
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
      local line_number = add_python_import_current_word()
      vim.cmd([[normal! ]] .. line_number .. [[G0]])
    end, { silent = true, desc = "Add python import and move cursor" })
    vim.keymap.set("x", "<leader>i", function()
      local line_number = add_python_import_current_selection()
      vim.cmd([[normal! ]] .. line_number .. [[G0]])
    end, { silent = true, desc = "Add python import and move cursor" })

    vim.keymap.set({ "n", "i" }, "<M-CR>", function()
      add_python_import_current_word()
      vim.notify("Added python import: " .. vim.fn.expand "<cword>")
    end, { silent = true, desc = "Add python import" })
    vim.keymap.set("x", "<M-CR>", function()
      add_python_import_current_selection()
      vim.notify("Added python import: " .. vim.fn.getreg "s")
    end, { silent = true, desc = "Add python import" })
  end,
})
