local wezterm = require("wezterm")

local config = {
	-- color_scheme = "Dracula (Official)",
	-- color_scheme = "catppuccin-frappe",

	font = wezterm.font_with_fallback({
		-- "Cascadia Code NF",
		"JetBrainsMono Nerd Font",
		"Fira Code Nerd Font",
	}),
	font_size = 14.3,

	max_fps = 120,

	window_decorations = "RESIZE",

	-- undercurl becomes ugly if underline_position < -4
	underline_position = -4,
	keys = {
		{
			-- Used in neovim (python-import.nvim)
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
			mods = "CMD|SHIFT",
			action = wezterm.action.ActivateTabRelative(-1),
		},
		{
			key = "F2",
			mods = "CMD|SHIFT",
			action = wezterm.action.ActivateTabRelative(-1),
		},
		{
			key = "F6",
			mods = "CMD|SHIFT",
			action = wezterm.action.ActivateTabRelative(1),
		},
		{
			key = "D",
			mods = "CMD|SHIFT",
			action = wezterm.action_callback(function(win, pane)
				local tab, window = pane:move_to_new_window()
			end),
		},
		{
			key = "C",
			mods = "CMD|SHIFT",
			action = wezterm.action_callback(function(win, pane)
				local tab, window = pane:move_to_new_tab()
			end),
		},
		{
			key = "|",
			mods = "CTRL|SHIFT|ALT",
			action = wezterm.action.SplitPane({
				direction = "Right",
				-- command = { args = { "top" } },
				size = { Percent = 50 },
			}),
		},
		{
			key = "_",
			mods = "CTRL|SHIFT|ALT",
			action = wezterm.action.SplitPane({
				direction = "Down",
				-- command = { args = { "top" } },
				size = { Percent = 50 },
			}),
		},
		-- OSC 133
		-- need to enable shell integration
		-- https://wezterm.org/shell-integration.html
		{ key = "UpArrow", mods = "SHIFT", action = wezterm.action.ScrollToPrompt(-1) },
		{ key = "DownArrow", mods = "SHIFT", action = wezterm.action.ScrollToPrompt(1) },
	},

	enable_scroll_bar = true,
	scrollback_lines = 30000,

	enable_kitty_graphics = true,
}

-- disable ctrl+shift +/- zooming
-- in favour of using cmd + = and cmd + -
if wezterm.target_triple == "aarch64-apple-darwin" then
	table.insert(config.keys, {
		key = "+",
		mods = "CTRL|SHIFT",
		action = wezterm.action.DisableDefaultAssignment,
	})
	table.insert(config.keys, {
		key = "_",
		mods = "CTRL|SHIFT",
		action = wezterm.action.DisableDefaultAssignment,
	})
end

-- config.hyperlink_rules = wezterm.default_hyperlink_rules()
-- NOTE: the default rule doesn't work well with parens, brackets, or braces.
-- Updated rules following https://github.com/wez/wezterm/issues/3803
config.hyperlink_rules = {
	-- Rewrite bare: ssh://github.com/...  -->  https://github.com/...
	-- Put this BEFORE any generic \w+:// rules in your real config.
	{
		regex = [[\bssh://(github\.com)/?([^\s)\]\}>]*)?]],
		format = "https://$1/$2",
	},
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
	-- {
	-- 	regex = "[^(]\\b(\\w+://\\S+[)/a-zA-Z0-9-]+)",
	-- 	format = "$1",
	-- 	highlight = 1,
	-- },
	{
		regex = "(?<![\\(\\{\\[<])\\b\\w+://\\S+",
		format = "$0",
	},
	-- NOTE(kiyoon): hyperlink at the beginning of the line doesn't work
	-- handle it.
	-- {
	-- 	regex = "^\\b(\\w+://\\S+[)/a-zA-Z0-9-]+)",
	-- 	format = "$1",
	-- 	highlight = 1,
	-- },
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
	regex = [[🔗🐍 \[(\w+)\]] .. "]",
	format = "https://docs.astral.sh/ruff/rules/$1",
})
table.insert(config.hyperlink_rules, {
	regex = [[🔗🐍b \[(\w+)\]] .. "]",
	format = "https://docs.basedpyright.com/latest/configuration/config-files/#$1",
})

table.insert(config.hyperlink_rules, {
	regex = [[🔗🐚 \[(\w+)\]] .. "]",
	format = "https://shellcheck.net/wiki/$1",
})

-- rustc error
table.insert(config.hyperlink_rules, {
	regex = [[🔗🦀 \[E([0-9]+)\]] .. "]",
	format = "https://doc.rust-lang.org/error_codes/E$1.html",
})
-- rustc lint warning
table.insert(config.hyperlink_rules, {
	regex = [[🔗🦀 \[([a-z0-9_]+)\]] .. "]",
	format = "https://doc.rust-lang.org/rustc/?search=$1",
})
-- clippy
table.insert(config.hyperlink_rules, {
	regex = [[🔗🦀cl \[([a-z0-9_]+)\]] .. "]",
	format = "https://rust-lang.github.io/rust-clippy/master/index.html#$1",
})

table.insert(config.hyperlink_rules, {
	regex = [[🔗🌜d \[(.*)\]] .. "]",
	format = "https://luals.github.io/wiki/diagnostics/#$1",
})

table.insert(config.hyperlink_rules, {
	regex = [[🔗🌜s \[(.*)\]] .. "]",
	format = "https://luals.github.io/wiki/syntax-errors/#$1",
})

-- biome
table.insert(config.hyperlink_rules, {
	regex = [[🔗 \[([a-z0-9-]+)]] .. "]",
	format = "https://biomejs.dev/linter/rules/$1",
})
table.insert(config.hyperlink_rules, {
	regex = [[\[lint/.*/(.*)\]] .. "]",
	format = "https://next.biomejs.dev/linter/rules/$1",
})

-- selene
table.insert(config.hyperlink_rules, {
	regex = [[🔗selene \[([a-z0-9_]+)\]] .. "]",
	format = "https://kampfkarren.github.io/selene/lints/$1.html",
})

config.colors = {
	-- The color of the scrollbar "thumb"; the portion that represents the current viewport
	scrollbar_thumb = "#392a48",

	-- Setting copied from Ghostty 1.0
	background = "#282c34",
	foreground = "#ffffff",

	-- See https://www.ditig.com/publications/256-colors-cheat-sheet
	-- in the range from 0 to 15
	ansi = {
		"#1d1f21",
		"#cc6666",
		"#b5bd68",
		"#f0c674",
		"#81a2be",
		"#b294bb",
		"#8abeb7",
		"#c5c8c6",
	},
	brights = {
		"#666666",
		"#d54e53",
		"#b9ca4a",
		"#e7c547",
		"#7aa6da",
		"#c397d8",
		"#70c0b1",
		"#eaeaea",
	},

	-- in the range from 16 to 255
	indexed = {
		[16] = "#000000",
		[17] = "#00005f",
		[18] = "#000087",
		[19] = "#0000af",
		[20] = "#0000d7",
		[21] = "#0000ff",
		[22] = "#005f00",
		[23] = "#005f5f",
		[24] = "#005f87",
		[25] = "#005faf",
		[26] = "#005fd7",
		[27] = "#005fff",
		[28] = "#008700",
		[29] = "#00875f",
		[30] = "#008787",
		[31] = "#0087af",
		[32] = "#0087d7",
		[33] = "#0087ff",
		[34] = "#00af00",
		[35] = "#00af5f",
		[36] = "#00af87",
		[37] = "#00afaf",
		[38] = "#00afd7",
		[39] = "#00afff",
		[40] = "#00d700",
		[41] = "#00d75f",
		[42] = "#00d787",
		[43] = "#00d7af",
		[44] = "#00d7d7",
		[45] = "#00d7ff",
		[46] = "#00ff00",
		[47] = "#00ff5f",
		[48] = "#00ff87",
		[49] = "#00ffaf",
		[50] = "#00ffd7",
		[51] = "#00ffff",
		[52] = "#5f0000",
		[53] = "#5f005f",
		[54] = "#5f0087",
		[55] = "#5f00af",
		[56] = "#5f00d7",
		[57] = "#5f00ff",
		[58] = "#5f5f00",
		[59] = "#5f5f5f",
		[60] = "#5f5f87",
		[61] = "#5f5faf",
		[62] = "#5f5fd7",
		[63] = "#5f5fff",
		[64] = "#5f8700",
		[65] = "#5f875f",
		[66] = "#5f8787",
		[67] = "#5f87af",
		[68] = "#5f87d7",
		[69] = "#5f87ff",
		[70] = "#5faf00",
		[71] = "#5faf5f",
		[72] = "#5faf87",
		[73] = "#5fafaf",
		[74] = "#5fafd7",
		[75] = "#5fafff",
		[76] = "#5fd700",
		[77] = "#5fd75f",
		[78] = "#5fd787",
		[79] = "#5fd7af",
		[80] = "#5fd7d7",
		[81] = "#5fd7ff",
		[82] = "#5fff00",
		[83] = "#5fff5f",
		[84] = "#5fff87",
		[85] = "#5fffaf",
		[86] = "#5fffd7",
		[87] = "#5fffff",
		[88] = "#870000",
		[89] = "#87005f",
		[90] = "#870087",
		[91] = "#8700af",
		[92] = "#8700d7",
		[93] = "#8700ff",
		[94] = "#875f00",
		[95] = "#875f5f",
		[96] = "#875f87",
		[97] = "#875faf",
		[98] = "#875fd7",
		[99] = "#875fff",
		[100] = "#878700",
		[101] = "#87875f",
		[102] = "#878787",
		[103] = "#8787af",
		[104] = "#8787d7",
		[105] = "#8787ff",
		[106] = "#87af00",
		[107] = "#87af5f",
		[108] = "#87af87",
		[109] = "#87afaf",
		[110] = "#87afd7",
		[111] = "#87afff",
		[112] = "#87d700",
		[113] = "#87d75f",
		[114] = "#87d787",
		[115] = "#87d7af",
		[116] = "#87d7d7",
		[117] = "#87d7ff",
		[118] = "#87ff00",
		[119] = "#87ff5f",
		[120] = "#87ff87",
		[121] = "#87ffaf",
		[122] = "#87ffd7",
		[123] = "#87ffff",
		[124] = "#af0000",
		[125] = "#af005f",
		[126] = "#af0087",
		[127] = "#af00af",
		[128] = "#af00d7",
		[129] = "#af00ff",
		[130] = "#af5f00",
		[131] = "#af5f5f",
		[132] = "#af5f87",
		[133] = "#af5faf",
		[134] = "#af5fd7",
		[135] = "#af5fff",
		[136] = "#af8700",
		[137] = "#af875f",
		[138] = "#af8787",
		[139] = "#af87af",
		[140] = "#af87d7",
		[141] = "#af87ff",
		[142] = "#afaf00",
		[143] = "#afaf5f",
		[144] = "#afaf87",
		[145] = "#afafaf",
		[146] = "#afafd7",
		[147] = "#afafff",
		[148] = "#afd700",
		[149] = "#afd75f",
		[150] = "#afd787",
		[151] = "#afd7af",
		[152] = "#afd7d7",
		[153] = "#afd7ff",
		[154] = "#afff00",
		[155] = "#afff5f",
		[156] = "#afff87",
		[157] = "#afffaf",
		[158] = "#afffd7",
		[159] = "#afffff",
		[160] = "#d70000",
		[161] = "#d7005f",
		[162] = "#d70087",
		[163] = "#d700af",
		[164] = "#d700d7",
		[165] = "#d700ff",
		[166] = "#d75f00",
		[167] = "#d75f5f",
		[168] = "#d75f87",
		[169] = "#d75faf",
		[170] = "#d75fd7",
		[171] = "#d75fff",
		[172] = "#d78700",
		[173] = "#d7875f",
		[174] = "#d78787",
		[175] = "#d787af",
		[176] = "#d787d7",
		[177] = "#d787ff",
		[178] = "#d7af00",
		[179] = "#d7af5f",
		[180] = "#d7af87",
		[181] = "#d7afaf",
		[182] = "#d7afd7",
		[183] = "#d7afff",
		[184] = "#d7d700",
		[185] = "#d7d75f",
		[186] = "#d7d787",
		[187] = "#d7d7af",
		[188] = "#d7d7d7",
		[189] = "#d7d7ff",
		[190] = "#d7ff00",
		[191] = "#d7ff5f",
		[192] = "#d7ff87",
		[193] = "#d7ffaf",
		[194] = "#d7ffd7",
		[195] = "#d7ffff",
		[196] = "#ff0000",
		[197] = "#ff005f",
		[198] = "#ff0087",
		[199] = "#ff00af",
		[200] = "#ff00d7",
		[201] = "#ff00ff",
		[202] = "#ff5f00",
		[203] = "#ff5f5f",
		[204] = "#ff5f87",
		[205] = "#ff5faf",
		[206] = "#ff5fd7",
		[207] = "#ff5fff",
		[208] = "#ff8700",
		[209] = "#ff875f",
		[210] = "#ff8787",
		[211] = "#ff87af",
		[212] = "#ff87d7",
		[213] = "#ff87ff",
		[214] = "#ffaf00",
		[215] = "#ffaf5f",
		[216] = "#ffaf87",
		[217] = "#ffafaf",
		[218] = "#ffafd7",
		[219] = "#ffafff",
		[220] = "#ffd700",
		[221] = "#ffd75f",
		[222] = "#ffd787",
		[223] = "#ffd7af",
		[224] = "#ffd7d7",
		[225] = "#ffd7ff",
		[226] = "#ffff00",
		[227] = "#ffff5f",
		[228] = "#ffff87",
		[229] = "#ffffaf",
		[230] = "#ffffd7",
		[231] = "#ffffff",
		[232] = "#080808",
		[233] = "#121212",
		[234] = "#1c1c1c",
		[235] = "#262626",
		[236] = "#303030",
		[237] = "#3a3a3a",
		[238] = "#444444",
		[239] = "#4e4e4e",
		[240] = "#585858",
		[241] = "#626262",
		[242] = "#6c6c6c",
		[243] = "#767676",
		[244] = "#808080",
		[245] = "#8a8a8a",
		[246] = "#949494",
		[247] = "#9e9e9e",
		[248] = "#a8a8a8",
		[249] = "#b2b2b2",
		[250] = "#bcbcbc",
		[251] = "#c6c6c6",
		[252] = "#d0d0d0",
		[253] = "#dadada",
		[254] = "#e4e4e4",
		[255] = "#eeeeee",
	},
}

-- to turn off above settings
-- config.color_scheme = "Dracula (Official)"
-- config.colors = {}

-- From wezterm doc
config.colors.tab_bar = {
	-- The color of the strip that goes along the top of the window
	-- (does not apply when fancy tab bar is in use)
	background = "#0b0022",

	-- The active tab is the one that has focus in the window
	active_tab = {
		-- The color of the background area for the tab
		bg_color = "#2b2042",
		-- The color of the text for the tab
		fg_color = "#c0c0c0",

		-- Specify whether you want "Half", "Normal" or "Bold" intensity for the
		-- label shown for this tab.
		-- The default is "Normal"
		intensity = "Normal",

		-- Specify whether you want "None", "Single" or "Double" underline for
		-- label shown for this tab.
		-- The default is "None"
		underline = "None",

		-- Specify whether you want the text to be italic (true) or not (false)
		-- for this tab.  The default is false.
		italic = false,

		-- Specify whether you want the text to be rendered with strikethrough (true)
		-- or not for this tab.  The default is false.
		strikethrough = false,
	},

	-- Inactive tabs are the tabs that do not have focus
	inactive_tab = {
		bg_color = "#1b1032",
		fg_color = "#808080",

		-- The same options that were listed under the `active_tab` section above
		-- can also be used for `inactive_tab`.
	},

	-- You can configure some alternate styling when the mouse pointer
	-- moves over inactive tabs
	inactive_tab_hover = {
		bg_color = "#3b3052",
		fg_color = "#909090",
		italic = true,

		-- The same options that were listed under the `active_tab` section above
		-- can also be used for `inactive_tab_hover`.
	},

	-- The new tab button that let you create new tabs
	new_tab = {
		bg_color = "#1b1032",
		fg_color = "#808080",

		-- The same options that were listed under the `active_tab` section above
		-- can also be used for `new_tab`.
	},

	-- You can configure some alternate styling when the mouse pointer
	-- moves over the new tab button
	new_tab_hover = {
		bg_color = "#3b3052",
		fg_color = "#909090",
		italic = true,

		-- The same options that were listed under the `active_tab` section above
		-- can also be used for `new_tab_hover`.
	},
}

config.window_background_opacity = 0.85
config.macos_window_background_blur = 20

if wezterm.target_triple == "x86_64-pc-windows-msvc" then
	config.default_prog = { "pwsh.exe", "-NoLogo" }
else
	config.term = "wezterm"
end

return config
