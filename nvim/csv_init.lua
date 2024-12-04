-- Configuration for csv, tsv files
-- Data files are often very big and slow to load, so we disable most plugins.

-- if venv exists, use it
if vim.fn.isdirectory(vim.fn.expand("~/.virtualenvs/neovim")) == 1 then
  vim.g.python3_host_prog = vim.fn.expand("~/.virtualenvs/neovim/bin/python3")
  -- vim.g.python3_host_prog = vim.fn.expand("~/bin/miniconda3/envs/nvim/bin/python3")
else
  vim.g.python3_host_prog = "/usr/bin/python3"
end

vim.o.number = true
vim.o.termguicolors = true
vim.opt.iskeyword:append("-") -- treats words with `-` as single words
vim.o.cursorline = true
vim.o.inccommand = "split"
vim.o.updatetime = 500
vim.o.wrap = false

-- Better Korean mapping in normal mode. It's not perfect
vim.o.langmap =
  "ㅁa,ㅠb,ㅊc,ㅇd,ㄷe,ㄹf,ㅎg,ㅗh,ㅑi,ㅓj,ㅏk,ㅣl,ㅡm,ㅜn,ㅐo,ㅔp,ㅂq,ㄱr,ㄴs,ㅅt,ㅕu,ㅍv,ㅈw,ㅌx,ㅛy,ㅋz"
-- Faster filetype detection for neovim
vim.g.do_filetype_lua = 1

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
  vim.cmd("put = execute('messages')")
  vim.bo.modifiable = false

  -- No need for below because we created a temporary buffer
  -- vim.bo.modified = false
end

vim.api.nvim_create_user_command("Messages", open_messages_in_buffer, {})

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

-- Align CSV columns. Much faster than rainbow_csv
-- https://stackoverflow.com/questions/51471554/align-columns-in-comma-separated-file

-- Mac only
-- if vim.fn.has "macunix" == 1 then
--   vim.api.nvim_create_user_command(
--     "CsvAlign",
--     ":set nowrap | %!sed 's/,/&^::,/g' | column -t -s'&^::' | sed 's/ ,/,/g'",
--     {}
--   )
--   vim.api.nvim_create_user_command(
--     "TsvAlign",
--     ":set nowrap | %!sed 's/\t/&^::\t/g' | column -t -s'&^::' | sed 's/ \t/\t/g'",
--     {}
--   )
-- -- Linux only
-- elseif vim.fn.has "unix" == 1 then
--   vim.api.nvim_create_user_command("CsvAlign", ":set nowrap | %!column -t -s, -o,", {})
-- end

require("kiyoon.async_run")

vim.api.nvim_create_user_command("CsvAlign", function()
  vim.cmd([[%!]] .. vim.g.python3_host_prog .. [[ ~/.config/nvim/csv_tools.py align --filetype ]] .. vim.bo.filetype)
end, {})

vim.api.nvim_create_user_command("CsvAlignEdit", function()
  vim.cmd(
    [[%!]]
      .. vim.g.python3_host_prog
      .. [[ ~/.config/nvim/csv_tools.py align --edit-mode --filetype ]]
      .. vim.bo.filetype
  )
end, {})

vim.api.nvim_create_user_command("CsvShrink", function()
  vim.cmd([[%!]] .. vim.g.python3_host_prog .. [[ ~/.config/nvim/csv_tools.py shrink --filetype ]] .. vim.bo.filetype)
end, {})

vim.api.nvim_create_user_command("CsvSelectAndAlign", function(opts)
  vim.cmd(
    [[%!]]
      .. vim.g.python3_host_prog
      .. [[ ~/.config/nvim/csv_tools.py select ']]
      .. opts.fargs[1]
      .. [[' --filetype ]]
      .. vim.bo.filetype
      .. [[ | ]]
      .. vim.g.python3_host_prog
      .. [[ ~/.config/nvim/csv_tools.py align --filetype ]]
      .. vim.bo.filetype
  )
end, { nargs = 1 })
vim.api.nvim_create_user_command("CsvSelectAndAlignEdit", function(opts)
  vim.cmd(
    [[%!]]
      .. vim.g.python3_host_prog
      .. [[ ~/.config/nvim/csv_tools.py select ']]
      .. opts.fargs[1]
      .. [[' --filetype ]]
      .. vim.bo.filetype
      .. [[ | ]]
      .. vim.g.python3_host_prog
      .. [[ ~/.config/nvim/csv_tools.py align --edit-mode --filetype ]]
      .. vim.bo.filetype
  )
end, { nargs = 1 })

-- Lock header row
-- https://stackoverflow.com/questions/1773311/vim-lock-top-line-of-a-window
vim.cmd([[1spl]])
vim.cmd([[set scrollbind]])
-- go to the first window
vim.cmd([[wincmd w]])
vim.cmd([[set scrollbind]]) -- synchronize lower window
vim.cmd([[set sbo=hor]]) -- synchronize horizontally

-- Run this after loading all UI
vim.defer_fn(function()
  vim.cmd([[wincmd w]])
end, 0)

-- H, L to move columns based on the length from the first row.

vim.keymap.set({ "n", "v" }, "H", function()
  local first_line = vim.fn.getline(1)
  local col = vim.fn.col(".")
  local start = col
  for i = col - 1, 1, -1 do
    if string.sub(first_line, i, i) == "," then
      start = i
      break
    end
  end

  if start ~= 1 then
    for i = start - 1, 1, -1 do
      if string.sub(first_line, i, i) == "," then
        start = i + 1
        break
      end
    end
  end

  vim.cmd("normal! " .. start .. "|")
end, { desc = "Goto column left" })

vim.keymap.set({ "n", "v" }, "L", function()
  local first_line = vim.fn.getline(1)
  local col = vim.fn.col(".")
  local first_line_len = string.len(first_line)
  local start = col
  for i = col + 1, first_line_len do
    if string.sub(first_line, i, i) == "," then
      start = i + 1
      break
    end
  end
  vim.cmd("normal! " .. start .. "|")
end, { desc = "Goto column right" })

-- unmap J to avoid accidental join
vim.keymap.set({ "n", "x" }, "J", "<nop>", { silent = true, noremap = true })
-- use <space>J to join lines
vim.keymap.set({ "n", "x" }, "<space>J", "J", { silent = true, noremap = true })
