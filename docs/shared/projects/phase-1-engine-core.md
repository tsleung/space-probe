# Phase 1: Engine Core Foundation

**Status:** Complete
**Duration:** Session 1

---

## Objective

Create the foundational engine infrastructure that all games will use.

---

## Components Created

### 1. Result Type (`scripts/engine/types/result.gd`)

Explicit error handling - no more silent failures.

```gdscript
# Usage
var result = some_operation()
if result.is_ok():
    var value = result.get_value()
else:
    var error = result.get_error()
    print("Error [%s]: %s" % [error.code, error.message])
```

**Key Methods:**
- `Result.ok(value)` - Create success result
- `Result.err(error_dict)` - Create error result
- `Result.error(code, message, context)` - Helper for creating errors
- `is_ok()` / `is_err()` - Check result type
- `unwrap_or(default)` - Get value or default
- `map(callable)` / `and_then(callable)` - Chain operations

### 2. RNG Manager (`scripts/engine/core/rng_manager.gd`)

Centralized, seedable randomness for deterministic replay.

```gdscript
var rng = RNGManager.new(12345)  # Seeded
var roll = rng.randf()           # 0.0 to 1.0
var rolls = rng.randf_array(5)   # Multiple rolls for an action
var item = rng.pick_weighted(items, weights)  # Weighted selection
```

**Key Features:**
- Seedable for replay/testing
- Call counting for debugging
- State serialization for save/load
- Weighted random selection
- Dice rolling utilities

### 3. Action Types (`scripts/engine/types/action_types.gd`)

All action type constants and creator functions.

```gdscript
# Constants
ActionTypes.PLACE_COMPONENT
ActionTypes.ADVANCE_TRAVEL_DAY
ActionTypes.SELECT_EVENT_CHOICE

# Action creators
var action = ActionTypes.place_component("nuclear_engine", Vector2i(2, 3))
var action = ActionTypes.hire_crew("santos")
```

**Categories:**
- Core (initialize, load, save)
- Phase transitions
- Ship building
- Crew management
- Resources
- Events
- Travel
- Mars base

### 4. Game Types (`scripts/engine/types/game_types.gd`)

Enums, constants, and factory functions.

```gdscript
# Enums
GameTypes.GamePhase.TRAVEL_TO_MARS
GameTypes.ComponentState.DEGRADED
GameTypes.CrewStatus.HEALTHY

# Factory functions
var state = GameTypes.create_game_state("mars_mission", "normal")
var component = GameTypes.create_component("engine", definition, position)
var crew = GameTypes.create_crew_member(definition)

# Immutable updates
var new_state = GameTypes.with_field(state, "current_day", 5)
var new_state = GameTypes.with_fields(state, {"day": 5, "phase": "travel"})
```

### 5. Store (`scripts/engine/core/store.gd`)

Single source of truth for game state.

```gdscript
var store = Store.new()

# Signals
store.state_changed.connect(_on_state_changed)
store.error_occurred.connect(_on_error)

# Dispatch
var result = store.dispatch(action)
if not result.is_ok():
    handle_error(result.get_error())

# With random values
store.dispatch_with_random(action, 5)  # Inject 5 random values
```

**Responsibilities:**
- Hold state (single source of truth)
- Validate actions before dispatch
- Route actions to reducers
- Emit signals on changes
- Manage RNG
- Handle persistence

### 6. Dispatcher (`scripts/engine/core/dispatcher.gd`)

Routes actions to the correct reducer.

```gdscript
var dispatcher = Dispatcher.new()
dispatcher.register_reducer("mars_mission", "ship_building", ShipBuildingReducer.new())
dispatcher.register_reducer("mars_mission", "travel", TravelReducer.new())
```

**Features:**
- Phase-specific reducers
- Game-level reducers (cross-phase)
- Global reducers (all games)
- Built-in core action handling

### 7. Action Validator (`scripts/engine/validation/action_validator.gd`)

Validates all actions before dispatch.

```gdscript
# Validation levels
1. Structure   - Has required fields?
2. Types       - Fields are correct types?
3. References  - Referenced IDs exist?
4. Business    - Action allowed in current state?
```

**Error Examples:**
```gdscript
{
    "code": "POSITION_OCCUPIED",
    "message": "Position (2, 3) is already occupied",
    "position": {"q": 2, "r": 3},
    "occupying_component": "fuel_tank"
}
```

### 8. Persistence (`scripts/engine/core/persistence.gd`)

Save/load game state.

```gdscript
var persistence = Persistence.new()
persistence.save("save1.json", data)
var result = persistence.load_file("save1.json")
var saves = persistence.list_saves()
```

**Features:**
- JSON save format
- Auto-save with timestamps
- Save listing and info
- Export/import for sharing
- Version validation

### 9. Game Loader (`scripts/engine/core/game_loader.gd`)

Loads game definitions from data files.

```gdscript
var loader = GameLoader.new()
var result = loader.load_game("mars_mission")
var component = loader.get_component("mars_mission", "nuclear_engine")
var games = loader.list_available_games()
```

**Loads:**
- Manifest
- Components
- Engines
- Crew roster
- Events (by phase)
- Balance config
- Shared content

### 10. Schema Validator (`scripts/engine/validation/schema_validator.gd`)

Validates loaded game data.

```gdscript
var validator = SchemaValidator.new()
var result = validator.validate_game(game_data)
```

**Validates:**
- Manifest structure
- Component fields
- Engine fields
- Crew fields
- Event structure
- Balance sections
- Cross-references (event triggers, relationships)

---

## Directory Structure Created

```
scripts/engine/
├── core/
│   ├── store.gd
│   ├── dispatcher.gd
│   ├── rng_manager.gd
│   ├── persistence.gd
│   └── game_loader.gd
├── validation/
│   ├── action_validator.gd
│   └── schema_validator.gd
└── types/
    ├── result.gd
    ├── action_types.gd
    └── game_types.gd
```

---

## Design Decisions

### Why Result<T, E> instead of exceptions?

GDScript doesn't have exceptions. We could use signals for errors, but that makes control flow hard to follow. Result types:
- Make error handling explicit at call sites
- Carry error context (code, message, details)
- Enable chaining with `map()` and `and_then()`
- Work well with LLMs (clear success/failure paths)

### Why centralized RNG?

- **Determinism**: Same seed = same game (for testing/replay)
- **No hidden state**: Random values passed into pure functions
- **Debuggability**: Can log all random calls
- **Save/load**: RNG state preserved in saves

### Why action creators?

- **Type safety**: Ensures required fields present
- **Discoverability**: IDE autocomplete shows available actions
- **Consistency**: Standard structure for all actions
- **Documentation**: Function signatures document action shapes

### Why validation layers?

Early validation catches errors before they corrupt state:
1. **Structural**: Malformed actions caught immediately
2. **Type**: Wrong types caught before reducer runs
3. **Reference**: Invalid IDs caught before lookup fails
4. **Business**: Invalid operations caught with context

---

## Testing Strategy

All these components are pure or have minimal side effects, making them testable:

```gdscript
# Result type
func test_result_ok():
    var r = Result.ok(42)
    assert_true(r.is_ok())
    assert_eq(r.get_value(), 42)

# RNG determinism
func test_rng_deterministic():
    var rng1 = RNGManager.new(12345)
    var rng2 = RNGManager.new(12345)
    assert_eq(rng1.randf(), rng2.randf())

# Validation
func test_validates_missing_type():
    var validator = ActionValidator.new()
    var result = validator.validate({}, {})
    assert_true(result.is_err())
    assert_eq(result.get_error().code, "MISSING_ACTION_TYPE")
```

---

## Next Steps

Phase 2 will:
1. Create data file structure in `data/games/mars_mission/`
2. Migrate existing balance numbers to `balance.json`
3. Migrate component definitions to `components.json`
4. Migrate crew roster to `crew_roster.json`
5. Create event JSON files

---

## Files Created

| File | LOC | Purpose |
|------|-----|---------|
| `result.gd` | ~120 | Error handling type |
| `rng_manager.gd` | ~180 | Centralized randomness |
| `action_types.gd` | ~280 | Action definitions |
| `game_types.gd` | ~320 | Enums and factories |
| `store.gd` | ~200 | State container |
| `dispatcher.gd` | ~150 | Action routing |
| `action_validator.gd` | ~300 | Action validation |
| `persistence.gd` | ~200 | Save/load |
| `game_loader.gd` | ~220 | Data loading |
| `schema_validator.gd` | ~280 | Data validation |
| **Total** | ~2,250 | Engine foundation |
