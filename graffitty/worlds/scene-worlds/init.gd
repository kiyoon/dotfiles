extends "res://worlds/scene-worlds/SceneWorldSettings.gd"

func _init(user: TerminalConfig) -> void:
	super(user)
	sheet.padding = 48.0
	terminal_window.blur_radius = 0.0 # Pixels; try 8.0 for frosted panes.
