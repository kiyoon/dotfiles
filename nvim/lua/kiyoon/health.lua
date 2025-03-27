local M = {}

function M.check()
  vim.health.start("kiyoon/dotfiles")

  if vim.fn.has("nvim-0.11.0") == 1 then
    vim.health.ok("Using Neovim >= 0.11.0")
  else
    vim.health.error("Neovim >= 0.11.0 is required")
  end

  for _, cmd in ipairs({ "git", "rg", "fd" }) do
    if vim.fn.executable(cmd) == 1 then
      vim.health.ok(("`%s` is installed"):format(cmd))
    else
      vim.health.warn(("`%s` is not installed"):format(cmd))
    end
  end
end

return M
