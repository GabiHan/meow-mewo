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

### Careers

Twenty more careers, listed at the Bus stop by **field** (hover one for its description). The key is the career;
`place` is where you go ("Registered nurse at the Clinic"). Healthcare uses **Medicine**, design and writing **Creativity**,
the hands-on jobs **Handiness** (new skills, practised at home: docs/PEOPLE.md "Skills").

| Career | Field | Workplace | Days | Hours | Skill | Level 1 | Level 2 | Level 3 | What it is |
|---|---|---|---|---|---|---|---|---|---|
| Nurse practitioner | Health and care | Clinic | Mon–Fri | 08:00–16:00 | Medicine | Registered nurse $24/h | Nurse practitioner $38/h (Medicine 3) | Lead nurse practitioner $52/h (Medicine 6) | Provides advanced primary and specialty healthcare. |
| Physician assistant | Health and care | Hospital | Tue–Sat | 07:00–15:00 | Medicine | PA trainee $22/h | Physician assistant $36/h (Medicine 3) | Senior physician assistant $50/h (Medicine 6) | Diagnoses illnesses, develops treatment plans, and assists in medical care. |
| Physical therapist assistant | Health and care | Rehab center | Mon–Fri | 09:00–17:00 | Fitness | Rehab aide $15/h | Physical therapist assistant $22/h (Fitness 2) | Senior PT assistant $30/h (Fitness 5) | Helps patients recover mobility and manage pain under a physical therapist. |
| Health services manager | Health and care | Hospital | Mon–Fri | 09:00–17:00 | Charisma | Unit coordinator $20/h | Health services manager $34/h (Charisma 3) | Hospital director $55/h (Charisma 6) | Plans and coordinates health services in hospitals or clinics. |
| Mental health counselor | Health and care | Counseling center | Mon–Fri | 10:00–18:00 | Charisma | Peer counselor $16/h | Mental health counselor $26/h (Charisma 3) | Clinical counselor $38/h (Charisma 6) | Supports individuals and groups with emotional and behavioral challenges. |
| Software developer | Tech | Tech company | Mon–Fri | 10:00–18:00 | Logic | Junior developer $24/h | Software developer $38/h (Logic 3) | Lead engineer $55/h (Logic 6) | Designs, builds, and maintains applications and software systems. |
| Data scientist | Tech | Tech company | Mon–Fri | 09:00–17:00 | Logic | Data analyst $22/h | Data scientist $36/h (Logic 4) | Principal data scientist $54/h (Logic 7) | Analyzes complex data sets to guide business and scientific decisions. |
| Information security analyst | Tech | Security firm | Sun–Thu | 08:00–16:00 | Logic | Security intern $18/h | Information security analyst $32/h (Logic 3) | Security architect $50/h (Logic 6) | Protects computer networks and data from cyber threats. |
| UX/UI designer | Creative | Design studio | Mon–Fri | 10:00–18:00 | Creativity | Junior designer $18/h | UX/UI designer $30/h (Creativity 3) | Design lead $45/h (Creativity 6) | Shapes how users interact with digital products and interfaces. |
| Operations research analyst | Business and finance | Logistics company | Mon–Fri | 08:00–16:00 | Logic | Junior analyst $19/h | Operations research analyst $31/h (Logic 4) | Head of operations research $46/h (Logic 7) | Uses math and analytics to solve logistics and operational problems. |
| Accountant | Business and finance | Accounting firm | Mon–Fri | 09:00–17:00 | Logic | Bookkeeper $16/h | Accountant $27/h (Logic 2) | Senior auditor $40/h (Logic 5) | Prepares and audits financial records for businesses and individuals. |
| Financial manager | Business and finance | Bank | Mon–Fri | 09:00–17:00 | Logic | Financial analyst $22/h | Financial manager $38/h (Logic 4) | Chief financial officer $60/h (Logic 7) | Oversees organizational budgets, investments, and financial strategy. |
| Civil engineer | Engineering and energy | Engineering firm | Mon–Fri | 08:00–16:00 | Logic | Engineering technician $19/h | Civil engineer $33/h (Logic 3) | Chief engineer $50/h (Logic 6) | Designs infrastructure such as roads, bridges, and water systems. |
| Solar PV installer | Engineering and energy | Solar company | Mon–Fri | 07:00–15:00 | Handiness | Installer helper $15/h | Solar PV installer $23/h (Handiness 2) | Installation lead $32/h (Handiness 5) | Assembles and maintains solar energy systems. |
| Wind turbine technician | Engineering and energy | Wind farm | Tue–Sat | 07:00–15:00 | Handiness | Trainee technician $17/h | Wind turbine technician $26/h (Handiness 3) | Site supervisor $36/h (Handiness 6) | Inspects, repairs, and maintains wind turbines. |
| Commercial pilot | Engineering and energy | Airfield | Thu–Mon | 06:00–14:00 | Handiness | Flight instructor $20/h | Commercial pilot $40/h (Handiness 4) | Captain $60/h (Handiness 7) | Flies aircraft for charter, cargo, or specialized operations. |
| Teacher | Education | School | Mon–Fri | 08:00–15:00 | Charisma | Teaching assistant $14/h | Teacher $24/h (Charisma 2) | Head teacher $36/h (Charisma 5) | Instructs students across early childhood, K–12, or higher education. |
| Graphic designer | Creative | Design studio | Mon–Fri | 09:00–17:00 | Creativity | Design intern $14/h | Graphic designer $24/h (Creativity 2) | Art director $40/h (Creativity 6) | Creates visual concepts for branding, print, and digital media. |
| Writer / editor | Creative | Publishing house | Mon–Thu | 10:00–16:00 | Creativity | Copywriter $14/h | Writer and editor $24/h (Creativity 3) | Editor-in-chief $40/h (Creativity 6) | Produces, refines, and manages content for books, media, or organizations. |
| Event planner | Creative | Event agency | Wed–Sun | 12:00–20:00 | Charisma | Event assistant $14/h | Event planner $24/h (Charisma 2) | Events director $38/h (Charisma 5) | Coordinates logistics, venues, and vendors for conferences, weddings, or gatherings. |

### Getting hired

Like in real life, most jobs only take you if you already have what they need: a **degree** (from College) and/or
a **skill level** (`degree` and `needs` in `JOBS`). The Bus stop greys out the ones you can't get yet and says what's
missing ("· needs a degree, Medicine 3 (you: 1)"); hover a job for its description and requirements. NPCs only
apply where they'd be hired. Barista, Intern, Gym assistant and Open-mic comic take anyone grown up, so everyone
can start somewhere and practise toward the rest.

| Job | Degree | Skills needed to be hired |
|---|---|---|
| Café, Office, Gym, Comedy club | – | – |
| Restaurant | – | Cooking 1 |
| Nurse practitioner, Physician assistant | ✓ | Medicine 3 |
| Physical therapist assistant | – | Fitness 2, Medicine 1 |
| Health services manager | ✓ | Charisma 2 |
| Mental health counselor | ✓ | Charisma 3 |
| Software developer, Information security analyst | – | Logic 3 |
| Data scientist | ✓ | Logic 4 |
| UX/UI designer | – | Creativity 2, Logic 1 |
| Operations research analyst, Civil engineer | ✓ | Logic 3 |
| Accountant | ✓ | Logic 2 |
| Financial manager | ✓ | Logic 3, Charisma 1 |
| Solar PV installer | – | Handiness 1 |
| Wind turbine technician | – | Handiness 2, Fitness 1 |
| Commercial pilot | – | Handiness 3, Logic 2 |
| Teacher | ✓ | Charisma 2 |
| Graphic designer, Writer / editor | – | Creativity 2 |
| Event planner | – | Charisma 2 |

A degree starts you one level up in jobs that don't require one; where a degree is required, it's what gets you in
(you start at level 1).

### Getting, quitting and going to work (you)

Click the **Bus stop**. Its menu lists every job by field ("Barista at the Café → Shift lead — $15/h, Mon–Fri
08:00–14:00 (Charisma)"; hover for what the job is), then College under *Study*, lets you **quit**, and has **Go to work now** during your work hours.
A job taken during its working hours starts the next workday.

* **Manual mode:** at the start of your shift you get one reminder ("Time for work! (click the Bus
  stop)") and the HUD shows *WORK TIME*. You have until 30 minutes before the end to go.
* **Auto mode:** you go by yourself, like the NPCs.
* **While you're at work** you can't be controlled, you're hidden, and time runs at **Ultra**
  automatically (like sleeping), dropping back to your speed when you're home.
* The top-left panel shows your job, pay, the next shift and your performance.

**Unemployed grown-up NPCs look for work** every morning: they take a job whose skill they're best
at (`find_work`); among equally good ones each person always picks the same one (by their name, no randomness). The person you control never gets a job they didn't choose.

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
Burned out −5, Depressed −6; a **Ruthless** person, dark traits put into their career, +3: see PEOPLE.md "The path"):

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

**Add a job:** a row in `JOBS` in `jobs.gd`: `degree`/`needs` (to be hired; leave out for anyone), `field` (Bus stop section), `place` (where; the key if missing),
`about`, `skill`, `days` (0 = Monday), `start`/`end` hours (same day), and `levels` as `[title, $ per hour, skill needed]`.
Texts say where with `Jobs.place(job)` / `Jobs.title_at(job, level)`, never the key itself. It appears at the Bus stop
automatically. Add it to the table above.
**Give an NPC a job and money:** `.set_life(money, "Job")` after `setup()` in `main.gd`.
**Change prices:** `cost` in `RECIPES` / `DRINKS` (kitchen.gd); bills: `BILL` in jobs.gd.
