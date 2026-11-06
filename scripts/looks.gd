# What people look like: a layered paper doll (the "build a character" art in assets/doll, prepared by
# tools/import_doll.gd into art/doll/<part>/<n>.png + art/doll/doll.cfg). Drawn by doll.gd. Static.
#
# A look is a Dictionary of numbers: one per PARTS key (1..count, 0 = none where `none` is true) and one per
# colour (an index into its palette). Line-art layers are white and tinted: hair parts by HAIR[hair_color],
# clothes by CLOTHES[<part>_color], the mouth by LIPS[lips], the figure by the skin's tone. Skin and eyes are
# drawn as they are (pre-coloured). The palettes are the swatches of the art's palette sheet
# (assets/doll/palette.png). Old saves stored a look's name (a String): normalize() turns it into a look.
#
# Facing: the doll has one picture, turned slightly to the right; people facing left are mirrored.
# DIRS are the 8 grid directions (`facing_dir` indexes them; vision.gd uses it for the view cone).
const DIR := "res://art/doll/"
const DIRS := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(1, -1), Vector2(0, -1), Vector2(-1, -1), Vector2(-1, 0), Vector2(-1, 1)]

# Layers, back to front (the order of the art's PSD). tint: "hair", "hair_dark" (eyebrows), "skin"
# (the tone of the chosen skin), "lips", or a colour key into CLOTHES.
const PARTS := [
	{"key": "back", "label": "Long hair", "tint": "hair", "none": true, "tab": "Hair"},
	{"key": "skin", "label": "Skin", "tint": "", "none": false, "tab": "Body"},
	{"key": "figure", "label": "Figure", "tint": "skin", "none": true, "tab": "Body"},
	{"key": "hair", "label": "Hair", "tint": "hair", "none": true, "tab": "Hair"},
	{"key": "mouth", "label": "Mouth", "tint": "lips", "none": false, "tab": "Body"},
	{"key": "eyes", "label": "Eyes", "tint": "", "none": false, "tab": "Body"},
	{"key": "lashes", "label": "Lashes", "tint": "", "none": true, "tab": "Body"},
	{"key": "brows", "label": "Eyebrows", "tint": "hair_dark", "none": false, "tab": "Body"},
	{"key": "shoes", "label": "Shoes", "tint": "shoes_color", "none": true, "tab": "Clothes"},
	{"key": "top", "label": "Top", "tint": "top_color", "none": true, "tab": "Clothes"},
	{"key": "bottom", "label": "Bottom", "tint": "bottom_color", "none": true, "tab": "Clothes"},
	{"key": "dress", "label": "Dress", "tint": "dress_color", "none": true, "tab": "Clothes"},
	{"key": "gloves", "label": "Gloves", "tint": "gloves_color", "none": true, "tab": "Clothes"},
	{"key": "beard", "label": "Beard", "tint": "hair", "none": true, "tab": "Hair", "grown": true},
	{"key": "bonus", "label": "Braids & locks", "tint": "hair", "none": true, "tab": "Hair"},
	{"key": "bangs", "label": "Fringe", "tint": "hair", "none": true, "tab": "Hair"},
]
const COLORS := ["hair_color", "lips", "top_color", "bottom_color", "dress_color", "shoes_color", "gloves_color"]

const HAIR := [
	Color("db592e"), Color("911714"), Color("533028"), Color("b86e40"), Color("ffd99d"), Color("292934"), Color("ffffff"),
	Color("969696"), Color("f7e7cf"), Color("315a91"), Color("78c5ec"), Color("69e0d6"), Color("469a56"), Color("a25fb3"),
	Color("fab3d3"), Color("a82b01"), Color("5e0200"), Color("200d09"), Color("853f13"), Color("d2a761"), Color("000000"),
	Color("d0d0d0"), Color("595959"), Color("dfb78f"), Color("011335"), Color("398eb9"), Color("28a298"), Color("125c21"),
	Color("6f2a80"), Color("c75d8b"),
]
const NATURAL_HAIR := [0, 1, 2, 3, 4, 5, 15, 16, 17, 18, 19, 20, 23]  # random looks; greys for old people below
const GREY_HAIR := [6, 7, 21, 22]
const LIPS := [Color("383838"), Color("f5a4cc"), Color("b14660"), Color("94212a"), Color("673524"), Color("e6bb75"),
	Color("68843b"), Color("23315d"), Color("6e5191")]
const CLOTHES := [
	Color("9c3e52"), Color("d7abbb"), Color("ba79b2"), Color("6c5289"), Color("314d75"), Color("82aab8"), Color("5a8677"),
	Color("566f40"), Color("ebb04f"), Color("ba8a6d"), Color("734c3e"), Color("b33634"),
	Color("262626"), Color("f7f4f0"), Color("c0aba0"), Color("6e4a42"), Color("7a3842"), Color("524a71"), Color("36485d"),
	Color("3b4e30"),
	Color("ede0ba"), Color("eac8be"), Color("eac2d1"), Color("c2add6"), Color("bcd3e5"), Color("bce5d9"), Color("c1d6b6"),
	Color("db5bb2"), Color("6458c0"), Color("4ea4db"), Color("4ac0b5"), Color("85b84b"), Color("fadc71"), Color("db703a"),
	Color("c32f33"),
	Color("000000"), Color("232323"), Color("464646"), Color("696969"), Color("898989"), Color("a8a8a8"), Color("c7c7c7"),
	Color("f0f0f0"),
	Color("f9f8fa"), Color("636469"), Color("b1bac0"), Color("e8edef"), Color("eddec9"), Color("786457"), Color("ccc5bc"),
	Color("f7f2f0"),
]
const NATURAL_SKIN := 17  # skins 1..17 are human tones; 18..29 are fantasy colours (creator only)

const WORLD_SCALE := 0.33  # art/doll pixels → world pixels (a grown-up is ~90 px tall)
const HEAD := Vector2(0, -212)  # the middle of the face, from the feet (art/doll pixels)

# The starting residents (main.gd), the key art and old saves that stored a look's name.
const PRESETS := {
	"jo": {"skin": 2, "figure": 2, "hair": 12, "bangs": 1, "back": 0, "bonus": 0, "hair_color": 3, "eyes": 3, "lashes": 3,
		"brows": 3, "mouth": 1, "lips": 2, "top": 1, "top_color": 24, "bottom": 3, "bottom_color": 4, "dress": 0,
		"shoes": 2, "shoes_color": 13, "gloves": 0, "beard": 0},
	"sam": {"skin": 14, "hair": 1, "bangs": 0, "back": 0, "bonus": 0, "hair_color": 2, "eyes": 4, "lashes": 0, "brows": 5,
		"mouth": 4, "lips": 0, "top": 11, "top_color": 7, "bottom": 1, "bottom_color": 4, "dress": 0, "shoes": 2,
		"shoes_color": 12, "gloves": 0, "beard": 0},
	"alex": {"skin": 6, "figure": 2, "hair": 9, "bangs": 0, "back": 12, "bonus": 0, "hair_color": 5, "eyes": 7, "lashes": 2,
		"brows": 2, "mouth": 6, "lips": 3, "top": 2, "top_color": 3, "bottom": 2, "bottom_color": 12, "dress": 0,
		"shoes": 4, "shoes_color": 12, "gloves": 0, "beard": 0},
	"mia": {"skin": 17, "hair": 3, "bangs": 11, "back": 0, "bonus": 0, "hair_color": 4, "eyes": 13, "lashes": 1, "brows": 1,
		"mouth": 8, "lips": 1, "top": 10, "top_color": 32, "bottom": 8, "bottom_color": 5, "dress": 0, "shoes": 3,
		"shoes_color": 27, "gloves": 0, "beard": 0},
	"lily": {"skin": 3, "hair": 10, "bangs": 10, "back": 0, "bonus": 0, "hair_color": 19, "eyes": 5, "lashes": 1, "brows": 1,
		"mouth": 2, "lips": 1, "top": 0, "bottom": 0, "dress": 2, "dress_color": 22, "shoes": 3, "shoes_color": 1,
		"gloves": 0, "beard": 0},
	"riley": {"skin": 1, "hair": 0, "bangs": 0, "back": 0, "bonus": 0, "hair_color": 0, "eyes": 1, "lashes": 0, "brows": 4,
		"mouth": 3, "lips": 0, "top": 4, "top_color": 38, "bottom": 3, "bottom_color": 12, "dress": 0, "shoes": 2,
		"shoes_color": 15, "gloves": 0, "beard": 1},
	"noah": {"skin": 9, "hair": 7, "bangs": 0, "back": 0, "bonus": 0, "hair_color": 17, "eyes": 3, "lashes": 0, "brows": 5,
		"mouth": 5, "lips": 4, "top": 6, "top_color": 4, "bottom": 7, "bottom_color": 18, "dress": 0, "shoes": 2,
		"shoes_color": 13, "gloves": 0, "beard": 0},
	"kai": {"skin": 12, "hair": 4, "bangs": 0, "back": 0, "bonus": 0, "hair_color": 6, "eyes": 16, "lashes": 0, "brows": 4,
		"mouth": 7, "lips": 0, "top": 5, "top_color": 32, "bottom": 1, "bottom_color": 32, "dress": 0, "shoes": 2,
		"shoes_color": 12, "gloves": 0, "beard": 2},
}

static var _cfg: ConfigFile = null


# The direction (index into DIRS) closest to a grid vector.
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


static func cfg() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(DIR + "doll.cfg")
	return _cfg


# How many pictures a part has (art/doll/<part>/).
static func count(part: String) -> int:
	return int(cfg().get_value("count", part, 0))


static func part_info(key: String) -> Dictionary:
	for p in PARTS:
		if p.key == key:
			return p
	return {}


static func texture(part: String, n: int) -> Texture2D:
	var path := DIR + "%s/%d.png" % [part, n]
	return load(path) if n > 0 and ResourceLoader.exists(path) else null


# Where picture n of a part goes, from the feet (art/doll pixels).
static func offset(part: String, n: int) -> Vector2:
	var feet: Vector2 = cfg().get_value("canvas", "feet", Vector2.ZERO)
	return Vector2(cfg().get_value(part, str(n), Vector2i.ZERO)) - feet


static func tone(skin: int) -> Color:
	return cfg().get_value("tone", str(skin), Color.WHITE)


# The colour a layer is drawn in.
static func tint(look: Dictionary, part: Dictionary) -> Color:
	match part.tint:
		"":
			return Color.WHITE
		"hair":
			return HAIR[int(look.get("hair_color", 0)) % HAIR.size()]
		"hair_dark":
			return HAIR[int(look.get("hair_color", 0)) % HAIR.size()].darkened(0.3)
		"skin":
			return tone(int(look.get("skin", 1)))
		"lips":
			return LIPS[int(look.get("lips", 0)) % LIPS.size()]
	return CLOTHES[int(look.get(part.tint, 0)) % CLOTHES.size()]


# A random everyday look. Girls usually get long hair and lashes, sometimes a dress; boys sometimes a beard
# (only drawn on grown-ups). `old` greys the hair.
static func random_for(sex: String, old := false) -> Dictionary:
	var f := sex == "F"
	var look := {
		"skin": randi_range(1, NATURAL_SKIN), "figure": 0, "eyes": randi_range(1, count("eyes")),
		"lashes": randi_range(1, count("lashes")) if f or randf() < 0.2 else 0,
		"brows": randi_range(1, count("brows")), "mouth": randi_range(1, count("mouth")),
		"lips": randi_range(0, 4) if f else [0, 4].pick_random(),
		"hair": randi_range(1, count("hair")) if f or randf() < 0.9 else 0,
		"bangs": randi_range(1, count("bangs")) if randf() < (0.7 if f else 0.3) else 0,
		"back": randi_range(1, count("back")) if randf() < (0.6 if f else 0.08) else 0,
		"bonus": randi_range(1, count("bonus")) if f and randf() < 0.15 else 0,
		"beard": randi_range(1, count("beard")) if not f and randf() < 0.3 else 0,
		"hair_color": (GREY_HAIR if old else NATURAL_HAIR).pick_random(),
		"top": randi_range(1, count("top")), "bottom": randi_range(1, count("bottom")), "dress": 0,
		"shoes": randi_range(1, count("shoes")), "gloves": 0,
	}
	if f and randf() < 0.3:
		look.top = 0
		look.bottom = 0
		look.dress = randi_range(1, count("dress"))
	for c in COLORS:
		if c != "hair_color" and c != "lips":
			look[c] = randi() % CLOTHES.size()
	return look


# A look from whatever was stored: a look (Dictionary), a preset's name, or nothing (random).
static func normalize(look: Variant, sex: String, old := false) -> Dictionary:
	if look is Dictionary and not look.is_empty():
		return look
	if look is String and PRESETS.has(look):
		return PRESETS[look].duplicate()
	return random_for(sex, old)
