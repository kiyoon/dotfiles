local wezterm = require("wezterm")

local config = {
	color_scheme = "Dracula (Official)",

	font = wezterm.font_with_fallback({
		"JetBrainsMono Nerd Font",
		"Fira Code Nerd Font",
	}),
	font_size = 14.3,

	-- undercurl becomes ugly if underline_position < -4
	underline_position = -4,
	keys = {
		{
			key = "Enter",
			mods = "ALT",
			action = wezterm.action.DisableDefaultAssignment,
		},
		{
			key = "r",
			mods = "CMD|SHIFT",
			action = wezterm.action.ReloadConfiguration,
		},
		{
			key = "F3",
			mods = "CTRL|SHIFT",
			action = wezterm.action.ActivateTabRelative(-1),
		},
		{
			key = "F4",
			mods = "CTRL|SHIFT",
			action = wezterm.action.ActivateTabRelative(-1),
		},
		{
			key = "F6",
			mods = "CTRL|SHIFT",
			action = wezterm.action.ActivateTabRelative(1),
		},
	},

	enable_scroll_bar = true,
	term = "wezterm",

	enable_kitty_graphics = true,
}

config.hyperlink_rules = wezterm.default_hyperlink_rules()
-- make username/project paths clickable. this implies paths like the following are for github.
-- ( "nvim-treesitter/nvim-treesitter" | wbthomason/packer.nvim | wez/wezterm | "wez/wezterm.git" )
-- as long as a full url hyperlink regex exists above this it should not match a full url to
-- github or gitlab / bitbucket (i.e. https://gitlab.com/user/project.git is still a whole clickable url)
table.insert(config.hyperlink_rules, {
	regex = [[["'\s]([\w\d]{1}[-\w\d]+)(/){1}([-\w\d\.]+)["'\s]] .. "]",
	format = "https://www.github.com/$1/$3",
})

-- Example:
--     ruff: Mixed spaces and tabs [E101]
table.insert(config.hyperlink_rules, {
	regex = [[[rR]uff:.*\[(\w+)\]] .. "]",
	format = "https://docs.astral.sh/ruff/rules/$1",
})

return config
