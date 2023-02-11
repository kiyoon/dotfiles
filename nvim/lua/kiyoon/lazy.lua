local nvim_treesitter_dev = false
local nvim_treesitter_textobjects_dev = false
local jupynium_dev = false

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
      require "kiyoon.tokyonight"
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
      require "kiyoon.jupynium"
    end,
    dev = jupynium_dev,
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
    -- Similar to tpope/vim-surround
    -- dsf to delete surrounding function call.
    "kylechui/nvim-surround",
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup()
    end,
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
    event = "InsertEnter",
    init = function()
      vim.g.copilot_no_tab_map = true
      vim.cmd [[imap <silent><script><expr> <C-s> copilot#Accept("")]]
    end,
  },
  -- "Exafunction/codeium.vim",
  {
    "nvim-lualine/lualine.nvim",
    cond = (vim.fn.exists "g:started_by_firenvim" or vim.fn.exists "g:vscode") == 0,
    config = function()
      require("lualine").setup {}
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
    event = "BufReadPre",
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
    lazy = true,
    init = function()
      local function open_nvim_tree(data)
        -- buffer is a directory
        local directory = vim.fn.isdirectory(data.file) == 1

        if not directory then
          return
        end

        -- change to the directory
        vim.cmd.cd(data.file)

        -- open the tree
        require("nvim-tree.api").tree.open()
      end

      vim.api.nvim_create_augroup("nvim_tree_open", {})
      vim.api.nvim_create_autocmd({ "VimEnter" }, {
        callback = open_nvim_tree,
        group = "nvim_tree_open",
      })
    end,
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
    "akinsho/bufferline.nvim",
    cond = (vim.fn.exists "g:started_by_firenvim" or vim.fn.exists "g:vscode") == 0,
    config = function()
      require "kiyoon.bufferline"
    end,
  },

  -- Treesitter: Better syntax highlighting, text objects, refactoring, context
  {
    "nvim-treesitter/nvim-treesitter",
    event = "BufReadPre",
    build = ":TSUpdate",
    config = function()
      require "kiyoon.treesitter"
    end,
    dependencies = {
      "RRethy/nvim-treesitter-endwise",
      "andymass/vim-matchup",
      "mrjones2014/nvim-ts-rainbow",
    },
    dev = nvim_treesitter_dev,
  },
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    event = "VeryLazy",
    dev = nvim_treesitter_textobjects_dev,
  },
  {
    "nvim-treesitter/nvim-treesitter-context",
    event = "VeryLazy",
  },
  {
    "nvim-treesitter/playground",
    cmd = "TSPlaygroundToggle",
  },
  {
    "lukas-reineke/indent-blankline.nvim",
    event = "BufReadPost",
    config = function()
      vim.opt.list = true
      --vim.opt.listchars:append "space:⋅"
      --vim.opt.listchars:append "eol:↴"

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
  -- { 'RRethy/nvim-treesitter-textsubjects' }
  --
  -- % to match up if, else, etc. Enabled in the treesitter config below
  {
    "Wansmer/treesj",
    event = "VeryLazy",
    config = function()
      require("treesj").setup { use_default_keymaps = false }
    end,
    keys = {
      { "<space>l", "<cmd>TSJSplit<CR>", desc = "Treesitter Split" },
      { "<space>h", "<cmd>TSJJoin<CR>", desc = "Treesitter Join" },
      -- { "<space>g", "<cmd>TSJToggle<CR>", desc = "Treesitter Toggle" },
    },
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

  -- Motions
  -- {
  --   "phaazon/hop.nvim",
  --   event = "VeryLazy",
  --   config = function()
  --     require("hop").setup()
  --     -- require "kiyoon.hop"
  --   end,
  -- },
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
      { "m", "<Cmd>lua require('tsht').nodes()<CR>", mode = "o", desc = "TreeSitter [M]otion" },
      { "m", ":lua require('tsht').nodes()<CR>", mode = "x", noremap = true, desc = "TreeSitter [M]otion" },
      { "m", "<Cmd>lua require('tsht').move({ side = 'start' })<CR>", desc = "TreeSitter [M]otion" },
      { "M", "m", noremap = true, desc = "[M]ark" },
    },
  },
  {
    "ggandor/leap.nvim",
    event = "VeryLazy",
    dependencies = {
      "tpope/vim-repeat",
      { "ggandor/flit.nvim", opts = { labeled_modes = "nv" } },
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

  -- Dashboard
  {
    "goolord/alpha-nvim",
    event = "VimEnter",
    config = function()
      require "kiyoon.alpha"
    end,
  },

  -- Telescope
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    config = function()
      require "kiyoon.telescope"
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
    },
    event = "CmdlineEnter",
    config = function()
      require "kiyoon.wilder"
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

  {
    "neovim/nvim-lspconfig",
    event = "BufReadPre",
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
      "folke/neodev.nvim",
    },
    config = function()
      require "kiyoon.lsp"
    end,
  },
  {
    "hrsh7th/nvim-cmp",
    -- load cmp on InsertEnter
    event = "InsertEnter",
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
      require "kiyoon.lsp.cmp"
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
  -- {
  --   -- sourcegraph.com integration
  --   -- usage:
  --   -- :edit <sourcegraph url>
  --   "tjdevries/sg.nvim",
  --   build = "cargo build --workspace",
  --   dependencies = { "nvim-lua/plenary.nvim" },
  --   config = function()
  --     require("sg").setup {
  --       on_attach = require("kiyoon.lsp.handlers").on_attach,
  --     }
  --     vim.cmd [[nnoremap <leader>fS <cmd>lua require('sg.telescope').fuzzy_search_results()<CR>]]
  --   end,
  -- },

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
  {
    "jose-elias-alvarez/null-ls.nvim",
    event = "BufReadPre",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    config = function()
      require "kiyoon.lsp.null-ls"
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
    cmd = { "TroubleToggle", "Trouble" },
    keys = {
      { "<leader>xd", "<cmd>TroubleToggle document_diagnostics<cr>", desc = "Document Diagnostics (Trouble)" },
      { "<leader>xw", "<cmd>TroubleToggle workspace_diagnostics<cr>", desc = "Workspace Diagnostics (Trouble)" },
      { "<leader>xl", "<cmd>TroubleToggle loclist<cr>", desc = "Location List (Trouble)" },
      { "<leader>xq", "<cmd>TroubleToggle quickfix<cr>", desc = "Quickfix List (Trouble)" },
      { "gR", "<cmd>TroubleToggle lsp_references<cr>", desc = "LSP references (Trouble)" },
    },
    config = function()
      require("trouble").setup {
        auto_open = false,
        auto_close = true,
        auto_preview = true,
        auto_fold = true,
      }
    end,
  },

  -- DAP (Debugger)
  {
    "mfussenegger/nvim-dap",
    event = "VeryLazy",
    dependencies = {
      "rcarriga/nvim-dap-ui",
      "Weissle/persistent-breakpoints.nvim",
    },
    config = function()
      require "kiyoon.dap"
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
  {
    "theHamsta/nvim-dap-virtual-text",
    event = "VeryLazy",
    config = function()
      require("nvim-dap-virtual-text").setup()
    end,
  },

  {
    "aserowy/tmux.nvim",
    event = "VeryLazy",
    dependencies = {
      "gbprod/yanky.nvim",
      "nvim-telescope/telescope.nvim",
      "nvim-lua/plenary.nvim",
    },
    config = function()
      require "kiyoon.tmux-yanky"
    end,
  },
  {
    "RRethy/vim-illuminate",
    event = "BufReadPost",
    config = function()
      require "kiyoon.illuminate"
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
      timeout = 3000,
      max_height = function()
        return math.floor(vim.o.lines * 0.75)
      end,
      max_width = function()
        return math.floor(vim.o.columns * 0.75)
      end,
    },
  },
  "folke/lsp-colors.nvim",
  {
    "folke/which-key.nvim",
    event = "BufReadPost",
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
    event = "BufReadPost",
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
  -- {
  --   "glacambre/firenvim",
  --   init = function()
  --     if vim.fn.exists "g:started_by_firenvim" then
  --       vim.o.laststatus = 0
  --       vim.cmd [[au BufEnter github.com_*.txt set filetype=markdown]]
  --       vim.g.firenvim_config = {
  --         globalSettings = {
  --           ["<C-w>"] = "noop",
  --           ["<C-n>"] = "default",
  --         },
  --       }
  --     end
  --   end,
  --   build = "firenvim#install(0)",
  -- },
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
      vim.o.statuscolumn = "%@v:lua.ScSa@%s%T%@v:lua.ScLa@%{%v:lua.ScLn()%}%T%@v:lua.ScFa@ %{%v:lua.ScFc()%} %T"
    end,
    config = function()
      -- functions modified from statuscol.nvim
      --- Toggle a (conditional) DAP breakpoint.
      local function toggle_breakpoint(args)
        local status, persistent_breakpoints_api = pcall(require, "persistent-breakpoints.api")
        if not status then
          return
        end
        if args.mods:find "c" then
          persistent_breakpoints_api.set_conditional_breakpoint()
        else
          persistent_breakpoints_api.toggle_breakpoint()
        end
      end

      --- Handler for clicking the line number.
      local function lnum_click(args)
        if args.button == "l" then
          -- Toggle DAP (conditional) breakpoint on (Ctrl-)left click
          toggle_breakpoint(args)
        elseif args.button == "m" then
          vim.cmd "norm! yy" -- Yank on middle click
        elseif args.button == "r" then
          if args.clicks == 2 then
            vim.cmd "norm! dd" -- Cut on double right click
          else
            vim.cmd "norm! p" -- Paste on right click
          end
        end
      end

      require("statuscol").setup {
        relculright = true,
        foldfunc = "builtin",
        separator = " ",
        Lnum = lnum_click,
        DapBreakpointRejected = toggle_breakpoint,
        DapBreakpoint = toggle_breakpoint,
        DapBreakpointCondition = toggle_breakpoint,
        -- when manually setting vim.o.statuscolumn, you shouldn't set below.
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
    event = "VeryLazy",
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
    "dstein64/vim-startuptime",
    cmd = "StartupTime",
    config = function()
      vim.g.startuptime_tries = 10
    end,
  },
  {
    -- "jk or jj to escape insert mode"
    "max397574/better-escape.nvim",
    event = "InsertEnter",
    config = function()
      require("better_escape").setup()
    end,
  },
  {
    "Vimjas/vim-python-pep8-indent",
    ft = "python",
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
}
