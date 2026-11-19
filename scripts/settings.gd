# Player settings, saved in user://settings.cfg and applied at once. Static.
#   master   overall volume 0..1 (the Master audio bus)
#   music    music volume 0..1 (the Music bus, music.gd)
#   sounds   other sounds 0..1 (the Sounds bus; for sound effects to come)
#   muted    everything silent
#   fullscreen   on by default; the window also opens fullscreen (project.godot window/size/mode=3) so it never flashes
#   ai_directs   the local language model decides what NPCs near you do (llm.gd decide()), when it's running
# Changed from Settings on the home screen or the in-game ☰ menu (settings_panel.gd). Fullscreen also has a key
# everywhere: F11, Alt+Enter or Ctrl+Cmd+F (window_keys.gd, made by ensure_keys()).
# The window scales everything (project.godot stretch "canvas_items" + "expand"): the screen is always at least
# 1280×720 in UI units, bigger screens show the same UI larger, wider/taller ones get extra room.
const PATH := "user://settings.cfg"
const DEFAULTS := {"master": 0.8, "music": 0.6, "sounds": 0.8, "muted": false, "fullscreen": true, "ai_directs": true}
const BUSES := {"master": "Master", "music": "Music", "sounds": "Sounds"}

static var values := {}


static func value(key: String) -> Variant:
	if values.is_empty():
		load_settings()
	return values.get(key, DEFAULTS[key])


static func load_settings() -> void:
	values = DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for key in DEFAULTS:
			values[key] = cfg.get_value("settings", key, DEFAULTS[key])
	apply()


static func set_value(key: String, v: Variant) -> void:
	if values.is_empty():
		load_settings()
	values[key] = v
	apply()
	var cfg := ConfigFile.new()
	for k in values:
		cfg.set_value("settings", k, values[k])
	cfg.save(PATH)


# Make sure the Music and Sounds buses exist (sent to Master), then set every volume.
static func apply() -> void:
	for key in BUSES:
		var bus := AudioServer.get_bus_index(BUSES[key])
		if bus < 0:
			AudioServer.add_bus()
			bus = AudioServer.bus_count - 1
			AudioServer.set_bus_name(bus, BUSES[key])
			AudioServer.set_bus_send(bus, "Master")
		var level: float = values.get(key, DEFAULTS[key])
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(level, 0.0001)))
	AudioServer.set_bus_mute(0, values.get("muted", false))
	if DisplayServer.get_name() != "headless":
		var full: bool = values.get("fullscreen", false)
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode and (full or DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN):
			DisplayServer.window_set_mode(mode)


static func toggle_fullscreen() -> void:
	set_value("fullscreen", not value("fullscreen"))


static func is_fullscreen_key(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return false
	var key: InputEventKey = event
	return key.keycode == KEY_F11 or (key.keycode == KEY_ENTER and key.alt_pressed) \
		or (key.keycode == KEY_F and key.ctrl_pressed and key.meta_pressed)


# The node at /root/WindowKeys that listens for the fullscreen key on every screen (home, creator, game).
static func ensure_keys(tree: SceneTree) -> void:
	if tree.root.has_node("WindowKeys"):
		return
	var keys: Node = load("res://scripts/window_keys.gd").new()
	keys.name = "WindowKeys"
	tree.root.add_child.call_deferred(keys)
