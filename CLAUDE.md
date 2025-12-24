# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SpaceProbe is a collection of space simulation games built in Godot 4.5 (GDScript). The games include:

| Game | Description | Design Doc |
|------|-------------|------------|
| **MOT** | Mars Odyssey Trek - Oregon Trail meets Apollo 13 | `docs/games/mot/design.md` |
| **FCW** | First Contact War - Desperate last stand strategy | `docs/games/fcw/design.md` |
| **VNP** | Von Neumann Probe - Real-time fleet combat spectacle | `docs/games/vnp/design.md` |
| **MCS** | Mars Colony Sim - Generational colony builder | `docs/games/mcs/design.md` |

## FCW Design Philosophy

FCW is fundamentally different from traditional RTS games. The core thesis:

> **"Movement IS the game. Desperation comes from physics."**

### Core Principles

1. **You Cannot Win** - Earth will fall. Victory is measured by lives evacuated. This isn't a power fantasy - it's managing decline with dignity. Inspired by Halo Reach: noble sacrifice, losing battle fought with honor.

2. **Show, Don't Tell** - The narrative emerges from watching ships move, zones fall, and transmissions scroll. No cutscenes. The story is in the logistics.

3. **Every Number is a Life** - Population counters aren't abstract. The UI should make you feel each million lost or saved.

4. **Physics Creates Desperation** - You can SEE the Herald coming. You can CALCULATE when they arrive. You know where your ships CAN'T be in time. The clock isn't abstract - it's orbital mechanics.

### The Detection Dilemma

The Herald is observation-limited:
- Only sees what's near it (5 AU observation radius, 10 AU for burning ships)
- Follows activity (responds to detected burns)
- Doesn't care about planets - only human signatures
- **Critical**: If you don't fly to/from Earth, Herald doesn't know it's there

This creates the central tragic choice:
- Help outer colonies = Activity draws Herald toward inner system
- Go dark = Abandon everyone, but Herald might not find Earth
- Evacuate = Massive activity, definitely draws Herald

### What FCW is NOT

- NOT a production chain game (removed fake resources - no ore/steel/energy economy)
- NOT about building more ships than the enemy
- NOT turn-based waiting (continuous player agency, discrete simulation ticks)

### What FCW IS

- A game of tradeoffs: ships, people, time
- Every action has a detection cost
- Speed vs stealth for every movement
- Watching doom approach while frantically trying to save what you can

### Victory Tiers

| Tier | Lives Evacuated | Description |
|------|-----------------|-------------|
| LEGENDARY | 80M+ | "Against all odds" |
| HEROIC | 40-80M | "Enough to rebuild" |
| PYRRHIC | 15-40M | "A remnant survives" |
| TRAGIC | 5-15M | "Scattered survivors" |
| ANNIHILATION | <5M | "Humanity's light flickers" |

## Development Philosophy: Documentation First

**We document before we implement. We update after we implement.**

See `docs/DOCUMENTATION.md` for full governance, templates, and workflows.

### The Workflow

1. **Research** (if needed) → `docs/games/{game}/research/`
2. **Create project doc** → `docs/games/{game}/projects/` (BEFORE coding)
3. **Implement** the code
4. **Update design doc** → `docs/games/{game}/design.md` (AFTER coding)
5. **Log decisions** → `docs/games/{game}/notes/decisions.md`
6. **Archive project** → `docs/archive/projects/`

### Mandatory: Documentation Update After Implementation

**After completing any implementation work, spawn a subagent to update documentation.** This prevents documentation from falling behind without blocking the main work thread.

```
After implementation, spin off a Task subagent with:
"Update documentation for [feature]. Check and update:
- docs/games/{game}/design.md (if systems/mechanics changed)
- docs/games/{game}/notes/changelog.md (append entry)
- docs/games/{game}/notes/decisions.md (if significant choices made)
- balance.json comments (if numbers changed)
Do NOT update thematic/philosophy sections unless explicitly requested."
```

### What Changes vs What Stays Stable

| Document Type | Stability | Updates When |
|--------------|-----------|--------------|
| **Core Philosophy** (FCW thesis, game identity) | Stable | Only with explicit creative direction change |
| **Thematic Elements** (victory conditions, emotional goals) | Stable | Rarely, requires deliberate decision |
| **Systems & Mechanics** (how things work) | Living | After implementation changes them |
| **Balance & Numbers** (tuning values) | Living | As we tune and playtest |
| **Decisions Log** | Immutable | Append-only, never edit past entries |
| **Changelog** | Immutable | Append-only, never edit past entries |

**Rule of thumb:** If you're changing how something *works*, update the systems docs. If you're changing what the game *is about*, that requires explicit discussion first.

### Documentation Structure

```
docs/
├── games/{mot,fcw,vnp,mcs}/  # Per-game documentation
│   ├── design.md             # Source of truth (Living)
│   ├── research/             # Exploration (Evergreen)
│   ├── projects/             # Active work (Transient)
│   └── notes/                # Decisions, changelog (Immutable)
├── shared/                   # Cross-game docs
│   ├── architecture/         # System architecture
│   ├── projects/             # Engine work
│   └── research/             # Multi-game research
├── principles/               # How we work (Evergreen)
├── reference/                # Lookup tables
└── archive/                  # Historical artifacts
```

### Key Documentation

| Doc | Purpose |
|-----|---------|
| `docs/DOCUMENTATION.md` | Documentation governance & templates |
| `docs/DOMAIN_COUNCILS.md` | AI review councils for quality gates |
| `docs/game-design.md` | Cross-game philosophy |
| `docs/games/{game}/design.md` | Per-game source of truth (Living) |
| `docs/games/{game}/notes/decisions.md` | Decision log (Immutable, append-only) |
| `docs/games/{game}/notes/changelog.md` | Change history (Immutable, append-only) |
| `docs/principles/godot-performance.md` | Performance best practices |
| `docs/principles/llm-development.md` | LLM collaboration guidelines |

### Domain Councils

For significant changes, invoke parallel AI review councils:

| Council | Mandate | Key Question |
|---------|---------|--------------|
| **Game Design** | Is this fun and coherent? | "Does this serve the player experience?" |
| **Architecture** | Is this technically sound? | "Does this follow our patterns?" |
| **Balance** | Do the numbers work? | "Is this mathematically fair?" |
| **Quality** | Is this reliable? | "How do we test this?" |
| **Performance** | Will this run well? | "What's the frame budget cost?" |

See `docs/DOMAIN_COUNCILS.md` for full council definitions and review process.

## Running the Project

```bash
# Open in Godot Editor
godot project.godot

# Run main menu
godot --path . scenes/ui/main_menu.tscn

# Run specific games directly
godot --path . scenes/von_neumann_probe/vnp_main.tscn     # VNP
godot --path . scenes/first_contact_war/fcw_main.tscn    # FCW
godot --path . scenes/mars_odyssey_trek/phase1_main.tscn # MOT Phase 1
godot --path . scenes/mars_odyssey_trek/phase2_integrated.tscn # MOT Phase 2
```

## Testing

Uses [GUT](https://github.com/bitwes/Gut) (Godot Unit Test) framework. Tests are in `tests/unit/`.

```bash
# Run all tests from command line
godot --headless -s addons/gut/gut_cmdln.gd

# Run specific test file
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_vnp_systems.gd

# Run tests matching pattern
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_vnp*.gd

# Run tests in Godot Editor: use the GUT panel (bottom dock)
```

Test files follow `test_*.gd` naming convention and extend `GutTest`.

## Safe Zones for Editing

### Green Zone: Edit Freely
Data files - game content, not engine logic:
- `data/games/*/balance.json` - Tune numbers
- `data/games/*/events/*.json` - Add/modify events
- `data/games/*/crew_roster.json`, `ships.json`, etc.

### Yellow Zone: Edit with Care
Game-specific logic - run tests after changes:
- `scripts/mars_odyssey_trek/`, `scripts/von_neumann_probe/`, etc.
- Game-specific stores, reducers, UI

### Red Zone: Edit Rarely
Engine infrastructure - affects all games:
- `scripts/engine/` - Core store, systems, types

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

#### 4. Reproducible Simulation (Principle 0)

**We understand our games through deterministic math.** All randomness is seeded so we can:
- Reproduce any bug by replaying with the same seed
- Run Monte Carlo simulations to balance the game
- Tune event probabilities to pace the narrative
- Scale visual effects proportional to mechanical impact

```gdscript
# RNG injected, never created inline
var rng = RNGManager.new(seed)
var new_state = reducer.reduce(state, action, balance, rng)

# Systems are simulatable in isolation
func test_balance():
    for seed in range(10000):
        var rng = RNGManager.new(seed)
        var result = System.simulate(state, rng)
        results.append(result)
```

See `docs/principles/engineering-principles.md` for the full Reproducible Simulation principle.

### Godot Performance (Summary)

See `docs/principles/godot-performance.md` for full details. Key rules:

1. **Nodes own their data** - Positions/velocities live on Node2D, not in state dictionaries
2. **Cache everything** - `@onready` for node refs, cache targets with cooldown timers
3. **Avoid O(N²)** - Use Area2D signals instead of iterating all entities
4. **Pool high-frequency objects** - Projectiles yes, ships no
5. **Profile first** - Use Godot's built-in profiler before optimizing

**Use state management for:** Team resources, game phase, player choices, save/load data

**Don't put in state:** Entity positions, velocities, transient combat data (targets, cooldowns)

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
