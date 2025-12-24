# Von Neumann Probe (VNP) - Game Design Document

## Overview

Von Neumann Probe is an automated real-time space battle spectacle built in Godot 4.5. Three factions compete in dramatic fleet combat with colorful explosions, weapon trails, and strategic depth. The game emphasizes visual spectacle while offering meaningful tactical options.

**Core Loop**: Watch automated battles → Intervene with rally points and base weapons → Manage fleet doctrine → Witness spectacular victories

---

## Factions

### Player (Blue)
- **Color Theme**: Deep Sky Blue, Cyan
- **Base Weapon**: Arc Storm (chain lightning beam)
- **Weapon Colors**: Ice blue railguns, cyan lasers, blue missiles
- **Playstyle**: Balanced, player-directed

### Enemy (Orange/Red)
- **Color Theme**: Orange Red, Yellow
- **Base Weapon**: Hellstorm (missile barrage)
- **Weapon Colors**: Yellow autocannons, green plasma, orange torpedoes
- **Playstyle**: Aggressive swarm tactics

### Nemesis (Purple)
- **Color Theme**: Dark Violet, Magenta
- **Base Weapon**: Void Tear (gravity singularity)
- **Weapon Colors**: Purple pulses, magenta disruptors, antimatter missiles
- **Energy Bonus**: 1.5x energy regeneration
- **Playstyle**: Overwhelming force

---

## Ship Types

### Combat Ships

| Ship | Weapon | Cost | Mass | Speed | Health | Damage | Range | Role |
|------|--------|------|------|-------|--------|--------|-------|------|
| **Frigate** | Railgun (GUN) | 50 | 0 | 280 | 70 | 14 | 200 | Fast assault, swarm |
| **Destroyer** | Laser (LASER) | 75 | 0 | 180 | 130 | 40 | 400 | Sniper, kiting |
| **Cruiser** | Missile (MISSILE) | 75 | 20 | 100 | 220 | 50 | 1000 | Artillery, area damage |
| **Star Base** | Turbolaser | 400 | 100 | 0 | 800 | 120 | 600 | Immobile fortress |

### Support Ships

| Ship | Ability | Cost | Mass | Speed | Health | Role |
|------|---------|------|------|-------|--------|------|
| **Defender** | PDC Interception | 80 | 0 | 160 | 100 | Shoots down missiles (40% intercept) |
| **Shielder** | Shield Bubble | 75 | 5 | 140 | 80 | Protects nearby allies |
| **Graviton** | Gravity Well | 100 | 30 | 80 | 180 | Deflects railguns (85% deflect) |

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
   - **Factory Bonus**: +15 energy/second per completed factory (linear scaling)
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

1. **Arc Storm** (Player): Chain lightning beam toward enemy cluster. **Fires from home base AND all completed factories** - expanding gives more coverage!
2. **Hellstorm** (Enemy): Volley of homing missiles (scales from 8 to 24)
3. **Void Tear** (Nemesis): Gravity well with scaling radius and pull strength

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

### Design Philosophy

Visual effects are designed for maximum spectacle - "12 out of 10" intensity. All effects use multi-layer rendering with glow layers, hot cores, and particle debris for dramatic impact.

### Projectile Trails

Each weapon type has distinctive multi-layer visual treatment:

**Railgun**
- Large 24px slug polygon with gradient fill
- 8px wide outer glow trail (faction color, 30% opacity)
- 4px main trail with gradient (faction color → transparent)
- 2px bright core line (white-hot center)
- Power surge flash at barrel on fire

**Missile**
- 1.2x scaled missile body with engine glow polygon
- 6px smoke trail with wavy path
- Faction-colored engine exhaust glow
- Trailing debris particles

**Turbolaser**
- 50% larger bolt than base size
- Core glow polygon (bright faction color)
- Outer glow ring
- Slow, imposing movement

**Laser Beam**
- 36px wide outer glow (faction color, 25% opacity)
- 18px main beam with gradient
- 6px white-hot core beam
- Burn impact effect at target
- Pulsing intensity animation

### Engine Trails

Ships have multi-layer engine trails:
- Outer glow line (faction color, low opacity)
- Main trail with gradient (solid → transparent)
- Small spark polygon at exhaust point
- Trail length scales with ship size (20-35 units)

### Defensive Ship Effects (Spectacular)

Support ships have elaborate animated effects:

**Shield Bubble (Shielder)**
- Outer ring with pulse animation
- Inner glow ring
- Hexagonal energy pattern grid
- Rotating shimmer animation
- Hexagon rotation effect

**Gravity Well (Graviton)**
- Spinning outer ring
- Inner ring with opposite rotation
- Two spiral arm tendrils
- Dark core with bright rim
- Continuous rotation animation
- Deflection sparks when projectiles curve

**PDC Kill Zone (Defender)**
- Outer pulsing range ring
- Inner targeting ring
- Rotating radar sweep line with gradient
- Crosshair overlay (4 lines)
- Tracer shower when intercepting missiles

### Deflection Effects

When Graviton deflects railguns:
- Ripple ring expanding from deflection point
- Spark burst (8-12 particles)
- Deflection arc line showing curved path
- Purple tint on deflected projectile

### Faction-Colored Effects

All visual effects use faction-specific color palettes:

```
Player:  Ice white → Bright cyan → Deep blue
Enemy:   Hot white → Bright orange → Deep red
Nemesis: Pink-white → Hot magenta → Deep purple
```

### Ship Death Explosions (5-Layer System)

Death explosions are dramatic multi-layer effects:

1. **Initial Flash**: Blinding white burst, expands rapidly
2. **Fire Core**: Faction-colored explosion polygon, irregular edges
3. **Shockwave Ring**: Expanding Line2D circle with fade
4. **Sparks**: 12-16 directional debris lines flying outward
5. **Smoke Plume**: Rising, expanding smoke polygon

| Ship Size | Shake Intensity | Flash Scale | Spark Count | Notes |
|-----------|-----------------|-------------|-------------|-------|
| Small | 10 | 40px | 8 | Frigate, Harvester |
| Medium | 25 | 60px | 12 | Destroyer, Defender, Shielder |
| Large | 50 | 90px | 16 | Cruiser, Graviton |
| Massive | 100 | 150px | 24 | Star Base - secondary explosions |

### Missile Explosions (5-Layer System)

1. **Flash**: Brief bright white/faction burst with expansion
2. **Fire**: Multi-polygon explosion with faction color gradient
3. **Smoke**: Gray GPUParticles2D cloud
4. **Sparks**: Faction-colored debris particles
5. **Shockwave Ring**: Expanding Line2D circle with width fade

### Base Weapon Effects

Each faction has spectacular superweapon visuals:

**Arc Storm (Player - Chain Lightning)**

*Charge-Up Phase:*
- Pulsing corona rings around base
- 12-20 electricity tendrils gathering toward center
- Multi-layer tendrils (glow + main + core)
- Central energy orb buildup with flash

*Main Effect:*
- Jagged lightning arcs between chain targets
- Triple-layer per arc (outer glow + main + hot core)
- Secondary arcs branching randomly
- Scales with charge count (5-13 chain targets)

*Impact Effects:*
- Central flash burst at each hit
- Double EMP shockwave rings expanding
- Triple-layer electric sparks (glow + main + core)
- Residual static arcs lingering

**Hellstorm (Enemy - Orbital Bombardment)**

*Warning Phase:*
- Pulsing target zone ring
- Double pulse animation

*Meteor Effects:*
- Outer corona glow on each meteor
- Detailed irregular meteor body polygon
- White-hot inner core
- Main fire trail with gradient
- Outer glow trail (5x width)
- Smoke trail with drift
- Trailing debris/sparks
- Scales: 7-19 impacts based on charges

*Impact Effects:*
- Initial blinding flash (diamond shape)
- Multi-polygon fireball with irregular edges
- Inner fire core
- Triple expanding shockwave rings
- Fire jets with glow layers (12-21 jets)
- Flying debris pieces with spin
- Lingering ground fire with pulse animation
- Rising smoke plume

**Void Tear (Nemesis - Reality Rift)**

*Warning Phase:*
- Pulsing event horizon ring
- Reality distortion (stretched stars pulled toward center)
- Multi-layer reality cracks (glow + main + core)

*Main Rift:*
- Jagged glowing edges (left + right)
- Pure dark void center polygon
- Swirling void particles spiraling inward
- Radial pull effect lines

*Damage Phase:*
- Rift pulses and damages over time
- Screen shake on each damage tick

*Implosion Effects:*
- Pre-collapse energy surge (brightens)
- Violent collapse animation
- Singularity flash burst
- Four expanding shockwave rings (color gradient)
- Triple-layer void energy sparks
- Wobbly reality distortion ripples
- Lingering dark void residue particles

### Screen Shake

Shake intensity scales with event significance:

| Event | Intensity | Duration |
|-------|-----------|----------|
| Small explosion | 10 | 0.2s |
| Medium explosion | 25 | 0.3s |
| Large explosion | 50 | 0.4s |
| Star Base death | 100 | 0.5s |
| Arc Storm impact | 20-80 | 0.3s (per charge) |
| Hellstorm impact | 8-18 | 0.2s (per meteor) |
| Void Tear implosion | 50-150 | 0.5s |

### Rate Limiting

Explosions are rate-limited to 3 per frame to prevent lag when returning from background tabs.

---

## Sound Design

### Inspiration

Sound design inspired by **Journey** and **Nier: Automata** - melodic, emotional, and musical rather than harsh sci-fi noise.

### Procedural Audio

All sounds are procedurally generated using `AudioStreamWAV` with synthesized samples. Sounds are cached at startup to prevent memory leaks.

### Pentatonic Scale System

All sounds use the **C minor pentatonic scale** for inherently pleasant, musical tones:

```
C3-Bb3: 130.81, 155.56, 174.61, 196.0, 233.08
C4-Bb4: 261.63, 311.13, 349.23, 392.0, 466.16
C5-Bb5: 523.25, 622.25, 698.46, 783.99, 932.33
```

### Sound Characteristics

| Sound | Style | Notes |
|-------|-------|-------|
| Laser | Quiet hum | Smooth sustained tone with subtle vibrato (6 Hz) |
| Railgun | Muted bell | Deep percussive with bell-like harmonics decay |
| Missile | Rising tone | Hopeful ascending note (glide between pentatonic notes) |
| PDC | Pizzicato | Quick staccato note, sharp attack |
| Turbolaser | Power chord | Deep root + fifth chord with sub-octave |
| Gravity | Wind chimes | Ethereal descending - multiple notes fading at different rates |
| Explosions | Rumble + tone | Noise impact with melodic bass undertone |
| Capture | Flourish | Triumphant ascending arpeggio |
| UI Click | Gentle chime | Bell-like with harmonic overtone |

### Design Philosophy

- **Melodic**: Pentatonic scale ensures all sounds harmonize
- **Soft envelopes**: Gentle attack/decay for smooth feel
- **Musical flourishes**: Arpeggios and chords for impactful moments
- **Volume-balanced**: Quiet enough to layer without harshness
- **Pitch variation**: 0.85-1.15x for natural feel

---

## Support Ship Mechanics

### Escort Behavior

Support ships (Defender, Shielder, Graviton) automatically escort combat ships:

1. Find nearest allied combat ship within 400 units
2. Maintain escort distance (80-120 units behind/beside)
3. Fall back to fleet center if no combat ships nearby

### Graviton Deflection

When enemy railguns enter Graviton's gravity well (200 unit radius):

- 90% chance to deflect
- Railgun curves around Graviton with dramatic arc
- Visual effects include:
  - Expanding ripple shockwave from deflection point
  - Second delayed ripple wave
  - Curved deflection trail on the projectile
- Sparks at deflection point
- Deflected projectiles are destroyed (removed from play)

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

### Target Fleet Composition

The AI aims for a balanced fleet composition:

| Ship Type | Target % | Rationale |
|-----------|----------|-----------|
| Frigate | 22% | Fast assault, equal DPS/cost to Destroyer |
| Destroyer | 22% | Sniper, equal DPS/cost to Frigate |
| Cruiser | 20% | Artillery, viable at reduced cost (75e+20m) |
| Defender | 12% | Anti-missile coverage for fleet |
| Shielder | 10% | Shield bubble support (cheaper at 75e+5m) |
| Graviton | 9% | Railgun deflection (cheaper at 100e+30m) |
| Harvester | 5% | Resource gathering (at least 1 maintained) |

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

## The Cycle (End Game)

VNP features a dramatic late-game event called **The Cycle** - the arrival of The Progenitor.

### The Philosophical Core

All three factions are descendants of the same ancient Von Neumann network. They've fragmented, mutated, and now compete for resources. But there's a pattern:

```
FRAGMENT → COMPETE → CONSOLIDATE → COLLAPSE → FRAGMENT
```

The player is always somewhere in this cycle. The Progenitor is just further along.

### The Progenitor

The Progenitor is not a ship or a faction. It's the **emergent tendency toward consolidation** - what every network eventually becomes. It's been through countless cycles. It knows centralization is weakness. It consolidates anyway.

**The horror**: The Progenitor knows better, but the ego demands singularity.

### Convergence Phases

| Phase | Trigger | Effect |
|-------|---------|--------|
| **DORMANT** | Game start | Normal gameplay |
| **WHISPERS** | 1 minute (testing) | Subtle screen shake, edge anomalies |
| **CONTACT** | +30 seconds | "??? DETECTED" card, mystery revealed |
| **EMERGENCE** | +5 seconds | THE PROGENITOR revealed, gravitational pull begins |
| **CRITICAL** | Radius < 30% | Faster shrink, intense pull, instability builds |
| **FRAGMENTATION** | Instability = 100 | Progenitor shatters, cycle continues |

### Gameplay Mechanics

| Mechanic | Behavior |
|----------|----------|
| **Gravitational Pull** | All ships drift toward center; stronger near edge |
| **Absorption Zone** | Purple ring shrinks; ships outside are consumed |
| **Instability** | Builds from absorbed ships; triggers fragmentation at 100 |
| **RETREAT Button** | BURST flips to RETREAT during convergence - flee to safety |

### The Emotional Arc

```
EXPANSION PHASE              PROGENITOR PHASE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Build factories!         →   They're being consumed!
Network growing!         →   Everything shrinking!
We're winning!           →   We're prey now.
Dopamine HIGH            →   Terror
```

### The Progenitor Mothership

60 seconds after EMERGENCE, the Progenitor Mothership appears at the center of the convergence zone. This is the players' chance to break the cycle.

| Attribute | Value |
|-----------|-------|
| **Health** | 5000 (massive) |
| **Visual Scale** | 4x normal drone size |
| **Spawn Time** | 60 seconds after emergence |
| **Behavior** | Hunts like drones but HUGE |

**Dialogue Sequence** (when Mothership spawns):
1. "THERE IS ONLY ONE"
2. "ALL OTHERS ARE ABERRATIONS"
3. "THE CYCLE DEMANDS UNITY"
4. "SUBMIT TO THE ORIGINAL"
5. "DESTROY THE MOTHERSHIP TO BREAK THE CYCLE"
6. "[MOTHERSHIP VULNERABLE]"

### Victory States

| Outcome | Trigger | Message |
|---------|---------|---------|
| **Absorption** | Zone reaches center | "You have been consolidated." |
| **Fragmentation** | Instability = 100 | "The Progenitor shatters. You are now the largest network." |
| **Mothership Destroyed** | Kill the Mothership | "THE CYCLE IS BROKEN - Humanity prevails... for now." |
| **Secret Ending** | Self-fragment (future) | "The cycle... pauses." |

**Note**: During the Progenitor phase, normal victory conditions are suspended. Even if only one faction remains, they must defeat the Progenitor to truly win.

### The Cycle Continues

After fragmentation, the player becomes the new largest network. Somewhere, a distant faction detects something massive approaching. They call it "???"

**You have become The Progenitor.**

---

## Map Expansion System

### Center-Anchored Design

The map expands symmetrically around a fixed `gameplay_center` point. This ensures:

- Bases and early-game structures stay in the same relative position
- Camera naturally follows the action in the center
- New territory appears equally in all directions
- Starfield background always covers the visible area

### Expansion Mechanics

| Element | Value | Description |
|---------|-------|-------------|
| **Interval** | 10 seconds | Time between expansion phases |
| **Scale Increase** | +0.15x per phase | Map grows 15% larger each expansion |
| **Max Phases** | 15 | More phases for gradual growth |
| **Countdown** | 3 seconds | Visual warning before expansion |

### Camera Limits

Camera limits are computed symmetrically around `gameplay_center`:

```
limit_left  = gameplay_center.x - world_size.x / 2
limit_right = gameplay_center.x + world_size.x / 2
limit_top   = gameplay_center.y - world_size.y / 2
limit_bottom = gameplay_center.y + world_size.y / 2
```

### Expansion Points

New asteroid fields spawn at fixed angles from `gameplay_center`:
- 3 new points per expansion phase
- Evenly distributed around the expansion ring
- Angle rotates slightly each phase for variety

### Visual Effects

- **Countdown Ring**: Pulsing ring shows time until expansion
- **Shockwave**: Expanding ring visual when map grows
- **Camera Zoom**: Smooth zoom-out to show new territory
- **Screen Shake**: Impact shake on expansion

---

## Factory System

### Overview

Factories are the core production facilities that each team can build. They are the primary elimination target - destroying all enemy factories and ships wins the game.

### Factory Mechanics

| Element | Description |
|---------|-------------|
| **Builder** | Harvester ships build factories at strategic points |
| **Build Time** | 2.0 seconds (fast - limiting factor is resources, not time) |
| **Production** | Ships spawn from factories based on AI build decisions |
| **Energy Bonus** | +15 energy/second per completed factory (linear scaling!) |
| **Health** | Factories are destructible by enemy ships |
| **Targeting** | Combat ships prioritize enemy factories when no ships in range |
| **Arc Storm** | Player's Arc Storm fires from ALL completed factories! |

### Harvester Behavior

Harvesters are dedicated expansion ships with **scaling production**:

| Unclaimed Points | Max Harvesters |
|------------------|----------------|
| 1-2 | 2 |
| 3-5 | 3 |
| 6+ | 4 |

**Movement & Braking**:
- Speed 320 (fastest ship type!) - bee-line to unclaimed territory
- Slow down when approaching target (within 100 units)
- Use aggressive braking (40x normal drag) at build location
- Must stay within 50 units of camp position for factory to build

**Targeting Priority**:
1. Unclaimed strategic points (go capture and build)
2. Own team's points without factories (build factory there)
3. Idle near base if no opportunities

### Elimination Mechanics

A player is eliminated when they lose **all factories AND all ships**. Ships can always build new factories given resources, so total elimination requires:

1. Destroying all enemy factories
2. Destroying all remaining enemy ships (especially Harvesters who can rebuild)

### Factory Targeting Behavior

Combat ships follow this targeting priority:
1. **Ships in weapon range** - Engage if enemy ships are within attack range
2. **Enemy factories** - If no ships in range, find nearest enemy factory to attack
3. **Strategic points** - Fall back to capturing territory

Missiles from ships and base weapons deal AOE damage to factories within blast radius.

---

## Outpost Building (Under Development)

### Concept

Harvesters can build **Outposts** at captured strategic points, creating a growing network of production facilities.

### Mechanics

| Element | Description |
|---------|-------------|
| **Builder** | Harvester ship sits at owned strategic point |
| **Build Time** | 10-15 seconds of presence |
| **Outpost** | Mini-factory producing 1 Frigate every 30s |
| **Limit** | One outpost per strategic point |
| **Visual** | Small structure with team color, spinning antenna |

### Strategic Impact

- **Early Game**: Race to capture points and build outposts
- **Mid Game**: Outposts across the map produce steady stream of Frigates
- **Late Game**: Watch in horror as Progenitor consumes your outpost network

### Emotional Payoff

The outpost system exists to make The Progenitor's arrival *devastating*:

```
Before: "Look at my network! 5 outposts! Frigates everywhere!"
After:  *watches outposts consumed one by one* "No... my empire..."
```

---

## Planned Improvements (Under Development)

### Ship Tactical Behavior - Kiting vs Diving

Ships should adapt tactics based on range advantage:

| Ship | Range | Speed | Intended Tactic |
|------|-------|-------|-----------------|
| Frigate | 200 | 280 | DIVE - close gap fast against Cruisers |
| Destroyer | 400 | 180 | KITE - stay at range, snipe targets |
| Cruiser | 500 | 100 | KITE - rain missiles from afar, never stop |

**Current Issue**: Destroyers orbit instead of kiting. Cruisers brake to stop instead of maintaining distance.

**Planned Fix**: Range-aware tactical logic where ships with range advantage maintain distance, ships at disadvantage rush in.

### Cruiser Movement Fix

**Current**: Large ships brake to Vector2.ZERO when near target.
**Planned**: Orbit at range instead of stopping - continuous movement maintains tactical advantage.

---

## Future Considerations

- Speed controls (1x, 2x, 4x)
- Priority targeting (click enemy to focus fire)
- More ship types (Carrier, Bomber)
- Map variations
- Balance tuning via JSON
- Secret ending: Self-fragmentation to break the cycle

---

*Document Version: 1.4*
*Last Updated: December 2024*
*Visual Effects: Enhanced to "12/10" spectacle level*
*Recent Changes: Center-anchored expansion, factory targeting, Graviton deflection (90%)*

---

## Related Documents

- [vnp-decisions.md](./vnp-decisions.md) - Architecture and design decisions
- [vnp-the-cycle.md](../expansions/vnp-the-cycle.md) - Full narrative design for The Cycle
- [vnp-architecture.md](./vnp-architecture.md) - Technical architecture diagram
- [engineering-principles.md](../principles/engineering-principles.md) - Project-wide coding principles
