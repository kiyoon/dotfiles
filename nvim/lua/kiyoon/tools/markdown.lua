local M = {}

---@class TurnToLinkOpts
---@field repeat_content? boolean Whether to repeat the content of the link

---In normal mode, turn the current word (viW) into a link.
---In visual mode, turn the selected text into a link.
---@param opts table
M.turn_to_link = function(opts)
  opts = opts or {}
  opts.repeat_content = opts.repeat_content or false
  opts.finish_mode = opts.finish_mode or "n"

  -- If in normal mode, select the inner word synchronously
  if vim.fn.mode() == "n" then
    vim.cmd("normal! viW")
  end

  -- Visual mode: wrap the selected text in a markdown link
  -- Exit visual mode
  -- If you don't exit visual mode, the previous selection will be used
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)
  local bufnr = vim.api.nvim_get_current_buf()
  local start_pos = vim.api.nvim_buf_get_mark(bufnr, "<") -- {line, col}
  local end_pos = vim.api.nvim_buf_get_mark(bufnr, ">") -- {line, col}
  local s_row, s_col = start_pos[1] - 1, start_pos[2]
  local e_row, e_col = end_pos[1] - 1, end_pos[2] + 1

  -- Retrieve the selected text
  local lines = vim.api.nvim_buf_get_lines(bufnr, s_row, e_row + 1, false)
  if #lines == 0 then
    return
  end
  local text
  if #lines == 1 then
    text = lines[1]:sub(s_col + 1, e_col)
  else
    local parts = {}
    parts[1] = lines[1]:sub(s_col + 1)
    for i = 2, #lines - 1 do
      parts[i] = lines[i]
    end
    parts[#lines] = lines[#lines]:sub(1, e_col)
    text = table.concat(parts, "\n")
  end

  -- Prepare link text and URL
  local url = ""
  if opts.repeat_content then
    -- strip backticks if present
    url = text:gsub("^`(.*)`$", "%1")
  end
  local link = string.format("[%s](%s)", text, url)

  -- Replace the selected region with the link
  vim.api.nvim_buf_set_text(bufnr, s_row, s_col, e_row, e_col, { link })

  -- move the cursor to the end of the link
  local link_length = #link
  local new_col = s_col + link_length - 1
  if new_col > vim.api.nvim_buf_get_lines(bufnr, s_row, s_row + 1, false)[1]:len() then
    new_col = vim.api.nvim_buf_get_lines(bufnr, s_row, s_row + 1, false)[1]:len()
  end
  vim.api.nvim_win_set_cursor(0, { s_row + 1, new_col })
end

return M
