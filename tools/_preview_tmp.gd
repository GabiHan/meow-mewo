extends SceneTree
# Contact sheet of prefabs: godot --path . -s res://tools/_preview_tmp.gd -- <dir> <out.png>
var frames := 0
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var files := []
	for sub in Array(DirAccess.get_directories_at(args[0])) + [""]:
		var d: String = args[0] + ("/" + sub if sub != "" else "")
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".tscn") and not "_door" in f and not "_cover" in f and f != "frame.tscn":
				files.append(d + "/" + f)
	files.sort()
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var grid := GridContainer.new()
	grid.columns = 11
	root.add_child(grid)
	for path in files:
		var box := VBoxContainer.new()
		var svc := SubViewportContainer.new()
		var sv := SubViewport.new()
		sv.size = Vector2i(112, 90)
		sv.own_world_3d = true
		sv.transparent_bg = false
		svc.add_child(sv)
		var model: Node3D = load(path).instantiate()
		sv.add_child(model)
		var aabb := AABB()
		var first := true
		for m in model.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = m.global_transform * m.get_aabb() if m.is_inside_tree() else m.get_aabb()
			aabb = b if first else aabb.merge(b)
			first = false
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = maxf(aabb.size.length(), 0.1) * 1.1
		var c := aabb.get_center()
		var eye := c + Vector3(1, 0.8, 1).normalized() * 10.0
		cam.transform = Transform3D(Basis.looking_at(c - eye, Vector3.UP), eye)
		sv.add_child(cam)
		var sun := DirectionalLight3D.new()
		sun.rotation = Vector3(-0.9, 0.4, 0)
		sv.add_child(sun)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color(0.85, 0.85, 0.85)
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color.WHITE
		env.environment.ambient_light_energy = 0.6
		sv.add_child(env)
		box.add_child(svc)
		var l := Label.new()
		l.text = "%s %.1fx%.1fx%.1f" % [path.get_file().get_basename(), aabb.size.x, aabb.size.y, aabb.size.z]
		l.add_theme_font_size_override("font_size", 8)
		box.add_child(l)
		grid.add_child(box)
func _process(_d: float) -> bool:
	frames += 1
	if frames == 30:
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[1])
		quit()
	return false
