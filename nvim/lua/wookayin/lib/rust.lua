--- Added by kiyoon
local M = {}

---Return the node that covers the type. It searches for the closest ancestor from the current node, so it can be pretty broad.
---@return TSNode?
local function get_node_that_covers_type()
  ---@type TSNode?
  local node = vim.treesitter.get_node()
  -- Climb up and find the closest ancestor node whose children has a `type` node:
  -- it should be generic enough to cover the full text, not part of the type like type_identifier.
  while
    (node ~= nil)
    and not vim.list_contains({
      -- "type_identifier",
      -- "reference_type",
      -- "primitive_type",
      "field_declaration",
      "function_item",
    }, node:type())
  do
    node = node:parent()
  end

  if node == nil then
    require("kiyoon.notify").notify("Not in a type node", vim.log.levels.ERROR, { title = "toggle_option_type" })
    return nil
  end

  return node
end

---Return the @type node from `kiyoon.scm` query.
---@param node TSNode The node to search for the type node.
---@return TSNode?
local function get_type_node_under_cursor(node)
  local winnr = 0
  local cursor = vim.api.nvim_win_get_cursor(winnr) -- (row,col): (1,0)-indexed
  local bufnr = vim.api.nvim_get_current_buf()

  local query = vim.treesitter.query.get("rust", "kiyoon") ---@type vim.treesitter.Query?
  if query == nil then
    require("kiyoon.notify").notify("Query not found.", vim.log.levels.ERROR, { title = "toggle_option_type" })
    return nil
  end

  for _, match in query:iter_matches(node, bufnr) do
    for id, nodes in pairs(match) do
      --- In Nvim 0.9 node is a TSNode, in Nvim 0.10+ it is a list of TSNode
      --- @type TSNode
      local node0 = type(nodes) == "table" and nodes[#nodes] or nodes

      -- cursor in node
      if vim.treesitter.is_in_node_range(node0, cursor[1] - 1, cursor[2]) then
        local name = query.captures[id] -- name of the capture in the query
        if name == "type" then
          return node0
        end
      end
    end
  end

  require("kiyoon.notify").notify("Cursor not in a type node.", vim.log.levels.ERROR, { title = "toggle_option_type" })
  return nil
end

---Adds `Option<...>` to the type hint (or strip it).
M.toggle_option_type = function()
  local bufnr = vim.api.nvim_get_current_buf()

  local node = get_node_that_covers_type() ---@type TSNode?
  if node == nil then
    return
  end

  local type_node = get_type_node_under_cursor(node) ---@type TSNode?
  if type_node == nil then
    return
  end

  local text = vim.treesitter.get_node_text(type_node, bufnr)
  local srow, scol, erow, ecol = type_node:range()
  local new_text
  if text:match("^Option%<.*%>$") then
    -- strip Option<...>
    new_text = text:gsub("^Option<(.*)>", "%1")
  else
    -- add Option<...>
    new_text = "Option<" .. text .. ">"
  end
  vim.api.nvim_buf_set_text(bufnr, srow, scol, erow, ecol, { new_text })
end

---Adds `Option<...>` to the type hint (or strip it).
M.toggle_result_type = function()
  local bufnr = vim.api.nvim_get_current_buf()

  local node = get_node_that_covers_type() ---@type TSNode?
  if node == nil then
    return
  end

  local type_node = get_type_node_under_cursor(node) ---@type TSNode?
  if type_node == nil then
    return
  end

  local text = vim.treesitter.get_node_text(type_node, bufnr)
  local srow, scol, erow, ecol = type_node:range()
  local new_text
  if text:match("^Result%<.*%>$") then
    -- strip Result<...>
    -- new_text = text:gsub("^Option<(.*)>", "%1")

    -- Result<type, error> is stripped to type
    -- Result type is defined as follows:

    -- (generic_type
    --   type: (type_identifier)
    --   type_arguments: (type_arguments
    --     (type_identifier)))

    -- see node's type_arguments's first child node to get the type.
    assert(type_node:type() == "generic_type")
    type_node = type_node:named_child(1)
    if type_node == nil then
      require("kiyoon.notify").notify("Unknown error", vim.log.levels.ERROR, { title = "toggle_option_type" })
      return
    end
    assert(type_node:type() == "type_arguments")
    type_node = type_node:named_child(0)
    if type_node == nil then
      require("kiyoon.notify").notify("Unknown error", vim.log.levels.ERROR, { title = "toggle_option_type" })
      return
    end
    new_text = vim.treesitter.get_node_text(type_node, bufnr)
    vim.api.nvim_buf_set_text(bufnr, srow, scol, erow, ecol, { new_text })
  else
    -- add Option<...>
    new_text = "Result<" .. text .. ", >"
    vim.api.nvim_buf_set_text(bufnr, srow, scol, erow, ecol, { new_text })
    -- move cursor to the error type
    vim.api.nvim_win_set_cursor(0, { srow + 1, scol + #new_text - 1 })
  end
end

return M
