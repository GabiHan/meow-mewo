# Lives at /root/WindowKeys (settings.gd ensure_keys(), from the home screen and the game): the fullscreen
# key works everywhere, even while paused or typing.
extends Node

const Settings = preload("res://scripts/settings.gd")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if Settings.is_fullscreen_key(event):
		Settings.toggle_fullscreen()
		get_viewport().set_input_as_handled()
