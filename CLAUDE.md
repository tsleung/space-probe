# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SpaceProbe is a collection of space simulation games built in Godot 4.5 (GDScript). The games include:

- **MOT (Mars Odyssey Trek)** - The core game, a Mars mission simulator inspired by Oregon Trail
- **FCW (First Contact War)** - Strategy expansion
- **VNP (Von Neumann Probe)** - Real-time idle expansion
- **MCS (Mars Colony Sim)** - Colony building expansion

## Design Documentation

See `docs/` for detailed specs:
- `docs/game-design.md` - Core design philosophy
- `docs/phase-1-ship-building.md` through `docs/phase-4-return-trip.md` - Phase mechanics
- `docs/architecture/overview.md` - System architecture
- `docs/architecture/refactor-plan.md` - Architecture migration plan
- `docs/principles/engineering-principles.md` - Coding principles
- `docs/principles/llm-development.md` - LLM collaboration guidelines
- `docs/projects/` - Phase completion documentation
- `docs/projects/vnp-game-design.md` - VNP game mechanics and design

## Documentation Practices

**Keep docs updated as mechanics evolve.** When making changes:

1. **If mechanics are settled**: Update the relevant game design doc with the new mechanics
2. **If mechanics are in flux**: Add a note in the doc marking the area as "under active development" with discussion/direction notes
3. **Design discussions**: Document the reasoning and tradeoffs being considered, even if the final decision hasn't been made

Example note for evolving mechanics:
```markdown
## Base Weapon System (Under Development)

**Current Direction**: Charge-based system where accumulated charges affect both power and range.
- x1 charge = close range, desperation fire
- x5 charges = long range, can clear center of map

**Open Questions**: Charge accumulation rate, visual spectacle scaling
```

This ensures context is preserved across sessions and collaborators can understand the design intent.

## Running the Project

```bash
# Open in Godot Editor
godot project.godot

# Run from command line
godot --path . scenes/ui/main_menu.tscn
```

## Architecture Overview

### Engine Layer (`scripts/engine/`)

The new modular engine provides reusable infrastructure:

```
scripts/engine/
├── core/           # Core infrastructure
│   ├── store.gd         # State container with signals
│   ├── dispatcher.gd    # Action routing
│   ├── rng_manager.gd   # Seedable randomness
│   ├── persistence.gd   # Save/load
│   ├── game_loader.gd   # Load game definitions
│   └── game_registry.gd # Game discovery
├── types/          # Type definitions
│   ├── result.gd        # Result<T,E> for error handling
│   ├── action_types.gd  # Action constants
│   └── game_types.gd    # Enums and factories
├── validation/     # Validation layers
│   ├── action_validator.gd
│   └── schema_validator.gd
├── systems/        # Pure domain logic
│   ├── hex_grid_system.gd
│   ├── resource_system.gd
│   ├── crew_system.gd
│   ├── component_system.gd
│   ├── event_system.gd
│   └── time_system.gd
├── reducers/       # State reducers
│   ├── game_reducer.gd        # Main router
│   ├── ship_building_reducer.gd
│   ├── travel_reducer.gd
│   └── mars_reducer.gd
├── utils/          # Utilities
│   └── hex_math.gd
└── ui/             # UI helpers
    └── store_binding.gd
```

### Data Layer (`data/`)

All game content is data-driven:

```
data/
├── games/
│   ├── mars_odyssey_trek/    # MOT - Core game
│   │   ├── manifest.json
│   │   ├── balance.json
│   │   ├── engines.json
│   │   ├── components.json
│   │   ├── crew_roster.json
│   │   └── events/
│   ├── first_contact_war/    # FCW expansion
│   │   ├── manifest.json
│   │   ├── balance.json
│   │   ├── ships.json
│   │   └── zones.json
│   ├── von_neumann_probe/    # VNP expansion
│   │   ├── manifest.json
│   │   └── balance.json
│   └── mars_colony_sim/      # MCS expansion
│       ├── manifest.json
│       └── balance.json
├── shared/
│   ├── traits.json
│   └── conditions.json
└── difficulty.json
```

### Key Design Patterns

#### 1. Pure Functions

All game logic is in static, pure functions:
```gdscript
# Systems return new state, never mutate
static func consume_daily(state: Dictionary, balance: Dictionary, rng: RNGManager) -> Dictionary:
    var new_state = state.duplicate(true)
    # ... modifications ...
    return new_state
```

#### 2. Result Type

Explicit error handling:
```gdscript
var result = HexGridSystem.can_place_component(ship, component, position)
if not result.is_ok():
    var error = result.get_error()
    push_warning("Placement failed: %s" % error.message)
    return
```

#### 3. Data-Driven Configuration

All magic numbers in balance.json:
```gdscript
# DON'T: Magic numbers in code
var daily_food = 2.0 * crew_count

# DO: Read from balance
var daily_food = balance.get("daily_food_per_crew", 2.0) * crew_count
```

#### 4. Deterministic Randomness

RNG injected, never created inline:
```gdscript
# In Store (side effects allowed)
var rng = RNGManager.new(seed)
var new_state = reducer.reduce(state, action, balance, rng)

# In Reducer/System (pure)
static func apply_daily_update(state, balance, rng: RNGManager) -> Dictionary:
    var roll = rng.randf()  # Deterministic with seed
```

### Game-Specific Code

Each game has its own Store/Reducer in a dedicated directory:

- **MOT (Mars Odyssey Trek)**: `scripts/mars_odyssey_trek/` - Uses shared engine systems
- **FCW (First Contact War)**: `scripts/first_contact_war/fcw_store.gd`, `fcw_reducer.gd`
- **VNP (Von Neumann Probe)**: `scripts/von_neumann_probe/vnp_store.gd`, `vnp_reducer.gd`
- **MCS (Mars Colony Sim)**: `scripts/mars_colony_sim/mcs_store.gd`, `mcs_reducer.gd`

### UI Binding

UI components use StoreBinding for reactive updates:
```gdscript
func _ready():
    var binding = StoreBinding.new(self, GameStore)
    binding.bind_property("resources.food.current", _on_food_changed)
    binding.bind_property("crew", _on_crew_changed)
```

## Working with the Codebase

### Adding New Features

1. **Add data to JSON** (balance, events, etc.)
2. **Create/update system** if new domain logic needed
3. **Add action type** in `action_types.gd`
4. **Implement in reducer** (phase-specific or shared)
5. **Connect UI** via StoreBinding

### Modifying Balance

Edit JSON files directly:
```bash
# Adjust resource consumption
vim data/games/mars_odyssey_trek/balance.json

# Add new event
vim data/games/mars_odyssey_trek/events/phase2.json
```

### Testing

Systems are testable in isolation:
```gdscript
func test_resource_consumption():
    var state = create_test_state()
    var balance = load_test_balance()
    var rng = RNGManager.new(12345)  # Fixed seed

    var result = ResourceSystem.consume_daily(state, balance, rng)

    assert(result.resources.food.current < state.resources.food.current)
```

## File Naming Conventions

- `*.gd` - GDScript files
- `*.gd.uid` - Godot 4.x UID files (auto-generated, keep in git)
- `*.json` - Data files
- `*.tscn` - Scene files
- `*.tres` - Resource files

## Quick Reference

### Game Phases (MOT - Mars Odyssey Trek)
1. `ship_building` - Construct ship, hire crew
2. `travel_to_mars` - 180+ day journey
3. `mars_arrival` - Landing sequence
4. `mars_base` - Surface operations
5. `travel_to_earth` - Return journey
6. `earth_arrival` - Reentry
7. `game_over` - Results

### Common Systems
- `HexGridSystem` - Ship component placement
- `ResourceSystem` - Consumption, rationing
- `CrewSystem` - Stats, relationships
- `ComponentSystem` - Quality, repair
- `EventSystem` - Triggers, choices
- `TimeSystem` - Day/sol progression

### Common Actions
- `ActionTypes.ADVANCE_DAY`
- `ActionTypes.PLACE_COMPONENT`
- `ActionTypes.HIRE_CREW`
- `ActionTypes.RESOLVE_EVENT`
- `ActionTypes.SET_RATIONING`
