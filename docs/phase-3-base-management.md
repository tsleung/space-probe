# Phase 3: Base Management

**Core Fantasy:** Colony Governor
**Primary Tension:** Scientific Goals vs Survival
**Design Inspiration:** Rimworld meets The Martian's survival sequences

## Overview

You've made it to Mars. Now the real mission begins. Establish a base, keep your crew alive, and complete the scientific objectives that justified this billion-dollar mission. Every sol (Martian day) is a balance between ambition and survival.

## The Colony Governor Fantasy

Why "colony governor"?
- You're building something new on hostile ground
- Resource scarcity demands prioritization
- Every decision trades safety for progress
- The crew looks to you for leadership
- Success means leaving a legacy

## The Martian Environment

### Mars Facts (The Martian accuracy)

| Factor | Value | Impact |
|--------|-------|--------|
| Gravity | 0.38g | Movement, construction affected |
| Temperature | -60°C average | Heating critical |
| Atmosphere | 95% CO2, 0.6% pressure | No breathable air |
| Sol length | 24h 37m | Slightly longer days |
| Dust storms | Seasonal | Major hazard events |
| Radiation | High | Health degradation |

### Landing Site Selection

Chosen at end of Phase 2, affects Phase 3:

| Site Type | Resources | Hazards | Science Bonus |
|-----------|-----------|---------|---------------|
| **Polar Region** | Water ice abundant | Extreme cold | Ice core samples |
| **Valles Marineris** | Geological diversity | Unstable terrain | Canyon geology |
| **Olympus Mons Region** | Volcanic samples | Altitude, thin air | Volcanic science |
| **Jezero Crater** | Ancient lake bed | Dust storms | Biosignature potential |
| **Acidalia Planitia** | Flat, safe | Few resources | Ease of operations |

## Base Construction

### Starting Assets

Deployed from ship cargo:
- Habitation module (pre-fab shelter)
- Oxygenator (CO2 → O2 conversion)
- Water reclaimer
- Food storage
- Equipment storage
- Solar panels
- Wind turbines (if brought)
- Batteries
- 2 Rovers

### Base Layout

Similar hex-grid to ship building, but on Martian surface:

```
    [SOL] [SOL] [SOL]
  [BAT] [HAB] [OXY] [   ]
    [STO] [LAB] [GRN]
  [ROV] [AIR] [WAT] [   ]
    [   ] [   ] [   ]
```

### Constructible Modules

| Module | Function | Requirements |
|--------|----------|--------------|
| **Solar Array** | Power generation | Sunlight, clear of dust |
| **Wind Turbine** | Backup power | Wind exposure |
| **Greenhouse** | Food production | Water, power, seeds |
| **Water Extractor** | Mine ice/atmosphere | Power, location-dependent |
| **Workshop** | Repairs, fabrication | Power, materials |
| **Laboratory** | Science experiments | Power, equipment |
| **Radiation Shelter** | Storm protection | Materials |
| **Communications** | Earth contact | Power |
| **Airlock** | EVA access | Required for outside work |

### Construction Requirements

Building new modules requires:
- **Materials:** Salvaged from ship, local resources, or cargo
- **Time:** Crew labor (sols)
- **Power:** Construction equipment
- **Expertise:** Engineer skill check

## Daily Operations

### Sol Structure

Each sol (Martian day):
1. Morning briefing - status report, weather forecast
2. Task assignment - allocate crew to activities
3. Operations - tasks execute, events occur
4. Evening report - results, resource update
5. Night cycle - some systems continue, crew rests

### Task Categories

**Survival Tasks:**
- Life support maintenance
- Food/water management
- Base repairs
- Power monitoring

**Science Tasks:**
- Sample collection (EVA required)
- Laboratory analysis
- Data transmission to Earth
- Experiment monitoring

**Expansion Tasks:**
- Module construction
- Rover expeditions
- Resource prospecting
- System upgrades

### EVA System

Outside excursions are dangerous but necessary:

| EVA Factor | Consideration |
|------------|---------------|
| **Suit time** | Limited O2 supply (6-8 hours) |
| **Radiation** | Cumulative exposure |
| **Dust** | Suit degradation |
| **Distance** | Rover vs walking range |
| **Buddy system** | Solo EVA = higher risk |

## Resource Management

### Critical Resources

| Resource | Source | Consumption | Emergency |
|----------|--------|-------------|-----------|
| **Oxygen** | Oxygenator, reserves | Constant | Fatal in hours |
| **Water** | Extractor, ice mining, reclaimer | Per person/sol | Fatal in days |
| **Food** | Storage, greenhouse | Per person/sol | Starvation timeline |
| **Power** | Solar, wind, batteries | Per system | Cascading failures |

### Resource Production

**Greenhouse:**
- Grows food over time (potatoes, anyone?)
- Requires water, power, attention
- Risk: crop failure, contamination
- Long-term sustainability path

**Water Extraction:**
- Polar sites: mine ice
- Other sites: atmospheric extraction (slower)
- Water recycler recovers ~90%

**Power Generation:**
- Solar: high output, dust accumulation problem
- Wind: backup, less affected by dust
- Batteries: buffer for night/storms

## The Science Mission

### Why Are We Here?

The mission has scientific objectives - completing them is the win condition.

### Experiment Categories

**Geology:**
- Soil composition analysis
- Core samples
- Seismic monitoring
- Mineral identification

**Atmosphere:**
- Air composition sampling
- Weather pattern recording
- Dust storm tracking
- Pressure monitoring

**Ice/Water:**
- Water ice extraction
- Subsurface ice mapping
- Ancient water evidence
- Isotope analysis

**Biosignatures:**
- Organic compound search
- Microbial life detection
- Fossil evidence
- Contamination prevention

### Science Workflow

1. **Collection:** EVA to gather samples
2. **Analysis:** Lab time to process
3. **Documentation:** Record findings
4. **Transmission:** Send data to Earth
5. **Validation:** Earth confirms receipt

### Science Points

Experiments generate science points:
- Primary objectives = large point values
- Secondary discoveries = bonus points
- Final score partly determined by science output
- Some experiments require specific equipment (Phase 1 choices matter)

## Event System

### Mars Events

**Environmental:**
- Dust storm (blocks solar, limits EVA)
- Temperature extreme (heating crisis)
- Radiation event (shelter or exposure)
- Equipment failure (maintenance check)

**Discovery Events:**
- Unusual geological formation
- Potential water source
- Anomalous reading (investigate?)
- Cave system discovered

**Crew Events:**
- Illness (limited medical supplies)
- Injury during EVA
- Psychological stress (isolation)
- Conflict over priorities

**Earth Events:**
- Mission update (objective change)
- Supply drop possibility (if budget allows)
- Family news (morale impact)
- Public attention (pressure)

### The Great Dust Storm

A major narrative event that occurs in most playthroughs:
- Extended dust storm (weeks)
- Solar power drops to minimal
- EVA impossible
- Crew confined to habitat
- Tests all systems and relationships

## Crew Dynamics

### Long-Term Isolation

Phase 3 is the longest phase - crew dynamics matter:
- Relationships evolve
- Personal missions come due
- Specialties become critical
- One sick crew member = major problem

### Role Criticality

| Role | Phase 3 Importance |
|------|-------------------|
| **Engineer** | Critical - repairs, construction |
| **Scientist** | Critical - experiment execution |
| **Medical** | Important - health maintenance |
| **Pilot** | Reduced - prep for Phase 4 |

### Morale Factors

Positive:
- Scientific discoveries
- Communication with Earth/family
- Successful EVAs
- Good food variety
- Personal space

Negative:
- Monotony
- Equipment failures
- Isolation duration
- Crew conflict
- Earth feels far away

## The Return Preparation

### MAV Readiness

The Mars Ascent Vehicle must be prepared:
- Fuel production (ISRU if equipped)
- System checks
- Weight calculations
- Launch window tracking

### Departure Decision

When to leave Mars:
- Minimum stay for science objectives
- Maximum stay before return window closes
- Crew health/morale considerations
- MAV fuel status

## Failure States

### Mission-Ending

- Total life support failure
- Total crew loss
- MAV destroyed/non-functional
- Base abandoned (unable to return)

### Partial Failures

- Crew member death (continue with fewer)
- Experiment failures (reduced score)
- Equipment loss (adaptation required)
- Early departure (reduced science)

## UI Elements

### Main Display

- Base hex grid (center)
- Resource bars (top)
- Sol counter / return window timer (top right)
- Crew cards with task assignments (bottom)
- Weather forecast (top left)
- Alert log (right sidebar)

### Map View

- Landing site overview
- Explored areas
- Sample collection sites
- Rover range indicators
- Points of interest

### Science Panel

- Experiment checklist
- Sample inventory
- Analysis queue
- Science points tracker
- Transmission log

## Replayability Elements

- Different landing sites = different challenges
- Random events and discoveries
- Science objective variations
- Crew composition effects
- Multiple viable strategies (safe vs ambitious)
- Achievements for special accomplishments
