# Von Neumann Probe (VNP) - Game Design Document

## Overview

Von Neumann Probe is an automated real-time space battle spectacle built in Godot 4.5. Three factions compete in dramatic fleet combat with colorful explosions, weapon trails, and strategic depth. The game emphasizes visual spectacle while offering meaningful tactical options.

**Core Loop**: Watch automated battles → Intervene with rally points and base weapons → Manage fleet doctrine → Witness spectacular victories

---

## Factions

### Player (Blue)
- **Color Theme**: Deep Sky Blue, Cyan
- **Base Weapon**: Ion Cannon (chain lightning damage)
- **Weapon Colors**: Ice blue railguns, cyan lasers, blue missiles
- **Playstyle**: Balanced, player-directed

### Enemy (Orange/Red)
- **Color Theme**: Orange Red, Yellow
- **Base Weapon**: Missile Barrage (area bombardment)
- **Weapon Colors**: Yellow autocannons, green plasma, orange torpedoes
- **Playstyle**: Aggressive swarm tactics

### Nemesis (Purple)
- **Color Theme**: Dark Violet, Magenta
- **Base Weapon**: Singularity (gravity well)
- **Weapon Colors**: Purple pulses, magenta disruptors, antimatter missiles
- **Energy Bonus**: 1.5x energy regeneration
- **Playstyle**: Overwhelming force

---

## Ship Types

### Combat Ships

| Ship | Weapon | Cost | Mass | Speed | Health | Damage | Range | Role |
|------|--------|------|------|-------|--------|--------|-------|------|
| **Frigate** | Railgun (GUN) | 50 | 0 | 280 | 70 | 18 | 200 | Fast assault, swarm |
| **Destroyer** | Laser (LASER) | 75 | 0 | 180 | 130 | 40 | 400 | Sniper, mid-range |
| **Cruiser** | Missile (MISSILE) | 100 | 25 | 100 | 220 | 50 | 500 | Artillery, area damage |
| **Star Base** | Turbolaser | 400 | 100 | 0 | 800 | 120 | 600 | Immobile fortress |

### Support Ships

| Ship | Ability | Cost | Mass | Speed | Health | Role |
|------|---------|------|------|-------|--------|------|
| **Defender** | PDC Interception | 80 | 0 | 160 | 100 | Shoots down missiles (40% intercept) |
| **Shielder** | Shield Bubble | 90 | 10 | 140 | 80 | Protects nearby allies |
| **Graviton** | Gravity Well | 120 | 40 | 80 | 180 | Deflects railguns (85% deflect) |

### Defense Structures

| Structure | Weapon | Health | Damage | Range | Fire Rate | Role |
|-----------|--------|--------|--------|-------|-----------|------|
| **Base Turret** | Railgun | 350 | 25 | 350 | 3/sec | Early game defense |
| **Star Base** | Turbolaser | 800 | 120 | 600 | 0.5/sec | Fortress, area denial |

**Base Turrets**: Each team spawns with 2 turrets flanking their home base. These provide critical early-game protection while fleets build up, preventing rushes from overwhelming a base before defenses can be established. Not buildable - spawned automatically at game start and on restart.

### Rock-Paper-Scissors Damage

- **Gun (Railgun)** → Strong vs Laser, Weak vs Missile
- **Laser** → Strong vs Missile, Weak vs Gun
- **Missile** → Strong vs Gun, Weak vs Laser

Each counter deals **2x damage**, each disadvantage deals **0.5x damage**.

---

## Economy System

### Two Resources

1. **Energy** (Yellow)
   - Regenerates passively: 60/second for Player/Enemy, 90/second for Nemesis
   - Used for all ship building
   - No upper limit

2. **Mass** (Brown)
   - Earned from captured strategic points
   - Required for advanced ships (Cruiser, Shielder, Graviton, Star Base)
   - Provides strategic depth beyond energy racing

### Strategic Points

| Type | Mass Income | Bonus |
|------|-------------|-------|
| **Command Center** (1x, center) | 3/tick | +15% damage to all ships |
| **Asteroid Field** (6x, territories) | 5/tick | Primary mass source |
| **Relay Station** (3x, between factions) | 2/tick | +10% health to new ships |

Ships automatically capture points by presence. Capture shown with team-colored rings.

---

## Base Weapons (Superweapons)

Each faction has a unique base weapon that charges over time.

### Charge System

- **Cooldown**: 15 seconds per charge
- **Max Charges**: 5
- **Modes**:
  - **Auto**: Fires immediately when 1 charge available
  - **Manual**: Accumulates charges for strategic burst

### Charge Scaling (Risk/Reward)

The number of charges fired dramatically affects range, damage, and visual spectacle:

| Charges | Range | Damage | Visual Effect | Use Case |
|---------|-------|--------|---------------|----------|
| **x1** | 350 | 80 | Small burst | Desperation defense, close enemies |
| **x2** | 612 | 120 | Core beam added | Tactical strike |
| **x3** | 875 | 160 | Charge-up, particles | Significant push |
| **x4** | 1137 | 200 | Major spectacle | Area clearing |
| **x5** | 1400 | 240 | MASSIVE effect | Reaches center, game-changing |

**Strategic Choice**: Fire early for survival vs. accumulate for devastating long-range strikes.

### Weapon Types

1. **Ion Cannon** (Player): Beam weapon along line toward enemy cluster
2. **Missile Barrage** (Enemy): Volley of homing missiles (scales from 8 to 24)
3. **Singularity** (Nemesis): Gravity well with scaling radius and pull strength

### UI Controls (Player Only)

- **Mode Toggle (M/A)**: Switch between Manual and Auto
- **FIRE Button**: Fire 1 charge (close range, responsive)
- **BURST Button**: Fire ALL charges at once (long range, spectacular)
- **Charge Indicators**: 5 dots showing stored charges

---

## Fleet Doctrine System

Player can customize their faction's behavior via the Fleet Doctrine panel.

### Build Stance

Controls what ship types the AI prefers to build:

| Stance | Focus | Counter-Pick Chance |
|--------|-------|---------------------|
| **Aggressive** | Frigates, Cruisers | 40% (commits to strategy) |
| **Balanced** | Mixed fleet | 60% (adaptive) |
| **Defensive** | Support ships | 70% (very reactive) |

### Fleet Posture

Controls how ships move tactically:

- **Offensive**: Ships push toward enemy, chase targets aggressively
- **Defensive**: Ships stay near fleet center, limited chase distance

### Fleet Adherence

Controls how tightly ships stick together:

- **Loose**: Ships spread out, pursue individual targets
- **Tight**: Ships cluster, overlapping support ranges

### Ship Production Priorities

Click ship type buttons in the doctrine panel to adjust production weights:

| Priority | Multiplier | Visual | Effect |
|----------|------------|--------|--------|
| Normal | 1x | Gray | Standard production weight |
| Boosted | 2x | Green | Double chance to build |
| High | 3x | Orange | Triple chance to build |
| Exclusive | ∞ | Red | Almost exclusively builds this type |

**Usage**: Click a ship type to cycle through priority levels. Useful for countering enemy fleet composition or focusing on a specific strategy.

---

## Visual Effects System

### Projectile Trails

Each weapon type has distinctive visual treatment:

- **Railgun**: Line2D trail with faction-colored gradient
- **Laser**: Instant beam with glow
- **Missile**: GPUParticles2D smoke trail, curved bezier arc flight path
- **Turbolaser**: Large bolt with trailing particle glow, slow movement

### Faction-Colored Effects

All visual effects use faction-specific color palettes:

```
Player:  Ice white → Bright cyan → Deep blue
Enemy:   Hot white → Bright orange → Deep red
Nemesis: Pink-white → Hot magenta → Deep purple
```

### Explosions

Death explosions scale with ship size:

| Ship Size | Shake Intensity | Explosion Scale | Notes |
|-----------|-----------------|-----------------|-------|
| Small | 10 | 2.0x | Frigate, Harvester |
| Medium | 25 | 3.5x | Destroyer, Defender, Shielder |
| Large | 50 | 6.0x | Cruiser, Graviton |
| Massive | 100 | 12.0x | Star Base - secondary explosions + shockwave |

### Explosion Layers (Missiles)

1. **Flash**: Brief bright white/faction burst
2. **Fire**: Main explosion with faction color gradient
3. **Smoke**: Gray dissipating particles
4. **Sparks**: Faction-colored debris
5. **Shockwave Ring**: Expanding Line2D circle

### Rate Limiting

Explosions are rate-limited to 3 per frame to prevent lag when returning from background tabs.

---

## Sound Design

### Procedural Audio

All sounds are procedurally generated using `AudioStreamWAV` with synthesized samples. Sounds are cached at startup to prevent memory leaks.

### Sound Characteristics

| Sound | Style | Notes |
|-------|-------|-------|
| Laser | Bubbly sine sweep | Wobbling frequency (800 + sin(t*40)*300 Hz) |
| Railgun | Soft pop/thud | Low sine tones (180 + 90 Hz) |
| Missile | Smooth whoosh | Rising frequency (100 → 500 Hz) |
| PDC | Soft tick | Quick 600 Hz pulse |
| Turbolaser | Deep pulse | Wobbling 200 Hz with sub-bass |
| Explosions | Tonal boom | Low sine (120 - size*20 Hz), soft decay |
| Capture | Ascending tone | Rising (400 → 1000 Hz) with fifth harmonic |

### Design Philosophy

- Soft attack/decay envelopes for smooth feel
- Tone-based (sine waves) rather than noise-based for cleaner sound
- Volume-balanced to prevent harshness
- Pitch variation (0.85-1.15x) for natural feel

---

## Support Ship Mechanics

### Escort Behavior

Support ships (Defender, Shielder, Graviton) automatically escort combat ships:

1. Find nearest allied combat ship within 400 units
2. Maintain escort distance (80-120 units behind/beside)
3. Fall back to fleet center if no combat ships nearby

### Graviton Deflection

When enemy railguns enter Graviton's gravity well:

- 85% chance to deflect
- Railgun curves around Graviton
- Creates visual deflection trail (purple-tinted)
- Sparks at deflection point
- Deflected projectiles deal 30% damage

---

## Rally Point System

Player can direct their fleet by clicking:

1. **Click Enemy Base**: All new ships route to attack that base
2. **Click Strategic Point**: Fleet prioritizes capturing that point
3. **Click Player Base**: Clear rally point (ships go to fleet center)

### Visual Feedback

- Line2D arrow from player base to rally target
- Semi-transparent blue with arrow head
- Updates when rally point changes

---

## AI Controller

### Build Decision Loop

Each team has a Timer (0.3s + random 0-0.3s) that triggers build decisions:

1. **Wait for Full Options**: Don't build until energy >= max ship cost (prevents cheap spam)
2. **Check Mass**: Filter to affordable ships based on current mass
3. **Counter-Pick** (chance based on stance): Analyze enemy weapon types, build counter
4. **Weighted Random**: Select from remaining options based on stance weights

### Victory Conditions

Game ends when one team eliminates all enemies:

1. Check every 0.5 seconds
2. Victory screen for 3 seconds
3. Auto-restart with reset state

---

## UI Layout

### Top Status Bar (Centered)

```
[Player Panel] [Enemy Panel] [Nemesis Panel] [Menu]
```

Each panel shows:
- Team name (colored)
- Ship count
- Energy (yellow)
- Mass (brown)
- Strategic points owned
- Base weapon status (charge indicators + mode/fire for player)

### Bottom Left: Fleet Doctrine

Compact panel with:
- Stance buttons: AGG | BAL | DEF
- Posture + Adherence: OFF | DEF | LSE | TGT
- Fleet composition: FRG:0 DST:0 CRS:0 DEF:0 SHD:0 GRV:0

---

## Technical Architecture

### State Management (Redux-like)

- **VnpStore**: Central state container with subscription system
- **VnpReducer**: Pure function state updates
- **Actions**: BUILD_SHIP, DAMAGE_SHIP, CAPTURE_STRATEGIC_POINT, etc.

### Pure Functions (VnpSystems)

All testable game logic is extracted to `vnp_systems.gd` as static pure functions:

| Category | Functions | Usage |
|----------|-----------|-------|
| **Movement** | `apply_thrust`, `apply_drag`, `clamp_velocity`, `calculate_movement` | Ship physics |
| **Targeting** | `score_target`, `find_best_target`, `find_better_target` | Combat AI |
| **Clustering** | `calculate_centroid`, `calculate_cluster_score`, `find_enemy_cluster` | Base weapon targeting |
| **Fleet** | `calculate_fleet_center` | Formation positioning |
| **Base Weapon** | `get_weapon_range`, `get_weapon_damage`, `evaluate_base_weapon_fire` | Superweapon AI |
| **Geometry** | `point_to_line_distance`, `is_in_beam_path`, `apply_damage_falloff` | Beam collision |
| **Bonuses** | `get_team_health_bonus`, `get_team_damage_bonus` | Strategic point effects |

**Why Pure Functions?**
- Unit testable without game scene (40 tests in `tests/unit/test_vnp_systems.gd`)
- No side effects - deterministic results
- Self-documenting through function signatures

### Key Files

```
scripts/von_neumann_probe/
├── vnp_main.gd          # Main game loop, timers, visual orchestration
├── vnp_store.gd         # State container
├── vnp_reducer.gd       # State mutations
├── vnp_systems.gd       # Pure functions (tested)
├── vnp_types.gd         # Enums, constants, ship stats
├── vnp_ai_controller.gd # Build decisions, fleet formations
├── vnp_ui.gd            # UI creation and updates
├── vnp_sound_manager.gd # Procedural audio
├── ship.gd              # Ship behavior, combat, escort logic
├── projectile.gd        # Projectile movement, effects, damage
└── base_weapon.gd       # Superweapon mechanics
```

### Data-Driven Balance

Ship stats and game parameters are defined in `vnp_types.gd` for easy tuning:

```gdscript
const SHIP_STATS = {
    ShipType.FRIGATE: { "cost": 50, "health": 70, "speed": 280, "damage": 18, "range": 200, ... },
    ShipType.DESTROYER: { "cost": 75, "health": 130, "speed": 180, "damage": 40, "range": 400, ... },
    # etc.
}
```

**Adjustable Parameters**:
- Ship costs, health, speed, damage, range
- Energy regeneration rates (60/sec player, 90/sec nemesis)
- Strategic point bonuses (+15% damage, +10% health, +5 mass)
- Base weapon charge timing and scaling

### Performance Optimizations

- Explosion rate limiting (3/frame)
- Sound caching (generate once at startup)
- Ship pooling via ID tracking
- Line2D trails instead of Trail2D addon

---

## Future Considerations

- Speed controls (1x, 2x, 4x)
- Priority targeting (click enemy to focus fire)
- More ship types (Carrier, Bomber)
- Map variations
- Balance tuning via JSON

---

*Document Version: 1.1*
*Last Updated: December 2024*

---

## Related Documents

- [vnp-decisions.md](./vnp-decisions.md) - Architecture and design decisions
- [engineering-principles.md](../principles/engineering-principles.md) - Project-wide coding principles
