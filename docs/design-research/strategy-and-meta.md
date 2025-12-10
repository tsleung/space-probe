# Strategic Depth & Meta-Game Systems

Deep design research for factions, meta-progression, resource chains, emergent narrative, and world-building. Drawing from EU4, Tropico, Helldivers 2, SimTower, The Expanse, and Bobiverse.

---

## 1. Faction System (EU4 + Tropico + The Expanse)

### 1.1 Design Philosophy

The mission doesn't happen in a vacuum. Multiple stakeholders have invested in this mission, and they have competing - sometimes conflicting - interests. The player must navigate these relationships while keeping the mission on track.

**Core Tension:** You cannot please everyone. Every decision has faction implications.

### 1.2 The Factions

| Faction | What They Want | What They Hate |
|---------|----------------|----------------|
| **NASA** | Mission success, crew safety, scientific return, proper protocols | Private sector dominance, political interference, shortcuts |
| **Private Space** | ROI, technology demonstrations, media attention, contract extensions | Government bureaucracy, safety-induced delays, exclusion |
| **Congress** | Budget control, American jobs, political victories, no scandals | Cost overruns, foreign contractors, embarrassments |
| **International Partners** | Shared credit, their equipment used, joint operations, technology transfer | Unilateral decisions, exclusion from discoveries, American dominance |
| **Public Opinion** | Exciting discoveries, crew human interest stories, streaming content | Accidents, boring phases, perceived waste |
| **Crew Families** | Crew safety above everything, communication access, return schedule | Risk-taking, communication blackouts, extended missions |
| **Scientific Community** | Data quality, peer review, sample priority, publication rights | Commercial exploitation, rushed timelines, secrecy |

### 1.3 Standing Mechanics

Each faction has a standing score (0-100):

| Range | Status | Effects |
|-------|--------|---------|
| 0-20 | Hostile | Active opposition, -20% budget, negative events |
| 21-40 | Cold | No support, occasional blocks |
| 41-60 | Neutral | Standard operations |
| 61-80 | Friendly | Occasional bonuses, support during crises |
| 81-100 | Allied | Major bonuses, crisis protection, special options |

### 1.4 Decision Trade-offs

**Ship Building Phase Examples:**

| Decision | NASA | Private | Congress | Public | Families |
|----------|------|---------|----------|--------|----------|
| Use expensive safe components | +15 | -10 | -20 | +5 | +20 |
| Use cheap commercial parts | -10 | +20 | +15 | -5 | -15 |
| Hire foreign contractors | -5 | +5 | -25 | 0 | 0 |
| Stream construction progress | 0 | +15 | +5 | +25 | +10 |
| Delay launch for more testing | +20 | -15 | -10 | -5 | +15 |
| Rush to hit window | -15 | +10 | +5 | +10 | -20 |

**Travel Phase Examples:**

| Event Response | NASA | Private | Scientific | Families |
|----------------|------|---------|------------|----------|
| Investigate anomaly (risk) | +5 | +10 | +20 | -15 |
| Play it safe | +10 | -5 | -10 | +20 |
| Stream crew activities | 0 | +15 | -5 | -10 |
| Maintain communication blackouts | +5 | -10 | 0 | -25 |

### 1.5 Faction Conflicts

Factions can conflict with each other, creating impossible situations:

**Congress vs NASA:** "Cut the budget 20% or we defund next year."
- NASA standing drops if you cut
- Congress standing drops if you don't
- Player must choose who to disappoint

**Private vs International:** "Our patent, our technology - no sharing."
- Private wants exclusivity
- International wants collaboration
- Player must navigate or lose standing with one

**Families vs Scientific:** "Bring them home now vs. stay for more data."
- Families want early return
- Scientists want extended mission
- Crew members may have opinions based on their own families

### 1.6 Standing Consequences

**Budget Effects:**
```
NASA Standing:    Budget modifier
0-20:            0.8x
21-40:           0.9x
41-60:           1.0x
61-80:           1.1x
81-100:          1.15x

Congress Standing: Additional modifier
0-20:            0.7x (severe cuts)
21-40:           0.85x
41-60:           1.0x
61-80:           1.1x
81-100:          1.2x (earmarks!)
```

**Event Unlocks:**
- High Private standing: Access to experimental technology
- High Scientific standing: Better experiment equipment
- High Public standing: Morale boost events, crowdfunding options
- High Families standing: Crew morale bonuses, special messages

### 1.7 Commander Profile (Tropico-style)

Your decisions shape who you are:

| Style | Characterized By | Faction Affinity | Crew Affinity |
|-------|------------------|------------------|---------------|
| Authoritarian | Quick decisions without consultation | Congress, Military | Follows orders crew |
| Democratic | Crew votes, slower but buy-in | Public, Families | Independent crew |
| Scientific | Data-driven, experiment-focused | Scientific, NASA | Scientist crew |
| Pragmatic | Survival-focused, flexible ethics | Private | Experienced crew |

Your dominant style affects:
- Available dialogue options
- Crew reactions to your decisions
- Faction trust modifiers
- Available events

---

## 2. Meta-Progression System (Helldivers 2 + Bobiverse)

### 2.1 Design Philosophy

Each mission contributes to a larger "Space Program." Success unlocks new options for future missions. Failure teaches lessons. Over time, the player builds toward Mars colonization.

### 2.2 Technology Tiers

**Tier 1 - Available at Start:**
- Basic Chemical Engines
- Standard Life Support
- Basic Communications
- Manual Controls

**Tier 2 - Unlock with Successful Mission:**
- Ion Propulsion (+25% fuel efficiency)
- Advanced Life Support (+15% crew health)
- High-Gain Antenna (+50% data transmission)
- Basic Automation

**Tier 3 - Unlock with 3 Successful Missions:**
- VASIMR Engines (variable thrust/efficiency)
- Closed-Loop ISRU
- Artificial Gravity Modules
- Advanced Medical Bay

**Tier 4 - Unlock with Perfect Mission or Special Achievement:**
- Fusion Propulsion (experimental)
- Autonomous Manufacturing
- Terraforming Equipment
- Permanent Habitat Modules

### 2.3 Legacy System

Each mission leaves a legacy that affects future missions:

**Infrastructure Legacy:**
- Communications relay left in Mars orbit
- Cached supplies on Mars surface
- Established landing sites
- Pre-positioned equipment

**Knowledge Legacy:**
- Mars maps improved
- Resource locations known
- Weather patterns documented
- Optimal landing sites identified

**Personnel Legacy:**
- Trained crew available for future missions
- Mission controllers experienced
- Scientists with Mars expertise
- Engineers who know the systems

**Reputation Legacy:**
- Faction standing modifiers carry forward (decayed)
- Public perception affects funding
- International relationships persist
- Scientific credibility accumulates

### 2.4 Mission Grades and Rewards

| Grade | Requirements | Unlocks |
|-------|--------------|---------|
| S | All crew, all science, under budget, early return | Choice of Tier 4 tech |
| A | All crew, primary science, on budget | Tier 3 tech unlock |
| B | 3+ crew, primary science | Tier 2 tech unlock |
| C | 1+ crew returns | Minor tech unlock |
| D | Data transmitted, no crew | Lessons learned bonus |
| F | Total loss | Inquiry event, possible setback |

### 2.5 Achievement Unlocks

| Achievement | Condition | Reward |
|-------------|-----------|--------|
| First Contact | Complete first mission | Ion Engine research |
| No One Left Behind | Return all crew healthy | Emergency Medical Bay |
| Speed Demon | Complete 30+ days early | Advanced Trajectory Planning |
| Budget Hero | Under 75% budget | Congressional Budget Bonus |
| Science First | 100% experiments | Advanced Lab Module |
| Mars Veteran | Same crew on 2 missions | Leadership trait for crew |
| The Martian | Survive critical system failure | Emergency Protocols |
| Legacy Builder | Leave infrastructure | Starting base in future |

### 2.6 Community Goals (Optional Multiplayer)

If implementing online features:

**Global Objectives:**
```
CURRENT ERA: First Wave

Global Stats:
- Missions Completed: 15,847
- Missions Successful: 8,234
- Total Crew Saved: 31,456
- Total Crew Lost: 12,893

Active Community Goal:
"MARS COMMUNICATIONS NETWORK"
Collectively complete 1,000 successful missions
to unlock permanent Mars relay for all players.

Progress: 734 / 1,000
Reward: +20% communication efficiency for all
```

**Hall of Fame:**
- Top mission scores
- Fastest completions
- Most crew saved
- Most science collected

---

## 3. Resource Chain System (Tropico + SimTower + The Martian)

### 3.1 ISRU (In-Situ Resource Utilization)

The Martian showed us: on Mars, you make what you need.

**Raw Resources (Gathered):**
- Regolith (Martian soil)
- Ice (polar regions, subsurface)
- Atmospheric CO2
- Iron Ore
- Aluminum Ore

**Processed Resources:**
- Water (from ice)
- Oxygen (from water, CO2)
- Hydrogen (from water)
- Methane (from CO2 + hydrogen)
- Iron (from ore)
- Aluminum (from ore)

**Manufactured Goods:**
- Rocket Fuel (methane + oxygen)
- Building Materials
- Spare Parts
- Solar Cells

### 3.2 Production Chains

```
PRIMARY CHAINS:

[ICE] → Ice Processor → [WATER]
           ↓
         [WATER] → Electrolyzer → [OXYGEN] + [HYDROGEN]
                       ↓
[ATMOSPHERIC CO2] + [HYDROGEN] → Sabatier Reactor → [METHANE] + [WATER]
                                        ↓
         [METHANE] + [OXYGEN] → Fuel Synthesis → [ROCKET FUEL]


MANUFACTURING CHAINS:

[REGOLITH] → Smelter → [IRON] / [ALUMINUM]
                ↓
[IRON] + [ALUMINUM] → Fabricator → [SPARE PARTS]
                         ↓
[SPARE PARTS] + [MATERIALS] → Workshop → [EQUIPMENT]
```

### 3.3 Facility Types

| Facility | Input | Output | Power | Crew |
|----------|-------|--------|-------|------|
| Ice Processor | 10 Ice | 9 Water | 50 kW | 0.5 |
| Electrolyzer | 10 Water | 8.9 O2 + 1.1 H2 | 100 kW | 0.25 |
| CO2 Collector | Atmosphere | 10 CO2/day | 30 kW | 0 |
| Sabatier Reactor | 10 CO2 + 5 H2 | 4 Methane + 4.5 Water | 200 kW | 0.5 |
| Fuel Synthesizer | 10 Methane + 35 O2 | 10 Fuel | 500 kW | 1 |
| Smelter | 100 Regolith | 5 Iron + 2 Aluminum | 300 kW | 1 |
| Fabricator | 5 Iron + 2 Aluminum | 1 Spare Part | 150 kW | 1 |

### 3.4 Efficiency System

Production efficiency depends on:

```
Base Efficiency: 100%

Modifiers:
+ Crew Skill:        -20% to +20%
+ Power Availability: -50% to +0% (drops rapidly below 80% power)
+ Maintenance Level:  -30% to +0%
+ Facility Quality:   -20% to +20%
+ Adjacent Bonuses:   +5% to +15%

Example:
80% skilled crew: +10%
90% power:        -5%
Good maintenance: -5%
Quality facility: +10%
No adjacency:     +0%
Total:            110% efficiency
```

### 3.5 Base Building (SimTower Style)

**Vertical Construction:**
```
SURFACE LEVEL: [SOLAR] [SOLAR] [SOLAR] [COMM] [PAD]
                          ↓ power
LEVEL 0:      [AIRLOCK] [EVA PREP] [STORAGE]
                          ↓
LEVEL -1:     [QUARTERS] [COMMON] [MEDICAL]
                          ↓
LEVEL -2:     [LAB] [WORKSHOP] [GREENHOUSE]
                          ↓
LEVEL -3:     [STORAGE] [LIFE SUPPORT] [POWER]
                          ↓
LEVEL -4:     [EMERGENCY SHELTER] (deepest radiation protection)
```

**Adjacency Bonuses:**
- Lab near Sample Storage: +10% science
- Quarters near Common: +5% morale
- Workshop near Storage: +10% repair speed
- Greenhouse near Water: +15% yield

**Power Grid:**
```
POWER BUDGET
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Generation: 45 kW (solar panels)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Life Support:   20 kW [CRITICAL]
Laboratory:      8 kW [SCIENCE]
Greenhouse:      5 kW [FOOD]
Workshop:        6 kW [REPAIR]
Communications:  2 kW [EARTH]
Heating:         8 kW [COMFORT]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total Need:     49 kW
Deficit:         4 kW ← PROBLEM
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## 4. Emergent Narrative System (EU4 + CK2)

### 4.1 Design Philosophy

The best stories aren't scripted - they emerge from systems interacting. A dust storm isn't just a resource event; it's the context for character growth, relationship changes, and memorable moments.

### 4.2 Event Chain System

Events can trigger follow-up events:

**Example Chain: "The Signal"**

```
STAGE 1: Signal Detected (Sol 30+, random trigger)
"Communications detecting unusual signal pattern from northern plains."

OPTIONS:
A) Investigate immediately → Stage 2A
B) Log and continue priorities → Stage 2B
C) Report to Earth, await instructions → Stage 2C

STAGE 2A: Investigation
"Rover expedition reveals source: buried metallic object,
possibly failed Soviet mission from 1970s."

OPTIONS:
A) Excavate → Stage 3A (requires equipment, crew)
B) Document only → Chain ends (minor science)

STAGE 2B: Signal Fades
"Signal weakened. May have been equipment malfunction."
Chain ends (but flag set for possible future reference)

STAGE 2C: Earth Decision
Earth responds after 40-minute delay...
"Proceed with caution. Document everything."
Returns to Stage 2A with Earth approval bonus

STAGE 3A: Discovery
"The object is a Soviet lander from 1973 Mars program,
never announced, never known to have existed."

IMPLICATIONS:
- Major science discovery
- International faction implications (Russia)
- Possible follow-up chain (what else is hidden?)
```

### 4.3 Character-Driven Events

Events tie to specific crew:

**Chen's Geology Discovery:**
```
TRIGGER: Chen skill > 80, Sol 50+, specific terrain

"Dr. Chen has found something unusual in the sediment layers.
Ancient water signatures, far more recent than expected."

OPTIONS:
A) Prioritize analysis → Chen arc progression + science
B) Note for later → Minor science, Chen disappointed
C) Let Chen decide → Relationship test
```

**Martinez's Family Crisis:**
```
TRIGGER: Martinez morale < 40, Sol 60+

"Delayed message: Martinez's daughter is hospitalized on Earth.
He's withdrawn, barely functional."

OPTIONS:
A) Give him space → Slower recovery, respects privacy
B) Crew support → Faster recovery if relationships good
C) Mission first → Martinez resentment, fast return to function
```

### 4.4 Story Beat System

Certain moments are guaranteed if conditions allow:

| Beat | Trigger | Purpose |
|------|---------|---------|
| First Mars View | Day 120+ of travel | Emotional milestone |
| Halfway Point | 50% journey | Check-in, morale event |
| First EVA | Sol 1 on Mars | Achievement moment |
| The Long Night | First dust storm | Survival test |
| Point of No Return | Departure decision | Dramatic tension |
| Earth Rising | Final approach | Homecoming emotion |

### 4.5 After-Action Report Generation

The game generates a narrative summary:

```
MISSION REPORT: ARES VII

THE JOURNEY BEGINS
On Day 182, the spacecraft Endeavour departed lunar orbit,
2 days past the optimal launch window due to last-minute
life support recalibration. Commander Chen gave the order
with quiet confidence, though the delayed departure would
add 11 days to the journey.

THE CRISIS AT DAY 247
When the solar particle event struck, Dr. Webb was mid-EVA.
The crew had 6 minutes warning. Engineer Tanaka's quick
thinking saved his life - she remotely piloted the rover to
provide shielding while he sprinted to the airlock.

This moment would define their relationship for the
remainder of the mission.

THE DISCOVERY
Sol 45 brought the unexpected: beneath the Jezero rim,
the drill struck ice far shallower than predicted...

[continues based on actual events]
```

---

## 5. The Lived-In Universe (Star Wars + The Expanse)

### 5.1 Design Philosophy

The world exists beyond your mission. Other things are happening. History has led to this moment. The universe should feel real, not like a stage set for your story.

### 5.2 World State

```
WORLD CONTEXT:

Year: 2035
Era: "First Wave" - Early crewed Mars exploration

SPACE AGENCIES:
- NASA: Leading Mars program, moderate budget pressure
- SpaceX: 2 successful cargo missions, pushing crewed flight
- ESA: Life support partnership, Ariane launches
- CNSA: Competing program, established Moon base
- ISRO: Rising low-cost player

POLITICAL CLIMATE:
- US administration: Moderately space-supportive
- International tensions: Moderate (cooperation possible)
- Climate pressure: High (some argue Earth first)
- Public interest: Recovering from post-ISS slump

CONCURRENT MISSIONS:
- Artemis IX: Lunar base, operational
- Zhurong-3: Chinese Mars rover, active
- Gateway: Lunar station, expanding
- Starship: SpaceX cargo runs to Mars
```

### 5.3 News Feed System

Daily news from Earth (filtered by communication delay):

**Independent World Events:**
```
"Blue Origin announces lunar hotel construction timeline"
"Congress debates 15% increase to NASA budget"
"Chinese probe sends first images from Mars south pole"
"Solar storm disrupts Earth satellite communications"
"SpaceX Starship completes 100th successful landing"
```

**Reactions to Player Actions:**
```
[After risky EVA decision]
"Mars mission commander draws criticism for unnecessary risk"
Public Opinion: -5

[After major discovery]
"Historic finding on Mars: Evidence of ancient water"
Scientific Community: +15, Public Opinion: +20

[After crew conflict leaked]
"Sources report tension among Mars crew members"
Families: -10, Public: interest +5
```

### 5.4 Corporate Players

Companies have their own agendas:

**HelioTech (Solar Power):**
- Supplier relationship
- May offer discounts for high standing
- May have quality scandal

**Titan Propulsion (Engines):**
- Competitor relationship
- May try to poach crew
- May offer collaboration

**AresLife (Life Support):**
- Partner relationship
- Breakthrough events possible
- May be acquired (changing relationship)

### 5.5 Historical Texture

Real Mars locations have game-layer history:

**Jezero Crater:**
- Real: Ancient river delta, Perseverance site
- Game: First successful sample return (2033)
- Significance: High biosignature potential
- Easter egg: Perseverance visible on western rim

**Olympus Mons:**
- Real: Largest volcano in solar system
- Game: Chinese Zhurong-2 attempted summit (2034)
- Significance: Potential geothermal energy
- Easter egg: Ancient lava tubes in area

**Valles Marineris:**
- Real: Massive canyon system
- Game: ESA mapping mission (2032)
- Significance: Geological goldmine
- Easter egg: "The Face" nearby (debunked but fun)

---

## 6. Implementation Priority

**Phase 1 - Essential:**
- 3 core factions (NASA, Congress, Public)
- Basic standing system
- Simple tech unlocks (3 tiers)

**Phase 2 - Depth:**
- All 7 factions
- Commander profile
- Full tech tree
- Basic ISRU (water → oxygen)

**Phase 3 - Ambitious:**
- Faction conflicts
- Legacy system
- Full resource chains
- Event chains

**Phase 4 - Polish:**
- News feed
- Corporate players
- Generated narratives
- Community goals (if multiplayer)

**Phase 5 - Dream:**
- Full lived-in universe
- Multi-mission campaigns
- Colonization endgame
- Persistent world state
