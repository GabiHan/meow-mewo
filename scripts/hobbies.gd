# Hobbies: what someone loves to spend their free time on. Static, no dependencies. docs/PEOPLE.md "Hobbies".
#
# Everyone has up to MAX hobbies (npc.gd `hobbies`). A hobby makes its activities more attractive (`likes`, an
# object name, "cooking" or "social", like traits), speeds up its skill (SKILL_BOOST) and doing it gives the
# "Hobby time" moodlet. NPCs get random ones; you pick yours in the household creator.
const MAX := 2
const LIKE := 1.6  # × how attractive a hobby's activities are
const SKILL_BOOST := 1.3  # × skill xp while doing it
const HOBBIES := {
	"Reading": {"text": "Never without a book", "likes": ["Bookshelf"], "skill": "Logic"},
	"Fitness": {"text": "Works out every day", "likes": ["Pull-up bar"], "skill": "Fitness"},
	"Cooking": {"text": "Loves to cook", "likes": ["cooking"], "skill": "Cooking"},
	"Films": {"text": "Watches everything", "likes": ["TV"], "skill": "Comedy"},
	"Music": {"text": "Always listening", "likes": ["Radio"], "skill": ""},
	"Gardening": {"text": "Green fingers", "likes": ["Plant"], "skill": ""},
	"Writing": {"text": "Keeps a diary", "likes": ["Nightstand"], "skill": ""},
	"Socialising": {"text": "Out and about", "likes": ["social", "Bench"], "skill": "Charisma"},
}


static func like(c: Node2D, key: String) -> float:
	for h in c.hobbies:
		if key in HOBBIES[h].likes:
			return LIKE
	return 1.0


# Is doing `key` (object name, "cooking", "social") one of their hobbies?
static func is_hobby(c: Node2D, key: String) -> bool:
	return like(c, key) > 1.0


static func skill_boost(c: Node2D, skill: String) -> float:
	for h in c.hobbies:
		if HOBBIES[h].skill == skill:
			return SKILL_BOOST
	return 1.0


static func random_pick() -> Array:
	var all := HOBBIES.keys()
	all.shuffle()
	return all.slice(0, MAX)


static func describe(c: Node2D) -> String:
	return ", ".join(c.hobbies) if not c.hobbies.is_empty() else "none"
