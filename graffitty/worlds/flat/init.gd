extends "res://scenes/FlatWorldSettings.gd"

func _init(user: TerminalConfig) -> void:
	super(user)
	terminal_window.blur_radius = 0.0 # Pixels; try 8.0 for frosted panes.
	terminal_window.padding = Vector4(8, 8, 8, 8) # Left, top, right, bottom.
