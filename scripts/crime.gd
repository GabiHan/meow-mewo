# Crime: burglars and the police. One node, world.crime (made by world.gd). Full documentation: docs/CRIME.md.
#
# Now and then a burglar comes for a house (at night while everyone sleeps, or by day while nobody's home; your
# household's home 1 time in 2). He walks up from the street, picks the door lock, goes in, takes the household's
# money and up to MAX_ITEMS of the most valuable carryable things (Catalog `carry`), and runs off down the street.
# He's an npc.gd person with role "burglar" (police officers: role "police"); this node moves them.
#
# Protection (build mode, "Security"): a porch light (lit at night: he skips the house), a reinforced lock (slow
# to pick, he may give up), an alarm (rings when he opens the door: wakes everyone, calls the police) and a phone
# (needed to call the police).
#
# Someone inside who sees him (perception) picks a reaction: you choose in a popup (Manual mode), everyone else
# by rules (npc_reaction). What happens next is outcome(): an if/else on the situation, see docs/CRIME.md.
# Police arrive POLICE_MINUTES after the call and chase him: caught, everything goes back; he escapes, it's gone.
# Saving in the middle of a burglary ends it (abort): he vanishes and everything in his bag goes back.
#
# Abductions (same node, `kind` "abduction"): a kidnapper (role "kidnapper") takes one person, of any age but
# children most of all (STAGE_WEIGHT). By day someone outside with nobody (Teen or older) near them; at night someone
# asleep at home (he breaks in like a burglar: porch light, lock and alarm work the same). Witnesses react with the
# same popup and rules; abduction_outcome() decides. Caught by the police or scared off: they're safe. If he gets
# away they're missing (hidden, out of "characters", kept in `missing`): from the conditions (police called, a phone
# at home, their age) return_chance() says if they'll come home, after RETURN_DAYS; if not, after LOST_DAYS they're
# never found (Life.die: grief and a grave).
#
# Personality (morals.gd): a burglar may be a neighbour on the Criminal path (`identity`): they vanish while it
# happens, someone who knows them may recognise them, caught they go to jail (JAIL_DAYS away, a criminal record).
# You can break in too (`kind` "intruder", break_in_as): pick the lock, steal and search for cash, and the
# residents react to you with the same rules; the police chase you, caught you're arrested.
extends Node

const Social = preload("res://scripts/social.gd")
const Emotions = preload("res://scripts/emotions.gd")
const Ages = preload("res://scripts/ages.gd")
const Skills = preload("res://scripts/skills.gd")
const Body = preload("res://scripts/body.gd")
const Perception = preload("res://scripts/perception.gd")
const GameTime = preload("res://scripts/game_time.gd")
const Mind = preload("res://scripts/mind.gd")
const Catalog = preload("res://scripts/catalog.gd")
const Life = preload("res://scripts/life.gd")
const Looks = preload("res://scripts/looks.gd")
const Morals = preload("res://scripts/morals.gd")

const NIGHT_CHANCE := 0.1  # per game night, for the whole neighbourhood...
const DAY_CHANCE := 0.006  # ...and per game hour from 9 to 17 (an empty house): about once a game week in all
const NIGHT_HOURS := [0.5, 4.5]  # a night burglary starts between these hours
const YOUR_HOME_SHARE := 0.5  # how often the target is your household's home
const VIOLENT_CHANCE := 0.25
const STRENGTH := [3, 8]  # a burglar's strength (a witness' is Fitness ± traits)
const PICK_MINUTES := 8.0  # picking the door lock
const LOCK_SLOWER := 3.0  # ×, with a reinforced lock...
const LOCK_GIVE_UP := 0.6  # ...and the chance he gives up on it
const SEARCH_MINUTES := 6.0  # per thing taken
const MAX_ITEMS := 2
const STEAL_SHARE := 0.3  # of the household's money...
const STEAL_MAX := 500  # ...at most this much
const ESCAPE_DISTANCE := 30  # tiles down the street: he's gone
const CALL_SAFE := 4.0  # tiles: closer than this, a violent burglar gets to you before you finish a call or a shout
const CHOICE_SECONDS := 30.0  # online the popup doesn't pause: after this (sim seconds) you hide
const HIDE_MINUTES := 30.0
const POLICE_MINUTES := 15.0  # from the call to the police at the door...
const ALARM_FASTER := 0.5  # ×, when the alarm called them
const ALARM_FLEE := 0.7  # a violent burglar still runs at the alarm this often (the others always do)
const CATCH_REACH := 1.5  # tiles
const POLICE_STAY_MINUTES := 20.0  # officers look around this long before they drive off
const BURGLAR_SPEED := 2.0
const POLICE_SPEED := 2.6
const DARK_CLOTHES := [12, 36]  # Looks.CLOTHES indices
const POLICE_BLUE := 18
const REACTIONS := ["Call", "Hide", "Fight", "Shout"]
# Abductions
const OUT_CHANCE := 0.015  # per game hour from OUT_HOURS, when someone is outside alone
const OUT_HOURS := [7.0, 21.0]
const ABDUCT_NIGHT_CHANCE := 0.03  # per game night (when no burglar came): a kidnapper takes someone asleep
const ALONE_RADIUS := 10.0  # tiles: outside, nobody else awake (Teen or older) this close
const STAGE_WEIGHT := [6.0, 6.0, 5.0, 3.0, 1.0, 1.0, 1.0]  # Ages stage -> how likely he picks them
const GRAB_REACH := 1.5  # tiles
const STALK_MINUTES := 90.0  # he gives up if he can't reach them in this long
const RETURN_BASE := 0.4  # chance a missing person comes home...
const RETURN_POLICE := 0.3  # ...+ the police were called while it happened
const RETURN_PHONE := 0.15  # ...+ a phone at home (the family reports it at once)
const RETURN_GROWN := 0.1  # ...+ Teen or older (they may get away by themselves)
const RETURN_MAX := 0.9
const RETURN_DAYS := [1.0, 10.0]  # they come home after this many game days
const LOST_DAYS := 21.0  # the others are never found: after this many days the family stops waiting
# Criminals (morals.gd)
const RECOGNISE_CHANCE := 0.6  # someone who knows the neighbour behind the mask recognises them
const JAIL_DAYS := 2.0
const FINE := 300  # $ for a burglar who's caught (on top of giving everything back)
const STEALTH_FASTER := 0.06  # × lock-picking time per Stealth level (you, breaking in)

var world: Node2D
var burglar: Node2D = null
var b := -1  # the house
var phase := ""  # approach, picking, to_item, taking, leaving
var timer := 0.0  # game minutes left in picking / taking
var violent := false
var strength := 5
var gives_up := false
var item: Node2D = null  # what he's taking now
var targets := []  # what he still means to take
var bag := {"money": {}, "items": []}  # money: npc_name -> $, items: [{id, cell, rot, floor, building, name}]
var escape_cell := Vector2i.ZERO
var confronted := false  # someone already reacted (others who see him are just scared)
var exposed := false  # someone saw him: the label shows "Burglar"
var witnesses := {}  # npc_name -> true
var alarm_rang := false
var police_called := false
var police_at := -1.0  # game time the police get here
var police := []  # officers
var police_car: Node2D = null
var police_until := -1.0  # game time the officers leave
var chase_timer := 0.0
var choosing: Node2D = null  # you, while the popup is open
var choice_deadline := 0.0
var paused_for_choice := false
var next_night := -1  # game day of the last night roll
var next_hour := -1  # game hour index of the last day roll
var last_result := ""  # for tests: the last outcome applied
var enabled := true  # random burglaries (scripted tests turn them off and call start())
var kind := "burglary"  # or "abduction" (then `burglar` is the kidnapper)
var victim: Node2D = null  # the person he came for (abduction)
var holding := false  # he has them
var stalk_timer := 0.0
var missing := []  # [{person, since, back_at (-1: never), lost_at, seen, jail}]: hidden people (see header)
var identity: Node2D = null  # the neighbour behind the burglar's mask (Criminal path), or null: a stranger
var entered := false  # you (an intruder) got inside
var searching := 0.0  # game minutes left searching for cash (intruder)
var fenced := 0  # $ you got for what you stole (intruder)


func _process(delta: float) -> void:
	if world == null or world.puppet or world.player == null:
		return
	var minutes := delta * GameTime.MINUTES_PER_SECOND
	roll()
	if choosing and world.clock >= choice_deadline:
		choose(choosing, "Hide")  # online: nobody answered in time
	if burglar and kind == "intruder":
		intruder_update(minutes)
	elif burglar:
		burglar_update(minutes)
	police_update(minutes)
	missing_update()


# --- When and where ---

func roll() -> void:
	if not enabled or burglar or not police.is_empty() or world.day < 1:
		return
	var t: float = world.now()
	var hour := fmod(t / 3600.0, 24.0)
	var day := int(t / 86400.0)
	if day != next_night and hour >= NIGHT_HOURS[0] and hour < NIGHT_HOURS[1]:
		next_night = day
		if randf() < NIGHT_CHANCE:
			var target := pick_target(true)
			if target >= 0:
				start(target)
		elif randf() < ABDUCT_NIGHT_CHANCE:
			var target := pick_target(true)
			if target >= 0:
				abduct(pick_victim(residents(target).filter(func(c): return c.building == target)))
		return
	var h := int(t / 3600.0)
	if h == next_hour:
		return
	next_hour = h
	if hour >= 9.0 and hour < 17.0 and randf() < DAY_CHANCE:
		var target := pick_target(false)
		if target >= 0:
			start(target)
	elif hour >= OUT_HOURS[0] and hour < OUT_HOURS[1] and randf() < OUT_CHANCE:
		abduct(pick_victim(outside_alone()))


func residents(i: int) -> Array:
	return get_tree().get_nodes_in_group("characters").filter(func(c): return c.role == "" and c.home == i and not c.dead)


# A house to burgle: at night one where everyone's asleep and no porch light is on; by day one where nobody's home.
func pick_target(night: bool) -> int:
	var options := []
	for i in world.BUILDINGS.size():
		var people := residents(i)
		if people.is_empty() or world.BUILDINGS[i].get("porch_light", false) and night:
			continue
		var home_now := people.filter(func(c): return c.building == i and not c.at_work)
		if night and home_now.any(func(c): return Perception.is_awake(c)):
			continue
		if not night and not home_now.is_empty():
			continue
		options.append(i)
	if options.is_empty():
		return -1
	var yours: int = world.player.home
	if yours in options and (options.size() == 1 or randf() < YOUR_HOME_SHARE):
		return yours
	options.erase(yours)
	return options.pick_random()


static func has(world_node: Node2D, i: int, object_name: String) -> bool:
	return world_node.get_tree().get_nodes_in_group("smart_objects").any(func(o): return o.building == i and o.object_name == object_name)


# --- The burglar ---

# Send a burglar to house i. opts: violent, strength (tests and the F7 key). False if one is already about.
func start(i: int, opts := {}) -> bool:
	if burglar or not police.is_empty() or i < 0:
		return false
	reset_state()
	b = i
	violent = opts.get("violent", randf() < VIOLENT_CHANCE)
	strength = opts.get("strength", randi_range(STRENGTH[0], STRENGTH[1]))
	var who: Node2D = opts.get("identity", null) if opts.has("identity") else pick_criminal(i)
	if not arrive("Burglar", "burglar", world.door_outside(i), 0, [ESCAPE_DISTANCE, ESCAPE_DISTANCE / 2]):
		return false
	if who:  # a neighbour on the Criminal path: they're "out" meanwhile, he wears their face
		identity = who
		burglar.sex = who.sex
		var look: Dictionary = who.look.duplicate()
		for part in ["top_color", "bottom_color", "shoes_color"]:
			if look.has(part):
				look[part] = burglar.look[part]
		burglar.look = look
		strength = maxi(strength, int(Morals.fight_strength(who)))
		who.pose = ""
		who.cancel_current()
		hide_person(who)
	phase = "approach"
	print("A burglar is on his way to %s%s" % [world.BUILDINGS[i].name, " (it's %s)" % who.npc_name if who else ""])
	return true


# A neighbour on the Criminal path who could be the burglar (not from that house or yours).
func pick_criminal(i: int) -> Node2D:
	var options := get_tree().get_nodes_in_group("characters").filter(func(c): return c.role == "" and c.home != i \
		and (world.player == null or c.home != world.player.home) and not c.controlled and can_take(c) and Morals.is_criminal(c))
	return options.pick_random() if not options.is_empty() else null


# He appears down the street (`distances` tiles away along x or y, either way) and walks to `target`. False if no
# spot can reach it.
func arrive(p_name: String, p_role: String, target: Vector2i, f: int, distances: Array) -> bool:
	var side := 1 if randf() < 0.5 else -1
	burglar = person(p_name, p_role, target, DARK_CLOTHES.pick_random(), BURGLAR_SPEED)
	burglar.activity = "Sneaking around"
	for d in distances:
		for s in [side, -side]:
			for along in [Vector2i(1, 0), Vector2i(0, 1)]:
				var spot: Vector2i = world.random_walkable_near(target + along * s * d, 0, 4)
				burglar.grid_pos = Vector2(spot)
				if burglar.walk_to(target, f):
					escape_cell = spot
					return true
	despawn(burglar)
	burglar = null
	return false


func reset_state() -> void:
	b = -1
	phase = ""
	item = null
	targets = []
	bag = {"money": {}, "items": []}
	confronted = false
	exposed = false
	witnesses = {}
	alarm_rang = false
	police_called = false
	police_at = -1.0
	choosing = null
	last_result = ""
	kind = "burglary"
	victim = null
	holding = false
	identity = null
	entered = false
	searching = 0.0
	fenced = 0


func person(p_name: String, p_role: String, at: Vector2i, clothes: int, p_speed: float) -> Node2D:
	var c: Node2D = load("res://scripts/npc.gd").new().setup(p_name, Vector2(at), Color(0.3, 0.3, 0.35), -1, [], {"Fitness": 3})
	c.role = p_role
	c.sex = "M"
	c.age_days = Ages.days_for_years(32.0)
	c.speed = p_speed
	var look := Looks.random_for("M")
	look.top = maxi(look.top, 1)
	look.bottom = maxi(look.bottom, 1)
	look.dress = 0
	for part in ["top_color", "bottom_color", "shoes_color"]:
		look[part] = clothes
	c.look = look
	get_tree().get_first_node_in_group("game").add_child(c)
	return c


func despawn(c: Node2D) -> void:
	if not is_instance_valid(c):
		return
	c.dead = true
	c.visible = false
	c.remove_from_group("characters")
	if b >= 0:
		world.uninvite(b, c)
	c.queue_free()


func noun() -> String:
	return "kidnapper" if kind == "abduction" else "burglar"


func burglar_update(minutes: float) -> void:
	var c := burglar
	match phase:
		"approach":
			if c.state == "idle":
				phase = "picking"
				var lock: bool = world.BUILDINGS[b].get("lock", false)
				timer = PICK_MINUTES * (LOCK_SLOWER if lock else 1.0)
				gives_up = lock and randf() < LOCK_GIVE_UP
				c.activity = "Picking the lock"
		"picking":
			timer -= minutes
			if timer <= 0.0:
				if gives_up:
					log_house("A %s tried the lock at {a}'s home and gave up" % noun())
					leave(false)
				else:
					break_in()
		"to_item":
			if not is_instance_valid(item) or not item.is_in_group("smart_objects"):
				next_item()
			elif c.state == "idle":
				phase = "taking"
				timer = SEARCH_MINUTES
				c.activity = "Searching"
		"taking":
			timer -= minutes
			if timer <= 0.0:
				take_money()
				if is_instance_valid(item) and item.is_in_group("smart_objects") and item.user == null:
					steal(item)
				next_item()
		"to_victim":
			stalk(minutes)
		"leaving":
			if c.state == "idle":
				if c.cell().distance_to(escape_cell) <= 2.0 or not c.walk_to(escape_cell, 0):
					escaped()
				else:
					c.running = true


func break_in() -> void:
	world.invite(b, burglar, 6.0)
	log_house("A %s broke into {a}'s home" % noun())
	if has(world, b, "Alarm"):
		ring_alarm()
		if not violent or randf() < ALARM_FLEE:
			leave(true)
			return
	if kind == "abduction":
		go_for_victim()
		return
	targets = loot_in(b)
	next_item()


# The most valuable carryable things in house i, MAX_ITEMS of them.
func loot_in(i: int) -> Array:
	var things := get_tree().get_nodes_in_group("smart_objects").filter(func(o):
		var id := Catalog.id_of(o)
		return o.building == i and id != "" and Catalog.ITEMS[id].get("carry", false))
	things.sort_custom(func(x, y): return Catalog.ITEMS[Catalog.id_of(x)].price > Catalog.ITEMS[Catalog.id_of(y)].price)
	return things.slice(0, MAX_ITEMS)


func next_item() -> void:
	while not targets.is_empty():
		item = targets.pop_front()
		if is_instance_valid(item) and item.user == null and burglar.walk_to(item.use_cell(), item.floor):
			burglar.activity = "Looking for valuables"
			phase = "to_item"
			return
	item = null
	take_money()
	leave(false)


func take_money() -> void:
	if not bag.money.is_empty():
		return
	var grown := residents(b).filter(func(c): return Ages.is_grown_up(c) and c.money > 0)
	var total := 0
	for c in grown:
		total += c.money
	var want := mini(int(total * STEAL_SHARE), STEAL_MAX)
	for c in grown:
		var share := int(want * float(c.money) / maxf(total, 1.0))
		c.money -= share
		bag.money[c.npc_name] = share


func steal(obj: Node2D) -> void:
	var id := Catalog.id_of(obj)
	bag.items.append({"id": id, "cell": Vector2i(obj.grid_pos), "rot": obj.facing, "floor": obj.floor, "building": obj.building,
		"name": Catalog.ITEMS[id].name})
	world.solid.get(obj.floor, {}).erase(Vector2i(obj.grid_pos))
	obj.remove_from_group("smart_objects")
	obj.queue_free()
	burglar.carrying_loot = true


func loot_text() -> String:
	var parts := []
	var money := money_taken()
	if money > 0:
		parts.append("$%d" % money)
	for it in bag.items:
		parts.append("the " + it.name.to_lower())
	return " and ".join(parts) if not parts.is_empty() else "nothing"


func money_taken() -> int:
	var total := 0
	for n in bag.money:
		total += bag.money[n]
	return total


# Everything in his bag goes back (caught, beaten, or the game is saved).
func give_back() -> void:
	for c in residents(b):
		c.money += bag.money.get(c.npc_name, 0)
	for it in bag.items:
		var node: Node2D = Catalog.make_object(it.id, it.cell, it.rot)
		world.add_object(node, it.building, it.floor)
	bag = {"money": {}, "items": []}
	if burglar:
		burglar.carrying_loot = false


func leave(run: bool) -> void:
	if burglar == null:
		return
	phase = "leaving"
	item = null
	burglar.cancel_current()
	burglar.activity = "Running off" if run else "Sneaking off"
	if not burglar.walk_to(escape_cell, 0):
		escaped()
		return
	burglar.running = run


func escaped() -> void:
	if kind == "abduction" and holding:
		disappear(victim)
	elif money_taken() > 0 or not bag.items.is_empty():
		log_house("The burglar got away from {a}'s home with " + loot_text())
		for c in residents(b):
			Emotions.add(c, "Burgled")
	if identity:  # back home as if nothing happened, richer
		for it in bag.items:
			identity.money += int(Catalog.ITEMS[it.id].price / 2)
		identity.money += money_taken()
		Morals.after_crime(identity)
		unmask()
	despawn(burglar)
	burglar = null
	bag = {"money": {}, "items": []}
	if not police.is_empty():
		for o in police:
			o.show_emote("\"He got away.\"", null)


func caught() -> void:
	if burglar == null:
		return
	if kind == "intruder":
		arrest_intruder()
		return
	if kind == "abduction":
		if holding:
			var v := victim
			release(v)
			Social.log_event("The police caught the kidnapper: {a} is safe", v, v)
			for o in close_to(v):
				Emotions.add(o, "Relieved")
		else:
			log_house("The police caught the kidnapper near {a}'s home")
	else:
		log_house("The police caught the burglar at {a}'s home")
		give_back()
		for c in residents(b):
			Emotions.add(c, "Relieved")
		if identity:
			var people := residents(b)
			Social.log_event("The burglar was {a}!", identity, people[0] if not people.is_empty() else identity)
			var who := identity
			unmask()
			jail(who)
	police[0].show_emote("\"You're under arrest!\"", null)
	despawn(burglar)
	burglar = null
	police_until = world.now() + 5.0 * 60.0
	for o in police:
		o.cancel_current()


# --- Being seen (npc.gd notice → here) ---

func spotted(witness: Node2D, c: Node2D) -> void:
	if c != burglar or witness.role != "" or witnesses.has(witness.npc_name) or witness == victim:
		return
	if kind == "abduction":
		spotted_kidnapper(witness, c)
		return
	if kind == "intruder":
		spotted_intruder(witness, c)
		return
	witnesses[witness.npc_name] = true
	if identity and witness.known.has(identity.npc_name) and randf() < RECOGNISE_CHANCE:
		recognise(witness, identity)
	exposed = true
	if witness.building != b or phase in ["approach", "leaving"] or confronted:
		Emotions.add(witness, "Scared")
		return
	confronted = true
	Social.log_event("{a} caught a burglar in the house", witness, witness)
	if witness.controlled and not witness.auto_mode and Ages.stage(witness) >= Ages.CHILD:
		ask(witness)
	else:
		choose(witness, npc_reaction(witness, witness.grid_pos.distance_to(c.grid_pos), phone_here(witness)))


# A phone where the witness is (outside nobody has one at hand).
func phone_here(witness: Node2D) -> bool:
	return witness.building >= 0 and has(world, witness.building, "Phone")


# How someone who isn't you reacts. Never reckless: close to him you hide, unless you're Hot-headed.
static func npc_reaction(c: Node2D, distance: float, phone: bool) -> String:
	if Ages.stage(c) < Ages.TEEN:
		return "Hide"
	if "Hot-headed" in c.traits or "Brave" in c.traits:
		return "Fight"
	if "Psychopath" in c.traits:  # no fear at all
		return "Call" if phone else "Fight"
	if distance <= CALL_SAFE:
		return "Hide"
	if phone:
		return "Call"
	if "Loner" in c.traits or "Anxious" in Mind.states(c):
		return "Hide"
	return "Shout"


# You saw him: you choose (the game pauses offline; online you have CHOICE_SECONDS).
func ask(you: Node2D) -> void:
	var game := get_tree().get_first_node_in_group("game")
	var ctl: Node = game.controller_of(you)
	if ctl == null:
		choose(you, npc_reaction(you, you.grid_pos.distance_to(burglar.grid_pos), phone_here(you)))
		return
	choosing = you
	choice_deadline = world.clock + CHOICE_SECONDS
	var grown: bool = Ages.stage(you) >= Ages.TEEN
	var phone := phone_here(you)
	var title := "There's a burglar in the house!"
	if kind == "intruder":
		title = "%s is breaking in!" % Social.display_name(you, burglar)
	elif kind == "abduction":
		title = "A stranger is taking %s!" % Social.display_name(you, victim) if holding else "There's a stranger in the house!"
	ctl.show_menu([title], [
		{"label": "Call the police" if phone else "Call the police (no phone)", "disabled": not phone or not grown, "action": choose.bind(you, "Call")},
		{"label": "Hide", "action": choose.bind(you, "Hide")},
		{"label": "Fight him", "disabled": not grown, "action": choose.bind(you, "Fight")},
		{"label": "Shout", "action": choose.bind(you, "Shout")},
	])
	if not game.is_online() and not game.paused:
		game.toggle_pause()
		paused_for_choice = true


func choose(witness: Node2D, reaction: String) -> void:
	if choosing == witness:
		choosing = null
		if paused_for_choice:
			paused_for_choice = false
			var game := get_tree().get_first_node_in_group("game")
			if game.paused:
				game.toggle_pause()
	if burglar == null or witness.dead:
		return
	resolve(witness, reaction)


# Is the house still quiet (nobody else awake, no alarm, no police called)?
func quiet(witness: Node2D) -> bool:
	if alarm_rang or police_called:
		return false
	return not get_tree().get_nodes_in_group("characters").any(func(c): return c != witness and c.role == "" \
		and c.building == b and Perception.is_awake(c) and Ages.stage(c) >= Ages.TEEN)


func fight_strength(c: Node2D) -> float:
	return Morals.fight_strength(c)


# The heart of it: what happens, from the situation. s: reaction, violent, close, fight_win, quiet, alarm.
# Returns {result, police}: result is steal_and_flee, flee, beaten, knocked, kill_and_steal or kill_and_flee.
static func outcome(s: Dictionary) -> Dictionary:
	var police: bool = s.get("alarm", false)
	match s.reaction:
		"Hide":
			return {"result": "steal_and_flee", "police": police}
		"Call":
			if s.violent and s.close:
				return attack(s, police)  # he gets to you before you finish the call
			return {"result": "flee", "police": true}
		"Shout":
			if s.violent and s.close:
				return attack(s.merged({"quiet": false}, true), police)  # everyone's awake now
			return {"result": "flee", "police": police}
		"Fight":
			if s.fight_win:
				return {"result": "beaten", "police": police}
			return attack(s, police)
	return {"result": "steal_and_flee", "police": police}


static func attack(s: Dictionary, police: bool) -> Dictionary:
	if s.violent:
		return {"result": "kill_and_steal" if s.quiet else "kill_and_flee", "police": police}
	return {"result": "knocked", "police": police}


func resolve(witness: Node2D, reaction: String) -> void:
	if kind == "abduction":
		resolve_abduction(witness, reaction)
		return
	if kind == "intruder":
		resolve_intruder(witness, reaction)
		return
	var c := burglar
	var s := {"reaction": reaction, "violent": violent, "close": witness.grid_pos.distance_to(c.grid_pos) <= CALL_SAFE,
		"fight_win": fight_strength(witness) > strength, "quiet": quiet(witness), "alarm": alarm_rang}
	var r := outcome(s)
	last_result = r.result
	if witness.pose == "":
		witness.cancel_current()
	match reaction:
		"Call":
			witness.show_emote("\"Police? There's someone in my house!\"", null)
			witness.activity = "Calling the police"
		"Hide":
			witness.show_emote("*hides*", null)
			witness.activity = "Hiding"
			witness.think_delay = HIDE_MINUTES
			Emotions.add(witness, "Scared")
		"Shout":
			witness.show_emote("\"Get out of my house!\"", null)
			wake_house()
		"Fight":
			witness.show_emote("*jumps on the burglar*", null)
	if r.police:
		call_police(witness, false)
	match r.result:
		"flee":
			Emotions.add(witness, "Scared")
			leave(true)
		"beaten":
			Emotions.add(witness, "Brave")
			give_back()
			Social.log_event("{a} fought off a burglar", witness, witness)
			leave(true)
		"knocked":
			c.show_emote("*shoves {who} to the floor*", witness)
			Body.go_down(witness, "knocked out", "Hurt")
			Social.log_event("{a} was knocked down by a burglar", witness, witness)
			leave(true)
		"kill_and_steal", "kill_and_flee":
			kill(witness)
			if r.result == "kill_and_flee":
				leave(true)


func kill(witness: Node2D) -> void:
	burglar.show_emote("*attacks {who}*", witness)
	for other in get_tree().get_nodes_in_group("characters"):
		if other != witness and other.role == "" and other.building == witness.building and Perception.is_awake(other) \
				and (witness.building >= 0 or Perception.can_see(other, witness)):
			Emotions.add(other, "Traumatised")
	Life.die(witness, "was killed by a " + noun())


func wake_house() -> void:
	for c in get_tree().get_nodes_in_group("characters"):
		if c.role == "" and c.building == b and not Perception.is_awake(c):
			c.cancel_current()
			c.activity = "Woken up"
			Emotions.add(c, "Scared")


func ring_alarm() -> void:
	alarm_rang = true
	exposed = true
	log_house("The alarm went off at {a}'s home")
	for c in get_tree().get_nodes_in_group("characters"):
		if c.role == "" and c.building == b:
			c.show_emote("*the alarm is ringing!*", null)
	wake_house()
	call_police(null, true)


# --- The police ---

func call_police(by: Node2D, alarm: bool) -> void:
	if police_called:
		return
	police_called = true
	police_at = world.now() + POLICE_MINUTES * (ALARM_FASTER if alarm else 1.0) * 60.0
	if by:
		Social.log_event("{a} called the police", by, by)


func police_update(minutes: float) -> void:
	if police_at >= 0.0 and world.now() >= police_at:
		police_at = -1.0
		police_arrive()
	if police.is_empty():
		return
	police = police.filter(func(o): return is_instance_valid(o))
	if burglar:
		chase(minutes)
	elif police_until < 0.0:
		police_until = world.now() + POLICE_STAY_MINUTES * 60.0
	elif world.now() >= police_until:
		police_leave()


func police_arrive() -> void:
	var door: Vector2i = world.door_outside(b) if b >= 0 else burglar.cell() if burglar else world.player.cell()
	var stop := Vector2(door.x, world.traffic.road_centre(door.y) + 0.55)
	if absf(stop.y - door.y) > 12.0:
		stop = Vector2(door) + Vector2(0, 2)
	police_car = world.traffic.add_car("police", stop, Vector2(1, 0))
	police_car.place()
	for n in 2:
		var at: Vector2i = world.random_walkable_near(Vector2i(stop.round()) + Vector2i(n * 2 - 1, -1), 0, 3)
		var o := person("Officer %d" % (n + 1), "police", at, POLICE_BLUE, POLICE_SPEED)
		if b >= 0:
			world.invite(b, o, 6.0)
		police.append(o)
	police_until = -1.0
	if kind == "abduction" and victim:
		Social.log_event("The police came looking for {a}", victim, victim)
	else:
		log_house("The police came to {a}'s home")
	if burglar:
		police[0].show_emote("\"Police! Stop right there!\"", null)
		if phase != "leaving" and kind != "intruder":
			leave(true)
	else:
		police[0].show_emote("\"Looks like we're too late.\"", null)


func chase(minutes: float) -> void:
	chase_timer -= minutes
	for o in police:
		if o.grid_pos.distance_to(burglar.grid_pos) <= CATCH_REACH and o.floor == burglar.floor:
			caught()
			return
	if chase_timer > 0.0:
		return
	chase_timer = 1.0
	for o in police:
		if o.walk_to(burglar.cell(), burglar.floor):
			o.running = true
			o.activity = "Chasing the " + noun()


func police_leave() -> void:
	for o in police:
		if b >= 0:
			world.uninvite(b, o)
		despawn(o)
	police = []
	police_until = -1.0
	if is_instance_valid(police_car):
		world.traffic.cars.erase(police_car)
		police_car.queue_free()
	police_car = null


# --- Ending it ---

# Saving (or leaving) in the middle of a burglary: he and the police vanish, his bag goes back.
func abort() -> void:
	if burglar and kind == "intruder":
		end_intrusion()  # you got away with it
	if identity:
		unmask()
	if burglar and holding:
		release(victim)
	if burglar:
		give_back()
		despawn(burglar)
		burglar = null
	police_leave()
	if choosing:
		choose(choosing, "Hide")
	police_at = -1.0
	phase = ""


func active() -> bool:
	return burglar != null or not police.is_empty()


# A line in the events feed about house b ({a} = one of its residents, so your household sees it).
func log_house(text: String) -> void:
	var people := residents(b)
	var who: Node2D = people[0] if not people.is_empty() else null
	Social.log_event(text, who, who)


# --- Abductions ---

# Someone he could take: a resident (not you if nobody else in your household could carry on, never a joined
# player), not at work, not missing.
func can_take(c: Node2D) -> bool:
	if c == null or c.role != "" or c.dead or c.at_work or not c.is_in_group("characters"):
		return false
	if not c.controlled:
		return true
	var ctl: Node = get_tree().get_first_node_in_group("game").controller_of(c)
	if ctl == null or ctl.peer != 0:
		return false
	return ctl.household().any(func(o): return o != c and ctl.playable(o) and not o.controlled)


# People outside on their own: nobody else awake, Teen or older, within ALONE_RADIUS tiles.
func outside_alone() -> Array:
	var people: Array = get_tree().get_nodes_in_group("characters").filter(func(c): return c.role == "" and not c.dead)
	return people.filter(func(c): return c.building == -1 and c.floor == 0 and not c.at_work \
		and not people.any(func(o): return o != c and not o.at_work and o.floor == 0 and Ages.stage(o) >= Ages.TEEN \
			and Perception.is_awake(o) and o.grid_pos.distance_to(c.grid_pos) <= ALONE_RADIUS))


# One of `people`, children most likely (STAGE_WEIGHT); from your household 1 time in 2 when there's one.
func pick_victim(people: Array) -> Node2D:
	people = people.filter(can_take)
	var yours := people.filter(func(c): return world.player and c.home == world.player.home)
	if not yours.is_empty() and (yours.size() == people.size() or randf() < YOUR_HOME_SHARE):
		people = yours
	elif not yours.is_empty():
		people = people.filter(func(c): return not c in yours)
	var total := 0.0
	for c in people:
		total += STAGE_WEIGHT[Ages.stage(c)]
	var r := randf() * total
	for c in people:
		r -= STAGE_WEIGHT[Ages.stage(c)]
		if r <= 0.0:
			return c
	return null


# Send a kidnapper for `v` (tests and F8 call this directly). opts: violent, strength. At home he breaks in; outside
# he walks up to them. False if he can't (someone's already about, they can't be taken, no way to them).
func abduct(v: Node2D, opts := {}) -> bool:
	if active() or not can_take(v):
		return false
	reset_state()
	kind = "abduction"
	victim = v
	violent = opts.get("violent", randf() < VIOLENT_CHANCE)
	strength = opts.get("strength", randi_range(STRENGTH[0], STRENGTH[1]))
	if v.building >= 0:  # at home: through the door like a burglar
		b = v.building
		if not arrive("Kidnapper", "kidnapper", world.door_outside(b), 0, [ESCAPE_DISTANCE, ESCAPE_DISTANCE / 2]):
			reset_state()
			return false
		phase = "approach"
	else:
		b = v.home
		if not arrive("Kidnapper", "kidnapper", v.cell(), v.floor, [ESCAPE_DISTANCE / 2, 8]):
			reset_state()
			return false
		phase = "to_victim"
		stalk_timer = STALK_MINUTES
	print("A kidnapper is after %s" % v.npc_name)
	return true


func go_for_victim() -> void:
	phase = "to_victim"
	stalk_timer = STALK_MINUTES
	timer = 0.0
	burglar.activity = "Sneaking around"


func stalk(minutes: float) -> void:
	var c := burglar
	var v := victim
	stalk_timer -= minutes
	if not is_instance_valid(v) or v.dead or v.at_work or not v.is_in_group("characters") or stalk_timer <= 0.0:
		leave(false)  # they're gone (or he gave up)
		return
	if v.floor == c.floor and v.grid_pos.distance_to(c.grid_pos) <= GRAB_REACH:
		grab()
		return
	timer -= minutes
	if timer > 0.0 and c.state == "walking":
		return
	timer = 1.0  # they move: follow them
	if not c.walk_to(v.cell(), v.floor):
		c.walk_to(world.free_neighbor(v.cell(), v.floor, c.cell()), v.floor)


# He reaches them. Teens and grown-ups may break free (fight_strength); the others are taken.
func grab() -> void:
	var v := victim
	burglar.cancel_current()
	if Ages.stage(v) >= Ages.TEEN and Perception.is_awake(v) and fight_strength(v) > strength:
		last_result = "broke_free"
		exposed = true
		v.show_emote("*breaks free*", null)
		Emotions.add(v, "Scared")
		Social.log_event("{a} broke free from a kidnapper", v, v)
		leave(true)
		return
	burglar.show_emote("*grabs {who}*", v)
	take(v)
	leave(false)


# They're in his hands: hidden and out of everything (like at work), until released or gone.
func take(v: Node2D) -> void:
	v.pose = ""
	v.cancel_current()
	if v.controlled:  # you carry on as someone else in your household (can_take checked there is one)
		var ctl: Node = get_tree().get_first_node_in_group("game").controller_of(v)
		if ctl:
			ctl.on_death(v)
	hide_person(v)
	holding = true
	burglar.carrying_person = true
	burglar.activity = "Carrying someone off"


func hide_person(v: Node2D) -> void:
	v.remove_from_group("characters")
	v.visible = false
	v.set_process(false)
	v.state = "idle"
	v.path = []


# Back in the world at `at` (floor f): scared, but safe.
func show_person(v: Node2D, at: Vector2i, f: int) -> void:
	v.floor = f
	v.grid_pos = Vector2(world.random_walkable_near(at, f, 1))
	v.building = world.building_at(v.cell(), f)
	v.add_to_group("characters")  # update_view() shows them when you can see them
	v.set_process(true)
	v.state = "idle"
	v.activity = "Idle"
	v.think_delay = 0.0


func release(v: Node2D) -> void:
	holding = false
	if burglar:
		burglar.carrying_person = false
	if not is_instance_valid(v):
		return
	show_person(v, burglar.cell() if burglar else world.door_outside(v.home), burglar.floor if burglar else 0)
	Emotions.add(v, "Scared")
	v.show_emote("*runs to safety*", null)


# His family and partner (they worry, then are relieved / grieve).
func close_to(v: Node2D) -> Array:
	return get_tree().get_nodes_in_group("characters").filter(func(o): return o != v and o.role == "" \
		and (o.home == v.home and v.home >= 0 or Ages.family(o, v) or o.lover == v.npc_name))


func spotted_kidnapper(witness: Node2D, c: Node2D) -> void:
	var inside: bool = b >= 0 and c.building == b and phase not in ["approach", "picking"]
	if not holding and not inside:
		return  # just a stranger walking by, for now
	witnesses[witness.npc_name] = true
	exposed = true
	if confronted:
		Emotions.add(witness, "Scared")
		return
	confronted = true
	if holding:
		Social.log_event("{a} saw a stranger carrying someone off", witness, witness)
	else:
		Social.log_event("{a} caught a stranger in the house", witness, witness)
	if witness.controlled and not witness.auto_mode and Ages.stage(witness) >= Ages.CHILD:
		ask(witness)
	else:
		choose(witness, npc_reaction(witness, witness.grid_pos.distance_to(c.grid_pos), phone_here(witness)))


# What a witness' reaction leads to. s: reaction, violent, close, fight_win, holding.
# Returns {result, police}: result is taken (he goes on / gets away with them), freed (they're safe: he drops them or
# runs off empty-handed), knocked_taken or killed_taken (the witness is hurt or killed, he goes on).
static func abduction_outcome(s: Dictionary) -> Dictionary:
	match s.reaction:
		"Call":
			if s.violent and s.close:
				return abduction_attack(s)
			return {"result": "taken" if s.holding else "freed", "police": true}  # he runs, with them if he has them
		"Shout":
			if s.violent and s.close:
				return abduction_attack(s)
			return {"result": "freed", "police": false}  # he panics, drops them and runs
		"Fight":
			if s.fight_win:
				return {"result": "freed", "police": false}
			return abduction_attack(s)
	return {"result": "taken", "police": false}  # Hide


static func abduction_attack(s: Dictionary) -> Dictionary:
	return {"result": "killed_taken" if s.violent else "knocked_taken", "police": false}


func resolve_abduction(witness: Node2D, reaction: String) -> void:
	var c := burglar
	var s := {"reaction": reaction, "violent": violent, "close": witness.grid_pos.distance_to(c.grid_pos) <= CALL_SAFE,
		"fight_win": fight_strength(witness) > strength, "holding": holding}
	var r := abduction_outcome(s)
	last_result = r.result
	if witness.pose == "":
		witness.cancel_current()
	match reaction:
		"Call":
			witness.show_emote("\"Police? Someone's being taken!\"", null)
			witness.activity = "Calling the police"
		"Hide":
			witness.show_emote("*hides*", null)
			witness.activity = "Hiding"
			witness.think_delay = HIDE_MINUTES
			Emotions.add(witness, "Scared")
		"Shout":
			witness.show_emote("\"Help! Let them go!\"", null)
			if witness.building >= 0:
				wake_house()
		"Fight":
			witness.show_emote("*jumps on the stranger*", null)
	if r.police:
		call_police(witness, false)
	match r.result:
		"freed":
			if holding:
				var v := victim
				release(v)
				Social.log_event("{a} was saved from a kidnapper", v, v)
			Emotions.add(witness, "Brave" if reaction == "Fight" else "Scared")
			leave(true)
		"taken":
			if holding or reaction == "Call":
				leave(true)
		"knocked_taken":
			c.show_emote("*shoves {who} to the floor*", witness)
			Body.go_down(witness, "knocked out", "Hurt")
			Social.log_event("{a} was knocked down by a kidnapper", witness, witness)
			if holding:
				leave(true)
		"killed_taken":
			kill(witness)
			if holding:
				leave(true)


# How likely a missing person is to come home, from what happened.
static func return_chance(stage: int, police_called_then: bool, phone_at_home: bool) -> float:
	var p := RETURN_BASE
	if police_called_then:
		p += RETURN_POLICE
	if phone_at_home:
		p += RETURN_PHONE
	if stage >= Ages.TEEN:
		p += RETURN_GROWN
	return minf(p, RETURN_MAX)


# He got away with them: they're missing. Whether they'll come back is settled now (return_chance).
func disappear(v: Node2D) -> void:
	holding = false
	if burglar:
		burglar.carrying_person = false
	var now: float = world.now()
	var phone: bool = v.home >= 0 and has(world, v.home, "Phone")
	var back := randf() < return_chance(Ages.stage(v), police_called, phone)
	missing.append({"person": v, "since": now, "back_at": now + randf_range(RETURN_DAYS[0], RETURN_DAYS[1]) * 86400.0 if back else -1.0,
		"lost_at": now + LOST_DAYS * 86400.0, "seen": exposed})
	Social.log_event("{a} was taken by a kidnapper" if exposed else "{a} has gone missing", v, v)
	for o in close_to(v):
		Emotions.add(o, "Worried sick")
		Social.remember(o, v, "went missing", -1.0)


func is_missing(v: Node2D) -> bool:
	return missing.any(func(m): return m.person == v)


func missing_update() -> void:
	if missing.is_empty():
		return
	var now: float = world.now()
	for m in missing.duplicate():
		if not is_instance_valid(m.person):
			missing.erase(m)
		elif m.back_at >= 0.0 and now >= m.back_at:
			come_back(m)
		elif m.back_at < 0.0 and now >= m.lost_at:
			never_found(m)


# Found by the police, or got away: home again after `days`, older, hungry and shaken.
func come_back(m: Dictionary) -> void:
	missing.erase(m)
	var v: Node2D = m.person
	var days: float = (world.now() - m.since) / 86400.0
	v.age_days += days * Life.AGING_SPEED
	show_person(v, world.door_outside(v.home) + Vector2i(0, 1) if v.home >= 0 else v.home_cell, 0)
	for need in v.needs:
		v.needs[need] = minf(v.needs[need], 35.0)
	if m.get("jail", false):
		Social.log_event("{a} came home from jail", v, v)
		return
	Emotions.add(v, "Traumatised")
	v.show_emote("\"I'm home...\"", null)
	Social.log_event("{a} came home after %d days missing" % maxi(1, roundi(days)), v, v)
	for o in close_to(v):
		stop_worrying(o)
		Emotions.add(o, "Reunited")


# Never found: the family stops waiting. Grief and a grave, as for a death.
func never_found(m: Dictionary) -> void:
	missing.erase(m)
	var v: Node2D = m.person
	for o in close_to(v):
		stop_worrying(o)
	Life.die(v, "was never found")


# Worried sick only while someone close to them is still missing.
func stop_worrying(o: Node2D) -> void:
	if not missing.any(func(m): return is_instance_valid(m.person) and not m.get("jail", false) and (m.person.home == o.home and o.home >= 0 \
			or Ages.family(o, m.person) or o.lover == m.person.npc_name)):
		Emotions.set_condition(o, "Worried sick", false)


# Saving: missing people are kept apart from "people" (save_game.gd).
func capture_missing() -> Array:
	var SaveGame: GDScript = load("res://scripts/save_game.gd")
	return missing.filter(func(m): return is_instance_valid(m.person)).map(func(m): return {
		"person": SaveGame.capture_person(m.person), "since": m.since, "back_at": m.back_at, "lost_at": m.lost_at, "seen": m.seen, "jail": m.get("jail", false)})


func restore_missing(main: Node2D, rows: Array) -> void:
	var SaveGame: GDScript = load("res://scripts/save_game.gd")
	missing = []
	for row in rows:
		var v: Node2D = SaveGame.make_person(main, row.person)
		hide_person(v)
		missing.append({"person": v, "since": row.since, "back_at": row.back_at, "lost_at": row.lost_at, "seen": row.seen,
			"jail": row.get("jail", false)})



# --- Criminals: the neighbour behind the mask, jail, and you breaking in (morals.gd) ---

func recognise(witness: Node2D, who: Node2D) -> void:
	Social.log_event("{a} recognised the burglar: it was {b}!", witness, who)
	Social.change_friendship(witness, who, -50.0)
	Social.remember(witness, who, "broke into our home", -8.0)


# The neighbour comes back from "out" (at their home door).
func unmask() -> void:
	var who := identity
	identity = null
	if is_instance_valid(who) and not who.is_in_group("characters") and not is_missing(who):
		show_person(who, world.door_outside(who.home) + Vector2i(0, 1) if who.home >= 0 else who.home_cell, 0)


# Arrested: a criminal record, and JAIL_DAYS away (missing list, `jail`). If it's you, you carry on as someone else in
# your household; with nobody else, no jail, only the record and the shame.
func jail(c: Node2D) -> void:
	c.record += 1
	Emotions.add(c, "Arrested")
	if not can_take(c):
		Social.log_event("{a} was let off with a fine", c, c)
		return
	c.pose = ""
	c.cancel_current()
	if c.controlled:
		var ctl: Node = get_tree().get_first_node_in_group("game").controller_of(c)
		if ctl:
			ctl.on_death(c)
	hide_person(c)
	var now: float = world.now()
	missing.append({"person": c, "since": now, "back_at": now + JAIL_DAYS * 86400.0, "lost_at": INF, "seen": true, "jail": true})
	Social.log_event("{a} went to jail for %d days" % int(JAIL_DAYS), c, c)


func intruder() -> Node2D:
	return burglar if kind == "intruder" else null


func can_break_in(c: Node2D, i: int) -> bool:
	return i >= 0 and c.role == "" and Ages.stage(c) >= Ages.TEEN and i != c.home and not world.can_enter(c, i) and not active()


# You (or anyone controlled) go and break into house i.
func break_in_as(c: Node2D, i: int) -> bool:
	if not can_break_in(c, i):
		return false
	reset_state()
	kind = "intruder"
	b = i
	burglar = c
	escape_cell = world.door_outside(i)
	c.cancel_current()
	if not c.walk_to(escape_cell, 0):
		reset_state()
		burglar = null
		return false
	c.activity = "Sneaking up to " + world.BUILDINGS[i].name
	phase = "approach"
	return true


func intruder_update(minutes: float) -> void:
	var c := burglar
	if not is_instance_valid(c) or c.dead or not c.is_in_group("characters"):
		end_intrusion()
		return
	var door: Vector2i = world.door_outside(b)
	match phase:
		"approach":
			if c.state == "walking":
				return
			if c.cell().distance_to(door) > 1.5:
				end_intrusion()  # changed your mind
				return
			phase = "picking"
			var lock: bool = world.BUILDINGS[b].get("lock", false)
			var stealth := Skills.level(c, "Stealth")
			timer = PICK_MINUTES * (LOCK_SLOWER if lock else 1.0) * maxf(0.4, 1.0 - STEALTH_FASTER * stealth)
			gives_up = lock and randf() < LOCK_GIVE_UP * maxf(0.2, 1.0 - 0.08 * stealth)
			c.activity = "Picking the lock"
		"picking":
			if c.state != "idle" or c.cell().distance_to(door) > 1.5:
				end_intrusion()
				return
			timer -= minutes
			c.practice("Stealth", minutes)
			if timer > 0.0:
				return
			if gives_up:
				c.show_emote("*the lock won't give*", null)
				end_intrusion()
				return
			world.invite(b, c, 3.0)
			phase = "inside"
			Social.log_event("{a} broke into %s" % world.BUILDINGS[b].name, c, c)
			c.activity = "Inside: click things to steal them"
			if has(world, b, "Alarm"):
				ring_alarm()
		"inside":
			if c.building == b:
				entered = true
			if police_called and (c.cell().distance_to(door) > ESCAPE_DISTANCE or (c.home >= 0 and c.building == c.home)):
				end_intrusion()  # got away from the police
				return
			if entered and c.building != b and not police_called and c.floor == 0:
				end_intrusion()  # out again, and nobody called anyone
				return
			if c.state != "idle" or c.pose != "":
				return
			if is_instance_valid(item) and item.is_in_group("smart_objects"):
				if c.cell().distance_to(item.use_cell()) <= 1.5:
					timer -= minutes
					c.activity = "Stealing the " + Catalog.ITEMS[Catalog.id_of(item)].name.to_lower()
					if timer <= 0.0:
						steal_for(c, item)
						item = null
			elif searching > 0.0:
				searching -= minutes
				c.activity = "Searching for cash"
				if searching <= 0.0:
					take_money()
					c.money += money_taken()
					c.practice("Stealth", 10.0)
					c.activity = "Found $%d" % money_taken()


# The object menu (controller.gd) while you're inside: steal this, search for cash.
func steal_entries(c: Node2D, obj: Node2D) -> Array:
	if intruder() != c or phase != "inside" or obj.building != b:
		return []
	var entries := [{"section": "Burglary"}]
	var id := Catalog.id_of(obj)
	if id != "" and Catalog.ITEMS[id].get("carry", false):
		entries.append({"label": "Steal the %s (fence it for $%d)" % [Catalog.ITEMS[id].name.to_lower(), Catalog.ITEMS[id].price / 2],
			"action": order_steal.bind(obj)})
	entries.append({"label": "Search for cash", "disabled": not bag.money.is_empty(), "action": order_search})
	return entries


func order_steal(obj: Node2D) -> void:
	var c := burglar
	if c == null or not is_instance_valid(obj):
		return
	c.cancel_current()
	item = obj
	timer = SEARCH_MINUTES
	if not c.walk_to(obj.use_cell(), obj.floor):
		c.walk_to(world.free_neighbor(Vector2i(obj.grid_pos), obj.floor, c.cell()), obj.floor)


func order_search() -> void:
	if burglar == null:
		return
	burglar.cancel_current()
	item = null
	searching = SEARCH_MINUTES


func steal_for(c: Node2D, obj: Node2D) -> void:
	var price: int = Catalog.ITEMS[Catalog.id_of(obj)].price
	steal(obj)
	c.money += price / 2
	fenced += price / 2
	c.practice("Stealth", 10.0)


# Seen by someone inside: they react to you with the same rules as to a burglar.
func spotted_intruder(witness: Node2D, c: Node2D) -> void:
	if witness == c or witness.building != b or not phase in ["picking", "inside"]:
		return
	witnesses[witness.npc_name] = true
	exposed = true
	if witness.known.has(c.npc_name):
		Social.change_friendship(witness, c, -50.0)
		Social.remember(witness, c, "broke into our home", -8.0)
	if confronted:
		Emotions.add(witness, "Scared")
		return
	confronted = true
	Social.log_event("{a} caught {b} breaking in", witness, c)
	if witness.controlled and not witness.auto_mode and Ages.stage(witness) >= Ages.CHILD:
		ask(witness)
	else:
		choose(witness, npc_reaction(witness, witness.grid_pos.distance_to(c.grid_pos), phone_here(witness)))


# Pure: what a resident's reaction to you means. s: reaction, fight_win (they beat you), phone (in the house).
static func intruder_outcome(s: Dictionary) -> Dictionary:
	match s.reaction:
		"Call":
			return {"result": "seen", "police": true}
		"Shout":
			return {"result": "seen", "police": s.phone}  # the house wakes up and someone calls
		"Fight":
			return {"result": "you_down" if s.fight_win else "they_down", "police": s.phone}
	return {"result": "unseen", "police": false}


func resolve_intruder(witness: Node2D, reaction: String) -> void:
	var c := burglar
	var s := {"reaction": reaction, "fight_win": fight_strength(witness) > fight_strength(c), "phone": has(world, b, "Phone")}
	var r := intruder_outcome(s)
	last_result = r.result
	if witness.pose == "":
		witness.cancel_current()
	match reaction:
		"Call":
			witness.show_emote("\"Police? Someone's breaking in!\"", null)
			witness.activity = "Calling the police"
		"Hide":
			witness.show_emote("*hides*", null)
			witness.activity = "Hiding"
			witness.think_delay = HIDE_MINUTES
			Emotions.add(witness, "Scared")
		"Shout":
			witness.show_emote("\"Get out of my house!\"", null)
			wake_house()
		"Fight":
			witness.show_emote("*jumps on {who}*", c)
	if r.police:
		call_police(witness, false)
	match r.result:
		"you_down":
			Body.go_down(c, "knocked out", "Hurt")
			Social.log_event("{a} knocked {b} down", witness, c)
			Emotions.add(witness, "Brave")
		"they_down":
			Body.go_down(witness, "knocked out", "Hurt")
			Social.log_event("{a} knocked {b} down", c, witness)


# You're done (out of the house, gave up, or got away from the police).
func end_intrusion() -> void:
	var c := burglar
	var took: bool = money_taken() > 0 or not bag.items.is_empty()
	if took:
		log_house("Someone broke into {a}'s home and took " + loot_text())
		for r in residents(b):
			Emotions.add(r, "Burgled")
		if is_instance_valid(c):
			Social.log_event("{a} got away with " + loot_text(), c, c)
	if is_instance_valid(c):
		if took or entered:
			Morals.after_crime(c)
		c.carrying_loot = false
		world.uninvite(b, c)
		if c.state != "walking" and c.pose == "":
			c.activity = "Idle"
	if not police.is_empty() and police_called:
		for o in police:
			o.show_emote("\"They got away.\"", null)
	burglar = null
	bag = {"money": {}, "items": []}
	kind = "burglary"
	phase = ""
	item = null
	searching = 0.0


func arrest_intruder() -> void:
	var c := burglar
	police[0].show_emote("\"You're under arrest!\"", null)
	c.money = maxi(0, c.money - fenced - money_taken())  # the money from it goes back...
	give_back()  # ...with everything taken
	var fine := mini(c.money, FINE)
	c.money -= fine
	var people := residents(b)
	Social.log_event("The police caught {b} breaking into {a}'s home", people[0] if not people.is_empty() else c, c)
	Social.log_event("{a} was arrested (fine $%d)" % fine, c, c)
	c.carrying_loot = false
	world.uninvite(b, c)
	burglar = null
	kind = "burglary"
	phase = ""
	police_until = world.now() + 5.0 * 60.0
	for o in police:
		o.cancel_current()
	jail(c)
