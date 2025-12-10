# Phase 2: Travel to Mars

**Core Fantasy:** Submarine Captain
**Primary Tension:** Resource Management vs Crew Morale
**Design Inspiration:** FTL meets The Martian's transit sequences

## Overview

The journey to Mars. Six months (minimum) in a metal tube with four people. The ship you built in Phase 1 now reveals its strengths and weaknesses. This phase is about managing the slow burn of resources and sanity while responding to crises.

## The Submarine Captain Fantasy

Why "submarine captain"?
- Isolated from help (no resupply possible)
- Every resource is finite and precious
- Crew psychology is as critical as ship systems
- Long periods of routine punctuated by emergencies
- Decisions have life-or-death consequences

## Time Progression

### The Journey Display

```
EARTH =====[SHIP]=================================== MARS
      Day 47/183                              136 days remaining
```

- Clear progress indicator (Oregon Trail DNA)
- Daily tick system - each "day" is a gameplay turn
- Speed varies based on engine type and fuel usage
- Can adjust speed on VASIMR engines (trade speed for fuel)

### Daily Routine

Each day, the player:
1. Reviews overnight status report
2. Assigns crew to daily tasks
3. Addresses any events/crises
4. Manages resource allocation
5. Advances to next day (or auto-advance for routine periods)

### Time Compression

- "Routine mode" - auto-advance days when nothing eventful
- Player can set alerts (wake me if X happens)
- Events interrupt auto-advance
- Full manual control always available

## Resource Management

### Primary Resources

| Resource | Depletion Rate | Consequences of Shortage |
|----------|----------------|-------------------------|
| **Food** | Per crew/day | Starvation, morale loss, eventually death |
| **Water** | Per crew/day | Dehydration, health loss |
| **Oxygen** | Ship-wide/day | Suffocation (critical) |
| **Power** | System-dependent | Systems go offline |
| **Fuel** | Speed-dependent | Can't decelerate at Mars |

### Secondary Resources

| Resource | Function | Notes |
|----------|----------|-------|
| **Medical Supplies** | Treat injuries/illness | Finite, no resupply |
| **Spare Parts** | Repair components | Quality affects repair effectiveness |
| **Morale Items** | Entertainment, comfort | Personal items, games, movies |

### The Oxygen Cycle

- Oxygenator converts CO2 back to O2
- Efficiency based on component quality
- Damage/malfunction = emergency
- Backup systems (if installed) provide buffer

### Power Management

```
POWER BUDGET
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Generation: 45 kW (solar panels)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Life Support:   20 kW [CRITICAL]
Navigation:      5 kW [CRITICAL]
Lighting:        3 kW [  ]
Heating:         8 kW [  ]
Gym:             2 kW [  ]
Lab:             4 kW [  ]
Comms:           2 kW [  ]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Remaining:       1 kW → Battery
```

Players can disable non-critical systems to conserve power during emergencies.

## Crew Management

### Daily Task Assignment

Each crew member can perform one primary task per day:

| Task | Effect | Who's Best |
|------|--------|------------|
| **Pilot Watch** | Required for navigation | Pilot |
| **Maintenance** | Prevents degradation | Engineer |
| **Health Check** | Early illness detection | Medical |
| **Experiments** | Prep for Phase 3 science | Scientist |
| **Repair** | Fix damaged components | Engineer |
| **Rest** | Recover health/morale | Anyone |
| **Exercise** | Maintain fitness | Anyone (Gym required) |
| **Social** | Improve relationships | Anyone |

### Crew Stats

| Stat | Range | Effects |
|------|-------|---------|
| **Health** | 0-100 | Below 50 = impaired. 0 = death |
| **Morale** | 0-100 | Below 30 = conflicts. Below 10 = breakdown |
| **Fatigue** | 0-100 | Above 70 = errors increase |

### Crew Relationships

- Crew members develop relationships over time
- Positive bonds = morale support during crises
- Negative bonds = conflicts, morale drain
- Isolation events can fracture relationships

### Morale Events

Low morale triggers events:
- Crew conflict (productivity loss)
- Depression (stat reduction)
- Insubordination (crew refuses tasks)
- Breakdown (crew member incapacitated)

High morale triggers:
- Crew bonding (relationship improvement)
- Inspiration (task efficiency bonus)
- Morale spreads (lifts other crew members)

## Event System

### Event Categories

**Ship Events:**
- Component malfunction (quality-based probability)
- Hull breach (micrometeorite)
- Power fluctuation
- Navigation error

**Crew Events:**
- Illness (space flu, radiation sickness)
- Injury (accident during task)
- Conflict between crew members
- Personal crisis (news from home)
- Cabin fever

**Space Events:**
- Solar flare (radiation + power surge)
- Communication blackout
- Cosmic ray burst
- Asteroid proximity alert
- Earth/home transmission (morale event)

### Event Structure (Oregon Trail DNA)

Events present choices, not just outcomes:

```
┌─────────────────────────────────────────┐
│ SOLAR FLARE DETECTED                    │
│                                         │
│ A solar flare will reach the ship in    │
│ 6 hours. Radiation levels will spike.   │
│                                         │
│ Options:                                │
│ [A] Shelter in cargo hold               │
│     - Crew safe, 12 hour productivity   │
│       loss                              │
│                                         │
│ [B] Continue operations with shielding  │
│     - Minor radiation exposure          │
│     - Risk of equipment damage          │
│                                         │
│ [C] Emergency power to shielding        │
│     - Full protection                   │
│     - Drains 2 days of battery          │
└─────────────────────────────────────────┘
```

### Cascading Failures

One problem can trigger others:
- Solar flare → Power surge → Oxygenator damage → Oxygen shortage
- Quality matters: High-quality components resist cascades

## Component Reliability

### The Quality Check

When components are stressed, roll against quality:
- Component quality 80% = 80% chance of passing stress
- Failed checks = damage or malfunction
- Multiple failures = component destroyed

### Component States

| State | Function | Icon |
|-------|----------|------|
| **Operational** | Working normally | Green |
| **Degraded** | Reduced efficiency | Yellow |
| **Damaged** | Minimal function | Orange |
| **Critical** | About to fail | Red |
| **Destroyed** | Non-functional | Black |

### Repair System

- Repairs require time + spare parts + crew assignment
- Repair quality depends on: Engineer skill, parts quality, component complexity
- Some damage is permanent (quality ceiling reduced)

## The Mars Approach

### Final Weeks

As Mars approaches:
- Tension builds (narrative events)
- Deceleration burn required (fuel critical)
- Mars orbit insertion (piloting check)
- Landing site selection (affects Phase 3)

### Landing Sequence

The transition to Phase 3:
1. Orbit achieved
2. Landing site selected
3. Cargo deployed (base components)
4. Crew descent in MAV
5. Phase 3 begins

## Failure States

### Mission-Ending Events

- Total oxygen failure (no backup)
- Total crew loss
- Unable to decelerate (fly past Mars)
- Ship structural failure

### Partial Failures

- Crew member death (continue with 3)
- Component destruction (adapt)
- Cargo loss (Phase 3 harder)
- MAV damage (Phase 4 in jeopardy)

## UI Elements

### Main Display

- Journey progress bar (top)
- Ship status overview (left) - component health at a glance
- Resource gauges (right) - fuel, O2, food, water, power
- Crew status cards (bottom) - health, morale, current task
- Event log (scrolling feed)
- Days remaining counter

### Ship View

- Hex layout from Phase 1
- Color-coded component status
- Click component for details/repair options

### Crew Detail View

- Individual stat bars
- Relationship web
- Task history
- Personal mission progress

## Replayability Elements

- Random event sequences
- Quality variations from Phase 1 construction
- Engine choice affects event types (nuclear = radiation events)
- Crew personality combinations
- Multiple valid resource strategies
- Optional speed records (can you do it in 5 months?)
