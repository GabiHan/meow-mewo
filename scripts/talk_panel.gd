# The window for talking to someone in your own words (click a person → "Talk…"; the conversation
# itself is talk.gd). You type, they answer: an NPC with the language model (llm.gd), a real person
# (online) by typing back. Opens by itself when another player starts talking to you.
# Enter sends, Esc or x closes. It closes by itself if they leave (work, someone else, too far).
# What you do goes through Net.order(), so online it happens on the host.
extends PanelContainer

const Social = preload("res://scripts/social.gd")
const Llm = preload("res://scripts/llm.gd")
const Net = preload("res://scripts/net.gd")
const Talk = preload("res://scripts/talk.gd")
const UiTheme = preload("res://scripts/ui_theme.gd")
const MAX_LINES := 12
const GRACE_MSEC := 2000  # online, their side catches up a moment after opening

var you: Node2D
var npc: Node2D
var history := []  # {you: bool, text}
var title: Label
var log_label: Label
var input: LineEdit
var waiting := false
var opened_at := 0


func _ready() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -230
	offset_right = 230
	offset_bottom = -96  # above the bottom row
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PAPER, 4, UiTheme.ACCENT_SOFT))
	visible = false
	var column := VBoxContainer.new()
	add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 15)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close_button := Button.new()
	close_button.text = "x"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	head.add_child(close_button)
	log_label = Label.new()
	log_label.add_theme_font_size_override("font_size", 13)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.custom_minimum_size = Vector2(440, 0)
	column.add_child(log_label)
	input = LineEdit.new()
	input.placeholder_text = "Say something… (Enter to send, Esc to leave)"
	input.max_length = 200
	input.text_submitted.connect(send)
	input.gui_input.connect(func(event):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			close())
	column.add_child(input)


func game() -> Node2D:
	return get_tree().get_first_node_in_group("game")


# You start talking to them.
func open(p_you: Node2D, p_npc: Node2D) -> void:
	if visible:
		close()
	show_window(p_you, p_npc)
	Net.order(game(), "talk_open", [npc.npc_name])


# Another player started talking to you (talk.gd).
func incoming(from: Node2D) -> void:
	show_window(game().player, from)


func show_window(p_you: Node2D, p_npc: Node2D) -> void:
	you = p_you
	npc = p_npc
	history = []
	waiting = false
	opened_at = Time.get_ticks_msec()
	visible = true
	refresh()
	input.grab_focus()


func send(text: String) -> void:
	text = text.strip_edges()
	if text == "" or waiting or npc == null:
		return
	input.clear()
	history.append({"you": true, "text": text})
	waiting = not Talk.is_human(npc)  # a real person answers when they want to
	Net.order(game(), "talk_send", [text, history])
	refresh()


# An NPC answered (talk.gd), or the AI is off.
func answered(d: Dictionary) -> void:
	waiting = false
	if not visible:
		return
	history.append({"you": false, "text": d.get("reply", "...")})
	refresh()


# The other player said something.
func received(text: String) -> void:
	if visible:
		history.append({"you": false, "text": text})
		refresh()


# The other side ended it.
func closed() -> void:
	visible = false
	waiting = false
	npc = null


func refresh() -> void:
	if not is_instance_valid(npc):
		return
	var name := Social.display_name(you, npc)
	var who := " (a real person)" if Talk.is_human(npc) else ""
	title.text = "Talking with %s%s — %s (%d)" % [name, who, Social.relationship_word(Social.friendship(npc, you)), Social.friendship(npc, you)]
	var lines := history.map(func(h): return ("You: " if h.you else name + ": ") + h.text)
	if waiting:
		lines.append(name + " is thinking…")
	if lines.is_empty():
		lines.append("Say hello!")
	log_label.text = "\n".join(lines.slice(maxi(0, lines.size() - MAX_LINES)))


func close() -> void:
	if not visible:
		return
	closed()
	Net.order(game(), "talk_close", [])


func _process(_delta: float) -> void:
	if not visible:
		return
	if Time.get_ticks_msec() - opened_at < GRACE_MSEC:
		return
	if not is_instance_valid(npc) or npc.partner != you or you.partner != npc:
		closed()  # it ended on its own (they left, or it was closed on the other side)
	elif not Llm.can_talk(you, npc):
		close()


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_pressed() and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
