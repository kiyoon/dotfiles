local util = require("lspconfig.util")

return {
  -- https://github.com/neovim/nvim-lspconfig/pull/2984
  -- by default, biome is active only when biome.json is configured.
  -- this changes the behavior to be active with single files.
  root_dir = function(bufnr, on_dir)
    local fname = vim.api.nvim_buf_get_name(bufnr)
    local root_files = {
      "biome.json",
      "biome.jsonc",
      -- "package.json",
      "node_modules",
      ".git",
    }
    root_files = util.insert_package_json(root_files, "biome", fname)
    local root_dir = vim.fs.dirname(vim.fs.find(root_files, { path = fname, upward = true })[1])
    on_dir(root_dir)
  end,
  single_file_support = true,
  -- workspace_required = false,
  -- settings = {},
}
