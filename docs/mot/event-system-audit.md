# MOT Phase 2 Event System Audit

## Executive Summary

The event system has **two separate implementations** that don't communicate with each other, plus a **third real-time crisis system**. This creates confusion and inconsistency.

---

## Current State

### 1. JSON Events (`data/games/mars_odyssey_trek/events/phase2.json`)

**8 events with sophisticated outcome weighting:**
| Event | Category | Day Range | Options | Weighted Outcomes |
|-------|----------|-----------|---------|------------------|
| solar_particle_event | space | 20-160 | 3 | Yes (0.85/0.15, 0.6/0.4, 0.25/0.75) |
| micrometeorite_impact | ship | 10-170 | 3 | Yes |
| crew_disagreement | crew | 30-150 | 3 | Yes |
| medical_emergency | crew | 20-160 | 3 | Yes |
| oxygen_alert | ship | 40-170 | 3 | Yes |
| birthday_space | quiet | 30-160 | 2 | Yes |
| earth_visible | quiet | 60-140 | 2 | Yes |
| halfway_mars | milestone | 50% | 2 | Guaranteed success |

**NOT CURRENTLY USED** - These JSON events are loaded but the system primarily uses hardcoded events.

### 2. Hardcoded Events (`scripts/mars_odyssey_trek/phase2/phase2_store.gd`)

**13 events in random pool:**
| Event | Options | Effect Types |
|-------|---------|--------------|
| SOLAR_FLARE | 3 | morale_loss, minor_radiation, power_drain |
| COMPONENT_MALFUNCTION | 2 | morale_boost, morale_loss |
| MESSAGE_FROM_EARTH | 2 | morale_boost |
| MICROMETEORITE | 2 | thorough_check, quick_check |
| CARGO_LOOSE | 2 | secure_cargo, minor_loss |
| CREW_CONFLICT | 3 | morale_boost, morale_loss |
| MEDICAL_EMERGENCY | 3 | health_check, quick_treatment, rest_treatment |
| POWER_SURGE | 2 | power_drain, fatigue_gain |
| NAVIGATION_DRIFT | 2 | fuel_loss, delay_correction |
| WATER_RECYCLER_ISSUE | 3 | water_fix, partial_fix, water_ration |
| OXYGEN_FLUCTUATION | 3 | thorough_check, use_spare, watch_and_wait |
| COMMUNICATION_STATIC | 2 | power_drain, communication_delay |
| MORALE_MILESTONE | 3 | food_loss, morale_boost, morale_loss |

**3 special events:**
- MIDPOINT_CRISIS (Day 90-95)
- MARS_VISIBLE_EVENT (Day 140)
- FINAL_APPROACH (Day 173-176)

### 3. Real-Time Crisis System (`scripts/mars_odyssey_trek/phase2/crisis/`)

**10 crisis types running in parallel:**
| Crisis | Room | Resource Drain | Fix Time |
|--------|------|----------------|----------|
| O2_LEAK | Life Support | oxygen | 6s |
| POWER_FLUCTUATION | Engineering | power | 5s |
| WATER_RECYCLER | Life Support | water | 7s |
| HULL_STRESS | Cargo Bay | (breach risk) | 10s |
| MEDICAL_EMERGENCY | Medical | crew_health | 5s |
| NAVIGATION_DRIFT | Bridge | fuel | 8s |
| COMMS_FAILURE | Bridge | morale | 6s |
| FIRE | Any | oxygen | 4s |
| EQUIPMENT_FAULT | Engineering | power | 6s |
| FOOD_CONTAMINATION | Cargo Bay | food | 8s |

---

## Critical Issues Found

### Issue 1: Duplicate Systems (CRITICAL)
The same events exist in multiple places:
- **Medical Emergency**: Hardcoded event + JSON event + Crisis system
- **O2/Oxygen**: OXYGEN_FLUCTUATION event + O2_LEAK crisis
- **Navigation**: NAVIGATION_DRIFT event + NAVIGATION_DRIFT crisis
- **Water Recycler**: WATER_RECYCLER_ISSUE event + WATER_RECYCLER crisis
- **Power**: POWER_SURGE event + POWER_FLUCTUATION crisis

**Impact**: Player confusion, inconsistent mechanics, unbalanced gameplay.

### Issue 2: JSON Effects Not Implemented (HIGH)
The JSON events define effects that don't exist in the reducer:
```
Missing implementations:
- consumption_multiplier (oxygen efficiency reduction)
- set_flag (hull_patch_needed, life_support_wear)
- component_damage/repair (target specific)
- relationship (crew pair effects)
- crew_status (recovering, critical, sick)
- percent-based resource changes
```

**Impact**: JSON events would behave unexpectedly if enabled.

### Issue 3: Effect Type Mismatch (FIXED)
The `effect` field was being compared incorrectly (int vs string).
```gdscript
// Before (broken):
if effect == "repair_section" or effect == str(Phase2Types.EventEffectType.REPAIR_SECTION):

// After (fixed):
var effect_str = str(effect)
if effect_str == "repair_section" or effect == Phase2Types.EventEffectType.REPAIR_SECTION:
```

### Issue 4: No Weighted Outcomes in Hardcoded Events (MEDIUM)
JSON events have sophisticated probability-weighted outcomes:
```json
"outcomes": [
  {"weight": 0.85, "effects": [...]},  // Good outcome
  {"weight": 0.15, "effects": [...]}   // Bad outcome
]
```

Hardcoded events always have the same outcome - no risk/reward variance.

### Issue 5: Event vs Crisis Confusion (MEDIUM)
- **Events**: Pause game, show popup, player makes choice, instant resolution
- **Crises**: Real-time, no popup, assign crew, fix over time

Both can drain the same resources (oxygen, power, water) but operate completely differently.

---

## Visual Feedback Status

**Complete and working for all event types:**
- 17 event types have dedicated visual handlers
- Each choice has room flashing + crew movement
- Screen shake for critical events
- Particle effects (sparks, steam, debris) where appropriate

---

## Recommendations

### Immediate Fixes

1. **Consolidate to One Event System**
   - Either use JSON events (more sophisticated) or hardcoded (simpler)
   - Don't maintain both

2. **Differentiate Events from Crises**
   - Events = Story moments (solar flare, message from Earth, milestones)
   - Crises = Real-time emergencies (fires, leaks, failures)
   - Remove overlap (don't have both an oxygen event AND an oxygen crisis)

3. **Implement Missing Effect Types**
   If keeping JSON events, add reducer support for:
   - `consumption_multiplier`
   - `set_flag` / `check_flag`
   - `component_damage` / `component_repair`
   - `relationship`
   - `crew_status`

### Balance Recommendations

4. **Add Weighted Outcomes to Hardcoded Events**
   Give each choice a risk/reward element:
   ```gdscript
   // Current: Always same outcome
   "effect": "morale_boost", "effect_value": 10

   // Better: Random outcome based on roll
   "outcomes": [
     {"weight": 0.7, "effect": "morale_boost", "value": 15},
     {"weight": 0.3, "effect": "morale_boost", "value": 5}
   ]
   ```

5. **Tune Crisis Spawn Rates**
   Current: 15% chance every 2 seconds (very frequent)
   Consider: Scale with journey progress (quiet early, chaotic late)

6. **Add Event Prerequisites**
   Events should check state:
   - Don't trigger birthday if morale < 20
   - Don't trigger milestone celebration if crew is injured
   - Medical emergency only if medical supplies > 0

---

## Proposed Unified Event Categories

| Category | Delivery | Player Action | Examples |
|----------|----------|---------------|----------|
| **Story Events** | Popup (paused) | Choose option | Solar flare, Earth message, Milestones |
| **Crises** | Real-time overlay | Assign crew | Fires, leaks, failures |
| **Quiet Moments** | Popup (brief) | Choose option | Birthday, Earth visible |
| **Emergencies** | Popup + Crisis | Both | Midpoint cascade (starts crisis after choice) |

---

## Files to Review

- `data/games/mars_odyssey_trek/events/phase2.json` - Unused but well-designed
- `scripts/mars_odyssey_trek/phase2/phase2_store.gd:60-340` - Event pool setup
- `scripts/mars_odyssey_trek/phase2/phase2_reducer.gd:389-548` - Effect application
- `scripts/mars_odyssey_trek/phase2/ship_view_bridge.gd:230-520` - Visual handlers
- `scripts/mars_odyssey_trek/phase2/crisis/` - Crisis system

---

## Audit Complete

**Status**: Core functionality works, but system is over-complicated with duplication.

**Next Steps**:
1. Decide: JSON events or hardcoded events?
2. Decide: Which problems are events vs crises?
3. Implement missing effect types OR remove JSON events
4. Add weighted outcomes for player choice variance
