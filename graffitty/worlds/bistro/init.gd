extends "res://worlds/scene-worlds/SceneWorldSettings.gd"

func _init(user: TerminalConfig) -> void:
	super(user)
	sheet.padding = 48.0
	terminal_window.blur_radius = 8.0 # Blur scenery behind terminal panes.
