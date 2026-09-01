local demo_env = "KITTY_CAMERA_DEMO"
local allowed_demo = "nvim-tour"

local function emit_demo(name)
  local osc = ("\27]1337;SetUserVar=camera_demo=%s\7"):format(vim.base64.encode(name))
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
    if vim.env[demo_env] ~= allowed_demo then
      return
    end
    vim.env[demo_env] = nil
    if #vim.api.nvim_list_uis() > 0 then
      emit_demo(allowed_demo)
    end
  end,
})
