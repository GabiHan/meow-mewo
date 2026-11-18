# To do (tickets)

Things noticed along the way that weren't part of the task they were found in. Newest first.

## From the Cozy Paws UI work (2026-11-16)
1. **Flaky tests on unchanged code.** `check_sim.gd` fails now and then without any UI change: crime ("a burglar sets
   off for your home", "Dex, now a criminal, is the burglar…", breaking in), invitations ("let in: you're invited and
   walk inside"), the commute ("the car is away while you work") and abductions. A different set fails each run, and
   "2 resources still in use at exit" shows up on the original code too. Probably timing that isn't fully seeded.
2. **`.DS_Store` files are tracked by git** and keep showing as modified: untrack them and add `.DS_Store` to `.gitignore`.
3. **Old colours that don't follow dusk.** Code that uses the old constants or literals directly stays in day colours
   after sunset: `hud.gd` (`DashedBox`, the mood line, `Color(0.65, 0.65, 0.7)` in `friendship_color`, `MID`/`HIGH`),
   `build_mode.gd`, `menu.gd`, `creator.gd`, `key_art.gd`. Move them to `UiTheme.c()` / `UiTheme.tint()`.
4. **Inventory and hotbar** exist as components (`scripts/ui/inventory_slot.gd`, `hotbar.gd`) but the game has no
   inventory yet. If one is added, the hotbar can't use keys 1-4 (they're game speeds).
5. **Design system sync:** the need colours `peach`, `aqua`, `bubble` (hunger, bladder, hygiene) are new in the game;
   add them to the Cozy Paws design system artifact, along with the 7-need StatBar.
6. **Labels in the world** (`npc.gd`, `smart_object.gd`, `block.gd`) now use Nunito through `UiTheme.font()`: check
   they still read well over the world at every zoom.
7. **EB Garamond** (`assets/fonts/EBGaramond*.ttf`) is no longer used: remove it (and its credit) once nothing needs it.
8. **Item art at dusk:** icons that use `petal` (strawberry, gift) turn lilac at dusk. Item art may want fixed colours.
