# Screenshot of the game with every HUD panel open (needs a window), or of the home screen:
#   godot --path . -s res://tools/shot.gd -- out.png [W H [menu|build]]
#   godot --path . -s res://tools/shot.gd -- out.png W H sky HOUR WEATHER   (outdoors, no panels: the atmosphere)
extends SceneTree

var frames := 0
var out := "shot.png"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 2:
		DisplayServer.window_set_size(Vector2i(int(args[1]), int(args[2])))
	if args.size() > 3 and args[3] == "menu":
		change_scene_to_file("res://scenes/menu.tscn")
		frames = 61  # nothing to open: just wait and save
	else:
		change_scene_to_file("res://scenes/main.tscn")


func _process(_d: float) -> bool:
	frames += 1
	var args := OS.get_cmdline_user_args()
	if frames == 60 and args.size() > 5 and args[3] == "sky":
		var hud: CanvasLayer = get_first_node_in_group("hud")
		var world: Node2D = hud.player.world
		world.clock = (float(args[4]) - 8.0) * 60.0
		world.weather = args[5]
		world.weather_until = world.now() + 99999.0
		hud.player.grid_pos = Vector2(494, 512)
		hud.player.building = -1
		world.update_view(true)
	elif frames == 60 and args.size() > 3 and args[3] == "build":
		get_first_node_in_group("hud").game.build.toggle()
	elif frames == 60:
		var hud: CanvasLayer = get_first_node_in_group("hud")
		hud.set_today(true)
		hud.set_passport(true)
		hud.toggle_relationships()
		hud.show_toast("Game saved ✿", "saved")
		var p: Node2D = hud.player
		for n in 3:
			hud.heard(p, "A rather long line of chat to see how the feed wraps and where it ends up on the screen", null)
		hud.talk.open(p, get_first_node_in_group("characters") if get_first_node_in_group("characters") != p else get_nodes_in_group("characters")[1])
		root.get_tree().paused = false
	if frames == 200:
		root.get_texture().get_image().save_png(out)
		quit()
	return false
