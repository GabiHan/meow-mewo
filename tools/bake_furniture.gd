# Bakes 3D furniture models (assets/furniture_obj, Quaternius low-poly pack) into isometric sprites
# that match the game's 2:1 projection (iso.gd: a 1 m tile is 64×32 px).
#
# Run (needs a window, not --headless):  godot --path . -s res://tools/bake_furniture.gd
# Output: art/furniture/<Model>_r<0-3>.png and art/furniture/sprites.json
#   {"<Model>_r<n>": {"anchor": [x, y]}}: the pixel where the model's floor centre is, which goes on
#   the object's tile centre. r = rotation in 90° steps (r0 faces the +y grid direction).
# Add a model: put its name and rotations in MODELS, run the bake, then use it in main.gd.
extends SceneTree

const SRC := "res://assets/furniture_obj/OBJ/%s.obj"
const OUT := "res://art/furniture/"
const SIZE := 512
const PX_PER_M := 45.25  # 32 px across per metre along a grid axis: 32 / cos(45°)
const MODEL_SCALE := 0.85  # a touch smaller than life, to suit the characters
const MAX_FOOTPRINT := 1.6  # metres; bigger models are shrunk to fit around one tile

# model -> rotations to bake (all four: anything can be rotated in build mode)
const MODELS := {
	"Kitchen_Fridge": [0, 1, 2, 3],
	"Kitchen_2Drawers": [0, 1, 2, 3],
	"Kitchen_Oven": [0, 1, 2, 3],
	"Kitchen_Sink": [0, 1, 2, 3],
	"Kitchen_Cabinet1": [0, 1, 2, 3],
	"Kitchen_3Drawers": [0, 1, 2, 3],
	"Table_RoundSmall": [0, 1, 2, 3],
	"Table_RoundLarge": [0, 1, 2, 3],
	"Chair_1": [0, 1, 2, 3],
	"Chair_2": [0, 1, 2, 3],
	"Chair_3": [0, 1, 2, 3],
	"Stool": [0, 1, 2, 3],
	"Bed_King": [0, 1, 2, 3],
	"Bed_Single": [0, 1, 2, 3],
	"Bed_Bunk": [0, 1, 2, 3],
	"NightStand_1": [0, 1, 2, 3],
	"NightStand_2": [0, 1, 2, 3],
	"Bathroom_Shower1": [0, 1, 2, 3],
	"Bathroom_Toilet": [0, 1, 2, 3],
	"Bathroom_Sink": [0, 1, 2, 3],
	"Bathroom_Bathtub": [0, 1, 2, 3],
	"Bathroom_WashingMachine": [0, 1, 2, 3],
	"Bookshelf": [0, 1, 2, 3],
	"Shelf_Small1": [0, 1, 2, 3],
	"Shelf_Large": [0, 1, 2, 3],
	"Drawer_2": [0, 1, 2, 3],
	"Drawer_4": [0, 1, 2, 3],
	"Couch_Large1": [0, 1, 2, 3],
	"Couch_Small1": [0, 1, 2, 3],
	"Couch_Medium1": [0, 1, 2, 3],
	"Couch_L": [0, 1, 2, 3],
	"Carpet_1": [0, 1, 2, 3],
	"Carpet_2": [0, 1, 2, 3],
	"Carpet_Round": [0, 1, 2, 3],
	"Houseplant_1": [0, 1, 2, 3],
	"Houseplant_3": [0, 1, 2, 3],
	"Houseplant_5": [0, 1, 2, 3],
	"Houseplant_7": [0, 1, 2, 3],
	"Light_Floor1": [0, 1, 2, 3],
	"Light_Floor3": [0, 1, 2, 3],
	"Light_Stand1": [0, 1, 2, 3],
	"Light_Stand2": [0, 1, 2, 3],
	"Trashcan_Small1": [0, 1, 2, 3],
	"Trashcan_Large": [0, 1, 2, 3],
	"Fireplace": [0, 1, 2, 3],
}

var viewport: SubViewport
var holder: Node3D
var queue := []
var frames := 0
var index := {}
var current_model := ""


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
	sun.light_energy = 1.7
	viewport.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.95, 0.93, 0.9)
	env.environment.ambient_light_energy = 1.3
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	viewport.add_child(env)

	holder = Node3D.new()
	viewport.add_child(holder)
	for model in MODELS:
		for r in MODELS[model]:
			queue.append([model, r])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 1:
		return next_model()
	if frames < 4:  # let it render
		return false
	save_current()
	frames = 0
	return false


func next_model() -> bool:
	for child in holder.get_children():
		child.queue_free()
	if queue.is_empty():
		var f := FileAccess.open(OUT + "sprites.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(index, "\t"))
		print("baked %d sprites" % index.size())
		quit()
		return true
	var model: String = queue[0][0]
	var r: int = queue[0][1]
	var mesh: Mesh = load(SRC % model)
	var aabb := mesh.get_aabb()
	var s := MODEL_SCALE * minf(1.0, MAX_FOOTPRINT / maxf(aabb.size.x, aabb.size.z))
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = -Vector3(aabb.position.x + aabb.size.x / 2.0, aabb.position.y, aabb.position.z + aabb.size.z / 2.0)
	var pivot := Node3D.new()
	pivot.rotation.y = r * PI / 2.0
	pivot.scale = Vector3.ONE * s
	pivot.add_child(inst)
	holder.add_child(pivot)
	return false


func save_current() -> void:
	var model: String = queue[0][0]
	var r: int = queue[0][1]
	current_model = model
	queue.pop_front()
	var image := viewport.get_texture().get_image()
	pastel(image)
	var used := image.get_used_rect()
	var name := "%s_r%d" % [model, r]
	image.get_region(used).save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	index[name] = {"anchor": [SIZE / 2 - used.position.x, SIZE / 2 - used.position.y]}
	frames = 0
	next_model()


# The game's pastel look: each kind of furniture gets a pastel colour (shaded by the model's own
# light and dark), plants keep their colours but softer. First matching prefix wins.
const TINTS := [
	["Kitchen_Fridge", Color(0.78, 0.9, 1.0)], ["Kitchen", Color(0.72, 0.93, 0.84)], ["Bed", Color(1.0, 0.76, 0.84)],
	["Couch", Color(0.82, 0.76, 1.0)], ["Chair", Color(1.0, 0.82, 0.68)], ["Stool", Color(1.0, 0.82, 0.68)],
	["Table", Color(1.0, 0.84, 0.7)], ["NightStand", Color(1.0, 0.84, 0.7)], ["Bathroom", Color(0.78, 0.9, 1.0)],
	["Bookshelf", Color(1.0, 0.94, 0.82)], ["Shelf", Color(1.0, 0.94, 0.82)], ["Drawer", Color(1.0, 0.86, 0.78)],
	["Light", Color(1.0, 0.95, 0.7)], ["Carpet", Color(1.0, 0.75, 0.82)], ["Trashcan", Color(0.8, 0.92, 0.85)],
	["Fireplace", Color(1.0, 0.85, 0.78)],
]
const SOFTEN := 0.3  # plants (no tint): lift towards white this much


func pastel(image: Image) -> void:
	var tint := Color.TRANSPARENT
	for row in TINTS:
		if String(queue_model()).begins_with(row[0]):
			tint = row[1]
			break
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var rgb: Color
			if tint.a > 0.0:
				var light := clampf(c.get_luminance() * 1.6, 0.0, 1.0)
				rgb = (tint * (0.62 + 0.38 * light)).lerp(Color.WHITE, 0.12)
			else:
				rgb = Color(c.r, c.g, c.b).lerp(Color(1.0, 0.97, 0.98), SOFTEN)
			image.set_pixel(x, y, Color(rgb.r, rgb.g, rgb.b, c.a))


func queue_model() -> String:
	return current_model
