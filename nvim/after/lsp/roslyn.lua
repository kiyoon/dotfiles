-- NOTE: roslyn LSP doesn't set diagnostic.source, so we set it here.
local default_pull = vim.lsp.handlers["textDocument/diagnostic"]

---@param err any
---@param result any
---@param ctx table
---@param config table
local function roslyn_pull_handler(err, result, ctx, config)
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  if client and client.name == "roslyn" and result and result.items then
    for _, d in ipairs(result.items) do
      if d.source == nil or d.source == "" then
        d.source = "roslyn"
      end
    end
  end
  return default_pull(err, result, ctx, config)
end

---@type vim.lsp.Config
local M = {
  settings = {
    ["csharp|background_analysis"] = {
      background_analysis = {
        dotnet_analyzer_diagnostics_scope = "fullSolution",
        dotnet_compiler_diagnostics_scope = "fullSolution",
      },
    },
    ["csharp|code_lens"] = {
      dotnet_enable_references_code_lens = true,
      dotnet_enable_tests_code_lens = true,
    },
    ["csharp|completion"] = {
      dotnet_provide_regex_completions = true,
      dotnet_show_completion_items_from_unimported_namespaces = true,
      dotnet_show_name_completion_suggestions = true,
    },
    ["csharp|inlay_hints"] = {
      csharp_enable_inlay_hints_for_implicit_object_creation = true,
      csharp_enable_inlay_hints_for_implicit_variable_types = true,
      csharp_enable_inlay_hints_for_lambda_parameter_types = true,
      csharp_enable_inlay_hints_for_types = true,

      dotnet_enable_inlay_hints_for_indexer_parameters = true,
      dotnet_enable_inlay_hints_for_literal_parameters = true,
      dotnet_enable_inlay_hints_for_object_creation_parameters = true,
      dotnet_enable_inlay_hints_for_other_parameters = true,
      dotnet_enable_inlay_hints_for_parameters = true,

      dotnet_suppress_inlay_hints_for_parameters_that_differ_only_by_suffix = true,
      dotnet_suppress_inlay_hints_for_parameters_that_match_argument_name = true,
      dotnet_suppress_inlay_hints_for_parameters_that_match_method_intent = true,
    },
    ["csharp|symbol_search"] = {
      dotnet_search_reference_assemblies = true,
    },
    ["csharp|formatting"] = {
      dotnet_organize_imports_on_format = true,
    },
  },

  -- roslyn doesn't send diagnostic.source, so we set it here.
  handlers = {
    ["textDocument/diagnostic"] = roslyn_pull_handler,
  },
}

return M
