# Decorative furniture (couches, plants, rugs...): a baked sprite on a tile. Not usable; it blocks
# its tile unless it's flat (`flat`: rugs, drawn under everything). Placed from PROPS in main.gd.
extends Node2D

const Iso = preload("res://scripts/iso.gd")
const Furniture = preload("res://scripts/furniture.gd")

var sprite := ""
var cell := Vector2i.ZERO
var flat := false
var catalog_id := ""  # build mode item (catalog.gd), "" = placed in main.gd
var rotation_index := 0


func setup(p_sprite: String, p_cell: Vector2i, p_flat := false) -> Node2D:
	sprite = p_sprite
	cell = p_cell
	flat = p_flat
	position = Iso.to_screen(Vector2(p_cell))
	if flat:
		z_index = -1  # on the floor, under people and furniture
	add_child(Furniture.make_sprite(sprite))
	return self


func rotate_to(r: int) -> void:
	rotation_index = r
	sprite = "%s_r%d" % [sprite.substr(0, sprite.rfind("_r")), r]
	var s: Sprite2D = get_child(0)
	s.texture = Furniture.texture(sprite)
	s.offset = -Furniture.anchor(sprite)
