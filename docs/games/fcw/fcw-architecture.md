# First Contact War - Architecture Overview

## Quick Reference

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         FCW SYSTEM ARCHITECTURE                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────┐    signals     ┌─────────────┐    actions    ┌─────────┐ │
│   │  FCWMain    │◄──────────────►│  FCWStore   │──────────────►│FCWReducer│ │
│   │ (UI Control)│                │   (State)   │◄──────────────│ (Logic) │ │
│   └──────┬──────┘                └──────┬──────┘   new state   └────┬────┘ │
│          │                              │                           │      │
│          │ owns                         │ holds                     │ uses │
│          ▼                              ▼                           ▼      │
│   ┌─────────────┐                ┌─────────────┐            ┌───────────┐  │
│   │FCWSolarMap  │                │ Game State  │            │ FCWTypes  │  │
│   │ (Rendering) │                │ Dictionary  │            │ FCWTime   │  │
│   └─────────────┘                └─────────────┘            │ FCWOrbital│  │
│   ┌─────────────┐                                           │FCWHeraldAI│  │
│   │FCWBattleView│                                           └───────────┘  │
│   │FCWPlanetView│                                                          │
│   └─────────────┘                                                          │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 1. File Inventory

### Scripts (15 files)
| File | Lines | Purpose | Dependencies |
|------|-------|---------|--------------|
| `fcw_main.gd` | ~1500 | UI controller, game loop, AI orchestration | Store, SolarMap, BattleView, Evaluator, Enumerator |
| `fcw_store.gd` | ~450 | State container, signals, dispatch, replay | Reducer, Types, ReplayManager |
| `fcw_reducer.gd` | ~1750 | Pure game logic, state transitions | Types, Time, Orbital, HeraldAI |
| `fcw_types.gd` | ~780 | Enums, constants, factories, state shape | None |
| `fcw_solar_map.gd` | ~3900 | Procedural rendering, visual effects | Types |
| `fcw_battle_view.gd` | ~400 | Cinematic battle window | Types |
| `fcw_planet_view.gd` | ~200 | Planet detail PiP window | Types |
| `fcw_battle_system.gd` | ~300 | Named ship management | Types |
| `fcw_time.gd` | ~200 | Time utilities, travel times | None |
| `fcw_orbital.gd` | ~330 | Route planning, intercept math | Types |
| `fcw_herald_ai.gd` | ~490 | Herald decision-making, detection | Types |
| `fcw_replay_manager.gd` | ~230 | Record/replay games, verify determinism | Types, Reducer |
| `fcw_headless_runner.gd` | ~260 | Batch simulation, strategy testing | Types, Reducer, ReplayManager |
| `fcw_action_enumerator.gd` | ~280 | Enumerate valid actions, decision space | Types, Reducer |
| `fcw_state_evaluator.gd` | ~260 | Objective functions, action ranking, phase detection | Types, Reducer |

### Data Files
| File | Purpose |
|------|---------|
| `manifest.json` | Game metadata |
| `balance.json` | Game constants (partially used) |
| `ships.json` | Ship definitions (not currently used - in Types) |
| `zones.json` | Zone definitions (not currently used - in Types) |

### Scenes
| File | Purpose |
|------|---------|
| `fcw_main.tscn` | Main game scene with UI layout |

---

## 2. State Management

### Redux-like Pattern
```
┌──────────────────────────────────────────────────────────────────────────┐
│                           STATE FLOW                                     │
├──────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│    User Input          FCWMain              FCWStore           FCWReducer│
│         │                  │                    │                    │   │
│         │   click/key      │                    │                    │   │
│         ├─────────────────►│                    │                    │   │
│         │                  │  dispatch(action)  │                    │   │
│         │                  ├───────────────────►│                    │   │
│         │                  │                    │  reduce(state,     │   │
│         │                  │                    │         action)    │   │
│         │                  │                    ├───────────────────►│   │
│         │                  │                    │                    │   │
│         │                  │                    │◄───────────────────┤   │
│         │                  │                    │    new_state       │   │
│         │                  │◄───────────────────┤                    │   │
│         │                  │  state_changed     │                    │   │
│         │                  │     signal         │                    │   │
│         │                  │                    │                    │   │
│         │                  ▼                    │                    │   │
│         │            _sync_ui()                 │                    │   │
│         │                                       │                    │   │
└──────────────────────────────────────────────────────────────────────────┘
```

### Action Types (FCWReducer)
```gdscript
Actions = {
    # Time
    "TICK"          # Advance 1 hour (primary time action)
    "END_TURN"      # Advance 1 week (legacy, deprecated)

    # Ships
    "BUILD_SHIP"    # Queue ship construction
    "ASSIGN_FLEET"  # Send ships to zone
    "SET_FLEET_ORDER"  # Set zone defense posture

    # Entities (New System)
    "SPAWN_ENTITY"      # Create warship/transport/weapon
    "SET_DESTINATION"   # Send entity to zone
    "SET_MOVEMENT_STATE"# Change BURNING/COASTING/ORBITING
    "SPLIT_ENTITY"      # Split fleet for decoys
    "LAUNCH_WEAPON"     # Fire torpedo/missile
}
```

### State Shape
```gdscript
state = {
    # Time
    turn: int,                    # Week number (1-indexed)
    game_time: float,             # Hours since start (authoritative clock)

    # Zones (6 total)
    zones: {
        ZoneId -> {
            id, status, population, workers,
            buildings: {BuildingType -> count},
            assigned_fleet: {ShipType -> count}
        }
    },

    # Entities (New unified system)
    entities: [
        {
            id, entity_type, faction,
            position: Vector2,      # AU coordinates
            velocity: Vector2,      # AU/week
            acceleration: float,
            movement_state,         # BURNING/COASTING/ORBITING
            origin, destination,    # Zone IDs
            combat_power, hull, signature,
            cargo: {souls, resources}
        }
    ],

    # Legacy fleet (migration in progress)
    fleet: {ShipType -> count},
    production_queue: [{ship_type, turns_remaining}],
    fleets_in_transit: [{from_zone, to_zone, ship_type, count, turns_remaining}],

    # Evacuation
    lives_evacuated: int,
    lives_lost: int,
    lives_intercepted: int,
    colony_ships_in_transit: [{souls_aboard, turns_remaining, name}],

    # Herald
    herald_attack_target: ZoneId,
    herald_current_zone: ZoneId,
    herald_transit: {from_zone, to_zone, turns_remaining},
    herald_strength: int,
    herald_intel: {
        known_routes: {route_key -> traffic},
        activity_zones: {zone_id -> level},
        last_detected: {entity_id -> detection_info}
    },

    # Events
    tick_events: {intercepts, detections, arrivals},
    event_log: [{turn, message, is_critical}],

    # Game state
    game_over: bool,
    victory_tier: VictoryTier
}
```

### Signals (FCWStore)
```gdscript
# State changes
signal state_changed(new_state)
signal turn_ended(turn)

# Time boundaries
signal hour_ticked(game_time)
signal day_boundary(day)
signal week_boundary(week)

# Game events
signal zone_fallen(zone_id)
signal battle_resolved(zone_id, defended)
signal game_over(victory_tier)
signal ship_completed(ship_type)

# Entity events
signal entity_spawned(entity)
signal entity_destroyed(entity)
signal entity_detected(entity, by_herald)
signal entity_arrived(entity, zone_id)
signal intercept_started(pursuer, target)
```

---

## 3. Time System

### Time Hierarchy
```
┌────────────────────────────────────────────────────────────────────────┐
│                         TIME ARCHITECTURE                              │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│   Real Time (delta)                                                    │
│        │                                                               │
│        ▼                                                               │
│   ┌─────────────────┐                                                  │
│   │ _accumulated_time│  FCWMain tracks partial ticks                   │
│   └────────┬────────┘                                                  │
│            │ >= 1.0 triggers                                           │
│            ▼                                                           │
│   ┌─────────────────┐                                                  │
│   │  dispatch_tick()│  Advances game_time by 1 HOUR                    │
│   └────────┬────────┘                                                  │
│            │                                                           │
│            ▼                                                           │
│   ┌─────────────────────────────────────────────────────────┐         │
│   │                    GAME TIME (hours)                     │         │
│   ├─────────────────────────────────────────────────────────┤         │
│   │  Hour (1)  │  Day (24 hours)  │  Week (168 hours)       │         │
│   ├─────────────────────────────────────────────────────────┤         │
│   │  - Entity  │  - Production    │  - Combat resolution    │         │
│   │    movement│  - Resource      │  - Herald advances      │         │
│   │  - Physics │    generation    │  - Evacuation tallied   │         │
│   │  - Detection│                 │  - Turn counter +1      │         │
│   └─────────────────────────────────────────────────────────┘         │
│                                                                        │
│   Speed Settings (ticks per real second):                              │
│   PAUSED=0, SLOW=0.5, NORMAL=1, FAST=4, VERY_FAST=12                  │
│                                                                        │
│   At NORMAL: 1 week = 168 seconds (~3 minutes)                         │
│   At VERY_FAST: 1 week = 14 seconds                                    │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

### Visual Interpolation
```
┌─────────────────────────────────────────────────────────────────────┐
│                    VISUAL SMOOTHING                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   Game logic: Discrete 1-hour ticks                                 │
│   Visuals: Smooth interpolation between ticks                       │
│                                                                     │
│   tick N                    tick N+1                                │
│     │                          │                                    │
│     ●━━━━━━━━━━━━━━━━━━━━━━━━━●                                    │
│     │     ▲                    │                                    │
│     │     │                    │                                    │
│     │  _tick_progress (0→1)    │                                    │
│     │     │                    │                                    │
│     │  visual position =       │                                    │
│     │  lerp(prev_pos,         │                                    │
│     │       curr_pos,         │                                    │
│     │       _tick_progress)   │                                    │
│                                                                     │
│   Snapshots saved at tick start:                                    │
│   - prev_entity_positions: {entity_id -> Vector2}                   │
│   - prev_zone_positions: {zone_id -> Vector2}                       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 4. Entity System

### Entity Types
```
┌─────────────────────────────────────────────────────────────────────┐
│                       ENTITY TAXONOMY                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   EntityType          Faction        Movement States                │
│   ──────────          ───────        ───────────────                │
│   WARSHIP             HUMAN          BURNING (visible, fast)        │
│   TRANSPORT           HERALD         COASTING (stealthy, slow)      │
│   WEAPON                             ORBITING (stationary)          │
│   HERALD_SHIP                        DESTROYED                      │
│                                                                     │
│   ┌─────────────────────────────────────────────────────────────┐   │
│   │                 ENTITY LIFECYCLE                            │   │
│   ├─────────────────────────────────────────────────────────────┤   │
│   │                                                             │   │
│   │   SPAWN ──► ORBITING ──► BURNING ──► COASTING ──► ORBITING │   │
│   │     │          │            │            │            │     │   │
│   │     │          │            │            │            │     │   │
│   │     │          ▼            ▼            ▼            ▼     │   │
│   │     │      at zone      visible      stealthy    arrived   │   │
│   │     │                   to Herald                          │   │
│   │     │                                                       │   │
│   │     └──────────────────────────────────────────────────────►│   │
│   │                         DESTROYED                           │   │
│   └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Detection System
```
┌─────────────────────────────────────────────────────────────────────┐
│                    HERALD DETECTION                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   Herald Observation Radius: 5 AU                                   │
│   Extended Range (burning): 10 AU                                   │
│   Drone Range: 10 AU                                                │
│                                                                     │
│   Detection Probability = f(distance, movement_state, traffic)      │
│                                                                     │
│                    ┌─────────┐                                      │
│                    │ HERALD  │                                      │
│                    └────┬────┘                                      │
│                         │                                           │
│            ┌────────────┼────────────┐                              │
│            │            │            │                              │
│            ▼            ▼            ▼                              │
│       ┌────────┐  ┌────────┐  ┌────────┐                           │
│       │BURNING │  │COASTING│  │ORBITING│                           │
│       │ ship   │  │ ship   │  │ ship   │                           │
│       └────────┘  └────────┘  └────────┘                           │
│       HIGH det.   LOW det.    NONE det.                             │
│       (2x range)  (1x range)  (close only)                          │
│                                                                     │
│   Traffic Patterns:                                                 │
│   - Herald learns routes from detected burns                        │
│   - High-traffic routes have higher detection                       │
│   - Patterns decay over time (10 week memory)                       │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 5. Zone System

### Zone Layout
```
┌─────────────────────────────────────────────────────────────────────┐
│                    SOLAR SYSTEM ZONES                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│                        KUIPER (0)                                   │
│                     [Herald Spawn]                                  │
│                           │                                         │
│              ┌────────────┼────────────┐                           │
│              │            │            │                           │
│              ▼            ▼            ▼                           │
│         JUPITER(1)   ASTEROID(2)   SATURN(3)                       │
│         [Power]      [Mining]      [Weapons]                       │
│              │            │            │                           │
│              └────────────┼────────────┘                           │
│                           │                                         │
│                           ▼                                         │
│                        MARS (4)                                     │
│                     [Chokepoint]                                    │
│                           │                                         │
│                           ▼                                         │
│                        EARTH (5)                                    │
│                     [Evacuation]                                    │
│                                                                     │
│   Travel Times (weeks):                                             │
│   Kuiper ↔ Outer: 2 weeks                                          │
│   Outer ↔ Mars: 3 weeks                                            │
│   Mars ↔ Earth: 2 weeks                                            │
│                                                                     │
│   Zone IDs: KUIPER=0, JUPITER=1, ASTEROID_BELT=2,                  │
│             SATURN=3, MARS=4, EARTH=5                               │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Zone Status Flow
```
   CONTROLLED ──────► UNDER_ATTACK ──────► FALLEN
       │                    │                 │
       │                    │                 │
   (defended)         (Herald here)     (population=0)
```

---

## 6. UI Architecture

### Scene Tree
```
FCWMain (Control)
├── FCWStore (Node)                    # State management
├── MainContainer (VBoxContainer)
│   ├── Header (HBoxContainer)
│   │   ├── TurnLabel                  # "WEEK X, DAY Y - HH:00"
│   │   ├── LivesLabel                 # "EVACUATED: X [TIER]"
│   │   └── ThreatLabel                # "HERALD: X → Zone (STATUS)"
│   ├── GuidancePanel (PanelContainer)
│   │   └── GuidanceLabel (RichTextLabel)  # Strategic advice
│   ├── GameArea (HBoxContainer)
│   │   ├── MapPanel (PanelContainer)
│   │   │   └── SolarMap (FCWSolarMap) # Created dynamically
│   │   └── SidePanel (VBoxContainer)
│   │       ├── ResourcesPanel
│   │       │   └── ResourcesContainer # ore, steel, etc.
│   │       ├── FleetPanel
│   │       │   ├── FleetList          # Ship counts
│   │       │   ├── BuildButtons       # Ship build buttons
│   │       │   └── ProductionLabel    # Queue status
│   │       ├── ZoneDetailPanel        # Selected zone info
│   │       │   ├── ZoneNameLabel
│   │       │   ├── ZoneStatusLabel
│   │       │   ├── ZoneDefenseLabel
│   │       │   └── AssignButtons      # Ship assignment
│   │       └── EventLog
│   │           └── LogText (RichTextLabel)
│   └── Footer (HBoxContainer)
│       ├── AutoPlayBtn                # AI toggle
│       ├── SpeedLabel
│       ├── SpeedSlider
│       ├── PauseBtn
│       └── MainMenuBtn
└── GameOverPanel (PanelContainer)     # Victory/defeat screen
    └── VictoryTierLabel, Stats, Buttons

# Created dynamically by FCWMain:
├── BattleView (FCWBattleView)         # Corner cinematic window
├── ExtraBattleViews[]                 # Cascading battle windows
└── PlanetView (FCWPlanetView)         # PiP planet detail
```

### Rendering Layers (FCWSolarMap)
```
┌─────────────────────────────────────────────────────────────────────┐
│                    RENDERING ORDER (back to front)                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   1. Nebula background                                              │
│   2. Starfield                                                      │
│   3. Zone connections (energy flow lines)                           │
│   4. Fallen zone debris                                             │
│   5. Particles (ambient)                                            │
│   6. Staging areas                                                  │
│   7. Zones (planets)                                                │
│   8. Skirmishes (combat effects)                                    │
│   9. Warp flashes                                                   │
│  10. Civilian ships                                                 │
│  11. Herald attack ships                                            │
│  12. Player fleets at zones                                         │
│  13. Herald observation zone overlay                                │
│  14. Traffic patterns                                               │
│  15. Entity trajectories                                            │
│  16. Entities (from state)                                          │
│  17. Lasers                                                         │
│  18. Explosions                                                     │
│  19. Herald (main)                                                  │
│  20. Attack indicator                                               │
│  21. Danger vignette                                                │
│  22. Exodus counter                                                 │
│  23. Colony ships                                                   │
│  24. Transmissions (UI overlay)                                     │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 7. AI Systems

### Human AI (FCWMain._run_ai_turn)
```
┌─────────────────────────────────────────────────────────────────────┐
│                    AI DECISION TREE                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   Each Week:                                                        │
│                                                                     │
│   1. SHIP BUILDING                                                  │
│      ├── herald_strength > 500? → Build Dreadnoughts               │
│      ├── turn % 4 == 0? → Build Carriers (evacuation)              │
│      ├── turn % 3 == 0? → Build Cruisers                           │
│      └── else → Build Frigates                                     │
│                                                                     │
│   2. STRATEGIC ASSESSMENT                                           │
│      └── defense_ratio = target_defense / herald_strength          │
│          ├── < 0.8 → CRITICAL (will fall)                          │
│          ├── < 1.2 → MARGINAL (might fall)                         │
│          └── >= 1.2 → HOLDING                                       │
│                                                                     │
│   3. EMERGENCY RESPONSE (if CRITICAL)                               │
│      └── Scramble all ships to threatened zone                     │
│                                                                     │
│   4. REINFORCE MARGINAL ZONES                                       │
│      └── Send ships to achieve 1.3x defense ratio                  │
│                                                                     │
│   5. BLOCKADE AT MARS (if Herald in outer system)                  │
│      └── Maintain 50% herald_strength at Mars                      │
│                                                                     │
│   6. EVACUATION FLEET                                               │
│      └── All Carriers + half Frigates → Earth                      │
│                                                                     │
│   7. REDISTRIBUTE FROM SAFE ZONES                                   │
│      └── Pull ships from non-adjacent zones                        │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Herald AI (FCWHeraldAI)
```
┌─────────────────────────────────────────────────────────────────────┐
│                    HERALD BEHAVIOR                                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   Priority Order:                                                   │
│                                                                     │
│   1. INTERCEPT high-value targets in range                          │
│      └── Transports with souls (highest priority)                  │
│      └── Burning warships                                          │
│                                                                     │
│   2. RELEASE DRONES toward detected burns                           │
│      └── 3 drones per wave                                         │
│      └── Predict target trajectory                                 │
│                                                                     │
│   3. MOVE toward highest activity zone                              │
│      └── Based on accumulated detections                           │
│                                                                     │
│   4. PATROL known high-traffic routes                               │
│      └── Midpoint ambush positions                                 │
│                                                                     │
│   5. HOLD if no activity detected                                   │
│                                                                     │
│   Learning:                                                         │
│   - Remembers traffic patterns (10 week decay)                     │
│   - Predicts entity positions from last sighting                   │
│   - Activity zones accumulate detection events                      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 8. Game Loop

### Main Loop (FCWMain._process)
```
┌─────────────────────────────────────────────────────────────────────┐
│                    FRAME UPDATE                                     │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   Every frame (delta):                                              │
│                                                                     │
│   1. cinematic_update()     # Camera AI (runs even when paused)    │
│   2. _update_planet_view()  # PiP window                           │
│   3. planet_view_timer      # Auto-close                           │
│   4. attack_phase_timer     # Combat animation                     │
│                                                                     │
│   [if paused] → return                                              │
│                                                                     │
│   5. Accumulate time: _accumulated_time += delta * speed           │
│                                                                     │
│   6. [while _accumulated_time >= 1.0]                               │
│      └── _process_tick()                                           │
│          └── store.dispatch_tick()                                 │
│          └── [if week boundary] → _process_week_boundary()         │
│                                                                     │
│   7. Update tick progress for interpolation                         │
│   8. solar_map.set_tick_progress()                                 │
│   9. _sync_header()                                                │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Tick Processing (FCWReducer._reduce_tick)
```
┌─────────────────────────────────────────────────────────────────────┐
│                    HOURLY TICK                                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   0. Clear tick_events                                              │
│   1. Snapshot positions (for interpolation)                         │
│   2. Advance game_time += 1 hour                                    │
│   3. Update entity positions (hourly movement)                      │
│   4. Process entity arrivals                                        │
│   5. [if day boundary]                                              │
│      └── Process production                                        │
│      └── Generate resources                                        │
│   6. [if week boundary]                                             │
│      └── Process combat                                            │
│      └── Process evacuation                                        │
│      └── Advance Herald                                            │
│      └── Check victory/defeat                                      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 9. Victory System

### Victory Tiers
```
┌─────────────────────────────────────────────────────────────────────┐
│                    VICTORY THRESHOLDS                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   Tier          Souls Saved      Description                        │
│   ────          ───────────      ───────────                        │
│   ANNIHILATION  < 5M             "The light goes out"               │
│   TRAGIC        5M - 15M         "Scattered, broken"                │
│   PYRRHIC       15M - 40M        "A remnant survives"               │
│   HEROIC        40M - 80M        "Enough to rebuild"                │
│   LEGENDARY     80M+             "Against all odds"                 │
│                                                                     │
│   Evacuation Math:                                                  │
│   - Ships at Earth evacuate per week                                │
│   - Carriers: 8x evacuation multiplier                              │
│   - Base: (combat_power / 10) * 100,000 souls per ship              │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 10. Module Communication

### Signal Flow Diagram
```
┌─────────────────────────────────────────────────────────────────────┐
│                    SIGNAL CONNECTIONS                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   FCWStore                           FCWMain                        │
│   ────────                           ───────                        │
│   state_changed ─────────────────► _on_state_changed()              │
│                                    └─► _sync_ui()                   │
│                                    └─► _update_guidance()           │
│                                                                     │
│   turn_ended ────────────────────► _on_turn_ended()                 │
│                                    └─► _update_guidance()           │
│                                                                     │
│   zone_fallen ───────────────────► _on_zone_fallen()                │
│                                    └─► solar_map effects            │
│                                    └─► planet view                  │
│                                    └─► pause game                   │
│                                                                     │
│   game_over ─────────────────────► _on_game_over()                  │
│                                    └─► cinematic sequence           │
│                                    └─► show panel                   │
│                                                                     │
│   ship_completed ────────────────► _on_ship_completed()             │
│                                    └─► battle_system add            │
│                                                                     │
│   FCWSolarMap                        FCWMain                        │
│   ───────────                        ───────                        │
│   zone_clicked ──────────────────► _on_zone_clicked()               │
│                                    └─► _select_zone()               │
│                                                                     │
│   zone_hovered ──────────────────► _on_zone_hovered()               │
│                                                                     │
│   FCWBattleView                      FCWMain                        │
│   ─────────────                      ───────                        │
│   battle_complete ───────────────► _on_battle_complete()            │
│   ship_destroyed ────────────────► _on_ship_destroyed()             │
│   expand_toggled ────────────────► _on_battle_view_expand_toggled() │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Data Flow
```
┌─────────────────────────────────────────────────────────────────────┐
│                    DATA DEPENDENCIES                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   FCWTypes (Constants & Factories)                                  │
│       │                                                             │
│       ├──► FCWTime (time utilities)                                │
│       ├──► FCWOrbital (route math)                                 │
│       ├──► FCWHeraldAI (detection, decisions)                      │
│       └──► FCWReducer (game logic)                                 │
│                  │                                                  │
│                  └──► FCWStore (state container)                   │
│                           │                                         │
│                           └──► FCWMain (UI controller)             │
│                                    │                                │
│                                    ├──► FCWSolarMap (rendering)    │
│                                    ├──► FCWBattleView (combat)     │
│                                    ├──► FCWPlanetView (detail)     │
│                                    └──► FCWBattleSystem (ships)    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 11. Current Status & Migration

### Entity System Migration
```
┌─────────────────────────────────────────────────────────────────────┐
│                    MIGRATION STATUS                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   LEGACY SYSTEM                      NEW ENTITY SYSTEM              │
│   (zone-based)                       (position-based)               │
│   ─────────────                      ────────────────               │
│   fleet: {ShipType -> count}    →    entities: [Entity]            │
│   fleets_in_transit: [...]      →    entity.movement_state         │
│   herald_current_zone           →    herald entity position        │
│   herald_transit                →    herald entity velocity        │
│                                                                     │
│   Current State (Dec 2025):                                         │
│   ✅ Entity data structures defined                                │
│   ✅ Entity movement processing                                    │
│   ✅ Entity arrival handling                                       │
│   ✅ Herald as entity                                              │
│   ✅ Detection system                                              │
│   ✅ Intercept mechanics                                           │
│   ✅ Entity signal emission                                        │
│   ✅ Capital ships as named entities                               │
│   ✅ Route selection UI (2-click simplified)                       │
│   ✅ Detection visualization (clean, discrete labels)              │
│   ✅ Traffic pattern display (simple lines)                        │
│   🟡 Entity control panel (partial)                                │
│   ❌ Full legacy system removal                                    │
│                                                                     │
│   Both systems run in parallel during migration                     │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 12. Quick Debug Reference

### Key State Paths
```gdscript
# Current time
state.game_time                    # Hours (float)
state.turn                         # Week number

# Herald position
state.herald_current_zone          # Legacy zone ID
state.entities[0].position         # Entity AU coords (Herald is first)

# Evacuation progress
state.lives_evacuated              # Total souls saved
state.lives_intercepted            # Souls lost to Herald

# Combat
state.herald_strength              # Herald attack power
FCWReducer.calc_zone_defense()     # Zone defense calculation
```

### Important Functions
```gdscript
# Time
FCWTime.get_week(game_time)        # Get week from hours
FCWTime.format_time(game_time)     # "WEEK X, DAY Y - HH:00"

# Zones
FCWTypes.get_zone_position(id, t)  # AU position at time t
FCWTypes.get_zone_name(id)         # Human-readable name

# Entities
FCWTypes.create_entity({...})      # Factory function
FCWTypes.get_herald_entity(state)  # Get Herald from entities array
```

---

## 13. UI Visualization Plan (December 2025)

### Current State: Backend Complete, UI Missing

The entity system, detection mechanics, orbital calculations, and Herald AI are **85% complete at code level**. What's missing is the **UI layer** that exposes these systems to players and creates the emotional experience of desperation through physics.

### Implemented Systems (Backend)

| System | File | Status |
|--------|------|--------|
| Entity data structures | `fcw_types.gd` | Complete |
| Entity movement (position, velocity, acceleration) | `fcw_reducer.gd` | Complete |
| Detection probability calculation | `fcw_herald_ai.gd` | Complete |
| Traffic pattern learning | `fcw_reducer.gd` | Complete |
| Route calculation (direct/coast/gravity assist) | `fcw_orbital.gd` | Complete |
| Herald AI (5-tier decision system) | `fcw_herald_ai.gd` | Complete |
| Intercept mechanics | `fcw_reducer.gd` | Complete |
| Time system (hourly ticks, visual interpolation) | `fcw_time.gd` | Complete |

### Missing Systems (UI/Visualization)

| Feature | Purpose | Impact |
|---------|---------|--------|
| Detection zone visualization | Show probability shading on map | Player understands cost of every action |
| Route selection UI | Choose speed vs stealth tradeoffs | Player agency over movement |
| Entity-level control | Select ships, set destinations | Direct control of assets |
| Trajectory rendering | Show projected paths | See where ships will be |
| Herald observation radius | Visual of what Herald can see | Understand threat detection |
| Timeline/ETA pressure display | Countdown to key events | Feel the desperation |
| Fleet split UI | Decoy tactics | Emergent strategy |

---

## 14. UI Implementation Phases

### Phase 1: Detection Visualization ✅ COMPLETE

**Goal:** Player can SEE detection probability on the map

**Implementation (Simplified Dec 2025):**
1. `fcw_solar_map.gd` - `_draw_herald_observation_zone()`
   - Clean circle showing observation radius with subtle pulse
   - Drone range indicator (inner danger zone)
   - No complex effects - focus on clarity

2. `fcw_solar_map.gd` - `_draw_zone_detection_labels()`
   - Discrete percentages at each zone: `[X%]`
   - Color-coded: green (safe) → yellow → orange → red (danger)
   - Pulses when danger is high (>5%)

3. `fcw_solar_map.gd` - `_draw_traffic_patterns()`
   - Simple lines connecting zones with known traffic
   - Line width/opacity based on traffic level
   - Percentage shown at midpoint for significant traffic (>30%)

**Visual Language (Simplified):**
```
Detection Indicators:
[0.1%]  → Dim green text, safe
[1%]    → Yellow text
[5%]    → Orange text, pulsing
[10%+]  → Red text, pulsing

Traffic Lines:
< 30%   → Thin orange line
30-50%  → Medium line with percentage
> 50%   → Thick red line with percentage
```

### Phase 2: Timeline Pressure Display ✅ COMPLETE

**Goal:** Player FEELS the countdown - Enhanced Header Bar approach

**Implementation:**
1. `fcw_main.gd` - Header with urgency
   ```
   ┌─────────────────────────────────────────────────────────────────────────┐
   │ WEEK 4, DAY 3 - 14:00 │ Herald → Mars: 23d │ EVAC: 2.3M │ THREAT: HIGH │
   └─────────────────────────────────────────────────────────────────────────┘
   ```

2. Threat level system (0-3):
   - **LOW** (0): Standard colors
   - **ELEVATED** (1): Yellow tint, Herald within 2 zones
   - **HIGH** (2): Orange tint, zone falling
   - **CRITICAL** (3): Red pulse, Earth threatened

### Phase 3: Route Selection UI ✅ COMPLETE (Simplified)

**Goal:** Player makes informed movement decisions with minimal clicks

**Implementation (2-Click Flow):**
1. `fcw_solar_map.gd` - Entity selection
   - Click capital ship to select (blue highlight)
   - Callout label shows: Name, Power, Status (STATIONED/IN TRANSIT/COASTING)
   - Instructions appear: "L-CLICK: STEALTH" / "R-CLICK: OPTIONS"

2. `fcw_solar_map.gd` - Route cost previews
   - When ship selected, all destinations show time/risk preview
   - Faint connection lines to available destinations
   - "CLICK" prompt on hover

3. `fcw_solar_map.gd` - Simplified routing
   - **Left-click destination**: Uses stealth coast (default, safer)
   - **Right-click destination**: Shows route options popup (FAST BURN/STEALTH COAST/GRAVITY ASSIST)

4. `fcw_store.gd` - Dispatch helper
   - `dispatch_set_entity_destination(entity_id, zone_id, route_type)`

### Phase 4: Trajectory Rendering (Priority: Medium)

**Goal:** Player sees where ships will be

**Changes:**
1. `fcw_solar_map.gd` - Add `_draw_trajectories()` layer
   - Curved lines showing projected paths
   - Dashed for coast, solid for burn
   - Color indicates faction (blue human, purple Herald)
   - Shows intercept points where paths cross

2. Click entity to highlight its full trajectory with ETAs

### Phase 5: Entity Control Integration (Priority: Medium)

**Goal:** Full player control over individual entities

**Changes:**
1. Entity selection panel (right side)
   - Ship name, type, status
   - Current orders
   - Route modification
   - Split fleet option

2. Quick actions
   - Emergency burn (high signature, fast)
   - Go dark (coast, minimize signature)
   - Abort mission (return to origin)

---

## 15. Critical Files to Modify

| File | Changes |
|------|---------|
| `fcw_solar_map.gd` | Detection zones, trajectories, entity selection, route UI |
| `fcw_main.gd` | Header redesign, timeline display |
| `fcw_main.tscn` | UI structure for new panels |
| `fcw_store.gd` | Route selection dispatch helpers |
| `fcw_types.gd` | UI-related enums if needed |

---

## 16. Success Criteria

After implementation, player should be able to:

1. **See** detection probability across the solar system (where is safe vs dangerous)
2. **Feel** timeline pressure (countdown to Herald arrival, evacuation window)
3. **Choose** between speed and stealth for any movement
4. **Understand** why the Herald went where it did (followed activity)
5. **Experience** the "Earth dilemma" (help colonies = draw Herald, go dark = abandon them)

---

## 17. Resolved Design Decisions

- **Detection**: Visually stunning with discrete percentages at points of interest
- **Timeline**: Enhanced header bar with continuous clock and Herald countdown
- **Herald observation**: Ominous energy field with scanning effects
- **Traffic**: Glowing lane connections showing accumulated activity

---

## 18. Implementation Order

1. **Detection zone visualization** - Highest impact, exposes core mechanic
2. **Timeline pressure display** - Creates urgency
3. **Route selection UI** - Player agency
4. **Trajectory rendering** - Visual clarity
5. **Entity control panel** - Full control

Each phase builds on the previous, and each is independently valuable

---

## 19. Deterministic Simulation Infrastructure

FCW supports fully deterministic simulation for:
- **Replay & Debug**: Record games and replay them exactly
- **AI Optimization**: Run thousands of simulations to find optimal strategies
- **Narrative Control**: Predict when key moments occur

### 19.1 Determinism Guarantee

**Same seed = identical outcome.** The game uses seed-controlled RNG:

```gdscript
# Start deterministic game
store.start_new_game(12345)  # Fixed seed

# After game, verify determinism
var result1 = runner.run_game(12345)
var result2 = runner.run_game(12345)
assert(result1.lives_evacuated == result2.lives_evacuated)
```

All randomness flows through:
1. `FCWStore._rng` - Seeded RNG instance
2. `random_values` array - Passed to reducer with each tick
3. Entity ID derivation - Names derived from counters, not random

### 19.2 FCWReplayManager

**Purpose:** Record games and replay them for testing/analysis.

**Recording Format:**
```json
{
  "version": "1.0.0",
  "seed": 12345678901234,
  "actions": [
    {"tick": 0, "action": {"type": "TICK"}},
    {"tick": 1, "action": {"type": "BUILD_SHIP", "ship_type": 0}}
  ],
  "outcome": {
    "lives_evacuated": 45000000,
    "lives_lost": 120000000,
    "victory_tier": 1,
    "final_turn": 52
  }
}
```

**Key Functions:**
| Function | Purpose |
|----------|---------|
| `create_recording(seed, history, state)` | Create recording from completed game |
| `save_recording(recording, filepath)` | Save to JSON file |
| `load_recording(filepath)` | Load from JSON file |
| `replay(recording, verify)` | Replay game, optionally verify outcome matches |
| `verify_determinism(seed, ticks)` | Run same seed twice, verify identical |
| `get_key_moments(recording)` | Extract narrative turning points |
| `get_decision_points(recording)` | Extract player decision points |

**Usage:**
```gdscript
# Record a game
store.start_new_game(12345)
# ... play game ...
var recording = store.get_recording()
store.save_recording("user://game.json")

# Replay and verify
var result = FCWReplayManager.replay(recording)
print("Matched: ", result.success)
```

### 19.3 FCWHeadlessRunner

**Purpose:** Run games without UI for batch simulation and strategy testing.

**Key Functions:**
| Function | Purpose |
|----------|---------|
| `run_game(seed, strategy, max_ticks)` | Run single game with optional AI strategy |
| `run_batch(count, strategy, base_seed)` | Run N games, collect statistics |
| `compare_strategies(strategies, games_per)` | Compare multiple strategies on same seeds |
| `strategy_passive()` | Built-in: Do nothing |
| `strategy_build_cruisers()` | Built-in: Always build cruisers |
| `strategy_defend_earth()` | Built-in: Focus all defense on Earth |
| `strategy_forward_defense()` | Built-in: Defend outermost zone |

**Usage:**
```gdscript
# Run 100 games with defend_earth strategy
var results = FCWHeadlessRunner.run_batch(100,
    FCWHeadlessRunner.strategy_defend_earth())
FCWHeadlessRunner.print_batch_summary(results)

# Compare strategies
var comparison = FCWHeadlessRunner.compare_strategies([
    {"name": "Passive", "strategy": FCWHeadlessRunner.strategy_passive()},
    {"name": "Defend Earth", "strategy": FCWHeadlessRunner.strategy_defend_earth()},
    {"name": "Forward Defense", "strategy": FCWHeadlessRunner.strategy_forward_defense()}
], 100)
FCWHeadlessRunner.print_comparison_summary(comparison)
```

**Custom Strategy:**
```gdscript
# Strategies are Callables that return actions
func my_strategy(state: Dictionary) -> Array:
    var actions = []
    # Analyze state, decide what to do
    if FCWReducer.can_afford_ship(state, FCWTypes.ShipType.CARRIER):
        actions.append(FCWReducer.action_build_ship(FCWTypes.ShipType.CARRIER))
    return actions

var results = FCWHeadlessRunner.run_batch(100, my_strategy)
```

### 19.4 FCWActionEnumerator

**Purpose:** Enumerate all valid player actions at any game state.

**Key Functions:**
| Function | Purpose |
|----------|---------|
| `get_valid_actions(state)` | All valid actions at current state |
| `get_action_categories(state)` | Actions grouped by type |
| `get_action_count(state)` | Total number of valid actions |
| `get_decision_space_size(state)` | Breakdown by category |
| `filter_actions_by_type(actions, type)` | Filter by action type |
| `filter_high_impact_actions(state)` | Skip micro-optimizations |
| `analyze_decision_complexity(state, depth)` | Game tree branching analysis |
| `get_action_description(action)` | Human-readable action name |

**Action Categories:**
- `BUILD_SHIP` - Commission new ships
- `ASSIGN_FLEET` - Send ships from reserve to zone
- `RECALL_FLEET` - Move ships between zones
- `SET_FLEET_ORDER` - Change zone stance (defend/patrol/evacuate)
- `SET_DESTINATION` - Move entity to destination

**Usage:**
```gdscript
var state = store.get_state()

# Get all valid actions
var actions = FCWActionEnumerator.get_valid_actions(state)
print("Valid actions: ", actions.size())

# Get only build actions
var builds = FCWActionEnumerator.filter_actions_by_type(actions, "BUILD_SHIP")

# Analyze decision space
var space = FCWActionEnumerator.get_decision_space_size(state)
print("Build options: ", space.build)
print("Assign options: ", space.assign)
```

### 19.5 FCWStateEvaluator

**Purpose:** Objective functions and heuristics for AI decision-making.

**Primary Objective:** `lives_evacuated` - THE metric for success.

**Game Phases:**
| Phase | Detection | Strategy |
|-------|-----------|----------|
| `EARLY` | Herald at Kuiper/outer | Build fleet, minimize detection |
| `MID` | Herald at Jupiter/Asteroid | Mars blockade, start evacuation |
| `LATE` | Herald at Mars/inner | Maximize evacuation, sacrifice outer |
| `ENDGAME` | Earth threatened | Pure evacuation, all ships escort |

**Key Functions:**
| Function | Purpose |
|----------|---------|
| `evaluate(state)` | Primary: lives evacuated |
| `evaluate_terminal(state)` | With victory tier bonus |
| `evaluate_composite(state, weights)` | Weighted multi-factor |
| `score_action(state, action)` | Score by simulating |
| `rank_actions(state, actions)` | Rank all actions |
| `get_best_action(state, actions)` | Highest-scored action |
| `get_game_phase(state)` | Detect current phase |
| `get_phase_weights(phase)` | Phase-appropriate weights |
| `get_fleet_strength(state)` | Total combat power |
| `get_defense_ratio(state)` | Fleet vs Herald strength |
| `get_urgency(state)` | Time pressure factor |

**Usage:**
```gdscript
var state = store.get_state()
var phase = FCWStateEvaluator.get_game_phase(state)

# Get best build action
var actions = FCWActionEnumerator.get_valid_actions(state)
var builds = actions.filter(func(a): return a.type == "BUILD_SHIP")
var best = FCWStateEvaluator.get_best_action(state, builds)

# Rank all actions
var ranked = FCWStateEvaluator.rank_actions(state, actions)
for entry in ranked.slice(0, 5):
    print(FCWActionEnumerator.get_action_description(entry.action),
          " score: ", entry.score)
```

### 19.6 Human AI Integration

The Human AI in `fcw_main.gd` uses this infrastructure:

```gdscript
func _run_ai_turn() -> void:
    var state = store.get_state()
    var phase = FCWStateEvaluator.get_game_phase(state)

    match phase:
        FCWStateEvaluator.GamePhase.EARLY:
            _ai_early_game(state)  # Build fleet
        FCWStateEvaluator.GamePhase.MID:
            _ai_mid_game(state)    # Blockade + evacuate
        FCWStateEvaluator.GamePhase.LATE:
            _ai_late_game(state)   # Max evacuation
        FCWStateEvaluator.GamePhase.ENDGAME:
            _ai_endgame(state)     # Pure evacuation
```

Ship building uses action enumeration + ranking:
```gdscript
func _execute_ranked_build_actions(state: Dictionary) -> void:
    var all_actions = FCWActionEnumerator.get_valid_actions(state)
    var build_actions = all_actions.filter(func(a): return a.type == "BUILD_SHIP")
    var ranked = FCWStateEvaluator.rank_actions(state, build_actions)

    for entry in ranked:
        store.dispatch_build_ship(entry.action.ship_type)
```

---

## 20. Testing Determinism

Verify determinism is working:

```gdscript
# In GDScript console or test file
var runner = FCWHeadlessRunner

# Run same seed twice
var result1 = runner.run_game(12345)
var result2 = runner.run_game(12345)

# Should be identical
print("Lives match: ", result1.lives_evacuated == result2.lives_evacuated)
print("Tier match: ", result1.victory_tier == result2.victory_tier)
print("Ticks match: ", result1.ticks == result2.ticks)

# Formal verification
print("Determinism verified: ", FCWReplayManager.verify_determinism(12345, 500))
```

---

## 21. Herald Timeline Model

The Herald advances through the solar system weekly, choosing targets based on **detection signatures** accumulated from human activity. Players can manipulate these signatures to control the Herald's path.

### 21.1 Core Timeline

```
Week 1: Herald attacks Kuiper (starting position)
Week 2: Herald evaluates signatures → moves toward highest detection
Week 3+: Each week = attack current zone + evaluate + move toward next target
```

**Key principle:** The Herald is **always moving**. Every week it attacks, evaluates, and advances. Players cannot stop it—only redirect it.

### 21.2 Zone Adjacency & Reachability

```
┌─────────────────────────────────────────────────────────────────┐
│                    SOLAR SYSTEM GRAPH                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   KUIPER ──────► SATURN ◄────────► JUPITER                     │
│      │              │                  │                        │
│      │              ▼                  ▼                        │
│      └──────► ASTEROID_BELT ◄──────────┘                       │
│                    │                                            │
│                    ▼                                            │
│                  MARS                                           │
│                    │                                            │
│                    ▼                                            │
│                 EARTH                                           │
│                                                                 │
│   SKIP ROUTES (require signature > 0.4):                       │
│   - Saturn ──► Mars                                            │
│   - Jupiter ──► Mars                                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

From each zone, Herald can reach:
| Zone | Adjacent | Skip (sig > 0.4) |
|------|----------|------------------|
| Kuiper | Saturn, Jupiter | — |
| Saturn | Jupiter, Asteroid | Mars |
| Jupiter | Saturn, Asteroid | Mars |
| Asteroid | Jupiter, Mars | — |
| Mars | Asteroid, Earth | — |
| Earth | — (end) | — |

### 21.3 Detection Signatures

Each zone accumulates a **signature** (0.0 - 1.0+) based on human activity:

```gdscript
# Signature contribution weights (in FCWTypes)
SIG_POPULATION = 0.00000001    # Per person (10B = 0.1)
SIG_STATIONED_SHIP = 0.02      # Per ship stationed
SIG_PRODUCTION = 0.10          # Per ship built this week
SIG_TRANSIT = 0.15             # Per ship transiting through
SIG_ACTIVE_BURN = 0.30         # Per ship burning (VERY visible!)
SIG_COMBAT = 0.50              # Per combat event
SIG_EVACUATION = 0.20          # Per 1M people evacuating
```

**Signature decay:** Each week, all signatures multiply by `HERALD_SIG_DECAY = 0.6` (40% loss). Going dark works!

### 21.4 Target Selection Algorithm

```gdscript
static func choose_next_target(state: Dictionary, current_zone: int) -> int:
    # 1. Score adjacent zones
    for zone_id in get_zone_adjacent(current_zone):
        var sig = zone_signatures[zone_id]
        var orbit_diff = current_orbit - target_orbit  # Positive = inward
        var inward_bonus = 1.0 + (orbit_diff * 0.15)   # Slight inward preference
        var score = sig * inward_bonus + (0.05 if orbit_diff > 0 else 0.0)

    # 2. Score skip zones (only if signature > 0.4)
    for zone_id in get_zone_skip_targets(current_zone):
        if sig >= 0.4:
            score = sig * inward_bonus * 0.9  # Skip penalty

    # 3. If no strong signal, follow default inward path
    if best_target < 0:
        return ZONE_DEFAULT_NEXT[current_zone]
```

### 21.5 Player Strategies

| Strategy | How It Works | Signature Effect |
|----------|--------------|------------------|
| **Decoy Fleet** | Build/patrol ships at outer zones | +0.3-0.5 per burn |
| **Stealth Evacuation** | Use coast-only transports | -90% signature vs burn |
| **Go Dark** | Stop production, recall ships | Sig decays 40%/week |
| **Trail Cutting** | Scuttle detected ships | Removes known routes |
| **Blockade Sacrifice** | Station fleet, buy time | Combat draws Herald |

### 21.6 Dramatic Event Messages

The Herald AI generates dramatic messages for major events:

**Zone Attack:**
```
━━━ PRIORITY ALERT ━━━
EUROPA BASE: "God help us. It's bigger than the images showed."
GANYMEDE STATION: "All available ships, break orbit NOW! Do not engage!"
IO MINING CONSORTIUM: "We can see it from here. The sky is burning."
Jupiter system: 2.0M civilians in the engagement zone.
```

**Movement (high signature):**
```
━━━ HERALD MOVEMENT DETECTED ━━━
DEEP SPACE NETWORK: "It's changing course. Heading directly for Mars."
INTELLIGENCE: "It detected our activity. Signature level: 52%"
MARS DEFENSE: "All hands, prepare for engagement. This is not a drill."
```

**Movement (default path):**
```
━━━ HERALD MOVEMENT DETECTED ━━━
OBSERVATORY: "Herald continuing inward from Jupiter toward Asteroid Belt."
COMMAND: "Default trajectory. It hasn't detected our main operations... yet."
```

### 21.7 Example Timeline

| Week | Herald Position | Detection | Player Action | Outcome |
|------|-----------------|-----------|---------------|---------|
| 1 | Kuiper | — | Build fleet at Jupiter (+0.3) | — |
| 2 | → Jupiter | Jupiter highest | Decoy burns at Saturn (+0.4) | Herald follows default |
| 3 | Jupiter (attack) | Saturn now higher | Start Mars evacuation (quiet) | Jupiter falls |
| 4 | → Saturn | Followed decoy! | Continue evacuation | Decoy worked! |
| 5 | Saturn (attack) | Mars sig low | Scuttle decoy fleet | Saturn falls |
| 6 | → Asteroid | Default inward | Earth evacuation begins | Bought 2 weeks |
| 7 | Asteroid (attack) | Mars sig from evac | Blockade at Mars | Asteroid falls |
| 8 | → Mars | Detected evac | Final Earth evacuation | Blockade delays |
| 9 | Mars (battle) | Earth visible | Last transports depart | Mars falls |
| 10 | → Earth | Game over | How many evacuated? | — |

### 21.8 Implementation Files

| File | Functions |
|------|-----------|
| `fcw_types.gd` | Zone adjacency, signature constants, orbit order |
| `fcw_herald_ai.gd` | `process_weekly_herald_turn()`, `choose_next_target()`, `update_zone_signatures()`, `decay_zone_signatures()`, dramatic messages |
| `fcw_reducer.gd` | `_track_activity()`, activity tracking in build/transit/combat/evacuation |
| `fcw_store.gd` | `zone_signatures`, `weekly_activity` in state |

### 21.9 Key Constants

```gdscript
# Behavior tuning (in FCWTypes)
HERALD_SIG_DECAY = 0.6         # 40% signature loss per week
HERALD_SKIP_THRESHOLD = 0.4    # Minimum sig to skip zones
HERALD_INWARD_BIAS = 0.15      # Preference for moving toward Sun
HERALD_MIN_SIG_TO_ATTRACT = 0.1  # Below this, zone doesn't attract

# Timing
HERALD_ATTACK_DURATION = 0     # Instant attack
HERALD_TRAVEL_TIME = 1         # 1 week between zones
```

### 21.10 Winning Strategy

The key insight: **You control the Herald's path through activity management.**

1. **Week 1-2:** Build fleet aggressively (Earth signature rises, but Herald starts at Kuiper)
2. **Week 3-4:** Create decoy activity at Saturn/Jupiter while keeping Mars dark
3. **Week 5-6:** Herald follows decoys; begin quiet Mars evacuation (coast-only transports)
4. **Week 7-8:** Sacrifice outer colonies, all resources to Earth evacuation
5. **Week 9-10:** Blockade at Mars buys final days; transports escape to Kuiper

The game is won not by defeating the Herald, but by **leading it on a longer path while evacuating as many souls as possible.**
