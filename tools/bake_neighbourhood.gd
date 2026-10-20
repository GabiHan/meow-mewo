# Bakes the neighbourhood (assets/kenney/suburban, Kenney "City Kit (Suburban)", CC0) into isometric
# sprites that match the game's 2:1 projection: every house in World.START_BUILDINGS, and the trees.
#
# Run (needs a window):  godot --path . -s res://tools/bake_neighbourhood.gd   then  godot --headless --import
# Output: art/neighbourhood/<sprite>.png and sprites.json ({"<sprite>": {"anchor": [x, y]}}, like furniture)
#   house_<building>_<floors>[_winter]: the house stretched over its rect (walls included), front towards its
#     door, "models"[floors - 1] of the building (one- and two-storey: build mode can add a storey). The anchor
#     is the rect's centre on the ground. The kit's palette texture is repainted in the house's "color" (walls)
#     and "roof"; in winter the roof is snowy. world.gd cuts the sprite into strips so people sort around it.
#   tree_<large|small>_<season>: leaves in GameTime.LEAVES; the anchor is the trunk's foot.
#   road_straight_x / road_straight_y / road_crossroad: 3×3 tiles of road (assets/kenney/roads, "City Kit (Roads)"),
#     a kit tile per 3 m, graded to the pastel palette by brightness (ROAD_DARK → ROAD_LIGHT). Anchor: the centre.
#   car_<model>_r<0-3>: the cars (assets/kenney/cars, "Car Kit"), r0 heading +y, r1 +x, r2 −y, r3 −x like
#     furniture; the anchor is the car's centre on the ground.
extends SceneTree

const World = preload("res://scripts/world.gd")
const GameTime = preload("res://scripts/game_time.gd")
const SRC := "res://assets/kenney/suburban/Models/GLB format/%s.glb"
const PALETTE := "res://assets/kenney/suburban/Models/GLB format/Textures/colormap.png"
const OUT := "res://art/neighbourhood/"
const SIZE := 1024
const PX_PER_M := 45.25
const HOUSE_HEIGHT := 0.5  # houses are stretched to their rect; their height is scaled by this share of that
const TREE_SCALE := 5.0  # metres per kit unit
const TREES := {"large": "tree-large", "small": "tree-small"}
const ROAD_SRC := "res://assets/kenney/roads/Models/GLB format/%s.glb"
const CAR_SRC := "res://assets/kenney/cars/Models/GLB format/%s.glb"
const ROAD_SCALE := 3.0  # metres per kit tile: the game's roads are 3 tiles wide (world.gd ROAD_WIDTH)
const ROADS := {"road_straight_y": ["road-straight", 0.0], "road_straight_x": ["road-straight", PI / 2.0], "road_crossroad": ["road-crossroad", 0.0]}
const ROAD_DARK := Color(0.69, 0.66, 0.77)  # asphalt
const ROAD_LIGHT := Color(0.97, 0.96, 0.99)  # pavements and lines
const CAR_SCALE := 0.85  # metres per kit unit: a car is about 1.3 m wide and 2.2 m long
const CARS := ["sedan", "suv", "taxi", "van", "hatchback-sports", "police", "delivery"]
const SOFTEN := 0.12  # cars: their own colours, lifted a little towards white (like furniture)
# Swatches of the kit's palette texture (pixels)
const ROOF := Rect2i(0, 128, 64, 128)
const WALL := Rect2i(192, 256, 64, 128)
const LEAF := [Rect2i(0, 128, 64, 128), Rect2i(64, 384, 64, 128)]
const SNOW := Color(0.98, 0.98, 1.0)  # world.gd SNOW_ROOF_COLOR

var viewport: SubViewport
var holder: Node3D
var queue := []  # [sprite, model path, texture (null: the model's own), transform, finish ("", "road", "soft")]
var frames := 0
var index := {}
var palette: Image


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
	var pitch := deg_to_rad(30.0)
	var eye := Vector3(sin(PI / 4) * cos(pitch), sin(pitch), cos(PI / 4) * cos(pitch)) * 60.0
	cam.transform = Transform3D(Basis.looking_at(-eye, Vector3.UP), eye)
	cam.far = 200.0
	viewport.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-55.0), deg_to_rad(20.0), 0.0)
	sun.light_energy = 1.2
	viewport.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.95, 0.93, 0.9)
	env.environment.ambient_light_energy = 0.75
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	viewport.add_child(env)
	holder = Node3D.new()
	viewport.add_child(holder)
	palette = Image.load_from_file(ProjectSettings.globalize_path(PALETTE))
	palette.convert(Image.FORMAT_RGBA8)

	for i in World.START_BUILDINGS.size():
		var b: Dictionary = World.START_BUILDINGS[i]
		for floors in [1, 2]:
			for winter in [false, true]:
				var tex := repaint({ROOF: SNOW if winter else b.roof, WALL: b.color})
				queue.append(["house_%d_%d%s" % [i, floors, "_winter" if winter else ""], SRC % b.models[floors - 1], tex, house_fit(b, b.models[floors - 1]), ""])
	for t in TREES:
		for season in GameTime.LEAVES:
			var swatches := {}
			for r in LEAF:
				swatches[r] = GameTime.LEAVES[season]
			queue.append(["tree_%s_%s" % [t, season], SRC % TREES[t], repaint(swatches), Transform3D(Basis().scaled(Vector3.ONE * TREE_SCALE), Vector3.ZERO), ""])
	for road in ROADS:
		var path: String = ROAD_SRC % ROADS[road][0]
		queue.append([road, path, null, centred(path, Basis(Vector3.UP, ROADS[road][1]).scaled(Vector3.ONE * ROAD_SCALE)), "road"])
	for car in CARS:
		for r in 4:
			var path: String = CAR_SRC % car
			queue.append(["car_%s_r%d" % [car, r], path, null, centred(path, Basis(Vector3.UP, r * PI / 2.0).scaled(Vector3.ONE * CAR_SCALE)), "soft"])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))


# The palette with each swatch rect repainted in a colour, keeping its light-to-dark gradient.
func repaint(swatches: Dictionary) -> ImageTexture:
	var img := palette.duplicate()
	for r: Rect2i in swatches:
		var target: Color = swatches[r]
		var top := palette.get_pixel(r.position.x + r.size.x / 2, r.position.y).get_luminance()
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var k := palette.get_pixel(x, y).get_luminance() / maxf(top, 0.01)
				img.set_pixel(x, y, Color(target.r * k, target.g * k, target.b * k))
	return ImageTexture.create_from_image(img)


# Turn the model's front (+z) towards the door and stretch it over the building's rect, centred on it.
func house_fit(b: Dictionary, model_name: String) -> Transform3D:
	var model: Node3D = load(SRC % model_name).instantiate()
	var box := bounds(model)
	model.free()
	var r: Rect2i = b.rect
	var door_on_x: bool = b.door.x == r.end.x - 1  # door on the +x wall: front faces +x
	var turn := Basis(Vector3.UP, PI / 2.0) if door_on_x else Basis()
	var size := Vector3(box.size.z, 0, box.size.x) if door_on_x else Vector3(box.size.x, 0, box.size.z)
	var sx := r.size.x / size.x
	var sz := r.size.y / size.z
	var scale := Basis().scaled(Vector3(sx, (sx + sz) / 2.0 * HOUSE_HEIGHT, sz))
	var centre := box.position + box.size / 2.0
	return Transform3D(scale * turn, Vector3.ZERO) * Transform3D(Basis(), -Vector3(centre.x, box.position.y, centre.z))


# `basis` applied to the model, with its floor centre on the origin.
func centred(path: String, basis: Basis) -> Transform3D:
	var model: Node3D = load(path).instantiate()
	var box := bounds(model)
	model.free()
	var centre := box.position + box.size / 2.0
	return Transform3D(basis, Vector3.ZERO) * Transform3D(Basis(), -Vector3(centre.x, box.position.y, centre.z))


static func bounds(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var chain := Transform3D.IDENTITY
		var p: Node = m
		while p != n:
			chain = p.transform * chain
			p = p.get_parent()
		var b: AABB = chain * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 1:
		return next_model()
	if frames < 4:
		return false
	var job: Array = queue.pop_front()
	var image := viewport.get_texture().get_image()
	finish(image, job[4])
	var used := image.get_used_rect()
	image.get_region(used).save_png(ProjectSettings.globalize_path(OUT + job[0] + ".png"))
	index[job[0]] = {"anchor": [SIZE / 2 - used.position.x, SIZE / 2 - used.position.y]}
	frames = 0
	return false


# Roads: graded by brightness from ROAD_DARK to ROAD_LIGHT. Cars: softened.
func finish(image: Image, how: String) -> void:
	if how == "":
		return
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var rgb: Color
			if how == "road":
				rgb = ROAD_DARK.lerp(ROAD_LIGHT, clampf((c.get_luminance() - 0.2) / 0.6, 0.0, 1.0))
			else:
				rgb = Color(c.r, c.g, c.b).lerp(Color(1.0, 0.97, 0.98), SOFTEN)
			image.set_pixel(x, y, Color(rgb.r, rgb.g, rgb.b, c.a))


func next_model() -> bool:
	for child in holder.get_children():
		holder.remove_child(child)
		child.queue_free()
	if queue.is_empty():
		var f := FileAccess.open(OUT + "sprites.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(index, "\t"))
		print("baked %d neighbourhood sprites" % index.size())
		quit()
		return true
	var job: Array = queue[0]
	var model: Node3D = load(job[1]).instantiate()
	for m in model.find_children("*", "MeshInstance3D", true, false):
		if job[2] == null:
			break
		for s in m.mesh.get_surface_count():
			var mat: StandardMaterial3D = m.mesh.surface_get_material(s).duplicate()
			mat.albedo_texture = job[2]
			m.set_surface_override_material(s, mat)
	var pivot := Node3D.new()
	pivot.transform = job[3]
	pivot.add_child(model)
	holder.add_child(pivot)
	return false
