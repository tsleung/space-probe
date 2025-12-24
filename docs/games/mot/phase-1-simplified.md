# Phase 1: Ship Building (Simplified Design)

**Core Fantasy:** Mission Planner making meaningful tradeoffs
**Design Philosophy:** 5-7 decisions that matter, not 50 that don't

## The Oregon Trail Principle

Oregon Trail's store worked because:
1. Clear categories (food, ammunition, spare parts)
2. Simple tradeoffs (more food = less ammunition)
3. Consequences felt later (ran out of food on day 47)
4. Quick decisions (under 5 minutes total)

We apply this to spacecraft construction.

## Decision Flow

```
┌─────────────────────────────────────────────────┐
│           MARS ODYSSEY TREK                     │
│         Mission Planning Phase                   │
├─────────────────────────────────────────────────┤
│                                                  │
│  1. CONSTRUCTION APPROACH    ────────►          │
│  2. ENGINE SELECTION         ────────►          │
│  3. SHIP CLASS              ────────►          │
│  4. LIFE SUPPORT            ────────►          │
│  5. CREW SELECTION          ────────►          │
│  6. SUPPLY LOADOUT          ────────►          │
│                                                  │
│  Budget: $650M    Days to Window: 75            │
└─────────────────────────────────────────────────┘
```

---

## Decision 1: Construction Approach

**The Question:** Where do we build the ship?

This is a new mechanic that creates interesting tradeoffs around mass, reliability, and time.

| Approach | Description | Tradeoffs |
|----------|-------------|-----------|
| **Earth-Built** | Traditional: build everything on Earth, launch assembled | Heavy (more fuel), Reliable, Proven |
| **Orbital Assembly** | Launch components, assemble at space station | Lighter, Risky assembly, Requires time in orbit |
| **Lunar Shipyard** | Build at Moon base, lower gravity launch | Lightest, Longest prep time, Newest tech |

**Layman explanation:**
> "Launching from Earth is like driving uphill with a full backpack. Building in space means less weight to escape Earth's gravity, but you're assembling furniture in a swimming pool."

**Power user detail:**
> "Earth launch: ~9.4 km/s delta-v to LEO. Lunar launch: ~2.4 km/s to escape. But orbital assembly has a 3-5% per-component failure rate during EVA integration."

### Mechanical Impact

| Approach | Mass Penalty | Reliability | Build Time | Cost |
|----------|--------------|-------------|------------|------|
| Earth-Built | +30% fuel needed | 95% base | Fast | $$ |
| Orbital Assembly | Normal | 85% base | Medium | $$$ |
| Lunar Shipyard | -20% fuel needed | 80% base | Slow | $$$$ |

---

## Decision 2: Engine Selection

**The Question:** How do we get there?

Simplified from 9 engines to 4 archetypes that represent real tradeoffs.

| Engine | Travel Time | Fuel Efficiency | Risk | Special |
|--------|-------------|-----------------|------|---------|
| **Chemical** | 8-9 months | Poor | Low | The reliable workhorse |
| **Ion Drive** | 6-7 months | Excellent | Medium | Needs space assembly |
| **Nuclear Thermal** | 4-5 months | Good | High | Radiation events possible |
| **Solar Sail** | 10-12 months | Perfect (no fuel) | Medium | Slow but fuel-free |

**Layman explanation:**
> "Chemical rockets are like a sprint - lots of power, burns fuel fast. Ion drives are a marathon - gentle push for months, sips fuel. Nuclear is the fast train with the 'don't touch' signs."

**Power user detail:**
> "Chemical: Isp ~450s, high thrust. Ion: Isp ~3000s, millinewton thrust. Nuclear thermal: Isp ~900s, enables faster Hohmann transfers. Solar sail: infinite Isp, but acceleration falls with 1/r² from Sun."

### What the player sees:

```
┌─────────────────────────────────────────────────┐
│  ENGINE SELECTION                               │
├─────────────────────────────────────────────────┤
│                                                  │
│  ○ CHEMICAL ROCKET                              │
│    "The Reliable Workhorse"                     │
│    ━━━━━━━━━━━━━━━━━━━━━━━━                     │
│    Trip: 8-9 months  │  Fuel: ████████░░        │
│    Risk: ██░░░░░░░░  │  Cost: $$                │
│                                                  │
│    Like a car with a full tank - proven,        │
│    predictable, but you'll need a lot of gas.   │
│                                                  │
├─────────────────────────────────────────────────┤
│  ○ ION DRIVE                                    │
│    "The Patient Sipper"                         │
│    ━━━━━━━━━━━━━━━━━━━━━━━━                     │
│    Trip: 6-7 months  │  Fuel: ██░░░░░░░░        │
│    Risk: ████░░░░░░  │  Cost: $$$               │
│                                                  │
│    Whisper-quiet electric propulsion. Uses      │
│    almost no fuel, but must be built in space.  │
│                                                  │
├─────────────────────────────────────────────────┤
│  ○ NUCLEAR THERMAL                              │
│    "The Hot Rod"                                │
│    ━━━━━━━━━━━━━━━━━━━━━━━━                     │
│    Trip: 4-5 months  │  Fuel: █████░░░░░        │
│    Risk: ██████░░░░  │  Cost: $$$$              │
│                                                  │
│    Splits atoms to heat propellant. Fast, but   │
│    radiation is no joke. Shorter exposure time. │
│                                                  │
└─────────────────────────────────────────────────┘
```

---

## Decision 3: Ship Class

**The Question:** How big is our vessel?

Instead of placing individual components, pick a ship class that bundles them.

| Class | Crew Comfort | Cargo Space | Durability | Notes |
|-------|--------------|-------------|------------|-------|
| **Capsule** | Cramped | Minimal | High | Apollo-style, tight but tough |
| **Standard** | Adequate | Moderate | Medium | Balanced approach |
| **Cruiser** | Comfortable | Spacious | Lower | More room, more to break |

**Layman explanation:**
> "Capsule is a camping trip in a tent. Standard is an RV. Cruiser is bringing the whole house - comfortable but more things can go wrong."

### Mechanical Impact

| Class | Morale Decay | Storage | Hull Strength | Mass |
|-------|--------------|---------|---------------|------|
| Capsule | +50% faster | 3,000 kg | 120% | Light |
| Standard | Normal | 5,000 kg | 100% | Medium |
| Cruiser | -30% slower | 8,000 kg | 80% | Heavy |

---

## Decision 4: Life Support Tier

**The Question:** How redundant are our survival systems?

This is the "insurance policy" decision.

| Tier | Description | O2 Recycling | Failure Risk |
|------|-------------|--------------|--------------|
| **Basic** | Single system | 80% | One failure = crisis |
| **Standard** | Primary + manual backup | 90% | Survivable failure |
| **Redundant** | Triple redundancy | 95% | Can lose two systems |

**Layman explanation:**
> "Basic is one air filter. Standard is two. Redundant is three plus a guy who knows how to hold his breath really well."

**Power user detail:**
> "Sabatier reactors for CO2→CH4+H2O, MOXIE for O2 generation. Redundant systems add 400kg mass but reduce MTBF-related mortality by 60%."

---

## Decision 5: Crew Selection

**The Question:** Who goes to Mars?

Pick 4 crew from a roster. Each has a specialty and a personality trait.

**Required Roles:**
- Commander (1) - Leadership, crisis management
- Pilot (1) - Navigation, landing, EVA
- Engineer (1) - Repairs, construction
- Specialist (1) - Scientist OR Medic

**Simplified Crew Display:**

```
┌─────────────────────────────────────────────────┐
│  CREW SELECTION                    4 of 4 slots │
├─────────────────────────────────────────────────┤
│                                                  │
│  COMMANDER (pick 1)                             │
│  ┌──────────────────┐  ┌──────────────────┐     │
│  │ Dr. Sarah Chen   │  │ Cmdr. Okonkwo    │     │
│  │ "Natural Leader" │  │ "The Stoic"      │     │
│  │                  │  │                  │     │
│  │ + Crew morale    │  │ + Stays calm     │     │
│  │ + Crisis mgmt    │  │ + Pilot backup   │     │
│  └──────────────────┘  └──────────────────┘     │
│                                                  │
│  PILOT (pick 1)                                 │
│  ┌──────────────────┐  ┌──────────────────┐     │
│  │ Lt. Reyes        │  │ Maj. Volkov      │     │
│  │ "Risk Taker"     │  │ "Cautious"       │     │
│  │                  │  │                  │     │
│  │ + Better outcomes│  │ + Fewer accidents│     │
│  │ - More accidents │  │ - Slower progress│     │
│  └──────────────────┘  └──────────────────┘     │
│                                                  │
└─────────────────────────────────────────────────┘
```

**Key Design:** Each crew choice is a meaningful tradeoff, not "better stats."

---

## Decision 6: Supply Loadout

**The Question:** What do we pack?

This is the classic Oregon Trail moment. Budget constrains total, player allocates.

**Categories:**
- **Food** - Days of rations (need ~500 days minimum round trip)
- **Water** - Liters reserve (recycling covers most, this is backup)
- **Spare Parts** - Repair capacity (0-3 major repairs possible)
- **Medical Supplies** - Treatment capacity
- **Science Equipment** - Bonus to Phase 3 experiments

**The Tradeoff:**
```
Budget Remaining: $50M
Cargo Capacity: 5,000 kg remaining

┌────────────────────────────────────────────────┐
│  SUPPLY LOADOUT                                │
├────────────────────────────────────────────────┤
│                                                 │
│  FOOD            [━━━━━━━━━━░░░░░]  650 days   │
│                  $15M / 1,500 kg                │
│                                                 │
│  WATER RESERVE   [━━━━━━░░░░░░░░░]  +30 days   │
│                  $5M / 800 kg                   │
│                                                 │
│  SPARE PARTS     [━━━━━━━━░░░░░░░]  2 repairs  │
│                  $20M / 600 kg                  │
│                                                 │
│  MEDICAL         [━━━━░░░░░░░░░░░]  Standard   │
│                  $8M / 200 kg                   │
│                                                 │
│  SCIENCE GEAR    [━━░░░░░░░░░░░░░]  Basic      │
│                  $2M / 400 kg                   │
│                                                 │
│  ──────────────────────────────────────────    │
│  TOTAL:          $50M / 3,500 kg    [LAUNCH]   │
└────────────────────────────────────────────────┘
```

---

## What We're NOT Doing

### Removed Complexity:
- ~~Hex grid placement~~ → Ship class selection
- ~~Component testing cycles~~ → Reliability built into tier choice
- ~~Quality percentages~~ → Simplified risk levels
- ~~Adjacency bonuses~~ → Bundled into ship class
- ~~Build time management~~ → Implied by approach choice

### Why:
1. Kids in classrooms need to finish in 10-15 minutes
2. Each decision should feel meaningful, not granular
3. Complexity emerges from decision *interactions*, not decision *count*

---

## Consequence Ripples

Every decision echoes through later phases:

| Phase 1 Decision | Phase 2 Impact | Phase 3 Impact | Phase 4 Impact |
|------------------|----------------|----------------|----------------|
| Earth-Built | More fuel management | Normal | Heavier return ship |
| Ion Drive | Longer but efficient | Standard arrival | Same engine home |
| Capsule Class | Morale drops faster | Less cargo for base | Tighter margins |
| Basic Life Support | Higher crisis risk | Same | Higher crisis risk |
| Risk-Taker Pilot | Wild events | Great EVAs, accidents | Exciting return |
| Low Spare Parts | Can't fix much | Limited repairs | Pray nothing breaks |

---

## UI Flow Timing

Target: 10-15 minutes for Phase 1

| Step | Time | Notes |
|------|------|-------|
| Intro/Context | 1 min | Mission briefing |
| Construction Approach | 1 min | Big picture choice |
| Engine Selection | 2 min | Core tradeoff |
| Ship Class | 1 min | Quick choice |
| Life Support | 1 min | Risk tolerance |
| Crew Selection | 3 min | The fun part |
| Supply Loadout | 3 min | Oregon Trail moment |
| Review & Launch | 1 min | Confirmation |

---

## Open Questions

1. **Difficulty:** Do we show different budgets, or same budget with different margins?
2. **Randomization:** Fixed crew roster or some randomization per playthrough?
3. **Tutorial:** First-time players get recommendations? Or let them fail?
4. **Visual Style:** Cards? Sliders? Dialog boxes?

---

## Next Steps

1. Design the UI mockups for each decision screen
2. Update data files to support simplified model
3. Build the Phase 1 scene in Godot
4. Wire up state management
5. Test with actual humans (classroom if possible)
