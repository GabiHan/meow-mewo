# Talking in your own words (click a person → Talk…). This is the conversation itself; talk_panel.gd
# is the window you type in. It runs where the simulation runs: offline here, online on the host for
# everyone (net.gd forwards what joined players do). Static.
#
#   open()   you and they stop and face each other ("talking", neither is the initiator, so it lasts
#            until someone closes it). If they're a real person (another player, online), their
#            window opens too.
#   say()    what you typed. An NPC answers with the language model (llm.gd): how your words came across
#            changes their friendship toward you (Llm.TONE). A real person just gets your words and
#            answers themselves (a little friendship and social each way).
#   close()  you've met (names known), each side that said something remembers the talk (good or bad),
#            it's logged, and the other person's window closes.
# Windows are told what happens through ui(): the local panel, or the player's computer (net.gd).
const Social = preload("res://scripts/social.gd")
const Llm = preload("res://scripts/llm.gd")

const HUMAN_TONE := "neutral"  # what each message between two real people does (Llm.TONE)

static var talks := {}  # npc_name -> {"feeling": sum of tones, "said": bool}, for everyone in a talk


static func is_human(c: Node2D) -> bool:
	return c.controlled or c.human  # someone is playing them (you, or another player online)


static func open(you: Node2D, other: Node2D) -> bool:
	if other == null or other == you or other.partner != null or not Llm.can_talk(you, other):
		return false
	you.cancel_current()
	for pair in [[you, other], [other, you]]:
		var me: Node2D = pair[0]
		me.begin_waiting(pair[1], 0.0)
		me.state = "talking"
		me.activity = "Talking with {who}"
		talks[me.npc_name] = {"feeling": 0.0, "said": false}
	if is_human(other):
		ui(other, "incoming", [you])
	return true


static func say(you: Node2D, text: String, history: Array) -> void:
	var other: Node2D = you.partner
	if other == null or not talks.has(you.npc_name):
		return
	text = text.strip_edges().substr(0, 200)
	you.show_emote("\"%s\"" % text, other, Llm.emote_seconds(text))
	talks[you.npc_name].said = true
	if is_human(other):
		Llm.apply_tone(other, you, HUMAN_TONE)
		ui(other, "received", [text])
		return
	var llm := you.get_tree().get_first_node_in_group("llm")
	if llm == null or not llm.talk(other, you, history, func(d): answered(you, other, d)):
		ui(you, "answered", [{"reply": "(%s doesn't seem to hear you: the AI is off)" % Social.display_name(you, other), "offline": true}])


static func answered(you: Node2D, other: Node2D, d: Dictionary) -> void:
	if not (is_instance_valid(you) and is_instance_valid(other)) or you.partner != other:
		return
	var tone: String = d.get("tone", "neutral")
	Llm.apply_tone(other, you, tone)
	if talks.has(you.npc_name):
		talks[you.npc_name].feeling += Llm.TONE.get(tone, 0.0)
	var reply: String = d.get("reply", "...")
	other.show_emote("\"%s\"" % reply, you, Llm.emote_seconds(reply))
	ui(you, "answered", [d])


static func close(you: Node2D) -> void:
	var other: Node2D = you.partner
	if other == null or not talks.has(you.npc_name):
		talks.erase(you.npc_name)
		return
	var mine: Dictionary = talks.get(you.npc_name, {})
	var theirs: Dictionary = talks.get(other.npc_name, {})
	if mine.get("said", false) or theirs.get("said", false):
		for pair in [[you, other], [other, you]]:
			pair[0].known[pair[1].npc_name] = true  # you've properly met
			pair[0].last_social = you.world.now()
		for pair in [[other, you, mine], [you, other, theirs]]:  # the listener remembers the speaker
			if pair[2].get("said", false):
				var feeling: float = pair[2].feeling
				Social.remember(pair[0], pair[1], "talked with me", signf(feeling) if feeling != 0.0 else 0.5)
		Social.log_event("{a} talked with {b}", you, other)
	talks.erase(you.npc_name)
	talks.erase(other.npc_name)
	if is_human(other):
		ui(other, "closed", [])
	you.end_social()


# Tell the window of the real person playing `c`: theirs on this computer, or on theirs (net.gd).
static func ui(c: Node2D, method: String, args: Array) -> void:
	var game := c.get_tree().get_first_node_in_group("game")
	if game and c == game.player:
		game.hud.talk.callv(method, args)
		return
	var net := c.get_tree().root.get_node_or_null("Net")
	if net:
		net.talk_ui(c, method, args)
