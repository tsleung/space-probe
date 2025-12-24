# MOT Phase 2: Real-Time Crisis System

> **Reference:** See `docs/mot/phase-2-systems.md` for complete Phase 2 systems documentation.

## Design Goal

Transform the "Oregon Trail" turn-based event system into an "Overcooked meets Apollo 13" real-time crisis management experience. The crew must physically move through the ship, fetch items, and fix problems before they escalate to catastrophic failure.

## Core Differences

| Oregon Trail Model | CRISIS Mode |
|-------------------|-------------|
| Event popup pauses game | Crises exist as room states, no pause |
| One event at a time | Multiple simultaneous crises (4-8) |
| Pick from menu options | Direct crew to rooms, manage item logistics |
| Time stops for decisions | Time never stops, escalation is visible |
| Events resolve instantly | Repairs take real time (3-5s work + travel) |
| Abstract choices | Physical fetch tasks (cargo → crisis) |

## Two Game Modes

### Normal Mode
- Turn-based event management (FTL-style)
- Events pause for decisions
- Story moments with weighted outcomes

### CRISIS Mode (The Overcooked Moment)
- Pure real-time, no pausing
- Multiple simultaneous crises
- Tile-based movement with pathfinding
- Item fetch tasks from cargo bay
- AI struggles to keep up
- 45-120 second intense sessions

Trigger: Major failures, cascade events, story beats

---

## Tile-Based Architecture

### Grid System
```
32×12 tiles, 16px each = 512×192 pixel play area

Movement:
- WALK: 0.4s per tile (normal)
- RUN: 0.25s per tile (emergency)
- Pickup: 0.5s
- Work: 3-5s depending on crisis
```

### Room Layout
```
[CARGO]─[LIFE SUPPORT]─[ENGINEERING]
                            │
[MEDICAL]─[QUARTERS]─[CORRIDOR]─[BRIDGE]
```

### Pathfinding
- A* algorithm with crew blocking
- Crew members block their current tile
- Must route around other crew
- Creates natural bottlenecks in corridors

---

## Crisis System

### Crisis Lifecycle
```
EMERGING (6s) → ACTIVE (8s) → CRITICAL (8s) → CATASTROPHIC (6s) → FAILURE
   Yellow         Orange          Red           Flashing           Game Over
   0.5x drain     1.0x drain      2.0x drain    4.0x drain
```

### Crisis Types

| Crisis | Room | Drain | Requires Item | Work Time |
|--------|------|-------|---------------|-----------|
| O2 Leak | Life Support | Oxygen -2/s | Spare Part | 4s |
| Power Fluctuation | Engineering | Power -3/s | Station task | 5s |
| Water Recycler | Life Support | Water -1.5/s | Spare Part | 4s |
| Hull Stress | Cargo Bay | Breach risk | Patch Kit | 5s |
| Medical Emergency | Medical | Health -5/s | Med Kit | 4s |
| Navigation Drift | Bridge | Fuel -1/s | Station task | 4s |
| Comms Failure | Bridge | Morale -2/s | Station task | 3s |
| Fire | Any | Oxygen -4/s | Extinguisher | 3s |
| Equipment Fault | Engineering | Power -1.5/s | Spare Part | 4s |
| Food Contamination | Cargo Bay | Food -3/s | Sanitizer | 4s |

### Station Tasks vs Fetch Tasks

**Station Tasks** (no item needed):
- Power Fluctuation, Navigation Drift, Comms Failure
- Crew goes directly to crisis room and works

**Fetch Tasks** (item required):
- All other crises
- Crew must: Go to cargo → Pick up item → Go to crisis → Work

---

## Multi-Step Task Phases

```
IDLE → MOVING_TO_CARGO → PICKING_UP → MOVING_TO_CRISIS → WORKING → COMPLETED
         Walk to           Grab item      Walk to          Fix crisis
         cargo bay         (0.5s)         crisis room      (3-5s)
```

### Item Types

| Item | Location | Fixes |
|------|----------|-------|
| Spare Part | Cargo Bay | O2 Leak, Water Recycler, Equipment Fault |
| Patch Kit | Cargo Bay | Hull Stress |
| Med Kit | Cargo Bay | Medical Emergency |
| Extinguisher | Cargo Bay | Fire |
| Sanitizer | Cargo Bay | Food Contamination |

### Item Scarcity

Items spawn at CRISIS start based on type:
- **Standard**: 3-4 of each item
- **Cascade**: 4-5 of each item
- **Storm**: Deliberately scarce (forces triage)

When items run out, that crisis type becomes unfixable. This creates triage decisions.

---

## AI Controller

### Local Awareness
```
Crew can see:
1. Crises in their current room
2. Crises in adjacent rooms
3. Any crisis at ACTIVE+ severity (ship-wide alarm)

Cannot see:
- EMERGING crises in distant rooms
```

### Priority Calculation
```gdscript
score = crisis.severity × 100      # Urgency first
score += crisis.time × 5           # Older crises
score += specialist_bonus × 20     # Crew efficiency
score += travel_distance × -3      # Penalize far crises
score += fetch_needed × cargo_dist × -2  # Penalize fetch tasks
```

### Panic Behavior
When `active_crises >= 3`:
- Reaction delay +50%
- 20% chance of suboptimal assignment
- 10% chance to forget item

### Reassignment
Every 2.5 seconds:
1. Check for unassigned crises
2. Prioritize by severity
3. If CRITICAL+ crisis unassigned, steal crew from lower priority

---

## Crew Efficiency

| Role | Best At | Speed |
|------|---------|-------|
| Engineer | Power, Hull, Equipment | 1.5x |
| Scientist | O2, Water, Navigation | 1.5x |
| Medical | Medical Emergency | 1.5x |
| Commander | Any crisis | 1.25x |

---

## Balance Design

### The Pressure Equation
```
4 crew × ~4 fixes/minute = ~16 crisis capacity per minute
vs
Standard CRISIS: 8-12 crises in 45-60s = barely positive margin
```

The margin erodes due to:
- Travel time between crises
- Fetch tasks taking longer
- Corridor bottlenecks
- Item scarcity
- Panic-induced mistakes

**Design goal:** Perfect play = barely survive. Good play = lose 1-2 crises.

---

## Visual Indicators

### Room Crisis Overlay
- Colored border pulse (yellow → orange → red → flashing)
- Crisis type icon
- Progress bar when crew working
- Severity stars (1-4)

### Crew Status
- Line from crew to assigned crisis
- "Walking" / "Working" animation
- Item carried indicator
- Speed efficiency icon

### Global Alerts
- Crisis count badge
- Flashing screen edge when CRITICAL+
- Resource drain rate indicators

---

## Implementation Status

### Completed
- [x] CrisisTypes.gd - Crisis definitions with item requirements
- [x] TileGrid.gd - A* pathfinding with crew blocking
- [x] CrisisModeController.gd - Multi-step task orchestration
- [x] CrisisAI.gd - Local awareness, travel costs, panic behavior
- [x] CargoStorage.gd - Item inventory management
- [x] ItemTypes.gd - Item definitions
- [x] CrewMember tile mode - Discrete stepping movement

### In Progress
- [ ] UI for manual crew commands
- [ ] Sound effects integration
- [ ] Final balance tuning

---

## File Structure
```
scripts/mars_odyssey_trek/phase2/
├── crisis/
│   ├── crisis_types.gd          # Crisis + item definitions
│   ├── crisis_manager.gd        # Active crisis tracking
│   ├── crisis_mode_controller.gd # CRISIS mode orchestration
│   ├── crisis_ai.gd             # AI assignment with panic
│   ├── tile_grid.gd             # A* pathfinding
│   └── item_types.gd            # Item definitions
└── ship/
    ├── cargo_storage.gd         # Item inventory
    └── crew_member.gd           # Tile-based movement
```

---

## Debug Controls

| Key | Action |
|-----|--------|
| C | Toggle CRISIS mode |
| V | Spawn random crisis |

---

## Integration Notes

- CRISIS mode runs parallel to Phase2Store
- Resource drain feeds back to Phase2Store state
- Can trigger traditional events after CRISIS ends (story beats)
- Crew visual positions sync with ShipView
- Control surfaces can break during CRISIS (see phase-2-systems.md)
