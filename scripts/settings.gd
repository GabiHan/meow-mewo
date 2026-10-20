# Player settings, saved in user://settings.cfg and applied at once. Static.
#   master   overall volume 0..1 (the Master audio bus)
#   music    music volume 0..1 (the Music bus, music.gd)
#   sounds   other sounds 0..1 (the Sounds bus; for sound effects to come)
#   muted    everything silent
#   fullscreen
# Changed from Settings on the home screen or the in-game ☰ menu (settings_panel.gd).
const PATH := "user://settings.cfg"
const DEFAULTS := {"master": 0.8, "music": 0.6, "sounds": 0.8, "muted": false, "fullscreen": false}
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
