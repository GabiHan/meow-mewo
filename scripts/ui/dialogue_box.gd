# The talking panel (Cozy Paws "DialogueBox"): a petal nameplate over a panel with the words, then either answer
# choices or a bobbing paw that means "continue". `body` takes extra content (talk_panel.gd puts the chat log and
# the text field there).
#   var d := DialogueBox.make("Mochi")
#   d.set_text("Mrrp! I found a strawberry patch…")
#   d.set_choices(["Yes please", "Not today"])   # chosen(index)
extends VBoxContainer

signal chosen(index: int)
signal continued

const UiTheme = preload("res://scripts/ui_theme.gd")
const CozyButton = preload("res://scripts/ui/cozy_button.gd")
const CozyIcon = preload("res://scripts/ui/cozy_icon.gd")

var nameplate: PanelContainer
var speaker_label: Label
var card: PanelContainer
var body: VBoxContainer
var text_label: Label
var choices_row: HFlowContainer
var paw: Control
var header: HBoxContainer  # the card's top row: subtitle + corner
var subtitle: Label
var corner: HBoxContainer  # right end of the top row (talk_panel.gd puts its close button here)


static func make(speaker := "") -> VBoxContainer:
	var d := new()
	d.build()
	d.set_speaker(speaker)
	return d


func build() -> void:
	add_theme_constant_override("separation", -14)  # the nameplate sits on the card's top edge
	var plate_row := MarginContainer.new()
	plate_row.add_theme_constant_override("margin_left", 22)
	plate_row.z_index = 1
	plate_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate_row)
	nameplate = PanelContainer.new()
	var plate := UiTheme.sticker("petal", UiTheme.RADIUS_PILL, UiTheme.STROKE_MD, 0)
	plate.content_margin_top = 2
	plate.content_margin_bottom = 3
	nameplate.add_theme_stylebox_override("panel", plate)
	nameplate.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	plate_row.add_child(nameplate)
	speaker_label = Label.new()
	speaker_label.add_theme_font_override("font", UiTheme.display_font())
	speaker_label.add_theme_font_size_override("font_size", 18)
	UiTheme.tint(speaker_label, "font_color", "on_petal")
	nameplate.add_child(speaker_label)
	card = PanelContainer.new()
	var style := UiTheme.panel()
	style.set_border_width_all(UiTheme.STROKE_LG)
	style.content_margin_top = 24
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", style)
	add_child(card)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	card.add_child(body)
	header = HBoxContainer.new()
	header.visible = false
	body.add_child(header)
	subtitle = Label.new()
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle.add_theme_font_size_override("font_size", 13)
	UiTheme.tint(subtitle, "font_color", "ink_muted")
	header.add_child(subtitle)
	corner = HBoxContainer.new()
	header.add_child(corner)
	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(320, 0)
	text_label.add_theme_font_size_override("font_size", 16)
	UiTheme.tint(text_label, "font_color", "ink")
	body.add_child(text_label)
	choices_row = HFlowContainer.new()
	choices_row.add_theme_constant_override("h_separation", 8)
	choices_row.add_theme_constant_override("v_separation", 8)
	choices_row.visible = false
	body.add_child(choices_row)
	paw = CozyIcon.make("paw", 20)
	paw.size_flags_horizontal = Control.SIZE_SHRINK_END
	body.add_child(paw)


# A small line in the card's top row (e.g. how you get on), with `corner` for buttons on its right.
func set_subtitle(text: String) -> void:
	subtitle.text = text
	header.visible = text != "" or corner.get_child_count() > 0


func set_speaker(name: String) -> void:
	speaker_label.text = name
	nameplate.visible = name != ""


func set_text(text: String) -> void:
	text_label.text = text
	text_label.visible = text != ""


# Answers as pill buttons: the first is the petal one, the rest quiet. An empty list brings the paw back.
func set_choices(choices: Array) -> void:
	for n in choices_row.get_children():
		n.queue_free()
	for i in choices.size():
		var b := CozyButton.make(choices[i], "petal" if i == 0 else "quiet", "", true)
		b.pressed.connect(func(): chosen.emit(i))
		choices_row.add_child(b)
	choices_row.visible = not choices.is_empty()
	paw.visible = choices.is_empty()


func show_paw(on: bool) -> void:
	paw.visible = on


func _gui_input(event: InputEvent) -> void:
	if paw.visible and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		continued.emit()


func _process(_delta: float) -> void:
	if paw.visible:
		paw.pivot_offset = paw.size / 2.0
		paw.scale = Vector2.ONE * (1.0 + 0.06 * sin(Time.get_ticks_msec() / 150.0))
