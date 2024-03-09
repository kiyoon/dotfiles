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
	scrollback_lines = 30000,
	term = "wezterm",

	enable_kitty_graphics = true,
}

-- config.hyperlink_rules = wezterm.default_hyperlink_rules()
-- NOTE: the default rule doesn't work well with parens, brackets, or braces.
-- Updated rules following https://github.com/wez/wezterm/issues/3803
config.hyperlink_rules = {
	-- Matches: a URL in parens: (URL)
	{
		regex = "\\((\\w+://\\S+)\\)",
		format = "$1",
		highlight = 1,
	},
	-- Matches: a URL in brackets: [URL]
	{
		regex = "\\[(\\w+://\\S+)\\]",
		format = "$1",
		highlight = 1,
	},
	-- Matches: a URL in curly braces: {URL}
	{
		regex = "\\{(\\w+://\\S+)\\}",
		format = "$1",
		highlight = 1,
	},
	-- Matches: a URL in angle brackets: <URL>
	{
		regex = "<(\\w+://\\S+)>",
		format = "$1",
		highlight = 1,
	},
	-- Then handle URLs not wrapped in brackets
	{
		regex = "[^(]\\b(\\w+://\\S+[)/a-zA-Z0-9-]+)",
		format = "$1",
		highlight = 1,
	},
	-- implicit mailto link
	{
		regex = "\\b\\w+@[\\w-]+(\\.[\\w-]+)+\\b",
		format = "mailto:$0",
	},
}

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
