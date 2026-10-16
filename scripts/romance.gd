# Romance: attraction, dating, engagement, marriage, break-ups, jealousy. Static.
# Full documentation: docs/PEOPLE.md (Romance). Depends only on ages.gd and emotions.gd.
#
# `romance` {npc_name: -100..100} is separate from friendship and one-directional, like it.
# `lover` (npc_name) and `lover_status` ("Dating", "Engaged", "Married") are stored on both people.
# Romantic interactions are for Young adults and older, never between family (ages.gd). Anyone may
# love anyone; only babies need a woman and a man (life.gd).
const Ages = preload("res://scripts/ages.gd")
const Emotions = preload("res://scripts/emotions.gd")

const FAITHFUL_PENALTY := 0.5  # someone already taken is this much less likely to accept romance
const DESIRE := 8.0  # how much a single person (or a couple) wants romance with someone they click with
const AFTERGLOW_HOURS := 4.0  # after a romantic moment the wish for another one builds back up over this long
const JEALOUS_ROMANCE := -20.0  # seeing your lover being romantic with someone else
const BREAKUP_ROMANCE := -40.0


# Chemistry: every pair has a fixed attraction 0..1 (the same both ways), so only some people click.
static func chemistry(a: Node2D, b: Node2D) -> float:
	var names := [a.npc_name, b.npc_name]
	names.sort()
	return (hash("-".join(names)) % 1000) / 1000.0


# How much `a` wants romance with `b` (for the AI): attraction and existing feelings, not needs.
static func desire(a: Node2D, b: Node2D) -> float:
	if a.lover != "" and a.lover != b.npc_name:
		return 0.0  # taken (and faithful, mostly)
	var since: float = (a.world.now() - a.last_romance) / 3600.0
	return DESIRE * chemistry(a, b) * 2.0 * (1.0 + maxf(romance(a, b), 0.0) / 50.0) * clampf(since / AFTERGLOW_HOURS, 0.1, 1.0)


static func romance(a: Node2D, b: Node2D) -> float:
	return a.romance.get(b.npc_name, 0.0)


static func change(a: Node2D, b: Node2D, amount: float) -> void:
	a.romance[b.npc_name] = clampf(romance(a, b) + amount, -100.0, 100.0)


static func word(value: float) -> String:
	if value >= 60.0:
		return "In love"
	if value >= 20.0:
		return "Crush"
	if value <= -20.0:
		return "Turned off"
	return "–"


# May these two be romantic at all?
static func possible(a: Node2D, b: Node2D) -> bool:
	return Ages.is_grown_up(a) and Ages.is_grown_up(b) and not Ages.family(a, b)


static func are_lovers(a: Node2D, b: Node2D) -> bool:
	return a.lover == b.npc_name and b.lover == a.npc_name


static func status_text(c: Node2D) -> String:
	if c.lover == "":
		return "Single"
	return {"Dating": "Dating %s", "Engaged": "Engaged to %s", "Married": "Married to %s"}[c.lover_status] % c.lover


static func set_status(a: Node2D, b: Node2D, status: String) -> void:
	for pair in [[a, b], [b, a]]:
		pair[0].lover = pair[1].npc_name if status != "" else ""
		pair[0].lover_status = status


# Married couples live together: the partner moves into the initiator's home (and back on divorce).
static func move_in(mover: Node2D, home: int) -> void:
	if mover.home == home:
		return
	mover.original_home = mover.home
	mover.home = home
	mover.home_cell = mover.world.door_inside(home) if home >= 0 else mover.home_cell


static func move_out(c: Node2D) -> void:
	if c.original_home >= 0 and c.original_home != c.home:
		c.home = c.original_home
		c.home_cell = c.world.door_inside(c.home)
	c.original_home = -1


# Lovers who saw a or b being romantic with someone else get jealous (they must have seen it: `seen`).
static func jealousy(a: Node2D, b: Node2D, people: Array) -> Array:
	var jealous := []
	for w in people:
		if w == a or w == b or w.lover == "":
			continue
		for cheater in [a, b]:
			var other: Node2D = b if cheater == a else a
			if w.lover == cheater.npc_name and other.npc_name != w.npc_name and w.seen.has(cheater):
				change(w, cheater, JEALOUS_ROMANCE)
				Emotions.add(w, "Jealous")
				jealous.append([w, cheater])
	return jealous
