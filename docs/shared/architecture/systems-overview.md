# SpaceProbe Systems Architecture

## High-Level Overview

```
                                 MAIN MENU
                                     |
            +------------+-----------+-----------+------------+
            |            |           |           |            |
           MOT         FCW         VNP         MCS        Voyage
      (Core Game)   (Strategy)  (Real-time)  (Colony)   (Simulator)
            |            |           |           |
            v            v           v           v
    +---------------------------------------------------------------+
    |                    SHARED ENGINE LAYER                         |
    |  Store | Dispatcher | RNG Manager | Persistence | Systems     |
    +---------------------------------------------------------------+
            |
            v
    +---------------------------------------------------------------+
    |                       DATA LAYER                               |
    |  balance.json | events/*.json | ships.json | crew_roster.json |
    +---------------------------------------------------------------+
```

## Game Modules

### 1. Mars Odyssey Trek (MOT) - Core Game
**Status:** Phase 1 legacy, Phase 2 refactored

| Component | File | Lines | Purpose |
|-----------|------|-------|---------|
| Types | `phase2/phase2_types.gd` | ~280 | Enums, constants, factories |
| Reducer | `phase2/phase2_reducer.gd` | ~470 | Pure state transformations |
| Store | `phase2/phase2_store.gd` | ~400 | Signals, dispatch, state |
| View | `phase2/phase2_view.gd` | ~400 | Visual rendering |
| Controller | `phase2/phase2_controller.gd` | ~140 | Input, game loop |
| Main | `phase2/phase2_main_v2.gd` | ~55 | Coordinator |

**Phases:**
1. Ship Building - Component selection, crew hiring, budget
2. Travel to Mars - 183-day journey, events, resource management
3. Mars Arrival - Landing sequence (planned)
4. Mars Base - Surface operations (planned)
5. Return Journey - Earth return (planned)

---

### 2. First Contact War (FCW) - Strategy Expansion
**Status:** Mature (~12K lines)

| Component | File | Lines | Purpose |
|-----------|------|-------|---------|
| Store | `fcw_store.gd` | ~500 | State + signals |
| Reducer | `fcw_reducer.gd` | 1,768 | State transformations |
| Types | `fcw_types.gd` | ~800 | Entity types, factories |
| Main | `fcw_main.gd` | 1,473 | Game controller |
| Solar Map | `fcw_solar_map.gd` | 3,983 | System visualization |
| Battle View | `fcw_battle_view.gd` | 2,009 | Combat rendering |
| Herald AI | `fcw_herald_ai.gd` | ~300 | Enemy AI |
| Time | `fcw_time.gd` | ~150 | Time system |
| Orbital | `fcw_orbital.gd` | ~200 | Orbital mechanics |

**Key Systems:**
- Time: Hours-based (24h/day, 168h/week)
- Entities: Warships, Transports, Weapons, Strategic Points
- Movement: BURNING, COASTING, ORBITING states
- Factions: HUMAN_HERALD vs ENEMY

---

### 3. Von Neumann Probe (VNP) - Real-time Idle
**Status:** Functional (~7K lines)

| Component | File | Lines | Purpose |
|-----------|------|-------|---------|
| Store | `vnp_store.gd` | 42 | Simple observer pattern |
| Reducer | `vnp_reducer.gd` | 249 | State changes |
| Types | `vnp_types.gd` | ~200 | Constants |
| Main | `vnp_main.gd` | 1,447 | Real-time loop |
| UI | `vnp_ui.gd` | 853 | Interface |
| Ship | `ship.gd` | 1,854 | Ship behavior |
| Projectile | `projectile.gd` | 803 | Combat |
| Base Weapon | `base_weapon.gd` | 719 | Defense |
| AI Controller | `vnp_ai_controller.gd` | ~400 | Enemy AI |
| Sound | `vnp_sound_manager.gd` | ~200 | Audio |

**Key Systems:**
- Real-time combat with momentum physics
- Energy economy for ship production
- Planet occupation for income
- Expansion/defense strategy

---

### 4. Mars Colony Sim (MCS) - Colony Building
**Status:** Mature (~5.8K lines)

| Component | File | Lines | Purpose |
|-----------|------|-------|---------|
| Store | `mcs_store.gd` | 500 | Redux store |
| Reducer | `mcs_reducer.gd` | 983 | State transformations |
| Types | `mcs_types.gd` | 813 | Enums, factories |
| View | `mcs_view.gd` | 675 | Isometric 2.5D |
| UI | `mcs_ui.gd` | 1,228 | Interface |
| Population | `mcs_population.gd` | 739 | Colonist sim |
| Economy | `mcs_economy.gd` | 307 | Resources |
| Events | `mcs_events.gd` | 515 | Event system |
| AI | `mcs_ai.gd` | 579 | NPC behavior |
| Politics | `mcs_politics.gd` | 139 | Government |

**Simulation Domains:**
- Population: Colonists with traits, specialties, generations
- Economy: Food, power, water, materials
- Politics: Government types, stability, elections
- Buildings: Construction, efficiency, assignment-based

---

## Shared Engine Layer

```
scripts/engine/
├── core/
│   ├── store.gd           # State container, signals, dispatch
│   ├── dispatcher.gd      # Action routing
│   ├── rng_manager.gd     # Seedable randomness
│   ├── persistence.gd     # Save/load
│   ├── game_loader.gd     # JSON loading
│   └── game_registry.gd   # Game discovery
├── types/
│   ├── result.gd          # Result<T,E> error handling
│   ├── action_types.gd    # Shared actions
│   └── game_types.gd      # Common enums
├── systems/
│   ├── hex_grid_system.gd # Ship building grid
│   ├── resource_system.gd # Consumption/rationing
│   ├── crew_system.gd     # Stats, relationships
│   ├── component_system.gd# Quality, repair
│   ├── event_system.gd    # Triggers, choices
│   └── time_system.gd     # Day/sol progression
├── reducers/
│   ├── game_reducer.gd    # Main router
│   ├── ship_building_reducer.gd
│   ├── travel_reducer.gd
│   └── mars_reducer.gd
└── utils/
    └── hex_math.gd        # Hex calculations
```

---

## Data Flow Pattern

```
┌─────────────────────────────────────────────────────────┐
│                     UI LAYER                            │
│   Buttons, Labels, Views (subscribe to signals)        │
└────────────────────────┬────────────────────────────────┘
                         │ user action
                         v
┌─────────────────────────────────────────────────────────┐
│                   CONTROLLER                            │
│   Input handling, game loop timing                      │
└────────────────────────┬────────────────────────────────┘
                         │ dispatch(action)
                         v
┌─────────────────────────────────────────────────────────┐
│                     STORE                               │
│   State container, signal emission                      │
│   - Calls reducer with current state + action           │
│   - Replaces state with result                          │
│   - Emits state_changed signal                          │
└────────────────────────┬────────────────────────────────┘
                         │ reduce(state, action)
                         v
┌─────────────────────────────────────────────────────────┐
│                    REDUCER                              │
│   Pure static functions (no side effects)               │
│   - Takes state + action                                │
│   - Returns NEW state (never mutates)                   │
│   - Deterministic (given same input = same output)      │
└─────────────────────────────────────────────────────────┘
```

---

## Scene Hierarchy

```
scenes/
├── ui/
│   ├── main_menu.tscn        # Entry point
│   ├── event_popup.tscn
│   ├── game_over.tscn
│   └── launch_sequence.tscn
│
├── mars_odyssey_trek/
│   ├── phase1_main.tscn      # Ship building
│   ├── phase2_v2.tscn        # Travel (current)
│   ├── phase2_main.tscn      # Travel (legacy)
│   └── [selectors/]          # UI components
│
├── first_contact_war/
│   └── fcw_main.tscn
│
├── von_neumann_probe/
│   ├── vnp_main.tscn
│   ├── ship.tscn
│   └── projectile.tscn
│
├── mars_colony_sim/
│   └── mcs.tscn
│
└── voyage/
    └── voyage_map.tscn
```

---

## Data Layer

```
data/
├── games/
│   ├── mars_odyssey_trek/
│   │   ├── manifest.json
│   │   ├── balance.json      # Game constants
│   │   ├── crew_roster.json  # Available crew
│   │   └── events/           # Phase events
│   │
│   ├── first_contact_war/
│   │   ├── manifest.json
│   │   ├── balance.json
│   │   ├── ships.json
│   │   └── zones.json
│   │
│   ├── von_neumann_probe/
│   │   ├── manifest.json
│   │   └── balance.json
│   │
│   └── mars_colony_sim/
│       ├── manifest.json
│       └── balance.json
│
├── shared/
│   ├── traits.json
│   └── conditions.json
│
└── difficulty.json
```

---

## Module Complexity Summary

| Module | Files | LOC | Pattern | Tests |
|--------|-------|-----|---------|-------|
| Engine | 23 | ~5K | Redux/Pure | Framework |
| MOT P2 | 9 | ~2K | Redux/Signals | 46 tests |
| FCW | 11 | ~12K | Redux/Signals | - |
| VNP | 13 | ~7K | Observer | 22 tests |
| MCS | 10 | ~5.8K | Redux/Signals | - |

**Total:** ~35K+ lines of game logic

---

## Signal Flow Examples

### MOT Phase 2: Day Advance
```
Controller._process(delta)
    │
    └─► store.advance_day()
            │
            └─► dispatch(action_advance_day([randoms]))
                    │
                    └─► reducer.reduce(state, action)
                            │
                            ├─► _reduce_advance_day()
                            ├─► _reduce_consume_resources()
                            ├─► _reduce_update_crew()
                            └─► returns new_state
                    │
                    └─► emit signals:
                            ├─► state_changed(new_state)
                            ├─► day_advanced(day)
                            ├─► resources_changed(resources)
                            └─► [conditional: event_triggered, mars_visible]
                    │
                    └─► View._on_state_changed()
                            ├─► _sync_day_counter()
                            ├─► _sync_journey_bar()
                            ├─► _sync_resources()
                            └─► _sync_crew()
```

### FCW: Turn Tick
```
UI: "Advance Time" button
    │
    └─► fcw_store.dispatch_tick()
            │
            └─► FCWReducer.reduce()
                    ├─► Update game_time (+1 hour)
                    ├─► Process entity movements
                    ├─► Check interceptions
                    └─► Update zone occupancy
            │
            └─► emit signals:
                    ├─► state_changed
                    ├─► hour_ticked
                    ├─► day_boundary (if crossed)
                    └─► entity_destroyed (if combat)
            │
            └─► FCWSolarMap updates positions
```

---

## Module Connections

```
                    ┌──────────────┐
                    │  Main Menu   │
                    └──────┬───────┘
                           │
        ┌──────────┬───────┼───────┬──────────┐
        │          │       │       │          │
        v          v       v       v          v
    ┌──────┐  ┌──────┐ ┌──────┐ ┌──────┐ ┌────────┐
    │ MOT  │  │ FCW  │ │ VNP  │ │ MCS  │ │ Voyage │
    │      │  │      │ │      │ │      │ │        │
    │ P1→P2│  │Solar │ │Combat│ │Colony│ │  Map   │
    │ →P3..│  │  Map │ │ Loop │ │  Sim │ │  Sim   │
    └──┬───┘  └──┬───┘ └──┬───┘ └──┬───┘ └────────┘
       │         │        │        │
       └─────────┴────────┴────────┘
                    │
            ┌───────┴───────┐
            │ Shared Engine │
            │  (optional)   │
            └───────────────┘
```

**Current State:**
- Each game has its own Store/Reducer
- Shared engine exists but not fully integrated
- Games are independent (no cross-module state)

**Future Direction:**
- Unified engine layer
- Shared systems (crew, resources, events)
- Cross-game state (e.g., MOT crew → MCS colonists)
