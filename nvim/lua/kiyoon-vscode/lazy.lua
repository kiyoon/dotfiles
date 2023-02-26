--- NOTE: I keep all plugins in one file, because I often want to disable half of them when I debug what plugin broke my config.

return {
  --- NOTE: Python
  {
    "wookayin/vim-autoimport",
    ft = { "python" },
    keys = {
      { "<M-CR>", ":ImportSymbol<CR>" },
      { "<M-CR>", "<Esc>:ImportSymbol<CR>a", mode = "i" },
    },
  },
  {
    "Vimjas/vim-python-pep8-indent",
    ft = "python",
  },
  {
    "metakirby5/codi.vim",
    cmd = "Codi",
    init = function()
      vim.g["codi#interpreters"] = {
        python = {
          bin = "python3",
        },
      }
      vim.g["codi#virtual_text_pos"] = "right_align"
    end,
  },
  --- NOTE: Coding
  {
    -- "jk or jj to escape insert mode"
    "max397574/better-escape.nvim",
    event = "InsertEnter",
    config = function()
      require("better_escape").setup()
    end,
  },
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
    -- dsf to delete surrounding function call.
    "kylechui/nvim-surround",
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup()
    end,
  },
  {
    -- I don't use autopairs. I only need this for fast-wrap.
    -- <A-e> in insert mode to add closing pair without moving cursor
    -- Similar to nvim-surround, but works in insert mode
    "windwp/nvim-autopairs",
    keys = {
      { "<m-e>", mode = "i" },
    },
    config = function()
      local ap = require "nvim-autopairs"
      ap.setup {
        -- Disable auto fast wrap
        enable_afterquote = false,
        -- <A-e> to manually trigger fast wrap
        fast_wrap = {},
      }

      -- Remove all autopair rules, but keep the fast wrap
      local function manual_trigger(opening, closing)
        local rule
        if ap.get_rule(opening)[1] == nil then
          rule = ap.get_rule(opening)
        else
          rule = ap.get_rule(opening)[1]
        end
        print(vim.inspect(rule))
        rule:use_key("<m-p>"):replace_endpair(function()
          -- repeat the number of characters in the closing pair
          return closing .. string.rep("<left>", #closing)
        end)
      end
      manual_trigger("'", "'")
      manual_trigger('"', '"')
      manual_trigger("`", "`")
      manual_trigger("{", "}")
      manual_trigger("(", ")")
      manual_trigger("[", "]")
      -- local Rule = require "nvim-autopairs.rule"
      -- local function delete_on_key(opening, closing)
      --   ap.add_rule(Rule(opening, closing):use_key("<m-d>"):replace_endpair(function()
      --     return string.rep("<right><bs>", #closing)
      --   end))
      -- end
      -- delete_on_key("'", "',")
      -- delete_on_key("{", "}")
      -- delete_on_key("(", ")")
      -- delete_on_key("[", "]")
    end,
  },
  -- {
  --   "numToStr/Comment.nvim",
  --   keys = {
  --     { "gc", mode = { "n", "x", "o" }, desc = "Comment / uncomment lines" },
  --     { "gb", mode = { "n", "x", "o" }, desc = "Comment / uncomment a block" },
  --   },
  --   config = function()
  --     require("Comment").setup()
  --   end,
  -- },
  {
    "kana/vim-textobj-entire",
    keys = {
      { "ie", mode = { "o", "x" }, desc = "Select entire buffer (file)" },
      { "ae", mode = { "o", "x" }, desc = "Select entire buffer (file)" },
    },
    dependencies = { "kana/vim-textobj-user" },
  }, -- vie, vae to select entire buffer (file)
  {
    "kana/vim-textobj-fold",
    keys = {
      { "iz", mode = { "o", "x" }, desc = "Select fold" },
      { "az", mode = { "o", "x" }, desc = "Select fold" },
    },
    dependencies = { "kana/vim-textobj-user" },
  }, -- viz, vaz to select fold
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
      "<C-n>",
      "<C-p>",
      "p",
      "P",
      "=p",
      "=P",
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
      require "kiyoon.tmux-yanky"
      -- After initialising yanky, this mapping gets lost so we do this here.
      vim.cmd [[nnoremap Y y$]]
    end,
  },
  --- NOTE: Treesitter: Better syntax highlighting, text objects, refactoring, context
  {
    "nvim-treesitter/nvim-treesitter",
    event = { "BufReadPost", "BufNewFile" },
    build = ":TSUpdate",
    config = function()
      require "kiyoon.treesitter"
    end,
    dependencies = {
      {
        "nvim-treesitter/nvim-treesitter-textobjects",
      },
      "RRethy/nvim-treesitter-endwise",
      {
        "andymass/vim-matchup",
        init = function()
          --- Without this, lualine will flicker when matching offscreen
          --- Maybe it happens when cmdheight is set to 0
          vim.g.matchup_matchparen_offscreen = { method = "popup" }
        end,
      },
    },
  },
  {
    "kiyoon/treesitter-indent-object.nvim",
    keys = {
      {
        "ai",
        "<Cmd>lua require'treesitter_indent_object.textobj'.select_indent_outer()<CR>",
        mode = { "x", "o" },
        desc = "Select context-aware indent (outer)",
      },
      {
        "aI",
        "<Cmd>lua require'treesitter_indent_object.textobj'.select_indent_outer(true)<CR>",
        mode = { "x", "o" },
        desc = "Select context-aware indent (outer, line-wise)",
      },
      {
        "ii",
        "<Cmd>lua require'treesitter_indent_object.textobj'.select_indent_inner()<CR>",
        mode = { "x", "o" },
        desc = "Select context-aware indent (inner, partial range)",
      },
      {
        "iI",
        "<Cmd>lua require'treesitter_indent_object.textobj'.select_indent_inner(true)<CR>",
        mode = { "x", "o" },
        desc = "Select context-aware indent (inner, entire range)",
      },
    },
  },
  {
    "danymat/neogen",
    dependencies = "nvim-treesitter/nvim-treesitter",
    config = true,
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
      require("treesj").setup { use_default_keymaps = false }
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
    "mfussenegger/nvim-treehopper",
    dependencies = {
      {
        "phaazon/hop.nvim",
        config = function()
          require("hop").setup()
        end,
      },
    },
    keys = {
      {
        "m",
        "<Cmd>lua require('tsht').nodes()<CR>",
        mode = "o",
        desc = "TreeSitter [M]otion",
      },
      {
        "m",
        ":lua require('tsht').nodes()<CR>",
        mode = "x",
        noremap = true,
        desc = "TreeSitter [M]otion",
      },
      { "m", "<Cmd>lua require('tsht').move({ side = 'start' })<CR>", desc = "TreeSitter [M]otion" },
      { "M", "m", noremap = true, desc = "[M]ark" },
    },
  },
  {
    "ggandor/leap.nvim",
    keys = {
      { "s", mode = { "n", "x", "o" }, desc = "Leap forward to" },
      { "S", mode = { "n", "x", "o" }, desc = "Leap backward to" },
      { "gs", mode = { "n", "x", "o" }, desc = "Leap from windows" },
    },
    dependencies = {
      "tpope/vim-repeat",
    },
    config = function(_, opts)
      local leap = require "leap"
      for k, v in pairs(opts) do
        leap.opts[k] = v
      end
      leap.add_default_mappings()
      vim.keymap.del({ "x", "o" }, "x")
      vim.keymap.del({ "x", "o" }, "X")

      -- x to delete without yanking
      vim.keymap.set({ "n", "x" }, "x", [["_x]], { noremap = true })
    end,
  },
  {
    "ggandor/flit.nvim",
    keys = function()
      ---@type LazyKeys[]
      local ret = {}
      for _, key in ipairs { "f", "F", "t", "T" } do
        ret[#ret + 1] = { key, mode = { "n", "x", "o" }, desc = key }
      end
      return ret
    end,
    opts = { labeled_modes = "nv" },
  },
  {
    "Wansmer/sibling-swap.nvim",
    dependencies = {
      { "nvim-treesitter/nvim-treesitter", dev = nvim_treesitter_dev },
    },
    config = function()
      require("sibling-swap").setup {
        use_default_keymaps = false,
      }
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
    dependencies = {
      { "nvim-treesitter/nvim-treesitter", dev = nvim_treesitter_dev },
    },
    config = function()
      require("iswap").setup {
        move_cursor = true,
      }
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
    -- cmd = "AerialToggle",
    -- keys = {
    --   "[r",
    --   "]r",
    --   {
    --     "<leader>a",
    --     "<Cmd>AerialToggle!<CR>",
    --     desc = "Aerial toggle",
    --   },
    -- },
    config = function()
      local aerial = require "aerial"
      aerial.setup {
        -- optionally use on_attach to set keymaps when aerial has attached to a buffer
        on_attach = function(bufnr)
          -- Jump forwards/backwards with '{' and '}'
          local tstext_repeat_move = require "nvim-treesitter.textobjects.repeatable_move"
          local anext, aprev = tstext_repeat_move.make_repeatable_move_pair(aerial.next, aerial.prev)
          vim.keymap.set("n", "[r", aprev, { buffer = bufnr, desc = "Aerial prev" })
          vim.keymap.set("n", "]r", anext, { buffer = bufnr, desc = "Aerial next" })
        end,
      }
      -- You probably also want to set a keymap to toggle aerial
      vim.keymap.set("n", "<leader>a", "<cmd>AerialToggle!<CR>", { desc = "Aerial toggle" })
    end,
  },

  -- Snippets
  {
    "L3MON4D3/LuaSnip",
    version = "v1.x",
    event = "InsertEnter",
    dependencies = {
      "rafamadriz/friendly-snippets",
    },
    config = function()
      require "kiyoon.luasnip"
    end,
  },
}
