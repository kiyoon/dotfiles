local M = {}

-- Alternative:
-- Get a movement function pair (forward, backward) and turn them into two repeatable movement functions
-- They don't need to have the first argument as a table of options
local tstext_repeat_move = require("nvim-treesitter-textobjects.repeatable_move")

-- move_fn's first argument must be a table of options, and it should include a `forward` boolean
-- indicating whether to move forward (true) or backward (false)
local set_last_move = function(move_fn, opts, ...)
  if type(move_fn) ~= "function" then
    vim.notify(
      "nvim-treesitter-textobjects: move_fn has to be a function but got " .. vim.inspect(move_fn),
      vim.log.levels.ERROR
    )
    return false
  end

  if type(opts) ~= "table" then
    vim.notify(
      "nvim-treesitter-textobjects: opts has to be a table but got " .. vim.inspect(opts),
      vim.log.levels.ERROR
    )
    return false
  elseif opts.forward == nil then
    vim.notify(
      "nvim-treesitter-textobjects: opts has to include a `forward` boolean but got " .. vim.inspect(opts),
      vim.log.levels.ERROR
    )
    return false
  end

  tstext_repeat_move.last_move = { func = move_fn, opts = vim.deepcopy(opts), additional_args = { ... } }
  return true
end

M.make_repeatable_move_pair = function(forward_move_fn, backward_move_fn)
  local general_repeatable_move_fn = function(opts, ...)
    if opts.forward then
      forward_move_fn(...)
    else
      backward_move_fn(...)
    end
  end

  local repeatable_forward_move_fn = function(...)
    set_last_move(general_repeatable_move_fn, { forward = true }, ...)
    forward_move_fn(...)
  end

  local repeatable_backward_move_fn = function(...)
    set_last_move(general_repeatable_move_fn, { forward = false }, ...)
    backward_move_fn(...)
  end

  return repeatable_forward_move_fn, repeatable_backward_move_fn
end

return M
