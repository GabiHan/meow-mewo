# The home screen (scenes/menu.tscn, the game's first scene). Built in code like everything else.
#
#   Play Game    -> Create a new household (name it, add up to 4 people) | Choose a household
#   Continue     -> loads the most recent save
#   Saved Games  -> every save: Load / Delete
#   Quit
# Starting a game fills in session.gd and switches to scenes/main.tscn.
extends Control

const UiTheme = preload("res://scripts/ui_theme.gd")
const SaveGame = preload("res://scripts/save_game.gd")
const Session = preload("res://scripts/session.gd")
const Looks = preload("res://scripts/looks.gd")
const Traits = preload("res://scripts/traits.gd")
const Main = preload("res://scripts/main.gd")

const MAX_MEMBERS := 4
const AGES := ["Child", "Teen", "Young adult", "Adult", "Old"]
const TAKEN_NAMES := ["Jo", "Sam", "Alex", "Mia", "Lily", "Riley", "Noah", "You"]  # people already on the street
const PINK := Color(0.653, 0.544, 0.565)  # titles

var page: VBoxContainer  # the centre column, rebuilt for each page
var members := []  # create page: one Dictionary of controls per person
var household_edit: LineEdit
var error_label: Label


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	RenderingServer.set_default_clear_color(Color("#d8d8e9"))
	Engine.time_scale = 1.0
	build_background()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	page = VBoxContainer.new()
	page.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_theme_constant_override("separation", 12)
	center.add_child(page)
	show_title()


# Soft gradient, floating pastel circles, and a few of the characters standing at the bottom.
func build_background() -> void:
	var gradient := Gradient.new()
	gradient.set_color(0, Color("#c9def4"))  # the palette, top to bottom (ui_theme.gd)
	gradient.set_color(1, Color("#f5ccd4"))
	for n in range(1, 6):
		gradient.add_point(n / 6.0, UiTheme.PALETTE[n])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_to = Vector2(0, 1)
	var bg := TextureRect.new()
	bg.texture = texture
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for n in 14:
		var bubble := Panel.new()
		var size := rng.randf_range(40, 160)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(UiTheme.PALETTE[(n * 3) % 7].lightened(0.35), 0.55)
		style.set_corner_radius_all(int(size))
		bubble.add_theme_stylebox_override("panel", style)
		bubble.position = Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 720)) - Vector2.ONE * size / 2
		bubble.size = Vector2.ONE * size
		bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bubble)
	var looks := ["alex", "jo", "sam", "mia", "riley"]
	for n in looks.size():
		var sheet := Looks.sheet(looks[n])
		if sheet == null:
			continue
		var person := TextureRect.new()
		person.texture = Looks.portrait(looks[n])
		person.scale = Vector2.ONE * 1.8
		person.position = Vector2([70, 230, 920, 1080, 1180][n] - 86, 520)
		person.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(person)


func clear_page() -> void:
	for child in page.get_children():
		child.queue_free()
	members = []


func title_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", PINK)
	label.add_theme_color_override("font_outline_color", Color.WHITE)
	label.add_theme_constant_override("outline_size", size / 4)
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
	title_label("Meow Mewo", 72)
	small_label("a cozy little life sim")
	page.add_child(Control.new())
	button("Play Game", show_play)
	var latest := SaveGame.latest()
	var cont := button("Continue", continue_game)
	cont.disabled = latest == ""
	if latest != "":
		var meta: Dictionary = SaveGame.read(latest).meta
		cont.tooltip_text = "%s — %s, %s" % [meta.household, meta.date, meta.time]
		small_label("%s · %s %s" % [meta.household, meta.date, meta.time])
	button("Saved Games", show_saves)
	button("Quit", func(): get_tree().quit())


func show_play() -> void:
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
	button("Back", show_play, 200)


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
	Session.reset()
	Session.mode = "new"
	Session.new_household = spec
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func start_household(home: int) -> void:
	Session.reset()
	Session.household = home
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func continue_game() -> void:
	load_game(SaveGame.latest())


func load_game(slot: String) -> void:
	var data := SaveGame.read(slot)
	if data.is_empty():
		return
	Session.reset()
	Session.mode = "load"
	Session.save_data = data
	Session.slot = slot
	get_tree().change_scene_to_file("res://scenes/main.tscn")
