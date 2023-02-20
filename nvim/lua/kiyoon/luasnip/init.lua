require("luasnip.loaders.from_vscode").lazy_load()

require "kiyoon.luasnip.lua"

local ls = require "luasnip"
local types = require "luasnip.util.types"

ls.config.set_config {
  history = true,
  updateevents = "TextChanged,TextChangedI",
  enable_autosnippets = true,
  ext_opts = {
    [types.choiceNode] = {
      active = {
        -- virt_text = {{"", "Comment"}},
        virt_text = { { "", "Error" } },
      },
    },
  },
}

vim.keymap.set({ "i", "s" }, "<A-j>", function()
  if ls.expand_or_jumpable() then
    ls.expand_or_jump()
  end
end, { silent = true })

vim.keymap.set({ "i", "s" }, "<A-k>", function()
  if ls.jumpable(-1) then
    ls.jump(-1)
  end
end, { silent = true })

vim.keymap.set({ "i", "s" }, "<A-l>", function()
  if ls.choice_active() then
    ls.change_choice(1)
  end
end, { silent = true })

local s = ls.snippet
local func_node = ls.function_node

local t = ls.text_node
local i = ls.insert_node

local date = function()
  return { os.date "%Y-%m-%d" }
end

-- Autopairs from https://github.com/L3MON4D3/Dotfiles/blob/1214ff2bbb567fa8bdd04a21976a1a64ae931330/.config/nvim/luasnippets/all.lua
local function neg(fn, ...)
  return not fn(...)
end

local function even_count(c)
  local line = vim.api.nvim_get_current_line()
  local _, ct = string.gsub(line, c, "")
  return ct % 2 == 0
end

local function part(func, ...)
  local args = { ... }
  return function()
    return func(unpack(args))
  end
end

local function char_count_same(c1, c2)
  local line = vim.api.nvim_get_current_line()
  local _, ct1 = string.gsub(line, "%" .. c1, "")
  local _, ct2 = string.gsub(line, "%" .. c2, "")
  return ct1 == ct2
end

local function pair(pair_begin, pair_end, expand_func, ...)
  return s(
    { trig = pair_begin, wordTrig = false },
    { t { pair_begin }, i(1), t { pair_end } },
    { condition = part(expand_func, part(..., pair_begin, pair_end)) }
  )
end

-- Same as pair, but with a comma after the closing pair
local function pair_comma(pair_begin, pair_end, expand_func, ...)
  return s(
    { trig = pair_begin .. ",", wordTrig = false },
    { t { pair_begin }, i(1), t { pair_end .. "," } },
    { condition = part(expand_func, part(..., pair_begin, pair_end)) }
  )
end

ls.add_snippets(nil, {
  all = {
    s({
      trig = "date",
      namr = "Date",
      dscr = "Date in the form of YYYY-MM-DD",
    }, {
      func_node(date, {}),
    }),
    -- Autopairs
    pair("(", ")", neg, char_count_same),
    pair_comma("(", ")", neg, char_count_same),
    pair("{", "}", neg, char_count_same),
    pair_comma("{", "}", neg, char_count_same),
    pair("[", "]", neg, char_count_same),
    pair_comma("[", "]", neg, char_count_same),
    pair("<", ">", neg, char_count_same),
    pair_comma("<", ">", neg, char_count_same),
    pair("'", "'", neg, even_count),
    pair_comma("'", "'", neg, even_count),
    pair('"', '"', neg, even_count),
    pair_comma('"', '"', neg, even_count),
    pair("`", "`", neg, even_count),
    pair_comma("`", "`", neg, even_count),
    s({ trig = "{}", wordTrig = false, hidden = true }, { t { "{", "\t" }, i(1), t { "", "}" } }),
    s({ trig = "{},", wordTrig = false, hidden = true }, { t { "{", "\t" }, i(1), t { "", "}," } }),
    s({ trig = "()", wordTrig = false, hidden = true }, { t { "(", "\t" }, i(1), t { "", ")" } }),
    s({ trig = "(),", wordTrig = false, hidden = true }, { t { "(", "\t" }, i(1), t { "", ")," } }),
  },
})
