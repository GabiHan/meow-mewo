# Online mode: play live with other people on the same Wi-Fi. Lives at /root/Net while you're online
# (made by the home screen to join, or by main.gd to host); offline it doesn't exist and the game runs
# exactly as before. Full documentation: docs/ONLINE.md.
#
# One computer HOSTS a town: it runs the whole simulation (everyone's needs, the AI, the language
# model) as usual. Others JOIN it and take a free household (or move a new one into the starter
# house). A joined game is a mirror: it starts from a snapshot of the town (save_game.gd capture) and
# then only shows what the host sends (npc.gd `puppet`, world.gd `puppet`):
#   fast  (FAST_SECONDS, unreliable): the clock, game speed, and where everyone is and what they're doing
#   slow  (SLOW_SECONDS, reliable):   everyone's SAVE_FIELDS (needs, feelings, relationships, money...),
#                                     who's using what, kitchens, guests, the social log, the AI status
#   layout (when furniture changes):  all objects and props
#   heard (as it happens):            things people say (npc.gd show_emote → your chat feed)
# What a joined player does is an order (Net.order): a click (worked out on their screen: a person, a
# house, or a tile), a menu choice, Tab, switching household member, care, Talk…. The host carries it out
# with a Controller of its own for that player (controller.gd `peer`), and menus built there are sent to
# the player to choose from. Finding towns: the host shouts a beacon on the Wi-Fi every BEACON_SECONDS.
extends Node

const SaveGame = preload("res://scripts/save_game.gd")
const Session = preload("res://scripts/session.gd")
const Social = preload("res://scripts/social.gd")
const Talk = preload("res://scripts/talk.gd")
const Ages = preload("res://scripts/ages.gd")
const World = preload("res://scripts/world.gd")

const PORT := 8910
const DISCOVERY_PORT := 8911
const VERSION := 1  # both sides must match
const MAX_PLAYERS := 4  # the host and three more
const FAST_SECONDS := 0.1
const SLOW_SECONDS := 1.0
const BEACON_SECONDS := 1.0
const FOUND_SECONDS := 4.0  # a town that stops shouting disappears from the list
const PERSON_EXTRAS := ["thought", "thought_at", "wish", "wish_why", "wish_until", "napping", "pending_work"]

signal towns_changed  # the list of towns on the Wi-Fi changed (home screen)
signal offered(households: Array, starter_free: bool)  # the host's households arrived (home screen)
signal joined  # we're in: Session holds the snapshot, load the game
signal failed(reason: String)

var role := ""  # "host" or "client"
var main: Node2D
var players := {}  # host: peer id -> {controller, household, ready}
var towns := {}  # home screen: ip -> {name, players, seen (msec)}
var beacon: PacketPeerUDP
var listener: PacketPeerUDP
var fast_timer := 0.0
var slow_timer := 0.0
var beacon_timer := 0.0
var layout_key := 0  # hash of the objects and props: when it changes, joined players get the new layout


static func find(tree: SceneTree) -> Node:
	return tree.root.get_node_or_null("Net") if tree else null


static func create(tree: SceneTree) -> Node:
	var net := find(tree)
	if net == null:
		net = load("res://scripts/net.gd").new()
		net.name = "Net"
		tree.root.add_child(net)
	return net


static func is_client(tree: SceneTree) -> bool:
	var net := find(tree)
	return net != null and net.role == "client"


static func is_online(tree: SceneTree) -> bool:
	return find(tree) != null and find(tree).role != ""


# Do something as the person you control: here (offline / hosting), or on the host (joined).
static func order(game: Node2D, kind: String, args: Array) -> void:
	var net := find(game.get_tree())
	if net and net.role == "client":
		net.command.rpc_id(1, kind, args)
	else:
		run(game.controller, kind, args)


# Carry out an order for the person `ctl` controls (the local controller, or a joined player's).
static func run(ctl: Node, kind: String, args: Array) -> void:
	var body: Node2D = ctl.body
	if body == null or not is_instance_valid(body) or body.dead:
		return
	match kind:
		"click":
			ctl.do_click(args[0])
		"choice":
			ctl.choose(int(args[0]))
		"mode":
			body.toggle_mode()
		"control":
			var c: Node2D = ctl.person(str(args[0]))
			if c and c in ctl.household() and ctl.playable(c) and not c.controlled:
				ctl.take_control(c)
		"care":
			var child: Node2D = ctl.person(str(args[0]))
			var i: Array = Social.INTERACTIONS.filter(func(x): return x.name == args[1])
			if child and not i.is_empty():
				body.order_interaction(child, i[0])
		"talk_open":
			if not Talk.open(body, ctl.person(str(args[0]))):
				Talk.ui(body, "closed", [])
		"talk_send":
			Talk.say(body, str(args[0]), args[1])
		"talk_close":
			Talk.close(body)


# --- Hosting ---

func host(p_main: Node2D) -> bool:
	var enet := ENetMultiplayerPeer.new()
	if enet.create_server(PORT, MAX_PLAYERS - 1) != OK:
		return false
	multiplayer.multiplayer_peer = enet
	multiplayer.peer_disconnected.connect(_on_player_left)
	role = "host"
	main = p_main
	beacon = PacketPeerUDP.new()
	beacon.set_broadcast_enabled(true)
	beacon.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	return true


func player_count() -> int:
	return 1 + players.size()


# The households in the town: who lives there and whether someone is already playing them.
func household_list() -> Array:
	var homes := {}
	for c in main.get_tree().get_nodes_in_group("characters"):
		if c.home >= 0 and not c.dead:
			homes.get_or_add(c.home, []).append(c)
	var list := []
	for h in homes:
		var people: Array = homes[h]
		list.append({"home": h, "name": main.home_name(h), "taken": people.any(func(c): return c.controlled),
			"members": ", ".join(people.map(func(c): return "%s (%d)" % [c.npc_name, Ages.years(c)]))})
	list.sort_custom(func(a, b): return a.home < b.home)
	return list


@rpc("any_peer", "reliable")
func hello(version: int) -> void:
	var id := multiplayer.get_remote_sender_id()
	if version != VERSION:
		refused.rpc_id(id, "That town runs a different version of the game.")
	else:
		offer.rpc_id(id, household_list(), not household_list().any(func(h): return h.home == main.STARTER_HOUSE))


# A joining player picks a household (home >= 0) or moves a new one in (spec).
@rpc("any_peer", "reliable")
func claim(home: int, spec: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	if players.has(id):
		return
	var you: Node2D = null
	var name := ""
	if not spec.is_empty():
		if household_list().any(func(h): return h.home == main.STARTER_HOUSE):
			refused.rpc_id(id, "Someone already lives in the starter house.")
			return
		var taken := main.get_tree().get_nodes_in_group("characters").map(func(c): return c.npc_name)
		for m in spec.members:  # names must be unique in the town
			var base: String = m.name
			var n := 2
			while m.name in taken:
				m.name = "%s %d" % [base, n]
				n += 1
			taken.append(m.name)
		var before: Array = main.get_tree().get_nodes_in_group("characters")
		you = main.spawn_household(spec, false)
		var newcomers := main.get_tree().get_nodes_in_group("characters").filter(func(c): return not c in before)
		load("res://scripts/life.gd").setup_families(main, newcomers)
		name = spec.name
	else:
		var h: Array = household_list().filter(func(x): return x.home == home)
		if h.is_empty() or h[0].taken:
			refused.rpc_id(id, "Someone is already playing that household.")
			return
		var people := main.get_tree().get_nodes_in_group("characters").filter(func(c): return c.home == home and not c.dead \
			and Ages.stage(c) >= Ages.CHILD)
		people.sort_custom(func(a, b): return Ages.is_grown_up(a) and not Ages.is_grown_up(b) or a.age_days > b.age_days)
		if people.is_empty():
			refused.rpc_id(id, "Nobody there can be played.")
			return
		you = people[0]
		name = h[0].name
	var ctl: Node = load("res://scripts/controller.gd").new().setup(main, null)
	ctl.peer = id
	main.add_child(ctl)
	players[id] = {"controller": ctl, "household": name, "ready": false}
	ctl.take_control(you)
	Social.log_event("{a} came online", you, you)
	welcome.rpc_id(id, SaveGame.capture(main), you.npc_name, name)


@rpc("any_peer", "reliable")
func ready_to_play() -> void:
	var id := multiplayer.get_remote_sender_id()
	if players.has(id):
		players[id].ready = true


@rpc("any_peer", "reliable")
func command(kind: String, args: Array) -> void:
	var p: Dictionary = players.get(multiplayer.get_remote_sender_id(), {})
	if p.get("ready", false):
		run(p.controller, kind, args)


@rpc("any_peer", "reliable")
func want_layout() -> void:
	var objects: Array = main.get_tree().get_nodes_in_group("smart_objects").map(SaveGame.capture_object)
	layout.rpc_id(multiplayer.get_remote_sender_id(), layout_key, objects, SaveGame.capture_props(main.world), main.world.building_state())


func _on_player_left(id: int) -> void:
	var p: Dictionary = players.get(id, {})
	players.erase(id)
	if p.is_empty():
		return
	var body: Node2D = p.controller.body
	if body and is_instance_valid(body):
		if body.partner:
			Talk.close(body)
		body.controlled = false  # back to living on their own
		Social.log_event("{a} went offline", body, body)
	p.controller.queue_free()


func controller_of(c: Node2D) -> Node:
	for id in players:
		if players[id].controller.body == c:
			return players[id].controller
	return null


func peer_of(c: Node2D) -> int:
	for id in players:
		if players[id].controller.body == c:
			return id
	return 0


func ready_peers() -> Array:
	return players.keys().filter(func(id): return players[id].ready)


# Host → the player who controls `c`.
func send_menu(peer: int, headers: Array, entries: Array) -> void:
	var plain := []
	for e in entries:
		plain.append({"section": e.section} if e.has("section") else {"label": e.label, "disabled": e.get("disabled", false)})
	menu.rpc_id(peer, headers, plain)


func you_are_now(peer: int, c: Node2D) -> void:
	if players.get(peer, {}).get("ready", false):
		you_are.rpc_id(peer, c.npc_name)


func talk_ui(c: Node2D, method: String, args: Array) -> void:
	var peer := peer_of(c)
	if peer != 0:
		talk_event.rpc_id(peer, method, args.map(func(a): return {"person": a.npc_name} if a is Node2D else a))


func said(c: Node2D, text: String, with: Node2D, seconds: float) -> void:
	for id in ready_peers():
		heard.rpc_id(id, c.npc_name, text, with.npc_name if with else "", seconds)


func fast_state() -> Array:
	var people := []
	for c in main.get_tree().get_nodes_in_group("characters"):
		people.append([c.npc_name, c.grid_pos, c.floor, c.state, c.target_object.net_id if c.target_object else 0,
			c.step.get("asleep", false), c.step.get("seconds", 0.0), c.use_timer, c.partner.npc_name if c.partner else "",
			c.activity, c.activity_with.npc_name if c.activity_with else "", c.held, c.at_work, c.peek_window, c.auto_mode,
			c.controlled, c.pose, c.running])
	return [main.world.clock, Engine.time_scale, main.paused, people]


func slow_state() -> Dictionary:
	var people := []
	for c in main.get_tree().get_nodes_in_group("characters"):
		var person := SaveGame.capture_person(c)
		for field in PERSON_EXTRAS:
			person[field] = c.get(field)
		people.append(person)
	var objects := main.get_tree().get_nodes_in_group("smart_objects").map(func(o): return [o.net_id, \
		o.user.npc_name if o.user else "", o.items])
	return {"people": people, "objects": objects, "layout": layout_key, "kitchens": main.world.kitchens,
		"guests": main.world.guests, "weather": main.world.weather, "log": SaveGame.capture_log(), "ai": main.llm.status, "players": player_count()}


func compute_layout_key() -> int:
	var objects: Array = main.get_tree().get_nodes_in_group("smart_objects").map(func(o): return [o.net_id, o.grid_pos, o.facing, o.floor])
	return str([objects, SaveGame.capture_props(main.world), main.world.building_state()]).hash()


func host_update(delta: float) -> void:
	beacon_timer -= delta
	if beacon_timer <= 0.0:
		beacon_timer = BEACON_SECONDS
		beacon.put_packet(JSON.stringify({"game": "meow-mewo", "version": VERSION, "name": main.household_name,
			"players": player_count(), "max": MAX_PLAYERS}).to_utf8_buffer())
	var peers := ready_peers()
	if peers.is_empty():
		return
	fast_timer -= delta
	if fast_timer <= 0.0:
		fast_timer = FAST_SECONDS
		var state := fast_state()
		for id in peers:
			fast.rpc_id(id, state)
	slow_timer -= delta
	if slow_timer <= 0.0:
		slow_timer = SLOW_SECONDS
		layout_key = compute_layout_key()
		var state := slow_state()
		for id in peers:
			slow.rpc_id(id, state)


# --- Joining (home screen) ---

func listen() -> void:
	if listener:
		return
	listener = PacketPeerUDP.new()
	listener.bind(DISCOVERY_PORT)


func join(ip: String) -> void:
	var enet := ENetMultiplayerPeer.new()
	if enet.create_client(ip, PORT) != OK:
		failed.emit("Couldn't connect to %s." % ip)
		return
	multiplayer.multiplayer_peer = enet
	role = "client"
	if not multiplayer.connected_to_server.is_connected(_on_connected):
		multiplayer.connected_to_server.connect(_on_connected)
		multiplayer.connection_failed.connect(func(): fail("No town answered at that address."))
		multiplayer.server_disconnected.connect(_on_host_left)


func _on_connected() -> void:
	hello.rpc_id(1, VERSION)


func fail(reason: String) -> void:
	close_connection()
	failed.emit(reason)


@rpc("authority", "reliable")
func refused(reason: String) -> void:
	fail(reason)


@rpc("authority", "reliable")
func offer(households: Array, starter_free: bool) -> void:
	offered.emit(households, starter_free)


@rpc("authority", "reliable")
func welcome(data: Dictionary, controlled: String, household: String) -> void:
	Session.reset()
	Session.mode = "load"
	Session.save_data = data
	Session.online = "client"
	Session.controlled = controlled
	Session.online_household = household
	joined.emit()


# --- Playing in someone's town ---

# main.gd: the game has loaded from the snapshot.
func attach(p_main: Node2D) -> void:
	main = p_main
	if role == "client":
		ready_to_play.rpc_id(1)


@rpc("authority", "unreliable_ordered")
func fast(state: Array) -> void:
	if main == null or role != "client":
		return
	main.world.clock = state[0]
	Engine.time_scale = state[1]
	main.paused = state[2]
	for row in state[3]:
		var c: Node2D = main.controller.person(row[0])
		if c == null:
			continue
		c.net_target = row[1]
		if c.floor != row[2] or c.grid_pos.distance_to(row[1]) > 3.0:
			c.grid_pos = row[1]  # stairs, or too far behind: jump
		c.floor = row[2]
		c.state = row[3]
		c.target_object = object(row[4])
		c.step = {"asleep": row[5], "seconds": row[6]} if row[3] == "using" else {}
		c.use_timer = row[7]
		c.partner = main.controller.person(row[8])
		c.activity = row[9]
		c.activity_with = main.controller.person(row[10])
		c.held = row[11]
		c.at_work = row[12]
		c.peek_window = row[13]
		c.auto_mode = row[14]
		c.human = row[15]
		c.pose = row[16]
		c.running = row[17]


@rpc("authority", "reliable")
func slow(state: Dictionary) -> void:
	if main == null or role != "client":
		return
	var names := {}
	for person in state.people:
		names[person.npc_name] = true
		var c: Node2D = main.controller.person(person.npc_name)
		if c == null:  # born, or moved in
			c = SaveGame.make_person(main, person)
			c.net_target = person.grid_pos
		for field in person:
			if not field in ["grid_pos", "floor"]:
				c.set(field, person[field])
	for c in main.get_tree().get_nodes_in_group("characters"):
		if not names.has(c.npc_name):  # passed away
			c.dead = true
			c.visible = false
			c.remove_from_group("characters")
	for row in state.objects:
		var o := object(row[0])
		if o:
			o.user = main.controller.person(row[1])
			o.items = row[2]
	main.world.kitchens = state.kitchens
	main.world.guests = state.guests
	main.world.weather = state.get("weather", "Clear")
	Social.event_log.clear()
	for e in state.log:
		Social.event_log.append({"text": e[0], "a": main.controller.person(e[1]), "b": main.controller.person(e[2]),
			"a_name": e[1], "b_name": e[2]})
	main.llm.status = state.ai
	main.online_players = state.players
	if state.layout != layout_key:
		layout_key = state.layout
		want_layout.rpc_id(1)


# All objects and props, after furniture changed (or a grave appeared).
@rpc("authority", "reliable")
func layout(key: int, objects: Array, props: Array, buildings: Array) -> void:
	if main == null:
		return
	layout_key = key
	var world: Node2D = main.world
	world.apply_building_state(buildings)  # stairs built or removed: floors first
	var wanted := {}
	for o in objects:
		wanted[o.net_id] = o
	for o in main.get_tree().get_nodes_in_group("smart_objects"):
		var w: Dictionary = wanted.get(o.net_id, {})
		if w.is_empty() or w.pos != o.grid_pos or w.extras.facing != o.facing or w.floor != o.floor:
			o.remove_from_group("smart_objects")
			o.queue_free()
		else:
			wanted.erase(o.net_id)
	for id in wanted:
		SaveGame.make_object(world, wanted[id])
	for b in world.floor_nodes.size():
		for f in world.floor_nodes[b].size():
			for n in world.floor_nodes[b][f].get_children():
				if "flat" in n:
					n.queue_free()
	for p in props:
		SaveGame.make_prop(world, p)


@rpc("authority", "reliable")
func heard(who: String, text: String, with: String, seconds: float) -> void:
	var c: Node2D = main.controller.person(who) if main else null
	if c:
		c.show_emote(text, main.controller.person(with), seconds)


@rpc("authority", "reliable")
func menu(headers: Array, entries: Array) -> void:
	if main == null:
		return
	var n := 0
	var items := []
	for e in entries:
		if e.has("section"):
			items.append(e)
			continue
		var index := n
		items.append({"label": e.label, "disabled": e.disabled, "action": func(): command.rpc_id(1, "choice", [index])})
		n += 1
	main.controller.show_menu(headers, items)


@rpc("authority", "reliable")
func you_are(name: String) -> void:
	var c: Node2D = main.controller.person(name) if main else null
	if c:
		main.controller.take_control(c)


@rpc("authority", "reliable")
func talk_event(method: String, args: Array) -> void:
	if main == null:
		return
	main.hud.talk.callv(method, args.map(func(a): return main.controller.person(a.person) if a is Dictionary and a.has("person") else a))


func object(id: int) -> Node2D:
	if id == 0:
		return null
	for o in main.get_tree().get_nodes_in_group("smart_objects"):
		if o.net_id == id:
			return o
	return null


func _on_host_left() -> void:
	close_connection()
	if main and is_instance_valid(main):  # playing: back to the home screen, which says why
		Session.notice = "The host closed the town."
		Engine.time_scale = 1.0
		get_tree().change_scene_to_file("res://scenes/menu.tscn")
		leave()
	else:
		failed.emit("The host closed the town.")


# --- Every frame ---

func _process(delta: float) -> void:
	if role == "host" and main and is_instance_valid(main):
		host_update(delta)
	if listener:
		while listener.get_available_packet_count() > 0:
			var data = JSON.parse_string(listener.get_packet().get_string_from_utf8())
			var ip := listener.get_packet_ip()
			if data is Dictionary and data.get("game") == "meow-mewo":
				var fresh := not towns.has(ip)
				towns[ip] = {"name": data.get("name", "?"), "players": data.get("players", 1), "max": data.get("max", MAX_PLAYERS),
					"seen": Time.get_ticks_msec()}
				if fresh:
					towns_changed.emit()
		for ip in towns.keys():
			if Time.get_ticks_msec() - towns[ip].seen > FOUND_SECONDS * 1000.0:
				towns.erase(ip)
				towns_changed.emit()


func status_text() -> String:
	if role == "host":
		return "Online: hosting · %d/%d players · %s" % [player_count(), MAX_PLAYERS, ", ".join(local_ips())]
	if role == "client" and main:
		return "Online: %d players in this town" % main.online_players
	return ""


static func local_ips() -> Array:
	return Array(IP.get_local_addresses()).filter(func(a): return a.begins_with("192.168.") or a.begins_with("10.") \
		or a.begins_with("172."))


func close_connection() -> void:
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	role = ""


# Leaving (exit to menu, quit, back on the home screen): close everything and go away.
func leave() -> void:
	close_connection()
	if listener:
		listener.close()
	name = "NetClosed"  # so a new /root/Net can be made right away
	queue_free()
