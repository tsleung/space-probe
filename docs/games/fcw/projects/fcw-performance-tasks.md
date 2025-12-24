# FCW Performance Optimization Tasks

**Game:** First Contact War (Turn-based Strategy with Real-time Map)
**Priority:** MEDIUM - Turn-based nature reduces urgency, but solar map updates need attention

Reference: `docs/principles/godot-performance.md`

---

## Current Architecture

FCW uses a hybrid approach:
- **Turn-based mechanics** (168 hours = 1 week/turn)
- **Real-time solar map** rendering entity positions
- **Redux-like store** with pure reducer

**Files to audit:**
- `fcw_solar_map.gd` (3,983 lines) - Map visualization
- `fcw_battle_view.gd` (2,009 lines) - Combat rendering
- `fcw_reducer.gd` (1,768 lines) - State transformations

---

## Potential Issues to Investigate

### 1. Entity Position Updates

**File:** `scripts/first_contact_war/fcw_solar_map.gd`

**Question:** How are entity positions updated on the solar map?
- If iterating all entities every frame to update positions: potential O(N) per frame
- If using signals/tweens for position changes: good

**Audit Task:**
```
Search for:
- _process or _physics_process in fcw_solar_map.gd
- Loops over state.entities in rendering code
- get_nodes_in_group calls
```

**Expected Pattern:**
```gdscript
# GOOD: Update positions only when state changes
func _on_state_changed(new_state):
    for entity_id in new_state.entities:
        var node = entity_nodes.get(entity_id)
        if node:
            node.position = _world_to_screen(new_state.entities[entity_id].position)

# BAD: Update positions every frame
func _process(delta):
    for entity_id in state.entities:
        # ... update position
```

---

### 2. Intercept Calculations

**File:** `scripts/first_contact_war/fcw_reducer.gd`

**Question:** How are intercept checks performed?
- During tick processing, do we check all entity pairs?
- With 100+ entities, this could be O(N²)

**Audit Task:**
```
Search for intercept logic:
- _check_intercepts or similar
- Nested loops over entities
- Distance calculations in hot paths
```

**Mitigation (if needed):**
- Only check entities on intercept courses (BURNING toward enemy)
- Use spatial partitioning (divide map into sectors)
- Cache "entities in sector" and only check within sectors

---

### 3. Zone Occupancy Calculations

**File:** `scripts/first_contact_war/fcw_reducer.gd`

**Question:** How is zone control calculated?
- Iterating all entities to count per-zone?
- Could cache zone membership

**Expected Pattern:**
```gdscript
# GOOD: Maintain zone membership in state
state.zone_entities = {
    "earth": ["entity_1", "entity_2"],
    "mars": ["entity_3"],
    # ...
}

# BAD: Count every tick
func _calculate_zone_control():
    for entity_id in state.entities:
        var entity = state.entities[entity_id]
        var zone = _get_zone_for_position(entity.position)
        # count...
```

---

### 4. Battle View Rendering

**File:** `scripts/first_contact_war/fcw_battle_view.gd`

**Question:** During battles, how are combatants rendered?
- Particle effects pooled?
- Damage numbers pooled?
- Ship sprites cached?

**Audit Task:**
```
Search for:
- instantiate() calls
- Particle creation in loops
- Label/sprite creation per damage tick
```

---

## Good Patterns to Verify

FCW should already follow these patterns (verify):

1. **State changes via reducer** - Not every frame
2. **Signal-driven UI** - View reacts to state_changed
3. **Cached node references** - @onready vars
4. **Throttled dispatch** - Not dispatching every frame

---

## Recommended Actions

### Phase 1: Audit (Do First)
- [ ] Search `_process` and `_physics_process` in FCW files
- [ ] Identify any O(N²) loops
- [ ] Check for group queries in hot paths
- [ ] Verify object pooling for battle effects

### Phase 2: Document Findings
- [ ] Update this file with specific line numbers
- [ ] Rate severity (critical/moderate/minor)
- [ ] Propose fixes

### Phase 3: Implement (If Needed)
- [ ] Add spatial partitioning for intercepts
- [ ] Cache zone membership
- [ ] Pool battle effect objects

---

## Testing

After any optimizations:
- Create scenario with 200+ entities
- Run 100 turns rapidly
- Monitor frame time during map updates
- Monitor memory during battles

**Target:** Maintain 60fps with 200 entities on solar map
