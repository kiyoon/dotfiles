extends "res://graffitty/config.gd"
const TerminalHost := preload("res://scenes/TerminalHost.gd")
const Paths := preload("res://graffitty/paths.gd")
const KeyBinding := TerminalConfig.KeyBinding
const MouseBinding := TerminalConfig.MouseBinding

func _init() -> void:
	navigator.enabled = true
	# Settle once on app entry; typing resumes effects. Prefix, R settles manually.
	rules = default_rules()
	# Optional persistent rules (disabled examples; defaults stay one-shot):
	# rules.append(Rule.while_active({"app": "nvim"}, Actions.disable({"exclude": ["sparks"]})))
	# rules.append(Rule.while_active({"app": ["claude", "codex"]}, Actions.disable({"include": ["camera", "pane_zoom"]})))
	# One-shot actions accept the same selectors:
	# prefix.bindings[KEY_R] = Actions.settle({"include": ["all"], "exclude": ["sparks"]})
	prefix.bindings[KEY_L | KEY_MASK_CTRL] = "navigator.send_literal"
	# Remote startup settings live under [remote] in server.toml.
	tiling.enabled = true
	window.max_fps = 60 # Active window; set to 120 for a higher cap.
	window.inactive_max_fps = 30 # Inactive window after pointer activity ends.
	window.background_blur = true
	window.macos.blur_radius = 20
	window.windows.blur_material = "acrylic"
	# Generic terminal preferences. Each world receives a copy and may use,
	# override, or replace it.

	# Fonts and grid metrics. Font size uses reference-layout pixels.
	terminal.font_family = "JetBrainsMono Nerd Font" # Empty: bundled font.
	# Optional explicit files override font_family; regular is required in file mode.
	# Empty style paths reuse regular. These are style choices, not fallback fonts.
	# Missing glyphs try these installed families in order, before built-in/system fallback.
	terminal.font_fallbacks = [] # Example: ["Apple SD Gothic Neo", "Apple Color Emoji"]
	terminal.font_regular_path = ""
	terminal.font_bold_path = ""
	terminal.font_italic_path = ""
	terminal.font_bold_italic_path = ""
	terminal.font_features = {} # OpenType tag: integer, e.g. {"zero": 1, "ss01": 1}.
	terminal.font_variations = {} # Variable-font axis: float, e.g. {"wght": 450.0}.
	terminal.symbol_maps = [] # TerminalConfig.SymbolMap.new(0xe000, 0xf8ff, "Symbols Nerd Font Mono").
	terminal.font_size = 16 # 6..72; worlds scale to their surfaces.
	terminal.ligatures = true
	terminal.line_height = 1.0 # Font-height multiplier, 0.5..3.
	terminal.column_width = 1.0 # Cell-width multiplier, 0.5..3.

	# Text, selection, and the 16 ANSI colors. Programs may set their own colors.
	terminal.foreground = Color("#ffffff")
	terminal.palette = PackedColorArray([
		Color("#1d1f21"), Color("#cc6666"), Color("#b5bd68"), Color("#f0c674"),
		Color("#81a2be"), Color("#b294bb"), Color("#8abeb7"), Color("#c5c8c6"),
		Color("#666666"), Color("#d54e53"), Color("#b9ca4a"), Color("#e7c547"),
		Color("#7aa6da"), Color("#c397d8"), Color("#70c0b1"), Color("#eaeaea"),
	])
	terminal.palette_overrides = {} # Additional index: Color entries, indices 0..255.
	terminal.selection_foreground = Color.TRANSPARENT # Inherit/invert cell color.
	terminal.selection_background = Color("#7f6699")
	terminal.cursor_color = Color("#ffffff")
	terminal.cursor_shape = "auto" # auto follows app; block, beam, underline, hollow.
	terminal.cursor_blink = "auto" # auto follows applications; on, off.
	terminal.cursor_blink_interval_ms = 500 # Duration of each on/off phase.
	terminal.cursor_beam_thickness = 0.0 # Pixels; 0 uses the font metric.
	terminal.cursor_underline_thickness = 0.0
	terminal.text_outline = false
	terminal.text_outline_width = 1.0 # 0..32, only when enabled.
	terminal.text_outline_color = Color("#000000bf")

	# Terminal background color and alpha.
	terminal.background.color = Color("#282c34")
	terminal.background.alpha = 0.85 # 0..1, independent of explicitly colored cells.

	# Terminal overlays: worlds may use, override, or omit these preferences.
	# Sheet padding/corners, camera, lighting, and weather belong to each world.
	terminal.effects.cursor_trail.style = "lightning"
	terminal.effects.cursor_trail.delay_ms = 3 # 0 disables; delay before following, milliseconds.
	terminal.effects.cursor_trail.decay = Vector2(0.1, 0.4) # Fast/slow corners, seconds.
	terminal.effects.cursor_trail.start_threshold = Vector2(2, 2) # Horizontal/vertical cells.
	terminal.effects.cursor_trail.color = Color("#c397d8") # TRANSPARENT follows cursor color.
	terminal.effects.typing_particles.preset = "sparks" # none, sparks, basic, fireworks, flames, glitter.
	terminal.effects.typing_particles.amount = 6 # Per burst, 1..2048 (pool capacity).
	terminal.effects.typing_particles.scale = 1.0 # 0.01..100.
	terminal.effects.typing_particles.combo = false # Build particle intensity while typing.

	# Process settings: new shells only. Switching worlds preserves live shells.

	# Terminal protocol permissions; explicit copy/paste remains available.
	terminal.clipboard_read = "ask" # OSC 52: deny, ask, allow.
	terminal.clipboard_write = true # OSC 52 clipboard writes.
	terminal.open_hyperlinks = true
	terminal.hyperlink_patterns = [r"(?:https?://|ftp://|file://)[^\s<>\"]+"]
	terminal.hyperlink_handler = Callable() # Optional func(uri: String); replaces the OS opener.
	terminal.audible_bell = false
	terminal.visual_bell_duration_ms = 0 # 0 disables the flash.
	terminal.visual_bell_color = Color(1, 1, 1, 0.25)
	terminal.selection_word_boundaries = null # null uses Ghostty defaults; a string replaces them.
	terminal.iskeyword.append("-") # Copy mode: keep hyphenated names as one word; Space motions split them.
	terminal.copy_on_select = "primary" # none, primary, clipboard, both.
	terminal.scroll_multiplier = 1.0
	terminal.mouse_bypass_modifiers = KEY_MASK_SHIFT # 0 disables bypass of application mouse reporting.
	terminal.mouse_bindings = [
		MouseBinding.new(MOUSE_BUTTON_LEFT, "select"),
		MouseBinding.new(MOUSE_BUTTON_LEFT, "select", KEY_MASK_ALT),
		MouseBinding.new(MOUSE_BUTTON_LEFT, "open_link", KEY_MASK_CTRL),
		MouseBinding.new(MOUSE_BUTTON_LEFT, "open_link", KEY_MASK_META),
		MouseBinding.new(MOUSE_BUTTON_MIDDLE, "paste_primary"),
		MouseBinding.new(MOUSE_BUTTON_WHEEL_UP, "scroll_up"),
		MouseBinding.new(MOUSE_BUTTON_WHEEL_DOWN, "scroll_down"),
	]
	terminal.quick_select_patterns = [] # Additional regexes; last capture group is selected.
	terminal.quick_select_defaults = true
	terminal.quick_select_alphabet = "asdfqwerzxcvjklmiuopghtybn"
	terminal.modal_key_bindings = TerminalConfig.default_modal_bindings() # search, copy_mode, quick_select.
	terminal.leader = null # A Godot key mask or InputEventKey, e.g. KEY_B | KEY_MASK_CTRL.
	terminal.sequence_timeout_ms = 1000
	terminal.key_sequences = [] # TerminalConfig.KeySequence.new([TerminalConfig.LEADER, KEY_F], "search").
	terminal.key_tables = {} # Name: TerminalConfig.KeyTable; bindings, sequences, one_shot, timeout_ms.

	# Bind native Godot key/modifier constants directly; combine them with |.
	# An InputEventKey with keycode and modifier flags also works.
	# Focused-terminal bindings only. An empty list disables all activation keys.
	# To unbind a key remove its entry. "ignore" consumes it without sending to PTY.
	# Modal navigation is configured separately in modal_key_bindings.
	# Tab/window/browser shortcuts belong to the host, not TerminalConfig.
	terminal.key_bindings = [
		KeyBinding.new(KEY_F | KEY_MASK_CTRL | KEY_MASK_SHIFT, "search"),
		KeyBinding.new(KEY_SPACE | KEY_MASK_CTRL | KEY_MASK_SHIFT, "quick_select"),
		KeyBinding.new(KEY_X | KEY_MASK_CTRL | KEY_MASK_SHIFT, "copy_mode"),
		KeyBinding.new(KEY_O | KEY_MASK_CTRL | KEY_MASK_SHIFT, "copy_last_output"),
		KeyBinding.new(KEY_UP | KEY_MASK_SHIFT, "previous_prompt"),
		KeyBinding.new(KEY_DOWN | KEY_MASK_SHIFT, "next_prompt"),
		KeyBinding.new(KEY_PAGEUP | KEY_MASK_SHIFT, "scroll_page_up"),
		KeyBinding.new(KEY_PAGEDOWN | KEY_MASK_SHIFT, "scroll_page_down"),
		KeyBinding.new(KEY_HOME | KEY_MASK_SHIFT, "scroll_top"),
		KeyBinding.new(KEY_END | KEY_MASK_SHIFT, "scroll_bottom"),
	]
	# Copy/paste: Command on macOS, Ctrl+Shift elsewhere.
	if OS.get_name() == "macOS":
		terminal.key_bindings.append_array([
			KeyBinding.new(KEY_C | KEY_MASK_META, "copy"),
			KeyBinding.new(KEY_V | KEY_MASK_META, "paste"),
		])
	else:
		terminal.key_bindings.append_array([
			KeyBinding.new(KEY_C | KEY_MASK_CTRL | KEY_MASK_SHIFT, "copy"),
			KeyBinding.new(KEY_V | KEY_MASK_CTRL | KEY_MASK_SHIFT, "paste"),
		])

	# Font sizing: Command on macOS, Control elsewhere.
	var command := KEY_MASK_META if OS.get_name() == "macOS" else KEY_MASK_CTRL
	terminal.key_bindings.append_array([
		KeyBinding.new(KEY_EQUAL | command, "increase_font_size"),
		KeyBinding.new(KEY_EQUAL | command | KEY_MASK_SHIFT, "increase_font_size"),
		KeyBinding.new(KEY_MINUS | command, "decrease_font_size"),
		KeyBinding.new(KEY_0 | command, "reset_font_size"),
	])

	# Paths.stdpath: config (~/.config/graffitty), data (~/.local/share/graffitty),
	# cache (~/.cache/graffitty), state (~/.local/state/graffitty); XDG-aware.
	# App startup choice. World-specific effects are owned by each world.
	world.path = "" # Flat at startup.
	# world.path = Paths.stdpath("data").path_join("worlds/edinburgh-castle/edinburgh-castle.pck")

	# Menu placement is entirely ours. No worlds are added automatically.
	# Each callback receives the focused workspace host, after the menu closes.
	match OS.get_name():
		"macOS": menu = macos_menu()
		"Windows": menu = windows_menu()
		"Linux": menu = linux_menu()
	menu.append_array(view_effect_menu())
	# Native checkpoints (available after starting a session-aware Graffitty build).
	menu.append_array([
		MenuItem.new(["Sessions", "Save"], func(host): host.call("save_session"), Callable(), func(host): return host.has_method("save_session")),
		MenuItem.new(["Sessions", "Save and Quit"], func(host): host.call("save_session", "main", true), Callable(), func(host): return host.has_method("save_session")),
		MenuItem.new(["Sessions", "Restore Latest"], func(host): host.call("restore_session"), Callable(), func(host): return host.has_method("restore_session")),
		MenuItem.new(["Sessions", "History", "Main"], func(host): host.call("show_session_history", "main"), Callable(), func(host): return host.has_method("show_session_history")),
		MenuItem.new(["Sessions", "History", "Cron"], func(host): host.call("show_session_history", "cron"), Callable(), func(host): return host.has_method("show_session_history")),
	])

func macos_menu() -> Array[MenuItem]:
	var items: Array[MenuItem] = [
		MenuItem.new(["Shell", "New Terminal"], func(host: TerminalHost) -> void: host.world.create_terminal_tab(), Callable(), Callable(), KEY_T | KEY_MASK_META),
		MenuItem.new(["Shell", "New Browser"], func(host: TerminalHost) -> void: host.create_browser_session(), Callable(), Callable(), KEY_B | KEY_MASK_META),
		MenuItem.new(["View", "World", "Flat"], func(host: TerminalHost) -> void: host.switch_world(""), func(host: TerminalHost) -> bool: return host.current_plugin.is_empty()),
		MenuItem.new(["View", "World", "Flat 2D"], func(host: TerminalHost) -> void: host.switch_world("flat-2d"), func(host: TerminalHost) -> bool: return host.current_plugin == "flat-2d"),
		MenuItem.new(["View", "Messages"], func(host: TerminalHost) -> void: host.show_messages()),
		MenuItem.new(["View", "Snow"], func(host: TerminalHost) -> void: host.set_snow_enabled(not host.snow_enabled), snow_checked, snow_available),
	]
	items.append_array(external_world_menu())
	return items

func windows_menu() -> Array[MenuItem]:
	var items: Array[MenuItem] = [
		MenuItem.new(["File", "New Terminal"], func(host: TerminalHost) -> void: host.world.create_terminal_tab(), Callable(), Callable(), KEY_T | KEY_MASK_CTRL | KEY_MASK_SHIFT),
		MenuItem.new(["File", "New Browser"], func(host: TerminalHost) -> void: host.create_browser_session(), Callable(), Callable(), KEY_B | KEY_MASK_CTRL | KEY_MASK_SHIFT),
		MenuItem.new(["View", "World", "Flat"], func(host: TerminalHost) -> void: host.switch_world(""), func(host: TerminalHost) -> bool: return host.current_plugin.is_empty()),
		MenuItem.new(["View", "World", "Flat 2D"], func(host: TerminalHost) -> void: host.switch_world("flat-2d"), func(host: TerminalHost) -> bool: return host.current_plugin == "flat-2d"),
		MenuItem.new(["View", "Messages"], func(host: TerminalHost) -> void: host.show_messages()),
		MenuItem.new(["View", "Snow"], func(host: TerminalHost) -> void: host.set_snow_enabled(not host.snow_enabled), snow_checked, snow_available),
	]
	items.append_array(external_world_menu())
	return items

func linux_menu() -> Array[MenuItem]:
	var items: Array[MenuItem] = [
		MenuItem.new(["File", "New Terminal"], func(host: TerminalHost) -> void: host.world.create_terminal_tab(), Callable(), Callable(), KEY_T | KEY_MASK_CTRL | KEY_MASK_SHIFT),
		MenuItem.new(["File", "New Browser"], func(host: TerminalHost) -> void: host.create_browser_session(), Callable(), Callable(), KEY_B | KEY_MASK_CTRL | KEY_MASK_SHIFT),
		MenuItem.new(["View", "World", "Flat"], func(host: TerminalHost) -> void: host.switch_world(""), func(host: TerminalHost) -> bool: return host.current_plugin.is_empty()),
		MenuItem.new(["View", "World", "Flat 2D"], func(host: TerminalHost) -> void: host.switch_world("flat-2d"), func(host: TerminalHost) -> bool: return host.current_plugin == "flat-2d"),
		MenuItem.new(["View", "Messages"], func(host: TerminalHost) -> void: host.show_messages()),
		MenuItem.new(["View", "Snow"], func(host: TerminalHost) -> void: host.set_snow_enabled(not host.snow_enabled), snow_checked, snow_available),
	]
	items.append_array(external_world_menu())
	return items

func snow_checked(host: TerminalHost) -> bool:
	return snow_available(host) and host.snow_enabled

func snow_available(host: TerminalHost) -> bool:
	return host.world != null and host.world.fx_enabled and host.world.fx_weather == "snow"

func external_world_menu() -> Array[MenuItem]:
	var items: Array[MenuItem] = []
	# Only these explicitly configured external packs appear in the menu.
	# App installs contain Flat and Flat 2D; world packs are updated separately.
	for world in [
		{"id": "edinburgh-castle", "name": "Edinburgh Castle"},
		{"id": "bistro", "name": "Bistro"},
	]:
		var path := Paths.stdpath("data").path_join("worlds/%s/%s.pck" % [world.id, world.id])
		if not FileAccess.file_exists(path) or not FileAccess.file_exists(path.get_basename() + ".json"):
			continue
		items.append(MenuItem.new(["View", "World", world.name],
			func(host: TerminalHost) -> void: host.switch_world(path),
			func(host: TerminalHost) -> bool: return host.current_plugin == path))
	return items


# Ordinary config callbacks: the live effects object reads these targets each
# frame. Switching changes its destination without resetting the camera/shell.
const MILD_EFFECTS := {
	"lighting.strength": 0.6,
	"lighting.minimum": 0.0,
	"lighting.maximum": 1.4,
	"camera.dof_blur_tint": "#6f5fa8",
	"camera.dof_blur_tint_strength": 0.85,
	"lighting.color": "#fff0dc",
	"camera.zoom": 1.15,
	"camera.tilt_limit_deg": 4.0,
	"camera.drift_px": 2.0,
	"camera.drift_speed": 0.7,
	"sheet.ripple": 0.04,
	"sheet.curvature_deg": 1.5,
	"splash_scale": 0.2,
	"splash_speed": 300.0,
	"splash_life": 0.45,
}
const EXAGGERATED_EFFECTS := {
	"camera.dof_blur_tint_strength": 0.35,
	"lighting.strength": 1.8,
	"lighting.minimum": 0.0,
	"lighting.maximum": 1.4,
	"camera.dof_blur_tint": "#6f5fa8",
	"lighting.color": "#fff0dc",
	"camera.zoom": 2.0,
	"camera.tilt_limit_deg": 18.0,
	"camera.drift_px": 20.0,
	"camera.drift_speed": 2.0,
	"sheet.ripple": 1.5,
	"sheet.curvature_deg": 24.0,
	"splash_scale": 2.5,
	"splash_speed": 900.0,
	"splash_life": 1.1,
}

func view_effect_menu() -> Array[MenuItem]:
	return [
		MenuItem.new(["View", "Off"], set_view_effects_off, view_effects_off, view_effects_available),
		MenuItem.new(["View", "Mild"],
			func(host: TerminalHost) -> void: set_view_effects(host, MILD_EFFECTS),
			func(host: TerminalHost) -> bool: return view_effects_match(host, MILD_EFFECTS), view_effects_available),
		MenuItem.new(["View", "Exaggerated"],
			func(host: TerminalHost) -> void: set_view_effects(host, EXAGGERATED_EFFECTS),
			func(host: TerminalHost) -> bool: return view_effects_match(host, EXAGGERATED_EFFECTS), view_effects_available),
	]

func view_effects_available(host: TerminalHost) -> bool:
	return is_instance_valid(host.world) and host.world.get("fx_cfg") != null and host.world.get("fx_enabled") == true

func view_effects_off(host: TerminalHost) -> bool:
	return host.has_meta("view_effects_release")

func set_view_effects_off(host: TerminalHost) -> void:
	if not view_effects_available(host) or view_effects_off(host): return
	host.set_meta("view_effects_release", Actions.disable().call(host))

func set_view_effects(host: TerminalHost, values: Dictionary) -> void:
	if not view_effects_available(host): return
	if view_effects_off(host):
		var release: Callable = host.get_meta("view_effects_release")
		host.remove_meta("view_effects_release")
		release.call()
	var effects = host.world.fx_cfg
	effects.set_option("scene.sheet", "typing_shape", "saddle")
	var section := "state." + str(effects.behavior.active_state)
	for key in values:
		if key.begins_with("lighting.") or key.begins_with("camera.dof_"):
			var group := str(key).get_slice(".", 0)
			effects.set_option("scene." + group, str(key).get_slice(".", 1), values[key])
			continue
		effects.set_option("scene.typing" if key.begins_with("splash_") else section, key, values[key])
	# Scene-wide lighting and DOF tint are separate from animated state targets.
	host.world._fx_apply_scene()

func view_effects_match(host: TerminalHost, values: Dictionary) -> bool:
	if not view_effects_available(host) or view_effects_off(host): return false
	var effects = host.world.fx_cfg
	var frame: Dictionary = effects.frame(str(effects.behavior.active_state))
	for key in values:
		if key.begins_with("lighting.") or key.begins_with("camera.dof_"):
			var group := str(key).get_slice(".", 0)
			var actual = effects.scene.get(group, {}).get(str(key).get_slice(".", 1))
			if actual == null: return false
			if values[key] is String:
				if Color(str(actual)) != Color(values[key]): return false
			elif not is_equal_approx(float(actual), float(values[key])): return false
			continue
		var current = effects.scene.typing.get(key, INF) if key.begins_with("splash_") else frame.get(key, INF)
		if not is_equal_approx(float(current), float(values[key])): return false
	return true
