--[[
Asynchronous terminal commands.
https://www.reddit.com/r/neovim/comments/1377lwn/is_there_a_plugin_for_async_shell_command/

These work like ! commands, but allow you to continue to use Neovim while the command runs in the background.

Usages:
:'<, '>X command
:Xr command
:%Xw command
:Xr command
:Xstop
:vnoremap <leader>! :'<,'>X command<cr>
--]]

M = {}

MARK_NS = vim.api.nvim_create_namespace "AsyncShell"
MAX_LENGTH = 100000

local last_job_id = 0

function M.KillAsyncShell()
  if last_job_id ~= 0 then
    vim.fn.jobstop(last_job_id)
    print(string.format("Job %d killed", last_job_id))
    last_job_id = 0
  end
end

function M.AsyncShell(command, ex, line1, line2)
  local bufnum = vim.api.nvim_get_current_buf()
  local start_row, start_col, end_row, end_col

  -- :r !command
  if ex == "r" and line1 then
    start_row = line1
    start_col = 1
    end_row = line1
    end_col = 1
  else
    _, start_row, start_col = unpack(vim.fn.getpos "'<")
    _, end_row, end_col = unpack(vim.fn.getpos "'>")

    -- print(
    --   command .. ', ' .. bufnum .. ', (' .. start_row .. '/' .. line1 .. ',' .. start_col .. '), (' .. end_row .. '/' .. line2 .. ', ' .. end_col .. ')')
    if line1 and line2 and (start_row ~= line1 or end_row ~= line2) then
      -- If visual-mode selection is not the same as the range, use the range
      -- print 'V mode'
      start_row = line1
      start_col = 1
      end_row = line2
      end_col = MAX_LENGTH
    end
    if end_col >= MAX_LENGTH then
      local last_line_text = vim.api.nvim_buf_get_lines(bufnum, end_row - 1, end_row, false)[1]
      end_col = #last_line_text + 1
    end
  end

  -- nvim api is zero based
  start_row = start_row - 1
  start_col = start_col - 1
  end_row = end_row - 1
  end_col = end_col - 1

  print(
    string.format(
      "Running [%s] on lines %d-%d, cols %d-%d",
      command,
      start_row + 1,
      end_row + 1,
      start_col + 1,
      end_col + 1
    )
  )

  local selected_lines = vim.api.nvim_buf_get_text(bufnum, start_row, start_col, end_row, end_col, {})
  -- print(string.format("Selected lines: %d", #selected_lines))
  print(string.format("[%s]", table.concat(selected_lines, "] [")))

  -- Save as marks so they can move with edits
  -- nvim_buf_set_extmark({buffer}, {ns_id}, {line}, {col}, {*opts})
  local mark1 = vim.api.nvim_buf_set_extmark(bufnum, MARK_NS, start_row, start_col, {})
  local mark2 = vim.api.nvim_buf_set_extmark(bufnum, MARK_NS, end_row, end_col, {})
  local output = {}
  local job_id = vim.fn.jobstart(command, {
    on_stdout = function(_, data, _)
      output = data
    end,
    on_stderr = function(_, data, _)
      if #data > 0 then
        print(table.concat(data, "\n"))
      end
    end,
    on_exit = function(job_id, code, _)
      if code ~= 0 then
        print(string.format("[%s](%d) exited with code %d", command, job_id, code))
      else
        if ex ~= "w" then
          start_row, start_col = unpack(vim.api.nvim_buf_get_extmark_by_id(bufnum, MARK_NS, mark1, {}))
          end_row, end_col = unpack(vim.api.nvim_buf_get_extmark_by_id(bufnum, MARK_NS, mark2, {}))
          -- print("Original Changed lines " .. (end_row - start_row + 1))

          -- to avoid disrupting meantime user edits,
          -- reduce change start to the first line where the original input differs
          while start_row < end_row and selected_lines[1] == output[1] do
            table.remove(selected_lines, 1)
            table.remove(output, 1)
            start_row = start_row + 1
            start_col = 0
          end
          -- print("Reduced Changed lines " .. (end_row - start_row + 1))

          vim.api.nvim_buf_set_text(bufnum, start_row, start_col, end_row, end_col, output)
        end
      end
      vim.api.nvim_buf_del_extmark(bufnum, MARK_NS, mark1)
      vim.api.nvim_buf_del_extmark(bufnum, MARK_NS, mark2)

      if last_job_id == job_id then
        last_job_id = 0
      end
    end,
    stdout_buffered = true,
    stderr_buffered = true,
  })

  vim.fn.chansend(job_id, selected_lines)
  vim.fn.chanclose(job_id, "stdin")

  last_job_id = job_id
  print(string.format("To kill [%s]> :call jobstop(%d)", command, job_id))
end

vim.cmd [[command! -nargs=1 -range X  lua require('kiyoon.async_run').AsyncShell(<q-args>, '!', <line1>, <line2>) ]]
vim.cmd [[command! -nargs=1 -range Xr lua require('kiyoon.async_run').AsyncShell(<q-args>, 'r', <line1>, <line2>) ]]
vim.cmd [[command! -nargs=1 -range Xw lua require('kiyoon.async_run').AsyncShell(<q-args>, 'w', <line1>, <line2>) ]]
vim.cmd [[command! Xstop lua require('kiyoon.async_run').KillAsyncShell() ]]

return M
