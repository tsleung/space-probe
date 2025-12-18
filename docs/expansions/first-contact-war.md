# FCW (First Contact War) - Game Design Document

**Version:** 2.0 (Updated December 2025)
**Core Fantasy:** Humanity's desperate last stand against an overwhelming alien invasion
**Inspiration:** Halo Reach (noble sacrifice, losing battle fought with honor)
**Gameplay:** Mindustry (production chains) + Sins of a Solar Empire (fleet allocation)

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

### Continuous Time System

The game features continuous time progression between turns:

```
Time Display: "WEEK X, DAY Y - HH:00"

Speed Multipliers:
- PAUSED: 0x (game stopped)
- SLOW: 0.5x (16 seconds/week)
- NORMAL: 1x (8 seconds/week)
- FAST: 2x (4 seconds/week)
- VERY FAST: 4x (2 seconds/week)

Within each week:
- 7 days, 24 hours/day
- Clock visibly ticks
- Fleet positions interpolate smoothly
- No instant teleportation
```

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

**Fleet Orders:**
- **DEFEND** - Full combat power vs attackers
- **DELAY** - Half power, slows Herald advance if successful
- **ESCORT** - Protects evacuation convoys

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

### Continuous Time System

**Problem:** Discrete turn jumps felt jarring; players couldn't see time passing.

**Solution:** Implemented continuous time flow:
- Visible clock: "WEEK X, DAY Y - HH:00"
- Time flows smoothly between weeks
- All ship movements interpolate based on time progress
- Speed controls: Paused / Slow / Normal / Fast / Very Fast

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

*"Spartans never die. They're just missing in action."*
