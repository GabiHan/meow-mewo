# Meow Mewo

A lightweight isometric life sim: **The Sims** meets **Project Zomboid**. Characters have needs that
decay over time, decide for themselves what to do about them, and build relationships through
social interactions. The long-term goal is NPCs that react to you like real people would.

Current state: a 1 km open world (roads, trees) with one street of three houses. Your house has two
floors. Every house has a working kitchen (cook, eat, wash up, drinks; see [docs/KITCHEN.md](docs/KITCHEN.md)).
You start as **Jo** (20), sharing a house with Sam. Neighbours: Alex with her daughters Mia (8) and
Lily (2), and Riley with his son Noah (15). You control anyone in your household (click their name
at the top left), there's no game over, and everyone lives a whole life: emotions and long-term
mental health, learning, romance, family, work and death; see [docs/PEOPLE.md](docs/PEOPLE.md). Everyone ages through life stages (baby to old), kids go to school, and grown-ups can
have babies; see [docs/LIFE.md](docs/LIFE.md). Each has a personality (traits),
emotions, memories of what others did, and skills that grow with practice; see
[docs/PEOPLE.md](docs/PEOPLE.md). People and furniture are drawn with sprites baked from 3D models (Quaternius' Universal Base
Characters and a low-poly furniture pack; see *Character art* and *Furniture art*); the world itself
is still simple shapes.

---

## Running it

Requires **Godot 4.7** (installed with `brew install --cask godot`; the app is `/Applications/Godot.app`).

**Easiest:** double-click **`play.command`** in this folder (in Finder). The first time, macOS may
block it: right-click it → *Open* → *Open*.

| What | How |
|---|---|
| Play (Terminal) | `cd ~/mewo/meow-mewo && godot --path .` |
| Play (Finder) | double-click `play.command` |
| Play (Godot app) | open Godot → *Import* → pick `project.godot` → *Import & Edit*, then press **F5** |
| Open the editor | `godot -e --path .` (or Godot → Import → pick `project.godot`) |
| Run automated checks | `godot --headless --fixed-fps 60 -s res://tests/check_sim.gd` |

In the editor, press **F5** to play.

## Home screen and saving

The game opens on the **home screen** (`scenes/menu.tscn`, `menu.gd`):

| Button | What it does |
|---|---|
| **Play Game** | **Choose a household** (Jo & Sam, Alex's family, Riley & Noah: you play the household's first grown-up) or **Create a new household** |
| **Continue** | Loads your most recent save (greyed out until you have one; shows which) |
| **Saved Games** | Every save (household, in-game date, money, when saved) with **Load** and **Delete** |
| **Quit** | Closes the game |

**Creating a household:** give it a name and add up to 4 people, each with a name, sex, age (Child,
Teen, Young adult, Adult, Old), a look (with a preview) and up to 3 traits. Names must be new (not
someone on the street), and there must be at least one grown-up. They move into the **Starter house**
on the street (basic furniture included), the grown-ups share **$1,500**, and children get the
grown-ups as parents (and go to school).

**In the game**, the **Menu ▾** button under the clock: **Save game** (to this game's save; the first
save creates it), **Save as a new game**, **Save and exit to main menu**, **Exit to main menu**
(without saving), **Quit game**.

**What's saved** (`save_game.gd`, files in `user://saves/`, on a Mac `~/Library/Application
Support/Godot/app_userdata/Meow Mewo/saves`): every person (needs, emotions and mental state,
memories, relationships and romance, skills, money, job, age, look, family...), all furniture (also
what you bought, food on counters, graves), the clock and date, clean dishes, invitations, the social
log, who you control and the game speed. Not saved: what people were doing at that instant (they
carry on from idle).

## Controls

| Input | Action |
|---|---|
| Left-click floor | Walk there (around walls, through doors) |
| Left-click an object | Use it; if it has several interactions (bed: Sleep / Nap / Relax, toilet: Pee / Poo...), a menu lets you choose |
| (automatic) | A small bar over anyone doing something shows how far along the action is |
| Left-click a kitchen object (Fridge, Stove, Counter, Table, Sink) | Menu: cook, drink, eat leftovers, throw away, wash dishes |
| Left-click the stairs | Go to the other floor |
| Left-click a house's door (outside) | Walk in if it's your home or you're invited; otherwise **knock** and wait for an answer. Doors are the only way in |
| R, or the Relationships button | Open/close the relationships drawer on the right |
| B, or the Build button | **Build mode**: buy furniture from a catalog and place it in your home (R rotates, right-click cancels, click furniture to sell or move); see [docs/BUILD.md](docs/BUILD.md) |
| Left-click a ground-floor window (outside) | Walk to it and **peek in** until you do something else |
| Left-click a person | Open the interaction menu (shows your relationship and their mood) |
| Tab / Mode button | Toggle **Manual** / **Auto** for your character |
| P / Space / 0, or the `\|\|` button | Pause / unpause (resumes at your speed). You can still click to give orders while paused |
| 1 / 2 / 3 / 4, or the `>` … `>>>>` buttons | Speed: Normal 1x / Fast 5x / Faster 20x / Ultra 60x |
| Mouse wheel | Zoom in / out |
| F3 | Show NPC details above their heads: why they feel what they feel, traits, skills, needs, who they can see |

**Manual** mode: your character only does what you click. **Auto** mode: it runs the same AI as the
NPCs. Clicks still work in Auto; your character follows the order, then decides for itself again.

---

## The look

Pastel and cutesy, built from one 7-shade palette (`PALETTE` in `ui_theme.gd`), baby blue → lavender → pink:

| # | Hex | Used for |
|---|-----|----------|
| 0 | `#c9def4` | Summer ground, fridge and bathroom furniture, pressed buttons |
| 1 | `#d0dbef` | Spring ground, kitchen furniture, trash cans |
| 2 | `#d8d8e9` | Background, shelves, disabled buttons, panels (lightened) |
| 3 | `#dfd5e4` | Roads (darkened), interior walls (lightened), couches, fireplace |
| 4 | `#e6d2df` | Fall ground, tables, night stands, drawers |
| 5 | `#eecfd9` | Starter house, panel borders, chairs, stools, carpets |
| 6 | `#f5ccd4` | Buttons, beds, lamps, blossom trees |

Houses use shades 6, 0, 3 and 5, each with a darker roof; floors are pink. Inside, nights are a soft pink lamplight; outside, the sky changes through the day (see Day and night).
Furniture sprites are tinted with these shades when baked (`TINTS` in `tools/bake_furniture.gd`; plants are
just softened), and character sheets get a soft brighter finish.

**Bubbly buttons:** every button is a pill (`UiTheme.bubble()`): round ends, a deeper bottom edge and a
soft shadow so it looks raised; hovered it brightens, pressed it turns baby blue and sinks (the edge
shrinks and the text moves down). Panels are rounded, light lavender with a pink border.

Colour constants are written as literal `Color(r, g, b)` values (a palette shade already darkened or
lightened), because GDScript constants can't call `.darkened()`.

## You and your household

You start as **Jo** (change the name in `main.gd`, `PLAYER_NAME`). Everyone who lives in your home is
listed in a row at the top left: **click a name to control that person** (the one you control is
green, and has a green ring under them). Babies and toddlers aren't playable: clicking them, on the
bar or in the world, opens a panel from the left with their needs, feeling and care buttons (Feed,
Change & clean, Rock to sleep, Play with, Read a story, Hug).

There's **no game over**. When someone dies of old age they become a grave outside their home; if
it's the person you control, you carry on as another member of the household (or, if none is left,
someone else). Whoever you control: Tab switches them between Manual (only your orders) and Auto
(they live on their own); everyone else always lives on their own.

## Screen (HUD)

| Where | What |
|---|---|
| Footer band (full width, bottom) | Your **feeling** (colour per emotion, with the reasons underneath), your **money** (red below $0) and the **7 need bars** with their values. Bars shade from red (low) through amber to green; a value under 25 turns red |
| Top left | Household bar (click to switch), Manual/Auto button, Relationships button, where you are, game speed, who you are (age, sex), job, skills, mind (mental state) |
| Left panel | A baby or toddler you clicked: needs, feeling, parents, care buttons |
| Right drawer (R) | **Relationships**: everyone, sorted by friendship, with a bar (−100…100), tier, how they see you, how they feel, where they are, traits (once met), invitations both ways, and their latest memory of you. Refreshes twice a second, even when paused |
| Top right | Clock, weekday, part of day, date, speed buttons |
| Top centre | "PAUSED" while paused |
| Bottom left, above the footer | Recent social events |
| Bottom right, above the footer | Controls cheat sheet |

## Project layout

```
project.godot           Engine config (main scene, 1280x720 window, GL Compatibility renderer)
scenes/menu.tscn        First scene: the home screen (menu.gd)
scenes/main.tscn        The game: just a Node2D with main.gd; everything else is built in code
scripts/
  main.gd               Builds the game (world, OBJECTS table, characters, camera, HUD); speed, F3, zoom
  world.gd              Map, buildings, floors, pathfinding, terrain streaming, what you can see
  block.gd              Tile-sized shapes: walls, house exteriors, trees, stairs
  furniture.gd          Loads baked furniture sprites (art/furniture) and their floor anchors
  looks.gd              What each person looks like (body, skin, hair, clothes) and their sprite sheets
  prop.gd               Decorative furniture on a tile (couches, plants, rugs...)
  catalog.gd            Build mode catalog: items, prices, placement rules, buy/sell/move/rotate
  actions.gd            What you can do with each kind of furniture (Sleep/Nap, Pee/Poo, Read a novel...)
  build_mode.gd         Build mode UI: catalog panel, placement preview, input
  ground.gd             Flat floor tiles (a terrain chunk or a building floor)
  iso.gd                Grid <-> screen conversion for the isometric view
  game_time.gd          Clock, calendar, seasons, daylight (time → hh:mm:ss, weekday, season, screen tint)
  smart_object.gd       Objects that advertise which needs they satisfy
  npc.gd                Character brain: needs, utility AI, movement, conversation state machine
  controller.gd         You: mouse and keyboard, menus, and which household member you control
  menu.gd               Home screen: play, continue, saved games, create/choose a household
  session.gd            What the home screen asked the game to start (household, new, or a save)
  save_game.gd          Saving and loading the whole game (user://saves)
  ui_theme.gd           The palette and the UI theme (bubbly pill buttons, rounded light panels)
  romance.gd            Romance score, chemistry, dating/engaged/married, jealousy
  mind.gd               Long-term mental states (depressed, anxious, thriving...) and learned tastes
  social.gd             Interactions, relationships, memories and grudges, spoken lines, social event log
  emotions.gd           Moodlets → emotion (Happy, Angry, Sad...) and what each emotion does
  traits.gd             Personality traits (Outgoing, Hot-headed, Foodie...) and their effects
  skills.gd             Skills 0-10 (Cooking, Charisma, Comedy, Fitness, Logic): xp, levels, effects
  kitchen.gd            Recipes, drinks, plates/cups, leftovers and spoiling, kitchen menus and AI options
  perception.gd         What NPCs see (sight radius, line of sight) and how they react (greetings, peeking)
  ownership.gd          Homes, invitations, knocking on doors, answering the door
  jobs.gd               Money, jobs and schools, shifts, pay, performance, promotions, firing, weekly bills
  ages.gd               Life stages, years, fertility, family (no dependencies)
  life.gd               Ageing, growing up, pregnancy, births, families
  hud.gd                Footer band (feeling + need bars), mode/info panel, clock, event feed, controls cheat sheet
tests/
  check_sim.gd          Headless simulation with assertions (exit code 1 on failure)
tools/
  bake_furniture.gd     Renders 3D models into isometric sprites (art/furniture)
  bake_characters.gd    Poses the 3D characters and renders their sprite sheets (art/characters)
assets/                 The furniture packs (zips) and the unpacked OBJ models (assets/furniture_obj)
art/furniture/          Baked sprites + sprites.json (anchors)
art/characters/         One sprite sheet per look (8 directions × 7 frames)
docs/
  DEVLOG.md             What changed in each update and why
  KITCHEN.md            Everything about the kitchen: recipes, drinks, spoiling, dishes, NPC use
  PEOPLE.md             Everything about people: emotions, moodlets, traits, memories, interactions, skills
  WORK.md               Everything about money and jobs
  LIFE.md               Everything about ages, growing up, schools and babies
  BUILD.md              Build mode: controls, rules, the catalog
play.command            Double-click to play (macOS)
```

Scripts reference each other with `preload("res://scripts/x.gd")` instead of `class_name`, so they
work headless without the editor having built its class cache.

---

## How the simulation works

### Coordinates
Game logic uses **grid coordinates** (tiles, `Vector2`, can be fractional while walking). `iso.gd`
converts to screen pixels: a tile is 64×32 px. The main node and every container in the world have
`y_sort_enabled`, so things lower on screen are drawn in front. Floor tiles use `z_index = -1`.
Every character and object also has a `floor` (0 = ground) and a `building` (−1 = outside).

### Time, calendar and seasons (`game_time.gd`)
**1 real second = 1 game minute** at 1x speed (`MINUTES_PER_SECOND`), so a day lasts 24 real
minutes (4.8 min at Fast, 72 s at Faster, 24 s at Ultra). `world.clock` counts real seconds of simulation; `world.now()` turns it into
game seconds. The game starts on **Monday, Spring day 1, year 1 at 08:00**.

The HUD (top right) shows the weekday, the time as **hh:mm:ss**, the part of the day (Morning before
12:00, Afternoon before 17:00, Evening, Night when it's dark) and the date: season, day of the season,
year.

**Calendar:** a week has 7 days (Monday–Sunday). A year has 4 seasons of **7 days** each
(`DAYS_PER_SEASON`): Spring, Summer, Fall, Winter, so a year is 28 days.

**Day and night:** the sun rises and sets at different times per season (`SUN`). The screen is tinted by
`CanvasModulate`; the HUD is never tinted.

* **Indoors** keeps the palette: no tint by day, soft pink lamplight at night (`INDOOR_NIGHT_TINT`).
* **Outdoors** follows the sky (`SKY` colours, placed by `sky_keys()` around the season's sunrise and sunset), blending smoothly:

| When (spring) | Sky | Look |
|---------------|-----|------|
| until 1 h before sunrise (05:00) | night | deep dark blue |
| sunrise (06:00) | dawn | pink-lilac |
| sunrise + 1 h (07:00) | morning | cool blue |
| 10:30 | late morning | pale blue |
| 12:00 to sunset − 2 h (18:00) | afternoon | bright, untinted |
| sunset − 45 min (19:15) | golden | warm gold |
| sunset (20:00) | sunset | pink-coral |
| sunset + 45 min (20:45) | dusk | violet |
| from sunset + 1.5 h (21:30) | night | deep dark blue |

| Season | Sunrise | Sunset | Grass | Trees | Roofs |
|---|---|---|---|---|---|
| Spring | 06:00 | 20:00 | Fresh green | Light green | Red |
| Summer | 05:30 | 21:30 | Dry yellow-green | Dark green | Red |
| Fall | 07:00 | 19:00 | Brown | Orange | Red |
| Winter | 08:00 | 17:00 | Snow | Snow-covered | Snow |

When the season changes, the terrain chunks are rebuilt in the new colours.

Game time drives: need decay (game hours), action durations (game minutes), food spoiling (game
hours, see the kitchen doc) and sleep at night.

### Speed and pause (`main.gd`)
Like The Sims: four speeds and a pause, set with keys or the buttons under the clock (the active one
is highlighted). The HUD shows the current speed.

| Speed | Key | Multiplier | A game day takes |
|---|---|---|---|
| Paused | P / Space / 0 | 0 | – |
| Normal | 1 | 1x | 24 min |
| Fast | 2 | 5x | 4.8 min |
| Faster | 3 | 20x | 72 s |
| Ultra | 4 | 60x | 24 s |

Pausing sets `Engine.time_scale` to 0, so everything stops, but clicks and menus still work: orders
start when you unpause. **While your character sleeps, time automatically runs at Ultra** and returns
to your speed when you wake up (`auto_sleep_speed`). It shows as "Ultra (60x) while you sleep".

### The world (`world.gd`)
**1 tile = 1 m.** The map is 1024×1024 tiles (`SIZE`): a road every 64 tiles (`ROAD_EVERY`), about
12,000 trees (randomly placed but the same every run), and the houses in `BUILDINGS`, on the street
around tile (490, 512). The camera follows you.

| Building | Rect (incl. walls) | Floors | Door | Stairs | Who lives there |
|---|---|---|---|---|---|
| Your house | (482,499) 12×10 | 2 | (487,508) | (483,500) | Jo, Sam |
| Alex's house | (498,499) 10×10 | 1 | (502,508) | – | Alex |
| Riley's house | (486,518) 10×9 | 1 | (495,522) | – | Riley, Noah |
| Starter house | (498,518) 10×9 | 1 | (507,522) | – | a household you create (empty otherwise) |

**What you can see** (`update_view()`, runs every frame after everyone has moved):

| Where you are | Visible |
|---|---|
| Inside a building | Only the floor you're on: its floor tiles, walls (cut down to `INNER_WALL_HEIGHT`), stairs, objects and the people on it. The outside, other floors and other buildings are hidden. |
| Outside | Terrain, trees, outdoor objects and people outside within `VIEW_RADIUS` (40 tiles); houses as closed exteriors (walls, windows, door, roof). Interiors and the people in them are hidden. |

| Peeking through a window | The outside view, except that the house you're peeking into shows its ground floor instead of its exterior. Rooms out of sight are dimmed, and only the objects and people in line of sight are shown. |

Standing in a doorway counts as inside. Clicking a house from outside picks what's under the mouse
on its exterior (`exterior_hit()`): the **door** walks you to the tile just inside, a **ground-floor
window** walks you to the tile just outside it and starts peeking, and anything else does nothing.

**Line of sight** (`has_line_of_sight()`): a straight grid line (Bresenham) between two cells on the
same floor. Walls block it; doors, windows and objects don't. Windows with closed curtains block it.
Ground-floor windows are every other tile on the walls facing the camera (bottom and right), in `windows`.

**Streaming:** terrain is cut into 16×16-tile chunks (`CHUNK`). Outside, the 7×7 chunks around you
exist as nodes; when you cross into a new chunk, missing ones are built and far ones are freed.
Indoors no terrain is drawn.

**Walls and floors:** a building's outer ring of tiles is wall on every floor, except the door
(ground floor only). Upper floors exist only inside buildings. Objects make their own tile solid.

**Pathfinding:** `find_path(from, from_floor, to, to_floor)` returns cells as `Vector3i(x, y, floor)`.
It runs A* (`AStarGrid2D`) over the box around start and goal, grown by `PATH_MARGIN` (10). Trips
spanning more than `MAX_PATH_SPAN` (160) tiles are refused. A floor change routes through the
building's stairs cell; walking onto it switches `floor`.

### Needs
Characters walk at 2 tiles/s (NPCs) and 2.5 tiles/s (player), set in `speed`.
Walking follows `path` (see *The world*); `walk_to(cell, floor)` returns false if there's no way.

Every character has seven needs from 0 (desperate) to 100 (fully satisfied):

| Need | Refilled by |
|---|---|
| hunger | Food: cook at the Fridge/Stove, eat at the Table (see [Kitchen](docs/KITCHEN.md)) |
| thirst | Drinks: Water (Sink), Juice/Milk/Soda (Fridge), Coffee (Counter) |
| energy | Bed, Coffee |
| fun | TV, Bench, jokes, hugs |
| bladder | Toilet (drinks and spoiled food *lower* it) |
| hygiene | Shower |
| social | Talking to other characters |

**Decay:** each need empties at its own rate, in **game hours** (`DECAY_HOURS` in `npc.gd`). At 1x
speed a game hour is one real minute, so "16 h" is 16 real minutes:

| Need | Empties in | Points lost per game hour |
|---|---|---|
| bladder | 10 h | 10 |
| thirst | 16 h | 6.3 |
| energy | 18 h awake | 5.6 |
| fun | 20 h | 5 |
| hunger | 24 h | 4.2 |
| social | 30 h | 3.3 |
| hygiene | 36 h | 2.8 |

So people use the toilet and drink several times a day, eat two or three meals, and have to sleep
every night. **Sleep is for the night:** beds score ×3 at night and ×0.4 by day (`NIGHT_SLEEP_BONUS`,
`DAY_SLEEP_PENALTY`), so NPCs go to bed in the evening unless they're exhausted. A night's sleep is
7 game hours.

 NPCs start with random needs from 40 to 90; Jo starts at 85.
`setup()` accepts per-need overrides of starting values and decay rates, for future personalities.

**Mood** is the average of all needs: Happy (> 70), Fine (> 45), Uncomfortable (> 25), Miserable.

### Utility AI (how characters decide)
This is the same idea The Sims uses. When a character is idle, it scores every option it's allowed:
objects in **its own home** or **outdoors** (not the neighbors' fridges) within `CONSIDER_RADIUS`
(30 tiles), and people within `SOCIAL_RADIUS` (20 tiles).

```
urgency(need)  = ((100 - need) / 100)²            # low needs matter much more
score(option)  = Σ amount × urgency(need) × emotion weight(need)   # e.g. Bored: fun ×1.5
               / (1 + distance × 0.05)            # closer is slightly better
               × trait liking                     # e.g. Bookworm: Bookshelf ×2 (docs/PEOPLE.md)
distance       = tiles in a straight line + 8 per floor of difference (FLOOR_COST)
```

* **Objects** advertise a dictionary like `{"fun": 60}`. Negative amounts are costs.
* **Kitchen options** (recipes, drinks, leftovers in the character's own home) advertise what the
  food/drink gives, and are also divided by `1 + task seconds / 60`. See [docs/KITCHEN.md](docs/KITCHEN.md).
* **Other characters** advertise the social interaction this character would pick with them.
* Highest score wins. If nothing scores at least `ACT_THRESHOLD` (5), the character wanders up to
  5 tiles; more than 12 tiles from home (`HOME_LEASH`), it wanders back toward home.
* If the chosen thing can't be reached, the character waits `RETHINK_DELAY` (1 s) and thinks again.

### Objects
`smart_object.gd`. Each one has a grid position, advertisements, a use duration, a `user`, a
`building` and a `floor`. They're listed in the `OBJECTS` table in `main.gd`. Characters **reserve**
an object (`user = self`) when they choose it, so two characters never go for the same one. When
using finishes, the reservation is cleared (`release_object()`). You stand on the tile in front of an
object (`use_cell()`: the tile on its front side, `grid_pos + (0, 1)` unless it was rotated in build mode) to use it.

| Object | Advertises | Seconds |
|---|---|---|
| Fridge, Counter, Stove, Sink, Table | nothing directly: a menu of kitchen tasks ([docs/KITCHEN.md](docs/KITCHEN.md)) | – |
| Shower | hygiene +80 | 10 |
| Bed ("Sleeping") | energy +100 | 420 (7 game hours) |
| Toilet | bladder +90 | 3 |
| TV ("Watching TV") | fun +60; Comedy skill | 30 |
| Bench | fun +25 | 15 |
| Bus stop | nothing: click it for the jobs menu; workers leave for work from here | – |
| Bookshelf ("Reading") | fun +35; Logic skill; Learned something (Focused) | 45 |
| Pull-up bar ("Working out") | fun +15, energy −10, hygiene −10; Fitness skill; Pumped (Energized) | 30 |

Seconds are real seconds at 1x speed, which are also game minutes. A small bar over the character
fills up while they use something.

| Where | Objects (tile) |
|---|---|
| Your house, ground floor | Kitchen (Fridge (485,500), Counter (486,500), Stove (487,500), Sink (488,500), Table (486,504)), TV (491,500), Toilet (492,505) |
| Your house, floor 1 | Bed (488,500), Shower (491,500), Bookshelf (484,503) |
| Alex's house | Kitchen (Fridge (500,500), Counter (501,500), Stove (502,500), Sink (503,500), Table (501,504)), Bed (505,500), Shower (506,500), Toilet (499,504), TV (505,505), Bookshelf (503,506) |
| Riley's house | Kitchen (Fridge (488,519), Counter (489,519), Stove (490,519), Sink (487,521), Table (490,523)), Bed (492,519), Shower (494,519), Toilet (488,524), TV (492,523), Bookshelf (487,519) |
| Outdoors | Bench (500,516), Pull-up bar (503,516), Bus stop (497,511) |

### Furniture interactions (`actions.gd`)
Every kind of furniture has its own interactions. Click it to choose; NPCs score each action of each
object (×0.85–1.15 for variety) and pick the best, so they nap, pee, read novels, etc. on their own.
Night sleep in a bed scores ×3 at night and ×0.4 by day; naps don't. Actions marked *asleep* mean
they notice nothing and, for you, time runs at Ultra.

| Furniture | Interaction | Gives | Minutes | Also |
|---|---|---|---|---|
| Bed | Sleep | energy +100 | 420 | asleep, night; Well rested |
| | Nap | energy +35 | 90 | asleep |
| | Relax in bed | fun +15, energy +5 | 30 | |
| Crib | Sleep | energy +100 | 300 | asleep, night |
| Couch (sofa, armchair) | Relax | fun +20, energy +10 | 30 | seat |
| | Sit | energy +5, fun +5 | 15 | |
| | Nap on the couch | energy +30 | 60 | asleep |
| Chair, stool | Sit | energy +5 | 10 | seat |
| Toilet | Pee | bladder +70 | 2 | |
| | Poo | bladder +80, hygiene −5 | 8 | |
| Shower / bathtub | Take a shower | hygiene +80 | 10 | Freshened up |
| | Take a bath | hygiene +100, fun +15 | 30 | Freshened up |
| Bathroom sink | Wash hands / Brush teeth | hygiene +10 / +15 | 2 / 3 | |
| TV | Watch comedy / the news / a cooking show | fun +60 / +20 / +35 | 30 / 20 / 30 | Comedy / Logic / Cooking |
| Bookshelf | Read a textbook / a novel / a cookbook | fun +25 / +45 / +15 | 45 / 60 / 30 | Logic (Learned something) / – / Cooking |
| Fireplace | Relax by the fire / Warm up | fun +25, social +5 / energy +10, fun +10 | 30 / 15 | |
| Bench | Sit on the bench | fun +25 | 15 | |
| Pull-up bar | Work out / Do a few pull-ups | fun +15, energy −10, hygiene −10 / fun +8, energy −3 | 30 / 10 | Fitness |
| Fridge, Stove, Counter, Sink, Table | kitchen menus: cook, drinks, leftovers, wash up | | | [docs/KITCHEN.md](docs/KITCHEN.md) |

**Seats** (couch, chair): you sit on the seat itself, so its tile stays walkable; everything else
you use from the tile in front of it. Your house's chairs, couch and bathroom sinks are usable.

### Character state machine (`npc.gd`)

```
idle ──think()──► walking ──arrive()──► using ──step done──► next step (walking/queueing) … ──last step──► idle
                     │                        
                     └─(partner)──► Social.begin ──accepted──► talking ──Social.finish──► idle
                                                 └─rejected──► idle
queueing: the next step's object is busy; wait up to QUEUE_TIMEOUT (15 s), then give up
waiting: someone is walking over to talk to you; give up after wait_limit
         (their walking time + WAIT_SLACK, 5 s)
```

**Tasks** are lists of steps (`run_steps`): `{object, verb, seconds, ads?, start?, done?}`. Using
the TV is one step; cooking a meal is four (Fridge → Stove → Table → Sink). What a character is
carrying is in `held`. A task that's interrupted puts the carried item down (`drop_task`). Details in
[docs/KITCHEN.md](docs/KITCHEN.md).

### People: emotions, traits, memories, skills
Full details and every table: **[docs/PEOPLE.md](docs/PEOPLE.md)**. In short:

* **Emotions** come from moodlets (e.g. *Argued*: Angry for 3 h; *Hungry*: Uncomfortable while
  hunger < 25). The strongest emotion is what they feel, shown as `Feeling: Angry` above their head.
  Emotions change who they talk to, what they choose, whether they say yes, and how fast they learn.
* **Traits** (3 per NPC) change need decay, likes, feelings and learning: Outgoing, Loner, Cheerful,
  Hot-headed, Goofball, Foodie, Bookworm, Active, Lazy, Neat, Slob.
* **Memories:** everyone remembers what others did to them. Recent bad memories become grudges, and
  they bring old events up in conversation.
* **Skills** 0–10: Cooking, Charisma, Comedy, Fitness, Logic, earned by doing things. They unlock
  recipes and interactions, make food better, jokes land, people say yes, and you walk faster.

### Social interactions (`social.gd`)
1. The initiator picks a partner and an interaction. The AI uses weighted random by score × emotion
   × traits, so NPCs aren't predictable; you use the click menu.
2. The partner stops and **waits**; the initiator walks to the tile next to them.
3. On arrival the partner **accepts or rejects** (friendship, needs, emotion, your Charisma, their
   traits, grudges; see PEOPLE.md). The initiator **says a line** out loud. Arguing and insulting
   can't be refused.
4. Accepted: both **talk** for the duration, then *both* get need changes, friendship, moodlets and a
   memory, and the initiator gets skill xp. Jokes can fall flat. Rejected: friendship −2 both ways,
   the initiator feels Rejected.

Interactions: **Chat, Tell a joke, Compliment, Deep talk, Discuss ideas, Hug, Comfort, Argue, Insult**
(table with requirements and effects in [docs/PEOPLE.md](docs/PEOPLE.md)). Durations are in game minutes.

NPCs **greet** people they know when they see them ("Good morning, Sam!"), or glare at people
they're angry with.

**Names are hidden until you've met.** An NPC appears as **Unknown** (above their head, in menus,
in the HUD and in the event feed) until they complete an interaction with you. A rejected one doesn't
count. Every character has `known` (names it has met); `Social.display_name(viewer, c)` decides
what to show. Text that mentions someone uses a `{who}` placeholder plus `activity_with`, and log
entries use `{a}`/`{b}`, so names are filled in at display time from the point of view of the person you control.

**Relationships** are one-directional (`relationships[other_name]`, −100..100), so Sam can like you
more than you like Sam. Tiers: Enemy (< −30), Disliked (< 0), Acquaintance (< 20), Friend (< 50), Good friend.

**Availability:** you can only start a conversation with someone who is idle or wandering and not
already in one. NPCs approach the person you control (in Manual mode) only while they stand still. You can interrupt an
NPC who is walking to an object, but not one who is using one.

All completed and rejected interactions go to `Social.event_log`, which is shown in the bottom-left of the HUD, just above the footer.

### Money and jobs (`jobs.gd`)
Full details: **[docs/WORK.md](docs/WORK.md)**. Everyone has money. It comes from **jobs**: 5
careers (Café, Restaurant, Office, Gym, Comedy club), each with 3 levels, a schedule and hourly pay.
On a workday the worker walks to the **Bus stop**, is away (hidden) until the shift ends, and comes
back paid for the hours worked. Performance goes up with good shifts (skill and emotion) and down
for lateness and missed shifts; at 100% with enough skill you're promoted. At 25% or less a bad shift
earns a **warning**, and the next one gets you **fired**. It goes out on
**ingredients and drinks** (kitchen) and **$80 bills every Monday** (grown-ups only); below $0 you're *Broke* (Tense).
Jo (unemployed, $300) gets a job at the Bus stop; unemployed NPCs find one by themselves each morning. In Manual mode you get a reminder and go yourself;
in Auto mode you go alone. While you're at work, time runs at Ultra.

### Ages, schools and babies (`ages.gd`, `life.gd`)
Full details: **[docs/LIFE.md](docs/LIFE.md)**. Life stages: **Baby, Toddler, Child, Teen, Young
adult, Adult, Old**, one day older per game day (old age after ~90 days). Each stage limits what
someone can do (babies stay put and must be fed and changed, children can't use the stove, jobs are for young
adults and up). Kids go to **Kindergarten / School / High school** automatically (like jobs, no pay,
graded A–F); young adults may enroll in **College** for a degree. **Try for a baby** needs a fertile
woman and man (young adult or adult; women until menopause at 50), friendship 70+, at home, not
family; a pregnancy lasts 3 days and the baby is born at home. Jo is a 20-year-old woman. People die of
old age (usually 78–96): they become a grave outside their home and the people who loved them grieve.

### Homes and invitations (`ownership.gd`)
Every house belongs to the people who live in it (their `home`): you and Sam live in Your house,
Alex and Riley in their own. **Nobody may go into a home that isn't theirs unless they're invited.**
This is enforced by pathfinding: `world.find_path(..., who)` treats forbidden houses as walls, so
nobody, not even you, can walk in uninvited (only out, if you're already inside).

| How to get in | What happens |
|---|---|
| **Knock** (click the door, or an NPC who wants to see someone inside) | Walk to the door and knock. A resident who is home and awake answers: let in with chance `0.4 + friendship/100 + emotion + traits + grudge` (strangers 10%). Let in = invited. No = Rejected moodlet, and NPCs won't knock there again for 3 h. Nobody home: "Nobody answered" after 30 game minutes |
| **Invite over** (social interaction, friendship ≥ 10) | The partner is invited to the initiator's home |

* **Your door:** when someone knocks while you're home in Manual mode, you decide: a popup asks
  *Let them in* or *Turn them away*. In Auto mode, or if you're out, a housemate answers.
* **Invitations** last **6 game hours** (`INVITE_HOURS`), stored in `world.guests`. When one ends,
  the guest walks out on their own. A host can also **Ask to leave** (a guest in their home; can't
  be refused). Asking is more likely when Tense, Angry, or a Loner.
* Guests can't use the hosts' kitchen (NPCs only use their own home's objects).
* The relationships drawer shows invitations both ways with the time left.

### Perception (`perception.gd`)
Every `LOOK_INTERVAL` (0.5 s) each NPC looks around. It **sees** every character on its floor within
`SIGHT_RADIUS` (10 tiles) with a line of sight, including through windows and open doors. The result
is in `seen` (shown with F3). For each person seen, `notice()` decides whether it's worth reacting to.
Someone asleep (using a Bed) sees nothing. The player overrides `notice()`, so you choose your own reactions.

**Peeking.** Each look, someone inside the house you're peeking into who can see you has a 35%
chance (`NOTICE_CHANCE`) to catch you. They react once per peek:

```
score = their friendship toward you / 100 + (their mood − 50) / 100 − 0.15 ± 0.25 (random)
        − 0.2 if they've never met you
        − 1.0 if you caught them at the Shower or Toilet
        + their emotion's "saying yes" bonus (Angry −0.3, Happy +0.1...) + traits (Hot-headed −0.2)
```

| Score | Reaction | Their friendship toward you | Also |
|---|---|---|---|
| > 0.25 | Waves | +2 | Social +5. If they're free, they come outside to chat with you, which ends the peek |
| −0.15 to 0.25 | Stares back | −3 | – |
| < −0.15 | Yells "Creep!" | −10 (−20 if at the Shower/Toilet) | Closes the curtains on that window for 60 s, which ends your peek and blocks sight |

The reaction shows above their head for 4 s and goes into the social log. In practice strangers
usually stare or yell, good friends in a good mood wave, and anyone caught in the shower yells.
Staring or yelling makes **you** Embarrassed, and they **remember** it; a wave makes them Happy.

---

## Build mode

Press **B** at home: time pauses and a catalog of about 45 items in 10 categories opens along the
bottom. Pick an item, rotate it with R, and click to buy and place it. Usable furniture (chairs,
sofas, beds, kitchen appliances, toilet, bathtub, sinks, bookshelf, TV, fireplace) works right away
for everyone in the house. Click furniture with nothing picked to rotate, move or delete (sell) it. You can't build
in walls, doorways or on the stairs, or block anything. Details and the full catalog:
**[docs/BUILD.md](docs/BUILD.md)**.

## Character art

People are Quaternius' **Universal Base Characters** (free version, CC0; `assets/characters`: the
rigged male and female glTF bodies, light/dark skin textures, hairstyles, beard). The pack has no
animations and its bodies are in underwear, so **`tools/bake_characters.gd`** does it all in code:

* **Poses** by rotating skeleton bones: arms down from the T-pose, a 4-step walk cycle (legs and
  arms swinging), sitting (thighs forward, knees bent, lowered), lying (on the back).
* **Clothes** painted on by a shader, per vertex by its main bone: shirt on the spine, clavicles and
  upper arms; trousers on the pelvis and legs; shoes on the feet; skin (the pack's texture) elsewhere.
* **Hair** ("origin at 0" models) attached to the head bone; hair and eyebrows tinted per look.
* Rendered at the game's isometric angle and scale in **8 directions × 7 frames** (idle, walk ×4,
  sit, lie) into one sheet per look: `art/characters/<look>.png`, cells of 96×112 px, feet at (48, 100).

| Look | Body | Skin | Hair | Shirt / pants |
|---|---|---|---|---|
| jo (you) | F | light | long, brown | teal / navy |
| sam | M | dark | buzzed + beard | orange / grey |
| alex | F | dark | buns | purple / black |
| mia | F | dark | buns | yellow / blue |
| lily | F | dark | short | light blue / pink |
| riley | M | light | parted, grey + beard | red / brown |
| noah | M | light | parted, brown | blue / charcoal |
| girl_a, girl_b, boy_a, boy_b | | | | for babies born in the game (picked by sex) |

In the game (`npc.gd animate()`): the row is the direction they walk (or face what they use / who they
talk to), the frame is the walk cycle while moving, **sitting** on chairs, couches, the toilet and at
the table, **lying** in bed or napping on the couch (drawn on the bed). Children are scaled down by
age (toddler 50%, child 70%, teen 90%); babies keep their bundle. A small overlay on top draws the
progress bar and whatever they carry.

**Add or change a look:** edit `LOOKS` in `looks.gd`, run `godot --path . -s res://tools/bake_characters.gd`
(needs a window; add look names after `--` to bake only those), then `godot --headless --import`, and
give a person `.set_look("name")` in `main.gd`.

## Furniture art

The 3D furniture pack (`assets/*.zip`; the OBJ version is unpacked in `assets/furniture_obj/OBJ`) is
turned into 2D sprites by **`tools/bake_furniture.gd`**: each model is rendered with an orthographic
camera at the game's 2:1 isometric angle (30° pitch, 45° yaw) and scale (1 m = one tile, 45.25 px per
metre), lit, cropped and saved as `art/furniture/<Model>_r<rotation>.png`, with the pixel of its floor
centre in `sprites.json`. Rotation r0 faces the +y grid direction (towards where you stand to use it),
r1 +x, r2 −y, r3 −x. Models are scaled to 85% and to at most 1.6 m across, so they fit a tile.

Sprites are shown as `Sprite2D` children (drawing them by hand in `_draw` inside the y-sorted world
renders them white with the GL Compatibility renderer).

| Object | Model |
|---|---|
| Fridge, Counter, Stove, Sink | Kitchen_Fridge, Kitchen_2Drawers, Kitchen_Oven, Kitchen_Sink |
| Table | Table_RoundSmall |
| Bed | Bed_King (your house), Bed_Single (others; also Crib) |
| Shower | Bathroom_Bathtub (the pack's shower model is just a rail) |
| Toilet, Bookshelf | Bathroom_Toilet, Bookshelf |
| TV, Bench, Pull-up bar, Bus stop | placeholder boxes (no model in the pack) |

**Your house** is also decorated with props (`PROPS` in `main.gd`): kitchen cabinet, two chairs at
the table, a couch facing the TV on a rug, a floor lamp, plants, a bathroom sink and a bin downstairs;
a nightstand, floor lamp, round rug, bathroom sink, armchair, dresser, shelf and plant upstairs.
Props block their tile (rugs don't); a test checks every object is still reachable from the door.

All catalog models are baked in 4 rotations (180 sprites).

**Add furniture:** add the model to `MODELS` in `tools/bake_furniture.gd` (with the rotations you
need), run `godot --path . -s res://tools/bake_furniture.gd` (needs a window), then
`godot --headless --import`, and use `"<Model>_r<n>"` in `FURNITURE` (an object type), an object's
`"sprite"` extra, or a `PROPS` row.

## How to…

**Add an object:** one row in `OBJECTS` in `main.gd`:
`["Sink", 0, 0, Vector2(484, 505), {"hygiene": 30}, 2.0, Color.WHITE, 24]` (building, floor, tile).
The tile in front of it (y + 1) must be walkable. People who live there (or anyone, for building −1)
will use it automatically if it helps their needs.

**Add a building:** add a row to `World.BUILDINGS` (rect including walls, floors, door on the bottom
or right wall, optional stairs cell, color). Trees are kept off it automatically. Then add its
objects to `OBJECTS` and give residents that building index as their home.

**Change how fast time runs:** `MINUTES_PER_SECOND` in `game_time.gd`. Need decay stays in game hours.
Season length: `DAYS_PER_SEASON`. Sunrise/sunset: `SUN`. Colours: `GRASS`, `LEAVES`, the tints.

**Add a need:** add it to `NEEDS` in `npc.gd` *and* `hud.gd`, give some object (or kitchen recipe/drink)
an advertisement for it, and extend the F3 line in `npc.gd label_text()`.

**Add a recipe or drink:** one row in `RECIPES` / `DRINKS` in `kitchen.gd`, plus its row in
[docs/KITCHEN.md](docs/KITCHEN.md).

**Add an interaction:** add a dictionary to `INTERACTIONS` in `social.gd` (and its memory text in
`past_tense()`). The AI and the click menu pick it up automatically.

**Add an NPC:** `add_child(Npc.new().setup("Name", Vector2(x, y), Color(...), home, ["Trait", ...], {"Skill": level}))`
in `main.gd`, where `home` is a building index (−1 = no home).

**Add a trait, moodlet or skill:** see *How to…* in [docs/PEOPLE.md](docs/PEOPLE.md).

**After any change:** run the checks (see *Running it*). Add a check to `tests/check_sim.gd` for new
behavior, and add an entry to `docs/DEVLOG.md`.

---

## Known limitations
* Characters walk through each other (pathfinding only avoids walls, trees and objects).
* Paths longer than ~150 tiles are refused, so you can't click across town in one go.
* Doors are always open, and houses have no inner walls or rooms yet.
* Only ground-floor windows on the two camera-facing walls can be peeked through.
* Doors can't be locked; ownership is enforced by pathfinding, not by a lock.
* Only one street has houses; the rest of the 1 km map is grass, trees and empty roads.
* Seasons only change how things look and how long the days are; there's no temperature or weather yet.
* NPCs have no daily schedule (work, school) yet; they only prefer to sleep at night.
* Nothing happens when a need hits 0 (no accidents, fainting or moodles yet).
* Food costs money but the fridge never runs out (no grocery shopping or stock yet).
* Workplaces and schools are off-map: you see the bus stop, not the café or school.
* Graves are decorative; nobody visits them yet.
* Babies and toddlers can't be neglected to the point of being taken away (they just cry).
* One person per object: a Table seats one, so two people eat one after the other.
* No save/load; relationships reset each run.
* Everything resets each run (no save/load).
* Jo has no traits; NPC lines come from small fixed lists.
* Labels can overlap when characters stand close together.

## Roadmap (rough order)
1. **Consequences at 0**: bladder accident, passing out, refusing to socialize when miserable.
2. **Relationships 2.0**: romance, family, rivals; choosing your own traits; aspirations/goals.
3. **Things to buy**: groceries with stock, furniture, a shop on the street.
4. **Save/load**.
5. **Schedules and weather**: jobs, opening hours, temperature, rain and snowfall.
5. **Rooms and a bigger town**: inner walls, lockable doors, more streets and buildings, maybe generated.
6. **Zomboid layer**: scarcity, danger, injuries, safety as a need.
7. Optional: LLM-written dialogue on top of the systemic AI (systems decide, LLM only writes words).
