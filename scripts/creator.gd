# The character creator: dress up a paper doll (looks.gd, doll.gd). Opened over the household creator
# (menu.gd) for one person; emits `finished` with the new look, or {} when cancelled.
#
#   left:   the doll as it looks now, "Randomise" (a random look of that person's sex)
#   right:  tabs Body (skin, figure, eyes, lashes, eyebrows, mouth, lips) | Hair (colour, hair, fringe, long hair,
#           braids & locks, beard) | Clothes (top, bottom, dress, shoes, gloves, each with its colour)
#           ◂ ▸ step through a part's pictures (None where a part is optional); swatches pick colours.
# A dress replaces the top and bottom (and picking a top or bottom takes the dress off).
extends Control

signal finished(look: Dictionary)

const UiTheme = preload("res://scripts/ui_theme.gd")
const Looks = preload("res://scripts/looks.gd")
const Doll = preload("res://scripts/doll.gd")
const TABS := ["Body", "Hair", "Clothes"]
const PREVIEW_SCALE := 1.45
const SWATCH := Vector2(22, 22)

var look := {}
var sex := "F"
var grown := true
var doll: Node2D
var rows: VBoxContainer
var tab_buttons := {}
var refreshers: Array[Callable] = []


func setup(p_look: Dictionary, p_sex: String, p_grown := true) -> Control:
	look = p_look.duplicate() if not p_look.is_empty() else Looks.random_for(p_sex)
	sex = p_sex
	grown = p_grown
	return self


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.INK, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", padded(UiTheme.flat(UiTheme.PAPER, UiTheme.ACCENT_SOFT), 18))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var title := Label.new()
	title.text = "Create a character"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", UiTheme.INK)
	column.add_child(title)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	column.add_child(body)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	var stage := PanelContainer.new()
	stage.add_theme_stylebox_override("panel", UiTheme.flat(UiTheme.ACCENTS[9].lerp(Color.WHITE, 0.75), UiTheme.LINE))
	left.add_child(stage)
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(290, 470)
	stage.add_child(preview)
	doll = Doll.new()
	doll.scale = Vector2.ONE * PREVIEW_SCALE
	doll.position = Vector2(145, 455)
	preview.add_child(doll)
	var shuffle := Button.new()
	shuffle.text = "Randomise ✿"
	shuffle.custom_minimum_size = Vector2(0, 40)
	shuffle.pressed.connect(func():
		look = Looks.random_for(sex)
		changed())
	left.add_child(shuffle)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.custom_minimum_size = Vector2(520, 0)
	body.add_child(right)
	var tabs := HBoxContainer.new()
	right.add_child(tabs)
	for t in TABS:
		var b := Button.new()
		b.text = t
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(110, 36)
		b.pressed.connect(show_tab.bind(t))
		tabs.add_child(b)
		tab_buttons[t] = b
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 10)
	column.add_child(buttons)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(120, 42)
	cancel.pressed.connect(func(): close({}))
	buttons.add_child(cancel)
	var done := Button.new()
	done.name = "Done"
	done.text = "Done"
	done.custom_minimum_size = Vector2(160, 42)
	done.add_theme_stylebox_override("normal", UiTheme.flat(UiTheme.ACTIVE_FILL, UiTheme.ACCENT))
	done.pressed.connect(func(): close(look))
	buttons.add_child(done)
	show_tab(TABS[0])
	changed()


func close(result: Dictionary) -> void:
	finished.emit(result)
	queue_free()


func padded(style: StyleBoxFlat, margin: int) -> StyleBoxFlat:
	style.set_content_margin_all(margin)
	return style


func show_tab(tab: String) -> void:
	for t in tab_buttons:
		tab_buttons[t].button_pressed = t == tab
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	refreshers.clear()
	match tab:
		"Body":
			swatch_row("Skin", "skin", range(Looks.count("skin")).map(func(i): return Looks.tone(i + 1)), 1)
			for key in ["figure", "eyes", "lashes", "brows", "mouth"]:
				picker_row(key)
			swatch_row("Lips", "lips", Looks.LIPS)
		"Hair":
			swatch_row("Hair colour", "hair_color", Looks.HAIR)
			for key in ["hair", "bangs", "back", "bonus", "beard"]:
				picker_row(key)
		"Clothes":
			for key in ["top", "bottom", "dress", "shoes", "gloves"]:
				picker_row(key)
				swatch_row("", key + "_color", Looks.CLOTHES)
	refresh()


# ◂ value ▸ for one part (Looks.PARTS).
func picker_row(key: String) -> void:
	var part := Looks.part_info(key)
	var row := HBoxContainer.new()
	row.name = key
	row.add_theme_constant_override("separation", 8)
	rows.add_child(row)
	var name := Label.new()
	name.text = part.label + (" (grown-ups)" if part.get("grown", false) else "")
	name.custom_minimum_size = Vector2(170, 0)
	name.add_theme_font_size_override("font_size", 17)
	row.add_child(name)
	var value := Label.new()
	for step in [-1, 1]:
		var b := Button.new()
		b.text = "◂" if step < 0 else "▸"
		b.custom_minimum_size = Vector2(36, 32)
		b.pressed.connect(func(): pick(key, step))
		row.add_child(b)
		if step < 0:
			value.custom_minimum_size = Vector2(90, 0)
			value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.add_child(value)
	refreshers.append(func():
		var n := int(look.get(key, 0))
		value.text = "None" if n == 0 else "%d / %d" % [n, Looks.count(key)])


# Step a part to its next (or previous) picture, through None when it's optional.
func pick(key: String, step: int) -> void:
	var part := Looks.part_info(key)
	var first := 0 if part.none else 1
	var n := Looks.count(key)
	var value := int(look.get(key, first)) + step
	if value > n:
		value = first
	elif value < first:
		value = n
	look[key] = value
	if key == "dress" and value > 0:
		look.top = 0
		look.bottom = 0
	elif key in ["top", "bottom"] and value > 0:
		look.dress = 0
	changed()


# A row of colour swatches; picking one sets look[key] to its index (+ base: skins count from 1).
func swatch_row(title: String, key: String, colors: Array, base := 0) -> void:
	if title != "":
		var name := Label.new()
		name.text = title
		name.add_theme_font_size_override("font_size", 17)
		rows.add_child(name)
	var flow := HFlowContainer.new()
	flow.name = key
	flow.add_theme_constant_override("h_separation", 4)
	flow.add_theme_constant_override("v_separation", 4)
	rows.add_child(flow)
	var swatches := []
	for i in colors.size():
		var b := Button.new()
		b.custom_minimum_size = SWATCH
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func():
			look[key] = i + base
			changed())
		flow.add_child(b)
		swatches.append(b)
	refreshers.append(func():
		var chosen := int(look.get(key, base)) - base
		for i in swatches.size():
			var on: bool = i == chosen
			var style := UiTheme.flat(colors[i], UiTheme.INK if on else UiTheme.LINE, 3 if on else 1)
			for state in ["normal", "hover", "pressed"]:
				swatches[i].add_theme_stylebox_override(state, style))


func changed() -> void:
	doll.show_look(look, grown)
	refresh()


func refresh() -> void:
	for f in refreshers:
		f.call()
