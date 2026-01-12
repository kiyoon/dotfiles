-- Configuration for csv, tsv files
-- Data files are often very big and slow to load, so we disable most plugins.

-- Requires uv

-- -- if venv exists, use it
-- if vim.fn.isdirectory(vim.fn.expand("~/.virtualenvs/neovim")) == 1 then
--   vim.g.python3_host_prog = vim.fn.expand("~/.virtualenvs/neovim/bin/python3")
--   -- vim.g.python3_host_prog = vim.fn.expand("~/bin/miniconda3/envs/nvim/bin/python3")
-- else
--   vim.g.python3_host_prog = "/usr/bin/python3"
-- end

vim.o.number = true
vim.o.termguicolors = true
vim.opt.iskeyword:append("-") -- treats words with `-` as single words
vim.o.cursorline = true
vim.o.inccommand = "split"
vim.o.updatetime = 500
vim.o.wrap = false
vim.o.laststatus = 3 -- global status line because we have a header window

-- Faster filetype detection for neovim
vim.g.do_filetype_lua = 1

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
  vim.cmd([[%!uv run --quiet ~/.config/nvim/csv_tools.py align --filetype ]] .. vim.bo.filetype)
end, {})

vim.api.nvim_create_user_command("CsvAlignEdit", function()
  vim.cmd([[%!uv run --quiet ~/.config/nvim/csv_tools.py align --edit-mode --filetype ]] .. vim.bo.filetype)
end, {})

vim.api.nvim_create_user_command("CsvShrink", function()
  vim.cmd([[%!uv run --quiet ~/.config/nvim/csv_tools.py shrink --filetype ]] .. vim.bo.filetype)
end, {})

vim.api.nvim_create_user_command("CsvSelectAndAlign", function(opts)
  vim.cmd(
    [[%!uv run --quiet ~/.config/nvim/csv_tools.py select ']]
      .. opts.fargs[1]
      .. [[' --filetype ]]
      .. vim.bo.filetype
      .. [[ | uv run --quiet ~/.config/nvim/csv_tools.py align --filetype ]]
      .. vim.bo.filetype
  )
end, { nargs = 1 })
vim.api.nvim_create_user_command("CsvSelectAndAlignEdit", function(opts)
  vim.cmd(
    [[%!uv run --quiet ~/.config/nvim/csv_tools.py select ']]
      .. opts.fargs[1]
      .. [[' --filetype ]]
      .. vim.bo.filetype
      .. [[ | uv run --quiet ~/.config/nvim/csv_tools.py align --edit-mode --filetype ]]
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

  local found = false
  if start ~= 1 then
    for i = start - 1, 1, -1 do
      if string.sub(first_line, i, i) == "," then
        found = true
        start = i + 1
        break
      end
    end
  end

  if not found then
    -- there is no comma before the current column
    -- so it's the first column
    start = 1
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

require("kiyoon.settings.mkview")
require("kiyoon.settings.keychrone_mappings")
require("kiyoon.settings.korean_langmap")
require("kiyoon.settings.messages_in_buffer")
require("kiyoon.settings.tmux_window_name")
require("kiyoon.settings.highlight_yank")
require("kiyoon.settings.osc52")
require("kiyoon.settings.no_lua_ts")
