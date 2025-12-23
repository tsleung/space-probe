# MOT Phase 2: Real-Time Crisis System

## Design Goal
Transform the "Oregon Trail" turn-based event system into an "Overcooked" real-time crisis management experience.

## Core Differences

| Oregon Trail Model | Overcooked Model |
|-------------------|------------------|
| Event popup pauses game | Crises exist as room states |
| One event at a time | Multiple simultaneous crises |
| Pick from menu options | Direct crew to rooms |
| Time stops for decisions | Time never stops |
| Events resolve instantly | Repairs take real time |

## Architecture

### CrisisManager (New Component)
Manages all active crises in real-time:
- Spawns new crises based on probability
- Tracks crisis severity/escalation
- Handles crew assignment to crises
- Calculates resource drain from active crises

### Crisis States
Each crisis progresses through severity levels:
```
EMERGING (0-3s) → ACTIVE (3-10s) → CRITICAL (10-20s) → CATASTROPHIC (20s+)
     Yellow           Orange            Red              Flashing Red
```

### Crisis Types (Room-Based)
| Crisis | Room | Effect if Ignored | Fix Time |
|--------|------|-------------------|----------|
| O2 Leak | Life Support | -O2/sec | 8s |
| Power Fluctuation | Engineering | -Power/sec, lights flicker | 6s |
| Water Recycler Jam | Life Support | -Water/sec | 7s |
| Hull Stress | Cargo Bay | Risk of breach | 10s |
| Medical Emergency | Medical | Crew health drain | 5s |
| Navigation Drift | Bridge | Fuel waste | 8s |
| Comms Failure | Bridge | No Earth contact (morale) | 6s |
| Fire | Any | Spreads to adjacent rooms | 4s |

### Crew Assignment
- Each crew member can only work one crisis at a time
- Moving to a crisis takes real time (walking)
- Some crew are better at certain crises:
  - Engineer: Power, Hull (50% faster)
  - Scientist: O2, Water, Navigation (50% faster)
  - Medical: Medical emergencies (50% faster)
  - Commander: Any crisis (25% faster), boosts adjacent crew

### Resource Drain Formula
```
drain_per_second = base_drain * severity_multiplier * active_crisis_count

Severity Multipliers:
- EMERGING: 0.5x
- ACTIVE: 1.0x
- CRITICAL: 2.0x
- CATASTROPHIC: 4.0x
```

### AI Auto-Assignment
When AI mode is on:
1. Prioritize CRITICAL and CATASTROPHIC crises
2. Send best-suited crew member
3. If crew busy, queue the assignment
4. Balance between multiple active crises

## Visual Design

### Room Crisis Indicators
- Colored border pulse (yellow → orange → red)
- Icon overlay showing crisis type
- Progress bar for repair (when crew assigned)
- Severity number (1-4 stars)

### Crew Status
- Colored line from crew to their assigned crisis
- "Working" animation when fixing
- Speed indicator showing efficiency

### Global Status
- Crisis count badge in corner
- Flashing alert when CRITICAL+ exists
- Resource drain rate indicators

## Implementation Status

### Phase 1: Crisis Data Types ✅
- [x] Create CrisisTypes.gd with enums and constants
- [x] Define crisis definitions (type, room, effects, fix time)

### Phase 2: CrisisManager ✅
- [x] Spawn logic based on time/probability
- [x] Severity escalation over time
- [x] Resource drain calculations
- [x] Crisis resolution when crew completes fix

### Phase 3: Crew Assignment ✅
- [x] Click-to-assign interface (when AI off)
- [x] AI auto-assignment logic
- [x] Crew efficiency bonuses
- [x] Walking time to reach crisis (via ShipView)

### Phase 4: Visual Integration ✅
- [x] Room crisis overlays with pulsing borders
- [x] Crew assignment lines
- [x] Severity color indicators
- [x] Fix progress bars

### Phase 5: Balance & Polish (In Progress)
- [x] Basic spawn rates
- [x] Fix times per crisis type
- [x] Fire spread mechanic
- [x] Scene integration (CrisisController in phase2_integrated.tscn)
- [ ] Tune for optimal pacing
- [ ] Add more cascade effects

## File Structure
```
scripts/mars_odyssey_trek/phase2/
├── crisis/
│   ├── crisis_types.gd      # Enums, constants, crisis definitions
│   ├── crisis_manager.gd    # Main crisis logic
│   ├── crisis_ai.gd         # AI auto-assignment
│   ├── crisis_visual.gd     # Room overlays and indicators
│   └── crisis_controller.gd # Integration with Phase2Store/ShipView
```

## Keyboard Controls
- **C** - Toggle crisis mode on/off
- **V** - Debug: spawn random crisis

## Integration with Existing Systems
- CrisisManager runs parallel to Phase2Store
- Crises can trigger traditional events (rare, major story beats)
- Resource drain feeds into Phase2Store state
- Crew positions sync with ShipView
