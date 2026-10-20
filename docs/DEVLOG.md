# Dev log

Newest first. Each entry: what changed, why, and anything to watch out for.

## 2026-10-20 — Talk while busy, every piece of furniture usable, cars and roads
- **Talking to someone busy doesn't interrupt them**: if they're using something,
  queueing or on the way to it, they keep doing it (`busy_talk`); the initiator comes to where they are and talks
  while they carry on (Social.begin leaves their state alone, end_social doesn't reset it). Task over first: they
  stop and wait or join in. They walk off: the initiator follows up to `MAX_CHASES` times, and a talk ends
  ("Never mind") if they get more than `TALK_REACH` + 1 tiles away. Asleep: "is asleep". Talk… (typed) works the same.
- **Every catalog item is usable**: new `actions.gd` entries for nightstands, coffee table, desk, kitchen cabinet and
  drawers, washing machine, lamps, plants, rugs, shelves, dressers, coat rack, bins, radio and teddy bear (toddlers may
  cuddle it). Rugs are `STAND_ON` (used standing on them, walkable, drawn flat). Your house's `PROPS` and props in
  older saves become their catalog objects (`Catalog.make_object`, `id_for_model`); four of them were turned to face
  into the room so they can be reached.
- **Roads** from Kenney's City Kit (Roads): 3×3-tile straight and crossroads pieces per chunk (`world.road_pieces`),
  graded to pastel. **Cars** from the Car Kit (7 models × 4 headings, `tools/bake_neighbourhood.gd`).
- **traffic.gd / car.gd** (new): a home car per house (`BUILDINGS` `car`, tiles solid), hundreds of street-parked cars
  (`park_cars`, `parked_cells`), and up to 5 traffic cars near you in right-hand lanes, turning at crossroads, stopping
  for people and the car ahead, shown only where you can see. **Driving to work**: grown-ups with a job take the home
  car if it's there (`go_to_work` → `drive_off`; `Jobs.working` → `come_back`, `parked_back` ends the shift), else the bus.
- Riley's car sits west of the house (east, it would close the gap between Riley's and the Starter house).
- Tests: `check_busy_talk`, `check_commute`, `check_traffic`; the work test takes the bus (car marked away); the
  "NPCs completed social interactions" check now counts over the whole run (the 8-entry log filled up with skill
  level-ups now that lots of furniture trains skills, so it failed now and then).
- Online: `busy_talk` is synced (`Net.PERSON_EXTRAS`). `check_online.gd`'s Talk… step now keeps walking Alex after
  Mia until they're close (she wanders off to use things more now, which made the old 4 s timing fail often), and
  accepts her talking while busy.
- **Watch out:** people walk through driving cars (only parked ones block paths). Online, traffic is local and
  cosmetic on joined games; commutes only show on the host. The asphalt colour is `ROAD_DARK` in the baker.

## 2026-10-20 — Kenney art: characters, furniture and the neighbourhood's houses
- **Assets:** the Kenney kits (Mini Characters, Furniture Kit, City Kit (Suburban), CC0) unzipped in `assets/kenney/`;
  only their GLBs are imported (`.gdignore` in the FBX/OBJ/DAE/STL and preview folders). The old Quaternius packs
  (`assets/characters`, `assets/furniture_obj`, the four zips) are deleted.
- **Characters** (`tools/bake_characters.gd`, rewritten): each look is a kit model (`looks.gd` `model`), posed by
  sampling its own animations (`POSES`: idle, walk, sit, static for bed, sprint, pick-up, die) instead of turning
  bones and painting clothes. Same sheet layout (8 × 13, 96×112, feet at (48, 100)), so npc.gd is unchanged.
  New look `kai` (household creator). Labels describe the new models.
- **Furniture** (`tools/bake_furniture.gd`): sprite ids stay the game's names (saves, catalog, PROPS keep working);
  `MODELS` maps each to kit model(s), stacked (lamp on a side table, TV on its cabinet). Kit colours, softened, instead
  of tinting. The TV finally has a model; the fireplace is a placeholder box (no fireplace in the kit). New catalog
  decor: coffee table, desk, coat rack, radio, teddy bear.
- **Neighbourhood** (`tools/bake_neighbourhood.gd`, new → `art/neighbourhood`): houses from the suburban kit, two
  models per building (`models`: one / two storeys), turned to the door, stretched over the rect, palette repainted
  in the house's wall and roof colours, plus a snowy winter version; trees in each season's leaf colour.
  `world.gd build_exterior` cuts the house sprite into 16 px strips y-sorted at the front wall; the per-tile boxes
  stay as invisible click areas (`Block.under_sprite`) that still draw closed curtains. Winter rebuilds exteriors.
- **Doors moved to match the models:** your house (487,508) → (485,508); Starter house (507,522) → (507,525), and its
  shower (506,524) → (505,524) so the tile inside the door stays free.
- `furniture.gd` takes a folder (`Furniture.SCENERY` for the neighbourhood).
- Tests: `check_art()` (everything baked, houses are strips over click boxes, strips sort behind people at the door,
  snowy winter roofs, trees have sprites); door cells updated.
- **Watch out:** `check_online.gd` failed once on "Mia stops to talk with Alex" (a 4 s walk timing) and passed 3 times
  after; looks like an old timing flake. Re-bake houses after changing a building's rect, colours or models.

## 2026-10-20 — Zomboid-style sight, light and weather; strangers stay strangers
- **Strangers:** nothing above the head of someone you haven't talked to (then `Name - Mood`); their menu shows no
  feeling, traits or thought; the relationships drawer says only "You haven't met yet"; you don't hear them talking
  among themselves; the events feed shows only your household's events (`hud.ours_event`).
- **View (Project Zomboid style):** the neighbourhood is always on screen, inside or out; the house you're in opens up,
  other houses show their exterior. **vision.gd** casts 480 rays from your sim every 150 ms: walls block, windows and
  doors don't; 180° cone in front (28 tiles by day, 3.5 in the dark), 4.5 behind; lamps and homes with someone awake
  are lit at night. Out of sight: a soft veil (one pixel per tile on a linear-filtered texture mapped onto the iso grid),
  light where you remember, thicker where you've never been; trees, exteriors and furniture tinted the same; people
  only shown when seen. Ground moved to z −2 under the veil (−1).
- **Weather** (weather.gd, weather_fx.gd): clear / cloudy / rain / fog by season (fog likelier in the morning), 3–8 h
  spells, shortens outdoor sight; rain falls and fog veils the screen (real time). Saved; online the host sends it.
  Weather sign next to the weekday.
- Tests: the old "inside, the outside is hidden" checks became "people only when seen, other houses' rooms hidden,
  the neighbourhood always there"; new vision checks (walls, memory, far ahead, close behind, fog, night, people in the
  dark). Tests that move people call `world.update_view(true)`.
- **Watch out:** a sight update costs ~8 ms; keep RAYS × range modest. Windows let sight through both ways.

## 2026-10-20 — More human bodies, drawn walls, build-mode music
- **body.gd** (new): running (in a hurry, or Shift+click; ×1.8) with **tripping**, **passing out** at 0 energy,
  **fainting** at 0 hunger, **accidents** at 0 bladder, **farting** (with reactions), **illness** (cold, flu, food
  poisoning from stale/spoiled food; contagious, slower, tired, sleep heals faster) and **throwing up**. People who are
  down are in state "down" with a `pose`; witnesses laugh, worry or are grossed out. 10 new moodlets. Old "Nothing
  happens at 0" limitation removed.
- **New sprite frames** (13 per row now): run ×4, bent over, down on the floor (baked raised to fit the cell and
  lowered by `Looks.DOWN_DROP` in game). All sheets re-baked.
- **Build mode:** press-drag-release draws a straight line of walls (`line_cells`, a green/red tile preview), and a
  **Remove walls** tool does the same to take them out. The build-mode song plays while building (music.gd "build").
- Saved: illness, symptoms, next fart, last meal (`SAVE_FIELDS`). Online: `pose` and `running` are in the fast update.
- Tests: running, tripping and getting up, passing out (energy back), fainting, accidents, farts and reactions, food
  poisoning, throwing up, being sick (slower, tired) and recovering; drawing a wall line.

## 2026-10-20 — v0.0.1: home screen, music, settings, walls and stairs
- **Version 0.0.1** (`application/config/version` in project.godot), shown on the home screen.
- **Home screen** after the mockup: key art on the left (`key_art.gd`: a little room with the household made of the
  game's own pieces; pages open there instead), on the right "A life simulation", **Meow *Mewo***, the menu (Play
  game outlined, Quit as accent text, a small sign on each), "Loading the neighbourhood…" with a bar (the game scene
  loads in the background with `ResourceLoader.load_threaded_request`) and the version. New **Settings** page.
- **Music** (`music.gd`, /root/Music): home screen / inside your own home / anywhere else, crossfading over 2 s on
  real time; game speed and pause don't affect it. **Settings** (`settings.gd`, `settings_panel.gd`): Volume, Music,
  Sounds, Mute, Fullscreen, saved in user://settings.cfg; on the home screen and in ☰ → Settings.
- **Build mode: walls and stairs** (new Build category). A wall is a prop with `wall = true` (a cut-down wall block,
  blocks walking and sight; sell/move like furniture; saved and synced as props). Stairs ($1500) in a one-storey house
  add an upper floor (`world.add_upper_floor`; the exterior is rebuilt taller); removable while upstairs is empty
  (`remove_upper_floor`, `Catalog.remove_stairs`). `World.BUILDINGS` is now a per-game copy of `START_BUILDINGS`;
  `building_state()` is saved (`world.buildings`) and sent with the online `layout`.
- **Less on screen:** furniture names only show on mouse-over; the "Stairs" label is gone; no AI line in the passport.
- llama-server is started with `--log-disable` (its log was flooding the terminal).
- Tests: walls block and free tiles and sight; stairs add an upper floor that can be reached, can't be removed while
  something's upstairs, come out for 75%, and the building state round-trips.
- **Watch out:** at exit Godot may report the music's AudioStreamMP3 / playbacks as leaked: stopped playbacks are only
  dropped by the audio server's next mix, which doesn't come during shutdown (harmless). Build mode pauses time, so
  scripts that wait in build mode must use real time.

## 2026-10-20 — Cozy planner look: lilac accents, serif, head portraits
- New `ACCENTS` palette in ui_theme.gd (#9ba9ff → #f4ccff) for the UI accent; `PALETTE` (#c9def4 → #f5ccd4) stays the
  atmosphere (world, panel paper) and now also fills the space behind the world as a gradient (`UiTheme.backdrop()`
  on a CanvasLayer at -10, dimmed with the daylight).
- Theme rewritten after the mockup: flat cards with thin borders and small corners, flat buttons (pressed = lilac
  fill + periwinkle border), **EB Garamond** (assets/fonts, OFL) with italics for subtitles, also on world labels.
  The bubbly pill buttons are gone. Today has an accent line on top and a dotted timeline; the passport has a
  dashed skills box and lilac chips; the person you control has a double-bordered chip; need bars go lilac →
  periwinkle (rose under 25).
- **Head portraits:** `tools/bake_characters.gd` renders each look's head close-up (`-- portraits` for only those)
  → `art/characters/<look>_face.png`, `Looks.face()`; the passport shows it.
- Chat feed: you only hear people in the same building as you (neighbours' greetings leaked in at the start).
- Tests found the HUD as "the first CanvasLayer", which became the backdrop: they use `main.hud` now.
- **Watch out:** don't set `ThemeDB.get_default_theme().default_font`: the renderer then reports the font's glyph
  textures as leaked at exit. World labels set `UiTheme.font()` on themselves.

## 2026-10-20 — A lighter screen: bottom row, Today and Passport tabs
- New HUD layout (from a mockup): only a **bottom row** is always on screen: household + money (left), clock and
  weekday + pause/speeds + Build mode (centre), ☰ menu (right: Relationships, Controls, save/exit/quit). The old
  footer band, top-left info panel, top-right clock panel and the controls cheat sheet are gone.
- **Today** (`>` tab, top left): what you're doing (minutes left), the task's next steps, your next shift or school
  day, your AI wish (`hud.today_items()`). **Passport** (`<` tab, top right): portrait (head and shoulders), name,
  Manual/Auto, a mood line (`MoodLine`, Social.mood) with the emotion word, skill chips, the 7 needs, info lines,
  and the current activity with a progress bar. Both hidden until opened; `show_today`/`show_passport` are static
  so they stay open across games.
- The chat feed sits above the household row and hides when nothing's new; social events show for 20 s after
  something happens (`EVENT_SECONDS`). Kept the pastel theme (not the mockup's beige) per the project's look.
- Tests: tabs start closed, open and close; Today's first item and the passport's progress.

## 2026-10-20 — Online mode (same Wi-Fi), labels are just "Name - Mood"
- **Labels:** above heads only `Name - Mood` (strangers `Unknown - Mood`); F3 adds the activity and details.
  Lines, reactions, thoughts and "Level up!" go to a **chat feed** in the HUD (bottom left, above the social
  events): what's said near you, for a minute, names as you know them (`hud.gd heard()`, from `show_emote()`).
  `Llm.wrap_line` is gone (nothing is drawn over heads any more).
- **Online mode** (`net.gd`, docs/ONLINE.md): Play Online → Host a town / Join a town (found on the Wi-Fi by a
  UDP beacon, or by address). The host runs the simulation; joined games start from `SaveGame.capture` and are
  puppets (`Npc.puppet`, `world.puppet`, `llm.remote`) fed by `fast` (0.1 s) and `slow` (1 s) updates, `layout`
  when furniture changes and `heard` for speech. Joined players' clicks are resolved on their screen and run on
  the host by a Controller per player (`controller.gd peer`); menus are sent back. Up to 4 players.
- **Talk… between players** (`talk.gd`, split out of talk_panel.gd): your words go to the other player's window,
  no AI; with NPCs it's the host's model. The talk panel is now only the window.
- Everything a player does from the UI goes through `Net.order()` (mode, switching household member, care,
  talking, clicks). Who controls someone: `game.controller_of(c)` (life.gd deaths, ownership.gd knocking).
- `save_game.gd` split into `capture_person/object/props/log` and `make_person/object/prop` (used by net.gd).
  Objects get a `net_id` (saved) so every computer agrees which is which.
- Online the host decides the speed, sleeping doesn't speed time up, build mode is offline only, only the
  host saves. A player who leaves: their household goes back to the AI. The host leaving closes the town.
- Tests: `tests/check_online.gd` (+ `tests/online_host.gd`): a real host process joined over 127.0.0.1 (household
  list, snapshot, puppets, clock, click to walk, host-built menu, Talk… through the host, chat feed).
  check_sim: labels, chat feed, talking to a real person.
- **Watch out:** /root/Net must have the same path on both sides (RPCs); main.gd hosts with `call_deferred`
  (the root is busy adding the scene in `_ready`). `leave()` renames the node so a new one can be made at once.

## 2026-10-20 — AI words: local Qwen3.5 from Hugging Face
- Asked for Qwen3.8 from Hugging Face, but its smallest model (27B) doesn't fit in this Mac's 8 GB, so the game
  uses **Qwen3.5 4B** (`unsloth/Qwen3.5-4B-GGUF:Q4_K_M`, ~2.7 GB) through llama.cpp's `llama-server` (`brew install
  llama.cpp`). With a window, `llm.gd` starts the server on port 8765 (it downloads the model on the first start)
  and stops it when the game ends. Full details in docs/AI.md.
- The systems still decide; the model writes words: **conversation lines** near you (replacing the scripted
  line, plus the partner's reply), **thoughts** (`~ … ~` and in the click menu), **wishes** (what an NPC feels like
  doing for 3 game hours: ×1.6 in `choose_action()`), and **Talk…** in a person's menu: a panel (talk_panel.gd)
  where you type and they answer in character; the tone of your words changes their friendship toward you.
- Prompts are built from traits, emotions, mind, needs, job, partner, friendship, family and memories. Strangers
  stay "a stranger" in prompts, so the model can't use a name the speaker doesn't know.
- Without the server nothing changes (scripted lines). The HUD shows AI off / starting… / online.
- Tests: `check_llm()` with a fake server (`llm.fake`): cleaned text, wrapped rows, stranger names hidden,
  written line + reply, late lines dropped, short conversations skipped, thoughts, wishes (boost, expiry, invalid
  choices ignored), the talk panel (stop to talk, friendship by tone, meeting, memory, log).
- **Watch out:** `show_emote()` takes an optional duration now (written lines stay longer). `wrap()` is a GDScript
  built-in, hence `Llm.wrap_line()`. Headless runs never contact a server: set `llm.fake` in tests.

## 2026-10-16 — Outdoor sky through the day
- Outside, the screen tint now follows a sky gradient (`SKY` + `sky_keys()` in `game_time.gd`): deep night, pink-lilac
  dawn, cool blue morning, bright afternoon, golden hour, pink-coral sunset, violet dusk. Keyframes sit around each
  season's sunrise/sunset, so winter evenings get dark early. Indoors keeps the palette (untinted by day, pink lamplight
  at night). Furniture colours unchanged. `NIGHT_TINT`/`DUSK_TINT` removed.
- Tests: blue morning, white afternoon, warm sunset, dark night outside; untinted indoors by day; keyframes ordered
  in every season.

## 2026-10-16 — Palette and bubbly buttons
- One 7-shade palette (`#c9def4` … `#f5ccd4`, `PALETTE` in `ui_theme.gd`) now drives the whole environment: ground per
  season, roads, houses and roofs, floors, interior walls, blossom trees, dusk and night tints, the home-screen gradient
  and bubbles. Furniture re-baked with palette tints (`TINTS` in bake_furniture.gd, 180 sprites).
- **Bubbly buttons:** `UiTheme.bubble()` pill style (raised bottom edge, shadow; pressed = baby blue and sinks).
- **Watch out:** constants can't call `.darkened()`/`.lightened()`, so shaded palette colours are literal `Color(...)`
  values; recompute them if the palette changes.

## 2026-10-16 — Pastel look, home screen, households, saving
- **Pastel, cutesy look:** new palette for terrain, roads, trees (cherry blossom in spring), houses (each with its own
  roof colour), floors, walls, windows, doors, night tint; `ui_theme.gd` (rounded light panels, candy buttons, lilac text)
  on the HUD, build mode and menus; world labels dark-on-white. Furniture re-baked with a pastel tint per kind
  (`TINTS` in bake_furniture.gd), characters with a softer finish.
- **Home screen** (`scenes/menu.tscn` is now the main scene; `menu.gd`): Play Game (choose one of 3 households, or create
  a new one: name + up to 4 people with sex, age, look with preview, traits; validated), Continue, Saved Games (load/delete),
  Quit. `session.gd` carries the choice to main.gd.
- New **Starter house** (building 3) with basic furniture for created households ($1,500 shared by the grown-ups;
  children get them as parents). `main.gd` split into `place_furniture`, `spawn_residents`, `spawn_household`.
- **Saving** (`save_game.gd`): a full snapshot (people via `SAVE_FIELDS`, objects, props, world, log) with store_var in
  `user://saves/<slot>.save`; `restore()` rebuilds it. Social log entries keep names, so people who died still show.
- In-game **Menu ▾** under the clock: save, save as new, save and exit, exit to main menu, quit; a "Game saved ✿" toast.
- Tests: save → load round trip (people, money, relationships, ages, looks, skills, control, clock, furniture, log),
  delete, new household (starter house, funds, parents, school), choosing Alex's family, creator validation.
- **Watch out:** static vars (Social.event_log, Session) survive scene changes; main.gd clears the log on start.
  Adding a field to people that should persist means adding it to `SAVE_FIELDS`.

## 2026-10-16 — Real characters (Quaternius Universal Base Characters)
- The pack (CC0, free version: rigged bodies in underwear, no animations) is in `assets/characters` (only the Godot
  glTF files, the light-skin textures, and two normal maps copied under the names the glTFs expect).
- New `tools/bake_characters.gd`: poses the skeleton in code (arms down, 4-frame walk, sit, lie), paints clothes by
  bone with a shader (shirt/pants/shoes colours per look), attaches hair to the head bone, and renders 8 directions ×
  7 frames per look into `art/characters/<look>.png`. New `looks.gd` with 11 looks (7 residents + 4 for newborns).
- `npc.gd`: a `Sprite2D` body animated in `animate()` (direction from movement, walk cycle, sit, lie on the bed),
  kids scaled by stage, babies still a bundle; progress bar and carried plates moved to an `Overlay` child drawn on top.
  `set_look()`; newborns get `Looks.random_for(sex)`.
- Tests: everyone has a sheet, babies a bundle plus a future look, walking uses the right row/frames, sitting and
  sleeping frames, direction mapping.
- **Watch out:** anything drawn in the person's own `_draw` is under the sprite; put things that must show on top in
  `draw_overlay()`.

## 2026-10-16 — Furniture interactions, rotate/delete in build mode
- New `actions.gd`: per-furniture interactions (Bed: Sleep/Nap/Relax; Couch: Relax/Sit/Nap; Chair: Sit; Toilet: Pee/Poo;
  Shower: Shower/Bath; Bathroom sink: Wash hands/Brush teeth; TV: comedy/news/cooking show; Bookshelf: textbook/novel/
  cookbook; Fireplace; Bench; Pull-up bar). Clicking an object with several opens a menu; NPCs score each action
  (with ±15% variety). `use_object(obj, action)`; steps carry `asleep` (naps count as sleep). `time_factor` takes an action
  (only a night's Sleep gets the night bonus).
- **Seats** (couch, chair): you sit on the tile itself, which stays walkable (`is_seat()`, no solid tile).
- Your house's chairs, couch and bathroom sinks became usable objects (OBJECTS, with `facing` in extras).
- Build mode: Rotate (in place, with the same rules) and Delete (sell) next to Move. `rotate_to()` on objects and props.
- Tests: action lists, Poo, sitting on a chair, napping counts as sleep, pee/poo variety, fridge can't turn to the
  counter, couch and decor rotate.

## 2026-10-16 — Build mode
- New **build mode** (B / Build button, at home): paused, a catalog panel (10 categories, ~45 items with baked icons and
  prices), a green/red placement preview that follows the mouse, R to rotate, click to buy and place, right-click/Esc to
  cancel, click your furniture to sell (75%) or move. "Other floor" to build upstairs. **docs/BUILD.md**.
- `catalog.gd`: items, prices, rules (inside your home, free tile, not stairs/doorway, front tile free for usable
  furniture, nothing may become unreachable from the door), buy/sell/move. `build_mode.gd`: UI and input.
- Usable furniture is a real smart object (new **Couch** "Relaxing", **Fireplace**, plus beds, kitchen, toilet, bathtub,
  bookshelf, TV). Objects now have `facing` (rotation) and `use_cell()` follows it.
- All catalog models baked in 4 rotations (180 sprites).
- Tests: walls/doorway/stairs/outside refused, buying a rotated sofa (money, usable, front tile), blocking the fridge
  refused, rugs allowed, can't afford, selling refunds 75% and frees the tile, existing furniture recognised, moving
  is free, a bought bookshelf works, B opens/closes and pauses.
- **Watch out:** R rotates in build mode, so the relationships drawer ignores R while building.

## 2026-10-16 — Furniture from the 3D asset packs
- The user's packs (Blends, FBX, OBJ zips of the same 123 low-poly models) are in `assets/`; the OBJ version is
  unpacked in `assets/furniture_obj/` (Godot imports OBJ + MTL colours directly).
- New `tools/bake_furniture.gd` renders chosen models at the game's isometric angle and scale into
  `art/furniture/*.png` + `sprites.json` (floor anchors). 35 sprites (some in several rotations).
- Objects use sprites per type (`FURNITURE` in main.gd; your bed is a king): fridge, counter, oven, sink, table, beds,
  bathtub (for Shower), toilet, bookshelf. TV, bench, pull-up bar and bus stop keep boxes (no model).
- Your house is decorated with `PROPS` (new `prop.gd`): chairs, couch, rugs, lamps, plants, sinks, nightstand,
  armchair, dresser, shelf. New `world.add_prop()`; props block their tile unless flat.
- Tests: every object in every house reachable from its front door; furniture sprites in use.
- **Watch out:** draw sprites with `Sprite2D` nodes, not `draw_texture` in `_draw`: inside the y-sorted world the
  latter rendered as white rectangles (GL Compatibility). Re-run `godot --headless --import` after baking.

## 2026-10-16 — Household control, death, baby care, romance, mental health, many interactions
- **No more player script.** `player.gd` was split: what a person does moved into `npc.gd` (`controlled`, `auto_mode`,
  click_tile/click_building/order_interaction/peeking), input and menus into the new `controller.gd`. You start as
  **Jo** (`PLAYER_NAME` in main.gd). The **household bar** (top left) lists everyone in your home; click to control
  them (babies/toddlers open their needs panel). The controlled person has a green ring.
- **Death of old age:** lifespans 78–96 years; on death a grave appears near their home, family/partners grieve,
  friends feel loss. **No game over:** if you die you carry on as someone else in the household.
- **Babies and toddlers need care:** needs drop faster, they cry below 20 (and stress the house), babies nap. Care
  interactions Feed / Change & clean / Rock to sleep (+ Play with, Read a story), chosen by NPC carers from the
  little one's needs. Clicking a baby/toddler opens a panel from the left with needs and care buttons.
- **Romance** (`romance.gd`): romance score, chemistry per pair, Flirt, Kiss, Cuddle, Ask to be partners, Propose,
  Get married (moves in), Break up, Divorce, jealousy. New emotion **Flirty**. Try for a baby: partners or friends 70+.
- **More interactions:** Apologize (forgives grudges), Talk about feelings, Gossip, Brag, Vent, Ask for advice,
  High five, Tease and Prank (can backfire), Give a gift ($20), Play with, Read a story. 36 interactions in all.
- **Mind** (`mind.gd`): hourly emotion samples → lasting Depressed / Anxious / Thriving, plus Isolated and Burned out,
  each with effects (acceptance, needs, sleep, work performance, learning). Learned tastes for hobbies from how
  they felt afterwards.
- Unemployed grown-up NPCs look for a job each morning (`Jobs.find_work`).
- Tests: household and switching, death (grave, grief, control passes on), baby crying/feeding, care scores,
  the baby panel, romance chain (flirt → kiss → dating → engaged → married → jealousy → divorce), apologize, gift,
  prank backfiring, depression/support/recovery, anxiety and sleep, isolation, burn-out, learned tastes.
  Three weeks at Ultra: two couples formed (one married), care and support happened on their own, NPCs found work.
- **Watch out:** romance isn't need-driven (`Romance.desire`); without it NPCs never flirt (their social need is
  usually met). Learning only applies to `Mind.LEARNABLE` hobbies.

## 2026-10-16 — Ages, schools, babies, getting fired
- New `ages.gd`, `life.gd` and **docs/LIFE.md**. Life stages Baby → Toddler → Child → Teen → Young adult → Adult → Old
  ("young teen" from the request = Young adult). One day older per game day (old age ~90 days). Birthdays, new traits
  for growing kids. Stage effects: walking speed, cared-for needs (babies/toddlers), kitchen/object/interaction limits.
- Everyone has a sex and age; you're a 20-year-old woman. New NPCs: Mia (8) and Lily (2), Alex's daughters; Noah (15),
  Riley's son. Families start close. New beds: Mia's Bed, Lily's Crib, Noah's Bed.
- **Schools** reuse the job machinery (`school: true`): Kindergarten, School, High school assigned by stage; College
  optional for young adults (14 days → degree → jobs start at level 2). Grades A–F from performance.
- **Babies:** "Try for a baby" (friendship 70+, fertile woman + man, young adult+, at home, not family, 40% chance).
  3-day pregnancy, then a baby is born in the mother's home with both parents.
- **Fired:** a performance-lowering shift at ≤ 25% gives a warning; the next one fires you. Bills now only for grown-ups.
- Fixes: wait limits use the real walking speed (toddlers are slow); "You" → "you" in the log no longer breaks "Young";
  "grew up into an Adult".
- Tests: stages, years, families, kitchen/job limits, growing up (school change, trait), fertility and menopause,
  baby rules (not with kids, same sex, outside), pregnancy → birth, babies stay put and are fed, only Hug with babies,
  college → degree → Analyst, warning → fired, grades, kids skip bills, log grammar; kids go to school in the run.
  Two weeks at Ultra: kids grew up (Mia → Teen, Lily → Child, Noah → Young adult), adults promoted.

## 2026-10-16 — Money and jobs
- New `jobs.gd` and **docs/WORK.md**. Everyone has `money`. 5 jobs (Café, Restaurant, Office, Gym, Comedy club)
  with 3 levels, schedules and hourly pay. Sam: Comedy club, Alex: Restaurant, Riley: Office; you start unemployed with $300.
- Shifts are rabbit holes: walk to the new **Bus stop**, `at_work` (hidden, state "working") until the end time, paid for
  hours worked. Performance from skill + emotion − lateness; −20 for a missed shift; promotion at 100% with enough skill.
  The job's skill is practised at 25% while at work.
- Player: Bus stop menu (apply / quit / go to work now). Manual mode = one reminder per shift; Auto = goes alone.
  Ultra speed while you're at work (like sleeping). No input while away.
- Spending: kitchen `cost` per recipe/drink (water free), paid at the Fridge/pouring; menus show prices and "(can't afford)";
  the AI skips what it can't afford. Bills: $80 per resident every Monday 00:00. "Broke" (Tense) below $0.
- New moodlets: Payday, Promoted, Missed work, Broke. HUD: money in the footer, job line top-left, jobs in the drawer.
- `play.command`: double-click launcher for macOS. README "Running it" rewritten.
- Tests: taking a job, Manual reminder, going to work (hidden), pay for hours, one shift per day, missed shift, promotion
  with/without skill, Auto goes alone, prices and "can't afford", free water, bills on Mondays only, Broke; and in the
  run Riley commutes to the office and comes back paid. A game week at Ultra: every shift worked, 3 promotions.
- **Watch out:** `take_job` during working hours marks today as done, so the first shift is the next workday.

## 2026-10-16 — Relationships drawer, homes and invitations
- **Relationships drawer** (R or the new button): a right-hand panel with a card per person: friendship bar and
  tier, how they see you, feeling, where they are (vague for people you haven't met, since house names contain names),
  traits once met, invitations both ways with time left, and their latest memory of you. The relationship lines left
  the top-left panel.
- **Ownership** (new `ownership.gd`): you may only enter your home or one you're invited to. `world.find_path` takes
  `who` and treats forbidden houses as walls (except the one you're in, so you can leave). `world.guests` holds
  invitations (6 game hours).
- **Knocking:** clicking a door you can't enter walks you there and knocks; NPCs knock too when the person they want to
  see is inside. A resident answers by `answer_chance` (friendship, emotion, traits, grudge; strangers 10%). If you're
  home in Manual mode, you decide via a popup. Turned away → Rejected and a 3 h knock cooldown.
- New interactions **Invite over** and **Ask to leave**. Guests whose invitation ends walk out by themselves.
- Tests: access rules, paths blocked/unblocked, answer chances, knocking → invited → walk in, invitation expiry → walk out,
  Invite over, Ask to leave, an NPC knocking on your door (popup, turn away), the drawer lists everyone, and a per-frame
  invariant that nobody ever walks into a home uninvited. In two Ultra days Sam knocked at Alex's and was turned away.
- **Watch out:** a character's `home` decides ownership, so give every resident the right home index in `main.gd`.

## 2026-10-16 — Needs footer band
- The need bars moved from the top-left panel to a full-width **footer band** (Sims-style): your feeling on the left in
  its emotion's colour with the reasons, then 7 rounded bars with values that shade red → amber → green
  (`need_color()` in hud.gd; values under 25 turn red). Footer constants (`FOOTER_HEIGHT`, colours) are at the top of hud.gd.
- The event feed and the controls cheat sheet are anchored just above the footer, so they follow the window size.
- The top-left panel keeps mode, location, speed, skills and relationships (the feeling line moved to the footer).

## 2026-10-16 — People: emotions, traits, memories, skills
- New **docs/PEOPLE.md** documents all of it.
- **Emotions** (`emotions.gd`): Sims-4-style moodlets (reason + emotion + strength + duration), plus condition
  moodlets from needs and a messy home. The strongest emotion is shown as "Feeling: …" and changes acceptance,
  interaction choice, which needs matter most, and skill learning speed.
- **Traits** (`traits.gd`): 11 traits. Sam: Outgoing/Goofball/Slob, Alex: Hot-headed/Foodie/Neat,
  Riley: Loner/Bookworm/Cheerful. They change need decay, likes, feelings, learning, acceptance and peeking reactions.
  Shown in the NPC menu once you've met them.
- **Memories** (social.gd): everyone remembers interactions, rejections, flat jokes and peeking. Recent bad ones
  are grudges (lower acceptance, fewer nice interactions) and get brought up in conversation.
- **Social:** new Compliment, Discuss ideas (Logic 3), Comfort (partner Sad), Insult (when Angry). Argue now needs
  an Angry/Tense/Uncomfortable feeling. Lines are spoken out loud, jokes can fall flat (Comedy), durations are in game
  minutes. NPCs greet people they know, or glare at people they're angry with.
- **Skills** (`skills.gd`): Cooking, Charisma, Comedy, Fitness, Logic, levels 0-10, earned by doing things (×1.5 for a
  matching trait or emotion). Effects: recipe unlocks and food quality (Burnt/Good/Delicious), acceptance and
  friendship gains, jokes landing, walking speed, Discuss ideas. Level-ups give Confident and a log line.
- New objects: Bookshelf in every house (Logic), Pull-up bar outside (Fitness); TV practises Comedy.
  Objects take optional extras {verb, skill, moodlet} in `OBJECTS`.
- `npc.setup()` signature is now (name, tile, color, home, traits, {skill: level}); the old needs/decay overrides are gone.
- HUD shows your feeling and skills; NPC labels show "Feeling"; F3 adds reasons, traits and skills.
- Tests: traits, emotions and wear-off, Comfort only for Sad, grudges and fading, argue memories, glaring, greetings,
  level-ups, recipe unlocks, trait xp bonus, cooking quality by level, joke and speed effects; the run must show 3+
  emotions, skill practice and memories. Two game days at Ultra: no errors.
- **Watch out:** emotes with no target (`show_emote(text, null)`) must not use `{who}`.

## 2026-10-16 — Pause and Sims-style speeds
- Pause (P / Space / 0) and four speeds on keys 1–4: Normal 1x, Fast 5x, Faster 20x, **Ultra 60x** (new). Pause keeps
  your speed for when you resume. Clickable `|| > >> >>> >>>>` buttons under the clock, a "PAUSED" banner, and the
  current speed in the HUD.
- While your character sleeps, time runs at Ultra and drops back to your speed on waking (`auto_sleep_speed` in main.gd).
- Speed logic lives in `main.gd` (`set_speed`, `toggle_pause`, `apply_speed`); the HUD gets `main` in `setup()`.
- Tests: pause/unpause, resume at the chosen speed, Fast = 5x, Ultra while asleep. The 15-minute run turns
  `auto_sleep_speed` off so it stays at 1x. Two game days at Ultra ran without errors (15 meals, 27 drinks).

## 2026-10-16 — Clock, day/night, calendar, seasons
- New `game_time.gd`. **1 real second = 1 game minute**, so a day lasts 24 real minutes. Start: Monday, Spring day 1,
  year 1, 08:00. HUD clock panel (top right): weekday, hh:mm:ss, part of day, season/day/year.
- Calendar: 7-day weeks, 4 seasons × 7 days = 28-day year.
- Day/night: sunrise/sunset per season (long summer days, short winter ones), dawn/dusk fade, `CanvasModulate`
  tint (dark blue at night, warm at dusk, lamps on indoors). Seasons recolour grass, trees and roofs (snow in winter);
  terrain chunks are rebuilt when the season changes.
- **Needs retuned to game hours** (`DECAY_HOURS` replaces `DECAY_MINUTES`): bladder 10 h, thirst 16, energy 18, fun 20,
  hunger 24, social 30, hygiene 36. Beds score ×3 at night and ×0.4 by day; sleeping takes 7 game hours ("Sleeping").
  TV 30 min, Shower 10 min, Bench 15 min.
- Food now spoils in game hours (`spoil_hours`: 6–24 h); labels show "9h 32m left".
- Controls text at the bottom has an outline so it's readable on snow.
- Tests: start date/time, 1 s = 1 min, weekday/season/year rollover, daylight at noon/midnight, short winter evenings,
  night tint, season rebuilds terrain, beds preferred at night, someone slept, decay per game hour.
- **Watch out:** `world.season` starts empty and is set on the first frame; don't build chunks before that.

## 2026-10-16 — Per-need decay rates, action progress bar
- Needs no longer all decay at 1 point / 30 s. `DECAY_MINUTES` in `npc.gd` sets how long each takes to empty:
  thirst 25 min, bladder 35, hunger 40, fun 50, social 60, energy 80, hygiene 100 (replaces `BASE_DECAY`).
- A small progress bar is drawn over any character who is `using` something (cooking, eating, showering, TV…),
  filling up over the step's `seconds`.
- Tests: each need drops at its own rate in 30 s; thirst drops faster than energy.

## 2026-10-16 — Kitchen: cooking, eating, washing up, drinks, thirst
- New need **thirst** (7 needs). Drinks fill it; food fills hunger.
- Every house has a kitchen: **Fridge, Counter, Stove, Sink, Table**, with 4 clean plates and 4 cups each.
  Click any of them for a menu. Full details in the new **docs/KITCHEN.md**.
- Cooking is a chain: Fridge (ingredients) → Counter/Stove (make) → Table (eat from a plate) → Sink (wash the plate).
  5 recipes. Extra servings stay on the Counter as leftovers that **spoil** (fresh → stale → spoiled, timer on the label).
- 5 drinks (Water at the Sink, Juice/Milk/Soda at the Fridge, Coffee at the Counter): pour → drink → wash the cup.
- No clean plates means no cooking until you wash some. Interrupted tasks put what you're carrying on the Table/Counter.
- NPCs cook, drink and eat leftovers on their own (only in their own kitchen), and wash up first if they're out of dishes.
- **Engine change:** object use is now **step-based** (`run_steps` in `npc.gd`). Using the TV is a one-step task.
  New state `queueing` (waiting for a busy object). `drop_task()` replaces `release_object()` when abandoning work.
  The Fridge no longer gives hunger directly.
- Player menus are generic now (`show_menu(headers, entries)`), used for both people and kitchen objects.
- Tests: the full pasta chain, leftovers, spoiling, throwing away, juice, no plates, interruption, Sam eating on his own,
  and that people ate/drank during the 15-minute run. The test now quits if the main scene fails to load
  (before, it hung forever).
- **Watch out:** a step's `start` lambda gets the step as an argument. Don't capture the step dictionary inside its
  own lambda: that's a reference cycle and leaks memory (it showed as "resources still in use at exit").

## 2026-10-16 — Doors, peeking through windows, NPC perception
- From outside, clicking a house picks what's under the mouse (`World.exterior_hit()`): the **door** walks you
  in (the only way in), a **ground-floor window** walks you there and starts **peeking**, and a wall does nothing.
- Peeking (player state `peeking`): the house shows its ground floor instead of its exterior. Rooms out of sight
  are dimmed (`Ground.set_lit()`), and only objects and people in line of sight through the window are shown.
- **Line of sight** in `world.gd`: walls block it, and windows/doors don't unless the curtains are closed.
- New `perception.gd`: NPCs look around every 0.5 s and see people within 10 tiles in line of sight (`seen`,
  shown with F3). If they catch you peeking, they **wave** (and come out to chat), **stare**, or **yell** and close
  the curtains for 60 s. It depends on friendship, mood, whether you've met, and whether they're in the shower or on the toilet.
  Asleep (in bed) they notice nothing. Reactions appear above their head (`show_emote`) and in the social log.
- Social log now writes "you" mid-sentence ("Alex yelled at you for peeking").
- Tests: door/window/wall picking, sight through windows and not walls, peek view, one reaction per peek,
  wave → comes to chat, shower → yell + curtains end the peek, asleep → no noticing.
- **Watch out:** `npc.notice()` is a hook; the player overrides it to do nothing. Put new automatic reactions in
  `Perception.notice()`.

## 2026-10-16 — Open world: houses with floors, a street, streaming
- New `world.gd`: a 1024×1024-tile map (1 tile = 1 m) with a road grid, trees and three houses
  (`BUILDINGS`). Your house has two floors joined by stairs; Alex and new neighbor **Riley** have their own.
- **Visibility:** inside, you see only the floor you're on in your building. Outside, you see the
  terrain and people within 40 tiles, and houses as closed exteriors. Terrain is streamed in 16×16 chunks.
- **Pathfinding** (A* over the area around the trip) around walls, trees and objects, through doors, and
  up/down stairs. Characters have `floor`, `building`, `path`; `walk_to()` replaces setting `walk_target`.
- NPCs have a **home**: they only use objects in their home or outdoors (new: Bench), only consider things
  within 30 tiles (people within 20), and wander back home when they drift too far.
- Waiting for a conversation partner now lasts their walking time + 5 s (`wait_limit`), since people come
  from farther away. The test checks waits against that.
- Camera follows the player; mouse wheel zooms. HUD shows where you are. New `block.gd` and `ground.gd` for drawing.
- Tests: walls/doors/upper floors, paths through doors and stairs, per-frame "nothing visible from another
  building/floor", someone used the stairs and went outside, and chunk streaming after moving.
- **Watch out:** `world.gd` has `process_priority = 100` so the view updates *after* characters move;
  otherwise someone going through a door is visible for one frame in the wrong place.
- **Watch out:** doors must be on a building's bottom or right wall to be drawn (the others face away from the camera).

## 2026-10-16 — Strangers are "Unknown", slower walking
- NPCs show as **Unknown** until they've completed an interaction with you (rejections don't count).
  New: `known` on every character, `Social.display_name()`, `{who}` placeholders in `activity`
  (with `activity_with`), and event log entries stored as `{text, a, b}` and formatted per viewer.
- Walking speed −0.5: NPCs 2.5 → 2.0, player 3.0 → 2.5 tiles/s.
- Tests: names hidden at start, revealed only for people you've met.
- **Watch out:** never put a character's name straight into `activity` or the log; use the placeholders.

## 2026-10-16 — Six needs, social interactions, slower decay, docs

**Changed**
- Needs now decay at **1 point per 30 seconds** for everyone (`BASE_DECAY` in `npc.gd`). Previously
  1–2 points per *second*, with personality-specific rates (Alex used to tire faster; that was removed).
- New needs: **bladder, hygiene, social** (six in total). New objects: **Toilet**, **Shower**. The Fridge now
  costs 10 bladder.
- **Social system** (`scripts/social.gd`): Chat, Tell a joke, Deep talk, Hug, Argue. One-directional
  friendship, acceptance chance from friendship + mood, social event log in the HUD.
- NPCs pick conversations through the same utility scoring as objects. The player clicks an NPC for a menu.
- Game speed keys 1/2/3 (1x/5x/20x), F3 shows NPC need values, controls cheat sheet in the HUD.
- NPC labels show name, activity and mood; outlined text so it stays readable over objects.
- `tests/check_sim.gd`: simulates 15 minutes headless and asserts decay, reservations, wait timeouts,
  player-ordered chat, and that NPCs socialize on their own.
- README, this devlog and CLAUDE.md added.

**Watch out**
- `player.gd` `_init()` must call `super()`; otherwise the player's needs/decay dictionaries are never
  filled (this bug happened during this update).
- At 1x speed things happen slowly by design; use speed 3 (20x) to see the full cycle.

## 2026-10-16 — Manual / Auto mode
- `player.gd` now **extends `npc.gd`** instead of duplicating it. Hooks: `think()` (the player only
  acts on its own in Auto) and `label_text()`.
- Mode button in the HUD plus the Tab key. Clicks work in both modes.

## 2026-10-16 — Player needs + HUD
- The player got hunger/energy/fun that decay and refill from objects. `hud.gd` added with colored bars.

## 2026-10-16 — Player and second NPC
- Click-to-move player; click an object to use it.
- Second NPC (Alex). Object reservation (`user`), so two characters never use one object.

## 2026-10-16 — Project start
- Godot 4.7.2 installed with Homebrew. Isometric room, Fridge/Bed/TV, one NPC (Sam) using utility AI.
