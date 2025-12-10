# Phase 1: Ship Building

**Core Fantasy:** NASA Project Manager
**Primary Tension:** Budget vs Quality vs Time
**Design Inspiration:** Kerbal Space Program meets project management sim

## Overview

The player oversees construction of the Mars vessel at the Lunar Shipyard. This phase establishes the foundation for the entire mission - every decision here echoes through subsequent phases.

## The Triangle of Constraints

```
        TIME
       /    \
      /      \
   BUDGET----QUALITY
```

Players cannot optimize all three. This creates meaningful decisions:
- Rush to hit the launch window? Quality suffers.
- Obsess over testing? Budget depletes or you miss the window.
- Go cheap? Components fail during transit.

## Setting

**Location:** Lunar Orbital Shipyard (Zero-G construction facility)

Why the Moon?
- Zero-G assembly allows massive ship structures
- Lower launch costs for materials from Earth
- Narrative justification for unique building challenges

## Core Mechanics

### The Countdown

A prominent timer shows days until optimal launch window:
- **Optimal window:** 6-month travel time to Mars
- **Each day late:** Adds travel time (exponential penalty)
- **Too early:** Ship sits idle, accumulating holding costs and risks

### Hex Grid Construction

Players place ship components on a hex grid:

```
      [  ] [  ] [  ]
    [  ] [CK] [EN] [  ]
      [CR] [CF] [CR]
    [  ] [GY] [CG] [  ]
      [HG] [MV] [  ]
```

**Placement Rules:**
- Components must connect (no floating pieces)
- Some components have adjacency bonuses/penalties
- Ship must be balanced for proper thrust alignment
- Grid size determines maximum ship capacity

### Component System

Each component has:
| Attribute | Description |
|-----------|-------------|
| Base Cost | Initial purchase price |
| Build Time | Days to construct |
| Quality Rating | 0-100%, affects reliability |
| Test Cost | Money per quality point |
| Weight | Affects fuel requirements |
| Power Draw | Daily power consumption |

### Quality & Testing

**The Testing Loop:**
1. Component is built at base quality (40-60%)
2. Player allocates testing budget and time
3. Each test cycle improves quality but may reveal defects
4. Defects require additional time/money to fix
5. Diminishing returns - getting from 90% to 95% costs more than 60% to 80%

**Quality Impact:**
| Quality | Failure Rate During Transit |
|---------|----------------------------|
| < 50% | Guaranteed failures |
| 50-70% | High risk of failures |
| 70-85% | Moderate risk |
| 85-95% | Low risk |
| 95%+ | Minimal risk (never zero) |

## Ship Components

### Required Components

| Component | Function | Special Rules |
|-----------|----------|---------------|
| **Cockpit** | Navigation, ship control | Must have line-of-sight to front |
| **Engine** | Propulsion | Determines travel speed & fuel needs |
| **Crew Room** (x4) | Houses 1 crew member each | Low quality = morale penalties |
| **Cafeteria** | Food preparation, social space | Adjacent to Crew Rooms = morale bonus |
| **Cargo** | Stores supplies and equipment | Size determines supply capacity |
| **Hangar** | Houses rovers, equipment | Required for surface operations |
| **MAV** | Mars Ascent Vehicle | Required for return mission |

### Optional Components

| Component | Function | Trade-off |
|-----------|----------|-----------|
| **Gym** | Maintains crew fitness | Reduces health degradation in transit |
| **Medical Bay** | Treats injuries/illness | Insurance against crew loss |
| **Laboratory** | Early experiment prep | Bonus to Phase 3 science |
| **Observation Deck** | Morale facility | High cost, high morale benefit |
| **Backup Systems** | Redundancy | Weight penalty, failure insurance |

## Engine Selection

The engine choice is the most consequential decision in Phase 1.

| Engine | Speed | Fuel Efficiency | Cost | Risk | Special |
|--------|-------|-----------------|------|------|---------|
| **Traditional** | Slow | Poor | Low | Low | Available immediately |
| **Hermes (Ion)** | Medium | Excellent | High | Low | Must assemble in space |
| **Hall Thruster** | Fast | Excellent | High | Medium | Complex testing required |
| **Nuclear Fission** | Fast | Good | Very High | High | Containment leak risk |
| **Solar Sail** | Variable | N/A (no fuel) | Medium | Medium | Dependent on solar proximity |
| **Laser Sail** | Fast | N/A | Very High | Low | Requires Earth-based laser array |
| **Pulsed Plasma** | Medium | Good | Medium | Medium | Balanced option |
| **MPD Thruster** | Fast | Good | High | Medium | High power requirements |
| **VASIMR** | Variable | Excellent | Very High | Low | Can adjust speed/efficiency ratio |

### Engine Selection Consequences

Your engine choice affects:
- **Phase 2:** Travel time, fuel management, random event types
- **Phase 3:** How much fuel remains for emergencies
- **Phase 4:** Whether return trip is even possible with remaining fuel

## Budget System

### Income Sources
- Initial NASA grant (difficulty setting)
- Milestone bonuses (meeting targets)
- Efficiency bonuses (under-budget components)

### Expense Categories
- Component purchase
- Testing cycles
- Crew training (affects Phase 2-4 performance)
- Contingency reserve (recommended 15-20%)
- Holding costs (if built early)

### Budget Events
Random events can impact budget:
- Congressional review (budget cut/increase)
- Contractor delays (cost overruns)
- Technology breakthrough (discount on specific component)
- Accident (emergency repairs)

## Holding Risks

If the ship is completed before the launch window:

| Risk | Probability/Day | Consequence |
|------|-----------------|-------------|
| Component degradation | 2% | Quality loss |
| Supply spoilage | 1% | Cargo loss |
| Crew illness | 0.5% | Crew stat reduction |
| Micrometeorite damage | 0.1% | Hull damage |
| Budget overrun | 5% | Holding costs increase |

## Crew Assignment

During this phase, players also select and train their crew:

### Crew Roles
- **Commander/Pilot:** Navigation, leadership, crisis management
- **Engineer:** Repairs, ship maintenance, construction
- **Scientist:** Experiments, analysis, medical backup
- **Medical Officer:** Health, morale, psychological support

### Training Trade-offs
- More training = better stats, but costs time and money
- Cross-training creates redundancy but dilutes expertise
- Personal missions unlock during training (optional objectives)

## UI Elements

### Main View
- Hex grid workspace (center)
- Component palette (left sidebar)
- Budget tracker (top)
- Countdown timer (top right, prominent)
- Quality overview (right sidebar)
- Crew status (bottom)

### Information Panels
- Component details on hover
- Testing results popup
- Budget breakdown
- Risk assessment

## Phase Completion

### Launch Readiness Checklist
- [ ] All required components placed
- [ ] All components meet minimum quality threshold
- [ ] Cargo loaded (supplies, equipment, MAV)
- [ ] Crew assigned and trained
- [ ] Fuel loaded
- [ ] Budget has reserve for contingencies

### The Launch Decision
Player can launch:
- **On window:** Optimal travel time
- **Early:** Holding risks accumulate
- **Late:** Each day adds to travel time

The LAUNCH button transitions to Phase 2.

## Replayability Elements

- Randomized starting budget
- Random events during construction
- Multiple viable ship configurations
- Engine choice creates different Phase 2 experiences
- Crew personality combinations
- Optional challenge modifiers (harder budget, shorter window)
