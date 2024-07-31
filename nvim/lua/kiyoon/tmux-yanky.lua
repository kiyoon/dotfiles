-- Integrates tmux.nvim with yanky.nvim and which-key.nvim so we get the benefits of all yank-related plugins.
require("tmux").setup {
  copy_sync = {
    enable = true,
    sync_clipboard = false,
    sync_registers = true,
    sync_registers_keymap_reg = false,
  },
  resize = {
    enable_default_keybindings = false,
    resize_step_x = 4,
    resize_step_y = 2,
  },
}

-- since we want to use sync_registers with yanky.nvim, we need to
-- configure keybindings manually.
local yanky = require "yanky"
yanky.setup {
  highlight = {
    on_put = true,
    on_yank = true,
    timer = 300,
  },
}
vim.keymap.set("n", "p", function()
  if vim.env.TMUX then
    require("tmux.copy").sync_registers()
  end
  yanky.put("p", false)
end)
vim.keymap.set("x", "p", function()
  if vim.env.TMUX then
    require("tmux.copy").sync_registers()
  end
  yanky.put("p", true)
end)
vim.keymap.set("n", "P", function()
  if vim.env.TMUX then
    require("tmux.copy").sync_registers()
  end
  yanky.put("P", false)
end)
vim.keymap.set("x", "P", function()
  if vim.env.TMUX then
    require("tmux.copy").sync_registers()
  end
  yanky.put("P", true)
end)

vim.keymap.set("n", "<c-n>", "<Plug>(YankyCycleForward)")
vim.keymap.set("n", "<c-p>", "<Plug>(YankyCycleBackward)")
vim.keymap.set({ "n", "x" }, "y", "<Plug>(YankyYank)")
vim.keymap.set("n", "=p", "<Plug>(YankyPutAfterFilter)")
vim.keymap.set("n", "=P", "<Plug>(YankyPutBeforeFilter)")
require("telescope").load_extension "yank_history"
