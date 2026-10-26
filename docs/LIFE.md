# Life: ages, growing up, schools, babies

Code: `scripts/ages.gd` (stages, years, fertility, family; no dependencies), `scripts/life.gd`
(ageing, pregnancy, births, families), schools in `scripts/jobs.gd`. Keep this file in sync.

## Life stages

Everyone has an age in game days (`age_days`) and a sex (`sex`: "F" or "M"). The stage comes from
the age. Each stage also maps to years, which is what the game shows ("Young adult, 20, female").

| Stage | Lasts (game days) | Years | Walks | Notes |
|---|---|---|---|---|
| Baby | 3 | 0–1 | can't | Stays where put, naps when tired; hunger/thirst/bladder/hygiene drop ×2 and must be cared for |
| Toddler | 7 | 1–4 | ×0.5 | Needs drop ×1.5 and must be cared for; sleeps (Crib), watches TV, chats, hugs; **Kindergarten** |
| Child | 14 | 4–13 | ×0.85 | Uses the kitchen but not the Stove or Coffee; **School** |
| Teen | 14 | 13–18 | ×1 | Cooks; no jobs, no babies; **High school**; answers the door |
| Young adult | 22 | 18–26 | ×1 | Jobs or optional **College**; can have babies |
| Adult | 30 | 26–61 | ×1 | Jobs; women can have babies until they turn Old (61) |
| Old | stays | 61+ | ×0.8 | Energy drops ×1.2; men can still father children |

**Ageing:** every new game day everyone gets one day older (`AGING_SPEED` in life.gd: 2.0 for a
short lifespan, 0.0 to turn ageing off). That's about 90 game days (≈ 36 real hours at 1x) from
birth to old age. Moving into a new stage gives a *Birthday* moodlet (Happy, 8 h), a "Happy
birthday!" emote and a log line. Children and teens gain a new random trait as they grow, up to 3.
Everyone has a natural lifespan, picked at birth between **78 and 96 years** (`DEATH_YEARS` in
life.gd); Old people keep ageing about a year per day past 90 until then. See *Death* below.

Bodies are drawn smaller for younger stages; babies are a bundle; old people have grey hair;
women have a hair bun; a pregnant woman has a bump.

## The residents

| Who | Sex | Age | Lives | Family | School / job |
|---|---|---|---|---|---|
| Jo (you) | F | 20 (Young adult) | Your house | – | none yet |
| Sam | M | 23 (Young adult) | Your house | – | Comedy club |
| Alex | F | 38 (Adult) | Alex's house | mother of Mia and Lily | Restaurant |
| Mia | F | 8 (Child) | Alex's house | Alex's daughter | School |
| Lily | F | 2.5 (Toddler) | Alex's house | Alex's daughter | Kindergarten |
| Riley | M | 42 (Adult) | Riley's house | father of Noah | Office |
| Noah | M | 15 (Teen) | Riley's house | Riley's son | High school |

Families start out knowing each other: parent ↔ child friendship 50, siblings 30. New beds: Mia's
Bed (499,502) and Lily's Crib (506,503) in Alex's house, Noah's Bed (493,521) in Riley's house.

## What each age may do

| | Baby | Toddler | Child | Teen | Young adult+ |
|---|---|---|---|---|---|
| Objects | – | Bed, Crib, TV | all | all | all |
| Kitchen | – (must be fed) | – (must be fed) | Counter recipes, cold drinks | all | all |
| Start interactions | – | Chat, Tell a joke, Hug | + Compliment, Comfort, Argue, Discuss ideas (Logic 3) | + Deep talk, Insult | + Invite over, Ask to leave, Try for a baby |
| Be the partner of | Hug, Play, care | most, care | most | all except romance | all |
| Answer the door | – | – | – | yes | yes |
| Jobs, bills | – | – | – | – | yes |

## Schools

Schools work like jobs (see WORK.md): on school days the pupil takes the bus at the start time
and comes back at the end. There's no pay; performance shows as a **grade**. Toddlers, children and
teens are enrolled automatically by stage; growing up moves them to the next school.

| School | Who | Days | Hours | Practises |
|---|---|---|---|---|
| Kindergarten | Toddlers | Mon–Fri | 09:00–12:00 | Charisma |
| School | Children | Mon–Fri | 08:00–14:00 | Logic |
| High school | Teens | Mon–Fri | 08:00–15:00 | Logic |
| College | Young adults (optional) | Mon–Thu | 10:00–15:00 | Logic |

* **Grades** come from performance (starts at 50): A ≥ 90, B ≥ 75, C ≥ 60, D ≥ 40, F below. Same
  shift formula as jobs (skill + emotion − lateness); skipping school costs 20 and gives *Skipped
  school* (Tense). Pupils can't be expelled.
* **College:** enroll at the Bus stop (Young adults without a degree; it replaces a job). After
  **14 attended days** you graduate: *Graduated* (Confident, 24 h), and **any job you take afterwards
  starts at level 2** (e.g. Analyst instead of Intern).
* Teens leave High school when they become Young adults.

## Babies

The **Try for a baby** interaction (30 minutes) is available only when:

* both are **Young adults or older**, a **woman and a man**, and both **fertile**: women are fertile
  as Young adults and Adults (**until they turn Old at 61**); men from Young adult on, **Old men too**;
* the initiator's friendship toward the partner is **70 or more**, and the partner accepts (normal
  acceptance rules);
* they're **at home together** (inside one of their homes);
* they're **not family** (parents, children, siblings), and she isn't already pregnant.

Each try has a **40%** chance (`BABY_CHANCE`). If it works, both feel *Expecting* (Happy) and it's
logged. The pregnancy lasts **3 game days** (`PREGNANCY_DAYS`): she's *Pregnant* (Uncomfortable 1)
and her energy drops ×1.3. Then the baby is **born in the mother's home**: a random name and sex,
one random trait, parents recorded, and parents ↔ baby friendship 50. Parents feel *New baby*
(Happy 3, 24 h). The NPCs try rarely (the AI weights it ×0.3).

Jo is a female Young adult, so she can have a baby with a man she's close to (friendship 70+) or
her partner (romance), at home.

## Caring for babies and toddlers

They can't look after themselves. Their hunger, thirst, bladder and hygiene drop faster (babies ×2,
toddlers ×1.5). When **any need drops below 20 they cry** (*Crying*, Sad 3, and "Waaah!"), and
older people in the same house who see it get *Baby crying* (Tense). Babies nap where they are
when tired (4 hours). Care interactions (teens and older who live with them, or their parents):

| Care | Gives the little one | Minutes |
|---|---|---|
| Feed | hunger +70, thirst +50; *Fed* (Happy) | 10 |
| Change & clean | bladder full, hygiene +80; *Clean and dry* (Happy) | 10 |
| Rock to sleep | energy +60 | 20 |
| Play with (children too) | fun +25, social +15; *Played together* (Playful) | 20 |
| Read a story (teens+, to toddlers and children) | fun +15, social +15; *Story time* (Happy) | 15 |
| Hug | social +25 | 2 |

NPC carers decide by the little one's needs: the score is the baby's need value × 2 (× 1.5 more
for parents), so a hungry baby gets fed first. **Click a baby or toddler** (or their name in the
household bar) to see their needs in a panel from the left, with these care buttons.

## Death

When someone reaches their lifespan (checked each new day) they **pass away**: it's logged ("Riley
passed away at 87"), they disappear, and a **grave** ("Grave of Riley") appears near their home's
door. Family and partners feel *Grieving* (Sad 4, 72 h), friends (friendship ≥ 20) *Lost someone*
(Sad 2, 48 h), and a partner is single again. Grief can turn into depression (mind.gd). If it's the
person you control, you carry on as someone else in your household: no game over.

## Moodlets

| Moodlet | Emotion | Strength | Lasts |
|---|---|---|---|
| Birthday | Happy | 2 | 8 h |
| Expecting | Happy | 2 | 24 h |
| Pregnant | Uncomfortable | 1 | while pregnant |
| New baby | Happy | 3 | 24 h |
| Skipped school | Tense | 1 | 4 h |
| Crying (babies/toddlers) | Sad | 3 | while a need < 20 |
| Baby crying (housemates) | Tense | 1 | 1 h |
| Fed / Clean and dry | Happy | 1 | 1 h |
| Grieving | Sad | 4 | 72 h |
| Lost someone | Sad | 2 | 48 h |
| Graduated | Confident | 3 | 24 h |

## How to…

**Add a person with an age:** `Npc.new().setup(...).set_life(money, job).set_age("F", years, ["Parent"])`
in `main.gd`. Toddlers, children and teens are enrolled in their school automatically.
**Change lifespans:** `days` per stage in `STAGES` (ages.gd), or `AGING_SPEED` (life.gd).
**Change who may do what:** `a_min`/`b_min` on interactions (social.gd), `Kitchen.allowed`,
`npc.may_use`, `Ages.EFFECTS` (speed and cared-for needs).
