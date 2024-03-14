local servers_use_formatting = {
  -- "lua_ls",
  -- "ruff_lsp",
}

local M = {}

local status_cmp_ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
local icons = require "kiyoon.icons"

if status_cmp_ok then
  M.capabilities = vim.lsp.protocol.make_client_capabilities()
  M.capabilities.textDocument.completion.completionItem.snippetSupport = true
  M.capabilities = cmp_nvim_lsp.default_capabilities(M.capabilities)
end

M.setup = function()
  local signs = {

    { name = "DiagnosticSignError", text = icons.diagnostics.Error },
    { name = "DiagnosticSignWarn", text = icons.diagnostics.Warn },
    { name = "DiagnosticSignHint", text = icons.diagnostics.Hint },
    { name = "DiagnosticSignInfo", text = icons.diagnostics.Info },
  }

  for _, sign in ipairs(signs) do
    vim.fn.sign_define(sign.name, { texthl = sign.name, text = sign.text, numhl = "" })
  end

  local config = {
    -- virtual_text = true,
    virtual_text = { spacing = 3, prefix = "" },
    signs = {
      active = signs, -- show signs
    },
    update_in_insert = true,
    underline = true,
    -- This will cover the DAP breakpoints
    -- severity_sort = true,
    float = {
      focusable = true,
      style = "minimal",
      border = "rounded",
      source = "always",
      header = "",
      prefix = "",
    },
  }

  vim.diagnostic.config(config)

  vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, {
    border = "rounded",
  })

  vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, {
    border = "rounded",
  })

  -- vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
  --   -- virtual_text = true,
  --   virtual_text = { spacing = 0, prefix = "" },
  --   signs = true,
  --   underline = true,
  --   update_in_insert = true,
  -- })
end

function M.lsp_keymaps(bufnr)
  local opts = { noremap = true, silent = true, buffer = bufnr }
  local keymap = function(mode, lhs, rhs, opts_, desc)
    opts_.desc = desc
    return vim.keymap.set(mode, lhs, rhs, opts_)
  end
  keymap("n", "gD", vim.lsp.buf.declaration, opts, "[G]o to [D]eclaration")
  keymap("n", "gd", vim.lsp.buf.definition, opts, "[G]o to [D]efinition")
  keymap("n", "K", vim.lsp.buf.hover, opts, "LSP hover")
  keymap("n", "gI", vim.lsp.buf.implementation, opts, "[G]o to [I]mplementation")
  keymap("n", "gr", vim.lsp.buf.references, opts, "[G]o to [R]eferences")
  keymap("n", "gl", function()
    local source_to_icon = {
      rustc = "🦀",
      ["rust-analyzer"] = "🦀",
      clippy = "🦀cl",
      ruff = "🐍",
      shellcheck = "🐚",
      tsserver = "🌐",
    }
    vim.diagnostic.open_float {
      format = function(diagnostic)
        -- if diagnostic.user_data ~= nil then
        --   vim.print(diagnostic.user_data)
        -- end
        local message
        if diagnostic.source == "clippy" then
          -- remove "for further information visit https://rust-lang.github.io/rust-clippy/...." from the message
          -- match line break at the end
          message = diagnostic.message:gsub(
            "for further information visit https://rust%-lang%.github%.io/rust%-clippy/.*\n",
            ""
          )
        else
          message = diagnostic.message
        end

        if source_to_icon[diagnostic.source] ~= nil then
          return string.format("%s 🔗%s", message, source_to_icon[diagnostic.source])
        end

        return string.format("%s 🔗%s", message, diagnostic.source)
      end,
    }
  end, opts, "Show Diagnostics")
  keymap("n", "<space>pi", "<cmd>LspInfo<cr>", opts)
  keymap("n", "<space>pI", "<cmd>LspInstallInfo<cr>", opts)
  -- Use actions-preview.nvim
  -- keymap("n", "<space>pa", vim.lsp.buf.code_action, opts, "Code [A]ction")
  keymap({ "n", "x", "o", "i" }, "<A-l>", "<cmd>lua vim.diagnostic.goto_next({buffer=0})<cr>", opts)
  keymap({ "n", "x", "o", "i" }, "<A-h>", "<cmd>lua vim.diagnostic.goto_prev({buffer=0})<cr>", opts)

  local next_warn = function()
    vim.diagnostic.goto_next { severity = vim.diagnostic.severity.WARNING }
  end
  local prev_warn = function()
    vim.diagnostic.goto_prev { severity = vim.diagnostic.severity.WARNING }
  end
  local next_err = function()
    vim.diagnostic.goto_next { severity = vim.diagnostic.severity.ERROR }
  end
  local prev_err = function()
    vim.diagnostic.goto_prev { severity = vim.diagnostic.severity.ERROR }
  end
  local status, tsrepeat = pcall(require, "nvim-treesitter.textobjects.repeatable_move")
  if status then
    next_warn, prev_warn = tsrepeat.make_repeatable_move_pair(next_warn, prev_warn)
    next_err, prev_err = tsrepeat.make_repeatable_move_pair(next_err, prev_err)
  end

  keymap({ "n", "x", "o" }, "[w", prev_warn, opts, "Previous [W]arning")
  keymap({ "n", "x", "o" }, "]w", next_warn, opts, "Next [W]arning")
  keymap({ "n", "x", "o" }, "[e", prev_err, opts, "Previous [E]rror")
  keymap({ "n", "x", "o" }, "]e", next_err, opts, "Next [E]rror")

  -- keymap("n", "<space>pr", "<cmd>lua vim.lsp.buf.rename()<cr>", opts)
  keymap("n", "<space>ps", vim.lsp.buf.signature_help, opts, "[S]ignature Help")
  -- keymap("i", "<C-h>", vim.lsp.buf.signature_help, opts, "Signature [H]elp")
  keymap("n", "<space>pq", vim.diagnostic.setqflist, opts, "Set [Q]uickfix List")

  if vim.bo.filetype == "python" then
    keymap("n", "<space>po", "<cmd>PyrightOrganizeImports<cr>", opts, "[O]rganise Imports (python)")
  end
end

M.on_attach = function(client, bufnr)
  -- Disable LSP formatting for most servers
  -- LSP is slow to initialise, and using their formatting can result in reverting the changes.
  -- Annoying especially when you format on save, and save a document very quick before the LSP is initialised.
  client.server_capabilities.documentFormattingProvider = false
  for _, server in pairs(servers_use_formatting) do
    if client.name == server then
      client.server_capabilities.documentFormattingProvider = true
      break
    end
  end

  M.lsp_keymaps(bufnr)
end

return M
