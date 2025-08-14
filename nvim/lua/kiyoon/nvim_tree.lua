local nvim_tree = require("nvim-tree")

local icons = require("kiyoon.icons")

local function nvim_tree_on_attach(bufnr)
  local api = require("nvim-tree.api")

  local function opts(desc)
    return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
  end

  api.config.mappings.default_on_attach(bufnr)

  vim.keymap.set("n", "u", api.tree.change_root_to_parent, opts("Up"))
  vim.keymap.set("n", "<F1>", api.node.show_info_popup, opts("Info"))
  vim.keymap.set("n", "l", api.node.open.edit, opts("Open"))
  vim.keymap.set("n", "<CR>", api.node.open.edit, opts("Open"))
  vim.keymap.set("n", "o", api.node.open.edit, opts("Open"))
  vim.keymap.set("n", "h", api.node.navigate.parent_close, opts("Close Directory"))
  vim.keymap.set("n", "v", api.node.open.vertical, opts("Open: Vertical Split"))

  vim.keymap.set("n", "-", "", { buffer = bufnr })
  vim.keymap.del("n", "-", { buffer = bufnr })
  vim.keymap.set("n", "<C-k>", "", { buffer = bufnr })
  vim.keymap.del("n", "<C-k>", { buffer = bufnr })
  vim.keymap.set("n", "O", "", { buffer = bufnr })
  vim.keymap.del("n", "O", { buffer = bufnr })
end

nvim_tree.setup({
  on_attach = nvim_tree_on_attach,
  hijack_netrw = false,
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
      hint = icons.Hint,
      info = icons.Info,
      warning = icons.Warn,
      error = icons.Error,
    },
  },
  view = {
    width = 30,
    side = "left",
  },
  filters = {
    custom = { ".git" },
  },
})
