# Ownership: homes, invitations, knocking. Static like social.gd. Full documentation: docs/PEOPLE.md.
#
# A building belongs to the people who live there (their `home`). Anyone else needs an invitation to
# go in (world.guests, checked by world.can_enter, which pathfinding respects: you can't even walk in).
# Invitations last INVITE_HOURS. Ways to get one:
#   - Knock on the door (click it, or the AI wants to see someone inside). A resident who is home and
#     awake answers: yes or no by answer_chance(). If you live there, are home and in Manual mode,
#     you always decide: popup Let them in / Turn them away. Nobody home or no answer within KNOCK_WAIT: "Nobody answered".
#   - The "Invite over" social interaction (social.gd).
# A guest whose invitation runs out (or who is asked to leave) walks out on their own (npc.gd).
const Social = preload("res://scripts/social.gd")
const Emotions = preload("res://scripts/emotions.gd")
const Traits = preload("res://scripts/traits.gd")
const Perception = preload("res://scripts/perception.gd")
const Ages = preload("res://scripts/ages.gd")

const INVITE_HOURS := Social.INVITE_HOURS
const KNOCK_WAIT := 30.0  # game minutes a knocker waits for an answer
const KNOCK_COOLDOWN_HOURS := 3.0  # NPCs don't knock on the same door again for this long after a no
const STRANGER_CHANCE := 0.1  # chance of letting in someone you've never met


# Residents of building b who are home and could come to the door.
static func residents_home(node: Node, b: int) -> Array:
	return node.get_tree().get_nodes_in_group("characters").filter(func(r):
		return r.home == b and r.building == b and Perception.is_awake(r) and r.partner == null and Ages.stage(r) >= Ages.TEEN)


# Chance that `host` lets `guest` in.
static func answer_chance(host: Node2D, guest: Node2D) -> float:
	if not host.known.has(guest.npc_name):
		return STRANGER_CHANCE
	var chance := 0.4 + Social.friendship(host, guest) / 100.0 + Emotions.accept_bonus(host) + Traits.bonus(host, "accept")
	chance += clampf(Social.recent_feeling(host, guest) * 0.05, -0.3, 0.1)
	return clampf(chance, 0.05, 0.95)


# `knocker` is standing at building b's door and knocks.
static func knock(knocker: Node2D, b: int) -> void:
	knocker.state = "knocking"
	knocker.knock_building = b
	knocker.knock_timer = KNOCK_WAIT
	knocker.activity = "Knocking on the door"
	var hosts := residents_home(knocker, b)
	if hosts.is_empty():
		return  # nobody comes; the knocker gives up after KNOCK_WAIT
	var you: Array = hosts.filter(func(h): return h.controlled and not h.auto_mode)
	if not you.is_empty():  # your home and you're there in Manual: you decide
		knocker.get_tree().get_first_node_in_group("game").controller_of(you[0]).ask_at_door(you[0], knocker, b)
		return
	hosts.sort_custom(func(x, y): return Social.friendship(x, knocker) > Social.friendship(y, knocker))
	var host: Node2D = hosts[0]  # the resident who likes them most comes to the door
	answer(host, knocker, b, randf() < answer_chance(host, knocker))


static func answer(host: Node2D, knocker: Node2D, b: int, yes: bool) -> void:
	if knocker.state != "knocking" or knocker.knock_building != b:
		return  # they already left
	knocker.state = "idle"
	knocker.knock_building = -1
	if yes:
		knocker.world.invite(b, knocker, INVITE_HOURS)
		host.show_emote("\"Come on in, {who}!\"", knocker)
		knocker.activity = "Invited in"
		Social.remember(host, knocker, "came to visit", 0.5)
		Social.log_event("{a} let {b} in", host, knocker)
		knocker.on_invited(b)
	else:
		var stranger: bool = not host.known.has(knocker.npc_name)
		host.show_emote("\"Who are you? Go away!\"" if stranger else "\"Not now, sorry.\"", knocker)
		knocker.activity = "Turned away"
		Emotions.add(knocker, "Rejected")
		knocker.knock_cooldown[b] = knocker.world.now() + KNOCK_COOLDOWN_HOURS * 3600.0
		Social.log_event("{a} turned {b} away at the door", host, knocker)


# Nobody answered in time.
static func give_up(knocker: Node2D) -> void:
	knocker.knock_cooldown[knocker.knock_building] = knocker.world.now() + KNOCK_COOLDOWN_HOURS * 3600.0
	knocker.state = "idle"
	knocker.knock_building = -1
	knocker.activity = "Nobody answered"
