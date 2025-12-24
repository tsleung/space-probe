# Mars Colony Sim (MCS) Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              MCS ARCHITECTURE                                │
└─────────────────────────────────────────────────────────────────────────────┘

┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   MCS_UI     │────▶│  MCS_STORE   │────▶│ MCS_REDUCER  │
│  (Control)   │◀────│   (State)    │◀────│   (Logic)    │
└──────────────┘     └──────────────┘     └──────────────┘
       │                    │                    │
       │                    │                    ▼
       │                    │           ┌──────────────────┐
       │                    │           │  PURE SYSTEMS    │
       │                    │           ├──────────────────┤
       │                    │           │ • MCS_Population │
       │                    │           │ • MCS_Economy    │
       │                    │           │ • MCS_Politics   │
       │                    │           │ • MCS_Events     │
       │                    │           └──────────────────┘
       │                    │
       ▼                    ▼
┌──────────────┐     ┌──────────────┐
│  MCS_VIEW    │     │   MCS_AI     │
│ (Isometric)  │     │ (Governor)   │
└──────────────┘     └──────────────┘
```

---

## Core Files

| File | Role | Lines |
|------|------|-------|
| `mcs_ui.gd` | Main controller, game loop, UI sync | ~1200 |
| `mcs_store.gd` | State container, signals, persistence | ~500 |
| `mcs_reducer.gd` | Pure state transformations | ~1000 |
| `mcs_types.gd` | Enums, factories, constants | ~800 |
| `mcs_view.gd` | Isometric 2.5D renderer | ~680 |
| `mcs_ai.gd` | AI governor decision making | ~150 |
| `mcs_population.gd` | Birth/death/aging simulation | ~150 |
| `mcs_economy.gd` | Resource production/consumption | ~100 |
| `mcs_politics.gd` | Stability, factions, elections | ~100 |
| `mcs_events.gd` | Event definitions and triggers | ~100 |

---

## Data Flow

```
User Input / AI Decision
         │
         ▼
    ┌─────────┐
    │ ACTION  │  (e.g., ADVANCE_YEAR, BUILD, RESOLVE_EVENT)
    └────┬────┘
         │
         ▼
┌─────────────────┐
│   MCS_STORE     │
│  dispatch()     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  MCS_REDUCER    │  Pure function: (state, action) → new_state
│  reduce()       │
└────────┬────────┘
         │
         ├──────────────────────────────────────┐
         ▼                                      ▼
┌─────────────────┐                    ┌─────────────────┐
│ MCS_POPULATION  │                    │  MCS_ECONOMY    │
│ advance_year()  │                    │ calc_production │
└─────────────────┘                    └─────────────────┘
         │                                      │
         └──────────────┬───────────────────────┘
                        ▼
              ┌─────────────────┐
              │   NEW STATE     │
              └────────┬────────┘
                       │
                       ▼
              ┌─────────────────┐
              │ state_changed   │  Signal emitted
              │    signal       │
              └────────┬────────┘
                       │
         ┌─────────────┴─────────────┐
         ▼                           ▼
┌─────────────────┐         ┌─────────────────┐
│    MCS_UI       │         │   MCS_VIEW      │
│   _sync_ui()    │         │ update_state()  │
└─────────────────┘         └─────────────────┘
```

---

## State Shape

```gdscript
state = {
    # Time
    current_year: int,           # 1+
    phase: ColonyPhase,          # SURVIVAL → GROWTH → SOCIETY → INDEPENDENCE

    # Population
    colonists: [                 # Array of colonist dicts
        {
            id: String,
            display_name: String,
            age: int,
            generation: Generation,    # EARTH_BORN, FIRST_GEN, SECOND_GEN, THIRD_GEN_PLUS
            life_stage: LifeStage,     # INFANT, CHILD, ADOLESCENT, ADULT, ELDER
            specialty: Specialty,       # ENGINEER, SCIENTIST, MEDIC, etc.
            health: float,
            morale: float,
            traits: [TraitType],
            relationships: {},
            is_alive: bool,
        },
        ...
    ],

    # Resources
    resources: {
        food: float,
        water: float,
        oxygen: float,
        fuel: float,
        building_materials: float,
        machine_parts: float,
        medicine: float,
    },

    # Infrastructure
    buildings: [
        {
            id: String,
            type: BuildingType,
            is_operational: bool,
            construction_progress: float,  # 0.0 - 1.0
            condition: float,
            assigned_workers: [colonist_ids],
            worker_capacity: int,
        },
        ...
    ],

    # Politics
    politics: {
        system: PoliticalSystem,       # MISSION_COMMAND → INDEPENDENT_STATE
        stability: float,              # 0-100
        independence_sentiment: float, # 0-100
        faction_standings: {Faction: float},
        current_leader: String,
        ruling_faction: Faction,
        last_election_year: int,
    },

    # Events
    active_events: [event_dicts],
    resolved_events: [event_ids],

    # Log
    colony_log: [{year, message, log_type}],
}
```

---

## UI Layout

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ MARS COLONY    Era: Survival         Year 3, Day 1    Pop: 24    Stab: 100%│
├───────────────┬─────────────────────────────────────────┬───────────────────┤
│  LEFT PANEL   │              CENTER PANEL               │   RIGHT PANEL     │
│  (180px)      │              (Flexible)                 │   (220px)         │
├───────────────┼─────────────────────────────────────────┼───────────────────┤
│               │                                         │                   │
│  Resources    │     ┌───────────────────────────┐      │  Active Event     │
│  ─────────    │     │                           │      │  ────────────     │
│  Food: 9794   │     │                           │      │  First Martian    │
│  Water: 5209  │     │    ISOMETRIC COLONY VIEW  │      │  A baby has been  │
│  O2: 2551     │     │                           │      │  born...          │
│  Fuel: 800    │     │         [LP]              │      │                   │
│  Materials    │     │        /    \             │      │  [Choice 1]       │
│  Parts        │     │      [H]    [G]           │      │  [Choice 2]       │
│  Medicine     │     │                           │      │                   │
│               │     └───────────────────────────┘      │  ─────────────    │
│  Buildings    │                                         │  Chronicle        │
│  ──────────   │  ┌─────────────────────────────────┐   │  ──────────       │
│  Hab Pod      │  │ Colonists │ Stats │ Politics   │   │  [Year 1] Colony  │
│  Greenhouse   │  ├─────────────────────────────────┤   │  founded...       │
│  Solar Array  │  │ Population details / stats      │   │  [Year 2] First   │
│  ...          │  │                                 │   │  Martian born...  │
│               │  └─────────────────────────────────┘   │                   │
│  [Build]      │                                         │                   │
│  [Repair]     │                                         │                   │
├───────────────┴─────────────────────────────────────────┴───────────────────┤
│ [Auto] [AI Spectate ▼] [Visionary ▼] [Speed: ====●====] [3x] [Save] [Menu]  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Game Loop (Idle Mode)

```
_process(delta):
    │
    ├─► Accumulate _game_days += delta * _time_scale
    │
    ├─► Update colony_view.set_game_time() for animations
    │
    └─► If NEW YEAR crossed:
            │
            ├─► AI resolves pending events
            │
            ├─► store.advance_year()
            │       │
            │       └─► reducer._reduce_advance_year()
            │               ├─► Population phase (births, deaths, aging)
            │               ├─► Economy phase (production, consumption)
            │               ├─► Building maintenance (degradation)
            │               ├─► Politics phase (stability, factions)
            │               ├─► Phase transition check
            │               ├─► Event triggers
            │               └─► Victory/loss check
            │
            ├─► auto_assign_workers()
            │
            ├─► auto_repair_all()
            │
            ├─► AI maybe builds (60% Visionary, 40% others)
            │
            └─► Trigger random visual events
```

---

## Building Types (22)

| Category | Buildings | Production |
|----------|-----------|------------|
| **Housing** | Hab Pod, Apartment Block, Luxury Quarters, Barracks | Beds |
| **Food** | Greenhouse, Hydroponics, Protein Vats | Food/yr |
| **Power** | Solar Array, Wind Turbine, RTG, Fission Reactor | Power |
| **Water** | Water Extractor | Water/yr |
| **Life Support** | Oxygenator | Oxygen/yr |
| **Industry** | Workshop, Factory, Storage | Parts, Repairs |
| **Medical** | Medical Bay, Hospital | Health |
| **Science** | Lab, Research Center | Research |
| **Education** | School, University | Skills |
| **Social** | Recreation Center, Temple | Morale, Stability |
| **Governance** | Government Hall | Politics |
| **Infrastructure** | Landing Pad | Trade |

---

## Colony Phases

```
SURVIVAL (Year 1-10)
    │  • Focus: Don't die
    │  • Challenges: Resource scarcity
    │  • Buildings: Basic life support
    │
    ▼ (Pop > 30 AND Year > 5)

GROWTH (Year 10-30)
    │  • Focus: Expand population
    │  • Challenges: Housing, food scaling
    │  • Buildings: More production
    │
    ▼ (Pop > 100 AND Year > 15)

SOCIETY (Year 30-60)
    │  • Focus: Civilization
    │  • Challenges: Politics, factions
    │  • Buildings: Social, governance
    │
    ▼ (Pop > 300 AND Year > 40)

INDEPENDENCE (Year 60+)
    │  • Focus: Self-sufficiency
    │  • Challenges: Independence vote
    │  • Buildings: Megastructures
    │
    ▼ Victory Conditions:
       • Independence + 1000 pop, OR
       • 100 years + 500 pop
```

---

## AI Governor Personalities

| Personality | Building Priority | Event Choices | Style |
|-------------|-------------------|---------------|-------|
| **Pragmatist** | Balanced, reactive | Safe, practical | Risk-averse |
| **Visionary** | Growth-focused, aggressive | Bold, long-term | 60% build rate |
| **Humanist** | Housing, medical, social | People-first | Morale-focused |
| **Cautious** | Infrastructure, safety | Conservative | Slow and steady |

---

## Isometric View System

```
World Space (400x400 units)          Screen Space
    Y-
    │                                 ┌───────┐
    │    (0,0)                        │  NW   │ ← _iso_transform(0,0,0)
    │      ┌──────┐                   │   ◇   │
    │      │      │                  ╱│  ╱ ╲  │╲
    └──────┤ MAP  ├─────X+          ╱ │ ╱   ╲ │ ╲
           │      │               SW  │╱     ╲│  NE
           └──────┘                   ◇───────◇
              │                        ╲     ╱
              │                         ╲   ╱
           (400,400)                     ╲ ╱
                                          ◇ SE

_iso_transform(x, y, z):
    screen_x = (x - y) * 2.0      # Diamond shape
    screen_y = (x + y) * 1.0 - z  # Z goes up
```

### Height Progression

```
                    ╔═══╗
                    ║   ║ Space Elevator (200+ units)
                    ║   ║
                    ╠═══╣
                    ║   ║ Arcology (90 units)
                    ╠═══╣
                    ║   ║ Apartment Block (35 units)
                 ╔══╬═══╬══╗
                 ║  ║   ║  ║ Factory (18 units)
              ╔══╬══╬═══╬══╬══╗
              ║  ║  ║   ║  ║  ║ Greenhouse (8 units)
           ═══╬══╬══╬═══╬══╬══╬═══ Solar Array (2 units)
           ───┴──┴──┴───┴──┴──┴─── Ground (0)
           ═══════════════════════ Tunnels (-3 units)
```

### Tier Multipliers

| Colony Phase | Height Multiplier | Visual Effect |
|--------------|-------------------|---------------|
| Survival | 0.7x | Low, huddled structures |
| Growth | 1.0x | Normal heights |
| Society | 1.4x | Taller, developed |
| Independence | 1.8x | Skyscrapers appear |
| Transcendence | 2.5x | Megastructures tower |

---

## Signal Flow

```
MCS_STORE signals:
    state_changed(state)      → MCS_UI._sync_ui()
    year_advanced(year)       → MCS_UI._on_year_advanced()
    game_ended(victory, msg)  → MCS_UI._on_game_ended()
    log_entry_added(entry)    → MCS_UI._add_log_entry()

MCS_UI internal:
    _process(delta)           → Time accumulation, AI decisions
    _sync_ui()                → Update all UI elements
    _on_speed_changed(val)    → Adjust _time_scale
```

---

## Future Expansion Points

### Near-term
- [ ] More events with rich narrative content
- [ ] Building upgrade paths
- [ ] Trade system with Earth
- [ ] Relationship mechanics between colonists

### Mid-term
- [ ] Multiple colony sites
- [ ] Disasters / crisis events
- [ ] Tech tree / research system
- [ ] Expedition system

### Long-term
- [ ] Terraforming progress
- [ ] Rival factions / conflict
- [ ] Megastructure construction animations
- [ ] Procedural colonist stories
