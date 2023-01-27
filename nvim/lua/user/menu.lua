-- vim.api.nvim_cmd({ cmd = "anoremenu", args = { "PopUp.-2-", "<Nop>" } }, {})
vim.api.nvim_cmd({ cmd = "aunmenu!", args = { "PopUp.How-to\\ disable\\ mouse" } }, {})
vim.api.nvim_cmd({
  cmd = "vnoremenu",
  args = {
    "PopUp.Extract\\ Function",
    [[ <Esc><Cmd>lua require('refactoring').refactor('Extract Function')<CR>]],
  },
}, {})
vim.api.nvim_cmd({
  cmd = "vnoremenu",
  args = {
    "PopUp.Extract\\ Function\\ To\\ File",
    [[ <Esc><Cmd>lua require('refactoring').refactor('Extract Function To File')<CR>]],
  },
}, {})
vim.api.nvim_cmd({
  cmd = "vnoremenu",
  args = {
    "PopUp.Extract\\ Variable",
    [[ <Esc><Cmd>lua require('refactoring').refactor('Extract Variable')<CR>]],
  },
}, {})
vim.api.nvim_cmd({
  cmd = "vnoremenu",
  args = {
    "PopUp.Inline\\ Variable",
    [[ <Esc><Cmd>lua require('refactoring').refactor('Inline Variable')<CR>]],
  },
}, {})
