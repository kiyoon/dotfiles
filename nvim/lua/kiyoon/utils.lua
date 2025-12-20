local M = {}

M.list_reverse = function(tab)
  for i = 1, math.floor(#tab / 2), 1 do
    tab[i], tab[#tab - i + 1] = tab[#tab - i + 1], tab[i]
  end
  return tab
end

-- keep a stable operatorfunc name; update only the "last fn"
M._last = nil

_G._kiyoon_dotfiles_opfunc = function(type)
  if M._last then
    return M._last(type)
  end
end

---@param fn fun(type: string)  -- operatorfunc gets a {type} arg
function M.make_dot_repeatable(fn)
  M._last = fn
  vim.go.operatorfunc = "v:lua._kiyoon_dotfiles_opfunc"

  if vim.fn.mode() == "i" then
    -- run one normal command and return to insert automatically
    vim.api.nvim_feedkeys(vim.keycode("<C-o>g@l"), "n", false)
  else
    vim.api.nvim_feedkeys(vim.keycode("g@l"), "n", false)
  end
end

return M
