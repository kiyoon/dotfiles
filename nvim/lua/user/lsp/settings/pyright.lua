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
    python = {
      analysis = {
        typeCheckingMode = "basic", -- off, basic, strict
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
        autoImportCompletions = true,
        diagnosticsMode = "openFilesOnly", -- workspace, openFilesOnly
      },
    },
  },
}
