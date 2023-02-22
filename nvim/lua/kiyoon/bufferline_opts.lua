local icons = require "kiyoon.icons"

return {
  options = {
    right_mouse_command = "", -- can be a string | function, see "Mouse actions"
    diagnostics = "nvim_lsp",
    always_show_bufferline = false,
    diagnostics_indicator = function(_, _, diag)
      local ret = (diag.error and icons.diagnostics.Error .. diag.error .. " " or "")
        .. (diag.warning and icons.diagnostics.Warn .. diag.warning or "")
      return vim.trim(ret)
    end,
    offsets = {
      {
        filetype = "neo-tree",
        text = "Neo-tree",
        highlight = "Directory",
        text_align = "left",
      },
      {
        filetype = "NvimTree",
        text = "Nvim Tree",
        highlight = "Directory",
        text_align = "left",
      },
    },
  },
}
