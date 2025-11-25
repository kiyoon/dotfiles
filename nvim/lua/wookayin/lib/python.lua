-- from wookayin/dotfiles
-- lib/python
-- Utilities and functions specific to python

local status, notify = pcall(require, "notify")
if not status then
  notify = function(msg, level, opts) end
end

local M = {}

--[[ Implementations for $DOTVIM/after/ftplugin/python.lua ]]

-- Node types that do not require parentheses
-- because they are not multiple statements.
-- e.g., identifier: variable_name
--       call: function_call()
--       subscript: a[0]
M.no_paren_ts_node_types = {
  identifier = true,
  call = true,
  attribute = true,
  subscript = true,
  string = true,
}

M.toggle_breakpoint = function()
  local pattern = "breakpoint()" -- Use python >= 3.7.
  local line = vim.fn.getline(".") --[[@as string]]
  line = vim.trim(line)
  local lnum = vim.fn.line(".") ---@cast lnum integer

  if vim.startswith(line, pattern) then
    vim.cmd.normal([["_dd]]) -- delete the line without altering registers
  else
    local indents = string.rep(" ", vim.fn.indent(vim.fn.prevnonblank(lnum)) or 0)
    vim.fn.append(lnum - 1, indents .. pattern)
    vim.cmd.normal("k")
  end
  -- save file without any events
  if vim.bo.modifiable and vim.bo.modified then
    vim.cmd([[ silent! noautocmd write ]])
  end
end

M.toggle_fstring = function()
  -- Credit: https://www.reddit.com/r/neovim/comments/tge2ty/python_toggle_fstring_using_treesitter/
  local winnr = 0
  local cursor = vim.api.nvim_win_get_cursor(winnr)
  ---@type TSNode?
  local node = require("wookayin.utils.ts_utils").get_node_at_cursor(winnr)

  while (node ~= nil) and (node:type() ~= "string") do
    node = node:parent()
  end
  if node == nil then
    vim.api.nvim_echo({ { "f-string: not in a string node.", "WarningMsg" } }, false, {})
    return
  end

  ---@diagnostic disable-next-line: unused-local
  local srow, scol, _erow, _ecol = require("wookayin.utils.ts_utils").get_vim_range({ node:range() })
  local line = vim.api.nvim_buf_get_lines(0, srow - 1, srow, false)[1]
  local scol_utf = vim.str_utfindex(line, "utf-16", scol)
  vim.fn.setcursorcharpos(srow, scol_utf)

  local char = line:sub(scol, scol)
  local is_fstring = (char == "f")

  if is_fstring then
    vim.cmd([[normal! "_x]])
    -- if cursor is in the same line as text change
    if srow == cursor[1] then
      cursor[2] = cursor[2] - 1 -- negative offset to cursor
    end
  else
    vim.cmd([[noautocmd normal if]])
    -- if cursor is in the same line as text change
    if srow == cursor[1] then
      cursor[2] = cursor[2] + 1 -- positive offset to cursor
    end
  end
  vim.api.nvim_win_set_cursor(winnr, cursor)
end

M.toggle_line_comment = function(text)
  local comment = "# " .. text
  local line = vim.fn.getline(".") --[[ @as string ]]
  local newline ---@type string

  if vim.endswith(line, comment) then
    -- Already exists at the end: strip the comment
    newline = string.match(line:sub(1, #line - #comment), "(.-)%s*$")
  else
    newline = line .. "  " .. comment
  end
  ---@diagnostic disable-next-line: param-type-mismatch
  vim.fn.setline(".", newline)
end

---@class python_tools.toggle_typing_opts.Opts
---@field more_args boolean Add comma and move cursor to the next argument like T -> Annotated[T, <cursor_pos>]

---@param name string e.g. Annotated
---@param opts python_tools.toggle_typing_opts.Opts
M.toggle_typing = function(name, opts)
  local winnr = 0
  local cursor = vim.api.nvim_win_get_cursor(winnr) -- (row,col): (1,0)-indexed
  local bufnr = vim.api.nvim_get_current_buf()

  local function has_type(node, t)
    return node and node:type() == t
  end
  local function get_text(node)
    return vim.treesitter.get_node_text(node, bufnr)
  end

  ---@type TSNode?
  local node = vim.treesitter.get_node()

  -- Climb up and find the closest ancestor node whose children has a `type` node:
  while
    (node ~= nil)
    and not vim.list_contains({
      "assignment",
      "typed_default_parameter",
      "typed_parameter",
      "function_definition",
    }, node:type())
  do
    node = node:parent()
  end
  -- Find its direct children of type `type`
  ---@type TSNode?
  local type_node = node and vim.tbl_filter(function(n)
    return n:type() == "type"
  end, node:named_children())[1] or nil
  if not type_node then
    vim.cmd.echon(([["toggle_typing[%s]: not in a type hint node."]]):format(name))
    return
  end
  -- Check range

  local unpack_generic = function(node)
    -- Determine if `node` represents `Optional[...]` (w.r.t `name`), for example.
    --  type: (type)
    --    (generic_type)
    --      (identifier)
    --      (type_parameter)
    --        (type) <-- returns this node `T` if given `Optional[T]`.
    assert(node:type() == "type")
    node = node:named_child(0)
    if has_type(node, "generic_type") then
      node = node:named_child(0)
      if has_type(node, "identifier") and get_text(node) == name then
        ---@cast node TSNode
        node = node:next_named_sibling() -- 0.9.0 only
      end
      if has_type(node, "type_parameter") then
        node = assert(node):named_child(0)
        if has_type(node, "type") then
          return node
        end
      end
    end
    return nil
  end

  local T_node = unpack_generic(type_node) ---@type TSNode?
  local new_text ---@type string
  if T_node then
    -- replace: e.g., Optional[T] => T
    new_text = get_text(T_node)
  else
    if not opts.more_args then
      -- replace: e.g., T => Optional[T]
      new_text = name .. "[" .. get_text(type_node) .. "]"
    else
      -- replace: e.g., T => Annotated[T, ]
      new_text = name .. "[" .. get_text(type_node) .. ", ]"
    end
  end

  -- treesitter range is 0-indexed and end-exclusive
  -- nvim_buf_set_text() also uses 0-indexed and end-exclusive indexing
  local srow, scol, erow, ecol = type_node:range()
  vim.api.nvim_buf_set_text(0, srow, scol, erow, ecol, { new_text })

  -- Restore cursor
  if not opts.more_args then
    vim.api.nvim_win_set_cursor(winnr, cursor)
  else
    vim.api.nvim_win_set_cursor(winnr, { srow + 1, scol + #new_text - 1 })
  end
end

--- Added by kiyoon
--- Adds `None` to the type hint.
--- If the type hint is already `Optional[T]`, it removes the `Optional` and add None.
--- If the type hint already contains `None`, it removes `None`.
M.toggle_typing_none = function()
  local winnr = 0
  local cursor = vim.api.nvim_win_get_cursor(winnr) -- (row,col): (1,0)-indexed
  local bufnr = vim.api.nvim_get_current_buf()

  local function has_type(node, t)
    return node and node:type() == t
  end
  local function get_text(node)
    return vim.treesitter.get_node_text(node, bufnr)
  end

  ---@type TSNode?
  local node = vim.treesitter.get_node()

  -- Climb up and find the closest ancestor node whose children has a `type` node:
  while
    (node ~= nil)
    and not vim.list_contains({
      "assignment",
      "typed_default_parameter",
      "typed_parameter",
      "function_definition",
    }, node:type())
  do
    node = node:parent()
  end
  -- Find its direct children of type `type`
  ---@type TSNode?
  local type_node = node and vim.tbl_filter(function(n)
    return n:type() == "type"
  end, node:named_children())[1] or nil
  if not type_node then
    vim.cmd.echon([["toggle_typing_none: not in a type hint node."]])
    return
  end
  -- Check range

  ---@param node TSNode?
  ---@param wrapper_names string|string[] e.g., "Optional", "Annotated"
  local unpack_generic = function(node, wrapper_names)
    -- Determine if `node` represents `Optional[...]` (w.r.t `name`), for example.
    --  type: (type)
    --    (generic_type)
    --      (identifier)
    --      (type_parameter)
    --        (type) <-- returns this node `T` if given `Optional[T]`.

    if type(wrapper_names) == "string" then
      wrapper_names = { wrapper_names }
    end
    assert(node:type() == "type")
    node = node:named_child(0)
    if has_type(node, "generic_type") then
      node = node:named_child(0)
      if has_type(node, "identifier") and vim.list_contains(wrapper_names, get_text(node)) then
        ---@cast node TSNode
        node = node:next_named_sibling() -- 0.9.0 only
      end
      if has_type(node, "type_parameter") then
        node = assert(node):named_child(0)
        if has_type(node, "type") then
          return node
        end
      end
    end
    return nil
  end

  local function ends_with_none(node)
    -- Determine if `node` has binary_operator, and the right child is none.
    --  type: (type)
    --    (binary_operator)
    --      left:  <- returns this node if the right node is none
    --      right: none
    --
    -- return the left node if the right node is none
    --
    -- Case 2: if list[str] | None, it will be shown as:
    -- (type
    --   (union_type
    --     (type
    --       ..)
    --     (type
    --       (none))))

    assert(node:type() == "type")
    node = node:named_child(0)
    if has_type(node, "binary_operator") then
      local right_node = node:named_child(1)
      if has_type(right_node, "none") then
        return true
      end
    elseif has_type(node, "union_type") then
      -- Case 2
      local right_node = node:named_child(1)
      if has_type(right_node, "type") then
        if has_type(right_node:named_child(0), "none") then
          return true
        else
          return ends_with_none(right_node)
        end
      end
    end
    return false
  end

  local root_wrappers = {
    "Annotated",
    "Mapped", -- sqlalchemy
  }
  local annotated_type_node = unpack_generic(type_node, root_wrappers) ---@type TSNode?
  if annotated_type_node then
    -- replace: e.g., Annotated[T, str] => Annotated[T | None, str]
    -- by treating the first type parameter as the type to be modified.
    type_node = annotated_type_node
  end

  local T_node = unpack_generic(type_node, "Optional") ---@type TSNode?
  local new_text ---@type string
  if T_node then
    -- replace: e.g., Optional[T] => T | None
    new_text = get_text(T_node) .. " | None"
  else
    local ends_none = ends_with_none(type_node)
    if ends_none then
      -- replace: e.g., T | None => T
      -- make count of space irrelevant
      new_text = get_text(type_node):gsub("%s*|%s*None%s*$", "", 1)
    else
      -- replace: e.g., T => T | None
      new_text = get_text(type_node) .. " | None"
    end
  end

  -- treesitter range is 0-indexed and end-exclusive
  -- nvim_buf_set_text() also uses 0-indexed and end-exclusive indexing
  local srow, scol, erow, ecol = type_node:range()
  vim.api.nvim_buf_set_text(0, srow, scol, erow, ecol, { new_text })

  -- Restore cursor
  vim.api.nvim_win_set_cursor(winnr, cursor)
end

--- Added by kiyoon
--- Replaces Union[T1, T2] with T1 | T2
--- Replaces Optional[T] with T | None
--- Replaces List[T] with list[T]
--- Replaces Dict[K, V] with dict[K, V]
--- Replaces Set[T] with set[T]
--- Replaces Tuple[T1, T2] with tuple[T1, T2]
M.upgrade_typing = function(node)
  local winnr = 0
  local cursor = vim.api.nvim_win_get_cursor(winnr) -- (row,col): (1,0)-indexed
  local bufnr = vim.api.nvim_get_current_buf()

  local function has_type(node, t)
    return node and node:type() == t
  end
  local function get_text(node)
    return vim.treesitter.get_node_text(node, bufnr)
  end

  if node == nil then
    node = vim.treesitter.get_node()
  end

  -- Climb up and find the closest ancestor node which is `generic_type` e.g. `Union`
  -- if the Union, List etc. is right side of binary_operator (|), it will be shown as `subscript`
  while (node ~= nil) and node:type() ~= "generic_type" and node:type() ~= "subscript" do
    node = node:parent()
  end

  if not node then
    notify("No fix found.", "info", {
      title = "Fix python typing",
    })
    return
  end

  assert(node:type() == "generic_type" or node:type() == "subscript")

  local function num_type_parameters(node)
    if node:type() == "subscript" then
      -- Union[T1, T2] is shown as `subscript` node
      -- children: Union, T1, T2
      return node:named_child_count() - 1
    elseif node:type() == "generic_type" then
      -- Union[T1, T2] is shown as `generic_type` node
      -- children: Union, [T1, T2] (type_parameter)
      return node:named_child(1):named_child_count()
    end
  end

  local function get_type_parameter_element(node, idx)
    if node:type() == "subscript" then
      -- Union[T1, T2] is shown as `subscript` node
      -- children: Union, T1, T2
      return node:named_child(idx + 1)
    elseif node:type() == "generic_type" then
      -- Union[T1, T2] is shown as `generic_type` node
      -- children: Union, [T1, T2] (type_parameter)
      return node:named_child(1):named_child(idx)
    end
  end

  local identifier_node = node:named_child(0) -- e.g., Union
  local identifier_name = get_text(identifier_node)

  local new_text ---@type string
  local change_identifier_only = false -- if true, only change the identifier. e.g., `List` => `list`
  if identifier_name == "Union" then
    if num_type_parameters(node) == 0 then
      -- no arguments
      notify("At least one argument is required", "error", {
        title = "Fix python typing (Union)",
      })
      return
    end

    new_text = get_text(get_type_parameter_element(node, 0))
    for i = 1, num_type_parameters(node) - 1 do
      local arg_node = get_type_parameter_element(node, i)
      new_text = new_text .. " | " .. get_text(arg_node)
    end
  elseif identifier_name == "Optional" then
    if num_type_parameters(node) == 0 then
      -- no arguments
      notify("At least one argument is required", "error", {
        title = "Fix python typing (Optional)",
      })
      return
    end

    new_text = get_text(get_type_parameter_element(node, 0)) .. " | None"
  elseif identifier_name == "List" then
    new_text = "list"
    change_identifier_only = true
  elseif identifier_name == "Tuple" then
    new_text = "tuple"
    change_identifier_only = true
  elseif identifier_name == "Dict" then
    new_text = "dict"
    change_identifier_only = true
  elseif identifier_name == "Set" then
    new_text = "set"
    change_identifier_only = true
  else
    -- recursively upgrade the type hint
    return M.upgrade_typing(node:parent())
  end

  -- treesitter range is 0-indexed and end-exclusive
  -- nvim_buf_set_text() also uses 0-indexed and end-exclusive indexing
  if change_identifier_only then
    local srow, scol, erow, ecol = identifier_node:range()
    vim.api.nvim_buf_set_text(0, srow, scol, erow, ecol, { new_text })
  else
    local srow, scol, erow, ecol = node:range()
    vim.api.nvim_buf_set_text(0, srow, scol, erow, ecol, { new_text })
  end

  -- Restore cursor
  vim.api.nvim_win_set_cursor(winnr, cursor)
end

--- Added by kiyoon
--- replaces os.path with pathlib. Plus, some other function replacements.
--- e.g., `os.path.join(a, b)` => `Path(a) / b`
--- `print(a)` => `logger.info(a)`
--- See ruff PTH code for more details.
M.os_path_to_pathlib = function(wrap_with_path)
  if wrap_with_path == nil then
    wrap_with_path = true
  end
  local winnr = 0
  local cursor = vim.api.nvim_win_get_cursor(winnr) -- (row,col): (1,0)-indexed
  local bufnr = vim.api.nvim_get_current_buf()

  local function has_type(node, t)
    return node and node:type() == t
  end
  local function get_text(node)
    return vim.treesitter.get_node_text(node, bufnr)
  end

  ---@type TSNode?
  local node = vim.treesitter.get_node()

  -- Climb up and find a `call` node:
  while (node ~= nil) and node:type() ~= "call" do
    node = node:parent()
  end

  if not node then
    -- Not a call node.
    -- Alternatively, check if the current node is a variable.
    -- Find attribute node (e.g. self.var)
    -- If not found use the current node (identifier, string).
    node = vim.treesitter.get_node()
    while (node ~= nil) and node:type() ~= "attribute" do
      node = node:parent()
    end

    if not node then
      node = vim.treesitter.get_node()
      if node == nil or not vim.list_contains({ "identifier", "string" }, node:type()) then
        notify("Not in a call node, nor is a variable.", "error", {
          title = "os.path to pathlib.Path",
        })
        return
      end
    end

    -- Wrap the variable with Path() if it's a string or a variable.
    local text = get_text(node)
    local new_text = "Path(" .. text .. ")"
    -- treesitter range is 0-indexed and end-exclusive
    -- nvim_buf_set_text() also uses 0-indexed and end-exclusive indexing
    local srow, scol, erow, ecol = node:range()
    local new_text_list = vim.split(new_text, "\n")
    vim.api.nvim_buf_set_text(0, srow, scol, erow, ecol, new_text_list)

    -- Restore cursor
    vim.api.nvim_win_set_cursor(winnr, cursor)

    return
  end

  assert(node:type() == "call")
  local function_node = node:named_child(0) -- e.g., `os.path.join`
  local arglist_node = node:named_child(1) -- e.g., `a, b`

  local function_name = get_text(function_node)

  local function wrap_with_pathlib(node)
    local text = get_text(node)
    if node:type() == "string" then
      -- obviously string needs to be wrapped with Path(.)
      return "Path(" .. text .. ")"
    elseif M.no_paren_ts_node_types[node:type()] then
      if wrap_with_path then
        return "Path(" .. text .. ")"
      else
        return text
      end
    else
      if wrap_with_path then
        return "Path(" .. text .. ")"
      else
        return "(" .. text .. ")"
      end
    end
  end

  ---os.path functions that require one path argument
  ---e.g. os.path.exists(a) => Path(a).exists()
  local function one_arg_function_to_pathlib(pathlib_function_name)
    if arglist_node:named_child_count() == 0 then
      notify("At least one argument is required.", "error", {
        title = "os.path to pathlib.Path",
      })
      return nil
    end

    return wrap_with_pathlib(arglist_node:named_child(0)) .. "." .. pathlib_function_name
  end

  ---os.path.join to pathlib.Path
  local function osp_join_to_pathlib()
    if arglist_node:named_child_count() == 0 then
      -- no arguments
      notify("At least one argument is required.", "error", {
        title = "os.path.join to pathlib.Path",
      })
      return
    end

    local new_text = wrap_with_pathlib(arglist_node:named_child(0))
    for i = 1, arglist_node:named_child_count() - 1 do
      local arg_node = arglist_node:named_child(i)
      if M.no_paren_ts_node_types[arg_node:type()] then
        new_text = new_text .. " / " .. get_text(arg_node)
      else
        new_text = new_text .. " / (" .. get_text(arg_node) .. ")"
      end
    end
    return new_text
  end

  ---os.path functions that require one path argument and multiple other arguments
  ---e.g. os.path.rename(a, b) => Path(a).rename(b)
  local function multi_arg_function_to_pathlib(pathlib_function_name)
    local new_text = one_arg_function_to_pathlib(pathlib_function_name .. "(")
    if new_text == nil then
      return nil
    end

    local new_args = {}
    for i = 1, arglist_node:named_child_count() - 1 do
      local arg_node = arglist_node:named_child(i)
      table.insert(new_args, get_text(arg_node))
    end
    new_text = new_text .. table.concat(new_args, ", ") .. ")"
    return new_text
  end

  ---Alternative method. Change only the function name.
  ---e.g. print(a) => logger.info(a)
  ---@param change_to string
  ---@return string
  local function change_call_name(change_to)
    local new_text = change_to .. "("
    local new_args = {}
    for i = 0, arglist_node:named_child_count() - 1 do
      local arg_node = arglist_node:named_child(i)
      table.insert(new_args, get_text(arg_node))
    end
    new_text = new_text .. table.concat(new_args, ", ") .. ")"
    return new_text
  end

  local new_text ---@type string | nil
  if function_name == "os.path.join" then
    new_text = osp_join_to_pathlib()
  elseif function_name == "join" then
    new_text = osp_join_to_pathlib()
  elseif function_name == "osp_join" then
    new_text = osp_join_to_pathlib()
  elseif function_name == "os.mkdir" then
    new_text = one_arg_function_to_pathlib("mkdir()")
  elseif function_name == "os.makedirs" then
    if arglist_node:named_child_count() == 0 then
      -- no arguments
      notify("At least one argument is required.", "error", {
        title = "os.makedirs to pathlib.Path",
      })
      return
    end
    new_text = one_arg_function_to_pathlib("mkdir(parents=True")
    for i = 1, arglist_node:named_child_count() - 1 do
      local arg_node = arglist_node:named_child(i)
      new_text = new_text .. ", " .. get_text(arg_node)
    end
    new_text = new_text .. ")"
  elseif function_name == "os.path.exists" then
    new_text = one_arg_function_to_pathlib("exists()")
  elseif function_name == "os.path.abspath" then
    new_text = one_arg_function_to_pathlib("resolve()")
  elseif function_name == "os.remove" then
    new_text = one_arg_function_to_pathlib("unlink()")
  elseif function_name == "os.unlink" then
    new_text = one_arg_function_to_pathlib("unlink()")
  elseif function_name == "os.rmdir" then
    new_text = one_arg_function_to_pathlib("rmdir()")
  elseif function_name == "os.path.expanduser" then
    new_text = one_arg_function_to_pathlib("expanduser()")
  elseif function_name == "os.path.isdir" then
    new_text = one_arg_function_to_pathlib("is_dir()")
  elseif function_name == "os.path.isfile" then
    new_text = one_arg_function_to_pathlib("is_file()")
  elseif function_name == "os.path.islink" then
    new_text = one_arg_function_to_pathlib("is_symlink()")
  elseif function_name == "os.path.isabs" then
    new_text = one_arg_function_to_pathlib("is_absolute()")
  elseif function_name == "os.path.basename" then
    new_text = one_arg_function_to_pathlib("name")
  elseif function_name == "os.path.dirname" then
    new_text = one_arg_function_to_pathlib("parent")
  elseif function_name == "os.stat" then
    new_text = one_arg_function_to_pathlib("stat()")
  elseif function_name == "os.path.getsize" then
    new_text = one_arg_function_to_pathlib("stat().st_size")
  elseif function_name == "os.path.getmtime" then
    new_text = one_arg_function_to_pathlib("stat().st_mtime")
  elseif function_name == "os.path.getctime" then
    new_text = one_arg_function_to_pathlib("stat().st_ctime")
  elseif function_name == "os.path.getatime" then
    new_text = one_arg_function_to_pathlib("stat().st_atime")
  elseif function_name == "os.listdir" then
    new_text = one_arg_function_to_pathlib("iterdir()")
  elseif function_name == "os.rename" then
    new_text = multi_arg_function_to_pathlib("rename")
  elseif function_name == "os.replace" then
    new_text = multi_arg_function_to_pathlib("replace")
  elseif function_name == "os.path.samefile" then
    new_text = multi_arg_function_to_pathlib("samefile")
  elseif function_name == "open" then
    new_text = multi_arg_function_to_pathlib("open")
  elseif function_name == "glob.glob" then
    new_text = multi_arg_function_to_pathlib("glob") -- this is not completely correct
  elseif function_name == "print" then
    if arglist_node:named_child_count() > 1 then
      notify("print() with more than one argument can't be safely converted to logger.info", "warning", {
        title = "os.path to pathlib.Path",
      })
    end
    new_text = change_call_name("logger.info")
  else
    notify("Function `" .. function_name .. "` not recognised.", "error", {
      title = "os.path to pathlib.Path",
      on_open = function(win)
        local buf = vim.api.nvim_win_get_buf(win)
        vim.bo[buf].filetype = "markdown"
      end,
    })
    return
  end

  if new_text == nil then
    return
  end

  -- treesitter range is 0-indexed and end-exclusive
  -- nvim_buf_set_text() also uses 0-indexed and end-exclusive indexing
  local srow, scol, erow, ecol = node:range()
  local new_text_list = vim.split(new_text, "\n")
  vim.api.nvim_buf_set_text(0, srow, scol, erow, ecol, new_text_list)

  -- Restore cursor
  vim.api.nvim_win_set_cursor(winnr, cursor)
end

local buffer = require("nvim-surround.buffer")
local config = require("nvim-surround.config")

-- Add delimiters around a visual selection.
-- Taken from nvim-surround https://github.com/kylechui/nvim-surround/commit/23f4966aba1d90d9ea4e06dfe3dd7d07b8420611
---@param delimiters string[][]
---@param args? { curpos: position, curswant: number }
local visual_surround = function(delimiters, args)
  -- Get a character and selection from the user
  args = args or {}
  args.curpos = args.curpos or buffer.get_curpos()
  args.curswant = args.curswant or vim.fn.winsaveview().curswant

  -- if vim.fn.visualmode() == "V" then
  --   args.line_mode = true
  -- end

  -- exit visual mode
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)

  local first_pos, last_pos = buffer.get_mark("<"), buffer.get_mark(">")
  if not delimiters or not first_pos or not last_pos then
    return
  end

  if vim.fn.visualmode() == "\22" then -- Visual block mode case (add delimiters to every line)
    if vim.o.selection == "exclusive" then
      last_pos[2] = last_pos[2] - 1
    end
    -- Get (visually) what columns the start and end are located at
    local first_disp = vim.fn.strdisplaywidth(buffer.get_line(first_pos[1]):sub(1, first_pos[2] - 1)) + 1
    local last_disp = vim.fn.strdisplaywidth(buffer.get_line(last_pos[1]):sub(1, last_pos[2] - 1)) + 1
    -- Find the min/max for some variables, since visual blocks can either go diagonally or anti-diagonally
    local mn_disp, mx_disp = math.min(first_disp, last_disp), math.max(first_disp, last_disp)
    local mn_lnum, mx_lnum = math.min(first_pos[1], last_pos[1]), math.max(first_pos[1], last_pos[1])
    -- Check if $ was used in creating the block selection
    local surround_to_end_of_line = args.curswant == vim.v.maxcol
    -- Surround each line with the delimiter pair, last to first (for indexing reasons)
    for lnum = mx_lnum, mn_lnum, -1 do
      local line = buffer.get_line(lnum)
      if surround_to_end_of_line then
        buffer.insert_text({ lnum, #buffer.get_line(lnum) + 1 }, delimiters[2])
      else
        local index = buffer.get_last_byte({ lnum, 1 })[2]
        -- The current display count should be >= the desired one
        while vim.fn.strdisplaywidth(line:sub(1, index)) < mx_disp and index <= #line do
          index = buffer.get_last_byte({ lnum, index + 1 })[2]
        end
        -- Go to the end of the current character
        index = buffer.get_last_byte({ lnum, index })[2]
        buffer.insert_text({ lnum, index + 1 }, delimiters[2])
      end

      local index = 1
      -- The current display count should be <= the desired one
      while vim.fn.strdisplaywidth(line:sub(1, index - 1)) + 1 < mn_disp and index <= #line do
        index = buffer.get_last_byte({ lnum, index })[2] + 1
      end
      if vim.fn.strdisplaywidth(line:sub(1, index - 1)) + 1 > mn_disp then
        -- Go to the beginning of the previous character
        index = buffer.get_first_byte({ lnum, index - 1 })[2]
      end
      buffer.insert_text({ lnum, index }, delimiters[1])
    end
  else -- Regular visual mode case
    if vim.o.selection == "exclusive" then
      last_pos[2] = last_pos[2] - 1
    end

    last_pos = buffer.get_last_byte(last_pos)
    buffer.insert_text({ last_pos[1], last_pos[2] + 1 }, delimiters[2])
    buffer.insert_text(first_pos, delimiters[1])
  end

  config.get_opts().indent_lines(first_pos[1], last_pos[1] + #delimiters[1] + #delimiters[2] - 2)
  buffer.restore_curpos({
    first_pos = first_pos,
    old_pos = args.curpos,
  })
end
M.wrap_selection_with_path = function()
  visual_surround({ { "Path(" }, { ")" } }, {})
end

return M
