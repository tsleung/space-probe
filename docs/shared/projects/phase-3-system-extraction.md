# Phase 3: System Extraction

## Status: COMPLETE

## Overview

Phase 3 extracts domain-specific systems from the monolithic game logic into pure, testable modules. Each system handles a single responsibility and operates through static functions with no side effects.

## Systems Created

### 1. HexMath (`scripts/engine/utils/hex_math.gd`)

Hex coordinate mathematics and utilities.

**Key Functions:**
- `hex_to_pixel()` / `pixel_to_hex()` - Coordinate conversion
- `get_neighbors()` - Adjacent hex positions
- `distance()` - Hex distance calculation
- `get_component_hexes()` - Multi-hex component positions
- `hex_key()` / `parse_hex_key()` - String key utilities

### 2. HexGridSystem (`scripts/engine/systems/hex_grid_system.gd`)

Component placement and ship grid management.

**Key Functions:**
- `can_place_component()` - Validation with placement rules
- `place_component()` / `remove_component()` - Grid modifications
- `get_component_at()` / `get_all_components()` - Queries
- `check_launch_readiness()` - Pre-launch validation
- `calculate_ship_quality()` - Weighted quality calculation

### 3. ResourceSystem (`scripts/engine/systems/resource_system.gd`)

Resource consumption, recycling, and scarcity management.

**Key Functions:**
- `consume_daily()` - Daily resource consumption
- `apply_deprivation()` - Starvation/dehydration effects
- `days_remaining()` - Supply duration calculation
- `get_resource_status()` - Warning level assessment
- `calculate_recommended_supplies()` - Supply planning

**Resource Types:**
- Food (no recycling)
- Water (life support recycling)
- Oxygen (life support recycling)
- Fuel (engine-specific consumption)

### 4. CrewSystem (`scripts/engine/systems/crew_system.gd`)

Crew stats, relationships, and condition management.

**Key Functions:**
- `apply_daily_update()` - Daily stat changes
- `calculate_effectiveness()` - Work output calculation
- `calculate_skill_check()` - Success probability
- `update_relationship()` - Relationship changes
- `get_best_for_skill()` - Crew selection

**Crew Stats:**
- Health (0-100)
- Morale (0-100)
- Fatigue (0-100)
- Status (healthy, sick, injured, critical, dead)
- Relationships (per crew member, 0-100)

### 5. ComponentSystem (`scripts/engine/systems/component_system.gd`)

Component quality, degradation, testing, and repair.

**Key Functions:**
- `apply_daily_wear()` - Quality degradation
- `test_component()` - Quality improvement through testing
- `repair_component()` - Quality restoration
- `calculate_failure_chance()` - Failure probability
- `calculate_effectiveness()` - Output based on quality

**Component States:**
- OPERATIONAL (quality > 70)
- DEGRADED (quality 50-70)
- DAMAGED (quality 30-50)
- CRITICAL (quality 10-30)
- DESTROYED (quality <= 10)

### 6. EventSystem (`scripts/engine/systems/event_system.gd`)

Event triggering, selection, resolution, and effect application.

**Key Functions:**
- `check_event_trigger()` - Random event checks
- `select_event()` - Weighted event selection
- `is_choice_available()` - Requirement validation
- `resolve_choice()` - Outcome determination
- `apply_effects()` - State modification

**Effect Types:**
- `crew_health`, `crew_morale`, `crew_fatigue`
- `resource` (amount or percent)
- `component_damage`, `component_repair`
- `relationship` (between crew)
- `time`, `set_flag`, `log`

### 7. TimeSystem (`scripts/engine/systems/time_system.gd`)

Time progression, phase transitions, and deadline tracking.

**Key Functions:**
- `advance_time()` - Daily progression with effects
- `calculate_time_units_to_advance()` - Real-time support
- `days_until_launch_window()` - Launch window tracking
- `calculate_launch_penalty()` - Window miss penalties
- `calculate_travel_progress()` - Journey progress

**Time Units:**
- DAY (Earth day, ship building and travel)
- SOL (Mars day, surface operations)

## Design Principles Applied

### 1. Pure Functions

Every system function is:
- **Deterministic**: Same inputs always produce same outputs
- **Side-effect free**: No external state modification
- **RNG-injectable**: Random values passed as parameters

```gdscript
# All random values come from RNGManager parameter
static func apply_daily_update(
    state: Dictionary,
    balance: Dictionary,
    rng: RNGManager  # Injected randomness
) -> Dictionary:
```

### 2. State Immutability

All functions return new state, never mutate:
```gdscript
var new_state = state.duplicate(true)  # Deep copy
# ... modifications ...
return new_state
```

### 3. Balance-Driven

All magic numbers come from balance Dictionary:
```gdscript
var base_wear = balance.get("base_component_wear_per_day", 0.02)
var morale_decay = balance.get("morale_decay_per_day", 0.5)
```

### 4. Explicit Error Handling

Systems use Result<T,E> for operations that can fail:
```gdscript
static func can_place_component(...) -> Result:
    if occupied:
        return Result.error("POSITION_OCCUPIED", ...)
    return Result.ok({"hexes": hexes})
```

## File Structure

```
scripts/engine/
├── utils/
│   └── hex_math.gd           # Coordinate math
└── systems/
    ├── hex_grid_system.gd    # Ship grid operations
    ├── resource_system.gd    # Resource management
    ├── crew_system.gd        # Crew management
    ├── component_system.gd   # Component quality
    ├── event_system.gd       # Event resolution
    └── time_system.gd        # Time progression
```

## Integration Points

Systems integrate through the Dispatcher/Reducer pattern:

```
Action → Dispatcher → Reducer → Systems → New State
```

Example flow:
```gdscript
# Reducer calls systems
func reduce_advance_day(state, action):
    var new_state = state
    new_state = TimeSystem.advance_time(new_state, balance, rng)
    new_state = ResourceSystem.consume_daily(new_state, balance, rng)
    new_state = CrewSystem.apply_daily_update(new_state, balance, rng)
    new_state = ComponentSystem.apply_daily_wear(new_state, balance, rng)
    return new_state
```

## Testing Strategy

Each system can be tested in isolation:

```gdscript
# Test resource consumption
func test_daily_consumption():
    var state = create_test_state()
    var balance = load_balance()
    var rng = RNGManager.new(12345)  # Fixed seed

    var result = ResourceSystem.consume_daily(state, balance, rng)

    assert(result.resources.food.current < state.resources.food.current)
```

## Dependencies Between Systems

```
TimeSystem
    ├── ResourceSystem.consume_daily()
    ├── CrewSystem.apply_daily_update()
    └── ComponentSystem.apply_daily_wear()

EventSystem
    ├── CrewSystem (conditions, effects)
    ├── ComponentSystem (conditions, effects)
    └── ResourceSystem (conditions, effects)

HexGridSystem
    └── HexMath (coordinate calculations)

ComponentSystem
    └── HexGridSystem (component queries)
```

## Migration Notes

### From Old Code

| Old Location | New System |
|--------------|------------|
| `ShipLogic.hex_*` | `HexMath`, `HexGridSystem` |
| `TravelLogic.calc_daily_consumption` | `ResourceSystem` |
| `CrewLogic.apply_*` | `CrewSystem` |
| `ComponentLogic.*` | `ComponentSystem` |
| `InteractiveEvents.*` | `EventSystem` |
| `TravelLogic.calc_travel_days` | `TimeSystem` |

### Breaking Changes

- All functions now require `balance` dictionary parameter
- All functions now require `RNGManager` for randomness
- State mutations replaced with immutable returns
- Direct enum access replaced with factory functions

## Next Phase

Phase 4: Reducer Split - Split the monolithic GameReducer into phase-specific reducers that call these systems appropriately.
