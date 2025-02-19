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

local function tbl_reverse(tab)
  for i = 1, math.floor(#tab / 2), 1 do
    tab[i], tab[#tab - i + 1] = tab[#tab - i + 1], tab[i]
  end
  return tab
end

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
    vim.notify(string.format("Failed to run ruff with code %d", response.code), vim.log.levels.ERROR)
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

M.toggle_ruff_noqa = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local current_line = vim.fn.line(".")
  M.run_ruff(bufnr)

  if bufnr_to_ruff_per_line_multiline[bufnr][current_line] == nil then
    vim.notify("No ruff error on current line", vim.log.levels.ERROR)
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
    vim.notify("No ruff error on current line", vim.log.levels.ERROR)
    return
  end

  local code = table.concat(codes, " ")
  require("wookayin.lib.python").toggle_line_comment("noqa: " .. code)
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

  vim.notify(ruff_fix_message .. "\n" .. diff, "info", {
    title = "Ruff fix applied",
    on_open = function(win)
      local buf = vim.api.nvim_win_get_buf(win)
      vim.bo[buf].filetype = "diff"
    end,
  })
end

local function apply_ruff_fix(fix)
  local content = vim.split(fix["content"], "\n")
  local start_row = fix["location"]["row"] - 1
  local start_col = fix["location"]["column"] - 1
  local end_row = fix["end_location"]["row"] - 1
  local end_col = fix["end_location"]["column"] - 1

  -- end row can be out of bounds
  local num_lines = vim.api.nvim_buf_line_count(0)
  if end_row >= num_lines then
    end_row = num_lines - 1
    end_col = #vim.api.nvim_buf_get_lines(0, end_row, end_row + 1, false)[1]
  end

  vim.api.nvim_buf_set_text(0, start_row, start_col, end_row, end_col, content)
end

M.ruff_fix_current_line = function(bufnr, ruff_codes)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

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

  local current_line = vim.fn.line(".")
  M.run_ruff(bufnr)

  if bufnr_to_ruff_per_line_multiline[bufnr][current_line] == nil then
    vim.notify("No ruff fix available for current line", vim.log.levels.ERROR)
    return
  end

  local all_fixes = {}
  for _, ruff_output in ipairs(bufnr_to_ruff_per_line_multiline[bufnr][current_line]) do
    if ruff_codes == nil or do_fix_code[ruff_output["code"]] then
      local fix = ruff_output["fix"]
      if fix == vim.NIL then
        goto continue
      end

      local fixes_in_current_edit = {}
      for _, edit in ipairs(fix["edits"]) do
        edit["message"] = fix["message"]
        table.insert(fixes_in_current_edit, edit)
      end
      -- NOTE: each fix may have multiple edits
      -- In this case, we have to reverse the order of the edits
      -- Otherwise, the prior edits will ruin the later edits
      fixes_in_current_edit = tbl_reverse(fixes_in_current_edit)
      vim.list_extend(all_fixes, fixes_in_current_edit)
      -- table.insert(all_fixes, fix)
    end
    ::continue::
  end

  if #all_fixes == 0 then
    vim.notify("No ruff fix available for current line", vim.log.levels.ERROR)
    return
  end

  local prev_buf_str = notify_diff_pre(bufnr)
  for _, fix in pairs(all_fixes) do
    apply_ruff_fix(fix)
    notify_diff(bufnr, prev_buf_str, fix["message"])
    -- TODO: check if applying all fixes is correct
    -- break
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
    for _, ruff_line in pairs(bufnr_to_ruff_per_line[bufnr]) do
      for _, ruff_output in ipairs(ruff_line) do
        if ruff_codes == nil or do_fix_code[ruff_output["code"]] then
          local fix = ruff_output["fix"]
          if fix ~= vim.NIL then
            -- NOTE: each fix may have multiple edits
            -- In this case, we have to reverse the order of the edits
            -- Otherwise, the prior edits will ruin the later edits
            local fixes_in_current_edit = tbl_reverse(fix["edits"])
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
    vim.notify("No fix available.", vim.log.levels.ERROR)
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
              vim.notify("Failed to create __init__.py", vim.log.levels.ERROR)
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
