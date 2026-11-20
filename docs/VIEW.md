# Seeing the world: sight, light and weather (`vision.gd`, `weather.gd`, `weather_fx.gd`)

Like Project Zomboid: you look down on the whole neighbourhood, but you only *see* what your sim can see.

## What's on screen (`world.gd update_view`)

| Thing | Shown |
|---|---|
| The neighbourhood (terrain, roads, trees, outdoor objects) | Always, inside or out (chunks around you are streamed) |
| The house you're in | Opened up: the floor you're on (tiles, cut-down walls, furniture), no roof or exterior |
| Other houses | From outside (their exterior), dimmed like everything else you can't see right now |
| People | Only while your sim can see them (`vision.sees()`), never inside another house (unless you're peeking in through its window) |
| Cars | Driving: only while your sim can see them, like people. Parked: always (scenery, veiled like trees) |
| Out of sight | A soft veil: light over places you remember, thicker over places you've never seen. Dusty rose-lilac by day, deep plum at night (like the dusk UI), cream in fog |

Furniture names only appear on mouse-over, and strangers show nothing above their heads (see README).

## Sight (`vision.gd`)

Every `UPDATE_MSEC` (150 ms, real time) it casts `RAYS` (480) rays from the person you control, on their floor,
out to `RADIUS` (34) tiles. A ray stops at a wall (`world.blocks_sight`: walls and closed curtains; open windows
and doors let sight through, so you can see in and out of houses through their windows).

| Ray | How far it sees |
|---|---|
| In front (a `CONE_DEGREES` = 180° cone around where they face) | `sight_range()`: from `NIGHT_RANGE` (3.5 tiles) in the dark to `DAY_RANGE` (28) in daylight (`GameTime.daylight`); outdoors × the weather |
| Behind | `BEHIND_RANGE` (4.5 tiles) |
| Lit tiles | `DAY_RANGE` (× weather outdoors), as long as the ray gets there |

**Light** (only matters when it's dark, daylight < 0.6): lamps (furniture whose sprite is a `Light_…`) light
`LAMP_RADIUS` (5) tiles around them; a house is lit inside at night while someone there is awake.

What you see is remembered per floor (`remembered`). The veil is one pixel per tile, stretched onto the
isometric grid with smooth filtering (soft edges); its thickness is `MEMORY_ALPHA` / `UNKNOWN_ALPHA`, from the
day value to the night value with the darkness. Trees, house exteriors and the furniture and walls of the house
you're in are tinted the same way (a house you see any wall of is shown as seen).

## Weather (`weather.gd`)

The world has one weather at a time (`world.weather`), lasting 3–8 game hours, then a new one is drawn for the
season (fog is 3× likelier before 10:00). It's saved, and online the host sends it to everyone.

| Weather | Sight outdoors | Sky by day | °C | Spring | Summer | Fall | Winter | On screen (`weather_fx.gd`, outdoors) | People outside (inside) | Needs outside |
|---|---|---|---|---|---|---|---|---|---|---|
| ☀ Clear (☾ at night) | ×1 | – | +2 | 4 | 6 | 3 | 3 | the sun's glows (README "Day and night") | Sunny day (Happy 1) | – |
| ☁ Cloudy | ×0.85 | grey | −1 | 3 | 2 | 3 | 3 | drifting cloud shadows | – | – |
| ≈ Windy | ×0.95 | slightly grey | −2 | 2 | 1 | 3 | 1 | leaves (petals in spring, snow in winter) blowing past | Windswept (Energized 1) | hygiene ×1.3 |
| ☂ Rain | ×0.6 | blue-grey | −3 | 3 | 1 | 3 | 1 | rain, cloud shadows | Soaked (Uncomfortable 2) (Cozy inside, Happy 1) | hygiene ×1.5, energy ×1.1 |
| ⚡ Storm | ×0.45 | dark | −4 | 1 | 1 | 1 | 0 | heavy slanted rain, lightning flashes (a dimmer flash indoors), blowing leaves | Caught in a storm (Tense 2) (Cozy inside) | hygiene ×2, energy ×1.2 |
| ❄ Snow | ×0.7 | cold white | −6 | 0 | 0 | 0 | 4 | snowflakes | Snow day (Playful 2) (Cozy inside) | energy ×1.2, hunger ×1.15 |
| ≋ Fog | ×0.3 | – | −1 | 1 | 0 | 3 | 2 | a white haze, and the veil turns white | – | – |
| ♨ Heatwave | ×0.9 | warm | +9 | 0 | 2 | 0 | 0 | a warm shimmer | Too hot (Uncomfortable 2) | thirst ×1.8, energy ×1.2, hygiene ×1.3 |

**Temperature** (`Weather.temperature()`): the season's average (spring 14, summer 25, fall 12, winter 1 °C), ±5
through the day (warmest at 15:00, coldest at 03:00), plus the weather's °C.

Moods come from `npc.gd look_around()` (conditional moodlets: they last while you're out in it); people at work
aren't affected. The sky tint is `world.gd sky_color()`: `GameTime.tint()` × the weather's tint, scaled by daylight
(and to a third indoors). Under the clock: weekday · part of the day, the weather sign and the temperature; hover it
for "Rain, 9 °C — Steady rain". Effects move on real time (the same at any game speed).

## Tuning

`vision.gd`: `RADIUS`, `RAYS`, `DAY_RANGE`, `NIGHT_RANGE`, `BEHIND_RANGE`, `CONE_DEGREES`, `LAMP_RADIUS`,
`UPDATE_MSEC`, `MEMORY_ALPHA`, `UNKNOWN_ALPHA`, the veil colours. `weather.gd`: `KINDS`, `CHANCES`, `MORNING_FOG`, `HOURS`, `SEASON_TEMP`, `SWING`. `weather_fx.gd`: the particle counts
and the glow colours.
A sight update takes about 8 ms (mostly the rays).

## Limits

* Upstairs you only see the floor you're on (no looking out of upper windows).
* Trees don't block sight; furniture doesn't either.
* NPCs' own sight (perception.gd) doesn't depend on light or weather yet.
