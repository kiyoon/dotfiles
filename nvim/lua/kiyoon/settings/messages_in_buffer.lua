-- Add :Messages command to open messages in a buffer. Useful for debugging.
-- Better than the default :messages
local function open_messages_in_buffer(args)
  if Bufnr_messages == nil or vim.fn.bufexists(Bufnr_messages) == 0 then
    -- Create a temporary buffer
    Bufnr_messages = vim.api.nvim_create_buf(false, true)
  end
  -- Create a split and open the buffer
  vim.cmd([[sb]] .. Bufnr_messages)
  -- vim.cmd "botright 10new"
  vim.bo.modifiable = true
  vim.api.nvim_buf_set_lines(Bufnr_messages, 0, -1, false, {})
  vim.cmd("put = execute('messages')")
  vim.bo.modifiable = false

  -- No need for below because we created a temporary buffer
  -- vim.bo.modified = false
end

vim.api.nvim_create_user_command("Messages", open_messages_in_buffer, {})
