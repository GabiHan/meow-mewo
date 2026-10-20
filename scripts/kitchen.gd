# Kitchen: recipes, drinks, plates and cups, leftovers that spoil. Static like social.gd.
# Full documentation: docs/KITCHEN.md (keep it in sync with the tables below).
#
# A kitchen is the Fridge, Counter, Stove, Sink and Table of one building, plus that building's clean
# plates and cups (world.kitchens[building]). Everything is done as a list of steps that a character
# runs one after another (npc.gd run_steps): walk to the step's object, spend `seconds` there, gain
# `ads` gradually, then call `done`. Items being carried are in the character's `held`.
#
#   Cook:     Fridge "Getting ingredients" -> Counter/Stove "Making X" -> Table "Eating X" -> Sink "Washing the plate"
#   Drink:    source "Pouring X" -> same place "Drinking X" -> Sink "Washing the cup"
#   Leftover: Counter/Table "Picking up X" -> Table "Eating X" -> Sink "Washing the plate"
#
# A step's `start` gets the step itself (to set verb/seconds/ads when it begins, e.g. by freshness);
# lambdas never capture their own step, which would be a reference cycle (memory leak).
#
# Items (in `held`, or in a Counter/Table's `items`):
#   {"id", "kind": "food", "recipe", "made": world.now(), "quality"}   a plate of food (made: game seconds)
#   {"id", "kind": "drink", "drink"}                        a full cup
#   {"id", "kind": "dirty", "dish": "plate" | "cup"}        needs washing at the Sink
const Skills = preload("res://scripts/skills.gd")
const Emotions = preload("res://scripts/emotions.gd")
const Ages = preload("res://scripts/ages.gd")

const RECIPES := {
	"Sandwich": {"cost": 5, "min_cooking": 0, "station": "Counter", "seconds": 4.0, "servings": 1, "eat_seconds": 4.0, "spoil_hours": 8.0,
		"ads": {"hunger": 40}, "color": Color(0.9, 0.75, 0.45)},
	"Salad": {"cost": 6, "min_cooking": 0, "station": "Counter", "seconds": 5.0, "servings": 1, "eat_seconds": 4.0, "spoil_hours": 6.0,
		"ads": {"hunger": 30, "thirst": 5, "fun": 5}, "color": Color(0.45, 0.8, 0.35)},
	"Omelette": {"cost": 4, "min_cooking": 1, "station": "Stove", "seconds": 7.0, "servings": 1, "eat_seconds": 5.0, "spoil_hours": 6.0,
		"ads": {"hunger": 50}, "color": Color(0.98, 0.85, 0.3)},
	"Pasta": {"cost": 8, "min_cooking": 2, "station": "Stove", "seconds": 10.0, "servings": 2, "eat_seconds": 6.0, "spoil_hours": 12.0,
		"ads": {"hunger": 65, "fun": 5}, "color": Color(0.95, 0.6, 0.3)},
	"Soup": {"cost": 10, "min_cooking": 4, "station": "Stove", "seconds": 12.0, "servings": 3, "eat_seconds": 5.0, "spoil_hours": 24.0,
		"ads": {"hunger": 45, "thirst": 10}, "color": Color(0.85, 0.45, 0.3)},
}

const DRINKS := {
	"Water": {"cost": 0, "source": "Sink", "seconds": 2.0, "drink_seconds": 3.0, "ads": {"thirst": 40, "bladder": -10}},
	"Juice": {"cost": 2, "source": "Fridge", "seconds": 2.0, "drink_seconds": 3.0, "ads": {"thirst": 50, "hunger": 5, "bladder": -10}},
	"Milk": {"cost": 2, "source": "Fridge", "seconds": 2.0, "drink_seconds": 3.0, "ads": {"thirst": 40, "hunger": 10, "bladder": -10}},
	"Soda": {"cost": 2, "source": "Fridge", "seconds": 2.0, "drink_seconds": 3.0, "ads": {"thirst": 35, "fun": 10, "bladder": -15}},
	"Coffee": {"cost": 1, "source": "Counter", "seconds": 5.0, "drink_seconds": 4.0, "ads": {"thirst": 20, "energy": 20, "bladder": -15}},
}

# Cooking skill (skills.gd): recipes need `min_cooking`, cooking practises the skill, and the cook's
# level decides the quality of every serving (Skills.cooking_quality).
# quality: hunger × multiplier, and a moodlet when eaten (emotions.gd).
const QUALITY := {
	"Burnt": {"hunger": 0.5, "moodlet": "Burnt food"},
	"Good": {"hunger": 1.0, "moodlet": ""},
	"Delicious": {"hunger": 1.25, "moodlet": "Delicious meal"},
}

# Money (jobs.gd): `cost` is paid when getting the ingredients / pouring. You can't start what you
# can't afford (menus show it greyed out; the AI skips it). Leftovers are free.
const PLATES := 4  # clean plates each kitchen starts with
const CUPS := 4
const FETCH_SECONDS := 2.0  # getting ingredients from the fridge
const PICK_UP_SECONDS := 1.0
const WASH_SECONDS := {"plate": 3.0, "cup": 2.0}
const KITCHEN_OBJECTS := ["Fridge", "Counter", "Stove", "Sink", "Table"]

# Freshness (game time): Fresh while more than half the spoil time is left, then Stale, then Spoiled at 0.
# What eating it does, on top of the recipe's ads (hunger is multiplied, the rest is added):
const FRESHNESS := {
	"Fresh": {"hunger": 1.0, "fun": 0, "bladder": 0},
	"Stale": {"hunger": 0.7, "fun": -5, "bladder": 0},
	"Spoiled": {"hunger": 0.3, "fun": -15, "bladder": -20},  # stomach ache
}

static var next_id := 0
static var meals_eaten := 0  # counters for tests
static var drinks_drunk := 0


# --- Lookups ---

static func find(node: Node, b: int, object_name: String) -> Node2D:
	for o in node.get_tree().get_nodes_in_group("smart_objects"):
		if o.building == b and o.object_name == object_name:
			return o
	return null


static func dishes(world: Node2D, b: int) -> Dictionary:
	return world.kitchens.get_or_add(b, {"plate": PLATES, "cup": CUPS})


static func new_item(fields: Dictionary) -> Dictionary:
	next_id += 1
	fields.id = next_id
	return fields


# Game seconds until it spoils (negative once spoiled). `now` is world.now().
static func time_left(item: Dictionary, now: float) -> float:
	return RECIPES[item.recipe].spoil_hours * 3600.0 - (now - item.made)


static func freshness(item: Dictionary, now: float) -> String:
	var left := time_left(item, now)
	if left <= 0.0:
		return "Spoiled"
	return "Fresh" if left > RECIPES[item.recipe].spoil_hours * 1800.0 else "Stale"


# What eating this plate gives right now.
static func eat_ads(item: Dictionary, now: float) -> Dictionary:
	var f: Dictionary = FRESHNESS[freshness(item, now)]
	var ads: Dictionary = RECIPES[item.recipe].ads.duplicate()
	ads.hunger = ads.hunger * f.hunger * QUALITY[item.get("quality", "Good")].hunger
	for need in ["fun", "bladder"]:
		if f[need] != 0:
			ads[need] = ads.get(need, 0) + f[need]
	return ads


static func item_text(item: Dictionary, now: float) -> String:
	match item.kind:
		"food":
			var left := time_left(item, now)
			if left <= 0.0:
				return "%s (spoiled)" % item.recipe
			var q: String = "" if item.get("quality", "Good") == "Good" else item.quality.to_lower() + ", "
			return "%s (%s%s, %dh %02dm left)" % [item.recipe, q, freshness(item, now).to_lower(), int(left) / 3600, int(left) / 60 % 60]
		"drink":
			return "Cup of " + item.drink.to_lower()
	return "Dirty " + item.dish


# [surface, item] for every item on the Counter/Table of building b.
static func items_in(node: Node, b: int) -> Array:
	var result := []
	for o in node.get_tree().get_nodes_in_group("smart_objects"):
		if o.building == b:
			for item in o.items:
				result.append([o, item])
	return result


# --- Step lists ---

static func cook_steps(c: Node2D, b: int, recipe: String) -> Array:
	var r: Dictionary = RECIPES[recipe]
	var fridge := find(c, b, "Fridge")
	var station := find(c, b, r.station)
	if fridge == null or station == null or find(c, b, "Table") == null or find(c, b, "Sink") == null:
		return []
	return [
		{"object": fridge, "verb": "Getting ingredients", "seconds": FETCH_SECONDS, "done": func(): pay(c, r.cost)},
		{"object": station, "verb": "Making " + recipe.to_lower(), "seconds": r.seconds, "skill": "Cooking",
			"done": func(): cooked(c, b, recipe, station)},
	] + eat_and_wash_steps(c, b)


static func eat_and_wash_steps(c: Node2D, b: int) -> Array:
	var eat := {"object": find(c, b, "Table"), "verb": "Eating", "seconds": 5.0}
	eat.start = func(s: Dictionary):  # the plate's freshness when you sit down decides what it's worth
		if c.held.get("kind") == "food":
			s.verb = "Eating " + c.held.recipe.to_lower()
			s.seconds = RECIPES[c.held.recipe].eat_seconds
			s.ads = eat_ads(c.held, c.world.now())
		else:
			s.seconds = 0.0
	eat.done = func():
		if c.held.get("kind") == "food":
			meals_eaten += 1
			var moodlet: String = QUALITY[c.held.get("quality", "Good")].moodlet
			var fresh := freshness(c.held, c.world.now())
			if fresh == "Spoiled":
				moodlet = "Stomach ache"
			load("res://scripts/body.gd").ate(c, fresh)  # stale or spoiled food can mean food poisoning
			if moodlet != "":
				Emotions.add(c, moodlet)
			c.held = new_item({"kind": "dirty", "dish": "plate"})
	return [eat, wash_step(c, b)]


static func drink_steps(c: Node2D, b: int, drink: String) -> Array:
	var d: Dictionary = DRINKS[drink]
	var source := find(c, b, d.source)
	if source == null or find(c, b, "Sink") == null:
		return []
	var verb := "Making coffee" if drink == "Coffee" else "Pouring " + drink.to_lower()
	var pour := func():
		if pay(c, d.cost):
			take_dish(c, b, "cup", {"kind": "drink", "drink": drink})
	var finished := func():
		drinks_drunk += 1
		if drink == "Coffee":
			Emotions.add(c, "Caffeinated")
		c.held = new_item({"kind": "dirty", "dish": "cup"})
	return [
		{"object": source, "verb": verb, "seconds": d.seconds, "done": pour},
		{"object": source, "verb": "Drinking " + drink.to_lower(), "seconds": d.drink_seconds, "ads": d.ads, "done": finished},
		wash_step(c, b),
	]


# Take an item off a Counter/Table, then do something with it.
static func pick_up_step(c: Node2D, surface: Node2D, item: Dictionary, verb: String) -> Dictionary:
	var take := func():
		var i: int = surface.items.find(item)
		if i < 0:
			c.steps.clear()  # someone else took it
			return
		surface.items.remove_at(i)
		c.held = item
	return {"object": surface, "verb": verb, "seconds": PICK_UP_SECONDS, "done": take}


static func leftover_steps(c: Node2D, surface: Node2D, item: Dictionary) -> Array:
	return [pick_up_step(c, surface, item, "Picking up the " + item.recipe.to_lower())] + eat_and_wash_steps(c, surface.building)


static func throw_away_steps(c: Node2D, surface: Node2D, item: Dictionary) -> Array:
	var step := pick_up_step(c, surface, item, "Throwing away the " + item.recipe.to_lower())
	var pick: Callable = step.done
	step.done = func():
		pick.call()
		if c.held.get("id") == item.id:
			c.held = new_item({"kind": "dirty", "dish": "plate"})
	return [step, wash_step(c, surface.building)]


# Wash every dirty dish in the kitchen, one trip to the sink each.
static func wash_all_steps(c: Node2D, b: int) -> Array:
	var steps := []
	for pair in items_in(c, b):
		if pair[1].kind == "dirty":
			steps.append(pick_up_step(c, pair[0], pair[1], "Picking up the dirty " + pair[1].dish))
			steps.append(wash_step(c, b))
	return steps


static func wash_step(c: Node2D, b: int) -> Dictionary:
	var step := {"object": find(c, b, "Sink"), "verb": "Washing up", "seconds": 0.0}
	step.start = func(s: Dictionary):
		if c.held.get("kind") == "dirty":
			s.verb = "Washing the " + c.held.dish
			s.seconds = WASH_SECONDS[c.held.dish]
	step.done = func():
		if c.held.get("kind") == "dirty":
			dishes(c.world, b)[c.held.dish] += 1
			c.held = {}
	return step


# Stove/Counter done: plate up. Extra servings go on the Counter as leftovers.
static func cooked(c: Node2D, b: int, recipe: String, station: Node2D) -> void:
	var k := dishes(c.world, b)
	var n: int = mini(RECIPES[recipe].servings, k.plate)
	if n == 0:
		c.show_emote("No clean plates!", null)
		c.steps.clear()
		return
	k.plate -= n
	var quality := Skills.cooking_quality(c)
	c.held = new_item({"kind": "food", "recipe": recipe, "made": c.world.now(), "quality": quality})
	if quality != "Good":
		c.show_emote("Burnt it!" if quality == "Burnt" else "This looks delicious!", null)
	var counter := find(c, b, "Counter")
	for i in n - 1:
		(counter if counter else station).items.append(new_item({"kind": "food", "recipe": recipe, "made": c.world.now(), "quality": quality}))


# Pay for ingredients; if you can't, the task stops here.
static func pay(c: Node2D, cost: int) -> bool:
	if c.money >= cost:
		c.money -= cost
		return true
	c.show_emote("I can't afford that!", null)
	c.steps.clear()
	return false


static func take_dish(c: Node2D, b: int, dish: String, item: Dictionary) -> void:
	var k := dishes(c.world, b)
	if k[dish] <= 0:
		c.show_emote("No clean %ss!" % dish, null)
		c.steps.clear()
		return
	k[dish] -= 1
	c.held = new_item(item)


# The task was interrupted: put whatever you're holding on the nearest Table/Counter of the
# building you're in (a dirty dish or food, so nothing is lost). Outside, dishes go straight back.
static func put_down(c: Node2D) -> void:
	if c.held.is_empty():
		return
	var best: Node2D = null
	for name in ["Table", "Counter"]:
		var s := find(c, c.building, name)
		if s and (best == null or c.grid_pos.distance_to(s.grid_pos) < c.grid_pos.distance_to(best.grid_pos)):
			best = s
	if best:
		if c.held.kind == "drink":  # a half-drunk cup becomes a dirty one
			c.held = new_item({"kind": "dirty", "dish": "cup"})
		best.items.append(c.held)
	elif c.held.kind != "food" and c.home >= 0:
		dishes(c.world, c.home)[c.held.get("dish", "cup")] += 1
	c.held = {}


# --- Choices ---

# Everything `c` could do in kitchen b, for the AI: [{name, ads, anchor, seconds, steps: Callable}].
# If there are no clean plates/cups but dirty ones, the option washes them first.
# Age limits: babies and toddlers don't use the kitchen (they're fed); children can't use the
# Stove or make Coffee.
static func allowed(c: Node2D, station: String) -> bool:
	var s := Ages.stage(c)
	return s > Ages.TODDLER and not (s == Ages.CHILD and station in ["Stove", "Coffee"])


static func options(c: Node2D, b: int) -> Array:
	var result := []
	if b < 0 or find(c, b, "Fridge") == null or Ages.stage(c) <= Ages.TODDLER:
		return result
	var k := dishes(c.world, b)
	var has_dirty := {"plate": false, "cup": false}
	for pair in items_in(c, b):
		if pair[1].kind == "dirty":
			has_dirty[pair[1].dish] = true
	for recipe in RECIPES:
		var r: Dictionary = RECIPES[recipe]
		if (k.plate > 0 or has_dirty.plate) and Skills.level(c, "Cooking") >= r.min_cooking and c.money >= r.cost \
				and allowed(c, r.station):
			result.append({"name": recipe, "ads": r.ads, "anchor": find(c, b, "Fridge"), "cooking": true,
				"seconds": FETCH_SECONDS + r.seconds + r.eat_seconds + WASH_SECONDS.plate,
				"steps": func(): return (wash_all_steps(c, b) if k.plate == 0 else []) + cook_steps(c, b, recipe)})
	for drink in DRINKS:
		var d: Dictionary = DRINKS[drink]
		if (k.cup > 0 or has_dirty.cup) and c.money >= d.cost and allowed(c, "Coffee" if drink == "Coffee" else d.source):
			result.append({"name": drink, "ads": d.ads, "anchor": find(c, b, d.source),
				"seconds": d.seconds + d.drink_seconds + WASH_SECONDS.cup,
				"steps": func(): return (wash_all_steps(c, b) if k.cup == 0 else []) + drink_steps(c, b, drink)})
	for pair in items_in(c, b):
		var item: Dictionary = pair[1]
		if item.kind == "food" and freshness(item, c.world.now()) != "Spoiled":  # nobody eats spoiled food on purpose
			result.append({"name": "leftover " + item.recipe, "ads": eat_ads(item, c.world.now()), "anchor": pair[0],
				"seconds": PICK_UP_SECONDS + RECIPES[item.recipe].eat_seconds + WASH_SECONDS.plate,
				"steps": func(): return leftover_steps(c, pair[0], item)})
	return result


# Menu entries for the player clicking a kitchen object: [{label, disabled?, action?}] or
# {"section": title}. `run` is called with the chosen step list.
static func menu(c: Node2D, obj: Node2D, run: Callable) -> Array:
	var b: int = obj.building
	var k := dishes(c.world, b)
	var entries := []
	if obj.object_name in ["Fridge", "Stove"]:
		entries.append({"section": "Cook (%d/%d clean plates)" % [k.plate, PLATES]})
		for recipe in RECIPES:
			var r: Dictionary = RECIPES[recipe]
			if obj.object_name == "Stove" and r.station != "Stove":
				continue
			var skilled: bool = Skills.level(c, "Cooking") >= r.min_cooking
			var why := "" if skilled else " (needs Cooking %d)" % r.min_cooking
			if not allowed(c, r.station):
				why = " (too young)"
				skilled = false
			if skilled and k.plate == 0:
				why = " (no clean plates)"
			elif skilled and c.money < r.cost:
				why = " (can't afford)"
			entries.append({"label": "%s — $%d, hunger +%d, %d serving%s%s" % [recipe, r.cost, r.ads.hunger, r.servings,
				"" if r.servings == 1 else "s", why],
				"disabled": why != "", "action": func(): run.call(cook_steps(c, b, recipe))})
	var drinks := DRINKS.keys().filter(func(d): return DRINKS[d].source == obj.object_name)
	if not drinks.is_empty():
		entries.append({"section": "Drink (%d/%d clean cups)" % [k.cup, CUPS]})
		for drink in drinks:
			var cost: int = DRINKS[drink].cost
			var why := " (no clean cups)" if k.cup == 0 else " (can't afford)" if c.money < cost else ""
			entries.append({"label": "%s — %s, thirst +%d%s" % [drink, "free" if cost == 0 else "$%d" % cost, DRINKS[drink].ads.thirst, why],
				"disabled": why != "", "action": func(): run.call(drink_steps(c, b, drink))})
	if obj.object_name in ["Counter", "Table"] and not obj.items.is_empty():
		entries.append({"section": "On the " + obj.object_name.to_lower()})
		for item in obj.items:
			var text := item_text(item, c.world.now())
			if item.kind == "food":
				entries.append({"label": "Eat " + text, "action": func(): run.call(leftover_steps(c, obj, item))})
				entries.append({"label": "Throw away " + text, "action": func(): run.call(throw_away_steps(c, obj, item))})
			elif item.kind == "dirty":
				var wash := [pick_up_step(c, obj, item, "Picking up the dirty " + item.dish), wash_step(c, b)]
				entries.append({"label": "Wash " + text.to_lower(), "action": func(): run.call(wash)})
	if obj.object_name == "Sink":
		var dirty := items_in(c, b).filter(func(p): return p[1].kind == "dirty").size()
		entries.append({"section": "Dishes"})
		entries.append({"label": "Wash all dirty dishes (%d)" % dirty, "disabled": dirty == 0,
			"action": func(): run.call(wash_all_steps(c, b))})
	return entries
