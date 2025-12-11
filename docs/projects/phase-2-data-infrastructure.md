# Phase 2: Data Infrastructure

**Status:** Complete
**Duration:** Session 1

---

## Objective

Create the data layer - JSON files that define all game content. This separates game design (data) from game logic (code).

---

## Files Created

### Game Manifest
`data/games/mars_mission/manifest.json`

Defines the game's identity and configuration:
- Game ID, name, description
- Phase definitions
- Systems used (hex_grid, crew, resources, etc.)
- Core settings

### Engines
`data/games/mars_mission/engines.json`

9 engine types extracted from `engine_logic.gd`:

| Engine | Cost | Travel Modifier | Risk |
|--------|------|-----------------|------|
| Traditional Chemical | $40M | 1.0x | Low |
| HERMES Ion | $120M | 0.85x | Medium |
| Hall Thruster | $100M | 0.9x | Medium |
| Nuclear Thermal | $200M | 0.7x | High (radiation) |
| Solar Sail | $80M | 1.3x | Low |
| Laser Sail | $150M | 0.6x | Medium |
| Pulsed Plasma | $130M | 0.8x | Medium |
| MPD Thruster | $180M | 0.75x | Medium |
| VASIMR | $160M | 0.65x | Medium |

Each engine includes:
- Stats (cost, mass, thrust, ISP)
- Fuel configuration
- Testing parameters
- Special properties (radiation risk, variable thrust)

### Components
`data/games/mars_mission/components.json`

14 ship components extracted from `component_logic.gd`:

| Component | Cost | Required | Purpose |
|-----------|------|----------|---------|
| Cockpit | $50M | Yes | Command center |
| Engine Mount | $30M | Yes | Propulsion structure |
| Exercise Facility | $20M | No | Crew health |
| Cafeteria | $30M | No | Morale |
| Crew Quarters | $25M | Yes | Housing (1 per crew) |
| Cargo Bay | $20M | Yes | Supply storage |
| Hangar Bay | $60M | No | EVA/rover support |
| MAV Docking | $150M | Yes | Mars landing |
| Science Lab | $45M | No | Research bonus |
| Medical Bay | $40M | Yes | Healthcare |
| Life Support | $35M | Yes | Critical survival |
| Fuel Tank | $15M | Yes | Propellant storage |
| Solar Array | $25M | Yes | Power generation |
| Communications | $30M | Yes | Earth contact |

Each component includes:
- Stats (cost, mass, power, capacity)
- Testing parameters
- Degradation rates
- Special effects
- Placement rules

### Crew Roster
`data/games/mars_mission/crew_roster.json`

10 pre-defined crew members extracted from `crew_roster.gd`:

| Name | Role | Personality | Key Trait |
|------|------|-------------|-----------|
| Dr. Sarah Chen | Commander | LEADER | Stability |
| Cmdr. Adaeze Okonkwo | Commander | STOIC | Emotional control |
| Lt. Carlos Reyes | Pilot | RISK_TAKER | High reward |
| Maj. Katya Volkov | Pilot | CAUTIOUS | Safety |
| Eng. Miguel Santos | Engineer | OPTIMIST | Morale resilience |
| Dr. Ji-yeon Kim | Engineer | LONER | Solo efficiency |
| Dr. Vikram Patel | Scientist | CURIOUS | Discovery bonus |
| Dr. Astrid Johansson | Scientist | HOMESICK | Earth contact bonus |
| Dr. James Thompson | Medic | CARETAKER | Medical bonus |
| Dr. Yuki Nakamura | Medic | PESSIMIST | Negative resilience |

Each crew member includes:
- Skills (piloting, engineering, science, medical, leadership)
- Base stats (health, morale)
- Traits with mechanical effects
- Background and motivation
- Pre-defined relationships

### Balance Configuration
`data/games/mars_mission/balance.json`

All magic numbers extracted from multiple logic files:

**Sections:**
- `difficulty` - Per-difficulty modifiers
- `phase1` - Ship building balance
- `phase2` - Travel to Mars balance
- `phase3` - Mars base balance
- `phase4` - Return trip balance
- `crew` - Crew stat thresholds and formulas
- `components` - Component degradation and repair
- `activities` - Task effects
- `events` - Event damage ranges
- `scoring` - Victory conditions and tiers
- `formulas` - Math formulas as strings

**Key Numbers:**
```
Starting Budget: $650M (normal)
Days to Window: 75 (normal)
Base Travel Days: 180
Daily Food/Crew: 2.0 kg
Daily Water/Crew: 3.0 L
Daily Oxygen/Crew: 0.84 kg
Base Event Chance: 12%
```

### Events by Phase

**Phase 1 Events** (`events/phase1.json`)
- Congressional Budget Review
- Contractor Supply Delay
- Technology Breakthrough
- Crew Training Incident
- Documentary Crew Request

**Phase 2 Events** (`events/phase2.json`)
- Solar Particle Event
- Micrometeorite Impact
- Crew Disagreement
- Medical Emergency
- Oxygen System Alert
- Birthday in Space
- Earth Visible
- Halfway to Mars

**Phase 3 Events** (`events/phase3.json`)
- Dust Storm Approaching
- Anomalous Sensor Reading
- EVA Emergency
- Water Ice Discovery

**Phase 4 Events** (`events/phase4.json`)
- System Cascade Warning
- Food Supplies Critical
- Earth Contact Restored
- Reentry Systems Check

Each event includes:
- Trigger conditions (random, time-based, resource-based)
- Multiple choices with requirements
- Weighted outcomes with effects
- Log messages

### Shared Content

**Traits** (`data/shared/traits.json`)
10 personality traits with mechanical effects

**Conditions** (`data/shared/conditions.json`)
12 status conditions (injuries, illnesses, states)

**Difficulty Settings** (`data/difficulty.json`)
4 difficulty levels with multipliers

---

## Data Structure Summary

```
data/
├── games/
│   └── mars_mission/
│       ├── manifest.json        # Game identity
│       ├── engines.json         # 9 engines
│       ├── components.json      # 14 components
│       ├── crew_roster.json     # 10 crew
│       ├── balance.json         # All numbers
│       └── events/
│           ├── phase1.json      # 5 events
│           ├── phase2.json      # 8 events
│           ├── phase3.json      # 4 events
│           └── phase4.json      # 4 events
├── shared/
│   ├── traits.json              # 10 traits
│   └── conditions.json          # 12 conditions
└── difficulty.json              # 4 difficulties
```

---

## Benefits for LLM Development

### Adding New Content

```
Before: Edit GDScript, risk breaking logic
After:  Edit JSON, validated automatically

Example: Add new engine
1. Open engines.json
2. Copy existing engine structure
3. Modify values
4. Save
```

### Balancing

```
Before: Hunt for magic numbers across files
After:  All numbers in balance.json

Example: Make game harder
1. Open balance.json
2. Find phase2.base_event_chance
3. Change 0.12 to 0.15
4. Save
```

### Adding Events

```
Before: Write GDScript for each event
After:  Define event in JSON

Example: Add "Meteor Shower" event
1. Open events/phase2.json
2. Add new event object with:
   - Trigger conditions
   - Choices with outcomes
   - Effects as data
3. Engine automatically handles it
```

---

## Schema Reference

### Event Schema
```json
{
  "id": "unique_id",
  "title": "Display Title",
  "category": "crew|ship|space|environment|discovery",
  "description": "What the player sees",
  "trigger": {
    "type": "random|day_reached|resource_below",
    "base_probability": 0.03,
    "conditions": [...]
  },
  "choices": [
    {
      "id": "choice_id",
      "text": "Button text",
      "requirements": [...],
      "outcomes": [
        {
          "weight": 0.7,
          "description": "What happens",
          "effects": [
            {"type": "crew_health", "target": "all", "amount": -10}
          ]
        }
      ]
    }
  ]
}
```

### Effect Types
- `crew_health` - Change crew health
- `crew_morale` - Change crew morale
- `crew_fatigue` - Change crew fatigue
- `resource` - Change resource amount
- `component_damage` - Damage component
- `component_repair` - Repair component
- `time` - Skip time
- `budget` - Change budget
- `samples` - Add samples
- `set_flag` - Set game flag
- `log` - Add log entry

---

## Validation

The `SchemaValidator` checks:
- Required fields present
- Values in valid ranges
- Cross-references valid
- Outcome weights sum correctly

Errors are warnings, not blockers - allows iteration.

---

## Next Steps

Phase 3 will extract the pure logic systems:
- HexGridSystem
- ResourceSystem
- CrewSystem
- ComponentSystem
- EventSystem

These systems will read from loaded game data and implement the formulas defined in balance.json.
