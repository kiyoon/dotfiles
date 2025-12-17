local notify = require("type_righter.notify")
local utils = require("type_righter.utils")
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
  utils.make_dot_repeatable(function()
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
  end)
end

M.toggle_fstring = function()
  utils.make_dot_repeatable(function()
    -- Credit: https://www.reddit.com/r/neovim/comments/tge2ty/python_toggle_fstring_using_treesitter/
    local winnr = 0
    local cursor = vim.api.nvim_win_get_cursor(winnr)
    ---@type TSNode?
    local node = require("type_righter.ts_utils").get_node_at_cursor(winnr)

    while (node ~= nil) and (node:type() ~= "string") do
      node = node:parent()
    end
    if node == nil then
      vim.api.nvim_echo({ { "f-string: not in a string node.", "WarningMsg" } }, false, {})
      return
    end

    ---@diagnostic disable-next-line: unused-local
    local srow, scol, _erow, _ecol = require("type_righter.ts_utils").get_vim_range({ node:range() })
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
  end)
end

M.toggle_line_comment = function(text)
  utils.make_dot_repeatable(function()
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
  end)
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
  utils.make_dot_repeatable(function()
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
  end)
end

--- Added by kiyoon
--- Replaces Union[T1, T2] with T1 | T2
--- Replaces Optional[T] with T | None
--- Replaces List[T] with list[T]
--- Replaces Dict[K, V] with dict[K, V]
--- Replaces Set[T] with set[T]
--- Replaces Tuple[T1, T2] with tuple[T1, T2]
M.upgrade_typing = function(node)
  utils.make_dot_repeatable(function()
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
      notify("No fix found.", vim.log.levels.ERROR, {
        title = "type-righter.nvim",
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
        notify("At least one argument is required", vim.log.levels.ERROR, {
          title = "type-righter.nvim",
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
        notify("At least one argument is required", vim.log.levels.ERROR, {
          title = "type-righter.nvim",
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
  end)
end

return M
