# Bakes 3D furniture models (assets/kenney/furniture, Kenney "Furniture Kit", CC0) into isometric
# sprites that match the game's 2:1 projection (iso.gd: a 1 m tile is 64×32 px).
#
# Run (needs a window, not --headless):  godot --path . -s res://tools/bake_furniture.gd
# Output: art/furniture/<Sprite>_r<0-3>.png and art/furniture/sprites.json
#   {"<Sprite>_r<n>": {"anchor": [x, y]}}: the pixel where the model's floor centre is, which goes on
#   the object's tile centre. r = rotation in 90° steps (r0 faces the +y grid direction).
# Sprite ids are the game's own names (main.gd, catalog.gd, saves); MODELS says which kit model each one is.
# Add one: a row in MODELS, run the bake, then use it in main.gd or catalog.gd.
extends SceneTree

const SRC := "res://assets/kenney/furniture/Models/GLTF format/%s.glb"
const OUT := "res://art/furniture/"
const SIZE := 512
const PX_PER_M := 45.25  # 32 px across per metre along a grid axis: 32 / cos(45°)
const KIT_SCALE := 2.1  # metres per kit unit (a kit wall is 1 unit wide, 1.3 high)
const MODEL_SCALE := 0.85  # a touch smaller than life, to suit the characters
const MAX_FOOTPRINT := 1.6  # metres; bigger models are shrunk to fit around one tile

# sprite id -> [kit model(s) stacked bottom to top, scale]. Every sprite is baked in all four rotations
# (anything can be rotated in build mode).
const MODELS := {
	"Kitchen_Fridge": [["kitchenFridgeLarge"], 1.0],
	"Kitchen_2Drawers": [["kitchenCabinetDrawer"], 1.0],
	"Kitchen_Oven": [["kitchenStove"], 1.0],
	"Kitchen_Sink": [["kitchenSink"], 1.0],
	"Kitchen_Cabinet1": [["kitchenCabinet"], 1.0],
	"Kitchen_3Drawers": [["kitchenBar"], 1.0],
	"Table_RoundSmall": [["tableRound"], 1.0],
	"Table_RoundLarge": [["tableCloth"], 1.0],
	"Table_Coffee": [["tableCoffee"], 1.0],
	"Desk": [["desk"], 1.0],
	"Chair_1": [["chair"], 1.0],
	"Chair_2": [["chairModernCushion"], 1.0],
	"Chair_3": [["chairCushion"], 1.0],
	"Stool": [["stoolBar"], 1.0],
	"Bed_King": [["bedDouble"], 1.0],
	"Bed_Single": [["bedSingle"], 1.0],
	"Bed_Bunk": [["bedBunk"], 1.0],
	"NightStand_1": [["cabinetBedDrawer"], 1.0],
	"NightStand_2": [["cabinetBedDrawerTable"], 1.0],
	"Bathroom_Shower1": [["shower"], 1.0],
	"Bathroom_Toilet": [["toilet"], 1.0],
	"Bathroom_Sink": [["bathroomSink"], 1.0],
	"Bathroom_Bathtub": [["bathtub"], 1.0],
	"Bathroom_WashingMachine": [["washer"], 1.0],
	"Bookshelf": [["bookcaseOpen"], 1.0],
	"Shelf_Small1": [["bookcaseOpenLow"], 1.0],
	"Shelf_Large": [["bookcaseClosedWide"], 1.0],
	"Drawer_2": [["sideTableDrawers"], 1.0],
	"Drawer_4": [["bookcaseClosed"], 1.0],
	"Couch_Large1": [["loungeSofaLong"], 1.0],
	"Couch_Small1": [["loungeChair"], 1.0],
	"Couch_Medium1": [["loungeSofa"], 1.0],
	"Couch_L": [["loungeSofaCorner"], 1.0],
	"Carpet_1": [["rugRectangle"], 1.0],
	"Carpet_2": [["rugSquare"], 1.0],
	"Carpet_Round": [["rugRound"], 1.0],
	"Houseplant_1": [["pottedPlant"], 1.0],
	"Houseplant_3": [["plantSmall1"], 2.6],
	"Houseplant_5": [["plantSmall2"], 2.6],
	"Houseplant_7": [["plantSmall3"], 2.6],
	"Light_Floor1": [["lampRoundFloor"], 1.0],
	"Light_Floor3": [["lampSquareFloor"], 1.0],
	"Light_Stand1": [["sideTable", "lampSquareTable"], 1.0],
	"Light_Stand2": [["sideTable", "lampRoundTable"], 1.0],
	"Trashcan_Small1": [["trashcan"], 1.0],
	"Trashcan_Large": [["trashcan"], 1.4],
	"TV": [["cabinetTelevision", "televisionModern"], 1.0],
	"Radio": [["sideTable", "radio"], 1.0],
	"Teddy": [["bear"], 1.2],
	"Coat_Rack": [["coatRackStanding"], 1.0],
}

var viewport: SubViewport
var holder: Node3D
var queue := []
var frames := 0
var index := {}


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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	if FileAccess.file_exists(OUT + "sprites.json"):
		index = JSON.parse_string(FileAccess.get_file_as_string(OUT + "sprites.json"))


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
		var f := FileAccess.open(OUT + "sprites.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(index, "\t"))
		print("baked %d sprites" % index.size())
		quit()
		return true
	var row: Array = MODELS[queue[0][0]]
	var r: int = queue[0][1]
	var stack := Node3D.new()  # the parts, stacked
	var top := 0.0
	for part in row[0]:
		var model: Node3D = load(SRC % part).instantiate()
		var box := bounds(model)
		var holder_part := Node3D.new()
		holder_part.add_child(model)
		model.position -= Vector3(box.position.x + box.size.x / 2.0, box.position.y - top, box.position.z + box.size.z / 2.0)
		stack.add_child(holder_part)
		top += box.size.y if part != row[0][-1] else 0.0
	var aabb := bounds_of_children(stack)
	var s := KIT_SCALE * MODEL_SCALE * float(row[1])
	s = minf(s, MAX_FOOTPRINT / maxf(aabb.size.x, aabb.size.z))
	var pivot := Node3D.new()
	pivot.rotation.y = r * PI / 2.0  # the kit's models face +z, the +y grid direction
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
	var name := "%s_r%d" % [sprite, r]
	image.get_region(used).save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	index[name] = {"anchor": [SIZE / 2 - used.position.x, SIZE / 2 - used.position.y]}
	frames = 0
	next_model()


# The game's soft pastel look: the kit's own colours, lifted a little towards a warm white.
const SOFTEN := 0.12


func soften(image: Image) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var rgb := Color(c.r, c.g, c.b).lerp(Color(1.0, 0.97, 0.98), SOFTEN)
			image.set_pixel(x, y, Color(rgb.r, rgb.g, rgb.b, c.a))
