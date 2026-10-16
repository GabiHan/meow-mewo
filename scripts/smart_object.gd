# An object that "advertises" which needs it satisfies, Sims-style.
# NPCs score every advertisement against their own needs and pick the best one.
extends Node2D

const Iso = preload("res://scripts/iso.gd")
const Kitchen = preload("res://scripts/kitchen.gd")
const Furniture = preload("res://scripts/furniture.gd")
const Actions = preload("res://scripts/actions.gd")

var object_name := ""
var grid_pos := Vector2.ZERO
var advertisements := {}  # need name -> how much it restores per use
var duration := 3.0  # seconds to use
var color := Color.WHITE
var box_height := 24.0
var user: Node2D = null  # whoever is using or has reserved this object
var building := -1  # set by World.add_object: index in World.BUILDINGS, -1 = outdoors (anyone may use it)
var floor := 0
var verb := ""  # shown while using it ("Reading"); default "Using <name>"
var skill := ""  # skill practised while using it (skills.gd)
var moodlet := ""  # moodlet when done (emotions.gd)
var sprite := ""  # baked furniture sprite (furniture.gd); "" = draw a placeholder box
var facing := 0  # rotation 0-3: which side its front (use tile) is on: +y, +x, -y, -x
var catalog_id := ""  # build mode item it was bought as (catalog.gd), "" = part of the house
var sprite_node: Sprite2D
const FACING := [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]
var items := []  # plates/cups sitting on this object (Counter, Table), see kitchen.gd
var label: Label
var label_timer := 0.0
var drawn_items := -1


func setup(p_name: String, p_grid: Vector2, p_ads: Dictionary, p_duration: float, p_color: Color, p_height := 24.0) -> Node2D:
	object_name = p_name
	grid_pos = p_grid
	advertisements = p_ads
	duration = p_duration
	color = p_color
	box_height = p_height
	return self


# Optional extras from the OBJECTS table: {verb, skill, moodlet}.
func with_extras(extras: Dictionary) -> Node2D:
	verb = extras.get("verb", "")
	skill = extras.get("skill", "")
	moodlet = extras.get("moodlet", "")
	sprite = extras.get("sprite", "")
	facing = extras.get("facing", facing)
	if sprite != "" and Furniture.has(sprite):
		box_height = Furniture.anchor(sprite).y - 10.0  # labels and plates sit on top of the model
		sprite_node = Furniture.make_sprite(sprite)
		sprite_node.show_behind_parent = true  # plates (drawn by this node) go on top
		add_child(sprite_node)
	else:
		sprite = ""
	return self


func _ready() -> void:
	add_to_group("smart_objects")
	position = Iso.to_screen(grid_pos)
	label = Label.new()
	label.text = object_name
	label.add_theme_font_size_override("font_size", 12)
	label.position = Vector2(-20, -box_height - 34)
	label.add_theme_color_override("font_color", Color(0.36, 0.29, 0.48, 0.85))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.8))
	add_child(label)


# Items on top: redraw when they change, and refresh the label (with spoil timers) twice a second.
func _process(delta: float) -> void:
	if items.size() != drawn_items:
		drawn_items = items.size()
		queue_redraw()
	label_timer -= delta
	if label_timer > 0.0 or (items.is_empty() and label.text == object_name):
		return
	label_timer = 0.5
	var now: float = get_tree().get_first_node_in_group("world").now()
	var lines := [object_name]
	for item in items:
		lines.append("  " + Kitchen.item_text(item, now))
	label.text = "\n".join(lines)
	label.position = Vector2(-20, -box_height - 34 - 17 * items.size())


# The tile you stand on to use the object: the one in front of it (seats: the seat itself).
func use_cell() -> Vector2i:
	return Vector2i(grid_pos) if is_seat() else Vector2i(grid_pos) + FACING[facing]


func is_seat() -> bool:
	return object_name in Actions.SEATS


# Turn it to face another way (build mode): its front tile and sprite follow.
func rotate_to(r: int) -> void:
	facing = r
	if sprite != "":
		sprite = "%s_r%d" % [sprite.substr(0, sprite.rfind("_r")), r]
		sprite_node.texture = Furniture.texture(sprite)
		sprite_node.offset = -Furniture.anchor(sprite)


func _draw() -> void:
	if sprite != "":  # the model is a Sprite2D child (with_extras); only the plates are drawn here
		draw_items(-box_height + 10.0)
		return
	# Placeholder isometric box: top face plus two shaded side faces.
	var w := 28.0
	var h := 14.0
	var top := -box_height
	draw_colored_polygon(PackedVector2Array([Vector2(-w, top), Vector2(0, top + h), Vector2(0, h), Vector2(-w, 0)]), color.darkened(0.1))
	draw_colored_polygon(PackedVector2Array([Vector2(w, top), Vector2(0, top + h), Vector2(0, h), Vector2(w, 0)]), color.darkened(0.22))
	draw_colored_polygon(PackedVector2Array([Vector2(0, top - h), Vector2(w, top), Vector2(0, top + h), Vector2(-w, top)]), color)
	draw_items(top)


# Plates and cups on top, in a row.
func draw_items(top: float) -> void:
	for n in items.size():
		var item: Dictionary = items[n]
		var at := Vector2(-12 + (n % 4) * 8, top - 2 + (n / 4) * 4)
		var dish := Color(0.7, 0.66, 0.6) if item.kind == "dirty" else Color(0.95, 0.95, 0.97)
		draw_set_transform(at, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 5.0, dish)
		if item.kind == "food":
			draw_circle(Vector2.ZERO, 3.0, Kitchen.RECIPES[item.recipe].color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
