# AI: a local language model for words (`llm.gd`, `talk_panel.gd`)

People in Meow Mewo can speak with words written by **Qwen3.5 4B** (by Alibaba's Qwen team, from Hugging Face:
[`unsloth/Qwen3.5-4B-GGUF`](https://huggingface.co/unsloth/Qwen3.5-4B-GGUF), the `Q4_K_M` file, ~2.7 GB),
running **on your own computer** with [llama.cpp](https://github.com/ggml-org/llama.cpp)'s `llama-server`.
It's free, private and works offline after the first download.

**The systems still decide; the model only writes words.** Who talks to whom, whether they say yes,
friendship, moodlets, memories and what people do all come from the simulation as before. The model
gets a short description of the people involved (built from those systems) and writes what they say
and think. Without the server, everything falls back to the scripted lines and the game plays the same.

> Why not Qwen3.8? The smallest Qwen3.8 is 27B parameters (~16 GB even when quantised), which doesn't
> fit next to the game in 8 GB of memory. Qwen3.5 4B is the newest small Qwen that does. To use another
> model, change `MODEL` in `llm.gd` (any `user/repo:quant` GGUF on Hugging Face that llama.cpp supports).

## Setup

```bash
brew install llama.cpp   # once
```

That's all: when the game runs with a window it looks for `llama-server` (Homebrew's
`/opt/homebrew/bin` or `/usr/local/bin`) and starts it on port `8765`. The **first start downloads the
model** from Hugging Face (into `~/.cache/huggingface`), which takes a few minutes; after that it's ready
in a few seconds. (The HUD no longer shows its status; `llm.status_text()` still reports it.) The game stops the
server when the game ends. It runs quietly (`--log-disable`); to see its log, run it yourself (below).

If a server is already running on port 8765 the game uses it and doesn't start (or stop) its own. To run
one yourself (for example on a stronger machine):

```bash
llama-server -hf unsloth/Qwen3.5-4B-GGUF:Q4_K_M --no-mmproj --reasoning off --port 8765 -c 4096 -np 1
```

Tests (headless) never start or contact a server.

## What it does

| Feature | When | What you see | Effect on the game |
|---|---|---|---|
| **Conversation lines** | An accepted interaction starts near you (`HEAR_RADIUS` 25 tiles, on screen, same floor) and lasts at least `MIN_TALK_SECONDS` (4) real seconds at the current speed | In your chat feed: the scripted line at once, then the written one when it arrives (usually 1–3 s), and `REPLY_DELAY` (2.5 s) later the partner's reply | None (words only). Dropped if the conversation already ended |
| **Thoughts** | Every other background job (`BACKGROUND_SECONDS`, 6 real s, when nothing else is queued): someone near you (child or older, awake, not already showing a line) whose last thought is over `THOUGHT_MINUTES` (120) game minutes old | `Name thinks: …` in your chat feed; "Thinking: …" in their click menu while it's fresh | None |
| **Wishes** | The other background jobs: an NPC (not the one you control, child or older, awake, not at work) whose wish has worn off | "Wants to: …" in their click menu (once you've met) and in F3 details | For `WISH_HOURS` (3) game hours, options with that key score ×`WISH_BOOST` (1.6) in `choose_action()` |
| **Talk…** | Click a person → **Talk… (type to them)**: the AI is online, both are children or older, within `TALK_RADIUS` (6 tiles) on the same floor, and they aren't busy with someone | A panel above the bottom row: type, Enter sends, Esc or x leaves. Your words and their answers are in the chat feed too | Per message: their friendship toward you changes by how it came across (`TONE`: nice +2, neutral +0.5, mean −4) and both get +`TALK_SOCIAL` (4) social. On leaving: you've met (names known), they remember "talked with me" (good or bad) and it's logged |

### Wish keys

The model picks one of these (a JSON schema with an `enum`, so it can't invent one):

| Key | Boosts in `choose_action()` |
|---|---|
| An object name (TV, Bookshelf, Pull-up bar, Shower…) that they may use within `WISH_RADIUS` (30 tiles) | That object's actions |
| `cooking` (only if they can cook something at home) | Kitchen options that cook |
| `social` | Every social interaction |

Kitchen objects and the Bus stop aren't offered (cooking covers the kitchen; work has its own schedule).

### Talking to someone

While the panel is open you and they are both in state `talking` with each other as `partner` and neither
is the initiator, so nobody's `talk_timer` ends it. It closes by itself if either of you leaves (clicking
somewhere else, a shift starting, walking more than `TALK_RADIUS` away). Talking doesn't need Charisma and
can't be refused: they always answer, but a mean message costs friendship.

## What the model is told

Built from the systems each time (`who()`, `relation()`, `setting()`):

* **Who**: name (or "a stranger" when the other person hasn't met them), life stage, age, sex; traits with
  their text; feeling and its reasons; mind states (depressed, thriving…); needs under 30 ("hungry",
  "lonely"); job or school; partner.
* **Relation**: how they see the other person (friendship word and value, romance, family) and the last
  three memories of them; "a stranger" if they haven't met.
* **Setting**: weekday, part of day, season, where they are.
* **Conversation lines** also get the interaction's name and the stock line it replaces.

Every request starts with `STYLE` (casual, short, in character, no narration or emojis). Thinking is
turned off (`--reasoning off` and `enable_thinking: false`), and any `<think>` block or `Name:` prefix is
stripped (`clean_line`). Answers that need structure use llama.cpp's JSON-schema output.

Online (docs/ONLINE.md) the **host's** model writes for everyone, and "near you" means near any player.
Talk… with another player doesn't use the model at all (`talk.gd`).

## Requests

One at a time (`busy`), in a queue of up to `MAX_QUEUE` (3) background requests; anything more is
skipped. What you type goes to the front. A request that fails because the server went away sets the AI
offline (scripted lines again) until the health check (`HEALTH_SECONDS`, 3 s) finds it again.

## Tuning

All in `llm.gd`: `MODEL`, `PORT`, `HEAR_RADIUS`, `MIN_TALK_SECONDS`, `REPLY_DELAY`, `BACKGROUND_SECONDS`,
`THOUGHT_MINUTES`, `WISH_HOURS`, `WISH_BOOST`, `WISH_RADIUS`, `TALK_RADIUS`, `TONE`, `TALK_SOCIAL`, `STYLE`.
A smaller model (`unsloth/Qwen3.5-2B-GGUF:Q4_K_M`, ~1.3 GB) answers faster with simpler lines; a bigger
one (`unsloth/Qwen3.5-9B-GGUF:Q4_K_M`) needs 16 GB of memory.

## Testing

`check_llm()` in `tests/check_sim.gd` sets `llm.fake` (a function that answers requests) and
`llm.online = true`, and calls `llm.pump()` to deliver answers right away.
