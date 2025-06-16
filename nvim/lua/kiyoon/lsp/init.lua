local notify = require("kiyoon.notify").notify

local servers = {
  "lua_ls",
  "html",
  "cssls",
  "tailwindcss",
  "ts_ls",
  -- "eslint",
  "jsonls",
  "biome",
  "basedpyright",
  -- "ty",
  -- "ruff_lsp",
  "bashls",
  "yamlls",
  "vimls",
  "dockerls",
  -- "grammarly",
  -- "rust_analyzer", -- rust-tools.nvim will attach to LSP, so don't put this here
}

local servers_attach_only = {
  -- "ty",
  -- "pyrefly",
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
require("mason-lspconfig").setup({
  automatic_enable = false,
  ensure_installed = ensure_installed,
  automatic_installation = true,
})

local function install_pkg_background(pkg_name)
  local installed_pkgs = require("mason-registry").get_installed_package_names()
  if not vim.tbl_contains(installed_pkgs, pkg_name) then
    -- Code from mason-lspconfig.nvim/install.lua
    -- Install in the background, unlike the following line:
    -- require("mason.api.command").MasonInstall { "shellcheck" }

    local pkg = require("mason-registry").get_package(pkg_name)
    pkg:install():once(
      "closed",
      vim.schedule_wrap(function()
        if pkg:is_installed() then
          notify(
            ("%s was successfully installed using Mason."):format(pkg_name),
            vim.log.levels.INFO,
            { title = "kiyoon/dotfiles" }
          )
        else
          notify(
            ("Failed to install %s. Installation logs are available in :Mason and :MasonLog"):format(pkg_name),
            vim.log.levels.ERROR,
            { title = "kiyoon/dotfiles" }
          )
        end
      end)
    )
  end
end

-- bashls needs shellcheck, but it's not a server. Thus it's available on mason but not mason-lspconfig's ensure_installed
install_pkg_background("shellcheck")
install_pkg_background("actionlint")
-- install_pkg_background("selene")

-- local lspconfig = require("lspconfig")
local handlers = require("kiyoon.lsp.handlers")
handlers.setup()

-- expand servers to include servers_attach_only
for _, server in pairs(servers_attach_only) do
  if not vim.tbl_contains(servers, server) then
    table.insert(servers, server)
  end
end
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
  end

  -- lspconfig[server].setup(opts)
  vim.lsp.enable(server)
  vim.lsp.config(server, opts)
end

local status, wk = pcall(require, "which-key")
if status then
  wk.add({
    { "<space>p", group = "LS[P] (language server)" },
  })
end
