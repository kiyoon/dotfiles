local codes_to_ignore = {
  -- ["lint/correctness/noUnusedImports"] = true,
  -- ["lint/correctness/noUnusedVariables"] = true,
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
  local translate_message = require("kiyoon.lang.ty").translate_ty_message
  for _, diagnostic in ipairs(diagnostics) do
    ---@diagnostic disable-next-line: param-type-mismatch
    diagnostic.message = translate_message(diagnostic.code, diagnostic.message)
  end
end

return {
  cmd = { "pyrefly", "lsp" },
  filetypes = { "python" },
  root_markers = {
    "pyproject.toml",
    "setup.py",
    "setup.cfg",
    "requirements.txt",
    "Pipfile",
    "pyrightconfig.json",
    ".git",
  },
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
