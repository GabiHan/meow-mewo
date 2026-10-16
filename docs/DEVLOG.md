# Dev log

Newest first. Each entry: what changed, why, and anything to watch out for.

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
