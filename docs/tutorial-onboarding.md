# Tutorial & Onboarding

How players learn Space Probe without reading a manual. The best tutorial is no tutorial - just clear design.

---

## Philosophy

### Show, Don't Tell
- Tooltips over text walls
- Learn by doing, not reading
- Mistakes are teachers

### Progressive Disclosure
- Phase 1 teaches Phase 1
- New mechanics introduced when needed
- No front-loading of information

### Respect Intelligence
- Players are smart
- Don't over-explain
- Let them discover depth

---

## First-Time Flow

### 1. Main Menu → New Game
```
┌─────────────────────────────────────────────────────────────┐
│                     SPACE PROBE                             │
│                                                             │
│              [ NEW MISSION ]                                │
│              [ CONTINUE ]     (greyed if no save)           │
│              [ SETTINGS ]                                   │
│              [ CREDITS ]                                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 2. Difficulty Selection
```
┌─────────────────────────────────────────────────────────────┐
│                   SELECT DIFFICULTY                         │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ STANDARD (Recommended for first playthrough)        │   │
│  │ The intended experience. Challenging but fair.      │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ RELAXED                                              │   │
│  │ More resources, fewer failures. Focus on the story. │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ VETERAN                                              │   │
│  │ Tighter margins, harsher consequences.              │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 3. Mission Briefing (Sets Context)
```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│                    MISSION BRIEFING                         │
│                                                             │
│  The year is 2035.                                          │
│                                                             │
│  You are the Mission Director for humanity's first          │
│  crewed mission to Mars.                                    │
│                                                             │
│  Your job:                                                  │
│  • Build a ship that can make the journey                   │
│  • Keep your crew alive for 2+ years                        │
│  • Conduct scientific research on Mars                      │
│  • Bring everyone home                                      │
│                                                             │
│  Your resources are limited.                                │
│  Your decisions have consequences.                          │
│  Your crew is counting on you.                              │
│                                                             │
│                    [ BEGIN MISSION ]                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Ship Building Tutorial

**Approach:** Guided first component, then let them explore.

### Step 1: The Cockpit (Forced First)
```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  "Every ship needs a cockpit. Let's start there."          │
│                                                             │
│  ← The COCKPIT is highlighted in the component list         │
│                                                             │
│  Click to select it.                                        │
│                                                             │
│  [Cockpit component pulses gently]                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Step 2: Placement
```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  "Drag the cockpit to the hex grid to place it."           │
│                                                             │
│  The cockpit should be at the front of your ship.           │
│                                                             │
│  [Valid hexes glow, invalid hexes dim]                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Step 3: Quality Introduction
```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  "Your cockpit starts at 55% quality."                      │
│                                                             │
│  Higher quality = fewer failures during the mission.        │
│                                                             │
│  Click TEST to improve quality.                             │
│  (Costs time and money)                                     │
│                                                             │
│  [TEST button highlighted]                                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Step 4: Budget and Time
```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  "Notice your budget decreased."                            │
│                                                             │
│  Budget: $650M → $594M                                      │
│  Days remaining: 75 → 73                                    │
│                                                             │
│  Every test costs money and time.                           │
│  But launching untested components is risky.                │
│                                                             │
│  [Budget and countdown highlighted]                         │
│                                                             │
│                  [ GOT IT ]                                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Step 5: Freedom
```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  "Now build your ship."                                     │
│                                                             │
│  Required:                                                  │
│  • Engine (choose wisely - it affects travel time)          │
│  • 4 Crew Rooms (one per astronaut)                         │
│  • Cargo bay (for supplies)                                 │
│  • MAV (to get home from Mars)                             │
│                                                             │
│  Optional but recommended:                                  │
│  • Cafeteria, Gym, Medical Bay                              │
│                                                             │
│  Hover over any component for details.                      │
│  Press [?] anytime for help.                                │
│                                                             │
│                  [ START BUILDING ]                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

**After this, no more forced tutorials.** Player explores freely.

---

## Phase 2: Travel Tutorial

**Approach:** First day is guided, then hands-off.

### Day 1 Auto-Pause
```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  "Launch successful. The journey begins."                   │
│                                                             │
│  Your crew:                                                 │
│  • Santos (Commander) - navigation, leadership              │
│  • Chen (Engineer) - repairs, maintenance                   │
│  • Okonkwo (Scientist) - experiments, analysis              │
│  • Kowalski (Medical) - health, morale                      │
│                                                             │
│  Assign daily tasks, manage resources, and respond          │
│  to events.                                                 │
│                                                             │
│  Mars is 200 days away.                                     │
│                                                             │
│                  [ CONTINUE ]                               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### First Event (Day 3-5, Guaranteed Easy One)
```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  ── FIRST EVENT ──                                          │
│                                                             │
│  "Routine Maintenance Alert"                                │
│                                                             │
│  The water recycler needs a filter change.                  │
│  This is normal - just assign an engineer.                  │
│                                                             │
│  [Choices shown with clear consequences]                    │
│                                                             │
│  This is your first decision event.                         │
│  Read the options carefully - there's usually no            │
│  "perfect" choice.                                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Phase 3: Mars Base Tutorial

### Landing Moment
```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  "Touchdown confirmed. Welcome to Mars."                    │
│                                                             │
│  Your base modules have been deployed.                      │
│                                                             │
│  New objectives:                                            │
│  • Keep the crew alive (food, water, oxygen, power)         │
│  • Conduct scientific research (your reason for being here) │
│  • Prepare the MAV for return (fuel production)             │
│                                                             │
│  The return window opens in 120 sols.                       │
│  You can leave earlier, but you'll miss science.            │
│  Stay too long, and the window closes.                      │
│                                                             │
│                  [ EXPLORE BASE ]                           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### EVA Introduction (First EVA)
```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  "Time for your first EVA (spacewalk on Mars)."            │
│                                                             │
│  EVAs let you:                                              │
│  • Collect samples for research                             │
│  • Repair exterior equipment                                │
│  • Explore the terrain                                      │
│                                                             │
│  But they have risks:                                       │
│  • Suit failures                                            │
│  • Dust storms                                              │
│  • Distance from base                                       │
│                                                             │
│  Always check the weather before sending crew outside.      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Phase 4: Return Tutorial

### Departure Moment
```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  "MAV launch successful. Heading home."                     │
│                                                             │
│  The return journey is different:                           │
│  • Your ship has wear from the outbound trip                │
│  • Supplies are whatever you have left                      │
│  • No resupply possible - what you have is what you have    │
│                                                             │
│  Watch for:                                                 │
│  • System degradation (things break down)                   │
│  • Resource scarcity (may need rationing)                   │
│  • Crew fatigue (they're tired)                             │
│                                                             │
│  Earth is waiting.                                          │
│                                                             │
│                  [ BEGIN RETURN ]                           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Contextual Help System

### Tooltip Format
```
┌─────────────────────────────────┐
│ COMPONENT QUALITY               │
│ ─────────────────────────────── │
│ How reliable this component is. │
│                                 │
│ Higher quality = fewer failures │
│ during the mission.             │
│                                 │
│ Improve with testing (costs     │
│ time and money).                │
│                                 │
│ 70%+ recommended for safety.    │
└─────────────────────────────────┘
```

### Help Menu (? Button)
```
┌─────────────────────────────────────────────────────────────┐
│                      HELP                                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  CURRENT PHASE: Ship Building                               │
│                                                             │
│  ▸ What should I do?                                        │
│  ▸ How does quality work?                                   │
│  ▸ What are the required components?                        │
│  ▸ How does the launch window work?                         │
│  ▸ Tips for this phase                                      │
│                                                             │
│  ─────────────────────────────────────                      │
│                                                             │
│  ▸ Controls                                                 │
│  ▸ Game concepts                                            │
│  ▸ About Space Probe                                        │
│                                                             │
│                    [ CLOSE ]                                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Learning Through Failure

### First Death (If It Happens)
```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  Chen has died.                                             │
│                                                             │
│  [Portrait, greyed out]                                     │
│                                                             │
│  "James Chen, 38. Engineer. Father."                        │
│                                                             │
│  Cause: Radiation exposure during solar event.              │
│                                                             │
│  The remaining crew must continue without him.              │
│  His expertise will be missed.                              │
│                                                             │
│  ─────────────────────────────────────                      │
│                                                             │
│  Death in Space Probe is permanent.                         │
│  Your choices matter.                                       │
│                                                             │
│                    [ CONTINUE ]                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Mission Failure (Learning Moment)
```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  MISSION FAILED                                             │
│                                                             │
│  What went wrong:                                           │
│                                                             │
│  • Life support quality was only 52%                        │
│    → Consider more testing in Phase 1                       │
│                                                             │
│  • No backup systems installed                              │
│    → Redundancy saves lives                                 │
│                                                             │
│  • Power reserves depleted on Day 156                       │
│    → Watch power consumption vs generation                  │
│                                                             │
│  Every failure teaches something.                           │
│  Ready to try again?                                        │
│                                                             │
│         [ TRY AGAIN ]         [ MAIN MENU ]                 │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## What We DON'T Do

### No Mandatory Tutorial
- Skip button always available
- Returning players can jump straight in

### No Tutorial Missions
- Real mission from the start
- Difficulty selector handles learning curve

### No Information Overload
- One concept at a time
- Details available but not forced

### No Hand-Holding
- Show information, don't make decisions
- Player agency always respected

---

## Simplicity Verification

Every tutorial element must pass:
- [ ] Can it be skipped?
- [ ] Is it under 3 sentences?
- [ ] Does it teach ONE thing?
- [ ] Is it shown at the right moment?
- [ ] Can the player discover this naturally?
