local allowed_timeline = "nvim-tour"

local function emit_timeline(name)
  local osc = ("\27]1337;SetUserVar=camera_timeline=%s\7"):format(vim.base64.encode(name))
  local term = vim.env.TERM or ""
  local through_tmux = vim.env.TMUX and vim.env.TMUX ~= ""
    and (vim.startswith(term, "tmux") or vim.startswith(term, "screen"))
  if through_tmux then
    osc = "\27Ptmux;\27" .. osc .. "\27\\"
  end
  vim.api.nvim_ui_send(osc)
end

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    -- KITTY_WINDOW_ID is inherited through tmux, while other terminals do
    -- not set it. Headless Nvim has no UI to carry the OSC event.
    if (vim.env.KITTY_WINDOW_ID or "") == "" or #vim.api.nvim_list_uis() == 0 then
      return
    end
    emit_timeline(allowed_timeline)
  end,
})
