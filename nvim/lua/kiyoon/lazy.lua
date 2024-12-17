--- NOTE: I keep all plugins in one file, because I often want to disable half of them when I debug what plugin broke my config.

local nvim_treesitter_dev = false
local nvim_treesitter_textobjects_dev = false
local jupynium_dev = false
local python_import_dev = false

local icons = require("kiyoon.icons")

return {
  {
    "folke/tokyonight.nvim",
    lazy = false, -- make sure we load this during startup if it is your main colorscheme
    priority = 1000, -- make sure to load this before all the other start plugins
    config = function()
      require("kiyoon.tokyonight")
      vim.cmd.colorscheme("tokyonight")
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
      { "<C-_>", "<Plug>(tmuxsend-tmuxbuffer)", mode = { "n", "x" }, desc = "Yank to tmux buffer" },
    },
  },

  --- NOTE: Python
  {
    -- There are four types of python highlighting.
    -- 1. Default vim python (syntax highlighting)
    -- 2. This plugin (syntax highlighting)
    -- 3. nvim-treesitter (syntax highlighting)
    -- 4. basedpyright (semantic highlighting)
    --
    -- I want to use 4, so I disabled 3 which is distracting. (It's good but too much color)
    -- However, then it was sometimes confusing if f-strings were actually f-strings. (the values were not highlighted)
    -- with this plugin (2), I can see the f-strings are actually f-strings, but it doesn't hurt the 4.
    "vim-python/python-syntax",
    ft = "python",
    init = function()
      vim.g.python_highlight_all = 1
    end,
  },
  {
    "kiyoon/python-import.nvim",
    build = "uv tool install . --force --reinstall",
    keys = {
      {
        "<M-CR>",
        function()
          require("python_import.api").add_import_current_word_and_notify()
        end,
        mode = { "i", "n" },
        silent = true,
        desc = "Add python import",
        ft = "python",
      },
      {
        "<M-CR>",
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
        ---@type string[]
        import = {
          -- "tqdm",
        },

        ---@type table<string, string>
        import_as = {
          -- These are the default values. Here for demonstration.
          -- np = "numpy",
          -- pd = "pandas",
        },

        ---@type table<string, string>
        import_from = {
          -- tqdm = nil,
          -- tqdm = "tqdm",
        },

        ---@type table<string, string[]>
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
  -- {
  --   "Vimjas/vim-python-pep8-indent",
  --   ft = "python",
  -- },
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
    build = "bash scripts/build_with_uv.sh ~/.virtualenvs/jupynium",
    ft = { "python", "markdown" },
    config = function()
      local python_host
      if jupynium_dev then
        python_host = { "conda", "run", "--no-capture-output", "-n", "jupynium_dev", "python" }
      else
        python_host = { "~/.virtualenvs/jupynium/bin/python" }
      end
      require("jupynium").setup({
        default_notebook_URL = "localhost:8888/nbclassic",
        python_host = python_host,
        jupyter_command = { "conda", "run", "--no-capture-output", "-n", "base", "jupyter" },
        -- firefox_profiles_ini_path = "~/snap/firefox/common/.mozilla/firefox/profiles.ini",

        -- notify = {
        --   ignore = {
        --     "download_ipynb",
        --   },
        -- },
      })
    end,
    dev = jupynium_dev,
  },
  -- {
  --   "SUSTech-data/neopyter",
  --   dependencies = {
  --     "nvim-lua/plenary.nvim",
  --     "AbaoFromCUG/websocket.nvim",
  --   },
  --   opts = {
  --     -- auto define autocmd
  --     auto_attach = true,
  --     -- auto connect rpc service
  --     auto_connect = true,
  --     mode = "direct",
  --     -- same with JupyterLab settings
  --     remote_address = "127.0.0.1:19001",
  --     file_pattern = { "*.ju.*" },
  --     on_attach = function(bufnr) end,
  --
  --     highlight = {
  --       enable = true,
  --       shortsighted = true,
  --     },
  --   },
  -- },

  --- NOTE: Coding
  -- {
  --   -- "jk or jj to escape insert mode"
  --   "max397574/better-escape.nvim",
  --   event = "InsertEnter",
  --   config = function()
  --     require("better_escape").setup()
  --   end,
  -- },
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
      local ap = require("nvim-autopairs")
      ap.setup({
        -- Disable auto fast wrap
        enable_afterquote = false,
        -- <A-e> to manually trigger fast wrap
        fast_wrap = {},
      })

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
  --   "tpope/vim-sleuth", -- Detect tabstop and shiftwidth automatically
  --   event = "BufReadPost",
  --   -- config = function()
  --   --   -- script to execute AFTER the plugin is loaded
  --   --   -- vim.defer_fn(function()
  --   --   --   vim.opt.tabstop = 4
  --   --   -- end, 0)
  --   -- end,
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
  {
    "github/copilot.vim",
    -- event = "InsertEnter",
    -- cmd = { "Copilot" },
    init = function()
      vim.g.copilot_no_tab_map = true
      vim.cmd([[imap <silent><script><expr> <C-s> copilot#Accept("")]])
      vim.cmd([[imap <silent><script><expr> <F7> copilot#Accept("")]])

      -- delete word in INSERT mode
      -- you can use <C-w> but this is for consistency with github copilot
      -- using <A-Right> to accept a word.
      vim.cmd([[inoremap <A-Left> <C-\><C-o>db]])
      vim.cmd([[inoremap <A-BS> <C-\><C-o>db]]) -- consistency with zsh and bash
      vim.cmd([[inoremap <F2> <C-\><C-o>db]])
      vim.cmd([[inoremap <F3> <C-\><C-o>db]])
      vim.cmd([[inoremap <F5> <Plug>(copilot-accept-word)]])
      vim.cmd([[inoremap <F6> <Plug>(copilot-accept-word)]])
    end,
  },
  -- Free copilot alternative
  -- "Exafunction/codeium.vim",
  {
    "Bryley/neoai.nvim",
    dependencies = {
      "MunifTanjim/nui.nvim",
    },
    cmd = {
      "NeoAI",
      "NeoAIOpen",
      "NeoAIClose",
      "NeoAIToggle",
      "NeoAIContext",
      "NeoAIContextOpen",
      "NeoAIContextClose",
      "NeoAIInject",
      "NeoAIInjectCode",
      "NeoAIInjectContext",
      "NeoAIInjectContextCode",
      "InjectCommitMessage",
      "TextifyCommitMessage",
    },
    keys = {
      { "<space>as", mode = { "x" }, desc = "summarize text" },
    },
    config = function()
      require("neoai").setup({
        models = {
          {
            name = "openai",
            model = "gpt-4o",
            params = nil,
          },
        },
        shortcuts = {
          {
            name = "textify",
            key = "<space>as",
            desc = "fix text with AI",
            use_context = true,
            prompt = [[
                Please rewrite the text to make it more readable, clear,
                concise, and fix any grammatical, punctuation, or spelling
                errors
            ]],
            modes = { "x" },
            strip_function = nil,
          },
        },
      })
      require("kiyoon.neoai")
    end,
  },

  {
    "robitx/gp.nvim",
    init = function()
      local status, wk = pcall(require, "which-key")
      if status then
        wk.add({
          { "<leader>c", group = "ChatGPT" },
        })
      end
    end,
    cmd = {
      "GpChatNew",
      "GpChatPaste",
      "GpRewrite",
      "GpAppend",
      "GpAgent",
      "GpNextAgent",
    },
    keys = {
      { "<leader>cg", "<cmd>GpChatNew<CR>", mode = { "n", "x" }, desc = "ChatGPT" },
      {
        "<leader>ce",
        "<cmd>GpRewrite<CR>",
        mode = { "n", "x" },
        desc = "ChatGPT Edit With Instructions",
      },
    },
    config = function()
      require("gp").setup({
        openai_api_key = { "pass", "API-dear/openai" },
        agents = {
          {
            name = "ChatGPT4o",
            chat = true,
            command = false,
            -- string with model name or table with model name and parameters
            model = { model = "gpt-4o", temperature = 1.1, top_p = 1 },
            -- system prompt (use this to specify the persona/role of the AI)
            system_prompt = "You are a general AI assistant.\n\n"
              .. "The user provided the additional info about how they would like you to respond:\n\n"
              .. "- If you're unsure don't guess and say you don't know instead.\n"
              .. "- Ask question if you need clarification to provide better answer.\n"
              .. "- Think deeply and carefully from first principles step by step.\n"
              .. "- Zoom out first to see the big picture and then zoom in to details.\n"
              .. "- Use Socratic method to improve your thinking and coding skills.\n"
              .. "- Don't elide any code from your output if the answer requires coding.\n"
              .. "- Take a deep breath; You've got this!\n",
          },
          {
            name = "ChatGPT3-5-Turbo",
            chat = true,
            command = false,
            -- string with model name or table with model name and parameters
            model = { model = "gpt-3.5-turbo", temperature = 1.1, top_p = 1 },
            -- system prompt (use this to specify the persona/role of the AI)
            system_prompt = "You are a general AI assistant.\n\n"
              .. "The user provided the additional info about how they would like you to respond:\n\n"
              .. "- If you're unsure don't guess and say you don't know instead.\n"
              .. "- Ask question if you need clarification to provide better answer.\n"
              .. "- Think deeply and carefully from first principles step by step.\n"
              .. "- Zoom out first to see the big picture and then zoom in to details.\n"
              .. "- Use Socratic method to improve your thinking and coding skills.\n"
              .. "- Don't elide any code from your output if the answer requires coding.\n"
              .. "- Take a deep breath; You've got this!\n",
          },
          {
            name = "CodeGPT4o",
            chat = false,
            command = true,
            -- string with model name or table with model name and parameters
            model = { model = "gpt-4o", temperature = 0.8, top_p = 1 },
            -- system prompt (use this to specify the persona/role of the AI)
            system_prompt = "You are an AI working as a code editor.\n\n"
              .. "Please AVOID COMMENTARY OUTSIDE OF THE SNIPPET RESPONSE.\n"
              .. "START AND END YOUR ANSWER WITH:\n\n```",
          },
          {
            name = "CodeGPT3-5-Turbo",
            chat = false,
            command = true,
            -- string with model name or table with model name and parameters
            model = { model = "gpt-3.5-turbo", temperature = 0.8, top_p = 1 },
            -- system prompt (use this to specify the persona/role of the AI)
            system_prompt = "You are an AI working as a code editor.\n\n"
              .. "Please AVOID COMMENTARY OUTSIDE OF THE SNIPPET RESPONSE.\n"
              .. "START AND END YOUR ANSWER WITH:\n\n```",
          },
        },
      })
    end,
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
    opts = require("kiyoon.gitsigns_opts"),
    -- add at least one keys so that which-key can register the leader key
    keys = {
      {
        "<leader>hb",
      },
    },
    init = function()
      local status, wk = pcall(require, "which-key")
      if status then
        wk.add({
          { "<leader>h", group = "Gitsigns" },
        })
      end
    end,
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
      require("kiyoon.nvim_tree")
    end,
  },
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
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
      { "<space>nn", "<cmd>Neotree toggle<CR>", mode = { "n", "x" }, desc = "[N]eotree toggle" },
    },
  },
  {
    "stevearc/oil.nvim",
    -- cond = function()
    --   return vim.fn.isdirectory(vim.fn.expand "%:p") == 1
    -- end,
    config = function()
      require("oil").setup({
        keymaps = {
          ["\\"] = { "actions.select", opts = { vertical = true }, desc = "Open the entry in a vertical split" },
          ["|"] = { "actions.select", opts = { horizontal = true }, desc = "Open the entry in a horizontal split" },
          ["<C-r>"] = "actions.refresh",
          ["g?"] = "actions.show_help",
          ["<CR>"] = "actions.select",
          ["<C-t>"] = { "actions.select", opts = { tab = true }, desc = "Open the entry in new tab" },
          ["<C-p>"] = "actions.preview",
          ["<C-c>"] = "actions.close",
          ["-"] = "actions.parent",
          ["_"] = "actions.open_cwd",
          ["`"] = "actions.cd",
          ["~"] = { "actions.cd", opts = { scope = "tab" }, desc = ":tcd to the current oil directory" },
          ["gs"] = "actions.change_sort",
          ["gx"] = "actions.open_external",
          ["g."] = "actions.toggle_hidden",
          ["g\\"] = "actions.toggle_trash",
        },
        use_default_keymaps = false,
      })
    end,
  },

  --- NOTE: Treesitter: Better syntax highlighting, text objects, refactoring, context
  {
    "nvim-treesitter/nvim-treesitter",
    event = { "BufReadPost", "BufNewFile" },
    build = ":TSUpdate",
    init = function(plugin)
      -- PERF: add nvim-treesitter queries to the rtp and it's custom query predicates early
      -- This is needed because a bunch of plugins no longer `require("nvim-treesitter")`, which
      -- no longer trigger the **nvim-treesitter** module to be loaded in time.
      -- Luckily, the only things that those plugins need are the custom queries, which we make available
      -- during startup.
      require("lazy.core.loader").add_to_rtp(plugin)
      require("nvim-treesitter.query_predicates")
    end,
    config = function()
      require("kiyoon.treesitter")
    end,
    dependencies = {
      {
        "nvim-treesitter/nvim-treesitter-textobjects",
        -- "kiyoon/nvim-treesitter-textobjects",
        -- branch = "fix/builtin_find",
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
          ---@param threshold number @Use global strategy if nr of lines exceeds this value
          local function init_strategy(threshold)
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
              return vim.fn.line("$") > threshold and require("rainbow-delimiters").strategy["global"]
                or require("rainbow-delimiters").strategy["local"]
            end
          end

          vim.g.rainbow_delimiters = {
            strategy = {
              [""] = init_strategy(500),
              c = init_strategy(200),
              cpp = init_strategy(200),
              lua = init_strategy(500),
              vimdoc = init_strategy(300),
              vim = init_strategy(300),
              markdown = require("rainbow-delimiters").strategy["global"], -- markdown parser is slow
            },
            query = {
              [""] = "rainbow-delimiters",
              latex = "rainbow-blocks",
              javascript = "rainbow-delimiters-react",
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
    -- This commit is the parent of https://github.com/nvim-treesitter/nvim-treesitter-context/pull/316
    -- which introduced showing context in multiple lines.
    -- However, it becomes too long and I prefer the old behaviour.
    commit = "e5676455c7e68069c6299facd4b5c4eb80cc4e9d",

    config = function()
      require("treesitter-context").setup({
        max_lines = 7,
      })
    end,
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
      require("indent_blankline").setup({
        space_char_blankline = " ",
        show_current_context = true,
        show_current_context_start = true,
      })
    end,
  },
  {
    "kiyoon/treesitter-indent-object.nvim",
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
  -- {
  --   -- Alternative to indent-blankline and treesitter-indent-object
  --   "folke/snacks.nvim",
  --   opts = {
  --     indent = {
  --       -- your indent configuration comes here
  --       -- or leave it empty to use the default settings
  --       -- refer to the configuration section below
  --       indent = {
  --         -- only_scope = true, -- only show indent guides of the scope
  --       },
  --       scope = {
  --         enabled = true,
  --         underline = true,
  --       },
  --       animate = {
  --         enabled = false,
  --       },
  --     },
  --     scope = {
  --       enabled = true,
  --       -- These keymaps will only be set if the `scope` plugin is enabled.
  --       -- Alternatively, you can set them manually in your config,
  --       -- using the `Snacks.scope.textobject` and `Snacks.scope.jump` functions.
  --     },
  --   },
  -- },
  {
    "danymat/neogen",
    dependencies = "nvim-treesitter/nvim-treesitter",
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
  -- % to match up if, else, etc. Enabled in the treesitter config below
  {
    "Wansmer/treesj",
    keys = {
      { "<space>l", "<cmd>TSJSplit<CR>", desc = "Treesitter Split" },
      { "<space>h", "<cmd>TSJJoin<CR>", desc = "Treesitter Join" },
      -- { "<space>g", "<cmd>TSJToggle<CR>", desc = "Treesitter Toggle" },
    },
    config = function()
      require("treesj").setup({ use_default_keymaps = false })
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
    keys = require("kiyoon.refactoring_keys"),
    init = function()
      local status, wk = pcall(require, "which-key")
      if status then
        wk.add({
          { "<space>r", group = "[R]efactor" },
        })
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
      require("tabout").setup({
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
      })
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
      local select_ease = require("SelectEase")

      local lua_query = [[
          ;; query
          ((identifier) @cap)
          ((string_content) @cap)
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
        select_ease.select_node({
          queries = queries,
          direction = "previous",
          vertical_drill_jump = true,
          -- visual_mode = true, -- if you want Visual Mode instead of Select Mode
        })
      end, {})
      vim.keymap.set({ "n", "s", "i" }, "<C-A-j>", function()
        select_ease.select_node({
          queries = queries,
          direction = "next",
          vertical_drill_jump = true,
          -- visual_mode = true, -- if you want Visual Mode instead of Select Mode
        })
      end, {})
      vim.keymap.set({ "n", "s", "i" }, "<C-A-h>", function()
        select_ease.select_node({
          queries = queries,
          direction = "previous",
          current_line_only = true,
          -- visual_mode = true, -- if you want Visual Mode instead of Select Mode
        })
      end, {})
      vim.keymap.set({ "n", "s", "i" }, "<C-A-l>", function()
        select_ease.select_node({
          queries = queries,
          direction = "next",
          current_line_only = true,
          -- visual_mode = true, -- if you want Visual Mode instead of Select Mode
        })
      end, {})

      -- previous / next node that matches query
      vim.keymap.set({ "n", "s", "i" }, "<C-A-p>", function()
        select_ease.select_node({ queries = queries, direction = "previous" })
      end, {})
      vim.keymap.set({ "n", "s", "i" }, "<C-A-n>", function()
        select_ease.select_node({ queries = queries, direction = "next" })
      end, {})
    end,
  },
  -- NOTE: Motions
  -- {
  --   "mfussenegger/nvim-treehopper",
  --   dependencies = {
  --     {
  --       "phaazon/hop.nvim",
  --       config = function()
  --         require("hop").setup()
  --       end,
  --     },
  --   },
  --   keys = {
  --     {
  --       "m",
  --       "<Cmd>lua require('tsht').nodes()<CR>",
  --       mode = "o",
  --       desc = "TreeSitter [M]otion",
  --     },
  --     {
  --       "m",
  --       ":lua require('tsht').nodes()<CR>",
  --       mode = "x",
  --       noremap = true,
  --       desc = "TreeSitter [M]otion",
  --     },
  --     { "m", "<Cmd>lua require('tsht').move({ side = 'start' })<CR>", desc = "TreeSitter [M]otion" },
  --     { "M", "m", noremap = true, desc = "[M]ark" },
  --   },
  -- },

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

  -- {
  --   "ggandor/leap.nvim",
  --   keys = {
  --     { "s", mode = { "n", "x", "o" }, desc = "Leap forward to" },
  --     { "S", mode = { "n", "x", "o" }, desc = "Leap backward to" },
  --     { "gs", mode = { "n", "x", "o" }, desc = "Leap from windows" },
  --   },
  --   dependencies = {
  --     "tpope/vim-repeat",
  --   },
  --   config = function(_, opts)
  --     local leap = require "leap"
  --     for k, v in pairs(opts) do
  --       leap.opts[k] = v
  --     end
  --     leap.add_default_mappings()
  --     vim.keymap.del({ "x", "o" }, "x")
  --     vim.keymap.del({ "x", "o" }, "X")
  --
  --     -- x to delete without yanking
  --     vim.keymap.set({ "n", "x" }, "x", [["_x]], { noremap = true })
  --   end,
  -- },
  -- {
  --   "ggandor/flit.nvim",
  --   keys = function()
  --     ---@type LazyKeys[]
  --     local ret = {}
  --     for _, key in ipairs { "f", "F", "t", "T" } do
  --       ret[#ret + 1] = { key, mode = { "n", "x", "o" }, desc = key }
  --     end
  --     return ret
  --   end,
  --   opts = { labeled_modes = "nv" },
  -- },
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
    dependencies = {
      { "nvim-treesitter/nvim-treesitter", dev = nvim_treesitter_dev },
    },
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
          local tstext_repeat_move = require("nvim-treesitter.textobjects.repeatable_move")
          local anext, aprev = tstext_repeat_move.make_repeatable_move_pair(aerial.next, aerial.prev)
          vim.keymap.set("n", "[r", aprev, { buffer = bufnr, desc = "Aerial prev" })
          vim.keymap.set("n", "]r", anext, { buffer = bufnr, desc = "Aerial next" })
        end,
      })
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
        wk.add({
          { "<leader>f", group = "Telescope [F]uzzy [F]inder" },
          { "<leader>fi", group = "[I]nner" },
        })
      end
    end,
    dependencies = {
      {
        "nvim-telescope/telescope-fzf-native.nvim",
        build = "make",
        cond = function()
          return vim.fn.executable("make") == 1
        end,
        config = function()
          require("telescope").load_extension("fzf")
        end,
      },
      { "kiyoon/telescope-insert-path.nvim" },
      {
        "nvim-telescope/telescope-live-grep-args.nvim",
      },
    },
    config = function()
      require("kiyoon.telescope")
    end,
  },

  --- NOTE: LSP
  --
  -- CoC supports out-of-the-box features like inlay hints
  -- which isn't possible with native LSP yet.
  -- {
  --   "neoclide/coc.nvim",
  --   -- branch = "release",
  --   commit = "bbaa1d5d1ff3cbd9d26bb37cfda1a990494c4043",
  --   ft = "python",
  --   init = function()
  --     vim.cmd [[ hi link CocInlayHint LspInlayHint ]]
  --     vim.g.coc_data_home = vim.fn.stdpath "data" .. "/coc"
  --   end,
  --   config = function()
  --     vim.cmd [[
  --       call coc#add_extension('coc-pyright')
  --     ]]
  --   end,
  -- },

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
      {
        "folke/lazydev.nvim",
        ft = "lua",
        opts = {
          library = {
            -- Library items can be absolute paths
            "~/project/nvim-treesitter-textobjects",
            "~/project/jupynium.nvim",
            "~/project/python-import.nvim",
            -- Or relative, which means they will be resolved as a plugin
            -- "LazyVim",
            -- When relative, you can also provide a path to the library in the plugin dir
            -- "luvit-meta/library", -- see below
            { path = "luvit-meta/library", words = { "vim%.uv" } },
          },
        },
      },
      -- { "saghen/blink.cmp" },
    },
    config = function()
      require("kiyoon.lsp")
    end,
  },
  -- optional for lazydev.nvim: `vim.uv` typings. Plugin will never be loaded
  { "Bilal2453/luvit-meta", lazy = true },
  {
    "hrsh7th/nvim-cmp",
    -- event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "hrsh7th/cmp-calc",
      "hrsh7th/cmp-emoji",
      "saadparwaiz1/cmp_luasnip",
      "onsails/lspkind.nvim", -- display icons
    },
    config = function()
      require("kiyoon.cmp")
    end,
  },
  -- {
  --   "saghen/blink.cmp",
  --   lazy = false, -- lazy loading handled internally
  --   -- optional: provides snippets for the snippet source
  --   dependencies = {
  --     "rafamadriz/friendly-snippets",
  --   },
  --   -- use a release tag to download pre-built binaries
  --   version = "v0.*",
  --
  --   ---@module 'blink.cmp'
  --   ---@type blink.cmp.Config
  --   opts = {
  --     -- 'default' for mappings similar to built-in completion
  --     -- 'super-tab' for mappings similar to vscode (tab to accept, arrow keys to navigate)
  --     -- 'enter' for mappings similar to 'super-tab' but with 'enter' to accept
  --     -- see the "default configuration" section below for full documentation on how to define
  --     -- your own keymap.
  --     keymap = { preset = "default" },
  --
  --     highlight = {
  --       -- sets the fallback highlight groups to nvim-cmp's highlight groups
  --       -- useful for when your theme doesn't support blink.cmp
  --       -- will be removed in a future release, assuming themes add support
  --       use_nvim_cmp_as_default = true,
  --     },
  --     -- set to 'mono' for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
  --     -- adjusts spacing to ensure icons are aligned
  --     nerd_font_variant = "mono",
  --
  --     -- experimental auto-brackets support
  --     -- accept = { auto_brackets = { enabled = true } }
  --
  --     -- experimental signature help support
  --     -- trigger = { signature_help = { enabled = true } }
  --
  --     windows = {
  --       autocomplete = {
  --         -- Controls how the completion items are selected
  --         -- 'preselect' will automatically select the first item in the completion list
  --         -- 'manual' will not select any item by default
  --         -- 'auto_insert' will not select any item by default, and insert the completion items automatically when selecting them
  --         selection = "auto_insert",
  --       },
  --     },
  --   },
  --   -- allows extending the enabled_providers array elsewhere in your config
  --   -- without having to redefining it
  --   opts_extend = { "sources.completion.enabled_providers" },
  -- },
  -- {
  --   "kiyoon/lsp-inlayhints.nvim",
  --   event = "LSPAttach",
  --   -- init = function()
  --   --   vim.cmd [[hi link LspInlayHint Comment]]
  --   --   vim.cmd [[hi LspInlayHint guifg=#d8d8d8 guibg=#3a3a3a]]
  --   -- end,
  --   config = function()
  --     require "kiyoon.lsp.inlayhints"
  --   end,
  -- },
  {
    "chrisgrieser/nvim-lsp-endhints",
    event = "LspAttach",
    config = function()
      require("lsp-endhints").setup({
        label = {
          truncateAtChars = 40,
        },
      })
      require("kiyoon.lsp.inlayhints")
    end,
  },
  {
    "ray-x/lsp_signature.nvim",
    -- event = "LSPAttach",
    event = "BufReadPre",
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
    "mrcjkb/rustaceanvim",
    version = "^5", -- Recommended
    ft = { "rust" },
    init = function()
      vim.g.rustaceanvim = {
        -- Plugin configuration
        tools = {},
        -- LSP configuration
        server = {
          on_attach = function(client, bufnr)
            -- you can also put keymaps in here
          end,
          default_settings = {
            -- rust-analyzer language server configuration
            ["rust-analyzer"] = {
              check = {
                command = "clippy",
              },
            },
          },
        },
        -- DAP configuration
        dap = {},
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
      require("kiyoon.lsp.null-ls")
    end,
  },
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
      {
        -- Customize or remove this keymap to your liking
        "<space>pf",
        function()
          require("conform").format({ async = true, lsp_fallback = true })
        end,
        mode = "",
        desc = "Format buffer",
      },
    },
    -- Everything in opts will be passed to setup()
    opts = {
      -- Define your formatters
      formatters_by_ft = {
        lua = { "stylua" },
        -- python = { "isort", "black" },
        python = { "ruff_fix", "ruff_format" },
        javascript = { { "prettierd", "prettier" } },
        typescript = { { "prettierd", "prettier" } },
        html = { { "prettierd", "prettier" } },
        yaml = { "prettier" },
        json = { "prettier" },
        c = { "clang-format" },
        cpp = { "clang-format" },
      },
      -- Set up format-on-save
      format_on_save = { timeout_ms = 2000, lsp_fallback = true },
      -- Customize formatters
      formatters = {
        shfmt = {
          prepend_args = { "-i", "2" },
        },
        -- isort = {
        --   prepend_args = { "--profile", "black" },
        -- },
        ruff_fix = {
          -- I: isort
          -- D20, D21: docstring
          -- UP00: upgrade to python 3.10
          -- UP032: f-string over str.format
          -- UP034: extraneous parentheses
          -- ruff:[RUF100]: unused noqa

          -- IGNORED:
          -- ruff:[D212]: multi-line docstring summary should start at the first line (in favor of D213, second line)
          prepend_args = {
            "check",
            "--select",
            "I,D20,D21,UP00,UP032,UP034",
            "--ignore",
            "D212",
          },
        },
        prettier = {
          prepend_args = {
            "--no-semi",
            "--single-quote",
            "--jsx-single-quote",
            -- "--plugin",
            -- vim.fn.expand "$HOME/.local/lib/node_modules/prettier-plugin-toml/lib/index.cjs",
          },
        },
      },
    },
    init = function()
      -- If you want the formatexpr, here is the place to set it
      vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
    end,
  },
  {
    "j-hui/fidget.nvim",
    event = "LSPAttach",
    opts = { -- In options table:
      progress = {
        ignore = {
          "null-ls",
        },
      },
    },
  },

  {
    "smjonas/inc-rename.nvim",
    keys = {
      {
        "<space>pR",
        function()
          return ":IncRename " .. vim.fn.expand("<cword>")
        end,
        expr = true,
        desc = "[R]ename with live preview",
      },
      {
        -- Rename in normal mode, like
        -- https://blog.viktomas.com/graph/neovim-lsp-rename-normal-mode-keymaps/
        -- but without the messy autocmd
        -- and you can return to the command line with <C-c> and see the preview
        "<space>pr",
        function()
          vim.api.nvim_feedkeys(":IncRename " .. vim.fn.expand("<cword>"), "n", false)
          local key = vim.api.nvim_replace_termcodes("<C-f>", true, false, true)
          vim.api.nvim_feedkeys(key, "c", false)
          vim.api.nvim_feedkeys("b", "n", false)
        end,
        desc = "[R]ename in normal mode",
      },
    },
    config = true,
  },

  -- LSP diagnostics
  {
    "folke/trouble.nvim",
    cmd = { "Trouble" },
    opts = {
      use_diagnostic_signs = true,
      auto_open = false,
      auto_close = true,
      auto_preview = true,
      auto_fold = true,
    },
    keys = {
      {
        "<leader>xx",
        "<cmd>Trouble diagnostics toggle<cr>",
        desc = "Diagnostics (Trouble)",
      },
      {
        "<leader>xX",
        "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
        desc = "Buffer Diagnostics (Trouble)",
      },
      {
        "<leader>cs",
        "<cmd>Trouble symbols toggle focus=false<cr>",
        desc = "Symbols (Trouble)",
      },
      {
        "<leader>cl",
        "<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
        desc = "LSP Definitions / references / ... (Trouble)",
      },
      {
        "<leader>xL",
        "<cmd>Trouble loclist toggle<cr>",
        desc = "Location List (Trouble)",
      },
      {
        "<leader>xQ",
        "<cmd>Trouble qflist toggle<cr>",
        desc = "Quickfix List (Trouble)",
      },
    },
    init = function()
      local status, wk = pcall(require, "which-key")
      if status then
        wk.add({
          { "<leader>x", group = "Trouble" },
        })
      end
    end,
  },
  {
    "kosayoda/nvim-lightbulb",
    event = "BufRead",
    config = function()
      require("nvim-lightbulb").setup({
        priority = 20, -- higher than LSP diagnostics
        sign = {
          enabled = true,
        },
        float = {
          enabled = false,
        },
        autocmd = {
          enabled = true,
        },
      })
      -- vim.cmd [[autocmd CursorHold,CursorHoldI * lua require'nvim-lightbulb'.update_lightbulb()]]
    end,
  },
  {
    "aznhe21/actions-preview.nvim",
    keys = {
      {
        "<space>pa",
        function()
          require("actions-preview").code_actions()
        end,
        desc = "Code [A]ction",
      },
    },
    opts = {
      telescope = {
        sorting_strategy = "ascending",
        layout_strategy = "vertical",
        layout_config = {
          width = 0.8,
          height = 0.9,
          prompt_position = "top",
          preview_cutoff = 20,
          preview_height = function(_, _, max_lines)
            return max_lines - 15
          end,
        },
      },
    },
  },

  --- NOTE: DAP (Debugger)
  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
    config = function()
      local dapui = require("dapui")
      local dap = require("dap")
      dapui.setup({
        expand_lines = true,
        icons = { expanded = "", collapsed = "", circular = "" },
        mappings = {
          -- Use a table to apply multiple mappings
          expand = { "<CR>", "<2-LeftMouse>" },
          open = "o",
          remove = "d",
          edit = "e",
          repl = "r",
          toggle = "t",
        },
        layouts = {
          {
            elements = {
              { id = "scopes", size = 0.33 },
              { id = "breakpoints", size = 0.17 },
              { id = "stacks", size = 0.25 },
              { id = "watches", size = 0.25 },
            },
            size = 0.33,
            position = "right",
          },
          {
            elements = {
              { id = "repl", size = 0.45 },
              { id = "console", size = 0.55 },
            },
            size = 0.27,
            position = "bottom",
          },
        },
        floating = {
          max_height = 0.9,
          max_width = 0.5, -- Floats will be treated as percentage of your screen.
          border = vim.g.border_chars, -- Border style. Can be 'single', 'double' or 'rounded'
          mappings = {
            close = { "q", "<Esc>" },
          },
        },
      })

      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end

      -- dap.listeners.before.event_terminated["dapui_config"] = function()
      --   dapui.close()
      -- end
      --
      -- dap.listeners.before.event_exited["dapui_config"] = function()
      --   dapui.close()
      -- end
    end,
  },
  {
    "theHamsta/nvim-dap-virtual-text",
    dependencies = {
      "mfussenegger/nvim-dap",
      "nvim-treesitter/nvim-treesitter",
    },
    opts = {},
  },
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
      {
        "<space>do",
        "<cmd>lua require('kiyoon.dap').load_files_with_breakpoints()<cr>",
        desc = "Load files with breakpoints",
      },
    },
    init = function()
      vim.fn.sign_define("DapBreakpoint", { text = "", texthl = "DiagnosticSignError", linehl = "", numhl = "" })
      vim.fn.sign_define(
        "DapBreakpointCondition",
        { text = "", texthl = "DiagnosticSignWarn", linehl = "", numhl = "" }
      )
    end,
    config = function()
      require("kiyoon.dap")
    end,
  },
  {
    "kiyoon/persistent-breakpoints.nvim",
    event = "BufReadPost",
    config = function()
      require("persistent-breakpoints").setup({
        load_breakpoints_event = { "BufReadPost" },
      })
    end,
  },
  {
    "mfussenegger/nvim-dap-python",
    ft = "python",
    config = function()
      -- Path to python with debugpy installed
      require("dap-python").setup(vim.g.python3_host_prog)
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
      require("kiyoon.wilder")
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
          require("notify").dismiss({ silent = true, pending = true })
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
      vim.notify = require("notify")
    end,
  },

  -- better vim.ui
  {
    "stevearc/dressing.nvim",
    lazy = true,
    init = function()
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.ui.select = function(...)
        require("lazy").load({ plugins = { "dressing.nvim" } })
        return vim.ui.select(...)
      end
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.ui.input = function(...)
        require("lazy").load({ plugins = { "dressing.nvim" } })
        return vim.ui.input(...)
      end
    end,
  },
  -- Settings from LazyVim
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    opts = function(plugin)
      return require("kiyoon.lualine_opts")
    end,
  },
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    keys = {
      { "<leader>bp", "<Cmd>BufferLineTogglePin<CR>", desc = "Toggle pin" },
      { "<leader>bP", "<Cmd>BufferLineGroupClose ungrouped<CR>", desc = "Delete non-pinned buffers" },
    },
    opts = require("kiyoon.bufferline_opts"),
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
      require("kiyoon.ufo")
    end,
  },
  {
    "RRethy/vim-illuminate",
    event = { "BufReadPost", "BufNewFile" },
    config = function()
      require("kiyoon.illuminate")
    end,
  },
  {
    "folke/todo-comments.nvim",
    cmd = { "TodoTrouble", "TodoTelescope" },
    event = { "BufReadPost", "BufNewFile" },
    dependencies = "nvim-lua/plenary.nvim",
    config = function()
      local todo_comments = require("todo-comments")
      todo_comments.setup({
        -- match TODO(scope):
        -- See https://github.com/folke/todo-comments.nvim/pull/255
        highlight = {
          -- vimgrep regex, supporting the pattern TODO(name):
          pattern = [[.*<((KEYWORDS)%(\(.{-1,}\))?):]],
        },
        search = {
          -- ripgrep regex, supporting the pattern TODO(name):
          pattern = [[\b(KEYWORDS)(\(\w*\))*:]],
        },
      })
      local tstext = require("nvim-treesitter.textobjects.repeatable_move")
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
      require("kiyoon.alpha")
    end,
  },
  {
    "luukvbaal/statuscol.nvim",
    config = function()
      require("kiyoon.statuscol")
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
      -- vim.o.timeout = true
      -- vim.o.timeoutlen = 600
      require("which-key").setup({
        delay = 600,
      })

      -- Sync with tmux registers
      -- https://github.com/folke/which-key.nvim/issues/743#issuecomment-2234460129
      local reg = require("which-key.plugins.registers")
      local expand = reg.expand

      function reg.expand()
        if vim.env.TMUX then
          require("tmux.copy").sync_registers()
        end
        return expand()
      end
    end,
  },
  {
    "iamcco/markdown-preview.nvim",
    cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
    ft = { "markdown" },
    build = function()
      vim.fn["mkdp#util#install"]()
    end,
    init = function()
      vim.cmd([[
        function OpenMarkdownPreview (url)
          execute "silent ! firefox " . a:url
        endfunction
        let g:mkdp_browserfunc = 'OpenMarkdownPreview'
      ]])
    end,
  },
  -- {
  --   "mechatroner/rainbow_csv",
  --   ft = "csv",
  -- },
  -- {
  --   "cameron-wags/rainbow_csv.nvim",
  --   opts = {},
  --   ft = {
  --     "csv",
  --     "tsv",
  --     "csv_semicolon",
  --     "csv_whitespace",
  --     "csv_pipe",
  --     "rfc_csv",
  --     "rfc_semicolon",
  --   },
  -- },
  {
    "fei6409/log-highlight.nvim",
    config = function()
      require("log-highlight").setup({
        -- The file extensions.
        extension = "log",

        -- The file path glob patterns, e.g. `.*%.lg`, `/var/log/.*`.
        -- Note: `%.` is to match a literal dot (`.`) in a pattern in Lua, but most
        -- of the time `.` and `%.` here make no observable difference.
        pattern = {
          "/var/log/.*",
          "messages%..*",
        },
      })
    end,
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
  {
    "stevearc/overseer.nvim",
    cmd = {
      "OverseerRun",
      "OverseerToggle",
    },
    opts = {},
  },
  {
    "lifthrasiir/hangeul.vim",
    init = function()
      vim.cmd([[let hangeul_enabled = 1]])
    end,
    config = function()
      vim.keymap.set("i", "<C-h>", "<Plug>HanMode", { noremap = false, silent = true })
    end,
  },
  {
    -- Usage:
    -- 1. Create kernel with: python -m ipykernel install --user --name {project name}
    -- 2. :MoltenInit
    "benlubas/molten-nvim",
    version = "^1.0.0", -- use version <2.0.0 to avoid breaking changes
    lazy = false, -- somehow it doesn't work with lazy loading and the plugin is fast to load
    -- cmd = {
    --   "MoltenInit",
    --   "MoltenInfo",
    -- },
    keys = {
      {
        "<space>mx",
        ":<C-u>MoltenEvaluateVisual<CR>gv",
        mode = "x",
        desc = "evaluate visual selection",
        silent = true,
      },
      {
        "<space>mm",
        ":MoltenEvaluateOperator<CR>",
        mode = "n",
        desc = "evaluate (operator-pending)",
        silent = true,
      },
      {
        "<space>mX",
        ":MoltenEvaluateLine<CR>",
        mode = "n",
        desc = "evaluate line",
        silent = true,
      },
      {
        "<space>mx",
        function()
          -- local jupynium_textobj = require("jupynium.textobj")
          -- jupynium_textobj.select_cell()
          -- local key = vim.api.nvim_replace_termcodes(":<C-u>MoltenEvaluateVisual<CR>gv", true, false, true)
          -- vim.api.nvim_feedkeys(key, "n", false)

          -- save cursor
          local save_cursor = vim.api.nvim_win_get_cursor(0)
          vim.cmd([[MoltenEvaluateOperator]])
          vim.api.nvim_feedkeys("ij", "m", false) -- select inner cell
          -- restore cursor
          vim.schedule(function()
            vim.api.nvim_win_set_cursor(0, save_cursor)
          end)
        end,
        mode = "n",
        desc = "evaluate cell (need jupynium textobject)",
        silent = true,
      },
      {
        "<space>mr",
        ":MoltenReevaluateCell<CR>",
        mode = "n",
        desc = "[R]e-evaluate cell",
      },
      {
        "<space>md",
        ":MoltenDelete<CR>",
        mode = "n",
        desc = "[D]elete cell output",
      },
      {
        "<space>mh",
        ":MoltenHideOutput<CR>",
        mode = "n",
        desc = "[H]ide output",
      },
      {
        "<space>me",
        ":noautocmd MoltenEnterOutput<CR>",
        mode = "n",
        desc = "[E]nter output",
      },
    },
    dependencies = {
      "3rd/image.nvim",
    },
    build = ":UpdateRemotePlugins",
    init = function()
      -- these are examples, not defaults. Please see the readme
      vim.g.molten_image_provider = "image.nvim"
      vim.g.molten_output_win_max_height = 20
    end,
  },
  {
    -- see the image.nvim readme for more information about configuring this plugin
    "3rd/image.nvim",
    build = false, -- do not use hererocks
    dependencies = {
      "kiyoon/magick.nvim",
    },
    opts = {
      backend = "kitty",
      integrations = {
        markdown = {
          enabled = false,
          clear_in_insert_mode = false,
          download_remote_images = true,
          only_render_image_at_cursor = false,
          filetypes = { "markdown", "vimwiki" }, -- markdown extensions (ie. quarto) can go here
        },
      },
      max_width = 100,
      max_height = 12,
      max_height_window_percentage = math.huge,
      max_width_window_percentage = math.huge,
      window_overlap_clear_enabled = false, -- toggles images when windows are overlapped
      window_overlap_clear_ft_ignore = { "cmp_menu", "cmp_docs", "" },
      editor_only_render_when_focused = false, -- auto show/hide images when the editor gains/looses focus
      tmux_show_only_in_active_window = false, -- auto show/hide images in the correct Tmux window (needs visual-activity off)
      hijack_file_patterns = {
        "*.png",
        "*.jpg",
        "*.jpeg",
        "*.gif",
        "*.webp",
        "*.PNG",
        "*.JPG",
        "*.JPEG",
        "*.GIF",
        "*.WEBP",
      }, -- render image files as images when opened
    },
  },
  {
    -- required for wookayin/dotfiles, the python keymaps
    -- which is in kiyoon/python_utils.lua
    "tpope/vim-repeat",
  },
  {
    "linrongbin16/gitlinker.nvim",
    config = function()
      require("gitlinker").setup()
    end,
  },
  {
    "jbyuki/venn.nvim",
    keys = {
      {
        "<leader>v",
        "<cmd>lua Toggle_venn()<CR>",
        mode = "n",
        desc = "Toggle Venn",
      },
    },
    config = function()
      function _G.Toggle_venn()
        local venn_enabled = vim.inspect(vim.b.venn_enabled)
        if venn_enabled == "nil" then
          vim.b.venn_enabled = true
          vim.cmd([[setlocal ve=all]])
          -- draw a line on HJKL keystokes
          vim.api.nvim_buf_set_keymap(0, "n", "J", "<C-v>j:VBox<CR>", { noremap = true })
          vim.api.nvim_buf_set_keymap(0, "n", "K", "<C-v>k:VBox<CR>", { noremap = true })
          vim.api.nvim_buf_set_keymap(0, "n", "L", "<C-v>l:VBox<CR>", { noremap = true })
          vim.api.nvim_buf_set_keymap(0, "n", "H", "<C-v>h:VBox<CR>", { noremap = true })
          -- draw a box by pressing "f" with visual selection
          vim.api.nvim_buf_set_keymap(0, "v", "f", ":VBox<CR>", { noremap = true })
        else
          vim.cmd([[setlocal ve=]])
          vim.cmd([[mapclear <buffer>]])
          vim.b.venn_enabled = nil
        end
      end
    end,
  },
  -- {
  --   "Wansmer/symbol-usage.nvim",
  --   event = "BufReadPre", -- need run before LspAttach if you use nvim 0.9. On 0.10 use 'LspAttach'
  --   config = function()
  --     local function h(name)
  --       return vim.api.nvim_get_hl(0, { name = name })
  --     end
  --
  --     -- hl-groups can have any name
  --     vim.api.nvim_set_hl(0, "SymbolUsageRounding", { fg = h("CursorLine").bg, italic = true })
  --     vim.api.nvim_set_hl(0, "SymbolUsageContent", { bg = h("CursorLine").bg, fg = h("Comment").fg, italic = true })
  --     vim.api.nvim_set_hl(0, "SymbolUsageRef", { fg = h("Function").fg, bg = h("CursorLine").bg, italic = true })
  --     vim.api.nvim_set_hl(0, "SymbolUsageDef", { fg = h("Type").fg, bg = h("CursorLine").bg, italic = true })
  --     vim.api.nvim_set_hl(0, "SymbolUsageImpl", { fg = h("@keyword").fg, bg = h("CursorLine").bg, italic = true })
  --
  --     local function text_format(symbol)
  --       local res = {}
  --
  --       local round_start = { "", "SymbolUsageRounding" }
  --       local round_end = { "", "SymbolUsageRounding" }
  --
  --       if symbol.references then
  --         local usage = symbol.references <= 1 and "usage" or "usages"
  --         local num = symbol.references == 0 and "no" or symbol.references
  --         table.insert(res, round_start)
  --         table.insert(res, { "󰌹 ", "SymbolUsageRef" })
  --         table.insert(res, { ("%s %s"):format(num, usage), "SymbolUsageContent" })
  --         table.insert(res, round_end)
  --       end
  --
  --       if symbol.definition then
  --         if #res > 0 then
  --           table.insert(res, { " ", "NonText" })
  --         end
  --         table.insert(res, round_start)
  --         table.insert(res, { "󰳽 ", "SymbolUsageDef" })
  --         table.insert(res, { symbol.definition .. " defs", "SymbolUsageContent" })
  --         table.insert(res, round_end)
  --       end
  --
  --       if symbol.implementation then
  --         if #res > 0 then
  --           table.insert(res, { " ", "NonText" })
  --         end
  --         table.insert(res, round_start)
  --         table.insert(res, { "󰡱 ", "SymbolUsageImpl" })
  --         table.insert(res, { symbol.implementation .. " impls", "SymbolUsageContent" })
  --         table.insert(res, round_end)
  --       end
  --
  --       return res
  --     end
  --
  --     require("symbol-usage").setup {
  --       text_format = text_format,
  --     }
  --   end,
  -- },
  {
    "m4xshen/hardtime.nvim",
    dependencies = { "MunifTanjim/nui.nvim", "nvim-lua/plenary.nvim" },
    opts = {
      disable_mouse = false,
      restriction_mode = "hint",
      restricted_keys = {
        ["h"] = {},
        ["j"] = {},
        ["k"] = {},
        ["l"] = {},
        ["-"] = {},
        ["+"] = {},
        ["gj"] = {},
        ["gk"] = {},
        ["<CR>"] = {},
        ["<C-M>"] = {},
        ["<C-N>"] = {},
        ["<C-P>"] = {},
      },
      disabled_keys = {
        ["<Up>"] = {},
        ["<Down>"] = {},
        ["<Left>"] = {},
        ["<Right>"] = {},
      },
      hints = {
        ["[kj][%^_]"] = {
          -- message = function(key)
          --    return "Use "
          --       .. (key:sub(1, 1) == "k" and "-" or "<CR> or +")
          --       .. " instead of "
          --       .. key
          -- end,
          -- length = 2,
        },
        ["[^fFtT]li"] = {
          -- message = function()
          --    return "Use a instead of li"
          -- end,
          -- length = 3,
        },
      },
    },
  },
}
