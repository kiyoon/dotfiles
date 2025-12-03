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
local vimrcpath = vim.fn.stdpath("config") .. "/.vimrc"
vim.cmd("source " .. vimrcpath)

vim.o.termguicolors = true
vim.opt.iskeyword:append("-") -- treats words with `-` as single words
vim.o.cursorline = true
vim.o.inccommand = "split"
vim.o.updatetime = 500
vim.o.exrc = true -- read config from .exrc.lua / .nvimrc.lua
-- vim.o.winborder = "rounded"
vim.o.pumblend = 30 -- popup menu transparency

-- This may cause lualine to flicker
-- vim.o.cmdheight = 0

vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "gitcommit", "markdown" },
  callback = function()
    vim.opt_local.wrap = true
    -- vim.opt_local.spell = true
  end,
})

vim.cmd([[
" With GUI demo
nmap <leader>G <Cmd>call system("docker run --gpus all --rm --device=/dev/video0:/dev/video0 -e DISPLAY=${DISPLAY} -v /tmp/.X11-unix:/tmp/.X11-unix -v ~/project/nvim-hand-gesture:/workspace -v /run/user:/run/user kiyoon/nvim-hand-gesture --gui --nvim_socket_path " . v:servername . " &")<CR>
" Without GUI
nmap <leader>g <Cmd>call system("docker run --gpus all --rm --device=/dev/video0:/dev/video0 -v ~/project/nvim-hand-gesture:/workspace -v /run/user:/run/user kiyoon/nvim-hand-gesture --nvim_socket_path " . v:servername . " &")<CR>
" Quit running process
nmap <leader><leader>g <Cmd>let g:quit_nvim_hand_gesture = 1<CR>
]])

-- Configure context menu on right click
require("kiyoon.menu")

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

vim.cmd([[
augroup AutoView
  autocmd!
  autocmd BufWritepre,BufWinLeave ?* silent! mkview
  autocmd BufWinEnter ?* silent! loadview
augroup END
]])

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

require("wookayin.python_keymaps")
require("wookayin.rust_keymaps")

-- Convert | to │ (box drawing character)
-- Convert │ to └
-- Convert └ to │
-- vim.keymap.set("n", "<space>tl", function()
--   local current_pos = vim.api.nvim_win_get_cursor(0)
--   local current_row = current_pos[1] - 1
--   local current_col = current_pos[2]
--   -- NOTE: since the lines are 3 bytes long, we need to get 3 bytes
--   local current_char = vim.api.nvim_buf_get_text(0, current_row, current_col, current_row, current_col + 3, {})[1]
--
--   local old_char = nil
--   local new_char = nil
--   if current_char:sub(1, 1) == "|" then
--     old_char = "|"
--     new_char = "│"
--   elseif current_char == "│" then
--     old_char = "│"
--     new_char = "└"
--   elseif current_char == "└" then
--     old_char = "└"
--     new_char = "│"
--   else
--     old_char = current_char:sub(1, 1)
--   end
--
--   local byte_size_old_char = vim.fn.len(old_char)
--
--   if new_char == nil then
--     vim.notify("Can't convert. No mapping for " .. old_char)
--     return
--   end
--
--   vim.api.nvim_buf_set_text(0, current_row, current_col, current_row, current_col + byte_size_old_char, { new_char })
-- end)

-- sql formatter for selection
vim.keymap.set("x", "<space>pF", function()
  vim.cmd([['<,'>!sql-formatter -c '{ "keywordCase": "upper" }']])
end, { desc = "Run sql-formatter in selection" })

local make_repeatable_keymap = require("wookayin.utils").make_repeatable_keymap
local cycle_case = require("kiyoon.tools.cycle_case")
vim.keymap.set("n", "<space>ta", make_repeatable_keymap("n", "<Plug>(cycle-case)", cycle_case), { remap = true })

vim.api.nvim_create_augroup("markdown_mappings", { clear = true })
vim.api.nvim_create_autocmd({ "FileType" }, {
  pattern = { "markdown" },
  callback = function()
    local bufmap = function(mode, lhs, rhs, opts)
      return vim.keymap.set(mode, lhs, rhs, vim.tbl_deep_extend("error", { buffer = true }, opts or {}))
    end
    bufmap({ "n", "x" }, "<space>tl", function()
      require("kiyoon.tools.markdown").turn_to_link({ repeat_content = false })
      vim.cmd("startinsert")
    end, { remap = true, desc = "Make markdown hyperlink" })
    bufmap({ "n", "x" }, "<space>tL", function()
      require("kiyoon.tools.markdown").turn_to_link({ repeat_content = true })
    end, { remap = true, desc = "Make markdown hyperlink (content repeat)" })
  end,
  group = "markdown_mappings",
})

require("kiyoon.settings.keychrone_mappings")
require("kiyoon.settings.korean_langmap")
require("kiyoon.settings.messages_in_buffer")
require("kiyoon.settings.tmux_window_name")
require("kiyoon.settings.highlight_yank")
require("kiyoon.settings.osc52")
require("kiyoon.settings.no_lua_ts")
