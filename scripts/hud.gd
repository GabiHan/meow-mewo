# Screen-space UI, kept light (like the mockup): only the bottom row is always there.
#   bottom-left   household: everyone who lives in your home (click to control them; babies and toddlers
#                 open their needs panel), then your money
#   bottom-centre clock and weekday, pause / speeds, Build mode
#   bottom-right  ☰ menu: Relationships, Controls, Settings (volume, music, fullscreen), save, exit, quit
#   left tab  >   TODAY: what you're doing now (and how long it takes), the next steps of the task, your next
#                 shift or school day, and what you feel like doing (AI). Hidden until you click the tab.
#   right tab <   PASSPORT: you at a glance: portrait, name, mood line and word, skills, the 7 needs, age, job,
#                 Manual/Auto, and what you're doing with a progress bar. Hidden until you click the tab.
#   above the household row: chat feed (what people you know say and think near you, see heard()) and new
#                 social events of your household; hidden when there's nothing new. Strangers stay a mystery.
#   left panel    a baby or toddler you clicked: their needs, feeling, parents and care buttons
#   right drawer  Relationships (☰ menu or R): everyone you know of, with a friendship bar, how they feel,
#                 where they are, traits (once met), invitations and memories of you
#   top-centre    "PAUSED" banner while paused; toasts
#   bottom-centre talking to someone in your own words (talk_panel.gd), above the bottom row
extends CanvasLayer

const Social = preload("res://scripts/social.gd")
const GameTime = preload("res://scripts/game_time.gd")
const Emotions = preload("res://scripts/emotions.gd")
const Skills = preload("res://scripts/skills.gd")
const Traits = preload("res://scripts/traits.gd")
const Jobs = preload("res://scripts/jobs.gd")
const Ages = preload("res://scripts/ages.gd")
const Mind = preload("res://scripts/mind.gd")
const Looks = preload("res://scripts/looks.gd")
const Llm = preload("res://scripts/llm.gd")
const TalkPanel = preload("res://scripts/talk_panel.gd")
const Net = preload("res://scripts/net.gd")
const SettingsPanel = preload("res://scripts/settings_panel.gd")
const Weather = preload("res://scripts/weather.gd")
const DRAWER_WIDTH := 320
const NEEDS := ["hunger", "thirst", "energy", "fun", "bladder", "hygiene", "social"]
const BAR_HEIGHT := 56  # the bottom row
const MARGIN := 16
const PASSPORT_WIDTH := 560
const TODAY_WIDTH := 250
const TODAY_ITEMS := 6
const FEED_EVENTS := 3  # newest social events shown above the household row...
const EVENT_SECONDS := 20.0  # ...for this long after something new happens
const UiTheme = preload("res://scripts/ui_theme.gd")
const PANEL_COLOR := UiTheme.PAPER_GLASS
const ACCENT := UiTheme.ACCENT  # Today's dots, the mood line, chips, the activity bar (ui_theme.gd ACCENTS)
const BAR_BACK := UiTheme.LINE
const LOW := UiTheme.ROSE  # a need under 25, money below $0, disliking you
const MID := Color("#d8c2ff")  # a need around half
const HIGH := UiTheme.ACCENT  # a full need, liking you
const SPEED_LABELS := ["||", "▶", "▶▶ ×2", "▶▶ ×3", "▶▶ ×4"]
const CONTROLS := "Click floor: walk\nClick object: use it\nClick person: interact (Talk… to type)\nClick door: enter / knock\n" \
	+ "Click stairs: change floor\nTab: Manual / Auto\nB: build mode\nR: relationships\nP / Space / 0: pause\n1-4: speed\n" \
	+ "Mouse wheel: zoom\nF3: NPC details\n< and > tabs: Today and Passport"

# Whether Today and Passport are open; static so it stays when you switch person or load a game.
static var show_today := false
static var show_passport := false

var player: Node2D
var game: Node2D  # main.gd (speed and pause)
var speed_buttons := []  # [pause, normal, fast, faster, ultra]
var paused_label: Label
var bars := {}  # passport need bars
var fills := {}
var values := {}  # need -> Label with the number
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
var money_label: Label
var mode_button: Button
var info_label: Label  # passport: age, job, where, mind, AI, online
var time_label: Label
var date_label: Label
var today_panel: PanelContainer
var today_list: VBoxContainer
var today_date: Label
var today_tab: Button
var today_refresh_at := 0
var passport: PanelContainer
var passport_tab: Button
var portrait: TextureRect
var name_label: Label
var mood_line: Control
var mood_word: Label
var reasons_label: Label
var skills_row: HFlowContainer
var skills_key := ""
var activity_label: Label
var activity_pct: Label
var activity_bar: ProgressBar
var feed_panel: PanelContainer
var events_label: Label
var last_event := ""
var events_until := 0
var talk: PanelContainer  # talking to someone in your own words (talk_panel.gd)
const CHAT_LINES := 6
const CHAT_SECONDS := 60.0  # real seconds a line stays in the chat feed
const HEAR_RADIUS := 25.0  # tiles: you hear people on your floor who are on screen within this
var chat := []  # what you heard, newest last: {who, text, with, at (msec)}
var chat_label: Label


# The passport's mood: a line from low to high with a diamond where you are.
class MoodLine:
	extends Control
	var value := 0.5
	func _draw() -> void:
		var y := size.y / 2.0
		var x := size.x * clampf(value, 0.0, 1.0)
		draw_line(Vector2(0, y), Vector2(size.x, y), UiTheme.LINE, 2.0)
		draw_line(Vector2(0, y), Vector2(x, y), UiTheme.ACCENT, 2.0)
		var d := 5.0
		var diamond := PackedVector2Array([Vector2(x, y - d), Vector2(x + d, y), Vector2(x, y + d), Vector2(x - d, y)])
		draw_colored_polygon(diamond, Color.WHITE)
		diamond.append(diamond[0])
		draw_polyline(diamond, UiTheme.ACCENT, 1.5)


# A box with a dashed lilac border (the passport's skills).
class DashedBox:
	extends PanelContainer
	func _ready() -> void:
		var margins := StyleBoxEmpty.new()
		margins.set_content_margin_all(8)
		add_theme_stylebox_override("panel", margins)
	func _draw() -> void:
		var r := Rect2(Vector2.ONE, size - Vector2.ONE * 2.0)
		var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
		for n in 4:
			draw_dashed_line(corners[n], corners[n + 1], UiTheme.ACCENT_SOFT, 1.0, 4.0)


func setup(p_player: Node2D, p_game: Node2D) -> CanvasLayer:
	player = p_player
	game = p_game
	return self


func _ready() -> void:
	add_to_group("hud")
	build_bottom_row()
	build_today()
	build_passport()
	build_feed()
	build_child_panel()
	build_drawer()
	talk = TalkPanel.new()
	add_child(talk)
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
	apply_theme.call_deferred()
	set_today(show_today)
	set_passport(show_passport)


# A rounded light card (ui_theme.gd box).
func card(border := Color.TRANSPARENT) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.box(PANEL_COLOR, 10, border))
	return panel


func small(text := "", size := 13, alpha := 0.7, italic := false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.modulate = Color(1, 1, 1, alpha)
	if italic:
		label.add_theme_font_override("font", UiTheme.font(true))
	return label


func flat_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE  # keep Tab and Space for the shortcuts
	b.pressed.connect(action)
	return b


# Anchor a control to the bottom of the screen at the bottom-row height.
func on_bottom_row(c: Control, h_anchor: float) -> void:
	c.anchor_left = h_anchor
	c.anchor_right = h_anchor
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_top = -BAR_HEIGHT - MARGIN
	c.offset_bottom = -MARGIN
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN


func build_bottom_row() -> void:
	var left := HBoxContainer.new()
	on_bottom_row(left, 0.0)
	left.offset_left = MARGIN
	left.add_theme_constant_override("separation", 10)
	add_child(left)
	household_row = HBoxContainer.new()
	household_row.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(household_row)
	var wallet := card()
	wallet.tooltip_text = "Your money"
	left.add_child(wallet)
	money_label = Label.new()
	money_label.add_theme_font_size_override("font_size", 18)
	money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	wallet.add_child(money_label)

	var center := card()
	on_bottom_row(center, 0.5)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	center.add_child(row)
	var clock := VBoxContainer.new()
	clock.add_theme_constant_override("separation", -4)
	clock.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(clock)
	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size", 24)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.mouse_filter = Control.MOUSE_FILTER_PASS
	clock.add_child(time_label)
	date_label = small("", 11)
	date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock.add_child(date_label)
	row.add_child(VSeparator.new())
	for n in 5:  # pause, then one button per speed
		var b := flat_button(SPEED_LABELS[n], game.toggle_pause if n == 0 else game.set_speed.bind(n - 1))
		b.tooltip_text = ["Pause (P / Space / 0)", "Normal 1x (1)", "Fast 5x (2)", "Faster 20x (3)", "Ultra 60x (4)"][n]
		b.toggle_mode = true
		row.add_child(b)
		speed_buttons.append(b)
	row.add_child(VSeparator.new())
	row.add_child(flat_button("Build mode", func(): game.build.toggle()))

	var game_menu := MenuButton.new()
	game_menu.text = "☰"
	game_menu.flat = false
	game_menu.focus_mode = Control.FOCUS_NONE
	game_menu.add_theme_font_size_override("font_size", 20)
	on_bottom_row(game_menu, 1.0)
	game_menu.offset_right = -MARGIN
	game_menu.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var popup := game_menu.get_popup()
	popup.add_item("Relationships  (R)", 10)
	popup.add_item("Controls", 11)
	popup.add_item("Settings", 12)
	popup.add_separator()
	for item in ["Save game", "Save as a new game", "Save and exit to main menu", "Exit to main menu", "Quit game"]:
		popup.add_item(item, ["Save game", "Save as a new game", "Save and exit to main menu", "Exit to main menu", "Quit game"].find(item))
	popup.id_pressed.connect(on_game_menu)
	add_child(game_menu)


# --- Today (left tab) ---

func build_today() -> void:
	today_panel = card()
	var paper := UiTheme.box(PANEL_COLOR, 4)
	paper.border_color = ACCENT
	paper.border_width_top = 2  # the accent line along the top, like a planner page
	today_panel.add_theme_stylebox_override("panel", paper)
	today_panel.position = Vector2(MARGIN, MARGIN)
	today_panel.custom_minimum_size = Vector2(TODAY_WIDTH, 0)
	add_child(today_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	today_panel.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	var title := Label.new()
	title.text = "Today"
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	today_date = small("", 12, 0.7, true)
	head.add_child(today_date)
	today_list = VBoxContainer.new()
	today_list.add_theme_constant_override("separation", 0)
	column.add_child(today_list)
	today_tab = flat_button(">", func(): set_today(not today_panel.visible))
	today_tab.tooltip_text = "Today"
	add_child(today_tab)


func set_today(on: bool) -> void:
	show_today = on
	today_panel.visible = on
	today_tab.text = "<" if on else ">"
	today_refresh_at = 0


# What's on today for `c`, in order: {title, sub, now}.
func today_items(c: Node2D) -> Array:
	var items := []
	var where: String = c.target_object.object_name if c.target_object else c.world.location_name(c)
	if c.state == "using" and c.step.get("seconds", 0.0) > 0.0:
		items.append({"title": c.shown_activity(c), "sub": "%s · %d min" % [where, ceili(c.use_timer)], "now": true})
	elif c.at_work:
		items.append({"title": c.shown_activity(c), "sub": c.world.location_name(c), "now": true})
	else:
		items.append({"title": c.shown_activity(c) if c.activity != "Idle" else "Free time", "sub": where, "now": true})
	for n in c.steps.size():
		var s: Dictionary = c.steps[n]
		items.append({"title": s.get("verb", "Next step"), "sub": "%s · %s" % [s.object.object_name if s.get("object") else "", "Next" if n == 0 else "Then"],
			"now": false})
	var t: float = c.world.now()
	if c.job != "" and not c.at_work:
		var school := Jobs.is_school(c.job)
		var what := "School (%s)" % c.job if school else "Work at the %s" % c.job
		if Jobs.should_work(c, t):
			items.append({"title": what, "sub": "Bus stop · now!", "now": false})
		else:
			var next := Jobs.next_shift(c, t)
			if next >= 0.0:
				var day := "" if GameTime.day_index(next) == GameTime.day_index(t) else GameTime.weekday(next).substr(0, 3) + " "
				items.append({"title": what, "sub": "Bus stop · %s%s" % [day, GameTime.clock_text(next).substr(0, 5)], "now": false})
	if Llm.wish_text(c) != "":
		items.append({"title": "Feels like it: " + Llm.wish_text(c).get_slice(" (", 0), "sub": Llm.wish_text(c).get_slice(" (", 1).trim_suffix(")"),
			"now": false})
	return items.slice(0, TODAY_ITEMS)


func fill_today() -> void:
	for n in today_list.get_children():
		n.queue_free()
	var t: float = player.world.now()
	today_date.text = "%s · %s" % [GameTime.weekday(t).substr(0, 3), GameTime.part_of_day(t)]
	var items := today_items(player)
	for n in items.size():
		var item: Dictionary = items[n]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		today_list.add_child(row)
		var rail := VBoxContainer.new()  # a dot, and a thin line down to the next one
		rail.add_theme_constant_override("separation", 0)
		rail.custom_minimum_size = Vector2(12, 0)
		row.add_child(rail)
		var dot := Label.new()
		dot.text = "●" if item.now else "○"
		dot.add_theme_font_size_override("font_size", 12)
		dot.add_theme_color_override("font_color", ACCENT)
		dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rail.add_child(dot)
		var stem := ColorRect.new()
		stem.color = UiTheme.ACCENT_SOFT if n < items.size() - 1 else Color.TRANSPARENT
		stem.custom_minimum_size = Vector2(1, 0)
		stem.size_flags_vertical = Control.SIZE_EXPAND_FILL
		stem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		rail.add_child(stem)
		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", -3)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var title := Label.new()
		title.text = item.title
		title.add_theme_font_size_override("font_size", 16)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.custom_minimum_size = Vector2(TODAY_WIDTH - 54, 0)
		text.add_child(title)
		text.add_child(small(item.sub, 12, 0.65, true) if item.sub != "" else Control.new())
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 8)
		text.add_child(gap)


# --- Passport (right tab) ---

func build_passport() -> void:
	passport = card()
	passport.anchor_left = 1.0
	passport.anchor_right = 1.0
	passport.offset_left = -PASSPORT_WIDTH - MARGIN
	passport.offset_right = -MARGIN
	passport.offset_top = MARGIN
	passport.grow_horizontal = Control.GROW_DIRECTION_BEGIN  # wider content grows leftwards, not off screen
	add_child(passport)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	passport.add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	column.add_child(top)
	var frame := PanelContainer.new()
	var frame_style := UiTheme.flat(UiTheme.ACCENTS[9].lerp(Color.WHITE, 0.6), UiTheme.ACCENT_SOFT)
	frame_style.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", frame_style)
	frame.custom_minimum_size = Vector2(64, 64)
	top.add_child(frame)
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(60, 60)
	frame.add_child(portrait)
	var who := VBoxContainer.new()
	who.alignment = BoxContainer.ALIGNMENT_CENTER
	who.custom_minimum_size = Vector2(170, 0)
	top.add_child(who)
	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 28)
	who.add_child(name_label)
	mode_button = flat_button("", func(): Net.order(game, "mode", []))
	mode_button.tooltip_text = "Manual: only your orders · Auto: they live on their own (Tab)"
	mode_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	who.add_child(mode_button)
	top.add_child(VSeparator.new())
	var mood := VBoxContainer.new()
	mood.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mood.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(mood)
	var mood_head := HBoxContainer.new()
	mood.add_child(mood_head)
	var mood_title := small("Mood", 13)
	mood_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mood_head.add_child(mood_title)
	mood_word = Label.new()
	mood_word.add_theme_font_size_override("font_size", 15)
	mood_word.add_theme_font_override("font", UiTheme.font(true))
	mood_head.add_child(mood_word)
	mood_line = MoodLine.new()
	mood_line.custom_minimum_size = Vector2(0, 14)
	mood.add_child(mood_line)
	reasons_label = small("", 12, 0.65, true)
	reasons_label.clip_text = true
	mood.add_child(reasons_label)

	var skills_box := DashedBox.new()
	column.add_child(skills_box)
	skills_row = HFlowContainer.new()
	skills_row.add_theme_constant_override("h_separation", 6)
	skills_row.add_theme_constant_override("v_separation", 6)
	skills_box.add_child(skills_row)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 6)
	column.add_child(grid)
	for need in NEEDS:
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 1)
		grid.add_child(cell)
		var head := HBoxContainer.new()
		cell.add_child(head)
		var label := small(need.capitalize(), 13, 0.85)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(label)
		values[need] = small("", 13, 0.85)
		head.add_child(values[need])
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(110, 8)
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

	info_label = small("", 13, 0.75)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(info_label)
	var activity := HBoxContainer.new()
	column.add_child(activity)
	activity_label = small("", 13, 0.85, true)
	activity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	activity_label.clip_text = true
	activity.add_child(activity_label)
	activity_pct = small("", 13, 0.85)
	activity.add_child(activity_pct)
	activity_bar = ProgressBar.new()
	activity_bar.custom_minimum_size = Vector2(0, 4)
	activity_bar.show_percentage = false
	var track := StyleBoxFlat.new()
	track.bg_color = BAR_BACK
	activity_bar.add_theme_stylebox_override("background", track)
	var done := StyleBoxFlat.new()
	done.bg_color = ACCENT
	activity_bar.add_theme_stylebox_override("fill", done)
	column.add_child(activity_bar)

	passport_tab = flat_button("<", func(): set_passport(not passport.visible))
	passport_tab.tooltip_text = "Passport"
	add_child(passport_tab)


func set_passport(on: bool) -> void:
	show_passport = on
	passport.visible = on
	passport_tab.text = ">" if on else "<"


func update_passport() -> void:
	name_label.text = player.npc_name
	if portrait.get_meta("look", "") != player.look:
		portrait.set_meta("look", player.look)
		portrait.texture = Looks.face(player.look)  # just the head
	mode_button.text = "%s  (Tab)" % ("Auto" if player.auto_mode else "Manual")
	var emotion := Emotions.describe(player)
	mood_word.text = emotion
	mood_line.value = Social.mood(player) / 100.0
	mood_line.queue_redraw()
	reasons_label.text = Emotions.reasons(player, 3) if not player.moodlets.is_empty() else "Nothing special"
	var key := Skills.summary(player)
	if key != skills_key:
		skills_key = key
		for n in skills_row.get_children():
			n.queue_free()
		for skill in player.skills:
			if Skills.level(player, skill) <= 0:
				continue
			var chip := PanelContainer.new()
			var style := UiTheme.flat(Color.WHITE, ACCENT)
			style.content_margin_left = 8
			style.content_margin_right = 8
			style.content_margin_top = 1
			style.content_margin_bottom = 1
			chip.add_theme_stylebox_override("panel", style)
			var label := Label.new()
			label.text = "%s  %d" % [skill, Skills.level(player, skill)]
			label.add_theme_font_size_override("font_size", 14)
			chip.add_child(label)
			skills_row.add_child(chip)
	for need in NEEDS:
		var value: float = player.needs[need]
		bars[need].value = value
		fills[need].bg_color = need_color(value)
		values[need].text = str(int(value))
		values[need].modulate = LOW if value < 25.0 else Color(1, 1, 1, 0.85)
	var lines := ["%s%s%s · %s" % [Ages.describe(player), " · pregnant" if player.pregnant_until >= 0.0 else "",
		" · degree" if player.degree else "", player.world.location_name(player)], job_text()]
	if not Mind.states(player).is_empty():
		lines.append("Mind: " + ", ".join(Mind.states(player)))
	var net := Net.find(get_tree())
	if net and net.role != "":
		lines.append(net.status_text())
	info_label.text = "\n".join(lines)
	activity_label.text = player.shown_activity(player)
	var using: bool = player.state == "using" and player.step.get("seconds", 0.0) > 0.0
	var progress := clampf(1.0 - player.use_timer / player.step.seconds, 0.0, 1.0) if using else 0.0
	activity_pct.text = "%d%%" % int(progress * 100.0) if using else ""
	activity_bar.value = progress * 100.0
	activity_bar.visible = using


# The tabs sit at the screen edge when closed and next to their panel when open.
func place_tabs() -> void:
	var screen := get_viewport().get_visible_rect().size
	today_tab.position = Vector2(today_panel.position.x + today_panel.size.x + 6 if today_panel.visible else 4, MARGIN + 8)
	var right: float = passport.position.x - passport_tab.size.x - 6 if passport.visible else screen.x - passport_tab.size.x - 4
	passport_tab.position = Vector2(right, MARGIN + 8)


# --- Chat feed and new events (above the household row) ---

func build_feed() -> void:
	feed_panel = card()
	feed_panel.anchor_top = 1.0
	feed_panel.anchor_bottom = 1.0
	feed_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN  # grows upward as lines come in
	feed_panel.offset_left = MARGIN
	feed_panel.offset_bottom = -BAR_HEIGHT - MARGIN - 10
	feed_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(feed_panel)
	var column := VBoxContainer.new()
	feed_panel.add_child(column)
	chat_label = Label.new()
	chat_label.add_theme_font_size_override("font_size", 15)
	chat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chat_label.custom_minimum_size = Vector2(380, 0)
	column.add_child(chat_label)
	events_label = small("", 13, 0.7, true)
	events_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	events_label.custom_minimum_size = Vector2(380, 0)
	column.add_child(events_label)


func update_feed() -> void:
	var now := Time.get_ticks_msec()
	chat = chat.filter(func(e): return now - e.at < CHAT_SECONDS * 1000.0)
	chat_label.visible = not chat.is_empty()
	chat_label.text = "\n".join(chat.map(chat_text))
	var ours := Social.event_log.filter(ours_event)  # only what happens to your household
	var newest: String = Social.format_event(ours[-1], player) if not ours.is_empty() else ""
	if newest != last_event:
		last_event = newest
		events_until = now + int(EVENT_SECONDS * 1000.0)
	var recent := ours.slice(maxi(0, ours.size() - FEED_EVENTS))
	events_label.text = "\n".join(recent.map(func(e): return Social.format_event(e, player)))
	events_label.visible = newest != "" and now < events_until
	feed_panel.visible = chat_label.visible or events_label.visible


# Right-hand drawer listing your relationships. Hidden until opened.
func build_drawer() -> void:
	drawer = PanelContainer.new()
	drawer.anchor_left = 1.0
	drawer.anchor_right = 1.0
	drawer.anchor_bottom = 1.0
	drawer.offset_left = -DRAWER_WIDTH - 16
	drawer.offset_right = -16
	drawer.offset_top = MARGIN
	drawer.offset_bottom = -BAR_HEIGHT - MARGIN * 2  # above the bottom row
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_width_left = 2
	style.border_color = ACCENT
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
		b.custom_minimum_size = Vector2(0, BAR_HEIGHT)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = "%s · %s" % [Ages.describe(c), "you control them" if c == player else "click to control"]
		if c == player:  # who you are: a double lilac border, like the mockup
			var on := UiTheme.flat(UiTheme.ACTIVE_FILL, ACCENT, 2)
			on.expand_margin_left = 2
			on.expand_margin_right = 2
			on.expand_margin_top = 2
			on.expand_margin_bottom = 2
			on.shadow_color = UiTheme.ACCENTS[8]
			on.shadow_size = 3
			for state in ["normal", "hover", "pressed"]:
				b.add_theme_stylebox_override(state, on)
		elif Ages.stage(c) <= Ages.TODDLER:
			b.modulate = Color(1, 1, 1, 0.75)
			b.tooltip_text = "%s · not playable: click to see their needs" % Ages.describe(c)
		b.pressed.connect(pick_household.bind(c))
		household_row.add_child(b)


func pick_household(c: Node2D) -> void:
	if Ages.stage(c) <= Ages.TODDLER:
		show_child(c)
	elif c != player:
		Net.order(game, "control", [c.npc_name])


# --- Babies and toddlers (not playable: you see their needs and look after them) ---

func build_child_panel() -> void:
	child_panel = PanelContainer.new()
	child_panel.offset_left = 16
	child_panel.offset_top = 300  # below Today
	child_panel.custom_minimum_size = Vector2(300, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
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
	Net.order(game, "care", [child.npc_name, action])


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

		var lines := []
		if met:  # strangers: nothing about what they're doing or how they feel
			lines.append("Feeling %s · %s" % [Emotions.describe(c).to_lower(), where(c, met)])
			lines.append("Their view of you: %s (%+d)" % [Social.relationship_word(Social.friendship(c, player)), Social.friendship(c, player)])
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
		return "No job yet (get one at the Bus stop)" if Ages.is_grown_up(player) else "No school"
	var t: float = player.world.now()
	var when := "at work now" if player.at_work else "WORK TIME: go to the Bus stop" if Jobs.should_work(player, t) else ""
	if when == "":
		var next := Jobs.next_shift(player, t)
		when = "next shift %s %s" % [GameTime.weekday(next).substr(0, 3), GameTime.clock_text(next).substr(0, 5)] if next >= 0.0 else ""
	if Jobs.is_school(player.job):
		return "%s · %s · grade %s" % [player.job, when.replace("work", "school").replace("shift", "class"), Jobs.grade(player.performance)]
	return "%s at the %s, $%d/h · %s · performance %d%%%s" % [Jobs.title(player), player.job, Jobs.hourly(player), when,
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


# Smooth red → amber → green.
static func need_color(value: float) -> Color:
	if value < 25.0:
		return LOW
	return MID.lerp(HIGH, clampf((value - 25.0) / 60.0, 0.0, 1.0))


func _process(_delta: float) -> void:
	update_household()
	money_label.text = "$ %d" % player.money
	money_label.modulate = LOW.darkened(0.2) if player.money < 0 else Color.WHITE
	toast.visible = Time.get_ticks_msec() < toast_until
	if child_panel.visible:
		update_child_panel()
	var t: float = player.world.now()
	time_label.text = GameTime.clock_text(t).substr(0, 5)
	date_label.text = "%s  %s" % [GameTime.weekday(t).to_upper(), Weather.icon(player.world.weather)]
	time_label.tooltip_text = "%s · %s · %s · %s" % [GameTime.part_of_day(t), player.world.weather, GameTime.date_text(t), game.speed_text()]
	paused_label.visible = game.paused
	for n in speed_buttons.size():
		var active: bool = game.paused if n == 0 else (not game.paused and not game.sleep_boost and game.speed == n - 1) \
			or (n == 4 and game.sleep_boost and not game.paused)
		speed_buttons[n].set_pressed_no_signal(active)
		speed_buttons[n].disabled = Net.is_client(get_tree())  # joined: the host decides the speed
	if passport.visible:
		update_passport()
	if today_panel.visible and Time.get_ticks_msec() >= today_refresh_at:  # twice a second
		today_refresh_at = Time.get_ticks_msec() + 500
		fill_today()
	place_tabs()
	if drawer.visible and Time.get_ticks_msec() >= drawer_refresh_at:  # twice a second, even when paused
		drawer_refresh_at = Time.get_ticks_msec() + 500
		fill_drawer()
	update_feed()


# --- Chat feed ---

# Someone said (or thought, or did) something: npc.gd show_emote(). Goes in the feed if you can hear it.
func heard(c: Node2D, text: String, with: Node2D) -> void:
	if player == null or not hears(c, with):
		return
	var now := Time.get_ticks_msec()
	if chat.any(func(e): return e.who == c and e.text == text and now - e.at < 10000):
		return  # a crying baby doesn't fill the feed
	chat.append({"who": c, "text": text, "with": with, "at": now})
	if chat.size() > CHAT_LINES:
		chat.pop_front()


# A social event that involves someone in your household (you see nothing about other households).
func ours_event(e: Dictionary) -> bool:
	for who in [e.get("a"), e.get("b")]:
		if who and is_instance_valid(who) and who.home == player.home and player.home >= 0:
			return true
	return false


# You hear what's said near you, but not strangers talking among themselves (only to you).
func hears(c: Node2D, with: Node2D) -> bool:
	if c == player or with == player:
		return true
	if not player.known.has(c.npc_name):
		return false
	return c.is_visible_in_tree() and c.building == player.building and c.floor == player.floor \
		and c.grid_pos.distance_to(player.grid_pos) <= HEAR_RADIUS


# One feed line, with names as you know them: "Sam: Good morning, you!", "Unknown thinks: ...".
func chat_text(e: Dictionary) -> String:
	var name := "Someone" if not is_instance_valid(e.who) else "You" if e.who == player else Social.display_name(player, e.who)
	var who := "" if e.with == null or not is_instance_valid(e.with) else "you" if e.with == player else Social.display_name(player, e.with)
	var text: String = e.text.replace("{who}", who)
	if text.begins_with("~ ") and text.ends_with(" ~"):
		return "%s thinks: %s" % [name, text.substr(2, text.length() - 4)]
	return "%s: %s" % [name, text]


# The pastel look (ui_theme.gd) on every panel, button and label of the HUD.
func apply_theme() -> void:
	for child in get_children():
		if child is Control:
			child.theme = UiTheme.get_theme()


# --- Game menu (☰, bottom right) ---

const SaveGame = preload("res://scripts/save_game.gd")
const Session = preload("res://scripts/session.gd")


func on_game_menu(id: int) -> void:
	if id == 10:
		toggle_relationships()
		return
	if id == 11:
		var dialog := AcceptDialog.new()
		dialog.title = "Controls"
		dialog.dialog_text = CONTROLS
		dialog.theme = UiTheme.get_theme()
		dialog.confirmed.connect(dialog.queue_free)
		dialog.canceled.connect(dialog.queue_free)
		add_child(dialog)
		dialog.popup_centered()
		return
	if id == 12:
		open_settings()
		return
	if Net.is_client(get_tree()) and id in [0, 1, 2]:
		show_toast("Only the host can save this town")
		return
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


# Settings (☰ → Settings): volumes, mute, fullscreen, in a small window in the middle of the screen.
func open_settings() -> void:
	var window := PanelContainer.new()
	window.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PAPER, 4, UiTheme.LINE))
	window.anchor_left = 0.5
	window.anchor_right = 0.5
	window.anchor_top = 0.5
	window.anchor_bottom = 0.5
	window.grow_horizontal = Control.GROW_DIRECTION_BOTH
	window.grow_vertical = Control.GROW_DIRECTION_BOTH
	window.theme = UiTheme.get_theme()
	add_child(window)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	window.add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(flat_button("x", window.queue_free))
	SettingsPanel.build(column)


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
	if Net.find(get_tree()):
		Net.find(get_tree()).leave()  # hosting: the town closes for everyone
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
