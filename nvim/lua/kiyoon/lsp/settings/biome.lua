local util = require("lspconfig.util")

local codes_to_ignore = {
  ["lint/correctness/noUnusedImports"] = true,
  ["lint/correctness/noUnusedVariables"] = true,
}
---@param diagnostics vim.Diagnostic[]
---@return vim.Diagnostic[]
local function filter_diagnostics(diagnostics)
  local filtered_diagnostics = {}
  for _, diagnostic in ipairs(diagnostics) do
    if not codes_to_ignore[diagnostic.code] then
      table.insert(filtered_diagnostics, diagnostic)
    end
  end
  return filtered_diagnostics
end

---@param diagnostics vim.Diagnostic[]
local function translate_and_simplify_code(diagnostics)
  local translate_biome_message = require("kiyoon.lang.biome").translate_biome_message
  for _, diagnostic in ipairs(diagnostics) do
    ---@diagnostic disable-next-line: param-type-mismatch
    diagnostic.message = translate_biome_message(diagnostic.code, diagnostic.message)

    -- code is like lint/nursery/useGoogleFontDisplay
    -- return kebab case like use-google-font-display
    -- lua match lint/\w/(\w)
    local kebab_case_code = string.match(diagnostic.code, [[lint/%w+/(%w+)]])
    -- make camel case to kebab case
    if kebab_case_code ~= nil then
      kebab_case_code = kebab_case_code:gsub("(%u)", "-%1"):lower()
      diagnostic.code = kebab_case_code
    end
  end
end

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
  handlers = {
    ["textDocument/publishDiagnostics"] = function(err, result, ctx)
      if result and result.diagnostics then
        result.diagnostics = filter_diagnostics(result.diagnostics)
        translate_and_simplify_code(result.diagnostics)
      end
      return vim.lsp.diagnostic.on_publish_diagnostics(err, result, ctx)
    end,
  },
}
