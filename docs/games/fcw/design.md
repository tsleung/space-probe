# FCW (First Contact War) - Game Design Document

**Version:** 2.1 (Updated December 2025)
**Core Fantasy:** Humanity's desperate last stand against an overwhelming alien invasion
**Inspiration:** Halo Reach (noble sacrifice, losing battle fought with honor)
**Gameplay:** Fleet movement strategy + Evacuation management

---

## Table of Contents

1. [Story & Concept](#story--concept)
2. [Core Design Philosophy](#core-design-philosophy)
3. [Game Mechanics](#game-mechanics)
4. [Visual Systems](#visual-systems)
5. [Narrative Systems](#narrative-systems)
6. [Technical Architecture](#technical-architecture)
7. [Recent Changes](#recent-changes-december-2025)

---

## Story & Concept

### Setup

Year 2157. The Mars colony has thrived for a century. Then the Heralds arrived.

First contact was not peaceful. An alien armada entered the solar system and began systematically destroying human outposts. Earth's orbital defense fleet was shattered in hours.

You are the Emergency Production Coordinator for the Sol Defense Authority. Your job: transform civilian industry into war production, manage scarce resources, and allocate what little fleet we can muster to slow the Herald advance.

### The Core Truth

**You will not win.** This is Reach. Earth will fall. The goal is to buy time for evacuation ships to escape, preserve what humanity you can, and make the enemy pay for every AU they take.

**"You cannot win - you choose how history remembers you."**

### Emotional Arc

```
PEACE (Turns 1-3)
"Everything is fine. Build your fleet."
↓
DETECTION (Turn 3)
"Something is coming. You have time."
↓
FIRST CONTACT (Turns 4-8)
"We can hold them! Maybe we can win!"
↓
REALIZATION (Turns 9-12)
"We can't win. How many can we save?"
↓
DESPERATE EVACUATION (Turns 13-20)
"Every ship, every life, every second counts"
↓
EARTH FALLS (Turn 20-25)
"This is how humanity is remembered"
```

---

## Core Design Philosophy

### "Show, Don't Tell"
The narrative emerges from watching ships move, zones fall, and transmissions scroll. No cutscenes, no dialogue trees. The story is in the logistics.

### "Every Number is a Life"
Population counters aren't abstract. They're the difference between LEGENDARY and ANNIHILATION. The UI should make you feel each million lost or saved.

### "Roguelite Tragedy"
Each playthrough is different, but the arc is the same: hope → realization → desperation → sacrifice → legacy. The variety is in *how* you lose and *what* you save.

### "Compelling to Watch"
The game should be interesting even at 4x speed with AI playing. The visual language should tell the story without reading text. A viewer should immediately understand: "Humanity is losing, but they're fighting."

### "Spartans Never Die"
Not victims, but heroes buying time. Every life saved matters. The tone is tragic then DEFIANT - emphasize courage, sacrifice, and hope.

### "Every Moment Matters"
The weeks march as inevitability - futility, hopelessness, dread. You are trading off what little remains for even less in the future. But you are NOT a victim to operational structure. You can make decisions at any moment, not just at turn boundaries. The player has continuous agency to respond to the unfolding crisis.

This matters because: if tradeoffs are so crucial, you wouldn't wait a week before changing course. Every hour counts. The clock shows hours, days, weeks - all ticking relentlessly. The player should FEEL this weight. When they see "WEEK 4, DAY 3 - 14:00", they should feel the Herald getting closer, the resources dwindling, the window closing.

The discrete time events (hourly ticks, daily updates, weekly phases) create the rhythm of dread. The continuous player agency creates the desperate scramble to respond. Together they produce the core emotional experience: watching doom approach while frantically trying to save what you can.

---

## Game Mechanics

### Victory Conditions

**Earth will fall. Victory is measured by lives evacuated:**

| Tier | Lives Evacuated | Description |
|------|-----------------|-------------|
| **LEGENDARY** | 80M+ | "They will remember what we did here" |
| **HEROIC** | 40-80M | "Enough to rebuild" |
| **PYRRHIC** | 15-40M | "A remnant survives" |
| **TRAGIC** | 5-15M | "Scattered survivors" |
| **ANNIHILATION** | <5M | "Humanity's light flickers" |

*Note: Victory tiers were rebalanced to be achievable through skilled play. LEGENDARY requires excellent strategy with carriers for evacuation.*

### Turn Structure (1 Turn = 1 Week)

```
1. PRODUCTION PHASE
   - All controlled zones produce resources from buildings
   - Zone resource bonuses applied

2. SHIP CONSTRUCTION
   - Production queue advances
   - Completed ships added to fleet

3. FLEET TRANSIT
   - Player fleets in transit advance by 1 week
   - Arriving fleets deploy to destination zones
   - If destination fell, ships reroute to Earth

4. HERALD TRANSIT
   - Herald fleet advances toward target (takes multiple weeks)
   - Herald arrives when transit complete

5. COMBAT PHASE (Only if Herald has arrived)
   - Zone defense vs Herald strength
   - Combat roll variance (0.8-1.2x)
   - Zone holds (30-50% losses) or falls (all destroyed)

6. HERALD ADVANCE
   - Pick next target (weakest adjacent to fallen zones)
   - Start transit to new target

7. EVACUATION
   - Ships at Earth evacuate civilians
   - Carriers provide 8x evacuation bonus

8. GAME OVER CHECK
   - If Earth falls, calculate victory tier

9. ADVANCE TURN
   - Turn counter +1
   - Herald strength scales up
```

### Time System Architecture

FCW uses a **discrete simulation with visual interpolation**:

**Time Hierarchy:**
- **Hour** = Base simulation tick (finest granularity, game logic runs here)
- **Day** = 24 hours (production updates, daily events)
- **Week** = 7 days / 168 hours (major phases, Herald milestones)

**Single Source of Truth:**
```gdscript
game_time: float  # Hours since game start

# Derived values
var current_hour = int(game_time) % 24
var current_day = int(game_time / 24) % 7 + 1  # 1-7
var current_week = int(game_time / 168) + 1
```

**Discrete Simulation Layer:**
- Game logic advances in 1-hour ticks
- Entity positions update: `position += velocity * 1_hour`
- Detection rolls, events, combat resolution happen at tick boundaries
- Pausing stops ticks from advancing

**Visual Interpolation Layer:**
- `tick_progress: 0.0 → 1.0` tracks progress to next hour tick
- All rendered positions: `lerp(pos_at_tick_N, pos_at_tick_N+1, tick_progress)`
- Creates smooth animation between discrete states
- Pausing freezes `tick_progress`, visuals freeze

**Player Agency:**
- Decisions can be made at ANY time (real-time)
- Orders queue and execute at next tick, or immediately where appropriate
- Clock marches regardless - you react to it, not wait for it

**Speed Multipliers:**
```
- PAUSED: 0 ticks/sec (game stopped)
- SLOW: 0.5 ticks/sec (1 hour = 2 real seconds)
- NORMAL: 1 tick/sec (1 hour = 1 real second)
- FAST: 2 ticks/sec (1 hour = 0.5 real seconds)
- VERY FAST: 4 ticks/sec (1 hour = 0.25 real seconds)
```

**Time Display:** `"WEEK X, DAY Y - HH:00"`

**Battle Replays:**
- Battles have their own independent timeline
- Main game clock can be paused while battle plays
- A 1-hour battle in game time can replay over several minutes
- Battle outcome is pre-calculated; replay is just visualization

### Zone System (6 Zones)

**Map Layout:**
```
                    ┌─────────────┐
                    │   KUIPER    │ ← Heralds enter here
                    │  (Rare El.) │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
        ┌─────┴─────┐ ┌────┴────┐ ┌─────┴─────┐
        │  JUPITER  │ │ ASTEROID│ │  SATURN   │
        │  (Energy) │ │  (Ore)  │ │  (Rare)   │
        └─────┬─────┘ └────┬────┘ └─────┬─────┘
              │            │            │
              └────────────┼────────────┘
                           │
                    ┌──────┴──────┐
                    │    MARS     │
                    │ (Shipyards) │
                    └──────┬──────┘
                           │
                    ┌──────┴──────┐
                    │    EARTH    │ ← Protect at all costs
                    │ (Population)│
                    └─────────────┘
```

**Zone Properties:**

| Zone | Population | Resource Bonus | Special |
|------|------------|----------------|---------|
| Earth | 8 Billion | Production hub | Final defense |
| Mars | 50M | Shipyard bonus | Chokepoint |
| Jupiter | 2M | +10 Energy | Gas giant |
| Saturn | 1M | +3 Rare | Ring system |
| Asteroid Belt | 500K | +5 Ore | Mining colony |
| Kuiper | 50K | +3 Rare | Entry point |

**Zone Status:**
- `CONTROLLED` - Under human control
- `UNDER_ATTACK` - Herald attacking this turn
- `FALLEN` - Permanently lost

### Travel Times (in weeks)

Fleet and Herald movement takes realistic travel time between zones:

| Route | Weeks |
|-------|-------|
| Earth ↔ Mars | 2 |
| Mars ↔ Jupiter/Saturn/Asteroid | 3 |
| Outer planets ↔ Kuiper | 2 |
| Earth ↔ Jupiter (via Mars) | 5 |
| Earth ↔ Kuiper (via Mars + outer) | 7 |

*Ships in transit are visible on the map, smoothly interpolating position.*

### Resource System

**Raw Resources:**
- **Ore** - Asteroid mining, planetary extraction
- **Steel** - Refined from ore
- **Energy** - Solar collectors, fusion plants
- **Electronics** - Manufactured components
- **Rare Elements** - Specific locations only
- **Weapons** - Military-grade systems

**Starting Resources:**
```
Ore: 100
Steel: 50
Energy: 100
Electronics: 20
Rare: 30
Weapons: 10
```

**Production Chains:**
```
MINE → extracts Ore (10/turn)
REFINERY → Ore to Steel (10 Ore → 5 Steel)
POWER_PLANT → Energy (20/turn)
ELECTRONICS_FACTORY → Energy to Electronics (5 Energy → 3 Electronics)
WEAPONS_LAB → Rare + Energy to Weapons (5 Rare + 5 Energy → 2 Weapons)
SHIPYARD → Converts resources to ships
```

### Ship Types

| Ship | Cost (S/E/W) | Combat Power | Build Turns | Special |
|------|--------------|--------------|-------------|---------|
| **Frigate** | 10/5/2 | 10 | 1 | Cheap, fast build |
| **Cruiser** | 30/15/8 | 40 | 2 | Backbone of fleet |
| **Carrier** | 50/30/5 | 25 | 2 | +50% zone defense, **8x evacuation** |
| **Dreadnought** | 100/50/20 | 150 | 3 | Heavy firepower |

**Starting Fleet:**
- 10 Frigates
- 3 Cruisers
- 1 Carrier
- 0 Dreadnoughts

**Capital Ship Fleet Transfer:**

When a capital ship (Cruiser, Carrier, or Dreadnought) departs a zone, it automatically takes a portion of the zone's frigates as escort:

```
Escort portion = 1 / (number of capital ships at zone)

Example:
  2 capital ships at Mars, 10 frigates
  First capital ship departs → takes 5 frigates (50%)
  Second capital ship departs → takes remaining 5 frigates (100%)
```

This creates meaningful fleet movement decisions - you're not just moving one ship, you're deploying a battle group. The escort frigates:
- Travel with the capital ship to its destination
- Are removed from the origin zone's defense
- Are added to the destination zone when the capital ship arrives

**Fleet Roster UI:**

The UNN CAPITAL FLEET panel (top-right) shows all capital ships with:
- Ship name and type (color-coded)
- Current location (`@ Mars`) or destination (`→ Earth`)
- Escort count if traveling (`+5` frigates)

Click a ship in the roster to select it, then click a zone to send it there.

### Herald Forces

**Attack Strength Scaling:**

| Turn | Attack Strength |
|------|-----------------|
| 1-5 | 50-100 |
| 6-10 | 150-300 |
| 11-15 | 400-600 |
| 16-20 | 800-1200 |
| 21-25 | 1500-2500 |

**Herald Behavior:**
1. **Peace Period (Turns 1-3):** No attacks, players prepare
2. **Target Selection:** Always attack weakest adjacent zone
3. **Travel Time:** Herald takes 2-7 weeks to reach target (no teleporting)
4. **Combat:** Only attacks after arriving at destination

### Combat Resolution

```
Zone Defense = Σ (ship combat power × count) × carrier_bonus
  where carrier_bonus = 1 + (0.5 × carrier_count)

Combat Outcome:
  If Defense ≥ Herald: Zone HOLDS (30-50% fleet losses)
  If Defense < Herald: Zone FALLS (fleet destroyed, population lost)
```

### Evacuation System

Ships assigned to Earth help evacuate civilians:

```
Evacuation per ship = count × (combat_power / 10) × 100,000 × multiplier
  where multiplier = 8.0 for Carriers, 1.0 for others

Example:
  1 Frigate at Earth = 1 × (10/10) × 100K × 1 = 100K/turn
  1 Carrier at Earth = 1 × (25/10) × 100K × 8 = 2M/turn
```

**Carriers are ESSENTIAL for reaching higher victory tiers.**

---

## Visual Systems

### Solar Map Overview

The solar map is the primary game view, rendered entirely in code with no texture dependencies.

**Visual Layers (Back to Front):**
1. Starfield background (20 contextual stars)
2. Nebula dust clouds (slow drift animation)
3. Zone circles (sized by importance, colored by world)
4. Orbital connection lines (white, dashed)
5. Staging areas (moons, stations, asteroid clusters)
6. Fleet icons (triangles for human, diamonds for Herald)
7. Ships in transit (animated bezier curves)
8. Attack waves (Herald ship swarms)
9. Combat effects (lasers, explosions, warp flashes)
10. Transmissions overlay (typewriter text)

**Zone Positions (Normalized 0-1):**
```
Earth: (0.85, 0.5) - Far right
Mars: (0.65, 0.5) - Center-right
Asteroid Belt: (0.45, 0.3) - Center
Jupiter: (0.45, 0.7) - Center-lower
Saturn: (0.25, 0.35) - Left-center
Kuiper: (0.1, 0.5) - Far left (entry point)
```

**Zone Visual Sizes:**
```
Earth: 40 (largest - population center)
Jupiter: 35 (gas giant)
Saturn: 30 (gas giant)
Mars: 25 (colony)
Asteroid Belt: 20 (mining)
Kuiper: 15 (frontier)
```

**Zone Colors:**
```
Earth: Blue (0.2, 0.5, 1.0)
Mars: Red-Orange (0.9, 0.4, 0.2)
Asteroid Belt: Gray (0.6, 0.6, 0.6)
Jupiter: Orange-Tan (0.9, 0.7, 0.5)
Saturn: Yellow-Tan (0.9, 0.85, 0.6)
Kuiper: Cold Blue (0.4, 0.5, 0.7)
```

### Staging Areas

Each zone has identifiable sub-locations for combat:

| Zone | Staging Areas |
|------|---------------|
| Earth | Luna (moon), L2 Station |
| Mars | Phobos (moon), Deimos (moon) |
| Asteroid Belt | Ceres Cluster, Vesta Field |
| Jupiter | Europa (moon), Ganymede (moon), Io Station |
| Saturn | Titan (moon), Rings, Enceladus (moon) |
| Kuiper | Pluto (moon), Eris Cluster |

**Staging Type Visuals:**
- **MOON**: Gray rocky sphere with craters
- **ASTEROID_CLUSTER**: Scattered rocks with dashed boundary
- **STATION**: Rotating structure with solar panel arms
- **RING**: Elliptical arc around planet

### Ship Visuals

**Human Ships (Blue/Cyan):**
- Triangular hull shape
- Engine glow (cyan/white)
- Particle trail during movement
- Size scales with ship type

**Herald Ships (Purple/Magenta):**
- Diamond/angular aggressive shape
- Menacing orange-purple engine trail
- Swarm behavior in attack waves

**Civilian Ships (Varied colors):**
- Transport: Rounded, blue-white
- Miner: Industrial with arms, gray
- Freighter: Boxy, green-gray
- Liner: Elegant white
- Tanker: Large brown cylinder

**Colony Ships (Exodus Fleet):**
- Large ark shape (white/green)
- Named vessels ("New Dawn", "Hope", etc.)
- Visible soul count (e.g., "400,000 aboard")
- Green engine trail
- Warp flash on departure

### Combat Effects

**Laser Fire:**
- Human: Blue/cyan beams
- Herald: Purple/magenta energy beams
- Width and length vary by weapon type

**Explosions:**
- Inner flash (white/yellow)
- Expanding ring
- Particle debris
- Color differs: blue for human losses, purple for Herald

**Warp Flashes:**
- Brief bright flash at ship spawn/exit
- Expanding ring effect
- Used for fleet departures and arrivals

**Screen Effects:**
- Screen shake during combat
- Red vignette when desperate
- Danger pulse on threatened zones

### Multi-Level Zoom

**Zoom Levels:**

| Level | View | Purpose |
|-------|------|---------|
| GALAXY | Sol among billions of stars | "Humanity's last light" - scale, isolation |
| SYSTEM | All 6 zones (default) | Strategic overview |
| PLANET | Single zone enlarged | Intense focus during attacks |
| BATTLE | Cinematic combat view | Visceral ship-to-ship action |

**Galaxy View:**
- 800+ procedurally generated stars
- Spiral arm distribution
- Sol marked with pulsing crosshair
- Herald presence at galaxy edge (red glow)
- Caption: "AMONG THE STARS, ONE LIGHT FLICKERS"

**Planet View (Picture-in-Picture):**
- Enlarged planet with atmospheric glow
- All staging areas visible
- Active skirmishes rendered
- Defense vs Herald strength overlay
- Border pulse when under attack

### Herald Mothership

The Herald fleet is visualized as a terrifying mothership:

**Design:**
- Multiple overlapping hull sections (magenta/purple)
- Pulsing energy core
- Energy tendrils/arcs between sections
- Orbital debris ring
- Threat beam pointing at target zone

**Movement:**
- Travels smoothly between zones (not teleporting)
- Trail particles during transit
- Position interpolates with continuous time
- Takes 2-7 weeks to reach destination

### Fleets in Transit

Ships moving between zones display:
- Bezier curve path (curved, not straight line)
- Ship icon at current position
- Smooth interpolation based on week progress
- Ship count label
- Arrival countdown

---

## Narrative Systems

### Radio Transmissions

Text overlays with typewriter effect. Context-sensitive based on game state.

**Priority Levels:**

| Priority | Color | Use Case |
|----------|-------|----------|
| 0 - Routine | Blue | Peaceful chatter |
| 1 - Important | Yellow | State changes |
| 2 - Critical | Orange | Combat reports |
| 3 - Desperate | Red | Mayday calls |

**Sample Transmissions:**

*Peace:*
```
[Ceres Mining] Ore shipment en route to Mars. All nominal.
[Luna Traffic] Passenger liner departing for Jupiter colonies.
[Titan Refinery] Fuel reserves at 94%. Production steady.
```

*Tension:*
```
[Fleet Command] All ships maintain defensive positions.
[Early Warning] Herald signatures detected. Stand by.
[Mars Defense] Scrambling patrol wings. Code Yellow.
```

*Combat:*
```
[Battlegroup] Engaging hostile forces! All hands!
[Defense Grid] Shields holding! Return fire!
[Squadron Lead] Break and attack! For Earth!
```

*Desperate:*
```
[Mayday] Hull breach! Evacuating decks 3 through 7!
[Last Stand] We'll hold them here. Get the civvies out.
[Final Transmission] If anyone hears this... remember us.
```

### Evacuation Milestones

Automatic events at population thresholds:

| Milestone | Story Beat |
|-----------|------------|
| 1M saved | "The first million. The Svalbard Vault team is among them." |
| 5M saved | "Colony Ship 'Hope' carries the world's artists and musicians." |
| 10M saved | "The children. We prioritized the children." |
| 25M saved | "Enough scientists to rebuild. Enough dreamers to try." |
| 40M saved | "HEROIC threshold. History will remember this as a victory." |
| 60M saved | "More than we dared hope. More than we deserved." |
| 80M saved | "LEGENDARY. Against all odds, humanity endures." |

### Zone Fall Narratives

Custom dramatic messages emphasizing sacrifice:

```
JUPITER HAS FALLEN

"Admiral Chen's fleet held for 6 turns.
Six turns of evacuation ships escaping.
Her last transmission: 'We bought them time.
That was always the mission.'"

Population lost: 2,000,000
Defense fleet: Destroyed with honor
Legacy: 12 million evacuees owe their lives to Jupiter's stand
```

**Zone-specific messages:**
- **Kuiper**: "They were the first line."
- **Saturn**: "Titan colony... searching for survivors."
- **Jupiter**: "Europa, Ganymede... gone."
- **Asteroid Belt**: "The mines are silent."
- **Mars**: "Mars is burning."
- **Earth**: "If anyone hears this... remember us."

### Endgame Sequence

**Final Transmission from Sol:**
```
"This is Admiral Chen to all evacuation vessels.
Earth's defense fleet is engaging.
We will hold them as long as we can.

To the [X] million souls now bound for the stars:
You carry everything we were.
Our music. Our stories. Our hope.

The Herald came for humanity.
They found us wanting to live.
And by every star in the sky,
we did not go quietly.

This is humanity's last transmission from Sol.
Not a surrender. A beginning.

We will survive."

[EVACUATION TOTAL: XX,XXX,XXX]
[VICTORY TIER: HEROIC]
"Enough to rebuild"
```

### Narrative State Machine

Game automatically determines mood:

| State | Conditions | Effects |
|-------|------------|---------|
| PEACE | Early game, Herald far, strong defenses | Civilian traffic, peaceful transmissions |
| TENSION | Herald approaching, marginal defense | Traffic stops, warning transmissions |
| COMBAT | Active attack phase | Combat effects, battle transmissions |
| DESPERATE | Earth threatened, few zones, outgunned | Screen effects, urgent transmissions |

---

## Technical Architecture

### File Structure

```
scripts/first_contact_war/
├── fcw_types.gd        # Enums, constants, data structures
├── fcw_store.gd        # State management, signals, getters
├── fcw_reducer.gd      # Pure game logic, turn processing
├── fcw_main.gd         # UI controller, AI, display logic
├── fcw_solar_map.gd    # Visual strategic map (3500+ lines)
├── fcw_battle_view.gd  # Cinematic combat window
├── fcw_planet_view.gd  # Planet detail overlay
└── fcw_battle_system.gd # Named ships, battle reports

scenes/first_contact_war/
└── fcw_main.tscn       # Main game scene

data/games/first_contact_war/
├── manifest.json       # Game metadata
├── zones.json          # Zone definitions
├── ships.json          # Ship definitions
└── balance.json        # Balance parameters
```

### State Structure

```gdscript
{
  # Core
  turn: int,
  resources: {ore, steel, energy, electronics, rare, weapons},

  # Zones
  zones: {
    zone_id: {
      id, status, population, workers,
      buildings: {building_type → count},
      assigned_fleet: {ship_type → count}
    }
  },

  # Fleet
  fleet: {ship_type → count},
  fleet_assignments: {zone_id → {ship_type → count}},
  fleet_orders: {zone_id → FleetOrder},
  production_queue: [{ship_type, turns_remaining}],
  fleets_in_transit: [{from_zone, to_zone, ship_type, count, turns_remaining}],

  # Herald
  herald_attack_target: int,
  herald_current_zone: int,
  herald_transit: {from_zone, to_zone, turns_remaining, total_turns},
  herald_strength: int,

  # Outcome
  lives_evacuated: int,
  lives_lost: int,
  total_population: int,
  event_log: [{turn, message, is_critical}],
  game_over: bool,
  victory_tier: int
}
```

### Reducer Actions

```gdscript
enum ActionType {
  END_TURN,        # Process full turn sequence
  BUILD_SHIP,      # Add ship to production queue
  ASSIGN_FLEET,    # Send ships to a zone (creates transit)
  SET_FLEET_ORDER, # Set DEFEND/DELAY/ESCORT
  EVACUATE_ZONE    # Reserved for manual evacuation
}
```

### AI System

The AI plays automatically when enabled:

1. **Ship Building:** Prioritizes based on threat (Dreadnoughts if Herald strong, Carriers for evacuation)
2. **Emergency Response:** Scrambles ships to threatened zones
3. **Blockade Formation:** Establishes defensive line at Mars chokepoint
4. **Evacuation Fleet:** Keeps Carriers at Earth for civilian rescue
5. **Fleet Redistribution:** Pulls ships from safe zones to reinforce

---

## Recent Changes (December 2025)

### Time System Refactor (In Progress)

**Problem:** Original continuous time system had three unsynchronized time layers:
1. Discrete `state.game_time` (updated at turn boundaries)
2. Continuous `_week_progress` (UI interpolation)
3. Orbital calculations (using stale game_time)

This caused entities to lag behind the displayed clock by up to 1 week, Herald AI making decisions with stale position data, and pause not properly freezing all systems.

**Solution:** Unified time architecture with discrete simulation + visual interpolation:
- Single source of truth: `game_time` in hours
- Simulation advances in 1-hour ticks (discrete)
- Visual layer interpolates between ticks (continuous appearance)
- Pause stops both tick advancement AND visual interpolation
- Player can make decisions at any time (real-time agency)

**Key Insight:** The game is NOT turn-based in the traditional sense. Players have continuous agency to respond to the unfolding crisis. The discrete ticks create the rhythm; the interpolation creates the smoothness; the player agency creates the desperate scramble to respond.

### Herald Travel Time

**Problem:** Herald teleported instantly between zones, breaking immersion.

**Solution:** Herald now takes time to travel:
- Uses same zone travel time constants as player fleets
- Herald position interpolates smoothly during transit
- Herald can only attack after arriving at destination
- Creates strategic windows for player response

**Technical Changes:**
- Added `herald_current_zone` and `herald_transit` to state
- Added `_process_herald_transit()` to turn sequence
- Combat skipped if Herald in transit
- Solar map animates Herald position based on `_week_progress`

### Fleet Transit Visualization

**Problem:** Ships assigned to zones appeared instantly.

**Solution:** Ships now travel between zones:
- Travel times based on zone distances (2-7 weeks)
- Ships visible on map during transit
- Smooth bezier curve paths
- Arrival notifications in event log

### Battle View Clipping

**Problem:** Ships were rendering outside the battle view window bounds.

**Solution:** Added `clip_contents = true` and bounds clamping to keep all ships within the visible area.

### Victory Tier Rebalancing

**Problem:** Higher victory tiers were mathematically impossible.

**Solution:** Lowered thresholds to be achievable:
- LEGENDARY: 500M → 80M
- HEROIC: 200M → 40M
- PYRRHIC: 50M → 15M
- TRAGIC: 10M → 5M

Also boosted Carrier evacuation multiplier to 8x, making them strategically essential.

---

## Design Inspirations

- **Halo Reach:** Noble sacrifice, losing battle fought with honor
- **Mindustry:** Production chains, resource management
- **Sins of a Solar Empire:** Fleet allocation, zone strategy
- **Star Wars Rebellion:** Multi-level zoom, strategic map
- **FTL:** Roguelite tragedy, meaningful failure

---

## Movement Refactor (December 2025 - In Progress)

### Vision Statement

Transform FCW from zone-based fleet management into **space chess** where position, velocity, and time are everything. Inspired by Bobiverse, The Expanse, and real orbital mechanics.

> **Core thesis**: Desperation comes from physics. You can SEE the Herald coming. You can CALCULATE when they arrive. You know where your ships CAN'T be in time. The clock isn't abstract - it's orbital mechanics.

### Design Principles

#### "Movement IS the game"

> "This is a game of tradeoffs til numbers go down, figuring out numbers go down, and which ones you decide to prioritize. It can be evacuating civilians, evacuating military, saving ships, doing damage."

Every decision involves position, time, and speed:
- Where ships are matters more than how many
- Time windows open and close as planets move
- Desperation = watching the clock, knowing what you can't do in time

#### "Unified Entity System"

> "We need a general refactoring so all elements, transport or combat ships, are subject to the same mechanics. This sounds complicated but it also simplifies - there are less types and special cases. This is good because then we can get emergent narratives when systems mix together."

All movable things follow the same rules:
- Combat ships, transports, weapons - all entities
- Same physics, same detection, same intercept rules
- Emergent gameplay from consistent systems

#### "Detection Creates the Drama"

> "There can be even a detection mechanic where if ships move between star systems creates an observable traffic link, so if we have an armada at a place, we don't want to send it because it will reveal that link."

Herald is observation-limited:
- Only sees what's near it (local observation radius)
- Follows activity (responds to detected burns)
- Doesn't care about planets - only human signatures
- **Critical**: If you don't fly to/from Earth, Herald doesn't know it's there

#### "The Earth Dilemma"

> "This allows an emergent realization the player will find as they replay FCW, that ultimately to save everyone on earth, you may need to abandon everyone else out there and keep earth dark - and that's not even guaranteed, just your best hope probabilistically."

The central tragic choice:
- Help outer colonies = Activity draws Herald toward inner system
- Go dark = Abandon everyone, but Herald might not find Earth
- Evacuate = Massive activity, definitely draws Herald

### Core Mechanics

#### Physics-Based Movement

> "If we know a ship accelerates and decelerates, figuring out where they can accelerate to for gravity assist and how they will slow down will create known intercept points. This should change as orbital bodies move relative to each other."

Ships have:
- **Position** (continuous, in AU)
- **Velocity** (direction + speed)
- **Acceleration** (thrust capability)

Movement creates signatures:
- **Burning** = High signature, visible across system
- **Coasting** = Low signature, nearly invisible
- **Deceleration burns** reveal destination (you MUST slow down)

#### Gravity Assists

> "Let's make movement the core game mechanic - we have tradeoffs to make so everything we do is related to speed and time."

Orbital bodies create:
- Slingshot opportunities (faster travel, predictable path)
- Known intercept points (we know where they'll be)
- Orbital windows (travel costs change as planets move)

#### Attack Vectors

> "I'm inspired by the Bobiverse near lightspeed attack. Even in the Expanse attack vectors matter a lot. Even in traditional air combat if you get behind release and evade, the target can't escape."

Combat depends on:
- Intercept geometry (can you match their trajectory?)
- Closing velocity (high = devastating kinetic damage)
- Aspect angle (behind them with thrust advantage = checkmate)

#### Weapons as Entities

> "This allows conventional mass weapons to have massive impact. Bombers can slingshot torpedoes without power and stealth, then activate burns to track targets."

Torpedoes follow same physics:
- **Unpowered launch**: Inherit launcher velocity, coast silently
- **Terminal burn**: High signature, homing capability
- Kinetic damage scales with closing velocity

#### Decoy Tactics

> "We introduce the decoy mechanic as emergent where we have a fleet with large mass of ships fly near the herald and try to lead it away, or at least distract it which buys time."

Split fleet feature:
- Send part of fleet as decoy
- Creates burn signature Herald follows
- Buys time for evacuation or repositioning

#### Herald Drones

> "We need the herald, like in Bobiverse, have the ability to release very fast drones which shows how outmatched humanity is anyway. This helps remove the 'hope' from playing."

Herald capabilities:
- Can release fast hunter-killer drones
- Shows technological superiority
- Reinforces "managing decline" theme

### Detection System

#### Probability Visualization

> "We need the user to see detection probability. Let's show a 'zone' (maybe its slight shading, maybe its a dotted line boundary) which shows standard deviation detection or some sort of probability in a transparent way per time (0.1% per day, 1% per day, 10% per day or something increasing given the activity of a trafficked lane)."

Detection rates:
- **IDLE**: 0.1% per day (minimal background)
- **LOW**: 1% per day (occasional traffic)
- **MEDIUM**: 5% per day (regular traffic)
- **HIGH**: 10% per day (heavy traffic)
- **BURNING**: 50% per day (active burn in range)

#### Traffic Accumulation

Routes become "known" over time:
- Each transit adds to route traffic level
- Traffic decays slowly without activity
- High-traffic routes become danger zones

#### Herald Introduction

> "We can additionally introduce the herald because they follow a ship into the system! We see the tendril mechanic directly occurring and the user goes from seeing normal traffic to an ominous herald colored detection network, then the herald comes."

Herald enters by following activity:
1. Player sees normal civilian traffic
2. Herald's detection tendrils spread (ominous visualization)
3. Herald fleet arrives, following the activity

### Technical Implementation

#### New Files

| File | Purpose |
|------|---------|
| `fcw_orbital.gd` | Route calculation, orbital positions, gravity assists |
| `fcw_herald_ai.gd` | Detection logic, pattern tracking, response behavior (planned) |

#### Modified Files

| File | Changes |
|------|---------|
| `fcw_types.gd` | EntityType/Faction/MovementState enums, entity factory functions, orbital data, detection constants |
| `fcw_store.gd` | Entity signals, entity getters, zone position helpers |
| `fcw_reducer.gd` | Entity movement processing, detection processing, intercept resolution, traffic decay |

#### Entity System

```gdscript
# All entities share this structure
var entity = {
    "id": String,
    "entity_type": EntityType,  # WARSHIP, TRANSPORT, WEAPON, HERALD_SHIP
    "faction": Faction,         # HUMAN, HERALD

    # Physics
    "position": Vector2,        # AU coordinates
    "velocity": Vector2,        # AU/week
    "acceleration": float,      # Max thrust

    # Detection
    "signature": float,         # 0 = dark, 1 = burning
    "movement_state": MovementState,  # BURNING, COASTING, ORBITING, DESTROYED

    # Payload
    "combat_power": float,
    "cargo": Dictionary,        # souls, resources

    # Orders
    "destination": int,         # Zone ID
    "route": Array,             # Waypoints
    "eta": float
}
```

#### Turn Processing (Updated)

```
1. Production
2. Ship construction
3. Fleet transit (legacy)
3b. Entity movement (NEW)
4. Herald transit
4b. Detection update (NEW)
5. Combat
5b. Entity intercepts (NEW)
6. Herald advance
7. Evacuation
8. Colony ships (legacy)
9. Game over check
10. Advance turn + game_time
11. Traffic decay (NEW)
```

### UI Changes (Planned)

#### Solar Map

- Render entities at continuous positions (not zone-locked)
- Draw trajectory curves (projected paths)
- Animate burn states (engine glow)
- Show detection zones with probability shading
- Visualize Herald observation radius

#### Planet View

> "Given we already have a planet view, we can make it smaller so that we are seeing orbital trajectories and gravity assists occurring in a close up view that the solar view doesn't show."

Close-up view showing:
- Detailed trajectory curves
- Gravity assist maneuvers
- Intercept geometries

#### Route Selection

When entity selected:
1. Destinations light up with travel times
2. Show route options (direct, coast, gravity assist)
3. Display detection exposure for each route
4. Can split fleet mid-transit

### Migration Strategy

The new entity system runs parallel to legacy systems:
1. Legacy `fleets_in_transit` and `colony_ships` still work
2. New `entities` array processes alongside
3. Gradual migration of features to entity system
4. Eventually remove legacy arrays

---

## Current Implementation Status (December 2025)

### What's Working ✅

#### Core Game Loop
- **Turn processing**: Full week-based structure with production, combat, evacuation
- **Time system**: Discrete 1-hour ticks with visual interpolation
- **Speed control**: 5 speeds (Paused, Slow, Normal, Fast, Very Fast) fully synced
- **Pause system**: Freezes ALL animations including visual effects and transports

#### Combat & Defense
- **Zone defense calculation**: Ship combat power with carrier bonuses
- **Herald strength scaling**: Progressive difficulty over 25 turns
- **Combat resolution**: Variance rolls (0.8-1.2x), zone holds or falls
- **Fleet assignment**: Ships can be sent to zones for defense

#### Evacuation
- **Carrier-based evacuation**: 8x multiplier makes carriers essential
- **Victory tiers**: 5 outcomes properly calculated
- **Population tracking**: Lives evacuated/lost/intercepted

#### Visual Systems
- **Solar map**: Fully procedural, 24+ render layers, no textures
- **Zone rendering**: Color-coded planets with staging areas
- **Fleet visualization**: Triangles (human) vs diamonds (Herald)
- **Ships in transit**: Bezier curve paths with smooth interpolation
- **Combat effects**: Lasers, explosions, warp flashes, screen shake
- **Herald mothership**: Multi-section design with energy tendrils
- **Map zoom**: Mouse wheel/trackpad zoom toward cursor (1.0-4.0x), zoom out returns to default view
- **Battle duration**: 2.0 seconds per phase for smaller fleet sizes (doubled from 1.0s)

#### Spectator Features
- **Auto-pause on major events**: Game pauses when zones fall or battles occur
- **Battle view**: Corner cinematic window showing ship-to-ship combat
- **Planet view PiP**: Picture-in-picture zoom on threatened zones
- **Transmissions**: Typewriter-effect narrative overlays
- **Cinematic camera**: AI-driven zoom and focus decisions

#### AI System
- **Auto-play mode**: AI plays the game autonomously
- **Ship building**: Smart priorities (Dreadnoughts late-game, Carriers for evacuation)
- **Emergency response**: Scrambles ships to critical zones
- **Mars blockade**: Establishes chokepoint defense
- **Evacuation fleet**: Keeps carriers at Earth

#### Entity System (Partial)
- **Entity data structures**: Position, velocity, movement state defined
- **Entity movement processing**: Hourly position updates
- **Herald as entity**: Travels with realistic time between zones
- **Entity signals**: Spawned, destroyed, arrived, intercepted

#### Capital Ship Fleet System ✅ NEW
- **Fleet roster UI**: Shows all capital ships with location/destination and escort count
- **Click-to-select**: Click ship in roster to select, click zone to send
- **Escort transfer**: Capital ships automatically take portion of frigates when departing
- **Visual positioning**: Ships orbit within zone visual (not floating outside)

### What's In Progress 🟡

#### Entity System Migration (~60%)
- Legacy `fleets_in_transit` still primary for player fleets
- New entity system runs in parallel
- Detection and intercept mechanics implemented but not fully integrated
- UI doesn't expose entity-level controls yet

#### Herald AI
- Detection probability calculation implemented
- Drone spawning scaffolded but incomplete
- Pattern learning (traffic routes) partially implemented
- Needs tuning and testing

#### Route Selection
- Route calculation (direct, coast, gravity assist) implemented in `fcw_orbital.gd`
- UI to select routes not implemented
- Player can't choose stealth vs speed tradeoffs yet

### Known Issues ❌

#### AI Gaps ✅ FIXED
All major AI gaps have been addressed:
1. ~~`_ai_redistribute_fleet` is empty~~ → Now actually moves ships from safe zones to threatened zones
2. ~~Emergency response workaround~~ → Uses new `RECALL_FLEET` action to reassign ships
3. ~~No carrier escort logic~~ → Carriers get 2 escorts each (frigates or cruisers)
4. ~~Time-based building~~ → Now need-based: prioritizes defense, evacuation, reserves

#### Entity System Gaps
1. ~~**UI for entity control**: No player interface to select entities and set destinations~~ ✅ FIXED - Fleet roster click-to-select
2. **Route visualization**: Trajectory curves rendered for selected entities ✅ PARTIAL
3. **Detection zone shading**: Probability visualization implemented ✅ DONE
4. **Entity-based evacuation**: Still uses legacy colony ship system

#### Balance/Tuning
1. **Defense ratios**: 0.8 critical / 1.2 marginal thresholds need validation
2. **Travel times**: Zone ID mapping was fixed but needs gameplay testing
3. **Resource generation**: May be too generous or too sparse

#### Fixed Issues ✅

**Zone Signature Display Bug (December 2025)**
- **Problem**: Zone signatures were showing 7699%, population accumulating unbounded
- **Root Cause**: `fcw_herald_ai.gd:update_zone_signatures()` was adding population without limits
- **Solution**: Population now sets a clamped baseline (max 0.15), final signature clamped to 0.0-1.0
- **File**: `scripts/first_contact_war/fcw_herald_ai.gd`

**Click Handling in Route Selection (December 2025)**
- **Problem**: Clicking Mars in route selection mode was selecting ships at Mars instead of the zone
- **Root Cause**: Entity click handling wasn't checking route selection state
- **Solution**: Entity clicks now skipped when in route selection mode
- **File**: `scripts/first_contact_war/fcw_solar_map.gd`

**Attack Status Label (December 2025)**
- **Problem**: "UNDER ATTACK" showing when Herald was approaching but not yet arrived
- **Root Cause**: Status logic didn't distinguish approaching vs attacking
- **Solution**: Now shows "INCOMING" when Herald is approaching, "UNDER ATTACK" when arrived
- **File**: `scripts/first_contact_war/fcw_solar_map.gd`

**ORDERS System Fixed (December 2025)**
- **Problem**: GO DARK, MAX EVAC, BLOCKADE orders not working with new entity system
- **Root Cause**: Orders were using old `zone.assigned_fleet` system, incompatible with capital ship entities
- **Solution**:
  - GO DARK: Switches all burning entities to COASTING
  - MAX EVAC: Finds Carrier entities and dispatches to Earth
  - BLOCKADE: Finds Cruiser/Dreadnought entities and dispatches to Mars
- **File**: `scripts/first_contact_war/fcw_main.gd`

### Recent Infrastructure Fixes (This Session)

| Fix | File | Issue |
|-----|------|-------|
| Zone ID mapping | `fcw_time.gd` | Travel table used wrong zone IDs |
| Entity signals | `fcw_store.gd` | Added spawned/destroyed/arrived/intercept signals |
| Tick events | `fcw_types.gd`, `fcw_reducer.gd` | Track intercepts for signal emission |
| Entity dispatch helpers | `fcw_store.gd` | Added convenience methods for entity actions |
| Detection consolidation | `fcw_types.gd` | Removed duplicate, use `FCWHeraldAI.calc_detection_probability()` |
| Pause freeze | `fcw_solar_map.gd` | Moved `_global_time` update after pause check |
| Speed sync | `fcw_solar_map.gd`, `fcw_main.gd` | Visual animations now scale with game speed |
| Explicit preloads | `fcw_main.gd` | Added FCWTypes/FCWSolarMap preloads for reliability |
| RECALL_FLEET action | `fcw_reducer.gd`, `fcw_store.gd` | New action to move ships between zones |
| AI redistribute fleet | `fcw_main.gd` | Actually pulls ships from safe zones to threatened zones |
| AI need-based building | `fcw_main.gd` | Prioritizes defense, evacuation, reserves instead of turn modulo |
| AI carrier escorts | `fcw_main.gd` | Assigns 2 escorts per carrier at Earth |
| AI emergency response | `fcw_main.gd` | Uses recall_fleet to properly reassign ships in crisis |
| **Capital ship escort** | `fcw_reducer.gd` | Capital ships take portion of frigates when departing |
| **Fleet roster UI** | `fcw_solar_map.gd` | Click-to-select ships, shows location + escort count |
| **Ship orbit radius** | `fcw_solar_map.gd` | Ships stay within zone visual (0.7x radius) |
| **Remove assign buttons** | `fcw_main.gd`, `fcw_main.tscn` | Ships travel with capital ships, no teleporting |
| **Speed label width** | `fcw_main.tscn` | Fixed width prevents layout shift on text change |
| **Zone signature bug** | `fcw_herald_ai.gd` | Fixed unbounded accumulation (7699%) |
| **Route selection clicks** | `fcw_solar_map.gd` | Skip entity clicks when in route selection mode |
| **Attack status label** | `fcw_solar_map.gd` | INCOMING vs UNDER ATTACK distinction |
| **ORDERS system** | `fcw_main.gd` | Fixed GO DARK, MAX EVAC, BLOCKADE for entity system |
| **Map zoom** | `fcw_solar_map.gd` | Mouse wheel/trackpad zoom (1.0-4.0x) |
| **Battle duration** | `fcw_battle_view.gd` | Doubled to 2.0 seconds per phase |

### Recommended Improvements

#### Priority 1: AI Completion ✅ DONE
All AI improvements implemented:
- `RECALL_FLEET` action enables moving ships between zones
- `_ai_redistribute_fleet` now pulls ships from safe zones
- Need-based building responds to defense deficit and evacuation needs
- Carrier escort logic ensures transports are protected
- Emergency response uses proper fleet reassignment

#### Priority 2: Entity System ✅ MOSTLY DONE
1. ~~Add route selection UI when clicking entities~~ → Fleet roster click-to-select
2. ~~Visualize entity trajectories on solar map~~ → Bezier trajectory curves
3. ~~Show detection probability zones~~ → Concentric probability rings around Herald
4. Migrate colony ships to entity system (still pending)

#### Priority 3: Polish
1. Tune defense ratio thresholds (0.8 critical / 1.2 marginal)
2. Balance resource generation rates
3. Add more narrative transmissions for key events
4. Improve Herald drone behavior (pursuit logic, lifetime)

---

## Deterministic Simulation & AI Optimization

### Determinism Guarantee

FCW is fully deterministic: **same seed = identical outcome**.

```gdscript
# Start with fixed seed for reproducible game
store.start_new_game(12345)

# Record game for replay
var recording = store.get_recording()
store.save_recording("user://game.json")
```

This enables:
- **Replay & Debug**: Record games and replay them exactly
- **AI Optimization**: Run thousands of simulations to find optimal strategies
- **Narrative Control**: Predict when key moments occur

### AI Decision Architecture

The Human AI uses **phase-adaptive strategy** with action evaluation:

| Phase | Herald Location | Strategy |
|-------|-----------------|----------|
| **EARLY** | Kuiper/outer zones | Build fleet aggressively, minimize detection signature |
| **MID** | Jupiter/Asteroid Belt | Mars blockade + start evacuation, balanced defense |
| **LATE** | Mars/inner zones | Maximize evacuation, sacrifice outer zones |
| **ENDGAME** | Earth threatened | Pure evacuation, all ships protect transports |

The AI uses:
- `FCWActionEnumerator` - Discovers all valid actions at each decision point
- `FCWStateEvaluator` - Ranks actions by expected impact on lives saved
- Phase detection - Adapts strategy as Herald advances

### Batch Simulation

Run many games to test strategies:

```gdscript
# Compare strategies across 100 games
var comparison = FCWHeadlessRunner.compare_strategies([
    {"name": "Passive", "strategy": FCWHeadlessRunner.strategy_passive()},
    {"name": "Defend Earth", "strategy": FCWHeadlessRunner.strategy_defend_earth()},
    {"name": "Forward Defense", "strategy": FCWHeadlessRunner.strategy_forward_defense()}
], 100)
FCWHeadlessRunner.print_comparison_summary(comparison)
```

See `docs/expansions/fcw-architecture.md` section 19 for full API documentation.

---

## Architecture Reference

For detailed technical architecture including:
- Complete state shape
- Signal flow diagrams
- Module dependencies
- Data flow patterns
- **Deterministic simulation infrastructure** (Section 19)
- **Testing determinism** (Section 20)

See: `docs/expansions/fcw-architecture.md`

---

*"Spartans never die. They're just missing in action."*
