# Life: ageing, growing up, pregnancy and births. Static. Full documentation: docs/LIFE.md.
#
# Every new game day everyone gets AGING_SPEED days older (world.gd calls new_day). Crossing into a
# new stage: a "Birthday" moodlet, a log line, and school changes (Jobs.school_for_stage).
#
# Babies: the "Try for a baby" interaction (social.gd) between close friends (friendship 70+) who are a
# fertile woman (Young adult or Adult, not Old) and a man (Young adult or older, Old too), at home.
# BABY_CHANCE per try. Pregnancy lasts PREGNANCY_DAYS; then the baby is born in the mother's home.
const Ages = preload("res://scripts/ages.gd")
const Social = preload("res://scripts/social.gd")
const Emotions = preload("res://scripts/emotions.gd")
const Traits = preload("res://scripts/traits.gd")
const Jobs = preload("res://scripts/jobs.gd")

const AGING_SPEED := 1.0  # game days of age per game day. Short lifespan: 2.0. Off: 0.0
const PREGNANCY_DAYS := 3.0
const BABY_CHANCE := 0.4
const HOUSEMATE_FRIENDSHIP := 15.0
const FAMILY_FRIENDSHIP := 50.0  # parents and their new baby start this close
const BABY_NAMES := {"F": ["Lily", "Emma", "Zoe", "Nina", "Ava", "Chloe", "Maya", "Rose"],
	"M": ["Leo", "Max", "Theo", "Eli", "Owen", "Finn", "Hugo", "Jude"]}
const DEATH_YEARS := [78.0, 96.0]  # everyone's natural lifespan is somewhere in this range
const GRIEF_FRIENDSHIP := 20.0  # friends this close feel "Lost someone"; family and partners grieve
const BABY_COLORS := [Color(0.95, 0.75, 0.4), Color(0.5, 0.75, 0.95), Color(0.85, 0.55, 0.8), Color(0.55, 0.85, 0.6)]


# At the start: parents and children (and siblings) know and love each other; housemates know each other.
# `only`: just pairs with one of these people (a household that moved in later, online).
static func setup_families(node: Node, only := []) -> void:
	var people: Array = node.get_tree().get_nodes_in_group("characters")
	for a in people:
		for b in people:
			if not only.is_empty() and not (a in only or b in only):
				continue
			if a != b and Ages.family(a, b):
				a.known[b.npc_name] = true
				Social.change_friendship(a, b, FAMILY_FRIENDSHIP if (a.npc_name in b.parents or b.npc_name in a.parents) else 30.0)
			elif a != b and a.home >= 0 and a.home == b.home:  # housemates know each other
				a.known[b.npc_name] = true
				Social.change_friendship(a, b, HOUSEMATE_FRIENDSHIP)


static func new_day(world: Node2D) -> void:
	for c in world.get_tree().get_nodes_in_group("characters"):
		var before := Ages.stage(c)
		c.age_days += AGING_SPEED
		if Ages.stage(c) != before:
			grew_up(c)
		if Ages.stage(c) == Ages.OLD and Ages.years(c) >= c.death_years:
			die(c)


# --- Death ---

# Passing away of old age: the people who loved them grieve, partners are widowed, a gravestone
# appears outside their home. If it's you, the game is over (hud.gd shows it).
static func die(c: Node2D) -> void:
	var age := int(Ages.years(c))
	Social.log_event("{a} passed away at %d" % age, c, c)
	if c.partner:
		c.end_social()
	c.drop_task()
	for other in c.get_tree().get_nodes_in_group("characters"):
		if other == c:
			continue
		var close: bool = Ages.family(c, other) or other.lover == c.npc_name
		if close:
			Emotions.add(other, "Grieving")
		elif Social.friendship(other, c) >= GRIEF_FRIENDSHIP:
			Emotions.add(other, "Lost someone")
		if other.lover == c.npc_name:
			other.lover = ""
			other.lover_status = ""
		Social.remember(other, c, "passed away", 0.0)
	c.dead = true
	c.visible = false
	c.remove_from_group("characters")
	if c.controlled:  # no game over: you carry on as someone else in your household
		var ctl: Node = c.get_tree().get_first_node_in_group("game").controller_of(c)
		if ctl:
			ctl.on_death(c)
	c.set_process(false)
	var spot: Vector2i = c.world.random_walkable_near(c.world.door_outside(c.home) + Vector2i(2, 2) if c.home >= 0 else c.cell(), 0, 3)
	var grave: Node2D = load("res://scripts/smart_object.gd").new().setup("Grave of " + c.npc_name, Vector2(spot), {}, 0.0,
		Color(0.55, 0.55, 0.6), 22)
	c.world.add_object(grave, -1, 0)


static func grew_up(c: Node2D) -> void:
	Emotions.add(c, "Birthday")
	var stage := Ages.stage_name(c)
	var article := "an" if stage[0] in "AEIOU" else "a"
	c.show_emote("Happy birthday! Now %s %s" % [article, stage], null)
	Social.log_event("{a} grew up into %s %s" % [article, stage], c, c)
	var allowed: Array = c.traits.duplicate()
	if Ages.stage(c) in [Ages.CHILD, Ages.TEEN] and c.traits.size() < 3:  # personality fills in as they grow
		var options := Traits.TRAITS.keys().filter(func(t): return not t in allowed)
		c.traits.append(options.pick_random())
	Jobs.school_for_stage(c)


# --- Babies ---

static func can_have_baby(a: Node2D, b: Node2D) -> bool:
	if a.sex == b.sex or not Ages.fertile(a) or not Ages.fertile(b) or Ages.family(a, b):
		return false
	var mother: Node2D = a if a.sex == "F" else b
	return mother.pregnant_until < 0.0


static func try_for_baby(a: Node2D, b: Node2D) -> bool:
	if not can_have_baby(a, b) or randf() >= BABY_CHANCE:
		return false
	var mother: Node2D = a if a.sex == "F" else b
	var father: Node2D = b if mother == a else a
	mother.pregnant_until = mother.world.now() + PREGNANCY_DAYS * 86400.0
	mother.baby_father = father.npc_name
	Emotions.add(mother, "Expecting")
	Emotions.add(father, "Expecting")
	Social.log_event("{a} and {b} are expecting a baby!", mother, father)
	return true


# Called every frame for a pregnant character.
static func check_birth(mother: Node2D) -> void:
	if mother.pregnant_until < 0.0 or mother.world.now() < mother.pregnant_until:
		return
	mother.pregnant_until = -1.0
	var sex: String = ["F", "M"].pick_random()
	var taken := mother.get_tree().get_nodes_in_group("characters").map(func(c): return c.npc_name)
	var names: Array = BABY_NAMES[sex].filter(func(n): return not n in taken)
	var baby_name: String = names.pick_random() if not names.is_empty() else "Baby %d" % taken.size()
	var spot: Vector2i = mother.home_cell if mother.home >= 0 else mother.cell()
	spot = mother.world.random_walkable_near(spot, 0, 2)
	var baby: Node2D = load("res://scripts/npc.gd").new().setup(baby_name, Vector2(spot), BABY_COLORS.pick_random(),
		mother.home, [Traits.TRAITS.keys().pick_random()], {})
	baby.sex = sex
	baby.age_days = 0.0
	baby.parents = [mother.npc_name, mother.baby_father]
	baby.look = load("res://scripts/looks.gd").random_for(sex)
	baby.death_years = randf_range(DEATH_YEARS[0], DEATH_YEARS[1])
	mother.get_parent().add_child(baby)
	for parent in mother.get_tree().get_nodes_in_group("characters"):
		if parent.npc_name in baby.parents:
			Social.change_friendship(parent, baby, FAMILY_FRIENDSHIP)
			Social.change_friendship(baby, parent, FAMILY_FRIENDSHIP)
			parent.known[baby.npc_name] = true
			baby.known[parent.npc_name] = true
			Emotions.add(parent, "New baby")
	Social.log_event("{a} had a baby: {b}!", mother, baby)
