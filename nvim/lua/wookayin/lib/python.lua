-- from wookayin/dotfiles
-- lib/python
-- Utilities and functions specific to python

local M = {}

--[[ Implementations for $DOTVIM/after/ftplugin/python.lua ]]

M.toggle_breakpoint = function()
  local pattern = "breakpoint()" -- Use python >= 3.7.
  local line = vim.fn.getline "." --[[@as string]]
  line = vim.trim(line)
  local lnum = vim.fn.line "." ---@cast lnum integer

  if vim.startswith(line, pattern) then
    vim.cmd.normal [["_dd]] -- delete the line without altering registers
  else
    local indents = string.rep(" ", vim.fn.indent(vim.fn.prevnonblank(lnum)) or 0)
    vim.fn.append(lnum - 1, indents .. pattern)
    vim.cmd.normal "k"
  end
  -- save file without any events
  if vim.bo.modifiable and vim.bo.modified then
    vim.cmd [[ silent! noautocmd write ]]
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
  local srow, scol, erow, ecol = require("wookayin.utils.ts_utils").get_vim_range { node:range() }
  vim.fn.setcursorcharpos(srow, scol)

  local char = vim.api.nvim_get_current_line():sub(scol, scol)
  local is_fstring = (char == "f")

  if is_fstring then
    vim.cmd [[normal "_x]]
    -- if cursor is in the same line as text change
    if srow == cursor[1] then
      cursor[2] = cursor[2] - 1 -- negative offset to cursor
    end
  else
    vim.cmd [[noautocmd normal if]]
    -- if cursor is in the same line as text change
    if srow == cursor[1] then
      cursor[2] = cursor[2] + 1 -- positive offset to cursor
    end
  end
  vim.api.nvim_win_set_cursor(winnr, cursor)
end

M.toggle_line_comment = function(text)
  local comment = "# " .. text
  local line = vim.fn.getline "." --[[ @as string ]]
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

M.toggle_typing = function(name)
  if vim.fn.has "nvim-0.9" == 0 then
    return vim.api.nvim_err_writeln "toggle_typing: this feature requires neovim 0.9.0."
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

  -- Climb up and find the closest ancestor node whose children has a `type` node:
  while
    (node ~= nil)
    and not vim.tbl_contains({
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
    -- replace: e.g., T => Optional[T]
    new_text = name .. "[" .. get_text(type_node) .. "]"
  end

  -- treesitter range is 0-indexed and end-exclusive
  -- nvim_buf_set_text() also uses 0-indexed and end-exclusive indexing
  local srow, scol, erow, ecol = type_node:range()
  vim.api.nvim_buf_set_text(0, srow, scol, erow, ecol, { new_text })

  -- Restore cursor
  vim.api.nvim_win_set_cursor(winnr, cursor)
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
    and not vim.tbl_contains({
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
    vim.cmd.echon [["toggle_typing_none: not in a type hint node."]]
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
      if has_type(node, "identifier") and get_text(node) == "Optional" then
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

  local ends_with_none = function(node)
    -- Determine if `node` has binary_operator, and the right child is none.
    --  type: (type)
    --    (binary_operator)
    --      left:  <- returns this node if the right node is none
    --      right: none
    --
    -- return the left node if the right node is none
    assert(node:type() == "type")
    node = node:named_child(0)
    if has_type(node, "binary_operator") then
      local right_node = node:named_child(1)
      if has_type(right_node, "none") then
        return node:named_child(0) -- left node
      end
    end
    return nil
  end

  local T_node = unpack_generic(type_node) ---@type TSNode?
  local new_text ---@type string
  if T_node then
    -- replace: e.g., Optional[T] => T | None
    new_text = get_text(T_node) .. " | None"
  else
    local without_none_node = ends_with_none(type_node)
    if without_none_node then
      -- replace: e.g., T | None => T
      new_text = get_text(without_none_node)
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
  while (node ~= nil) and node:type() ~= "generic_type" do
    node = node:parent()
  end

  if not node then
    vim.notify("No fix found.", "info", {
      title = "Fix python typing",
    })
    return
  end

  assert(node:type() == "generic_type")
  local identifier_node = node:named_child(0) -- e.g., `os.path.join`
  local type_parameter_node = node:named_child(1) -- e.g., `a, b`

  local identifier_name = get_text(identifier_node)

  local new_text ---@type string
  local change_identifier_only = false -- if true, only change the identifier. e.g., `List` => `list`
  if identifier_name == "Union" then
    if type_parameter_node:named_child_count() == 0 then
      -- no arguments
      vim.notify("At least one argument is required.", "error", {
        title = "Fix python typing",
      })
      return
    end

    new_text = get_text(type_parameter_node:named_child(0))
    for i = 1, type_parameter_node:named_child_count() - 1 do
      local arg_node = type_parameter_node:named_child(i)
      new_text = new_text .. " | " .. get_text(arg_node)
    end
  elseif identifier_name == "Optional" then
    if type_parameter_node:named_child_count() == 0 then
      -- no arguments
      vim.notify("At least one argument is required.", "error", {
        title = "Fix python typing",
      })
      return
    end

    new_text = get_text(type_parameter_node:named_child(0)) .. " | None"
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
--- replaces os.path with pathlib
--- e.g., `os.path.join(a, b)` => `Path(a) / b`
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
    vim.notify("Not in a call node.", "error", {
      title = "os.path to pathlib.Path",
    })
    return
  end

  assert(node:type() == "call")
  local function_node = node:named_child(0) -- e.g., `os.path.join`
  local arglist_node = node:named_child(1) -- e.g., `a, b`

  local function_name = get_text(function_node)

  local function wrap_with_pathlib(node)
    local text = get_text(node)
    if node:type() == "identifier" or node:type() == "call" then
      if wrap_with_path then
        return "Path(" .. text .. ")"
      else
        return text
      end
    elseif node:type() == "string" then
      -- obviously string needs to be wrapped with Path(.)
      return "Path(" .. text .. ")"
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
      vim.notify("At least one argument is required.", "error", {
        title = "os.path to pathlib.Path",
      })
      return nil
    end

    return wrap_with_pathlib(arglist_node:named_child(0)) .. "." .. pathlib_function_name
  end

  local new_text ---@type string | nil
  if function_name == "os.path.join" then
    if arglist_node:named_child_count() == 0 then
      -- no arguments
      vim.notify("At least one argument is required.", "error", {
        title = "os.path.join to pathlib.Path",
      })
      return
    end

    new_text = wrap_with_pathlib(arglist_node:named_child(0))
    for i = 1, arglist_node:named_child_count() - 1 do
      local arg_node = arglist_node:named_child(i)
      if has_type(arg_node, "identifier") or has_type(arg_node, "string") or has_type(arg_node, "call") then
        new_text = new_text .. " / " .. get_text(arg_node)
      else
        new_text = new_text .. " / (" .. get_text(arg_node) .. ")"
      end
    end
  elseif function_name == "os.makedirs" then
    if arglist_node:named_child_count() == 0 then
      -- no arguments
      vim.notify("At least one argument is required.", "error", {
        title = "os.path.join to pathlib.Path",
      })
      return
    end
    new_text = one_arg_function_to_pathlib "mkdir(parents=True"
    for i = 1, arglist_node:named_child_count() - 1 do
      local arg_node = arglist_node:named_child(i)
      new_text = new_text .. ", " .. get_text(arg_node)
    end
    new_text = new_text .. ")"
  elseif function_name == "os.path.exists" then
    new_text = one_arg_function_to_pathlib "exists()"
  elseif function_name == "os.path.abspath" then
    new_text = one_arg_function_to_pathlib "resolve()"
  elseif function_name == "os.remove" then
    new_text = one_arg_function_to_pathlib "unlink()"
  elseif function_name == "os.unlink" then
    new_text = one_arg_function_to_pathlib "unlink()"
  elseif function_name == "os.path.expanduser" then
    new_text = one_arg_function_to_pathlib "expanduser()"
  elseif function_name == "os.path.isdir" then
    new_text = one_arg_function_to_pathlib "is_dir()"
  elseif function_name == "os.path.isfile" then
    new_text = one_arg_function_to_pathlib "is_file()"
  elseif function_name == "os.path.islink" then
    new_text = one_arg_function_to_pathlib "is_symlink()"
  elseif function_name == "os.path.isabs" then
    new_text = one_arg_function_to_pathlib "is_absolute()"
  elseif function_name == "os.path.basename" then
    new_text = one_arg_function_to_pathlib "name"
  elseif function_name == "os.path.dirname" then
    new_text = one_arg_function_to_pathlib "parent"
  elseif function_name == "os.path.getsize" then
    new_text = one_arg_function_to_pathlib "stat().st_size"
  elseif function_name == "os.path.getmtime" then
    new_text = one_arg_function_to_pathlib "stat().st_mtime"
  elseif function_name == "os.path.getctime" then
    new_text = one_arg_function_to_pathlib "stat().st_ctime"
  elseif function_name == "os.path.getatime" then
    new_text = one_arg_function_to_pathlib "stat().st_atime"
  else
    vim.notify("Function `" .. function_name .. "` not recognised.", "error", {
      title = "os.path to pathlib.Path",
      on_open = function(win)
        local buf = vim.api.nvim_win_get_buf(win)
        vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
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
  vim.api.nvim_buf_set_text(0, srow, scol, erow, ecol, { new_text })

  -- Restore cursor
  vim.api.nvim_win_set_cursor(winnr, cursor)
end

return M
