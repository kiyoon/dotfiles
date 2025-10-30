require("treesitter-modules").setup({
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
    disable = function(ctx)
      local disable_langs = { "python", "javascript", "typescript" }

      if vim.list_contains(disable_langs, ctx.language) then
        -- allow highlighting in floating buffers
        if vim.bo[ctx.buf].buftype == "nofile" then
          return false
        end
        -- allow highlighting in .ju.py notebooks
        if vim.api.nvim_buf_get_name(ctx.buf):match("%.ju%.py$") then
          return false
        end
        return true
      end

      -- disable for large files
      local max_filesize = 100 * 1024 -- 100 KB
      local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(ctx.buf))
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
})

local status, wk = pcall(require, "which-key")
if status then
  wk.add({
    { "<space>t", group = "Language-specific [T]ools" },
  })
end
