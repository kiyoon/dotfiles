vim.g.python3_host_prog = "/usr/bin/python3"
-- vim.g.python3_host_prog = "~/bin/miniconda3/envs/nvim/bin/python3"

local lazypath = vim.fn.stdpath "data" .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system {
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  }
end
vim.opt.rtp:prepend(lazypath)

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

local vimrcpath = vim.fn.stdpath "config" .. "/.vimrc"
vim.cmd("source " .. vimrcpath)
vim.opt.iskeyword:append "-" -- treats words with `-` as single words
vim.o.updatetime = 500
-- Faster filetype detection for neovim
vim.g.do_filetype_lua = 1

vim.cmd [[
	xmap gc  <Plug>VSCodeCommentary
	nmap gc  <Plug>VSCodeCommentary
	omap gc  <Plug>VSCodeCommentary
	nmap gcc <Plug>VSCodeCommentaryLine
]]
