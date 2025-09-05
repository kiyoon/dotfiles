vim.g.Illuminate_ftblacklist = { "alpha", "NvimTree" }
vim.api.nvim_set_keymap("n", "<space>v", '<cmd>lua require"illuminate".textobj_select()<cr>', { noremap = true })

require("illuminate").configure({
  providers = {
    "treesitter",
    "regex",
    "lsp", -- lsp provider has incorrect handling of multibyte characters
  },
  delay = 200,
  filetypes_denylist = {
    "dirvish",
    "fugitive",
    "alpha",
    "NvimTree",
    "packer",
    "neogitstatus",
    "Trouble",
    "lir",
    "Outline",
    "spectre_panel",
    "toggleterm",
    "DressingSelect",
    "TelescopePrompt",
  },
  filetypes_allowlist = {},
  modes_denylist = {},
  modes_allowlist = {},
  providers_regex_syntax_denylist = {},
  providers_regex_syntax_allowlist = {},
  under_cursor = true,
})
