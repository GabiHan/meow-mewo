# Build mode

Buy furniture from a catalog and place it in your home, like The Sims' buy mode. Code:
`scripts/build_mode.gd` (UI, preview, input) and `scripts/catalog.gd` (items, prices, placement
rules). Keep this file in sync with `ITEMS` in catalog.gd.

## Using it

| Input | Action |
|---|---|
| **B**, or the **Build mode** button | Open / close build mode. Only while the person you control is at home. Time is paused while you build, the view lifts so the catalog doesn't cover the house, and the build-mode song plays |
| Category tabs | **Build** (walls, stairs), Seating, Tables, Beds, Kitchen, Bathroom, Lighting, Plants, Rugs, Storage, Fun |
| Click an item | Pick it up: a preview follows the mouse, **green** where it fits, **red** where it doesn't |
| **R** | Rotate the preview (4 directions) |
| Left-click | Buy it and place it (the money comes from the person you control) |
| Right-click / Esc | Stop placing; something you were moving goes back where it was |
| Left-click furniture in your house (nothing picked) | **Rotate** (turn it in place), **Move** (free), or **Delete** (removed and sold for 75%). Walls: Move or Delete |
| Left-click stairs you built (ground floor) | **Remove them and the upper floor** (75% back), only while nothing and nobody is upstairs |
| **Other floor** | Build upstairs / downstairs |
| **Done** | Close build mode |

## Placement rules

Walls follow the same rules as furniture (free tile, nothing blocked). Stairs need a free ground-floor tile in a
house with one floor; the stairs tile stays walkable. Built stairs and the upper floor are saved
(`world.building_state()`), and online the host sends them to everyone.

* Only inside **your own home** (the home of the person you control), on the floor you're on.
* Only on a free floor tile: not walls, not the stairs, not the doorway or the tile just inside the
  door, not on other furniture.
* Usable furniture also needs its **front tile free** (people stand there to use it). Seats (chairs,
  stools, sofas) don't: you sit on the seat itself, and its tile stays walkable. Its front is
  the side it faces: rotation 0 = towards the lower left, then lower right, upper right, upper left.
* **Nothing may be blocked:** after placing, every object's front tile and the stairs must still be
  reachable from the door (checked with pathfinding). Rugs never block.
* You need enough money (moving things is free).

Selling refunds 75% of the price (furniture that came with the house sells as its catalog item, or
for $20 if it isn't in the catalog). You can't sell or move something someone is using right now.

## The catalog

Usable furniture ("✓") is a real object: people in your home use it on their own (it advertises its
needs to the AI like everything else). The rest is decoration.

| Category | Item | Price | Usable | Does |
|---|---|---|---|---|
| Build | Wall | $70 each | | A cut-down wall like the house's own: blocks walking and sight (rooms!). **Press, drag and let go** to draw a straight line of walls (a click does one tile); the tiles light up green where a wall fits |
| Build | Remove walls | free | | Drag over walls you built to remove them (sold for 75%); they light up pink |
| Build | Stairs + upper floor | $1500 | | Only in a one-storey house, on the ground floor: stairs on that tile and a new, empty upper floor (the house gets taller outside) |
| Seating | Wooden chair / Modern chair / Dining armchair / Stool | $40 / $60 / $75 / $25 | ✓ | Sit |
| Seating | Armchair / Loveseat / Sofa / Corner sofa | $180 / $260 / $350 / $480 | ✓ | Relax, Sit, Nap on the couch |
| Tables | Round dining table / Large table | $120 / $220 | ✓ | a Table (eat here, put food down) |
| Tables | Coffee table / Desk / Nightstand / Bedside table | $90 / $150 / $60 / $70 | | |
| Beds | Single bed / King bed / Bunk bed | $300 / $650 / $420 | ✓ | Sleep (7 h), Nap, Relax in bed |
| Kitchen | Fridge / Oven / Counter / Kitchen sink | $500 / $400 / $150 / $200 | ✓ | the kitchen objects (docs/KITCHEN.md) |
| Kitchen | Kitchen cabinet / Kitchen drawers | $110 / $130 | | |
| Bathroom | Toilet | $250 | ✓ | Pee, Poo |
| Bathroom | Bathtub | $500 | ✓ | Take a shower, Take a bath |
| Bathroom | Bathroom sink | $120 | ✓ | Wash hands, Brush teeth |
| Bathroom | Washing machine | $350 | | |
| Lighting | Floor lamp / Reading lamp / Shade lamp / Standing lamp | $60 / $70 / $90 / $85 | | |
| Plants | Fern / Cactus / Small palm / Big leafy plant | $25 / $20 / $30 / $45 | | |
| Rugs | Rug / Dark rug / Round rug | $60 / $70 / $80 | | walkable |
| Storage | Bookshelf | $250 | ✓ | Read a textbook (Logic), a novel, a cookbook (Cooking) |
| Storage | Wall shelf / Tall shelf / Dresser / Tall dresser / Coat rack / Bin / Large bin | $50 / $140 / $160 / $190 / $35 / $15 / $30 | | |
| Fun | TV | $350 | ✓ | Watch comedy / the news / a cooking show |
| Fun | Radio / Teddy bear | $45 / $20 | | |
| Fun | Fireplace | $800 | ✓ | Relax by the fire, Warm up (placeholder box: no fireplace in the kit) |

What each usable item does in detail is in README, *Furniture interactions* (`actions.gd`).
Rotating checks the same rules: usable furniture needs its new front tile free, and nothing may
become unreachable; seats and decor turn freely.

## Adding an item

1. If it's a new model, add a sprite id and its Kenney kit model to `MODELS` in `tools/bake_furniture.gd`,
   bake (`godot --path . -s res://tools/bake_furniture.gd`) and `godot --headless --import`.
2. Add a row to `ITEMS` in `catalog.gd`: `name`, `category` (one of `CATEGORIES`), `price`, `model`,
   optional `flat` (rugs) and, for usable furniture, `object`: `{name, ads, minutes, extras}` like an
   `OBJECTS` row in main.gd.
3. Add it to the table above.
