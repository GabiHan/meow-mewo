# Background music. Lives at /root/Music (made once by the home screen or the game) so it keeps
# playing across scenes. Three tracks, crossfaded over FADE_SECONDS:
#   menu     the home screen               assets/music/home_screen.mp3
#   home     you're inside your own home   assets/music/at_home.mp3
#   outside  anywhere else                 assets/music/outside.mp3
#   build    in build mode                 assets/music/build_mode.mp3
# Fades run on real time, not game time, and the players ignore pause and game speed: speeding the
# game up (or pausing it) never changes the music. Volume: the Music bus (settings.gd).
extends Node

const Settings = preload("res://scripts/settings.gd")
const TRACKS := {
	"menu": "res://assets/music/home_screen.mp3",
	"home": "res://assets/music/at_home.mp3",
	"outside": "res://assets/music/outside.mp3",
	"build": "res://assets/music/build_mode.mp3",
}
const FADE_SECONDS := 2.0
const QUIET_DB := -40.0  # where a fade starts and ends

var players := []  # two AudioStreamPlayers: the one fading in and the one fading out
var current := ""  # track playing (or fading in)
var fade_start := 0  # msec


static var instance: Node  # the one music player (it's added to /root a moment after it's made)


static func ensure(tree: SceneTree) -> Node:
	if instance == null or not is_instance_valid(instance):
		instance = load("res://scripts/music.gd").new()
		instance.name = "Music"
		tree.root.add_child.call_deferred(instance)  # the root may be busy adding a scene right now
	return instance


# Switch to a track (crossfade). Nothing happens if it's already the one playing.
static func play(tree: SceneTree, track: String) -> void:
	ensure(tree).want(track)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps fading while the game is paused
	Settings.load_settings()
	for n in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = QUIET_DB
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		players.append(p)
	if current != "":  # asked for a track before we were in the tree
		var track := current
		current = ""
		want(track)


# Quitting: stop and let go of the songs (otherwise they're reported as still in use at exit).
func _exit_tree() -> void:
	for p in players:
		p.stop()
		p.stream = null
	instance = null


func want(track: String) -> void:
	if track == current or not TRACKS.has(track):
		return
	current = track
	if players.is_empty():
		return  # _ready starts it
	var stream: AudioStream = load(TRACKS[track])
	if stream is AudioStreamMP3:
		stream.loop = true
	players.reverse()  # the old one fades out, the other one fades in with the new song
	players[0].stream = stream
	players[0].volume_db = QUIET_DB
	players[0].play()
	fade_start = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	if players.is_empty() or current == "":
		return
	var k := clampf((Time.get_ticks_msec() - fade_start) / (FADE_SECONDS * 1000.0), 0.0, 1.0)
	players[0].volume_db = lerpf(QUIET_DB, 0.0, k)
	players[1].volume_db = lerpf(0.0, QUIET_DB, k)
	if k >= 1.0 and players[1].playing:
		players[1].stop()
