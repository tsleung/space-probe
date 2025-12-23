# VNP Performance Optimization Tasks

**Game:** Von Neumann Probe (Real-time Combat)
**Priority:** HIGH - These issues will cause lag with 50+ ships

Reference: `docs/principles/godot-performance.md`

---

## Critical Issues

### 1. O(N²) Scatter Force Calculation

**File:** `scripts/von_neumann_probe/ship.gd`
**Lines:** 1002-1014 (`_calculate_scatter_force`)
**Called From:** Line 954 in `_strafe_around_target_tactical`

**Current Code:**
```gdscript
for ship_id in state.ships:
    var ship = state.ships[ship_id]
    if ship.team == ship_data.team and ship_id != ship_data.id:
        var to_ally = position - ship.position
        var dist = to_ally.length()
        if dist < 100 and dist > 0:
            scatter += to_ally.normalized() * (100 - dist) / 100
```

**Problem:** Every attacking ship iterates ALL ships every frame when using scatter tactic.
- With 20 attacking ships: 20 × 50 × 60fps = 60,000 distance calculations/second

**Fix:**
1. Add an Area2D child to each ship with radius 100 (scatter avoidance range)
2. Maintain `var nearby_allies: Array = []` updated via signals
3. Replace loop with iteration over cached array

```gdscript
# In ship.gd _ready():
$AllyDetectionArea.body_entered.connect(_on_ally_entered)
$AllyDetectionArea.body_exited.connect(_on_ally_exited)

var nearby_allies: Array = []

func _on_ally_entered(body):
    if body.ship_data.team == ship_data.team and body != self:
        nearby_allies.append(body)

func _on_ally_exited(body):
    nearby_allies.erase(body)

func _calculate_scatter_force() -> Vector2:
    var scatter = Vector2.ZERO
    for ally in nearby_allies:
        if not is_instance_valid(ally):
            continue
        var to_ally = position - ally.position
        var dist = to_ally.length()
        if dist > 0:
            scatter += to_ally.normalized() * (100 - dist) / 100
    return scatter.normalized() * 50
```

---

### 2. O(N²) Threat Assessment

**File:** `scripts/von_neumann_probe/ship.gd`
**Lines:** 1095-1104 (`_assess_threat`)
**Called From:** Line 763 (every 0.5s per ship via cooldown)

**Current Code:**
```gdscript
for ship_id in state.ships:
    var ship = state.ships[ship_id]
    if ship.team != ship_data.team:
        var dist = position.distance_to(ship.position)
        if dist < 400:  # Tactical awareness range
            nearby_enemies += 1
            if ship.type == VnpTypes.ShipType.FRIGATE:
                nearby_frigates += 1
```

**Problem:** Each ship counts ALL enemy ships every 0.5 seconds.
- With 50 ships: 50 × 50 = 2,500 distance checks every 0.5s = 5,000/second

**Fix:**
1. Add Area2D with radius 400 (tactical awareness range)
2. Maintain `var enemies_in_range: Array = []` via signals
3. Count from cached array instead of iterating all ships

```gdscript
# Add to ship.gd
var enemies_in_range: Array = []

func _on_enemy_entered(body):
    if body.ship_data.team != ship_data.team:
        enemies_in_range.append(body)

func _on_enemy_exited(body):
    enemies_in_range.erase(body)

func _assess_threat() -> Dictionary:
    var nearby_frigates = 0
    var nearby_cruisers = 0

    for enemy in enemies_in_range:
        if not is_instance_valid(enemy):
            continue
        if enemy.ship_data.type == VnpTypes.ShipType.FRIGATE:
            nearby_frigates += 1
        elif enemy.ship_data.type == VnpTypes.ShipType.CRUISER:
            nearby_cruisers += 1

    # ... rest of threat logic
```

---

### 3. O(N²) Flank Position Calculation

**File:** `scripts/von_neumann_probe/ship.gd`
**Lines:** 1022-1026 (`_calculate_flank_position`)

**Current Code:**
```gdscript
for ship_id in state.ships:
    var ship = state.ships[ship_id]
    if ship.team == ship_data.team and ship_id != ship_data.id:
        ally_center += ship.position
        ally_count += 1
```

**Problem:** Computes ally center per-ship when flanking.

**Fix:** Precompute team centers in `vnp_ai_controller.gd` once per update:

```gdscript
# In vnp_ai_controller.gd
var team_centers: Dictionary = {}  # team -> Vector2

func _calculate_team_centers():
    var team_positions: Dictionary = {}  # team -> [positions]
    var team_counts: Dictionary = {}

    for ship in get_tree().get_nodes_in_group("ships"):
        var team = ship.ship_data.team
        if not team_positions.has(team):
            team_positions[team] = Vector2.ZERO
            team_counts[team] = 0
        team_positions[team] += ship.position
        team_counts[team] += 1

    for team in team_positions:
        if team_counts[team] > 0:
            team_centers[team] = team_positions[team] / team_counts[team]

# Call once per AI update tick, not per-ship
```

Then ships read from `ai_controller.team_centers[ship_data.team]`.

---

## Moderate Issues

### 4. PDC Defense Group Query

**File:** `scripts/von_neumann_probe/ship.gd`
**Line:** 1670 (`_run_pdc_defense`)

**Current Code:**
```gdscript
for node in get_tree().get_nodes_in_group("missiles"):
    if not is_instance_valid(node):
        continue
    if node.team == ship_data.team:
        continue
    # ...
```

**Problem:** Group query every frame for each Defender ship.

**Fix:** Maintain global missile registry in `vnp_main.gd`:

```gdscript
# In vnp_main.gd
var active_missiles: Array = []

func register_missile(missile):
    active_missiles.append(missile)

func unregister_missile(missile):
    active_missiles.erase(missile)

# Ships access via:
# get_parent().get_parent().active_missiles
# or signal-based: missile_spawned / missile_destroyed
```

---

### 5. Planet Capture Iteration

**File:** `scripts/von_neumann_probe/vnp_main.gd`
**Lines:** 649-689 (`_check_planet_capture`)

**Current Code:**
```gdscript
for ship_id in state.ships:
    var ship = state.ships[ship_id]
    var dist = ship.position.distance_to(planet_pos)
    if dist < 80:
        team_presence[ship.team] += 1
```

**Problem:** Iterates all ships for each planet every 2 seconds.

**Fix:** Use Area2D zones around planets:

```gdscript
# Each planet has Area2D child with radius 80
# Maintains ships_in_zone: Array via body_entered/exited

func _check_planet_capture(planet):
    var team_presence = {}
    for ship in planet.ships_in_zone:
        if is_instance_valid(ship):
            var team = ship.ship_data.team
            team_presence[team] = team_presence.get(team, 0) + 1
    # ... capture logic
```

---

## Minor Issues

### 6. Theme Color Override Every Frame

**File:** `scripts/von_neumann_probe/vnp_main.gd`
**Line:** 1413 (`_update_expansion_countdown`)

**Current:**
```gdscript
expansion_countdown_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0, alpha))
```

**Fix:** Use `modulate` instead (faster):
```gdscript
expansion_countdown_label.modulate.a = alpha
```

---

## Implementation Priority

1. **URGENT:** Fix scatter force (Issue #1) - causes most lag
2. **URGENT:** Fix threat assessment (Issue #2) - second biggest impact
3. **HIGH:** Add missile registry (Issue #4)
4. **MEDIUM:** Precompute team centers (Issue #3)
5. **LOW:** Planet capture zones (Issue #5)
6. **LOW:** Theme override fix (Issue #6)

---

## Testing

After implementing fixes, stress test with:
- 100 ships (50 per team)
- Multiple Defender ships with PDC active
- High scatter/flank tactic usage
- Monitor frame time in Godot profiler

**Target:** Maintain 60fps with 100 ships
