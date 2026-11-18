# One item stack (Cozy Paws "InventorySlot"): a 56 px rounded square. Empty = a sunken well, filled = raised paper,
# selected = petal ring and fill; a butter bubble shows the count above 1; an optional small hotkey number.
# Not used by the game yet (there's no inventory): ready for when there is one.
#   var s := InventorySlot.make("strawberry", 12)   s.set_selected(true)
extends Button

const UiTheme = preload("res://scripts/ui_theme.gd")
const CozyIcon = preload("res://scripts/ui/cozy_icon.gd")
const SIZE := 56

var item := ""
var count := 0
var selected := false
var icon_view: Control
var count_label: Label
var key_label: Label


static func make(p_item := "", p_count := 1, hotkey := "") -> Button:
	var s := new()
	s.build(hotkey)
	s.set_item(p_item, p_count)
	return s


func build(hotkey: String) -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	focus_mode = Control.FOCUS_NONE
	toggle_mode = false
	icon_view = CozyIcon.make("", 36)
	icon_view.set_anchors_preset(Control.PRESET_CENTER)
	icon_view.offset_left = -18
	icon_view.offset_top = -18
	icon_view.offset_right = 18
	icon_view.offset_bottom = 18
	add_child(icon_view)
	count_label = Label.new()
	count_label.add_theme_font_override("font", UiTheme.display_font())
	count_label.add_theme_font_size_override("font_size", 12)
	UiTheme.tint(count_label, "font_color", "on_butter")
	var bubble := UiTheme.sticker("butter", UiTheme.RADIUS_SM, UiTheme.STROKE_SM, 0)
	bubble.content_margin_left = 5
	bubble.content_margin_right = 5
	bubble.content_margin_top = 0
	bubble.content_margin_bottom = 0
	count_label.add_theme_stylebox_override("normal", bubble)
	count_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	count_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	count_label.offset_right = 7
	count_label.offset_bottom = 7
	add_child(count_label)
	key_label = Label.new()
	key_label.text = hotkey
	key_label.position = Vector2(5, 1)
	key_label.add_theme_font_size_override("font_size", 11)
	UiTheme.tint(key_label, "font_color", "ink_muted")
	add_child(key_label)
	_restyle()


func set_item(p_item: String, p_count := 1) -> void:
	item = p_item
	count = p_count if p_item != "" else 0
	icon_view.visible = item != ""
	icon_view.set_icon(item)
	count_label.text = str(count)
	count_label.visible = count > 1
	tooltip_text = item.capitalize() if item != "" else ""
	_restyle()


func set_selected(on: bool) -> void:
	selected = on
	_restyle()


func _restyle() -> void:
	var fill := "petal_soft" if selected else ("surface_200" if item != "" else "surface_300")
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		var s := UiTheme.button_style(fill if state == "normal" else ("petal_soft" if selected else "petal_hover"), state.contains("pressed"))
		s.set_content_margin_all(0)
		if selected:
			s.border_color = UiTheme.c("petal_strong")
			UiTheme._styles[-1][2] = "petal_strong"
		add_theme_stylebox_override(state, s)
