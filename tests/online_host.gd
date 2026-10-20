# The host for tests/check_online.gd: hosts Jo & Sam's town headless (started by that test as a
# second process). Quits by itself after a minute in case the test doesn't stop it.
extends SceneTree

const Session = preload("res://scripts/session.gd")

var t := 0.0
var cleared := false


func _initialize() -> void:
	Session.reset()
	Session.online = "host"
	root.add_child(load("res://scenes/main.tscn").instantiate())


func _process(delta: float) -> bool:
	t += delta
	if not cleared:
		cleared = true
		for c in get_nodes_in_group("characters"):
			c.job = ""  # nobody leaves for work or school during the test
			c.at_work = false
	return t > 60.0
