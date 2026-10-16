# Build mode, like The Sims' buy mode: a catalog of furniture to place in your home. B (or the Build
# button) toggles it while the person you control is at home. Time is paused while building.
#
#   Click a category, then an item     -> a preview follows the mouse (green: fits, red: doesn't)
#   R                                  -> rotate
#   Left-click                         -> buy and place it (or put down what you're moving)
#   Right-click / Esc                  -> stop placing (a moved item goes back where it was)
#   Left-click your furniture (nothing selected) -> Rotate (in place), Move, or Delete (sold: 75% back)
#   "Other floor"                      -> build upstairs/downstairs
# Rules and prices are in catalog.gd; documentation in docs/BUILD.md.
extends CanvasLayer

const Iso = preload("res://scripts/iso.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Furniture = preload("res://scripts/furniture.gd")
const Social = preload("res://scripts/social.gd")

const PANEL_HEIGHT := 178
const FOOTER_HEIGHT := 64  # hud.gd's footer band sits below the catalog

var main: Node2D
var active := false
var was_paused := false
var category := "Seating"
var selected := ""  # catalog id being placed
var rot := 0
var moving: Dictionary = {}  # {cell, rot, floor} of the item being moved (placed for free; Esc puts it back)
var cell := Vector2i.ZERO

var panel: PanelContainer
var items_row: HBoxContainer
var info: Label
var ghost: Node2D
var ghost_sprite: Sprite2D
var ghost_box: Polygon2D


func setup(p_main: Node2D) -> CanvasLayer:
	main = p_main
	return self


func _ready() -> void:
	add_to_group("build_mode")
	build_panel()
	panel.theme = load("res://scripts/ui_theme.gd").get_theme()
	ghost = Node2D.new()
	ghost.z_index = 60
	ghost.visible = false
	main.world.add_child(ghost)
	ghost_sprite = Sprite2D.new()
	ghost_sprite.centered = false
	ghost.add_child(ghost_sprite)
	ghost_box = Polygon2D.new()
	ghost_box.polygon = PackedVector2Array([Vector2(-28, -28), Vector2(0, -42), Vector2(28, -28), Vector2(28, 0), Vector2(0, 14), Vector2(-28, 0)])
	ghost.add_child(ghost_box)


func build_panel() -> void:
	panel = PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -FOOTER_HEIGHT - PANEL_HEIGHT
	panel.offset_bottom = -FOOTER_HEIGHT
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.97, 0.96, 0.99, 0.97)
	style.border_width_top = 3
	style.border_color = Color("#f5ccd4")
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	panel.visible = false
	add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	info = Label.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(info)
	var floor_button := Button.new()
	floor_button.text = "Other floor"
	floor_button.focus_mode = Control.FOCUS_NONE
	floor_button.pressed.connect(other_floor)
	top.add_child(floor_button)
	var done := Button.new()
	done.text = "Done (B)"
	done.focus_mode = Control.FOCUS_NONE
	done.pressed.connect(toggle)
	top.add_child(done)
	var tabs := HBoxContainer.new()
	column.add_child(tabs)
	for cat in Catalog.CATEGORIES:
		var b := Button.new()
		b.text = cat
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(show_category.bind(cat))
		tabs.add_child(b)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	items_row = HBoxContainer.new()
	scroll.add_child(items_row)
	show_category(category)


func show_category(cat: String) -> void:
	category = cat
	for b in panel.get_child(0).get_child(1).get_children():
		b.set_pressed_no_signal(b.text == cat)
	for child in items_row.get_children():
		child.queue_free()
	for id in Catalog.in_category(cat):
		var item: Dictionary = Catalog.ITEMS[id]
		var b := Button.new()
		b.text = "%s\n$%d" % [item.name, item.price]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(118, 104)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.expand_icon = true
		if item.model != "":
			b.icon = Furniture.texture(Catalog.sprite(id, 0))
		b.tooltip_text = "%s · $%d%s" % [item.name, item.price, " · usable" if item.has("object") else ""]
		b.pressed.connect(select.bind(id))
		items_row.add_child(b)


# --- On / off ---

func toggle() -> void:
	if active:
		close()
		return
	var p: Node2D = main.player
	if p.home < 0 or p.building != p.home:
		p.show_emote("Go home to build", null)
		return
	active = true
	panel.visible = true
	main.camera.offset = Vector2(0, 110)  # lift the house above the catalog
	was_paused = main.paused
	if not main.paused:
		main.toggle_pause()


func close() -> void:
	cancel()
	active = false
	panel.visible = false
	main.camera.offset = Vector2.ZERO
	ghost.visible = false
	if main.paused and not was_paused:
		main.toggle_pause()


func select(id: String) -> void:
	cancel()
	selected = id
	rot = 0


# Stop placing; something being moved goes back where it was (for free).
func cancel() -> void:
	if selected != "" and not moving.is_empty():
		Catalog.place(main.player, selected, moving.cell, moving.rot, moving.floor, true)
	selected = ""
	moving = {}
	ghost.visible = false


func other_floor() -> void:
	var p: Node2D = main.player
	var b: Dictionary = main.world.BUILDINGS[p.home]
	if not b.has("stairs") or b.floors < 2:
		p.show_emote("This house has one floor", null)
		return
	p.cancel_current()
	p.floor = 1 - p.floor if b.floors == 2 else (p.floor + 1) % b.floors
	p.grid_pos = Vector2(b.stairs)


# --- Input ---

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B:
			toggle()
			get_viewport().set_input_as_handled()
		elif active and event.keycode == KEY_R and selected != "":
			rot = (rot + 1) % 4
		elif active and event.keycode == KEY_ESCAPE:
			cancel()
	if not active:
		return
	if event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		if event.button_index == MOUSE_BUTTON_RIGHT:
			cancel()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			click()


func click() -> void:
	var p: Node2D = main.player
	if selected != "":
		var free := not moving.is_empty()
		var node := Catalog.place(p, selected, cell, rot, p.floor, free)
		if node:
			Social.log_event("{a} %s a %s" % ["moved" if free else "bought", Catalog.ITEMS[selected].name.to_lower()], p, p)
			if free:
				selected = ""
				moving = {}
				ghost.visible = false
		else:
			p.show_emote(reason(), null)
		return
	var thing := Catalog.thing_at(p, cell, p.floor)
	if thing == null:
		return
	var id := Catalog.id_of(thing)
	var name: String = Catalog.ITEMS[id].name if id != "" else (thing.object_name if "object_name" in thing else "this")
	var controller := get_tree().get_first_node_in_group("controller")
	var entries := [{"label": "Rotate", "action": turn.bind(thing)}]
	if id != "":
		entries.append({"label": "Move", "action": pick_up.bind(thing, id)})
	entries.append({"label": "Delete (sell for $%d)" % Catalog.sell_price(thing), "action": sell.bind(thing)})
	controller.show_menu([name], entries)


func reason() -> String:
	var p: Node2D = main.player
	var why := Catalog.why_not(p, selected, cell, rot, p.floor)
	if why != "":
		return why
	if moving.is_empty() and p.money < Catalog.ITEMS[selected].price:
		return "Can't afford it"
	return "That would block the way"


func turn(thing: Node2D) -> void:
	if not Catalog.rotate(main.player, thing):
		main.player.show_emote("Can't turn it that way", null)


func sell(thing: Node2D) -> void:
	var p: Node2D = main.player
	var money := Catalog.sell(p, thing)
	if money < 0:
		p.show_emote("Someone is using it", null)


func pick_up(thing: Node2D, id: String) -> void:
	var p: Node2D = main.player
	var at: Vector2i = thing.cell if "flat" in thing else Vector2i(thing.grid_pos)
	var r: int = thing.rotation_index if "rotation_index" in thing else thing.facing
	var f: int = p.floor
	if not Catalog.remove(p, thing):
		p.show_emote("Someone is using it", null)
		return
	selected = id
	rot = r
	moving = {"cell": at, "rot": r, "floor": f}


# --- Preview ---

func _process(_delta: float) -> void:
	if not active:
		return
	var p: Node2D = main.player
	info.text = "BUILD MODE — %s, %s · $%d · R: rotate · right-click/Esc: cancel · click your furniture to sell or move" % [
		main.world.BUILDINGS[p.home].name, "ground floor" if p.floor == 0 else "floor %d" % p.floor, p.money]
	if selected == "":
		ghost.visible = false
		return
	cell = Vector2i(Iso.to_grid(main.world.get_global_mouse_position()).round())
	ghost.visible = true
	ghost.position = Iso.to_screen(Vector2(cell))
	var sprite_name := Catalog.sprite(selected, rot)
	ghost_sprite.visible = sprite_name != ""
	ghost_box.visible = sprite_name == ""
	if sprite_name != "":
		ghost_sprite.texture = Furniture.texture(sprite_name)
		ghost_sprite.offset = -Furniture.anchor(sprite_name)
	var ok: bool = Catalog.why_not(p, selected, cell, rot, p.floor) == "" and (not moving.is_empty() or p.money >= Catalog.ITEMS[selected].price)
	ghost.modulate = Color(0.6, 1.0, 0.6, 0.8) if ok else Color(1.0, 0.45, 0.45, 0.7)
