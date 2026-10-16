# Emotions, Sims-style. Static like social.gd. Full documentation: docs/PEOPLE.md.
#
# A moodlet is a feeling with a reason, e.g. "Argued" = Angry, strength 3, for 3 game hours.
# Character `moodlets`: [{name, emotion, strength, until (game seconds; INF = while a condition holds)}].
# The emotion with the highest total strength is how the character feels; with nothing at all
# they're "Fine". Total 5+ reads as "Very ...".
#
# Conditional moodlets come from needs (NEED_MOODLETS) and surroundings (e.g. "Messy home"); they're
# recalculated every look (update) and last as long as the condition holds.
const Traits = preload("res://scripts/traits.gd")

const VERY := 5.0

# name: {emotion, strength, hours (0 = conditional), removes? (emotions it cancels)}
const MOODLETS := {
	# Social (social.gd)
	"Good conversation": {"emotion": "Happy", "strength": 1, "hours": 3},
	"Had a laugh": {"emotion": "Playful", "strength": 2, "hours": 2},
	"Joke fell flat": {"emotion": "Embarrassed", "strength": 2, "hours": 2},
	"Complimented": {"emotion": "Confident", "strength": 2, "hours": 3},
	"Deep connection": {"emotion": "Happy", "strength": 2, "hours": 4},
	"Interesting discussion": {"emotion": "Focused", "strength": 2, "hours": 2},
	"Hugged": {"emotion": "Happy", "strength": 2, "hours": 3},
	"Comforted": {"emotion": "Happy", "strength": 2, "hours": 3, "removes": ["Sad"]},
	"Argued": {"emotion": "Angry", "strength": 3, "hours": 3},
	"Insulted": {"emotion": "Sad", "strength": 3, "hours": 4},
	"Rejected": {"emotion": "Embarrassed", "strength": 2, "hours": 2},
	# Everyday and children (social.gd)
	"Made up": {"emotion": "Happy", "strength": 1, "hours": 2},
	"Gossiped": {"emotion": "Playful", "strength": 1, "hours": 2},
	"Showed off": {"emotion": "Confident", "strength": 1, "hours": 2},
	"Vented": {"emotion": "Happy", "strength": 1, "hours": 2, "removes": ["Tense", "Angry"]},
	"Good advice": {"emotion": "Focused", "strength": 1, "hours": 2},
	"Teased": {"emotion": "Angry", "strength": 1, "hours": 2},
	"Pranked": {"emotion": "Angry", "strength": 2, "hours": 3},
	"Got a gift": {"emotion": "Happy", "strength": 2, "hours": 4},
	"Played together": {"emotion": "Playful", "strength": 2, "hours": 2},
	"Story time": {"emotion": "Happy", "strength": 1, "hours": 2},
	"Fed": {"emotion": "Happy", "strength": 1, "hours": 1},
	"Clean and dry": {"emotion": "Happy", "strength": 1, "hours": 1},
	# Romance (romance.gd)
	"Flirted": {"emotion": "Flirty", "strength": 2, "hours": 3},
	"Kissed": {"emotion": "Flirty", "strength": 3, "hours": 3},
	"Cuddled": {"emotion": "Happy", "strength": 2, "hours": 3},
	"In love": {"emotion": "Happy", "strength": 3, "hours": 24},
	"Engaged": {"emotion": "Happy", "strength": 3, "hours": 24},
	"Just married": {"emotion": "Happy", "strength": 4, "hours": 48},
	"Broke up": {"emotion": "Sad", "strength": 2, "hours": 24},
	"Heartbroken": {"emotion": "Sad", "strength": 4, "hours": 48},
	"Jealous": {"emotion": "Angry", "strength": 3, "hours": 6},
	"In a relationship": {"emotion": "Happy", "strength": 1, "hours": 0},
	# Mind (mind.gd): lasting states from how they've felt for days
	"Depressed": {"emotion": "Sad", "strength": 4, "hours": 0},
	"Anxious": {"emotion": "Tense", "strength": 3, "hours": 0},
	"Thriving": {"emotion": "Happy", "strength": 2, "hours": 0},
	"Isolated": {"emotion": "Sad", "strength": 2, "hours": 0},
	"Burned out": {"emotion": "Tense", "strength": 2, "hours": 0},
	"Supported": {"emotion": "Happy", "strength": 2, "hours": 12},
	# Death (life.gd)
	"Grieving": {"emotion": "Sad", "strength": 4, "hours": 72},
	"Lost someone": {"emotion": "Sad", "strength": 2, "hours": 48},
	# Babies (life.gd)
	"Crying": {"emotion": "Sad", "strength": 3, "hours": 0},
	"Baby crying": {"emotion": "Tense", "strength": 1, "hours": 1},
	# Perception (perception.gd)
	"Caught a peeper": {"emotion": "Angry", "strength": 3, "hours": 3},
	"Friend at the window": {"emotion": "Happy", "strength": 1, "hours": 1},
	"Got caught peeking": {"emotion": "Embarrassed", "strength": 3, "hours": 2},
	# Food and drink (kitchen.gd)
	"Delicious meal": {"emotion": "Happy", "strength": 2, "hours": 4},
	"Burnt food": {"emotion": "Uncomfortable", "strength": 1, "hours": 2},
	"Stomach ache": {"emotion": "Uncomfortable", "strength": 3, "hours": 4},
	"Caffeinated": {"emotion": "Energized", "strength": 2, "hours": 3},
	# Activities (objects' "moodlet" in main.gd OBJECTS)
	"Well rested": {"emotion": "Energized", "strength": 2, "hours": 4},
	"Freshened up": {"emotion": "Happy", "strength": 1, "hours": 2},
	"Pumped": {"emotion": "Energized", "strength": 2, "hours": 2},
	"Learned something": {"emotion": "Focused", "strength": 2, "hours": 2},
	"Skill level up": {"emotion": "Confident", "strength": 2, "hours": 4},
	# Work and money (jobs.gd)
	"Payday": {"emotion": "Happy", "strength": 1, "hours": 3},
	"Promoted": {"emotion": "Confident", "strength": 3, "hours": 8},
	"Missed work": {"emotion": "Tense", "strength": 2, "hours": 4},
	"Broke": {"emotion": "Tense", "strength": 2, "hours": 0},
	"Warned at work": {"emotion": "Tense", "strength": 2, "hours": 8},
	"Fired": {"emotion": "Sad", "strength": 3, "hours": 24},
	"Skipped school": {"emotion": "Tense", "strength": 1, "hours": 4},
	"Graduated": {"emotion": "Confident", "strength": 3, "hours": 24},
	# Life (life.gd)
	"Birthday": {"emotion": "Happy", "strength": 2, "hours": 8},
	"Expecting": {"emotion": "Happy", "strength": 2, "hours": 24},
	"Pregnant": {"emotion": "Uncomfortable", "strength": 1, "hours": 0},
	"New baby": {"emotion": "Happy", "strength": 3, "hours": 24},
	# Conditions (recalculated every look)
	"Hungry": {"emotion": "Uncomfortable", "strength": 2, "hours": 0},
	"Thirsty": {"emotion": "Uncomfortable", "strength": 2, "hours": 0},
	"Exhausted": {"emotion": "Tense", "strength": 3, "hours": 0},
	"Bursting": {"emotion": "Uncomfortable", "strength": 3, "hours": 0},
	"Smelly": {"emotion": "Embarrassed", "strength": 2, "hours": 0},
	"Bored": {"emotion": "Bored", "strength": 2, "hours": 0},
	"Lonely": {"emotion": "Sad", "strength": 2, "hours": 0},
	"Content": {"emotion": "Happy", "strength": 1, "hours": 0},
	"Messy home": {"emotion": "Uncomfortable", "strength": 1, "hours": 0},
}

# [need, below this value, moodlet]
const NEED_MOODLETS := [
	["hunger", 25.0, "Hungry"], ["thirst", 25.0, "Thirsty"], ["energy", 15.0, "Exhausted"],
	["bladder", 20.0, "Bursting"], ["hygiene", 20.0, "Smelly"], ["fun", 25.0, "Bored"], ["social", 25.0, "Lonely"],
]
const CONTENT_ABOVE := 70.0  # all needs above this: "Content"

# What each emotion does.
# accept:  added to the chance of saying yes to an interaction
# prefer:  {interaction: ×} which interactions they start
# needs:   {need: ×} how much they care about a need right now
# learns:  skill learned 1.5× faster while feeling this
const EFFECTS := {
	"Happy": {"accept": 0.1, "prefer": {"Invite over": 1.5}, "learns": "Cooking"},
	"Playful": {"accept": 0.1, "prefer": {"Tell a joke": 3.0, "Tease": 2.0, "Prank": 2.0, "High five": 2.0, "Play with": 2.0},
		"learns": "Comedy"},
	"Confident": {"accept": 0.05, "prefer": {"Compliment": 2.0, "Chat": 1.5, "Brag": 2.0, "Flirt": 1.5}, "learns": "Charisma"},
	"Energized": {"needs": {"fun": 1.2}, "learns": "Fitness"},
	"Focused": {"prefer": {"Discuss ideas": 3.0}, "learns": "Logic"},
	"Sad": {"accept": -0.1, "prefer": {"Deep talk": 2.0, "Hug": 2.0, "Vent": 3.0, "Cuddle": 2.0}, "needs": {"social": 1.5}},
	"Angry": {"accept": -0.3, "prefer": {"Argue": 4.0, "Insult": 3.0, "Ask to leave": 2.0, "Vent": 2.0, "Break up": 2.0}},
	"Tense": {"accept": -0.15, "prefer": {"Argue": 2.0, "Ask to leave": 3.0}},
	"Embarrassed": {"accept": -0.1, "needs": {"social": 0.6}},
	"Uncomfortable": {"accept": -0.1},
	"Bored": {"accept": 0.05, "needs": {"fun": 1.5}, "prefer": {"Tell a joke": 1.5, "Gossip": 1.5, "Prank": 1.5}},
	"Flirty": {"accept": 0.1, "prefer": {"Flirt": 3.0, "Kiss": 2.0, "Cuddle": 2.0}, "learns": "Charisma"},
}
const SKILL_BOOST := 1.5


static func add(c: Node2D, name: String) -> void:
	var def: Dictionary = MOODLETS[name]
	if def.has("removes"):
		c.moodlets = c.moodlets.filter(func(m): return not (m.emotion in def.removes and m.until != INF))
	c.moodlets = c.moodlets.filter(func(m): return m.name != name)
	c.moodlets.append({"name": name, "emotion": def.emotion, "strength": def.strength * Traits.emotion(c, def.emotion),
		"until": INF if def.hours == 0 else c.world.now() + def.hours * 3600.0})


static func has(c: Node2D, name: String) -> bool:
	return c.moodlets.any(func(m): return m.name == name)


static func set_condition(c: Node2D, name: String, on: bool) -> void:
	if on and not has(c, name):
		add(c, name)
	elif not on and has(c, name):
		c.moodlets = c.moodlets.filter(func(m): return m.name != name)


# Drop expired moodlets and recalculate conditions. `conditions`: {moodlet name: bool} for extra ones.
static func update(c: Node2D, conditions := {}) -> void:
	var now: float = c.world.now()
	c.moodlets = c.moodlets.filter(func(m): return m.until > now)
	var all_good := true
	for row in NEED_MOODLETS:
		set_condition(c, row[2], c.needs[row[0]] < row[1])
	for need in c.needs:
		all_good = all_good and c.needs[need] > CONTENT_ABOVE
	set_condition(c, "Content", all_good)
	for name in conditions:
		set_condition(c, name, conditions[name])


static func totals(c: Node2D) -> Dictionary:
	var t := {}
	for m in c.moodlets:
		t[m.emotion] = t.get(m.emotion, 0.0) + m.strength
	return t


# The emotion the character feels right now (optionally leaving some moodlets out).
static func emotion(c: Node2D, ignore := []) -> String:
	var best := "Fine"
	var best_total := 0.0
	var t := {}
	for m in c.moodlets:
		if not m.name in ignore:
			t[m.emotion] = t.get(m.emotion, 0.0) + m.strength
	for e in t:
		if t[e] > best_total:
			best = e
			best_total = t[e]
	return best


static func describe(c: Node2D) -> String:
	var e := emotion(c)
	return ("Very " + e.to_lower()) if totals(c).get(e, 0.0) >= VERY else e


# The moodlets behind the current emotion, strongest first: "Argued, Hungry".
static func reasons(c: Node2D, count := 2) -> String:
	var e := emotion(c)
	var ms: Array = c.moodlets.filter(func(m): return m.emotion == e)
	ms.sort_custom(func(a, b): return a.strength > b.strength)
	return ", ".join(ms.slice(0, count).map(func(m): return m.name))


static func effect(c: Node2D, field: String, key := "") -> Variant:
	var fx: Dictionary = EFFECTS.get(emotion(c), {})
	if key == "":
		return fx.get(field, 0.0)
	return fx.get(field, {}).get(key, 1.0)


static func accept_bonus(c: Node2D) -> float:
	return effect(c, "accept")


static func prefer(c: Node2D, interaction: String) -> float:
	return effect(c, "prefer", interaction)


static func need_weight(c: Node2D, need: String) -> float:
	return effect(c, "needs", need)


static func skill_boost(c: Node2D, skill: String) -> float:
	return SKILL_BOOST if EFFECTS.get(emotion(c), {}).get("learns", "") == skill else 1.0
