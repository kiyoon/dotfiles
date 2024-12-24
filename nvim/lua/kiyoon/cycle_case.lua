-- Copied from https://github.com/CKolkey/ts-node-action
-- Modified to work without supported node on treesitter (just current word)
-- and add a kebab case

-- API Notes:
-- Every format is a table that implements the following three keys:
-- - pattern
-- - apply
-- - standardize
--
-- # Pattern
-- A Lua pattern (string) that matches the format
--
-- # Apply
-- A function that takes a _table_ of standardized strings as it's argument, and returns a _string_ in the format
--
-- # Standardize
-- A function that takes a _string_ in this format, and returns a table of strings, all lower case, no special chars.
-- ie: standardize("ts_node_action") -> { "ts", "node", "action" }
--     standardize("tsNodeAction")   -> { "ts", "node", "action" }
--     standardize("TsNodeAction")   -> { "ts", "node", "action" }
--     standardize("TS_NODE_ACTION") -> { "ts", "node", "action" }
--

local format_table = {
  snake_case = {
    pattern = "^%l+[%l_]*$",
    apply = function(tbl)
      return string.lower(table.concat(tbl, "_"))
    end,
    standardize = function(text)
      return vim.split(string.lower(text), "_", { trimempty = true })
    end,
  },
  kebab_case = {
    pattern = "^%l+[%l-]*$",
    apply = function(tbl)
      return string.lower(table.concat(tbl, "-"))
    end,
    standardize = function(text)
      return vim.split(string.lower(text), "-", { trimempty = true })
    end,
  },
  camel_case = {
    pattern = "^%l+[%u%l]*$",
    apply = function(tbl)
      local tmp = vim.tbl_map(function(word)
        return word:gsub("^.", string.upper)
      end, tbl)
      local value, _ = table.concat(tmp, ""):gsub("^.", string.lower)
      return value
    end,
    standardize = function(text)
      return vim.split(
        text:gsub(".%f[%l]", " %1"):gsub("%l%f[%u]", "%1 "):gsub("^.", string.upper),
        " ",
        { trimempty = true }
      )
    end,
  },
  pascal_case = {
    pattern = "^%u%l+[%u%l]*$",
    apply = function(tbl)
      local value, _ = table.concat(
        vim.tbl_map(function(word)
          return word:gsub("^.", string.upper)
        end, tbl),
        ""
      )
      return value
    end,
    standardize = function(text)
      return vim.split(
        text:gsub(".%f[%l]", " %1"):gsub("%l%f[%u]", "%1 "):gsub("^.", string.upper),
        " ",
        { trimempty = true }
      )
    end,
  },
  screaming_snake_case = {
    pattern = "^%u+[%u_]*$",
    apply = function(tbl)
      local value, _ = table.concat(
        vim.tbl_map(function(word)
          return word:upper()
        end, tbl),
        "_"
      )

      return value
    end,
    standardize = function(text)
      return vim.split(string.lower(text), "_", { trimempty = true })
    end,
  },
}

local function check_pattern(text, pattern)
  return not not string.find(text, pattern)
end

---Get current word in a buffer
---It is aware of the insert mode (move column by -1 if the mode is insert).
---@param winnr integer?
---@return string, integer, integer, integer
local function get_current_word(winnr)
  winnr = winnr or vim.api.nvim_get_current_win()
  -- local bufnr = vim.api.nvim_win_get_buf(winnr)

  -- local line = vim.fn.getline "."
  -- local col = vim.fn.col "."
  -- local mode = vim.fn.mode "."
  local row, line, col, mode
  vim.api.nvim_win_call(winnr, function()
    row = vim.fn.line(".")
    line = vim.fn.getline(".")
    col = vim.fn.col(".")
    mode = vim.fn.mode(".")
  end)

  if mode == "i" then
    -- insert mode has cursor one char to the right
    col = col - 1
  end
  local finish = line:find("[^a-zA-Z0-9_%-]", col)
  -- look forward
  while finish == col do
    col = col + 1
    finish = line:find("[^a-zA-Z0-9_%-]", col)
  end

  if finish == nil then
    finish = #line + 1
  end
  local start = vim.fn.match(line:sub(1, col), [[\k*$]])
  return line:sub(start + 1, finish - 1), row, start, finish
end

-- NOTE: The order of formats can be important, as some identifiers are the same for multiple formats.
--   Take the string 'action' for example. This is a match for both snake_case _and_ camel_case. It's
--   therefore important to place a format between those two so we can correcly change the string.
local default_formats = { "snake_case", "kebab_case", "pascal_case", "screaming_snake_case", "camel_case" }

local get_cycle_function = function(user_formats)
  user_formats = user_formats or default_formats

  local formats = {}
  for _, format in ipairs(user_formats) do
    if type(format) == "string" then
      format = format_table[format]
    end

    if format then
      table.insert(formats, format)
    else
      vim.notify("TS:NodeAction:CycleCase - Format '" .. format .. "' is invalid")
    end
  end

  local function action()
    local text, row, start_col, end_col = get_current_word()

    for i, format in ipairs(formats) do
      if check_pattern(text, format.pattern) then
        local next_i = i + 1 > #formats and 1 or i + 1
        local apply = formats[next_i].apply
        local standardize = format.standardize

        local cycled_text = apply(standardize(text))
        vim.api.nvim_buf_set_text(0, row - 1, start_col, row - 1, end_col - 1, { cycled_text })
        return
      end
    end
  end

  return action
end

return get_cycle_function()
