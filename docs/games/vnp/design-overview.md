# Von Neumann Probe (VNP) Game Mode

**Core Fantasy:** Immortal AI controlling self-replicating probes exploring the galaxy over millions of years
**Inspiration:** Bobiverse series by Dennis E. Taylor

## Overview

VNP is a completely separate roguelite game mode where you control an AI managing a fleet of self-replicating probes. Starting with a single probe, you must mine resources, replicate new probes, and explore the galaxy. Each run generates a unique procedural galaxy with 25 star systems.

## How to Play

### Starting the Game
1. Launch from Main Menu → "VNP Roguelite"
2. You begin with one probe (Bob-1) in your home system
3. The home system starts explored with some initial resources

### Controls
- **Left Click**: Select systems / Send idle probes to connected systems
- **Right Click / Middle Click + Drag**: Pan camera
- **Mouse Wheel**: Zoom in/out
- **WASD / Arrow Keys**: Pan camera
- **Space**: Advance turn
- **Next Turn Button**: Advance one turn (10 years)
- **Auto Button**: Toggle automatic turn advancement

### Core Actions
Each turn (10 years), probes can perform one action:

1. **Mine** - Extract resources from current system
   - Yields ~10 iron + ~2 rare elements per turn
   - Continues until system is depleted or manually stopped

2. **Replicate** - Build a new probe
   - Costs: 80 iron + 200 energy
   - Takes 3 turns to complete
   - New probe spawns in same system

3. **Travel** - Move to connected system
   - Click a green-highlighted reachable system
   - Travel time varies by distance (1-5 turns)
   - Explores new systems on arrival

4. **Idle** - Wait for orders (stop current mining/replication)

### Resources

| Resource | Description | Sources |
|----------|-------------|---------|
| Iron | Basic construction material | Mining, discoveries |
| Energy | Powers operations, regenerates (+10/turn) | Base regeneration, discoveries |
| Rare Elements | Advanced components | Mining, anomalies |

### Star Types

| Type | Color | Resources | Danger |
|------|-------|-----------|--------|
| Red Dwarf | Red | Low | Low |
| Yellow | Yellow | Medium | Low |
| Orange | Orange | Medium-High | Medium |
| Blue Giant | Blue | High | High |
| White Dwarf | White | Low iron, High rare | Medium |
| Neutron | Purple | Very High rare | Very High |

### Events

Random events occur during gameplay:

- **Hazards** - Radiation surges, micrometeorite storms (can damage probes)
- **Discoveries** - Resource caches, ancient wreckage (bonus resources)
- **Anomalies** - Strange signals in systems with anomaly markers

### Victory Conditions (any one)
- Explore 50% of galaxy (13+ systems)
- Have 20 active probes simultaneously
- (Future: Find "The Origin" - collect 5 clues)

### Defeat Condition
- All probes destroyed

### Scoring
- Systems explored: 100 pts each
- Probes built: 50 pts each
- Peak probe count: 100 pts each
- Iron mined: 1 pt per unit
- Rare mined: 5 pts per unit
- Turns survived: 10 pts each
- Victory bonus: 1.5x multiplier

## Architecture

VNP follows the Redux-style pattern from the main game:

```
scripts/von_neumann_probe/
├── vnp_types.gd      # Data structures (Probe, StarSystem, VNPState)
├── vnp_reducer.gd    # Pure reducer: (state, action) -> new_state
├── vnp_store.gd      # State management autoload, signals, RNG
├── vnp_galaxy_logic.gd  # Galaxy generation, navigation (pure)
├── vnp_main.gd       # Main UI controller
└── vnp_galaxy_view.gd   # Custom drawing for galaxy map

scenes/von_neumann_probe/
└── vnp_main.tscn     # Main game scene
```

## Future Features (Phase 3+)

- Event system expansion with more variety
- Win condition: "The Origin" questline
- Probe upgrades and specialization
- Alien encounters
- Sound effects and music
- Meta-progression (archive unlocks)
- Seed sharing for replayable galaxies
