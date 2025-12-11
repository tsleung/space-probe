# Data Schema

How Space Probe stores game data. Simple, readable formats for easy modding and debugging.

---

## Design Principles

### Human-Readable First
- JSON or similar structured format
- Meaningful field names
- Comments where helpful
- Easy to inspect and modify

### Separation of Concerns
- Static data (components, events) separate from runtime state
- Content files separate from save files
- Configuration separate from gameplay data

### Modding-Friendly
- Clear file locations
- Documented schemas
- Override system for custom content

---

## File Organization

```
space-probe/
├── data/
│   ├── components/
│   │   ├── engines.json
│   │   ├── life_support.json
│   │   ├── crew_modules.json
│   │   └── special.json
│   ├── events/
│   │   ├── phase1_events.json
│   │   ├── phase2_events.json
│   │   ├── phase3_events.json
│   │   └── phase4_events.json
│   ├── crew/
│   │   └── default_crew.json
│   ├── difficulty/
│   │   └── settings.json
│   └── text/
│       ├── en.json
│       └── [other languages].json
├── saves/
│   └── [save files].json
└── config/
    └── settings.json
```

---

## Core Data Structures

### Component Schema

```json
{
  "id": "engine_nuclear",
  "name": "Nuclear Thermal",
  "category": "engine",
  "description": "High thrust nuclear engine. Efficient but requires shielding.",

  "stats": {
    "cost": 85000000,
    "build_days": 25,
    "mass": 15,
    "base_quality": 55
  },

  "requirements": {
    "min_crew": 0,
    "power_draw": 5,
    "prerequisite_components": []
  },

  "effects": {
    "thrust": 200,
    "efficiency": 0.85,
    "travel_time_modifier": 0.75
  },

  "placement": {
    "hex_size": 2,
    "must_be_rear": true,
    "adjacent_requirements": ["fuel_tank"]
  },

  "failure_modes": [
    {
      "id": "coolant_leak",
      "description": "Coolant system malfunction",
      "base_probability": 0.02,
      "consequence": "radiation_exposure"
    },
    {
      "id": "thrust_loss",
      "description": "Reduced thrust output",
      "base_probability": 0.05,
      "consequence": "travel_delay"
    }
  ]
}
```

### Crew Schema

```json
{
  "id": "santos",
  "name": "Maria Santos",
  "role": "commander",
  "age": 42,
  "nationality": "Brazilian-American",

  "portrait": "res://assets/crew/santos.png",

  "stats": {
    "piloting": 85,
    "leadership": 75,
    "engineering": 45,
    "science": 40,
    "medical": 35
  },

  "traits": [
    {
      "id": "steady_under_pressure",
      "name": "Steady Under Pressure",
      "description": "No performance penalty in crisis",
      "effect": {
        "crisis_penalty": 0
      }
    },
    {
      "id": "perfectionist",
      "name": "Perfectionist",
      "description": "Takes longer but higher quality results",
      "effect": {
        "task_time_modifier": 1.25,
        "task_quality_modifier": 1.15
      }
    },
    {
      "id": "private",
      "name": "Private",
      "description": "Slower to open up, but deep loyalty once trust is built",
      "effect": {
        "relationship_gain_modifier": 0.75,
        "max_relationship_bonus": 1.2
      }
    }
  ],

  "background": {
    "short": "Former Navy pilot, first in her family to go to college.",
    "full": "Widowed - husband died in a car accident three years ago...",
    "motivation": "To lead a successful mission. To feel like the sacrifice was worth it."
  },

  "relationships": {
    "chen": { "trust": 60, "type": "respect" },
    "okonkwo": { "trust": 45, "type": "friction" },
    "kowalski": { "trust": 55, "type": "protective" }
  },

  "arc_events": ["santos_anniversary", "santos_crisis", "santos_resolution"]
}
```

### Event Schema

```json
{
  "id": "solar_flare_warning",
  "phase": 2,
  "category": "space",

  "title": "Solar Flare Warning",
  "description": "Sensors detect an incoming solar flare. The radiation will reach the ship in approximately 8 hours.",

  "trigger": {
    "type": "random",
    "base_probability": 0.03,
    "day_range": [20, 180],
    "conditions": [
      { "type": "not_active", "event": "solar_flare_warning" },
      { "type": "has_component", "component": "sensors", "optional": true }
    ]
  },

  "choices": [
    {
      "id": "shelter",
      "text": "Order all crew to radiation shelter",
      "requirements": {
        "components": ["radiation_shelter"]
      },
      "outcomes": [
        {
          "probability": 0.9,
          "description": "The shelter protects the crew effectively.",
          "effects": {
            "crew_health": -5,
            "time_lost": 1
          }
        },
        {
          "probability": 0.1,
          "description": "Minor exposure despite shelter.",
          "effects": {
            "crew_health": -15,
            "time_lost": 1
          }
        }
      ]
    },
    {
      "id": "rotate_ship",
      "text": "Use the ship's hull as a shield",
      "requirements": {},
      "outcomes": [
        {
          "probability": 0.6,
          "description": "The maneuver works. Most radiation is blocked.",
          "effects": {
            "crew_health": -10,
            "fuel": -5
          }
        },
        {
          "probability": 0.4,
          "description": "Partial success. Significant exposure.",
          "effects": {
            "crew_health": -25,
            "fuel": -5,
            "trigger_event": "radiation_sickness"
          }
        }
      ]
    },
    {
      "id": "continue_normal",
      "text": "Continue normal operations (risky)",
      "requirements": {},
      "outcomes": [
        {
          "probability": 0.3,
          "description": "The flare was weaker than expected.",
          "effects": {
            "crew_health": -15
          }
        },
        {
          "probability": 0.7,
          "description": "Severe radiation exposure.",
          "effects": {
            "crew_health": -40,
            "trigger_event": "radiation_sickness",
            "crew_injury": { "random": true, "severity": "moderate" }
          }
        }
      ]
    }
  ],

  "followup": {
    "id": "solar_flare_aftermath",
    "delay_days": 1,
    "condition": "any_radiation_damage"
  }
}
```

### Save Game Schema

```json
{
  "version": "1.0.0",
  "timestamp": "2024-01-15T14:32:00Z",
  "mission_name": "Ares I",
  "difficulty": "standard",

  "current_phase": 2,
  "current_day": 47,

  "phase1_summary": {
    "budget_spent": 612000000,
    "budget_remaining": 88000000,
    "ship_avg_quality": 72,
    "days_used": 68,
    "components_installed": ["cockpit", "nuclear_engine", "crew_quarters_1", "..."]
  },

  "ship": {
    "components": [
      {
        "id": "cockpit",
        "hex_position": { "q": 0, "r": 0 },
        "current_quality": 78,
        "damage": 0,
        "active_failures": []
      }
    ],
    "total_mass": 145,
    "power_capacity": 120,
    "power_draw": 85
  },

  "crew": [
    {
      "id": "santos",
      "status": "healthy",
      "health": 92,
      "morale": 78,
      "current_task": "navigation",
      "injuries": [],
      "conditions": [],
      "relationship_changes": {
        "chen": +5,
        "okonkwo": +3
      }
    }
  ],

  "resources": {
    "food": { "current": 450, "max": 600, "daily_consumption": 8 },
    "water": { "current": 380, "max": 500, "daily_consumption": 12 },
    "oxygen": { "current": 290, "max": 400, "daily_consumption": 3.4 },
    "power": { "generation": 120, "consumption": 85 },
    "fuel": { "current": 850, "max": 1000 }
  },

  "mission_log": [
    {
      "day": 1,
      "phase": 2,
      "entry": "Launch successful. Journey to Mars begins.",
      "type": "milestone"
    },
    {
      "day": 23,
      "phase": 2,
      "entry": "Minor water recycler issue. Chen repaired it.",
      "type": "event"
    }
  ],

  "active_events": [],
  "completed_events": ["launch_day", "first_week_adjustment"],
  "triggered_flags": ["chen_opened_up", "santos_anniversary_passed"]
}
```

---

## Runtime State

### Game State (In Memory)

```gdscript
class_name GameState

var current_phase: int = 1
var current_day: int = 1
var difficulty: String = "standard"

var ship: Ship
var crew: Array[CrewMember]
var resources: Resources
var mission_log: Array[LogEntry]

var active_events: Array[Event]
var event_cooldowns: Dictionary  # event_id -> days_remaining
var triggered_flags: Array[String]

var rng: RandomNumberGenerator
```

### Ship State

```gdscript
class_name Ship

var components: Array[PlacedComponent]
var hex_grid: HexGrid
var total_mass: float
var power_balance: float

func get_quality_average() -> float
func get_failure_probability(component_id: String) -> float
func apply_damage(component_id: String, amount: float)
func repair_component(component_id: String, crew: CrewMember)
```

### Crew State

```gdscript
class_name CrewMember

var id: String
var stats: Dictionary
var traits: Array[Trait]

var health: float = 100.0
var morale: float = 75.0
var stress: float = 0.0

var current_task: String = ""
var injuries: Array[Injury]
var conditions: Array[Condition]

var relationships: Dictionary  # crew_id -> trust_value
var arc_progress: Dictionary   # arc_event_id -> completed

func get_effective_skill(skill: String) -> float
func apply_stress(amount: float)
func heal(amount: float)
func change_relationship(other_id: String, amount: float)
```

---

## Configuration Files

### Difficulty Settings

```json
{
  "difficulties": {
    "relaxed": {
      "name": "Relaxed",
      "description": "More resources, fewer failures. Focus on the story.",
      "modifiers": {
        "starting_budget": 1.3,
        "resource_consumption": 0.75,
        "failure_rate": 0.5,
        "event_severity": 0.7,
        "crew_stat_decay": 0.6
      }
    },
    "standard": {
      "name": "Standard",
      "description": "The intended experience. Challenging but fair.",
      "modifiers": {
        "starting_budget": 1.0,
        "resource_consumption": 1.0,
        "failure_rate": 1.0,
        "event_severity": 1.0,
        "crew_stat_decay": 1.0
      }
    },
    "veteran": {
      "name": "Veteran",
      "description": "Tighter margins, harsher consequences.",
      "modifiers": {
        "starting_budget": 0.85,
        "resource_consumption": 1.2,
        "failure_rate": 1.5,
        "event_severity": 1.3,
        "crew_stat_decay": 1.25
      }
    }
  }
}
```

### Player Settings

```json
{
  "audio": {
    "master_volume": 0.8,
    "music_volume": 0.6,
    "effects_volume": 0.8,
    "alerts_volume": 1.0
  },
  "display": {
    "fullscreen": false,
    "resolution": "1920x1080",
    "vsync": true,
    "animations_enabled": true
  },
  "accessibility": {
    "colorblind_mode": "none",
    "reduced_motion": false,
    "screen_reader": false,
    "text_size": "medium"
  },
  "gameplay": {
    "auto_pause_on_event": true,
    "tutorial_hints": true,
    "confirm_dangerous_actions": true
  }
}
```

---

## Formulas Reference

### Quality Testing

```
quality_gain = 8 - (current_quality / 20)
test_cost = base_cost * (0.1 + quality_gain * 0.02)
test_time = 2 + floor(quality_gain / 3)
```

### Failure Probability

```
daily_failure_chance = base_rate * (100 - quality) / 50 * stress_modifier * wear_factor
where:
  base_rate = component.failure_modes[n].base_probability
  stress_modifier = 1.0 + (ship_stress * 0.5)
  wear_factor = 1.0 + (days_in_use / 200)
```

### Resource Consumption

```
daily_food = crew_count * 2.0 * activity_modifier
daily_water = crew_count * 3.0 * activity_modifier
daily_oxygen = crew_count * 0.84
daily_power = sum(component.power_draw) - sum(component.power_generation)
```

### Skill Checks

```
success_chance = base_difficulty + (skill / 100) * 0.5 + modifiers
where:
  modifiers = trait_bonus + equipment_bonus + relationship_bonus - stress_penalty
```

---

## Modding Support

### Override System

Custom content can override or extend base data:

```
mods/
└── my_mod/
    ├── mod.json           # Mod metadata
    ├── components/
    │   └── custom_engine.json
    ├── events/
    │   └── custom_events.json
    └── crew/
        └── custom_crew.json
```

### Mod Manifest

```json
{
  "id": "my_custom_mod",
  "name": "My Custom Mod",
  "version": "1.0.0",
  "author": "Modder Name",
  "description": "Adds new components and events.",
  "game_version_min": "1.0.0",

  "files": {
    "components": ["components/custom_engine.json"],
    "events": ["events/custom_events.json"],
    "crew": ["crew/custom_crew.json"]
  },

  "overrides": {
    "components/engines.json": "replace"
  }
}
```

---

## Validation

### Schema Validation Rules

**Components:**
- `id` must be unique
- `cost` must be > 0
- `base_quality` must be 0-100
- `hex_size` must be 1-4
- All referenced components in `adjacent_requirements` must exist

**Events:**
- `id` must be unique
- `phase` must be 1-4
- All choices must have at least one outcome
- Outcome probabilities must sum to 1.0
- Referenced events in `trigger_event` must exist

**Crew:**
- `id` must be unique
- All stat values must be 0-100
- Referenced crew in `relationships` must exist
- Arc events must exist in events data

### Validation Tool

Run during development:
```bash
godot --script validate_data.gd
```

Reports:
- Missing references
- Invalid values
- Orphaned data
- Balance warnings (e.g., component too cheap)

---

## Migration

### Version Updates

When schema changes between versions:

```json
{
  "migrations": [
    {
      "from": "0.9.0",
      "to": "1.0.0",
      "changes": [
        {
          "type": "rename_field",
          "path": "crew.*.health_points",
          "new_name": "health"
        },
        {
          "type": "add_field",
          "path": "crew.*",
          "field": "stress",
          "default": 0
        }
      ]
    }
  ]
}
```

Save files include version, and the game auto-migrates on load.

