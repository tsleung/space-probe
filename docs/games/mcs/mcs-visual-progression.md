# MCS Visual Progression System

## Overview

The Mars Colony Sim features a **visual storytelling system** where the colony's appearance evolves from desperate survival outpost to thriving shielded city. The intent is to create a **hopeful, inspiring** visual experience - a celebration of humanity rising above the Martian elements.

**Recent Update (Dec 2024):** Added Frostpunk-inspired 2.5D isometric system with Stage 1 tunnel visuals.

---

## Isometric Camera System (NEW)

### Projection
- **ISO_ANGLE = 0.5** - Y-axis squash for classic 2.5D isometric look
- All drawing uses `_transform_point()` for consistent projection
- Camera centered on colony (WORLD_CENTER = 256, 256)

### Camera Rotation
- **4 cardinal directions** (0, 90, 180, 270 degrees)
- **Q key**: Rotate left (counter-clockwise)
- **E key**: Rotate right (clockwise)
- Smooth animated transitions (ROTATION_SPEED = 4.0 rad/sec)

### Depth Sorting
- Painter's algorithm for proper isometric layering
- Buildings sorted by rotated Y position

---

## Stage 1: Tunnel Visuals (NEW)

**Identity:** "Desperate but hopeful pioneers carving out a foothold"

When visual_tier <= 1, the colony shows underground infrastructure:

### 1. LIFEPOD Core (Central Hub)
- Hexagonal base at world center with solar tower
- State-based glow colors based on stability:
  - **Thriving** (75+%): Bright blue
  - **Stable** (50-74%): Dimmer blue
  - **Stressed** (25-49%): Pale blue/white
  - **Crisis** (<25%): Red alert
- Efficiency zone rings radiating outward
- Beacon at tower apex with pulsing animation
- Night window lights and steam vent effects

### 2. Tunnel Entrance Airlocks
- Hexagonal frame with colored inner hatch (by building type)
- Warm underground glow visible through hatch
- Green status lights for operational buildings
- Blinking red warning for broken buildings
- Scaffolding effect for under-construction

### 3. Exposed Pipe Network
- Colored pipes connecting buildings to LIFEPOD Core:
  - **Water**: Blue
  - **Oxygen**: White
  - **Power**: Yellow
  - **Heat**: Red
- Curved routing with shadow/highlight for depth
- Animated flow markers on active pipes

### 4. Underground Cutaway
- Visible hab modules below surface
- Dark interior with connecting tunnels to core
- Warm window glow showing life below
- Shaft connections from airlock to underground hab

### 5. Dust Accumulation System
- Dust collects on buildings over time (faster during sandstorms)
- Robots automatically clean dustiest buildings
- Visual dust patches around airlocks
- Cleaning animation with sweep effect

---

## Core Concept: Advancement Score

A single `advancement` score (0.0 - 1.0) drives all visual progression:

```
advancement = (buildings * 0.40) + (year * 0.20) + (population * 0.20) + (stability * 0.10) + (resources * 0.10)
```

**Buildings dominate** (40%) because construction is the hero visual - humanity literally building mastery over Mars.

### Tier Thresholds (7 EPIC Tiers!)

| Tier | Advancement | Name | Theme | New Structures |
|------|-------------|------|-------|----------------|
| 0 | 0.00 - 0.08 | **Survival** | Desperate, exposed, constant threats | LIFEPOD Core, airlocks |
| 1 | 0.08 - 0.18 | **Bunkers** | Underground, fortified but vulnerable | Tunnels, pipes |
| 2 | 0.18 - 0.32 | **Outpost** | Organized, defended, hopeful | Perimeter walls, tubes |
| 3 | 0.32 - 0.50 | **Settlement** | Protected under hex domes | Hex domes, gardens |
| 4 | 0.50 - 0.70 | **Metropolis** | Rising towers, highways | Skyscrapers, superhighways |
| 5 | 0.70 - 0.88 | **Megacity** | Sci-fi city of the future | Space elevator, arcologies, terraforming towers |
| 6 | 0.88 - 1.00 | **Transcendence** | Beyond Earth, interplanetary hub | Orbital ring, launch loop, aurora effects |

---

## Visual Systems

### 1. Building Evolution

Buildings scale, brighten, and gain effects as advancement increases:

| Property | Tier 0 | Tier 4 |
|----------|--------|--------|
| Scale | 0.7x | 1.2x |
| Brightness | 30% | 100% |
| Effects | Flicker, scratches, dust | Glow, pristine highlight |

**Low Tier Effects:**
- Flicker animation (time-based sine wave)
- Deterministic scratch patterns
- Dust accumulation overlay
- Uneven edges

**High Tier Effects:**
- Pulsing glow outline
- Pristine white highlight bar
- Connected infrastructure

### 2. Hex Dome System

Domes appear at Tier 3+, providing dramatic visual protection.

**Implementation:**
- Building clusters detected (buildings within 80px grouped)
- Hexagonal grid drawn over each cluster
- Translucent cyan fill (alpha 0.08-0.15)
- Brighter hex edges (alpha 0.25)
- Animated shimmer wave traveling across dome

**Storm Interaction:**
- Dust particles check distance to dome center
- Particles hitting dome edge get `deflected = true`
- Deflected particles change trajectory (tangent to dome)
- Impact triggers ripple effect (expanding ring)
- Dome glow intensifies during storms

### 3. Storm System

Storm frequency and intensity decrease with advancement:

| Property | Tier 0 | Tier 4 |
|----------|--------|--------|
| Chance per year | 40% | 3% |
| Intensity | 1.0 | 0.15 |
| Particle count | 100 | 20 |
| Message | "⚠ SANDSTORM" | "◈ SHIELDS ACTIVE" |

**Storm Progression:**
- Tier 0-1: Full assault, buildings shake
- Tier 2: Walls block 50% of dust
- Tier 3-4: Domes deflect particles with ripple effects

### 4. Robot Evolution

Robots evolve from slow clunky workers to fast drone swarms:

| Property | Tier 0 | Tier 4 |
|----------|--------|--------|
| Count | 3 | 50 |
| Speed | 15 px/s | 120 px/s |
| Size | 8 px | 3 px |
| Style | Square + antenna | Round + glow |
| Behavior | Individual | Swarm groups of 5 |

**Swarm Mode (Tier 3+):**
- Robots assigned to groups
- Group leader moves to target
- Others follow with offset
- Bobbing hover animation at Tier 4
- Activity cloud sparkles around buildings

### 5. Colonist Behavior

Colonists become more visible and relaxed at higher tiers:

| Property | Tier 0 | Tier 4 |
|----------|--------|--------|
| Visibility | 30% | 95% |
| Speed | 45 px/s (scurrying) | 20 px/s (strolling) |
| Location | Near buildings only | Anywhere, plaza gatherings |
| Storm response | Hide immediately | Unaffected |

**Social Features (Tier 4):**
- Children have bouncing play indicators
- Social gathering circles when 3+ colonists near cluster
- Conversation bubble animations

### 6. Infrastructure Evolution

| Tier | Elements |
|------|----------|
| 0 | Raw Mars terrain |
| 1 | Connecting tubes between buildings |
| 2 | Perimeter wall, gates, watch towers |
| 3 | Hex domes, gardens, paths |
| 4 | Plazas, fountains, full shield grid |

---

## File Structure

```
scripts/mars_colony_sim/mcs_view.gd
├── Constants (colors, sizes)
├── State
│   ├── Building/colonist data
│   ├── Visual progression state
│   │   ├── _advancement (0.0-1.0)
│   │   ├── _visual_tier (0-4)
│   │   ├── _building_clusters
│   │   ├── _dome_ripples
│   │   └── _building_flicker/_damage
│   └── Effect state (storms, robots, particles)
├── Lifecycle (_ready, _process, _draw)
├── Visual Progression System
│   ├── _calculate_advancement()
│   ├── _calculate_building_clusters()
│   └── _calculate_infrastructure()
├── Drawing (layer order)
│   ├── _draw_mars_surface()
│   ├── _draw_ground_evolution()
│   ├── _draw_grid()
│   ├── _draw_sandstorm_back()
│   ├── _draw_buildings()
│   ├── _draw_hex_domes()
│   ├── _draw_work_particles()
│   ├── _draw_robots()
│   ├── _draw_colonists()
│   ├── _draw_rescue_lines()
│   ├── _draw_sandstorm_front()
│   ├── _draw_dust_particles()
│   ├── _draw_crisis_indicators()
│   └── _draw_stats_overlay()
├── Building Rendering
│   ├── _draw_building_damage()
│   ├── _draw_connecting_tubes()
│   ├── _draw_perimeter_wall()
│   └── _draw_infrastructure_elements()
├── Hex Dome System
│   ├── _draw_hex_domes()
│   ├── _draw_hex_dome()
│   ├── _draw_hex_cell()
│   ├── _draw_dome_shimmer()
│   └── _update_dome_ripples()
├── Ground Evolution
│   ├── _draw_paths()
│   ├── _draw_gardens()
│   └── _draw_city_features()
├── Robot System
│   ├── _init_robots()
│   ├── _get_robot_params()
│   ├── _update_robot_movement()
│   ├── _assign_swarm_groups()
│   └── _draw_robots()
├── Storm System
│   ├── _init_sandstorm_particles()
│   ├── _update_sandstorm()
│   ├── _draw_sandstorm_back/front()
│   └── Storm-dome interaction
└── Public API
    ├── get_advancement()
    ├── get_visual_tier()
    ├── start_sandstorm()
    ├── add_dome_ripple()
    └── set_robot_count()
```

---

## Performance Considerations

### Optimizations Applied

1. **No RNG in draw loops** - All randomness uses cached values or deterministic hash-based pseudo-random
2. **Cached terrain** - Mars surface craters computed once at `_ready()`
3. **Deterministic visuals** - Scratches, gardens use hash-based positioning
4. **Lazy cluster calculation** - Only recalculated when buildings change

### Draw Order Efficiency

Layers drawn back-to-front to minimize overdraw:
1. Background (solid fill)
2. Ground features (paths, gardens)
3. Grid (thin lines)
4. Storm back layer (tint)
5. Buildings (main elements)
6. Domes (translucent overlay)
7. Particles and effects
8. UI overlays

---

## Balance Parameters

All visual parameters stored in `data/games/mars_colony_sim/balance.json`:

```json
"visual_progression": {
  "advancement_weights": { "buildings": 0.40, ... },
  "tier_thresholds": [0.0, 0.15, 0.35, 0.55, 0.80],
  "storm": { "chance_range": [0.40, 0.03], ... },
  "robots": { "count_range": [3, 50], ... },
  "buildings": { "scale_range": [0.7, 1.2], ... },
  "colonists": { "visibility_range": [0.3, 0.95], ... },
  "dome": { "tier_threshold": 3, "hex_size": 18, ... }
}
```

---

## Continuous Time System

The simulation now runs in **continuous real-time** with time scaling, rather than discrete year jumps:

### Time Flow
- Time flows continuously at a configurable rate (default: 30 days/second)
- UI displays "Year X, Day Y" showing smooth progression
- Stats overlay shows current day within the year (Day N/365)
- Year transitions trigger game logic (events, AI decisions, births/deaths)

### Time Scale Controls
- 1x speed: ~24 seconds per year (slow, detailed observation)
- 2x speed: ~12 seconds per year (default)
- 5x speed: ~5 seconds per year (fast forward)
- 10x speed: ~2.4 seconds per year (rapid progression)

### Smooth Transitions
- **Colonist Fade-In**: New colonists (births) fade in over 0.5 seconds
- **Colonist Fade-Out**: Deceased colonists fade out smoothly
- **Position Preservation**: Colonist positions persist across year transitions
- **Robot Movement**: Continuous, not reset on year change

---

## Epic Megastructures (Tier 4+)

### Skyscrapers (Tier 4+)
- Towering buildings rising from apartments, factories, research centers
- Height scales with advancement (80-250px)
- 3D perspective with left/right face shading
- Window grid with night lighting (66% lit)
- Rooftop spires with blinking aircraft warning lights
- Multiple color variants (blue steel, silver, cyan, purple)

### Superhighways (Tier 4+)
- Elevated curved highways connecting building clusters
- Support pillars at regular intervals
- Bezier curve routing with perspective
- Vehicle traffic (headlights/taillights)
- Edge lights pulsing at night

### Space Elevator (Tier 5+) - THE CENTERPIECE
- Triple-cable tether reaching to sky
- Energy pulses traveling up cables
- Animated wave motion on cables
- Hexagonal base platform with glow ring
- Elevator car ascending/descending
- Thruster glow effects
- Counterweight visible at top

### Arcology Domes (Tier 5+)
- Massive hemispherical domes over building clusters
- Multiple horizontal rings creating 3D effect
- Translucent cyan fill
- Apex light with pulsing animation

### Atmospheric Processors (Tier 5+)
- Terraforming towers at colony edges
- Tapered tower body with processing rings
- Rising vapor plumes with particle animation
- Status indicator lights

### Orbital Ring (Tier 6)
- Ring visible in sky (screen space)
- Rotating around planet with stations
- Depth-based alpha (back dimmer)
- 5 orbital stations with blinking lights

### Launch Loop (Tier 6)
- Electromagnetic launcher arc
- Bezier curve track with energy glow
- Launch pods traveling along track
- Thruster trail effects

### Aurora Effects (Tier 4+ at night)
- Multi-colored wave patterns in sky
- 5 overlapping waves with different speeds
- Intensity increases with tier
- Colors: green, blue, purple, red

### City Glow & Neon (Tier 5+ at night)
- Warm city glow emanating from clusters
- Cyberpunk neon outlines on buildings
- Pulsing neon accents (cyan, magenta, orange, lime)

---

## AI Spectate Mode (Enhanced)

The AI now builds aggressively for faster visual progression:

- **85% chance** to build each year (was 30%)
- **1-4 buildings per year** instead of just 1
- More diverse building selection including late-game structures
- Expanded building priority system

### Faster Progression Settings
- Double starting colonists (24 vs 12)
- Quadruple starting resources
- Higher fertility rate (8% vs 2.5%)
- Lower tier thresholds for faster transitions

---

## Future Enhancements

- [x] Day/night cycle affecting lighting
- [x] Building shape variants (towers, domes, reactors, etc.)
- [x] Force field dome effect
- [x] Energy network visualization
- [x] Orbital elements (satellites, space station, orbital ring)
- [x] Atmospheric effects (aurora, meteors)
- [x] Mars sky with moons (Phobos, Deimos)
- [ ] Construction animations when buildings placed
- [ ] Tech tree unlocking visual upgrades
- [ ] Family tree viewer showing generation spread
- [ ] Sound design for dome impacts, storms, etc.
- [ ] Particle pooling for very large colonies

---

## Crater Terrain System (NEW - Dec 2025)

### Concept
Replace flat isometric ground with a **crater bowl** - colony built inside a protective Martian crater.

### Visual Elements
```
         ___________
       /             \      <- Raised rim (shadow on inner side)
      /               \
     |    COLONY      |     <- Central flat building zone
     |   [buildings]  |
      \               /
       \_____________/      <- Sloped walls
```

### Implementation
1. **Crater Rim**: Elevated ring around map edges with dramatic shadows
2. **Interior Slopes**: Gentle gradient from rim to center
3. **Central Plateau**: Flat buildable area
4. **Rim Features**:
   - Watch towers on rim edge
   - Observation posts looking outward
   - Canyon views on one side (optional)

### Crater Types by Location
| Location | Visual | Gameplay Bonus |
|----------|--------|----------------|
| Hellas Planitia | Deep crater, dramatic walls | Resource bonus |
| Olympus Mons Base | Volcanic, lava tubes visible | Geothermal power |
| Valles Marineris Edge | One wall is canyon cliff | Tourism bonus |
| Polar Region | Ice visible in crater walls | Water bonus |

---

## Terraforming Visual Progression (NEW - Dec 2025)

### Five Stages of Mars Transformation

Based on scientific research from NASA, Breakthrough Institute, and the Terraforming Mars board game.

#### Stage 0: BARREN (Default)
```
Sky:    Rust/brown gradient (#B87333 -> #5C3317)
Ground: Red/orange rock, dust
Effects: Frequent sandstorms, dust devils
```

#### Stage 1: WARMING
```
Sky:    Pink haze (#D4A5A5 -> #8B4C4C)
Ground: Darker red, ice melt pools visible
Effects: Mist rising from ice pools, reduced storms
Trigger: 50+ years OR terraforming towers built
```

#### Stage 2: WET
```
Sky:    Orange-pink (#E8B89D -> #A67B5B)
Ground: Brown/mud, small lakes forming
Effects: Dry river channels filling, occasional rain
Trigger: 100+ years OR 5+ terraforming structures
```

#### Stage 3: LIVING
```
Sky:    Blue-pink (#C9D6E3 -> #8BA3B9)
Ground: Green patches spreading from greenhouses
Effects: Lichen on rocks, hardy plants, clouds forming
Trigger: 200+ years OR advanced bioengineering
```

#### Stage 4: BREATHABLE
```
Sky:    Blue (#87CEEB -> #4A90B8)
Ground: Green continents, blue lakes/oceans
Effects: Trees, rain, wildlife, Earth-like weather
Trigger: 500+ years OR transcendence tier
```

### Visual Implementation
Each stage affects:
- `_draw_sky()`: Gradient colors shift
- `_draw_ground()`: Terrain palette changes
- `_draw_dust()`: Particle density decreases
- New elements unlock (lakes, plants, clouds)

### Terraforming Score Calculation
```gdscript
var terraforming_score = (
    years * 0.001 +
    terraforming_buildings * 0.1 +
    greenhouse_coverage * 0.2 +
    water_coverage * 0.3
)
var stage = int(clamp(terraforming_score / 0.25, 0, 4))
```

---

## Building Shape System (Implemented Dec 2025)

### Shape Types (11 Total)

| Shape | Visual | Buildings |
|-------|--------|-----------|
| HEX_PRISM | Classic hexagonal prism | Hab pods, medical bays, water extractors |
| TOWER | Rectangular with windows, antenna | Apartments, factories, hospitals, storage |
| DOME | Hemispherical with rings | Labs, recreation centers, temples |
| ARCOLOGY | Multi-level city under mega-dome | Research centers, luxury quarters |
| GREENHOUSE | Glass triangular panels, plants visible | Greenhouses, hydroponics, protein vats |
| SOLAR_ARRAY | Flat angled panels with sun glint | Solar arrays, wind turbines |
| REACTOR | Containment + cooling towers, glowing core | Fission reactor, RTG |
| TERRAFORMING_TOWER | Tapered tower with vapor plume | CO2 scrubbers, oxygenators |
| LANDING_PAD | Flat pad with rocket/ship | Landing pads, airlocks |
| COMMS_TOWER | Lattice tower with satellite dish | Communications |
| SPACE_ELEVATOR | Triple cables with energy pulses | Space elevator (future) |

### Shape Drawing Functions
Each shape has dedicated drawing function with:
- Unique geometry
- Animated effects (blinking lights, energy pulses, steam)
- Construction progress support
- Operational/broken state visuals

---

## New Megastructures (Dec 2025)

### Implemented
| Structure | Tier | Visual |
|-----------|------|--------|
| Space Elevator | 5+ | Triple cables, energy pulses, counterweight |
| Orbital Ring | 6 | Visible in sky with energy nodes |
| Force Field | 4+ | Hexagonal energy dome over colony |

### Planned Implementation
| Structure | Tier | Visual Description |
|-----------|------|-------------------|
| Mass Driver | 4 | Electromagnetic rail, glowing coils, projectile launch |
| Fusion Reactor | 4 | Tokamak ring, plasma core visible, magnetic containment |
| Orbital Mirror | 5 | Giant reflector in sky, light beam to surface |
| Launch Loop | 6 | 2000km curved track rising to 80km altitude |
| Dyson Swarm Start | 6 | Visible collectors around sun, energy beams down |
| Shkadov Thruster | 7 | Giant solar sail near sun (post-game) |

---

## Sky vs Ground Visual Elements (IMPORTANT)

**All visual elements MUST be clearly categorized as SKY or GROUND to prevent rendering bugs.**

### SKY ELEMENTS (Above Horizon - Screen Y < 50%)
These elements float in the atmosphere or orbit:

| Element | Function | Trigger |
|---------|----------|---------|
| **Phobos/Deimos** | Moons orbiting | Always |
| **Stars** | Background twinkle | Always (hidden in storms) |
| **Satellites** | Small orbiting dots | Colony tier 2+ |
| **Orbital Ships** | Freighters, liners orbiting | STARPORT built |
| **Landing Ships** | Shuttles descending/ascending | STARPORT built |
| **Orbital Station** | Large rotating station | ORBITAL building |
| **Asteroid Catcher** | Net catching rocks | CATCHER building |
| **Skyhook** | Rotating tether | SKYHOOK building |
| **Starport Ships** | Ships with engine flames | STARPORT building |
| **Mass Driver Projectile** | Launched cargo | MASS_DRIVER building |
| **Orbital Ring** | Ring around planet | Transcendence tier |
| **Aurora** | Green/blue curtains | Rare atmospheric event |
| **Meteors** | Shooting stars | Periodic |

### GROUND ELEMENTS (Below Horizon - Screen Y > 50%)
These elements are on or near the Martian surface:

| Element | Function | Trigger |
|---------|----------|---------|
| **Buildings** | Colony structures | Construction |
| **Colonists** | Walking people | Population |
| **Drones/Robots** | Cleaning, working | Always |
| **Transit System** | Monorail between buildings | 20+ buildings, ground-only |
| **Rim Lighting** | Sun-edge highlights | On buildings |
| **Dome Glow** | Interior warmth | On dome buildings |
| **Greenhouse Plants** | Visible inside glass | Greenhouse buildings |
| **Dust Particles** | Mars dust | Surface level |
| **Energy Network** | Power beams | Power buildings |
| **Force Field** | Hex dome | Tier 4+ |
| **City Spotlights** | Vertical light beams | Tall buildings |

### Implementation Rules
1. **SKY elements** use screen-space coordinates relative to `size.y * 0.15` (sky center)
2. **GROUND elements** must pass `screen_pos.y >= size.y * 0.5` check before drawing
3. **Transit system** has explicit ground boundary check to prevent sky rendering
4. **Landing ships** are allowed to transition through boundary (landing/takeoff animation)

---

## Atmospheric & Orbital Effects (Implemented Dec 2025)

### Sky System
- **Gradient sky**: Rust horizon to dark zenith
- **Phobos**: Fast-moving small moon
- **Deimos**: Slow-moving tiny moon
- **Stars**: Twinkling (hidden during sandstorms)

### Orbital Elements (Tier-Based)
| Tier | Elements Visible |
|------|-----------------|
| Survival | Just sky and moons |
| Growth | 3 orbiting satellites |
| Society | 6 satellites |
| Independence | Space station orbiting |
| Transcendence | Full orbital ring with 8 energy nodes |

### Atmospheric Effects
- **Aurora**: Rare green/blue curtains when sin(time) > 0.9
- **Meteors**: Streaking across sky every 15 seconds
- **Energy beams**: From power buildings to central hub

### Force Field Dome
- Hexagonal grid shimmer
- Impact flickers from micro-meteorites
- Activated via `activate_force_field(strength)`

---

## Implementation Status (Dec 2025)

### Complete
- [x] 11 building shape types
- [x] Sky gradient with moons
- [x] Orbital satellites (tier-based)
- [x] Space station (independence+)
- [x] Orbital ring (transcendence)
- [x] Force field dome
- [x] Energy network visualization
- [x] Aurora effect
- [x] Meteor showers
- [x] All building shape functions

### In Progress
- [ ] Crater terrain (replacing flat ground)
- [ ] Terraforming stage progression
- [ ] Mass driver structure
- [ ] Fusion reactor structure

### Backlog
- [ ] Conveyor belts between buildings
- [ ] Drone swarm logistics
- [ ] Visible resource stockpiles
- [ ] Periodic rocket launches
- [ ] Clouds (later terraforming)
- [ ] Rain effects (late terraforming)
- [ ] Building upgrade tiers (visual evolution)

---

## References

Full research documentation: `docs/research/mcs-visual-spectacle-research.md`

### Sources
- [Wikipedia: Megastructure](https://en.wikipedia.org/wiki/Megastructure)
- [NASA: Terraforming the Martian Atmosphere](https://mars.nasa.gov/resources/21974/terraforming-the-martian-atmosphere/)
- [Terraforming Mars Board Game](https://www.ultraboardgames.com/terraforming-mars/game-rules.php)
- [Dyson Sphere Program](https://screenrant.com/sci-fi-video-games-dyson-sphere-program-megastructures/)
- [Mars Colony Concepts](https://interestingengineering.com/science/what-would-a-martian-colony-look-like/)
