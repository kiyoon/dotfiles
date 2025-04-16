return {
  -- https://github.com/neovim/nvim-lspconfig/pull/2984
  -- by default, biome is active only when biome.json is configured.
  -- this changes the behavior to be active with single files.
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
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
