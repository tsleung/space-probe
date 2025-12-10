# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SpaceProbe is a Mars mission simulator game built in Godot 4.5 (GDScript), inspired by Oregon Trail. Players build spacecraft, manage crew, and travel to Mars while dealing with random events and resource management.

## Design Documentation

See `docs/` for detailed game design specs:
- `game-design.md` - Core design philosophy, win/lose conditions, overarching systems
- `phase-1-ship-building.md` through `phase-4-return-trip.md` - Phase-specific mechanics
- `phase-transitions.md` - Transition sequences and data flow between phases

## Running the Project

```bash
# Open in Godot Editor
godot project.godot

# Run from command line
godot --path . scenes/ui/main_menu.tscn
```

## Architecture

### Redux-style State Management

The codebase follows a Redux-like pattern with strict separation between pure logic and side effects:

1. **GameStore** (`scripts/autoload/game_store.gd`) - The only singleton/autoload. Holds mutable state, emits signals for UI reactivity, handles RNG and persistence. All state changes go through `dispatch()`.

2. **GameReducer** (`scripts/core/game_reducer.gd`) - Pure reducer: `(state, action) -> new_state`. Contains action creators and reducer implementations. All functions are static and deterministic.

3. **GameTypes** (`scripts/types/game_types.gd`) - Data type definitions using Dictionary factories (e.g., `create_component()`, `create_crew_member()`). Provides immutable-style updates via `with_field()` and `with_fields()`.

### Pure Logic Modules (scripts/core/)

All core logic is in static, pure functions with no side effects:

- **ComponentLogic** - Component construction, testing, quality calculations
- **ShipLogic** - Hex grid operations, ship mass/readiness calculations, launch checks
- **CrewLogic** - Crew stats, daily updates, team calculations
- **EngineLogic** - Engine definitions, delta-v calculations, travel time estimates
- **EventLogic** - Random event generation (deterministic with provided random values)
- **TravelLogic** - Travel time calculations, daily events during journey, crew activities

### UI Layer (scripts/ui/, scripts/phases/, scripts/components/)

UI scripts are thin layers that:
- Read state from GameStore via getters
- Dispatch actions through GameStore
- React to GameStore signals for updates
- Maintain only local UI state (selections, hover states)

### Key Pattern: Deterministic Randomness

Random values are generated in GameStore and passed into pure functions:
```gdscript
# GameStore (side effects)
dispatch_with_random(action)  # Injects random_values into action

# EventLogic (pure)
static func generate_travel_event(state, event_roll, type_roll, severity_roll) -> Dictionary
```

## Game Flow

1. **MAIN_MENU** → New Game starts at SHIP_BUILDING
2. **SHIP_BUILDING** → Place components on hex grid, select engine, recruit crew
3. **TRAVEL_TO_MARS** → Daily events, crew management, resource consumption
4. **MARS_BASE** → Surface operations (not yet implemented)
5. **TRAVEL_TO_EARTH** → Return journey (not yet implemented)

## Hex Grid System

- Uses axial coordinates (q, r) for hexes
- `ShipLogic.hex_to_pixel()` / `pixel_to_hex()` for conversions
- Multi-hex components spread from origin using `get_component_hexes()`
- Grid stored as `Dictionary<Vector2i, ComponentData>`

## Data Flow Example

```
User clicks "Place Component"
  → UI calls GameStore.place_component(component, position)
    → GameStore.dispatch(GameReducer.action_place_component(...))
      → GameReducer.reduce() returns new state
    → GameStore emits state_changed signal
  → UI receives signal, calls _sync_ui_to_state()
```
