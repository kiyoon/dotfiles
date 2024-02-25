local ls = require "luasnip"
local s = ls.snippet

local t = ls.text_node

return {
  s({ trig = "->" }, { t { "&rarr;" } }),
  s({ trig = "<-" }, { t { "&larr;" } }),
  s({ trig = "^" }, { t { "&uarr;" } }),
  s({ trig = "v" }, { t { "&darr;" } }),
}
