local M = {}

---Register a global internal keymap that wraps `rhs` to be repeatable.
---@param mode string|table keymap mode, see vim.keymap.set()
---@param lhs string lhs of the internal keymap to be created, should be in the form `<Plug>(...)`
---@param rhs string|function rhs of the keymap, see vim.keymap.set()
---@return string The name of a registered internal `<Plug>(name)` keymap. Make sure you use { remap = true }.
M.make_repeatable_keymap = function(mode, lhs, rhs)
  vim.validate({
    mode = { mode, { "string", "table" } },
    rhs = { rhs, { "string", "function" }, lhs = { name = "string" } },
  })
  if not vim.startswith(lhs, "<Plug>") then
    error("`lhs` should start with `<Plug>`, given: " .. lhs)
  end
  if type(rhs) == "string" then
    vim.keymap.set(mode, lhs, function()
      vim.fn["repeat#set"](vim.api.nvim_replace_termcodes(lhs, true, true, true))
      return rhs
    end, { buffer = false, expr = true })
  else
    vim.keymap.set(mode, lhs, function()
      rhs()
      vim.fn["repeat#set"](vim.api.nvim_replace_termcodes(lhs, true, true, true))
    end, { buffer = false })
  end
  return lhs
end

return M
