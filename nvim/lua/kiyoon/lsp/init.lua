local servers = {
  "lua_ls",
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
  -- "rust_analyzer", -- rust-tools.nvim will attach to LSP, so don't put this here
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

-- List of LSP servers to install, but not necessarily attach to
-- rust_analyzer is attached by rust-tools.nvim
local ensure_installed = { unpack(servers) }
table.insert(ensure_installed, "rust_analyzer")

-- Mason makes it easier to install language servers
-- Always load mason, mason-lspconfig and nvim-lspconfig in order.
require("mason").setup(settings)
require("mason-lspconfig").setup {
  ensure_installed = ensure_installed,
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

local handlers = require "kiyoon.lsp.handlers"
handlers.setup()

for _, server in pairs(servers) do
  local opts = {
    on_attach = handlers.on_attach,
    capabilities = handlers.capabilities,
  }

  server = vim.split(server, "@", {})[1]

  local require_ok, conf_opts = pcall(require, "kiyoon.lsp.settings." .. server)
  if require_ok then
    opts = vim.tbl_deep_extend("force", conf_opts, opts)
    -- opts = conf_opts
  else
    opts = {}
  end

  lspconfig[server].setup(opts)
end
