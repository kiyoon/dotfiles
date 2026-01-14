-- root finds bun.lock first if exists, otherwise it will use tsconfig.json
-- This is useful for monorepos where many projects share references.
-- If you don't set the root correctly, it will not find the references correctly.

local root = vim.fs.root(0, "bun.lock")
if root == nil then
  root = vim.fs.root(0, { "tsconfig.json", "jsconfig.json", "package.json", ".git" })
end

---@type vim.lsp.Config
return {
  root_dir = root,
  settings = {
    typescript = {
      updateImportsOnFileMove = "always",
      inlayHints = {
        parameterNames = { enabled = "all" }, -- "none" | "literals" | "all"
        parameterTypes = { enabled = true },
        variableTypes = { enabled = true },
        propertyDeclarationTypes = { enabled = true },
        functionLikeReturnTypes = { enabled = true },
        enumMemberValues = { enabled = true },
      },
      preferences = {
        importModuleSpecifierEnding = "auto",
      },
    },
    javascript = {
      updateImportsOnFileMove = "always",
      inlayHints = {
        parameterNames = { enabled = "all" },
        parameterTypes = { enabled = true },
        variableTypes = { enabled = true },
        propertyDeclarationTypes = { enabled = true },
        functionLikeReturnTypes = { enabled = true },
        enumMemberValues = { enabled = true },
      },
      preferences = {
        importModuleSpecifierEnding = "auto",
      },
    },
    vtsls = {
      enableMoveToFileCodeAction = true,
    },
  },
}
