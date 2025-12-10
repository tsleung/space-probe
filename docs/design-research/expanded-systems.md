# Expanded Systems Vision

This document synthesizes all design research into a coherent vision for Space Probe's expanded feature set.

---

## Core Philosophy Additions

Beyond our original design pillars, we add:

**Tynan Sylvester (Rimworld):** "Stories emerge from systems interacting, not from scripted events." Let the mechanics create drama.

**Tarn Adams (Dwarf Fortress):** "Complexity creates depth." Interconnected systems generate unique situations no designer could script.

**Justin Ma (FTL):** "Every run is a story, even failures are interesting." Defeat should be as memorable as victory.

**Hidetaka Miyazaki (Dark Souls/Elden Ring):** "Earned triumph through meaningful challenge." Success feels better when it was hard.

---

## The Interconnected Web

Every system connects to every other system:

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  ┌──────────┐     ┌──────────┐     ┌─────────────┐             │
│  │ CREW     │────→│ EVENTS   │────→│ RELATIONSHIPS│            │
│  │ TRAITS   │     │          │     │              │            │
│  └────┬─────┘     └────┬─────┘     └──────┬──────┘            │
│       │                │                   │                   │
│       ▼                ▼                   ▼                   │
│  ┌──────────┐     ┌──────────┐     ┌─────────────┐            │
│  │ TASK     │────→│ CRISIS   │────→│ DECISIONS   │            │
│  │ PERFORM  │     │ OUTCOMES │     │             │            │
│  └────┬─────┘     └────┬─────┘     └──────┬──────┘            │
│       │                │                   │                   │
│       ▼                ▼                   ▼                   │
│  ┌──────────┐     ┌──────────┐     ┌─────────────┐            │
│  │ RESOURCE │←────│ SHIP     │←────│ FACTION     │            │
│  │ STATE    │     │ QUALITY  │     │ STANDING    │            │
│  └────┬─────┘     └────┬─────┘     └──────┬──────┘            │
│       │                │                   │                   │
│       └────────────────┴───────────────────┘                   │
│                        │                                       │
│                        ▼                                       │
│               ┌────────────────┐                               │
│               │ MISSION        │                               │
│               │ OUTCOME        │                               │
│               └────────────────┘                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

**Example Cascade:**

1. **Chen's perfectionist trait** → She spends extra time testing the oxygen system
2. **Extra testing** → Delays launch by 3 days
3. **Delayed launch** → Slightly worse trajectory
4. **Congress faction** → Unhappy about cost overrun
5. **But:** High-quality oxygen system → Survives solar storm on Day 187
6. **Storm survival** → Chen vindicated, relationship boost
7. **Crew rally around Chen** → Morale spike
8. **High morale** → Better performance in Mars operations
9. **Mission success** → Congress forgives delay, public loves story

Every seemingly small decision can cascade.

---

## The Four Pillars Expanded

### Pillar 1: Meaningful Crew (CK2 + State of Decay + The Last of Us)

**From Stat Blocks to People:**

| Before | After |
|--------|-------|
| Health: 85 | Chen hasn't slept well since her sister died |
| Morale: 72 | Martinez keeps looking at his daughter's photo |
| Skill: Engineering 80 | Tanaka learned from the best - and the worst |
| Status: Healthy | Rodriguez is hiding something |

**Key Systems:**
- **Traits** that affect behavior, not just stats
- **Personal arcs** that progress through the mission
- **Relationships** that evolve based on events
- **Quiet moments** that build attachment
- **Meaningful death** that honors investment

### Pillar 2: Consequential Politics (EU4 + Tropico + The Expanse)

**From Solo Mission to Political Reality:**

| Before | After |
|--------|-------|
| You build a ship | Congress debates your budget |
| You make decisions | NASA and Private Space disagree on approach |
| You succeed or fail | Public opinion affects future funding |
| Mission ends | Legacy affects next mission |

**Key Systems:**
- **7 factions** with competing interests
- **Standing** that unlocks/blocks options
- **Commander profile** shaped by choices
- **Political events** that create dilemmas
- **Faction persistence** across phases

### Pillar 3: Living Resources (SimTower + The Martian + Tropico)

**From Simple Meters to Complex Economy:**

| Before | After |
|--------|-------|
| Food: 200 days | Greenhouse yield depends on water, power, crew skill |
| Oxygen: OK | ISRU chain: Ice → Water → Electrolysis → O2 + H2 |
| Fuel: 80% | Sabatier process: CO2 + H2 → Methane → Fuel |
| Power: Fine | Grid management: Solar vs. demand vs. storage |

**Key Systems:**
- **Production chains** with dependencies
- **Facility efficiency** based on multiple factors
- **Power grid** requiring active management
- **ISRU** making Mars resources usable
- **Scarcity pressure** creating constant decisions

### Pillar 4: Emergent Stories (CK2 + Rimworld + FTL)

**From Scripted Events to Generated Narrative:**

| Before | After |
|--------|-------|
| Random event: Storm | Storm reveals Chen's fear, strains Martinez-Park, tests faction patience |
| Equipment breaks | Equipment breaks BECAUSE of earlier decision, fixed USING relationship |
| Mission succeeds | Mission succeeds through unique combination never scripted |
| You played | You have a story to tell |

**Key Systems:**
- **Event chains** that branch on choices
- **Character-driven events** tied to arcs
- **Story beats** at key moments
- **After-action reports** that narrate your playthrough
- **Callbacks** to earlier decisions

---

## System Details

### Crew System Summary

**Traits (25+ traits across 5 categories):**
```
Disposition: optimist, pessimist, stoic, passionate
Social:      introvert, extrovert, empathetic, reserved
Work:        perfectionist, pragmatist, methodical, creative
Stress:      steady_hands, tunnel_vision, adrenaline_junkie, freeze_prone
Moral:       utilitarian, protector, by_the_book, ends_justify
```

**Personal Arc (5 stages):**
```
FACADE → CRACKS → REVELATION → CRISIS → RESOLUTION
```

**Relationships (4 metrics):**
```
Trust + Respect + Affection + Understanding = Relationship Type
```

**Conflict Resolution:**
```
Mediation | Compromise | Authority | Avoidance
```

### Faction System Summary

**7 Factions:**
```
NASA | Private Space | Congress | International
Public Opinion | Crew Families | Scientific Community
```

**Standing Effects:**
```
0-20:  Hostile  (-20% budget, negative events)
21-40: Cold     (no support)
41-60: Neutral  (standard)
61-80: Friendly (bonuses)
81-100: Allied  (major bonuses)
```

**Commander Profile:**
```
Authoritarian | Democratic | Scientific | Pragmatic
```

### Resource System Summary

**ISRU Chain:**
```
ICE → Water → O2 + H2 → (+ CO2) → Methane → Rocket Fuel
```

**Efficiency Formula:**
```
Base × Crew Skill × Power Availability × Maintenance × Quality
```

**Base Levels:**
```
Surface: Solar, Comms, Landing
Level 0: Airlock, EVA, Storage
Level -1: Living, Common, Medical
Level -2: Lab, Workshop, Greenhouse
Level -3: Storage, Life Support, Power
Level -4: Emergency Shelter
```

### Narrative System Summary

**Event Chains:**
```
Trigger → Branch → Consequence → Follow-up
```

**Story Beats:**
```
First Mars View | Halfway | First EVA | The Long Night | Point of No Return | Earth Rising
```

**Generated Reports:**
```
Mission history → Key moments → Character arcs → Final outcome
```

---

## Implementation Roadmap

### Phase 1: Foundation (Essential)
*The minimum viable expanded experience*

**Crew:**
- 3 traits per crew (10 trait types)
- Simple trust relationships
- Basic death handling

**Factions:**
- 3 core factions (NASA, Congress, Public)
- Standing affects budget
- Simple events

**Resources:**
- Basic ISRU (water → oxygen only)
- Simple power management

**Narrative:**
- Event choices with consequences
- Key story beats

### Phase 2: Depth
*The "it feels like a real game" milestone*

**Crew:**
- Full trait library (25 traits)
- Complete relationship metrics
- Personal arcs (all 5 stages)
- 10 quiet moments

**Factions:**
- All 7 factions
- Commander profile
- Faction conflicts

**Resources:**
- Full ISRU chains
- Efficiency system
- Power grid management

**Narrative:**
- Event chains (branching)
- Character-driven events
- Callbacks

### Phase 3: Ambitious
*The "this is special" milestone*

**Crew:**
- Conflict system
- Grief mechanics
- Legacy effects
- Full dialogue system

**Factions:**
- Political events
- Inter-faction dynamics
- Standing consequences

**Resources:**
- Manufacturing chains
- Base building optimization
- Adjacent bonuses

**Narrative:**
- Multi-stage chains
- Generated reports
- News feed

**Meta:**
- Technology unlocks
- Achievement system
- Basic legacy

### Phase 4: Polish
*The "award-worthy" milestone*

**Crew:**
- Procedural backstory elements
- Dynamic arc adaptation
- 50+ quiet moments

**World:**
- Full lived-in universe
- Corporate players
- Historical texture

**Meta:**
- Full legacy system
- Multi-mission campaigns
- Community goals (if multiplayer)

### Phase 5: Dream
*The "legendary" milestone*

- Colonization endgame
- Generation ships
- Persistent world state
- Full mod support
- Procedural missions
- Multiplayer cooperation

---

## Success Metrics

**We'll know we succeeded when:**

1. **Players tell stories** - "Let me tell you about my Chen..."
2. **Deaths hurt** - Players reload or accept grief
3. **Decisions matter** - "I should have tested more"
4. **Every run is different** - Natural replayability
5. **Systems surprise us** - Emergent situations designers didn't script
6. **Players remember** - The mission stays with them

---

## The Dream

Imagine a player finishing Space Probe:

> "My first mission, I lost Martinez on Sol 45. Dust storm.
> He went out to secure the solar panels and never came back.
>
> Chen blamed herself. She'd approved the EVA.
> Her perfectionism had kept us alive for months,
> but that one time she rushed...
>
> The crew almost fell apart. Rodriguez and Park were fighting.
> Congress wanted to abort. The public was demanding answers.
>
> But we made it. We made it because of what Martinez taught us
> before he died. His daughter's drawing is still on my fridge
> in the game. I can't bring myself to remove it.
>
> When we landed back on Earth, Chen stepped out first.
> She looked at the sky - the sky she'd told me she missed
> that night at the viewport, Sol 22 - and she smiled.
>
> 'We did it,' she said. 'We did it for him.'
>
> That's when I knew I had to play again."

That's the game we're building.
