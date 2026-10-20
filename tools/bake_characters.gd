# Bakes every look in scripts/looks.gd into a sprite sheet: the Quaternius base body (glTF, rigged)
# posed in code (no animations in the free pack), clothes painted on by bone, hair attached to the
# head bone, rendered at the game's isometric angle in 8 directions × 7 frames.
#
# Also a head portrait per look (art/characters/<look>_face.png, FACE × FACE, the HUD passport).
#
# Run (needs a window):  godot --path . -s res://tools/bake_characters.gd   then  godot --headless --import
# Only some looks: add `-- jo sam`. Only the portraits (sheets untouched): `-- portraits` (and optional looks).
extends SceneTree

const Looks = preload("res://scripts/looks.gd")
const BODY := {"F": "res://assets/characters/body/Superhero_Female_FullBody.gltf", "M": "res://assets/characters/body/Superhero_Male_FullBody.gltf"}
const SKIN := {
	"F": {"light": "res://assets/characters/body/T_Superhero_Female_Light_BaseColor.png", "dark": "res://assets/characters/body/T_Superhero_Female_Dark_BaseColor.png"},
	"M": {"light": "res://assets/characters/body/T_Superhero_Male_Ligh.png", "dark": "res://assets/characters/body/T_Superhero_Male_Dark.png"},
}
const HAIR := "res://assets/characters/hair/%s.gltf"
const RENDER := 256  # render square; the cell is cut out around the feet
const PX_PER_M := 45.25
const SCALE := 0.85
const OUT := "res://art/characters/"
const FACE := 128  # portrait size in pixels
const FACE_SIZE := 0.3  # metres of head in view (orthographic)
const FACE_FROM := Vector3(0.35, 0.08, 1.0)  # camera direction from the head: in front, a little to the side and above

# Clothing category per bone name prefix: 0 skin, 1 shirt, 2 pants, 3 shoes
const CATEGORY := {"pelvis": 2, "spine": 1, "clavicle": 1, "upperarm": 1, "thigh": 2, "calf": 2, "foot": 3, "ball": 3}

const SHADER := """
shader_type spatial;
uniform sampler2D skin_tex : source_color;
uniform vec3 shirt : source_color;
uniform vec3 pants : source_color;
uniform vec3 shoes : source_color;
uniform int bone_cat[80];
varying flat int cat;
void vertex() {
	int best = 0;
	float w = -1.0;
	for (int i = 0; i < 4; i++) {
		if (BONE_WEIGHTS[i] > w) { w = BONE_WEIGHTS[i]; best = int(BONE_INDICES[i]); }
	}
	cat = bone_cat[best];
}
void fragment() {
	vec3 tex = texture(skin_tex, UV).rgb;
	float shade = 0.75 + 0.25 * dot(tex, vec3(0.33));
	if (cat == 1) { ALBEDO = shirt * shade; }
	else if (cat == 2) { ALBEDO = pants * shade; }
	else if (cat == 3) { ALBEDO = shoes * shade; }
	else { ALBEDO = tex; }
	ROUGHNESS = 0.85;
}
"""

var viewport: SubViewport
var holder: Node3D
var jobs := []  # [look, dir, frame]
var current_look := ""
var model: Node3D
var skeleton: Skeleton3D
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
	sun.light_energy = 1.4
	viewport.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.95, 0.93, 0.9)
	env.environment.ambient_light_energy = 1.1
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
		face.adjust_bcs(1.08, 0.9, 0.9)
		face.save_png(ProjectSettings.globalize_path(OUT + job[0] + "_face.png"))
		frames_waited = 0
		return false
	var image := viewport.get_texture().get_image()
	image.adjust_bcs(1.08, 0.9, 0.9)  # a softer, pastel finish
	var cell := Rect2i(int(RENDER / 2.0 - Looks.FEET.x), int(RENDER / 2.0 - Looks.FEET.y), Looks.CELL.x, Looks.CELL.y)
	sheet.blit_rect(image, cell, Vector2i(job[2] * Looks.CELL.x, job[1] * Looks.CELL.y))
	frames_waited = 0
	return false


# The close-up camera looks at the head bone from FACE_FROM.
func aim_at_head() -> void:
	var head := skeleton.find_bone("Head")
	var at: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(head)).origin + Vector3(0, 0.1, 0)
	var eye := at + FACE_FROM.normalized() * 3.0
	face_cam.transform = Transform3D(Basis.looking_at(at - eye, Vector3.UP), eye)


func finish_sheet() -> void:
	if current_look != "" and sheet.get_width() > 0 and not "portraits" in OS.get_cmdline_user_args():
		sheet.save_png(ProjectSettings.globalize_path(OUT + current_look + ".png"))
		print("  ", current_look)


func find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r := find_skeleton(c)
		if r:
			return r
	return null


func build(look_name: String) -> void:
	current_look = look_name
	sheet = Image.create(Looks.CELL.x * Looks.FRAMES, Looks.CELL.y * 8, false, Image.FORMAT_RGBA8)
	if model:
		model.queue_free()
	var look: Dictionary = Looks.LOOKS[look_name]
	model = load(BODY[look.body]).instantiate()
	holder.add_child(model)
	skeleton = find_skeleton(model)
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER
	material.shader = shader
	material.set_shader_parameter("skin_tex", load(SKIN[look.body][look.skin]))
	material.set_shader_parameter("shirt", look.shirt)
	material.set_shader_parameter("pants", look.pants)
	material.set_shader_parameter("shoes", look.shoes)
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		var surface_material: Material = mesh.mesh.surface_get_material(0)
		if surface_material and surface_material.resource_name.begins_with("MI_Superhero"):
			var cats := PackedInt32Array()
			cats.resize(80)
			for i in mesh.skin.get_bind_count():
				var bone_name := skeleton.get_bone_name(mesh.skin.get_bind_bone(i)) if mesh.skin.get_bind_bone(i) >= 0 else String(mesh.skin.get_bind_name(i))
				for prefix in CATEGORY:
					if bone_name.begins_with(prefix):
						cats[i] = CATEGORY[prefix]
			material.set_shader_parameter("bone_cat", cats)
			mesh.material_override = material
		elif surface_material and surface_material.resource_name.begins_with("MI_Hair"):  # built-in eyebrows
			var brow := StandardMaterial3D.new()
			brow.albedo_color = look.hair_color
			mesh.material_override = brow
	for part in ([look.hair] if look.hair != "" else []) + (["Hair_Beard"] if look.beard else []):
		attach_hair(part, look.hair_color)


# Hair "origin at 0" meshes are placed for the rest pose: attach them to the head bone so they follow it.
func attach_hair(part: String, color: Color) -> void:
	var hair: Node3D = load(HAIR % part).instantiate()
	var head := skeleton.find_bone("Head")
	var attach := BoneAttachment3D.new()
	attach.bone_idx = head
	skeleton.add_child(attach)
	var holder_node := Node3D.new()
	holder_node.transform = skeleton.get_bone_global_rest(head).affine_inverse()
	attach.add_child(holder_node)
	holder_node.add_child(hair)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	for mesh in hair.find_children("*", "MeshInstance3D", true, false):
		mesh.material_override = mat


# Rotate a bone by `angle` around a world axis (character space), on top of its current pose.
func turn(bone_name: String, axis: Vector3, angle: float) -> void:
	var bone := skeleton.find_bone(bone_name)
	var parent := skeleton.get_bone_parent(bone)
	var parent_global := skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis()
	var global := skeleton.get_bone_global_pose(bone).basis
	var target := Basis(axis, angle) * global
	skeleton.set_bone_pose_rotation(bone, (parent_global.inverse() * target).get_rotation_quaternion())


# Pose for direction d and frame f (see looks.gd: idle, walk ×4, sit, lie, run ×4, bent over, down).
func pose(d: int, f: int) -> void:
	skeleton.reset_bone_poses()
	model.transform = Transform3D.IDENTITY
	# arms down from the T-pose
	turn("upperarm_l", Vector3.FORWARD, deg_to_rad(72.0))
	turn("upperarm_r", Vector3.FORWARD, deg_to_rad(-72.0))
	turn("lowerarm_l", Vector3.UP, deg_to_rad(-8.0))
	turn("lowerarm_r", Vector3.UP, deg_to_rad(8.0))
	if f >= Looks.WALK and f < Looks.WALK + 4:
		var swing := sin((f - Looks.WALK + 0.5) / 4.0 * TAU) * deg_to_rad(28.0)  # 4 distinct steps
		turn("thigh_l", Vector3.RIGHT, swing)
		turn("thigh_r", Vector3.RIGHT, -swing)
		turn("calf_l", Vector3.RIGHT, maxf(0.0, -swing) * 1.2)
		turn("calf_r", Vector3.RIGHT, maxf(0.0, swing) * 1.2)
		turn("upperarm_l", Vector3.RIGHT, -swing * 0.8)
		turn("upperarm_r", Vector3.RIGHT, swing * 0.8)
	elif f >= Looks.RUN and f < Looks.RUN + 4:  # bigger strides, bent knees and elbows, leaning forward
		var swing := sin((f - Looks.RUN + 0.5) / 4.0 * TAU) * deg_to_rad(48.0)
		turn("spine_01", Vector3.RIGHT, deg_to_rad(14.0))
		turn("thigh_l", Vector3.RIGHT, swing)
		turn("thigh_r", Vector3.RIGHT, -swing)
		turn("calf_l", Vector3.RIGHT, maxf(0.0, -swing) * 1.6 + deg_to_rad(15.0))
		turn("calf_r", Vector3.RIGHT, maxf(0.0, swing) * 1.6 + deg_to_rad(15.0))
		turn("upperarm_l", Vector3.RIGHT, -swing)
		turn("upperarm_r", Vector3.RIGHT, swing)
		turn("lowerarm_l", Vector3.RIGHT, deg_to_rad(-70.0))
		turn("lowerarm_r", Vector3.RIGHT, deg_to_rad(-70.0))
	elif f == Looks.BENT:  # hunched over, hands towards the knees
		turn("spine_01", Vector3.RIGHT, deg_to_rad(35.0))
		turn("spine_02", Vector3.RIGHT, deg_to_rad(15.0))
		turn("Head", Vector3.RIGHT, deg_to_rad(20.0))
		turn("thigh_l", Vector3.RIGHT, deg_to_rad(-12.0))
		turn("thigh_r", Vector3.RIGHT, deg_to_rad(-12.0))
		turn("calf_l", Vector3.RIGHT, deg_to_rad(18.0))
		turn("calf_r", Vector3.RIGHT, deg_to_rad(18.0))
		turn("upperarm_l", Vector3.RIGHT, deg_to_rad(-35.0))
		turn("upperarm_r", Vector3.RIGHT, deg_to_rad(-35.0))
		model.position.y = -0.08
	elif f == Looks.DOWN:  # face down on the floor, arms out a little
		turn("upperarm_l", Vector3.FORWARD, deg_to_rad(-40.0))
		turn("upperarm_r", Vector3.FORWARD, deg_to_rad(40.0))
		turn("thigh_l", Vector3.FORWARD, deg_to_rad(8.0))
		turn("thigh_r", Vector3.FORWARD, deg_to_rad(-8.0))
		# centred on the feet and raised so it fits the cell; the game lowers it again (Looks.DOWN_DROP)
		model.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(90.0)), Vector3(0, 0.62, -0.85))
	elif f == Looks.SIT:
		turn("thigh_l", Vector3.RIGHT, deg_to_rad(-85.0))
		turn("thigh_r", Vector3.RIGHT, deg_to_rad(-85.0))
		turn("calf_l", Vector3.RIGHT, deg_to_rad(85.0))
		turn("calf_r", Vector3.RIGHT, deg_to_rad(85.0))
		model.position.y = -0.42
	elif f == Looks.LIE:
		model.transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-90.0)), Vector3(0, 0.45, 0.8))
	var turn_body := Transform3D(Basis(Vector3.UP, d * PI / 4.0), Vector3.ZERO)
	holder.transform = Transform3D(Basis().scaled(Vector3.ONE * SCALE), Vector3.ZERO) * turn_body
