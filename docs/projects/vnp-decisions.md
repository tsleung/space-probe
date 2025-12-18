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

*Document Version: 1.0*
*Last Updated: December 2024*
