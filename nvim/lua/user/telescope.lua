-- local status_ok, project = pcall(require, "project_nvim")
-- if not status_ok then
--   return
-- end
-- project.setup({
--
--   -- detection_methods = { "lsp", "pattern" }, -- NOTE: lsp detection will get annoying with multiple langs in one project
--   detection_methods = { "pattern" },
--
--   -- patterns used to detect root dir, when **"pattern"** is in detection_methods
--   patterns = { ".git", "Makefile", "package.json" },
-- })

local tele_status_ok, telescope = pcall(require, "telescope")
if not tele_status_ok then
  return
end

-- telescope.load_extension('projects')

local path_actions = require "telescope_insert_path"
local trouble = require "trouble.providers.telescope"

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
        ["<c-t>"] = trouble.open_with_trouble,
      },
      i = { ["<c-t>"] = trouble.open_with_trouble },
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
            "40",
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
}

-- get git folder
local function get_git_dir()
  local git_dir = vim.fn.trim(vim.fn.system "git rev-parse --show-toplevel")
  return git_dir
end

local builtin = require "telescope.builtin"

M = {}
M.live_grep_gitdir = function()
  local git_dir = get_git_dir()
  if git_dir == "" then
    builtin.live_grep()
  else
    builtin.live_grep {
      cwd = git_dir,
    }
  end
end

M.grep_string_gitdir = function()
  local git_dir = get_git_dir()
  if git_dir == "" then
    builtin.grep_string()
  else
    builtin.grep_string {
      cwd = git_dir,
    }
  end
end

-- vim.keymap.set({ "n" }, "<leader>ff", builtin.find_files, { noremap = true, silent = true })
vim.keymap.set({ "i" }, "<C-t>", builtin.git_files, { noremap = true, silent = true })
vim.keymap.set(
  { "n" },
  "<leader>ff",
  builtin.git_files,
  { noremap = true, silent = true, desc = "[F]uzzy [F]ind Git [F]iles" }
)
vim.keymap.set({ "n" }, "<leader>fW", builtin.live_grep, { noremap = true, silent = true })
vim.keymap.set({ "n" }, "<leader>fw", M.live_grep_gitdir, { noremap = true, silent = true })
vim.keymap.set(
  { "n" },
  "<leader>fiw",
  M.grep_string_gitdir,
  { noremap = true, silent = true, desc = "Grep [i]nner [w]ord in git dir" }
)
vim.keymap.set({ "n" }, "<leader>fr", builtin.oldfiles, { noremap = true, silent = true })
vim.keymap.set({ "n" }, "<leader>fb", builtin.buffers, { noremap = true, silent = true })
vim.keymap.set({ "n" }, "<leader>fh", builtin.help_tags, { noremap = true, silent = true })
vim.keymap.set(
  { "n" },
  "<leader>fs",
  builtin.current_buffer_fuzzy_find,
  { noremap = true, silent = true, desc = "[F]uzzy [S]earch Current Buffer" }
)

local status, wk = pcall(require, "which-key")
if status then
  wk.register {
    ["<leader>f"] = { name = "Telescope [F]uzzy [F]inder" },
    ["<leader>fi"] = { name = "[I]nner" },
  }
end

return M
