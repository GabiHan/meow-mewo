# Burglars, kidnappers, criminals and the police (`crime.gd`)

A burglar sometimes breaks into a house to steal. He's a threat that makes you want to protect your home: you
prepare with **Security** items in build mode, and when he comes, what happens follows from the situation (who
sees him, is he violent, is there a phone, an alarm…), not from pure dice.

`crime.gd` is one node, `world.crime`. The burglar and the officers are ordinary `npc.gd` people with a `role`
(`"burglar"` / `"police"`): they walk, run and use doors with the normal pathfinding, show up only where you can
see (vision.gd), traffic stops for them, and online they're synced like everyone else. They have no needs, don't
chat, don't age, aren't saved and don't show in menus or the relationships drawer. Their label is just
**Burglar** (once someone has seen him) or **Police**.

## When and where

| What | Rule | Constant |
|---|---|---|
| At night | One roll per game night, starting between 00:30 and 04:30 | `NIGHT_CHANCE` 0.1, `NIGHT_HOURS` |
| By day | One roll per game hour from 9 to 17, only a house with **nobody home** | `DAY_CHANCE` 0.006 |
| How often | About once a game week in the whole neighbourhood | |
| Which house | Houses with residents. At night everyone there must be asleep and its **porch light** off | |
| Your home | Picked 1 time in 2 when it qualifies | `YOUR_HOME_SHARE` 0.5 |
| Not | During the first game day, or while another burglary or the police are still about | |
| Try it | **F7** sends one to your home now (offline or host) | |

## The burglar

He walks up from the street (`ESCAPE_DISTANCE` 30 tiles away), **picks the lock** (`PICK_MINUTES` 8 game minutes;
×3 with a reinforced lock, where he gives up 60% of the time), goes in, and takes:

- **money**: 30% of the household's grown-ups' money, at most $500 (`STEAL_SHARE`, `STEAL_MAX`);
- up to **2 things** (`MAX_ITEMS`), the most valuable *carryable* ones (catalog `carry`: TV, radio, lamps, plants,
  wall shelf, teddy bear, phone). `SEARCH_MINUTES` 6 each. He carries a sack.

Then he leaves the way he came and is gone once he's back down the street. If he got away with anything, the
household feels **Burgled** and the events feed says what he took.

Each burglar is **violent** 1 time in 4 (`VIOLENT_CHANCE`) and has a **strength** of 3–8.

## Being seen

Only people **inside the house** (residents and guests, awake) can see him. The first one to see him reacts; anyone
else who sees him later is just **Scared**.

**You** (the person you control, Manual mode) choose in a popup: **Call the police** (only with a phone in the house,
Teen or older), **Hide**, **Fight him** (Teen or older) or **Shout**. Offline the game pauses while it's open; online
the clock runs and after `CHOICE_SECONDS` you hide.

**Everyone else** (and you in Auto) by rules, never reckless (`npc_reaction`):

| Who | Reaction |
|---|---|
| Child or younger | Hide |
| Hot-headed | Fight |
| He's within `CALL_SAFE` (4 tiles) | Hide |
| There's a phone | Call the police |
| Loner, or Anxious (mind.gd) | Hide |
| Otherwise | Shout |

## What happens (`outcome()`)

`close` = he's within `CALL_SAFE` tiles of the witness. `quiet` = nobody else in the house is awake (Teen or older),
the alarm didn't ring and the police weren't called. A fight is won when the witness' strength (Fitness level, +2
Hot-headed, −3 Old, −2 Teen, ±2 random) beats his.

```
Hide:   he keeps stealing, then leaves                                   -> steal and flee
Call:   violent and close  -> he gets to you before the call ends: attack
        otherwise          -> the police are called, he runs with what he has   -> flee
Shout:  wakes the house (no longer quiet)
        violent and close  -> attack
        otherwise          -> he runs with what he has                    -> flee
Fight:  you win            -> he drops everything and runs                -> beaten
        you lose           -> attack
attack: violent and quiet      -> he kills the witness, then goes on stealing   -> kill and steal
        violent, house awake   -> he kills the witness and runs                 -> kill and flee
        not violent            -> knocked down (30 min on the floor, Hurt), he runs -> knocked
With the alarm (it rang at the door) the police are always on their way.
```

A killing uses `Life.die(c, "was killed by a burglar")`: grave, grief, and if it was you, you carry on as someone
else in the household. Awake housemates are **Traumatised**.

## Protection (build mode, "Security")

| Item | Price | Effect |
|---|---|---|
| Phone | $60 | Lets the house call the police. Also *Call a friend* (social, Charisma). He may steal it |
| Alarm | $400 | Rings when he opens the door: wakes everyone, calls the police (they come twice as fast). A calm burglar always runs; a violent one 70% of the time (`ALARM_FLEE`) |
| Reinforced lock | $250 | For the whole house (no tile). Picking takes ×3 and he gives up 60% of the time |
| Porch light | $80 | For the whole house (no tile). On from dusk to dawn, lights the door: he won't pick the house at night |

The lock and the porch light are `BUILDINGS` flags (`lock`, `porch_light`), saved in `building_state()`. They can't
be sold. Phone and Alarm are placeholder boxes (no model in the kits).

## The police

They arrive `POLICE_MINUTES` (15 game minutes, ×0.5 with the alarm) after the call, in a police car on the street in
front of the house, two officers on foot. If he's still there he runs; they run after him (faster than him).
Within `CATCH_REACH` tiles: **caught**, everything in his bag goes back, the household is **Relieved**. If he gets
down the street first, he's gone with it. Either way the officers stay `POLICE_STAY_MINUTES` and drive off.

## Abductions

The same node also sends **kidnappers** (`kind` "abduction", role `"kidnapper"`, label **Kidnapper** once seen). He
comes for one person, of **any age**, but children most of all.

| What | Rule | Constant |
|---|---|---|
| By day | One roll per game hour from 7 to 21 if someone is **outside alone**: no other awake Teen or older within 10 tiles | `OUT_CHANCE` 0.015, `OUT_HOURS`, `ALONE_RADIUS` |
| At night | When no burglar came that night, a roll: he picks a house like a burglar (all asleep, no porch light) and someone asleep in it | `ABDUCT_NIGHT_CHANCE` 0.03 |
| Who | Weighted by life stage: baby 6, toddler 6, child 5, teen 3, grown-ups 1. Your household 1 time in 2 when it qualifies | `STAGE_WEIGHT` |
| Not | People at work, already missing, a player who joined online, or you if nobody else in your household could carry on | `can_take()` |
| Try it | **F8** sends one for the youngest in your household (not you if there's anyone else) | |

**Outside** he walks up to them (following them as they move; he gives up after `STALK_MINUTES` 90). **At home** he
comes through the door like a burglar: the porch light keeps him away at night, the lock slows him and may make him
give up, the alarm wakes everyone, calls the police and usually makes him run. Then he walks to them.

Within `GRAB_REACH` (1.5 tiles) he **grabs** them. A Teen or older who's awake may **break free** (their fight
strength beats his). Otherwise he takes them: they vanish from the world (hidden, out of "characters"; if it was you,
you carry on as someone else in your household) and he carries a bundle off down the street.

### Being seen

He looks like any stranger until he **has someone in his arms** or is **inside a house**. Then the first person who
sees him reacts, with the same popup (You, Manual: "A stranger is taking Mia!") and the same rules as for a burglar
(`npc_reaction`). Outside there's no phone at hand: calling needs one in the house you're in. `abduction_outcome()`:

```
Hide:   he goes on (takes them, or keeps carrying them off)                  -> taken
Call:   violent and close -> attack
        he doesn't have them yet -> he runs off empty-handed, police called -> freed
        he has them              -> he runs with them, police called         -> taken (the police chase him)
Shout:  violent and close -> attack
        otherwise -> he panics, drops them and runs                          -> freed
Fight:  you win -> he drops them and runs                                    -> freed
        you lose -> attack
attack: violent -> kills the witness, goes on                                -> killed_taken
        calm    -> knocks the witness down (Hurt), goes on                   -> knocked_taken
```

**Freed**: they're back where he was, *Scared* (a winner is *Brave*). **Police**: the same car, officers and chase
as for a burglar; if they catch him, the person he holds is safe and the family *Relieved*.

### Missing

If he gets down the street with them, they're **missing** ("{a} has gone missing", or "was taken by a kidnapper" if
someone saw). Their household, family and partner are **Worried sick** until it ends. Whether they come back is
settled right then, from the situation (`return_chance()`):

| Condition | Chance they come home |
|---|---|
| Base | 40% (`RETURN_BASE`) |
| The police were called while it happened | +30% (`RETURN_POLICE`) |
| A phone at home (the family reports it at once) | +15% (`RETURN_PHONE`) |
| Teen or older (may get away by themselves) | +10% (`RETURN_GROWN`) |
| At most | 90% (`RETURN_MAX`) |

- **They come home** after 1–10 game days (`RETURN_DAYS`), at their front door: older by the days away, hungry and
  tired (needs at most 35), **Traumatised**. The family is **Reunited**.
- **Never found**: after `LOST_DAYS` (21 days) the family stops waiting: "{a} was never found", `Life.die` (grief,
  a grave by their home).

While missing they don't age, work or appear anywhere. They're saved apart from everyone else (`world.missing`:
`capture_missing()` / `restore_missing()`), with their due dates. Saving in the middle of an abduction ends it: he
vanishes and the person he held is back.

## Criminals next door (morals.gd)

When a burglar comes (not a kidnapper), he may be a **neighbour on the Criminal path** (`Morals.is_criminal`: a
grown-up with dark traits whom life pushed into crime; see [PEOPLE.md](PEOPLE.md) "The path"). Never someone from
that house or your household. While it happens they're "out" (hidden, like a missing person) and the burglar
wears their face in dark clothes, as strong as they are.

- Someone who **knows them** and sees the burglar recognises them 60% of the time (`RECOGNISE_CHANCE`): "{a}
  recognised the burglar: it was {b}!", friendship −50 and a bad memory.
- **Got away**: they're back at their own door, richer (the money, and half the price of what was taken).
- **Caught**: "The burglar was {a}!", everything goes back, and they go to **jail** (`JAIL_DAYS` 2): away like a
  missing person, then "came home from jail". A **criminal record** (`record`) and *Arrested*. A record makes crime
  likelier (pressure) and shows in their menu.

## You, breaking in

Click the door of a house you can't go into (Teen or older): **Knock** or **Break in**. You walk to the door and
pick the lock (`PICK_MINUTES` 8, ×3 if reinforced; 6% faster per Stealth level; a reinforced lock may beat you).
Walk away and it's off. Inside, click things: **Steal the TV (fence it for $X)** (carryable things, half their price
straight away) and **Search for cash** (the residents' money, like a burglar). An alarm rings when you get in.

Residents inside who see you react with the same rules as to a burglar (`npc_reaction`, or the popup if it's a
player). `intruder_outcome()`:

```
Hide:  nothing (you carry on)                                       -> unseen
Call:  the police are on their way                                  -> seen, police
Shout: wakes the house; with a phone in the house someone calls     -> seen (+police)
Fight: they win -> you're knocked down (30 min)                     -> you_down (+police with a phone)
       you win  -> they're knocked down                             -> they_down (+police with a phone)
```

Someone who knows you: friendship −50 and a memory. Leave the house before anyone calls: you got away (the
household feels *Burgled*, "Someone broke into…"). Once the police are called, get 30 tiles from the door or into
your own home to escape. Caught: **arrested**: what you took and the money from it go back, a $300 fine
(`FINE`), a criminal record, and 2 days in jail (you play someone else in your household meanwhile; alone, you're
let off with the fine). Afterwards your conscience decides how you feel (Guilty / Thrill / Uneasy).

## Moodlets

| Moodlet | Emotion | Strength | Lasts | From |
|---|---|---|---|---|
| Burgled | Sad | 3 | 48 h | He got away with something from your home |
| Scared | Tense | 3 | 6 h | Saw him, hid, was woken up |
| Brave | Confident | 3 | 12 h | Fought him off |
| Traumatised | Sad | 4 | 72 h | Saw a housemate killed |
| Relieved | Happy | 2 | 12 h | The police caught him |
| Hurt | Uncomfortable | 3 | 12 h | Knocked down by him |
| Worried sick | Sad | 4 | until it ends | Someone in your household, family or your partner is missing |
| Reunited | Happy | 4 | 48 h | They came home |

## Saving and online

- Saving in the middle of a burglary ends it (`abort()`): he and the police vanish and everything in his bag goes back.
- Online the host runs it. The burglar and officers are synced as people (`role`, `carrying_loot` in
  `Net.PERSON_EXTRAS`); a joined player who sees him gets the popup through their controller. The police car is
  only drawn on the host (traffic is local). On joined screens his label stays empty.

## Tests

`check_crime()` in tests/check_sim.gd: every branch of `outcome()`, the reaction rules, picking a house (empty by
day, porch light at night), the porch light's glow, a burglary with nobody home (money and TV gone, Burgled, in the
log), the lock, the popup and winning a fight, Alex (Hot-headed) killed by a strong violent burglar, the alarm
calling the police who catch him and drive off, and saving mid-burglary giving the bag back.

`check_personality()` (also): Dex the psychopath turned criminal as the burglar (got away richer, then caught and
jailed with a record), and you breaking into Dex and Noah's house, stealing the TV, being seen and arrested.

`check_abduction()`: every branch of `abduction_outcome()`, `return_chance()`, children picked more often, "outside
alone", a kidnapper grabbing Mia and Noah shouting him off, Mia missing then coming home 3 days older, taken from home
through the door and given back by saving, saved apart, and never found (grief). `check_saving()` loads a missing
person back as missing.
