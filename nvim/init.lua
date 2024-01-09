vim.g.python3_host_prog = "/usr/bin/python3"
-- vim.g.python3_host_prog = "~/bin/miniconda3/envs/nvim/bin/python3"

local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system {
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  }
end
vim.opt.rtp:prepend(lazypath)

-- Load plugin specs from `~/.config/nvim/lua/kiyoon/lazy.lua`
require("lazy").setup("kiyoon.lazy", {
  dev = {
    path = "~/project",
    -- patterns = { "kiyoon", "nvim-treesitter-textobjects" },
  },
  performance = {
    rtp = {
      disabled_plugins = {
        -- List of default plugins can be found here
        -- https://github.com/neovim/neovim/tree/master/runtime/plugin
        "matchit", -- Extended %. replaced by vim-matchup
        "matchparen", -- Highlight matching paren. replaced by vim-matchup
        "netrwPlugin", -- File browser. replaced by nvim-tree, neo-tree, oil.nvim
        "tohtml",
        "tutor",
        -- "tarPlugin",
        -- "gzip",
        -- "zipPlugin",
      },
    },
  },
})

-- Source .vimrc
local vimrcpath = vim.fn.stdpath "config" .. "/.vimrc"
vim.cmd("source " .. vimrcpath)

vim.o.termguicolors = true
vim.opt.iskeyword:append "-" -- treats words with `-` as single words
vim.o.cursorline = true
vim.o.inccommand = "split"
vim.o.updatetime = 500

-- This may cause lualine to flicker
-- vim.o.cmdheight = 0

vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "gitcommit", "markdown" },
  callback = function()
    vim.opt_local.wrap = true
    -- vim.opt_local.spell = true
  end,
})

--- NOTE: removed in favour of yanky.nvim

-- [[ Highlight on yank ]]
-- See `:help vim.highlight.on_yank()`
-- local highlight_group = vim.api.nvim_create_augroup("YankHighlight", { clear = true })
-- vim.api.nvim_create_autocmd("TextYankPost", {
--   callback = function()
--     vim.highlight.on_yank()
--   end,
--   group = highlight_group,
--   pattern = "*",
-- })

vim.cmd [[
" With GUI demo
nmap <leader>G <Cmd>call system("docker run --gpus all --rm --device=/dev/video0:/dev/video0 -e DISPLAY=${DISPLAY} -v /tmp/.X11-unix:/tmp/.X11-unix -v ~/project/nvim-hand-gesture:/workspace -v /run/user:/run/user kiyoon/nvim-hand-gesture --gui --nvim_socket_path " . v:servername . " &")<CR>
" Without GUI
nmap <leader>g <Cmd>call system("docker run --gpus all --rm --device=/dev/video0:/dev/video0 -v ~/project/nvim-hand-gesture:/workspace -v /run/user:/run/user kiyoon/nvim-hand-gesture --nvim_socket_path " . v:servername . " &")<CR>
" Quit running process
nmap <leader><leader>g <Cmd>let g:quit_nvim_hand_gesture = 1<CR>
]]

-- Configure context menu on right click
require "kiyoon.menu"

-- folding (use nvim-ufo for better control)
-- vim.cmd [[hi Folded guibg=black ctermbg=black]]
-- vim.o.foldmethod = "expr"
-- vim.o.foldcolumn = "auto:9"
-- -- vim.o.fillchars = [[eob: ,fold: ,foldopen:,foldsep: ,foldclose:]]
-- vim.o.fillchars = [[foldopen:,foldclose:]]
-- vim.o.foldminlines = 25
-- vim.o.foldexpr = "nvim_treesitter#foldexpr()"
-- -- open folds by default
-- vim.cmd [[autocmd BufReadPost,FileReadPost * normal zR]]

vim.cmd [[
augroup AutoView
  autocmd!
  autocmd BufWritepre,BufWinLeave ?* silent! mkview
  autocmd BufWinEnter ?* silent! loadview
augroup END
]]

-- Better Korean mapping in normal mode. It's not perfect
vim.o.langmap =
  "ㅁa,ㅠb,ㅊc,ㅇd,ㄷe,ㄹf,ㅎg,ㅗh,ㅑi,ㅓj,ㅏk,ㅣl,ㅡm,ㅜn,ㅐo,ㅔp,ㅂq,ㄱr,ㄴs,ㅅt,ㅕu,ㅍv,ㅈw,ㅌx,ㅛy,ㅋz"
-- Faster filetype detection for neovim
vim.g.do_filetype_lua = 1

-- splitting doesn't change the scroll
-- vim.o.splitkeep = "screen"

-- Use when you see everything is folded
-- Maybe some plugin is overwriting this?
-- vim.cmd [[
-- augroup FoldLevel
--   autocmd!
--   autocmd BufWinEnter ?* set foldlevel=99
-- augroup END
-- ]]

-- Add :Messages command to open messages in a buffer. Useful for debugging.
-- Better than the default :messages
local function open_messages_in_buffer(args)
  if Bufnr_messages == nil or vim.fn.bufexists(Bufnr_messages) == 0 then
    -- Create a temporary buffer
    Bufnr_messages = vim.api.nvim_create_buf(false, true)
  end
  -- Create a split and open the buffer
  vim.cmd([[sb]] .. Bufnr_messages)
  -- vim.cmd "botright 10new"
  vim.bo.modifiable = true
  vim.api.nvim_buf_set_lines(Bufnr_messages, 0, -1, false, {})
  vim.cmd "put = execute('messages')"
  vim.bo.modifiable = false

  -- No need for below because we created a temporary buffer
  -- vim.bo.modified = false
end

vim.api.nvim_create_user_command("Messages", open_messages_in_buffer, {})

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
  -- add_python_import(module)
end

vim.api.nvim_create_augroup("python_import", { clear = true })
vim.api.nvim_create_autocmd("FileType", {
  group = "python_import",
  pattern = "python",
  callback = function()
    vim.keymap.set("n", "<leader>i", function()
      local line_number = add_python_import_current_word()
      vim.cmd([[normal! ]] .. line_number .. [[G0]])
    end, { silent = true })
    vim.keymap.set("x", "<leader>i", function()
      local line_number = add_python_import_current_selection()
      vim.cmd([[normal! ]] .. line_number .. [[G0]])
    end, { silent = true })
  end,
})
