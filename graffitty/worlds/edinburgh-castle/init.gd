extends "res://worlds/edinburgh-castle/godot/EdinburghCastleSettings.gd"

func _init(user: TerminalConfig) -> void:
	super(user)
	# Starts with a copy of your global TerminalConfig and Castle's defaults.
	terminal.background.alpha = 0.28
	render_scale = 0.8 # 0.25..1; lower values render fewer pixels.
	# Platform-specific settings can use ordinary GDScript:
	# if OS.get_name() == "macOS":
	#     render_scale = 0.75

	weather.kind = "snow" # none, snow, rain.
	weather.intensity = 1.4
	weather.opacity = 0.4

	camera.left_preserving_cursor_follow_threshold = 0.7
	camera.top_preserving_cursor_follow_threshold = 0.7
	camera.overscroll = 1.0

	lighting.minimum = 0.0
	lighting.maximum = 1.4
	camera.dof_blur_tint = Color("#6f5fa8")

	sheet.padding = 48.0
	sheet.content_gloss = 0.0
	sheet.corner_radius = 18.0
	sheet.edge_blur = 32.0


	behavior.enter_duration = 0.8
	behavior.idle_after = 1.5
	behavior.leave_duration = 2.5

	states.idle.camera_zoom = 1.0
	states.typing.particles = "sparks"
