# The Settings controls (settings.gd): volumes, mute, fullscreen. Built into any container: the home
# screen's Settings page, or the window from the in-game ☰ menu (hud.gd). Changes apply and save at once.
extends RefCounted

const Settings = preload("res://scripts/settings.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")

const SLIDERS := [["master", "Volume"], ["music", "Music"], ["sounds", "Sounds"]]


static func build(parent: Container) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	parent.add_child(grid)
	for row in SLIDERS:
		var key: String = row[0]
		var name := Label.new()
		name.text = row[1]
		name.custom_minimum_size = Vector2(90, 0)
		grid.add_child(name)
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = Settings.value(key)
		slider.custom_minimum_size = Vector2(220, 24)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(slider)
		var amount := Label.new()
		amount.text = "%d%%" % int(slider.value * 100.0)
		amount.custom_minimum_size = Vector2(48, 0)
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(amount)
		slider.value_changed.connect(func(v):
			amount.text = "%d%%" % int(v * 100.0)
			Settings.set_value(key, v))
	for row in [["muted", "Mute everything"], ["fullscreen", "Fullscreen"]]:
		var key: String = row[0]
		var box := CheckBox.new()
		box.text = row[1]
		box.button_pressed = Settings.value(key)
		box.toggled.connect(func(on): Settings.set_value(key, on))
		parent.add_child(box)
	var note := Label.new()
	note.text = "Music keeps its own pace when you speed the game up."
	note.add_theme_font_override("font", UiTheme.font(true))
	note.add_theme_font_size_override("font_size", 13)
	note.modulate = Color(1, 1, 1, 0.65)
	parent.add_child(note)
