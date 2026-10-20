# People: emotions, traits, memories, skills, social life

How characters behave like people. Code: `scripts/emotions.gd`, `traits.gd`, `skills.gd`,
`social.gd`, `perception.gd`, with the character itself in `npc.gd`. Keep this file in sync with
the tables at the top of those scripts.

Every character (NPCs and you) has:

| What | Where | Summary |
|---|---|---|
| Needs | `needs` | Hunger, thirst, energy, fun, bladder, hygiene, social (README, *Needs*) |
| Emotion | `moodlets` | What they feel right now and why |
| Traits | `traits` | Their personality |
| Skills | `skills` | What they're good at, levels 0–10 |
| Memories | `memories` | What others did to them |
| Relationships | `relationships` | Friendship −100…100 toward each person (one-directional) |

## The residents

Each person has a **look** (body, skin, hair, clothes; README *Character art*).

| Who | Age ([LIFE.md](LIFE.md)) | Lives | Traits | Starting skills | Money, job ([WORK.md](WORK.md)) |
|---|---|---|---|---|---|
| Jo (you) | F, 20 | Your house | none (you decide) | Cooking 2, Charisma 1 | $300, none |
| Sam (roommate) | M, 23 | Your house | Outgoing, Goofball, Slob | Comedy 3, Charisma 2 | $200, Comedy club |
| Alex | F, 38 | Alex's house | Hot-headed, Foodie, Neat | Cooking 5, Fitness 2 | $400, Restaurant |
| Mia (Alex's daughter) | F, 8 | Alex's house | Cheerful | Logic 1 | School |
| Lily (Alex's daughter) | F, 2.5 | Alex's house | Goofball | – | Kindergarten |
| Riley | M, 42 | Riley's house | Loner, Bookworm, Cheerful | Logic 4, Cooking 2 | $600, Office |
| Noah (Riley's son) | M, 15 | Riley's house | Active, Goofball | Fitness 2 | $20, High school |

---

## Emotions

Like The Sims 4, emotions come from **moodlets**: feelings with a reason and a duration, e.g.
*Argued* = Angry, strength 3, for 3 game hours. Strengths of the same emotion add up, and **the
emotion with the highest total is how the character feels**. With no moodlets they feel **Fine**,
and a total of 5 or more reads as "Very angry". Labels show `Name - Angry`; press F3 to see the
reasons, and the HUD shows yours.

### Moodlets

The body (body.gd, see *The body*): Tripped, Passed out, Fainted, Had an accident, Threw up, Grossed out,
Farted, Funny fart, Feeling better, Sick (while ill).

| Moodlet | Emotion | Strength | Lasts | Comes from |
|---|---|---|---|---|
| Good conversation | Happy | 1 | 3 h | Chat, compliment or comfort (given) |
| Had a laugh | Playful | 2 | 2 h | A joke that landed (both) |
| Joke fell flat | Embarrassed | 2 | 2 h | Your joke didn't land |
| Complimented | Confident | 2 | 3 h | Receiving a compliment |
| Deep connection | Happy | 2 | 4 h | Deep talk (both) |
| Interesting discussion | Focused | 2 | 2 h | Discuss ideas (both) |
| Hugged | Happy | 2 | 3 h | Hug (both) |
| Comforted | Happy | 2 | 3 h | Being comforted. **Removes Sad moodlets** |
| Argued | Angry | 3 | 3 h | Argument (both) |
| Insulted | Sad | 3 | 4 h | Being insulted |
| Rejected | Embarrassed | 2 | 2 h | Someone turned down your interaction |
| Caught a peeper | Angry | 3 | 3 h | Yelled at someone peeking in |
| Friend at the window | Happy | 1 | 1 h | Waved at someone peeking in |
| Got caught peeking | Embarrassed | 3 | 2 h | Someone stared or yelled at you peeking |
| Delicious meal | Happy | 2 | 4 h | Ate delicious food |
| Burnt food | Uncomfortable | 1 | 2 h | Ate burnt food |
| Stomach ache | Uncomfortable | 3 | 4 h | Ate spoiled food |
| Caffeinated | Energized | 2 | 3 h | Coffee |
| Well rested | Energized | 2 | 4 h | Slept in a bed |
| Freshened up | Happy | 1 | 2 h | Shower |
| Pumped | Energized | 2 | 2 h | Pull-up bar |
| Learned something | Focused | 2 | 2 h | Reading at a bookshelf |
| Skill level up | Confident | 2 | 4 h | Reaching a new skill level |
| Flirted / Kissed | Flirty | 2 / 3 | 3 h | Flirting / kissing (new emotion **Flirty**: +0.1 saying yes, flirts more, learns Charisma) |
| Cuddled / In love / Engaged / Just married | Happy | 2 / 3 / 3 / 4 | 3 h / 24 h / 24 h / 48 h | Romance steps |
| Broke up / Heartbroken | Sad | 2 / 4 | 24 h / 48 h | Ending a relationship (initiator / partner) |
| Jealous | Angry | 3 | 6 h | Saw their partner being romantic with someone else |
| In a relationship | Happy | 1 | while dating, engaged or married | |
| Made up, Vented, Gossiped, Showed off, Good advice, Got a gift, Played together, Story time, Teased, Pranked, Supported | various | 1–2 | 2–12 h | New interactions (table below) |
| Depressed / Anxious / Thriving / Isolated / Burned out | Sad / Tense / Happy / Sad / Tense | 4 / 3 / 2 / 2 / 2 | lasting | Mind (below) |

**Conditions** last as long as the situation does (rechecked twice a second):

| Moodlet | Emotion | Strength | When |
|---|---|---|---|
| Hungry | Uncomfortable | 2 | hunger < 25 |
| Thirsty | Uncomfortable | 2 | thirst < 25 |
| Exhausted | Tense | 3 | energy < 15 |
| Bursting | Uncomfortable | 3 | bladder < 20 |
| Smelly | Embarrassed | 2 | hygiene < 20 |
| Bored | Bored | 2 | fun < 25 |
| Lonely | Sad | 2 | social < 25 |
| Content | Happy | 1 | every need above 70 |
| Messy home | Uncomfortable | 1 | at home with 3+ dirty dishes lying around (Neat: 1+, Slob: never) |

### What emotions do

| Emotion | Saying yes to others | Starts more often | Cares more about | Learns faster |
|---|---|---|---|---|
| Happy | +0.10 | – | – | Cooking |
| Playful | +0.10 | Tell a joke ×3 | – | Comedy |
| Confident | +0.05 | Compliment ×2, Chat ×1.5 | – | Charisma |
| Energized | – | – | fun ×1.2 | Fitness |
| Focused | – | Discuss ideas ×3 | – | Logic |
| Sad | −0.10 | Deep talk ×2, Hug ×2 | social ×1.5 | – |
| Angry | −0.30 | Argue ×4, Insult ×3 | – | – |
| Tense | −0.15 | Argue ×2 | – | – |
| Embarrassed | −0.10 | – | social ×0.6 (wants to hide) | – |
| Uncomfortable | −0.10 | – | – | – |
| Bored | +0.05 | Tell a joke ×1.5 | fun ×1.5 | – |

Some interactions need a feeling: you can only **Argue** when Angry, Tense or Uncomfortable, only
**Insult** when Angry, and only **Comfort** someone who is **Sad**. "Learns faster" means ×1.5 xp
for that skill.

---

## The body (`body.gd`)

People are only human. Everything here also shows on the character (new sprite frames: running, bent over,
down on the floor) and in your chat feed.

| What | When | What happens |
|---|---|---|
| **Running** | A need under 15 (bladder, hunger, thirst), late for work, or you **Shift+click** where to go. Not toddlers, old people or anyone with the flu | ×1.8 speed with a running animation |
| **Tripping** | While running: 1.2% per tile (×2 under 25 energy, ×0.5 for Active people) | Flat on the floor for 3 min, *Tripped* (Embarrassed). Goofballs and hot-heads who see it laugh (*Had a laugh*), friends ask "Are you okay?!" |
| **Passing out** | Energy hits 0 when not in bed | Down on the floor for 2.5 h, sleeping it off (+35 energy), *Passed out* |
| **Fainting** | Hunger hits 0 | Down for 45 min, *Fainted*; wakes up at 12 hunger (go eat!) |
| **Accident** | Bladder hits 0 | Bladder 100, hygiene −50, *Had an accident* (Embarrassed 4); witnesses are *Grossed out* |
| **Farting** | About every 9 game hours (×0.4–1.6), twice as often for 3 h after a meal | Goofballs, slobs and children: *Funny fart*. Others: *Farted* (Embarrassed) if someone heard. People within 4 tiles laugh (goofballs, children) or are *Grossed out* |
| **Cold** | Hygiene under 20: 3% per game hour; or from someone sick close by | 30 h: energy ×1.3, speed ×0.9, "*achoo!*" every ~1.5 h |
| **Flu** | Only from someone who has it | 54 h: energy ×1.7, speed ×0.75, coughing; 25% of symptoms are throwing up; no running |
| **Food poisoning** | Eating stale (25%) or spoiled (85%) food | 12 h: energy ×1.4, speed ×0.85; 60% of symptoms are throwing up |
| **Throwing up** | A symptom of the flu or food poisoning | Bent over for 2 min: hunger −25, thirst −15, hygiene −25, *Threw up*; witnesses *Grossed out* |

While sick they feel *Sick* (Uncomfortable 3); sleeping makes illness pass twice as fast; when it's over:
*Feeling better*. Coughing and sneezing on someone within 3 tiles can pass it on (cold 12%, flu 15%).
While on the floor or bent over (`state` "down") they don't think, walk, talk or take orders.

## Mind: lasting mental states (`mind.gd`)

Moodlets last hours; the mind remembers days. Once per game hour it records how someone feels
(`mood_samples`, the last 48 hours). From that balance come lasting states, which stay until the
balance changes:

| State | Starts when | Lifts when | Feels | Effects |
|---|---|---|---|---|
| **Depressed** | ≥ 45% of the last hours were Sad (after a day of history) | < 20% Sad | Sad 4 | −0.15 saying yes; cares half as much about fun, less about people; tires ×1.2; work −6; learns ×0.7 |
| **Anxious** | ≥ 55% Tense or Uncomfortable | < 25% | Tense 3 | −0.1 saying yes; sleep restores ×0.75; work −4; learns ×0.85 |
| **Thriving** | ≥ 70% good feelings | < 40% | Happy 2 | +0.05 saying yes; work +4; learns ×1.2 |
| **Isolated** | no completed interaction for 48 h | after one | Sad 2 | wants company ×1.5 |
| **Burned out** | 26+ hours at work in 3 days | below that | Tense 2 | tires ×1.15; work −5; learns ×0.8 |

So grief, a break-up, money trouble or loneliness can tip someone into depression or anxiety, which
makes things harder (worse at work, less social), and good days, love and friends pull them out.
**Talk about feelings** (friendship ≥ 20, the partner is struggling or sad) gives them *Supported*
(Happy, 12 h) and makes their 12 worst recent hours count as good ones.

**Learning from experience:** after a hobby (TV, Bookshelf, Pull-up bar, Bench, cooking, socialising)
people note whether they felt good afterwards; their taste for it goes ±0.05 (between ×0.5 and ×1.6)
and multiplies how attractive it is next time. Being turned down makes socialising a bit less
attractive. Press F3 to see each NPC's mind and learned tastes.

---

## Romance (`romance.gd`)

Romance is separate from friendship: `romance` (−100…100, one-directional), plus a relationship
status shared by both people: **Dating → Engaged → Married**. Only between Young adults and older,
never family. Anyone can love anyone (babies still need a woman and a man).

* **Chemistry:** every pair of people has a fixed attraction from 0 to 1, the same both ways, so only
  some pairs click. The AI's wish for romance with someone is `8 × chemistry × 2 × (1 + romance/50)`
  (not need-based), and it fades for 4 hours after a romantic moment. Someone taken only wants their
  partner (others ×0.1).
* **Saying yes to romance:** `0.3 + their romance/100 + their friendship/300 + needs + (chemistry −
  0.5) × 0.4`, minus 0.5 if they're with someone else.
* **Jealousy:** if someone's partner is romantic with another person in front of them, they get
  *Jealous* (Angry 3, 6 h), romance −20, a bad memory, and they say so.
* **Marriage:** the partner moves into the initiator's home; on divorce they move back.
* **Babies:** *Try for a baby* works for partners, or close friends (70+).

---

## Traits

Each trait changes how fast needs drop, what someone enjoys, how they feel and what they learn.
Several traits combine by multiplying.

| Trait | Means | Effects |
|---|---|---|
| Outgoing | Loves company | social drops ×1.4; social activities ×1.3; +0.1 to say yes |
| Loner | Needs time alone | social drops ×0.6; social activities ×0.7; −0.1 to say yes |
| Cheerful | Usually happy | Happy moodlets ×1.5, Sad moodlets ×0.5 |
| Hot-headed | Quick to anger | Angry moodlets ×1.5; Argue/Insult ×2; −0.2 peeking reaction (yells more) |
| Goofball | Loves a joke | Playful ×1.3; Tell a joke ×2.5; Comedy xp ×1.5 |
| Foodie | Lives to eat | hunger drops ×1.2; cooking ×1.4; Cooking xp ×1.5 |
| Bookworm | Always reading | Bookshelf ×2; Logic xp ×1.5 |
| Active | Can't sit still | energy drops ×1.1; Pull-up bar ×2.5; Fitness xp ×1.5 |
| Lazy | Avoids effort | energy drops ×0.85; TV ×1.5; Pull-up bar ×0.3 |
| Neat | Hates mess | hygiene drops ×1.2; "Messy home" at 1 dirty dish |
| Slob | Doesn't mind mess | hygiene drops ×0.8; never "Messy home" |

"Activities ×n" multiplies the AI score of doing that thing. You see an NPC's traits in their
menu **once you've met them**.

---

## Memories

After every interaction both people remember it: `{who, text, feeling, when}` (last 30 kept).
The person it was done to remembers it more strongly (feeling = friendship change ÷ 5; an insult
is −3). Peeking, rejections and flat jokes are remembered too.

* **Grudges and soft spots:** the feelings from the last **3 game days** about someone add up
  (`recent_feeling`). That changes their chance of saying yes (×0.05 per point, −0.3…+0.1). With a
  grudge (below −2) they rarely choose nice interactions with that person.
* **Bringing it up:** in a Chat, Argue or Deep talk there's a 30% chance they mention a memory
  instead of a normal line: *"I haven't forgotten how you insulted me."* or *"Remember when you
  told me a joke? That was nice."*
* The NPC menu shows the last two things they remember about you.

---

## Social interactions

The initiator walks over, says a line out loud (in your chat feed if you're near), and the partner accepts
or not. Effects apply to both when it ends. The initiator practises the listed skill. A partner who is busy
(using something or on the way to it) isn't interrupted: they keep doing it while they talk (`busy_talk`,
npc.gd); someone asleep can't be talked to.

| Interaction | Needs | Social | Fun | Friendship | Minutes | Skill | Moodlets (initiator / partner) |
|---|---|---|---|---|---|---|---|
| Chat | – | +20 | 0 | +3 | 10 | Charisma | Good conversation / Good conversation |
| Tell a joke | friendship ≥ −20 | +15 | +15 | +5 | 5 | Comedy | Had a laugh / Had a laugh |
| Compliment | friendship ≥ 0 | +10 | +5 | +4 | 3 | Charisma | Good conversation / Complimented |
| Deep talk | friendship ≥ 30 | +35 | 0 | +8 | 20 | Charisma | Deep connection / Deep connection |
| Discuss ideas | Logic 3 | +20 | +10 | +4 | 15 | Logic | Interesting discussion / Interesting discussion |
| Hug | friendship ≥ 50 | +25 | +5 | +5 | 2 | – | Hugged / Hugged |
| Comfort | friendship ≥ 20, partner Sad | +25 | 0 | +6 | 10 | Charisma | Good conversation / Comforted |
| Argue | feeling Angry/Tense/Uncomfortable; can't be refused | +10 | −5 | −10 | 10 | – | Argued / Argued |
| Insult | feeling Angry; can't be refused | 0 | 0 | −15 | 2 | – | – / Insulted |
| Apologize | they hold a grudge against you | +10 | 0 | +5 | 5 | Charisma | Made up / Made up; **their recent bad memories of you are forgiven** |
| Talk about feelings | friendship ≥ 20; they're struggling (depressed, anxious, isolated, burned out) or Sad | +25 | 0 | +6 | 20 | Charisma | Good conversation / Supported |
| Gossip | teens+, friendship ≥ 10 | +20 | +10 | +4 | 10 | – | Gossiped / Gossiped |
| Brag | feeling Confident or Happy | +10 | 0 | 0 | 5 | – | Showed off / – |
| Vent | feeling Sad, Tense, Angry or Uncomfortable; friendship ≥ 10 | +20 | 0 | +3 | 10 | – | Vented (Happy; clears Tense and Angry moodlets) / – |
| Ask for advice | friendship ≥ 10 | +15 | 0 | +3 | 10 | – | Good advice (Focused) / – |
| High five | feeling Happy, Playful, Energized or Confident | +5 | +10 | +2 | 1 | – | Had a laugh / Had a laugh |
| Tease | feeling Playful or Happy; **can backfire** | +10 | +15 | +3 | 3 | – | Had a laugh / Had a laugh — or partner *Teased* (Angry), friendship −4 |
| Prank | feeling Playful; friendship ≥ 10; **can backfire** | +5 | +20 | +4 | 5 | Comedy | Had a laugh / Had a laugh — or partner *Pranked* (Angry 2), friendship −8 |
| Give a gift | $20; friendship ≥ 10 | +10 | +5 | +8 (romance +3) | 3 | – | – / Got a gift (Happy 2) |
| Play with | partner baby–child | +15 | +25 | +4 | 20 | – | Played together / Played together |
| Read a story | teens+, partner toddler or child | +15 | +15 | +4 | 15 | Logic | – / Story time |
| Feed, Change & clean, Rock to sleep | teens+, family/housemates of a baby or toddler | | | | | | see [LIFE.md](LIFE.md) |
| Flirt | romance rules; friendship ≥ 10 | +10 | +10 | +2 (romance +6) | 5 | Charisma | Flirted (Flirty) / Flirted |
| Kiss | romance ≥ 30, friendship ≥ 20 | +15 | +10 | +3 (romance +8) | 2 | – | Kissed (Flirty 3) / Kissed |
| Cuddle | romance ≥ 25, friendship ≥ 30 | +25 | +5 | +3 (romance +5) | 15 | – | Cuddled / Cuddled |
| Ask to be partners | romance ≥ 40, friendship ≥ 30, both single | +15 | +5 | +5 (romance +10) | 5 | – | In love / In love → **Dating** |
| Propose | dating, romance ≥ 70 | +20 | +10 | +5 (romance +10) | 5 | – | Engaged / Engaged → **Engaged** |
| Get married | engaged, at home together | +30 | +20 | +10 (romance +10) | 60 | – | Just married / Just married → **Married**, moves in |
| Break up | dating/engaged, and romance < 20 or feeling Angry/Sad/Tense; can't be refused | 0 | 0 | −20 (romance −40) | 5 | – | Broke up / Heartbroken |
| Divorce | married, and romance < 0 or feeling Angry; can't be refused | 0 | 0 | −25 (romance −40) | 10 | – | Broke up / Heartbroken; moves back out |

Teasing and pranks land with the same chance as jokes (50% + 5% per Comedy level). Big steps
(proposing, marrying, breaking up, babies) are weighted ×0.3 for the AI so they don't happen on a whim.
| Invite over | friendship ≥ 10; you have a home they don't live in and they're not invited yet | +10 | 0 | +3 | 3 | Charisma | Good conversation / Good conversation. **They may come into your home for 6 h** |
| Ask to leave | they're a guest in your home and you're there; can't be refused | 0 | 0 | −2 | 2 | – | – / –. **Their invitation ends and they walk out** |
| Try for a baby | friendship ≥ 70; fertile woman + man, Young adult+, not family, at home together (see [LIFE.md](LIFE.md)) | +30 | +25 | +5 | 30 | – | Deep connection / Deep connection. 40% chance of a pregnancy |

**Age limits** (see [LIFE.md](LIFE.md)): every interaction has a youngest stage for the initiator
and the partner (`a_min`/`b_min`). Babies can't start anything and can only be hugged; toddlers chat,
joke and hug; romance and hosting are for young adults and older.

* **Jokes can fall flat:** chance it lands = 50% + 5% per Comedy level. If it doesn't, friendship
  goes −2 both ways, the teller is Embarrassed, and the listener remembers the terrible joke.
* **Saying yes:**
  `chance = 0.55 + their friendship/200 + (their needs average − 50)/150 + their emotion
  + your Charisma × 0.03 + their traits + grudge`, limited to 5–95%. A rejection is −2 friendship
  both ways, you feel Rejected and they remember turning you down.
* **Friendship gains** are multiplied by the initiator's charisma: +5% per level.
* **Which one the AI picks:** weighted random by need value × emotion × traits (Angry people argue,
  Goofballs joke, Sad people want deep talks and hugs).

### Homes, knocking and invitations

See README, *Homes and invitations*. In short: you can only go into your own home or one you're
invited to. Knock on a door to ask (the resident decides by friendship, emotion, traits and grudges;
strangers are let in 10% of the time), or get an **Invite over**. Invitations last 6 game hours, and
a host can **Ask to leave**. When you're home in Manual mode, you answer your own door. Being turned
away makes the knocker feel Rejected, and the host remembers a visit (+0.5).

Interaction preferences for these: Outgoing → Invite over ×2, Happy → Invite over ×1.5;
Loner → Ask to leave ×3, Tense ×3, Angry ×2.

### Greetings

When an NPC sees someone they've met (perception, sight radius 10) for the first time in 3 game
hours, they say hello: *"Good morning, Sam!"*, *"Hi"*, *"Good evening"* or *"Hey"* at night.
Instead they **glare** at an enemy (friendship < −30), at someone they hold a big recent grudge
against (≤ −3), or at someone they have a bad recent memory of while they're Angry.

### Peeking reactions
See README, *Perception*. The score now also includes the NPC's emotion (its "saying yes" bonus)
and traits (Hot-headed −0.2). Being caught makes **you** Embarrassed, and they remember it
(stare −1, yell −3). A wave makes them happy and is a nice memory.

---

## Skills

Skills go from 0 to 10. You earn xp per game minute of practice. From level L to L+1 takes
**100 + 50 × L** xp, so level 1 is 100, level 2 is 250 in total, …, level 10 is 3,250.

| Skill | Practised by | xp / minute | Effect |
|---|---|---|---|
| Cooking | Making food (the Stove/Counter step) | 10 | Unlocks recipes: Omelette 1, Pasta 2, Soup 4. Quality: burnt chance 30% − 6%/level, delicious 5% + 8%/level (max 80%) |
| Charisma | Chat, Compliment, Deep talk, Comfort | 8 | Others say yes +3% per level; friendship gains +5% per level |
| Comedy | Telling jokes; watching TV | 8 | Jokes land 50% + 5% per level |
| Fitness | Pull-up bar (outside, next to the bench) | 6 | Walk 3% faster per level |
| Logic | Reading at a bookshelf; Discuss ideas | 4 | Unlocks Discuss ideas at level 3 |

xp is ×1.5 with a matching **trait** (Foodie → Cooking, Goofball → Comedy, Bookworm → Logic,
Active → Fitness) and ×1.5 with a matching **emotion** (table above). On a level-up the character
feels Confident, says *"Level up! Cooking 3"* and it goes in the social log.

**Food quality** (kitchen): every serving from one cooking session has the cook's quality.

| Quality | Hunger | Moodlet when eaten |
|---|---|---|
| Burnt | ×0.5 | Burnt food (Uncomfortable) |
| Good | ×1 | – |
| Delicious | ×1.25 | Delicious meal (Happy) |

### New objects for skills

| Object | Where | Gives | Minutes | Skill | Moodlet |
|---|---|---|---|---|---|
| Bookshelf ("Reading") | Every house (yours: upstairs) | fun +35 | 45 | Logic | Learned something |
| Pull-up bar ("Working out") | Outside at (503,516) | fun +15, energy −10, hygiene −10 | 30 | Fitness | Pumped |
| TV ("Watching TV") | Every house | fun +60 | 30 | Comedy | – |

---

## How to…

**Add a trait:** a row in `TRAITS` in `traits.gd` (any of the fields documented there), plus a row here.
**Add a moodlet:** a row in `MOODLETS` in `emotions.gd`; give it with `Emotions.add(character, "Name")`.
A condition moodlet has `hours: 0`; switch it with `Emotions.set_condition` or add it to `NEED_MOODLETS`.
**Add a skill:** a row in `SKILLS` in `skills.gd`; practise it with a step's `"skill"` (objects:
the `skill` extra in `OBJECTS`), or `character.practice(skill, minutes)`.
**Add an interaction:** a row in `INTERACTIONS` in `social.gd`, plus its memory text in `past_tense()`.
**Give an NPC a personality:** `Npc.new().setup(name, tile, color, home, [traits], {skill: level})` in `main.gd`.
