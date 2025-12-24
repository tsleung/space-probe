# Mars Odyssey Trek - Phase Architecture

## Overview

MOT has 6 gameplay phases with 2 transition states:

```
Phase 1: Ship Building
    ↓
Phase 2: Travel to Mars (183 days)
    ↓
[Mars Arrival - transition]
    ↓
Phase 3: Mars Base Operations
    ↓
[Mars Departure - transition]
    ↓
Phase 4: Return Journey
    ↓
[Earth Arrival - transition]
    ↓
Game Over / Results
```

---

## Phase 1: Ship Building

**Status:** COMPLETE

### Files
| File | Lines | Purpose |
|------|-------|---------|
| `mot_main.gd` | 437 | Main controller, UI orchestration |
| `mot_store.gd` | 303 | State management, signals |
| `mot_types.gd` | 398 | Enums, factories, constants |
| `mot_orbital.gd` | ~200 | Launch window calculations |

### Scenes
```
scenes/mars_odyssey_trek/
├── phase1_main.tscn          # Main scene
├── orbital_selector.tscn     # Launch window picker
├── approach_selector.tscn    # Construction approach
├── engine_selector.tscn      # Engine selection
├── ship_class_selector.tscn  # Ship class
├── life_support_selector.tscn
├── crew_selector.tscn
├── cargo_loader.tscn
├── launch_review.tscn        # Final checklist
└── launch_animation.tscn
```

### State Shape
```gdscript
{
    phase: MOTTypes.Phase.SHIP_BUILDING,
    difficulty: String,
    budget_total: int,
    budget_remaining: int,
    budget_spent: int,

    # Selections
    launch_window: Dictionary,      # MOTOrbital.LaunchWindow
    construction_approach: int,     # ConstructionApproach enum
    engine: int,                    # EngineType enum
    ship_class: int,                # ShipClass enum
    life_support: int,              # LifeSupportTier enum
    upgrades: Array,                # upgrade IDs
    crew: Array,                    # 4 crew member IDs

    # Cargo
    cargo_capacity: int,
    cargo_used: int,
    cargo_manifest: {
        food_days: int,
        water_reserve: int,
        spare_parts: int,
        medical_kits: int,
        equipment: int
    },

    # Computed
    fuel_required: int,
    travel_days_estimate: int,
    reliability_estimate: float,
    is_ready_to_launch: bool,
    readiness_issues: Array
}
```

### Architecture Pattern
- **Store Pattern** (not Redux): MOTStore holds state, emits signals
- **Wizard Flow**: 8-step linear progression
- **Signal-Driven UI**: Components react to budget_changed, readiness_changed

### Data Files
- `data/games/mars_odyssey_trek/balance.json` - Budget, costs
- `data/games/mars_odyssey_trek/crew_roster.json` - Available crew

---

## Phase 2: Travel to Mars

**Status:** COMPLETE (recently refactored)

### Files
| File | Lines | Purpose |
|------|-------|---------|
| `phase2/phase2_types.gd` | 280 | Enums, factories, constants |
| `phase2/phase2_reducer.gd` | 470 | Pure state transformations |
| `phase2/phase2_store.gd` | 400 | Signals, dispatch, RNG |
| `phase2/phase2_view.gd` | 400 | Visual rendering |
| `phase2/phase2_controller.gd` | 140 | Input, game loop |
| `phase2/phase2_main_v2.gd` | 55 | Coordinator |

### Scenes
```
scenes/mars_odyssey_trek/
├── phase2_v2.tscn    # Current (Store/Reducer architecture)
└── phase2_main.tscn  # Legacy (archived)
```

### State Shape
```gdscript
{
    current_day: 1,
    total_days: 183,
    speed: Phase2Types.Speed.NORMAL,
    auto_advance: true,

    resources: {
        food: {current: 800, max: 800},
        water: {current: 400, max: 400},
        oxygen: {current: 100, max: 100},
        power: {current: 45, max: 50},
        fuel: {current: 100, max: 100}
    },

    storage_containers: [
        {id: "cargo_a", name: "Cargo Bay A", food: 250, water: 100, accessible: true, status: NOMINAL},
        {id: "cargo_b", name: "Cargo Bay B", food: 300, water: 150, accessible: true, status: NOMINAL},
        {id: "cargo_c", name: "Cargo Bay C", food: 200, water: 100, accessible: true, status: NOMINAL},
        {id: "emergency", name: "Emergency", food: 50, water: 50, accessible: true, status: NOMINAL}
    ],

    crew: [
        {id: "commander", role: COMMANDER, health: 100, morale: 85, fatigue: 0},
        {id: "engineer", role: ENGINEER, health: 100, morale: 80, fatigue: 0},
        {id: "scientist", role: SCIENTIST, health: 100, morale: 75, fatigue: 0},
        {id: "medical", role: MEDICAL, health: 100, morale: 80, fatigue: 0}
    ],

    repair: {in_progress: false, days_remaining: 0, target_container_id: ""},
    active_event: {},
    mars_visible: false,
    log: []
}
```

### Architecture Pattern
- **Redux-like**: Pure reducer with action creators
- **Immutable Updates**: `state.duplicate(true)` pattern
- **Signal Reactivity**: View subscribes to store signals
- **Separation**: Types / Reducer / Store / View / Controller

### Action Types
```gdscript
enum ActionType {
    ADVANCE_DAY,
    SET_SPEED,
    SET_AUTO_ADVANCE,
    TRIGGER_EVENT,
    RESOLVE_EVENT,
    BLOCK_SECTION,
    START_REPAIR,
    EVA_RETRIEVAL,
    ADD_LOG
}
```

### Tests
- `tests/unit/test_phase2_reducer.gd` - 46 unit tests

---

## Phase 3: Mars Base Operations

**Status:** PARTIAL (needs refactor to new architecture)

### Current Files (Legacy)
| File | Lines | Purpose |
|------|-------|---------|
| `scripts/phases/mars_base.gd` | 568 | Combined store/view/controller |

### Needed Refactor
```
phase3/
├── phase3_types.gd      # TO CREATE
├── phase3_reducer.gd    # TO CREATE
├── phase3_store.gd      # TO CREATE
├── phase3_view.gd       # TO CREATE
└── phase3_controller.gd # TO CREATE
```

### Planned State Shape
```gdscript
{
    current_sol: 1,           # Martian days
    total_sols: 30,           # Mission duration on surface

    # Carried from Phase 2
    crew: Array,              # Same 4 crew, updated stats
    resources: Dictionary,    # Remaining supplies
    damaged_components: Array,# Component states

    # Base operations
    base_modules: [
        {id: "hab", type: HABITAT, health: 100, power_draw: 5},
        {id: "lab", type: LABORATORY, health: 100, power_draw: 8},
        # ...
    ],

    # Activities
    crew_assignments: {
        "commander": "exploration",
        "engineer": "maintenance",
        "scientist": "experiments",
        "medical": "health_monitoring"
    },

    experiments: [
        {id: "soil_analysis", progress: 0, required_sols: 5, assigned_crew: "scientist"},
        # ...
    ],

    samples_collected: [],
    exploration_sites: [],

    # Departure readiness
    departure_checklist: {
        fuel_loaded: false,
        samples_secured: false,
        crew_healthy: false,
        systems_nominal: false
    }
}
```

### Key Mechanics (from design docs)
- Sol-by-sol progression
- Crew activity assignment
- Experiment execution with progress tracking
- EVA expeditions with suit timers
- Sample collection
- Base module health
- Departure checklist

---

## Phase 4: Return Journey

**Status:** PARTIAL (needs refactor to new architecture)

### Current Files (Legacy)
| File | Lines | Purpose |
|------|-------|---------|
| `scripts/phases/return_journey.gd` | 666 | Combined store/view/controller |

### Needed Refactor
```
phase4/
├── phase4_types.gd      # TO CREATE
├── phase4_reducer.gd    # TO CREATE
├── phase4_store.gd      # TO CREATE
├── phase4_view.gd       # TO CREATE
└── phase4_controller.gd # TO CREATE
```

### Planned State Shape
```gdscript
{
    current_day: 1,
    total_days: 180,          # Return journey duration

    # Carried from Phase 3
    crew: Array,
    resources: Dictionary,
    samples: Array,           # Scientific samples from Mars
    damaged_components: Array,

    # Same as Phase 2 travel
    speed: Speed.NORMAL,
    auto_advance: true,
    active_event: {},

    # Reentry sequence (final days)
    reentry_stage: ReentryStage.APPROACH,
    reentry_checks: {
        heat_shield: {status: UNKNOWN, quality: 0.0},
        navigation: {status: UNKNOWN, quality: 0.0},
        parachutes: {status: UNKNOWN, quality: 0.0},
        landing_systems: {status: UNKNOWN, quality: 0.0}
    },

    # Results
    mission_rating: null,     # GOLD, SILVER, BRONZE, FAILED
    final_score: 0,
    epilogue_text: ""
}
```

### Reentry Stages
```gdscript
enum ReentryStage {
    APPROACH,      # Final approach to Earth
    HEAT_SHIELD,   # Atmospheric entry
    PARACHUTE,     # Chute deployment
    LANDING,       # Final descent
    COMPLETE,      # Success
    FAILED         # Failure
}
```

---

## Phase Transitions

### Phase 1 → Phase 2
**Trigger:** Launch button pressed, all readiness checks pass

**State Transfer:**
```gdscript
# From Phase 1 → Phase 2
phase2_state.total_days = phase1_state.travel_days_estimate
phase2_state.resources.fuel.max = phase1_state.fuel_required
phase2_state.crew = _convert_crew_to_phase2_format(phase1_state.crew)
phase2_state.storage_containers = _init_containers_from_cargo(phase1_state.cargo_manifest)
```

### Phase 2 → Phase 3
**Trigger:** current_day >= total_days (183)

**State Transfer:**
```gdscript
# From Phase 2 → Phase 3
phase3_state.crew = phase2_state.crew  # With updated health/morale
phase3_state.resources = phase2_state.resources
phase3_state.damaged_components = _extract_damaged_containers(phase2_state)
```

### Phase 3 → Phase 4
**Trigger:** Departure checklist complete

**State Transfer:**
```gdscript
# From Phase 3 → Phase 4
phase4_state.crew = phase3_state.crew
phase4_state.resources = _load_return_resources(phase3_state)
phase4_state.samples = phase3_state.samples_collected
```

---

## Migration Checklist

### Phase 3 Migration
- [ ] Create `phase3/phase3_types.gd` with enums and factories
- [ ] Create `phase3/phase3_reducer.gd` with pure functions
- [ ] Create `phase3/phase3_store.gd` with signals
- [ ] Create `phase3/phase3_view.gd` for rendering
- [ ] Create `phase3/phase3_controller.gd` for game loop
- [ ] Create `phase3_v2.tscn` scene
- [ ] Write unit tests for reducer
- [ ] Implement phase2→phase3 transition
- [ ] Archive legacy `mars_base.gd`

### Phase 4 Migration
- [ ] Create `phase4/phase4_types.gd`
- [ ] Create `phase4/phase4_reducer.gd`
- [ ] Create `phase4/phase4_store.gd`
- [ ] Create `phase4/phase4_view.gd`
- [ ] Create `phase4/phase4_controller.gd`
- [ ] Create `phase4_v2.tscn` scene
- [ ] Implement reentry sequence logic
- [ ] Implement scoring/rating system
- [ ] Write unit tests for reducer
- [ ] Implement phase3→phase4 transition
- [ ] Archive legacy `return_journey.gd`
