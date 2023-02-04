return {
  -- the colorscheme should be available when starting Neovim
  {
    -- For treemux
    "kiyoon/nvim-tree-remote.nvim",
    cond = false,
  },
  -- {
  --   -- For treemux
  --   "folke/tokyonight.nvim",
  --   cond = false,
  -- },
  {
    "folke/tokyonight.nvim",
    lazy = false, -- make sure we load this during startup if it is your main colorscheme
    priority = 1000, -- make sure to load this before all the other start plugins
    config = function()
      -- load the colorscheme here
      require "user.tokyonight"
      vim.cmd.colorscheme "tokyonight-moon"
    end,
  },
  -- {
  --   "Mofiqul/dracula.nvim",
  --   lazy = false,
  --   priority = 1000, -- make sure to load this before all the other start plugins
  --   config = function()
  --     vim.cmd [[hi clear Folded]]
  --     vim.cmd [[hi! link Folded CursorColumn]]
  --    -- vim.cmd [[hi Folded guibg=black ctermbg=black]]
  --     vim.cmd.colorscheme "dracula"
  --   end,
  -- },

  {
    "kiyoon/tmuxsend.vim",
    keys = {
      { "-", "<Plug>(tmuxsend-smart)", mode = { "n", "x" }, desc = "Send to tmux (smart)" },
      { "_", "<Plug>(tmuxsend-plain)", mode = { "n", "x" }, desc = "Send to tmux (plain)" },
      { "<space>-", "<Plug>(tmuxsend-uid-smart)", mode = { "n", "x" }, desc = "Send to tmux w/ pane uid (smart)" },
      { "<space>_", "<Plug>(tmuxsend-uid-plain)", mode = { "n", "x" }, desc = "Send to tmux w/ pane uid (plain)" },
      { "<C-_>", "<Plug>(tmuxsend-tmuxbuffer)", mode = { "n", "x", desc = "Yank to tmux buffer" } },
    },
  },
  {
    "kiyoon/jupynium.nvim",
    -- build = "conda run --no-capture-output -n jupynium pip install .",
    build = "~/bin/miniconda3/envs/jupynium/bin/pip install .",
    enabled = vim.fn.isdirectory(vim.fn.expand "~/bin/miniconda3/envs/jupynium"),
    config = function()
      require "user.jupynium"
    end,
    dev = true,
  },
  {
    "numToStr/Comment.nvim",
    event = "VeryLazy",
    config = function()
      require("Comment").setup()
    end,
  },
  {
    "wookayin/vim-autoimport",
    ft = { "python" },
    keys = {
      { "<M-CR>", ":ImportSymbol<CR>" },
      { "<M-CR>", "<Esc>:ImportSymbol<CR>a", mode = "i" },
    },
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
    "tpope/vim-surround",
    event = "VeryLazy",
  },
  {
    "tpope/vim-sleuth", -- Detect tabstop and shiftwidth automatically
    event = "VeryLazy",
  },
  {
    "kana/vim-textobj-user",
    event = "VeryLazy",
  },
  {
    "kana/vim-textobj-entire",
    event = "VeryLazy",
    dependencies = { "kana/vim-textobj-user" },
  }, -- vie, vae to select entire buffer (file)
  {
    "kana/vim-textobj-fold",
    event = "VeryLazy",
    dependencies = { "kana/vim-textobj-user" },
  }, -- viz, vaz to select fold
  {
    "glts/vim-textobj-comment",
    event = "VeryLazy",
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
  {
    "github/copilot.vim",
    event = "VeryLazy",
  },
  -- "Exafunction/codeium.vim",
  {
    "nvim-lualine/lualine.nvim",
    cond = (vim.fn.exists "g:started_by_firenvim" or vim.fn.exists "g:vscode") == 0,
    config = function()
      require("lualine").setup()
    end,
  },

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
    config = function()
      require("inc_rename").setup()
    end,
  },

  {
    "lewis6991/gitsigns.nvim",
    event = "VeryLazy",
    config = function()
      require("gitsigns").setup {
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
    end,
  },

  {
    "nvim-tree/nvim-tree.lua",
    event = "VeryLazy",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    -- keys = {
    --   "<space>nt",
    -- },
    -- cmds = {
    --   "NvimTreeToggle",
    -- },
    config = function()
      require "user.nvim_tree"
    end,
  },

  {
    "akinsho/bufferline.nvim",
    cond = (vim.fn.exists "g:started_by_firenvim" or vim.fn.exists "g:vscode") == 0,
    config = function()
      require "user.bufferline"
    end,
  },

  -- Treesitter: Better syntax highlighting, text objects, refactoring, context
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    config = function()
      require "user.treesitter"
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    -- dev = true,
  },
  { "nvim-treesitter/nvim-treesitter-context" },
  { "nvim-treesitter/playground" },
  {
    "lukas-reineke/indent-blankline.nvim",
    config = function()
      require "user.indent_blankline"
    end,
  },
  { "kiyoon/treesitter-indent-object.nvim" },
  -- { 'RRethy/nvim-treesitter-textsubjects' }
  --
  -- % to match up if, else, etc. Enabled in the treesitter config below
  { "andymass/vim-matchup" },
  { "mrjones2014/nvim-ts-rainbow" },
  { "Wansmer/treesj" },
  {
    "ckolkey/ts-node-action",
    -- dependencies = { "nvim-treesitter" },
    opts = {},
  },
  {
    "ThePrimeagen/refactoring.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-treesitter/nvim-treesitter",
    },
    keys = {
      {
        "<space>re",
        [[ <Esc><Cmd>lua require('refactoring').refactor('Extract Function')<CR>]],
        mode = "v",
        noremap = true,
        silent = true,
        expr = false,
        desc = "[R]efactor: [E]xtract function",
      },
      {
        "<space>rf",
        [[ <Esc><Cmd>lua require('refactoring').refactor('Extract Function To File')<CR>]],
        mode = "v",
        noremap = true,
        silent = true,
        expr = false,
        desc = "[R]efactor: Extract function to [F]ile",
      },
      {
        "<space>rv",
        [[ <Esc><Cmd>lua require('refactoring').refactor('Extract Variable')<CR>]],
        mode = "v",
        noremap = true,
        silent = true,
        expr = false,
        desc = "[R]efactor: Extract [V]ariable",
      },
      {
        "<space>ri",
        [[ <Esc><Cmd>lua require('refactoring').refactor('Inline Variable')<CR>]],
        mode = { "n", "v" },
        noremap = true,
        silent = true,
        expr = false,
        desc = "[R]efactor: [I]nline variable",
      },
      {
        "<space>rb",
        [[ <Esc><Cmd>lua require('refactoring').refactor('Extract Block')<CR>]],
        mode = "n",
        noremap = true,
        silent = true,
        expr = false,
        desc = "[R]efactor: Extract [B]lock",
      },
      {
        "<space>rbf",
        [[ <Esc><Cmd>lua require('refactoring').refactor('Extract Block To File')<CR>]],
        mode = "n",
        noremap = true,
        silent = true,
        expr = false,
        desc = "[R]efactor: Extract [B]lock to [F]ile",
      },
    },
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

  -- Hop, leap
  {
    "phaazon/hop.nvim",
    config = function()
      require "user.hop"
    end,
  },
  { "mfussenegger/nvim-treehopper" },
  {
    "ggandor/leap.nvim",
    dependencies = {
      "tpope/vim-repeat",
    },
    config = function()
      require("leap").add_default_mappings()
    end,
  },
  {
    "Wansmer/sibling-swap.nvim",
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
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
      "nvim-treesitter/nvim-treesitter",
    },
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

  -- Dashboard
  {
    "goolord/alpha-nvim",
    config = function()
      require "user.alpha"
    end,
  },

  -- Telescope
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    config = function()
      require "user.telescope"
    end,
  },
  {
    "nvim-telescope/telescope-fzf-native.nvim",
    build = "make",
    enabled = vim.fn.executable "make" == 1,
    config = function()
      require("telescope").load_extension "fzf"
    end,
  },

  { "kiyoon/telescope-insert-path.nvim" },

  {
    "nvim-telescope/telescope-live-grep-args.nvim",
    config = function()
      require("telescope").load_extension "live_grep_args"
    end,
  },

  -- Beautiful command menu
  {
    "gelguy/wilder.nvim",
    build = ":UpdateRemotePlugins",
    dependencies = {
      {
        "romgrk/fzy-lua-native",
        build = "make",
      },
      -- {
      --   "nixprime/cpsm",
      --   build = "./install.sh",
      -- },
    },
    event = "CmdlineEnter",
    config = function()
      require "user.wilder"
    end,
  },

  -- LSP
  -- CoC supports out-of-the-box features like inlay hints
  -- which isn't possible with native LSP yet.
  {
    "neoclide/coc.nvim",
    branch = "release",
    cond = vim.g.vscode == nil,
    init = function()
      vim.cmd [[ let b:coc_suggest_disable = 1 ]]
      -- vim.cmd [[ autocmd FileType json let b:coc_suggest_disable = 0 ]]
    end,
    config = function()
      vim.cmd [[
        hi link CocInlayHint Comment
        call coc#add_extension('coc-pyright')
        " CocUninstall coc-sh
        " CocUninstall coc-clangd
        " CocUninstall coc-vimlsp
        " CocUninstall coc-java
        " CocUninstall coc-html
        " CocUninstall coc-css
        " CocUninstall coc-json
        " CocUninstall coc-yaml
        " CocUninstall coc-markdownlint
        " CocUninstall coc-sumneko-lua
        " CocUninstall coc-snippets
        " CocUninstall coc-actions
      ]]
    end,
  },

  -- Mason makes it easier to install language servers
  -- Always load mason, mason-lspconfig and nvim-lspconfig in order.
  { "williamboman/mason.nvim" },
  { "williamboman/mason-lspconfig.nvim" },
  {
    "neovim/nvim-lspconfig",
    event = "BufReadPre",
  },
  { "folke/neodev.nvim" },
  {
    "hrsh7th/nvim-cmp",
    -- load cmp on InsertEnter
    -- event = "InsertEnter",
    -- these dependencies will only be loaded when cmp loads
    -- dependencies are always lazy-loaded unless specified otherwise
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-calc",
      "saadparwaiz1/cmp_luasnip",
      "onsails/lspkind.nvim", -- display icons
    },
    config = function()
      require "user.lsp.cmp"
    end,
  },
  {
    "lvimuser/lsp-inlayhints.nvim",
    -- lazy = false,
    config = function()
      vim.cmd [[hi link LspInlayHint Comment]]
      -- vim.cmd [[hi LspInlayHint guifg=#d8d8d8 guibg=#3a3a3a]]
      require("lsp-inlayhints").setup()

      vim.api.nvim_create_augroup("LspAttach_inlayhints", {})
      vim.api.nvim_create_autocmd("LspAttach", {
        group = "LspAttach_inlayhints",
        callback = function(args)
          if not (args.data and args.data.client_id) then
            return
          end

          local bufnr = args.buf
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          require("lsp-inlayhints").on_attach(client, bufnr)
        end,
      })
    end,
  },
  {
    "ray-x/lsp_signature.nvim",
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
        debug = true, -- set to true to enable debug logging
        log_path = vim.fn.stdpath "cache" .. "/lsp_signature.log", -- log dir when debug is on
        -- default is  ~/.cache/nvim/lsp_signature.log
        verbose = true, -- show debug line number
      }
      require("lsp_signature").setup(cfg)
    end,
  },
  {
    "simrat39/rust-tools.nvim",
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
  {
    "utilyre/barbecue.nvim",
    name = "barbecue",
    version = "*",
    -- event = "VeryLazy",
    dependencies = {
      "SmiteshP/nvim-navic",
      "nvim-tree/nvim-web-devicons", -- optional dependency
    },
    opts = {
      -- configurations go here
    },
  },

  -- Snippets
  {
    "L3MON4D3/LuaSnip",
    version = "v1.x",
    dependencies = {
      "rafamadriz/friendly-snippets",
    },
    config = function()
      require "user.luasnip"
    end,
  },
  {
    "jose-elias-alvarez/null-ls.nvim",
    event = "BufReadPre",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    config = function()
      require "user.lsp.null-ls"
    end,
  },
  {
    "j-hui/fidget.nvim",
    event = "VeryLazy",
    config = function()
      require("fidget").setup()
    end,
  },

  -- LSP diagnostics
  {
    "folke/trouble.nvim",
    config = function()
      require("trouble").setup {
        auto_open = false,
        auto_close = true,
        auto_preview = true,
        auto_fold = true,
      }
      -- Lua
      vim.keymap.set("n", "<leader>xx", "<cmd>TroubleToggle<cr>", { silent = true, noremap = true })
      vim.keymap.set(
        "n",
        "<leader>xw",
        "<cmd>TroubleToggle workspace_diagnostics<cr>",
        { silent = true, noremap = true }
      )
      vim.keymap.set(
        "n",
        "<leader>xd",
        "<cmd>TroubleToggle document_diagnostics<cr>",
        { silent = true, noremap = true }
      )
      vim.keymap.set("n", "<leader>xl", "<cmd>TroubleToggle loclist<cr>", { silent = true, noremap = true })
      vim.keymap.set("n", "<leader>xq", "<cmd>TroubleToggle quickfix<cr>", { silent = true, noremap = true })
      vim.keymap.set("n", "gR", "<cmd>TroubleToggle lsp_references<cr>", { silent = true, noremap = true })
    end,
  },

  -- DAP (Debugger)
  "mfussenegger/nvim-dap",
  "mfussenegger/nvim-dap-python",
  "rcarriga/nvim-dap-ui",
  "Weissle/persistent-breakpoints.nvim",
  {
    "theHamsta/nvim-dap-virtual-text",
    config = function()
      require("nvim-dap-virtual-text").setup()
    end,
  },

  {
    "aserowy/tmux.nvim",
    config = function()
      require("tmux").setup {
        copy_sync = {
          enable = true,
          sync_clipboard = false,
          sync_registers = true,
        },
        resize = {
          enable_default_keybindings = false,
        },
      }
    end,
  },
  {
    "RRethy/vim-illuminate",
    config = function()
      require "user.illuminate"
    end,
  },

  -- UI
  {
    "rcarriga/nvim-notify",
    event = "VeryLazy",
    config = function()
      require("notify").setup {
        stages = "fade_in_slide_out",
      }
      vim.notify = require "notify"
    end,
  },
  "folke/lsp-colors.nvim",
  {
    "folke/which-key.nvim",
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
    "folke/todo-comments.nvim",
    dependencies = "nvim-lua/plenary.nvim",
    config = function()
      require("todo-comments").setup {
        -- your configuration comes here
        -- or leave it empty to use the default settings
        -- refer to the configuration section below
      }
      vim.keymap.set("n", "]t", function()
        require("todo-comments").jump_next()
      end, { desc = "Next todo comment" })

      vim.keymap.set("n", "[t", function()
        require("todo-comments").jump_prev()
      end, { desc = "Previous todo comment" })

      -- You can also specify a list of valid jump keywords

      -- vim.keymap.set("n", "]t", function()
      --   require("todo-comments").jump_next({keywords = { "ERROR", "WARNING" }})
      -- end, { desc = "Next error/warning todo comment" })
    end,
  },

  {
    "iamcco/markdown-preview.nvim",
    ft = "markdown",
    -- build = "cd app && yarn install",
    build = ":call mkdp#util#install()",
  },
  {
    "metakirby5/codi.vim",
    init = function()
      vim.g["codi#interpreters"] = {
        python = {
          bin = "python3",
        },
      }
      vim.g["codi#virtual_text_pos"] = "right_align"
    end,
    cmd = "Codi",
  },
  {
    "glacambre/firenvim",
    init = function()
      if vim.fn.exists "g:started_by_firenvim" then
        vim.o.laststatus = 0
        vim.cmd [[au BufEnter github.com_*.txt set filetype=markdown]]
        vim.g.firenvim_config = {
          globalSettings = {
            ["<C-w>"] = "noop",
            ["<C-n>"] = "default",
          },
        }
      end
    end,
    build = "firenvim#install(0)",
  },
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
  {
    "luukvbaal/statuscol.nvim",
    init = function()
      vim.o.statuscolumn = "%@v:lua.ScSa@%s%T%@v:lua.ScLa@%=%{v:lua.ScLn()}%T%@v:lua.ScFa@ %{%v:lua.ScFc()%} %T"
    end,
    config = function()
      require("statuscol").setup {
        relculright = true,
        foldfunc = "builtin",
        separator = " ",
        -- setopt = true,
        -- order = "SNsFs", -- gitsigns, number, fold, separator
      }
    end,
  },
  {
    "mbbill/undotree",
    cmd = "UndotreeToggle",
    keys = {
      { "<space>u", "<cmd>UndotreeToggle<CR>", mode = { "n", "x" }, desc = "Undotree Toggle" },
    },
  },
  {
    "kevinhwang91/nvim-ufo",
    dependencies = "kevinhwang91/promise-async",
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
      require "user.ufo"
    end,
  },
}
