# Personality, hobbies and the criminal path — design

Date: 2026-11-16. Status: built straight away (the user prefers that I make the calls; they're marked *(my call)*).

## Intent
Build complex characters: personality (traits, including dark ones like psychopath and sociopath) and hobbies.
Evil depends on personality, so you can play a criminal; it depends on how you build them and how you play them.
**Not every "evil" personality becomes a criminal.**

## Design
1. **Traits** (traits.gd), in groups: Social, Lifestyle, Heart (Kind, Honest, Brave) and Dark (Psychopath,
   Sociopath, Narcissist, Manipulative, Cruel, Kleptomaniac). New fields: `group`, `dark` (how wicked, 0–3),
   `conscience` (how bad crimes feel afterwards, −3..+2), `conflicts`. Up to **4 traits** in the creator
   *(my call)*. Conflicting picks are refused. Born and growing-up kids get a dark trait rarely (`DARK_CHANCE`).
2. **Hobbies** (hobbies.gd, new): up to 2 per person (Reading, Fitness, Cooking, Films, Music, Gardening, Writing,
   Socialising). A hobby makes its activity more attractive, gives a *Hobby time* moodlet and faster skill xp.
   NPCs get 2 random hobbies.
3. **The path** (morals.gd, new, pure): `dark` from the traits, plus `pressure` from life (broke and jobless,
   angry or depressed, grudges, a criminal record), minus what holds them (Thriving, a good career, people close
   to them). It gives one of four paths:
   - **Criminal**: dark ≥ 2 and pressure ≥ `CRIMINAL_PRESSURE`;
   - **Ruthless**: dark ≥ 2 but channelled into a career that's going well (+performance at work);
   - **Mean**: some darkness, which shows as cruelty in how they treat people, not crime;
   - **Decent**: otherwise. Kleptomaniacs have urges whatever their path.
   The path is recalculated, never stored: lose your job, get angry and broke, and a ruthless psychopath can tip
   into crime; a good job can pull them back.
4. **Crimes** anyone Teen or older can commit (social interactions): Pickpocket, Manipulate (con money),
   Threaten (mug), Attack (knock down). Stealth is a new skill. **Breaking in** to a house: click its locked door →
   *Break in*. Pick the lock, then *Steal* (fenced at half price) and *Search for cash* inside. Residents who see
   you react with the same rules as with a burglar. The police chase you; caught means **arrested** (fine, criminal
   record, 2 days in jail, and you play someone else meanwhile, or just a fine if you're alone). NPCs only commit
   the crimes their path allows. After a crime: *Guilty* (a conscience), *Thrill* (no conscience) or *Uneasy*.
5. **Neighbourhood criminals**: when a burglar comes, if a resident is on the Criminal path, **it's them** behind
   the mask. Recognised by a witness who knows them; caught → jail and a criminal record.

## Non-goals *(my call)*
- You can't murder or kidnap as the player (Attack only knocks down). Abductors stay anonymous strangers.
- No courts or prison life: jail is being away for a few days.
- Pickpocketing never calls the police (only the victim's anger and memory).
