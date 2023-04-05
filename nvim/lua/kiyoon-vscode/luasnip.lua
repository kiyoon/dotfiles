require("luasnip.loaders.from_lua").lazy_load() -- Load snippets from ~/.config/nvim/luasnippets
require("luasnip.loaders.from_vscode").lazy_load()

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

vim.keymap.set({ "i", "s" }, "<C-j>", function()
  if ls.expand_or_jumpable() then
    ls.expand_or_jump()
  end
end, { silent = true })

vim.keymap.set({ "i", "s" }, "<C-h>", function()
  if ls.jumpable(-1) then
    ls.jump(-1)
  end
end, { silent = true })

vim.keymap.set({ "i", "s" }, "<C-l>", function()
  if ls.choice_active() then
    ls.change_choice(1)
  end
end, { silent = true })

vim.keymap.set({ "i", "s" }, "<C-u>", function()
  if ls.choice_active() then
    require "luasnip.extras.select_choice"()
  end
end, { silent = true })
