# MCS (Mars Colony Sim): Implementation & Visual Design Document

**Last Updated:** December 2024
**Status:** Playable with AI autoplay, visual effects system complete

---

## Overview

This document covers the technical implementation of the Colony Sim expansion, including:
1. Architecture and code structure
2. Visual effects and graphics system
3. UI transparency features
4. Bug fixes and GDScript 4.x compatibility

For game design philosophy, see `colony-sim.md` and `colony-sim-core-loop.md`.

---

## Architecture

### File Structure

```
scripts/colonysim/
├── colony_sim_ui.gd      # Main UI controller
├── colony_view.gd        # Visual renderer with effects
├── colonysim_store.gd    # State management (Redux-style)
├── colonysim_reducer.gd  # Pure state transitions
├── colonysim_types.gd    # Enums and type definitions
├── colonysim_ai.gd       # AI governor personalities
├── colonysim_population.gd # Population simulation
├── colonysim_economy.gd  # Resource production/consumption
├── colonysim_politics.gd # Political system
└── colonysim_events.gd   # Event generation
```

### State Management

The colony sim uses a Redux-style architecture:

```gdscript
# State flows one direction:
# UI Action → Store.dispatch() → Reducer → New State → UI Update

# colonysim_store.gd
func dispatch(action: Dictionary) -> void:
    var new_state = ColonySimReducer.reduce(_state, action)
    _state = new_state
    state_changed.emit(_state)
```

### Key Design Patterns

1. **Pure Reducers**: All state transitions are pure functions
2. **Dictionary-based State**: Flexible schema, accessed via `.get()` for safety
3. **Signal-based Updates**: UI reacts to `state_changed` signals
4. **AI Governor**: Autonomous play with personality-based decision making

---

## Visual Effects System

### Design Philosophy

The colony view is designed to be **visually exciting** while maintaining a spreadsheet-style data display. The key insight: *numbers can change in the background, but show the story visually*.

Examples:
- Event causes productivity loss → Show sandstorm particles sweeping across
- Building breaks down → Show flashing red crisis indicator
- Robot rescues colonist → Show rescue animation with dashed path

### Colony View Components

The `colony_view.gd` renders multiple layers from back to front:

```gdscript
func _draw():
    _draw_mars_surface()       # 1. Background terrain
    _draw_grid()               # 2. Grid overlay
    _draw_sandstorm_back()     # 3. Weather behind buildings
    _draw_buildings()          # 4. Building blocks
    _draw_work_particles()     # 5. Sparks and harvest effects
    _draw_robots()             # 6. Worker and rescue robots
    _draw_colonists()          # 7. Population dots
    _draw_rescue_lines()       # 8. Rescue operation paths
    _draw_sandstorm_front()    # 9. Weather in front
    _draw_dust_particles()     # 10. Ambient dust
    _draw_crisis_indicators()  # 11. Flashing alerts
    _draw_stats_overlay()      # 12. HUD elements
```

### Mars Surface Background

A rust-red terrain with procedurally placed crater shadows:

```gdscript
func _draw_mars_surface():
    var bg_color = Color(0.35, 0.18, 0.12)  # Mars red-brown
    draw_rect(full_rect, bg_color, true)

    # Procedural craters with fixed seed for consistency
    var rng = RandomNumberGenerator.new()
    rng.seed = 12345
    for i in range(20):
        var pos = Vector2(rng.randf() * width, rng.randf() * height)
        var radius = rng.randf_range(5, 25)
        draw_circle(pos, radius, bg_color.darkened(rng.randf_range(0.1, 0.25)))
```

### Robot System

Robots are the visual workhorses of the colony. They:
- Move between buildings doing tasks
- Leave motion trails showing movement
- Change color based on task
- Have blinking antenna lights

```gdscript
# Robot structure
var robot = {
    "id": "robot_0",
    "pos": Vector2,           # Current position
    "target": Vector2,        # Destination
    "task": "working",        # idle, working, rescue, patrol
    "color": ROBOT_COLOR,     # Changes based on task
    "trail": []               # Position history for motion blur
}

# Task colors
ROBOT_COLOR = Color(0.6, 0.8, 1.0)      # Light blue - idle/patrol
RESCUE_ROBOT_COLOR = Color(1.0, 0.5, 0.2) # Orange - rescue
WORKING_COLOR = Color(0.5, 1.0, 0.6)    # Green - working
```

**Robot Count Scaling:**
Robots scale with colony size: 1 per 5 colonists or 3 buildings, minimum 3.

```gdscript
func _update_robot_count():
    var target = maxi(3, maxi(pop / 5, buildings / 3))
    colony_view.set_robot_count(target)
```

### Sandstorm Effects

Sandstorms are triggered by storm events and include:
- Orange tint overlay behind buildings
- 100+ streaming dust particles
- "⚠ SANDSTORM" warning text
- Gradual fade in/out

```gdscript
# Sandstorm particle structure
var particle = {
    "pos": Vector2,
    "vel": Vector2(randf_range(100, 200), randf_range(-20, 20)),
    "alpha": randf_range(0.3, 0.7),
    "size": randf_range(2, 6)
}

# Particles are elongated for wind effect
var wind_stretch = Vector2(size * 3, size * 0.5)
draw_rect(Rect2(pos - wind_stretch/2, wind_stretch), dust_color)
```

**Triggering:**
```gdscript
colony_view.start_sandstorm()      # Start with 8 second duration
colony_view.stop_sandstorm()       # Fade out
colony_view.trigger_event_effect("sandstorm", duration)
```

### Rescue Animations

When rescue events occur, an animated sequence shows:
1. Rescue robot dispatched from colony
2. Dashed line path to rescue site
3. Flashing emergency light on robot
4. Return journey with rescued colonist

```gdscript
var rescue = {
    "from": Vector2,        # Start position
    "to": Vector2,          # Rescue site
    "progress": 0.0,        # 0-1 animation progress
    "robot_pos": Vector2,   # Current robot position
    "returning": false      # Going vs returning
}

# Visual elements
_draw_dashed_line(from, to, dash_color, 2.0, 8.0)
draw_circle(robot_pos, 6, RESCUE_ROBOT_COLOR)
if sin(_time * 10) > 0:  # Flashing
    draw_circle(robot_pos + Vector2(0, -8), 3, Color.RED)
```

### Work Particles

Buildings emit particles showing activity:
- **Greenhouses**: Green particles (harvesting)
- **Workshops/Factories**: Orange sparks
- **Solar Arrays**: Yellow energy particles
- **Water Extractors**: Cyan droplets

```gdscript
func _get_building_work_type(building_type: int) -> String:
    match building_type:
        GREENHOUSE, HYDROPONICS: return "harvest"    # Green
        WORKSHOP, FACTORY: return "sparks"           # Orange
        SOLAR_ARRAY: return "energy"                 # Yellow
        WATER_EXTRACTOR: return "water"              # Cyan
        _: return "generic"

# Particles have gravity and fade out
particle["vel"].y += 50 * delta  # Gravity
particle["life"] -= delta * 2     # Fade
```

### Crisis Indicators

Buildings in crisis show:
- Flashing red circle overlay
- ⚠ warning icon above building
- Automatic trigger when buildings break

```gdscript
func _draw_crisis_indicators():
    var flash = sin(_alert_flash_timer) > 0

    for building_id in _crisis_buildings:
        var center = _get_building_center(building_id)

        if flash:
            draw_circle(center, CELL_SIZE * 0.7, Color(1, 0, 0, 0.3))
            draw_circle(center, CELL_SIZE * 0.7, Color.RED, false, 2.0)

        draw_string(font, center + Vector2(-6, -20), "⚠", ...)
```

### Ambient Dust

30 floating dust particles drift across the colony for atmosphere:

```gdscript
var dust = {
    "pos": Vector2,
    "vel": Vector2(randf_range(-5, 5), randf_range(-2, 2)),
    "alpha": randf_range(0.1, 0.3),
    "size": randf_range(1, 3)
}

# Gentle random drift
dust["vel"] += Vector2(randf_range(-10, 10), randf_range(-5, 5)) * delta
dust["vel"] = dust["vel"].clamp(Vector2(-10, -5), Vector2(10, 5))
```

### Event-Triggered Effects

Effects are triggered automatically based on game events:

```gdscript
func _trigger_visual_for_log(entry: Dictionary):
    var log_type = entry.get("log_type", "info")
    var message = entry.get("message", "").to_lower()

    match log_type:
        "crisis":
            if "storm" in message or "sandstorm" in message:
                colony_view.start_sandstorm()
            elif "rescue" in message or "lost" in message:
                colony_view.trigger_event_effect("rescue", 6.0)
            elif "breakdown" in message:
                colony_view.trigger_building_crisis(building_id)
        "death":
            colony_view.trigger_event_effect("crisis", 2.0)
        "birth":
            colony_view.trigger_event_effect("construction", 3.0)
        "milestone":
            colony_view.trigger_event_effect("construction", 5.0)
```

---

## UI Transparency System

### Design Goal

Players should understand at a glance:
1. What needs immediate attention (priorities)
2. Where resources are going (flows)
3. What buildings produce (output)
4. What robots are doing (tasks)

### Priority Alerts

Displayed at top of colony view as colored pills:

| Priority | Color | Examples |
|----------|-------|----------|
| 2 (Critical) | Red (pulsing) | `🔴 Food CRITICAL`, `⚡ Power deficit!` |
| 1 (Warning) | Yellow | `⚠ Low water`, `🏠 Housing tight` |
| 0 (Info) | Cyan | `✓ Stable`, `🔨 Building 2` |

```gdscript
func _update_priority_alerts(state, resources, buildings, colonists):
    var alerts = []

    # Critical resources (food, water, oxygen)
    for res_name in ["food", "water", "oxygen"]:
        var amount = resources.get(res_name, 0)
        if amount < 20:
            alerts.append({
                "priority": 2,
                "message": "%s CRITICAL" % res_name.capitalize(),
                "icon": "🔴"
            })
        elif amount < 50:
            alerts.append({
                "priority": 1,
                "message": "Low %s" % res_name,
                "icon": "⚠"
            })

    # Housing, power, broken buildings, stability...
    # Sort by priority, limit to 4
    alerts.sort_custom(func(a, b): return a.priority > b.priority)
    colony_view.set_priority_alerts(alerts.slice(0, 4))
```

### Resource Flow Display

Each resource shows current amount AND net change per year:

```
Food     [████████░░] 245  +15/yr   (green)
Water    [██████░░░░] 180  -8/yr    (red)
Oxygen   [█████████░] 320  +2/yr    (green)
```

Implementation:
```gdscript
func _update_resources(resources: Dictionary):
    var projection = _colony_store.project_next_year()
    var net_resources = projection.get("net", {})

    for resource_name in resource_order:
        var amount = resources.get(resource_name, 0)
        var net = net_resources.get(resource_name, 0)

        # Flow label with color
        var flow_label = Label.new()
        flow_label.text = "%s%.0f/yr" % ["+" if net >= 0 else "", net]
        flow_label.modulate = Color.GREEN if net > 0 else Color.RED if net < 0 else Color.GRAY
```

### Building Production Info

Each building shows what it produces:

```
Greenhouse (2/3) → +20 food/yr
Solar Array → +25 power
Hab Pod → 4 beds
Medical Bay → +health
Workshop [BROKEN]
```

```gdscript
func _get_building_output_text(building_type: int, is_operational: bool) -> String:
    if not is_operational:
        return ""

    match building_type:
        GREENHOUSE: return "→ +20 food/yr"
        SOLAR_ARRAY: return "→ +25 power"
        HAB_POD: return "→ 4 beds"
        MEDICAL_BAY: return "→ +health"
        WORKSHOP: return "→ repairs"
        # ... etc
```

### Robot Task Summary

Bottom-left HUD shows what robots are doing:

```
⚙3 🚨1 👁2
```
- ⚙ = working at buildings
- 🚨 = rescue operations
- 👁 = patrolling

### Stats Overlay

Top-right HUD shows:
- Population count
- Robot count (scales with colony)
- Building status (operational/total)
- Construction or repair status

---

## Technical Fixes (GDScript 4.x Compatibility)

### Issue 1: Reserved Keyword `trait`

**Problem:** `trait` is a reserved keyword in GDScript 4.x for the trait system.

**Files Affected:** `colonysim_population.gd`

**Fix:** Renamed loop variable from `trait` to `t`:
```gdscript
# Before (error)
for trait in all_parent_traits:

# After (fixed)
for t in all_parent_traits:
```

### Issue 2: Dictionary Dot Notation

**Problem:** GDScript 4.x cannot use dot notation to read Dictionary values. Must use `.get()`.

**Files Affected:**
- `colonysim_store.gd`
- `colonysim_reducer.gd`
- `colonysim_politics.gd`
- `colonysim_ai.gd`
- `colony_sim_ui.gd`

**Fix Pattern:**
```gdscript
# Before (error)
var colonists = _state.colonists
var stability = politics.stability

# After (fixed)
var colonists = _state.get("colonists", [])
var stability = politics.get("stability", 75.0)
```

**Scope:** ~50+ fixes across all reducer functions including:
- `_reduce_advance_year`
- `_reduce_trigger_event`
- `_reduce_check_victory`
- `_reduce_resolve_event_choice`
- `_reduce_add_colonist`
- `_reduce_remove_colonist`
- All store getter methods

### Issue 3: Class Resolution

**Problem:** Parse errors in one file caused `class_name` registration failures in dependent files.

**Symptom:** `Identifier "ColonySimAI" not declared in the current scope`

**Root Cause:** Cascading parse errors from `colonysim_population.gd` (trait keyword) and `colonysim_politics.gd` (Dictionary access).

**Fix:** Fix all parse errors in dependency order.

---

## AI Governor System

### Personalities

Four AI personalities with different priorities:

```gdscript
enum Personality {
    PRAGMATIST,  # Balanced approach
    VISIONARY,   # Long-term growth focus
    HUMANIST,    # Population welfare focus
    CAUTIOUS     # Risk-averse, safety first
}
```

### AI Decision Making

The AI makes decisions based on personality and colony state:

```gdscript
static func choose_event_option(event, state, personality, random_val) -> int:
    # Analyze choices based on personality priorities
    # Return index of chosen option

static func choose_building(state, personality, random_val) -> int:
    # Evaluate building priorities
    # Return BuildingType or -1 for no build
```

### Auto-Play Mode

Default mode runs the AI automatically:
- Resolves events instantly
- 30% chance to build each year
- Scales robot count with colony
- Triggers visual effects for events

---

## Building Types

### Housing
| Type | Capacity | Notes |
|------|----------|-------|
| Hab Pod | 4 beds | Basic |
| Apartment Block | 12 beds | Standard |
| Luxury Quarters | 6 beds | +morale |
| Barracks | 20 beds | Emergency |

### Production
| Type | Output | Workers |
|------|--------|---------|
| Greenhouse | +20 food/yr | 2-3 |
| Hydroponics | +40 food/yr | 1-2 |
| Protein Vats | +30 food/yr | 1 |
| Water Extractor | +30 water/yr | 2 |

### Power
| Type | Output | Notes |
|------|--------|-------|
| Solar Array | +25 power | Weather-dependent |
| Wind Turbine | +15 power | Consistent |
| RTG | +10 power | Long lifespan |
| Fission Reactor | +100 power | High cost |

### Services
| Type | Effect | Workers |
|------|--------|---------|
| Medical Bay | +health | 2-4 |
| Hospital | ++health | 6-10 |
| School | education | 2-4 |
| Lab | research | 2-4 |
| Workshop | repairs | 2-6 |
| Factory | +parts/yr | 10-20 |

### Social
| Type | Effect |
|------|--------|
| Recreation Center | +morale |
| Temple | +stability |
| Government Hall | governance |

---

## Future Enhancements

### Visual Polish
- [ ] Building construction animations
- [ ] Day/night lighting cycle
- [ ] Colonist speech bubbles for events
- [ ] Resource flow lines between buildings
- [ ] Explosion/damage effects for crises

### Gameplay
- [ ] Manual building placement on grid
- [ ] Resource trading with Earth
- [ ] Tech tree visualization
- [ ] Family tree browser
- [ ] Achievement system

### Performance
- [ ] LOD for large colonies (simplify distant buildings)
- [ ] Particle pooling for better performance
- [ ] Background processing for population simulation

---

## Testing Checklist

### Visual Effects
- [x] Sandstorm particles stream correctly
- [x] Rescue animations complete properly
- [x] Work particles spawn at buildings
- [x] Crisis indicators flash on broken buildings
- [x] Robots move between buildings
- [x] Robot count scales with population

### UI Transparency
- [x] Priority alerts show critical issues
- [x] Resource flows display correctly
- [x] Building outputs shown in list
- [x] Robot task summary updates
- [x] Stats overlay accurate

### Core Gameplay
- [x] AI autoplay works without errors
- [x] Events resolve correctly
- [x] Population ages and reproduces
- [x] Buildings construct and break
- [x] Victory/defeat conditions trigger

---

## Quick Reference

### Triggering Visual Effects

```gdscript
# From colony_sim_ui.gd
colony_view.start_sandstorm()                    # 8 second sandstorm
colony_view.trigger_event_effect("rescue", 5.0)  # Rescue animation
colony_view.trigger_event_effect("crisis", 4.0)  # Random building crisis
colony_view.trigger_event_effect("construction", 3.0)  # Work particles
colony_view.trigger_building_crisis(building_id) # Specific building
colony_view.set_robot_count(count)               # Scale robots
colony_view.set_priority_alerts(alerts)          # Update HUD alerts
```

### State Access Pattern

```gdscript
# Always use .get() for Dictionary access
var colonists = state.get("colonists", [])
var resources = state.get("resources", {})
var food = resources.get("food", 0)
var politics = state.get("politics", {})
var stability = politics.get("stability", 75.0)
```

### Color Palette

```gdscript
# Mars surface
Color(0.35, 0.18, 0.12)  # Background

# Buildings
Color(0.4, 0.6, 0.85)    # Housing (blue)
Color(0.3, 0.75, 0.35)   # Food (green)
Color(0.95, 0.85, 0.2)   # Power (yellow)
Color(0.9, 0.35, 0.35)   # Medical (red)

# Robots
Color(0.6, 0.8, 1.0)     # Worker (light blue)
Color(1.0, 0.5, 0.2)     # Rescue (orange)
Color(0.5, 1.0, 0.6)     # Working (green)

# Alerts
Color.RED                 # Critical (pulsing)
Color.YELLOW              # Warning
Color.CYAN                # Info
```
