-- if venv exists, use it
if vim.fn.isdirectory(vim.fn.expand("~/.virtualenvs/neovim")) == 1 then
  vim.g.python3_host_prog = vim.fn.expand("~/.virtualenvs/neovim/bin/python3")
  -- vim.g.python3_host_prog = vim.fn.expand("~/bin/miniconda3/envs/nvim/bin/python3")
else
  vim.g.python3_host_prog = "/usr/bin/python3"
end

vim.env.GIT_CONFIG_GLOBAL = ""

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
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

-- Load plugin specs from `~/.config/nvim/lua/kiyoon/lazy.lua`
require("lazy").setup("kiyoon-vscode.lazy", {
  dev = {
    path = "~/project",
    -- patterns = { "kiyoon", "nvim-treesitter-textobjects" },
  },
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

-- Source .vimrc
local vimrcpath = vim.fn.stdpath("config") .. "/.vimrc"
vim.cmd("source " .. vimrcpath)

vim.o.termguicolors = true
vim.opt.iskeyword:append("-") -- treats words with `-` as single words
vim.o.updatetime = 500
vim.o.exrc = true -- read config from .exrc.lua / .nvimrc.lua
-- Faster filetype detection for neovim
vim.g.do_filetype_lua = 1

vim.cmd([[
	xmap gc  <Plug>VSCodeCommentary
	nmap gc  <Plug>VSCodeCommentary
	omap gc  <Plug>VSCodeCommentary
	nmap gcc <Plug>VSCodeCommentaryLine
]])

-- Recognise Jupyter notebook files as python files
vim.filetype.add({
  pattern = {
    [".*%.ipynb.*"] = "python",
    -- uses lua pattern matching
    -- rathen than naive matching
  },
})

require("type_righter.keymaps.python")
require("type_righter.keymaps.rust")
require("type_righter.keymaps.typescript")
-- local typescript_captures = require("type_righter.languages.typescript").get_capture_node_under_cursor
-- require("type_righter.hitbox_debugger").toggle_hitbox_debug(typescript_captures)

-- sql formatter for selection
vim.keymap.set("x", "<space>pF", function()
  vim.cmd([['<,'>!sql-formatter -c '{ "keywordCase": "upper" }']])
end, { desc = "Run sql-formatter in selection" })

vim.keymap.set("n", "<space>ta", function()
  require("kiyoon.tools.cycle_case")()
end, { remap = true })

require("kiyoon.settings.python_keymaps")
require("kiyoon.settings.markdown_keymaps")
require("kiyoon.settings.keychrone_mappings")
require("kiyoon.settings.korean_langmap")
require("kiyoon.settings.no_lua_ts")
