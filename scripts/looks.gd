# What people look like: Quaternius "Universal Base Characters" (assets/characters, CC0) baked into
# sprite sheets by tools/bake_characters.gd (art/characters/<look>.png). Static.
#
# A look: label (shown in the household creator), body ("F"/"M"), skin ("light"/"dark"), hair (a model in assets/characters/hair, or ""),
# beard, hair colour, and clothes colours (the pack's bodies are in underwear, so clothes are painted
# on by body part when baking: shirt = torso and upper arms, pants = hips and legs, shoes = feet).
#
# Sheet layout: FRAMES columns × 8 rows (directions). A cell is CELL px; the feet are at FEET.
# Directions: row d faces the grid direction DIRS[d] (0 = +y, i.e. towards the lower left).
const LOOKS := {
	"jo": {"label": "Long brown hair, teal top", "body": "F", "skin": "light", "hair": "Hair_Long", "hair_color": Color(0.36, 0.22, 0.12), "beard": false,
		"shirt": Color(0.2, 0.62, 0.55), "pants": Color(0.2, 0.24, 0.38), "shoes": Color(0.92, 0.92, 0.9)},
	"sam": {"label": "Buzz cut & beard, orange top", "body": "M", "skin": "dark", "hair": "Hair_Buzzed", "hair_color": Color(0.1, 0.08, 0.07), "beard": true,
		"shirt": Color(0.93, 0.6, 0.25), "pants": Color(0.32, 0.32, 0.35), "shoes": Color(0.15, 0.15, 0.15)},
	"alex": {"label": "Buns, purple top", "body": "F", "skin": "dark", "hair": "Hair_Buns", "hair_color": Color(0.12, 0.08, 0.06), "beard": false,
		"shirt": Color(0.6, 0.35, 0.75), "pants": Color(0.15, 0.15, 0.2), "shoes": Color(0.45, 0.25, 0.15)},
	"mia": {"label": "Buns, yellow top", "body": "F", "skin": "dark", "hair": "Hair_Buns", "hair_color": Color(0.2, 0.12, 0.08), "beard": false,
		"shirt": Color(0.98, 0.8, 0.3), "pants": Color(0.35, 0.55, 0.85), "shoes": Color(0.9, 0.3, 0.4)},
	"lily": {"label": "Short hair, sky-blue top", "body": "F", "skin": "dark", "hair": "Hair_BuzzedFemale", "hair_color": Color(0.15, 0.1, 0.08), "beard": false,
		"shirt": Color(0.6, 0.85, 0.95), "pants": Color(0.95, 0.6, 0.75), "shoes": Color(0.95, 0.95, 0.95)},
	"riley": {"label": "Grey hair & beard, red top", "body": "M", "skin": "light", "hair": "Hair_SimpleParted", "hair_color": Color(0.55, 0.52, 0.5), "beard": true,
		"shirt": Color(0.85, 0.35, 0.4), "pants": Color(0.4, 0.3, 0.22), "shoes": Color(0.2, 0.15, 0.1)},
	"noah": {"label": "Parted hair, blue top", "body": "M", "skin": "light", "hair": "Hair_SimpleParted", "hair_color": Color(0.3, 0.18, 0.1), "beard": false,
		"shirt": Color(0.3, 0.45, 0.85), "pants": Color(0.2, 0.2, 0.25), "shoes": Color(0.9, 0.9, 0.9)},
	# For babies who grow up (life.gd picks one of their sex).
	"girl_a": {"label": "Red buns, pink top", "body": "F", "skin": "light", "hair": "Hair_Buns", "hair_color": Color(0.75, 0.35, 0.15), "beard": false,
		"shirt": Color(0.95, 0.5, 0.5), "pants": Color(0.3, 0.3, 0.5), "shoes": Color(0.95, 0.95, 0.95)},
	"girl_b": {"label": "Long dark hair, green top", "body": "F", "skin": "dark", "hair": "Hair_Long", "hair_color": Color(0.1, 0.07, 0.05), "beard": false,
		"shirt": Color(0.4, 0.75, 0.45), "pants": Color(0.55, 0.4, 0.3), "shoes": Color(0.2, 0.2, 0.2)},
	"boy_a": {"label": "Blond buzz cut, yellow top", "body": "M", "skin": "light", "hair": "Hair_Buzzed", "hair_color": Color(0.85, 0.7, 0.4), "beard": false,
		"shirt": Color(0.95, 0.85, 0.35), "pants": Color(0.25, 0.35, 0.55), "shoes": Color(0.9, 0.3, 0.3)},
	"boy_b": {"label": "Parted dark hair, aqua top", "body": "M", "skin": "dark", "hair": "Hair_SimpleParted", "hair_color": Color(0.08, 0.06, 0.05), "beard": false,
		"shirt": Color(0.5, 0.8, 0.9), "pants": Color(0.25, 0.25, 0.28), "shoes": Color(0.95, 0.95, 0.95)},
}

const FRAMES := 7  # idle, walk ×4, sit, lie
const IDLE := 0
const WALK := 1  # 1..4
const SIT := 5
const LIE := 6
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


# A single frame of a look (for menus): standing, facing the camera.
static func portrait(look: String) -> AtlasTexture:
	var frame := AtlasTexture.new()
	frame.atlas = sheet(look)
	frame.region = Rect2(0, 1 * CELL.y, CELL.x, CELL.y)
	return frame
