# Space Probe - Game Design Document

## Overview

A game similar to Oregon Trail set in near-future space exploration, using technology comparable to the movie "The Martian". Players manage a mission to Mars across four distinct phases.

## Core Design Philosophy

Drawing from legendary game designers:

**Sid Meier (Civilization):** "A game is a series of interesting decisions." Every phase should present meaningful choices with clear trade-offs. No optimal path - multiple viable strategies.

**Will Wright (SimCity):** Systems should be interconnected. Decisions in Phase 1 ripple through all subsequent phases. The ship you build determines what's possible on Mars.

**Hideo Kojima (Metal Gear):** Narrative tension through resource scarcity and time pressure. The crew aren't just stats - they're people with stories.

**Shigeru Miyamoto (Nintendo):** Easy to learn, difficult to master. Each phase should have simple core mechanics but deep optimization potential.

## Why Mars?

Mars is currently the closest available planet and relevant to current events. The mission involves landing on the planet, setting up a base, conducting scientific research, launching back into space, and returning to Earth.

## The Four Phases

| Phase | Core Fantasy | Primary Tension |
|-------|--------------|-----------------|
| [1. Ship Building](phase-1-ship-building.md) | NASA Project Manager | Budget vs Quality vs Time |
| [2. Travel to Mars](phase-2-travel-to-mars.md) | Submarine Captain | Resource Management vs Crew Morale |
| [3. Base Management](phase-3-base-management.md) | Colony Governor | Scientific Goals vs Survival |
| [4. Return Trip](phase-4-return-trip.md) | Desperate Survivor | Degraded Systems vs Hope |

See also: [Phase Transitions](phase-transitions.md)

## Win/Lose Conditions

### Victory Tiers (Sid Meier style - multiple win states)

| Tier | Name | Requirements |
|------|------|--------------|
| Gold | Perfect Mission | All 4 crew return, all experiments complete, under budget |
| Silver | Successful Mission | 3+ crew return, primary experiments complete |
| Bronze | Survival | At least 1 crew returns to Earth |
| Pyrrhic | Data Salvaged | Crew lost but scientific data transmitted to Earth |

### Failure States

- Ship fails to launch (Phase 1)
- Total crew loss en route (Phase 2)
- Base becomes unsustainable (Phase 3)
- Unable to return (Phase 4)

## Overarching Systems

### The Ripple Effect

Every phase inherits consequences from previous phases:

```
Ship Quality → Travel Reliability → Base Capability → Return Viability
     ↓              ↓                    ↓                  ↓
  Budget         Crew Health      Scientific Output    Final Score
```

### Crew System

4 crew members, each with:
- **Specialty:** Engineer, Scientist, Pilot, Medical
- **Stats:** Health, Morale, Skill Level
- **Relationships:** Bonds with other crew affect morale events
- **Personal Mission:** Optional side objective for bonus points

### Resource Categories

| Category | Phases Active | Description |
|----------|---------------|-------------|
| Budget | 1, 3 | Money for construction and resupply |
| Time | All | Days until launch window / mission milestones |
| Supplies | 2, 3, 4 | Food, water, oxygen, medical |
| Power | 2, 3, 4 | Solar/battery/reactor capacity |
| Morale | 2, 3, 4 | Crew mental state |
| Hull Integrity | 2, 4 | Ship structural health |

### The "Oregon Trail" DNA

What made Oregon Trail timeless:
1. **Meaningful preparation** - Buying supplies mattered
2. **Random events with player agency** - Events had choices, not just outcomes
3. **Permanent consequences** - Death was real, resources didn't respawn
4. **Clear progress indicator** - Always knew how far you'd come and how far to go
5. **Replayability through randomness** - Each playthrough felt different

We preserve all five in each phase.

## Technical Scope

- **Engine:** Godot
- **Art Style:** TBD
- **Target Platform:** TBD
- **Estimated Playtime:** 2-4 hours per complete mission

## Document Index

- [Phase 1: Ship Building](phase-1-ship-building.md)
- [Phase 2: Travel to Mars](phase-2-travel-to-mars.md)
- [Phase 3: Base Management](phase-3-base-management.md)
- [Phase 4: Return Trip](phase-4-return-trip.md)
- [Phase Transitions](phase-transitions.md)
