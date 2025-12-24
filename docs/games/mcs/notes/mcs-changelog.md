# MCS (Mars Colony Sim): Development Changelog

## December 2024 - Major Update

### Summary
Fixed all GDScript 4.x compatibility issues, implemented visual effects system, and added UI transparency features. Colony sim now runs with AI autoplay and dynamic visual storytelling.

---

## Bug Fixes

### GDScript 4.x Reserved Keyword Fix
**File:** `scripts/colonysim/colonysim_population.gd`

`trait` is a reserved keyword in GDScript 4.x. Changed all loop variables:

```gdscript
# Lines 353, 448, 536, 593 - Changed:
for trait in all_parent_traits:
# To:
for t in all_parent_traits:
```

### Dictionary Access Pattern Fixes
GDScript 4.x cannot use dot notation (`.key`) to read Dictionary values. Must use `.get("key", default)`.

**File:** `scripts/colonysim/colonysim_store.gd`
- All getter methods updated to use `.get()` pattern
- Examples:
  - `_state.colonists` → `_state.get("colonists", [])`
  - `_state.resources` → `_state.get("resources", {})`
  - `_state.politics.stability` → `_state.get("politics", {}).get("stability", 75.0)`

**File:** `scripts/colonysim/colonysim_reducer.gd`
- ~50+ fixes across all reducer functions
- Every Dictionary access converted to `.get()` pattern
- Functions affected:
  - `_reduce_advance_year`
  - `_reduce_trigger_event`
  - `_reduce_check_victory`
  - `_reduce_resolve_event_choice`
  - `_reduce_add_colonist`
  - `_reduce_remove_colonist`
  - `_reduce_update_politics`
  - All other reducer methods

**File:** `scripts/colonysim/colonysim_politics.gd`
- Line 21: `politics.faction_standings` → `politics.get("faction_standings", {})`
- Line 72: `politics.stability` → `politics.get("stability", 75.0)`

**File:** `scripts/colonysim/colonysim_ai.gd`
- Line 92: `state.resources.get()` → `resources.get()` (invalid dot notation on Dictionary)

**File:** `scripts/colonysim/colony_sim_ui.gd`
- Line 189: `event.id` → `event.get("id", "")`
- Various other Dictionary access patterns

---

## Visual Effects System

### New File Updates: `scripts/colonysim/colony_view.gd`

#### Added State Variables
```gdscript
# Weather effects
var _sandstorm_active: bool = false
var _sandstorm_intensity: float = 0.0
var _sandstorm_particles: Array = []

# Rescue/Crisis effects
var _active_rescues: Array = []
var _crisis_buildings: Array = []
var _alert_flash_timer: float = 0.0

# Activity effects
var _work_particles: Array = []
var _building_activity: Dictionary = {}

# Robots
var _robots: Array = []
var _robot_count: int = 3

# Dust/ambient particles
var _dust_particles: Array = []

# Event effects
var _current_event_effect: String = ""
var _event_effect_timer: float = 0.0

# Priority alerts
var _priority_alerts: Array = []
```

#### Added Drawing Functions
- `_draw_mars_surface()` - Red-brown terrain with crater shadows
- `_draw_sandstorm_back()` - Orange tint overlay
- `_draw_sandstorm_front()` - Streaming dust particles
- `_draw_robots()` - Worker robots with trails and task indicators
- `_draw_work_particles()` - Sparks and harvest effects
- `_draw_dust_particles()` - Ambient floating dust
- `_draw_rescue_lines()` - Dashed paths for rescue operations
- `_draw_crisis_indicators()` - Flashing red alerts on buildings
- `_draw_robot_task_summary()` - Bottom-left HUD
- `_draw_priority_alerts()` - Top alert pills

#### Added Update Functions
- `_update_robot_movement(delta)` - Move robots between buildings
- `_update_sandstorm(delta)` - Animate sandstorm particles
- `_update_rescue_animations(delta)` - Progress rescue missions
- `_update_work_particles(delta)` - Physics for work effects
- `_update_dust_particles(delta)` - Ambient dust drift
- `_update_event_effects(delta)` - Timer-based effect management

#### Added Public API
```gdscript
func start_sandstorm()
func stop_sandstorm()
func trigger_event_effect(effect_type: String, duration: float)
func trigger_building_crisis(building_id: String)
func clear_building_crisis(building_id: String)
func set_robot_count(count: int)
func get_robot_count() -> int
func set_priority_alerts(alerts: Array)
func clear_priority_alerts()
```

#### Added Helper Functions
- `_init_robots()` - Create initial robot pool
- `_init_dust_particles()` - Create ambient dust
- `_init_sandstorm_particles()` - Create storm particles
- `_assign_robot_task(robot)` - Give robot a job
- `_get_building_work_type(building_type)` - Map building to particle type
- `_spawn_work_particles_at(pos, work_type)` - Create work effects
- `_spawn_random_work_particle()` - Ambient building activity
- `_draw_dashed_line(from, to, color, width, dash_length)` - Rescue paths
- `trigger_rescue(from_pos, to_pos)` - Start rescue animation

---

## UI Transparency Features

### File: `scripts/colonysim/colony_sim_ui.gd`

#### Added Functions
```gdscript
func _update_priority_alerts(state, resources, buildings, colonists)
func _trigger_visual_for_log(entry: Dictionary)
func _trigger_event_visual(event: Dictionary)
func _trigger_random_visual_event()
func _update_robot_count()
func _get_building_output_text(building_type: int, is_operational: bool) -> String
```

#### Enhanced Functions

**`_update_resources()`** - Now shows net flow per year:
```gdscript
# Added projection data
var projection = _colony_store.project_next_year()
var net_resources = projection.get("net", {})

# Added flow label
flow_label.text = "%s%.0f/yr" % [net_sign, net]
flow_label.modulate = Color.GREEN if net > 0 else Color.RED
```

**`_update_buildings()`** - Now shows production info:
```gdscript
var output_text = _get_building_output_text(building_type, is_operational)
building_list.add_item("%s%s%s %s" % [name, worker_text, status, output_text])
```

**`_on_log_entry()`** - Now triggers visual effects:
```gdscript
func _on_log_entry(entry: Dictionary):
    _add_log_entry(entry)
    _trigger_visual_for_log(entry)  # NEW
```

**`_process()`** - Added visual triggers and robot scaling:
```gdscript
# After event resolution
_trigger_event_visual(event)

# After building
colony_view.trigger_event_effect("construction", 2.0)

# Random ambient events (10% chance)
if randf() < 0.1:
    _trigger_random_visual_event()

# Scale robots
_update_robot_count()
```

---

## Color Additions

### Building Colors (Brightened)
```gdscript
const BUILDING_COLORS = {
    "hab": Color(0.4, 0.6, 0.85),      # Bright Blue
    "food": Color(0.3, 0.75, 0.35),    # Vibrant Green
    "power": Color(0.95, 0.85, 0.2),   # Bright Yellow
    "medical": Color(0.9, 0.35, 0.35), # Bright Red
    "science": Color(0.7, 0.4, 0.85),  # Vibrant Purple
    "industry": Color(0.7, 0.55, 0.35),# Warm Brown
    "social": Color(0.85, 0.6, 0.7),   # Warm Pink
    "infra": Color(0.55, 0.55, 0.55),  # Medium Gray
}
```

### Generation Colors (Brightened)
```gdscript
const GEN_COLORS = {
    0: Color(1.0, 0.9, 0.3),   # Earth-born - Bright Gold
    1: Color(0.3, 0.95, 1.0),  # First gen - Bright Cyan
    2: Color(0.3, 1.0, 0.45),  # Second gen - Bright Green
    3: Color(1.0, 1.0, 0.4),   # Third gen+ - Bright Yellow
}
```

### Robot Colors (New)
```gdscript
const ROBOT_COLOR = Color(0.6, 0.8, 1.0)        # Light blue-white
const RESCUE_ROBOT_COLOR = Color(1.0, 0.5, 0.2) # Orange
```

---

## Stats Overlay Enhancement

**Before:** Simple population and building count
**After:**
- Population count
- Robot count (shows worker bot quantity)
- Building status with color (orange if broken)
- Construction/repair status line
- Robot task summary (bottom-left)
- Priority alerts (top)

---

## Event-to-Visual Mapping

| Log Type | Message Contains | Visual Effect |
|----------|-----------------|---------------|
| crisis | storm, sandstorm, dust | `start_sandstorm()` |
| crisis | rescue, lost, stranded | `trigger_event_effect("rescue")` |
| crisis | breakdown, malfunction | `trigger_building_crisis()` |
| crisis | (other) | `trigger_event_effect("crisis")` |
| death | - | `trigger_event_effect("crisis", 2.0)` |
| birth | - | `trigger_event_effect("construction", 3.0)` |
| milestone | - | `trigger_event_effect("construction", 5.0)` |

---

## Testing Results

### Before Fixes
```
SCRIPT ERROR: Parse Error: Identifier "ColonySimAI" not declared
SCRIPT ERROR: Could not resolve class "ColonySimPopulation"
SCRIPT ERROR: Invalid access to property or key 'colonists' on Dictionary
```

### After Fixes
- Colony sim loads without errors
- AI autoplay runs continuously
- Visual effects trigger on events
- Priority alerts update each year
- Resource flows display correctly

---

## Files Modified

1. `scripts/colonysim/colonysim_population.gd` - Reserved keyword fix
2. `scripts/colonysim/colonysim_politics.gd` - Dictionary access fix
3. `scripts/colonysim/colonysim_ai.gd` - Dictionary access fix
4. `scripts/colonysim/colonysim_store.gd` - Dictionary access fixes (~20 locations)
5. `scripts/colonysim/colonysim_reducer.gd` - Dictionary access fixes (~50 locations)
6. `scripts/colonysim/colony_sim_ui.gd` - Visual triggers, transparency features
7. `scripts/colonysim/colony_view.gd` - Complete visual effects system

## Files Created

1. `docs/expansions/colony-sim-implementation.md` - This implementation guide
2. `docs/expansions/colony-sim-changelog.md` - This changelog
