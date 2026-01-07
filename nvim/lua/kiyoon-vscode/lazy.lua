--- NOTE: I keep all plugins in one file, because I often want to disable half of them when I debug what plugin broke my config.

local python_import_dev = false
local nvim_treesitter_dev = false
local nvim_treesitter_textobjects_dev = false
local treesitter_indent_object_dev = false
local use_nvim_treesitter_main_branch = true

return {
  --- NOTE: Python
  {
    "kiyoon/python-import.nvim",
    build = "uv tool install . --force --reinstall",
    keys = {
      {
        "<C-h>",
        function()
          require("python_import.api").add_import_current_word_and_notify()
        end,
        mode = { "i", "n" },
        silent = true,
        desc = "Add python import",
        ft = "python",
      },
      {
        "<C-h>",
        function()
          require("python_import.api").add_import_current_selection_and_notify()
        end,
        mode = "x",
        silent = true,
        desc = "Add python import",
        ft = "python",
      },
      {
        "<space>i",
        function()
          require("python_import.api").add_import_current_word_and_move_cursor()
        end,
        mode = "n",
        silent = true,
        desc = "Add python import and move cursor",
        ft = "python",
      },
      {
        "<space>i",
        function()
          require("python_import.api").add_import_current_selection_and_move_cursor()
        end,
        mode = "x",
        silent = true,
        desc = "Add python import and move cursor",
        ft = "python",
      },
      {
        "<space>tr",
        function()
          require("python_import.api").add_rich_traceback()
        end,
        silent = true,
        desc = "Add rich traceback",
        ft = "python",
      },
    },
    opts = {
      extend_lookup_table = {
        import = {
          -- "tqdm",
        },

        import_as = {
          -- These are the default values. Here for demonstration.
          -- np = "numpy",
          -- pd = "pandas",
        },

        import_from = {
          -- tqdm = nil,
          -- tqdm = "tqdm",
        },

        statement_after_imports = {
          -- logger = { "import my_custom_logger", "", "logger = my_custom_logger.get_logger()" },
        },
      },

      ---Return nil to indicate no match is found and continue with the default lookup
      ---Return a table to stop the lookup and use the returned table as the result
      ---Return an empty table to stop the lookup. This is useful when you want to add to wherever you need to.
      ---@type fun(winnr: integer, word: string, ts_node: TSNode?): string[]?
      custom_function = function(winnr, word, ts_node)
        local bufnr = vim.api.nvim_win_get_buf(winnr)

        local utils = require("python_import.utils")
        if utils.get_cached_first_party_modules(bufnr) ~= nil then
          local first_module = utils.get_cached_first_party_modules(bufnr)[1]
          -- if statement ends with _DIR, import from the first module (from project import PROJECT_DIR)
          if word:match("_DIR$") then
            return { "from " .. first_module .. " import " .. word }
          elseif word == "setup_logging" then
            return { "from " .. first_module .. " import setup_logging" }
          end
        end
      end,
    },
    dev = python_import_dev,
  },
  --- NOTE: Coding
  {
    -- <space>siwie to substitute word from entire buffer
    -- <space>siwip to substitute word from paragraph
    -- <space>siwif to substitute word from function
    -- <space>siwic to substitute word from class
    -- <space>ssip to substitute word from paragraph
    "svermeulen/vim-subversive",
    keys = {
      { "<space>s", "<plug>(SubversiveSubstituteRange)", mode = { "n", "x" } },
      { "<space>ss", "<plug>(SubversiveSubstituteWordRange)", mode = { "n" } },
    },
  },

  {
    -- Similar to tpope/vim-surround
    -- Plus dsf to delete surrounding function call.
    "kylechui/nvim-surround",
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup()

      local right = function()
        local nowCol = vim.api.nvim_eval([[virtcol('.')]])
        local lastCol = vim.api.nvim_eval([[virtcol('$')]]) - 1
        if nowCol == lastCol then
          vim.cmd("startinsert!")
        else
          vim.cmd("norm! a")
        end
      end
      -- map backtick to surround backtick (or alt ` in i mode)
      -- backtick originally goes to the mark, but I don't use it. You can use ` to go to the mark.
      -- 디폴트 `ys`를 선행키로 잡으면 약간의 딜레이가 생긴다.
      vim.keymap.set("n", "`", function()
        vim.cmd.normal("viwS`f`l")
      end, { desc = "Surround backtick" })
      vim.keymap.set("i", "<A-`>", function()
        vim.cmd.normal("hviwS`f`l")
        right()
      end, { silent = false, desc = "Surround backtick" })
      vim.keymap.set("x", "`", function()
        vim.cmd.normal("S`f`")
        right()
      end, { silent = false, desc = "Surround backtick" })

      -- map <F4> to surround with parenthesis for function call (keep cursor at front)
      -- change iskeyword temporarily because we don't want `-` to be included in the word
      vim.keymap.set("n", "<F4>", function()
        local original_iskeyword = vim.opt.iskeyword
        vim.opt.iskeyword = "@,48-57,_,192-255" -- alphabet, _, and European accented characters
        vim.cmd.normal({ "viw", bang = true })
        vim.opt.iskeyword = original_iskeyword
        vim.cmd.normal("S)")
        vim.cmd.startinsert()
      end, { desc = "Surround parens (function call)" })
      vim.keymap.set("i", "<F4>", function()
        local original_iskeyword = vim.opt.iskeyword
        vim.opt.iskeyword = "@,48-57,_,192-255" -- alphabet, _, and European accented characters
        vim.cmd.normal({ "hviw", bang = true })
        vim.opt.iskeyword = original_iskeyword
        vim.cmd.normal("S)")
      end, { silent = false, desc = "Surround parens (function call)" })
      vim.keymap.set("x", "<F4>", function()
        vim.cmd.normal("S)")
        vim.cmd.startinsert()
      end, { silent = false, desc = "Surround parens (function call)" })

      -- map <space>tl to make hyperlink for markdown
      -- vim.keymap.set("n", "<space>tl", function()
      --   vim.cmd.normal("viwS]f]a()")
      --   vim.cmd.startinsert()
      -- end, { desc = "Make markdown hyperlink" })
      -- vim.keymap.set("x", "<space>tl", function()
      --   vim.cmd.normal("S]f]a()")
      --   vim.cmd.startinsert()
      -- end, { desc = "Make markdown hyperlink" })
    end,
  },
  {
    "kana/vim-textobj-entire",
    keys = {
      { "ie", mode = { "o", "x" }, desc = "Select entire buffer (file)" },
      { "ae", mode = { "o", "x" }, desc = "Select entire buffer (file)" },
    },
    dependencies = { "kana/vim-textobj-user" },
  }, -- vie, vae to select entire buffer (file)
  {
    "glts/vim-textobj-comment",
    keys = {
      { "ic", mode = { "o", "x" }, desc = "Select comment block" },
      { "ac", mode = { "o", "x" }, desc = "Select comment block" },
    },
    dependencies = { "kana/vim-textobj-user" },
  }, -- vic, vac

  {
    "chaoren/vim-wordmotion",
    event = "VeryLazy",
    -- use init instead of config to set variables before loading the plugin
    init = function()
      vim.g.wordmotion_prefix = "<space>"
    end,
  },
  ---Yank
  {
    "aserowy/tmux.nvim",
    keys = {
      "<C-h>",
      "<C-j>",
      "<C-k>",
      "<C-l>",
      { "<C-A-i>", [[<cmd>lua require("tmux").resize_top()<cr>]] },
      { "<C-A-u>", [[<cmd>lua require("tmux").resize_bottom()<cr>]] },
      { "<C-A-y>", [[<cmd>lua require("tmux").resize_left()<cr>]] },
      { "<C-A-o>", [[<cmd>lua require("tmux").resize_right()<cr>]] },
      { "<F16>", [[<cmd>lua require("tmux").resize_top()<cr>]], mode = { "n", "i", "x", "s", "o" } }, -- <S-F3>
      { "<F15>", [[<cmd>lua require("tmux").resize_top()<cr>]], mode = { "n", "i", "x", "s", "o" } }, -- <S-F2>
      { "<F18>", [[<cmd>lua require("tmux").resize_bottom()<cr>]], mode = { "n", "i", "x", "s", "o" } }, -- <S-F6>
      { "<F27>", [[<cmd>lua require("tmux").resize_left()<cr>]], mode = { "n", "i", "x", "s", "o" } }, -- <C-F3>
      { "<F26>", [[<cmd>lua require("tmux").resize_left()<cr>]], mode = { "n", "i", "x", "s", "o" } }, -- <C-F2>
      { "<F30>", [[<cmd>lua require("tmux").resize_right()<cr>]], mode = { "n", "i", "x", "s", "o" } }, -- <C-F6>
      "<C-n>",
      "<C-p>",
      -- { '"', mode = { "n", "x" } },
      -- { "<C-r>", mode = { "i" } },
      { "p", mode = { "n", "x", "o", "s" } },
      { "P", mode = { "n", "x", "o", "s" } },
      { "=p", mode = { "n", "x", "o", "s" } },
      { "=P", mode = { "n", "x", "o", "s" } },
      { "y", mode = { "x", "o", "s" } },
      { "d", mode = { "x", "o", "s" } },
      { "c", mode = { "x", "o", "s" } },
      { "Y", mode = { "n", "x", "o", "s" } },
      { "D", mode = { "n", "x", "o", "s" } },
      { "C", mode = { "n", "x", "o", "s" } },
    },
    dependencies = {
      "gbprod/yanky.nvim",
      "nvim-telescope/telescope.nvim",
      "nvim-lua/plenary.nvim",
    },
    config = function()
      require("kiyoon.tmux-yanky")
      -- After initialising yanky, this mapping gets lost so we do this here.
      vim.cmd([[nnoremap Y y$]])
    end,
  },
  --- NOTE: Treesitter: Better syntax highlighting, text objects, refactoring, context
  {
    "nvim-treesitter/nvim-treesitter",
    event = { "BufReadPost", "BufNewFile" },
    branch = "main",
    build = ":TSUpdate",
    -- init = function(plugin)
    --   -- PERF: add nvim-treesitter queries to the rtp and it's custom query predicates early
    --   -- This is needed because a bunch of plugins no longer `require("nvim-treesitter")`, which
    --   -- no longer trigger the **nvim-treesitter** module to be loaded in time.
    --   -- Luckily, the only things that those plugins need are the custom queries, which we make available
    --   -- during startup.
    --   require("lazy.core.loader").add_to_rtp(plugin)
    --   require("nvim-treesitter.query_predicates")
    -- end,
    config = function()
      if not use_nvim_treesitter_main_branch then
        require("kiyoon.treesitter")
      end
    end,
    dev = nvim_treesitter_dev,
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    -- "kiyoon/nvim-treesitter-textobjects",
    branch = "main",
    dev = nvim_treesitter_textobjects_dev,
    init = function()
      -- Disable entire built-in ftplugin mappings to avoid conflicts.
      -- See https://github.com/neovim/neovim/tree/master/runtime/ftplugin for built-in ftplugins.
      vim.g.no_plugin_maps = true

      -- Or, disable built-in vim keymaps to avoid conflicts (add as you like)
      -- vim.g.no_python_maps = true
      -- vim.g.no_ruby_maps = true
      -- vim.g.no_rust_maps = true
      -- vim.g.no_go_maps = true
    end,
    config = function()
      require("kiyoon.ts_textobjs_main")
    end,
  },
  {
    "kiyoon/treesitter-indent-object.nvim",
    dev = treesitter_indent_object_dev,
    dependencies = {
      "lukas-reineke/indent-blankline.nvim",
    },
    keys = {
      {
        "ai",
        function()
          require("treesitter_indent_object.textobj").select_indent_outer()
        end,
        mode = { "x", "o" },
        desc = "Select context-aware indent (outer)",
      },
      {
        "aI",
        function()
          require("treesitter_indent_object.textobj").select_indent_outer(true, "V")
          require("treesitter_indent_object.refiner").include_surrounding_empty_lines()
        end,
        mode = { "x", "o" },
        desc = "Select context-aware indent (outer, line-wise)",
      },
      {
        "ii",
        function()
          require("treesitter_indent_object.textobj").select_indent_inner()
        end,
        mode = { "x", "o" },
        desc = "Select context-aware indent (inner, partial range)",
      },
      {
        "iI",
        function()
          require("treesitter_indent_object.textobj").select_indent_inner(true, "V")
        end,
        mode = { "x", "o" },
        desc = "Select context-aware indent (inner, entire range) in line-wise visual mode",
      },
    },
  },
  {
    "danymat/neogen",
    config = function()
      local custom_templates = require("kiyoon.neogen")
      require("neogen").setup({
        snippet_engine = "luasnip",
        languages = {
          python = {
            template = {
              annotation_convention = "google_docstrings_notypes",
              google_docstrings_notypes = custom_templates.google_docstrings_notypes,
            },
          },
        },
      })
    end,
    -- Uncomment next line if you want to follow only stable versions
    -- version = "*"
    keys = {
      {
        "<space>td",
        "<cmd>lua require('neogen').generate()<CR>",
        desc = "Generate [D]ocstring",
      },
    },
  },
  -- { 'RRethy/nvim-treesitter-textsubjects' }
  --
  -- % to match up if, else, etc. Enabled in the treesitter config below
  {
    "Wansmer/treesj",
    keys = {
      { "<space>l", "<cmd>TSJSplit<CR>", desc = "Treesitter Split" },
      { "<space>h", "<cmd>TSJJoin<CR>", desc = "Treesitter Join" },
      -- { "<space>g", "<cmd>TSJToggle<CR>", desc = "Treesitter Toggle" },
    },
    config = function()
      require("treesj").setup({ use_default_keymaps = false, max_join_length = 1000 })
    end,
  },
  {
    "ckolkey/ts-node-action",
    dependencies = {
      -- "nvim-treesitter",
      "tpope/vim-repeat",
    },
    keys = {
      {
        "<space>ta",
        [[<cmd>lua require("ts-node-action").node_action()<CR>]],
        desc = "Node [A]ction",
      },
    },
  },
  {
    "abecodes/tabout.nvim",
    event = "InsertEnter",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require("tabout").setup({
        -- tabkey = "<Tab>",
        -- backwards_tabkey = "<S-Tab>",
        -- act_as_tab = true,
        tabkey = "<A-w>", -- like 'w'
        backwards_tabkey = "<A-b>", -- like 'b'
        act_as_tab = false,
        act_as_shift_tab = false,
        enable_backwards = true,
        completion = false,
        tabouts = {
          { open = "'", close = "'" },
          { open = '"', close = '"' },
          { open = "`", close = "`" },
          { open = "(", close = ")" },
          { open = "[", close = "]" },
          { open = "{", close = "}" },
        },
        ignore_beginning = true,
        exclude = {},
      })
    end,
  },
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    ---@type Flash.Config
    opts = {
      modes = {
        -- sometimes search results may not exist in a file.
        -- but flash search will accidentally match something else.
        -- e.g. I want to search for "enabled" but it matches "english"
        -- because "en" is in "english" and when you type a it matches the first one.
        -- so I disable search mode.
        search = {
          enabled = false,
        },
        -- Use nvim-treesitter-textobjects' repetable_move instead.
        char = {
          enabled = false,
        },
      },
    },
    -- stylua: ignore
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
      { "m", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
      { "M", "m", noremap = true, desc = "[M]ark" },
      { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
      { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
      { "<c-s>", mode = { "c" }, function() require("flash").toggle() end, desc = "Toggle Flash Search" },
    },
  },

  {
    "Wansmer/sibling-swap.nvim",
    dependencies = {
      { "nvim-treesitter/nvim-treesitter", dev = nvim_treesitter_dev },
    },
    config = function()
      require("sibling-swap").setup({
        use_default_keymaps = false,
      })
    end,
    keys = {
      {
        "<space><space><space>,",
        function()
          require("sibling-swap").swap_with_left_with_opp()
        end,
        mode = "n",
        desc = "Swap with left with opposite",
      },
      {
        "<space><space><space>.",
        function()
          require("sibling-swap").swap_with_right_with_opp()
        end,
        mode = "n",
        desc = "Swap with right with opposite",
      },
    },
  },
  {
    "mizlan/iswap.nvim",
    config = function()
      require("iswap").setup({
        move_cursor = true,
      })
    end,
    keys = {
      { "<leader>s", "<Cmd>ISwap<CR>", mode = "n", desc = "ISwap" },
      { "<leader>S", "<Cmd>ISwapNode<CR>", mode = "n", desc = "ISwapNode" },
      { "<leader><leader>s", "<Cmd>ISwapWith<CR>", mode = "n", desc = "ISwapWith" },
      { "<leader><leader>S", "<Cmd>ISwapNodeWith<CR>", mode = "n", desc = "ISwapNodeWith" },
      { "<space>.", "<Cmd>ISwapWithRight<CR>", mode = "n", desc = "ISwapWithRight" },
      { "<space>,", "<Cmd>ISwapWithLeft<CR>", mode = "n", desc = "ISwapWithLeft" },
      { "<space><space>.", "<Cmd>ISwapNodeWithRight<CR>", mode = "n", desc = "ISwapNodeWithRight" },
      { "<space><space>,", "<Cmd>ISwapNodeWithLeft<CR>", mode = "n", desc = "ISwapNodeWithLeft" },
    },
  },
  {
    "stevearc/aerial.nvim",
    event = "BufReadPre",
    config = function()
      local aerial = require("aerial")
      aerial.setup({
        -- optionally use on_attach to set keymaps when aerial has attached to a buffer
        on_attach = function(bufnr)
          -- Jump forwards/backwards with '{' and '}'
          local anext, aprev
          if use_nvim_treesitter_main_branch then
            local tstext_repeat_move = require("kiyoon.ts_textobjs_main_extended")
            anext, aprev = tstext_repeat_move.make_repeatable_move_pair(aerial.next, aerial.prev)
          else
            local tstext_repeat_move = require("nvim-treesitter.textobjects.repeatable_move")
            anext, aprev = tstext_repeat_move.make_repeatable_move_pair(aerial.next, aerial.prev)
          end
          vim.keymap.set("n", "[r", aprev, { buffer = bufnr, desc = "Aerial prev" })
          vim.keymap.set("n", "]r", anext, { buffer = bufnr, desc = "Aerial next" })
        end,
      })
      -- You probably also want to set a keymap to toggle aerial
      vim.keymap.set("n", "<leader>a", "<cmd>AerialToggle!<CR>", { desc = "Aerial toggle" })
    end,
  },

  -- Snippets
  {
    "L3MON4D3/LuaSnip",
    version = "v2.x",
    event = "InsertEnter",
    dependencies = {
      "rafamadriz/friendly-snippets",
    },
    config = function()
      require("kiyoon.luasnip")
    end,
  },
}
