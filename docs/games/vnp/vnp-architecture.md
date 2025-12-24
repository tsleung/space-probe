# VNP Architecture Overview

This document provides a comprehensive view of the Von Neumann Probe game architecture.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              vnp_main.tscn                                  │
│                           (Game Controller)                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                  │
│  │   VnpStore   │◄───│  VnpReducer  │    │  VnpSystems  │                  │
│  │    (State)   │    │  (Actions)   │    │ (Pure Logic) │                  │
│  └──────┬───────┘    └──────────────┘    └──────────────┘                  │
│         │                                                                   │
│         │ on_state_changed()                                               │
│         ▼                                                                   │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                  │
│  │   VnpMain    │    │    VnpUI     │    │     Ships    │                  │
│  │ (Game Loop)  │    │  (Display)   │    │  (Entities)  │                  │
│  └──────────────┘    └──────────────┘    └──────────────┘                  │
│         │                                       │                           │
│         ▼                                       ▼                           │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                  │
│  │ AIController │    │ SoundManager │    │ Projectiles  │                  │
│  │  (Decisions) │    │   (Audio)    │    │   (Pool)     │                  │
│  └──────────────┘    └──────────────┘    └──────────────┘                  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## File Structure

### Scripts (`scripts/von_neumann_probe/`)

| File | Lines | Responsibility |
|------|-------|----------------|
| `vnp_main.gd` | 1447 | Game loop, timers, camera, world, bases, strategic points, rally system |
| `ship.gd` | 1854 | Ship entity - movement, combat, targeting, visual effects |
| `vnp_ui.gd` | 853 | UI panels, victory display, fleet doctrine controls |
| `projectile.gd` | 803 | Projectile types (railgun/laser/missile/turbolaser), pooling |
| `base_weapon.gd` | 719 | Base weapons (Arc Storm, Hellstorm, Void Tear), charge system |
| `vnp_systems.gd` | 442 | Pure functions - targeting, movement, scoring |
| `vnp_ai_controller.gd` | 436 | AI build decisions, counter-picking, doctrine management |
| `vnp_sound_manager.gd` | 384 | Procedural audio generation, sound pooling |
| `vnp_types.gd` | 318 | Enums, constants, ship stats, weapon colors |
| `vnp_reducer.gd` | 249 | State reducer - all action handlers |
| `vnp_store.gd` | 42 | State container with pub/sub pattern |

### Scenes (`scenes/von_neumann_probe/`)

| Scene | Purpose |
|-------|---------|
| `vnp_main.tscn` | Root game scene |
| `vnp_store.tscn` | State management node |
| `vnp_ui.tscn` | UI container |
| `ship.tscn` | Ship entity template |
| `projectile.tscn` | Projectile template |
| `impact_fx.tscn` | Hit particle effect |
| `death_explosion_fx.tscn` | Death explosion effect |

---

## State Structure

```
state = {
    "teams": {
        PLAYER: { energy, mass, rally_point },
        ENEMY_1: { energy, mass, rally_point },
        NEMESIS: { energy, mass, rally_point }
    },

    "ships": {
        ship_id: { id, team, type, position, health, state, target }
    },

    "strategic_points": {
        point_id: { type, position, owner }
    },

    "expansion": { phase, world_scale, max_phase },

    "convergence": {                    // THE CYCLE
        phase,                          // ConvergencePhase enum
        center,                         // Vector2 - convergence point
        original_radius,                // Starting absorption radius
        absorption_radius,              // Current safe zone (shrinks)
        pull_strength,                  // Gravitational pull force
        instability,                    // 0-100, triggers fragmentation
        absorbed_count,                 // Ships consumed by Progenitor
        time_in_phase,                  // Time tracker for transitions
        progenitor_revealed             // Has ??? become THE PROGENITOR?
    },

    "game_over": bool,
    "winner": int
}
```

---

## Game Loop (Timers)

```
┌─────────────────────────────────────────────────────────────────┐
│                        GAME TICK TIMELINE                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Every Frame (60fps)                                            │
│  ├── Ships: _physics_process()                                  │
│  │   ├── Update target cache (every 0.3s)                       │
│  │   ├── Movement (thrust, momentum, drag)                      │
│  │   ├── Combat (fire weapons if target in range)               │
│  │   └── Sync position to state (every 0.5s)                    │
│  └── Projectiles: _physics_process()                            │
│      └── Move, check collisions, apply damage                   │
│                                                                  │
│  Every 0.3s                                                     │
│  └── AIController: Build decision per team                      │
│                                                                  │
│  Every 0.5s                                                     │
│  └── VictoryCheckTimer: CHECK_VICTORY action                    │
│                                                                  │
│  Every 1.0s                                                     │
│  └── EnergyRegenTimer: ADD_ENERGY to all teams                  │
│      ├── Player/Enemy: +60 energy                               │
│      └── Nemesis: +90 energy (1.5x multiplier)                  │
│                                                                  │
│  Every 2.0s                                                     │
│  ├── StrategicPointTimer: Mass income + capture check           │
│  └── PlanetIncomeTimer: Legacy planet income                    │
│                                                                  │
│  Every 10.0s                                                    │
│  └── ExpansionTimer: EXPAND_WORLD (phases 0-10)                 │
│                                                                  │
│  Every 15.0s (per team)                                         │
│  └── Base Weapon: +1 charge (max 5)                             │
│                                                                  │
│  Every 0.5s                                                     │
│  └── ConvergenceTimer: THE CYCLE processing                     │
│      ├── DORMANT: Check whispers trigger (60s or 60 ships)      │
│      ├── WHISPERS: Edge anomalies, random shake                 │
│      ├── CONTACT: ??? DETECTED card                             │
│      ├── EMERGENCE: Pull begins, zone shrinks (15 px/s)         │
│      ├── CRITICAL: Faster shrink (40 px/s), instability++       │
│      └── FRAGMENTATION: Game over, cycle continues              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         ACTION DISPATCH                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   Timer/Input/Ship                                              │
│         │                                                        │
│         ▼                                                        │
│   store.dispatch({ type: "ACTION", ... })                       │
│         │                                                        │
│         ▼                                                        │
│   reducer.reduce(state, action)                                 │
│         │                                                        │
│         ▼                                                        │
│   new_state returned                                            │
│         │                                                        │
│         ▼                                                        │
│   store._notify_subscribers()                                   │
│         │                                                        │
│         ├──► vnp_main.on_state_changed()                        │
│         │    └── Update ship nodes, visuals                     │
│         │                                                        │
│         ├──► vnp_ui.on_state_changed()                          │
│         │    └── Update panels, labels                          │
│         │                                                        │
│         └──► ship.on_state_changed() (each ship)                │
│              └── Check if destroyed, update target              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Actions Reference

### Core Actions

| Action | Trigger | Effect |
|--------|---------|--------|
| `BUILD_SHIP` | AI/Player | Deduct cost, spawn ship |
| `DAMAGE_SHIP` | Projectile hit | Reduce health, remove if dead |
| `ADD_ENERGY` | Timer (1s) | +60/+90 energy per team |
| `STRATEGIC_POINT_INCOME` | Timer (2s) | +mass based on owned points |
| `CAPTURE_STRATEGIC_POINT` | Capture check | Change owner, +50 energy +10 mass |
| `SET_RALLY_POINT` | Player click | Direct ships to location |
| `FULL_SEND` | Player double-click | Aggressive all-ship push |
| `EXPAND_WORLD` | Timer (10s) | Grow arena, spawn asteroid fields |
| `CHECK_VICTORY` | Timer (0.5s) | End game if 1 team left |
| `RESET_GAME` | After victory | Return to initial state |

### Convergence Actions (The Cycle)

| Action | Trigger | Effect |
|--------|---------|--------|
| `CONVERGENCE_SET_PHASE` | Phase transition | Change convergence phase, set pull strength |
| `CONVERGENCE_INITIALIZE` | Contact phase | Set center and initial radius |
| `CONVERGENCE_SHRINK` | Emergence/Critical | Reduce absorption radius |
| `CONVERGENCE_UPDATE_TIME` | Timer (0.5s) | Track time in current phase |
| `CONVERGENCE_ABSORB_SHIP` | Ship outside zone | Remove ship, increment absorbed count |
| `CONVERGENCE_ADD_INSTABILITY` | Ship absorbed | Increase toward fragmentation threshold |
| `CONVERGENCE_REVEAL_PROGENITOR` | Emergence | Mark progenitor as revealed |
| `CONVERGENCE_FRAGMENTATION` | Instability >= 100 | End game, cycle continues |
| `FULL_RETREAT` | Player during convergence | All ships flee to center |

---

## Ship Types

```
┌──────────────────────────────────────────────────────────────────┐
│                         SHIP ROSTER                               │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  COMBAT SHIPS                                                    │
│  ┌─────────┬──────┬───────┬────────┬────────┬──────────────────┐ │
│  │ Type    │ Cost │ Speed │ Health │ Weapon │ Role             │ │
│  ├─────────┼──────┼───────┼────────┼────────┼──────────────────┤ │
│  │ Frigate │  50  │  280  │   70   │ Railgun│ Fast swarm       │ │
│  │ Destroy │  75  │  180  │  130   │ Laser  │ Sniper           │ │
│  │ Cruiser │ 100* │  100  │  220   │ Missile│ Heavy artillery  │ │
│  │ Starbase│ 400* │   0   │  800   │ Turbo  │ Area denial      │ │
│  └─────────┴──────┴───────┴────────┴────────┴──────────────────┘ │
│  * = Requires mass                                               │
│                                                                   │
│  SUPPORT SHIPS                                                   │
│  ┌─────────┬──────┬───────┬────────┬──────────────────────────┐  │
│  │ Type    │ Cost │ Speed │ Health │ Ability                  │  │
│  ├─────────┼──────┼───────┼────────┼──────────────────────────┤  │
│  │ Defender│  80  │  160  │  100   │ PDC: 40% missile intercept│  │
│  │ Shielder│  90* │  140  │   80   │ Shield bubble (120 rad)  │  │
│  │ Graviton│ 120* │   80  │  180   │ Deflects railguns (85%)  │  │
│  └─────────┴──────┴───────┴────────┴──────────────────────────┘  │
│                                                                   │
│  WEAPON COUNTERS (Rock-Paper-Scissors)                           │
│  ┌───────────────────────────────────────────────────────────┐   │
│  │  GUN (Railgun) ──2x──► LASER ──2x──► MISSILE ──2x──► GUN │   │
│  │       ◄──0.5x──        ◄──0.5x──          ◄──0.5x──       │   │
│  └───────────────────────────────────────────────────────────┘   │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘
```

---

## UI Layout

```
┌─────────────────────────────────────────────────────────────────┐
│ [Player Panel] [Enemy Panel] [Nemesis Panel]      [Menu] [Exp] │
│  Ships: 12      Ships: 8      Ships: 15           [10s]        │
│  Energy: 450    Energy: 320   Energy: 890                      │
│  Mass: 25       Mass: 18      Mass: 42                         │
│  Points: 3      Points: 2     Points: 4                        │
│  [●●●○○]        [●●○○○]       [●●●●○]  ◄── Base weapon charges │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│                                                                 │
│                      (Game Viewport)                            │
│                                                                 │
│     ◆ = Strategic Point (CENTER gives +15% damage)             │
│     ⬡ = Asteroid Field (+5 mass/tick)                          │
│     ◇ = Relay Station (+10% health bonus)                      │
│                                                                 │
│     ▲ = Player Base (Arc Storm)                                │
│     ▼ = Enemy Base (Hellstorm)                                 │
│     ◄ = Nemesis Base (Void Tear)                               │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│ [Doctrine Panel - Collapsible]                                  │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ Build Stance: [Aggressive] [Balanced] [Defensive]          │ │
│ │ Formation:    [Offensive] [Defensive]                       │ │
│ │ Adherence:    [Loose] [Tight]                               │ │
│ │ Ship Priority: FR[2x] DE[1x] CR[1x] DF[1x] SH[1x] GR[1x]   │ │
│ └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

---

## Strategic Points

```
┌─────────────────────────────────────────────────────────────────┐
│                       MAP LAYOUT                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│                         [CENTER]                                 │
│                      +15% damage bonus                           │
│                      +3 mass/tick                                │
│                            │                                     │
│               ┌────────────┼────────────┐                        │
│               │            │            │                        │
│          [RELAY]      [RELAY]      [RELAY]                       │
│         +10% HP      +10% HP      +10% HP                        │
│         +2 mass      +2 mass      +2 mass                        │
│               │            │            │                        │
│    ┌──────────┼────────────┼────────────┼──────────┐             │
│    │          │            │            │          │             │
│ [AST]      [AST]        [AST]        [AST]      [AST]           │
│ +5 mass   +5 mass      +5 mass      +5 mass    +5 mass          │
│    │          │            │            │          │             │
│ [PLAYER]             [ENEMY]               [NEMESIS]             │
│   BASE                BASE                   BASE                │
│                                                                  │
│ (More asteroid fields spawn during EXPANSION phases)            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Base Weapons

| Team | Weapon | Effect | Visual |
|------|--------|--------|--------|
| Player | Arc Storm | Chain lightning, jumps to enemies | Blue arcs |
| Enemy | Hellstorm | Volley of homing missiles | Orange trails |
| Nemesis | Void Tear | Gravity well, pulls/damages | Purple vortex |

**Charge Scaling:**
- x1: 350 range, 80 damage
- x2: 560 range, 120 damage
- x3: 770 range, 160 damage
- x4: 980 range, 200 damage
- x5: 1400 range, 240 damage (clears center of map)

---

## AI Decision Making

```
┌─────────────────────────────────────────────────────────────────┐
│                      AI BUILD LOOP (every 0.3s)                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. Check if can afford ANY ship                                │
│     └── If not, wait                                            │
│                                                                  │
│  2. Analyze enemy fleet composition                             │
│     └── Count enemy weapon types (gun/laser/missile)            │
│                                                                  │
│  3. Counter-pick decision (based on stance)                     │
│     ├── Aggressive: 40% chance to counter-pick                  │
│     ├── Balanced: 55% chance to counter-pick                    │
│     └── Defensive: 70% chance to counter-pick                   │
│                                                                  │
│  4. If counter-picking:                                         │
│     ├── Enemy has mostly GUN → Build LASER (Destroyer)          │
│     ├── Enemy has mostly LASER → Build MISSILE (Cruiser)        │
│     └── Enemy has mostly MISSILE → Build GUN (Frigate)          │
│                                                                  │
│  5. If not counter-picking: Weighted random selection           │
│     └── Weight = base_weight × priority_multiplier              │
│                                                                  │
│  6. Dispatch BUILD_SHIP action                                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Module Dependencies

```
                    ┌──────────────┐
                    │  vnp_types   │ (constants, no deps)
                    └──────┬───────┘
                           │
          ┌────────────────┼────────────────┐
          │                │                │
          ▼                ▼                ▼
   ┌────────────┐   ┌────────────┐   ┌────────────┐
   │vnp_systems │   │vnp_reducer │   │  vnp_store │
   │(pure logic)│   │ (actions)  │   │  (state)   │
   └─────┬──────┘   └──────┬─────┘   └──────┬─────┘
         │                 │                │
         └────────────┬────┴────────────────┘
                      │
                      ▼
              ┌──────────────┐
              │   vnp_main   │ (orchestrator)
              └──────┬───────┘
                     │
      ┌──────────────┼──────────────┬──────────────┐
      │              │              │              │
      ▼              ▼              ▼              ▼
┌──────────┐  ┌──────────┐  ┌───────────┐  ┌────────────┐
│   ship   │  │  vnp_ui  │  │ai_control │  │sound_mgr   │
│(entities)│  │  (UI)    │  │ (AI)      │  │ (audio)    │
└────┬─────┘  └──────────┘  └───────────┘  └────────────┘
     │
     ▼
┌──────────┐  ┌──────────┐
│projectile│  │base_weapon│
│ (pool)   │  │(specials) │
└──────────┘  └──────────┘
```

---

## Performance Optimizations (Implemented)

| Optimization | Before | After |
|--------------|--------|-------|
| Position sync | 60/sec per ship | 2/sec per ship (throttled) |
| Target search | Every frame (O(N²)) | Cached 0.3s |
| Projectiles | instantiate/queue_free | Pool of 100 |
| Audio | Create on demand | Pre-cached pools |

---

## Not Implemented (Future)

- Speed controls (1x, 2x, 4x)
- Priority targeting (click enemy to focus)
- Carrier/Bomber ship types
- Map variations
- **Outpost Building**: Harvesters build mini-factories at strategic points
- **Secret Ending**: Self-fragmentation to break the cycle
- Probe self-replication mechanics (galaxy mode)
- Galaxy view/campaign mode

---

## External Dependencies

VNP is **self-contained** and does NOT use the shared engine layer (`scripts/engine/`).

Custom implementations:
- `vnp_store.gd` - Simple pub/sub (not engine Store)
- `vnp_reducer.gd` - Action handler (not Dispatcher)
- Uses Godot built-in: NavigationAgent2D, Area2D, CharacterBody2D
