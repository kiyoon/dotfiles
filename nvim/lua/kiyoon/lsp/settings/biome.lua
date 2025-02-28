M = {
  -- https://github.com/neovim/nvim-lspconfig/pull/2984
  -- by default, biome is active only when biome.json is configured.
  -- this changes the behavior to be active with single files.
  root_dir = function(fname)
    return vim.fs.dirname(vim.fs.find({
      "biome.json",
      "biome.jsonc",
      "package.json",
      "node_modules",
      ".git",
    }, { path = fname, upward = true })[1])
  end,
  single_file_support = true,
  -- settings = {},
}

return M
