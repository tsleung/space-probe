# Architecture Overview

SpaceProbe uses a **Redux-style architecture** optimized for LLM-assisted development. This document explains the high-level design.

---

## Core Philosophy

> **Game as Data, Engine as Code**

- **Game content** (components, events, balance) lives in JSON files
- **Engine logic** (how things work) lives in GDScript
- **UI** is a thin layer that renders state and dispatches actions

This separation allows:
- Designers to modify content without touching code
- LLMs to safely edit game content
- Engine code to remain stable while content evolves
- Multiple games (Mars Mission, FCW, VNP) to share the same engine

---

## The Three Layers

```
┌─────────────────────────────────────────────────────────────┐
│                         UI LAYER                            │
│  (Renders state, captures input, dispatches actions)        │
│  - ship_building_ui.gd                                      │
│  - travel_ui.gd                                             │
│  - Stateless except for local UI concerns                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ signals, dispatch()
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        STORE LAYER                          │
│  (Single source of truth, handles side effects)             │
│  - store.gd: State container                                │
│  - dispatcher.gd: Routes actions to reducers                │
│  - rng_manager.gd: All randomness                           │
│  - persistence.gd: Save/load                                │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ pure function calls
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                       LOGIC LAYER                           │
│  (Pure functions, deterministic, testable)                  │
│  - Engine systems (hex_grid, resources, crew, events)       │
│  - Game reducers (ship_building, travel, mars_base)         │
│  - Validation (action_validator, schema_validator)          │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ reads
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        DATA LAYER                           │
│  (JSON files, game content)                                 │
│  - components.json, events/*.json                           │
│  - balance.json, crew_roster.json                           │
│  - Loaded at startup, validated against schemas             │
└─────────────────────────────────────────────────────────────┘
```

---

## Data Flow

### Action Dispatch Flow

```
1. User clicks "Place Component"
   │
   ▼
2. UI calls store.dispatch({
     type: "PLACE_COMPONENT",
     component_id: "nuclear_engine",
     position: Vector2i(2, 3)
   })
   │
   ▼
3. Store validates action via ActionValidator
   │
   ├─► If invalid: emit error_occurred signal, return Result.err()
   │
   ▼
4. Dispatcher routes to correct reducer (ShipBuildingReducer)
   │
   ▼
5. Reducer returns new state (pure function, no side effects)
   │
   ▼
6. Store updates _state, emits state_changed signal
   │
   ▼
7. UI receives signal, calls _sync_to_state(new_state)
   │
   ▼
8. UI updates display
```

### State Change Rules

1. **Only Store mutates state** - Logic layer returns new state
2. **All changes via dispatch** - No direct state modification
3. **Signals notify changes** - UI subscribes to signals
4. **State is the truth** - UI derives everything from state

---

## Key Components

### Store (scripts/engine/core/store.gd)

The single source of truth. Responsibilities:
- Hold current game state
- Validate actions before dispatch
- Route actions to reducers
- Emit signals on state change
- NO game logic (that's in reducers)

```gdscript
class_name Store

signal state_changed(old_state, new_state)
signal action_dispatched(action)
signal error_occurred(error)

var _state: Dictionary = {}

func dispatch(action: Dictionary) -> Result:
    # Validate → Reduce → Emit
```

### Reducers (scripts/games/*/reducers/)

Pure functions that transform state. Each game phase has its own reducer.

```gdscript
class_name TravelReducer

static func reduce(state: Dictionary, action: Dictionary, game_data: Dictionary, rng: RNGManager) -> Dictionary:
    match action.type:
        "ADVANCE_DAY":
            return _reduce_advance_day(state, action, game_data, rng)
        # ...
```

Reducer rules:
- **Pure**: Same inputs → same outputs
- **Immutable**: Return new state, don't mutate
- **Focused**: One reducer per phase
- **Testable**: No dependencies on Store

### Systems (scripts/engine/systems/)

Reusable logic shared across games. Examples:
- **HexGridSystem**: Hex math, placement validation
- **ResourceSystem**: Consumption, production, scarcity
- **CrewSystem**: Stats, relationships, tasks
- **EventSystem**: Triggering, resolution, cooldowns
- **ComponentSystem**: Quality, wear, failure

Systems are:
- **Game-agnostic**: Work with any game's data
- **Pure functions**: Static methods, no state
- **Composable**: Can be combined in reducers

### Game Data (data/games/*)

JSON files defining game content:

```
data/games/mars_odyssey_trek/   # MOT
├── manifest.json      # Game metadata
├── phases.json        # Phase definitions
├── components.json    # Ship components
├── engines.json       # Engine types
├── crew_roster.json   # Available crew
├── events/            # Events by phase
│   ├── phase1.json
│   ├── phase2.json
│   ├── phase3.json
│   └── phase4.json
└── balance.json       # All numbers
```

### Validation (scripts/engine/validation/)

Two validators ensure correctness:

1. **SchemaValidator**: Validates JSON files on load
   - Required fields present
   - Types correct
   - References valid

2. **ActionValidator**: Validates actions before dispatch
   - Action structure valid
   - Parameters correct type
   - Business rules satisfied

---

## State Structure

```gdscript
{
    # Meta
    "game_id": "mot",
    "current_phase": "travel_to_mars",
    "difficulty": "normal",

    # Time
    "current_day": 47,
    "total_travel_days": 180,

    # Ship
    "ship": {
        "components": [...],
        "hex_grid": {...},
        "total_mass": 145
    },

    # Crew
    "crew": [
        {
            "id": "santos",
            "health": 92,
            "morale": 78,
            "current_task": "navigation",
            "relationships": {"chen": 65, "okonkwo": 45}
        },
        # ...
    ],

    # Resources
    "resources": {
        "food": {"current": 450, "max": 600},
        "water": {"current": 380, "max": 500},
        "oxygen": {"current": 290, "max": 400},
        "fuel": {"current": 850, "max": 1000}
    },

    # Events
    "active_events": [],
    "event_cooldowns": {},
    "triggered_flags": ["chen_opened_up"],

    # History
    "mission_log": [...],
    "action_history": [...]  # For replay/debugging
}
```

---

## Error Handling

All fallible operations return `Result`:

```gdscript
class_name Result

static func ok(value) -> Result
static func err(error: Dictionary) -> Result

func is_ok() -> bool
func get_value()
func get_error() -> Dictionary
func unwrap_or(default)
```

Error structure:
```gdscript
{
    "code": "POSITION_OCCUPIED",        # Machine-readable
    "message": "Cannot place here",     # Human-readable
    "position": Vector2i(2, 3),         # Context
    "occupying_component": "fuel_tank"  # More context
}
```

UI can handle errors gracefully:
```gdscript
func _on_place_component():
    var result = store.dispatch(action)
    if not result.is_ok():
        _show_error_message(result.get_error().message)
```

---

## Testing Strategy

### Unit Tests (tests/unit/)

Test pure functions in isolation:
- Systems: hex_grid, resources, crew, events
- Reducers: each action type
- Validators: valid and invalid cases
- Utilities: hex math, formulas

```gdscript
func test_consume_daily_reduces_food():
    var state = create_test_state()
    var balance = create_test_balance()
    var rng = RNGManager.new(12345)

    var new_state = ResourceSystem.consume_daily(state, balance, rng)

    assert_eq(new_state.resources.food.current, 92.0)
```

### Integration Tests (tests/integration/)

Test component interactions:
- Phase transitions
- Event chains
- Full game scenarios

### What We Don't Test

- UI rendering (manual testing)
- Godot engine behavior (trust the engine)
- Exact random outcomes (test distributions instead)

---

## File Organization

```
space-probe/
├── data/                    # Game content (JSON)
│   ├── games/              # Per-game content
│   ├── shared/             # Shared content
│   └── difficulty.json     # Difficulty settings
│
├── scripts/
│   ├── engine/             # Game-agnostic engine
│   │   ├── core/          # Store, RNG, persistence
│   │   ├── validation/    # Validators
│   │   ├── systems/       # Reusable systems
│   │   ├── types/         # Type definitions
│   │   └── utils/         # Utilities
│   │
│   ├── games/              # Game-specific code
│   │   ├── mot/           # MOT (Mars Odyssey Trek)
│   │   ├── fcw/           # FCW (First Contact War)
│   │   ├── vnp/           # VNP (Von Neumann Probe)
│   │   └── mcs/           # MCS (Mars Colony Sim)
│   │
│   ├── ui/                 # UI layer
│   │   ├── shared/        # Shared components
│   │   └── [game]/        # Game-specific UI
│   │
│   └── autoload/           # Godot autoloads
│
├── tests/                   # Test suite
│   ├── unit/              # Pure function tests
│   ├── integration/       # System tests
│   └── fixtures/          # Test data
│
├── scenes/                  # Godot scenes
│
└── docs/                    # Documentation
    ├── architecture/       # This stuff
    └── principles/         # Engineering principles
```

---

## Adding New Features

### Adding a New Event

1. Edit `data/games/[game]/events/[phase].json`
2. Schema validation ensures correctness
3. No code changes needed

### Adding a New Component

1. Edit `data/games/[game]/components.json`
2. If special behavior needed, add to reducer
3. Add tests for special behavior

### Adding a New System

1. Create `scripts/engine/systems/[name]_system.gd`
2. Implement as static pure functions
3. Add unit tests
4. Use in reducers as needed

### Adding a New Game

1. Create `data/games/[game]/` with manifest and content
2. Create `scripts/games/[game]/` with reducers
3. Create `scripts/ui/[game]/` for UI
4. Register in GameLoader

---

## Design Decisions

### Why Redux-style?

- **Predictable**: One-way data flow
- **Debuggable**: Can log/replay all actions
- **Testable**: Pure reducers
- **LLM-friendly**: Clear patterns

### Why JSON for Content?

- **Human-readable**: Easy to review/edit
- **LLM-safe**: Claude can edit without code risk
- **Moddable**: Players can customize
- **Validatable**: Schemas catch errors

### Why Static Functions?

- **No hidden state**: All inputs explicit
- **Testable**: No mocking needed
- **Composable**: Easy to combine
- **Fast**: No object overhead

### Why Separate Reducers per Phase?

- **Focused**: Each reducer ~250 LOC
- **Isolated**: Phase changes don't affect others
- **Parallel development**: Work on phases independently
- **LLM-friendly**: Fits in context window

---

## See Also

- [Refactor Plan](./refactor-plan.md) - Migration steps
- [Engineering Principles](../principles/engineering-principles.md) - Code guidelines
- [LLM Development](../principles/llm-development.md) - Working with Claude
- [Data Schema](../data-schema.md) - Content file formats
- [Balance & Numbers](../balance-and-numbers.md) - Game tuning
