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

### Scripts (11 files)
| File | Lines | Purpose | Dependencies |
|------|-------|---------|--------------|
| `fcw_main.gd` | ~1475 | UI controller, game loop, AI orchestration | Store, SolarMap, BattleView |
| `fcw_store.gd` | ~350 | State container, signals, dispatch | Reducer, Types |
| `fcw_reducer.gd` | ~1750 | Pure game logic, state transitions | Types, Time, Orbital, HeraldAI |
| `fcw_types.gd` | ~780 | Enums, constants, factories, state shape | None |
| `fcw_solar_map.gd` | ~3900 | Procedural rendering, visual effects | Types |
| `fcw_battle_view.gd` | ~400 | Cinematic battle window | Types |
| `fcw_planet_view.gd` | ~200 | Planet detail PiP window | Types |
| `fcw_battle_system.gd` | ~300 | Named ship management | Types |
| `fcw_time.gd` | ~200 | Time utilities, travel times | None |
| `fcw_orbital.gd` | ~330 | Route planning, intercept math | Types |
| `fcw_herald_ai.gd` | ~490 | Herald decision-making, detection | Types |

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
│   Current State:                                                    │
│   ✅ Entity data structures defined                                │
│   ✅ Entity movement processing                                    │
│   ✅ Entity arrival handling                                       │
│   ✅ Herald as entity                                              │
│   ✅ Detection system                                              │
│   ✅ Intercept mechanics                                           │
│   ✅ Entity signal emission                                        │
│   🟡 UI for entity control (not exposed)                           │
│   🟡 Route selection UI (not implemented)                          │
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
