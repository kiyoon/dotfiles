local M = {}

---@param fn function
function M.make_dot_repeatable(fn)
  _G._type_righter_last_function = fn
  vim.o.opfunc = "v:lua._type_righter_last_function"
  vim.api.nvim_feedkeys("g@l", "n", false)
end

return M
