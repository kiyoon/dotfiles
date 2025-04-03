local M = {}

M.list_reverse = function(tab)
  for i = 1, math.floor(#tab / 2), 1 do
    tab[i], tab[#tab - i + 1] = tab[#tab - i + 1], tab[i]
  end
  return tab
end

return M
