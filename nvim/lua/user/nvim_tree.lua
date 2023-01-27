local nvim_tree = require "nvim-tree"
local config_status_ok, nvim_tree_config = pcall(require, "nvim-tree.config")
if not config_status_ok then
  return
end

nvim_tree.setup {
  update_focused_file = {
    enable = true,
    update_cwd = true,
  },
  renderer = {
    --root_folder_modifier = ":t",
    icons = {
      glyphs = {
        default = "",
        symlink = "",
        folder = {
          arrow_open = "",
          arrow_closed = "",
          default = "",
          open = "",
          empty = "",
          empty_open = "",
          symlink = "",
          symlink_open = "",
        },
        git = {
          unstaged = "",
          staged = "S",
          unmerged = "",
          renamed = "➜",
          untracked = "U",
          deleted = "",
          ignored = "◌",
        },
      },
    },
  },
  diagnostics = {
    enable = true,
    show_on_dirs = true,
    icons = {
      hint = "",
      info = "",
      warning = "",
      error = "",
    },
  },
  view = {
    width = 30,
    side = "left",
    mappings = {
      list = {
        { key = "u", action = "dir_up" },
        { key = "<F1>", action = "toggle_file_info" },
        { key = { "l", "<CR>", "o" }, action = "edit" },
        { key = "h", action = "close_node" },
        { key = "v", action = "vsplit" },
      },
    },
  },
  remove_keymaps = {
    "-",
    "<C-k>",
    "O",
  },
  filters = {
    custom = { ".git" },
  },
}

vim.keymap.set("n", "<space>nt", "<cmd>NvimTreeToggle<CR>", {})
-- nnoremap <space>nr :NvimTreeRefresh<CR>
-- nnoremap <space>nf :NvimTreeFindFile<CR>
