# Bakes 3D models into isometric sprites that match the game's 2:1 projection (iso.gd: a 1 m tile is 64×32 px).
# Furniture comes from itHappy's "Cute Furniture" pack and plates, cups and food from its "Food" pack
# (assets/ithappy/furniture, assets/ithappy/food: the packs' prefab scenes, which hold the meshes and put each
# model's parts together, e.g. a fridge and its doors).
#
# Run (needs a window, not --headless):  godot --path . -s res://tools/bake_furniture.gd   then  godot --headless --import
# Output:
#   art/furniture/<Sprite>_r<0-3>.png + sprites.json {"<Sprite>_r<n>": {"anchor": [x, y]}}: the pixel where the
#     model's floor centre is, which goes on the object's tile centre. r = rotation in 90° steps (r0 faces +y).
#   art/food/<Sprite>.png + sprites.json: plates, cups and food (one view; the anchor is the bottom centre), drawn on
#     tables and counters and in people's hands (kitchen.gd item_sprite()).
# Sprite ids are the game's own names (main.gd, catalog.gd, saves): MODELS says which pack models each one is, as
# "<folder>/<model>" in the furniture pack's prefabs (furniture, kitchen, bathroom, decorations, plants).
# Add one: a row in MODELS (or FOOD), run the bake, then use it in main.gd or catalog.gd.
extends SceneTree

const SRC := "res://assets/ithappy/furniture/prefabs/assets/%s.tscn"
const FOOD_SRC := "res://assets/ithappy/food/prefabs/%s.tscn"
const OUT := "res://art/furniture/"
const FOOD_OUT := "res://art/food/"
const SIZE := 512
const PX_PER_M := 45.25  # 32 px across per metre along a grid axis: 32 / cos(45°)
const MODEL_SCALE := 0.85  # a touch smaller than life, to suit the characters (the packs are in metres)
const MAX_FOOTPRINT := 1.6  # metres; bigger models are shrunk to fit around one tile
const FOOD_SCALE := 1.6  # plates and cups are drawn a bit bigger than life so you can tell them apart

# sprite id -> [pack models stacked bottom to top, scale]. Every sprite is baked in all four rotations
# (anything can be rotated in build mode).
const MODELS := {
	"Kitchen_Fridge": [["kitchen/fridge_01"], 1.0],
	"Kitchen_2Drawers": [["kitchen/kitchen_d_09"], 1.0],  # the counter
	"Kitchen_Oven": [["kitchen/kitchen_d_10", "kitchen/microwave_01"], 1.0],  # the stove: drawers and a microwave
	"Kitchen_Sink": [["kitchen/kitchen_d_01", "bathroom/mixer_08"], 1.0],  # a cupboard with a tap
	"Kitchen_Cabinet1": [["kitchen/kitchen_d_08"], 1.0],
	"Kitchen_3Drawers": [["kitchen/kitchen_d_10"], 1.0],
	"Table_RoundSmall": [["kitchen/kitchen_d_06"], 1.0],
	"Table_RoundLarge": [["furniture/kitchen_table_09"], 1.0],
	"Table_Coffee": [["furniture/coffee_table_03"], 1.0],
	"Desk": [["furniture/work_table_06", "decorations/computer_01"], 1.0],
	"Chair_1": [["furniture/chair_17"], 1.0],
	"Chair_2": [["furniture/chair_pc_04"], 1.0],
	"Chair_3": [["furniture/armchair_18"], 1.0],
	"Couch_Small1": [["furniture/armchair_02"], 1.0],
	"Couch_Medium1": [["furniture/couch_11"], 1.0],
	"Couch_Large1": [["furniture/couch_08"], 1.0],
	"Bed_King": [["furniture/bed_02"], 1.0],
	"Bed_Single": [["furniture/bed_07"], 1.0],
	"NightStand_1": [["furniture/nightstand_02"], 1.0],
	"Bathroom_Bathtub": [["bathroom/bath_03"], 1.0],  # bath and shower
	"Bathroom_Toilet": [["bathroom/toilet_03"], 1.0],
	"Bathroom_Sink": [["bathroom/wash_basin_07"], 1.0],
	"Bookshelf": [["furniture/closet_01"], 1.0],
	"Shelf_Small1": [["decorations/book_03"], 1.6],  # a row of books
	"Drawer_4": [["furniture/closet_02"], 1.0],  # wardrobe
	"Carpet_1": [["decorations/paper_02"], 7.0],  # a sheet of paper, stretched into a cream rug
	"Houseplant_1": [["plants/plants_15"], 1.2],
	"Houseplant_3": [["plants/plants_05"], 2.4],
	"Houseplant_7": [["plants/plants_19"], 0.8],
	"Light_Floor1": [["decorations/light_05"], 1.0],
	"TV": [["kitchen/kitchen_d_08", "decorations/computer_01"], 1.0],  # a screen on a low cabinet
	"Guitar": [["decorations/guitar_01"], 1.4],
	"Toy_Car": [["decorations/toy_02"], 2.5],
	"Exercise_Bike": [["decorations/exercise_bike_01"], 1.0],
	"Clock_Tall": [["decorations/clock_03"], 1.0],
	"Game_Console": [["kitchen/kitchen_d_08", "decorations/game_console_01"], 1.0],
}

# Plates, cups and food (kitchen.gd item_sprite()): sprite -> food pack models stacked bottom to top.
const FOOD := {
	"Dish_plate": ["plate_001"],
	"Dish_cup": ["cup_003"],
	"Food_Sandwich": ["plate_001", "sandwich_001"],
	"Food_Salad": ["bowl_001", "avocado_003"],
	"Food_Omelette": ["plate_001", "egg_004"],
	"Food_Pasta": ["plate_007", "shrimp_002"],
	"Food_Soup": ["bowl_001"],
	"Drink_Water": ["glass_004"],
	"Drink_Juice": ["glass_005"],
	"Drink_Milk": ["yogurt_002"],
	"Drink_Soda": ["soda_002"],
	"Drink_Coffee": ["coffee_005"],
}

var viewport: SubViewport
var holder: Node3D
var queue := []
var frames := 0
var index := {}
var food_index := {}


func _initialize() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = SIZE / PX_PER_M
	var pitch := deg_to_rad(30.0)  # 2:1 dimetric
	var eye := Vector3(sin(PI / 4) * cos(pitch), sin(pitch), cos(PI / 4) * cos(pitch)) * 30.0
	cam.transform = Transform3D(Basis.looking_at(-eye, Vector3.UP), eye)  # looking at the origin
	viewport.add_child(cam)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(20.0), 0.0)
	sun.light_energy = 1.25
	viewport.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.95, 0.93, 0.9)
	env.environment.ambient_light_energy = 0.65
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	viewport.add_child(env)

	holder = Node3D.new()
	viewport.add_child(holder)
	var only: Array = OS.get_cmdline_user_args()  # optional: bake only these sprites
	for sprite in MODELS:
		if only.is_empty() or sprite in only:
			for r in 4:
				queue.append([sprite, r])
	for sprite in FOOD:
		if only.is_empty() or sprite in only:
			queue.append([sprite, -1])  # one view
	for dir in [OUT, FOOD_OUT]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	if FileAccess.file_exists(OUT + "sprites.json"):
		index = JSON.parse_string(FileAccess.get_file_as_string(OUT + "sprites.json"))
	if FileAccess.file_exists(FOOD_OUT + "sprites.json"):
		food_index = JSON.parse_string(FileAccess.get_file_as_string(FOOD_OUT + "sprites.json"))


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 1:
		return next_model()
	if frames < 4:  # let it render
		return false
	save_current()
	frames = 0
	return false


# The box around every mesh under `n`, in n's parent's space.
static func bounds(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var t: Transform3D = n.transform
		var p: Node = m
		var chain := Transform3D.IDENTITY
		while p != n:
			chain = p.transform * chain
			p = p.get_parent()
		var b: AABB = (t * chain) * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func next_model() -> bool:
	for child in holder.get_children():
		holder.remove_child(child)
		child.queue_free()
	if queue.is_empty():
		for pair in [[OUT, index], [FOOD_OUT, food_index]]:
			var f := FileAccess.open(pair[0] + "sprites.json", FileAccess.WRITE)
			f.store_string(JSON.stringify(pair[1], "\t"))
		print("baked %d furniture sprites and %d food sprites" % [index.size(), food_index.size()])
		quit()
		return true
	var sprite: String = queue[0][0]
	var r: int = queue[0][1]
	var food: bool = r < 0
	var parts: Array = FOOD[sprite] if food else MODELS[sprite][0]
	var stack := Node3D.new()  # the parts, stacked
	var top := 0.0
	for part in parts:
		var model: Node3D = load((FOOD_SRC if food else SRC) % part).instantiate()
		var box := bounds(model)
		var holder_part := Node3D.new()
		holder_part.add_child(model)
		model.position -= Vector3(box.position.x + box.size.x / 2.0, box.position.y - top, box.position.z + box.size.z / 2.0)
		stack.add_child(holder_part)
		top += box.size.y * (0.35 if food else 1.0) if part != parts[-1] else 0.0  # food sits down in its plate
	var aabb := bounds_of_children(stack)
	var s := FOOD_SCALE if food else MODEL_SCALE * float(MODELS[sprite][1])
	if not food:
		s = minf(s, MAX_FOOTPRINT / maxf(aabb.size.x, aabb.size.z))
	var pivot := Node3D.new()
	pivot.rotation.y = maxi(r, 0) * PI / 2.0  # the packs' models face +z, the +y grid direction
	pivot.scale = Vector3.ONE * s
	pivot.add_child(stack)
	holder.add_child(pivot)
	return false


static func bounds_of_children(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for c in n.get_children():
		var b := bounds(c)
		box = b if first else box.merge(b)
		first = false
	return box


func save_current() -> void:
	var sprite: String = queue[0][0]
	var r: int = queue[0][1]
	queue.pop_front()
	var image := viewport.get_texture().get_image()
	soften(image)
	var used := image.get_used_rect()
	var food: bool = r < 0
	var name := sprite if food else "%s_r%d" % [sprite, r]
	image.get_region(used).save_png(ProjectSettings.globalize_path((FOOD_OUT if food else OUT) + name + ".png"))
	(food_index if food else index)[name] = {"anchor": [SIZE / 2 - used.position.x, SIZE / 2 - used.position.y]}
	frames = 0
	next_model()


# The game's soft pastel look: the packs' own colours, lifted a little towards a warm white.
const SOFTEN := 0.12


func soften(image: Image) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var rgb := Color(c.r, c.g, c.b).lerp(Color(1.0, 0.97, 0.98), SOFTEN)
			image.set_pixel(x, y, Color(rgb.r, rgb.g, rgb.b, c.a))
