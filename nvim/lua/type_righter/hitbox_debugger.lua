local notify = require("type_righter.notify")
local debug = {
  enabled = false,
  ns = vim.api.nvim_create_namespace("type_righter_hitbox"),
}

local M = {}

local function clear_debug(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, debug.ns, 0, -1)
end

--- Highlight the given range in the buffer for debugging
---@param bufnr number Buffer number
---@param hb Range4
local function highlight_hitbox(bufnr, hb)
  vim.api.nvim_buf_clear_namespace(bufnr, debug.ns, 0, -1)
  if not hb then
    return
  end
  vim.api.nvim_buf_set_extmark(bufnr, debug.ns, hb.srow, hb.scol, {
    end_row = hb.erow,
    end_col = hb.ecol,
    hl_group = "Visual",
    priority = 200,
  })
end

-- Call this on CursorMoved when debug.enabled
local function update_debug_highlight(get_best_capture_fn)
  local bufnr = vim.api.nvim_get_current_buf()
  clear_debug(bufnr)
  local node, cap, hitbox = get_best_capture_fn()
  if not node then
    return
  end
  highlight_hitbox(bufnr, hitbox)

  -- Optional: show what capture you’re on
  vim.api.nvim_echo({ { ("hitbox: %s"):format(cap or "?"), "Comment" } }, false, {})
end

M.toggle_hitbox_debug = function(get_best_capture_fn)
  debug.enabled = not debug.enabled
  local bufnr = vim.api.nvim_get_current_buf()
  clear_debug(bufnr)

  if debug.enabled then
    -- unique augroup
    local grp = vim.api.nvim_create_augroup("TypeRighterHitboxDebug", { clear = true })
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
      group = grp,
      callback = function()
        update_debug_highlight(get_best_capture_fn)
      end,
    })
    update_debug_highlight(get_best_capture_fn)
    notify.notify("Hitbox debug: ON", vim.log.levels.INFO, { title = "type-righter.nvim" })
  else
    vim.api.nvim_del_augroup_by_name("TypeRighterHitboxDebug")
    notify.notify("Hitbox debug: OFF", vim.log.levels.INFO, { title = "type-righter.nvim" })
  end
end

return M
