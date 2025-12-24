# MOT (Mars Odyssey Trek) - Game Design Document

**Last Updated:** 2024-12-23
**Core Fantasy:** NASA Mission Commander leading humanity's first crewed Mars mission
**Tagline:** *"The journey of a lifetime. Every decision matters."*
**Inspiration:** Oregon Trail, FTL, Kerbal Space Program, Apollo 13

---

## Overview

Mars Odyssey Trek is a narrative survival game about managing a crew of astronauts on the first human mission to Mars. The game spans four distinct phases, each with unique mechanics and challenges. Your decisions in one phase ripple forward, creating emergent stories of triumph and tragedy.

**Core Loop:** Build ship → Travel to Mars → Survive on surface → Return home

---

## Game Phases

### Phase 1: Ship Building
**Core Fantasy:** NASA Project Manager
**Duration:** ~30 minutes
**Feel:** Kerbal Space Program meets project management

You oversee construction of the Mars vessel at the Lunar Shipyard. The central tension is the "Triangle of Constraints":

```
      TIME
     /    \
  BUDGET----QUALITY
```

- **Rush** to hit the launch window? Quality suffers.
- **Obsess** over testing? Budget depletes or you miss the window.
- **Go cheap?** Components fail during transit.

**Key Mechanics:**
- Hex grid ship construction
- Component quality testing (40-95%)
- Crew hiring with traits/flaws
- Launch window countdown

### Phase 2: Travel to Mars
**Core Fantasy:** Crisis Manager in Space
**Duration:** 180+ in-game days
**Feel:** Oregon Trail + FTL + Overcooked

The journey to Mars operates in two distinct modes:

**Normal Mode (Event Management):**
- Turn-based with real-time elements
- Advance day → Resolve events → Manage resources → Assign crew
- Story events with weighted outcomes

**CRISIS Mode (Real-Time Emergency):**
- Pure real-time, no pausing
- 45-120 seconds of intense management
- Multiple simultaneous crises to resolve
- Crew pathfinding and item fetching

**Key Mechanics:**
- Resource management (O2, Water, Food, Power, Fuel)
- Crew health, morale, and relationships
- Component degradation and repair
- Ship interior tile-based movement
- EVA operations for external repairs

### Phase 3: Mars Surface Operations
**Core Fantasy:** Mars Base Commander
**Duration:** 30+ sols
**Feel:** Surviving Mars + The Martian

Establish operations on the Martian surface. Manage limited resources while conducting science and preparing for the return journey.

**Key Mechanics:**
- Surface EVAs and exploration
- Habitat management
- Science objectives
- Resource extraction (water ice, regolith)
- Return ship preparation

### Phase 4: Return Journey
**Core Fantasy:** Getting Everyone Home
**Duration:** 180+ in-game days
**Feel:** Phase 2 with higher stakes

The return trip with a depleted crew and worn equipment. Component failures are more likely, resources are scarcer, but you're closer to home.

**Key Mechanics:**
- Same as Phase 2 with degraded systems
- Earth reentry sequence
- Final scoring and legacy

---

## Core Systems

### Resource System

| Resource | Consumption | Critical At |
|----------|-------------|-------------|
| Oxygen | 1/crew/day | 0 = death |
| Water | 0.5/crew/day | 0 = death in 3 days |
| Food | 1/crew/day | 0 = death in 7 days |
| Power | Variable | 0 = systems offline |
| Fuel | Per maneuver | 0 = stranded |

### Crew System

Each crew member has:
- **Stats:** Health, Morale, Stress, Fatigue
- **Skills:** Engineering, Medical, Science, Piloting
- **Traits:** Positive modifiers (Calm, Resourceful)
- **Flaws:** Negative modifiers (Claustrophobic, Reckless)
- **Relationships:** Trust levels with other crew

### Component System

Ship components have:
- **Quality:** 0-100%, affects failure rate
- **Condition:** Degrades over time
- **Power Draw:** Daily consumption
- **Repair Cost:** Resources needed to fix

### Event System

Events have:
- **Triggers:** Day range, resource levels, crew state
- **Choices:** 2-4 options with different outcomes
- **Outcomes:** Weighted by crew skills, component quality
- **Consequences:** Immediate and delayed effects

---

## Victory Conditions

| Outcome | Criteria |
|---------|----------|
| **Perfect Mission** | All crew survive, all objectives complete |
| **Successful Mission** | Majority crew survive, primary objectives complete |
| **Pyrrhic Victory** | At least one crew survives to Earth |
| **Mission Failure** | All crew lost |

---

## Detailed References

For complete mechanics, see:
- `phase-1-ship-building.md` - Ship construction details
- `phase-2-systems.md` - Complete Phase 2 reference (CRISIS mode, tiles, EVA)
- `phase-3-base-management.md` - Surface operations
- `phase-4-return-trip.md` - Return journey specifics
- `phase-transitions.md` - State transfer between phases
- `balance-math.md` - Mathematical models and balance

---

## Known Issues / Future Work

See `projects/` for active implementation work.
