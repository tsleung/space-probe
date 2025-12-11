# Architecture Refactor: "Game as Data, Engine as Code"

A comprehensive refactoring plan to create a robust, LLM-friendly architecture that treats game content as data and keeps the engine minimal and pure.

---

## Goals

1. **LLM Safety** - Claude Code can modify game content without risking engine stability
2. **Expansion Parity** - Mars Mission, FCW, VNP, Colony Sim are equal citizens
3. **Testability** - All pure logic has unit tests as a safety net
4. **Modularity** - Each system is self-contained and replaceable
5. **Data-Driven** - Game designers describe mechanics in JSON, not GDScript

---

## New Directory Structure

```
space-probe/
├── data/                           # ALL game content (JSON/Resources)
│   ├── games/                      # Game-specific content
│   │   ├── mars_mission/           # Oregon Trail Mars
│   │   │   ├── manifest.json       # Game metadata
│   │   │   ├── phases.json         # Phase definitions
│   │   │   ├── components.json     # Ship components
│   │   │   ├── engines.json        # Engine types
│   │   │   ├── crew_roster.json    # Available crew
│   │   │   ├── events/             # Event definitions by phase
│   │   │   │   ├── phase1.json
│   │   │   │   ├── phase2.json
│   │   │   │   ├── phase3.json
│   │   │   │   └── phase4.json
│   │   │   └── balance.json        # All magic numbers
│   │   ├── fcw/                    # First Contact War
│   │   ├── vnp/                    # Von Neumann Probe
│   │   └── colony_sim/             # Colony Simulation
│   ├── shared/                     # Content shared across games
│   │   ├── traits.json             # Crew traits
│   │   ├── conditions.json         # Status conditions
│   │   └── achievements.json       # Cross-game achievements
│   └── difficulty.json             # Difficulty settings
│
├── scripts/
│   ├── engine/                     # Game-agnostic engine code
│   │   ├── core/                   # Core engine systems
│   │   │   ├── store.gd            # Minimal state container + dispatch
│   │   │   ├── dispatcher.gd       # Action routing and middleware
│   │   │   ├── rng_manager.gd      # All randomness, seedable
│   │   │   ├── persistence.gd      # Save/load operations
│   │   │   └── game_loader.gd      # Loads game definitions from data/
│   │   │
│   │   ├── validation/             # Action validation layer
│   │   │   ├── action_validator.gd # Validates all actions before dispatch
│   │   │   └── schema_validator.gd # Validates JSON schemas on load
│   │   │
│   │   ├── systems/                # Reusable game systems
│   │   │   ├── hex_grid_system.gd  # Hex grid logic (game-agnostic)
│   │   │   ├── resource_system.gd  # Resource management
│   │   │   ├── crew_system.gd      # Crew stats and relationships
│   │   │   ├── event_system.gd     # Event triggering and resolution
│   │   │   ├── time_system.gd      # Day/sol progression
│   │   │   └── component_system.gd # Component quality, wear, repair
│   │   │
│   │   ├── types/                  # Core type definitions
│   │   │   ├── game_types.gd       # Enums, constants, type factories
│   │   │   ├── action_types.gd     # All action type definitions
│   │   │   └── result.gd           # Result<T, E> type for error handling
│   │   │
│   │   └── utils/                  # Utility functions
│   │       ├── hex_math.gd         # Hex coordinate math
│   │       ├── formula_engine.gd   # Evaluates formulas from data
│   │       └── random_utils.gd     # Random helpers
│   │
│   ├── games/                      # Game-specific code (minimal)
│   │   ├── mars_mission/
│   │   │   ├── reducers/           # Phase-specific reducers
│   │   │   │   ├── ship_building_reducer.gd
│   │   │   │   ├── travel_reducer.gd
│   │   │   │   ├── mars_base_reducer.gd
│   │   │   │   └── return_reducer.gd
│   │   │   ├── validators/         # Game-specific validation rules
│   │   │   │   └── mars_validator.gd
│   │   │   └── mars_game.gd        # Game coordinator
│   │   ├── fcw/
│   │   ├── vnp/
│   │   └── colony_sim/
│   │
│   ├── ui/                         # UI layer (thin)
│   │   ├── shared/                 # Shared UI components
│   │   │   ├── hex_grid_view.gd
│   │   │   ├── resource_bar.gd
│   │   │   ├── crew_panel.gd
│   │   │   ├── event_dialog.gd
│   │   │   └── mission_log.gd
│   │   ├── mars_mission/           # Mars-specific UI
│   │   │   ├── ship_building_ui.gd
│   │   │   ├── travel_ui.gd
│   │   │   ├── mars_base_ui.gd
│   │   │   └── return_ui.gd
│   │   ├── fcw/
│   │   ├── vnp/
│   │   └── colony_sim/
│   │
│   └── autoload/                   # Godot autoloads (minimal)
│       └── game_manager.gd         # Entry point, owns Store
│
├── tests/                          # Test suite
│   ├── unit/                       # Pure function tests
│   │   ├── test_hex_math.gd
│   │   ├── test_resource_system.gd
│   │   ├── test_crew_system.gd
│   │   ├── test_event_system.gd
│   │   └── test_reducers.gd
│   ├── integration/                # System integration tests
│   └── fixtures/                   # Test data
│
├── scenes/                         # Godot scenes (structure unchanged)
│
└── docs/                           # Documentation (existing)
```

---

## Core Architecture Components

### 1. Store (scripts/engine/core/store.gd)

Minimal state container. ~100 LOC target.

```gdscript
class_name Store
extends RefCounted

signal state_changed(old_state: Dictionary, new_state: Dictionary)
signal action_dispatched(action: Dictionary)
signal error_occurred(error: Dictionary)

var _state: Dictionary = {}
var _dispatcher: Dispatcher
var _validator: ActionValidator

func get_state() -> Dictionary:
    return _state.duplicate(true)  # Always return copy

func dispatch(action: Dictionary) -> Result:
    # Validate
    var validation = _validator.validate(action, _state)
    if not validation.is_ok():
        error_occurred.emit(validation.get_error())
        return validation

    # Get reducer for this game/phase
    var reducer = _dispatcher.get_reducer(action, _state)

    # Reduce
    var old_state = _state
    _state = reducer.reduce(_state, action)

    # Notify
    action_dispatched.emit(action)
    state_changed.emit(old_state, _state)

    return Result.ok(_state)
```

### 2. Result Type (scripts/engine/types/result.gd)

No more silent failures.

```gdscript
class_name Result
extends RefCounted

var _value
var _error
var _is_ok: bool

static func ok(value) -> Result:
    var r = Result.new()
    r._value = value
    r._is_ok = true
    return r

static func err(error: Dictionary) -> Result:
    var r = Result.new()
    r._error = error
    r._is_ok = false
    return r

func is_ok() -> bool:
    return _is_ok

func get_value():
    return _value

func get_error() -> Dictionary:
    return _error

func unwrap_or(default):
    return _value if _is_ok else default
```

### 3. Action Validator (scripts/engine/validation/action_validator.gd)

Validates every action before dispatch.

```gdscript
class_name ActionValidator
extends RefCounted

var _game_validators: Dictionary = {}  # game_id -> GameValidator

func register_game_validator(game_id: String, validator: GameValidator) -> void:
    _game_validators[game_id] = validator

func validate(action: Dictionary, state: Dictionary) -> Result:
    # Check action has required fields
    if not action.has("type"):
        return Result.err({
            "code": "MISSING_ACTION_TYPE",
            "message": "Action must have a 'type' field",
            "action": action
        })

    # Check game-specific validation
    var game_id = state.get("game_id", "mars_mission")
    if _game_validators.has(game_id):
        return _game_validators[game_id].validate(action, state)

    return Result.ok(action)
```

### 4. RNG Manager (scripts/engine/core/rng_manager.gd)

Centralized, seedable randomness.

```gdscript
class_name RNGManager
extends RefCounted

var _rng: RandomNumberGenerator
var _seed: int
var _call_count: int = 0  # For replay/debugging

func _init(seed: int = -1):
    _rng = RandomNumberGenerator.new()
    if seed == -1:
        _rng.randomize()
        _seed = _rng.seed
    else:
        _seed = seed
        _rng.seed = seed

func get_seed() -> int:
    return _seed

func get_call_count() -> int:
    return _call_count

## Get random float [0, 1)
func randf() -> float:
    _call_count += 1
    return _rng.randf()

## Get random int [0, max)
func randi_range(min_val: int, max_val: int) -> int:
    _call_count += 1
    return _rng.randi_range(min_val, max_val)

## Get N random floats (for actions that need multiple)
func randf_array(count: int) -> Array[float]:
    var result: Array[float] = []
    for i in range(count):
        result.append(randf())
    return result

## Pick random item from array
func pick(array: Array):
    if array.is_empty():
        return null
    return array[randi_range(0, array.size() - 1)]

## Weighted random selection
func pick_weighted(items: Array, weights: Array[float]):
    var total = 0.0
    for w in weights:
        total += w

    var roll = randf() * total
    var cumulative = 0.0

    for i in range(items.size()):
        cumulative += weights[i]
        if roll < cumulative:
            return items[i]

    return items[-1]
```

### 5. Game Loader (scripts/engine/core/game_loader.gd)

Loads game definitions from data/ directory.

```gdscript
class_name GameLoader
extends RefCounted

const DATA_PATH = "res://data/"

var _schema_validator: SchemaValidator
var _loaded_games: Dictionary = {}

func load_game(game_id: String) -> Result:
    var path = DATA_PATH + "games/" + game_id + "/"

    # Load manifest
    var manifest_result = _load_json(path + "manifest.json")
    if not manifest_result.is_ok():
        return manifest_result

    var manifest = manifest_result.get_value()

    # Load all game data
    var game_data = {
        "id": game_id,
        "manifest": manifest,
        "phases": _load_json(path + "phases.json").unwrap_or({}),
        "components": _load_json(path + "components.json").unwrap_or([]),
        "engines": _load_json(path + "engines.json").unwrap_or([]),
        "crew_roster": _load_json(path + "crew_roster.json").unwrap_or([]),
        "events": _load_events(path + "events/"),
        "balance": _load_json(path + "balance.json").unwrap_or({})
    }

    # Validate
    var validation = _schema_validator.validate_game(game_data)
    if not validation.is_ok():
        return validation

    _loaded_games[game_id] = game_data
    return Result.ok(game_data)

func get_game(game_id: String) -> Dictionary:
    return _loaded_games.get(game_id, {})

func _load_json(path: String) -> Result:
    if not FileAccess.file_exists(path):
        return Result.err({"code": "FILE_NOT_FOUND", "path": path})

    var file = FileAccess.open(path, FileAccess.READ)
    var json = JSON.new()
    var error = json.parse(file.get_as_text())

    if error != OK:
        return Result.err({
            "code": "JSON_PARSE_ERROR",
            "path": path,
            "line": json.get_error_line(),
            "message": json.get_error_message()
        })

    return Result.ok(json.data)

func _load_events(path: String) -> Dictionary:
    var events = {}
    var dir = DirAccess.open(path)
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if file_name.ends_with(".json"):
                var phase = file_name.trim_suffix(".json")
                events[phase] = _load_json(path + file_name).unwrap_or([])
            file_name = dir.get_next()
    return events
```

### 6. Formula Engine (scripts/engine/utils/formula_engine.gd)

Evaluates formulas defined in data files.

```gdscript
class_name FormulaEngine
extends RefCounted

## Evaluate a formula string with given variables
## Example: evaluate("base_cost * (1 + quality/100)", {"base_cost": 100, "quality": 75})
static func evaluate(formula: String, variables: Dictionary) -> float:
    var expression = Expression.new()
    var var_names = variables.keys()
    var var_values = variables.values()

    var error = expression.parse(formula, var_names)
    if error != OK:
        push_error("Formula parse error: " + expression.get_error_text())
        return 0.0

    var result = expression.execute(var_values)
    if expression.has_execute_failed():
        push_error("Formula execution error")
        return 0.0

    return result

## Evaluate a formula from a balance config
static func evaluate_from_config(formula_id: String, variables: Dictionary, balance: Dictionary) -> float:
    var formulas = balance.get("formulas", {})
    if not formulas.has(formula_id):
        push_error("Unknown formula: " + formula_id)
        return 0.0

    return evaluate(formulas[formula_id], variables)
```

---

## Data File Formats

### Game Manifest (data/games/mars_mission/manifest.json)

```json
{
  "id": "mars_mission",
  "name": "Mars Mission",
  "description": "Oregon Trail in space. Build a ship, travel to Mars, survive.",
  "version": "1.0.0",

  "phases": ["ship_building", "travel_to_mars", "mars_base", "return_trip"],
  "initial_phase": "ship_building",

  "systems": {
    "hex_grid": true,
    "crew": true,
    "resources": true,
    "events": true,
    "components": true
  },

  "reducer": "res://scripts/games/mars_mission/mars_game.gd"
}
```

### Balance Config (data/games/mars_mission/balance.json)

All magic numbers in one place.

```json
{
  "version": "1.0.0",

  "difficulty": {
    "easy": {
      "starting_budget": 800000000,
      "days_to_window": 90,
      "event_frequency_multiplier": 0.7,
      "failure_rate_multiplier": 0.7,
      "resource_consumption_multiplier": 0.9
    },
    "normal": {
      "starting_budget": 650000000,
      "days_to_window": 75,
      "event_frequency_multiplier": 1.0,
      "failure_rate_multiplier": 1.0,
      "resource_consumption_multiplier": 1.0
    },
    "hard": {
      "starting_budget": 500000000,
      "days_to_window": 60,
      "event_frequency_multiplier": 1.3,
      "failure_rate_multiplier": 1.5,
      "resource_consumption_multiplier": 1.1
    }
  },

  "phase1": {
    "base_component_quality": 55,
    "quality_test_gain_base": 8,
    "quality_test_gain_divisor": 20,
    "test_cost_multiplier": 0.05,
    "defect_chance_per_quality_point": 0.003,
    "holding_risk_degradation_chance": 0.015,
    "holding_risk_degradation_amount": 3
  },

  "phase2": {
    "base_travel_days": 180,
    "daily_food_per_crew": 2.0,
    "daily_water_per_crew": 3.0,
    "daily_oxygen_per_crew": 0.84,
    "water_recycling_efficiency": 0.9,
    "oxygen_recycling_efficiency": 0.85,
    "base_failure_rate": 0.005,
    "base_event_chance": 0.15,
    "morale_decay_per_day": 0.3,
    "health_decay_per_day": 0.5
  },

  "phase3": {
    "min_stay_sols": 90,
    "optimal_stay_sols": 120,
    "max_stay_sols": 180,
    "solar_dust_degradation_per_sol": 0.005,
    "greenhouse_base_yield": 1.0,
    "eva_base_success_rate": 0.95
  },

  "phase4": {
    "degradation_rate_base": 0.001,
    "rationing_health_penalty": {
      "light": 1.0,
      "moderate": 2.0,
      "severe": 4.0,
      "starvation": 8.0
    }
  },

  "formulas": {
    "quality_test_gain": "quality_test_gain_base - (current_quality / quality_test_gain_divisor)",
    "test_cost": "base_cost * test_cost_multiplier * (1 + current_quality / 100)",
    "daily_failure_chance": "base_rate * (100 - quality) / 50 * stress_modifier",
    "travel_time": "base_days * engine_modifier * fuel_factor",
    "skill_check": "base_difficulty + (skill / 100) * 0.5 + modifiers"
  },

  "scoring": {
    "base_score": 1000,
    "crew_survival_bonus": 1500,
    "max_efficiency_bonus": 2000,
    "time_bonus_per_day": 10,
    "critical_failure_penalty": 200,
    "tiers": {
      "gold": 8000,
      "silver": 5000,
      "bronze": 2500,
      "pyrrhic": 1000
    }
  }
}
```

### Event Definition (data/games/mars_mission/events/phase2.json)

```json
{
  "events": [
    {
      "id": "solar_flare_warning",
      "category": "space",
      "title": "Solar Flare Warning",
      "description": "Sensors detect an incoming solar flare. The radiation will reach the ship in approximately 8 hours.",

      "trigger": {
        "type": "random",
        "base_probability": 0.03,
        "day_range": [20, 180],
        "conditions": [
          {"type": "not_active_event", "event_id": "solar_flare_warning"},
          {"type": "has_component", "component_id": "sensors", "required": false}
        ]
      },

      "choices": [
        {
          "id": "shelter",
          "text": "Order all crew to radiation shelter",
          "requirements": [
            {"type": "has_component", "component_id": "radiation_shelter"}
          ],
          "outcomes": [
            {
              "weight": 0.9,
              "description": "The shelter protects the crew effectively.",
              "effects": [
                {"type": "crew_health", "target": "all", "amount": -5},
                {"type": "advance_time", "days": 1}
              ]
            },
            {
              "weight": 0.1,
              "description": "Minor exposure despite shelter.",
              "effects": [
                {"type": "crew_health", "target": "all", "amount": -15},
                {"type": "advance_time", "days": 1}
              ]
            }
          ]
        },
        {
          "id": "rotate_ship",
          "text": "Use the ship's hull as a shield",
          "outcomes": [
            {
              "weight": 0.6,
              "description": "The maneuver works. Most radiation is blocked.",
              "effects": [
                {"type": "crew_health", "target": "all", "amount": -10},
                {"type": "resource", "resource_id": "fuel", "amount": -5}
              ]
            },
            {
              "weight": 0.4,
              "description": "Partial success. Significant exposure.",
              "effects": [
                {"type": "crew_health", "target": "all", "amount": -25},
                {"type": "resource", "resource_id": "fuel", "amount": -5},
                {"type": "trigger_event", "event_id": "radiation_sickness"}
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

---

## Reducer Structure

Each game has phase-specific reducers that are pure functions.

### Example: Travel Reducer (scripts/games/mars_mission/reducers/travel_reducer.gd)

```gdscript
class_name TravelReducer
extends RefCounted

static func reduce(state: Dictionary, action: Dictionary, game_data: Dictionary, rng: RNGManager) -> Dictionary:
    match action.type:
        "ADVANCE_DAY":
            return _reduce_advance_day(state, action, game_data, rng)
        "ASSIGN_CREW_TASK":
            return _reduce_assign_crew_task(state, action, game_data)
        "RESOLVE_EVENT_CHOICE":
            return _reduce_resolve_event_choice(state, action, game_data, rng)
        _:
            return state

static func _reduce_advance_day(state: Dictionary, action: Dictionary, game_data: Dictionary, rng: RNGManager) -> Dictionary:
    var balance = game_data.balance
    var new_state = state.duplicate(true)

    # Advance day
    new_state.travel_day += 1

    # Consume resources
    new_state = ResourceSystem.consume_daily(new_state, balance.phase2, rng)

    # Update crew
    new_state = CrewSystem.apply_daily_update(new_state, balance.phase2, rng)

    # Check for component failures
    new_state = ComponentSystem.check_failures(new_state, balance.phase2, rng)

    # Check for random events
    new_state = EventSystem.check_random_event(new_state, game_data.events.phase2, balance.phase2, rng)

    # Check arrival
    if new_state.travel_day >= new_state.total_travel_days:
        new_state.current_phase = "mars_arrival"

    return new_state
```

---

## Test Structure

### Unit Test Example (tests/unit/test_resource_system.gd)

```gdscript
extends GutTest

var ResourceSystem = preload("res://scripts/engine/systems/resource_system.gd")

func test_consume_daily_reduces_resources():
    var state = {
        "resources": {
            "food": {"current": 100, "max": 200},
            "water": {"current": 100, "max": 200},
            "oxygen": {"current": 100, "max": 200}
        },
        "crew": [
            {"id": "santos", "status": "healthy"},
            {"id": "chen", "status": "healthy"}
        ]
    }

    var balance = {
        "daily_food_per_crew": 2.0,
        "daily_water_per_crew": 3.0,
        "daily_oxygen_per_crew": 0.84
    }

    var rng = RNGManager.new(12345)
    var new_state = ResourceSystem.consume_daily(state, balance, rng)

    assert_eq(new_state.resources.food.current, 96.0)  # 100 - (2 * 2.0)
    assert_eq(new_state.resources.water.current, 94.0)  # 100 - (2 * 3.0)
    assert_almost_eq(new_state.resources.oxygen.current, 98.32, 0.01)  # 100 - (2 * 0.84)

func test_starvation_damages_health():
    var state = {
        "resources": {
            "food": {"current": 0, "max": 200}
        },
        "crew": [
            {"id": "santos", "health": 100}
        ]
    }

    var balance = {"starvation_damage_per_day": 10}
    var rng = RNGManager.new(12345)

    var new_state = ResourceSystem.apply_starvation(state, balance, rng)

    assert_eq(new_state.crew[0].health, 90)
```

---

## Migration Plan

### Phase 1: Foundation (Engine Core)

1. Create `scripts/engine/` directory structure
2. Implement `Result` type
3. Implement `RNGManager`
4. Implement minimal `Store`
5. Implement `ActionValidator` (basic structure)
6. Create test harness with GUT

### Phase 2: Data Infrastructure

1. Create `data/` directory structure
2. Create `GameLoader`
3. Create `SchemaValidator`
4. Migrate balance numbers from code to `balance.json`
5. Migrate component definitions to `components.json`
6. Migrate engine definitions to `engines.json`
7. Migrate crew roster to `crew_roster.json`

### Phase 3: System Extraction

1. Extract `HexGridSystem` from `ShipLogic`
2. Extract `ResourceSystem` from `TravelLogic`
3. Extract `CrewSystem` from `CrewLogic`
4. Extract `ComponentSystem` from `ComponentLogic`
5. Extract `EventSystem` from `InteractiveEvents`
6. Add unit tests for each system

### Phase 4: Reducer Split

1. Create `ShipBuildingReducer` from `GameReducer`
2. Create `TravelReducer` from `GameReducer`
3. Create `MarsBaseReducer` from `GameReducer`
4. Create `ReturnReducer` from `GameReducer`
5. Create `Dispatcher` to route actions to correct reducer
6. Delete old `GameReducer`

### Phase 5: Game Parity

1. Create `data/games/mars_mission/manifest.json`
2. Migrate existing FCW code to new structure
3. Migrate existing VNP code to new structure
4. Migrate existing Colony Sim code to new structure
5. Verify all games load and run

### Phase 6: UI Migration

1. Update UI to use new Store signals
2. Create shared UI components
3. Migrate phase UIs to new game structure
4. Remove old UI code

### Phase 7: Cleanup

1. Delete `scripts/core/` (old logic modules)
2. Delete `scripts/autoload/game_store.gd`
3. Delete `scripts/types/game_types.gd` (merged into engine)
4. Update CLAUDE.md with new architecture
5. Update documentation

---

## LLM Workflow

After refactoring, Claude Code can safely work on the game:

### Adding a New Event

1. Claude reads `data/games/mars_mission/events/phase2.json`
2. Claude adds new event following the schema
3. No code changes required
4. Event automatically available in game

### Tuning Balance

1. Claude reads `data/games/mars_mission/balance.json`
2. Claude adjusts numbers
3. No code changes required
4. Changes take effect immediately

### Adding a New Component

1. Claude reads `data/games/mars_mission/components.json`
2. Claude adds new component following schema
3. If component needs special logic, Claude creates system extension
4. Tests validate the component works

### Creating a New Game

1. Claude creates `data/games/new_game/manifest.json`
2. Claude creates phase definitions, components, events
3. Claude creates minimal reducer in `scripts/games/new_game/`
4. Game is playable

---

## Validation Rules

Every action dispatch goes through validation:

```
Action received
    ↓
Check action has 'type' field
    ↓
Check action type is known
    ↓
Check required parameters present
    ↓
Check parameter types correct
    ↓
Check game state allows action (e.g., right phase)
    ↓
Check resources/requirements met
    ↓
Pass to reducer
```

If any check fails, return `Result.err()` with:
- Error code (machine-readable)
- Error message (human-readable)
- Context (what failed and why)

---

## Error Handling Philosophy

1. **Never silent failures** - Always return Result
2. **Fail fast** - Catch errors at validation, not in reducer
3. **Informative errors** - Include context for debugging
4. **Recoverable when possible** - UI can show error and let user retry
5. **Log everything** - Actions, errors, state changes for debugging

---

## Success Criteria

The refactor is complete when:

1. [ ] All games load from data files
2. [ ] All pure logic has unit tests
3. [ ] No magic numbers in code (all in balance.json)
4. [ ] No silent failures (all actions return Result)
5. [ ] GameStore is <150 LOC
6. [ ] Each reducer is <300 LOC
7. [ ] Claude Code can add events without touching GDScript
8. [ ] Claude Code can tune balance without touching GDScript
9. [ ] All existing functionality works
10. [ ] Documentation updated

---

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Breaking existing saves | Decision: wipe saves (approved) |
| Missing edge cases in migration | Comprehensive test suite |
| Formula engine limitations | Fall back to GDScript for complex logic |
| Performance of JSON loading | Cache loaded data, lazy load where possible |
| LLM generates invalid JSON | Schema validation catches errors immediately |
