# MCS Performance Optimization Tasks

**Game:** Mars Colony Sim (Turn-based Colony Builder)
**Priority:** LOW - Turn-based nature means performance is rarely an issue

Reference: `docs/principles/godot-performance.md`

---

## Architecture

MCS uses a pure turn-based approach:
- **Year-by-year progression** (each turn = 1 Martian year)
- **Isometric 2.5D rendering** for base view
- **Redux-like store** with pure reducer

**Primary Files:**
- `mcs_store.gd` (500 lines)
- `mcs_reducer.gd` (983 lines)
- `mcs_view.gd` (675 lines) - Isometric rendering
- `mcs_population.gd` (739 lines) - Colonist simulation

---

## Low-Risk Areas

### 1. Colonist Pathfinding

**File:** `scripts/mars_colony_sim/mcs_view.gd`

**Question:** How do colonists move around the base?
- If using A* on large grids every frame: potential issue
- If using simple waypoint movement: fine

**Current Status:** Likely simple waypoint system based on LOC count.

**If Needed:**
```gdscript
# Cache paths, don't recalculate every frame
var cached_path: Array = []
var path_valid: bool = false

func _on_destination_changed():
    cached_path = _calculate_path(position, destination)
    path_valid = true

func _process(delta):
    if path_valid and cached_path.size() > 0:
        # Follow cached path
```

---

### 2. Building Production Calculations

**File:** `scripts/mars_colony_sim/mcs_economy.gd`

**Question:** How is resource production calculated?
- Per-building iteration on each turn: fine (turn-based)
- Per-building iteration every frame: unnecessary

**Expected (Good) Pattern:**
```gdscript
# Only calculate on year advance
func _reduce_advance_year(state):
    var new_resources = state.resources.duplicate()
    for building in state.buildings:
        new_resources.food += building.food_production
        new_resources.power += building.power_production
    return new_resources
```

---

### 3. Isometric Rendering

**File:** `scripts/mars_colony_sim/mcs_view.gd`

**Question:** How are buildings rendered?
- Static sprites positioned once: good
- Recalculating isometric positions every frame: wasteful

**Expected Pattern:**
```gdscript
# Position calculated once when building placed
func _on_building_placed(building):
    var sprite = building_scene.instantiate()
    sprite.position = _grid_to_iso(building.grid_position)
    add_child(sprite)
    building_sprites[building.id] = sprite

# NOT recalculating in _process
```

---

## Population Simulation Considerations

With 100+ colonists, these patterns matter:

### Colonist Updates
```gdscript
# GOOD: Update colonist states in reducer (once per turn)
func _reduce_advance_year(state):
    var new_colonists = []
    for colonist in state.colonists:
        new_colonists.append(_update_colonist(colonist))
    return {colonists: new_colonists, ...}

# BAD: Update colonists every frame
func _process(delta):
    for colonist in state.colonists:
        # update health, mood, etc.
```

### Colonist Rendering
```gdscript
# GOOD: Only update visual positions when colonists move
func _on_colonist_moved(colonist_id, new_position):
    colonist_sprites[colonist_id].position = _grid_to_iso(new_position)

# BAD: Update all colonist visuals every frame
func _process(delta):
    for colonist_id in colonist_sprites:
        # recalculate position
```

---

## Recommended Audits

### Quick Checks
- [ ] Search for `_process` in mcs_*.gd files
- [ ] Verify no loops over colonists in frame callbacks
- [ ] Confirm building positions are cached

### Likely Non-Issues
- Turn advancement calculations (done once per turn)
- Event system (triggered, not polled)
- Politics/election system (turn-based)

---

## Future Scaling Considerations

If MCS grows to support:
- 500+ colonists
- 100+ buildings
- Real-time colonist movement

Then consider:
1. **Spatial hashing** for colonist-building interactions
2. **LOD system** for distant colonists (hide sprites, use dots)
3. **Chunked updates** (update 1/10th of colonists per frame)

For now, the turn-based architecture should handle reasonable colony sizes without issues.
