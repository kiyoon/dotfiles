M = {}

-- diagnostic float options used for vim.diagnostic.open_float, vim.diagnostic.goto_next, vim.diagnostic.goto_prev
-- adds URL to lint errors
local source_to_icon = {
  rustc = "🦀",
  ["rust-analyzer"] = "🦀",
  clippy = "🦀cl",
  ruff = "🐍",
  basedpyright = "🐍b",
  shellcheck = "🐚",
  tsserver = "🌐",
  ["Lua Syntax Check."] = "🌜s",
  ["Lua Diagnostics."] = "🌜d",
}

local float_opts = {
  format = function(diagnostic)
    -- if diagnostic.user_data ~= nil then
    --   vim.print(diagnostic.user_data)
    -- end
    local message
    if diagnostic.source == "clippy" then
      -- remove "for further information visit https://rust-lang.github.io/rust-clippy/...." from the message
      -- match line break at the end
      message =
        diagnostic.message:gsub("for further information visit https://rust%-lang%.github%.io/rust%-clippy/.*\n", "")
    else
      message = diagnostic.message
    end

    if source_to_icon[diagnostic.source] ~= nil then
      return string.format("%s 🔗%s", message, source_to_icon[diagnostic.source])
    end

    return string.format("%s 🔗%s", message, diagnostic.source)
  end,
}

function M.open_float()
  vim.diagnostic.open_float(float_opts)
end

function M.goto_next(opts)
  if opts.float == nil then
    opts.float = float_opts
  end
  vim.diagnostic.goto_next(opts)
end

function M.goto_prev(opts)
  if opts.float == nil then
    opts.float = float_opts
  end
  vim.diagnostic.goto_prev(opts)
end

return M
