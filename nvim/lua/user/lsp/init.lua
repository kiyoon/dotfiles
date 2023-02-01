local servers = {
  "sumneko_lua",
  "cssls",
  "html",
  "tsserver",
  "pyright",
  "bashls",
  "jsonls",
  "yamlls",
  "vimls",
  "dockerls",
  "grammarly",
  -- "rust_analyzer", -- use rust-tools.nvim instead
}

local settings = {
  ui = {
    border = "none",
    icons = {
      package_installed = "◍",
      package_pending = "◍",
      package_uninstalled = "◍",
    },
  },
  log_level = vim.log.levels.INFO,
  max_concurrent_installers = 4,
  pip = {
    -- upgrade_pip = true,
  },
}

require("mason").setup(settings)
require("mason-lspconfig").setup {
  ensure_installed = servers,
  automatic_installation = true,
}

require("neodev").setup {
  override = function(root_dir, library)
    library.enabled = true
    library.plugins = true
  end,
} -- make sure to call this before lspconfig

local lspconfig_status_ok, lspconfig = pcall(require, "lspconfig")
if not lspconfig_status_ok then
  return
end

local handlers = require "user.lsp.handlers"
handlers.setup()

for _, server in pairs(servers) do
  local opts = {
    on_attach = handlers.on_attach,
    capabilities = handlers.capabilities,
  }

  server = vim.split(server, "@", {})[1]

  local require_ok, conf_opts = pcall(require, "user.lsp.settings." .. server)
  if require_ok then
    opts = vim.tbl_deep_extend("force", conf_opts, opts)
    -- opts = conf_opts
  else
    opts = {}
  end

  lspconfig[server].setup(opts)
end
