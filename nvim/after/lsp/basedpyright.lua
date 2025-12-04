---@type vim.lsp.Config
local M = {
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

-- Decide how to run basedpyright-langserver:
-- 1. globally-installed basedpyright-langserver
-- 2. uvx
-- 3. bun x
-- 4. npx
local function get_basedpyright_cmd()
  local executable = vim.fn.executable

  if executable("basedpyright-langserver") == 1 then
    return { "basedpyright-langserver", "--stdio" }
  end

  -- 2. uvx / uv (PyPI-based)
  if executable("uvx") == 1 then
    -- uvx is sugar for `uv tool run`
    return { "uvx", "--from", "basedpyright", "basedpyright-langserver", "--stdio" }
  elseif executable("uv") == 1 then
    -- explicit form: `uv tool run --from basedpyright basedpyright-langserver -- --stdio`
    return {
      "uv",
      "tool",
      "run",
      "--from",
      "basedpyright",
      "basedpyright-langserver",
      "--",
      "--stdio",
    }
  end

  -- 3. bun x / npx (npm-based)
  if executable("bun") == 1 then
    -- bun x == bunx, both are fine
    -- but if you installed with winget, only bun works and bunx is not found
    return { "bun", "x", "basedpyright-langserver", "--stdio" }
  elseif executable("npx") == 1 then
    return { "npx", "basedpyright-langserver", "--stdio" }
  end

  -- Last-resort fallback (will just fail loudly if nothing exists)
  return { "basedpyright-langserver", "--stdio" }
end

M.cmd = get_basedpyright_cmd()

-- NOTE: pyright works with es-ES but not with es_ES. Weird.
-- but this is fixed in basedpyright.

-- if lang == "es" then
--   M.cmd_env = { LC_ALL = "es-ES.UTF-8" }
-- elseif lang == "fr" then
--   M.cmd_env = { LC_ALL = "fr-FR.UTF-8" }
-- elseif lang == "pt-br" then
--   M.cmd_env = { LC_ALL = "pt-br.UTF-8" }
-- elseif lang == "pt-pt" then
--   M.cmd_env = { LC_ALL = "pt-pt.UTF-8" }
-- end

return M
