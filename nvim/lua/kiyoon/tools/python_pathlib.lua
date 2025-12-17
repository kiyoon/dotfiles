local notify = require("kiyoon.notify").notify
local utils = require("kiyoon.utils")
local M = {}

--- replaces os.path with pathlib. Plus, some other function replacements.
--- e.g., `os.path.join(a, b)` => `Path(a) / b`
--- `print(a)` => `logger.info(a)`
--- See ruff PTH code for more details.
M.os_path_to_pathlib = function(wrap_with_path)
  utils.make_dot_repeatable(function()
    if wrap_with_path == nil then
      wrap_with_path = true
    end
    local winnr = 0
    local cursor = vim.api.nvim_win_get_cursor(winnr) -- (row,col): (1,0)-indexed
    local bufnr = vim.api.nvim_get_current_buf()

    local function has_type(node, t)
      return node and node:type() == t
    end
    local function get_text(node)
      return vim.treesitter.get_node_text(node, bufnr)
    end

    ---@type TSNode?
    local node = vim.treesitter.get_node()

    -- Climb up and find a `call` node:
    while (node ~= nil) and node:type() ~= "call" do
      node = node:parent()
    end

    if not node then
      -- Not a call node.
      -- Alternatively, check if the current node is a variable.
      -- Find attribute node (e.g. self.var)
      -- If not found use the current node (identifier, string).
      node = vim.treesitter.get_node()
      while (node ~= nil) and node:type() ~= "attribute" do
        node = node:parent()
      end

      if not node then
        node = vim.treesitter.get_node()
        if node == nil or not vim.list_contains({ "identifier", "string" }, node:type()) then
          notify("Not in a call node, nor is a variable.", vim.log.levels.ERROR, {
            title = "os.path to pathlib.Path",
          })
          return
        end
      end

      -- Wrap the variable with Path() if it's a string or a variable.
      local text = get_text(node)
      local new_text = "Path(" .. text .. ")"
      -- treesitter range is 0-indexed and end-exclusive
      -- nvim_buf_set_text() also uses 0-indexed and end-exclusive indexing
      local srow, scol, erow, ecol = node:range()
      local new_text_list = vim.split(new_text, "\n")
      vim.api.nvim_buf_set_text(0, srow, scol, erow, ecol, new_text_list)

      -- Restore cursor
      vim.api.nvim_win_set_cursor(winnr, cursor)

      return
    end

    assert(node:type() == "call")
    local function_node = node:named_child(0) -- e.g., `os.path.join`
    local arglist_node = node:named_child(1) -- e.g., `a, b`

    local function_name = get_text(function_node)

    local function wrap_with_pathlib(node)
      local text = get_text(node)
      if node:type() == "string" then
        -- obviously string needs to be wrapped with Path(.)
        return "Path(" .. text .. ")"
      elseif M.no_paren_ts_node_types[node:type()] then
        if wrap_with_path then
          return "Path(" .. text .. ")"
        else
          return text
        end
      else
        if wrap_with_path then
          return "Path(" .. text .. ")"
        else
          return "(" .. text .. ")"
        end
      end
    end

    ---os.path functions that require one path argument
    ---e.g. os.path.exists(a) => Path(a).exists()
    local function one_arg_function_to_pathlib(pathlib_function_name)
      if arglist_node:named_child_count() == 0 then
        notify("At least one argument is required.", "error", {
          title = "os.path to pathlib.Path",
        })
        return nil
      end

      return wrap_with_pathlib(arglist_node:named_child(0)) .. "." .. pathlib_function_name
    end

    ---os.path.join to pathlib.Path
    local function osp_join_to_pathlib()
      if arglist_node:named_child_count() == 0 then
        -- no arguments
        notify("At least one argument is required.", "error", {
          title = "os.path.join to pathlib.Path",
        })
        return
      end

      local new_text = wrap_with_pathlib(arglist_node:named_child(0))
      for i = 1, arglist_node:named_child_count() - 1 do
        local arg_node = arglist_node:named_child(i)
        if M.no_paren_ts_node_types[arg_node:type()] then
          new_text = new_text .. " / " .. get_text(arg_node)
        else
          new_text = new_text .. " / (" .. get_text(arg_node) .. ")"
        end
      end
      return new_text
    end

    ---os.path functions that require one path argument and multiple other arguments
    ---e.g. os.path.rename(a, b) => Path(a).rename(b)
    local function multi_arg_function_to_pathlib(pathlib_function_name)
      local new_text = one_arg_function_to_pathlib(pathlib_function_name .. "(")
      if new_text == nil then
        return nil
      end

      local new_args = {}
      for i = 1, arglist_node:named_child_count() - 1 do
        local arg_node = arglist_node:named_child(i)
        table.insert(new_args, get_text(arg_node))
      end
      new_text = new_text .. table.concat(new_args, ", ") .. ")"
      return new_text
    end

    ---Alternative method. Change only the function name.
    ---e.g. print(a) => logger.info(a)
    ---@param change_to string
    ---@return string
    local function change_call_name(change_to)
      local new_text = change_to .. "("
      local new_args = {}
      for i = 0, arglist_node:named_child_count() - 1 do
        local arg_node = arglist_node:named_child(i)
        table.insert(new_args, get_text(arg_node))
      end
      new_text = new_text .. table.concat(new_args, ", ") .. ")"
      return new_text
    end

    local new_text ---@type string | nil
    if function_name == "os.path.join" then
      new_text = osp_join_to_pathlib()
    elseif function_name == "join" then
      new_text = osp_join_to_pathlib()
    elseif function_name == "osp_join" then
      new_text = osp_join_to_pathlib()
    elseif function_name == "os.mkdir" then
      new_text = one_arg_function_to_pathlib("mkdir()")
    elseif function_name == "os.makedirs" then
      if arglist_node:named_child_count() == 0 then
        -- no arguments
        notify("At least one argument is required.", "error", {
          title = "os.makedirs to pathlib.Path",
        })
        return
      end
      new_text = one_arg_function_to_pathlib("mkdir(parents=True")
      for i = 1, arglist_node:named_child_count() - 1 do
        local arg_node = arglist_node:named_child(i)
        new_text = new_text .. ", " .. get_text(arg_node)
      end
      new_text = new_text .. ")"
    elseif function_name == "os.path.exists" then
      new_text = one_arg_function_to_pathlib("exists()")
    elseif function_name == "os.path.abspath" then
      new_text = one_arg_function_to_pathlib("resolve()")
    elseif function_name == "os.remove" then
      new_text = one_arg_function_to_pathlib("unlink()")
    elseif function_name == "os.unlink" then
      new_text = one_arg_function_to_pathlib("unlink()")
    elseif function_name == "os.rmdir" then
      new_text = one_arg_function_to_pathlib("rmdir()")
    elseif function_name == "os.path.expanduser" then
      new_text = one_arg_function_to_pathlib("expanduser()")
    elseif function_name == "os.path.isdir" then
      new_text = one_arg_function_to_pathlib("is_dir()")
    elseif function_name == "os.path.isfile" then
      new_text = one_arg_function_to_pathlib("is_file()")
    elseif function_name == "os.path.islink" then
      new_text = one_arg_function_to_pathlib("is_symlink()")
    elseif function_name == "os.path.isabs" then
      new_text = one_arg_function_to_pathlib("is_absolute()")
    elseif function_name == "os.path.basename" then
      new_text = one_arg_function_to_pathlib("name")
    elseif function_name == "os.path.dirname" then
      new_text = one_arg_function_to_pathlib("parent")
    elseif function_name == "os.stat" then
      new_text = one_arg_function_to_pathlib("stat()")
    elseif function_name == "os.path.getsize" then
      new_text = one_arg_function_to_pathlib("stat().st_size")
    elseif function_name == "os.path.getmtime" then
      new_text = one_arg_function_to_pathlib("stat().st_mtime")
    elseif function_name == "os.path.getctime" then
      new_text = one_arg_function_to_pathlib("stat().st_ctime")
    elseif function_name == "os.path.getatime" then
      new_text = one_arg_function_to_pathlib("stat().st_atime")
    elseif function_name == "os.listdir" then
      new_text = one_arg_function_to_pathlib("iterdir()")
    elseif function_name == "os.rename" then
      new_text = multi_arg_function_to_pathlib("rename")
    elseif function_name == "os.replace" then
      new_text = multi_arg_function_to_pathlib("replace")
    elseif function_name == "os.path.samefile" then
      new_text = multi_arg_function_to_pathlib("samefile")
    elseif function_name == "open" then
      new_text = multi_arg_function_to_pathlib("open")
    elseif function_name == "glob.glob" then
      new_text = multi_arg_function_to_pathlib("glob") -- this is not completely correct
    elseif function_name == "print" then
      if arglist_node:named_child_count() > 1 then
        notify("print() with more than one argument can't be safely converted to logger.info", "warning", {
          title = "os.path to pathlib.Path",
        })
      end
      new_text = change_call_name("logger.info")
    else
      notify("Function `" .. function_name .. "` not recognised.", "error", {
        title = "os.path to pathlib.Path",
        on_open = function(win)
          local buf = vim.api.nvim_win_get_buf(win)
          vim.bo[buf].filetype = "markdown"
        end,
      })
      return
    end

    if new_text == nil then
      return
    end

    -- treesitter range is 0-indexed and end-exclusive
    -- nvim_buf_set_text() also uses 0-indexed and end-exclusive indexing
    local srow, scol, erow, ecol = node:range()
    local new_text_list = vim.split(new_text, "\n")
    vim.api.nvim_buf_set_text(0, srow, scol, erow, ecol, new_text_list)

    -- Restore cursor
    vim.api.nvim_win_set_cursor(winnr, cursor)
  end)
end

local buffer = require("nvim-surround.buffer")
local config = require("nvim-surround.config")

-- Add delimiters around a visual selection.
-- Taken from nvim-surround https://github.com/kylechui/nvim-surround/commit/23f4966aba1d90d9ea4e06dfe3dd7d07b8420611
---@param delimiters string[][]
---@param args? { curpos: position, curswant: number }
local visual_surround = function(delimiters, args)
  -- Get a character and selection from the user
  args = args or {}
  args.curpos = args.curpos or buffer.get_curpos()
  args.curswant = args.curswant or vim.fn.winsaveview().curswant

  -- if vim.fn.visualmode() == "V" then
  --   args.line_mode = true
  -- end

  -- exit visual mode
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)

  local first_pos, last_pos = buffer.get_mark("<"), buffer.get_mark(">")
  if not delimiters or not first_pos or not last_pos then
    return
  end

  if vim.fn.visualmode() == "\22" then -- Visual block mode case (add delimiters to every line)
    if vim.o.selection == "exclusive" then
      last_pos[2] = last_pos[2] - 1
    end
    -- Get (visually) what columns the start and end are located at
    local first_disp = vim.fn.strdisplaywidth(buffer.get_line(first_pos[1]):sub(1, first_pos[2] - 1)) + 1
    local last_disp = vim.fn.strdisplaywidth(buffer.get_line(last_pos[1]):sub(1, last_pos[2] - 1)) + 1
    -- Find the min/max for some variables, since visual blocks can either go diagonally or anti-diagonally
    local mn_disp, mx_disp = math.min(first_disp, last_disp), math.max(first_disp, last_disp)
    local mn_lnum, mx_lnum = math.min(first_pos[1], last_pos[1]), math.max(first_pos[1], last_pos[1])
    -- Check if $ was used in creating the block selection
    local surround_to_end_of_line = args.curswant == vim.v.maxcol
    -- Surround each line with the delimiter pair, last to first (for indexing reasons)
    for lnum = mx_lnum, mn_lnum, -1 do
      local line = buffer.get_line(lnum)
      if surround_to_end_of_line then
        buffer.insert_text({ lnum, #buffer.get_line(lnum) + 1 }, delimiters[2])
      else
        local index = buffer.get_last_byte({ lnum, 1 })[2]
        -- The current display count should be >= the desired one
        while vim.fn.strdisplaywidth(line:sub(1, index)) < mx_disp and index <= #line do
          index = buffer.get_last_byte({ lnum, index + 1 })[2]
        end
        -- Go to the end of the current character
        index = buffer.get_last_byte({ lnum, index })[2]
        buffer.insert_text({ lnum, index + 1 }, delimiters[2])
      end

      local index = 1
      -- The current display count should be <= the desired one
      while vim.fn.strdisplaywidth(line:sub(1, index - 1)) + 1 < mn_disp and index <= #line do
        index = buffer.get_last_byte({ lnum, index })[2] + 1
      end
      if vim.fn.strdisplaywidth(line:sub(1, index - 1)) + 1 > mn_disp then
        -- Go to the beginning of the previous character
        index = buffer.get_first_byte({ lnum, index - 1 })[2]
      end
      buffer.insert_text({ lnum, index }, delimiters[1])
    end
  else -- Regular visual mode case
    if vim.o.selection == "exclusive" then
      last_pos[2] = last_pos[2] - 1
    end

    last_pos = buffer.get_last_byte(last_pos)
    buffer.insert_text({ last_pos[1], last_pos[2] + 1 }, delimiters[2])
    buffer.insert_text(first_pos, delimiters[1])
  end

  config.get_opts().indent_lines(first_pos[1], last_pos[1] + #delimiters[1] + #delimiters[2] - 2)
  buffer.restore_curpos({
    first_pos = first_pos,
    old_pos = args.curpos,
  })
end

M.wrap_selection_with_path = function()
  utils.make_dot_repeatable(function()
    visual_surround({ { "Path(" }, { ")" } }, {})
  end)
end

return M
