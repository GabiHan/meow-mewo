# Baked sprites (static). Furniture comes from tools/bake_furniture.gd → art/furniture (DIR); houses and trees
# from tools/bake_neighbourhood.gd → art/neighbourhood (SCENERY). Each folder has a sprites.json of anchors.
# A furniture sprite name is "<Model>_r<rotation>"; rotation r0 faces the +y grid direction (towards the tile in
# front, where people stand to use things), r1 +x, r2 −y, r3 −x. `anchor` is the pixel of the model's
# floor centre, which is drawn on the tile centre.
const DIR := "res://art/furniture/"
const SCENERY := "res://art/neighbourhood/"

static var indexes := {}  # dir -> {sprite: {anchor}}


static func has(sprite: String, dir := DIR) -> bool:
	return load_index(dir).has(sprite)


static func texture(sprite: String, dir := DIR) -> Texture2D:
	return load(dir + sprite + ".png")


static func anchor(sprite: String, dir := DIR) -> Vector2:
	var a: Array = load_index(dir)[sprite].anchor
	return Vector2(a[0], a[1])


# A Sprite2D showing `sprite` with its floor anchor at the node's origin.
static func make_sprite(sprite: String, dir := DIR) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = texture(sprite, dir)
	s.centered = false
	s.offset = -anchor(sprite, dir)
	return s


static func load_index(dir: String) -> Dictionary:
	if not indexes.has(dir):
		var path := dir + "sprites.json"
		indexes[dir] = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else {}
	return indexes[dir]
