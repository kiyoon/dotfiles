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
