# Money and jobs

Code: `scripts/jobs.gd` (tables at the top), with the character side in `npc.gd` (`update_work`,
`go_to_work`) and the Bus stop menu in `controller.gd`. Keep this file in sync with `jobs.gd`.

## Money

Everyone has `money` (in $). It's shown at the bottom left next to your household; it turns red below $0.

| Who | Starts with | Job |
|---|---|---|
| Jo (you) | $300 | none: get one at the Bus stop |
| Sam | $200 | Comedy club (Open-mic comic) |
| Alex | $400 | Restaurant (Line cook) |
| Riley | $600 | Office (Intern) |

**Money comes in** from shifts at work: hours worked × the hourly pay of your level, paid when the
shift ends ("You earned $87 at the Café", and a *Payday* moodlet: Happy).

**Money goes out** on:

| What | Cost |
|---|---|
| Cooking ingredients (paid at the Fridge, "Getting ingredients") | Sandwich $5, Salad $6, Omelette $4, Pasta $8 (2 servings), Soup $10 (3 servings) |
| Drinks | Water free (Sink), Juice/Milk/Soda $2, Coffee $1 |
| Bills | $80 per grown-up resident (Young adult and older), every Monday at 00:00 (`BILL`) |

Leftovers are free. You can't start what you can't afford: the menu shows "(can't afford)" and NPCs
don't choose it. Bills are taken even if you can't pay; **below $0 you feel *Broke*** (Tense) until
you're back above zero.

## Jobs

Jobs work like The Sims' rabbit holes. On a workday at the start time, the worker walks to their **home car**
(grown-ups with a job, if the car is home: `traffic.gd car_for`), gets in and drives off down the street; or to
the **Bus stop** (on the street, at (497,511): kids going to school, and anyone whose car is out). They disappear
to work and come back at the end time: by car, it drives back up the street and parks, and they get out
(`Jobs.working` waits for it; `traffic.gd parked_back` ends the shift). Clicking the Bus stop's "Go to work"
takes the car too when it's there.

| Job | Days | Hours | Skill | Level 1 | Level 2 | Level 3 |
|---|---|---|---|---|---|---|
| Café | Mon–Fri | 08:00–14:00 | Charisma | Barista $15/h | Shift lead $22/h (Charisma 2) | Café manager $32/h (Charisma 4) |
| Restaurant | Wed–Sun | 16:00–22:00 | Cooking | Line cook $18/h | Sous-chef $26/h (Cooking 4) | Head chef $40/h (Cooking 7) |
| Office | Mon–Fri | 09:00–17:00 | Logic | Intern $16/h | Analyst $28/h (Logic 3) | Manager $45/h (Logic 6) |
| Gym | Mon–Sat | 06:00–12:00 | Fitness | Assistant $14/h | Trainer $22/h (Fitness 3) | Head coach $34/h (Fitness 6) |
| Comedy club | Thu–Sun | 19:00–23:00 | Comedy | Open-mic comic $12/h | Opener $25/h (Comedy 4) | Headliner $50/h (Comedy 7) |

### Getting, quitting and going to work (you)

Click the **Bus stop**. Its menu lists every job ("Barista at the Café — $15/h, Mon–Fri
08:00–14:00 (Charisma)"), lets you **quit**, and has **Go to work now** during your work hours.
A job taken during its working hours starts the next workday.

* **Manual mode:** at the start of your shift you get one reminder ("Time for work! (click the Bus
  stop)") and the HUD shows *WORK TIME*. You have until 30 minutes before the end to go.
* **Auto mode:** you go by yourself, like the NPCs.
* **While you're at work** you can't be controlled, you're hidden, and time runs at **Ultra**
  automatically (like sleeping), dropping back to your speed when you're home.
* The top-left panel shows your job, pay, the next shift and your performance.

**Unemployed grown-up NPCs look for work** every morning: they take the job whose skill they're best
at (`find_work`). The person you control never gets a job they didn't choose.

NPCs always go to work by themselves. They drop whatever they're doing (except a conversation in
progress or knocking on a door).

### While at work

Needs keep dropping as usual, so you come home hungry and tired. You practise the job's skill at
a quarter of the normal rate (a full Office day ≈ 120 minutes of reading for Logic). Nobody can see
or talk to you.

### Getting fired

A shift that lowers your performance (a bad shift, or a missed one) and leaves it at **25% or
less** (`WARN_BELOW`) gets you a **warning**: *Warned at work* (Tense), and the HUD shows "WARNING:
one more bad shift and you're fired". The next one while warned and you're **fired**: no job,
performance back to 0, and *Fired* (Sad 3, 24 h). Getting back above 50% clears the warning.

### Who can work

Jobs are for **Young adults and older** (docs/LIFE.md). Teens and younger go to school instead
(Kindergarten, School, High school), which works the same way without pay. Young adults may enroll
in **College** at the Bus stop instead of a job; a degree makes later jobs start at level 2.

### Performance and promotions

Performance (0–100%) changes after every shift (mental states add to it: Thriving +4, Anxious −4,
Burned out −5, Depressed −6; see PEOPLE.md):

```
shift  = +10
       + 2 × your level in the job's skill
       + emotion at the end of the shift: Confident/Focused +8, Happy/Energized +5, Playful +3,
         Bored −2, Embarrassed −3, Sad/Tense/Uncomfortable −5, Angry −8
       − 10 if you arrived more than 30 minutes late
missed shift (not there by 30 min before the end) = −20, and a *Missed work* moodlet (Tense)
```

At **100%**, if your skill is high enough for the next level, you're **promoted**: new title, more
pay, performance back to 0, and a *Promoted* moodlet (Confident, 8 h). Without the skill you stay
at 100% until you learn it.

In a test week at Ultra speed, all three NPCs worked every shift and got their first promotion
(Sous-chef, Analyst, Opener), while an unemployed you went from $300 to $83 on food and bills.

## Moodlets

| Moodlet | Emotion | Strength | Lasts | When |
|---|---|---|---|---|
| Payday | Happy | 1 | 3 h | A shift ended |
| Promoted | Confident | 3 | 8 h | Promotion |
| Missed work | Tense | 2 | 4 h | Missed a shift |
| Warned at work | Tense | 2 | 8 h | A warning |
| Fired | Sad | 3 | 24 h | Fired |
| Broke | Tense | 2 | while < $0 | Money below zero |

## How to…

**Add a job:** a row in `JOBS` in `jobs.gd`: `skill`, `days` (0 = Monday), `start`/`end` hours
(same day), and `levels` as `[title, $ per hour, skill needed]`. It appears at the Bus stop
automatically. Add it to the table above.
**Give an NPC a job and money:** `.set_life(money, "Job")` after `setup()` in `main.gd`.
**Change prices:** `cost` in `RECIPES` / `DRINKS` (kitchen.gd); bills: `BILL` in jobs.gd.
