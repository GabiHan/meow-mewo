# Renders every Cozy Paws component in day and dusk to user://ui_gallery_day.png / _dusk.png (needs a window).
#   godot --path . -s res://tools/ui_gallery.gd
extends SceneTree

const UiTheme = preload("res://scripts/ui_theme.gd")
const CozyButton = preload("res://scripts/ui/cozy_button.gd")
const CozyIcon = preload("res://scripts/ui/cozy_icon.gd")
const NeedBar = preload("res://scripts/ui/need_bar.gd")
const DialogueBox = preload("res://scripts/ui/dialogue_box.gd")
const ToastStack = preload("res://scripts/ui/toast_stack.gd")
const ItemTooltip = preload("res://scripts/ui/item_tooltip.gd")
const Hotbar = preload("res://scripts/ui/hotbar.gd")

var frames := 0
var page: Control


func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	build()


func build() -> void:
	page = PanelContainer.new()
	page.theme = UiTheme.get_theme()
	page.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ground := StyleBoxFlat.new()
	ground.bg_color = UiTheme.c("surface_100")
	UiTheme.track(ground)
	ground.set_content_margin_all(24)
	page.add_theme_stylebox_override("panel", ground)
	root.add_child(page)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 32)
	page.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 18)
	cols.add_child(left)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.add_child(CozyButton.make("Go to sleep", "petal", "moon"))
	buttons.add_child(CozyButton.make("Plant seeds", "leaf", "sprout"))
	buttons.add_child(CozyButton.make("Maybe later"))
	buttons.add_child(CozyButton.make("Toss item", "berry"))
	left.add_child(buttons)
	var d := DialogueBox.make("Mochi")
	d.set_text("Mrrp! I found a strawberry patch behind the old mill. Want to see it tomorrow?")
	d.set_choices(["Yes please", "Not today"])
	left.add_child(d)
	left.add_child(Hotbar.make([["sprout", 8], ["strawberry", 12], ["fish", 2], ["flower", 5], [], []], 1))
	var icons := HFlowContainer.new()
	for n in CozyIcon.NAMES:
		icons.add_child(CozyIcon.make(n, 32))
	left.add_child(icons)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.custom_minimum_size.x = 380
	cols.add_child(right)
	var values := {"hunger": 64, "thirst": 45, "energy": 72, "fun": 90, "bladder": 30, "hygiene": 55, "social": 12}
	for need in values:
		var b := NeedBar.make(need, true, 12)
		b.set_value(values[need])
		right.add_child(b)
	right.add_child(ItemTooltip.make("Wild strawberry", "fresh", "Sweet and sun-warm. The kittens keep sneaking these.", 40, "x12"))
	var toasts := ToastStack.new()
	right.add_child(toasts)
	toasts.push("Got a gift from Mochi", "Check your mailbox.", "item", 99)
	toasts.push("Feeling sleepy", "Rest a little before you keep going.", "warning", 99)
	var field := LineEdit.new()
	field.placeholder_text = "Say something…"
	right.add_child(field)


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 10:
		save("day")
		UiTheme.set_dusk(true)
	elif frames == 20:
		save("dusk")
		UiTheme.release()
		return true
	return false


func save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(OS.get_user_data_dir() + "/ui_gallery_%s.png" % name)
	print("saved ", OS.get_user_data_dir() + "/ui_gallery_%s.png" % name)
