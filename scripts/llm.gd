# Words from a local language model: Qwen3.5 4B (Hugging Face: unsloth/Qwen3.5-4B-GGUF) running in
# llama.cpp's llama-server on this computer. The systems still decide everything that matters (who
# talks to whom, yes or no, friendship, what people do); the model only writes words and gives nudges:
#   conversation()  what two people near you say (replaces the scripted line, and the partner replies)
#   think()         a short private thought: "~ ... ~" over their head, and in their click menu
#   wish()          what an NPC feels like doing for the next WISH_HOURS: that option scores ×WISH_BOOST
#   talk()          you type to someone (talk_panel.gd) and they answer in character
# Without a server every caller falls back to the scripted behaviour, so the game plays the same.
# One request runs at a time (a laptop runs one); what you typed jumps the queue.
# With a window, the game starts llama-server itself if it's installed (and stops it when the game
# ends). Headless runs (the tests) never touch the network: they set `fake` to answer requests.
# Full documentation: docs/AI.md.
extends Node

const Social = preload("res://scripts/social.gd")
const Emotions = preload("res://scripts/emotions.gd")
const Traits = preload("res://scripts/traits.gd")
const Ages = preload("res://scripts/ages.gd")
const Mind = preload("res://scripts/mind.gd")
const Jobs = preload("res://scripts/jobs.gd")
const Romance = preload("res://scripts/romance.gd")
const GameTime = preload("res://scripts/game_time.gd")
const Kitchen = preload("res://scripts/kitchen.gd")
const Actions = preload("res://scripts/actions.gd")
const Perception = preload("res://scripts/perception.gd")

const MODEL := "unsloth/Qwen3.5-4B-GGUF:Q4_K_M"  # downloaded from Hugging Face on first start (~2.7 GB)
const PORT := 8765
const URL := "http://127.0.0.1:8765"
const SERVER_PATHS := ["/opt/homebrew/bin/llama-server", "/usr/local/bin/llama-server"]
const HEALTH_SECONDS := 3.0  # real seconds between checks while the server isn't ready
const REQUEST_TIMEOUT := 30.0
const MAX_QUEUE := 3  # background requests beyond this are skipped (what you type always goes in)
const HEAR_RADIUS := 25.0  # tiles: only conversations and thoughts near you get written words
const MIN_TALK_SECONDS := 4.0  # real seconds a conversation must last for a written line to arrive in time
const REPLY_DELAY := 2.5  # real seconds between a line and the partner's reply
const BACKGROUND_SECONDS := 6.0  # real seconds between background jobs (a thought or a wish)
const THOUGHT_MINUTES := 120.0  # game minutes before the same person has a new thought
const WISH_HOURS := 3.0
const WISH_BOOST := 1.6
const WISH_RADIUS := 30.0  # tiles: same as npc.gd CONSIDER_RADIUS
const TALK_RADIUS := 6.0  # tiles: how close you must be to type to someone
const TONE := {"nice": 2.0, "neutral": 0.5, "mean": -4.0}  # their friendship toward you per message you type
const TALK_SOCIAL := 4.0  # social need for both, per message

const STYLE := "You write the words for characters in a cosy, slightly funny life-sim game (like The Sims). " \
	+ "Characters talk like real people: casual, short and in character, matching their age, personality, mood " \
	+ "and how they feel about each other. Children talk like children. Each line is one or two short sentences, " \
	+ "under 20 words. No narration, no stage directions, no emojis, no quotation marks."

var online := false
var status := "off"  # "off" (no server), "starting" (loading or downloading the model), "online"
var fake := Callable()  # tests: func(request) -> String answers instead of the server
var queue := []  # {messages, max_tokens, schema, on_done}
var current := {}
var busy := false
var http: HTTPRequest
var health: HTTPRequest
var health_timer := 0.0
var background_timer := BACKGROUND_SECONDS
var next_job := "thought"  # background jobs alternate: thought, wish
var server_pid := -1  # llama-server we started (we stop it when the game ends)
var headless := DisplayServer.get_name() == "headless"
var remote := false  # joined someone's town (net.gd): their model writes the words; `status` is theirs


func _ready() -> void:
	add_to_group("llm")
	if remote:
		return
	http = HTTPRequest.new()
	http.timeout = REQUEST_TIMEOUT
	http.request_completed.connect(_on_reply)
	add_child(http)
	health = HTTPRequest.new()
	health.timeout = 2.0
	health.request_completed.connect(_on_health)
	add_child(health)
	if not headless:
		check_health()


func _exit_tree() -> void:
	if server_pid > 0:
		OS.kill(server_pid)
		server_pid = -1


func _process(delta: float) -> void:
	if remote or (headless and not fake.is_valid()):
		return
	if not online:
		health_timer -= delta
		if health_timer <= 0.0 and not headless:
			check_health()
		return
	background_timer -= delta
	if background_timer <= 0.0 and queue.is_empty() and not busy:
		background_timer = BACKGROUND_SECONDS
		background_job()


# --- The server ---

func check_health() -> void:
	health_timer = HEALTH_SECONDS
	if health.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		health.request(URL + "/health")


func _on_health(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and code == 200:
		online = true
		status = "online"
		return
	if code == 503:  # running, still loading the model
		status = "starting"
	elif server_pid < 0:
		start_server()


func start_server() -> void:
	for path in SERVER_PATHS:
		if FileAccess.file_exists(path):
			server_pid = OS.create_process(path, ["-hf", MODEL, "--no-mmproj", "--reasoning", "off", "--port", str(PORT),
				"-c", "4096", "-np", "1", "--log-disable"])
			status = "starting" if server_pid > 0 else "off"
			return


func status_text() -> String:
	match status:
		"online":
			return "AI: Qwen3.5 online"
		"starting":
			return "AI: Qwen3.5 starting…"
	return "AI: off (scripted lines)"


# --- Requests ---

# Queue a request. on_done gets a String (no schema) or a Dictionary (schema), only on success.
func ask(messages: Array, max_tokens: int, schema: Dictionary, on_done: Callable, urgent := false) -> bool:
	if not online:
		return false
	var request := {"messages": messages, "max_tokens": max_tokens, "schema": schema, "on_done": on_done}
	if urgent:
		queue.push_front(request)
	elif queue.size() >= MAX_QUEUE:
		return false
	else:
		queue.append(request)
	pump.call_deferred()
	return true


func pump() -> void:
	while not busy and not queue.is_empty():
		var request: Dictionary = queue.pop_front()
		if fake.is_valid():
			deliver(request, fake.call(request))
			continue
		var body := {"messages": request.messages, "max_tokens": request.max_tokens, "temperature": 0.8,
			"chat_template_kwargs": {"enable_thinking": false}}
		if not request.schema.is_empty():
			body["response_format"] = {"type": "json_schema", "json_schema": {"name": "answer", "schema": request.schema}}
		if http.request(URL + "/v1/chat/completions", ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(body)) == OK:
			busy = true
			current = request


func _on_reply(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	busy = false
	var request := current
	current = {}
	if result != HTTPRequest.RESULT_SUCCESS:
		online = false  # the server went away: back to scripted lines until it answers again
		status = "starting" if server_pid > 0 else "off"
		queue.clear()
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if code == 200 and data is Dictionary and not data.get("choices", []).is_empty():
		deliver(request, str(data.choices[0].message.get("content", "")))
	pump()


func deliver(request: Dictionary, text: String) -> void:
	text = strip_thinking(text)
	if request.schema.is_empty():
		text = clean_line(text)
		if text != "":
			request.on_done.call(text)
		return
	var data = JSON.parse_string(text)
	if data is Dictionary:
		for key in data:
			if data[key] is String:
				data[key] = clean_line(data[key])
		request.on_done.call(data)


static func strip_thinking(text: String) -> String:
	var end := text.find("</think>")
	return text.substr(end + 8) if end >= 0 else text


# One spoken line: no quotes, no "Name:" prefix, only the first line (small models add the other
# person's answer on the next one), not too long.
static func clean_line(text: String) -> String:
	text = text.strip_edges().get_slice("\n", 0).replace("\"", "").replace("“", "").replace("”", "")
	var colon := text.find(":")
	if colon > 0 and colon < 16 and not " " in text.substr(0, colon):
		text = text.substr(colon + 1).strip_edges()
	return text.substr(0, 160) if text.length() <= 160 else text.substr(0, 157) + "…"


# Real seconds a line counts as being said (emote_timer): longer lines take longer.
static func emote_seconds(text: String) -> float:
	return clampf(2.0 + text.split(" ", false).size() * 0.35, 4.0, 9.0)


# --- What the model knows about people ---

# Who `c` is right now, in one paragraph. With a `viewer`, c's name is only given if the viewer knows it.
static func who(c: Node2D, viewer: Node2D = null) -> String:
	var name := Social.display_name(viewer, c)
	var parts := ["%s (%s)" % [name if name != "Unknown" else "a stranger", Ages.describe(c).to_lower()]]
	if not c.traits.is_empty():
		parts.append("personality: " + ", ".join(c.traits.map(func(t): return "%s (%s)" % [t, Traits.TRAITS[t].text.to_lower()])))
	var why := Emotions.reasons(c)
	parts.append("feeling %s%s" % [Emotions.describe(c).to_lower(), " (" + why.to_lower() + ")" if why != "" else ""])
	var mind := Mind.states(c)
	if not mind.is_empty():
		parts.append("lately: " + ", ".join(mind).to_lower())
	var low := []
	for need in c.needs:
		if c.needs[need] < 30.0:
			low.append({"hunger": "hungry", "thirst": "thirsty", "energy": "tired", "fun": "bored", "bladder": "needs the toilet",
				"hygiene": "feels grubby", "social": "lonely"}[need])
	if not low.is_empty():
		parts.append("right now: " + ", ".join(low))
	if c.job != "":
		parts.append(("goes to %s" % c.job if Jobs.is_school(c.job) else "works as %s at the %s" % [Jobs.title(c), c.job]).to_lower())
	if c.lover != "":
		parts.append("%s with %s" % [c.lover_status.to_lower(), c.lover])
	return "; ".join(parts) + "."


# How `c` sees `other`: name (or stranger), friendship, romance, family, recent memories.
static func relation(c: Node2D, other: Node2D) -> String:
	var name := Social.display_name(c, other)
	if name == "Unknown":
		return "%s doesn't know this person yet (a stranger: %s)." % [c.npc_name, Ages.describe(other).to_lower()]
	var f := Social.friendship(c, other)
	var text := "%s sees %s as %s (friendship %d of 100)" % [c.npc_name, name, Social.relationship_word(f).to_lower(), f]
	if other.npc_name == c.lover:
		text += ", and they're " + c.lover_status.to_lower()
	elif Romance.romance(c, other) != 0.0:
		text += ", romance: " + Romance.word(Romance.romance(c, other)).to_lower()
	if other.npc_name in c.parents:
		text += "; it's their parent"
	elif c.npc_name in other.parents:
		text += "; it's their child"
	elif Ages.family(c, other):
		text += "; they're family"
	var mems := Social.memories_of(c, other)
	if not mems.is_empty():
		text += ". Recently %s: %s" % [name, ", ".join(mems.slice(maxi(0, mems.size() - 3)).map(func(m): return m.text))]
	return text + "."


static func setting(c: Node2D) -> String:
	var t: float = c.world.now()
	return "It's %s %s in %s. Where %s is: %s." % [GameTime.weekday(t), GameTime.part_of_day(t).to_lower(), GameTime.season(t).to_lower(),
		c.npc_name, c.world.location_name(c).to_lower()]


# Close enough to someone being played to be heard: you (and on your screen), or online another
# player (same floor, within HEAR_RADIUS).
func near_you(c: Node2D) -> bool:
	var you := get_tree().get_first_node_in_group("player")
	for h in get_tree().get_nodes_in_group("characters"):
		if not h.controlled:
			continue
		if c == h or c.partner == h:
			return true
		if c.floor == h.floor and c.grid_pos.distance_to(h.grid_pos) <= HEAR_RADIUS and (h != you or c.is_visible_in_tree()):
			return true
	return false


# --- Conversations (social.gd begin()) ---

# `a` just started interaction `i` with `b` and said the scripted `line`. Ask for a better line and a
# reply; they replace the scripted words if the conversation is still going when they arrive.
func conversation(a: Node2D, b: Node2D, i: Dictionary, line: String) -> void:
	if not online or not (near_you(a) or near_you(b)) or i.duration / maxf(Engine.time_scale, 1.0) < MIN_TALK_SECONDS:
		return
	var prompt := "\n".join([
		"Speaker: " + who(a),
		"Listener: " + who(b, a),
		relation(a, b),
		relation(b, a),
		setting(a),
		"%s starts this: %s. A generic example (don't copy it, write something fresher that fits them): %s" % [a.npc_name, i.name, line],
		"line = only the words %s says. reply = only %s's short answer. Only use a name the speaker knows." % [a.npc_name, b.npc_name]])
	var schema := {"type": "object", "properties": {"line": {"type": "string"}, "reply": {"type": "string"}}, "required": ["line", "reply"]}
	ask([{"role": "system", "content": STYLE}, {"role": "user", "content": prompt}], 120, schema, func(d): said(a, b, d))


func said(a: Node2D, b: Node2D, d: Dictionary) -> void:
	if not (is_instance_valid(a) and is_instance_valid(b)) or a.partner != b or a.state != "talking":
		return  # too late: the conversation is over
	var line: String = d.get("line", "")
	var reply: String = d.get("reply", "")
	if line != "":
		a.show_emote("\"%s\"" % line, b, emote_seconds(line))
	if reply != "":
		get_tree().create_timer(REPLY_DELAY, true, false, true).timeout.connect(replied.bind(b, a, reply))


func replied(b: Node2D, a: Node2D, reply: String) -> void:
	if is_instance_valid(a) and is_instance_valid(b) and b.partner == a and b.state == "talking":
		b.show_emote("\"%s\"" % reply, a, emote_seconds(reply))


# --- Background: thoughts and wishes ---

func background_job() -> void:
	var people := get_tree().get_nodes_in_group("characters").filter(func(c): return not c.dead and not c.at_work \
		and Ages.stage(c) >= Ages.CHILD and Perception.is_awake(c))
	var job := next_job
	next_job = "wish" if job == "thought" else "thought"
	if job == "thought":
		var t: float = get_tree().get_first_node_in_group("world").now()
		var near := people.filter(func(c): return near_you(c) and c.emote_timer <= 0.0 and t - c.thought_at >= THOUGHT_MINUTES * 60.0)
		if not near.is_empty():
			think(near.pick_random())
			return
	var wanting := people.filter(func(c): return not c.controlled and c.world.now() >= c.wish_until)
	if not wanting.is_empty():
		wish(wanting.pick_random())


func think(c: Node2D) -> bool:
	var prompt := "\n".join([who(c), setting(c), "%s is %s." % [c.npc_name, c.shown_activity(c).to_lower()],
		"Write one private thought %s has right now: first person, under 12 words." % c.npc_name])
	return ask([{"role": "system", "content": STYLE}, {"role": "user", "content": prompt}], 40, {}, func(text): thought(c, text))


func thought(c: Node2D, text: String) -> void:
	if not is_instance_valid(c):
		return
	c.thought = text
	c.thought_at = c.world.now()
	if c.emote_timer <= 0.0 and near_you(c):
		c.show_emote("~ %s ~" % text, null, emote_seconds(text))


# The things `c` could feel like doing: {key: description}. Keys are what choose_action() boosts:
# an object name, "cooking" or "social".
static func wish_options(c: Node2D) -> Dictionary:
	var options := {}
	for obj in c.get_tree().get_nodes_in_group("smart_objects"):
		if options.has(obj.object_name) or obj.object_name in Kitchen.KITCHEN_OBJECTS or obj.object_name == "Bus stop" \
				or not c.may_use(obj) or c.travel_distance(obj.grid_pos, obj.floor) > WISH_RADIUS:
			continue  # the kitchen is "cooking"; the bus stop is for work
		var actions := Actions.for_object(obj)
		if not actions.is_empty():
			options[obj.object_name] = "%s (%s)" % [obj.object_name, ", ".join(actions.map(func(a): return a.name.to_lower()))]
	if Kitchen.options(c, c.home).any(func(o): return o.get("cooking", false)):
		options["cooking"] = "cooking something nice"
	options["social"] = "spending time with someone"
	return options


func wish(c: Node2D) -> bool:
	var options := wish_options(c)
	var prompt := "\n".join([who(c), setting(c), "Things %s could do: %s." % [c.npc_name, "; ".join(options.values())],
		"Which ONE does %s most feel like doing in the next few hours, in character? Give the key and a few words why." % c.npc_name])
	var schema := {"type": "object", "properties": {"choice": {"type": "string", "enum": options.keys()}, "why": {"type": "string"}},
		"required": ["choice", "why"]}
	return ask([{"role": "system", "content": STYLE}, {"role": "user", "content": prompt}], 60, schema, func(d): wished(c, d, options))


func wished(c: Node2D, d: Dictionary, options: Dictionary) -> void:
	if not is_instance_valid(c) or not options.has(d.get("choice", "")):
		return
	c.wish = d.choice
	c.wish_why = d.get("why", "")
	c.wish_until = c.world.now() + WISH_HOURS * 3600.0


# How much choose_action() likes an option with this key (object name, "cooking", "social").
static func wish_factor(c: Node2D, key: String) -> float:
	return WISH_BOOST if c.wish == key and c.world.now() < c.wish_until else 1.0


static func wish_text(c: Node2D) -> String:
	if c.wish == "" or c.world.now() >= c.wish_until:
		return ""
	var what: String = {"cooking": "cook something", "social": "be with people"}.get(c.wish, "use the " + c.wish)
	return what + (" (%s)" % c.wish_why if c.wish_why != "" else "")


# --- You talking to someone (talk_panel.gd) ---

static func can_talk(you: Node2D, other: Node2D) -> bool:
	return Ages.stage(you) >= Ages.CHILD and Ages.stage(other) >= Ages.CHILD and not other.at_work and not other.dead \
		and other.floor == you.floor and other.grid_pos.distance_to(you.grid_pos) <= TALK_RADIUS


# history: [{you: bool, text}], newest last (the last one is what you just typed).
# on_reply gets {reply, tone}: tone is how your message came across ("nice", "neutral", "mean").
func talk(npc: Node2D, you: Node2D, history: Array, on_reply: Callable) -> bool:
	var system := "\n".join([STYLE, "You are %s. Stay in character and answer the person talking to you." % npc.npc_name,
		"You: " + who(npc), relation(npc, you), "The other person: " + who(you, npc).split(";")[0] + ".", setting(npc),
		"Also rate how their last message came across to you: nice, neutral or mean."])
	var messages := [{"role": "system", "content": system}]
	for h in history.slice(maxi(0, history.size() - 10)):
		messages.append({"role": "user" if h.you else "assistant", "content": h.text})
	var schema := {"type": "object", "properties": {"reply": {"type": "string"}, "tone": {"type": "string", "enum": TONE.keys()}},
		"required": ["reply", "tone"]}
	return ask(messages, 100, schema, on_reply, true)


# What one message you typed does: their friendship toward you by its tone, a little social for both.
static func apply_tone(npc: Node2D, you: Node2D, tone: String) -> void:
	Social.change_friendship(npc, you, TONE.get(tone, 0.0))
	for c in [npc, you]:
		c.needs.social = clampf(c.needs.social + TALK_SOCIAL, 0.0, 100.0)
