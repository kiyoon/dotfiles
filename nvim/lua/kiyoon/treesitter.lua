local function treesitter_selection_mode(info)
  -- * query_string: eg '@function.inner'
  -- * method: eg 'v' or 'o'
  --print(info['method'])		-- visual, operator-pending
  -- if vim.startswith(info["query_string"], "@function.") then
  --   return "V"
  -- end
  if vim.startswith(info["query_string"], "@class.") then
    return "V"
  end
  return "v"
end

local function treesitter_incwhitespaces(info)
  -- * query_string: eg '@function.inner'
  -- * selection_mode: eg 'charwise', 'linewise', 'blockwise'
  -- if vim.startswith(info['query_string'], '@function.') then
  --  return false
  -- elseif vim.startswith(info['query_string'], '@comment.') then
  --  return false
  -- end
  return false
end

require("nvim-treesitter.configs").setup({
  -- vim-matchup
  matchup = {
    enable = true, -- mandatory, false will disable the whole extension
  },

  indent = {
    enable = true,
    disable = { "yaml" },
  },

  incremental_selection = {
    enable = true,
    keymaps = {
      init_selection = false, -- set to `false` to disable one of the mappings
      node_incremental = "<cr>",
      scope_incremental = "grc",
      node_decremental = "<bs>",
    },
  },

  -- A list of parser names, or "all"
  ensure_installed = {
    "c",
    "lua",
    "rust",
    "python",
    "bash",
    "json",
    "yaml",
    "html",
    "css",
    "vim",
    "java",
    "javascript",
    "typescript",
    "cpp",
    "toml",
    "dockerfile",
    "gitcommit",
    "git_rebase",
    "gitattributes",
    "cmake",
    "latex",
    "markdown",
    "markdown_inline",
    "php",
    "gitignore",
    "sql",
  },

  -- Install parsers synchronously only in headless (only applied to `ensure_installed`)
  -- https://github.com/nvim-treesitter/nvim-treesitter/issues/3579
  sync_install = #vim.api.nvim_list_uis() == 0,

  -- Automatically install missing parsers when entering buffer
  -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
  auto_install = true,

  -- List of parsers to ignore installing (for "all")
  -- ignore_install = { "javascript" },

  ---- If you need to change the installation directory of the parsers (see -> Advanced Setup)
  -- parser_install_dir = "/some/path/to/store/parsers", -- Remember to run vim.opt.runtimepath:append("/some/path/to/store/parsers")!

  highlight = {
    enable = vim.g.vscode == nil,

    -- NOTE: these are the names of the parsers and not the filetype. (for example if you want to
    -- disable highlighting for the `tex` filetype, you need to include `latex` in this list as this is
    -- the name of the parser)
    -- list of language that will be disabled
    -- disable = { "python", "lua" },
    -- Or use a function for more flexibility, e.g. to disable slow treesitter highlight for large files
    disable = function(lang, buf)
      local disable_langs = { "python", "javascript", "typescript" }
      if vim.list_contains(disable_langs, lang) then
        -- For python etc. disable treesitter highlighting in favour of LSP semantic highlighting.
        -- However, we still want treesitter syntax highlighting for floating windows and injections.

        -- if the buffer is a floating window, enable treesitter
        if vim.bo[buf].buftype == "nofile" then
          return false
        end

        -- if the file extension is .ju.py, enable treesitter
        if vim.api.nvim_buf_get_name(buf):match("%.ju%.py$") then
          return false
        end

        return true
      end

      local max_filesize = 100 * 1024 -- 100 KB
      local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
      if ok and stats and stats.size > max_filesize then
        return true
      end
    end,

    -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
    -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
    -- Using this option may slow down your editor, and you may see some duplicate highlights.
    -- Instead of true it can also be a list of languages
    -- Kiyoon note: it enables additional highlighting such as `git commit`
    additional_vim_regex_highlighting = { "gitcommit" },
  },

  textobjects = {
    select = {
      enable = true,

      -- Automatically jump forward to textobj, similar to targets.vim
      lookahead = true,

      keymaps = {
        -- You can use the capture groups defined in textobjects.scm
        ["am"] = "@function.outer",
        ["im"] = "@function.inner",
        ["al"] = "@class.outer",
        -- You can optionally set descriptions to the mappings (used in the desc parameter of
        -- nvim_buf_set_keymap) which plugins like which-key display
        ["il"] = { query = "@class.inner", desc = "Select inner part of a class region" },
        ["ab"] = "@block.outer",
        ["ib"] = "@block.inner",
        ["ad"] = "@conditional.outer",
        ["id"] = "@conditional.inner",
        ["ao"] = "@loop.outer",
        ["io"] = "@loop.inner",
        ["aa"] = "@parameter.outer",
        ["ia"] = "@parameter.inner",
        ["af"] = "@call.outer",
        ["if"] = "@call.inner",
        ["a/"] = "@comment.outer",
        ["in"] = "@number.inner",
        ["ag"] = "@assignment.outer",
        ["ig"] = "@assignment.inner",
        ["ik"] = "@assignment.lhs",
        ["iv"] = "@assignment.rhs",
        --["ic"] = "@comment.outer",
        --["afr"] = "@frame.outer",
        --["ifr"] = "@frame.inner",
        ["aA"] = "@attribute.outer",
        ["iA"] = "@attribute.inner",
        --["asc"] = "@scopename.inner",
        --["isc"] = "@scopename.inner",
        ["as"] = { query = "@scope", query_group = "locals" },
        ["is"] = "@statement.outer",
        ["aS"] = "@toplevel",
        ["ar"] = { query = "@start", query_group = "aerial" },
      },
      -- You can choose the select mode (default is charwise 'v')
      --
      -- Can also be a function which gets passed a table with the keys
      -- * query_string: eg '@function.inner'
      -- * method: eg 'v' or 'o'
      -- and should return the mode ('v', 'V', or '<c-v>') or a table
      -- mapping query_strings to modes.
      selection_modes = treesitter_selection_mode,
      -- selection_modes = { ["@function.outer"] = "V" },
      -- if you set this to `true` (default is `false`) then any textobject is
      -- extended to include preceding or succeeding whitespace. succeeding
      -- whitespace has priority in order to act similarly to eg the built-in
      -- `ap`.
      --
      -- can also be a function which gets passed a table with the keys
      -- * query_string: eg '@function.inner'
      -- * selection_mode: eg 'v'
      -- and should return true of false
      include_surrounding_whitespace = treesitter_incwhitespaces,
    },
    swap = {
      enable = true,
      swap_next = {
        [")m"] = "@function.outer",
        [")c"] = "@comment.outer",
        [")a"] = "@parameter.inner",
        [")b"] = "@block.outer",
        [")l"] = "@class.outer",
        [")s"] = "@statement.outer",
        [")A"] = "@attribute.outer",
      },
      swap_previous = {
        ["(m"] = "@function.outer",
        ["(c"] = "@comment.outer",
        ["(a"] = "@parameter.inner",
        ["(b"] = "@block.outer",
        ["(l"] = "@class.outer",
        ["(s"] = "@statement.outer",
        ["(A"] = "@attribute.outer",
      },
    },
    move = {
      enable = true,
      set_jumps = true, -- whether to set jumps in the jumplist
      goto_next_start = {
        ["]m"] = "@function.outer",
        ["]f"] = "@call.outer",
        ["]d"] = "@conditional.outer",
        ["]o"] = "@loop.outer",
        ["]s"] = "@statement.outer",
        ["]a"] = "@parameter.outer",
        ["]c"] = "@comment.outer",
        ["]b"] = "@block.outer",
        ["]n"] = "@number.inner",
        ["]g"] = "@assignment.inner",
        ["]l"] = { query = "@class.outer", desc = "next class start" },
        ["]]m"] = "@function.inner",
        ["]]f"] = "@call.inner",
        ["]]d"] = "@conditional.inner",
        ["]]o"] = "@loop.inner",
        ["]]a"] = "@parameter.inner",
        ["]]b"] = "@block.inner",
        ["]]l"] = { query = "@class.inner", desc = "next class start" },
      },
      goto_next_end = {
        ["]M"] = "@function.outer",
        ["]F"] = "@call.outer",
        ["]D"] = "@conditional.outer",
        ["]O"] = "@loop.outer",
        ["]S"] = "@statement.outer",
        ["]A"] = "@parameter.outer",
        ["]C"] = "@comment.outer",
        ["]B"] = "@block.outer",
        ["]L"] = "@class.outer",
        ["]N"] = "@number.inner",
        ["]G"] = "@assignment.inner",
        ["]]M"] = "@function.inner",
        ["]]F"] = "@call.inner",
        ["]]D"] = "@conditional.inner",
        ["]]O"] = "@loop.inner",
        ["]]A"] = "@parameter.inner",
        ["]]B"] = "@block.inner",
        ["]]L"] = "@class.inner",
      },
      goto_previous_start = {
        ["[m"] = "@function.outer",
        ["[f"] = "@call.outer",
        ["[d"] = "@conditional.outer",
        ["[o"] = "@loop.outer",
        ["[s"] = "@statement.outer",
        ["[a"] = "@parameter.outer",
        ["[c"] = "@comment.outer",
        ["[b"] = "@block.outer",
        ["[l"] = "@class.outer",
        ["[n"] = "@number.inner",
        ["[g"] = "@assignment.inner",
        ["[[m"] = "@function.inner",
        ["[[f"] = "@call.inner",
        ["[[d"] = "@conditional.inner",
        ["[[o"] = "@loop.inner",
        ["[[a"] = "@parameter.inner",
        ["[[b"] = "@block.inner",
        ["[[l"] = "@class.inner",
      },
      goto_previous_end = {
        ["[M"] = "@function.outer",
        ["[F"] = "@call.outer",
        ["[D"] = "@conditional.outer",
        ["[O"] = "@loop.outer",
        ["[S"] = "@statement.outer",
        ["[A"] = "@parameter.outer",
        ["[C"] = "@comment.outer",
        ["[B"] = "@block.outer",
        ["[L"] = "@class.outer",
        ["[N"] = "@number.inner",
        ["[G"] = "@assignment.inner",
        ["[[M"] = "@function.inner",
        ["[[F"] = "@call.inner",
        ["[[D"] = "@conditional.inner",
        ["[[O"] = "@loop.inner",
        ["[[A"] = "@parameter.inner",
        ["[[B"] = "@block.inner",
        ["[[L"] = "@class.inner",
      },
    },
    lsp_interop = {
      enable = true,
      floating_preview_opts = { border = "rounded" },
      peek_definition_code = {
        ["<C-t>"] = "@function.outer",
        ["<leader>df"] = "@function.outer",
        ["<leader>dF"] = "@class.outer",
      },
    },
  },

  endwise = {
    enable = true,
  },
})

local ts_repeat_move = require("nvim-treesitter.textobjects.repeatable_move")

-- Repeat movement with ; and ,
-- ensure ; goes forward and , goes backward, regardless of the last direction
vim.keymap.set({ "n", "x", "o" }, ";", ts_repeat_move.repeat_last_move_next)
vim.keymap.set({ "n", "x", "o" }, ",", ts_repeat_move.repeat_last_move_previous)

-- vim way: ; goes to the direction you were moving.
-- vim.keymap.set({ "n", "x", "o" }, ";", ts_repeat_move.repeat_last_move)
-- vim.keymap.set({ "n", "x", "o" }, ",", ts_repeat_move.repeat_last_move_opposite)

-- Make builtin f, F, t, T also repeatable with ; and ,
-- Disabled in favour of folke/flash.nvim
-- vim.keymap.set({ "n", "x", "o" }, "f", ts_repeat_move.builtin_f)
-- vim.keymap.set({ "n", "x", "o" }, "F", ts_repeat_move.builtin_F)
-- vim.keymap.set({ "n", "x", "o" }, "t", ts_repeat_move.builtin_t)
-- vim.keymap.set({ "n", "x", "o" }, "T", ts_repeat_move.builtin_T)
vim.keymap.set({ "n", "x", "o" }, "f", ts_repeat_move.builtin_f_expr, { expr = true })
vim.keymap.set({ "n", "x", "o" }, "F", ts_repeat_move.builtin_F_expr, { expr = true })
vim.keymap.set({ "n", "x", "o" }, "t", ts_repeat_move.builtin_t_expr, { expr = true })
vim.keymap.set({ "n", "x", "o" }, "T", ts_repeat_move.builtin_T_expr, { expr = true })

-- This repeats the last query with always previous direction and to the start of the range.
vim.keymap.set({ "n", "x", "o" }, "<home>", function()
  ts_repeat_move.repeat_last_move({ forward = false, start = true })
end)

-- This repeats the last query with always next direction and to the end of the range.
vim.keymap.set({ "n", "x", "o" }, "<end>", function()
  ts_repeat_move.repeat_last_move({ forward = true, start = false })
end)

local status, wk = pcall(require, "which-key")
if status then
  wk.add({
    { "<space>t", group = "Language-specific [T]ools" },
  })
end
