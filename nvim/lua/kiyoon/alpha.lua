require("alpha").setup(require("alpha.themes.dashboard").config)
local alpha = require "alpha"
local dashboard = require "alpha.themes.dashboard"
local neovim_version = vim.version()
local neovim_version_str = string.format(
  "  v%s.%s.%s%s",
  neovim_version.major,
  neovim_version.minor,
  neovim_version.patch,
  neovim_version.prerelease and " nightly" or ""
)

dashboard.section.header.val = {
  [[                               __                ]],
  [[  ___     ___    ___   __  __ /\_\    ___ ___    ]],
  [[ / _ `\  / __`\ / __`\/\ \/\ \\/\ \  / __` __`\  ]],
  [[/\ \/\ \/\  __//\ \_\ \ \ \_/ |\ \ \/\ \/\ \/\ \ ]],
  [[\ \_\ \_\ \____\ \____/\ \___/  \ \_\ \_\ \_\ \_\]],
  [[ \/_/\/_/\/____/\/___/  \/__/    \/_/\/_/\/_/\/_/]] .. neovim_version_str,
}

local plugins_config_path = vim.fn.stdpath "config" .. "/lua/kiyoon/lazy.lua"
dashboard.section.buttons.val = {
  dashboard.button("e", "  New file", ":ene <BAR> startinsert <CR>"),
  dashboard.button("f", "  Find file (\\ff)", ":Telescope find_files hidden=true no_ignore=true<CR>"),
  dashboard.button("g", "  Find git file (\\fg)", ":Telescope git_files<CR>"),
  dashboard.button("r", "  Recently opened files (\\fr)", "<cmd>Telescope oldfiles<CR>"),
  -- dashboard.button("p", " " .. " Recent projects", ":lua require('telescope').extensions.projects.projects()<CR>"),
  dashboard.button("w", "  Find word (\\fw)", "<cmd>Telescope live_grep<cr>"),
  dashboard.button("d", " " .. " Diff view (\\dv)", "<cmd>DiffviewOpen<CR>"),
  dashboard.button("C", " " .. " ChatGPT (\\cg)", "<cmd>ChatGPT<CR>"),
  dashboard.button("l", " " .. " Install language support (:Mason)", ":Mason<CR>"),
  dashboard.button("p", " " .. " Plugins", "<cmd>Lazy<CR>"),
  dashboard.button("P", " " .. " Plugins config", ":e " .. plugins_config_path .. "<CR>"),
  dashboard.button("c", " " .. " Neovim config", ":e $MYVIMRC <CR>"),
  dashboard.button("q", " " .. " Quit", ":qa<CR>"),
}
-- local handle = io.popen('fortune')
-- local fortune = handle:read("*a")
-- handle:close()
-- dashboard.section.footer.val = fortune

local function footer()
  return {
    "https://github.com/kiyoon",
  }
end

dashboard.section.footer.val = footer()

dashboard.section.footer.opts.hl = "Type"
dashboard.section.header.opts.hl = "Include"
dashboard.section.buttons.opts.hl = "Keyword"

dashboard.config.opts.noautocmd = true

vim.cmd [[autocmd User AlphaReady echo 'ready']]

alpha.setup(dashboard.config)
