local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local conf = require("telescope.config").values
local scan = require "plenary.scandir"

local M = {}

M.setup = function(setup_config)
  --
end

M.jupynium_kernels = function(opts)
  opts = opts or {}
  local jupynium_finder = function()
    local jupynium_kernels = { "python3", "conda-jupynium" } -- first one is default
    local jupynium_kernels_disp = {
      ["conda-jupynium"] = "Conda: [jupynium]",
      ["python3"] = "Python 3",
    }

    local jupynium_maker = function(entry)
      local disp = jupynium_kernels_disp[entry]

      return { value = entry, display = disp, ordinal = disp }
    end

    return finders.new_table { results = jupynium_kernels, entry_maker = jupynium_maker }
  end

  pickers
    .new(opts, {
      prompt_title = "Select a kernel for Jupynium (Jupyter)",
      results_title = "Jupyter Kernels for Notebook",
      finder = jupynium_finder(),
      sorter = conf.generic_sorter(opts),

      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          print(vim.inspect(selection))
        end)
        return true
      end,
    })
    :find()
end

return M
