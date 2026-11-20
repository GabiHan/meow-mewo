# Personality traits: what makes each character different. Static like social.gd.
# Full documentation: docs/PEOPLE.md. Each character has a few traits (npc.gd `traits`).
#
# Fields (all optional; several traits combine by multiplying / adding):
#   text      shown in menus
#   decay     {need: ×}       how fast a need drops (Outgoing people get lonely faster)
#   likes     {key: ×}        how attractive an activity is: an object name, "cooking" or "social"
#   prefer    {interaction: ×} which social interactions they pick more often
#   emotions  {emotion: ×}    how strongly they feel moodlets of that emotion
#   skills    {skill: ×}      how fast they learn
#   accept    +x              chance of saying yes when someone wants to talk
#   peek      +x              peeking reaction score (negative = more likely to yell)
#   mess      n               dirty dishes at home before they feel "Messy home" (default 3)
#   group     Social, Lifestyle, Heart or Dark (the creator groups them)
#   dark      0..3            how wicked (morals.gd adds them up)
#   conscience n              how bad crimes feel afterwards (morals.gd): + guilty, − thrilled
#   urge      true            Kleptomaniac: wants to steal whatever their path
#   conflicts [trait]         can't be combined
const Hobbies = preload("res://scripts/hobbies.gd")

const TRAITS := {
	# Social
	"Outgoing": {"group": "Social", "text": "Loves company", "decay": {"social": 1.4}, "likes": {"social": 1.3}, "accept": 0.1, "prefer": {"Invite over": 2.0, "Gossip": 1.5, "Flirt": 1.3, "Wave": 1.5, "Dance with": 1.5}, "conflicts": ["Loner"]},
	"Loner": {"group": "Social", "text": "Needs time alone", "decay": {"social": 0.6}, "likes": {"social": 0.7}, "accept": -0.1, "prefer": {"Ask to leave": 3.0}, "conflicts": ["Outgoing"]},
	"Cheerful": {"group": "Social", "text": "Usually happy", "emotions": {"Happy": 1.5, "Sad": 0.5}},
	"Hot-headed": {"group": "Social", "text": "Quick to anger", "emotions": {"Angry": 1.5}, "prefer": {"Argue": 2.0, "Insult": 2.0, "Shove": 2.0, "Slap": 1.5}, "peek": -0.2},
	"Goofball": {"group": "Social", "text": "Loves a joke", "emotions": {"Playful": 1.3}, "prefer": {"Tell a joke": 2.5, "Prank": 2.0, "Tease": 1.5}, "skills": {"Comedy": 1.5}},
	# Lifestyle
	"Foodie": {"group": "Lifestyle", "text": "Lives to eat", "decay": {"hunger": 1.2}, "likes": {"cooking": 1.4}, "skills": {"Cooking": 1.5}},
	"Bookworm": {"group": "Lifestyle", "text": "Always reading", "likes": {"Bookshelf": 2.0}, "skills": {"Logic": 1.5}},
	"Active": {"group": "Lifestyle", "text": "Can't sit still", "decay": {"energy": 1.1}, "likes": {"Pull-up bar": 2.5}, "prefer": {"Dance with": 2.0}, "skills": {"Fitness": 1.5}, "conflicts": ["Lazy"]},
	"Lazy": {"group": "Lifestyle", "text": "Avoids effort", "decay": {"energy": 0.85}, "likes": {"TV": 1.5, "Pull-up bar": 0.3}, "conflicts": ["Active"]},
	"Neat": {"group": "Lifestyle", "text": "Hates mess", "decay": {"hygiene": 1.2}, "mess": 1, "conflicts": ["Slob"]},
	"Slob": {"group": "Lifestyle", "text": "Doesn't mind mess", "decay": {"hygiene": 0.8}, "mess": 99, "conflicts": ["Neat"]},
	# Heart: their conscience
	"Kind": {"group": "Heart", "text": "Cares about everyone", "conscience": 2, "emotions": {"Sad": 1.2}, "prefer": {"Compliment": 1.5, "Comfort": 2.0, "Hug": 1.5, "Give a gift": 1.5, "Pat on the back": 1.5, "Give a massage": 1.5}, "conflicts": ["Cruel", "Psychopath", "Sociopath"]},
	"Honest": {"group": "Heart", "text": "Can't tell a lie", "conscience": 1, "prefer": {"Apologize": 2.0}, "conflicts": ["Manipulative"]},
	"Brave": {"group": "Heart", "text": "Stands up to anyone", "emotions": {"Tense": 0.5}},
	# Dark (morals.gd): how wicked they are (`dark`) is only half of it; their life decides if it becomes crime
	"Psychopath": {"group": "Dark", "text": "Charming, fearless, feels nothing", "dark": 3, "conscience": -3, "accept": 0.05, "emotions": {"Tense": 0.3, "Sad": 0.4}, "prefer": {"Manipulate": 3.0, "Compliment": 1.3}, "conflicts": ["Kind", "Sociopath"]},
	"Sociopath": {"group": "Dark", "text": "Impulsive, no remorse", "dark": 2, "conscience": -2, "emotions": {"Angry": 1.6}, "prefer": {"Threaten": 2.0, "Attack": 1.5, "Insult": 1.5, "Argue": 1.5}, "conflicts": ["Kind", "Psychopath"]},
	"Narcissist": {"group": "Dark", "text": "It's all about them", "dark": 1, "conscience": -1, "emotions": {"Confident": 1.4, "Angry": 1.2}, "prefer": {"Brag": 3.0, "Manipulate": 1.5}},
	"Manipulative": {"group": "Dark", "text": "Uses people", "dark": 1, "conscience": -1, "prefer": {"Manipulate": 3.0, "Gossip": 1.5}, "conflicts": ["Honest"]},
	"Cruel": {"group": "Dark", "text": "Enjoys others' pain", "dark": 2, "conscience": -2, "prefer": {"Insult": 2.5, "Tease": 1.5, "Prank": 1.5, "Attack": 1.3, "Shove": 1.5}, "conflicts": ["Kind"]},
	"Kleptomaniac": {"group": "Dark", "text": "Can't help taking things", "urge": true, "prefer": {"Pickpocket": 3.0}},
}
const GROUPS := ["Social", "Lifestyle", "Heart", "Dark"]
const MAX := 4  # traits per person (the household creator)
const DARK_CHANCE := 0.15  # a random trait for a child is a dark one this often


static func multiplier(c: Node2D, field: String, key: String) -> float:
	var m := 1.0
	for t in c.traits:
		m *= TRAITS[t].get(field, {}).get(key, 1.0)
	return m


static func bonus(c: Node2D, field: String) -> float:
	var b := 0.0
	for t in c.traits:
		b += TRAITS[t].get(field, 0.0)
	return b


static func decay(c: Node2D, need: String) -> float:
	return multiplier(c, "decay", need)


static func like(c: Node2D, key: String) -> float:
	return multiplier(c, "likes", key) * Hobbies.like(c, key)


static func prefer(c: Node2D, interaction: String) -> float:
	return multiplier(c, "prefer", interaction)


static func emotion(c: Node2D, emotion_name: String) -> float:
	return multiplier(c, "emotions", emotion_name)


static func skill(c: Node2D, skill_name: String) -> float:
	return multiplier(c, "skills", skill_name) * Hobbies.skill_boost(c, skill_name)


static func mess_tolerance(c: Node2D) -> int:
	var tolerance := 3
	for t in c.traits:
		if TRAITS[t].has("mess"):
			tolerance = TRAITS[t].mess
	return tolerance


# Added up over their traits: "dark", "conscience".
static func total(c: Node2D, field: String) -> int:
	var t := 0
	for name in c.traits:
		t += TRAITS[name].get(field, 0)
	return t


static func conflict(a: String, b: String) -> bool:
	return b in TRAITS[a].get("conflicts", []) or a in TRAITS[b].get("conflicts", [])


# A list of traits with no conflicts and no repeats? "" if fine, else why not.
static func problem(list: Array) -> String:
	for i in list.size():
		for j in range(i + 1, list.size()):
			if list[i] == list[j]:
				return "%s is picked twice." % list[i]
			if conflict(list[i], list[j]):
				return "%s and %s don't go together." % [list[i], list[j]]
	return ""


# One more trait for someone who has `have`: no conflicts; a dark one only DARK_CHANCE of the time.
static func random_trait(have: Array) -> String:
	var dark := randf() < DARK_CHANCE
	var options := TRAITS.keys().filter(func(t): return not t in have and problem(have + [t]) == "" \
		and (TRAITS[t].group == "Dark") == dark)
	return options.pick_random() if not options.is_empty() else ""


static func names_in(group: String) -> Array:
	return TRAITS.keys().filter(func(t): return TRAITS[t].group == group)
