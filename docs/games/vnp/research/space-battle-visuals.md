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
- **Launch Effect - Power Surge**:
  - 25-particle muzzle blast (white -> faction color -> fade)
  - Expanding ring flash at muzzle (scales 3.5x over 0.15s)
  - Team-colored particles for faction identity

#### Laser (Destroyers) - "Instant Precision"
- **Behavior**: Instant hit, no travel time, guaranteed damage
- **Visual**: Dual-layer beam effect
  - Core beam: 14px width, bright faction color
  - Glow beam: 24px width, 40% opacity outer glow
- **Animation**: Both beams fade over 0.2 seconds
- **Impact**: 1.5x scaled burn mark at target location
- **Tactical**: Sniper role, 400 range, slower fire (1.5/sec)

#### Missile (Cruisers) - "Shower Salvo"
- **Behavior**: Fires 3-missile salvo with staggered launch
  - Each missile arcs on independent bezier curve
  - Varied arc heights (40-75% of distance)
  - Slight angular spread for shower pattern
  - Each tracks target independently
- **Speed**: 500 (fast, aggressive)
- **Visual**: Sleek thin rocket shape
- **Smoke Trail**: 20-particle GPUParticles2D per missile
  - Team-colored exhaust -> gray smoke gradient
  - Particles rise slightly (gravity: -10)
  - 0.4 second lifetime, tight trail
- **Damage**: Split across 3 missiles, each with 80-unit AOE
- **Tactical**: Bombardment, 500 range, slow reload (0.8/sec)

### Missile Explosions - Faction-Distinctive Colors

Each faction has a unique explosion palette for instant recognition:

**Player (Blue Fleet) - Plasma Explosions**
- Flash: Ice white (0.8, 0.9, 1.0)
- Fire: Bright cyan -> deep blue fade
- Sparks: Electric blue
- Ring: Cool blue shockwave

**Enemy (Orange Fleet) - Fire Explosions**
- Flash: Hot white (1.0, 0.95, 0.8)
- Fire: Bright orange -> deep red fade
- Sparks: Yellow-gold
- Ring: Orange shockwave

**Nemesis (Purple Fleet) - Void Explosions**
- Flash: Pink-white (1.0, 0.7, 1.0)
- Fire: Hot magenta -> deep purple fade
- Sparks: Pink-magenta
- Ring: Purple shockwave

**Per-Missile Particle Counts:**
1. Flash: 15 particles, 0.1s
2. Fire: 35 particles, 0.35s
3. Smoke: 20 particles, 0.8s (neutral gray)
4. Sparks: 15 particles, 0.45s
5. Shockwave: 65% scale ring

- **Screen Shake**: 12 per missile (cumulative 36 for full salvo)
- **Area Damage**: 80 radius per missile with distance falloff

### Ship Death Explosions

Scaled by ship size using GPUParticles2D (80 particles):

| Size | Ships | Shake | Scale |
|------|-------|-------|-------|
| Small | Frigate, Harvester | 10 | 2x |
| Medium | Destroyer, Defender, Shielder | 25 | 3.5x |
| Large | Cruiser, Graviton | 50 | 6x |

### Defensive Ships (Dec 2024)

Three support ship types that counter enemy weapons:

#### Defender (PDC) - "Missile Swatter"
- **Role**: Point Defense Cannon intercepts enemy missiles
- **Weapon**: PDC (WeaponType.PDC)
- **Cost**: 80 energy
- **Stats**: 100 health, 160 speed, 250 range
- **Behavior**:
  - Follows nearest ally (support role)
  - Scans for enemy missiles within range
  - Fires 3-5 tracer lines at missiles (8x/sec)
  - 40% intercept chance per burst
  - Intercepted missiles explode harmlessly mid-flight
- **Visual**:
  - Bristling hull shape with turret bumps
  - White-blue tracers (faction-colored)
  - Small interception explosion when missile destroyed

#### Shielder - "Bubble Guardian"
- **Role**: Creates shield bubble that protects allies from lasers
- **Weapon**: Shield (WeaponType.SHIELD)
- **Cost**: 90 energy
- **Stats**: 80 health, 140 speed, 120 shield radius
- **Behavior**:
  - Follows nearest ally (support role)
  - Creates visible shield bubble around itself
  - Allies within radius get laser damage reduction
- **Visual**:
  - Rounded dome-like hull shape
  - Pulsing shield bubble (Line2D circle)
  - Shield brightens when protecting allies
  - Team-colored shield (blue/orange/purple with 40% alpha)

#### Graviton - "Void Manipulator" ⭐ NEW
- **Role**: Creates gravity well that deflects railgun projectiles around allies
- **Weapon**: Gravity (WeaponType.GRAVITY)
- **Cost**: 150 energy (expensive support)
- **Stats**: 180 health, 80 speed, 140 gravity radius (scaled down from 200)
- **Behavior**:
  - Slow, hulking mass manipulator
  - Creates massive gravity well around itself
  - Railgun projectiles entering the field have 85% deflection chance (balanced from 90%)
  - Deflected projectiles curve around and deal 30% reduced damage
- **Visual - Swirling Vortex Effect** (scaled down for balance):
  - **Dark void center**: Black polygon (22px radius, 60% opacity) - ominous core
  - **Outer ring**: Slowly rotating, 3px wide, dimmed faction color
  - **Inner ring**: Counter-rotating faster, 2.5px wide, bright faction color
  - **Vortex particles**: 30 particles spiraling inward (reduced from 60)
    - Spawn at edge (140px radius)
    - Radial acceleration: -120 to -160 (pulled inward)
    - Tangential acceleration: 60-100 (spiral motion)
    - Bright at edge -> fade to black at center
  - **Pulsing intensity**: Modulate alpha 0.6-1.0 over 3 seconds
  - **Protection glow**: Rings thicken when allies within radius

  *Design note: Original effect was "absolutely terrifying" (user quote) - scaled down 30% so it doesn't visually dominate the battlefield. Still imposing but not raid-boss level.*
- **Deflection Visual**:
  - Ripple wave expands from deflection point (6x scale over 0.3s)
  - Curved trail showing projectile bend (old direction -> new)
  - Purple-tinted sparks at deflection point (12 particles)
  - Brief flash on gravity well (1.5x brightness pulse)
- **Tactical Design**:
  - The only counter to railgun (frigate) spam
  - Expensive to prevent overuse
  - Slow movement means positioning matters
  - Doesn't block missiles or lasers - specialized role
  - Creates dramatic "shots bending around" moments

### Engine Trails - Ship-Type Specific (Dec 2024)

Design note: *"Each ship should have an element of scary or not, but we should be mindful what we want the emotional journey to be when we see ships! Like rock paper scissors gets epic on its own."*

| Ship Type | Particles | Lifetime | Velocity | Feel |
|-----------|-----------|----------|----------|------|
| Frigate | 25 | 0.35s | 80-120 | Fast, aggressive |
| Destroyer | 30 | 0.5s | 60-90 | Steady, precise |
| Cruiser | 45 | 0.7s | 40-70 | Heavy, powerful |
| Defender | 28 | 0.45s | 55-85 | Alert, ready |
| Shielder | 22 | 0.5s | 45-75 | Protective |
| Graviton | 35 | 0.6s | 30-50 | Slow, ominous |
| Harvester | 18 | 0.4s | 50-70 | Utilitarian |

**Emotional Journey Per Ship:**
- **Frigates**: *"The swarm approaches"* - fast trails, darting motion
- **Destroyers**: *"Locked on"* - steady trails, precise positioning
- **Cruisers**: *"Here comes the bombardment"* - heavy trails, imposing presence
- **Defenders**: *"Wall of lead"* - alert stance, rapid PDC tracers
- **Shielders**: *"Safe zone"* - protective bubble, pulsing glow
- **Graviton**: *"Reality bending"* - swirling vortex, dark presence

### Muzzle Flash - Weapon-Specific Shapes

| Weapon | Shape | Feel |
|--------|-------|------|
| Railgun | Sharp triangle (18px) | Punchy burst |
| Laser | Wide hexagon glow | Charging beam |
| Missile | Fiery bloom | Launch flare |
| PDC | Small triangle (8px) | Rapid flash |

- Faction-specific weapon color (60% lightened)
- Fades to 0 alpha over 0.1 seconds
- Offset from ship bow based on ship type

### Ship Movement & Tactical AI (Dec 2024)

Design philosophy from user: *"I would love for the smaller faster ships to never stop moving, it seems odd that they'd stop and get shot when they can be doing hit and run, strafing runs. The large ships aren't fast enough to be able to do the same, it feels like a good advantage of being small and fast."*

#### Size-Based Combat Movement

| Size | Ships | Combat Behavior | Speed |
|------|-------|-----------------|-------|
| SMALL | Frigate, Harvester | Constant strafing, never stops | 200-280 |
| MEDIUM | Destroyer, Defender, Shielder | Slow orbit at 40% speed | 140-180 |
| LARGE | Cruiser, Graviton | Stop and fire | 80-100 |

**Small Ships - Strafing Runs**
- Circle target at 80% of weapon range
- Full speed movement at all times
- Random direction reversals for unpredictability
- Subtle weaving motion for evasive feel
- Nose always pointed at target while moving
- *"Hit and run - can't catch me!"*

**Medium Ships - Controlled Orbit**
- Slow orbit at 85% of weapon range
- 40% movement speed while firing
- More deliberate, tactical feel
- *"Mobile but methodical"*

**Large Ships - Stationary Fire**
- Stop completely to fire
- Park and unleash bombardment
- *"Too heavy to dance - but you won't survive my salvo"*

#### Side Thrusters Visual Feedback

Maneuvering thrusters fire when ships strafe laterally:
- Left thruster fires when moving right (points down)
- Right thruster fires when moving left (points up)
- Intensity scales with lateral movement speed
- Size-appropriate particle counts (8/12/15 for S/M/L)
- Team-colored exhaust

#### Adaptive Tactical AI

User quote: *"If they know they're attacking a ship that's slow and single fire capability, close distance quickly and kill while evading the attack or swarm it if its worth the kill. If it has short range AOE spray, scatter and stay back, or try to flank around."*

**Threat Assessment System**

Ships analyze nearby enemies every 0.5s and categorize threats:

| Threat Type | Trigger | Tactical Response |
|-------------|---------|-------------------|
| SLOW_HEAVY | vs Cruiser | Rush in, get close (60% range), fast evasive orbit |
| FAST_SWARM | 3+ Frigates nearby | Tight formation, focused fire |
| SNIPER | vs Destroyer | Small ships rush; large ships trade at range |
| AOE_SPRAY | vs Defender or 2+ Cruisers | Scatter! Stay at max range, flank around |
| SUPPORT | vs Shielder/Graviton | Priority kill, aggressive rush |

**Tactical Behaviors**

1. **Rush** - Close distance aggressively at 110% speed with slight weaving
2. **Scatter** - Push away from allies to avoid AOE clustering
3. **Flank** - Position on opposite side of target from allies
4. **Keep Distance** - Maintain maximum weapon range

**Scatter Force Calculation**
- Ships within 100 units of allies push apart
- Force scales inversely with distance
- Prevents clustering against AOE threats

**Flank Position Calculation**
- Find center of allied ships
- Position on opposite side of target
- Creates pincer movements naturally

### Star Bases - Capital Structures (Dec 2024)

User design philosophy: *"I think we should also be introducing point defense, or star bases which are extremely risky to attack - this makes the strafing runs and speed make more sense. It's like a huge stationary ship - I'm imagining X-Wings attacking a Star Destroyer, another similar capital ship would get wrecked but the fighters can dodge the turbolasers and get close."*

#### Star Base
- **Role**: Massive stationary defensive structure - "Star Destroyer" feel
- **Type**: MASSIVE size class (new)
- **Cost**: 500 energy (spawned free at game start per team)
- **Stats**: 800 health, 0 speed (stationary), 600 range
- **Weapon**: Turbolaser (new weapon type)

**Turbolaser Mechanics**
- **Speed**: 180 (slow projectile - easy to dodge for fast ships)
- **Damage**: 120 (devastating when it hits)
- **Fire Rate**: 0.5/sec (2 second reload)
- **Key Design**: Small fast ships can strafe and dodge; capital ships get wrecked

**Star Base Visuals**
- Massive angular hull (60px length, no scaling)
- 4 turret indicators around structure
- Hexagonal inner ring (80px radius, tech feel)
- Pulsing danger zone ring (600px radius)
- Rotating sensor sweep line
- Slow rotation to track targets

**Turbolaser Visual**
- Big elongated bolt (12px size)
- Bright overbright modulation (1.5x)
- Thick 10px trail
- 30-particle trailing glow (faction-colored)
- Dramatic charging effect on fire:
  - Circular charge glow (20px -> 40px)
  - Expanding ring flash (30px -> 90px)

**Turbolaser Impact**
- 20-particle bright flash
- 40-particle main explosion
- 25-particle sparks
- 1.2x scale shockwave
- 30 intensity screen shake

**Star Base Death - Massive Destruction**
- 100 intensity screen shake
- 12x scale explosion
- 5 secondary explosions in sequence (0.15s apart)
- Massive shockwave ring (20x scale over 1s)
- *"The Death Star explodes"* moment

**Tactical Implications**
- Small ships (Frigates) can strafe and dodge turbolasers
- Medium ships (Destroyers) take significant risk
- Large ships (Cruisers) nearly guaranteed to be hit
- Justifies all the strafing run mechanics we built
- Creates X-Wing vs Star Destroyer gameplay

### Asteroids-Style Momentum Physics (Dec 2024)

User quote: *"The movement should be more like Asteroids, where the ships carry momentum and use thrust to modify it. We can make the field bigger as we're introducing more maneuver."*

#### Physics System
- Ships have persistent velocity (momentum)
- Thrust applies acceleration, not instant velocity
- Space drag (0.3) prevents infinite drift
- Maximum speed clamped at 1.2x base speed (momentum overspeed)

**Movement Feel by Size**

| Size | Thrust Mult | Max Speed | Drag | Feel |
|------|-------------|-----------|------|------|
| SMALL | 2.5x | 1.4x (rush) | 0.5x | Zippy, drifty |
| MEDIUM | 2.5x | 1.2x | 1.0x | Weighty but mobile |
| LARGE | 2.5x | 1.2x | 1.0x | Gradual brake |
| MASSIVE | - | 0 | - | Stationary |

**Strafing with Momentum**
- Thrust towards desired orbit position
- Velocity builds over time
- Ships drift through turns
- Creates "slide" feel at high speed
- Side thrusters fire based on lateral velocity component

**Rush Maneuver (Enhanced)**
- 1.3x thrust multiplier for aggressive close
- 50% drag reduction (full burn feel)
- Slight weaving added to thrust direction
- Up to 1.4x base speed achievable

**Large Ship Braking**
- Gradual velocity reduction (2.0 lerp per second)
- Stops at < 5 velocity magnitude
- Heavy, momentum-preserving feel

### Expanded Battlefield (Dec 2024)

World size increased to support momentum-based combat:

| Parameter | Value |
|-----------|-------|
| World Scale | 1.5x viewport |
| World Padding | 150 units |
| Planet Count | 12 |
| Star Count | 450 (scaled) |
| Bright Stars | 67 (scaled) |
| Nebula Count | 10 (scaled) |

- Camera zoomed out to 0.67x to show full arena
- Bases positioned at corners of larger world
- Ships push towards world center (1.5x viewport center)
- More maneuvering room for momentum physics

### Faction Color Palettes

**Player (Blue Fleet)**
| Weapon | Color | Description |
|--------|-------|-------------|
| Railgun | `(0.7, 0.85, 1.0)` | Ice blue |
| Laser | `(0.2, 0.9, 1.0)` | Cyan beam |
| Missile | `(0.4, 0.7, 1.0)` | Blue trail |
| PDC | `(0.9, 0.95, 1.0)` | White-blue tracers |
| Shield | `(0.3, 0.6, 1.0, 0.4)` | Blue bubble |
| Gravity | `(0.2, 0.1, 0.4, 0.6)` | Dark blue void |

**Enemy (Orange Fleet)**
| Weapon | Color | Description |
|--------|-------|-------------|
| Railgun | `(1.0, 0.9, 0.3)` | Yellow autocannon |
| Laser | `(0.5, 1.0, 0.3)` | Green plasma |
| Missile | `(1.0, 0.5, 0.2)` | Orange torpedo |
| PDC | `(1.0, 1.0, 0.7)` | Yellow-white tracers |
| Shield | `(1.0, 0.6, 0.2, 0.4)` | Orange bubble |
| Gravity | `(0.3, 0.15, 0.1, 0.6)` | Dark orange void |

**Nemesis (Purple Fleet)**
| Weapon | Color | Description |
|--------|-------|-------------|
| Railgun | `(0.8, 0.3, 1.0)` | Purple pulse |
| Laser | `(0.6, 0.2, 0.9)` | Purple disruptor |
| Missile | `(0.9, 0.2, 0.8)` | Magenta antimatter |
| PDC | `(0.9, 0.7, 1.0)` | Light purple tracers |
| Shield | `(0.7, 0.2, 0.9, 0.4)` | Purple bubble |
| Gravity | `(0.15, 0.0, 0.2, 0.6)` | Deep purple void |

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
