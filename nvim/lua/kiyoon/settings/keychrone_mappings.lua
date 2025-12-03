vim.keymap.set({ "n", "v", "o" }, "<F2>", function()
  -- tmux previous window
  vim.fn.system("tmux select-window -t :-")
end, { desc = "tmux previous window" })
vim.keymap.set({ "n", "v", "o" }, "<F3>", function()
  -- tmux previous window
  vim.fn.system("tmux select-window -t :-")
end, { desc = "tmux previous window" })
vim.keymap.set({ "n", "v", "o" }, "<F5>", function()
  vim.fn.system("tmux select-window -t :+")
end, { desc = "tmux next window" })
vim.keymap.set({ "n", "v", "o" }, "<F6>", function()
  vim.fn.system("tmux select-window -t :+")
end, { desc = "tmux next window" })
