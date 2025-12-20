local M = {}

-- keep a stable operatorfunc name; update only the "last fn"
M._last = nil

_G._type_righter_opfunc = function(type)
  if M._last then
    return M._last(type)
  end
end

---@param fn fun(type: string)  -- operatorfunc gets a {type} arg
function M.make_dot_repeatable(fn)
  M._last = fn
  vim.go.operatorfunc = "v:lua._type_righter_opfunc"

  if vim.fn.mode() == "i" then
    -- run one normal command and return to insert automatically
    vim.api.nvim_feedkeys(vim.keycode("<C-o>g@l"), "n", false)
  else
    vim.api.nvim_feedkeys(vim.keycode("g@l"), "n", false)
  end
end

return M
