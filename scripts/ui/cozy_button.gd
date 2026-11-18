# Chunky sticker buttons (Cozy Paws "Button"): a token fill, the cocoa outline, a hard shadow; pressed sinks 3 px.
#   CozyButton.make("Go to sleep", "petal", "moon")
# Variants: "petal" the one main action on a screen, "leaf" confirm something good, "quiet" (default) everything else,
# "berry" only for careful actions (throw away, delete). `pill` for choices in a dialogue.
extends RefCounted

const UiTheme = preload("res://scripts/ui_theme.gd")
const CozyIcon = preload("res://scripts/ui/cozy_icon.gd")
const FILLS := {"petal": ["petal", "petal_strong"], "leaf": ["leaf", "leaf"], "quiet": ["surface_200", "petal_hover"],
	"berry": ["berry", "berry"]}


static func make(text: String, variant := "quiet", icon := "", pill := false) -> Button:
	var b := Button.new()
	b.text = text
	style(b, variant, pill)
	if icon != "":
		var i := CozyIcon.make(icon, 18)
		i.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		i.offset_left = 12
		i.offset_top = -9
		i.offset_bottom = 9
		i.offset_right = 30
		b.add_child(i)
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var s: StyleBox = b.get_theme_stylebox(state)
			s.content_margin_left += 22
	return b


static func style(b: Button, variant := "quiet", pill := false) -> void:
	var fills: Array = FILLS.get(variant, FILLS.quiet)
	var radius := UiTheme.RADIUS_PILL if pill else UiTheme.RADIUS_MD
	var states := {"normal": [fills[0], false], "hover": [fills[1], false], "pressed": [fills[1], true],
		"hover_pressed": [fills[1], true], "disabled": ["surface_300", false]}
	for state in states:
		var s := UiTheme.button_style(states[state][0], states[state][1])
		s.set_corner_radius_all(radius)
		b.add_theme_stylebox_override(state, s)
	var on: String = "ink" if variant == "quiet" else UiTheme.ON[fills[0]]
	for name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		UiTheme.tint(b, name, on)
	b.add_theme_font_size_override("font_size", 15)
	b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, 40)
