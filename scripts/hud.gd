# Screen-space UI:
#   footer band  full-width bar along the bottom: your feeling (colour per emotion, with reasons), your money and
#                the 7 need bars with values (red → amber → green; the value turns red below 25)
#   top-left     mode button, Relationships button (R), where you are, game speed, job, skills
#   left panel   a baby or toddler you clicked: their needs, feeling, parents and care buttons
#   household    (top-left, first row) everyone who lives in your home: click a name to control them
#                (babies and toddlers open their needs panel instead); the one you control is green
#   right drawer Relationships (toggle with the button or R): everyone you know of, with a friendship
#                bar, how they feel, where they are, traits (once met), invitations and memories of you
#   bottom-left  recent social events (Social.event_log), just above the footer
#   top-right    clock (hh:mm:ss), weekday, part of day, season / day / year, speed buttons
#   top-centre   "PAUSED" banner while paused
#   bottom-right controls cheat sheet, just above the footer
extends CanvasLayer

const Social = preload("res://scripts/social.gd")
const GameTime = preload("res://scripts/game_time.gd")
const Emotions = preload("res://scripts/emotions.gd")
const Skills = preload("res://scripts/skills.gd")
const Traits = preload("res://scripts/traits.gd")
const Jobs = preload("res://scripts/jobs.gd")
const Ages = preload("res://scripts/ages.gd")
const Mind = preload("res://scripts/mind.gd")
const DRAWER_WIDTH := 320
const NEEDS := ["hunger", "thirst", "energy", "fun", "bladder", "hygiene", "social"]
const FOOTER_HEIGHT := 64
const UiTheme = preload("res://scripts/ui_theme.gd")
const FOOTER_COLOR := Color(0.97, 0.96, 0.99, 0.95)
const FOOTER_ACCENT := Color("#f5ccd4")
const BAR_BACK := Color(0.893, 0.893, 0.940)
const LOW := Color(0.98, 0.5, 0.58)
const MID := Color(1.0, 0.78, 0.45)
const HIGH := Color(0.5, 0.84, 0.66)
const EMOTION_COLORS := {
	"Fine": Color(0.55, 0.5, 0.65), "Happy": Color(0.35, 0.72, 0.45), "Sad": Color(0.45, 0.6, 0.95),
	"Angry": Color(0.95, 0.35, 0.3), "Embarrassed": Color(0.95, 0.55, 0.75), "Uncomfortable": Color(0.75, 0.65, 0.45),
	"Energized": Color(1.0, 0.6, 0.25), "Playful": Color(0.9, 0.7, 0.2), "Bored": Color(0.6, 0.6, 0.68),
	"Confident": Color(0.3, 0.8, 0.9), "Flirty": Color(1.0, 0.5, 0.7), "Focused": Color(0.6, 0.5, 0.95), "Tense": Color(0.85, 0.45, 0.6),
}

var player: Node2D
var game: Node2D  # main.gd (speed and pause)
var speed_buttons := []  # [pause, normal, fast, faster, ultra]
var paused_label: Label
var bars := {}
var fills := {}
var values := {}  # need -> Label with the number
var feeling_label: Label
var drawer: PanelContainer
var drawer_list: VBoxContainer
var drawer_refresh_at := 0  # real-time msec of the next refresh
var toast: Label  # "Game saved" etc.
var toast_until := 0
const CARE_ACTIONS := ["Feed", "Change & clean", "Rock to sleep", "Play with", "Read a story", "Hug"]
var child: Node2D = null  # the little one shown in the left panel
var child_panel: PanelContainer
var child_title: Label
var child_info: Label
var child_bars := {}
var child_buttons := {}
var household_row: HBoxContainer
var household_key := ""  # who's in the bar now, to rebuild it only when that changes
var reasons_label: Label
var money_label: Label
var mode_button: Button
var info_label: Label
var events_label: Label
var time_label: Label
var date_label: Label


func setup(p_player: Node2D, p_game: Node2D) -> CanvasLayer:
	player = p_player
	game = p_game
	return self


func _ready() -> void:
	add_to_group("hud")
	build_footer()
	build_child_panel()
	apply_theme.call_deferred()
	var vbox := add_panel(Vector2(16, 16))
	household_row = HBoxContainer.new()
	vbox.add_child(household_row)

	mode_button = Button.new()
	mode_button.focus_mode = Control.FOCUS_NONE  # keep Tab free for the shortcut
	mode_button.pressed.connect(func(): player.toggle_mode())
	vbox.add_child(mode_button)
	var build_button := Button.new()
	build_button.text = "Build  (B)"
	build_button.focus_mode = Control.FOCUS_NONE
	build_button.pressed.connect(func(): game.build.toggle())
	vbox.add_child(build_button)
	var rel_button := Button.new()
	rel_button.text = "Relationships  (R)"
	rel_button.focus_mode = Control.FOCUS_NONE
	rel_button.pressed.connect(toggle_relationships)
	vbox.add_child(rel_button)
	build_drawer()

	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(info_label)

	events_label = Label.new()
	events_label.add_theme_font_size_override("font_size", 12)
	var events_box := add_panel(Vector2.ZERO)
	var events_panel: Control = events_box.get_parent().get_parent()
	events_panel.anchor_top = 1.0
	events_panel.anchor_bottom = 1.0
	events_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN  # grows upward as events come in
	events_panel.offset_left = 16
	events_panel.offset_bottom = -FOOTER_HEIGHT - 10
	events_box.add_child(events_label)

	var time_panel := PanelContainer.new()
	time_panel.anchor_left = 1.0
	time_panel.anchor_right = 1.0
	time_panel.offset_left = -250
	time_panel.offset_right = -16
	time_panel.offset_top = 16
	time_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(time_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	time_panel.add_child(margin)
	var time_box := VBoxContainer.new()
	margin.add_child(time_box)
	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size", 22)
	time_box.add_child(time_label)
	date_label = Label.new()
	date_label.add_theme_font_size_override("font_size", 12)
	time_box.add_child(date_label)
	var speed_row := HBoxContainer.new()
	time_box.add_child(speed_row)
	var game_menu := MenuButton.new()
	game_menu.text = "Menu  ▾"
	game_menu.flat = false
	game_menu.focus_mode = Control.FOCUS_NONE
	for item in ["Save game", "Save as a new game", "Save and exit to main menu", "Exit to main menu", "Quit game"]:
		game_menu.get_popup().add_item(item)
	game_menu.get_popup().id_pressed.connect(on_game_menu)
	time_box.add_child(game_menu)
	toast = Label.new()
	toast.anchor_left = 0.5
	toast.anchor_right = 0.5
	toast.offset_left = -200
	toast.offset_right = 200
	toast.offset_top = 70
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_font_size_override("font_size", 20)
	toast.add_theme_color_override("font_color", Color(0.85, 0.45, 0.65))
	toast.add_theme_color_override("font_outline_color", Color.WHITE)
	toast.add_theme_constant_override("outline_size", 8)
	add_child(toast)
	for n in 5:  # pause, then one button per speed
		var b := Button.new()
		b.text = ["||", ">", ">>", ">>>", ">>>>"][n]
		b.tooltip_text = ["Pause (P / Space / 0)", "Normal 1x (1)", "Fast 5x (2)", "Faster 20x (3)", "Ultra 60x (4)"][n]
		b.focus_mode = Control.FOCUS_NONE  # keep Space for pausing
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(40, 0)
		b.pressed.connect(game.toggle_pause if n == 0 else game.set_speed.bind(n - 1))
		speed_row.add_child(b)
		speed_buttons.append(b)

	paused_label = Label.new()
	paused_label.text = "PAUSED"
	paused_label.add_theme_font_size_override("font_size", 32)
	paused_label.add_theme_constant_override("outline_size", 10)
	paused_label.add_theme_color_override("font_outline_color", Color.WHITE)
	paused_label.add_theme_color_override("font_color", Color(0.85, 0.45, 0.65))
	paused_label.anchor_left = 0.5
	paused_label.anchor_right = 0.5
	paused_label.offset_left = -70
	paused_label.offset_top = 20
	add_child(paused_label)

	var help := Label.new()
	help.add_theme_font_size_override("font_size", 11)
	help.modulate = Color(1, 1, 1, 0.75)
	help.add_theme_constant_override("outline_size", 4)
	help.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.8))
	help.text = "Click floor: walk   Click object: use   Click person: interact   Click door: enter/knock   Click stairs: change floor\nTab: Manual/Auto   B: build   R: relationships   P/Space: pause   1-4: speed   Wheel: zoom   F3: NPC details"
	help.anchor_left = 1.0
	help.anchor_right = 1.0
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	help.offset_right = -16
	help.offset_bottom = -FOOTER_HEIGHT - 8
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(help)


# Right-hand drawer listing your relationships. Hidden until opened.
func build_drawer() -> void:
	drawer = PanelContainer.new()
	drawer.anchor_left = 1.0
	drawer.anchor_right = 1.0
	drawer.anchor_bottom = 1.0
	drawer.offset_left = -DRAWER_WIDTH - 16
	drawer.offset_right = -16
	drawer.offset_top = 160  # below the clock
	drawer.offset_bottom = -FOOTER_HEIGHT - 50  # above the controls text
	var style := StyleBoxFlat.new()
	style.bg_color = FOOTER_COLOR
	style.border_width_left = 2
	style.border_color = FOOTER_ACCENT
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	drawer.add_theme_stylebox_override("panel", style)
	drawer.visible = false
	add_child(drawer)
	var column := VBoxContainer.new()
	drawer.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	var title := Label.new()
	title.text = "Relationships"
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "x"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(toggle_relationships)
	head.add_child(close)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	drawer_list = VBoxContainer.new()
	drawer_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drawer_list.add_theme_constant_override("separation", 12)
	scroll.add_child(drawer_list)


# --- Household bar ---

func update_household() -> void:
	var people: Array = get_tree().get_first_node_in_group("controller").household()
	people.sort_custom(func(a, b): return a.age_days > b.age_days)
	var key := ",".join(people.map(func(c): return "%s:%d:%s" % [c.npc_name, Ages.stage(c), c == player]))
	if key == household_key:
		return
	household_key = key
	for child_node in household_row.get_children():
		child_node.queue_free()
	for c in people:
		var b := Button.new()
		b.text = c.npc_name
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = "%s · %s" % [Ages.describe(c), "you control them" if c == player else "click to control"]
		if c == player:
			b.modulate = Color("#c9def4") * 1.2
		elif Ages.stage(c) <= Ages.TODDLER:
			b.modulate = Color(0.95, 0.75, 0.85)
			b.tooltip_text = "%s · not playable: click to see their needs" % Ages.describe(c)
		b.pressed.connect(pick_household.bind(c))
		household_row.add_child(b)


func pick_household(c: Node2D) -> void:
	if Ages.stage(c) <= Ages.TODDLER:
		show_child(c)
	elif c != player:
		get_tree().get_first_node_in_group("controller").take_control(c)


# --- Babies and toddlers (not playable: you see their needs and look after them) ---

func build_child_panel() -> void:
	child_panel = PanelContainer.new()
	child_panel.offset_left = 16
	child_panel.offset_top = 230
	child_panel.custom_minimum_size = Vector2(300, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = FOOTER_COLOR
	style.border_width_right = 2
	style.border_color = Color(0.95, 0.7, 0.8)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	child_panel.add_theme_stylebox_override("panel", style)
	child_panel.visible = false
	add_child(child_panel)
	var column := VBoxContainer.new()
	child_panel.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	child_title = Label.new()
	child_title.add_theme_font_size_override("font_size", 16)
	child_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(child_title)
	var close := Button.new()
	close.text = "x"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func(): child_panel.visible = false)
	head.add_child(close)
	child_info = Label.new()
	child_info.add_theme_font_size_override("font_size", 11)
	child_info.modulate = Color(1, 1, 1, 0.75)
	column.add_child(child_info)
	var grid := GridContainer.new()
	grid.columns = 2
	column.add_child(grid)
	for need in NEEDS:
		var label := Label.new()
		label.text = need.capitalize()
		label.add_theme_font_size_override("font_size", 11)
		grid.add_child(label)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(190, 10)
		bar.show_percentage = false
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var back := StyleBoxFlat.new()
		back.bg_color = BAR_BACK
		back.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("background", back)
		var fill := StyleBoxFlat.new()
		fill.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("fill", fill)
		grid.add_child(bar)
		child_bars[need] = [bar, fill]
	var buttons := GridContainer.new()
	buttons.columns = 2
	column.add_child(buttons)
	for action in CARE_ACTIONS:
		var b := Button.new()
		b.text = action
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(care.bind(action))
		buttons.add_child(b)
		child_buttons[action] = b


func show_child(c: Node2D) -> void:
	child = c
	child_panel.visible = true
	update_child_panel()


func care(action: String) -> void:
	if child == null:
		return
	for i in Social.INTERACTIONS:
		if i.name == action:
			player.order_interaction(child, i)


func update_child_panel() -> void:
	if child == null or child.dead or not is_instance_valid(child):
		child_panel.visible = false
		return
	child_title.text = "%s — %s" % [Social.display_name(player, child), Ages.describe(child)]
	var parents: String = ", ".join(child.parents) if not child.parents.is_empty() else "unknown"
	child_info.text = "Feeling %s%s\n%s · parents: %s" % [Emotions.describe(child).to_lower(),
		" (%s)" % Emotions.reasons(child, 2) if not child.moodlets.is_empty() else "", child.activity, parents]
	for need in NEEDS:
		child_bars[need][0].value = child.needs[need]
		child_bars[need][1].bg_color = need_color(child.needs[need])
	var allowed: Array = Social.available_interactions(player, child).map(func(i): return i.name)
	for action in CARE_ACTIONS:
		child_buttons[action].disabled = not action in allowed
		child_buttons[action].tooltip_text = "" if action in allowed else "Only family or housemates (teens and up) can do this"


func toggle_relationships() -> void:
	drawer.visible = not drawer.visible
	drawer_refresh_at = 0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R and not game.build.active:
		toggle_relationships()


# One card per person: name and tier, friendship bar, then details.
func fill_drawer() -> void:
	for child in drawer_list.get_children():
		child.queue_free()
	var people := get_tree().get_nodes_in_group("characters").filter(func(c): return c != player)
	people.sort_custom(func(a, b): return Social.friendship(player, a) > Social.friendship(player, b))
	for c in people:
		var met: bool = player.known.has(c.npc_name)
		var f := Social.friendship(player, c)
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation", 2)
		drawer_list.add_child(card)
		var top := HBoxContainer.new()
		card.add_child(top)
		var name_label := Label.new()
		name_label.text = Social.display_name(player, c)
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top.add_child(name_label)
		var tier := Label.new()
		tier.text = "%s  %+d" % [Social.relationship_word(f), f]
		tier.add_theme_font_size_override("font_size", 12)
		tier.modulate = friendship_color(f)
		top.add_child(tier)

		var bar := ProgressBar.new()  # -100 … 100, filled from the left
		bar.min_value = -100
		bar.max_value = 100
		bar.value = f
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 8)
		var back := StyleBoxFlat.new()
		back.bg_color = BAR_BACK
		back.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("background", back)
		var fill := StyleBoxFlat.new()
		fill.bg_color = friendship_color(f)
		fill.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("fill", fill)
		card.add_child(bar)

		var lines := ["Feeling %s · %s" % [Emotions.describe(c).to_lower(), where(c, met)]]
		lines.append("Their view of you: %s (%+d)" % [Social.relationship_word(Social.friendship(c, player)), Social.friendship(c, player)])
		if met:
			lines.append(Ages.describe(c))
			var work := "unemployed"
			if Jobs.is_school(c.job):
				work = "at %s (grade %s)" % [c.job, Jobs.grade(c.performance)]
			elif c.job != "":
				work = "%s at the %s" % [Jobs.title(c), c.job]
			elif not Ages.is_grown_up(c):
				work = "too young for school" if Ages.stage(c) == Ages.BABY else "not in school"
			lines.append("Occupation: " + work)
			if Ages.family(player, c):
				lines.append("Family")
		if met:
			lines.append("Traits: " + ", ".join(c.traits))
		else:
			lines.append("You haven't met yet")
		if player.home >= 0 and player.world.invitation_left(player.home, c) > 0.0:
			lines.append("Invited to your home (%s left)" % hours_text(player.world.invitation_left(player.home, c)))
		if c.home >= 0 and player.world.invitation_left(c.home, player) > 0.0:
			lines.append("You're invited to theirs (%s left)" % hours_text(player.world.invitation_left(c.home, player)))
		var mems := Social.memories_of(c, player)
		if not mems.is_empty():
			lines.append("Remembers: you %s" % mems[-1].text)
		var details := Label.new()
		details.text = "\n".join(lines)
		details.add_theme_font_size_override("font_size", 11)
		details.modulate = Color(1, 1, 1, 0.75)
		details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(details)


func job_text() -> String:
	if player.job == "":
		return "Job: none (get one at the Bus stop)"
	var t: float = player.world.now()
	var when := "at work now" if player.at_work else "WORK TIME: go to the Bus stop" if Jobs.should_work(player, t) else ""
	if when == "":
		var next := Jobs.next_shift(player, t)
		when = "next shift %s %s" % [GameTime.weekday(next).substr(0, 3), GameTime.clock_text(next).substr(0, 5)] if next >= 0.0 else ""
	if Jobs.is_school(player.job):
		return "School: %s · %s\nGrade %s" % [player.job, when.replace("work", "school").replace("shift", "class"), Jobs.grade(player.performance)]
	return "Job: %s at the %s, $%d/h · %s\nPerformance %d%%%s" % [Jobs.title(player), player.job, Jobs.hourly(player), when,
		player.performance, " · WARNING: one more bad shift and you're fired" if player.warned else ""]


# Where someone is. House names contain names, so for people you haven't met it stays vague.
func where(c: Node2D, met: bool) -> String:
	if met or c.building < 0:
		return player.world.location_name(c)
	if c.building == c.home:
		return "at home"
	return "at your place" if c.building == player.home else "visiting someone"


static func friendship_color(f: float) -> Color:
	if f < 0.0:
		return Color(0.65, 0.65, 0.7).lerp(LOW, clampf(-f / 50.0, 0.0, 1.0))
	return Color(0.65, 0.65, 0.7).lerp(HIGH, clampf(f / 50.0, 0.0, 1.0))


static func hours_text(seconds: float) -> String:
	return "%dh %02dm" % [int(seconds) / 3600, int(seconds) / 60 % 60]


# The band along the bottom: feeling on the left, then one cell per need.
func build_footer() -> void:
	var footer := PanelContainer.new()
	footer.anchor_left = 0.0
	footer.anchor_right = 1.0
	footer.anchor_top = 1.0
	footer.anchor_bottom = 1.0
	footer.offset_top = -FOOTER_HEIGHT
	var style := StyleBoxFlat.new()
	style.bg_color = FOOTER_COLOR
	style.border_width_top = 2
	style.border_color = FOOTER_ACCENT
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	footer.add_theme_stylebox_override("panel", style)
	add_child(footer)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	footer.add_child(row)

	var feeling := VBoxContainer.new()
	feeling.custom_minimum_size = Vector2(170, 0)
	feeling.add_theme_constant_override("separation", 0)
	row.add_child(feeling)
	feeling_label = Label.new()
	feeling_label.add_theme_font_size_override("font_size", 20)
	feeling.add_child(feeling_label)
	reasons_label = Label.new()
	reasons_label.add_theme_font_size_override("font_size", 10)
	reasons_label.modulate = Color(1, 1, 1, 0.6)
	reasons_label.clip_text = true
	reasons_label.custom_minimum_size = Vector2(170, 0)
	feeling.add_child(reasons_label)
	row.add_child(VSeparator.new())
	var wallet := VBoxContainer.new()
	wallet.custom_minimum_size = Vector2(80, 0)
	wallet.add_theme_constant_override("separation", 0)
	row.add_child(wallet)
	var wallet_title := Label.new()
	wallet_title.text = "Money"
	wallet_title.add_theme_font_size_override("font_size", 10)
	wallet_title.modulate = Color(1, 1, 1, 0.6)
	wallet.add_child(wallet_title)
	money_label = Label.new()
	money_label.add_theme_font_size_override("font_size", 20)
	wallet.add_child(money_label)
	row.add_child(VSeparator.new())

	for need in NEEDS:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_theme_constant_override("separation", 3)
		row.add_child(cell)
		var head := HBoxContainer.new()
		cell.add_child(head)
		var name_label := Label.new()
		name_label.text = need.capitalize()
		name_label.add_theme_font_size_override("font_size", 12)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_label)
		var value_label := Label.new()
		value_label.add_theme_font_size_override("font_size", 12)
		head.add_child(value_label)
		values[need] = value_label

		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 12)
		bar.show_percentage = false
		var back := StyleBoxFlat.new()
		back.bg_color = BAR_BACK
		back.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("background", back)
		var fill := StyleBoxFlat.new()
		fill.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("fill", fill)
		cell.add_child(bar)
		bars[need] = bar
		fills[need] = fill


# Smooth red → amber → green.
static func need_color(value: float) -> Color:
	if value < 50.0:
		return LOW.lerp(MID, clampf((value - 15.0) / 35.0, 0.0, 1.0))
	return MID.lerp(HIGH, clampf((value - 50.0) / 25.0, 0.0, 1.0))


func add_panel(pos: Vector2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.position = pos
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)
	return vbox


func _process(_delta: float) -> void:
	for need in NEEDS:
		var value: float = player.needs[need]
		bars[need].value = value
		fills[need].bg_color = need_color(value)
		values[need].text = str(int(value))
		values[need].modulate = LOW if value < 25.0 else Color(1, 1, 1, 0.8)
	var emotion := Emotions.emotion(player)
	feeling_label.text = Emotions.describe(player)
	feeling_label.modulate = EMOTION_COLORS.get(emotion, Color.WHITE)
	reasons_label.text = Emotions.reasons(player, 3) if not player.moodlets.is_empty() else "Nothing special"
	money_label.text = "$%d" % player.money
	money_label.modulate = LOW if player.money < 0 else Color(0.3, 0.65, 0.45)

	update_household()
	toast.visible = Time.get_ticks_msec() < toast_until
	if child_panel.visible:
		update_child_panel()
	var t: float = player.world.now()
	time_label.text = "%s  %s" % [GameTime.weekday(t).substr(0, 3), GameTime.clock_text(t)]
	date_label.text = "%s\n%s" % [GameTime.part_of_day(t), GameTime.date_text(t)]

	paused_label.visible = game.paused
	for n in speed_buttons.size():
		var active: bool = game.paused if n == 0 else (not game.paused and not game.sleep_boost and game.speed == n - 1) \
			or (n == 4 and game.sleep_boost and not game.paused)
		speed_buttons[n].set_pressed_no_signal(active)
		speed_buttons[n].modulate = Color(0.749, 0.827, 0.909) * 1.25 if active else Color.WHITE

	mode_button.text = "Mode: %s  (Tab)" % ("Auto" if player.auto_mode else "Manual")

	var lines := [player.world.location_name(player),
		"Speed: " + game.speed_text(),
		"You: " + Ages.describe(player) + (" · pregnant" if player.pregnant_until >= 0.0 else "") + (" · college degree" if player.degree else ""),
		job_text(),
		"Skills: " + Skills.summary(player),
		"Mind: " + (", ".join(Mind.states(player)) if not Mind.states(player).is_empty() else "doing okay")]
	info_label.text = "\n".join(lines)

	if drawer.visible and Time.get_ticks_msec() >= drawer_refresh_at:  # twice a second, even when paused
		drawer_refresh_at = Time.get_ticks_msec() + 500
		fill_drawer()

	var events := Social.event_log.map(func(e): return Social.format_event(e, player))
	events_label.text = "\n".join(events) if not events.is_empty() else "No social events yet"


# The pastel look (ui_theme.gd) on every panel, button and label of the HUD.
func apply_theme() -> void:
	for child in get_children():
		if child is Control:
			child.theme = UiTheme.get_theme()


# --- Game menu (Menu ▾ under the clock) ---

const SaveGame = preload("res://scripts/save_game.gd")
const Session = preload("res://scripts/session.gd")


func on_game_menu(id: int) -> void:
	match id:
		0:
			save_game(false)
		1:
			save_game(true)
		2:
			if save_game(false):
				exit_to_menu()
		3:
			exit_to_menu()
		4:
			get_tree().quit()


func save_game(as_new: bool) -> bool:
	if Session.slot == "" or as_new:
		Session.slot = SaveGame.new_slot(game.household_name)
	var ok := SaveGame.save(game, Session.slot)
	show_toast("Game saved ✿" if ok else "Couldn't save the game")
	return ok


func show_toast(text: String) -> void:
	toast.text = text
	toast_until = Time.get_ticks_msec() + 2500


func exit_to_menu() -> void:
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
