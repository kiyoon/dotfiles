local M = {}

---key: bufnr
---value: list of ruff check info
---  key: line number
---  value: list of ruff check info
local bufnr_to_ruff_per_line = {}
---Save the changedtick of the buffer when ruff is run
local bufnr_to_ruff_changedtick = {}

---It also caches the results so repeated calls are fast
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

    ::continue::
  end

  bufnr_to_ruff_changedtick[bufnr] = changedtick
end

M.toggle_ruff_noqa = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local current_line = vim.fn.line "."
  M.run_ruff(bufnr)

  if bufnr_to_ruff_per_line[bufnr][current_line] == nil then
    vim.notify("No ruff error on current line", vim.log.levels.ERROR)
    return
  end

  local codes = {}
  local code_exists = {}

  for _, ruff_output in ipairs(bufnr_to_ruff_per_line[bufnr][current_line]) do
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
      vim.api.nvim_buf_set_option(buf, "filetype", "diff")
    end,
  })
end

local function apply_ruff_fix(fix)
  local content = vim.split(fix["content"], "\n")
  local start_row = fix["location"]["row"] - 1
  local start_col = fix["location"]["column"] - 1
  local end_row = fix["end_location"]["row"] - 1
  local end_col = fix["end_location"]["column"] - 1

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

  local current_line = vim.fn.line "."
  M.run_ruff(bufnr)

  if bufnr_to_ruff_per_line[bufnr][current_line] == nil then
    vim.notify("No ruff fix available for current line", vim.log.levels.ERROR)
    return
  end

  local all_fixes = {}
  for _, ruff_output in ipairs(bufnr_to_ruff_per_line[bufnr][current_line]) do
    if ruff_codes == nil or do_fix_code[ruff_output["code"]] then
      local fix = ruff_output["fix"]
      if fix == vim.NIL then
        goto continue
      end

      -- each fix may have multiple edits
      for _, edit in ipairs(fix["edits"]) do
        edit["message"] = fix["message"]
        table.insert(all_fixes, edit)
      end
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
    -- TODO: for now, only apply the first fix
    break
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
            -- each fix may have multiple edits
            apply_ruff_fix(fix["edits"][1])
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

  local current_line = vim.fn.line "."
  M.run_ruff(bufnr)

  if bufnr_to_ruff_per_line[bufnr] ~= nil and bufnr_to_ruff_per_line[bufnr][current_line] ~= nil then
    -- table.insert(actions, { title = "Ruff: Toggle noqa", action = M.toggle_ruff_noqa })

    for _, ruff_output in ipairs(bufnr_to_ruff_per_line[bufnr][current_line]) do
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
      end
    end
  end

  return actions
end

return M
