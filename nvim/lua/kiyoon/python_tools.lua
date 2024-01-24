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
  local ruff_outputs =
    vim.api.nvim_exec([[w !ruff check --output-format=json-lines --ignore-noqa -]], { output = true })
  assert(ruff_outputs ~= nil)
  ruff_outputs = vim.split(ruff_outputs, "\n")

  bufnr_to_ruff_per_line[bufnr] = {}
  for _, line in ipairs(ruff_outputs) do
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
  M.run_ruff()

  if bufnr_to_ruff_per_line[bufnr][current_line] == nil then
    vim.notify("No ruff error on current line", vim.log.levels.ERROR)
    return
  end

  local codes = {}
  for _, ruff_output in ipairs(bufnr_to_ruff_per_line[bufnr][current_line]) do
    if current_line == ruff_output["noqa_row"] then
      table.insert(codes, ruff_output["code"])
    end
  end

  if #codes == 0 then
    vim.notify("No ruff error on current line", vim.log.levels.ERROR)
    return
  end

  local code = table.concat(codes, " ")
  require("wookayin.lib.python").toggle_line_comment("noqa: " .. code)
end

M.ruff_fix_current_line = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local current_line = vim.fn.line "."
  M.run_ruff()

  if bufnr_to_ruff_per_line[bufnr][current_line] == nil then
    vim.notify("No ruff fix available for current line", vim.log.levels.ERROR)
    return
  end

  local all_fixes = {}
  for _, ruff_output in ipairs(bufnr_to_ruff_per_line[bufnr][current_line]) do
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
    ::continue::
  end

  if #all_fixes == 0 then
    vim.notify("No ruff fix available for current line", vim.log.levels.ERROR)
    return
  end

  for _, fix in pairs(all_fixes) do
    local content = vim.split(fix["content"], "\n")
    local start_row = fix["location"]["row"] - 1
    local start_col = fix["location"]["column"] - 1
    local end_row = fix["end_location"]["row"] - 1
    local end_col = fix["end_location"]["column"] - 1
    local message = fix["message"]

    -- local prev_buf = vim.api.nvim_buf_get_lines(0, start_row - 3, end_row + 3, false)
    local prev_buf = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local prev_buf_str = table.concat(prev_buf, "\n")

    vim.api.nvim_buf_set_text(0, start_row, start_col, end_row, end_col, content)

    local new_buf = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local new_buf_str = table.concat(new_buf, "\n")
    local diff = vim.diff(prev_buf_str, new_buf_str, { ctxlen = 3 })
    -- strip last empty line
    -- diff = vim.split(diff, "\n")
    -- table.remove(diff, #diff)
    -- diff = table.concat(diff, "\n")
    diff = diff:gsub("\n$", "")

    vim.notify(message .. "\n" .. diff, "info", {
      title = "Ruff fix applied at line " .. (start_row + 1),
      on_open = function(win)
        local buf = vim.api.nvim_win_get_buf(win)
        vim.api.nvim_buf_set_option(buf, "filetype", "diff")
      end,
    })

    -- TODO: for now, only apply the first fix
    break
  end
end

function M.available_actions(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local actions = {}

  local current_line = vim.fn.line "."
  M.run_ruff()

  if bufnr_to_ruff_per_line[bufnr] ~= nil and bufnr_to_ruff_per_line[bufnr][current_line] ~= nil then
    table.insert(actions, { title = "Ruff: Toggle noqa", action = M.toggle_ruff_noqa })

    local fix_available = false
    for _, ruff_output in ipairs(bufnr_to_ruff_per_line[bufnr][current_line]) do
      local fix = ruff_output["fix"]
      if fix ~= vim.NIL then
        fix_available = true
        break
      end
    end
    if fix_available then
      table.insert(actions, { title = "Ruff: Fix current line", action = M.ruff_fix_current_line })
    end
  end

  return actions
end

return M
