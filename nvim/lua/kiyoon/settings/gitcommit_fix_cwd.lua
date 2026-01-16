-- Automatically change the working directory to the git repository root
-- when editing a COMMIT_EDITMSG file.
-- Because sometimes it becomes completely wrong?
vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "COMMIT_EDITMSG",
  callback = function()
    local file = vim.api.nvim_buf_get_name(0)
    -- file = /path/to/repo/.git/COMMIT_EDITMSG
    local git_dir = vim.fn.fnamemodify(file, ":h") -- .../.git
    local repo_root = vim.fn.fnamemodify(git_dir, ":h") -- .../repo
    vim.cmd("lcd " .. vim.fn.fnameescape(repo_root))
  end,
})
