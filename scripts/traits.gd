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
const TRAITS := {
	"Outgoing": {"text": "Loves company", "decay": {"social": 1.4}, "likes": {"social": 1.3}, "accept": 0.1, "prefer": {"Invite over": 2.0, "Gossip": 1.5, "Flirt": 1.3}},
	"Loner": {"text": "Needs time alone", "decay": {"social": 0.6}, "likes": {"social": 0.7}, "accept": -0.1, "prefer": {"Ask to leave": 3.0}},
	"Cheerful": {"text": "Usually happy", "emotions": {"Happy": 1.5, "Sad": 0.5}},
	"Hot-headed": {"text": "Quick to anger", "emotions": {"Angry": 1.5}, "prefer": {"Argue": 2.0, "Insult": 2.0}, "peek": -0.2},
	"Goofball": {"text": "Loves a joke", "emotions": {"Playful": 1.3}, "prefer": {"Tell a joke": 2.5, "Prank": 2.0, "Tease": 1.5}, "skills": {"Comedy": 1.5}},
	"Foodie": {"text": "Lives to eat", "decay": {"hunger": 1.2}, "likes": {"cooking": 1.4}, "skills": {"Cooking": 1.5}},
	"Bookworm": {"text": "Always reading", "likes": {"Bookshelf": 2.0}, "skills": {"Logic": 1.5}},
	"Active": {"text": "Can't sit still", "decay": {"energy": 1.1}, "likes": {"Pull-up bar": 2.5}, "skills": {"Fitness": 1.5}},
	"Lazy": {"text": "Avoids effort", "decay": {"energy": 0.85}, "likes": {"TV": 1.5, "Pull-up bar": 0.3}},
	"Neat": {"text": "Hates mess", "decay": {"hygiene": 1.2}, "mess": 1},
	"Slob": {"text": "Doesn't mind mess", "decay": {"hygiene": 0.8}, "mess": 99},
}


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
	return multiplier(c, "likes", key)


static func prefer(c: Node2D, interaction: String) -> float:
	return multiplier(c, "prefer", interaction)


static func emotion(c: Node2D, emotion_name: String) -> float:
	return multiplier(c, "emotions", emotion_name)


static func skill(c: Node2D, skill_name: String) -> float:
	return multiplier(c, "skills", skill_name)


static func mess_tolerance(c: Node2D) -> int:
	var tolerance := 3
	for t in c.traits:
		if TRAITS[t].has("mess"):
			tolerance = TRAITS[t].mess
	return tolerance
