# Expansion: First Contact War

**Core Fantasy:** Humanity's desperate last stand against overwhelming alien invasion
**Inspiration:** Halo Reach (noble sacrifice, losing battle fought with honor)
**Gameplay:** Mindustry (production chains) + Sins of a Solar Empire (fleet allocation)

---

## Story Setup

Year 2157. The Mars colony has thrived for a century. Then the Heralds arrived.

First contact was not peaceful. An alien armada entered the solar system and began systematically destroying human outposts. Earth's orbital defense fleet was shattered in hours.

You are the Emergency Production Coordinator for the Sol Defense Authority. Your job: transform civilian industry into war production, manage scarce resources, and allocate what little fleet we can muster to slow the Herald advance.

**You will not win.** This is Reach. The goal is to buy time for evacuation ships to escape, preserve what humanity you can, and make the enemy pay for every AU they take.

---

## Core Loop (Turn = 1 Week)

```
1. PRODUCTION PHASE
   - Assign factories to production chains
   - Resources flow: Raw → Refined → Components → Ships/Weapons

2. ALLOCATION PHASE
   - Assign completed ships to defense zones
   - Choose: defend civilians, delay enemy, or evacuate assets

3. COMBAT PHASE (Auto-resolved)
   - Fleet strength vs Herald attack strength
   - Losses calculated, zones fall or hold

4. HERALD ADVANCE
   - Enemy pushes toward Earth
   - New attack vectors revealed

5. EVACUATION CHECK
   - Civilian ships escape if routes are clear
   - Running tally of lives saved
```

---

## Victory Conditions

**You cannot stop the Heralds.** Earth will fall. Victory is measured by:

| Tier | Lives Evacuated | Description |
|------|-----------------|-------------|
| LEGENDARY | 500M+ | "They will remember what we did here" |
| HEROIC | 200-500M | "Enough to rebuild" |
| PYRRHIC | 50-200M | "A remnant survives" |
| TRAGIC | 10-50M | "Scattered survivors" |
| ANNIHILATION | <10M | "Humanity's light flickers" |

The game ends when Earth falls (typically turn 20-30).

---

## Resources (Simplified Mindustry)

### Raw Resources (Gathered from zones you control)
- **Ore** - Asteroid mining, planetary extraction
- **Energy** - Solar collectors, fusion plants
- **Rare Elements** - Specific locations only

### Production Chains

```
ORE ──────────────► STEEL ─────────────► HULL PLATES
                                              │
ENERGY ───────────► ELECTRONICS ──────────────┤
                                              │
RARE ELEMENTS ────► WEAPON CORES ─────────────┤
                                              ▼
                                         WARSHIPS
```

### Buildings (Assign workers to each)
| Building | Input | Output | Workers |
|----------|-------|--------|---------|
| Mine | - | 10 Ore/turn | 100 |
| Refinery | 10 Ore | 5 Steel | 50 |
| Power Plant | - | 20 Energy | 50 |
| Electronics Factory | 5 Energy | 3 Electronics | 100 |
| Weapons Lab | 5 Rare + 5 Energy | 2 Weapon Cores | 200 |
| Shipyard | 10 Steel + 5 Electronics + 2 Weapons | 1 Frigate | 500 |

### Workforce
- Start with 10M workers across Sol system
- Workers die when zones fall
- Can evacuate workers (but lose production)
- Morale affects efficiency

---

## Fleet Units (Simplified Sins)

| Unit | Cost | Combat Power | Special |
|------|------|--------------|---------|
| Frigate | 10S + 5E + 2W | 10 | Cheap, fast to build |
| Cruiser | 30S + 15E + 8W | 40 | Backbone of fleet |
| Carrier | 50S + 30E + 5W | 25 | +50% to zone defense |
| Dreadnought | 100S + 50E + 20W | 150 | Takes 3 turns to build |

### Fleet Allocation
Each turn, assign ships to zones:
- **DEFEND** - Full combat power vs attackers
- **DELAY** - Half power, but slows Herald advance by 1 turn if successful
- **ESCORT** - Protects evacuation convoys (no combat)

---

## The Map (7 Zones)

```
                    ┌─────────────┐
                    │   KUIPER    │ ← Heralds enter here
                    │  (Rare El.) │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
        ┌─────┴─────┐ ┌────┴────┐ ┌─────┴─────┐
        │  JUPITER  │ │ ASTEROID│ │  SATURN   │
        │  (Energy) │ │  (Ore)  │ │  (Rare)   │
        └─────┬─────┘ └────┬────┘ └─────┬─────┘
              │            │            │
              └────────────┼────────────┘
                           │
                    ┌──────┴──────┐
                    │    MARS     │
                    │ (Shipyards) │
                    └──────┬──────┘
                           │
                    ┌──────┴──────┐
                    │    EARTH    │ ← Protect at all costs
                    │ (Population)│
                    └─────────────┘
```

Each zone has:
- **Resources** produced
- **Population** (workers + civilians)
- **Infrastructure** (buildings)
- **Defense Fleet** (assigned ships)

When a zone falls:
- All resources, population, infrastructure lost
- Adjacent zones exposed to attack

---

## Herald Forces

The Heralds attack in waves, growing stronger each turn:

| Turn | Attack Strength | Zones Targeted |
|------|-----------------|----------------|
| 1-5 | 50-100 | Kuiper only |
| 6-10 | 150-300 | Outer planets |
| 11-15 | 400-600 | Inner system |
| 16-20 | 800-1200 | Mars + Earth |
| 21+ | 1500+ | Final assault |

**Herald Behavior:**
- Always attack weakest adjacent zone
- If repelled, attack same zone next turn with +50% strength
- Occasionally split forces for multi-zone attack

---

## Events (One per turn)

Simple choice events that create dilemmas:

**"Refugee Fleet"**
> A civilian convoy from Neptune requests escort. 50,000 people.
- A) Divert 3 frigates to escort (lose combat power)
- B) Tell them to wait (30% chance they're destroyed)
- C) Order them to shelter in place (they're stuck)

**"Weapons Cache"**
> Hidden military stockpile found on Titan. Worth 20 Weapon Cores.
- A) Retrieve it (costs 2 frigates, 1 turn)
- B) Destroy it (deny to enemy if zone falls)
- C) Leave it (risk enemy capture)

**"Defector"**
> A Herald ship is broadcasting surrender signals.
- A) Accept surrender (gain intel: +10% combat effectiveness)
- B) Destroy it (could be trap, but safe)
- C) Ignore it (it leaves)

---

## UI Layout

```
┌────────────────────────────────────────────────────────────────┐
│  TURN 12 / ~8 TURNS UNTIL EARTH ASSAULT    [LIVES SAVED: 127M] │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                      SYSTEM MAP                          │  │
│  │                                                          │  │
│  │                    [KUIPER - FALLEN]                     │  │
│  │                          │                               │  │
│  │         [JUPITER]────[ASTEROID]────[SATURN - UNDER ATK]  │  │
│  │              │            │            │                 │  │
│  │              └────────[MARS]───────────┘                 │  │
│  │                         │                                │  │
│  │                      [EARTH]                             │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                │
├───────────────────────┬────────────────────────────────────────┤
│  PRODUCTION           │  FLEET ALLOCATION                      │
│  ───────────────────  │  ────────────────────────────────────  │
│  Ore: 45 (+15/turn)   │  Saturn Defense:  12 Frigates (120)    │
│  Steel: 23 (+8/turn)  │  Mars Defense:    4 Cruisers (160)     │
│  Energy: 67 (+20/turn)│  Evac Escort:     2 Frigates (20)      │
│  Electronics: 12      │  Reserve:         1 Dreadnought (150)  │
│  Weapon Cores: 4      │                                        │
│  ───────────────────  │  HERALD ATTACK: 280 → SATURN           │
│  Building: Cruiser    │  Defender Strength: 120                │
│  Progress: 2/3 turns  │  STATUS: WILL FALL                     │
├───────────────────────┴────────────────────────────────────────┤
│  [END TURN]  [REALLOCATE FLEET]  [PRODUCTION ORDERS]  [EVAC]   │
└────────────────────────────────────────────────────────────────┘
```

---

## Implementation Simplicity

### What we're NOT doing:
- No real-time combat
- No unit positioning/tactics
- No tech tree
- No diplomacy
- No detailed ship customization

### What we ARE doing:
- Turn-based resource management
- Simple production chains (5 resources, 6 buildings)
- Fleet as numbers (combat power totals)
- Auto-resolved combat (compare numbers)
- 7 static zones
- ~10 events
- Single win metric (lives evacuated)

### State Structure
```gdscript
FCWState = {
    turn: int,
    resources: {ore, steel, energy, electronics, weapons},
    zones: {zone_id: {status, population, buildings, fleet}},
    fleet: {frigates, cruisers, carriers, dreadnoughts},
    in_production: [{type, turns_remaining}],
    lives_evacuated: int,
    herald_strength: int,
    game_over: bool
}
```

---

## Emotional Arc

1. **Hope** (Turns 1-5): "We can hold them"
2. **Realization** (Turns 6-10): "We're losing"
3. **Desperation** (Turns 11-15): "Save who we can"
4. **Sacrifice** (Turns 16-20): "Make it count"
5. **Legacy** (End): "They will remember"

The tone is somber but not nihilistic. You're not a victim - you're a hero buying time. Every life saved matters. Every turn you hold is a victory.

*"Spartans never die. They're just missing in action."*
