# MOT Phase 2: Complete Systems Reference

> **Design Vision:** "Overcooked meets Apollo 13" - Frantic real-time crisis management with FTL-style power trade-offs and Oregon Trail resource scarcity.
> **Design Research:** See [Control Surface Design Research](research/control-surface-design.md)

## Table of Contents

1. [Game Modes Overview](#game-modes-overview)
2. [Ship Interior Layout](#ship-interior-layout)
3. [Tile-Based Movement System](#tile-based-movement-system)
4. [CRISIS Mode](#crisis-mode)
5. [Control Surfaces](#control-surfaces)
6. [Power Balance System](#power-balance-system)
7. [Hull Events](#hull-events)
8. [Visual Effects](#visual-effects)
9. [AI Behavior](#ai-behavior)
10. [Integration Architecture](#integration-architecture)

---

## Game Modes Overview

MOT Phase 2 operates in two distinct modes:

### Normal Mode (Event Management)
- **Feel:** Oregon Trail / FTL
- **Pacing:** Turn-based with real-time elements
- **Core Loop:** Advance day → Resolve events → Manage resources → Assign crew
- **Events:** Story moments with weighted outcomes (solar flare, crew conflict, etc.)
- **UI:** Event popups with choices, resource overview

### CRISIS Mode (Real-Time Emergency)
- **Feel:** Overcooked / Among Us / Apollo 13
- **Pacing:** Pure real-time, no pausing
- **Core Loop:** Crises spawn → Assign crew → Fetch items → Fix crises → Repeat
- **Trigger:** Major system failures, cascade events, story beats
- **Duration:** 45-120 seconds of intense management
- **Victory:** Resolve all crises before catastrophic failure
- **Failure:** Any crisis reaches CATASTROPHIC for too long

```
NORMAL MODE                          CRISIS MODE
┌─────────────────┐                 ┌─────────────────┐
│ Day 47/183      │    Trigger:    │ ⚠️ CASCADE ALERT │
│ [Advance Day]   │ ───────────▶   │ Multiple crises! │
│ Event: Solar    │    Major       │ [O2] [FIRE] [PWR]│
│ Flare detected  │    Failure     │ [45s remaining]  │
└─────────────────┘                 └─────────────────┘
         │                                  │
         │                                  │
         ▼                                  ▼
    Choose option                    Direct crew to
    (pause allowed)                  fix crises (no pause)
```

---

## Ship Interior Layout

### Room Layout (Horizontal Ship)
```
            [MEDICAL]───[QUARTERS]───[CORRIDOR]───[BRIDGE]  ◀── NOSE (toward Mars)
                                          │
            [CARGO ]───[LIFE SUP]───[ENGINEERING]
```

### Tile Grid (32×12 tiles, 16px each)
```
     0    4    8   12   16   20   24   28   32
   ┌──────────────────────────────────────────┐
 0 │                                          │
 2 │  ┌CARGO─┐  ┌LIFE──┐  ┌ENGIN─┐           │
 4 │  │      │  │  SUP │  │EERING│           │
 6 │  │ Items│  │      │  │Reactr│           │
 8 │  │      │  │      │  │      │           │
10 │  └──────┘  └──────┘  └──────┴──┬─────┐  │
   │            ┌CORRIDOR──────────┐│BRIDG│  │
12 │  ┌MEDIC─┐  │                  ││  E  │  │
14 │  │  AL  │  └──────────────────┘└─────┘  │
16 │  └──────┘  ┌QUARTERS─┐                  │
18 │            └─────────┘                  │
   └──────────────────────────────────────────┘
```

### Room Purposes

| Room | Primary Function | Control Systems | Crisis Types |
|------|-----------------|-----------------|--------------|
| **Bridge** | Navigation, Defense | Shields, Sensors | Navigation Drift |
| **Engineering** | Power, Propulsion | Power Core, Engine, Emergency Power | Power Fluctuation, Equipment Fault |
| **Life Support** | O2, Water | Life Support | O2 Leak, Water Recycler Jam |
| **Medical** | Crew Health | Medical Bay | Medical Emergency |
| **Cargo Bay** | Storage, Items | (item storage only) | Hull Stress, Food Contamination |
| **Quarters** | Crew Rest | (none) | (none - safe zone) |
| **Corridor** | Transit | (none) | Fire (can spread here) |

---

## Tile-Based Movement System

### Movement Constants
```gdscript
TILE_SIZE = 16           # Pixels per tile
WALK_TIME = 0.4s         # Seconds per tile (normal)
RUN_TIME = 0.25s         # Seconds per tile (emergency)
PICKUP_TIME = 0.5s       # Time to grab item
DROP_TIME = 0.3s         # Time to drop item
WORK_START_TIME = 0.3s   # Time to begin work
```

### Pathfinding
- **Algorithm:** A* with crew blocking
- **Blocked tiles:** Crew members block their current tile
- **Wait behavior:** Crew wait if path blocked (no collision)
- **Room transitions:** Must path through corridors between rows

### Crew States
```
IDLE → WALKING → WORKING → IDLE
         ↓
      RUNNING (emergency)
         ↓
      CARRYING (has item)
```

---

## CRISIS Mode

### Crisis Lifecycle
```
EMERGING (6s) → ACTIVE (8s) → CRITICAL (8s) → CATASTROPHIC (6s) → FAILURE
   Yellow         Orange          Red           Flashing Red       Game Over
   0.5x drain     1.0x drain      2.0x drain    4.0x drain
```

### Crisis Types

| Crisis | Room | Drain | Requires Item | Fix Time |
|--------|------|-------|---------------|----------|
| O2 Leak | Life Support | Oxygen -2/s | Spare Part | 4s |
| Power Fluctuation | Engineering | Power -3/s | (station task) | 5s |
| Water Recycler | Life Support | Water -1.5/s | Spare Part | 4s |
| Hull Stress | Cargo Bay | (breach risk) | Patch Kit | 5s |
| Medical Emergency | Medical | Health -5/s | Med Kit | 4s |
| Navigation Drift | Bridge | Fuel -1/s | (station task) | 4s |
| Fire | Any | Oxygen -4/s | Extinguisher | 3s |
| Equipment Fault | Engineering | Power -1.5/s | Spare Part | 4s |
| Food Contamination | Cargo Bay | Food -3/s | Sanitizer | 4s |
| Sensor Malfunction | Bridge | (no early warning) | Spare Part | 4s |

### Item Types

| Item | Stored In | Fixes |
|------|-----------|-------|
| Spare Part | Cargo Bay | O2 Leak, Water Recycler, Equipment Fault |
| Patch Kit | Cargo Bay | Hull Stress |
| Med Kit | Cargo Bay | Medical Emergency |
| Extinguisher | Cargo Bay | Fire |
| Sanitizer | Cargo Bay | Food Contamination |
| Power Cell | Cargo Bay | Power Fluctuation (severe) |

### Task Phases (Multi-Step Fetch)
```
IDLE → MOVING_TO_CARGO → PICKING_UP → MOVING_TO_CRISIS → WORKING → COMPLETED
                ↓              ↓              ↓              ↓
           Walk to       Grab item       Walk to        Fix crisis
           cargo bay     (0.5s)          crisis room    (3-5s)
```

### Spawn Balance
```
Standard CRISIS: 45-60s duration
- 8-12 crises spawn
- 35% spawn chance per 2s check
- Items: 3-4 of each type

Cascade CRISIS: 60-90s duration
- 12-18 crises spawn
- Higher spawn rate
- Items: 4-5 of each type

Storm CRISIS: 90-120s duration
- 15-25 crises spawn (deliberately overwhelming)
- Items: Deliberately scarce (forces triage)
```

### Crew Efficiency
```
Specialist fixing their crisis type: 1.5x speed
Commander fixing any crisis: 1.25x speed
Mismatched crew: 1.0x speed

4 crew × ~4 fixes/minute = ~16 crisis capacity
vs 14 crises in 28s = barely positive margin
```

---

## Control Surfaces

> **Full Reference:** See [Control Surfaces](control-surfaces.md) for complete details.
> **Design Research:** See [Control Surface Design Research](research/control-surface-design.md)

### Design Philosophy

**Fewer systems, more meaningful choices.** We reduced from 15 surfaces to 6 core systems based on game design research. Each system has a genuine trade-off where different states are optimal in different situations.

Key principles:
- Every surface must have a **real trade-off** (no dominant strategies)
- If one option is always best, it's a fake choice
- Systems should **interact** (shields drain power needed for engines)
- **Clear consequences** (not vague "morale bonus")

### The 6 Core Systems

| System | Location | States | Drain | Effect |
|--------|----------|--------|-------|--------|
| **Power Core** | Engineering | NORMAL / OVERDRIVE | 0 | Output: 10/hr or 15/hr (+heat risk) |
| **Shields** | Bridge | OFF / ON | 0 / 6/hr | 50% damage reduction |
| **Engine** | Engineering | IDLE / CRUISE / BURN | 1 / 3 / 8/hr | Speed: 0.5x / 1x / 1.5x |
| **Life Support** | Life Support | MINIMAL / NORMAL / BOOSTED | 2 / 4 / 8/hr | O2+Water: 0.5x / 1x / 1.5x |
| **Medical Bay** | Medical | OFF / ON | 0 / 4/hr | Healing: off / on |
| **Sensors** | Bridge | OFF / ON | 0 / 2/hr | Event warning: none / +1 day |

Plus: **Emergency Power** (Button) - +10 power for 30s, 5min cooldown

### Why Each System Matters

| System | Trade-off | When Each State is Optimal |
|--------|-----------|---------------------------|
| **Power Core** | Power vs explosion risk | OVERDRIVE when you NEED shields + burn + medical simultaneously |
| **Shields** | Protection vs drain | ON during events/combat, OFF during safe cruising |
| **Engine** | Speed vs fuel | BURN to escape, CRUISE normally, IDLE to conserve |
| **Life Support** | Resources vs power | MINIMAL in crisis, BOOSTED when reserves low |
| **Medical Bay** | Healing vs power | OFF when no one hurt (saves power!), ON when needed |
| **Sensors** | Warning vs power | OFF during crisis (too late), ON when cruising |

### Heat Mechanic (Power Core)

```
Heat in OVERDRIVE: +2/hr
Heat in NORMAL: -1/hr (dissipates)

Heat 0-5: Safe
Heat 6-7: Warning (steam particles)
Heat 8-9: Danger (alarms)
Heat 10+: CRITICAL - 10 seconds to explosion

Explosion: Power Core BROKEN, Engine 50% damage, Fire in Engineering
```

---

## Power Balance System

### Power Equation

```
Net Power = Generation - Drain

Generation:
  Solar Panels: +5/hr (passive, decreases far from sun)
  Power Core NORMAL: +10/hr
  Power Core OVERDRIVE: +15/hr (but heat builds!)
  Emergency Power: +10 for 30 seconds (limited use)

Sustainable generation: 15/hr
Maximum generation: 20/hr (with overdrive risk)
```

### Power States

```
Net Power > 0: Surplus (comfortable)
Net Power = 0: Balanced (no buffer)
Net Power < 0: Deficit (draining batteries)
Batteries empty: Systems start failing
```

### Scenario Analysis

**Safe Cruising:**
```
Life Support NORMAL: 4/hr
Engine CRUISE: 3/hr
Sensors ON: 2/hr
──────────────────────
Total drain: 9/hr
Generation: 15/hr
Surplus: +6/hr ✓
```

**Alert Mode (Event Approaching):**
```
Life Support NORMAL: 4/hr
Shields ON: 6/hr
Engine CRUISE: 3/hr
Sensors ON: 2/hr
──────────────────────
Total drain: 15/hr
Generation: 15/hr
Balance: 0 (sustainable but tight)
```

**Combat/Crisis:**
```
Life Support MINIMAL: 2/hr
Shields ON: 6/hr
Engine BURN: 8/hr
Medical ON: 4/hr
──────────────────────
Total drain: 20/hr
Generation: 15/hr
Deficit: -5/hr (draining batteries!)
```
**Decision:** Use Emergency Power, or OVERDRIVE (risk explosion)

**The Key Insight:** You can't have everything. Each crisis forces prioritization.

---

## Hull Events

### Event Types

| Event | Trigger | Visual | Damage | Control Surface Effect |
|-------|---------|--------|--------|----------------------|
| **Asteroid (Small)** | Random/Story | 8px rock, debris | 10% to room | 30% chance to break surface |
| **Asteroid (Medium)** | Random/Story | 16px rock, debris | 25% to room | 30% chance to break surface |
| **Asteroid (Large)** | Story only | 28px rock, explosion | 50% to room | 30% chance to break surface |
| **Solar Flare** | Random/Story | Yellow screen wash, lens flare | Power surge | 40% × intensity to break electronics |
| **Micrometeorite** | Random | Tiny streaks, small sparks | 5% minor | (none) |
| **Space Debris** | Random | Tumbling metal/panels | 15% if embeds | (none) |

### Warning System
```
Sensors ON: +1 day warning before events
Sensors OFF: No warning
Sensors BROKEN: No warning, worse event outcomes
```

---

## Visual Effects

### Particle Effects

| Effect | Trigger | Description |
|--------|---------|-------------|
| `spawn_sparks()` | Electrical damage | Orange/yellow particles, random scatter |
| `spawn_debris()` | Hull damage | Gray tumbling chunks with rotation |
| `spawn_smoke()` | Fire/overheating | Gray particles rising, expanding |
| `spawn_steam()` | Coolant/pressure | White particles, rapid rise |
| `spawn_fire()` | Fire crisis | Flickering orange/red flames |
| `spawn_explosion()` | Critical failure | Flash + shockwave ring + debris |
| `spawn_electrical_arc()` | Power surge | Blue-white zigzag line |
| `spawn_welding_sparks()` | Repairs | Bright white cascading sparks |
| `spawn_frost()` | Coolant boost | Blue-white particles on surfaces |
| `spawn_blood()` | Medical emergency | Red droplets |

### Screen Effects

| Effect | Trigger | Description |
|--------|---------|-------------|
| `shake_screen()` | Impacts, explosions | Camera displacement, intensity+duration |
| `trigger_impact()` | Asteroid hit | Red flash + shake |
| `trigger_solar_flare_effect()` | Solar flare | Yellow screen wash |

### State Visuals

| State | Surface Glow | Particles |
|-------|--------------|-----------|
| WORKING | Green pulse | None |
| USING | Yellow/bright | None |
| BROKEN | Red flicker | Sparks + Smoke |
| OFF | Gray (dim) | None |

---

## AI Behavior

### CRISIS Mode AI

The AI is designed to "barely cope" under pressure, creating visible struggle.

#### Priority Calculation
```gdscript
score = 0
score += crisis.severity × 100          # Urgency
score += min(crisis.total_time × 5, 25) # Older crises
score += specialist_bonus × 20          # Crew match
score += travel_tiles × -3              # Distance penalty
score += fetch_needed × cargo_dist × -2 # Item fetch penalty
```

#### Local Awareness
```
Crew can see:
1. Crises in their current room
2. Crises in adjacent rooms
3. Any crisis at ACTIVE severity or higher (ship-wide alarm)

Can NOT see:
- EMERGING crises in distant rooms (creates scramble when they escalate)
```

#### Panic Behavior
```
if active_crises >= 3:
    is_panicking = true
    reaction_delay *= 1.5           # Slower response
    20% chance: suboptimal choice   # Random score modifier
    10% chance: forget to grab item # Task failure
```

#### Reassignment Logic
```
Every 2.5 seconds:
1. Check unassigned crises
2. Sort by severity (highest first)
3. Try to assign available crew
4. If CRITICAL+ unassigned, steal crew from lower-priority crisis
```

---

## Integration Architecture

### Component Hierarchy
```
Phase2Store (main state)
    └── ShipSystemsIntegration (wiring)
            ├── ControlSurfaceManager (6 systems + emergency power)
            │       └── power balance, reactor heat
            ├── ControlSurfacesContainer (visuals)
            │       └── ControlSurfaceVisual (per system)
            └── HullEvents (external events)
                    └── asteroid, flare, debris, micrometeorite

CrisisModeController (CRISIS mode)
    ├── CrisisManager (crisis state)
    ├── CrisisAI (crew assignment)
    ├── CargoStorage (items)
    └── TileGrid (pathfinding)

Phase2Effects (particles, shake)

ShipView (crew visuals, rooms)
    ├── ShipRoom (per room)
    └── CrewMember (per crew, tile movement)
```

### Signal Flow
```
Hull Event (asteroid)
    → HullEvents.asteroid_impact signal
    → ShipSystemsIntegration handler
    → ControlSurfaceManager.break_surface()
    → ControlSurfacesContainer receives state change
    → ControlSurfaceVisual shows sparks/smoke
    → Phase2Effects.spawn_explosion()

Crisis Spawns
    → CrisisManager.crisis_spawned signal
    → CrisisAI queues reaction
    → After delay, CrisisAI.try_assign_crew()
    → CrisisModeController.assign_crisis_to_crew()
    → CrewMember.move_to_tile() or fetch task
```

### File Map
```
scripts/mars_odyssey_trek/phase2/
├── phase2_store.gd              # Main state, events, dispatch
├── phase2_reducer.gd            # Pure state mutations
├── phase2_types.gd              # Type definitions
├── phase2_effects.gd            # Particle effects, screen effects
├── crisis/
│   ├── crisis_types.gd          # Crisis definitions
│   ├── crisis_manager.gd        # Active crisis tracking
│   ├── crisis_mode_controller.gd # CRISIS mode orchestration
│   ├── crisis_ai.gd             # AI assignment logic
│   ├── tile_grid.gd             # A* pathfinding
│   └── item_types.gd            # Item definitions
└── ship/
    ├── ship_view.gd             # Visual ship interior
    ├── ship_room.gd             # Individual room visuals
    ├── ship_types.gd            # Room/crew enums
    ├── ship_hull.gd             # Exterior hull visual
    ├── crew_member.gd           # Crew movement/inventory
    ├── control_surface.gd       # Surface definitions
    ├── control_surface_manager.gd # Surface state management
    ├── control_surface_visual.gd  # Single surface rendering
    ├── control_surfaces_container.gd # All surfaces container
    ├── cargo_storage.gd         # Item inventory
    ├── hull_events.gd           # External events
    └── ship_systems_integration.gd # Wiring everything together
```

---

## Keyboard Debug Controls

| Key | Action |
|-----|--------|
| C | Toggle crisis mode |
| V | Spawn random crisis |
| B | Break random surface |
| H | Trigger random hull event |

---

## Balance Philosophy

> **Detailed Math:** See [Balance Mathematics](balance-math.md) for complete pressure analysis and margin-for-error calculations.

### The Pressure Equation
```
Difficulty = Demands / Capacity

Target: 0.85 - 0.95 for optimal challenge
Above 1.0 = mathematically impossible
Below 0.8 = too easy (player has slack)
```

### Key Thresholds

| Metric | Safe | Warning | Danger | Impossible |
|--------|------|---------|--------|------------|
| **Power Net** | +6/hr | 0/hr | -5/hr | -10/hr |
| **Crisis Spawn** | 1/8s | 1/5s | 1/4s | 1/3s |
| **Active Crises** | 3-4 | 5-6 | 7-8 | 9+ |
| **Reactor Heat** | 0-5 | 6-7 | 8-9 | 10+ |
| **Broken Systems** | 0-1 | 2 | 3 | 4+ |

### Crew Capacity Math
```
Crew: 4
Average fix time: 10.4s (weighted for fetch tasks)
Theoretical max: 23 fixes/min
With inefficiency: ~15 fixes/min (realistic)

Crisis lifespan: 28 seconds
Concurrent capacity: 5-6 crises safely
At 1/5s spawn: 12 crises/min = 80-95% capacity used
```

### Mistake Budget
```
Normal Difficulty = 3-4 significant mistakes tolerated per journey

Power mistakes: Hours to notice, hours to fail
Resource mistakes: Days to notice, days to fail
Crisis mistakes: Seconds to notice, minutes to fail

Player can make 2-3 simultaneous power mistakes and still have hours to correct.
```

### The Pressure Curve
```
CRISIS mode is designed so that:
- Perfect play = barely survive (0-2 losses)
- Good play = lose 1-2 crises to catastrophic
- Average play = fail after 60-90s
- Overwhelmed = triage mode (save 60%, lose 40%)

This creates:
1. Constant tension (never comfortable)
2. Visible struggle (crew always running)
3. Triage decisions (can't save everything)
4. Mastery curve (learn optimal patterns)
```

### Trade-off Design

**Power is the universal constraint.** With 6 systems competing for ~15/hr of power:

| Want This? | Costs You |
|------------|-----------|
| Shields ON | 6/hr - less for engines or life support |
| Engine BURN | 8/hr - can't also run shields + medical |
| Medical ON | 4/hr - might need that for boosted life support |
| Life Support BOOSTED | 8/hr - leaves little for anything else |

**No dominant strategy.** Every situation calls for different priorities:
- Asteroid incoming? Shields ON, Life Support MINIMAL
- Crew injured? Medical ON, Engine IDLE
- Low on O2? Life Support BOOSTED, everything else off
- Need to reach Mars fast? Engine BURN, accept the risks

**The power math forces real choices.** You can't have it all.

### Difficulty Slider Reference

| Difficulty | Mistake Budget | AI Win Rate | Spawn Rate |
|------------|----------------|-------------|------------|
| Story | 10+ | 99% | 1/10s |
| Easy | 5-6 | 95% | 1/8s |
| Normal | 3-4 | 80% | 1/5s |
| Hard | 1-2 | 50% | 1/4s |
| Brutal | 0 | 20% | 1/3s |

---

## Implementation Status

### Completed
- [x] Tile-based movement with A* pathfinding
- [x] Multi-step fetch tasks (cargo → crisis)
- [x] Item types and cargo storage
- [x] Hull events (asteroids, flares, debris)
- [x] Enhanced particle effects
- [x] Integration wiring
- [x] Control surface design (reduced to 6 systems)
- [x] Power balance math documentation
- [x] Heat mechanic design
- [x] control_surface.gd (6 systems)
- [x] control_surface_manager.gd
- [x] control_surface_visual.gd
- [x] control_surfaces_container.gd
- [x] Margin-for-error analysis (balance-math.md)

### Remaining
- [ ] Wire Phase2Store power effects
- [ ] Wire control surfaces to crew commands
- [ ] Balance tuning pass
- [ ] UI for surface interaction
- [ ] Sound effects integration
- [ ] Validate AI win rates against difficulty targets
