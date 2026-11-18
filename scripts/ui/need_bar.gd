# A need as a pill meter (Cozy Paws "StatBar"): icon disc, outlined track, fill, the number. Each need keeps its colour
# so players learn them; at or below LOW the fill turns berry (the icon keeps its colour).
#   var bar := NeedBar.make("energy", true)   then   bar.set_value(72)
extends HBoxContainer

const UiTheme = preload("res://scripts/ui_theme.gd")
const CozyIcon = preload("res://scripts/ui/cozy_icon.gd")
const LOW := 25.0
const NEEDS := {  # need -> [token, icon]
	"hunger": ["peach", "apple"], "thirst": ["sky", "drop"], "energy": ["leaf", "bolt"], "fun": ["butter", "sparkle"],
	"bladder": ["aqua", "roll"], "hygiene": ["bubble", "bubbles"], "social": ["petal", "heart"],
	"mood": ["butter", "smile"], "friendship": ["petal", "heart"],
}

var need := "energy"
var bar: ProgressBar
var fill: StyleBoxFlat
var value_label: Label
var name_label: Label
var low := false


static func make(p_need: String, show_name := false, height := 16) -> HBoxContainer:
	var b := new()
	b.need = p_need
	b.build(show_name, height)
	return b


func build(show_name: bool, height: int) -> void:
	add_theme_constant_override("separation", 6)
	var kind: Array = NEEDS.get(need, ["petal", "sparkle"])
	var disc := PanelContainer.new()
	disc.add_theme_stylebox_override("panel", UiTheme.sticker(kind[0], UiTheme.RADIUS_PILL, UiTheme.STROKE_SM, 0))
	disc.get_theme_stylebox("panel").set_content_margin_all(2)
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	disc.add_child(CozyIcon.make(kind[1], 16))
	disc.tooltip_text = need.capitalize()
	add_child(disc)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	if show_name:
		name_label = Label.new()
		name_label.text = need.capitalize()
		name_label.add_theme_font_size_override("font_size", 12)
		UiTheme.tint(name_label, "font_color", "ink_muted")
		column.add_child(name_label)
	bar = ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(80, height)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER if not show_name else Control.SIZE_FILL
	bar.add_theme_stylebox_override("background", UiTheme.sticker("surface_300", UiTheme.RADIUS_PILL, UiTheme.STROKE_SM, 0))
	fill = UiTheme.sticker(kind[0], UiTheme.RADIUS_PILL, UiTheme.STROKE_SM, 0)
	bar.add_theme_stylebox_override("fill", fill)
	column.add_child(bar)
	value_label = Label.new()
	value_label.custom_minimum_size = Vector2(28, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_vertical = Control.SIZE_SHRINK_END if show_name else Control.SIZE_SHRINK_CENTER
	value_label.add_theme_font_override("font", UiTheme.display_font())
	value_label.add_theme_font_size_override("font_size", 15)
	UiTheme.tint(value_label, "font_color", "ink")
	add_child(value_label)


# 0..100. The fill turns berry at or below LOW; the number always shows (never colour alone).
func set_value(v: float) -> void:
	bar.value = v
	value_label.text = str(int(v))
	var now_low := v <= LOW
	if now_low != low or bar.get_meta("painted", false) == false:
		low = now_low
		bar.set_meta("painted", true)
		var token: String = "berry" if low else NEEDS.get(need, ["petal"])[0]
		recolor(token)


func recolor(token: String) -> void:
	fill.bg_color = UiTheme.c(token)
	for e in UiTheme._styles:
		if e[0].get_ref() == fill:
			e[1] = token
