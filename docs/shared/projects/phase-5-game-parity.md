# Phase 5: Game Parity

## Status: COMPLETE

## Overview

Phase 5 establishes data-driven infrastructure for all expansion games (First Contact War, Von Neumann Probe, Colony Sim) so they can be managed through the unified game registry system alongside Mars Mission.

## Games Migrated

### 1. Mars Mission (Core)

The original Oregon Trail-style Mars journey.

**Data Files:**
- `data/games/mars_mission/manifest.json`
- `data/games/mars_mission/engines.json`
- `data/games/mars_mission/components.json`
- `data/games/mars_mission/crew_roster.json`
- `data/games/mars_mission/balance.json`
- `data/games/mars_mission/events/phase1-4.json`

**Genre:** Turn-based survival

### 2. First Contact War (FCW)

Real-time strategy defending Earth from alien invasion.

**Data Files:**
- `data/games/first_contact_war/manifest.json`
- `data/games/first_contact_war/ships.json` - 6 ship types
- `data/games/first_contact_war/zones.json` - 16 zones
- `data/games/first_contact_war/balance.json`

**Genre:** Turn-based strategy

**Key Features:**
- Zone-based map (solar system)
- Fleet management
- Civilian evacuation
- Herald invasion waves

### 3. Von Neumann Probe (VNP)

Real-time idle game about self-replicating probes.

**Data Files:**
- `data/games/von_neumann_probe/manifest.json`
- `data/games/von_neumann_probe/balance.json`

**Genre:** Real-time idle/strategy

**Key Features:**
- Procedural galaxy generation
- Continuous time progression
- Resource mining
- Probe replication

### 4. Colony Sim (Placeholder)

Future expansion for Mars colony management.

**Data Files:**
- `data/games/colony_sim/manifest.json` (placeholder)

## Game Registry System

Created `GameRegistry` (`scripts/engine/core/game_registry.gd`) to manage all games.

### Registry API

```gdscript
# Get all available games
var games = GameRegistry.get_available_games()

# Load specific game
var manifest = GameRegistry.get_game_manifest("mars_mission")

# Load all game data
var result = GameRegistry.load_game_data("first_contact_war")
if result.is_ok():
    var data = result.get_value()
    # data contains: manifest, balance, ships, zones, events, etc.
```

### Manifest Structure

Each game has a `manifest.json`:

```json
{
  "id": "game_id",
  "name": "Display Name",
  "description": "Game description",
  "version": "1.0.0",
  "genre": "turn_based_survival",
  "time_mode": "turn_based",

  "settings": {
    "game_specific_settings": "values"
  },

  "files": {
    "balance": "balance.json",
    "events": "events/main.json"
  },

  "reducers": {
    "main": "GameReducerClass"
  },

  "store": "GameStoreClass"
}
```

## File Structure

```
data/games/
├── mars_mission/
│   ├── manifest.json
│   ├── engines.json
│   ├── components.json
│   ├── crew_roster.json
│   ├── balance.json
│   └── events/
│       ├── phase1.json
│       ├── phase2.json
│       ├── phase3.json
│       └── phase4.json
│
├── first_contact_war/
│   ├── manifest.json
│   ├── ships.json
│   ├── zones.json
│   └── balance.json
│
├── von_neumann_probe/
│   ├── manifest.json
│   └── balance.json
│
└── colony_sim/
    └── manifest.json
```

## Game-Specific Balance

Each game has its own `balance.json` with magic numbers:

### Mars Mission Balance
- Resource consumption rates
- Crew stat decay
- Component quality thresholds
- Event trigger chances

### FCW Balance
- Herald strength progression
- Combat multipliers
- Victory tier thresholds
- Evacuation mechanics

### VNP Balance
- Mining rates
- Replication costs
- Travel speeds
- Event frequencies

## Genre Support

The engine supports different game genres:

| Genre | Time Mode | Example |
|-------|-----------|---------|
| `turn_based_survival` | Discrete days | Mars Mission |
| `turn_based_strategy` | 30-day turns | First Contact War |
| `real_time_idle` | Continuous | Von Neumann Probe |
| `colony_management` | Day/Night cycle | Colony Sim |

## Integration Pattern

Games integrate with the engine through:

1. **Manifest** - Declares game identity and files
2. **Balance** - All tunable numbers
3. **Store** - State management (can use shared or custom)
4. **Reducer** - Game logic (can use shared systems)

```
Main Menu
    ↓
GameRegistry.get_available_games()
    ↓
Player selects game
    ↓
GameRegistry.load_game_data(game_id)
    ↓
Initialize Store with game balance
    ↓
Game-specific UI scene
```

## Backward Compatibility

Existing game code (FCWStore, VNPStore, FCWReducer, VNPReducer) continues to work unchanged. The new infrastructure provides:

1. **Data-driven configuration** - Edit JSON instead of code
2. **Shared type system** - GameTypes used across all games
3. **Unified loading** - Single entry point for all game data
4. **LLM-friendly editing** - JSON is safer for AI to modify

## Future Work

- Colony Sim full implementation
- Shared event system for all games
- Cross-game achievements
- Modding support via custom game folders

## Next Phase

Phase 6: UI Migration - Update UI components to use the new Store signals and data-driven configuration.
