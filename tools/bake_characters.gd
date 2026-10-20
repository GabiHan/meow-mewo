# Bakes every look in scripts/looks.gd into a sprite sheet: a Kenney "Mini Characters" model (glTF,
# rigged and animated), posed by sampling its own animations, rendered at the game's isometric angle
# in 8 directions × FRAMES frames.
#
# Also a head portrait per look (art/characters/<look>_face.png, FACE × FACE, the HUD passport).
#
# Run (needs a window):  godot --path . -s res://tools/bake_characters.gd   then  godot --headless --import
# Only some looks: add `-- jo sam`. Only the portraits (sheets untouched): `-- portraits` (and optional looks).
extends SceneTree

const Looks = preload("res://scripts/looks.gd")
const MODEL := "res://assets/kenney/characters/Models/GLB format/%s.glb"
const RENDER := 256  # render square; the cell is cut out around the feet
const PX_PER_M := 45.25
const SCALE := 2.0  # metres per kit unit: the chibi models are 0.78 units tall, about 1.55 m in the game
const OUT := "res://art/characters/"
const FACE := 128  # portrait size in pixels
const FACE_SIZE := 0.95  # metres of head in view (orthographic)
const FACE_FROM := Vector3(0.35, 0.08, 1.0)  # camera direction from the head: in front, a little to the side and above

# frame -> [animation, time as a share of its length]; the model faces +z (the +y grid direction)
const POSES := {
	Looks.IDLE: ["idle", 0.0],
	Looks.WALK: ["walk", 0.125], Looks.WALK + 1: ["walk", 0.375], Looks.WALK + 2: ["walk", 0.625], Looks.WALK + 3: ["walk", 0.875],
	Looks.SIT: ["sit", 1.0],
	Looks.LIE: ["static", 0.0],
	Looks.RUN: ["sprint", 0.125], Looks.RUN + 1: ["sprint", 0.375], Looks.RUN + 2: ["sprint", 0.625], Looks.RUN + 3: ["sprint", 0.875],
	Looks.BENT: ["pick-up", 0.5],
	Looks.DOWN: ["die", 1.0],
}

var viewport: SubViewport
var holder: Node3D
var jobs := []  # [look, dir, frame]
var current_look := ""
var model: Node3D
var skeleton: Skeleton3D
var animations: AnimationPlayer
var sheet: Image
var frames_waited := 0
var face_viewport: SubViewport
var face_cam: Camera3D


func _initialize() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(RENDER, RENDER)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = RENDER / PX_PER_M
	var pitch := deg_to_rad(30.0)
	var eye := Vector3(sin(PI / 4) * cos(pitch), sin(pitch), cos(PI / 4) * cos(pitch)) * 30.0
	cam.transform = Transform3D(Basis.looking_at(-eye, Vector3.UP), eye)
	viewport.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(30.0), 0.0)
	sun.light_energy = 1.2
	viewport.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.95, 0.93, 0.9)
	env.environment.ambient_light_energy = 0.8
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	viewport.add_child(env)
	holder = Node3D.new()
	viewport.add_child(holder)
	face_viewport = SubViewport.new()  # same 3D world, a close-up camera on the head
	face_viewport.size = Vector2i(FACE, FACE)
	face_viewport.transparent_bg = true
	face_viewport.world_3d = viewport.find_world_3d()
	face_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	face_viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(face_viewport)
	face_cam = Camera3D.new()
	face_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	face_cam.size = FACE_SIZE
	face_viewport.add_child(face_cam)
	var only: Array = OS.get_cmdline_user_args()  # optional: bake only these looks
	var portraits_only := "portraits" in only
	only.erase("portraits")
	for look in Looks.LOOKS:
		if only.is_empty() or look in only:
			if not portraits_only:
				for d in 8:
					for f in Looks.FRAMES:
						jobs.append([look, d, f])
			jobs.append([look, -1, Looks.IDLE])  # the portrait
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))


func _process(_delta: float) -> bool:
	if frames_waited == 0:
		if jobs.is_empty():
			finish_sheet()
			print("baked character sheets")
			quit()
			return true
		var job: Array = jobs[0]
		if job[0] != current_look:
			finish_sheet()
			build(job[0])
		pose(maxi(job[1], 0), job[2])
		if job[1] < 0:
			aim_at_head()
	frames_waited += 1
	if frames_waited < 3:
		return false
	var job: Array = jobs.pop_front()
	if job[1] < 0:
		var face := face_viewport.get_texture().get_image()
		face.adjust_bcs(1.05, 0.95, 0.95)
		face.save_png(ProjectSettings.globalize_path(OUT + job[0] + "_face.png"))
		frames_waited = 0
		return false
	var image := viewport.get_texture().get_image()
	image.adjust_bcs(1.05, 0.95, 0.95)  # a softer, pastel finish
	var cell := Rect2i(int(RENDER / 2.0 - Looks.FEET.x), int(RENDER / 2.0 - Looks.FEET.y), Looks.CELL.x, Looks.CELL.y)
	sheet.blit_rect(image, cell, Vector2i(job[2] * Looks.CELL.x, job[1] * Looks.CELL.y))
	frames_waited = 0
	return false


# The close-up camera looks at the middle of the head from FACE_FROM.
func aim_at_head() -> void:
	var head := skeleton.find_bone("head")
	var at: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(head)).origin + Vector3(0, 0.4, 0)
	var eye := at + FACE_FROM.normalized() * 3.0
	face_cam.transform = Transform3D(Basis.looking_at(at - eye, Vector3.UP), eye)


func finish_sheet() -> void:
	if current_look != "" and sheet.get_width() > 0 and not "portraits" in OS.get_cmdline_user_args():
		sheet.save_png(ProjectSettings.globalize_path(OUT + current_look + ".png"))
		print("  ", current_look)


func build(look_name: String) -> void:
	current_look = look_name
	sheet = Image.create(Looks.CELL.x * Looks.FRAMES, Looks.CELL.y * 8, false, Image.FORMAT_RGBA8)
	if model:
		model.queue_free()
	model = load(MODEL % Looks.LOOKS[look_name].model).instantiate()
	holder.add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	animations = model.find_children("*", "AnimationPlayer", true, false)[0]


# Pose for direction d and frame f (see looks.gd: idle, walk ×4, sit, lie, run ×4, bent over, down).
func pose(d: int, f: int) -> void:
	var p: Array = POSES[f]
	animations.play(p[0])
	animations.seek(animations.get_animation(p[0]).length * p[1], true)
	animations.pause()
	model.transform = Transform3D.IDENTITY
	if f == Looks.LIE:  # on their back, along the bed, raised to its mattress
		model.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-90.0)), Vector3(0, 0.22, 0.38))
	elif f == Looks.SIT:
		model.position.y = 0.12  # the animation sits on the floor: up onto a seat
	elif f == Looks.DOWN:  # fallen over: centred on the feet and raised to fit the cell; the game lowers it (Looks.DOWN_DROP)
		model.position = Vector3(0, 0.22, 0.15)
	var turn_body := Transform3D(Basis(Vector3.UP, d * PI / 4.0), Vector3.ZERO)
	holder.transform = Transform3D(Basis().scaled(Vector3.ONE * SCALE), Vector3.ZERO) * turn_body
