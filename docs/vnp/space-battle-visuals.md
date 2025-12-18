# Space Battle Visual Design Research

Research on what makes space battles visually spectacular, based on analysis of The Expanse, Sins of a Solar Empire, Supreme Commander, Gratuitous Space Battles, Elite Dangerous, and Everspace 2.

## Key Principles

### 1. Scale Creates Drama
- **Hundreds of ships** on screen simultaneously (Sins of a Solar Empire)
- Strategic zoom from single fighter to entire system view
- "Bigger explosions = bigger emotional stakes" (visual shorthand for importance)

### 2. Visible Projectiles and Weapons
- **Projectiles must be large and bright** - "spinning-pulsating disk that is larger and far more visible"
- **Beam-lasers should be "10x as beamy"** (Gratuitous Space Battles 2)
- Different weapon types need distinct visual signatures
- Tracer effects and trails make projectile paths readable

### 3. Impact and Hit Effects
- **Muzzle flash** when weapons fire creates "impact" and "power" feeling
- **Hit sparks/impacts** when damage lands - essential for feedback
- Screen shake on big hits reinforces weight
- Audio cues supplement visuals (though we're focused on visuals)

### 4. Explosions Must Be Gratuitous
- "Explosions 10x more gratuitous" is the goal
- Multiple particle types: fire, debris, sparks, shockwave
- Explosions should scale with ship size
- Debris particles from destroyed ships add realism

### 5. Physics Creates Tension (The Expanse)
- G-forces affecting ship maneuvers
- Attack salvos and countermeasures
- Newtonian physics for projectiles (homing missiles, ballistic guns)
- Ships drifting/sliding feels more cinematic than instant turns

### 6. Emergent Cinematic Moments
- Unscripted drama: "One minute you're weeping as enemy frigates wipe out your capital ship's shields, the next you're cheering as reinforcements arrive"
- Let chaos create memorable moments
- Don't over-script - let systems interact

### 7. Readability
- **Clear, identifiable ship designs** - distinct silhouettes per faction/type
- **Well-staged battlefield** - viewer understands spatial relationships
- Color coding for factions (team colors)
- UI elements for health/status at a glance

### 8. Lighting and Atmosphere
- "Super-clever lighting system and mega-parallax" for cinematic look
- Weapon fire should illuminate nearby ships
- Glow effects on energy weapons
- Dark space background makes bright effects pop

## Specific Implementation Guidelines

### Projectiles
- Size: 2-4x larger than you think they need to be
- Bright, saturated colors (yellow for guns, orange for missiles)
- Trail effects that fade over 0.3-0.5 seconds
- Pointed/arrow shapes read as "fast"

### Lasers/Beams
- Width: 8-15 pixels at peak
- Fade time: 0.1-0.2 seconds (quick pulse)
- Bright, high-saturation color (cyan, green, red)
- Consider adding secondary glow/bloom

### Explosions
- Particle count: 50-100+ for dramatic effect
- Multiple colors: orange core, yellow edges, white flash
- Debris particles in addition to fire
- Explosiveness: 0.9+ for instant burst
- Duration: 0.8-1.5 seconds

### Hit Effects
- Particle count: 20-40
- Short duration: 0.2-0.4 seconds
- High velocity outward burst
- Bright sparks (yellow/white)

### Engine Trails
- Team-colored for faction identification
- Particle count: 15-30
- Short lifetime: 0.3-0.5 seconds
- Intensity increases during acceleration

### Screen Shake
- Small ships: 5-10 intensity
- Medium ships: 15-25 intensity
- Large ships: 30-50 intensity
- Decay: fast (5-10 per second)
- Additive for multiple simultaneous deaths

## Reference Games

### The Expanse (TV Show)
- Realistic physics, PDC point-defense spraying
- Missile salvos with countermeasures
- High-G maneuvers with visible strain

### Sins of a Solar Empire
- Strategic zoom from fighter to system
- Hundreds of ships in combat
- Capital ships as centerpiece

### Supreme Commander
- Strategic zoom innovation
- Massive scale battles
- Projectiles visible across entire map

### Gratuitous Space Battles 2
- "Beam-lasers 10x as beamy"
- "Explosions 10x more gratuitous"
- Lighting and parallax for depth

### Elite Dangerous
- Punchy weapon feedback
- Boost and drift mechanics
- Asteroid field combat

### Everspace 2
- "Buttery smooth, weapons are punchy"
- Fast, kinetic, DOOM-like combat
- Flashy explosions with tactical depth

---

## VNP Implementation (Dec 2024)

### Weapon Systems - Unique Character

Each weapon type has distinct behavior, visuals, and tactical role:

#### Railgun (Frigates) - "Punch Through"
- **Behavior**: Piercing projectiles that continue through up to 3 enemies
- **Speed**: 1200 (ultra-fast, almost hitscan feel)
- **Visual**: Long thin slug shape - elongated polygon
- **Trail**: Thin 4px gradient trail with faction color
- **Impact**: Small spark burst on each pierce, projectile continues
- **Tactical**: Glass cannon, 200 range, rapid fire (4/sec), must close distance

#### Laser (Destroyers) - "Instant Precision"
- **Behavior**: Instant hit, no travel time, guaranteed damage
- **Visual**: Dual-layer beam effect
  - Core beam: 14px width, bright faction color
  - Glow beam: 24px width, 40% opacity outer glow
- **Animation**: Both beams fade over 0.25 seconds
- **Impact**: 1.5x scaled burn mark at target location
- **Tactical**: Sniper role, 400 range, slower fire (1.5/sec)

#### Missile (Cruisers) - "Arc and Explode"
- **Behavior**: Arcing bezier trajectory with homing, massive AOE
- **Arc System**: Quadratic bezier curve
  - Rises to 35% of distance at arc peak
  - Randomly arcs left or right for visual variety
  - Smoothly tracks moving targets throughout flight
- **Speed**: 300 (slow but inevitable)
- **Visual**: Chunky rocket shape with fins
- **Smoke Trail**: 40-particle GPUParticles2D
  - Bright orange exhaust -> gray smoke gradient
  - Particles rise slightly (gravity: -20)
  - 0.8 second lifetime, lingers behind missile path
- **Tactical**: Bombardment, 500 range, slow reload (0.8/sec)

### Missile Explosions - 5 Layers!

Missiles create spectacular multi-layered explosions:

1. **White Flash** (instant)
   - 30 particles, 0.15s lifetime
   - White-hot center burst, velocity 200-400

2. **Fire Burst** (expanding)
   - 60 particles, 0.4s lifetime
   - Orange core -> red edges, velocity 150-350, scale 3-6x

3. **Smoke Cloud** (lingering)
   - 40 particles, 1.2s lifetime
   - Brown -> gray, rises upward (gravity -30)
   - Velocity 50-120, scale 4-10x

4. **Debris/Sparks** (fast outward)
   - 25 particles, 0.6s lifetime
   - Yellow sparks, velocity 300-500

5. **Shockwave Ring** (expanding circle)
   - Line2D circle, 8px width
   - Scales from 1x to 15x over 0.4s
   - Fades out while thinning

- **Screen Shake**: 35 intensity
- **Area Damage**: 120 radius with distance falloff

### Ship Death Explosions

Scaled by ship size using GPUParticles2D (80 particles):

| Size | Ships | Shake | Scale |
|------|-------|-------|-------|
| Small | Frigate, Harvester | 10 | 2x |
| Medium | Destroyer | 25 | 3.5x |
| Large | Cruiser | 50 | 6x |

### Engine Trails

- 20 particles per ship via GPUParticles2D
- Team-colored with 30% lightening
- Emits backward from ship rear
- 0.4 second lifetime
- Position offset based on ship size class

### Muzzle Flash

- Triangle polygon at ship front
- Faction-specific weapon color (50% lightened)
- Fades to 0 alpha over 0.1 seconds
- Offset from ship bow based on size

### Faction Color Palettes

**Player (Blue Fleet)**
| Weapon | Color | Description |
|--------|-------|-------------|
| Railgun | `(0.7, 0.85, 1.0)` | Ice blue |
| Laser | `(0.2, 0.9, 1.0)` | Cyan beam |
| Missile | `(0.4, 0.7, 1.0)` | Blue trail |

**Enemy (Orange Fleet)**
| Weapon | Color | Description |
|--------|-------|-------------|
| Railgun | `(1.0, 0.9, 0.3)` | Yellow autocannon |
| Laser | `(0.5, 1.0, 0.3)` | Green plasma |
| Missile | `(1.0, 0.5, 0.2)` | Orange torpedo |

**Nemesis (Purple Fleet)**
| Weapon | Color | Description |
|--------|-------|-------------|
| Railgun | `(0.8, 0.3, 1.0)` | Purple pulse |
| Laser | `(0.6, 0.2, 0.9)` | Purple disruptor |
| Missile | `(0.9, 0.2, 0.8)` | Magenta antimatter |

### Base Weapons (Special Abilities)

Each faction has a unique superweapon on 15-second cooldown:

**Ion Cannon (Player)**
- Beam weapon damages all enemies in a line
- 1200 unit range, sweeping damage
- Dual beam visual (bright core + wide glow)
- 30 intensity screen shake

**Missile Barrage (Enemy)**
- Fires 8 homing missiles at various targets
- Staggered launch (0.1s delays between missiles)
- Each missile has full smoke trail
- 20 intensity screen shake

**Singularity (Nemesis)**
- Black hole effect centered on enemy cluster
- 100-particle purple vortex pulling inward (radial_accel: -200)
- 150 radius area damage with distance falloff
- Dark center polygon that collapses over 1.2s
- 40 intensity screen shake

### Planet Capture System

- Ships within 80 units capture planets for their team
- Team with most ships near planet wins control
- Captured planets:
  - Change to team color (Polygon2D)
  - Get colored ring (Line2D circle, 25 radius)
  - Generate +5 energy per tick
  - +100 energy capture bonus

### Background - Space Environment

**Starfield (3 layers)**
1. 200 small diamond stars (1-3px, 30-80% opacity)
2. 30 larger colored stars (2-5px)
   - Colors: blue-white, warm white, orange, cool blue
3. 5 nebula clouds (8-point irregular polygons)
   - Purple, blue, red/pink, teal variants
   - 10-15% opacity for subtle atmosphere

### Screen Shake System

- **Additive**: Multiple explosions stack intensity
- **Decay**: 8 per second via lerp
- **Threshold**: Stops at 0.1 intensity
- **Implementation**: Camera2D offset randomized each frame

### UI Elements

- Team status panels (ships, energy, planets)
- Base weapon cooldown bars with icons
- Victory overlay with animation
- Menu button (top bar)

---

## FCW Implementation Status

### ✅ Implemented (Battle View - Dec 2024)

**Ships:**
- Angular military hulls with forward/rear sections
- Blue engine glow with pulsing intensity
- PDC turret dots on hull
- Bridge/command section highlight
- Health bars under damaged ships
- Hull breach glows when damaged
- Smoke trails from damaged ships

**Herald (Alien) Ships:**
- Organic pulsing blob shapes (8-point irregular polygon)
- Inner pulsing core with multiple layers
- Energy tendrils that wave and curve
- Glowing weapon ports before firing

**Weapons - PDC:**
- Tracer LINES (not dots) - much more visible
- White/yellow for humans, red/orange for Herald
- Muzzle flash at firing point
- Very rapid fire rate (0.06s cooldown)
- 25% hit probability per burst

**Weapons - Torpedoes:**
- Homing missiles that track targets
- Glowing exhaust trails that grow
- Blue trails for human, orange for Herald
- Bright nose with body glow
- Big explosion + sparks on impact

**Impact Effects:**
- Sparks flying outward on PDC hits
- Motion trails on sparks
- Screen shake proportional to hit size

**Explosions:**
- Core flash (white, fades fast)
- Main fireball (orange/yellow)
- Expanding ring shockwave
- Flying particle embers
- Secondary explosions for ship deaths
- Debris chunks (triangles, rectangles, dots)

**Environment:**
- Nebula patches (subtle colored glows)
- Twinkling starfield with parallax
- Dark space background
- Ambient background tracer fire for chaos

**UI:**
- Ship counts for both sides
- Battle timer progress bar
- Transmission text with typing effect
- Zone name header

---

## 🔮 Future Visual Effects To Add

### High Priority (Next Session)

**1. Missile Countermeasures / PDC Interception**
- PDC should shoot down incoming torpedoes
- Bright interception explosion mid-flight
- "PDC grid online" transmission

**2. Capital Ship Differentiation**
- Frigates: Small, fast, single engine
- Cruisers: Medium, twin engines, more turrets
- Carriers: Large, hangar bays visible, launch fighters
- Dreadnoughts: Massive, multiple weapon banks, heavy armor plating

**3. Fighter Swarms**
- Tiny ships from carriers
- Move in formation patterns
- Engage in dogfights around capitals
- Easy to kill but numerous

**4. Shield Effects**
- Bubble shimmer when hit
- Hexagonal shield pattern
- Shield overload flash when depleted
- Different color for human vs Herald shields

**5. Weapon Variety**
- Railgun: Long bright line, instant travel
- Missiles: Multiple smaller warheads
- Plasma cannon: Slow-moving bright orbs
- Point defense laser: Thin continuous beam

### Medium Priority

**6. Ship Maneuvers**
- Flip-and-burn deceleration (Expanse style)
- Roll to spread damage across hull
- Emergency thrust dodge
- Formation flying

**7. Damage States**
- Fire particles from hull breaches
- Sparking electrical damage
- Listing/tumbling when engines destroyed
- Venting atmosphere (white gas)

**8. Battle Phases**
- Opening salvo (all ships fire simultaneously)
- Close engagement (ships weaving)
- Retreat/pursuit (damaged ships fleeing)
- Last stand (final ship surrounded)

**9. Environmental Hazards**
- Asteroid debris to dodge
- Solar flare effects
- Planetary gravity wells
- Nebula clouds affecting sensors

**10. Cinematic Moments**
- Slow-motion on ship death
- Camera focus on decisive hit
- Named ship death zooms in
- Victory/defeat pose

### Low Priority (Polish)

**11. Lighting Effects**
- Weapon fire illuminates nearby ships
- Explosions cast dynamic light
- Engine glow on nearby surfaces
- Muzzle flash shadows

**12. Audio-Visual Sync Points**
- Visual pulse on bass hits
- Weapon fire synced to drums
- Silence before big explosion

**13. Post-Processing**
- Bloom on bright effects
- Chromatic aberration on damage
- Vignette during critical moments
- Motion blur on fast ships

**14. UI Enhancements**
- Targeting brackets
- Damage numbers floating up
- Kill feed in corner
- Named ship portraits

---

## 💡 Visual Effect Ideas Backlog

Ideas to try when iterating:

- **Railgun penetration** - Tracer continues through target
- **Chain explosions** - Ships too close explode each other
- **Debris collision** - Chunks hit other ships
- **Boarding pods** - Small craft attaching to hulls
- **Emergency FTL** - Ships jumping out mid-battle
- **Reinforcement warp-in** - Fleet arriving dramatically
- **Planet in background** - Gives scale reference
- **Sun lens flare** - Directional light source
- **Comm chatter overlay** - Radio transmissions
- **Black box recovery** - Data from destroyed ships
- **Medical evac shuttles** - Rescue from debris
- **Tractor beams** - Pulling disabled ships

---

## Sources
- [Sins of a Solar Empire Review - VideoGamer](https://www.videogamer.com/reviews/sins-of-a-solar-empire-review/)
- [The Expanse Space Battles - ResetEra](https://www.resetera.com/threads/the-expanse-has-the-coolest-space-battles-ive-ever-seen-in-movies-or-tv-spoilers-including-s3.42511/)
- [Amazing Space Battles Stellaris Mod](https://steamcommunity.com/sharedfiles/filedetails/?id=1878473679)
- [Gratuitous Space Battles 2 - Steam](https://store.steampowered.com/app/344840/Gratuitous_Space_Battles_2/)
- [Best Space Combat Games - The Gamer](https://www.thegamer.com/best-space-combat-games/)
