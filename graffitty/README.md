# Graffitty

`init.gd` is linked into `~/.config/graffitty/` by the dotfiles mise setup.
Restart Graffitty after editing. This is executable GDScript, with the app's OS
permissions. It requires a build with the structured configuration API.

All supported TerminalConfig options are listed explicitly in init.gd. The world
receives a copy and may override or replace it; camera/sheet geometry belong to the world. Cursor trails and typing particles
are optional terminal preferences.
Startup world selection and native menu entries are separate.
Menus are explicitly declared here; Graffitty never adds worlds automatically.
Callbacks receive the focused workspace host and may be custom GDScript methods
or lambdas. Optional checked/enabled callbacks control menu state.

Put world packs and their companion JSON manifests in
`~/.local/share/graffitty/worlds/edinburgh-castle/`. The config includes a Castle menu entry only
when that pack and manifest exist. Flat remains the startup default.

`Paths.stdpath("config")`, `"data"`, `"cache"`, and `"state"` expose the app
directories. Their corresponding `XDG_*_HOME` variables override the bases. The mise link
uses the default config location; with a custom XDG base, link this directory
there instead.

Edinburgh Castle reads its settings from
`Paths.stdpath("config").path_join("worlds/edinburgh-castle/init.gd")`.
The script extends `res://plugins/edinburgh-castle/EdinburghCastleSettings.gd`
and defines `_init(user: TerminalConfig)`, starting with `super(user)`.
It receives typed `weather`, `camera`, `lighting`, `sheet`, `typing`, `behavior`,
and `states` groups, plus `render_scale` and a copy of the global `terminal`
preferences with Castle's background default. All supported world settings are
listed in the dotfiles script. GDScript branches can select platform-specific
values. Settings are validated before use; invalid values discard the user
layer and restore Castle defaults with the global terminal preferences. Switching back to Flat restores Flat's configuration. Missing files use
the world's defaults. Each world author chooses whether and how to load a file. The script is loaded
when the world is entered; switch away and back to reload it. Bundled
`default.conf` remains an internal preset, not the user configuration.
