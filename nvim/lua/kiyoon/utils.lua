local M = {}

M.list_reverse = function(tab)
  for i = 1, math.floor(#tab / 2), 1 do
    tab[i], tab[#tab - i + 1] = tab[#tab - i + 1], tab[i]
  end
  return tab
end

---@param fn function
function M.make_dot_repeatable(fn)
  _G._kiyoon_dotfiles_last_function = fn
  vim.o.opfunc = "v:lua._kiyoon_dotfiles_last_function"
  vim.api.nvim_feedkeys("g@l", "n", false)
end

return M
