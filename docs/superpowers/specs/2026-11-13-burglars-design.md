# Burglars and police — design

Date: 2026-11-13. Status: approved (the user asked to build right away; the calls below marked *(my call)* were settled without a round of questions).

## Intent

A burglar sometimes breaks into a house to steal. It is a **threat that makes the player want to protect their
home**: they prepare (security items in build mode), and when it happens the outcome follows from conditions
(if / else on the situation: who saw him, is he violent, is there a phone, an alarm…), not pure dice.

Possible outcomes (from the request):
- he steals and runs away;
- someone spots him: he kills them, then steals;
- someone spots him: he kills them and runs away;
- the person who spots him manages to call the police; the police then catch him, or he gets away.

## Goals
- A visible burglar walking, picking the lock, searching, running; police arriving by car and chasing him.
- Security items to buy that change the outcome (approach C: items to prepare + the people at the moment).
- When **you** (the controlled person, Manual mode) spot him: a choice popup like `ask_at_door`
  (*Call the police / Hide / Fight / Shout*). In Auto mode, or for NPCs, the same choice is made by rules.
- Clear consequences: stolen money and furniture, a death (with the existing grave and grief), moodlets, a line in
  the events feed.

## Non-goals
- No combat system (a fight is one roll from the conditions, shown with an emote and a `down` pose).
- The player can never be the burglar. No jail, trials, insurance.
- No AI words needed (the model may still voice reactions through existing `show_emote`, nothing new).

## Anti-goals (it fails even if it works)
- Burglaries so frequent they become a chore, or a home that is hopeless to protect.
- Unfair deaths: dying with nothing you could have done. Every death must follow from a condition the player can
  change (no phone, no alarm, fought a violent burglar, …).
- Breaking the cozy look elsewhere: no blood, no gore. A death uses the existing grave.

## Constraints (from CLAUDE.md)
- Everything still works with the AI off, online (host simulates, joined games show puppets) and in tests.
- People move only with `walk_to()`. Reactions to what people see go in `perception.gd`.
- Unknown people are "Unknown": the burglar is never named; the log says "a burglar".
- New catalog items need an `object` + an `actions.gd` entry; keep docs/BUILD.md, README tables in sync.
- Tests in `tests/check_sim.gd` and `tests/check_online.gd` must pass; DEVLOG entry.

## Approaches considered
1. **Visible burglar and police in the world** (picked by the user): they are `npc.gd` people with a `role`
   ("burglar", "police"); a new static module `burglary.gd` decides when, where and how it ends. Reuses
   pathfinding, running, poses, perception, `Life.die`, the police car model. More work (online sync, tests).
2. Off-screen event: the outcome is computed at the time and applied (items gone, a notification). Cheap, but no
   chase, no moment to react, the popup would mean nothing. Rejected: it kills the threat.
3. A separate burglar script not based on `npc.gd`: would redo movement and sight. Rejected.

## Design

### Who and when (`burglary.gd`, static, plus a little state on `world`)
- Once per game night (00:00–05:00) a roll with `NIGHT_CHANCE` (tuned so it happens about **once a game week**
  in the neighbourhood); by day a smaller `DAY_CHANCE`, only for a house with **nobody home** (all at work/school/out).
- Target choice: houses with residents. **Your household's home is picked 1 time in 2** (it's a threat for *you*);
  otherwise a random other one. *(my call)*
- Deterrence before he even comes: a house whose **outdoor lamp** is on at night is skipped (he tries another
  house; if all are protected, no burglary that night). A house where someone is awake at night (`vision.gd` already
  knows "lit" homes) is skipped too.
- No more than one burglary at a time. Not during build mode; not in the first game day.

### The burglar
- A new `npc.gd` person, `role = "burglar"`, dark clothes (a `Looks` preset), adult, not in the `"characters"`
  group (so no needs, socials, bills, ageing); his own group `"intruders"`. Hidden stats rolled at spawn:
  `violent` (`VIOLENT_CHANCE` ≈ 0.25), `strength` 0–10, `nerve` (how long he stays).
- Steps: walks in from the street edge → **picks the door lock** (`PICK_MINUTES`; ×3 with a reinforced lock, and
  `GIVE_UP_CHANCE` ≈ 0.6 to give up at a reinforced lock) → goes in (exception in `world.can_enter` for his target
  only) → **searches** 1–2 rooms → takes loot → leaves by the door and runs to the street edge → despawns.
- **Loot:** `STEAL_SHARE` (≈ 30 %, max `STEAL_MAX` $500) of the household's money, split over the grown-ups, plus
  up to 2 of the most valuable *carryable* items (TV, radio, lamps, plants, teddy, shelves, small tables: catalog
  `carry: true`). Taken items disappear from the house (removed like a sale, no refund). He shows a carried bag.

### Being spotted (`perception.gd` → `Burglary.spotted(witness, burglar)`)
A resident (Teen or older, awake, line of sight) sees him. Children and babies who see him only cry/hide (he never
targets them). The witness chooses **one** reaction:
- **You, Manual mode:** popup *Call the police* (only listed if the house has a phone) / *Hide* / *Fight* / *Shout*.
  The game pauses while the popup is open *(my call)*.
- **NPC or Auto:** by rules — has a phone and not Hot-headed → Call; Hot-headed or Fitness ≥ 5 → Fight;
  Loner or Anxious → Hide; otherwise Shout.

Then the outcome, as an if/else (the core table; values are tuning constants):

```
if alarm and he's inside                     -> alarm already rang: police are coming, he flees (see Alarm)
match reaction:
  "Hide":   he keeps stealing, then leaves                      => STEAL AND FLEE
  "Call":   calling takes CALL_MINUTES
            if violent and he reaches the caller before the call ends -> attack (below)
            else -> police called; he grabs what he holds and flees    => FLEE (police chase)
  "Shout":  wakes the house (Perception: everyone awake, "Scared")
            if violent and alone with the shouter -> attack
            else -> he flees with what he already has            => FLEE
  "Fight":  win if witness strength (Fitness + traits) > burglar strength (+ random ±2)
            win  -> he drops the loot and flees empty-handed; he's "down" for a moment (police catch chance up)
            lose -> attack result (below)
attack:
  if violent -> the witness is killed (Life.die, cause "killed by a burglar")
                if the house is still quiet (nobody else awake, no alarm, no police called) -> KILL AND STEAL
                else                                                                     -> KILL AND FLEE
  else       -> the witness is knocked down (pose "down", "Hurt") and he flees with the loot => FLEE
```

### Alarm, phone, police
- **Alarm** (wall item): rings when he opens the door: wakes the whole house, calls the police by itself. He flees
  at once unless violent (then `ALARM_FLEE` ≈ 0.7 he flees anyway).
- **Phone** (small item): needed to call. Without one nobody in the house can call (only Hide / Fight / Shout).
- **Police:** arrive `POLICE_MINUTES` (≈ 15 game min, ×0.5 with an alarm) after the call, in a **police car**
  (the existing Kenney `police` model, traffic-style) at the house's door, two officers (`role = "police"`, npc.gd).
  - Burglar still inside or on the property → **caught**.
  - Burglar running → chase: police run at running speed; he escapes if he gets `ESCAPE_DISTANCE` tiles from the
    house before they reach him (`CATCH_REACH`). With his lead and the arrival delay, catching depends on how fast
    the police were called (alarm, phone).
  - Caught → he's taken to the car and both leave; **loot returned** (money back, items back in place).
    Escaped → loot is gone.

### Security items (new catalog category "Security")
| Item | Price (draft) | Effect |
|---|---|---|
| Phone | $60 | lets people in the house call the police |
| Reinforced lock | $250 | per house, no tile (like Stairs): pick ×3, he may give up |
| Alarm | $400 | rings on entry: wakes everyone, police called automatically |
| Outdoor lamp | $80 | placed outside next to the door; on at night: he skips the house |

Each needs an `object` + `actions.gd` entry (Phone: *Call a friend* (social +); Alarm: *Test the alarm*; Outdoor
lamp: *Turn on/off*). Models from the kits if present, placeholder boxes otherwise.

### Consequences
- Moodlets: *Burgled* (Sad/Tense, household, 2 days), *Scared* (witnesses), *Brave* (won a fight), *Traumatised*
  (saw a killing), *Relieved* (police caught him). Grief from the existing `Life.die`.
- Events feed: "A burglar broke into {house}", "{a} was killed by a burglar", "The police caught the burglar",
  "The burglar got away with $X and the TV". Shown for your household (`hud.ours_event`).
- Memory: the house remembers ("was burgled") for AI prompts (`Social.remember` style, optional).

### Online, saving
- Host simulates; burglar and police are synced like people (fast/slow updates); the popup goes through
  `Net.order` / `send_menu` like `ask_at_door`.
- Saving during a burglary: the burglary is dropped (burglar and police vanish, nothing stolen yet stays). Security
  items are normal objects/props and are saved. Reinforced lock: a building flag in `building_state()`.

### For testing and trying it
- `Burglary.start(world, building, opts)` forces one (opts: violent, strength). A debug key (F7) starts one at your
  house *(my call)*.
- Outcome function is pure (`Burglary.outcome(situation) -> String`) so `check_sim.gd` can test every branch,
  plus a few full runs (steal and flee; killed and steal; police catch; escape; lock give-up; alarm).

### Docs
- New `docs/CRIME.md` (the rules and the outcome table), README section and tables, docs/BUILD.md items, DEVLOG.

## Calls settled after the builder check *(my call)*
- **NPC reactions are never reckless**: rule-made reactions call only when the burglar is farther than
  `CALL_SAFE` tiles (else hide); only Hot-headed people fight. So a housemate dies only by their own temperament,
  never because the player bought a phone.
- **Pause**: the popup pauses the game offline only; online the clock runs and after `CHOICE_SECONDS` the choice
  defaults to *Hide*.
- **Outdoor lamp** turns on by itself from dusk to dawn (no chore).
- **Your home 1 time in 2** is kept.
- **Saving during a burglary**: the burglar and police vanish and everything in his bag goes back.
- Only people **inside the house** (residents and guests) can spot him; neighbours outside don't.

## Left to the builder
- Exact tuning numbers, the burglar's look preset, which rooms he searches, how the bag is drawn.
- How to keep intruders out of systems that iterate `"characters"` while still visible to vision/perception.
- Placeholder vs kit models for the four items.
