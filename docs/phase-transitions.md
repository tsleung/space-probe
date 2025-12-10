# Phase Transitions

## Overview

The transitions between phases are critical moments. They're where player decisions crystallize into consequences, where tension peaks, and where the narrative pivots. Each transition should feel like a meaningful threshold.

## Design Philosophy

**Sid Meier:** "Transitions are where games often lose players. Make them feel earned, not interrupted."

Transitions should:
- Feel like payoffs, not loading screens
- Summarize what the player accomplished
- Preview what's coming
- Carry forward consequences visibly
- Build anticipation

---

## Transition 1: Launch (Phase 1 → Phase 2)

### The Moment

The player has built their ship, tested their systems, and the launch window has arrived. This is the "point of no return."

### Pre-Launch Sequence

```
┌─────────────────────────────────────────────────────────────┐
│                    LAUNCH READINESS                         │
│                                                             │
│  Ship: [ARTEMIS IV]              Launch Window: OPTIMAL     │
│                                                             │
│  ✓ Hull Integrity: 94%                                      │
│  ✓ Engine Systems: 87%                                      │
│  ✓ Life Support: 91%                                        │
│  ✓ Navigation: 88%                                          │
│  ✓ Crew Status: Ready                                       │
│  ✓ Cargo Loaded: 98%                                        │
│  ⚠ Fuel Reserves: 76% (Below recommended)                   │
│                                                             │
│  Budget Remaining: $12.4M (Contingency Reserve)             │
│  Days to Window: 0                                          │
│                                                             │
│  [ ABORT LAUNCH ]              [ CONFIRM LAUNCH ]           │
└─────────────────────────────────────────────────────────────┘
```

### Launch Cinematics

A brief cinematic or animated sequence:
1. Crew boards the ship
2. Final systems check
3. Countdown
4. Engine ignition
5. Ship departs lunar orbit
6. Earth/Moon shrink in the viewport
7. Mars trajectory confirmed

### Data Carried Forward

| Data | Impact on Phase 2 |
|------|------------------|
| Component quality scores | Failure probabilities |
| Engine type | Travel time, fuel consumption |
| Cargo manifest | Available supplies |
| Budget reserve | Emergency options |
| Crew training levels | Task effectiveness |
| Ship layout | Adjacency effects persist |

### Narrative Moment

Brief crew reactions:
- Pilot: "Trajectory locked. Next stop, Mars."
- Engineer: "All systems nominal... for now."
- Scientist: "Six months. Let's make them count."
- Medical: "Everyone's vitals look good. Here we go."

---

## Transition 2: Mars Arrival (Phase 2 → Phase 3)

### The Moment

After months of travel, Mars fills the viewport. The crew must execute orbital insertion and landing - the most dangerous operation since launch.

### Arrival Sequence

```
┌─────────────────────────────────────────────────────────────┐
│                    MARS APPROACH                            │
│                                                             │
│  Distance to Mars Orbit: 2,400 km                           │
│  Velocity: 3.2 km/s                                         │
│  Fuel Remaining: 34%                                        │
│                                                             │
│  ORBITAL INSERTION BURN                                     │
│  Required: 1.8 km/s delta-v                                 │
│  Fuel Cost: 28%                                             │
│  Remaining After: 6%                                        │
│                                                             │
│  ⚠ Warning: Low fuel margin for course corrections          │
│                                                             │
│  [ EXECUTE BURN ]                                           │
└─────────────────────────────────────────────────────────────┘
```

### Landing Site Selection

If not pre-selected, player chooses now:

```
┌─────────────────────────────────────────────────────────────┐
│                 LANDING SITE SELECTION                      │
│                                                             │
│  Orbital scans complete. Select primary landing site:       │
│                                                             │
│  [1] Jezero Crater                                          │
│      + Ancient lake bed - high biosignature potential       │
│      + Moderate resources                                   │
│      - Seasonal dust storms                                 │
│                                                             │
│  [2] Acidalia Planitia                                      │
│      + Flat, safe terrain                                   │
│      + Easy operations                                      │
│      - Limited scientific interest                          │
│                                                             │
│  [3] Polar Region                                           │
│      + Abundant water ice                                   │
│      + Ice core science                                     │
│      - Extreme cold                                         │
│                                                             │
│  [4] Valles Marineris Edge                                  │
│      + Geological diversity                                 │
│      + Canyon exploration                                   │
│      - Unstable terrain                                     │
└─────────────────────────────────────────────────────────────┘
```

### Landing Sequence

1. Cargo deployment (base modules descend first)
2. Ship assumes parking orbit
3. Crew transfers to descent vehicle
4. Atmospheric entry
5. Parachute/retro-rocket landing
6. First steps on Mars

### First Steps Cinematic

The emotional peak of the game so far:
- Crew exits lander
- First view of Martian landscape
- Planting flag or mission marker
- Brief dialogue capturing the moment
- Camera pulls back to show the scale

### Data Carried Forward

| Data | Impact on Phase 3 |
|------|------------------|
| Ship component state | Repair difficulty for return |
| Remaining fuel | Return trip viability |
| Crew health/morale | Starting conditions |
| Cargo manifest | Available equipment |
| Landing site | Environmental challenges |
| Travel time | Crew fatigue |

### Status Report

```
┌─────────────────────────────────────────────────────────────┐
│                 MISSION STATUS REPORT                       │
│                 Sol 1 - Mars Surface                        │
│                                                             │
│  JOURNEY SUMMARY                                            │
│  Travel Time: 187 days (31 days over optimal)               │
│  Fuel Consumed: 94%                                         │
│  Components Damaged: 2 (Cafeteria, Secondary O2)            │
│  Crew Incidents: 1 (Dr. Chen - recovered)                   │
│                                                             │
│  ASSETS ON SURFACE                                          │
│  ✓ Habitation Module                                        │
│  ✓ Oxygenator                                               │
│  ✓ Water Reclaimer                                          │
│  ✓ Food Storage (73% capacity)                              │
│  ✓ Solar Arrays (6 units)                                   │
│  ✓ Rovers (2 units)                                         │
│  ⚠ Laboratory Equipment (minor damage)                      │
│                                                             │
│  SHIP IN ORBIT                                              │
│  Fuel Remaining: 6%                                         │
│  Hull Integrity: 81%                                        │
│  MAV Status: Ready                                          │
│                                                             │
│  [ BEGIN SURFACE OPERATIONS ]                               │
└─────────────────────────────────────────────────────────────┘
```

---

## Transition 3: Mars Departure (Phase 3 → Phase 4)

### The Moment

The return window is approaching. The crew must decide: stay longer for more science, or leave while conditions allow. Then comes the MAV launch - the most dangerous single event of the mission.

### Departure Decision

```
┌─────────────────────────────────────────────────────────────┐
│                  DEPARTURE PLANNING                         │
│                                                             │
│  Return Window Status: OPEN (closes in 45 sols)             │
│  Optimal Departure: 12 sols                                 │
│  Latest Safe Departure: 38 sols                             │
│                                                             │
│  MISSION OBJECTIVES                                         │
│  ✓ Primary Geology: Complete                                │
│  ✓ Primary Atmosphere: Complete                             │
│  ◐ Primary Ice Study: 67% complete (need 14 sols)           │
│  ○ Secondary Biosignature: Not started (need 30 sols)       │
│                                                             │
│  CREW STATUS                                                │
│  Commander Torres: Health 72%, Morale 65%                   │
│  Engineer Kowalski: Health 84%, Morale 71%                  │
│  Dr. Okonkwo: Health 68%, Morale 58%                        │
│  Dr. Chen: Health 61%, Morale 62%                           │
│                                                             │
│  Staying longer means:                                      │
│  + More science completion                                  │
│  - Higher crew fatigue                                      │
│  - Longer return trip (each sol = 0.5 day added)            │
│  - Tighter margins                                          │
│                                                             │
│  [ STAY: 14 SOLS ]  [ STAY: 30 SOLS ]  [ DEPART NOW ]       │
└─────────────────────────────────────────────────────────────┘
```

### MAV Launch Sequence

The most tense moment of the game:

```
┌─────────────────────────────────────────────────────────────┐
│                    MAV LAUNCH                               │
│                                                             │
│  All crew aboard Mars Ascent Vehicle                        │
│  Target: Artemis IV in parking orbit                        │
│                                                             │
│  MAV Systems:                                               │
│  Engine: 89% quality                                        │
│  Navigation: 92% quality                                    │
│  Life Support: 85% quality                                  │
│  Fuel: 100% (ISRU produced)                                 │
│                                                             │
│  Weather: Clear                                             │
│  Launch Window: Optimal                                     │
│                                                             │
│  "All systems go. On your mark, Commander."                 │
│                                                             │
│                    [ LAUNCH ]                               │
└─────────────────────────────────────────────────────────────┘
```

### Launch Cinematics

1. MAV engines ignite
2. Ascent through Martian atmosphere
3. Stage separation (if applicable)
4. Orbit achieved
5. Ship rendezvous
6. Docking
7. Crew transfer
8. Last look at Mars
9. Trans-Earth injection burn

### The "Last Look" Moment

Emotional beat:
- Crew gathers at viewport
- Mars recedes
- Brief reflection dialogue
- What they accomplished
- What they're leaving behind

### Data Carried Forward

| Data | Impact on Phase 4 |
|------|------------------|
| Ship deterioration | Reliability for return |
| Remaining fuel | Can they make it? |
| Crew final state | Health/morale buffer |
| Science samples | Final score component |
| Time on Mars | Added travel time home |
| MAV salvage | Emergency parts? |

### Status Report

```
┌─────────────────────────────────────────────────────────────┐
│                 DEPARTURE STATUS                            │
│                                                             │
│  MARS MISSION SUMMARY                                       │
│  Sols on Surface: 156                                       │
│  Science Completed: 73%                                     │
│  Samples Collected: 47 kg                                   │
│  EVAs Conducted: 89                                         │
│                                                             │
│  RETURN JOURNEY PROFILE                                     │
│  Estimated Duration: 234 days                               │
│  Fuel Margin: 8%                                            │
│  Critical Concerns: Low spare parts, damaged O2 backup      │
│                                                             │
│  CREW FOR RETURN                                            │
│  ✓ Commander Torres                                         │
│  ✓ Engineer Kowalski                                        │
│  ✓ Dr. Okonkwo                                              │
│  ✓ Dr. Chen                                                 │
│                                                             │
│  "Setting course for Earth. ETA: 234 days."                 │
│                                                             │
│  [ BEGIN RETURN JOURNEY ]                                   │
└─────────────────────────────────────────────────────────────┘
```

---

## Transition 4: Earth Arrival (Phase 4 → Ending)

### The Moment

Earth fills the viewport. After everything, the blue marble is within reach. But the final hurdle - reentry - remains.

### Final Approach

```
┌─────────────────────────────────────────────────────────────┐
│                   EARTH APPROACH                            │
│                                                             │
│  Distance to Earth: 45,000 km                               │
│  Time to Atmosphere: 4 hours                                │
│                                                             │
│  FINAL SYSTEMS CHECK                                        │
│  Heat Shield: 71% integrity                                 │
│  Parachutes: 88% quality                                    │
│  Navigation: Locked                                         │
│  Communication: Restored                                    │
│                                                             │
│  ☎ "Artemis IV, this is Houston. We have you on tracking.   │
│     Looking good for reentry. Welcome home."                │
│                                                             │
│  Commander Torres: "Roger Houston. It's good to hear your   │
│                    voice. We're ready."                     │
│                                                             │
│  [ INITIATE REENTRY SEQUENCE ]                              │
└─────────────────────────────────────────────────────────────┘
```

### Reentry Sequence

A series of quality checks with dramatic presentation:

1. **Deorbit Burn**
   - Fuel check: Do you have enough?
   - Success/failure determination

2. **Atmospheric Interface**
   - "Radio blackout begins"
   - Tension pause

3. **Heat Shield Test**
   - Quality check against heat shield
   - Visual: Fire and plasma outside windows
   - Pass: Continue
   - Fail: Catastrophic ending

4. **Parachute Deployment**
   - Quality check
   - Visual: Chutes open (or don't)

5. **Splashdown/Landing**
   - Final success
   - Visual: Ocean landing, recovery ships approaching

### Success Cinematic

The emotional payoff:
1. Capsule floating in ocean
2. Recovery teams approaching
3. Hatch opens
4. Crew emerges, waves
5. Crowd cheering (mission control, public)
6. Crew reunion with families (optional)
7. Final score overlay

### Ending Screen

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│              M I S S I O N   C O M P L E T E                │
│                                                             │
│                      ★ GOLD RATING ★                        │
│                                                             │
│  CREW RETURNED: 4/4                                         │
│  Commander Torres    Dr. Okonkwo                            │
│  Engineer Kowalski   Dr. Chen                               │
│                                                             │
│  MISSION DURATION: 847 days                                 │
│                                                             │
│  SCIENCE SCORE: 73%                                         │
│  ✓ Primary Geology         ✓ Primary Atmosphere             │
│  ✓ Primary Ice Study       ○ Secondary Biosignature         │
│                                                             │
│  BUDGET: $2.4M under budget                                 │
│                                                             │
│  FINAL SCORE: 8,742                                         │
│                                                             │
│  "The Artemis IV mission will be remembered as one of       │
│   humanity's greatest achievements. The crew's discoveries  │
│   have changed our understanding of Mars forever."          │
│                                                             │
│  [ VIEW STATISTICS ]  [ CREDITS ]  [ PLAY AGAIN ]           │
└─────────────────────────────────────────────────────────────┘
```

---

## Transition Design Principles

### 1. Summarize, Don't Skip

Players should see the consequences of their decisions laid out clearly. Don't just flash "Loading Phase 2" - show them what they built and what it means.

### 2. Build Tension

Each transition should have a moment of uncertainty:
- Launch: Will the engines fire?
- Mars Arrival: Will we have enough fuel?
- Mars Departure: Will the MAV reach orbit?
- Earth Arrival: Will the heat shield hold?

### 3. Emotional Beats

Include character moments:
- Crew reactions
- Brief dialogue
- Personal reflections
- The weight of the moment

### 4. Data Transparency

Show players exactly what's carrying forward. No hidden penalties. If their choices in Phase 1 are going to haunt them in Phase 4, foreshadow it.

### 5. Agency at Thresholds

Where possible, give players a final decision at each transition:
- Delay launch?
- Landing site selection?
- Stay longer on Mars?
- Risky vs safe reentry?

### 6. Pacing Control

Let players control transition speed:
- Option to skip cinematics (on replay)
- But never skip data summaries
- Auto-continue for streamers/content creators

---

## Failure Transitions

When things go wrong, transitions become endings:

### Launch Failure
"The engines failed to ignite. The Artemis program is suspended pending investigation."

### Mars Orbital Failure
"Unable to achieve stable orbit. Artemis IV passed Mars and continued into deep space. Contact was lost after 73 days."

### MAV Failure
"The MAV engine failed during ascent. The crew remains on Mars. NASA is evaluating rescue options." (Game over, but haunting)

### Reentry Failure
"Contact was lost during reentry. Recovery teams found no survivors." (The worst ending - so close)

Each failure should still show statistics and offer the option to retry.
