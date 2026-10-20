# The home screen (scenes/menu.tscn, the game's first scene). Built in code like everything else.
# Left: the key art (key_art.gd), or the page you opened. Right: "A life simulation", the title, the menu,
# then "Loading the neighbourhood…" (the game scene loads in the background) and the version (project.godot).
# The home-screen song plays (music.gd).
#
#   Play Game    -> Create a new household (name it, add up to 4 people) | Choose a household  (offline)
#   Play Online  -> Host a town (pick or create a household, or continue: others on your Wi-Fi can join)
#                 | Join a town (towns on the Wi-Fi, or type an address -> pick a free household or move a new one in)
#   Continue     -> loads the most recent save
#   Saved Games  -> every save: Load / Delete
#   Settings     -> volume, music, sounds, mute, fullscreen (settings_panel.gd)
#   Quit
# Starting a game fills in session.gd and switches to scenes/main.tscn.
extends Control

const UiTheme = preload("res://scripts/ui_theme.gd")
const SaveGame = preload("res://scripts/save_game.gd")
const Session = preload("res://scripts/session.gd")
const Looks = preload("res://scripts/looks.gd")
const Traits = preload("res://scripts/traits.gd")
const Main = preload("res://scripts/main.gd")
const Net = preload("res://scripts/net.gd")
const Music = preload("res://scripts/music.gd")
const KeyArt = preload("res://scripts/key_art.gd")
const SettingsPanel = preload("res://scripts/settings_panel.gd")
const GAME_SCENE := "res://scenes/main.tscn"
const SIDE_WIDTH := 330
const MARGIN := 24

const MAX_MEMBERS := 4
const AGES := ["Child", "Teen", "Young adult", "Adult", "Old"]
const TAKEN_NAMES := ["Jo", "Sam", "Alex", "Mia", "Lily", "Riley", "Noah", "You"]  # people already on the street

var page: VBoxContainer  # the page you opened (left side), rebuilt for each page
var key_art: Control  # the picture on the left when no page is open (key_art.gd)
var card: ScrollContainer  # holds `page`
var continue_button: Button
var notice_label: Label  # e.g. "The host closed the town."
var loading_label: Label
var loading_pct: Label
var loading_bar: ProgressBar
var loaded := false
var members := []  # create page: one Dictionary of controls per person
var household_edit: LineEdit
var error_label: Label
var hosting := false  # the household you start will be hosted online
var joining := false  # the household you create moves into someone else's town
var status_label: Label  # join pages: connecting, errors
var towns_box: VBoxContainer


func _exit_tree() -> void:
	UiTheme.release()


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	RenderingServer.set_default_clear_color(UiTheme.PAPER)
	Engine.time_scale = 1.0
	Music.play(get_tree(), "menu")
	ResourceLoader.load_threaded_request(GAME_SCENE)  # "Loading the neighbourhood…" while you choose
	build_layout()
	show_title()


# Like the mockup: the picture (or the page you opened) on the left, the title and the menu on the right.
func build_layout() -> void:
	var paper := ColorRect.new()
	paper.color = UiTheme.PAPER
	paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(paper)

	var left := Control.new()
	left.set_anchors_preset(Control.PRESET_FULL_RECT)
	left.offset_left = MARGIN
	left.offset_top = MARGIN
	left.offset_bottom = -MARGIN
	left.offset_right = -SIDE_WIDTH - MARGIN
	add_child(left)
	key_art = KeyArt.new()
	key_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	left.add_child(key_art)
	card = ScrollContainer.new()  # sub-pages show here, over the picture's place
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(card)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(center)
	page = VBoxContainer.new()
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override("separation", 12)
	center.add_child(page)

	var rule := ColorRect.new()  # the thin line between the picture and the menu
	rule.color = UiTheme.LINE
	rule.anchor_left = 1.0
	rule.anchor_right = 1.0
	rule.anchor_bottom = 1.0
	rule.offset_left = -SIDE_WIDTH
	rule.offset_right = -SIDE_WIDTH + 1
	add_child(rule)
	var side := VBoxContainer.new()
	side.anchor_left = 1.0
	side.anchor_right = 1.0
	side.anchor_bottom = 1.0
	side.offset_left = -SIDE_WIDTH + 40
	side.offset_right = -40
	side.offset_top = 52
	side.offset_bottom = -28
	side.add_theme_constant_override("separation", 10)
	add_child(side)
	var kicker := Label.new()
	kicker.text = "A   L I F E   S I M U L A T I O N"
	kicker.add_theme_font_size_override("font_size", 12)
	kicker.add_theme_color_override("font_color", UiTheme.ACCENT)
	side.add_child(kicker)
	var title := RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.add_theme_font_override("normal_font", UiTheme.font())
	title.add_theme_font_override("italics_font", UiTheme.font(true))
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.add_theme_font_size_override("normal_font_size", 46)
	title.add_theme_font_size_override("italics_font_size", 46)
	title.add_theme_color_override("default_color", UiTheme.INK)
	title.text = "Meow [i]Mewo[/i]"
	side.add_child(title)
	var accent := ColorRect.new()
	accent.color = UiTheme.ACCENT
	accent.custom_minimum_size = Vector2(52, 1)
	accent.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	side.add_child(accent)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	side.add_child(gap)
	nav_button(side, "Play game", "▷", show_play, "primary")
	nav_button(side, "Play online", "◎", show_online)
	continue_button = nav_button(side, "Continue", "›", continue_game)
	nav_button(side, "Saved games", "▤", show_saves)
	nav_button(side, "Settings", "⚙", show_settings)
	nav_button(side, "Quit", "↦", func(): get_tree().quit(), "quiet")
	notice_label = Label.new()
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.add_theme_font_override("font", UiTheme.font(true))
	notice_label.add_theme_font_size_override("font_size", 13)
	notice_label.add_theme_color_override("font_color", UiTheme.ROSE.darkened(0.25))
	side.add_child(notice_label)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(fill)
	var loading_row := HBoxContainer.new()
	side.add_child(loading_row)
	loading_label = Label.new()
	loading_label.add_theme_font_override("font", UiTheme.font(true))
	loading_label.add_theme_font_size_override("font_size", 13)
	loading_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	loading_row.add_child(loading_label)
	loading_pct = Label.new()
	loading_pct.add_theme_font_size_override("font_size", 13)
	loading_row.add_child(loading_pct)
	loading_bar = ProgressBar.new()
	loading_bar.show_percentage = false
	loading_bar.custom_minimum_size = Vector2(0, 3)
	side.add_child(loading_bar)
	var version := Label.new()
	version.text = "v " + str(ProjectSettings.get_setting("application/config/version", "0.0.1"))
	version.add_theme_font_size_override("font_size", 12)
	version.modulate = Color(1, 1, 1, 0.6)
	side.add_child(version)


# A menu button: the name on the left, a small sign on the right. "primary" is outlined in the
# accent (Play game), "quiet" is just accent text (Quit).
func nav_button(parent: Container, text: String, sign: String, action: Callable, kind := "") -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 42)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(action)
	if kind == "primary":
		b.add_theme_stylebox_override("normal", UiTheme.flat(UiTheme.PAPER, UiTheme.ACCENT))
		b.add_theme_color_override("font_color", UiTheme.ACCENT.darkened(0.25))
	elif kind == "quiet":
		for state in ["normal", "hover", "pressed"]:
			var none := StyleBoxEmpty.new()
			none.content_margin_left = 12
			b.add_theme_stylebox_override(state, none)
		b.add_theme_color_override("font_color", UiTheme.ACCENT.darkened(0.25))
		b.add_theme_color_override("font_hover_color", UiTheme.ACCENT)
	var mark := Label.new()
	mark.text = sign
	mark.anchor_left = 1.0
	mark.anchor_right = 1.0
	mark.anchor_bottom = 1.0
	mark.offset_left = -34
	mark.offset_right = -12
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.add_theme_color_override("font_color", UiTheme.ACCENT.darkened(0.15) if kind != "" else UiTheme.INK_SOFT)
	b.add_child(mark)
	parent.add_child(b)
	return b


func _process(_delta: float) -> void:
	var progress := []
	var status := ResourceLoader.load_threaded_get_status(GAME_SCENE, progress)
	var done := status == ResourceLoader.THREAD_LOAD_LOADED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE \
		or status == ResourceLoader.THREAD_LOAD_FAILED or loaded
	if status == ResourceLoader.THREAD_LOAD_LOADED and not loaded:
		loaded = true
		ResourceLoader.load_threaded_get(GAME_SCENE)  # collect it (it stays cached for when you start)
	var k: float = 1.0 if done else (progress[0] if not progress.is_empty() else 0.0)
	loading_bar.value = k * 100.0
	loading_pct.text = "%d%%" % int(k * 100.0)
	loading_label.text = "The neighbourhood is ready ✿" if done else "Loading the neighbourhood…"


func clear_page() -> void:
	for child in page.get_children():
		child.queue_free()
	members = []
	key_art.visible = false  # a page takes the picture's place
	card.visible = true


func title_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", UiTheme.INK)
	page.add_child(label)
	return label


func button(text: String, action: Callable, width := 320) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(width, 48)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(action)
	page.add_child(b)
	return b


func small_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.modulate = Color(1, 1, 1, 0.75)
	page.add_child(label)
	return label


# --- Pages ---

func show_title() -> void:
	clear_page()
	card.visible = false
	key_art.visible = true
	hosting = false
	joining = false
	var latest := SaveGame.latest()
	continue_button.disabled = latest == ""
	continue_button.tooltip_text = ""
	if latest != "":
		var meta: Dictionary = SaveGame.read(latest).meta
		continue_button.tooltip_text = "%s — %s, %s" % [meta.household, meta.date, meta.time]
	notice_label.text = Session.notice
	Session.notice = ""


func show_settings() -> void:
	clear_page()
	title_label("Settings", 40)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	page.add_child(box)
	SettingsPanel.build(box)
	button("Back", show_title, 200)


func show_play() -> void:
	hosting = false
	joining = false
	clear_page()
	title_label("Play", 44)
	button("Create a new household", show_create)
	button("Choose a household", show_households)
	button("Back", show_title, 200)


func show_households() -> void:
	clear_page()
	title_label("Choose a household", 40)
	for h in Main.HOUSEHOLDS:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(560, 0)
		page.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		card.add_child(row)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var name := Label.new()
		name.text = h.name
		name.add_theme_font_size_override("font_size", 22)
		text.add_child(name)
		var about := Label.new()
		about.text = h.about
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		about.custom_minimum_size = Vector2(380, 0)
		text.add_child(about)
		var play := Button.new()
		play.text = "Play"
		play.custom_minimum_size = Vector2(110, 44)
		play.pressed.connect(start_household.bind(h.home))
		row.add_child(play)
	button("Back", show_play, 200)


func show_saves() -> void:
	clear_page()
	title_label("Saved Games", 40)
	var saves := SaveGame.list()
	if saves.is_empty():
		small_label("No saved games yet. In a game: Menu → Save game.")
	for s in saves:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(600, 0)
		page.add_child(card)
		var row := HBoxContainer.new()
		card.add_child(row)
		var info := Label.new()
		info.text = "%s\\n%s %s · $%d · saved %s" % [s.meta.household, s.meta.date, s.meta.time, s.meta.money, s.meta.saved_at]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var load_button := Button.new()
		load_button.text = "Load"
		load_button.pressed.connect(load_game.bind(s.slot))
		row.add_child(load_button)
		var delete := Button.new()
		delete.text = "Delete"
		delete.pressed.connect(func():
			SaveGame.delete(s.slot)
			show_saves())
		row.add_child(delete)
	button("Back", show_title, 200)


# --- Create a household ---

func show_create() -> void:
	clear_page()
	title_label("New household", 40)
	household_edit = LineEdit.new()
	household_edit.placeholder_text = "Household name (e.g. The Meows)"
	household_edit.custom_minimum_size = Vector2(420, 40)
	page.add_child(household_edit)
	var list := VBoxContainer.new()
	list.name = "Members"
	page.add_child(list)
	add_member(list)
	var add := button("+ Add a person", func(): add_member(list), 220)
	add.name = "Add"
	error_label = small_label("")
	error_label.add_theme_color_override("font_color", Color(0.85, 0.3, 0.45))
	button("Move in!", move_in)
	button("Back", show_online if hosting or joining else show_play, 200)


func add_member(list: VBoxContainer) -> void:
	if members.size() >= MAX_MEMBERS:
		return
	var card := PanelContainer.new()
	list.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var m := {"card": card}
	m.name = LineEdit.new()
	m.name.placeholder_text = "Name"
	m.name.custom_minimum_size = Vector2(120, 36)
	row.add_child(m.name)
	m.sex = option(row, ["Female", "Male"])
	m.age = option(row, AGES)
	m.age.select(2)
	m.look = option(row, [])
	m.preview = TextureRect.new()
	m.preview.custom_minimum_size = Vector2(48, 56)
	m.preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	m.preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(m.preview)
	m.look.item_selected.connect(func(_i): m.preview.texture = Looks.portrait(m.look.get_item_metadata(m.look.selected)))
	m.traits = [option(row, ["(trait)"] + Traits.TRAITS.keys()), option(row, ["(trait)"] + Traits.TRAITS.keys()),
		option(row, ["(trait)"] + Traits.TRAITS.keys())]
	var remove := Button.new()
	remove.text = "×"
	remove.pressed.connect(func():
		members.erase(m)
		card.queue_free())
	row.add_child(remove)
	m.sex.item_selected.connect(func(_i): fill_looks(m))
	fill_looks(m)
	members.append(m)


func option(row: HBoxContainer, items: Array) -> OptionButton:
	var o := OptionButton.new()
	for item in items:
		o.add_item(item)
	row.add_child(o)
	return o


# Looks of the chosen sex (looks.gd).
func fill_looks(m: Dictionary) -> void:
	var sex := "F" if m.sex.selected == 0 else "M"
	m.look.clear()
	for look in Looks.LOOKS:
		if Looks.LOOKS[look].body == sex:
			m.look.add_item(Looks.LOOKS[look].label)
			m.look.set_item_metadata(m.look.item_count - 1, look)
	m.look.select(0)
	m.preview.texture = Looks.portrait(m.look.get_item_metadata(0))


# The household described by the create page, or {} (and an error shown) if something's wrong.
func read_household() -> Dictionary:
	var name := household_edit.text.strip_edges()
	var people := []
	var names := {}
	for m in members:
		var person := {"name": m.name.text.strip_edges(), "sex": "F" if m.sex.selected == 0 else "M",
			"stage": AGES[m.age.selected], "look": m.look.get_item_metadata(m.look.selected), "traits": []}
		for t in m.traits:
			var trait_name: String = t.get_item_text(t.selected)
			if t.selected > 0 and not trait_name in person.traits:
				person.traits.append(trait_name)
		if person.name == "":
			return fail("Every person needs a name.")
		if person.name in TAKEN_NAMES or names.has(person.name):
			return fail("%s is already taken: pick another name." % person.name)
		names[person.name] = true
		people.append(person)
	if name == "":
		return fail("Give your household a name.")
	if people.is_empty():
		return fail("Add at least one person.")
	if not people.any(func(p): return p.stage in ["Young adult", "Adult", "Old"]):
		return fail("A household needs at least one grown-up (young adult or older).")
	return {"name": name, "members": people}


func fail(message: String) -> Dictionary:
	error_label.text = message
	return {}


# --- Starting ---

func move_in() -> void:
	var spec := read_household()
	if spec.is_empty():
		return
	if joining:
		error_label.text = "Moving in…"
		Net.find(get_tree()).claim.rpc_id(1, -1, spec)
		return
	Session.reset()
	Session.online = "host" if hosting else ""
	Session.mode = "new"
	Session.new_household = spec
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func start_household(home: int) -> void:
	Session.reset()
	Session.online = "host" if hosting else ""
	Session.household = home
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func continue_game() -> void:
	load_game(SaveGame.latest())


func load_game(slot: String) -> void:
	var data := SaveGame.read(slot)
	if data.is_empty():
		return
	Session.reset()
	Session.online = "host" if hosting else ""
	Session.mode = "load"
	Session.save_data = data
	Session.slot = slot
	get_tree().change_scene_to_file("res://scenes/main.tscn")


# --- Online (net.gd, docs/ONLINE.md) ---

func show_online() -> void:
	hosting = false
	joining = false
	var net := Net.find(get_tree())
	if net:
		net.leave()
	clear_page()
	title_label("Play Online", 44)
	small_label("Play live with friends on the same Wi-Fi.\nThe host's computer runs the town (and the AI); everyone plays their own household.")
	button("Host a town", show_host)
	button("Join a town", show_join)
	button("Back", show_title, 200)


func show_host() -> void:
	clear_page()
	hosting = true
	title_label("Host a town", 40)
	small_label("Pick the household you'll play. Friends can join once you're in.")
	button("Choose a household", show_households)
	button("Create a new household", show_create)
	var cont := button("Continue your last save", continue_game)
	cont.disabled = SaveGame.latest() == ""
	button("Back", show_online, 200)


func show_join() -> void:
	clear_page()
	var net := Net.create(get_tree())
	net.listen()
	if not net.towns_changed.is_connected(fill_towns):
		net.towns_changed.connect(fill_towns)
		net.offered.connect(show_join_households)
		net.failed.connect(show_status)
		net.joined.connect(func(): get_tree().change_scene_to_file("res://scenes/main.tscn"))
	title_label("Join a town", 40)
	small_label("Towns on your Wi-Fi:")
	towns_box = VBoxContainer.new()
	page.add_child(towns_box)
	fill_towns()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(row)
	var address := LineEdit.new()
	address.placeholder_text = "or the host's address (e.g. 192.168.1.20)"
	address.custom_minimum_size = Vector2(320, 40)
	row.add_child(address)
	var go := Button.new()
	go.text = "Join"
	go.pressed.connect(func(): join(address.text.strip_edges()))
	row.add_child(go)
	status_label = small_label("")
	button("Back", show_online, 200)


func show_status(text: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = text
	if is_instance_valid(error_label):
		error_label.text = text


func fill_towns() -> void:
	if not is_instance_valid(towns_box):
		return
	for child in towns_box.get_children():
		child.queue_free()
	var towns: Dictionary = Net.find(get_tree()).towns
	if towns.is_empty():
		var none := Label.new()
		none.text = "Looking… (the host must be in a game they started from Host a town)"
		none.modulate = Color(1, 1, 1, 0.7)
		towns_box.add_child(none)
	for ip in towns:
		var t: Dictionary = towns[ip]
		var b := Button.new()
		b.text = "%s's town · %d/%d players · %s" % [t.name, t.players, t.max, ip]
		b.custom_minimum_size = Vector2(480, 44)
		b.disabled = t.players >= t.max
		b.pressed.connect(join.bind(ip))
		towns_box.add_child(b)


func join(ip: String) -> void:
	if ip == "":
		return
	show_status("Connecting to %s…" % ip)
	Net.find(get_tree()).join(ip)


# The host's households: play a free one, or move a new household into their starter house.
func show_join_households(households: Array, starter_free: bool) -> void:
	clear_page()
	title_label("Pick your household", 40)
	for h in households:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(560, 0)
		page.add_child(card)
		var row := HBoxContainer.new()
		card.add_child(row)
		var info := Label.new()
		info.text = "%s\n%s" % [h.name, h.members]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var play := Button.new()
		play.text = "Someone's playing" if h.taken else "Play"
		play.disabled = h.taken
		play.custom_minimum_size = Vector2(150, 44)
		play.pressed.connect(claim.bind(h.home))
		row.add_child(play)
	var new_household := button("Move a new household in", start_joining_household, 360)
	new_household.disabled = not starter_free
	if not starter_free:
		new_household.tooltip_text = "Someone already lives in the starter house"
	status_label = small_label("")
	button("Back", show_online, 200)


func claim(home: int) -> void:
	show_status("Moving in…")
	Net.find(get_tree()).claim.rpc_id(1, home, {})


func start_joining_household() -> void:
	joining = true
	show_create()
