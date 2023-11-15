--- NOTE: I keep all plugins in one file, because I often want to disable half of them when I debug what plugin broke my config.

local nvim_treesitter_dev = false
local nvim_treesitter_textobjects_dev = false
local jupynium_dev = false

local icons = require "kiyoon.icons"

return {
  {
    "folke/tokyonight.nvim",
    lazy = false, -- make sure we load this during startup if it is your main colorscheme
    priority = 1000, -- make sure to load this before all the other start plugins
    config = function()
      require "kiyoon.tokyonight"
      vim.cmd.colorscheme "tokyonight"
    end,
  },
  {
    "kiyoon/tmuxsend.vim",
    keys = {
      {
        "-",
        "<Plug>(tmuxsend-smart)",
        mode = { "n", "x" },
        desc = "Send to tmux (smart)",
      },
      {
        "_",
        "<Plug>(tmuxsend-plain)",
        mode = { "n", "x" },
        desc = "Send to tmux (plain)",
      },
      {
        "<space>-",
        "<Plug>(tmuxsend-uid-smart)",
        mode = { "n", "x" },
        desc = "Send to tmux w/ pane uid (smart)",
      },
      {
        "<space>_",
        "<Plug>(tmuxsend-uid-plain)",
        mode = { "n", "x" },
        desc = "Send to tmux w/ pane uid (plain)",
      },
      { "<C-_>", "<Plug>(tmuxsend-tmuxbuffer)", mode = { "n", "x", desc = "Yank to tmux buffer" } },
    },
  },

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
  {
    "kiyoon/jupynium.nvim",
    build = "conda run --no-capture-output -n jupynium pip install .",
    enabled = vim.fn.isdirectory(vim.fn.expand "~/bin/miniconda3/envs/jupynium"),
    ft = { "python", "markdown" },
    config = function()
      local jupynium_conda_env
      if jupynium_dev then
        jupynium_conda_env = "jupynium_dev"
      else
        jupynium_conda_env = "jupynium"
      end
      require("jupynium").setup {
        default_notebook_URL = "localhost:8888/nbclassic",
        python_host = { "conda", "run", "--no-capture-output", "-n", jupynium_conda_env, "python" },
        jupyter_command = { "conda", "run", "--no-capture-output", "-n", "base", "jupyter" },
        -- firefox_profiles_ini_path = "~/snap/firefox/common/.mozilla/firefox/profiles.ini",
      }
    end,
    dev = jupynium_dev,
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
    end,
  },
  {
    "numToStr/Comment.nvim",
    keys = {
      { "gc", mode = { "n", "x", "o" }, desc = "Comment / uncomment lines" },
      { "gb", mode = { "n", "x", "o" }, desc = "Comment / uncomment a block" },
    },
    config = function()
      require("Comment").setup()
    end,
  },
  -- {
  --   "echasnovski/mini.comment",
  --   config = function()
  --     require("mini.comment").setup()
  --   end,
  -- },
  {
    "tpope/vim-sleuth", -- Detect tabstop and shiftwidth automatically
    event = "VeryLazy",
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
      { "<C-A-i>", [[<cmd>lua require("tmux").resize_top()<cr>]] },
      { "<C-A-u>", [[<cmd>lua require("tmux").resize_bottom()<cr>]] },
      { "<C-A-y>", [[<cmd>lua require("tmux").resize_left()<cr>]] },
      { "<C-A-o>", [[<cmd>lua require("tmux").resize_right()<cr>]] },
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
  {
    "ojroques/nvim-osc52",
    event = "TextYankPost",
    config = function()
      -- Every time you yank to + register, copy it to system clipboard using OSC52.
      -- Use a terminal that supports OSC52,
      -- then the clipboard copy will work even from remote SSH to local machine.
      local function copy()
        if vim.v.event.operator == "y" and vim.v.event.regname == "+" then
          require("osc52").copy_register "+"
        end
      end

      vim.api.nvim_create_autocmd("TextYankPost", { callback = copy })

      -- Because we lazy-load on TextYankPost, the above autocmd will not be executed at first.
      -- So we need to manually call it once.
      copy()
    end,
  },
  {
    "github/copilot.vim",
    event = "InsertEnter",
    cmd = { "Copilot" },
    init = function()
      vim.g.copilot_no_tab_map = true
      vim.cmd [[imap <silent><script><expr> <C-s> copilot#Accept("")]]
    end,
  },
  -- Free copilot alternative
  -- "Exafunction/codeium.vim",
  {
    "jackMort/ChatGPT.nvim",
    init = function()
      local status, wk = pcall(require, "which-key")
      if status then
        wk.register {
          ["<leader>c"] = { name = "ChatGPT" },
        }
      end
    end,
    config = function()
      require("chatgpt").setup {
        -- optional configuration
      }
    end,
    dependencies = {
      "MunifTanjim/nui.nvim",
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
    },
    cmd = {
      "ChatGPT",
      "ChatGPTEditWithInstructions",
      "ChatGPTActAs",
      "ChatGPTRunCustomCodeAction",
    },
    keys = {
      { "<leader>cg", "<cmd>ChatGPT<CR>", mode = { "n", "x" }, desc = "ChatGPT" },
      {
        "<leader>ce",
        "<cmd>ChatGPTEditWithInstructions<CR>",
        mode = { "n", "x" },
        desc = "ChatGPT Edit With Instructions",
      },
      { "<leader>ca", "<cmd>ChatGPTActAs<CR>", mode = { "n", "x" }, desc = "ChatGPT Act As" },
      {
        "<leader>cc",
        "<cmd>ChatGPTRunCustomCodeAction<CR>",
        mode = { "n", "x" },
        desc = "ChatGPT Run Custom Code Action",
      },
    },
  },

  --- NOTE: Git
  {
    "sindrets/diffview.nvim",
    keys = {
      { "<leader>dv", ":DiffviewOpen<CR>" },
      { "<leader>dc", ":DiffviewClose<CR>" },
      { "<leader>dq", ":DiffviewClose<CR>:q<CR>" },
    },
    cmd = { "DiffviewOpen", "DiffviewClose" },
  },
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = require "kiyoon.gitsigns_opts",
  },

  --- NOTE: File tree
  {
    "nvim-tree/nvim-tree.lua",
    lazy = true,
    -- init = function()
    --   local function open_nvim_tree(data)
    --     -- buffer is a directory
    --     local directory = vim.fn.isdirectory(data.file) == 1
    --
    --     if not directory then
    --       return
    --     end
    --
    --     -- change to the directory
    --     vim.cmd.cd(data.file)
    --
    --     -- open the tree
    --     require("nvim-tree.api").tree.open()
    --   end
    --
    --   vim.api.nvim_create_augroup("nvim_tree_open", {})
    --   vim.api.nvim_create_autocmd({ "VimEnter" }, {
    --     callback = open_nvim_tree,
    --     group = "nvim_tree_open",
    --   })
    -- end,
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    keys = {
      {
        "<space>nt",
        "<cmd>NvimTreeToggle<CR>",
        desc = "Toggle NvimTree",
      },
    },
    cmd = {
      "NvimTreeToggle",
      "NvimTreeOpen",
    },
    config = function()
      require "kiyoon.nvim_tree"
    end,
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v2.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons", -- not strictly required, but recommended
      "MunifTanjim/nui.nvim",
    },
    init = function()
      vim.g.neo_tree_remove_legacy_commands = 1
    end,
    cmd = "Neotree",
    keys = {
      { "<space>nn", "<cmd>Neotree<CR>", mode = { "n", "x" }, desc = "[N]eotree" },
    },
  },
  {
    "stevearc/oil.nvim",
    cond = function()
      return vim.fn.isdirectory(vim.fn.expand "%:p") == 1
    end,
    config = function()
      require("oil").setup()
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
        dev = nvim_treesitter_textobjects_dev,
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
      {
        "HiPhish/rainbow-delimiters.nvim",
        config = function()
          -- https://github.com/ayamir/nvimdots/pull/868/files
          local function init_strategy(check_lines)
            return function()
              local errors = 200
              vim.treesitter.get_parser():for_each_tree(function(lt)
                if lt:root():has_error() and errors >= 0 then
                  errors = errors - 1
                end
              end)
              if errors < 0 then
                return nil
              end
              return (check_lines and vim.fn.line "$" > 450) and require("rainbow-delimiters").strategy["global"]
                or require("rainbow-delimiters").strategy["local"]
            end
          end

          vim.g.rainbow_delimiters = {
            strategy = {
              [""] = init_strategy(false),
              c = init_strategy(true),
              cpp = init_strategy(true),
            },
            query = {
              [""] = "rainbow-delimiters",
              latex = "rainbow-blocks",
              javascript = "rainbow-delimiters-ract",
            },
            highlight = {
              "RainbowDelimiterRed",
              "RainbowDelimiterOrange",
              "RainbowDelimiterYellow",
              "RainbowDelimiterGreen",
              "RainbowDelimiterBlue",
              "RainbowDelimiterCyan",
              "RainbowDelimiterViolet",
            },
          }
        end,
      },
    },
    dev = nvim_treesitter_dev,
  },
  {
    "nvim-treesitter/nvim-treesitter-context",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("treesitter-context").setup {
        max_lines = 10,
      }
    end,
  },
  {
    "nvim-treesitter/playground",
    cmd = "TSPlaygroundToggle",
  },
  {
    "lukas-reineke/indent-blankline.nvim",
    tag = "v2.20.8",
    -- main = "ibl",
    -- opts = {},
    event = "BufReadPost",
    config = function()
      vim.opt.list = true
      --vim.opt.listchars:append "space:⋅"
      --vim.opt.listchars:append "eol:↴"

      -- local highlight = {
      --   "RainbowDelimiterRed",
      --   "RainbowDelimiterOrange",
      --   "RainbowDelimiterYellow",
      --   "RainbowDelimiterGreen",
      --   "RainbowDelimiterBlue",
      --   "RainbowDelimiterCyan",
      --   "RainbowDelimiterViolet",
      -- }
      -- local hooks = require "ibl.hooks"
      -- -- create the highlight groups in the highlight setup hook, so they are reset
      -- -- every time the colorscheme changes
      -- hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
      --     vim.api.nvim_set_hl(0, "RainbowRed", { fg = "#E06C75" })
      --     vim.api.nvim_set_hl(0, "RainbowYellow", { fg = "#E5C07B" })
      --     vim.api.nvim_set_hl(0, "RainbowBlue", { fg = "#61AFEF" })
      --     vim.api.nvim_set_hl(0, "RainbowOrange", { fg = "#D19A66" })
      --     vim.api.nvim_set_hl(0, "RainbowGreen", { fg = "#98C379" })
      --     vim.api.nvim_set_hl(0, "RainbowViolet", { fg = "#C678DD" })
      --     vim.api.nvim_set_hl(0, "RainbowCyan", { fg = "#56B6C2" })
      -- end)
      --
      -- require("ibl").setup { scope = { highlight = highlight } }
      -- hooks.register(hooks.type.SCOPE_HIGHLIGHT, hooks.builtin.scope_highlight_from_extmark)
      require("indent_blankline").setup {
        space_char_blankline = " ",
        show_current_context = true,
        show_current_context_start = true,
      }
    end,
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
    "ThePrimeagen/refactoring.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      { "nvim-treesitter/nvim-treesitter", dev = nvim_treesitter_dev },
    },
    keys = require "kiyoon.refactoring_keys",
    init = function()
      local status, wk = pcall(require, "which-key")
      if status then
        wk.register {
          ["<space>r"] = { name = "[R]efactor" },
        }
      end
    end,
    config = function()
      require("refactoring").setup()
    end,
  },
  {
    "abecodes/tabout.nvim",
    event = "InsertEnter",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require("tabout").setup {
        tabkey = "<Tab>",
        backwards_tabkey = "<S-Tab>",
        act_as_tab = true,
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
      }
    end,
  },
  {
    "ziontee113/SelectEase",
    keys = {
      { "<C-A-k>", mode = { "n", "s", "i" } },
      { "<C-A-j>", mode = { "n", "s", "i" } },
      { "<C-A-h>", mode = { "n", "s", "i" } },
      { "<C-A-l>", mode = { "n", "s", "i" } },
      { "<C-A-n>", mode = { "n", "s", "i" } },
      { "<C-A-p>", mode = { "n", "s", "i" } },
    },
    config = function()
      local select_ease = require "SelectEase"

      local lua_query = [[
          ;; query
          ((identifier) @cap)
          ("string_content" @cap)
          ((true) @cap)
          ((false) @cap)
          ]]
      local python_query = [[
          ;; query
          ((identifier) @cap)
          ((string) @cap)
          ]]

      local queries = {
        lua = lua_query,
        python = python_query,
      }

      vim.keymap.set({ "n", "s", "i" }, "<C-A-k>", function()
        select_ease.select_node {
          queries = queries,
          direction = "previous",
          vertical_drill_jump = true,
          -- visual_mode = true, -- if you want Visual Mode instead of Select Mode
        }
      end, {})
      vim.keymap.set({ "n", "s", "i" }, "<C-A-j>", function()
        select_ease.select_node {
          queries = queries,
          direction = "next",
          vertical_drill_jump = true,
          -- visual_mode = true, -- if you want Visual Mode instead of Select Mode
        }
      end, {})
      vim.keymap.set({ "n", "s", "i" }, "<C-A-h>", function()
        select_ease.select_node {
          queries = queries,
          direction = "previous",
          current_line_only = true,
          -- visual_mode = true, -- if you want Visual Mode instead of Select Mode
        }
      end, {})
      vim.keymap.set({ "n", "s", "i" }, "<C-A-l>", function()
        select_ease.select_node {
          queries = queries,
          direction = "next",
          current_line_only = true,
          -- visual_mode = true, -- if you want Visual Mode instead of Select Mode
        }
      end, {})

      -- previous / next node that matches query
      vim.keymap.set({ "n", "s", "i" }, "<C-A-p>", function()
        select_ease.select_node { queries = queries, direction = "previous" }
      end, {})
      vim.keymap.set({ "n", "s", "i" }, "<C-A-n>", function()
        select_ease.select_node { queries = queries, direction = "next" }
      end, {})
    end,
  },
  -- NOTE: Motions
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

  -- Telescope
  {
    "nvim-telescope/telescope.nvim",
    lazy = true,
    cmd = { "Telescope" },
    branch = "0.1.x",
    keys = {
      {
        "<leader>fF",
        "<cmd>lua require('telescope.builtin').git_files()<cr>",
        noremap = true,
        silent = true,
        desc = "[F]uzzy [F]ind Git [F]iles",
      },
      {
        "<leader>ff",
        "<cmd>lua require('telescope.builtin').find_files()<cr>",
        noremap = true,
        silent = true,
        desc = "[F]uzzy [F]ind [F]iles",
      },
      {
        "<leader>fW",
        "<cmd>lua require('telescope.builtin').live_grep()<cr>",
        noremap = true,
        silent = true,
        desc = "[F]ind [W]ord",
      },
      {
        "<leader>fw",
        "<cmd>lua require('kiyoon.telescope').live_grep_gitdir()<cr>",
        noremap = true,
        silent = true,
        desc = "[F]ind [W]ord in git dir",
      },
      {
        "<leader>fiw",
        "<cmd>lua require('kiyoon.telescope').grep_string_gitdir()<cr>",
        noremap = true,
        silent = true,
        desc = "[F]ind [i]nner [w]ord in git dir",
      },
      {
        "<leader>fg",
        "<cmd>lua require('telescope').extensions.live_grep_args.live_grep_args()<cr>",
        desc = "Live grep with args",
      },
      {
        "<leader>fr",
        "<cmd>lua require('telescope.builtin').oldfiles()<cr>",
        noremap = true,
        silent = true,
        desc = "[F]ind [R]ecent files",
      },
      {
        "<leader>fb",
        "<cmd>lua require('telescope.builtin').buffers()<cr>",
        noremap = true,
        silent = true,
        desc = "[F]ind [B]uffers",
      },
      {
        "<leader>fh",
        "<cmd>lua require('telescope.builtin').help_tags()<cr>",
        noremap = true,
        silent = true,
        desc = "[F]ind in vim [H]elp",
      },
      {
        "<leader>fs",
        "<cmd>lua require('telescope.builtin').current_buffer_fuzzy_find()<cr>",
        noremap = true,
        silent = true,
        desc = "[F]uzzy [S]earch Current Buffer",
      },
    },
    init = function()
      local status, wk = pcall(require, "which-key")
      if status then
        wk.register {
          ["<leader>f"] = { name = "Telescope [F]uzzy [F]inder" },
          ["<leader>fi"] = { name = "[I]nner" },
        }
      end
    end,
    dependencies = {
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        cond = function()
          return vim.fn.executable "make" == 1
        end,
        config = function()
          require("telescope").load_extension "fzf"
        end,
      },
      { "kiyoon/telescope-insert-path.nvim" },
      {
        "nvim-telescope/telescope-live-grep-args.nvim",
      },
    },
    config = function()
      require "kiyoon.telescope"
    end,
  },

  --- NOTE: LSP
  --
  -- CoC supports out-of-the-box features like inlay hints
  -- which isn't possible with native LSP yet.
  {
    "neoclide/coc.nvim",
    -- branch = "release",
    commit = "bbaa1d5d1ff3cbd9d26bb37cfda1a990494c4043",
    cond = vim.g.vscode == nil,
    -- event = "BufReadPre",
    ft = "python",
    init = function()
      vim.cmd [[ let b:coc_suggest_disable = 1 ]]
      vim.cmd [[ hi link CocInlayHint Comment ]]
      vim.g.coc_data_home = vim.fn.stdpath "data" .. "/coc"
    end,
    config = function()
      vim.cmd [[
        call coc#add_extension('coc-pyright')
      ]]
    end,
  },

  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    cmd = {
      "Mason",
      "MasonUpdate",
    },
    build = ":MasonUpdate",
    dependencies = {
      {
        "williamboman/mason.nvim",
        dependencies = {
          "williamboman/mason-lspconfig.nvim",
        },
      },
      "folke/neodev.nvim",
    },
    config = function()
      require "kiyoon.lsp"
    end,
  },
  {
    "hrsh7th/nvim-cmp",
    -- event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-calc",
      "saadparwaiz1/cmp_luasnip",
      "onsails/lspkind.nvim", -- display icons
    },
    config = function()
      require "kiyoon.cmp"
    end,
  },
  {
    "lvimuser/lsp-inlayhints.nvim",
    event = "LSPAttach",
    config = function()
      require "kiyoon.lsp.inlayhints"
    end,
  },
  {
    "ray-x/lsp_signature.nvim",
    event = "LSPAttach",
    config = function()
      local cfg = {
        on_attach = function(client, bufnr)
          require("lsp_signature").on_attach({
            bind = true, -- This is mandatory, otherwise border config won't get registered.
            handler_opts = {
              border = "rounded",
            },
          }, bufnr)
        end,
        -- debug = true, -- set to true to enable debug logging
        -- log_path = vim.fn.stdpath "cache" .. "/lsp_signature.log", -- log dir when debug is on
        -- default is  ~/.cache/nvim/lsp_signature.log
        -- verbose = true, -- show debug line number
      }
      require("lsp_signature").setup(cfg)
    end,
  },
  {
    "simrat39/rust-tools.nvim",
    ft = "rust",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "mfussenegger/nvim-dap",
      "neovim/nvim-lspconfig",
    },
    config = function()
      local rt = require "rust-tools"
      rt.setup {
        server = {
          on_attach = function(_, bufnr)
            -- Hover actions
            vim.keymap.set("n", "<C-space>", rt.hover_actions.hover_actions, { buffer = bufnr })
            -- Code action groups
            vim.keymap.set("n", "<Leader>a", rt.code_action_group.code_action_group, { buffer = bufnr })
          end,
        },
      }
    end,
  },
  -- Show current context in lualine (statusline)
  {
    "SmiteshP/nvim-navic",
    lazy = true,
    init = function()
      vim.g.navic_silence = true
      vim.api.nvim_create_augroup("LspAttach_navic", {})
      vim.api.nvim_create_autocmd("LspAttach", {
        group = "LspAttach_navic",
        callback = function(args)
          if not (args.data and args.data.client_id) then
            return
          end

          local bufnr = args.buf
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client.server_capabilities.documentSymbolProvider then
            require("nvim-navic").attach(client, bufnr)
          end
        end,
      })
    end,
    opts = function()
      return {
        separator = " ",
        highlight = true,
        depth_limit = 5,
        icons = icons.kinds,
      }
    end,
  },

  -- Formatting and linting
  {
    "jose-elias-alvarez/null-ls.nvim",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    config = function()
      require "kiyoon.lsp.null-ls"
    end,
  },
  {
    "j-hui/fidget.nvim",
    event = "LSPAttach",
    opts = {},
  },

  {
    "smjonas/inc-rename.nvim",
    keys = {
      {
        "<space>pr",
        function()
          return ":IncRename " .. vim.fn.expand "<cword>"
        end,
        expr = true,
        desc = "LSP (R)ename",
      },
    },
    config = true,
  },

  -- LSP diagnostics
  {
    "folke/trouble.nvim",
    cmd = { "TroubleToggle", "Trouble" },
    opts = {
      use_diagnostic_signs = true,
      auto_open = false,
      auto_close = true,
      auto_preview = true,
      auto_fold = true,
    },
    keys = {
      { "<leader>xd", "<cmd>TroubleToggle document_diagnostics<cr>", desc = "Document Diagnostics (Trouble)" },
      { "<leader>xw", "<cmd>TroubleToggle workspace_diagnostics<cr>", desc = "Workspace Diagnostics (Trouble)" },
      { "<leader>xl", "<cmd>TroubleToggle loclist<cr>", desc = "Location List (Trouble)" },
      { "<leader>xq", "<cmd>TroubleToggle quickfix<cr>", desc = "Quickfix List (Trouble)" },
      { "gR", "<cmd>TroubleToggle lsp_references<cr>", desc = "LSP references (Trouble)" },
    },
    init = function()
      local status, wk = pcall(require, "which-key")
      if status then
        wk.register {
          ["<leader>x"] = { name = "Trouble" },
        }
      end
    end,
  },
  {
    "kosayoda/nvim-lightbulb",
    event = "BufRead",
    config = function()
      require("nvim-lightbulb").setup {
        sign = {
          enabled = true,
          priority = 20, -- higher than LSP diagnostics
        },
        autocmd = {
          enabled = true,
        },
      }
      -- vim.cmd [[autocmd CursorHold,CursorHoldI * lua require'nvim-lightbulb'.update_lightbulb()]]
    end,
  },
  {
    "weilbith/nvim-code-action-menu",
    cmd = "CodeActionMenu",
    keys = {
      { "<space>pa", "<cmd>CodeActionMenu<cr>", desc = "Code [A]ction" },
    },
  },

  --- NOTE: DAP (Debugger)
  {
    "mfussenegger/nvim-dap",
    keys = {
      -- Save breakpoints to file automatically.
      { "<space>db", "<cmd>lua require('persistent-breakpoints.api').toggle_breakpoint()<cr>" },
      { "<space>dB", "<cmd>lua require('persistent-breakpoints.api').set_conditional_breakpoint()<cr>" },
      { "<space>dC", "<cmd>lua require('persistent-breakpoints.api').clear_all_breakpoints()<cr>" },
      { "<space>dc", ":lua require'dap'.continue()<CR>" },
      { "<space>dn", ":lua require'dap'.step_over()<CR>" },
      { "<space>ds", ":lua require'dap'.step_into()<CR>" },
      { "<space>du", ":lua require'dap'.step_out()<CR>" },
      { "<space>dr", ":lua require'dap'.repl.open()<CR>" },
      { "<space>dl", ":lua require'dap'.run_last()<CR>" },
      { "<space>di", ":lua require'dapui'.toggle()<CR>" },
      { "<space>dt", ":lua require'dap'.disconnect()<CR>" },
    },
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "theHamsta/nvim-dap-virtual-text",
    },
    config = function()
      require "kiyoon.dap"
    end,
  },
  {
    "Weissle/persistent-breakpoints.nvim",
    event = "BufReadPost",
    config = function()
      require("persistent-breakpoints").setup {
        load_breakpoints_event = { "BufReadPost" },
      }
    end,
  },
  {
    "mfussenegger/nvim-dap-python",
    ft = "python",
    config = function()
      -- Path to python with debugpy installed
      require("dap-python").setup "python3"
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
      require "kiyoon.luasnip"
    end,
  },

  --- NOTE: UI
  --
  -- Beautiful command menu
  {
    "gelguy/wilder.nvim",
    build = ":UpdateRemotePlugins",
    dependencies = {
      {
        "romgrk/fzy-lua-native",
        -- build = "make",
      },
    },
    event = "CmdlineEnter",
    config = function()
      require "kiyoon.wilder"
    end,
  },
  -- better vim.notify()
  {
    "rcarriga/nvim-notify",
    event = "VeryLazy",
    keys = {
      {
        "<leader>un",
        function()
          require("notify").dismiss { silent = true, pending = true }
        end,
        desc = "Delete all Notifications",
      },
    },
    opts = {
      stages = "fade_in_slide_out",
      timeout = 3000,
      max_height = function()
        return math.floor(vim.o.lines * 0.75)
      end,
      max_width = function()
        return math.floor(vim.o.columns * 0.75)
      end,
    },
    config = function(_, opts)
      require("notify").setup(opts)
      vim.notify = require "notify"
    end,
  },

  -- better vim.ui
  {
    "stevearc/dressing.nvim",
    lazy = true,
    init = function()
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.ui.select = function(...)
        require("lazy").load { plugins = { "dressing.nvim" } }
        return vim.ui.select(...)
      end
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.ui.input = function(...)
        require("lazy").load { plugins = { "dressing.nvim" } }
        return vim.ui.input(...)
      end
    end,
  },
  -- Settings from LazyVim
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = function(plugin)
      return require "kiyoon.lualine_opts"
    end,
  },
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    keys = {
      { "<leader>bp", "<Cmd>BufferLineTogglePin<CR>", desc = "Toggle pin" },
      { "<leader>bP", "<Cmd>BufferLineGroupClose ungrouped<CR>", desc = "Delete non-pinned buffers" },
    },
    opts = require "kiyoon.bufferline_opts",
  },
  {
    "kevinhwang91/nvim-ufo",
    dependencies = "kevinhwang91/promise-async",
    event = { "BufReadPost", "BufNewFile" },
    init = function()
      vim.o.fillchars = [[eob: ,fold: ,foldopen:,foldsep: ,foldclose:]]
      -- vim.o.fillchars = [[foldopen:,foldclose:]]
      vim.o.foldcolumn = "auto:1" -- '0' is not bad
      vim.o.foldminlines = 25
      vim.o.foldlevel = 99 -- Using ufo provider need a large value, feel free to decrease the value
      vim.o.foldlevelstart = 99
      vim.o.foldenable = true
    end,
    config = function()
      require "kiyoon.ufo"
    end,
  },
  {
    "RRethy/vim-illuminate",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require "kiyoon.illuminate"
    end,
  },
  {
    "folke/todo-comments.nvim",
    cmd = { "TodoTrouble", "TodoTelescope" },
    event = { "BufReadPost", "BufNewFile" },
    dependencies = "nvim-lua/plenary.nvim",
    config = function()
      local todo_comments = require "todo-comments"
      todo_comments.setup {
        -- your configuration comes here
        -- or leave it empty to use the default settings
        -- refer to the configuration section below
      }
      local tstext = require "nvim-treesitter.textobjects.repeatable_move"
      local next_todo, prev_todo = tstext.make_repeatable_move_pair(todo_comments.jump_next, todo_comments.jump_prev)
      vim.keymap.set("n", "]t", next_todo, { desc = "Next todo comment" })

      vim.keymap.set("n", "[t", prev_todo, { desc = "Previous todo comment" })

      -- You can also specify a list of valid jump keywords

      -- vim.keymap.set("n", "]t", function()
      --   require("todo-comments").jump_next({keywords = { "ERROR", "WARNING" }})
      -- end, { desc = "Next error/warning todo comment" })
    end,
  },
  -- Dashboard
  {
    "goolord/alpha-nvim",
    event = "VimEnter",
    config = function()
      require "kiyoon.alpha"
    end,
  },
  {
    "luukvbaal/statuscol.nvim",
    config = function()
      require "kiyoon.statuscol"
    end,
  },

  --- NOTE: Utils
  {
    "dstein64/vim-startuptime",
    cmd = "StartupTime",
    config = function()
      vim.g.startuptime_tries = 10
    end,
  },
  {
    "mbbill/undotree",
    cmd = "UndotreeToggle",
    keys = {
      { "<space>u", "<cmd>UndotreeToggle<CR>", mode = { "n", "x" }, desc = "Undotree Toggle" },
    },
  },
  -- search/replace in multiple files
  {
    "windwp/nvim-spectre",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    -- stylua: ignore
    keys = {
      { "<leader>sr", function() require("spectre").open() end, desc = "Replace in files (Spectre)" },
    },
  },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      vim.o.timeout = true
      vim.o.timeoutlen = 600
      require("which-key").setup {
        -- your configuration comes here
        -- or leave it empty to use the default settings
        -- refer to the configuration section below
      }
    end,
  },
  {
    "iamcco/markdown-preview.nvim",
    ft = "markdown",
    -- build = "cd app && yarn install",
    build = ":call mkdp#util#install()",
  },
  {
    "mechatroner/rainbow_csv",
    ft = "csv",
  },
  -- NOTE: for kiyoon/treemux
  -- You need to have them installed but not using them with `cond = false`
  {
    "kiyoon/nvim-tree-remote.nvim",
    cond = false,
  },
  {
    "andythigpen/nvim-coverage",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    config = function()
      require("coverage").setup()
    end,
  },
}
