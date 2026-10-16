# Kitchen

Everything about food, drinks and dishes. The code is `scripts/kitchen.gd` (tables at the top);
characters run kitchen tasks through the step system in `scripts/npc.gd`. Keep this file in sync
with the tables in `kitchen.gd`.

## The kitchen

Every house has a kitchen made of five objects, plus its own **clean plates and cups**:

| Object | What you can do there (click it) |
|---|---|
| **Fridge** | Cook any recipe; pour Juice, Milk or Soda |
| **Stove** | Cook the stove recipes (Omelette, Pasta, Soup) |
| **Counter** | Make Coffee; eat, or throw away, food left on the counter; wash dirty dishes left there |
| **Table** | Where you eat. Eat or throw away food left there; wash dirty dishes left there |
| **Sink** | Drink Water; wash all dirty dishes in the kitchen |

Each kitchen starts with **4 plates and 4 cups** (`PLATES`, `CUPS`). Cooking takes one plate per
serving and a drink takes a cup. Washing gives the dish back. With no clean plates, every recipe in
the menu is greyed out ("no clean plates"): wash some dishes first.

| House | Fridge | Counter | Stove | Sink | Table |
|---|---|---|---|---|---|
| Your house (ground floor) | (485,500) | (486,500) | (487,500) | (488,500) | (486,504) |
| Alex's house | (500,500) | (501,500) | (502,500) | (503,500) | (501,504) |
| Riley's house | (488,519) | (489,519) | (490,519) | (487,521) | (490,523) |

## Hunger and thirst

These are two separate needs. **Food** fills hunger and **drinks** fill thirst; a few give a bit of
the other. Thirst runs out faster than hunger: it goes from full to empty in 16 game hours, hunger in 24
(`DECAY_HOURS` in `npc.gd`). At 1x speed a game hour is one real minute. Drinks also fill your bladder,
which shows as a negative bladder number.

## Cooking a meal

Click the **Fridge** (or the Stove) and pick a recipe. Your character then does it all:

1. **Fridge**: "Getting ingredients" (2 min)
2. **Counter or Stove** (depends on the recipe): "Making pasta" (the recipe's time). The food is
   put on plates here: one per serving, as long as there are clean plates.
3. **Table**: "Eating pasta". Hunger (and anything else the food gives) fills up gradually while eating.
4. **Sink**: "Washing the plate" (3 min). The plate is clean again.

Recipes with more than one serving leave the **extra plates on the Counter as leftovers**. Anyone
who lives there can eat them later (click the Counter → *Eat*); NPCs do this on their own too.

Times are in game time: "4 min" takes 4 real seconds at 1x speed (1 real second = 1 game minute).

| Recipe | Price | Cooking level | Made at | Cook time | Servings | Eat time | Spoils after | Gives |
|---|---|---|---|---|---|---|---|---|
| Sandwich | $5 | 0 | Counter | 4 min | 1 | 4 min | 8 h | hunger +40 |
| Salad | $6 | 0 | Counter | 5 min | 1 | 4 min | 6 h | hunger +30, thirst +5, fun +5 |
| Omelette | $4 | 1 | Stove | 7 min | 1 | 5 min | 6 h | hunger +50 |
| Pasta | $8 | 2 | Stove | 10 min | 2 | 6 min | 12 h | hunger +65, fun +5 |
| Soup | $10 | 4 | Stove | 12 min | 3 | 5 min | 24 h | hunger +45, thirst +10 |

## Prices

Ingredients are paid at the Fridge ("Getting ingredients") and drinks when poured; leftovers are
free. If you can't afford something it's greyed out ("can't afford") and NPCs won't choose it.
Money comes from jobs: see [WORK.md](WORK.md).

## Cooking skill and food quality

Cooking practises the **Cooking** skill (see [PEOPLE.md](PEOPLE.md)). Recipes need a level:
Sandwich and Salad 0, Omelette 1, Pasta 2, Soup 4. Locked ones show "(needs Cooking N)" in the menu.
The cook's level decides each meal's quality: **Burnt** (hunger ×0.5, *Burnt food* moodlet),
**Good**, or **Delicious** (hunger ×1.25, *Delicious meal*, Happy). Burnt chance is 30% − 6% per
level; delicious is 5% + 8% per level. The quality shows on leftovers, e.g. `Pasta (delicious, fresh, 9h left)`.
Coffee gives *Caffeinated* (Energized), and spoiled food gives *Stomach ache*.

## Food spoils

Every plate of food remembers when it was cooked and **counts down** to spoiling. The time left is
shown on the Counter/Table label, e.g. `Pasta (fresh, 9h 32m left)`, and in the menu. The timer runs
in game hours (`spoil_hours`, measured with `world.now()`), so it goes faster at higher speeds and stops while paused.

| Freshness | When | Eating it gives |
|---|---|---|
| **Fresh** | More than half the spoil time left | The recipe's full value |
| **Stale** | Less than half left | 70% of the hunger, fun −5 |
| **Spoiled** | Timer ran out | 30% of the hunger, fun −15, bladder −20 (stomach ache) |

What counts is the freshness when you sit down to eat. Spoiled food stays where it is until someone
**throws it away** (click it → *Throw away*): the food goes in the bin and the plate goes to the sink.
NPCs never choose spoiled food on purpose.

## Drinks

Pick a drink at its source. Your character pours or makes it, drinks it right there, then washes the cup.

1. **Source**: "Pouring juice" (2 min) or "Making coffee" (5 min). Takes a clean cup.
2. **Same place**: "Drinking juice". Thirst fills up gradually.
3. **Sink**: "Washing the cup" (2 min).

| Drink | Price | Where | Make | Drink | Gives |
|---|---|---|---|---|---|
| Water | free | Sink | 2 min | 3 min | thirst +40, bladder −10 |
| Juice | $2 | Fridge | 2 min | 3 min | thirst +50, hunger +5, bladder −10 |
| Milk | $2 | Fridge | 2 min | 3 min | thirst +40, hunger +10, bladder −10 |
| Soda | $2 | Fridge | 2 min | 3 min | thirst +35, fun +10, bladder −15 |
| Coffee | $1 | Counter | 5 min | 4 min | thirst +20, energy +20, bladder −15 |

## Interruptions and dirty dishes

You can stop a kitchen task at any time (click somewhere else, or someone comes over to talk).
Whatever you're carrying is put down on the nearest **Table or Counter** in the house:

* A plate of food stays there as a leftover, and keeps spoiling.
* A dirty plate or cup stays there until someone washes it (click it → *Wash*, or Sink → *Wash all dirty dishes*).
* A half-finished drink becomes a dirty cup.

Plates and cups on a Counter/Table are drawn on top of it: white = clean with food (the dot is the
food's color), grey = dirty. Your character also visibly carries the plate or cup.

## How NPCs use the kitchen

NPCs use only **their own** kitchen. When idle, each option is scored like any other action
(see *Utility AI* in the README), with two extras:

```
score = Σ amount × urgency(need)          # the recipe's / drink's / leftover's "Gives"
        / (1 + distance × 0.05)
        / (1 + total task seconds / 60)    # long recipes are a bit less attractive
        × random 0.85–1.15                 # so they don't eat the same thing every time
```

* **Leftovers** (fresh or stale) are options too. They're quick, so NPCs often eat them.
* **No clean plates/cups?** If there are dirty ones, the option becomes "wash all dirty dishes, then
  cook". If there are none at all, the option isn't available.
* If the Stove/Table/Sink is busy (someone else is using it), they wait up to 15 game minutes (`QUEUE_TIMEOUT`,
  shown as "Waiting for the Stove"). After that they give up and put down what they were carrying.

## How it works in code

* **Tasks are lists of steps.** `npc.gd run_steps(list)` runs them one at a time. A step is
  `{object, verb, seconds, ads?, start?, done?}`: walk to the object (reserving it), call `start(step)`,
  spend `seconds` there gaining `ads` gradually, call `done()`, go to the next step. Using a TV is a
  single step; cooking is four. Kitchen step lists come from `Kitchen.cook_steps`, `drink_steps`,
  `leftover_steps`, `throw_away_steps` and `wash_all_steps`.
* **Items.** What a character carries is in `held`; items left on a Counter/Table are in its `items`.
  An item is a dictionary with a unique `id`:
  `{"kind": "food", "recipe", "made"}`, `{"kind": "drink", "drink"}` or `{"kind": "dirty", "dish": "plate"|"cup"}`.
* **Clean dishes** per house: `world.kitchens[building] = {"plate": n, "cup": n}`.
* **Freshness** uses `world.clock` (game seconds): `Kitchen.time_left`, `freshness`, `eat_ads`.
* **Player menus** come from `Kitchen.menu(character, object, run)`; the AI's choices come from
  `Kitchen.options(character, building)`.

### Adding a recipe or drink
Add a row to `RECIPES` or `DRINKS` in `kitchen.gd` (and to the tables above). Menus and the AI
pick it up automatically. A recipe needs `cost`, `min_cooking`, `station` ("Counter" or "Stove"), `seconds`, `servings`,
`eat_seconds`, `spoil_hours`, `ads` (must include `hunger`) and a `color`. A drink needs `cost`,
`source` ("Fridge", "Counter" or "Sink"), `seconds`, `drink_seconds` and `ads` (must include `thirst`).

### Adding a kitchen to a building
Add a Fridge, Counter, Stove, Sink and Table for that building to `OBJECTS` in `main.gd`.
