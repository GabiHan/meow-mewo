# Saving and loading. Static. A save is one file in user://saves/<slot>.save holding a Dictionary
# written with store_var (Godot's own format, so Vector2/Color/INF survive):
#   meta:    household name, members, in-game date and time, when it was saved (for the menus)
#   world:   clock, kitchens (clean dishes), guests (invitations), speed, who you control, the social log
#   people:  every living person (SAVE_FIELDS of npc.gd); what they were doing at that moment is not kept
#   objects: every usable object (incl. bought furniture, food on counters, graves); props: decoration
# main.gd builds the world (houses, walls, terrain) and then restore() puts all this back.
const GameTime = preload("res://scripts/game_time.gd")
const Social = preload("res://scripts/social.gd")
const Kitchen = preload("res://scripts/kitchen.gd")
const Npc = preload("res://scripts/npc.gd")
const SmartObject = preload("res://scripts/smart_object.gd")
const Prop = preload("res://scripts/prop.gd")

const DIR := "user://saves/"
const VERSION := 1
const SAVE_FIELDS := ["npc_name", "body_color", "grid_pos", "floor", "home", "home_cell", "speed", "needs", "decay",
	"relationships", "known", "traits", "skills", "moodlets", "memories", "greeted", "mood_samples", "next_sample",
	"last_social", "work_log", "learned", "age_days", "sex", "parents", "pregnant_until", "baby_father", "death_years",
	"romance", "lover", "lover_status", "original_home", "last_romance", "money", "job", "job_level", "performance",
	"shift_day", "missed_day", "warned", "degree", "college_days", "look", "auto_mode", "caught_peeks", "knock_cooldown",
	"reminded_day", "illness", "ill_until", "next_symptom", "next_fart", "last_meal"]


static func path(slot: String) -> String:
	return DIR + slot + ".save"


# --- Writing ---

# One person, one object, one prop as plain data (also what online mode sends: net.gd).
static func capture_person(c: Node2D) -> Dictionary:
	var person := {}
	for field in SAVE_FIELDS:
		person[field] = c.get(field)
	return person


static func capture_object(o: Node2D) -> Dictionary:
	return {"name": o.object_name, "building": o.building, "floor": o.floor, "pos": o.grid_pos,
		"ads": o.advertisements, "duration": o.duration, "color": o.color, "height": o.box_height,
		"extras": {"verb": o.verb, "skill": o.skill, "moodlet": o.moodlet, "sprite": o.sprite, "facing": o.facing},
		"catalog_id": o.catalog_id, "items": o.items, "net_id": o.net_id}


static func capture_props(world: Node2D) -> Array:
	var props := []
	for b in world.floor_nodes.size():
		for f in world.floor_nodes[b].size():
			for n in world.floor_nodes[b][f].get_children():
				if "flat" in n:
					props.append({"sprite": n.sprite, "cell": n.cell, "flat": n.flat, "catalog_id": n.catalog_id,
						"rotation": n.rotation_index, "building": b, "floor": f, "wall": n.wall})
	return props


static func capture_log() -> Array:
	return Social.event_log.map(func(e): return [e.text, e.a.npc_name if is_instance_valid(e.a) else e.get("a_name", ""),
		e.b.npc_name if is_instance_valid(e.b) else e.get("b_name", "")])


static func capture(main: Node2D) -> Dictionary:
	var world: Node2D = main.world
	var people: Array = main.get_tree().get_nodes_in_group("characters").map(capture_person)
	var objects: Array = main.get_tree().get_nodes_in_group("smart_objects").map(capture_object)
	var props := capture_props(world)
	var log := capture_log()
	var t: float = world.now()
	var home: int = main.player.home
	return {
		"version": VERSION,
		"meta": {"household": main.household_name,
			"members": people.filter(func(p): return p.home == home).map(func(p): return p.npc_name),
			"date": "%s, %s" % [GameTime.weekday(t), GameTime.date_text(t)], "time": GameTime.clock_text(t).substr(0, 5),
			"saved_at": Time.get_datetime_string_from_system(false, true), "saved_unix": Time.get_unix_time_from_system(),
			"money": main.player.money},
		"world": {"clock": world.clock, "weather": world.weather, "weather_until": world.weather_until, "buildings": world.building_state(), "kitchens": world.kitchens, "guests": world.guests, "speed": main.speed,
			"controlled": main.player.npc_name, "household": main.household_name, "next_item_id": Kitchen.next_id, "log": log},
		"people": people, "objects": objects, "props": props,
	}


static func save(main: Node2D, slot: String) -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var f := FileAccess.open(path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_var(capture(main))
	return true


# A new slot name for a household: "Jo & Sam", "Jo & Sam 2"...
static func new_slot(household: String) -> String:
	var base := household.validate_filename().replace(" ", "_")
	if base == "":
		base = "save"
	var slot := base
	var n := 2
	while FileAccess.file_exists(path(slot)):
		slot = "%s_%d" % [base, n]
		n += 1
	return slot


# --- Reading ---

static func read(slot: String) -> Dictionary:
	if not FileAccess.file_exists(path(slot)):
		return {}
	var f := FileAccess.open(path(slot), FileAccess.READ)
	var data = f.get_var()
	return data if data is Dictionary and data.get("version", 0) == VERSION else {}


# Every save, newest first: [{slot, meta}].
static func list() -> Array:
	var saves := []
	var dir := DirAccess.open(DIR)
	if dir == null:
		return saves
	for file in dir.get_files():
		if file.ends_with(".save"):
			var slot := file.get_basename()
			var data := read(slot)
			if not data.is_empty():
				saves.append({"slot": slot, "meta": data.meta})
	saves.sort_custom(func(a, b): return a.meta.saved_unix > b.meta.saved_unix)
	return saves


static func latest() -> String:
	var saves := list()
	return saves[0].slot if not saves.is_empty() else ""


static func delete(slot: String) -> void:
	DirAccess.remove_absolute(path(slot))


# --- Restoring (main.gd calls this instead of placing the default people and furniture) ---

static func restore(main: Node2D, data: Dictionary) -> Node2D:
	var world: Node2D = main.world
	world.clock = data.world.clock
	world.day = GameTime.day_index(world.now())
	world.kitchens = data.world.kitchens
	world.guests = data.world.guests
	world.weather = data.world.get("weather", "Clear")
	world.weather_until = data.world.get("weather_until", 0.0)
	world.apply_building_state(data.world.get("buildings", []))  # built stairs and upper floors, before what's on them
	main.household_name = data.world.household
	Kitchen.next_id = data.world.next_item_id
	for o in data.objects:
		make_object(world, o)
	for p in data.props:
		make_prop(world, p)
	var controlled: Node2D = null
	var by_name := {}
	for person in data.people:
		var c := make_person(main, person)
		by_name[c.npc_name] = c
		if c.npc_name == data.world.controlled:
			controlled = c
	Social.event_log.clear()
	for e in data.world.log:  # people who have died since are shown by name
		Social.event_log.append({"text": e[0], "a": by_name.get(e[1]), "b": by_name.get(e[2]), "a_name": e[1], "b_name": e[2]})
	main.speed = data.world.speed
	return controlled


static func make_object(world: Node2D, o: Dictionary) -> Node2D:
	var obj: Node2D = SmartObject.new().setup(o.name, o.pos, o.ads, o.duration, o.color, o.height)
	var extras: Dictionary = o.extras.duplicate()
	if extras.sprite == "":
		extras.erase("sprite")
	obj.with_extras(extras)
	obj.catalog_id = o.catalog_id
	obj.items = o.items
	obj.net_id = o.get("net_id", 0)  # older saves: a new one is given by add_object
	world.add_object(obj, o.building, o.floor)
	return obj


static func make_prop(world: Node2D, p: Dictionary) -> Node2D:
	var prop: Node2D = Prop.new().setup(p.sprite, p.cell, p.flat, p.get("wall", false))
	prop.catalog_id = p.catalog_id
	prop.rotation_index = p.rotation
	world.add_prop(prop, p.building, p.floor)
	return prop


static func make_person(main: Node2D, person: Dictionary) -> Node2D:
	var c: Node2D = Npc.new().setup(person.npc_name, person.grid_pos, person.body_color, person.home, [], {})
	for field in SAVE_FIELDS:
		c.set(field, person[field])
	main.add_child(c)
	return c
