local notify = require("kiyoon.notify").notify
local utils = require("kiyoon.utils")

local M = {}

---key: bufnr
---value: list of ruff check info
---  key: line number
---  value: list of ruff check info
local bufnr_to_ruff_per_line = {}
---Same as above but if the error spans multiple lines, it will be repeated
---Used for code action and toggle noqa etc.
local bufnr_to_ruff_per_line_multiline = {}
---Save the changedtick of the buffer when ruff is run
local bufnr_to_ruff_changedtick = {}

---It also caches the results so repeated calls are fast
---@param bufnr integer vim buffer number
M.run_ruff = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local changedtick = vim.api.nvim_buf_get_changedtick(bufnr)
  if bufnr_to_ruff_changedtick[bufnr] == changedtick then
    return bufnr_to_ruff_per_line[bufnr]
  end

  -- NOTE: nvim_exec will write additional stuff to stdout, like "shell returned 1"
  -- so we need to pass the failing vim.json.decode
  local file_name = vim.api.nvim_buf_get_name(bufnr)
  local buf_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local response = vim
    .system({
      "ruff",
      "check",
      "--stdin-filename",
      file_name,
      "--output-format=json-lines",
      "--ignore-noqa",
      "-",
    }, { text = true, stdin = buf_lines })
    :wait()

  if response.code ~= 0 and response.code ~= 1 then
    -- NOTE: ruff returns 1 when there are violations
    notify(string.format("Failed to run ruff with code %d", response.code), vim.log.levels.ERROR)
  end
  local ruff_outputs = response.stdout:gsub("\n$", "")
  local ruff_outputs_list = vim.split(ruff_outputs, "\n")

  bufnr_to_ruff_per_line[bufnr] = {}
  bufnr_to_ruff_per_line_multiline[bufnr] = {}
  for _, line in ipairs(ruff_outputs_list) do
    local status, ruff_output = pcall(vim.json.decode, line)

    if not status then
      goto continue
    end
    local ruff_row = ruff_output["location"]["row"]
    if bufnr_to_ruff_per_line[bufnr][ruff_row] == nil then
      bufnr_to_ruff_per_line[bufnr][ruff_row] = { ruff_output }
    else
      table.insert(bufnr_to_ruff_per_line[bufnr][ruff_row], ruff_output)
    end

    local ruff_end_row = ruff_output["end_location"]["row"]
    for i = ruff_row, ruff_end_row do
      if bufnr_to_ruff_per_line_multiline[bufnr][i] == nil then
        bufnr_to_ruff_per_line_multiline[bufnr][i] = { ruff_output }
      else
        table.insert(bufnr_to_ruff_per_line_multiline[bufnr][i], ruff_output)
      end
    end

    ::continue::
  end

  bufnr_to_ruff_changedtick[bufnr] = changedtick
end

---Get comment node in the current line.
---@param winnr? number
---@return TSNode?
local function get_line_comment_node(winnr)
  winnr = winnr or 0
  local cursor = vim.api.nvim_win_get_cursor(winnr) -- (row,col): (1,0)-indexed
  local bufnr = vim.api.nvim_win_get_buf(winnr)

  -- find # in the current line
  local line = vim.api.nvim_buf_get_lines(bufnr, cursor[1] - 1, cursor[1], false)[1]
  local col = string.find(line, "#", 1, true)
  if col == nil then
    return nil
  end

  -- iterate through all # matches until vim.treesitter.get_node():type() == "comment"
  local node = nil
  while col ~= nil do
    node = vim.treesitter.get_node({ pos = { cursor[1] - 1, col - 1 }, bufnr = bufnr })
    if node and node:type() == "comment" then
      return node
    end
    col = string.find(line, "#", col + 1, true)
  end
end

---Remove comment starting with `comment_starts` from the current line.
---comment_starts should not include the # symbol.
---If there are multiple comments in the line, make sure to only remove the proper one.
---@param bufnr integer?
---@param comment_node TSNode comment node (even if there are multiple comments in the line, this is just one node that covers the entire comment)
---@param comment_starts string e.g. "noqa: "
---@return boolean status true if the comment is removed, false otherwise
local function remove_comment_startswith(bufnr, comment_node, comment_starts)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local comment_text = vim.treesitter.get_node_text(comment_node, bufnr)
  local match_idx = string.find(comment_text, "# " .. comment_starts, 1, true)
  if match_idx then
    -- Remove # `comment_starts`... # or if there is no comment (#) after the match, remove till the end
    local start_idx = match_idx + 2 + #comment_starts
    local end_idx = string.find(comment_text, "#", start_idx, true)
    local remove_trailing_space
    if end_idx then
      end_idx = end_idx - 1
      remove_trailing_space = false
    else
      end_idx = #comment_text
      remove_trailing_space = true
    end

    local new_comment_text = string.sub(comment_text, 1, match_idx - 1) .. string.sub(comment_text, end_idx + 1)
    local srow, scol, erow, ecol = comment_node:range()
    vim.api.nvim_buf_set_text(bufnr, srow, scol, erow, ecol, { new_comment_text })
    if remove_trailing_space then
      local line_content = vim.api.nvim_buf_get_lines(bufnr, srow, srow + 1, false)[1]
      local new_line_content = string.gsub(line_content, "%s+$", "")
      vim.api.nvim_buf_set_lines(bufnr, srow, srow + 1, false, { new_line_content })
    end
    return true
  end
  return false
end

---@param winnr integer?
M.toggle_ruff_noqa = function(winnr)
  winnr = winnr or vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(winnr)
  local current_line = vim.api.nvim_win_get_cursor(winnr)[1]

  -- 1. If there is an "# noqa: " comment, remove it.
  local comment_node = get_line_comment_node(winnr)
  if comment_node then
    if remove_comment_startswith(bufnr, comment_node, "noqa: ") then
      return
    end
  end

  -- 2. If not, add "# noqa " comment with existing ruff error codes.
  M.run_ruff(bufnr)

  if bufnr_to_ruff_per_line_multiline[bufnr][current_line] == nil then
    notify("No ruff error on current line", vim.log.levels.ERROR)
    return
  end

  local codes = {}
  local code_exists = {}

  for _, ruff_output in ipairs(bufnr_to_ruff_per_line_multiline[bufnr][current_line]) do
    if current_line == ruff_output["noqa_row"] then
      if not code_exists[ruff_output["code"]] then
        table.insert(codes, ruff_output["code"])
        code_exists[ruff_output["code"]] = true
      end
    end
  end

  if #codes == 0 then
    notify("No ruff error on current line", vim.log.levels.ERROR)
    return
  end

  local codes_concat = table.concat(codes, " ")
  local line_content = vim.api.nvim_buf_get_lines(bufnr, current_line - 1, current_line, false)[1]
  vim.api.nvim_buf_set_lines(
    bufnr,
    current_line - 1,
    current_line,
    false,
    { line_content .. "  # noqa: " .. codes_concat }
  )
end

---@param winnr integer?
---@return vim.Diagnostic[]
local get_pyright_diagnostics_current_line = function(winnr)
  winnr = winnr or vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(winnr)
  local line, _ = unpack(vim.api.nvim_win_get_cursor(winnr))
  local diagnostics = vim.diagnostic.get(bufnr, { lnum = line - 1 })
  if vim.tbl_isempty(diagnostics) then
    return {}
  end
  ---@param diagnostic vim.Diagnostic
  return vim.tbl_filter(function(diagnostic)
    if diagnostic.source == "Pyright" or diagnostic.source == "basedpyright" then
      return true
    end
    return false
  end, diagnostics)
end

---@param winnr integer?
M.toggle_pyright_ignore = function(winnr)
  winnr = winnr or vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(winnr)

  -- 1. If there is an "# pyright: ignore" or "# type: ignore" comment, remove it.
  local comment_node = get_line_comment_node(winnr)
  if comment_node then
    if remove_comment_startswith(bufnr, comment_node, "pyright: ignore") then
      return
    end
    if remove_comment_startswith(bufnr, comment_node, "type: ignore") then
      return
    end
  end

  -- 2. If not, add "# pyright: ignore[...]" comment with existing pyright error codes.
  local diagnostics = get_pyright_diagnostics_current_line(winnr)

  local codes = {}
  for _, diagnostic in ipairs(diagnostics) do
    codes[diagnostic.code] = true -- make sure codes are unique
  end
  local codes_list = vim.tbl_keys(codes)
  local codes_concat = table.concat(codes_list, ", ")
  local current_line = vim.api.nvim_win_get_cursor(winnr)[1]
  local line_content = vim.api.nvim_buf_get_lines(bufnr, current_line - 1, current_line, false)[1]
  local comment = "# pyright: ignore"
  if #codes_list ~= 0 then
    comment = comment .. "[" .. codes_concat .. "]"
  end

  vim.api.nvim_buf_set_lines(bufnr, current_line - 1, current_line, false, { line_content .. "  " .. comment })
end

local function notify_diff_pre(bufnr)
  if bufnr == nil then
    bufnr = vim.api.nvim_get_current_buf()
  end
  local prev_buf = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local prev_buf_str = table.concat(prev_buf, "\n")
  return prev_buf_str
end

local function notify_diff(bufnr, prev_buf_str, ruff_fix_message)
  if ruff_fix_message == nil then
    ruff_fix_message = "Ruff fix applied"
  end
  local new_buf = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local new_buf_str = table.concat(new_buf, "\n")
  local diff = vim.diff(prev_buf_str, new_buf_str, { ctxlen = 3 })
  -- strip last empty line
  -- diff = vim.split(diff, "\n")
  -- table.remove(diff, #diff)
  -- diff = table.concat(diff, "\n")
  diff = diff:gsub("\n$", "")

  notify(ruff_fix_message .. "\n" .. diff, "info", {
    title = "Ruff fix applied",
    on_open = function(win)
      local buf = vim.api.nvim_win_get_buf(win)
      vim.bo[buf].filetype = "diff"
    end,
    animate = false,
  })
end

local function apply_ruff_fix(fix)
  local content = vim.split(fix["content"], "\n")
  local start_row = fix["location"]["row"] - 1
  local start_col = fix["location"]["column"] - 1
  local end_row = fix["end_location"]["row"] - 1
  local end_col = fix["end_location"]["column"] - 1

  -- handle unicode
  local start_line_content = vim.api.nvim_buf_get_lines(0, start_row, start_row + 1, false)[1]
  local end_line_content = vim.api.nvim_buf_get_lines(0, end_row, end_row + 1, false)[1]
  start_col = vim.str_byteindex(start_line_content, "utf-16", start_col)
  end_col = vim.str_byteindex(end_line_content, "utf-16", end_col)

  -- end row can be out of bounds
  local num_lines = vim.api.nvim_buf_line_count(0)
  if end_row >= num_lines then
    end_row = num_lines - 1
    end_col = #end_line_content
  end

  vim.api.nvim_buf_set_text(0, start_row, start_col, end_row, end_col, content)
end

-- NOTE: Sometimes it can produce equal fixes, so it's better to run ruff again after each fix.
-- For example, if you want to remove unused imports, and there are two unused imports in the same line,
-- it will produce two fixes. If you apply the first fix, the second fix will be invalid.
--
-- M.ruff_fix_current_line = function(bufnr, ruff_codes)
--   bufnr = bufnr or vim.api.nvim_get_current_buf()
--
--   -- if ruff_code is a string, convert it to a table
--   if type(ruff_codes) == "string" then
--     ruff_codes = { ruff_codes }
--   end
--
--   local do_fix_code = {}
--   if ruff_codes ~= nil then
--     for _, code in pairs(ruff_codes) do
--       do_fix_code[code] = true
--     end
--   end
--
--   local current_line = vim.fn.line(".")
--   M.run_ruff(bufnr)
--
--   if bufnr_to_ruff_per_line_multiline[bufnr][current_line] == nil then
--     vim.notify("No ruff fix available for current line", vim.log.levels.ERROR)
--     return
--   end
--
--   local all_fixes = {}
--   for _, ruff_output in ipairs(bufnr_to_ruff_per_line_multiline[bufnr][current_line]) do
--     if ruff_codes == nil or do_fix_code[ruff_output["code"]] then
--       local fix = ruff_output["fix"]
--       if fix == vim.NIL then
--         goto continue
--       end
--
--       local fixes_in_current_edit = {}
--       for _, edit in ipairs(fix["edits"]) do
--         edit["message"] = fix["message"]
--         table.insert(fixes_in_current_edit, edit)
--       end
--       -- NOTE: each fix may have multiple edits
--       -- In this case, we have to reverse the order of the edits
--       -- Otherwise, the prior edits will ruin the later edits
--       fixes_in_current_edit = utils.list_reverse(fixes_in_current_edit)
--       vim.list_extend(all_fixes, fixes_in_current_edit)
--       -- table.insert(all_fixes, fix)
--     end
--     ::continue::
--   end
--
--   if #all_fixes == 0 then
--     vim.notify("No ruff fix available for current line", vim.log.levels.ERROR)
--     return
--   end
--
--   local prev_buf_str = notify_diff_pre(bufnr)
--   for _, fix in pairs(all_fixes) do
--     apply_ruff_fix(fix)
--     notify_diff(bufnr, prev_buf_str, fix["message"])
--     -- TODO: check if applying all fixes is correct
--     -- break
--   end
-- end

---@param bufnr integer? vim buffer number
---@param ruff_codes table|string|nil ruff code to fix, if nil, fix all
M.ruff_fix_current_line = function(bufnr, ruff_codes)
  if bufnr == 0 or bufnr == nil then
    bufnr = vim.api.nvim_get_current_buf()
  end

  -- if ruff_code is a string, convert it to a table
  if type(ruff_codes) == "string" then
    ruff_codes = { ruff_codes }
  end

  local do_fix_code = {}
  if ruff_codes ~= nil then
    for _, code in pairs(ruff_codes) do
      do_fix_code[code] = true
    end
  end

  local prev_buf_str = notify_diff_pre(bufnr)
  local num_fixed = 0
  local current_line = vim.fn.line(".")

  -- PERF: this runs ruff multiple times until it doesn't find any fix
  -- This can be slow but it's the easiest way to implement it
  -- NOTE: this will run up to 1000 times to avoid infinite loop
  --- Apply all ruff fixes, optionally only for a specific code
  repeat
    M.run_ruff(bufnr)
    local fixed = false
    local ruff_outputs = bufnr_to_ruff_per_line_multiline[bufnr][current_line]
    for _, ruff_output in ipairs(ruff_outputs) do
      if ruff_codes == nil or do_fix_code[ruff_output["code"]] then
        local fix = ruff_output["fix"]
        if fix ~= vim.NIL then
          -- NOTE: each fix may have multiple edits
          -- In this case, we have to reverse the order of the edits
          -- Otherwise, the prior edits will ruin the later edits
          local fixes_in_current_edit = utils.list_reverse(fix["edits"])
          for _, edit in ipairs(fixes_in_current_edit) do
            apply_ruff_fix(edit)
          end
          fixed = true
          num_fixed = num_fixed + 1
          break
        end
      end
    end
    if fixed then
      break
    end
  until not fixed or num_fixed > 1000

  if num_fixed == 0 then
    notify("No fix available.", vim.log.levels.ERROR)
  else
    notify_diff(bufnr, prev_buf_str, num_fixed .. " fixes applied")
  end
end

---@param bufnr integer vim buffer number
---@param ruff_codes table|string|nil ruff code to fix, if nil, fix all
M.ruff_fix_all = function(bufnr, ruff_codes)
  if bufnr == 0 or bufnr == nil then
    bufnr = vim.api.nvim_get_current_buf()
  end

  -- if ruff_code is a string, convert it to a table
  if type(ruff_codes) == "string" then
    ruff_codes = { ruff_codes }
  end

  local do_fix_code = {}
  if ruff_codes ~= nil then
    for _, code in pairs(ruff_codes) do
      do_fix_code[code] = true
    end
  end

  local prev_buf_str = notify_diff_pre(bufnr)
  local num_fixed = 0

  -- PERF: this runs ruff multiple times until it doesn't find any fix
  -- This can be slow but it's the easiest way to implement it
  -- NOTE: this will run up to 1000 times to avoid infinite loop
  --- Apply all ruff fixes, optionally only for a specific code
  repeat
    M.run_ruff(bufnr)
    local fixed = false
    for _, ruff_line in pairs(bufnr_to_ruff_per_line_multiline[bufnr]) do
      for _, ruff_output in ipairs(ruff_line) do
        if ruff_codes == nil or do_fix_code[ruff_output["code"]] then
          local fix = ruff_output["fix"]
          if fix ~= vim.NIL then
            -- NOTE: each fix may have multiple edits
            -- In this case, we have to reverse the order of the edits
            -- Otherwise, the prior edits will ruin the later edits
            local fixes_in_current_edit = utils.list_reverse(fix["edits"])
            for _, edit in ipairs(fixes_in_current_edit) do
              apply_ruff_fix(edit)
            end
            fixed = true
            num_fixed = num_fixed + 1
            break
          end
        end
      end
      if fixed then
        break
      end
    end
  until not fixed or num_fixed > 1000

  if num_fixed == 0 then
    notify("No fix available.", vim.log.levels.ERROR)
  else
    notify_diff(bufnr, prev_buf_str, num_fixed .. " fixes applied")
  end
end

function M.available_actions(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local actions = {}

  local current_line = vim.fn.line(".")
  M.run_ruff(bufnr)

  if
    bufnr_to_ruff_per_line_multiline[bufnr] ~= nil and bufnr_to_ruff_per_line_multiline[bufnr][current_line] ~= nil
  then
    -- table.insert(actions, { title = "Ruff: Toggle noqa", action = M.toggle_ruff_noqa })

    for _, ruff_output in ipairs(bufnr_to_ruff_per_line_multiline[bufnr][current_line]) do
      local fix = ruff_output["fix"]
      if fix ~= vim.NIL then
        local fix_code = ruff_output["code"]
        local ruff_message = ruff_output["message"]
        table.insert(actions, {
          title = "Ruff: Fix current: " .. fix["message"] .. " [" .. fix_code .. "]",
          action = function()
            M.ruff_fix_current_line(bufnr, fix_code)
          end,
        })
        table.insert(actions, {
          title = "Ruff: Fix " .. fix_code .. ": " .. ruff_message,
          action = function()
            M.ruff_fix_all(bufnr, fix_code)
          end,
        })
      elseif ruff_output["code"] == "INP001" then
        -- Missing __init__.py
        -- The fix isn't available by ruff, but I can provide a fix
        table.insert(actions, {
          title = "Ruff: Fix INP001: Add __init__.py",
          action = function()
            local file_name = vim.api.nvim_buf_get_name(bufnr)
            local dir_name = vim.fn.fnamemodify(file_name, ":h")
            local init_file = dir_name .. "/__init__.py"
            -- write an empty __init__.py
            local file = io.open(init_file, "a") -- append so it doesn't overwrite existing content by mistake
            if file == nil then
              notify("Failed to create __init__.py", vim.log.levels.ERROR)
              return
            end
            file:write("")
            file:close()
          end,
        })
      end
    end
  end

  return actions
end

return M
