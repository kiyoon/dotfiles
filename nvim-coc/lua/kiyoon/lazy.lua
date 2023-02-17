return {
	{
		"folke/tokyonight.nvim",
		lazy = false, -- make sure we load this during startup if it is your main colorscheme
		priority = 1000, -- make sure to load this before all the other start plugins
		config = function()
			-- load the colorscheme here
			-- require "kiyoon.tokyonight"
			vim.cmd.colorscheme("tokyonight-moon")
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
	{
		"numToStr/Comment.nvim",
		event = "VeryLazy",
		config = function()
			require("Comment").setup()
		end,
	},
	{
		"tpope/vim-surround",
		event = "VeryLazy",
	},
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
		cmd = { "Copilot" },
		init = function()
			vim.g.copilot_no_tab_map = true
			vim.cmd([[imap <silent><script><expr> <C-s> copilot#Accept("")]])
		end,
	},
	-- "Exafunction/codeium.vim",
	{
		"nvim-lualine/lualine.nvim",
		config = function()
			require("lualine").setup({})
		end,
	},
	-- Telescope
	{
		"nvim-telescope/telescope.nvim",
		branch = "0.1.x",
		dependencies = "nvim-lua/plenary.nvim",
		config = function()
			require("kiyoon.telescope")
		end,
	},
	{
		"nvim-telescope/telescope-fzf-native.nvim",
		build = "make",
		enabled = vim.fn.executable("make") == 1,
		config = function()
			require("telescope").load_extension("fzf")
		end,
	},

	{ "kiyoon/telescope-insert-path.nvim" },

	{
		"nvim-telescope/telescope-live-grep-args.nvim",
		config = function()
			require("telescope").load_extension("live_grep_args")
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
			require("kiyoon.wilder")
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
			-- vim.cmd [[ let b:coc_suggest_disable = 1 ]]
			vim.g.coc_data_home = vim.fn.stdpath("data") .. "/coc"
		end,
		config = function()
			require("kiyoon.coc")
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
			require("kiyoon.tmux-yanky")
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
					require("osc52").copy_register("+")
				end
			end

			vim.api.nvim_create_autocmd("TextYankPost", { callback = copy })

			-- Because we lazy-load on TextYankPost, the above autocmd will not be executed at first.
			-- So we need to manually call it once.
			copy()
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
}
