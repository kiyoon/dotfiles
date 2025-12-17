local M = {}

---@class Range4
---@field srow integer
---@field scol integer
---@field erow integer
---@field ecol integer

local function range4(srow, scol, erow, ecol)
  return { srow = srow, scol = scol, erow = erow, ecol = ecol }
end

local function from_node(node)
  local srow, scol, erow, ecol = node:range()
  return range4(srow, scol, erow, ecol)
end

local function contains(r, row0, col0)
  if row0 < r.srow or row0 > r.erow then
    return false
  end
  if row0 == r.srow and col0 < r.scol then
    return false
  end
  if row0 == r.erow and col0 > r.ecol then
    return false
  end
  return true
end

local function expand_whitespace(bufnr, r)
  -- expand left on start row
  do
    local line = (vim.api.nvim_buf_get_lines(bufnr, r.srow, r.srow + 1, false)[1] or "")
    local col = r.scol
    while col > 0 do
      local ch = line:sub(col, col)
      if ch:match("%s") then
        col = col - 1
      else
        break
      end
    end
    if col < r.scol then
      local ch = line:sub(col + 1, col + 1)
      if not ch:match("%s") then
        col = col + 1
      end
    end
    r.scol = col
  end

  -- expand right on end row (end is end-exclusive originally; we store ecol as inclusive-ish for hit)
  do
    local line = (vim.api.nvim_buf_get_lines(bufnr, r.erow, r.erow + 1, false)[1] or "")
    local col = r.ecol
    while col < #line do
      local ch = line:sub(col + 1, col + 1)
      if ch:match("%s") then
        col = col + 1
      else
        break
      end
    end
    r.ecol = col
  end

  return r
end

local function score(r)
  return (r.erow - r.srow) * 1000000 + (r.ecol - r.scol)
end

---@class GetCaptureNodeAndHitboxOpts
---@field expand_whitespace? boolean
---@field expand_extra fun(bufnr: integer, node: TSNode, cap: string, r: Range4): Range4

---Find the “best” capture node under cursor and return node+cap+hitbox.
---@param bufnr integer
---@param root TSNode
---@param query vim.treesitter.Query
---@param opts? GetCaptureNodeAndHitboxOpts
---@return TSNode?, string?, Range4?
function M.get_capture_node_and_hitbox(bufnr, root, query, opts)
  opts = opts or {}
  local cur = vim.api.nvim_win_get_cursor(0)
  local row0, col0 = cur[1] - 1, cur[2]

  local best_node, best_cap, best_hitbox, best_score

  for _, match, _ in query:iter_matches(root, bufnr) do
    for id, nodes in pairs(match) do
      local node0 = type(nodes) == "table" and nodes[#nodes] or nodes
      local cap = query.captures[id]

      local r = from_node(node0)
      if opts.expand_whitespace ~= false then
        r = expand_whitespace(bufnr, r)
      end
      if opts.expand_extra then
        r = opts.expand_extra(bufnr, node0, cap, r) or r
      end

      if contains(r, row0, col0) then
        local sc = score(r)
        if best_score == nil or sc < best_score then
          best_score = sc
          best_node, best_cap, best_hitbox = node0, cap, r
        end
      end
    end
  end

  return best_node, best_cap, best_hitbox
end

return M
