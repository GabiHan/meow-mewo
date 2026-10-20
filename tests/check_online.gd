# Online mode end to end: starts a host (tests/online_host.gd) as a second headless process, joins it
# over 127.0.0.1 as Alex's family, and checks the joined game. Run from the project folder:
#   godot --headless -s res://tests/check_online.gd
# (no --fixed-fps: both sides run in real time). Exits with code 1 if any check fails.
extends SceneTree

const Net = preload("res://scripts/net.gd")
const Session = preload("res://scripts/session.gd")
const Npc = preload("res://scripts/npc.gd")
const Ages = preload("res://scripts/ages.gd")

var host_pid := -1
var net: Node
var main: Node2D
var t := 0.0
var phase := "connect"
var phase_at := 0.0
var next_try := 2.0
var failures := 0
var offer := []
var start_clock := 0.0
var start_pos := Vector2.ZERO


func _initialize() -> void:
	host_pid = OS.create_process(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"-s", "res://tests/online_host.gd"])
	check(host_pid > 0, "started a host process")
	net = Net.create(self)
	net.offered.connect(func(list, _starter): offer = list)
	net.joined.connect(func(): phase = "joined")


func check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)
	if not ok:
		failures += 1


func person(name: String) -> Node2D:
	return main.controller.person(name)


func goto(p: String) -> void:
	phase = p
	phase_at = t


func _process(delta: float) -> bool:
	t += delta
	if t > 60.0:
		check(false, "finished in time (stuck in phase %s)" % phase)
		return finish()
	match phase:
		"connect":
			if not offer.is_empty():
				var jo_sam: Array = offer.filter(func(h): return h.home == 0)
				var alex: Array = offer.filter(func(h): return h.home == 1)
				check(not jo_sam.is_empty() and jo_sam[0].taken, "the host plays Jo & Sam (taken)")
				check(not alex.is_empty() and not alex[0].taken and "Alex" in alex[0].members, "Alex's family is free: %s" % [alex])
				net.claim.rpc_id(1, 1, {})
				goto("claiming")
			elif t >= next_try:  # the host takes a few seconds to start
				next_try = t + 2.0
				net.join("127.0.0.1")
		"joined":
			check(Session.online == "client" and Session.controlled == "Alex", "joined as Alex (%s)" % Session.controlled)
			main = load("res://scenes/main.tscn").instantiate()
			root.add_child(main)
			goto("playing")
		"playing":
			if t - phase_at < 3.0:
				return false
			var alex := person("Alex")
			check(Npc.puppet and main.player == alex and alex.controlled, "in the joined game you control Alex; people are puppets")
			check(main.get_tree().get_nodes_in_group("characters").size() == 7, "the whole town is there (7 people)")
			check(person("Jo").human and not person("Mia").human, "Jo is a real person (the host), Mia isn't")
			check(main.world.clock > 0.0, "the clock comes from the host (%.1f)" % main.world.clock)
			check(net.status_text().begins_with("Online: 2 players"), "HUD: %s" % net.status_text())
			start_clock = main.world.clock
			start_pos = alex.grid_pos
			var target: Vector2i = main.world.random_walkable_near(alex.cell(), alex.floor, 3)
			while target == alex.cell():
				target = main.world.random_walkable_near(alex.cell(), alex.floor, 3)
			Net.order(main, "click", [{"kind": "tile", "cell": target}])
			goto("walked")
		"walked":
			if t - phase_at < 3.0:
				return false
			var alex := person("Alex")
			check(alex.grid_pos.distance_to(start_pos) > 0.5, "clicking a tile: the host walks Alex there (%s → %s)" % [start_pos, alex.grid_pos])
			check(main.world.clock > start_clock, "time keeps coming from the host")
			Net.order(main, "click", [{"kind": "person", "name": "Mia"}])
			goto("menu")
		"menu":
			if t - phase_at < 1.5:
				return false
			var menu: PopupMenu = main.controller.menu
			var labels := []
			for n in menu.item_count:
				labels.append(menu.get_item_text(n))
			check(menu.item_count > 3 and labels.any(func(l): return l == "Chat"), "clicking Mia: the host's menu shows up here (%d items)" % menu.item_count)
			var mia := person("Mia")
			Net.order(main, "click", [{"kind": "tile", "cell": main.world.free_neighbor(mia.cell(), mia.floor, person("Alex").cell())}])
			goto("go to Mia")
		"go to Mia":
			if t - phase_at < 4.0:
				return false
			main.hud.talk.open(person("Alex"), person("Mia"))
			goto("talk")
		"talk":
			if t - phase_at < 1.5:
				return false
			check(person("Mia").partner == person("Alex") and person("Mia").state == "talking", "Talk…: Mia stops to talk with Alex on the host")
			main.hud.talk.send("Hi sweetie, how was school?")
			goto("sent")
		"sent":
			if t - phase_at < 1.5:
				return false
			var history: Array = main.hud.talk.history
			check(history.size() == 2 and "AI is off" in history[1].text, "Mia answers (the host's AI is off in tests): %s" % [history])
			check(main.hud.chat.any(func(e): return e.who == person("Alex") and "how was school" in e.text), "what you said comes back in the chat feed")
			main.hud.talk.close()
			goto("closed")
		"closed":
			if t - phase_at < 1.5:
				return false
			check(person("Mia").partner == null and person("Alex").known.has("Mia"), "closing the talk on the host: done, and you know each other")
			return finish()
	return false


func finish() -> bool:
	if host_pid > 0:
		OS.kill(host_pid)
	print("\n%s (%d failure%s)" % ["ALL PASSED" if failures == 0 else "FAILED", failures, "" if failures == 1 else "s"])
	quit(1 if failures > 0 else 0)
	return true
