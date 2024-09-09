-- NOTE: in nvim 0.9.5, if you import this module at the bottom,
-- it will sometimes not work, returning `lang` instaed of `M`.
-- Super strange, likely a bug in nvim.
local lang = require("kiyoon.lang").lang

M = {
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
          -- reportUndefinedVariable = false, -- ruff handles this with F822
        },
      },
    },
  },
}

-- NOTE: pyright works with es-ES but not with es_ES. Weird.
if lang == "es" then
  M.cmd_env = { LC_ALL = "es-ES.UTF-8" }
elseif lang == "fr" then
  M.cmd_env = { LC_ALL = "fr-FR.UTF-8" }
elseif lang == "pt-BR" then
  M.cmd_env = { LC_ALL = "pt-BR.UTF-8" }
elseif lang == "pt-PT" then
  M.cmd_env = { LC_ALL = "pt-PT.UTF-8" }
end

return M
