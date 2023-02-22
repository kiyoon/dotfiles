return {
  on_attach = function(bufnr)
    local gs = package.loaded.gitsigns
    local tstext = require "nvim-treesitter.textobjects.repeatable_move"

    local function map(mode, l, r, opts)
      opts = opts or {}
      opts.buffer = bufnr
      vim.keymap.set(mode, l, r, opts)
    end

    local next_hunk, prev_hunk = tstext.make_repeatable_move_pair(gs.next_hunk, gs.prev_hunk)
    -- Navigation
    map("n", "]h", function()
      if vim.wo.diff then
        return "]h"
      end
      vim.schedule(function()
        next_hunk()
      end)
      return "<Ignore>"
    end, { expr = true })

    map("n", "[h", function()
      if vim.wo.diff then
        return "[h"
      end
      vim.schedule(function()
        prev_hunk()
      end)
      return "<Ignore>"
    end, { expr = true })

    -- Actions
    map({ "n", "v" }, "<leader>hs", ":Gitsigns stage_hunk<CR>")
    map({ "n", "v" }, "<leader>hr", ":Gitsigns reset_hunk<CR>")
    map("n", "<leader>hS", gs.stage_buffer)
    map("n", "<leader>hu", gs.undo_stage_hunk)
    map("n", "<leader>hR", gs.reset_buffer)
    map("n", "<leader>hp", gs.preview_hunk)
    map("n", "<leader>hb", function()
      gs.blame_line { full = true }
    end)
    map("n", "<leader>tb", gs.toggle_current_line_blame)
    map("n", "<leader>hd", gs.diffthis)
    map("n", "<leader>hD", function()
      gs.diffthis "~"
    end)
    map("n", "<leader>td", gs.toggle_deleted)

    -- Text object
    map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>")
  end,
}
