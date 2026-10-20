# Social system: interactions, relationships, memories, mood, and the shared event log.
# Everything here is static so any character (NPC or player) can use it via preload.
# Full documentation: docs/PEOPLE.md.
#
# Flow of a conversation (see npc.gd for the state machine):
#   1. Initiator picks a partner + interaction (AI: choose_interaction, player: click menu).
#   2. Partner stops and waits ("waiting"); initiator walks next to them.
#   3. On arrival, begin() rolls accept_chance(). Accepted -> both "talking" and the initiator says a
#      line (near you, llm.gd may replace it with a written one, and the partner replies).
#      Rejected -> small friendship hit, initiator feels "Rejected", partner remembers it.
#   4. After the duration, finish() applies effects to BOTH characters: needs, friendship, moodlets,
#      skill xp (initiator), memories, and logs it. A joke can fall flat (Skills.joke_chance).
const Emotions = preload("res://scripts/emotions.gd")
const Skills = preload("res://scripts/skills.gd")
const Traits = preload("res://scripts/traits.gd")
const Ages = preload("res://scripts/ages.gd")
const Romance = preload("res://scripts/romance.gd")
const Mind = preload("res://scripts/mind.gd")

# Each interaction:
#   name, verb         menu text / shown above heads while it happens ("Chatting with Sam")
#   a_min / b_min      youngest life stage (ages.gd: 0 baby … 4 young adult) for initiator / partner.
#                      Babies can't start anything and can only be hugged; romance needs young adults.
#   b_max              (optional) oldest life stage for the partner (Feed: babies and toddlers)
#   min_friendship     initiator's friendship toward the partner must be at least this
#   min_romance        (optional) initiator's romance toward the partner must be at least this
#   romantic           (optional) romance rules: young adults+, not family; partners who see it get jealous
#   romance            (optional) romance change both ways when it completes
#   risky              (optional) can backfire (Tease, Prank): lands with 50% + 5%/Comedy level, else the
#                      `risky` dict applies instead (partner moodlet, friendship, emote, memory, log)
#   care               (optional) need gains for the partner (a baby or toddler) when it completes
#   cost               (optional) $ the initiator pays (Give a gift)
#   when_feeling       (optional) the initiator must feel one of these emotions
#   partner_feeling    (optional) the partner must feel one of these (Comfort someone who's sad)
#   min_skill          (optional) {skill: level} the initiator needs
#   always_accepted    (optional) can't be turned down (you can't refuse being insulted)
#   special            (optional) "invite": partner may come into the initiator's home for INVITE_HOURS;
#                      "ask_to_leave": initiator's guest loses their invitation and walks out (ownership.gd);
#                      "baby": may make the woman pregnant (life.gd); only between a fertile woman and man
#                      who are close friends (70+) or partners, not family, inside a home;
#                      "care": only by teens+ who live with the little one or are their parent;
#                      "apologize": only if the partner holds a grudge (recent bad memories of you);
#                      "partners"/"propose"/"marry"/"break_up"/"divorce": relationship steps (romance.gd)
#   social / fun       need change for both when it completes
#   friendship         change in both directions when it completes (×charisma for the initiator)
#   duration           game minutes of talking
#   skill              the initiator practises this skill for the duration
#   moodlet_a / _b     moodlets for the initiator / partner when it completes
#   lines              one is said out loud by the initiator
const INTERACTIONS := [
	{"name": "Chat", "a_min": 1, "b_min": 1, "verb": "Chatting with", "min_friendship": -100, "social": 20, "fun": 0, "friendship": 3,
		"duration": 10.0, "skill": "Charisma", "moodlet_a": "Good conversation", "moodlet_b": "Good conversation",
		"lines": ["How's your day going?", "Nice weather today, huh?", "Have you eaten yet?", "What have you been up to?"]},
	{"name": "Tell a joke", "a_min": 1, "b_min": 1, "verb": "Joking with", "min_friendship": -20, "social": 15, "fun": 15, "friendship": 5,
		"duration": 5.0, "skill": "Comedy", "moodlet_a": "Had a laugh", "moodlet_b": "Had a laugh",
		"lines": ["Why did the cat sit on the computer? To keep an eye on the mouse!", "I'm reading a book on anti-gravity. Can't put it down!", "What do you call a fake noodle? An impasta!"]},
	{"name": "Compliment", "a_min": 2, "b_min": 1, "verb": "Complimenting", "min_friendship": 0, "social": 10, "fun": 5, "friendship": 4,
		"duration": 3.0, "skill": "Charisma", "moodlet_a": "Good conversation", "moodlet_b": "Complimented",
		"lines": ["You look great today!", "You're really easy to talk to.", "I love your style."]},
	{"name": "Deep talk", "a_min": 3, "b_min": 3, "verb": "Deep talk with", "min_friendship": 30, "social": 35, "fun": 0, "friendship": 8,
		"duration": 20.0, "skill": "Charisma", "moodlet_a": "Deep connection", "moodlet_b": "Deep connection",
		"lines": ["Do you ever think about what you really want in life?", "Can I tell you something personal?"]},
	{"name": "Discuss ideas", "a_min": 2, "b_min": 2, "verb": "Discussing ideas with", "min_friendship": 0, "min_skill": {"Logic": 3},
		"social": 20, "fun": 10, "friendship": 4, "duration": 15.0, "skill": "Logic",
		"moodlet_a": "Interesting discussion", "moodlet_b": "Interesting discussion",
		"lines": ["I read the universe might be a hologram.", "What if time doesn't actually exist?"]},
	{"name": "Hug", "a_min": 1, "b_min": 0, "verb": "Hugging", "min_friendship": 50, "social": 25, "fun": 5, "friendship": 5,
		"duration": 2.0, "moodlet_a": "Hugged", "moodlet_b": "Hugged", "lines": ["Come here, you!"]},
	{"name": "Comfort", "a_min": 2, "b_min": 1, "verb": "Comforting", "min_friendship": 20, "partner_feeling": ["Sad"], "social": 25, "fun": 0,
		"friendship": 6, "duration": 10.0, "skill": "Charisma", "moodlet_a": "Good conversation", "moodlet_b": "Comforted",
		"lines": ["Hey, it's going to be okay.", "I'm here for you."]},
	{"name": "Invite over", "a_min": 4, "b_min": 3, "verb": "Inviting", "min_friendship": 10, "special": "invite", "social": 10, "fun": 0,
		"friendship": 3, "duration": 3.0, "skill": "Charisma", "moodlet_a": "Good conversation", "moodlet_b": "Good conversation",
		"lines": ["Want to come over to my place?", "You should stop by my house today!"]},
	{"name": "Ask to leave", "a_min": 4, "b_min": 1, "verb": "Showing the door to", "min_friendship": -100, "special": "ask_to_leave",
		"always_accepted": true, "social": 0, "fun": 0, "friendship": -2, "duration": 2.0,
		"lines": ["It's getting late, I think you should go.", "I need some time alone now."]},
	{"name": "Try for a baby", "a_min": 4, "b_min": 4, "verb": "Trying for a baby with", "min_friendship": 0,
		"special": "baby", "social": 30, "fun": 25, "friendship": 5, "duration": 30.0,
		"moodlet_a": "Deep connection", "moodlet_b": "Deep connection",
		"lines": ["I think I'm ready to start a family.", "Do you want to have a baby with me?"]},
	# Everyday
	{"name": "Apologize", "a_min": 2, "b_min": 2, "verb": "Apologizing to", "min_friendship": -100, "special": "apologize",
		"social": 10, "fun": 0, "friendship": 5, "duration": 5.0, "skill": "Charisma", "moodlet_a": "Made up", "moodlet_b": "Made up",
		"lines": ["I'm sorry about what happened.", "I was wrong. Can we start over?"]},
	{"name": "Talk about feelings", "a_min": 3, "b_min": 3, "verb": "Talking through feelings with", "min_friendship": 20,
		"special": "support", "social": 25, "fun": 0, "friendship": 6, "duration": 20.0, "skill": "Charisma",
		"moodlet_a": "Good conversation", "moodlet_b": "Supported",
		"lines": ["You haven't seemed yourself lately. Want to talk?", "I'm worried about you. How are you, really?"]},
	{"name": "Gossip", "a_min": 3, "b_min": 3, "verb": "Gossiping with", "min_friendship": 10, "social": 20, "fun": 10,
		"friendship": 4, "duration": 10.0, "moodlet_a": "Gossiped", "moodlet_b": "Gossiped",
		"lines": ["Did you hear what happened next door?", "Don't tell anyone, but..."]},
	{"name": "Brag", "a_min": 3, "b_min": 2, "verb": "Bragging to", "min_friendship": -100, "when_feeling": ["Confident", "Happy"],
		"social": 10, "fun": 0, "friendship": 0, "duration": 5.0, "moodlet_a": "Showed off",
		"lines": ["Guess who's the best at everything? Me.", "I'm kind of a big deal, you know."]},
	{"name": "Vent", "a_min": 2, "b_min": 2, "verb": "Venting to", "min_friendship": 10,
		"when_feeling": ["Sad", "Tense", "Angry", "Uncomfortable"], "social": 20, "fun": 0, "friendship": 3, "duration": 10.0,
		"moodlet_a": "Vented", "lines": ["I've had the worst day.", "Can I just complain for a minute?"]},
	{"name": "Ask for advice", "a_min": 2, "b_min": 3, "verb": "Asking advice from", "min_friendship": 10, "social": 15, "fun": 0,
		"friendship": 3, "duration": 10.0, "moodlet_a": "Good advice", "lines": ["What would you do in my place?", "Can I ask you something?"]},
	{"name": "High five", "a_min": 1, "b_min": 1, "verb": "High-fiving", "min_friendship": 0,
		"when_feeling": ["Happy", "Playful", "Energized", "Confident"], "social": 5, "fun": 10, "friendship": 2, "duration": 1.0,
		"moodlet_a": "Had a laugh", "moodlet_b": "Had a laugh", "lines": ["Up top!"]},
	{"name": "Tease", "a_min": 2, "b_min": 2, "verb": "Teasing", "min_friendship": 0, "when_feeling": ["Playful", "Happy"],
		"risky": {"moodlet_b": "Teased", "friendship": -4.0, "emote": "\"Not funny.\"", "memory": "made fun of me", "feeling": -1.5,
			"log": "{b} didn't like {a}'s teasing"},
		"social": 10, "fun": 15, "friendship": 3, "duration": 3.0, "moodlet_a": "Had a laugh", "moodlet_b": "Had a laugh",
		"lines": ["Nice shirt. Did your grandma pick it?", "You call that a haircut?"]},
	{"name": "Prank", "a_min": 2, "b_min": 2, "verb": "Pranking", "min_friendship": 10, "when_feeling": ["Playful"],
		"risky": {"moodlet_b": "Pranked", "friendship": -8.0, "emote": "\"Hey! Not cool!\"", "memory": "pranked me", "feeling": -2.0,
			"log": "{a}'s prank on {b} went wrong"},
		"social": 5, "fun": 20, "friendship": 4, "duration": 5.0, "skill": "Comedy", "moodlet_a": "Had a laugh", "moodlet_b": "Had a laugh",
		"lines": ["Look behind you!", "*hides a whoopee cushion*"]},
	{"name": "Give a gift", "a_min": 3, "b_min": 1, "verb": "Giving a gift to", "min_friendship": 10, "cost": 20,
		"social": 10, "fun": 5, "friendship": 8, "romance": 3, "duration": 3.0, "moodlet_b": "Got a gift",
		"lines": ["I got you something!", "This made me think of you."]},
	# With children
	{"name": "Play with", "a_min": 2, "b_min": 0, "b_max": 2, "verb": "Playing with", "min_friendship": 0, "social": 15, "fun": 25,
		"friendship": 4, "duration": 20.0, "moodlet_a": "Played together", "moodlet_b": "Played together",
		"lines": ["Peekaboo!", "Tag, you're it!", "Let's build a fort!"]},
	{"name": "Read a story", "a_min": 3, "b_min": 1, "b_max": 2, "verb": "Reading a story to", "min_friendship": 0, "social": 15,
		"fun": 15, "friendship": 4, "duration": 15.0, "skill": "Logic", "moodlet_b": "Story time",
		"lines": ["Once upon a time...", "And the little dragon said..."]},
	# Caring for babies and toddlers: `care` goes to the little one's needs (Life: they can't do it themselves)
	{"name": "Feed", "a_min": 3, "b_min": 0, "b_max": 1, "verb": "Feeding", "min_friendship": -100, "special": "care",
		"always_accepted": true, "care": {"hunger": 70, "thirst": 50}, "social": 5, "fun": 0, "friendship": 2, "duration": 10.0,
		"moodlet_b": "Fed", "lines": ["Here comes the airplane!", "Yummy, isn't it?"]},
	{"name": "Change & clean", "a_min": 3, "b_min": 0, "b_max": 1, "verb": "Changing", "min_friendship": -100, "special": "care",
		"always_accepted": true, "care": {"bladder": 100, "hygiene": 80}, "social": 0, "fun": 0, "friendship": 1, "duration": 10.0,
		"moodlet_b": "Clean and dry", "lines": ["Phew! Let's get you clean.", "All fresh now."]},
	{"name": "Rock to sleep", "a_min": 3, "b_min": 0, "b_max": 1, "verb": "Rocking", "min_friendship": -100, "special": "care",
		"always_accepted": true, "care": {"energy": 60}, "social": 5, "fun": 0, "friendship": 2, "duration": 20.0,
		"lines": ["Hush little baby...", "Time to sleep."]},
	# Romance (romance.gd): young adults and older, not family. Anyone may love anyone.
	{"name": "Flirt", "a_min": 4, "b_min": 4, "verb": "Flirting with", "min_friendship": 10, "romantic": true, "romance": 6,
		"social": 10, "fun": 10, "friendship": 2, "duration": 5.0, "skill": "Charisma", "moodlet_a": "Flirted", "moodlet_b": "Flirted",
		"lines": ["Has anyone told you you have amazing eyes?", "Is it hot in here, or is it just you?", "I like your smile."]},
	{"name": "Kiss", "a_min": 4, "b_min": 4, "verb": "Kissing", "min_friendship": 20, "min_romance": 30, "romantic": true, "romance": 8,
		"social": 15, "fun": 10, "friendship": 3, "duration": 2.0, "moodlet_a": "Kissed", "moodlet_b": "Kissed", "lines": ["Come here..."]},
	{"name": "Cuddle", "a_min": 4, "b_min": 4, "verb": "Cuddling", "min_friendship": 30, "min_romance": 25, "romantic": true, "romance": 5,
		"social": 25, "fun": 5, "friendship": 3, "duration": 15.0, "moodlet_a": "Cuddled", "moodlet_b": "Cuddled", "lines": ["This is nice."]},
	{"name": "Ask to be partners", "a_min": 4, "b_min": 4, "verb": "Asking out", "min_friendship": 30, "min_romance": 40,
		"romantic": true, "special": "partners", "romance": 10, "social": 15, "fun": 5, "friendship": 5, "duration": 5.0,
		"moodlet_a": "In love", "moodlet_b": "In love", "lines": ["Will you be my partner?", "I really like you. Want to make it official?"]},
	{"name": "Propose", "a_min": 4, "b_min": 4, "verb": "Proposing to", "min_friendship": 40, "min_romance": 70, "romantic": true,
		"special": "propose", "romance": 10, "social": 20, "fun": 10, "friendship": 5, "duration": 5.0,
		"moodlet_a": "Engaged", "moodlet_b": "Engaged", "lines": ["*kneels* Will you marry me?"]},
	{"name": "Get married", "a_min": 4, "b_min": 4, "verb": "Marrying", "min_friendship": 40, "romantic": true, "special": "marry",
		"romance": 10, "social": 30, "fun": 20, "friendship": 10, "duration": 60.0, "moodlet_a": "Just married", "moodlet_b": "Just married",
		"lines": ["I do.", "Let's do this. Today."]},
	{"name": "Break up", "a_min": 4, "b_min": 4, "verb": "Breaking up with", "min_friendship": -100, "special": "break_up",
		"always_accepted": true, "romance": -40, "social": 0, "fun": 0, "friendship": -20, "duration": 5.0,
		"moodlet_a": "Broke up", "moodlet_b": "Heartbroken", "lines": ["I think we should see other people.", "It's over."]},
	{"name": "Divorce", "a_min": 4, "b_min": 4, "verb": "Divorcing", "min_friendship": -100, "special": "divorce",
		"always_accepted": true, "romance": -40, "social": 0, "fun": 0, "friendship": -25, "duration": 10.0,
		"moodlet_a": "Broke up", "moodlet_b": "Heartbroken", "lines": ["I want a divorce."]},
	{"name": "Argue", "a_min": 2, "b_min": 2, "verb": "Arguing with", "min_friendship": -100, "when_feeling": ["Angry", "Tense", "Uncomfortable"],
		"always_accepted": true, "social": 10, "fun": -5, "friendship": -10, "duration": 10.0,
		"moodlet_a": "Argued", "moodlet_b": "Argued", "lines": ["You never listen to me!", "That's not what you said yesterday!"]},
	{"name": "Insult", "a_min": 3, "b_min": 2, "verb": "Insulting", "min_friendship": -100, "when_feeling": ["Angry"], "always_accepted": true,
		"social": 0, "fun": 0, "friendship": -15, "duration": 2.0, "moodlet_b": "Insulted",
		"lines": ["You're such a slob.", "Nobody likes you, you know."]},
]

const INVITE_HOURS := 6.0  # how long an invitation to someone's home lasts (ownership.gd)
const REJECT_FRIENDSHIP := -2.0
const FLAT_JOKE_FRIENDSHIP := -2.0
const MAX_LOG := 8
const MAX_MEMORIES := 30
const GRUDGE_DAYS := 3.0  # memories this recent count toward a grudge (or a soft spot)
const RECALL_CHANCE := 0.3  # chance to bring up an old memory instead of a normal line

# Recent social events, newest last: {"text": "{a} → {b}: Chat", "a": Node2D, "b": Node2D}.
# Names are filled in at display time (format_event) so strangers show as "Unknown".
static var event_log: Array[Dictionary] = []
static var you_word: RegEx  # "You" as a whole word, not at the start (so "Young" stays)


# Average of all needs (0-100). Emotions (emotions.gd) are separate: this is just physical state.
static func mood(c: Node2D) -> float:
	var total := 0.0
	for need in c.needs:
		total += c.needs[need]
	return total / c.needs.size()


static func mood_word(value: float) -> String:
	if value > 70.0:
		return "Happy"
	if value > 45.0:
		return "Fine"
	if value > 25.0:
		return "Uncomfortable"
	return "Miserable"


# How `a` feels about `b` (relationships are one-directional: a can like b more than b likes a).
static func friendship(a: Node2D, b: Node2D) -> float:
	return a.relationships.get(b.npc_name, 0.0)


static func change_friendship(a: Node2D, b: Node2D, amount: float) -> void:
	a.relationships[b.npc_name] = clampf(friendship(a, b) + amount, -100.0, 100.0)


# How `c` is named for `viewer`: real name once they've completed an interaction, else "Unknown".
static func display_name(viewer: Node2D, c: Node2D) -> String:
	if viewer == null or c == viewer or viewer.known.has(c.npc_name):
		return c.npc_name
	return "Unknown"


static func relationship_word(value: float) -> String:
	if value < -30.0:
		return "Enemy"
	if value < 0.0:
		return "Disliked"
	if value < 20.0:
		return "Acquaintance"
	if value < 50.0:
		return "Friend"
	return "Good friend"


# --- Memories ---

# `c` remembers something about `other`. feeling: positive = good memory, negative = bad.
static func remember(c: Node2D, other: Node2D, text: String, feeling: float) -> void:
	c.memories.append({"who": other.npc_name, "text": text, "feeling": feeling, "when": c.world.now()})
	if c.memories.size() > MAX_MEMORIES:
		c.memories.pop_front()


static func memories_of(c: Node2D, other: Node2D) -> Array:
	return c.memories.filter(func(m): return m.who == other.npc_name)


# Sum of recent feelings about `other`: below 0 is a grudge, above 0 a soft spot.
static func recent_feeling(c: Node2D, other: Node2D) -> float:
	var since: float = c.world.now() - GRUDGE_DAYS * 86400.0
	var total := 0.0
	for m in memories_of(c, other):
		if m.when >= since:
			total += m.feeling
	return total


# --- Choosing ---

# Interactions `a` is currently allowed to start with `b`.
static func available_interactions(a: Node2D, b: Node2D) -> Array:
	var result := []
	var f := friendship(a, b)
	for i in INTERACTIONS:
		if f < i.min_friendship or Ages.stage(a) < i.a_min or Ages.stage(b) < i.b_min or Ages.stage(b) > i.get("b_max", 99):
			continue
		if i.get("romantic", false) and (not Romance.possible(a, b) or Romance.romance(a, b) < i.get("min_romance", -100)):
			continue
		if i.get("cost", 0) > 0 and a.money < i.cost:
			continue
		if i.has("when_feeling") and not Emotions.emotion(a) in i.when_feeling:
			continue
		if i.has("partner_feeling") and not Emotions.emotion(b) in i.partner_feeling:
			continue
		match i.get("special", ""):
			"invite":  # you have a home, they don't live there and aren't invited yet
				if a.home < 0 or b.home == a.home or a.world.can_enter(b, a.home):
					continue
			"ask_to_leave":  # they're a guest in your home, and you're there
				if a.home < 0 or a.building != a.home or b.building != a.home or b.home == a.home:
					continue
			"baby":  # a fertile woman and man, close or partners, not family, not already expecting, at home together
				if not load("res://scripts/life.gd").can_have_baby(a, b) or a.building < 0 or a.building != b.building \
						or not a.building in [a.home, b.home] or (f < 70.0 and not Romance.are_lovers(a, b)):
					continue
			"care":
				if a.home != b.home and not a.npc_name in b.parents:
					continue
			"apologize":
				if recent_feeling(b, a) >= 0.0:
					continue
			"support":  # they're struggling: depressed, anxious, isolated, burned out, or just sad
				if Mind.states(b).filter(func(s): return s != "Thriving").is_empty() and Emotions.emotion(b) != "Sad":
					continue
			"partners":
				if a.lover != "" or b.lover != "":
					continue
			"propose":
				if not Romance.are_lovers(a, b) or a.lover_status != "Dating":
					continue
			"marry":
				if not Romance.are_lovers(a, b) or a.lover_status != "Engaged" or a.building < 0 \
						or a.building != b.building or not a.building in [a.home, b.home]:
					continue
			"break_up":  # only when it's gone sour or they're upset
				if not Romance.are_lovers(a, b) or a.lover_status == "Married" \
						or (Romance.romance(a, b) >= 20.0 and not Emotions.emotion(a) in ["Angry", "Sad", "Tense"]):
					continue
			"divorce":
				if not Romance.are_lovers(a, b) or a.lover_status != "Married" \
						or (Romance.romance(a, b) >= 0.0 and Emotions.emotion(a) != "Angry"):
					continue
		var skilled := true
		for s in i.get("min_skill", {}):
			skilled = skilled and Skills.level(a, s) >= i.min_skill[s]
		if skilled:
			result.append(i)
	return result


# What an interaction "advertises" to the utility AI, same format as smart objects.
static func advertisement(i: Dictionary) -> Dictionary:
	return {"social": i.social, "fun": i.fun}


const CARE_WEIGHT := 2.0  # how much caregivers care about a little one's needs, compared to their own


# How much `a` wants to do `i` with `b`, for the AI. Caring for a baby is scored by the baby's needs.
static func interaction_score(a: Node2D, b: Node2D, i: Dictionary) -> float:
	if i.has("care"):
		return b.advertisement_score(i.care) * CARE_WEIGHT * (1.5 if a.npc_name in b.parents else 1.0)
	if i.get("romantic", false):  # romance comes from attraction, not from needs
		return a.advertisement_score(advertisement(i)) + Romance.desire(a, b)
	return a.advertisement_score(advertisement(i))


# AI pick: weighted random by how much each option helps `a`, × how `a` feels and who `a` is.
# Angry people argue, playful people joke, goofballs joke more, hot-heads argue more.
static func choose_interaction(a: Node2D, b: Node2D) -> Dictionary:
	var options := available_interactions(a, b)
	if options.is_empty():
		return {}
	var weights := []
	var total := 0.0
	for i in options:
		var w := maxf(0.1, interaction_score(a, b, i)) * Emotions.prefer(a, i.name) * Traits.prefer(a, i.name)
		if i.get("special", "") in ["baby", "marry", "propose", "divorce", "break_up"]:
			w *= 0.3  # big decisions: not every time they're together
		if i.get("romantic", false) and a.lover != "" and a.lover != b.npc_name:
			w *= 0.1  # mostly faithful
		if recent_feeling(a, b) < -2.0 and i.friendship > 0:
			w *= 0.3  # holding a grudge: not in the mood to be nice to them
		weights.append(w)
		total += w
	var roll := randf() * total
	for n in options.size():
		roll -= weights[n]
		if roll <= 0.0:
			return options[n]
	return options[-1]


# Chance that `b` goes along with `a`'s interaction: liking `a`, being in a good mood and a good
# emotion, `a`'s charisma and `b`'s traits help; a recent grudge hurts.
static func accept_chance(a: Node2D, b: Node2D, i: Dictionary) -> float:
	if i.get("always_accepted", false):
		return 1.0
	var chance := 0.55 + friendship(b, a) / 200.0 + (mood(b) - 50.0) / 150.0
	if i.get("romantic", false):  # romance depends on attraction, and on being free
		chance = 0.3 + Romance.romance(b, a) / 100.0 + friendship(b, a) / 300.0 + (mood(b) - 50.0) / 150.0
		chance += (Romance.chemistry(a, b) - 0.5) * 0.4
		if b.lover != "" and b.lover != a.npc_name:
			chance -= Romance.FAITHFUL_PENALTY
	chance += Emotions.accept_bonus(b) + Skills.charisma_bonus(a) + Traits.bonus(b, "accept") + Mind.bonus(b, "accept")
	chance += clampf(recent_feeling(b, a) * 0.05, -0.3, 0.1)
	return clampf(chance, 0.05, 0.95)


# --- Doing ---

# Initiator has arrived next to the partner.
static func begin(a: Node2D, b: Node2D, i: Dictionary) -> void:
	if randf() < accept_chance(a, b, i):
		a.state = "talking"
		a.talk_timer = i.duration
		a.activity = i.verb + " {who}"
		a.activity_with = b
		if not b.busy_talk:  # someone busy keeps doing what they were doing while they talk (npc.gd)
			b.state = "talking"
			b.activity = i.verb + " {who}"
			b.activity_with = a
		var line := line_for(a, b, i)
		a.show_emote("\"%s\"" % line, b)
		var llm := a.get_tree().get_first_node_in_group("llm")
		if llm:  # near you, the language model rewrites the line and adds a reply (llm.gd)
			llm.conversation(a, b, i, line)
	else:
		change_friendship(a, b, REJECT_FRIENDSHIP)
		change_friendship(b, a, REJECT_FRIENDSHIP)
		Emotions.add(a, "Rejected")
		Mind.learn(a, "social", false)
		remember(a, b, "turned down my " + i.name.to_lower(), -1.0)
		b.show_emote("\"Not now.\"", a)
		log_event("{b} rejected {a}'s " + i.name.to_lower(), a, b)
		a.end_social()


# What the initiator says. Sometimes they bring up something they remember about the partner.
static func line_for(a: Node2D, b: Node2D, i: Dictionary) -> String:
	var mems := memories_of(a, b)
	if not mems.is_empty() and randf() < RECALL_CHANCE and i.name in ["Chat", "Argue", "Deep talk"]:
		var m: Dictionary = mems.pick_random()
		if m.feeling < 0:
			return "I haven't forgotten how you %s." % m.text
		return "Remember when you %s? That was nice." % m.text
	return i.lines.pick_random()


# Talking time is over: apply effects to both sides.
static func finish(a: Node2D, b: Node2D, i: Dictionary) -> void:
	var flat: bool = i.name == "Tell a joke" and randf() > Skills.joke_chance(a)
	if i.has("skill"):
		a.practice(i.skill, i.duration)
	if i.has("risky") and randf() > Skills.joke_chance(a):  # the tease or prank backfired
		var r: Dictionary = i.risky
		change_friendship(a, b, r.friendship)
		change_friendship(b, a, r.friendship)
		Emotions.add(b, r.moodlet_b)
		b.show_emote(r.emote, a)
		remember(b, a, r.memory, r.feeling)
		log_event(r.log, a, b)
		a.end_social()
		return
	if flat:
		change_friendship(a, b, FLAT_JOKE_FRIENDSHIP)
		change_friendship(b, a, FLAT_JOKE_FRIENDSHIP)
		Emotions.add(a, "Joke fell flat")
		b.show_emote("\"...\"", a)
		remember(b, a, "told me a terrible joke", -0.5)
		for me in [a, b]:
			me.known[(b if me == a else a).npc_name] = true
		log_event("{a}'s joke to {b} fell flat", a, b)
		a.end_social()
		return
	for pair in [[a, b], [b, a]]:
		var me: Node2D = pair[0]
		var other: Node2D = pair[1]
		me.needs.social = clampf(me.needs.social + i.social, 0.0, 100.0)
		me.needs.fun = clampf(me.needs.fun + i.fun, 0.0, 100.0)
		var amount: float = i.friendship * (Skills.friendship_multiplier(a) if i.friendship > 0 else 1.0)
		change_friendship(me, other, amount)
		me.known[other.npc_name] = true  # they've now properly met
		var moodlet: String = i.get("moodlet_a" if me == a else "moodlet_b", "")
		if moodlet != "":
			Emotions.add(me, moodlet)
	if i.has("care"):
		for need in i.care:
			b.needs[need] = clampf(b.needs[need] + i.care[need], 0.0, 100.0)
	if i.has("romance") and (i.romance < 0 or Romance.romance(a, b) >= 0.0 or i.get("romantic", false)):
		Romance.change(a, b, i.romance)
		Romance.change(b, a, i.romance)
	a.money -= i.get("cost", 0)
	if i.get("romantic", false):
		a.last_romance = a.world.now()
		b.last_romance = a.world.now()
		for pair in Romance.jealousy(a, b, a.get_tree().get_nodes_in_group("characters")):
			remember(pair[0], pair[1], "was romantic with someone else", -4.0)
			pair[0].show_emote("\"How could you?!\"", pair[1])
			log_event("{a} saw {b} being romantic with someone else", pair[0], pair[1])
	for me in [a, b]:
		me.last_social = a.world.now()
	Mind.learn(a, "social", true)
	match i.get("special", ""):
		"support":
			Mind.support(b)
		"apologize":  # forgiven: the grudge is let go
			for m in memories_of(b, a):
				m.feeling = maxf(m.feeling, 0.0)
		"partners":
			Romance.set_status(a, b, "Dating")
			log_event("{a} and {b} are now dating", a, b)
		"propose":
			Romance.set_status(a, b, "Engaged")
			b.show_emote("\"Yes! Yes!\"", a)
			log_event("{a} and {b} got engaged!", a, b)
		"marry":
			Romance.set_status(a, b, "Married")
			if a.home >= 0:
				Romance.move_in(b, a.home)
			log_event("{a} and {b} got married!", a, b)
		"break_up", "divorce":
			var was_married: bool = a.lover_status == "Married"
			Romance.set_status(a, b, "")
			if was_married:
				for c in [a, b]:
					Romance.move_out(c)
			log_event("{a} %s {b}" % ("divorced" if was_married else "broke up with"), a, b)
		"invite":
			a.world.invite(a.home, b, INVITE_HOURS)
		"ask_to_leave":
			a.world.uninvite(a.home, b)
			b.show_emote("\"Fine, I'm going.\"", a)
		"baby":
			load("res://scripts/life.gd").try_for_baby(a, b)
	# The partner remembers what was done to them; the initiator remembers what they did together.
	remember(b, a, past_tense(i.name), i.friendship / 5.0)
	remember(a, b, past_tense(i.name), signf(i.friendship))
	if i.name == "Tell a joke":
		b.show_emote("\"Haha!\"", a)
	elif i.name == "Compliment":
		b.show_emote("\"Aw, thanks!\"", a)
	elif i.name == "Insult":
		b.show_emote("\"How dare you!\"", a)
	var sign := "+" if i.friendship >= 0 else ""
	log_event("{a} → {b}: %s (friendship %s%d)" % [i.name, sign, i.friendship], a, b)
	a.end_social()


# Memory text, as the other person would say it: "you told me a joke".
static func past_tense(interaction: String) -> String:
	return {"Chat": "chatted with me", "Tell a joke": "told me a joke", "Compliment": "complimented me",
		"Deep talk": "opened up to me", "Discuss ideas": "discussed ideas with me", "Hug": "hugged me",
		"Comfort": "comforted me", "Argue": "argued with me", "Insult": "insulted me",
		"Invite over": "invited me over", "Ask to leave": "asked me to leave", "Try for a baby": "wanted a baby with me",
		"Apologize": "apologized to me", "Gossip": "gossiped with me", "Brag": "bragged to me", "Vent": "vented to me",
		"Ask for advice": "asked me for advice", "High five": "high-fived me", "Tease": "teased me", "Prank": "pranked me",
		"Give a gift": "gave me a gift", "Play with": "played with me", "Read a story": "read me a story", "Feed": "fed me",
		"Change & clean": "changed me", "Rock to sleep": "rocked me to sleep", "Flirt": "flirted with me", "Kiss": "kissed me",
		"Cuddle": "cuddled me", "Ask to be partners": "asked me out", "Propose": "proposed to me", "Get married": "married me",
		"Break up": "broke up with me", "Divorce": "divorced me", "Talk about feelings": "was there for me"}.get(interaction, interaction.to_lower())


static func log_event(text: String, a: Node2D, b: Node2D) -> void:
	event_log.append({"text": text, "a": a, "b": b})
	if event_log.size() > MAX_LOG:
		event_log.pop_front()
	print(format_event(event_log[-1], null))  # console always shows real names


static func format_event(e: Dictionary, viewer: Node2D) -> String:
	var a_name: String = display_name(viewer, e.a) if is_instance_valid(e.a) else e.get("a_name", "Someone")
	var b_name: String = display_name(viewer, e.b) if is_instance_valid(e.b) else e.get("b_name", "someone")
	var text: String = e.text.replace("{a}", a_name).replace("{b}", b_name)
	text = text.replace("You's", "your").replace("You was", "You were")
	if you_word == null:
		you_word = RegEx.create_from_string("(?<=\\s)You\\b")
	return you_word.sub(text, "you", true)
