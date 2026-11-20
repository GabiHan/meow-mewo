# The people living on the street when a game starts (main.gd spawn_residents()).
#
# CAST is the classic street: Jo & Sam, Alex's family, Riley & Noah. Tests (and running main.tscn directly) always
# play it. A game started from the home screen gets a fresh street from roll() (menu.gd → Session.town): the same
# houses and family shapes (a pair of roommates, a parent with two little ones, a parent with a teenager) but new
# names, sexes, looks, ages, traits, hobbies, skills, money and jobs. households() describes either for the menu.
const Traits = preload("res://scripts/traits.gd")
const Looks = preload("res://scripts/looks.gd")
const Jobs = preload("res://scripts/jobs.gd")
const Skills = preload("res://scripts/skills.gd")

# key: who they are in the family shape; parents: keys. "you": who you play in the first household.
# ages: [youngest, oldest] years for roll(); role: what the menu says about them (roll() uses their job).
const CAST := [
	{"key": "sam", "name": "Sam", "sex": "M", "years": 23.0, "ages": [19, 30], "home": 0, "tile": Vector2(490, 503),
		"color": Color(0.95, 0.65, 0.35), "traits": ["Outgoing", "Goofball", "Slob"], "skills": {"Comedy": 3, "Charisma": 2},
		"money": 200, "job": "Comedy club", "look": "sam", "role": "a stand-up comic"},
	{"key": "alex", "name": "Alex", "sex": "F", "years": 38.0, "ages": [30, 50], "home": 1, "tile": Vector2(502, 504),
		"color": Color(0.75, 0.45, 0.85), "traits": ["Hot-headed", "Foodie", "Neat"], "skills": {"Cooking": 5, "Fitness": 2},
		"money": 400, "job": "Restaurant", "look": "alex", "role": "a fiery cook"},
	{"key": "mia", "name": "Mia", "sex": "F", "years": 8.0, "ages": [5, 11], "home": 1, "tile": Vector2(500, 506),
		"color": Color(0.95, 0.8, 0.35), "traits": ["Cheerful"], "skills": {"Logic": 1}, "money": 0, "job": "", "look": "mia",
		"parents": ["alex"]},
	{"key": "lily", "name": "Lily", "sex": "F", "years": 2.5, "ages": [1.5, 3.5], "home": 1, "tile": Vector2(504, 503),
		"color": Color(0.6, 0.85, 0.95), "traits": ["Goofball"], "skills": {}, "money": 0, "job": "", "look": "lily",
		"parents": ["alex"]},
	{"key": "riley", "name": "Riley", "sex": "M", "years": 42.0, "ages": [32, 55], "home": 2, "tile": Vector2(490, 521),
		"color": Color(0.9, 0.4, 0.45), "traits": ["Loner", "Bookworm", "Cheerful"], "skills": {"Logic": 4, "Cooking": 2},
		"money": 600, "job": "Office", "look": "riley", "role": "a bookish office worker"},
	{"key": "noah", "name": "Noah", "sex": "M", "years": 15.0, "ages": [13, 17], "home": 2, "tile": Vector2(492, 525),
		"color": Color(0.45, 0.55, 0.9), "traits": ["Active", "Goofball"], "skills": {"Fitness": 2}, "money": 20, "job": "",
		"look": "noah", "parents": ["riley"]},
	{"key": "jo", "name": "Jo", "sex": "F", "years": 20.0, "ages": [18, 25], "home": 0, "tile": Vector2(488, 504),
		"color": Color(0.35, 0.8, 0.45), "traits": [], "skills": {"Cooking": 2, "Charisma": 1}, "money": 300, "job": "",
		"look": "jo", "you": true, "role": "a fresh start in life"},
]
const NAMES := {
	"F": ["Ava", "Bea", "Chloe", "Dana", "Elena", "Freya", "Grace", "Hana", "Iris", "Jade", "Kira", "Lena", "Maya", "Nora",
		"Olive", "Priya", "Quinn", "Rosa", "Sofia", "Tess", "Uma", "Vera", "Wren", "Yara", "Amara", "Leila", "Mei", "Nadia",
		"Ines", "Clara"],
	"M": ["Adam", "Ben", "Caleb", "Dev", "Eli", "Finn", "Gabe", "Hugo", "Ian", "Jonah", "Kai", "Leo", "Marco", "Nico",
		"Omar", "Pablo", "Rafi", "Theo", "Victor", "Wes", "Yusuf", "Zane", "Arjun", "Kenji", "Luca", "Mateo", "Oscar",
		"Ravi", "Tomas", "Felix"],
}
const PARENT_GAP := 20.0  # a parent is at least this many years older than their oldest child


# The street to play: the rolled one from the home screen, or the classic one.
static func current(rolled: Array) -> Array:
	return rolled if not rolled.is_empty() else CAST


# A brand-new street: CAST's shape with everything about the people rolled.
static func roll() -> Array:
	var cast := []
	var used := {}
	var by_key := {}
	for p in CAST:
		var r: Dictionary = p.duplicate(true)
		r.sex = ["F", "M"].pick_random()
		var names: Array = NAMES[r.sex].filter(func(n): return not used.has(n))
		r.name = names.pick_random()
		used[r.name] = true
		r.years = snappedf(randf_range(p.ages[0], p.ages[1]), 0.5)
		r.traits = []
		for n in randi_range(1, 3):
			var t := Traits.random_trait(r.traits)
			if t != "":
				r.traits.append(t)
		r.skills = {}
		for n in randi_range(0, 2) if r.years < 18.0 else randi_range(1, 3):
			r.skills[Skills.SKILLS.keys().pick_random()] = randi_range(1, 2 if r.years < 18.0 else 4)
		r.money = int(p.money * randf_range(0.5, 1.6))
		r.color = Color.from_hsv(randf(), 0.45, 0.92)
		if p.job != "":  # a grown-up with a job: any job, and they're qualified for it
			r.job = Jobs.JOBS.keys().filter(func(j): return not Jobs.is_school(j)).pick_random()
			var needs: Dictionary = Jobs.JOBS[r.job].get("needs", {})
			for s in needs:
				r.skills[s] = maxi(r.skills.get(s, 0), needs[s])
			r.degree = Jobs.JOBS[r.job].get("degree", false)
			var title: String = Jobs.JOBS[r.job].levels[0][0].to_lower()
			r.role = ("an " if title[0] in "aeiou" else "a ") + title
		r.look = Looks.random_for(r.sex)
		by_key[r.key] = r
		cast.append(r)
	for r in cast:  # parents old enough for their children
		for k in r.get("parents", []):
			by_key[k].years = maxf(by_key[k].years, r.years + PARENT_GAP + randf_range(0.0, 8.0))
	return cast


static func names(cast: Array) -> Array:
	return cast.map(func(r): return r.name)


static func parent_names(cast: Array, r: Dictionary) -> Array:
	return cast.filter(func(o): return o.key in r.get("parents", [])).map(func(o): return o.name)


# The households on the street, for the home screen and the HUD: [{name, home, about}] in home order.
static func households(cast: Array) -> Array:
	var who := {}
	for r in cast:
		who[r.key] = r
	var age := func(r: Dictionary) -> int: return int(r.years)
	var their := func(r: Dictionary) -> String: return "her" if r.sex == "F" else "his"
	var jo: Dictionary = who.jo
	var sam: Dictionary = who.sam
	var alex: Dictionary = who.alex
	var riley: Dictionary = who.riley
	var noah: Dictionary = who.noah
	return [
		{"name": "%s & %s" % [jo.name, sam.name], "home": 0, "about": "%s (%d), %s, and %s roommate %s (%d), %s." % [
			jo.name, age.call(jo), jo.role, their.call(jo), sam.name, age.call(sam), sam.role]},
		{"name": "%s's family" % alex.name, "home": 1, "about": "%s (%d), %s, raising %s (%d) and little %s (%d)." % [
			alex.name, age.call(alex), alex.role, who.mia.name, age.call(who.mia), who.lily.name, age.call(who.lily)]},
		{"name": "%s & %s" % [riley.name, noah.name], "home": 2, "about": "%s (%d), %s, and %s teenage %s %s (%d)." % [
			riley.name, age.call(riley), riley.role, their.call(riley), "daughter" if noah.sex == "F" else "son", noah.name,
			age.call(noah)]},
	]
