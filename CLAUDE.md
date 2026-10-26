# Notes for Claude (and any developer picking this up)

Godot 4.7 isometric life sim prototype (The Sims × Project Zomboid). Read `README.md` for how the
systems work and `docs/DEVLOG.md` for history before changing anything.

## Workflow for every update
1. Make the change.
2. Run `godot --headless --import` if you added new files, then
   `godot --headless --fixed-fps 60 -s res://tests/check_sim.gd` and `godot --headless -s res://tests/check_online.gd`.
   Both must print `ALL PASSED` with no `SCRIPT ERROR` lines. Add checks to `tests/check_sim.gd` for new behavior.
3. Update `README.md` (tables and how-to sections must match the code) and add a `docs/DEVLOG.md` entry.
4. Launch for the user with `godot --path .` (run in the background; it opens on the home screen). The user can also
   double-click `play.command`. Tests load `scenes/main.tscn` directly (Jo & Sam, via `session.gd` defaults).

## Conventions
- Everything is built in code from `main.gd` (the game) and `menu.gd` (the home screen); the only scenes are
  `scenes/menu.tscn` (first scene) and `scenes/main.tscn`. Placeholder
  art is drawn in `_draw()`; furniture uses baked sprites (art/furniture).
- Use `preload("res://scripts/x.gd")` constants, not `class_name` (headless runs don't have the class cache).
- Game logic uses grid coordinates; convert only for rendering via `iso.gd`.
- There's no player script: every person is an `npc.gd`. The one you control has `controlled = true`
  (set by `controller.gd` `take_control()`, which also moves the camera and updates `main.player`, `world.player`,
  `hud.player`). Behaviour differences for the controlled person are `if controlled` checks in npc.gd hooks
  (`think`, `notice`, `is_available`, `time_for_work`, `label_text`). Input and menus live in `controller.gd`.
- Lasting mental states and learned tastes: `mind.gd`. Romance: `romance.gd` (only depends on ages/emotions).
- Tuning values (needs, objects, interactions) live in tables: `NEEDS`/`DECAY_HOURS` in `npc.gd`, time/calendar/seasons in `game_time.gd`, object
  setup in `main.gd`, `INTERACTIONS` in `social.gd`. Keep the README tables in sync.
- Never write a character's name directly into `activity` or the social log: use `{who}` + `activity_with`,
  or `{a}`/`{b}` in `Social.log_event()`, so unmet NPCs show as "Unknown".
- Indent with tabs (GDScript).
- Time: `world.clock` is real simulation seconds; anything in game time (spoiling, calendar, daylight) uses
  `world.now()` (game seconds). 1 real second = 1 game minute, so step `seconds` are game minutes.
- Everything in the world has a `floor` and a `building` (−1 = outside). Move characters with `walk_to(cell, floor)`
  (pathfinding); don't set `grid_pos`/`walk_target` directly. New visible things go under a `world.gd` container
  (a building floor, `outdoors`, or a chunk) so `update_view()` shows and hides them correctly.
- Anything a character does at objects is a task: a list of steps run by `run_steps()` (see `npc.gd` header).
  Kitchen tables (recipes, drinks) live in `kitchen.gd` and are documented in `docs/KITCHEN.md`: keep both in sync.
  A step's lambdas must not capture their own step dictionary (reference cycle → leak); `start` receives the step.
- People systems: moodlets/emotions in `emotions.gd`, traits in `traits.gd`, skills in `skills.gd`, memories and
  interactions in `social.gd`. All documented in `docs/PEOPLE.md`: keep its tables in sync. Give feelings with
  `Emotions.add(c, "Moodlet")`, skill xp with `c.practice(skill, minutes)` (handles level-ups), memories with
  `Social.remember()`. Script dependency order (no preload cycles): ages, traits ← emotions ← mind ← skills ← romance ← social ← jobs ←
  life ← llm ← npc; scripts that need something "above" them load it at runtime (`load(...)`).
- Homes: always move characters with `walk_to()` (it passes `self` to `world.find_path`, which keeps them out of
  homes they may not enter). Invitations live in `world.guests` (`invite`/`uninvite`/`can_enter`); knocking in `ownership.gd`.
- Money and jobs: `jobs.gd` (documented in `docs/WORK.md`). Characters at work have `at_work = true` (hidden,
  state "working"); anything that looks for people should skip them. Scripted tests that jump the clock must
  clear jobs (`reset()` in the test does) or shifts start/miss by surprise.
- Ages: `ages.gd` has no dependencies (use it anywhere); `life.gd` does ageing/births. Anything a character does
  must respect their stage (interactions `a_min`/`b_min`, `Kitchen.allowed`, `may_use`, `Jobs.can_take`).
  Pregnancy only for fertile adults (`Ages.fertile`), never family (`Ages.family`). Documented in `docs/LIFE.md`.
- NPC reactions to what they see go in `perception.gd` (`notice()` → a reaction function + table), not in `npc.gd`.

- Build mode: `catalog.gd` (items, rules; keep docs/BUILD.md's table in sync) and `build_mode.gd` (UI). The controller
  ignores the mouse while build mode is active.
- Character art: `looks.gd` + `tools/bake_characters.gd` (needs a window) → `art/characters`. Things drawn on top of a
  person go in `draw_overlay()` (npc.gd), not `_draw` (that's under the sprite).
- Art comes from the Tiny Treats packs in `assets/tinytreats/` (glTF; furniture, houses, trees) and the Kenney kits in
  `assets/kenney/` (characters, cars, roads, furniture Tiny Treats lacks; only GLBs are imported). In `MODELS`,
  `"<pack>/<model>"` is Tiny Treats, a bare name Kenney.
  Furniture: `tools/bake_furniture.gd` (sprite ids → kit models in `MODELS`) → art/furniture. Houses and trees:
  `tools/bake_neighbourhood.gd` → art/neighbourhood (`Furniture.*(…, Furniture.SCENERY)`); re-bake after changing a
  building's rect or colours. All bakers need a window. See README "Furniture art" / "Neighbourhood art".
- Cars and roads: `traffic.gd` (home cars, traffic, driving to work) and `car.gd`; road pieces and street-parked cars
  are made with the chunks in `world.gd`. Home cars' tiles are solid; driving cars don't block paths, they stop
  for people. Scripted tests drive a car with `car.drive(delta, world.traffic)`. See README "Cars and roads".
- Every catalog item is usable (an `object` + `actions.gd` entry); new furniture needs both. Rugs are `STAND_ON`.

- AI words: `llm.gd` (local Qwen3.5 via llama-server) and `talk_panel.gd`; documented in `docs/AI.md` (keep its
  tables in sync). The model only writes words and nudges (`wish_factor`); systems decide. Everything must still
  work with the AI off. Never give it a name the speaker doesn't know (`who(c, viewer)`). Tests use `llm.fake`.
- Labels over heads are only `Name - Mood` (`label_text()`); anything said goes through `show_emote()` → HUD chat feed.
- Online: `net.gd` (docs/ONLINE.md). The host simulates; joined games are puppets (`Npc.puppet`, `world.puppet`,
  `llm.remote`). Anything the player does from the UI must go through `Net.order(game, kind, args)` (handled in
  `Net.run()`), never call methods on the body directly. Several people can be `controlled` on the host: find
  "who controls c" with `game.controller_of(c)`, not the "controller" group. Run `tests/check_online.gd` too.
- The body: `body.gd` (static; running, tripping, passing out, accidents, farts, illness, vomiting), documented in
  docs/PEOPLE.md "The body". People who are down have `state` "down" and `pose` set: don't give them orders
  (`cancel_current` refuses). New sprite frames go in `looks.gd` (FRAMES) + `tools/bake_characters.gd` POSES (a kit animation + time), then
  re-bake (needs a window).
- Sound: `music.gd` (/root/Music, `Music.play(tree, "menu"/"home"/"outside")`, real-time fades, not affected by
  game speed) and `settings.gd` (buses Master/Music/Sounds, user://settings.cfg). New sound effects go on the
  "Sounds" bus. Version: `application/config/version` in project.godot (shown on the home screen).
- Houses can change: `World.BUILDINGS` is this game's copy of `START_BUILDINGS` (stairs/upper floors from build mode;
  `building_state()` is saved and synced online). Build-mode walls are props with `wall = true`.
- The view is Project Zomboid style (`vision.gd`, `weather.gd`, docs/VIEW.md): the neighbourhood is always shown,
  people only when `world.vision.sees()` them. Scripted tests that move people must call `world.update_view(true)`
  (sight is recalculated every 150 ms of real time). The ground is z −2, the sight veil −1.
- Strangers: nothing over their head, no feeling/traits/thoughts in menus, no chatter, and the events feed shows only
  your household (`hud.ours_event`). Use `player.known` to decide what a stranger reveals.
- Furniture names only show on mouse-over (smart_object.gd); don't add always-on labels to the world.
- Saving: a new per-person field that should survive save/load must be added to `SAVE_FIELDS` in `save_game.gd`.
- UI: use `ui_theme.gd` for new controls (keep it cozy): `PALETTE` is the atmosphere (world, backdrop, panel paper),
  `ACCENTS` the UI accent (#9ba9ff = active). Flat cards/buttons with thin borders, EB Garamond (`UiTheme.font()`,
  italic for subtitles). Labels in the world set `UiTheme.font()` themselves (changing the engine's default theme
  font makes the renderer report leaked textures at exit). Find the HUD with `main.hud`, not "first CanvasLayer".

## Gotchas
- Don't `draw_texture()` in `_draw` for world sprites: it renders white inside the y-sorted world (use Sprite2D).
- Capturing a screenshot needs a non-headless run: `root.get_texture().get_image().save_png(path)` in
  a `-s` script after ~2s.
- `PopupMenu.set_item_disabled` needs a real index (`item_count - 1`), not `-1`.
- Palette shades used in constants are precomputed literal `Color(...)` values (constants can't call `.darkened()`).
