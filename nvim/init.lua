vim.g.python3_host_prog = "/usr/bin/python3"
-- vim.g.python3_host_prog = "~/bin/miniconda3/envs/nvim/bin/python3"

vim.env.GIT_CONFIG_GLOBAL = ""

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

-- Load plugin specs from `~/.config/nvim/lua/kiyoon/lazy.lua`
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
        "matchit", -- Extended %. replaced by vim-matchup
        "matchparen", -- Highlight matching paren. replaced by vim-matchup
        "netrwPlugin", -- File browser. replaced by nvim-tree, neo-tree, oil.nvim
        "tohtml",
        "tutor",
        -- "tarPlugin",
        -- "gzip",
        -- "zipPlugin",
      },
    },
  },
})

-- Source .vimrc
local vimrcpath = vim.fn.stdpath "config" .. "/.vimrc"
vim.cmd("source " .. vimrcpath)

vim.o.termguicolors = true
vim.opt.iskeyword:append "-" -- treats words with `-` as single words
vim.o.cursorline = true
vim.o.inccommand = "split"
vim.o.updatetime = 500

-- This may cause lualine to flicker
-- vim.o.cmdheight = 0

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

-- Configure context menu on right click
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

-- Add :Messages command to open messages in a buffer. Useful for debugging.
-- Better than the default :messages
local function open_messages_in_buffer(args)
  if Bufnr_messages == nil or vim.fn.bufexists(Bufnr_messages) == 0 then
    -- Create a temporary buffer
    Bufnr_messages = vim.api.nvim_create_buf(false, true)
  end
  -- Create a split and open the buffer
  vim.cmd([[sb]] .. Bufnr_messages)
  -- vim.cmd "botright 10new"
  vim.bo.modifiable = true
  vim.api.nvim_buf_set_lines(Bufnr_messages, 0, -1, false, {})
  vim.cmd "put = execute('messages')"
  vim.bo.modifiable = false

  -- No need for below because we created a temporary buffer
  -- vim.bo.modified = false
end

vim.api.nvim_create_user_command("Messages", open_messages_in_buffer, {})

-- only filetype specific mappings
-- autocmd

require "wookayin.python_keymaps"

-- Convert | to │ (box drawing character)
-- Convert │ to └
-- Convert └ to │
vim.keymap.set("n", "<space>tl", function()
  local current_pos = vim.api.nvim_win_get_cursor(0)
  local current_row = current_pos[1] - 1
  local current_col = current_pos[2]
  -- NOTE: since the lines are 3 bytes long, we need to get 3 bytes
  local current_char = vim.api.nvim_buf_get_text(0, current_row, current_col, current_row, current_col + 3, {})[1]

  local old_char = nil
  local new_char = nil
  if current_char:sub(1, 1) == "|" then
    old_char = "|"
    new_char = "│"
  elseif current_char == "│" then
    old_char = "│"
    new_char = "└"
  elseif current_char == "└" then
    old_char = "└"
    new_char = "│"
  else
    old_char = current_char:sub(1, 1)
  end

  local byte_size_old_char = vim.fn.len(old_char)

  if new_char == nil then
    vim.notify("Can't convert. No mapping for " .. old_char)
    return
  end

  vim.api.nvim_buf_set_text(0, current_row, current_col, current_row, current_col + byte_size_old_char, { new_char })
end)

vim.keymap.set({ "n", "v", "o" }, "<F2>", function()
  -- tmux previous window
  vim.fn.system "tmux select-window -t :-"
end, { desc = "tmux previous window" })
vim.keymap.set({ "n", "v", "o" }, "<F3>", function()
  -- tmux previous window
  vim.fn.system "tmux select-window -t :-"
end, { desc = "tmux previous window" })
vim.keymap.set({ "n", "v", "o" }, "<F5>", function()
  vim.fn.system "tmux select-window -t :+"
end, { desc = "tmux next window" })
vim.keymap.set({ "n", "v", "o" }, "<F6>", function()
  vim.fn.system "tmux select-window -t :+"
end, { desc = "tmux next window" })

-- Align CSV columns. Much faster than rainbow_csv
-- https://stackoverflow.com/questions/51471554/align-columns-in-comma-separated-file

-- Mac only
if vim.fn.has "macunix" == 1 then
  vim.api.nvim_create_user_command(
    "CsvAlign",
    ":set nowrap | %!sed 's/,/&^::,/g' | column -t -s'&^::' | sed 's/ ,/,/g'",
    {}
  )
-- Linux only
elseif vim.fn.has "unix" == 1 then
  vim.api.nvim_create_user_command("CsvAlign", ":set nowrap | %!column -t -s, -o,", {})
end

-- sql formatter for selection
vim.keymap.set("x", "<space>pF", function()
  vim.cmd [['<,'>!sql-formatter -c '{ "keywordCase": "upper" }']]
end, { desc = "Run sql-formatter in selection" })
