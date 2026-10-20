# What people look like: Kenney "Mini Characters" (assets/kenney/characters, CC0) baked into sprite
# sheets by tools/bake_characters.gd (art/characters/<look>.png). Static.
#
# A look: label (shown in the household creator), body ("F"/"M") and the kit model it's baked from
# (its clothes, hair and skin are part of the model).
#
# Sheet layout: FRAMES columns × 8 rows (directions). A cell is CELL px; the feet are at FEET.
# Directions: row d faces the grid direction DIRS[d] (0 = +y, i.e. towards the lower left).
const LOOKS := {
	"jo": {"label": "Auburn hair, dungarees", "body": "F", "model": "character-female-f"},
	"sam": {"label": "Glasses, green top", "body": "M", "model": "character-male-a"},
	"alex": {"label": "Buns, purple top, crutches", "body": "F", "model": "character-female-a"},
	"mia": {"label": "Blonde pigtails, yellow top", "body": "F", "model": "character-female-b"},
	"lily": {"label": "Grey beanie, orange top", "body": "F", "model": "character-female-c"},
	"riley": {"label": "Bald, ginger beard", "body": "M", "model": "character-male-b"},
	"noah": {"label": "Police cap, blue uniform", "body": "M", "model": "character-male-c"},
	"kai": {"label": "White hair, glasses, yellow dungarees", "body": "M", "model": "character-male-f"},
	# For babies who grow up (life.gd picks one of their sex).
	"girl_a": {"label": "Ginger bun, grey suit", "body": "F", "model": "character-female-d"},
	"girl_b": {"label": "Dark bun, white jacket", "body": "F", "model": "character-female-e"},
	"boy_a": {"label": "Dark hair, green top", "body": "M", "model": "character-male-d"},
	"boy_b": {"label": "Ginger hair, black suit", "body": "M", "model": "character-male-e"},
}

const FRAMES := 13  # idle, walk ×4, sit, lie, run ×4, bent over, down on the floor
const IDLE := 0
const WALK := 1  # 1..4
const SIT := 5
const LIE := 6  # in bed
const RUN := 7  # 7..10
const BENT := 11  # bent over: throwing up, out of breath (body.gd)
const DOWN := 12  # face down on the floor: tripped, fainted, passed out (body.gd)
const DOWN_DROP := 20.0  # pixels: the DOWN frame is baked raised (to fit the cell); draw it this much lower
const CELL := Vector2i(96, 112)
const FEET := Vector2(48, 100)
const DIRS := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(1, -1), Vector2(0, -1), Vector2(-1, -1), Vector2(-1, 0), Vector2(-1, 1)]
const DIR := "res://art/characters/"


# The row facing closest to a grid direction.
static func direction(v: Vector2) -> int:
	if v.length() < 0.001:
		return 0
	var best := 0
	var best_dot := -INF
	for d in DIRS.size():
		var dot: float = v.normalized().dot(DIRS[d].normalized())
		if dot > best_dot:
			best_dot = dot
			best = d
	return best


static func sheet(look: String) -> Texture2D:
	return load(DIR + look + ".png") if ResourceLoader.exists(DIR + look + ".png") else null


# A look for someone born in the game.
static func random_for(sex: String) -> String:
	return ["girl_a", "girl_b"].pick_random() if sex == "F" else ["boy_a", "boy_b"].pick_random()


# Just the head, from the front (art/characters/<look>_face.png, baked by tools/bake_characters.gd). Null if missing.
static func face(look: String) -> Texture2D:
	var path := "res://art/characters/%s_face.png" % look
	return load(path) if ResourceLoader.exists(path) else null


# A single frame of a look (for menus): standing, facing the camera.
static func portrait(look: String) -> AtlasTexture:
	var frame := AtlasTexture.new()
	frame.atlas = sheet(look)
	frame.region = Rect2(0, 1 * CELL.y, CELL.x, CELL.y)
	return frame
