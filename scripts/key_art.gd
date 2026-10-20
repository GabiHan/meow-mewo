# The home screen's key art: a cozy little room made of the game's own pieces (the atmosphere
# gradient, an isometric floor with lavender walls, baked furniture and the residents), framed like a picture.
extends Control

const UiTheme = preload("res://scripts/ui_theme.gd")
const Iso = preload("res://scripts/iso.gd")
const Block = preload("res://scripts/block.gd")
const Ground = preload("res://scripts/ground.gd")
const Furniture = preload("res://scripts/furniture.gd")
const Looks = preload("res://scripts/looks.gd")

const ROOM := 7  # tiles per side
const ZOOM := 1.7
const WALL_HEIGHT := 40.0
const WALL_COLOR := Color(0.925, 0.890, 0.935)
const FLOOR_COLOR := Color(0.950, 0.859, 0.888)
# [sprite, tile] — the furniture in the room
const FURNITURE := [
	["Bookshelf_r0", Vector2i(2, 1)], ["Light_Stand1_r0", Vector2i(4, 1)], ["Houseplant_1_r0", Vector2i(5, 1)],
	["Kitchen_Fridge_r0", Vector2i(1, 2)], ["Carpet_Round_r0", Vector2i(3, 4)], ["Couch_Large1_r1", Vector2i(1, 4)],
	["Table_RoundSmall_r0", Vector2i(4, 4)], ["Chair_1_r1", Vector2i(3, 4)], ["Houseplant_5_r0", Vector2i(5, 5)],
]
# [look, tile] — who's home
const PEOPLE := [["jo", Vector2(3.2, 3.0)], ["sam", Vector2(2.4, 5.2)], ["alex", Vector2(5.0, 3.0)], ["mia", Vector2(4.2, 5.6)]]

var room: Node2D


func _ready() -> void:
	clip_contents = true
	add_child(UiTheme.backdrop())
	var bubbles := Control.new()
	bubbles.set_anchors_preset(Control.PRESET_FULL_RECT)
	bubbles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubbles.draw.connect(func():
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		for n in 12:
			var at := Vector2(rng.randf() * bubbles.size.x, rng.randf() * bubbles.size.y)
			bubbles.draw_circle(at, rng.randf_range(18, 70), Color(UiTheme.ACCENTS[(n * 3) % 10], 0.16)))
	add_child(bubbles)
	room = Node2D.new()
	room.y_sort_enabled = true
	room.z_index = 2  # above the backdrop, so the floor (z -1 inside the room) still shows
	room.scale = Vector2.ONE * ZOOM
	add_child(room)
	var tiles := []
	for x in ROOM:
		for y in ROOM:
			if x == 0 or y == 0:
				room.add_child(Block.new().setup("box", Vector2i(x, y), WALL_HEIGHT, WALL_COLOR))
			else:
				tiles.append([Vector2i(x, y), FLOOR_COLOR.darkened(0.04 if (x + y) % 2 == 0 else 0.0)])
	room.add_child(Ground.new().setup(tiles))
	for f in FURNITURE:
		var holder := Node2D.new()
		holder.position = Iso.to_screen(Vector2(f[1]))
		if f[0].begins_with("Carpet"):
			holder.z_index = -1
		holder.add_child(Furniture.make_sprite(f[0]))
		room.add_child(holder)
	for p in PEOPLE:
		var sheet := Looks.sheet(p[0])
		if sheet == null:
			continue
		var s := Sprite2D.new()
		s.texture = sheet
		s.hframes = Looks.FRAMES
		s.vframes = 8
		s.frame = 1 * Looks.FRAMES + Looks.IDLE  # facing us
		s.centered = false
		s.offset = -Looks.FEET
		s.position = Iso.to_screen(p[1])
		room.add_child(s)
	resized.connect(place_room)
	place_room()


# Keep the room in the middle of the picture, a little below centre.
func place_room() -> void:
	var middle := Iso.to_screen(Vector2(ROOM / 2.0, ROOM / 2.0)) * ZOOM
	room.position = size / 2.0 - middle + Vector2(0, 40)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.LINE, false, 1.0)
