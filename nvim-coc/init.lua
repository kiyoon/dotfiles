vim.g.python3_host_prog = "/usr/bin/python3"
-- vim.g.python3_host_prog = "~/bin/miniconda3/envs/nvim/bin/python3"

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

require("lazy").setup("kiyoon.lazy", {
	dev = {
		path = "~/project",
		-- patterns = { "kiyoon", "nvim-treesitter-textobjects" },
	},
})

local vimrcpath = vim.fn.stdpath("config") .. "/.vimrc"
vim.cmd("source " .. vimrcpath)

vim.o.termguicolors = true
vim.opt.iskeyword:append("-") -- treats words with `-` as single words
vim.o.cursorline = true
vim.o.inccommand = "split"
vim.o.updatetime = 500

-- Better Korean mapping in normal mode. It's not perfect
vim.o.langmap =
	"ㅁa,ㅠb,ㅊc,ㅇd,ㄷe,ㄹf,ㅎg,ㅗh,ㅑi,ㅓj,ㅏk,ㅣl,ㅡm,ㅜn,ㅐo,ㅔp,ㅂq,ㄱr,ㄴs,ㅅt,ㅕu,ㅍv,ㅈw,ㅌx,ㅛy,ㅋz"
-- Faster filetype detection for neovim
vim.g.do_filetype_lua = 1

-- splitting doesn't change the scroll
-- vim.o.splitkeep = "screen"

vim.o.timeoutlen = 10000
