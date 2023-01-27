-- place this in one of your configuration file(s)
local hop = require "hop"
local directions = require("hop.hint").HintDirection

hop.setup()

-- default find keys will use hop instead
-- vim.keymap.set('', 'f', function()
--   hop.hint_char1({ direction = directions.AFTER_CURSOR, current_line_only = true })
-- end, {remap=true})
-- vim.keymap.set('', 'F', function()
--   hop.hint_char1({ direction = directions.BEFORE_CURSOR, current_line_only = true })
-- end, {remap=true})
-- vim.keymap.set('', 't', function()
--   hop.hint_char1({ direction = directions.AFTER_CURSOR, current_line_only = true, hint_offset = -1 })
-- end, {remap=true})
-- vim.keymap.set('', 'T', function()
--   hop.hint_char1({ direction = directions.BEFORE_CURSOR, current_line_only = true, hint_offset = 1 })
-- end, {remap=true})

-- <space>w and <space>e for word hopping

-- vim.keymap.set("", "<space>w", function()
--   hop.hint_words { current_line_only = true }
-- end, { remap = true })

vim.keymap.set("", "<space>f", function()
  hop.hint_char1 { current_line_only = true }
end, { remap = true })

-- more advanced, use two words to search everywhere
-- Use leap.nvim instead
-- vim.keymap.set("", "<space>g", function()
--   hop.hint_char2 {}
-- end, { remap = true })
-- vim.keymap.set("n", "<space>g", function()
--   hop.hint_char2 { multi_windows = true }
-- end, { remap = true })

-- Bidirectional t motion
-- https://github.com/phaazon/hop.nvim/issues/266

-- Derived from `hop.hint_with()`
local function hintWithTill(jump_target_gtr, opts)
  if opts == nil then
    -- Taken from override_opts()
    opts = setmetatable(opts or {}, { __index = require("hop").opts })
  end

  require("hop").hint_with_callback(jump_target_gtr, opts, function(jt)
    local jumpLine = jt.line + 1
    local jumpCol = jt.column - 1

    local curPos = vim.api.nvim_win_get_cursor(0)
    local row = curPos[1]
    local col = curPos[2]

    local hintOffset
    if row > jumpLine or (row == jumpLine and col > jumpCol) then
      hintOffset = 1
    else
      hintOffset = -1
    end

    require("hop").move_cursor_to(jt.window, jumpLine, jumpCol, hintOffset)
  end)
end

-- Derived from `hop.get_input_pattern()`
local function getInputChar(prompt)
  local K_Esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
  local K_BS = vim.api.nvim_replace_termcodes("<BS>", true, false, true)
  local K_CR = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
  local key = ""

  vim.api.nvim_echo({}, false, {})
  vim.cmd "redraw"
  vim.api.nvim_echo({ { prompt, "Question" }, { key } }, false, {})

  local ok, key = pcall(vim.fn.getchar)
  if not ok then
    return key
  end -- Interrupted by <C-c>

  if type(key) == "number" then
    key = vim.fn.nr2char(key)
  elseif key:byte() == 128 then
    -- It's a special key in string
  end

  if key == K_Esc or key == K_CR or key == K_BS then
    key = nil
  end

  vim.api.nvim_echo({}, false, {})
  vim.cmd "redraw"
  return key
end

-- Derived from `hop.hint_char1()`
function hintTill1(opts)
  -- Taken from override_opts()
  opts = setmetatable(opts or {}, { __index = require("hop").opts })

  local c = getInputChar "Till 1 char: "
  if not c then
    return
  end

  local generator = require("hop.jump_target").jump_targets_by_scanning_lines
  hintWithTill(generator(require("hop.jump_target").regex_by_case_searching(c, true, opts)), opts)
end

vim.keymap.set("n", "<space>t", "<Cmd>lua hintTill1()<CR>", { noremap = true })
vim.keymap.set("o", "<space>t", "V:lua hintTill1()<CR>", { noremap = true })
