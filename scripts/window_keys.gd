# Lives at /root/WindowKeys (settings.gd ensure_keys(), from the home screen and the game):
#   - the fullscreen key works everywhere, even while paused or typing;
#   - the UI size: whenever the window changes size, the UI is scaled to suit the screen (ui_scale()).
#
# UI size: everything is laid out in "UI units" (project.godot stretch canvas_items + expand). The scale is
# the window height / REFERENCE_HEIGHT (so a 1080p screen gets ×1.2: big enough to read across the room,
# not so big the panels cover the town), but never more than the window can hold at MIN_UI_SIZE (1280×720
# UI units, what the HUD needs so nothing overlaps) and never under 1 on a window bigger than that.
extends Node

const Settings = preload("res://scripts/settings.gd")
const MIN_UI_SIZE := Vector2(1280, 720)
const REFERENCE_HEIGHT := 900.0  # a window this tall shows the UI at ×1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if DisplayServer.get_name() == "headless":
		return  # tests keep the project's 1280×720
	get_window().size_changed.connect(fit_ui)
	fit_ui()


func _input(event: InputEvent) -> void:
	if Settings.is_fullscreen_key(event):
		Settings.toggle_fullscreen()
		get_viewport().set_input_as_handled()


# How much bigger than 1 UI unit per pixel the UI is drawn in a window of `size` pixels.
static func ui_scale(size: Vector2) -> float:
	var fits := minf(size.x / MIN_UI_SIZE.x, size.y / MIN_UI_SIZE.y)  # the most that still leaves 1280×720 of room
	return minf(maxf(size.y / REFERENCE_HEIGHT, minf(1.0, fits)), fits)


# The room (in UI units) a window of `size` pixels gives: at least MIN_UI_SIZE.
static func ui_size(size: Vector2) -> Vector2i:
	return Vector2i((size / ui_scale(size)).round())


func fit_ui() -> void:
	var window := get_window()
	window.content_scale_size = ui_size(Vector2(window.size))
