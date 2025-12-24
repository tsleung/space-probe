# VNP Architecture & Design Decisions

This document captures the architectural decisions and technical rationale for Von Neumann Probe (VNP). For game mechanics and balance details, see [vnp-game-design.md](./vnp-game-design.md).

---

## Core Architecture

### Decision: Redux-Style State Management

**Choice**: Centralized Store/Reducer pattern

**Rationale**:
- Predictable state transitions - easier to reason about game state
- Time-travel debugging potential - can replay/reverse game state
- Testability - reducers are pure functions
- Separation of concerns - UI observes state, doesn't manage it

**Implementation**:
```
VnpStore (state container) → dispatch(action) → VnpReducer (pure) → new state → UI reacts
```

**Files**:
- `vnp_store.gd` - State container with subscription system
- `vnp_reducer.gd` - Pure state transformation functions

### Decision: Pure Functions for Game Logic

**Choice**: Extract testable logic to `vnp_systems.gd` as static pure functions

**Rationale**:
- Unit testable without game scene
- No side effects - given same inputs, always same outputs
- Reusable across different contexts
- Self-documenting through function signatures

**Functions Extracted**:

| Category | Functions | Purpose |
|----------|-----------|---------|
| Movement | `apply_thrust`, `apply_drag`, `clamp_velocity`, `calculate_movement` | Physics calculations |
| Targeting | `score_target`, `find_best_target`, `find_better_target` | Enemy selection |
| Clustering | `calculate_centroid`, `calculate_cluster_score`, `find_enemy_cluster` | Group analysis |
| Fleet | `calculate_fleet_center` | Formation positioning |
| Base Weapon | `get_weapon_range`, `get_weapon_damage`, `evaluate_base_weapon_fire` | AI firing decisions |
| Geometry | `point_to_line_distance`, `is_in_beam_path`, `apply_damage_falloff` | Collision & damage |
| Bonuses | `get_team_health_bonus`, `get_team_damage_bonus` | Strategic point effects |

### Decision: Dependency Injection Over Globals

**Choice**: Pass references via `init()` functions instead of scene tree lookups

**Rationale**:
- Explicit dependencies - clear what each component needs
- Testable in isolation - can inject mock dependencies
- Resilient to scene restructuring - no hard-coded node paths

**Example**:
```gdscript
# Before (fragile):
func _get_main():
    return get_tree().root.get_node("VnpMain")

# After (robust):
var vnp_main = null

func init(data: Dictionary):
    vnp_main = data.get("vnp_main", null)
```

---

## Physics Model

### Decision: Asteroids-Style Momentum

**Choice**: Ships have momentum and inertia rather than instant direction changes

**Rationale**:
- Engaging combat feel - ships drift and strafe
- Skill expression - predicting enemy movement matters
- Visual interest - battles look dynamic, not static
- Tactical depth - positioning and timing matter

**Parameters**:
- Each ship type has: `speed` (max), `acceleration`, `turn_rate`
- Drag applied each frame to simulate space resistance
- Braking allowed for tactical maneuvers

---

## AI Architecture

### Decision: Centralized AI Controller

**Choice**: Single `vnp_ai_controller.gd` manages fleet-level decisions

**Rationale**:
- Fleet-level tactics possible (formation, focus fire)
- Counter-picking based on global enemy composition
- Consistent behavior per team
- Single point of tuning for AI behavior

**Responsibilities**:
- Build decisions (what ship type to produce)
- Fleet stance/formation settings
- Rally point interpretation
- Counter-pick algorithm

### Decision: Timer-Based Build Loop

**Choice**: Each team has a Timer (0.3s + jitter) for build decisions

**Rationale**:
- Prevents frame-by-frame spam
- Jitter prevents teams syncing up
- Easy to tune pacing via single constant
- Natural feeling production rhythm

---

## Testing Strategy

### Decision: GUT Framework

**Choice**: Godot Unit Test (GUT) for testing

**Rationale**:
- Canonical Godot testing framework
- CLI support for CI/CD integration
- Rich assertion library
- Active maintenance

**Configuration**: `.gutconfig.json` in project root

**Running Tests**:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless -s addons/gut/gut_cmdln.gd
```

### Test Coverage

**Currently Tested** (40 tests):
- All `VnpSystems` pure functions
- Movement physics
- Target scoring and selection
- Clustering algorithms
- Damage calculations

**To Be Added**:
- Store dispatch/subscribe
- Reducer state transitions
- Integration tests for combat outcomes

---

## Visual Effects Design

### Decision: Line2D Over Trail2D

**Choice**: Use native Line2D for projectile trails instead of addon

**Rationale**:
- No addon dependency
- Full control over appearance
- Better performance
- Consistent with rest of codebase

### Decision: Procedural Audio

**Choice**: Generate all sounds at runtime via `AudioStreamWAV`

**Rationale**:
- Zero audio file dependencies
- Consistent tone-based aesthetic
- Easy to tune programmatically
- Memory efficient (sounds cached once)

**Implementation**: `vnp_sound_manager.gd` generates waveforms at startup

---

## Data-Driven Configuration

### Decision: Balance Values in JSON

**Choice**: Ship stats, costs, and game parameters in `data/games/von_neumann_probe/balance.json`

**Rationale**:
- Non-code changes for balancing
- Easy A/B testing
- Clear separation of data and logic
- Moddable without code access

### Decision: Constants in vnp_types.gd

**Choice**: Game constants that rarely change live in `vnp_types.gd`

**What Goes Where**:
- `balance.json`: Values that need tuning (costs, damage, health)
- `vnp_types.gd`: Structural constants (enums, weapon types, color palettes)

---

## File Organization

### Directory Structure

```
scripts/von_neumann_probe/
├── vnp_types.gd          # Enums, constants, ship stats
├── vnp_store.gd          # State container (Redux store)
├── vnp_reducer.gd        # State transformation (pure)
├── vnp_systems.gd        # Pure functions (tested)
├── vnp_main.gd           # Game orchestrator
├── vnp_ai_controller.gd  # Fleet AI management
├── vnp_ui.gd             # HUD and controls
├── ship.gd               # Individual ship behavior
├── projectile.gd         # Flying weapons
├── base_weapon.gd        # Faction-specific base attacks
├── vnp_sound_manager.gd  # Procedural audio
├── vnp_galaxy_logic.gd   # Galaxy generation (unused)
└── vnp_galaxy_view.gd    # Galaxy view (unused)

scenes/von_neumann_probe/
├── vnp_main.tscn
├── ship.tscn
├── projectile.tscn
├── death_explosion_fx.tscn
├── impact_fx.tscn
├── vnp_store.tscn
└── vnp_ui.tscn

tests/unit/
└── test_vnp_systems.gd   # 40 pure function tests
```

---

## Trade-offs and Alternatives Considered

### Considered: ECS Architecture
**Rejected Because**: GDScript doesn't have great ECS support, Redux pattern achieves similar benefits with better Godot integration.

### Considered: Behavior Trees for AI
**Rejected Because**: Overkill for fleet-level decisions, simple decision trees in AI controller suffice.

### Considered: Scene-Attached Audio Files
**Rejected Because**: Procedural audio provides cleaner aesthetic and eliminates asset management.

### Considered: Tween-Based Projectile Movement
**Rejected Because**: Physics-based movement allows for more interesting effects (deflection, momentum).

---

## Open Questions

These areas may need revisiting:

1. **VNPStore Autoload**: Currently uses separate autoload pattern vs shared GameStore
2. **Galaxy View**: Code exists but unused - keep or remove?
3. **Harvester Ship Type**: Defined but not spawned - intended future feature?

---

## Tactical Behavior Changes (December 2024)

### Decision: Destroyer Kiting at Max Range

**Choice**: Destroyers strafe sideways at 95% of their weapon range when they outrange targets

**Rationale**:
- Destroyers (400 range) outrange Frigates (200 range) by 200 units
- Previous behavior: orbit at 85% range (340 units) - too close
- New behavior: strafe at max range, backing away if enemies close in
- Creates distinct tactical identity: "sniper" role vs Frigate's "brawler"

**Implementation**: `_strafe_at_max_range()` function in `ship.gd`

### Decision: Cruiser Continuous Orbital Movement

**Choice**: Cruisers always orbit at 85% range, never brake to a stop

**Rationale**:
- Previous behavior: brake to `Vector2.ZERO` when in range - made Cruisers sitting ducks
- Moving targets are harder to hit - continuous motion is survivability
- 85% range (425 of 500) provides buffer for range fluctuation
- Heavy, deliberate orbit speed (0.35-0.45) maintains Cruiser's weighty feel

**Implementation**: Removed braking branch, always call `_orbit_target()` with slow speed

### Decision: Balance Values Sync

**Updated Values** (synced design.md to vnp_types.gd):
- Frigate damage: 18 → 14 (balances DPS/cost)
- Cruiser cost: 100e+25m → 75e+20m (more accessible)
- Shielder cost: 90e+10m → 75e+5m (viable support)
- Graviton cost: 120e+40m → 100e+30m (reasonable capital)

---

## Expansion & Factory System (December 2024)

### Decision: Cruiser Missile Range Doubled

**Choice**: Cruiser range increased from 500 → 1000

**Rationale**:
- Cruisers are "true artillery" - should outrange everything significantly
- Creates distinct tactical role vs Destroyers (400 range)
- Missiles traveling further looks more dramatic
- Gives reason to build Cruisers for long-range bombardment

### Decision: Arc Storm Fires from Factories

**Choice**: Player's Arc Storm base weapon fires from home base AND all completed factories

**Rationale**:
- Creates strong incentive to expand with Harvesters
- More factories = more Arc Storm coverage = better defense
- Rewards territorial control beyond just resource income
- Makes factory network feel like a power grid

**Implementation**: `fire_base_weapon()` iterates over all team factories

### Decision: Harvester System Fixes

**Changes**:
1. **Max 2 harvesters** - Reduced from scaling 5 to fixed 2 when expansion needed
2. **Stay at build location** - Harvesters now actively brake to stop at target
3. **Complete factory check** - Only count complete factories when finding targets
4. **Camp tolerance** - Increased from 30 to 50 units for drift tolerance

**Rationale**:
- 6 harvesters flying around was excessive
- Harvesters were leaving mid-construction because incomplete factories counted as "nearby"
- Momentum physics caused drift exceeding camp tolerance

### Decision: Expansion Body Count

**Choice**: Reduced from 4-6 random to fixed 3 bodies per expansion

**Rationale**:
- 4-6 bodies per phase was overwhelming
- Fixed count provides predictable expansion pace
- 3 bodies evenly distributed looks cleaner

### Decision: Factory Energy Bonus

**Choice**: Each completed factory provides +15 energy/second (linear scaling)

**Rationale**:
- Rewards expansion beyond just Arc Storm coverage and ship spawn points
- Creates economic snowball - more factories = faster production = more factories
- Encourages aggressive harvester play to outpace enemy economy
- Gives meaningful reason to protect factories (not just production locations)
- Linear scaling (not exponential) keeps it predictable and balanced

**Implementation**: `_on_energy_regen()` in `vnp_main.gd` counts completed factories per team

---

## Progenitor Mothership (December 2024)

### Decision: Mothership as Win Condition

**Choice**: Progenitor Mothership spawns 60 seconds after emergence; destroying it breaks the cycle

**Rationale**:
- Gives players a tangible goal during Progenitor phase
- "Survive long enough and you get a shot" creates tension
- Normal victory suspended during Progenitor phase prevents anticlimactic wins
- 5000 HP mothership is a serious challenge but achievable

**Implementation**:
- `mothership_spawn_delay: 60.0` in CONVERGENCE_TIMING
- `MOTHERSHIP_CONFIG` defines stats (5000 HP, 4x visual scale)
- Destroying mothership sets `mothership_destroyed = true` in convergence state
- `_handle_mothership_victory()` shows special victory screen

### Decision: Victory Suspension During Progenitor

**Choice**: Normal victory conditions don't trigger while Progenitor is active with ships

**Rationale**:
- Prevents anticlimactic "Nemesis Wins!" when player is fighting the Progenitor
- Forces players to actually deal with the existential threat
- The real battle is against the cycle, not other factions

**Implementation**: `CHECK_VICTORY` in reducer checks `progenitor_active and progenitor_has_ships`

---

## Harvester Improvements (December 2024)

### Decision: Scaling Harvester Cap

**Choice**: Max harvesters scales based on unclaimed territory (2/3/4 based on 1-2/3-5/6+ points)

**Rationale**:
- Fixed cap of 2 was too slow when many expansion opportunities exist
- More unclaimed points = more harvesters needed to expand
- Prevents AI from building harvesters when there's nothing to claim

**Implementation**: `_decide_ship_to_build()` in `vnp_ai_controller.gd`

### Decision: Aggressive Harvester Braking

**Choice**: Harvesters use 40x stronger braking at build locations

**Rationale**:
- Asteroids-style momentum caused harvesters to overshoot targets
- Camp tolerance (50 units) was too tight for drifting ships
- Factory building requires staying still - momentum was preventing this

**Implementation**:
- `_harvester_brake()` function in `ship.gd` with 40x drag
- `_move_to()` slows harvesters to 30% when within 100 units of target
- Snap to zero velocity when speed < 8

### Decision: Harvester Speed Boost

**Choice**: Harvesters have speed 320 (fastest ship type, up from 200)

**Rationale**:
- Harvesters need to "bee-line" to unclaimed territory
- Expansion pace was too slow with standard ship speed
- Faster harvesters with stronger braking = quick transit + precise stop
- Creates distinct tactical role: dedicated expansion ships

**Implementation**: `SHIP_STATS[ShipType.HARVESTER]["speed"] = 320` in `vnp_types.gd`

---

## Performance (December 2024)

### Decision: Alt-Tab Effect Skip

**Choice**: Skip visual effects for 2 frames after window regains focus

**Rationale**:
- When alt-tabbed, game logic continues but rendering pauses
- Returning causes explosion backlog to fire simultaneously = lag spike
- Skipping effects briefly prevents the spike without affecting gameplay

**Implementation**:
- `_notification(NOTIFICATION_APPLICATION_FOCUS_IN)` sets `skip_effects_frames = 2`
- All spawn functions check `skip_effects_frames > 0` before creating particles
- Ships still die, damage still happens - only visuals skipped

---

*Document Version: 1.5*
*Last Updated: December 2024*
