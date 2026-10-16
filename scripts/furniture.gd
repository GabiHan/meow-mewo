# Furniture sprites baked from 3D models (tools/bake_furniture.gd → art/furniture). Static.
# A sprite name is "<Model>_r<rotation>"; rotation r0 faces the +y grid direction (towards the tile in
# front, where people stand to use things), r1 +x, r2 −y, r3 −x. `anchor` is the pixel of the model's
# floor centre, which is drawn on the tile centre.
const DIR := "res://art/furniture/"

static var index := {}


static func has(sprite: String) -> bool:
	load_index()
	return index.has(sprite)


static func texture(sprite: String) -> Texture2D:
	return load(DIR + sprite + ".png")


static func anchor(sprite: String) -> Vector2:
	load_index()
	var a: Array = index[sprite].anchor
	return Vector2(a[0], a[1])


# A Sprite2D showing `sprite` with its floor anchor at the node's origin.
static func make_sprite(sprite: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = texture(sprite)
	s.centered = false
	s.offset = -anchor(sprite)
	return s


static func load_index() -> void:
	if index.is_empty():
		index = JSON.parse_string(FileAccess.get_file_as_string(DIR + "sprites.json"))
