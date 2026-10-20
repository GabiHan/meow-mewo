# What the home screen (menu.gd) asked the game (main.gd) to start. Static, so it survives the
# change of scene. With nothing set (tests, or running main.tscn directly) you play Jo & Sam.
#
#   mode "household": play an existing household (`household` = its home building)
#   mode "new":       move a newly created household into the starter house (`new_household`)
#   mode "load":      continue a saved game (`save_data` from save_game.gd)
# `slot` is the save file the game saves to (Menu → Save); "" until the first save.
# Online (net.gd): `online` is "host" (host the town you start) or "client" (a joined town: save_data is
# the host's snapshot, `controlled` who you play, `online_household` your household's name).
# `notice` is shown on the home screen once (e.g. "The host closed the town").
static var mode := "household"
static var household := 0
static var new_household := {}
static var save_data := {}
static var slot := ""
static var online := ""
static var controlled := ""
static var online_household := ""
static var notice := ""


static func reset() -> void:
	mode = "household"
	household = 0
	new_household = {}
	save_data = {}
	slot = ""
	online = ""
	controlled = ""
	online_household = ""
