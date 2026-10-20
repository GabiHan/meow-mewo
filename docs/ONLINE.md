# Online mode: play with real people on the same Wi-Fi (`net.gd`)

**Offline** (Play Game) is the game as it always was: one household, everyone else runs on the AI.
**Online** (Play Online) puts several real people in one town: each plays their own household, live,
and everyone else is still run by the AI. It works on the same Wi-Fi (or the same computer); no
accounts, no server.

## How to play

| Who | What to do |
|---|---|
| Host | Home screen → **Play Online → Host a town** → choose a household, create a new one, or continue your last save. Others can join as soon as you're in. The top-left panel shows `Online: hosting · 1/4 players · 192.168.x.x` (your address) |
| Joining | **Play Online → Join a town**: towns on your Wi-Fi appear by themselves (click one), or type the host's address and press Join. Then **pick a free household** ("Someone's playing" ones are taken) or **Move a new household in** (into the starter house, if nobody lives there): the same household creator as offline |

Up to `MAX_PLAYERS` (4) people. A household someone is playing can't be taken by anyone else.
macOS may ask whether Godot may accept incoming network connections: the host must allow it.

## What's different online

| Thing | Online |
|---|---|
| Other players' characters | Real people: they only do what that player does (or live on their own in Auto). Their name in your menus is followed by "(a real person)" when you Talk… |
| **Talk…** with another player | Their talk window opens; you type to each other (no AI). Each message: a little friendship (`Talk.HUMAN_TONE`, +0.5) and social for both. When either closes it, you've met and both remember the talk |
| Talk… with an NPC, conversation lines, thoughts, wishes | Written by the **host's** language model (docs/AI.md), for everyone. "AI:" in the panel shows the host's status |
| Social interactions with another player | The same menu as with anyone. The systems decide yes or no (as when an NPC asks you); knocking at their door asks *them* (Let them in / Turn them away) |
| Game speed and pause | **The host decides** for everyone (the buttons are greyed out for others). Sleeping doesn't speed time up online |
| Build mode | Offline only for now ("Build mode only works offline for now") |
| Saving | Only the host saves (Menu → Save). In that save the other players' households are ordinary households again |
| A player leaves | Their household lives on by itself (back to the AI). "{name} went offline" in the social log |
| The host leaves | The town closes: everyone goes back to the home screen with "The host closed the town." |

## How it works

The **host runs the whole simulation** (needs, the AI, jobs, the language model) exactly as offline.
A joined game is a **mirror**: it starts from a snapshot of the town (`SaveGame.capture`, the same data
as a save file) and from then on only shows what the host sends. On a joined computer people are
**puppets** (`npc.gd puppet`): they don't think or decay, they glide to where the host says (`net_target`)
and animate; `world.gd puppet` stops day changes (bills, ageing) and `llm.gd remote` turns the model off.

| Message | From → to | How often | What |
|---|---|---|---|
| `hello` / `offer` | joiner → host → joiner | on connect | game version; the households (who's in them, taken or free) and whether the starter house is free |
| `claim` / `welcome` | joiner → host → joiner | once | the household picked (or a new one: names that already exist get a number), then the snapshot and who you are |
| `fast` | host → players | every `FAST_SECONDS` (0.1 s), unreliable | the clock, game speed, pause, and per person: where, floor, state, object in use, progress, partner, activity, what they carry, at work, peeking window, Auto, a real person or not |
| `slow` | host → players | every `SLOW_SECONDS` (1 s) | every person's `SAVE_FIELDS` (needs, feelings, relationships, money, skills, memories...) plus thought and wish; who's using each object and what's on it; kitchens, guests, the social log, the AI status, the player count. New people (births, households moving in) are created, people who died disappear |
| `layout` | host → a player | when furniture changes (a hash in `slow`) | all objects and props; changed ones are rebuilt |
| `heard` | host → players | as it happens | something someone said (`show_emote`): it goes into your chat feed if you can hear it |
| `command` | player → host | as you do things | orders (below) |
| `menu` / `you_are` / `talk_event` | host → a player | as needed | a menu to choose from, who you now control, what happens in your talk window |

**Orders** (`Net.order(game, kind, args)`; offline and on the host they run right away, joined they're
sent to the host, which runs them with that player's own Controller, `controller.gd peer`):

| Order | Args | What the host does |
|---|---|---|
| `click` | `{kind: "person", name}` / `{kind: "building", hit}` / `{kind: "tile", cell}`, worked out on the player's screen (`resolve_click`) | The same as a click: a person's menu, knock/enter/peek, walk, use an object, a kitchen or jobs menu |
| `choice` | menu entry number | Runs that entry of the last menu sent to them |
| `mode` | | Manual / Auto |
| `control` | name | Switch to another member of their household (not one someone else plays) |
| `care` | baby's name, action | Feed, Change & clean, ... (the baby panel) |
| `talk_open` / `talk_send` / `talk_close` | name / text, history / | talk.gd |

Objects have a `net_id` (world.gd `add_object`) that's the same on every computer (saved too); people
are matched by name, which is why names are unique in a town.

**Finding towns:** the host sends a small "here's a town" packet to the whole Wi-Fi every
`BEACON_SECONDS` (1 s) on UDP port `DISCOVERY_PORT` (8911); Join a town lists what it hears and forgets
towns silent for `FOUND_SECONDS` (4 s). The game itself uses ENet on port `PORT` (8910).

## Limits (for now)

* Same Wi-Fi only (or a VPN that makes it look like one). Over the internet would need a relay server.
* Build mode is offline only; the host decides the game speed for everyone.
* Joined players can't save; the town is the host's.
* A joined player sees changes about 0.1 s (where people are) to 1 s (everything else) late.

## Testing

`tests/check_online.gd` (`godot --headless -s res://tests/check_online.gd`, no `--fixed-fps`) starts a host
(`tests/online_host.gd`, Jo & Sam, jobs cleared) as a second process and joins it over 127.0.0.1 as Alex's family:
the household list, the snapshot, puppets, the clock, walking by clicking, a menu built on the host,
Talk… with Mia through the host, the chat feed. `check_sim.gd` checks talking to a real person offline
(no AI, friendship, memory).
