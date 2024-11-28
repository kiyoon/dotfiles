-- Even if your gitconfig redirects https to ssh (url insteadOf), this will make sure that
-- plugins will be installed via https instead of ssh.
vim.env.GIT_CONFIG_GLOBAL = ""

-- Remove the white status bar below
vim.o.laststatus = 0

-- True colour support
vim.o.termguicolors = true

-- lazy.nvim plugin manager
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

local function nvim_tree_on_attach(bufnr)
  local api = require("nvim-tree.api")
  local nt_remote = require("nvim_tree_remote")

  local function opts(desc)
    return { desc = "nvim-tree: " .. desc, buffer = bufnr, noremap = true, silent = true, nowait = true }
  end

  api.config.mappings.default_on_attach(bufnr)

  vim.keymap.set("n", "u", api.tree.change_root_to_node, opts("Dir up"))
  vim.keymap.set("n", "<F1>", api.node.show_info_popup, opts("Show info popup"))
  vim.keymap.set("n", "l", nt_remote.tabnew, opts("Open in treemux"))
  vim.keymap.set("n", "<CR>", nt_remote.tabnew, opts("Open in treemux"))
  vim.keymap.set("n", "<C-t>", nt_remote.tabnew, opts("Open in treemux"))
  vim.keymap.set("n", "<2-LeftMouse>", nt_remote.tabnew, opts("Open in treemux"))
  vim.keymap.set("n", "h", api.tree.close, opts("Close node"))
  vim.keymap.set("n", "v", nt_remote.vsplit, opts("Vsplit in treemux"))
  vim.keymap.set("n", "<C-v>", nt_remote.vsplit, opts("Vsplit in treemux"))
  vim.keymap.set("n", "<C-x>", nt_remote.split, opts("Split in treemux"))
  vim.keymap.set("n", "o", nt_remote.tabnew_main_pane, opts("Open in treemux without tmux split"))

  vim.keymap.set("n", "-", "", { buffer = bufnr })
  vim.keymap.del("n", "-", { buffer = bufnr })
  vim.keymap.set("n", "<C-k>", "", { buffer = bufnr })
  vim.keymap.del("n", "<C-k>", { buffer = bufnr })
  vim.keymap.set("n", "O", "", { buffer = bufnr })
  vim.keymap.del("n", "O", { buffer = bufnr })
end

require("lazy").setup({
  {
    "kiyoon/tmuxsend.vim",
    keys = {
      { "-", "<Plug>(tmuxsend-smart)", mode = { "n", "x" } },
      { "_", "<Plug>(tmuxsend-plain)", mode = { "n", "x" } },
      { "<space>-", "<Plug>(tmuxsend-uid-smart)", mode = { "n", "x" } },
      { "<space>_", "<Plug>(tmuxsend-uid-plain)", mode = { "n", "x" } },
      { "<C-_>", "<Plug>(tmuxsend-tmuxbuffer)", mode = { "n", "x" } },
    },
  },
  {
    "kiyoon/nvim-tree-remote.nvim",
    branch = "feat/python-path",
  },
  "folke/tokyonight.nvim",
  "nvim-tree/nvim-web-devicons",
  {
    "nvim-tree/nvim-tree.lua",
    config = function()
      local nvim_tree = require("nvim-tree")
      nvim_tree.setup({
        on_attach = nvim_tree_on_attach,
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
            hint = "",
            info = "",
            warning = "",
            error = "",
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
    end,
  },
  {
    "stevearc/oil.nvim",
    keys = {
      {
        "<space>o",
        function()
          -- Toggle oil / nvim-tree
          -- if nvim-tree is open, close it and open oil
          -- check filetype
          if vim.bo.filetype == "NvimTree" then
            vim.cmd("NvimTreeClose")
            vim.cmd("Oil")
          elseif vim.bo.filetype == "oil" then
            require("nvim-tree.lib").open({ current_window = true })
          end
        end,
        mode = { "n" },
        desc = "Toggle Oil/nvim-tree",
      },
    },
    config = function()
      require("oil").setup({
        keymaps = {
          ["\\"] = { "actions.select", opts = { vertical = true }, desc = "Open the entry in a vertical split" },
          ["|"] = { "actions.select", opts = { horizontal = true }, desc = "Open the entry in a horizontal split" },
          ["<C-r>"] = "actions.refresh",
          ["g?"] = "actions.show_help",
          ["<CR>"] = "actions.select",
          ["<C-t>"] = { "actions.select", opts = { tab = true }, desc = "Open the entry in new tab" },
          ["<C-p>"] = "actions.preview",
          ["<C-c>"] = "actions.close",
          ["-"] = "actions.parent",
          ["_"] = "actions.open_cwd",
          ["`"] = "actions.cd",
          ["~"] = { "actions.cd", opts = { scope = "tab" }, desc = ":tcd to the current oil directory" },
          ["gs"] = "actions.change_sort",
          ["gx"] = "actions.open_external",
          ["g."] = "actions.toggle_hidden",
          ["g\\"] = "actions.toggle_trash",
        },
        use_default_keymaps = false,
      })
    end,
  },
  {
    "aserowy/tmux.nvim",
    keys = {
      "<C-h>",
      "<C-j>",
      "<C-k>",
      "<C-l>",
      { "<C-A-i>", [[<cmd>lua require("tmux").resize_top()<cr>]] },
      { "<C-A-u>", [[<cmd>lua require("tmux").resize_bottom()<cr>]] },
      { "<C-A-y>", [[<cmd>lua require("tmux").resize_left()<cr>]] },
      { "<C-A-o>", [[<cmd>lua require("tmux").resize_right()<cr>]] },
      { "<F16>", [[<cmd>lua require("tmux").resize_top()<cr>]], mode = { "n", "i", "x", "s", "o" } }, -- <S-F3>
      { "<F15>", [[<cmd>lua require("tmux").resize_top()<cr>]], mode = { "n", "i", "x", "s", "o" } }, -- <S-F2>
      { "<F18>", [[<cmd>lua require("tmux").resize_bottom()<cr>]], mode = { "n", "i", "x", "s", "o" } }, -- <S-F6>
      { "<F27>", [[<cmd>lua require("tmux").resize_left()<cr>]], mode = { "n", "i", "x", "s", "o" } }, -- <C-F3>
      { "<F26>", [[<cmd>lua require("tmux").resize_left()<cr>]], mode = { "n", "i", "x", "s", "o" } }, -- <C-F2>
      { "<F30>", [[<cmd>lua require("tmux").resize_right()<cr>]], mode = { "n", "i", "x", "s", "o" } }, -- <C-F6>
      "<C-n>",
      "<C-p>",
      "p",
      "P",
      "=p",
      "=P",
      { "y", mode = { "x", "o", "s" } },
      { "d", mode = { "x", "o", "s" } },
      { "c", mode = { "x", "o", "s" } },
      { "Y", mode = { "n", "x", "o", "s" } },
      { "D", mode = { "n", "x", "o", "s" } },
      { "C", mode = { "n", "x", "o", "s" } },
    },
    config = function()
      -- Navigate tmux, and nvim splits.
      -- Sync nvim buffer with tmux buffer.
      require("tmux").setup({
        copy_sync = {
          enable = true,
          sync_clipboard = false,
          sync_registers = true,
        },
        resize = {
          enable_default_keybindings = false,
          resize_step_x = 5,
          resize_step_y = 5,
        },
      })
    end,
  },
}, {
  performance = {
    rtp = {
      disabled_plugins = {
        -- List of default plugins can be found here
        -- https://github.com/neovim/neovim/tree/master/runtime/plugin
        "gzip",
        "matchit", -- Extended %. replaced by vim-matchup
        "matchparen", -- Highlight matching paren. replaced by vim-matchup
        "netrwPlugin", -- File browser. replaced by nvim-tree, neo-tree, oil.nvim
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})

vim.cmd([[ colorscheme tokyonight-night ]])
vim.o.cursorline = true

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
