# You: the mouse and keyboard, driving one character of your household (`body`).
# Any character can be controlled (npc.gd `controlled`); you switch between the people who live in
# your home with the household bar at the top left (hud.gd), or take_control() in code. Babies and
# toddlers aren't playable: clicking them shows their needs instead.
#
# Left-click floor   -> walk there (finds a way around walls, through doors)
# Left-click object  -> walk to it and use it. Kitchen objects (Fridge, Stove, Counter, Table, Sink)
#                       open a menu instead: cook, drink, eat leftovers, wash dishes (kitchen.gd)
# Left-click stairs  -> go to the other floor
# Left-click a door  -> (outside) walk in if it's your home or you're invited; otherwise knock (ownership.gd)
# Left-click a window-> (outside, ground floor) walk to it and peek in until you do something else
# Left-click the Bus stop -> jobs menu: apply, quit, go to work (jobs.gd)
# Left-click a person -> menu of social interactions (social.gd); a baby/toddler -> their needs panel
# Tab                -> toggle Manual / Auto for the character you control
extends Node

const Iso = preload("res://scripts/iso.gd")
const Social = preload("res://scripts/social.gd")
const Emotions = preload("res://scripts/emotions.gd")
const Traits = preload("res://scripts/traits.gd")
const Kitchen = preload("res://scripts/kitchen.gd")
const Jobs = preload("res://scripts/jobs.gd")
const Ages = preload("res://scripts/ages.gd")
const Ownership = preload("res://scripts/ownership.gd")
const Romance = preload("res://scripts/romance.gd")
const Actions = preload("res://scripts/actions.gd")

const CLICK_RADIUS := 22.0  # pixels around a character's body that count as clicking them
const MENU_ID_OFFSET := 100  # entry ids start here so they never clash with header items

var body: Node2D  # the character you control
var main: Node2D
var camera: Camera2D
var menu: PopupMenu
var menu_actions := []  # Callable per menu entry, indexed by item id - MENU_ID_OFFSET


func setup(p_main: Node2D, p_camera: Camera2D) -> Node:
	main = p_main
	camera = p_camera
	return self


func _ready() -> void:
	add_to_group("controller")
	menu = PopupMenu.new()
	menu.theme = load("res://scripts/ui_theme.gd").get_theme()
	menu.id_pressed.connect(_on_menu_choice)
	add_child(menu)


# --- Who you are ---

# Become `c`: the camera follows them, the HUD shows their needs, the view is theirs.
func take_control(c: Node2D) -> void:
	if body and is_instance_valid(body):
		body.controlled = false
		body.remove_from_group("player")
	body = c
	c.controlled = true
	c.add_to_group("player")
	if camera.get_parent():
		camera.get_parent().remove_child(camera)
	c.add_child(camera)
	main.player = c
	main.world.player = c
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.player = c


# Everyone you can switch to: people living in your home (babies and toddlers can't be played).
func household() -> Array:
	return get_tree().get_nodes_in_group("characters").filter(func(c): return c.home == body.home and not c.dead)


static func playable(c: Node2D) -> bool:
	return Ages.stage(c) >= Ages.CHILD and not c.dead


# The character you controlled died: carry on as someone else in the household (or anyone left).
func on_death(c: Node2D) -> void:
	var next: Array = household().filter(func(o): return o != c and playable(o))
	if next.is_empty():
		next = get_tree().get_nodes_in_group("characters").filter(func(o): return o != c and playable(o))
	if next.is_empty():
		return
	next.sort_custom(func(a, b): return a.age_days > b.age_days)
	take_control(next[0])
	Social.log_event("You now live as {a}", next[0], next[0])


# --- Input ---

func _unhandled_input(event: InputEvent) -> void:
	if body == null or body.at_work or body.dead:
		return  # away at work until the shift ends
	if main.build and main.build.active:
		return  # build mode handles the mouse
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse: Vector2 = body.get_global_mouse_position()
		var other := character_at(mouse)
		var hit: Dictionary = main.world.exterior_hit(mouse) if body.building < 0 else {}
		if other and Ages.stage(other) <= Ages.TODDLER:
			get_tree().get_first_node_in_group("hud").show_child(other)  # little ones: their needs, from the left
		elif other:
			open_menu(other)
		elif not hit.is_empty():
			body.click_building(hit)
		else:
			click_tile(Vector2i(Iso.to_grid(mouse).round()))
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		body.toggle_mode()


func click_tile(cell: Vector2i) -> void:
	var obj: Node2D = body.object_at(cell)
	if obj and obj.object_name == "Bus stop":
		open_job_menu()
	elif obj and obj.object_name in Kitchen.KITCHEN_OBJECTS:
		open_kitchen_menu(obj)
	elif obj and Actions.for_object(obj).size() > 1:
		open_object_menu(obj)
	else:
		body.click_tile(cell)


# Furniture with several things to do (actions.gd): Sleep / Nap / Relax, Pee / Poo, ...
func open_object_menu(obj: Node2D) -> void:
	var c := body
	var entries := []
	for action in Actions.for_object(obj):
		var gains := []
		for need in action.ads:
			gains.append("%s %+d" % [need, action.ads[need]])
		var go := func():
			c.cancel_current()
			if not c.use_object(obj, action):
				c.activity = "Can't reach the " + obj.object_name
		entries.append({"label": "%s  (%s, %d min)" % [action.name, ", ".join(gains), action.minutes],
			"disabled": obj.user != null and obj.user != c, "action": go})
	show_menu([obj.object_name + ("  (in use)" if obj.user != null and obj.user != c else "")], entries)


func character_at(screen_pos: Vector2) -> Node2D:
	for c in get_tree().get_nodes_in_group("characters"):
		if c != body and c.is_visible_in_tree() and screen_pos.distance_to(c.position + Vector2(0, -25)) < CLICK_RADIUS:
			return c
	return null


# --- Menus ---

func open_menu(other: Node2D) -> void:
	var f := Social.friendship(body, other)
	var entries := []
	for i in Social.available_interactions(body, other):
		entries.append({"label": i.name, "action": body.order_interaction.bind(other, i)})
	var headers := ["%s — %s (%d)" % [Social.display_name(body, other), Social.relationship_word(f), f],
		"Feeling: %s (%s)" % [Emotions.describe(other), Emotions.reasons(other)]]
	if body.known.has(other.npc_name):  # you learn someone's personality once you've met them
		headers.append("%s · %s" % [Ages.describe(other), Romance.status_text(other)])
		headers.append("Traits: " + ", ".join(other.traits.map(func(t): return "%s (%s)" % [t, Traits.TRAITS[t].text])))
	else:
		headers.append("Traits: ? (talk to them to find out)")
	var r := Romance.romance(body, other)
	if r != 0.0:
		headers.append("Romance: %+d (%s)" % [r, Romance.word(r)])
	var mems := Social.memories_of(other, body)
	for m in mems.slice(maxi(0, mems.size() - 2)):
		headers.append("Remembers: you %s" % m.text)
	show_menu(headers, entries)


func open_kitchen_menu(obj: Node2D) -> void:
	var entries := Kitchen.menu(body, obj, body.do_task)
	if entries.is_empty():
		body.activity = "Nothing to do at the " + obj.object_name
		return
	show_menu([obj.object_name], entries)


func open_job_menu() -> void:
	var c := body
	var entries := []
	var t: float = main.world.now()
	var go_now := func():
		c.cancel_current()
		c.go_to_work()
	if Jobs.is_school(c.job) and c.job != "College":
		entries.append({"section": "School: %s (grade %s)" % [c.job, Jobs.grade(c.performance)]})
		entries.append({"label": "Go to school now" if Jobs.should_work(c, t) else "No school now (%s)" % Jobs.schedule_text(c.job),
			"disabled": not Jobs.should_work(c, t), "action": go_now})
		show_menu(["Bus stop — $%d" % c.money], entries)
		return
	if c.job != "":
		entries.append({"section": "Your job" if not Jobs.is_school(c.job) else "College (%d/%d days, grade %s)" % [
			c.college_days, Jobs.COLLEGE_DAYS, Jobs.grade(c.performance)]})
		var go := "Go to work now" if Jobs.should_work(c, t) else "Not a work time (%s)" % Jobs.schedule_text(c.job)
		entries.append({"label": go, "disabled": not Jobs.should_work(c, t), "action": go_now})
		entries.append({"label": "Quit (%s at the %s)" % [Jobs.title(c), c.job], "action": Jobs.quit_job.bind(c)})
	entries.append({"section": "Job listings" + ("" if Ages.is_grown_up(c) else " (young adults and up)")})
	for name in Jobs.JOBS:
		var j: Dictionary = Jobs.JOBS[name]
		if Jobs.is_school(name) and name != "College":
			continue
		var start: int = mini(1, j.levels.size() - 1) if c.degree and not Jobs.is_school(name) else 0
		var label := "Enroll in College — %s, %d days to a degree" % [Jobs.schedule_text(name), Jobs.COLLEGE_DAYS] if name == "College" \
			else "%s at the %s — $%d/h, %s (%s)" % [j.levels[start][0], name, j.levels[start][1], Jobs.schedule_text(name), j.skill]
		entries.append({"label": label, "disabled": name == c.job or not Jobs.can_take(c, name), "action": Jobs.take_job.bind(c, name)})
	show_menu(["Bus stop — $%d" % c.money], entries)


# Someone knocked on your door while you're home (Manual mode): you decide.
func ask_at_door(host: Node2D, knocker: Node2D, b: int) -> void:
	show_menu(["%s is knocking at the door" % Social.display_name(host, knocker)], [
		{"label": "Let them in", "action": Ownership.answer.bind(host, knocker, b, true)},
		{"label": "Turn them away", "action": Ownership.answer.bind(host, knocker, b, false)},
	])


# headers: greyed-out lines at the top. entries: {label, disabled?, action} or {section: title}.
func show_menu(headers: Array, entries: Array) -> void:
	menu.clear()
	menu_actions = []
	for h in headers:
		menu.add_item(h)
		menu.set_item_disabled(menu.item_count - 1, true)
	for e in entries:
		if e.has("section"):
			menu.add_separator(e.section)
			continue
		menu.add_item(e.label, MENU_ID_OFFSET + menu_actions.size())
		menu.set_item_disabled(menu.item_count - 1, e.get("disabled", false))
		menu_actions.append(e.action)
	menu.popup(Rect2i(Vector2i(get_viewport().get_mouse_position()), Vector2i.ZERO))


func _on_menu_choice(id: int) -> void:
	var n := id - MENU_ID_OFFSET
	if n >= 0 and n < menu_actions.size():
		menu_actions[n].call()
