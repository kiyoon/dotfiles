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

require("lazy").setup("kiyoon.lazy", {
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

vim.o.termguicolors = true
vim.opt.iskeyword:append "-" -- treats words with `-` as single words
vim.o.cursorline = true
vim.o.inccommand = "split"
vim.o.updatetime = 500

-- vim.o.cmdheight = 0  -- This may cause lualine to flicker

vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "gitcommit", "markdown" },
  callback = function()
    vim.opt_local.wrap = true
    -- vim.opt_local.spell = true
  end,
})

--- NOTE: removed in favour of yanky.nvim

-- [[ Highlight on yank ]]
-- See `:help vim.highlight.on_yank()`
-- local highlight_group = vim.api.nvim_create_augroup("YankHighlight", { clear = true })
-- vim.api.nvim_create_autocmd("TextYankPost", {
--   callback = function()
--     vim.highlight.on_yank()
--   end,
--   group = highlight_group,
--   pattern = "*",
-- })

vim.cmd [[
" With GUI demo
nmap <leader>G <Cmd>call system("docker run --gpus all --rm --device=/dev/video0:/dev/video0 -e DISPLAY=${DISPLAY} -v /tmp/.X11-unix:/tmp/.X11-unix -v ~/project/nvim-hand-gesture:/workspace -v /run/user:/run/user kiyoon/nvim-hand-gesture --gui --nvim_socket_path " . v:servername . " &")<CR>
" Without GUI
nmap <leader>g <Cmd>call system("docker run --gpus all --rm --device=/dev/video0:/dev/video0 -v ~/project/nvim-hand-gesture:/workspace -v /run/user:/run/user kiyoon/nvim-hand-gesture --nvim_socket_path " . v:servername . " &")<CR>
" Quit running process
nmap <leader><leader>g <Cmd>let g:quit_nvim_hand_gesture = 1<CR>
]]

-- local vscodepath = vim.fn.stdpath "config" .. "/vscode.vim"
-- vim.cmd("source " .. vscodepath)

require "kiyoon.menu"

-- folding (use nvim-ufo for better control)
-- vim.cmd [[hi Folded guibg=black ctermbg=black]]
-- vim.o.foldmethod = "expr"
-- vim.o.foldcolumn = "auto:9"
-- -- vim.o.fillchars = [[eob: ,fold: ,foldopen:,foldsep: ,foldclose:]]
-- vim.o.fillchars = [[foldopen:,foldclose:]]
-- vim.o.foldminlines = 25
-- vim.o.foldexpr = "nvim_treesitter#foldexpr()"
-- -- open folds by default
-- vim.cmd [[autocmd BufReadPost,FileReadPost * normal zR]]

vim.cmd [[
augroup AutoView
  autocmd!
  autocmd BufWritepre,BufWinLeave ?* silent! mkview
  autocmd BufWinEnter ?* silent! loadview
augroup END
]]

-- Better Korean mapping in normal mode. It's not perfect
vim.o.langmap =
  "ㅁa,ㅠb,ㅊc,ㅇd,ㄷe,ㄹf,ㅎg,ㅗh,ㅑi,ㅓj,ㅏk,ㅣl,ㅡm,ㅜn,ㅐo,ㅔp,ㅂq,ㄱr,ㄴs,ㅅt,ㅕu,ㅍv,ㅈw,ㅌx,ㅛy,ㅋz"
-- Faster filetype detection for neovim
vim.g.do_filetype_lua = 1

-- splitting doesn't change the scroll
-- vim.o.splitkeep = "screen"

-- Use when you see everything is folded
-- Maybe some plugin is overwriting this?
-- vim.cmd [[
-- augroup FoldLevel
--   autocmd!
--   autocmd BufWinEnter ?* set foldlevel=99
-- augroup END
-- ]]

local function open_messages_in_buffer(args)
  vim.cmd "botright 10new"
  vim.cmd "put = execute('messages')"
  vim.cmd [[set nomodifiable]]
  vim.cmd [[set nomodified]]
end

vim.api.nvim_create_user_command("Messages", open_messages_in_buffer, {})
