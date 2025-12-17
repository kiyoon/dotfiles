local M = {}

---@param fn function
local function make_dot_repeatable(fn)
  _G._kiyoon_toggler_last_function = fn
  vim.o.opfunc = "v:lua._kiyoon_toggler_last_function"
  vim.api.nvim_feedkeys("g@l", "n", false)
end

local function ts_expand_parameter_name_punct(bufnr, node, cap, r)
  if cap ~= "name" then
    return r
  end
  -- only safe for single-line names
  if r.srow ~= r.erow then
    return r
  end

  local line = (vim.api.nvim_buf_get_lines(bufnr, r.erow, r.erow + 1, false)[1] or "")
  local pos = r.ecol

  local function char_at(col0)
    if col0 < 0 or col0 >= #line then
      return ""
    end
    return line:sub(col0 + 1, col0 + 1)
  end

  -- r.ecol is currently at/after node end; grow right:
  while char_at(pos):match("%s") do
    pos = pos + 1
  end
  if char_at(pos) == "?" then
    pos = pos + 1
    while char_at(pos):match("%s") do
      pos = pos + 1
    end
  end
  if char_at(pos) == ":" then
    pos = pos + 1
  end

  r.ecol = math.max(r.ecol, pos)
  return r
end

local hitbox = require("wookayin.hitbox")

---@return integer?, TSNode?, vim.treesitter.Query?
local function get_ts_query_and_root()
  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype
  local lang = vim.treesitter.language.get_lang(ft) or ft

  local q = vim.treesitter.query.get(lang, "kiyoon")
  if not q then
    return nil, nil, nil
  end

  local parser = vim.treesitter.get_parser(bufnr, lang)
  local root = parser:parse()[1]:root()
  return bufnr, root, q
end

---@return TSNode?, string?, Range4?
M.get_capture_node_under_cursor = function()
  local bufnr, root, query = get_ts_query_and_root()
  if not (bufnr and root and query) then
    return nil, nil, nil
  end

  return hitbox.get_capture_node_and_hitbox(bufnr, root, query, {
    expand_whitespace = true,
    expand_extra = ts_expand_parameter_name_punct,
  })
end

-- tiny helpers for byte edits
local function buf_text(bufnr, row0, col0, col1)
  local t = vim.api.nvim_buf_get_text(bufnr, row0, col0, row0, col1, {})
  return t[1] or ""
end

local function find_qmark_pos(bufnr, row0, col0)
  local s = buf_text(bufnr, row0, col0, col0 + 16)
  local i = 1
  while i <= #s and s:sub(i, i):match("%s") do
    i = i + 1
  end
  if s:sub(i, i) == "?" then
    return col0 + (i - 1)
  end
  return nil
end

local function toggle_optional_marker(parameter_name_node)
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)

  local srow, scol, erow, ecol = parameter_name_node:range()
  if srow ~= erow then
    vim.notify("Optional toggle: multi-line parameter.name not supported", vim.log.levels.WARN)
    return
  end

  local qpos = find_qmark_pos(bufnr, erow, ecol)
  if qpos then
    -- remove '?'
    vim.api.nvim_buf_set_text(bufnr, erow, qpos, erow, qpos + 1, { "" })
    if cursor[1] - 1 == erow and cursor[2] > qpos then
      cursor[2] = cursor[2] - 1
      vim.api.nvim_win_set_cursor(0, cursor)
    end
  else
    -- insert '?' right after parameter.name (no space)
    vim.api.nvim_buf_set_text(bufnr, erow, ecol, erow, ecol, { "?" })
    if cursor[1] - 1 == erow and cursor[2] >= ecol then
      cursor[2] = cursor[2] + 1
      vim.api.nvim_win_set_cursor(0, cursor)
    end
  end
end

local function set_node_text(bufnr, node, text)
  local srow, scol, erow, ecol = node:range()
  local lines = vim.split(text, "\n", { plain = true })
  vim.api.nvim_buf_set_text(bufnr, srow, scol, erow, ecol, lines)
end

local function toggle_null_union(type_node)
  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)

  local text = vim.treesitter.get_node_text(type_node, bufnr)
  local new_text

  -- remove “| null” at end
  local stripped = text:gsub("%s*|%s*null%s*$", "", 1)
  if stripped ~= text then
    new_text = stripped
  else
    -- remove “null | T” at start
    stripped = text:gsub("^null%s*|%s*", "", 1)
    if stripped ~= text then
      new_text = stripped
    else
      -- add at end
      new_text = text .. " | null"
    end
  end

  set_node_text(bufnr, type_node, new_text)
  vim.api.nvim_win_set_cursor(0, cursor)
end

-- Public entry: “smart toggle”
M.toggle_null_or_optional = function()
  return make_dot_repeatable(function()
    local node, cap, hitbox = M.get_capture_node_under_cursor()
    if not node then
      vim.notify("Cursor not in a captured TS type/parameter.name node", vim.log.levels.WARN)
      return
    end

    if cap == "type" then
      toggle_null_union(node)
    elseif cap == "parameter.name" then
      toggle_optional_marker(node)
    else
      vim.notify("Unknown capture: " .. tostring(cap), vim.log.levels.WARN)
    end
  end)
end

return M
