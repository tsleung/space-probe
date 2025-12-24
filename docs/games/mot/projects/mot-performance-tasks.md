# MOT Performance Optimization Tasks

**Game:** Mars Odyssey Trek (Turn-based Journey Simulation)
**Priority:** LOW - Day-by-day progression means minimal real-time concerns

Reference: `docs/principles/godot-performance.md`

---

## Architecture

MOT uses a turn-based approach across all phases:
- **Phase 1:** Step-by-step wizard (no real-time)
- **Phase 2:** Day-by-day with speed controls (pseudo real-time)
- **Phase 3:** Sol-by-sol base operations (turn-based)
- **Phase 4:** Day-by-day return (same as Phase 2)

**Primary Files:**
- `phase2/phase2_store.gd` (400 lines)
- `phase2/phase2_reducer.gd` (470 lines)
- `phase2/phase2_view.gd` (400 lines)

---

## Phase 2 Considerations

### 1. Star Field Parallax

**File:** `scripts/mars_odyssey_trek/phase2/phase2_view.gd`
**Lines:** 377-399 (`_update_star_parallax`)

**Current Implementation:**
```gdscript
func _update_star_parallax(delta: float) -> void:
    if not star_field or stars.is_empty():
        return

    for i in range(min(stars.size(), star_field.get_child_count())):
        var star_data = stars[i]
        var star_node = star_field.get_child(i) as Polygon2D
        # ... update position and twinkle
```

**Status:** ACCEPTABLE
- 200 stars (STAR_COUNT = 200)
- Simple vector math per star
- No allocation in loop

**If Issues Arise:**
- Reduce star count
- Use GPU particles instead of individual Polygon2D nodes
- Disable parallax when paused

---

### 2. Day Advancement Dispatch

**File:** `scripts/mars_odyssey_trek/phase2/phase2_controller.gd`

**Current Implementation:**
```gdscript
func _process(delta: float) -> void:
    # ... speed checks ...
    day_timer += delta
    if day_timer >= seconds_per_day:
        day_timer = 0.0
        store.advance_day()  # Dispatch action
```

**Status:** GOOD
- Dispatch only when day advances (not every frame)
- Configurable speed controls timing
- Pauses correctly

---

### 3. Resource Bar Updates

**File:** `scripts/mars_odyssey_trek/phase2/phase2_view.gd`

**Current Implementation:**
```gdscript
func _sync_resources(state: Dictionary) -> void:
    var resources = state.resources
    _update_resource_bar("FoodBar", resources.food.current, resources.food.max)
    # ... 4 more bars
```

**Status:** GOOD
- Only called on state_changed signal
- Not called every frame
- Fixed number of bars (5)

---

### 4. Event Popup Animation

**File:** `scripts/mars_odyssey_trek/phase2/phase2_view.gd`
**Lines:** 261-296 (`_show_event_popup`)

**Status:** GOOD
- Uses Tween for animation (efficient)
- One-shot, not looping
- Proper cleanup

---

## No Issues Found

MOT's architecture is well-suited to its turn-based nature:

| Component | Pattern | Status |
|-----------|---------|--------|
| State updates | Signal-driven | GOOD |
| Day advancement | Throttled dispatch | GOOD |
| Star parallax | 200 nodes, simple math | ACCEPTABLE |
| UI updates | On state change only | GOOD |
| Animations | Tween-based | GOOD |

---

## Future Considerations

### If Adding Real-time Elements

If MOT ever adds real-time mechanics (e.g., ship visualization with moving parts):

1. **Pool particle effects** for engine exhaust
2. **Use GPU particles** for space debris
3. **Disable expensive visuals** on FAST speed

### Phase 3/4 Migration

When migrating Phase 3 and 4 to new architecture:
- Follow Phase 2 patterns (already performant)
- Keep turn-based dispatch model
- Avoid per-frame state iteration

---

## Recommended Actions

None required. Current implementation follows best practices:

- [x] State changes via reducer (not every frame)
- [x] Signal-driven UI updates
- [x] Throttled day advancement
- [x] Tween-based animations
- [x] Reasonable star count (200)

Monitor only if:
- Star field causes frame drops on low-end devices
- Adding real-time ship visualization
- Adding particle-heavy effects
