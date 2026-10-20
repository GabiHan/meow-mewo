# Decorative furniture (couches, plants, rugs...): a baked sprite on a tile. Not usable; it blocks
# its tile unless it's flat (`flat`: rugs, drawn under everything). Placed from PROPS in main.gd.
# A `wall` (build mode) is a prop too: a cut-down wall block instead of a sprite, that also blocks sight.
extends Node2D

const Iso = preload("res://scripts/iso.gd")
const Furniture = preload("res://scripts/furniture.gd")
const Block = preload("res://scripts/block.gd")
const WALL_HEIGHT := 22.0  # like the house's inner walls (world.gd INNER_WALL_HEIGHT)
const WALL_COLOR := Color(0.925, 0.890, 0.935)  # world.gd INNER_WALL_COLOR

var sprite := ""
var cell := Vector2i.ZERO
var flat := false
var catalog_id := ""  # build mode item (catalog.gd), "" = placed in main.gd
var rotation_index := 0
var wall := false


func setup(p_sprite: String, p_cell: Vector2i, p_flat := false, p_wall := false) -> Node2D:
	sprite = p_sprite
	cell = p_cell
	flat = p_flat
	wall = p_wall
	position = Iso.to_screen(Vector2(p_cell))
	if flat:
		z_index = -1  # on the floor, under people and furniture
	if wall:
		var block: Node2D = Block.new().setup("box", p_cell, WALL_HEIGHT, WALL_COLOR)
		block.position = Vector2.ZERO
		add_child(block)
	else:
		add_child(Furniture.make_sprite(sprite))
	return self


func rotate_to(r: int) -> void:
	if wall:
		return  # a wall looks the same every way
	rotation_index = r
	sprite = "%s_r%d" % [sprite.substr(0, sprite.rfind("_r")), r]
	var s: Sprite2D = get_child(0)
	s.texture = Furniture.texture(sprite)
	s.offset = -Furniture.anchor(sprite)
