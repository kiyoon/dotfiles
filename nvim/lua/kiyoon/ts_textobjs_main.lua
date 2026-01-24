local function treesitter_selection_mode(info)
  -- * query_string: eg '@function.inner'
  -- * method: eg 'v' or 'o'
  --print(info['method'])		-- visual, operator-pending
  -- if vim.startswith(info["query_string"], "@function.") then
  --   return "V"
  -- end
  if vim.startswith(info["query_string"], "@class.") then
    return "V"
  end
  return "v"
end

local function treesitter_incwhitespaces(info)
  -- * query_string: eg '@function.inner'
  -- * selection_mode: eg 'charwise', 'linewise', 'blockwise'
  -- if vim.startswith(info['query_string'], '@function.') then
  --  return false
  -- elseif vim.startswith(info['query_string'], '@comment.') then
  --  return false
  -- end
  return false
end

require("nvim-treesitter-textobjects").setup({
  select = {
    -- Automatically jump forward to textobj, similar to targets.vim
    lookahead = true,
    -- You can choose the select mode (default is charwise 'v')
    --
    -- Can also be a function which gets passed a table with the keys
    -- * query_string: eg '@function.inner'
    -- * method: eg 'v' or 'o'
    -- and should return the mode ('v', 'V', or '<c-v>') or a table
    -- mapping query_strings to modes.
    -- selection_modes = {
    --   ["@parameter.outer"] = "v", -- charwise
    --   ["@function.outer"] = "V", -- linewise
    --   ["@class.outer"] = "<c-v>", -- blockwise
    -- },
    selection_modes = treesitter_selection_mode,
    -- If you set this to `true` (default is `false`) then any textobject is
    -- extended to include preceding or succeeding whitespace. Succeeding
    -- whitespace has priority in order to act similarly to eg the built-in
    -- `ap`.
    --
    -- Can also be a function which gets passed a table with the keys
    -- * query_string: eg '@function.inner'
    -- * selection_mode: eg 'v'
    -- and should return true of false
    include_surrounding_whitespace = treesitter_incwhitespaces,
  },
  move = {
    -- whether to set jumps in the jumplist
    set_jumps = true,
  },
})

-- ─────────────────────────────────────────────
--  SELECT TEXTOBJECTS
-- ─────────────────────────────────────────────
local select = require("nvim-treesitter-textobjects.select")

local select_keymaps = {
  am = "@function.outer",
  im = "@function.inner",
  al = "@class.outer",
  il = "@class.inner",
  ab = "@block.outer",
  ib = "@block.inner",
  ad = "@conditional.outer",
  id = "@conditional.inner",
  ao = "@loop.outer",
  io = "@loop.inner",
  aa = "@parameter.outer",
  ia = "@parameter.inner",
  af = "@call.outer",
  ["if"] = "@call.inner",
  ["a/"] = "@comment.outer",
  ["in"] = "@number.inner",
  ag = "@assignment.outer",
  ig = "@assignment.inner",
  ik = "@assignment.lhs",
  iv = "@assignment.rhs",
  aA = "@attribute.outer",
  iA = "@attribute.inner",
  as = { query = "@scope", query_group = "locals" },
  is = "@statement.outer",
  aS = "@toplevel",
  ar = { query = "@start", query_group = "aerial" },
}

for lhs, query in pairs(select_keymaps) do
  vim.keymap.set({ "x", "o" }, lhs, function()
    local qstring, qgroup
    if type(query) == "table" then
      qstring = query.query
      qgroup = query.query_group
    else
      qstring = query
      qgroup = nil
    end

    select.select_textobject(qstring, qgroup)
  end, { desc = string.format("Select %s", type(query) == "table" and query.query or query) })
end

-- ─────────────────────────────────────────────
--  SWAP TEXT OBJECTS
-- ─────────────────────────────────────────────
local swap = require("nvim-treesitter-textobjects.swap")

local swap_next = {
  [")m"] = "@function.outer",
  [")c"] = "@comment.outer",
  [")a"] = "@parameter.inner",
  [")b"] = "@block.outer",
  [")l"] = "@class.outer",
  [")s"] = "@statement.outer",
  [")A"] = "@attribute.outer",
}
local swap_prev = {
  ["(m"] = "@function.outer",
  ["(c"] = "@comment.outer",
  ["(a"] = "@parameter.inner",
  ["(b"] = "@block.outer",
  ["(l"] = "@class.outer",
  ["(s"] = "@statement.outer",
  ["(A"] = "@attribute.outer",
}

for lhs, query in pairs(swap_next) do
  vim.keymap.set("n", lhs, function()
    swap.swap_next(query)
  end, { desc = string.format("Swap next %s", query) })
end

for lhs, query in pairs(swap_prev) do
  vim.keymap.set("n", lhs, function()
    swap.swap_previous(query)
  end, { desc = string.format("Swap previous %s", query) })
end

-- ─────────────────────────────────────────────
--  MOVE TEXT OBJECTS
-- ─────────────────────────────────────────────
local move = require("nvim-treesitter-textobjects.move")

local move_next_start = {
  ["]m"] = "@function.outer",
  ["]f"] = "@call.outer",
  ["]d"] = "@conditional.outer",
  ["]o"] = "@loop.outer",
  ["]s"] = "@statement.outer",
  ["]a"] = "@parameter.outer",
  ["]c"] = "@comment.outer",
  ["]b"] = "@block.outer",
  ["]n"] = "@number.inner",
  ["]g"] = "@assignment.inner",
  ["]k"] = "@assignment.lhs",
  ["]v"] = "@assignment.rhs",
  ["]l"] = "@class.outer",
  ["]]m"] = "@function.inner",
  ["]]f"] = "@call.inner",
  ["]]d"] = "@conditional.inner",
  ["]]o"] = "@loop.inner",
  ["]]a"] = "@parameter.inner",
  ["]]b"] = "@block.inner",
  ["]]l"] = "@class.inner",
}

local move_next_end = {
  ["]M"] = "@function.outer",
  ["]F"] = "@call.outer",
  ["]D"] = "@conditional.outer",
  ["]O"] = "@loop.outer",
  ["]S"] = "@statement.outer",
  ["]A"] = "@parameter.outer",
  ["]C"] = "@comment.outer",
  ["]B"] = "@block.outer",
  ["]L"] = "@class.outer",
  ["]N"] = "@number.inner",
  ["]G"] = "@assignment.inner",
  ["]K"] = "@assignment.lhs",
  ["]V"] = "@assignment.rhs",
  ["]]M"] = "@function.inner",
  ["]]F"] = "@call.inner",
  ["]]D"] = "@conditional.inner",
  ["]]O"] = "@loop.inner",
  ["]]A"] = "@parameter.inner",
  ["]]B"] = "@block.inner",
  ["]]L"] = "@class.inner",
}

local move_prev_start = {
  ["[m"] = "@function.outer",
  ["[f"] = "@call.outer",
  ["[d"] = "@conditional.outer",
  ["[o"] = "@loop.outer",
  ["[s"] = "@statement.outer",
  ["[a"] = "@parameter.outer",
  ["[c"] = "@comment.outer",
  ["[b"] = "@block.outer",
  ["[l"] = "@class.outer",
  ["[n"] = "@number.inner",
  ["[g"] = "@assignment.inner",
  ["[k"] = "@assignment.lhs",
  ["[v"] = "@assignment.rhs",
  ["[[m"] = "@function.inner",
  ["[[f"] = "@call.inner",
  ["[[d"] = "@conditional.inner",
  ["[[o"] = "@loop.inner",
  ["[[a"] = "@parameter.inner",
  ["[[b"] = "@block.inner",
  ["[[l"] = "@class.inner",
}

local move_prev_end = {
  ["[M"] = "@function.outer",
  ["[F"] = "@call.outer",
  ["[D"] = "@conditional.outer",
  ["[O"] = "@loop.outer",
  ["[S"] = "@statement.outer",
  ["[A"] = "@parameter.outer",
  ["[C"] = "@comment.outer",
  ["[B"] = "@block.outer",
  ["[L"] = "@class.outer",
  ["[N"] = "@number.inner",
  ["[G"] = "@assignment.inner",
  ["[K"] = "@assignment.lhs",
  ["[V"] = "@assignment.rhs",
  ["[[M"] = "@function.inner",
  ["[[F"] = "@call.inner",
  ["[[D"] = "@conditional.inner",
  ["[[O"] = "@loop.inner",
  ["[[A"] = "@parameter.inner",
  ["[[B"] = "@block.inner",
  ["[[L"] = "@class.inner",
}

for lhs, query in pairs(move_next_start) do
  vim.keymap.set({ "n", "x", "o" }, lhs, function()
    move.goto_next_start(query)
  end, { desc = string.format("Next %s start", query) })
end

for lhs, query in pairs(move_next_end) do
  vim.keymap.set({ "n", "x", "o" }, lhs, function()
    move.goto_next_end(query)
  end, { desc = string.format("Next %s end", query) })
end

for lhs, query in pairs(move_prev_start) do
  vim.keymap.set({ "n", "x", "o" }, lhs, function()
    move.goto_previous_start(query)
  end, { desc = string.format("Previous %s start", query) })
end

for lhs, query in pairs(move_prev_end) do
  vim.keymap.set({ "n", "x", "o" }, lhs, function()
    move.goto_previous_end(query)
  end, { desc = string.format("Previous %s end", query) })
end

-- ─────────────────────────────────────────────
--  REPEATABLE MOVES
-- ─────────────────────────────────────────────
local ts_repeat_move = require("nvim-treesitter-textobjects.repeatable_move")

-- Repeat movement with ; and ,
-- ensure ; goes forward and , goes backward regardless of the last direction
vim.keymap.set({ "n", "x", "o" }, ";", ts_repeat_move.repeat_last_move_next)
vim.keymap.set({ "n", "x", "o" }, ",", ts_repeat_move.repeat_last_move_previous)

-- vim way: ; goes to the direction you were moving.
-- vim.keymap.set({ "n", "x", "o" }, ";", ts_repeat_move.repeat_last_move)
-- vim.keymap.set({ "n", "x", "o" }, ",", ts_repeat_move.repeat_last_move_opposite)

-- Optionally, make builtin f, F, t, T also repeatable with ; and ,
vim.keymap.set({ "n", "x", "o" }, "f", ts_repeat_move.builtin_f_expr, { expr = true })
vim.keymap.set({ "n", "x", "o" }, "F", ts_repeat_move.builtin_F_expr, { expr = true })
vim.keymap.set({ "n", "x", "o" }, "t", ts_repeat_move.builtin_t_expr, { expr = true })
vim.keymap.set({ "n", "x", "o" }, "T", ts_repeat_move.builtin_T_expr, { expr = true })

vim.keymap.set({ "n", "x", "o" }, "<home>", function()
  ts_repeat_move.repeat_last_move({ forward = false, start = true })
end)
vim.keymap.set({ "n", "x", "o" }, "<end>", function()
  ts_repeat_move.repeat_last_move({ forward = true, start = false })
end)
