return {
  -- handlers = {
  --   ["textDocument/publishDiagnostics"] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
  --     virtual_text = { spacing = 0, prefix = "" },
  --     signs = true,
  --     underline = true,
  --     update_in_insert = true,
  --   }),
  -- },
  settings = {
    -- python = {
    basedpyright = {
      analysis = {
        typeCheckingMode = "standard", -- off, basic, standard, strict, all
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        autoImportCompletions = true,
        diagnosticsMode = "openFilesOnly", -- workspace, openFilesOnly
        diagnosticSeverityOverrides = {
          reportUnusedImports = false,
          reportUnusedVariable = false,
          -- reportUnusedClass = "warning",
          -- reportUnusedFunction = "warning",
          reportUndefinedVariable = false, -- ruff handles this with F822
          reportImplicitOverride = "warning",
        },
      },
    },
  },
}
