# Phase 4: Reducer Split

## Status: COMPLETE

## Overview

Phase 4 splits the monolithic GameReducer (~1100 LOC) into focused, phase-specific reducers. Each reducer handles only the actions relevant to its game phase, making the code more maintainable and easier to reason about.

## Reducers Created

### 1. GameReducerV2 (`scripts/engine/reducers/game_reducer.gd`)

The main entry point that routes actions to phase-specific reducers.

**Responsibilities:**
- Global action handling (new game, load, save)
- Phase routing to specific reducers
- Earth arrival/reentry sequence
- Ending tier calculation
- Game over state

**Key Functions:**
- `reduce()` - Main entry point, routes by phase
- `_reduce_new_game()` - Initialize new game state
- `_reduce_begin_reentry()` - Handle atmospheric reentry
- `_calculate_ending_tier()` - Determine Gold/Silver/Bronze/Pyrrhic/Failure

### 2. ShipBuildingReducer (`scripts/engine/reducers/ship_building_reducer.gd`)

Handles the ship construction phase.

**Actions:**
- `PLACE_COMPONENT` - Add component to hex grid
- `REMOVE_COMPONENT` - Remove and refund component
- `TEST_COMPONENT` - Run quality tests
- `SELECT_ENGINE` - Choose propulsion system
- `HIRE_CREW` - Add crew member
- `DISMISS_CREW` - Remove crew member
- `LOAD_CARGO` - Load supplies
- `ADVANCE_DAY` - Construction progress
- `LAUNCH` - Begin travel phase

**Key Functions:**
- `_create_component_instance()` - Instantiate from definition
- `_create_crew_instance()` - Instantiate from roster
- `_advance_single_day()` - Construction progress

### 3. TravelReducer (`scripts/engine/reducers/travel_reducer.gd`)

Handles both outbound (to Mars) and return (to Earth) journeys.

**Actions:**
- `ADVANCE_DAY` - Daily progression
- `ASSIGN_TASK` - Crew activity assignment
- `REPAIR_COMPONENT` - Fix damaged systems
- `TREAT_CREW` - Medical treatment
- `SET_RATIONING` - Resource management
- `RESOLVE_EVENT` - Handle player choices

**Key Functions:**
- `_check_crew_deaths()` - Mortality handling
- `_handle_arrival()` - Destination reached
- `_check_arrival_status()` - Validate arrival conditions
- `_add_degradation_warnings()` - Build tension

### 4. MarsReducer (`scripts/engine/reducers/mars_reducer.gd`)

Handles Mars surface operations.

**Actions:**
- `ADVANCE_DAY` - Sol progression (Mars time)
- `CONDUCT_EXPERIMENT` - Science operations
- `COLLECT_SAMPLE` - Geological sampling
- `EVA` - Extra-vehicular activities
- `REPAIR_COMPONENT` - Equipment maintenance
- `PREPARE_DEPARTURE` - Pre-flight checklist
- `DEPART_MARS` - Begin return journey

**Key Functions:**
- `_apply_mars_environment()` - Dust, radiation effects
- `_reduce_conduct_experiment()` - Science skill checks
- `_reduce_prepare_departure()` - Validate departure readiness

## Action Flow

```
User Action → Store.dispatch() → GameReducerV2.reduce()
    ↓
Phase Routing:
    ship_building    → ShipBuildingReducer.reduce()
    travel_to_mars   → TravelReducer.reduce()
    travel_to_earth  → TravelReducer.reduce()
    mars_base        → MarsReducer.reduce()
    earth_arrival    → GameReducerV2._reduce_earth_arrival()
    ↓
Phase Reducer calls Systems:
    - ResourceSystem
    - CrewSystem
    - ComponentSystem
    - EventSystem
    - TimeSystem
    ↓
Returns new state
```

## File Structure

```
scripts/engine/reducers/
├── game_reducer.gd           # Main router (GameReducerV2)
├── ship_building_reducer.gd  # Ship construction phase
├── travel_reducer.gd         # Journey phases
└── mars_reducer.gd           # Mars surface phase
```

## Design Principles Applied

### 1. Single Responsibility

Each reducer handles exactly one phase:
- Ship Building: Construction, crew hiring, launch
- Travel: Journey management, survival
- Mars: Surface operations, science

### 2. Consistent Interface

All reducers follow the same signature:
```gdscript
static func reduce(
    state: Dictionary,
    action: Dictionary,
    balance: Dictionary,
    rng: RNGManager
) -> Dictionary
```

### 3. System Delegation

Reducers call systems for domain logic:
```gdscript
# Reducer delegates to system
new_state = ResourceSystem.consume_daily(new_state, balance, rng)
new_state = CrewSystem.apply_daily_update(new_state, balance, rng)
new_state = ComponentSystem.apply_daily_wear(new_state, balance, rng)
```

### 4. Pure Functions

All reducer functions are:
- Deterministic (same inputs = same outputs)
- Side-effect free (no external state)
- RNG-injectable (randomness passed in)

## Phase Transitions

```
SHIP_BUILDING
    ↓ (LAUNCH action)
TRAVEL_TO_MARS
    ↓ (automatic on arrival)
MARS_ARRIVAL
    ↓ (landing sequence)
MARS_BASE
    ↓ (DEPART_MARS action)
TRAVEL_TO_EARTH
    ↓ (automatic on arrival)
EARTH_ARRIVAL
    ↓ (BEGIN_REENTRY action)
GAME_OVER
```

## Ending Tiers

The game calculates ending tier based on:
- Surviving crew count
- Science points earned
- Experiments completed
- Samples collected
- Ship quality on return
- Mission duration

Tiers:
- **Gold**: Score >= 1000
- **Silver**: Score >= 700
- **Bronze**: Score >= 400
- **Pyrrhic**: Score >= 200
- **Failure**: Score < 200

## Migration from Old Code

| Old Function | New Location |
|-------------|--------------|
| `_reduce_place_component` | `ShipBuildingReducer` |
| `_reduce_advance_travel_day` | `TravelReducer._reduce_advance_day` |
| `_reduce_conduct_experiment` | `MarsReducer._reduce_conduct_experiment` |
| `_reduce_start_new_game` | `GameReducerV2._reduce_new_game` |

## Testing Strategy

Each reducer can be tested independently:

```gdscript
func test_ship_building_place_component():
    var state = create_test_state()
    var action = {type = ActionTypes.PLACE_COMPONENT, ...}
    var balance = load_balance()
    var rng = RNGManager.new(12345)

    var result = ShipBuildingReducer.reduce(state, action, balance, rng)

    assert(result.ship.components.size() > 0)
```

## Benefits

1. **Smaller Files**: Each reducer is ~300-400 LOC instead of 1100
2. **Focused Logic**: Easy to understand phase-specific behavior
3. **Easier Testing**: Test phases in isolation
4. **Clear Dependencies**: Each reducer's needs are explicit
5. **Better Maintainability**: Changes isolated to relevant phase

## Next Phase

Phase 5: Game Parity - Migrate FCW, VNP, and Colony Sim expansion games to use the new architecture.
