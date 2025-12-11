# Colony Sim: Events Catalog

Events are the heart of the Colony Sim experience. They create stories, force decisions, and make each playthrough unique.

---

## Event Design Philosophy

### The "Interesting Decision" Test
Every event with choices must pass Sid Meier's test: is this an interesting decision? If one choice is obviously correct, redesign the event.

### The "Story Factory" Principle
Events should create stories, not just modify stats. Players should want to tell others what happened.

### The "Callback" Rule
Great events reference past decisions. "Remember when you chose to ration water? Well, the colonists remember too."

### The "No Pure RNG" Rule
Random events must give players agency. Even bad luck should offer choices about how to respond.

---

## Event Categories

### 1. SURVIVAL EVENTS
Life-or-death situations affecting the colony's physical existence.

### 2. SOCIAL EVENTS
Interpersonal drama, relationships, community dynamics.

### 3. POLITICAL EVENTS
Governance, factions, power struggles.

### 4. GENERATIONAL EVENTS
Birth, death, coming-of-age, legacy.

### 5. DISCOVERY EVENTS
Scientific findings, exploration, mysteries.

### 6. EARTH EVENTS
Communications, supplies, political pressure from home.

### 7. QUIET MOMENTS
Character-building scenes without immediate stakes.

---

## ACT 1 EVENTS (Years 1-5)
*"The Desperate Years"*

### SURVIVAL EVENTS - ACT 1

---

**EVENT: first_winter**

TITLE: The Long Night

TRIGGER:
- Year 1, Month 6
- Automatic (first playthrough teaches winter mechanics)

DESCRIPTION:
Mars winter is here. Dust storms are common, solar power drops 40%, and the temperature plummets. This will last 4 months.

Chief Engineer [Founder] has prepared a survival plan, but resources are tight.

CHOICES:
A) Follow the survival plan strictly
   → Power rationing, limited EVA
   → Safe but slow progress
   → Crew morale -10%

B) Push through with normal operations
   → Risk equipment failures
   → Maintain productivity
   → 30% chance of emergency event

C) Use this time for indoor projects
   → Accelerate research/training
   → Reduced resource consumption
   → Morale +5% (sense of purpose)

FOLLOW-UP:
- If B chosen and emergency triggers → EVENT: winter_emergency

---

**EVENT: equipment_cascade**

TITLE: Cascade Failure

TRIGGER:
- Year 1-3
- Any critical system below 60% condition
- 25% chance per year

DESCRIPTION:
[System] has failed, and it's causing problems with connected systems. The original ship components are showing their age.

CHOICES:
A) Emergency repair (all hands)
   → 2 weeks, all other work stops
   → System restored to 70%
   → No lasting damage

B) Jury-rig a workaround
   → 3 days, minimal disruption
   → System at 50% permanently
   → Risk of future cascade

C) Cannibalize from backup systems
   → 1 week, some disruption
   → System restored to 80%
   → Lose redundancy (future events more dangerous)

---

**EVENT: food_crisis_early**

TITLE: The Hungry Month

TRIGGER:
- Year 1-3
- Food reserves below 45 days
- Automatic

DESCRIPTION:
Food supplies are critically low. The greenhouse isn't producing enough yet, and the next supply ship is months away.

Rationing is necessary. The question is how severe.

CHOICES:
A) Light rationing (80% rations)
   → Extends supplies 25%
   → Morale -5%
   → Minor health impact

B) Severe rationing (60% rations)
   → Extends supplies 40%
   → Morale -15%
   → Health -10 over time

C) Prioritize workers (differential rations)
   → Workers get 100%, others get 60%
   → Morale -20% for non-workers
   → Productivity maintained
   → Faction: "Workers' Rights" forms if chosen multiple times

D) Slaughter the backup seed stock
   → Immediate food boost
   → No food crisis THIS time
   → Long-term food production -30% permanently

---

### SOCIAL EVENTS - ACT 1

---

**EVENT: first_conflict**

TITLE: The Argument

TRIGGER:
- Year 1-2
- 2+ founders with relationship < 40
- First conflict event

DESCRIPTION:
[Founder A] and [Founder B] are arguing loudly in the common area. It started over [random: work schedules / resource use / personal space] but has escalated into something deeper.

Other founders are watching. This is the first real conflict since landing.

CHOICES:
A) Mediate immediately
   → Skill check: Leadership
   → Success: Both +10 relationship, you +respect
   → Failure: Both -10 morale, you -respect

B) Let them work it out
   → 50% they resolve it (natural healing)
   → 50% it festers (relationship -20, future event)

C) Side with [Founder A]
   → A: +20 relationship with you
   → B: -30 relationship with you
   → Colony learns you pick sides

D) Separate them (assign different shifts)
   → Conflict suppressed
   → No relationship change
   → Productivity -10% (inefficient scheduling)

CALLBACK:
This event is referenced in future conflicts: "Remember how you handled the first argument?"

---

**EVENT: first_romance**

TITLE: Found in Translation

TRIGGER:
- Year 1-3
- 2 founders with relationship > 70, compatible traits
- Neither in existing relationship

DESCRIPTION:
You've noticed [Founder A] and [Founder B] spending more time together. The way they look at each other... it's clear something is developing.

In a colony this small, personal relationships affect everyone.

CHOICES:
A) Encourage the relationship
   → Both: +15 morale
   → Risk: If it ends badly, double morale penalty
   → Sets precedent for colony attitudes toward relationships

B) Discourage romantic relationships (professional atmosphere)
   → Both: -10 morale
   → Colony policy established: Relationships discouraged
   → May cause resentment long-term

C) Stay out of it (no official position)
   → No immediate effect
   → Relationship develops naturally
   → Others will make their own choices

FOLLOW-UP:
- If A or C → EVENT: relationship_milestone (wedding proposal possible)
- If B → EVENT: forbidden_romance (years later)

---

**EVENT: founder_homesickness**

TITLE: Looking at Earth

TRIGGER:
- Year 1-2
- Any founder with morale < 40
- Not during crisis

DESCRIPTION:
You find [Founder] at the observation window during night cycle, staring at a bright dot in the sky. Earth.

"I knew I'd never go back," they say quietly. "But knowing it and feeling it..."

CHOICES:
A) "Tell me about what you miss."
   → Long conversation about Earth
   → Founder +15 morale
   → You learn backstory detail (affects future events)
   → Time cost: 2 hours

B) "We're building something new here."
   → Inspirational speech
   → Founder +5 morale OR +10 if they have "optimist" trait
   → Generic but quick

C) "I miss it too."
   → Shared vulnerability
   → Founder +10 morale, +15 trust with you
   → Your morale -5 (admitting weakness)

D) [Say nothing, just stand with them]
   → Silent companionship
   → Founder +20 relationship with you
   → No dialogue, pure moment

QUIET MOMENT: This event has no wrong answer. All choices are valid.

---

### GENERATIONAL EVENTS - ACT 1

---

**EVENT: first_pregnancy**

TITLE: Two Heartbeats

TRIGGER:
- Year 2-5
- Any coupled founders
- Medical facility exists
- 15% chance per year per couple

DESCRIPTION:
[Founder] approaches you privately. She's pregnant. The first pregnancy in human history on another planet.

The medical bay isn't designed for obstetrics. Earth is too far for emergency consultation. Everything about this is unprecedented.

CHOICES:
A) Announce it to the colony
   → Colony morale +25 (hope for the future!)
   → Pressure on expectant parents (+stress)
   → Earth will want updates (media attention)

B) Keep it quiet until second trimester
   → Private matter respected
   → Avoids pressure if something goes wrong
   → Colony morale +15 when eventually announced

C) Express concern about the risks
   → Honest about medical limitations
   → Parents -10 morale (scared)
   → Medical team on high alert (+5% success chance)

FOLLOW-UP:
- Triggers EVENT: pregnancy_complications (20% chance)
- Triggers EVENT: first_birth (9 months later)

---

**EVENT: first_birth**

TITLE: A New World's First Citizen

TRIGGER:
- 9 months after first_pregnancy
- Automatic

DESCRIPTION:
After 14 hours of labor, [Mother] has given birth to a healthy baby [boy/girl]. The first human born on Mars.

The entire colony has gathered outside the medical bay. When the cry comes, everyone cheers.

This moment will be in history books.

CHOICES:
A) Name the child [Player's choice]
   → Player inputs name
   → Child becomes named character in game
   → High investment, high stakes if child dies later

B) Let the parents choose
   → Procedurally generated name
   → Parents +10 relationship with you (respect for privacy)
   → Slightly less player attachment

C) Hold a colony-wide naming vote
   → Democratic tradition established
   → Process takes 1 week
   → Child named by majority vote
   → Sets precedent for future decisions

EFFECTS:
- Colony morale +30
- "First Birth" achievement
- Child added to population (baby stage)
- Historical event logged
- Earth celebrates (faction standing +5 with all factions)

---

**EVENT: first_death**

TITLE: The First to Fall

TRIGGER:
- Year 1-5
- Any founder health reaches 0
- Or accident/illness kills a founder

DESCRIPTION:
[Founder] is dead.

[Cause of death: accident / illness / equipment failure / age (if old) / sacrifice (if during crisis)]

The colony has lost its first member. In the cramped quarters, surrounded by the Martian void, death feels very close.

CHOICES:
A) Full funeral ceremony (establish traditions)
   → 1 day of mourning, no work
   → Colony morale: -20 immediately, then +10 (closure)
   → "Funeral tradition" established
   → You choose: burial plot or cremation?

B) Brief memorial (mission continues)
   → 2 hours ceremony
   → Colony morale: -15 (feels insufficient)
   → Some crew may resent brevity

C) Let the crew decide how to handle it
   → Crew votes on ceremony
   → Democratic, but you appear weak
   → Outcome varies by crew composition

LASTING EFFECTS:
- "Memorial" location added to colony map
- Dead founder becomes "Founding Saint" in later culture events
- Surviving crew reference the death in future quiet moments

---

### EARTH EVENTS - ACT 1

---

**EVENT: first_supply_ship**

TITLE: Care Package from Home

TRIGGER:
- Year 2
- Automatic

DESCRIPTION:
The first supply ship since landing has entered Mars orbit. Contents: 2 tons of supplies, equipment, medicine, and 4 new colonists.

Earth wants to know what you need most for the next shipment.

CHOICES:
A) Request more colonists
   → +8 new colonists next ship
   → Faster growth, but strain on resources
   → Immigration faction strengthens

B) Request more equipment
   → Advanced manufacturing or medical equipment
   → Slower population growth
   → Better infrastructure

C) Request luxury items
   → Comfort goods, entertainment, personal items
   → Morale +20 when they arrive
   → Earth factions criticize "wasteful spending"

D) Request autonomy (reduce Earth oversight)
   → Fewer specific supplies
   → More general resources, your choice how to use
   → Earth factions: -10 standing
   → Independence path begins

---

**EVENT: earth_media_request**

TITLE: The Documentary Question

TRIGGER:
- Year 1-3
- After first_supply_ship
- 30% chance

DESCRIPTION:
Earth media wants unprecedented access. A documentary team wants to embed with the colony for 2 years. They'll broadcast everything—successes and failures.

The publicity could boost Earth support... or expose your struggles.

CHOICES:
A) Full access
   → Earth Public Opinion: +20 over time
   → All future events are "public" - failures hurt more
   → Morale boost from attention
   → Risk: Scandals have bigger impact

B) Curated access (you approve what's broadcast)
   → Public Opinion: +10
   → You control narrative
   → May be caught "editing" truth (scandal risk)

C) Decline
   → Public Opinion: -5 (hiding something?)
   → Complete privacy
   → Future media requests continue

---

## ACT 2 EVENTS (Years 6-20)
*"The Settlement Years"*

### POLITICAL EVENTS - ACT 2

---

**EVENT: council_formation**

TITLE: The Voice of the People

TRIGGER:
- Year 6-10
- Population > 25
- Automatic (political evolution)

DESCRIPTION:
The colony has grown beyond the founding crew. New colonists want representation. Several factions are emerging.

[Earther] argues for strong ties to Earth mission control.
[Founder Loyalist] wants to preserve the original mission values.
[Martian Nationalist] (if any Mars-born are adults) wants self-determination.

It's time to decide how decisions get made.

CHOICES:
A) Establish an advisory council (you retain authority)
   → Council of 5, elected by colonists
   → They advise, you decide
   → Gradual legitimacy
   → Your authority: Strong but questioned

B) Establish a governing council (shared power)
   → Council votes on major decisions
   → You have veto power
   → Faster political evolution
   → Your authority: Reduced but stable

C) Resist formalization (maintain founder rule)
   → "The original crew knows best"
   → Founder morale +10
   → Non-founder morale -15
   → Tension builds (future events more severe)

D) Full democracy immediately
   → Elected council with full power
   → You become one voice among many
   → Your authority: None (but you're popular)
   → Risk: Inexperienced governance

FOLLOW-UP:
- Sets political_system variable for all future events
- Triggers first_election in 2 years if council established

---

**EVENT: first_election**

TITLE: Democracy on Mars

TRIGGER:
- Year 8-12
- After council_formation (if A, B, or D chosen)
- Automatic

DESCRIPTION:
The first election on Mars. Three candidates have emerged:

[Candidate A] - [Faction: Earther] - Platform: Strong Earth ties, steady growth
[Candidate B] - [Faction: Founder] - Platform: Mission values, science priority
[Candidate C] - [Faction: Martian] - Platform: Self-sufficiency, independence path

Campaigning has been... intense.

CHOICES:
A) Endorse [Candidate A]
   → [A] likely wins
   → You gain influence with their faction
   → You lose influence with other factions
   → "Commander plays favorites" perception

B) Endorse [Candidate B]
   → Same as A, different faction

C) Endorse [Candidate C]
   → Same as A, different faction

D) Remain neutral
   → Election outcome based on colony composition
   → You maintain standing with all factions
   → Less influence over outcome
   → "Leader above politics" reputation

EFFECTS:
- Winner's faction gains +10 influence
- Winner's policies affect next 4 years
- Political traditions established

---

**EVENT: first_strike**

TITLE: Tools Down

TRIGGER:
- Year 10-20
- Worker morale < 40 OR unfair policy active for 3+ years
- Population > 50

DESCRIPTION:
A group of 15 workers has stopped working. They're gathered in the common area, refusing to return to their posts.

Their demands:
1. Better working conditions (shorter shifts)
2. More say in resource allocation
3. Recognition of a "Workers' Council"

Life support is still running, but food production and construction have halted.

CHOICES:
A) Negotiate in good faith
   → Meet with leaders, discuss demands
   → Takes 1 week
   → Likely compromise (some demands met)
   → Workers' faction gains legitimacy

B) Meet demands immediately
   → Strike ends instantly
   → Workers +30 morale
   → Other factions see you as weak
   → Encourages future demands

C) Refuse to negotiate (wait them out)
   → Strike continues
   → Each week: production loss, morale loss across colony
   → 50% chance workers give up
   → 50% chance escalation (sabotage, violence)

D) Arrest the leaders
   → Strike ends through force
   → Workers -40 morale
   → "Authoritarian" tag added to your leadership
   → Radicalization risk (underground movement)

FOLLOW-UP:
- If negotiated → EVENT: labor_agreement (establishes workers' rights)
- If arrested → EVENT: resistance_movement (years later)

---

### GENERATIONAL EVENTS - ACT 2

---

**EVENT: first_generation_comes_of_age**

TITLE: Children of Mars

TRIGGER:
- Year 18-22
- First Mars-born child reaches 18
- Automatic

DESCRIPTION:
[First Mars-Born], the first human born on Mars, has reached adulthood. They've never seen Earth except in pictures. Mars is the only home they've ever known.

The colony gathers to celebrate. But it's also a moment of reflection—what does it mean to be Martian?

CHOICES:
A) Grand ceremony (establish Coming of Age tradition)
   → Colony-wide celebration
   → [First Mars-Born] becomes symbol
   → Cultural tradition established
   → Morale +20

B) Quiet recognition (avoid singling out)
   → Personal ceremony with family
   → [First Mars-Born] appreciates normalcy
   → Less pressure on future Mars-born

C) Use the moment politically
   → Speech about Mars independence
   → Independence faction +20
   → Earth factions -10
   → [First Mars-Born] may resent being used

EFFECTS:
- [First Mars-Born] gets adult skills, enters workforce
- Cultural flag: "First Generation Adult"
- Unlocks: Mars-born can now hold political positions

---

**EVENT: founder_aging**

TITLE: The Weight of Years

TRIGGER:
- Year 15-25
- Any original founder reaches 60+
- Not in crisis

DESCRIPTION:
[Oldest Founder] has been reflecting on their age. In the low Martian gravity, they've stayed healthier longer than expected, but time catches everyone.

They want to discuss succession—who will carry on their knowledge?

CHOICES:
A) Formal apprenticeship program
   → [Founder] trains designated successor
   → Knowledge transfer +50%
   → Successor gets bonus skills
   → [Founder] feels useful (+10 morale)

B) Documentation project
   → [Founder] writes down everything they know
   → Creates "Founder's Manual" - colony asset
   → Can be accessed by anyone
   → Less personal connection

C) "You've still got years left"
   → Reassure them
   → [Founder] +5 morale
   → Knowledge transfer happens informally
   → Risk: Sudden death = knowledge lost

FOLLOW-UP:
- If A chosen, successor character gains "Founder's Heir" trait
- Triggers EVENT: founder_death (years later)

---

**EVENT: founder_death**

TITLE: Passing of the Torch

TRIGGER:
- Year 20-40
- Original founder reaches 70+ OR health < 20
- May be triggered by illness event

DESCRIPTION:
[Founder] is dying. The colony's [specialty] expert, one of the original eight, has reached the end.

They've asked to see you.

SCENE:
[Founder] lies in the medical bay. Their breathing is shallow.

"We made it," they say. "A hundred people on Mars. [If applicable: My grandchildren will grow up here.] That's something."

"I need you to promise me something..."

CHOICES:
A) "Anything."
   → [Founder] makes specific request based on their personality
   → e.g., "Don't let them forget why we came here"
   → e.g., "Take care of my family"
   → e.g., "Keep reaching for the stars"
   → Creates "Founder's Promise" - affects future events

B) "You've earned your rest."
   → Peaceful acceptance
   → [Founder] dies at peace
   → No specific legacy commitment

C) "I wish you could see what comes next."
   → Future-focused
   → [Founder] dies hopeful
   → Morale boost for you

EFFECTS:
- Colony mourns (morale -15, then recovery)
- Funeral event (if traditions established)
- [Founder] added to "Honored Dead" list
- Memorial event on anniversary
- Their descendents get "Founder's Blood" trait

---

### SOCIAL EVENTS - ACT 2

---

**EVENT: immigration_clash**

TITLE: New Blood, Old Tensions

TRIGGER:
- Year 8-15
- After major immigration wave (10+ new colonists at once)
- Original founders < 50% of population

DESCRIPTION:
Tensions are rising between the "old guard" (founders and early settlers) and the "newcomers" (recent immigrants from Earth).

The newcomers brought different expectations. They didn't sign up for frontier hardship—they expected a functioning colony. They want changes.

The founders feel their sacrifice is being dismissed. They built this. They bled for this.

CHOICES:
A) Side with the founders ("They earned their place")
   → Founders: +20 morale
   → Newcomers: -20 morale
   → Integration slows
   → "Old guard privilege" established

B) Side with the newcomers ("Fresh perspectives help us grow")
   → Newcomers: +20 morale
   → Founders: -20 morale
   → Founders may form resistance faction
   → Integration accelerates

C) Bridge-building program
   → Pair founders with newcomers in work teams
   → Mixed results initially
   → Long-term integration success
   → Takes 2 years to see results

D) Segregate to avoid conflict
   → Separate living/working areas
   → Peace through distance
   → Two distinct cultures emerge
   → Future unification events more difficult

---

**EVENT: forbidden_romance**

TITLE: Hearts in Conflict

TRIGGER:
- Year 10-20
- Two characters from opposed factions with relationship > 80
- If "professional atmosphere" policy is active, trigger is more likely

DESCRIPTION:
[Character A] from the [Faction A] faction and [Character B] from the [Faction B] faction have fallen in love. Their families—and factions—are not pleased.

They've come to you, asking you to perform a wedding ceremony despite the opposition.

CHOICES:
A) Perform the wedding (love conquers all)
   → Both factions: -10 standing (defied their wishes)
   → Couple: Maximum loyalty to you
   → Colony morale +10 (romantic story)
   → Sets precedent: Love > faction politics

B) Refuse (respect faction wishes)
   → Both factions: +5 standing
   → Couple: -30 relationship with you
   → May marry anyway, secretly
   → May leave colony together

C) Mediate between factions first
   → Delay wedding for 6 months
   → Negotiation attempts
   → 50% success: Wedding with blessing
   → 50% failure: Factions refuse, back to A or B

D) Suggest they wait until tensions ease
   → No immediate action
   → Relationship may survive or fail over time
   → No political fallout now

CALLBACK:
Years later: Their children become symbols of unity... or cautionary tales.

---

## ACT 3 EVENTS (Years 21-50)
*"The Colony Years"*

### POLITICAL EVENTS - ACT 3

---

**EVENT: independence_question**

TITLE: A Fork in the Road

TRIGGER:
- Year 25-40
- Colony self-sufficiency > 80%
- Population > 200
- Automatic (major story event)

DESCRIPTION:
The colony no longer needs Earth to survive. You could, if you chose, cut ties entirely. Some say you should.

The Independence Faction has called for a referendum. After heated debate, it's been scheduled for next year.

The question: Should Mars seek political independence from Earth?

This will define the colony's future.

EFFECTS:
- Year of campaigning begins
- EVENT: independence_campaign_a (Earther perspective)
- EVENT: independence_campaign_b (Independence perspective)
- EVENT: independence_vote (one year later)

---

**EVENT: independence_vote**

TITLE: The Declaration

TRIGGER:
- One year after independence_question
- Automatic

DESCRIPTION:
Today, the colony votes on independence.

The arguments have been made. The debates are over. Now it's in the colonists' hands.

Current polling shows:
- Independence: [X]%
- Remain with Earth: [Y]%
- Undecided: [Z]%

Your stance matters. The colonists are watching.

CHOICES:
A) Publicly support independence
   → Independence +15% in vote
   → Earth factions: Relationship -30
   → You become symbol of independence movement

B) Publicly support remaining with Earth
   → Remain +15% in vote
   → Mars nationalist factions: Relationship -30
   → You become symbol of Earth loyalty

C) Call for unity regardless of outcome
   → No vote modifier
   → Respected by both sides
   → "Unifier" reputation
   → Post-vote healing easier

D) Abstain (let the people decide)
   → No vote modifier
   → Some see this as leadership
   → Some see this as cowardice
   → Outcome purely reflects colony composition

OUTCOMES:
- If Independence wins: EVENT: independence_declaration
- If Remain wins: EVENT: renewed_partnership
- If close vote (within 5%): EVENT: divided_colony

---

**EVENT: independence_declaration**

TITLE: A New Nation

TRIGGER:
- independence_vote outcome: Independence wins

DESCRIPTION:
By a vote of [X] to [Y], the colony has chosen independence.

You stand at the central plaza, the Martian flag (designed by the art committee) flying overhead. Cameras broadcast to Earth—with a 14-minute delay.

The declaration is read aloud:

*"We, the people of Mars, in recognition of our unique circumstances and our right to self-determination, do hereby declare ourselves a free and independent nation..."*

Earth's response will arrive in 28 minutes.

CHOICES:
A) Sign the declaration (full commitment)
   → You become first leader of independent Mars
   → Earth relationship: SEVERED (for now)
   → Some colonists who opposed may leave on next ship

B) Sign but extend olive branch to Earth
   → Offer continued cooperation, trade, communication
   → Earth relationship: STRAINED but not severed
   → Independence faction slightly disappointed

C) Refuse to sign (despite vote)
   → Constitutional crisis
   → Your authority challenged
   → May be removed from power
   → Civil unrest likely

EFFECTS:
- Game enters "Independence" mode
- Earth supplies end (unless B chosen)
- New political events unlock
- Achievement: "A New Nation"

---

### DISCOVERY EVENTS - ACT 3

---

**EVENT: life_evidence**

TITLE: We Are Not Alone

TRIGGER:
- Year 25-50
- Science facility level 3+
- Geology experiment running
- 5% chance per year

DESCRIPTION:
[Lead Scientist] has called an emergency meeting.

"We found something in the deep drill samples. Microbial fossils. Three billion years old. Life on Mars."

The room is silent.

"We're not alone in the universe."

This changes everything—science, philosophy, politics. Earth will want to know. Some may want to suppress it.

CHOICES:
A) Announce immediately (full transparency)
   → Earth goes wild
   → Science faction +30
   → Colony morale +20 (historic moment)
   → Religious colonists may have crisis of faith events

B) Verify thoroughly before announcing (6 months)
   → Risk of leak
   → Scientific credibility if verified
   → If false positive, saved embarrassment
   → Earth pressure to share data

C) Control the narrative (announce YOUR way)
   → You decide framing
   → Political advantage
   → Risk: Cover-up accusations if discovered

D) Suppress the finding
   → This is too big. Too dangerous.
   → Only you and scientist know
   → Weight of secret (events)
   → May leak anyway (scandal)

FOLLOW-UP:
- Triggers religious_crisis (if announced)
- Triggers earth_scientific_mission (Earth wants to send experts)
- Triggers meaning_of_life (philosophical quiet moment)

---

**EVENT: terraforming_proposal**

TITLE: The Long Dream

TRIGGER:
- Year 30-50
- Population > 300
- Science level 3+
- Resources stable for 5+ years

DESCRIPTION:
[Visionary Scientist] has presented a plan to the council: Terraforming.

Not in our lifetimes. Not in our children's lifetimes. But in 500 years? Maybe 1000? Mars could have an atmosphere. Blue skies. Rain.

It would take everything we have. Generations of sacrifice. The benefits would go to people not yet born.

CHOICES:
A) Begin the Long Project
   → 10% of all production redirected to terraforming
   → Immediate quality of life impact
   → Visionary faction empowered
   → "We build for tomorrow" culture

B) Research only (no commitment)
   → Small science investment
   → No immediate impact
   → Keep options open
   → Visionaries disappointed

C) Reject terraforming entirely
   → "Mars should stay Mars"
   → Resources for present generation
   → Pragmatist faction empowered
   → Visionaries may leave or rebel

D) Let the people decide (referendum)
   → Democratic legitimacy
   → Campaign events
   → Outcome based on colony culture

---

## ACT 4 EVENTS (Years 51-100)
*"The Independence Years"*

### GENERATIONAL EVENTS - ACT 4

---

**EVENT: last_founder_dies**

TITLE: The End of an Era

TRIGGER:
- Year 50-80
- Last surviving original founder dies
- Automatic

DESCRIPTION:
[Last Founder] has died at age [X].

They were the last of the eight who stepped onto Mars that first day. The last person alive who remembered Earth's sky.

The colony observes a week of mourning. In their final years, they told stories of the early days—the fear, the hope, the desperate determination to survive.

Now those stories are history.

EFFECTS:
- Colony-wide mourning event
- "Founding Generation" officially ends
- Founder's stories preserved (or lost, depending on earlier choices)
- Massive cultural milestone
- All living colonists are Mars-natives or immigrants

CHOICES:
A) National holiday established (Founder's Day)
   → Annual commemoration
   → Founder culture preserved
   → "Never forget where we came from"

B) Living memorial (rename major facility)
   → [Last Founder]'s name lives on
   → Personal honor
   → Less formal than holiday

C) Move forward (no formal commemoration)
   → "They would have wanted us to focus on the future"
   → Some feel this is disrespectful
   → Clean break from founder era

---

**EVENT: second_generation_leadership**

TITLE: Born to Lead

TRIGGER:
- Year 40-60
- Second-generation Mars-born reaches 25+
- Leadership position open

DESCRIPTION:
[Second-Gen Character], grandchild of [Founder], has emerged as a candidate for [leadership position].

They're the first person born on Mars whose parents were also born on Mars. They've never known anyone who saw Earth firsthand.

Their platform: "We are Martians. Not expatriates. Not colonists. Martians."

CHOICES:
A) Support their candidacy
   → New generation takes power
   → Fresh perspective, fresh problems
   → Old guard fades

B) Support experienced candidate instead
   → "Not ready yet"
   → Second-gen character: -30 relationship
   → They'll remember this

C) No endorsement (let democracy work)
   → Outcome based on colony mood
   → You stay above politics
   → Respected but uninvolved

---

### CRISIS EVENTS - ACT 4

---

**EVENT: earth_collapse**

TITLE: Silence from Home

TRIGGER:
- Year 60-100
- 5% chance per year after Year 60
- More likely if Earth relations were poor

DESCRIPTION:
Transmissions from Earth have stopped.

For three weeks, nothing. No scheduled data. No personal messages. No news.

Then a single, fragmented message gets through:

"...war... infrastructure collapse... cannot send supplies... you're on your own... survive..."

Then silence.

You are truly alone.

CHOICES:
A) Announce the truth to the colony
   → Panic, then acceptance
   → Morale crisis (short-term)
   → Long-term: Colony unifies
   → "We are humanity's backup"

B) Controlled release (manage information)
   → Gradual revelation over months
   → Less panic, but trust damage if discovered
   → Some colonists demand the truth

C) Investigate before announcing
   → Send probe/signal attempts
   → Delayed response (1-2 years)
   → Colony knows something is wrong
   → Truth eventually comes out

EFFECTS:
- Earth supplies: ENDED
- Immigration: ENDED
- Colony is fully independent
- New "Last Colony" events unlock
- Some colonists may despair (suicide risk events)

---

**EVENT: civil_war_risk**

TITLE: On the Brink

TRIGGER:
- Year 60-100
- Two factions with < 20 relationship with each other
- Political stability < 30
- After a triggering dispute event

DESCRIPTION:
The [Faction A] and [Faction B] factions are arming themselves.

What started as political disagreement has become something darker. People are choosing sides. Families are split. Violence has been threatened.

The colony stands on the edge of civil war.

CHOICES:
A) Emergency mediation (all-hands summit)
   → 2-week pause on everything
   → Leadership skill check
   → Success: Step back from brink
   → Failure: War begins anyway

B) Side with [Faction A]
   → End the conflict quickly
   → [Faction A] wins
   → [Faction B]: Exile, imprisonment, or submission
   → 30% of colony dead or exiled
   → You rule as [Faction A] leader

C) Side with [Faction B]
   → Same as B, reversed factions

D) Call for separation
   → Colony splits into two colonies
   → Half the population leaves to establish new settlement
   → Loss of resources, population
   → Peace through distance

E) Resign (remove yourself as the divisive factor)
   → Maybe YOU are the problem
   → New leadership may heal or worsen
   → You become private citizen

---

## QUIET MOMENTS

---

**EVENT: quiet_stargazing_child**

TITLE: Questions About Earth

TRIGGER:
- Any year with Mars-born children
- Night cycle
- Morale > 50

DESCRIPTION:
You find a group of Mars-born children at the observation window, looking at the stars.

One of them points at a blue dot. "Is that Earth?"

"Yes," you say.

"Why do the old people cry when they look at it?"

CHOICES:
A) "Because they miss home."
   → Simple, truthful
   → Children: "But this IS home."
   → Perspective shift moment

B) "Because they're remembering people they loved."
   → Deeper truth
   → Leads to conversation about death, memory
   → Children: Ask about their own relatives

C) "Because it's beautiful."
   → Deflection
   → Children accept this
   → You avoid heavy conversation

D) [Sit with them in silence]
   → No words needed
   → Peaceful moment
   → Children eventually drift off to bed

---

**EVENT: quiet_founders_reunion**

TITLE: The Last Four

TRIGGER:
- Year 30-50
- 4 or fewer original founders surviving
- Anniversary of landing

DESCRIPTION:
The surviving founders have gathered for the anniversary. It used to be a colony-wide celebration. Now it's just the four of them, remembering.

You walk into the room and find them looking at old photos.

"Remember when the first greenhouse failed?" [Founder A] says.

"Remember when [Dead Founder] saved the oxygen system?"

"Remember when we thought we weren't going to make it?"

They're laughing now. Crying. Both.

CHOICES:
A) Join them
   → You're part of this moment
   → They share stories you've never heard
   → Relationship +20 with all survivors

B) Let them have their moment
   → Respectful distance
   → Watch from afar
   → They appreciate the privacy

C) Bring the colony in
   → Make it a celebration
   → Not all survivors want the attention
   → Some are grateful, some are overwhelmed

---

**EVENT: quiet_first_painting**

TITLE: Martian Art

TRIGGER:
- Year 10-30
- Arts facility exists
- Mars-born resident with creative trait

DESCRIPTION:
[Artist], born and raised on Mars, has completed the first original artwork by a Martian artist.

It's a painting of a Martian sunrise. But the colors aren't what you'd expect—brighter than the dusty reality. More vibrant.

"This is how I see it," they explain. "This is Mars through Martian eyes."

EFFECTS:
- "First Martian Art" added to colony assets
- Cultural development +10
- Morale +5

CHOICES:
A) Display it prominently (make it a symbol)
   → Central plaza installation
   → Artist becomes known
   → Cultural pride

B) Preserve it carefully (historical artifact)
   → Museum-quality preservation
   → Less public visibility
   → Historical value prioritized

C) Ask them to make more
   → Commission art program
   → Multiple artworks over time
   → Artist: May feel pressured or honored

---

## EVENT CHAINS

### THE LEGACY CHAIN

A multi-event chain following one founding family across generations.

**EVENT: legacy_1_founder_story**
Year 5-10: Founder tells you their greatest hope for Mars.

**EVENT: legacy_2_child_grows**
Year 20-25: Their child shows similar traits. Following in footsteps?

**EVENT: legacy_3_grandchild_choice**
Year 40-50: Grandchild must choose: Continue the legacy or break free?

**EVENT: legacy_4_fulfillment_or_failure**
Year 60-70: The legacy either fulfills the founder's hope or diverges entirely.

### THE INDEPENDENCE CHAIN

Ten-event chain from first whispers of independence to final resolution.

### THE DISCOVERY CHAIN

Multi-event mystery: Strange readings → Investigation → Revelation → Consequences

---

## Event Generation Rules

### Frequency Targets

| Event Type | Per Year (Early) | Per Year (Late) |
|------------|------------------|-----------------|
| Major | 1 | 2-3 |
| Minor | 2-3 | 3-5 |
| Quiet Moment | 0-1 | 1-2 |
| Crisis | 0-0.5 | 0.5-1 |

### Cooldown Rules

- Same exact event: Never repeat
- Same event type: 3+ years
- Same character focus: 2+ years
- Major crisis: 5+ years
- Death event: 2+ years (prevent fatigue)

### Context Sensitivity

Events should feel appropriate to the moment:
- No celebrations during crisis
- No quiet moments when resources critical
- Political events require political structure
- Generational events require appropriate ages

---

## Writing Guidelines

### Tone

- **Early game:** Hopeful desperation. "We might die, but what we're building matters."
- **Mid game:** Growing confidence. "We're not just surviving. We're thriving."
- **Late game:** Reflective weight. "We've built something that will outlast us."

### Character Voice

- Founders speak with mission jargon, Earth references
- First-gen Mars-born mix cultures
- Second-gen+ speak purely Martian idioms

### Callback Integration

Reference earlier events when possible:
- "Remember when we rationed water? The people remember too."
- "Your grandmother made the same choice 40 years ago."
- "The [Founder Memorial] stands as a reminder of what we sacrificed."

---

This catalog provides the skeleton. The flesh is the hundreds of specific events, each with unique dialogue, consequences, and connections to the colony's ongoing story.

Every event should make the player think: "What kind of civilization am I building?"

And every choice should echo through the years.
