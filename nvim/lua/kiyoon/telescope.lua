local tele_status_ok, telescope = pcall(require, "telescope")
if not tele_status_ok then
  return
end

local actions = require "telescope.actions"
local path_actions = require "telescope_insert_path"
local trouble = require "trouble.sources.telescope"
local lga_actions = require "telescope-live-grep-args.actions"

telescope.setup {
  defaults = {

    prompt_prefix = " ",
    selection_caret = " ",
    --path_display = { "smart" },
    --    file_ignore_patterns = { ".git/", "node_modules" },

    mappings = {
      n = {
        ["["] = path_actions.insert_reltobufpath_visual,
        ["]"] = path_actions.insert_abspath_visual,
        ["{"] = path_actions.insert_reltobufpath_insert,
        ["}"] = path_actions.insert_abspath_insert,
        ["-"] = path_actions.insert_reltobufpath_normal,
        ["="] = path_actions.insert_abspath_normal,
        ["<c-t>"] = trouble.open,
      },
      i = {
        ["<c-t>"] = trouble.open,
        ["<f2>"] = actions.move_selection_previous,
        ["<f3>"] = actions.move_selection_previous,
        ["<f5>"] = actions.move_selection_next,
        ["<f6>"] = actions.move_selection_next,
      },
    },
    preview = {
      mime_hook = function(filepath, bufnr, opts)
        local is_image = function(filepath)
          local image_extensions = { "png", "jpg", "jpeg", "gif" } -- Supported image formats
          local split_path = vim.split(filepath:lower(), ".", { plain = true })
          local extension = split_path[#split_path]
          return vim.tbl_contains(image_extensions, extension)
        end
        if is_image(filepath) then
          local term = vim.api.nvim_open_term(bufnr, {})
          local function send_output(_, data, _)
            for _, d in ipairs(data) do
              vim.api.nvim_chan_send(term, d .. "\r\n")
            end
          end
          vim.fn.jobstart({
            "viu",
            "-w",
            "60",
            "-b",
            filepath,
          }, {
            on_stdout = send_output,
            stdout_buffered = true,
          })
        else
          require("telescope.previewers.utils").set_preview_message(bufnr, opts.winid, "Binary cannot be previewed")
        end
      end,
    },
  },
  extensions = {
    live_grep_args = {
      auto_quoting = true, -- enable/disable auto-quoting
      -- define mappings, e.g.
      mappings = { -- extend mappings
        i = {
          ["<C-y>"] = lga_actions.quote_prompt(),
          ["<C-i>"] = lga_actions.quote_prompt { postfix = " --iglob " },
        },
      },
      -- ... also accepts theme settings, for example:
      -- theme = "dropdown", -- use dropdown theme
      -- theme = { }, -- use own theme spec
      -- layout_config = { mirror=true }, -- mirror preview pane
    },
  },
}

-- This has to be loaded after telescope.setup, otherwise the keymaps don't get set
telescope.load_extension "live_grep_args"

local builtin = require "telescope.builtin"

M = {}
M.live_grep_gitdir = function()
  local git_dir = vim.fs.root(0, ".git")
  if git_dir == nil then
    builtin.live_grep()
  else
    builtin.live_grep {
      cwd = git_dir,
    }
  end
end

M.grep_string_gitdir = function()
  local git_dir = vim.fs.root(0, ".git")
  if git_dir == nil then
    builtin.grep_string()
  else
    builtin.grep_string {
      cwd = git_dir,
    }
  end
end

return M
