# FCW Development Session - December 2025

## Session Goals
Transform FCW from a functional prototype into a game that **feels** like desperate last-stand strategy. Core thesis: "Movement IS the game. Desperation comes from physics."

---

## What We Built

### 1. Design Philosophy (CLAUDE.md)

Established core principles:
- **You Cannot Win** - Earth will fall. Victory = lives evacuated
- **Show, Don't Tell** - Narrative emerges from logistics, not cutscenes
- **Every Number is a Life** - Population counters aren't abstract
- **Physics Creates Desperation** - Orbital mechanics, not artificial timers

The "Earth Dilemma":
- Help outer colonies → Activity draws Herald inward
- Go dark → Abandon everyone, but Herald might not find Earth
- Evacuate → Massive activity, definitely draws Herald

### 2. Detection Visualization (Phase 1)

**File:** `fcw_solar_map.gd`

Enhanced `_draw_herald_observation_zone()`:
- Multi-layered energy field with breathing effect
- Rotating scanning beam sweep
- Energy tendrils reaching toward active zones
- Pulsing drone range indicator

Enhanced `_draw_traffic_patterns()`:
- Glowing lane connections between zones
- Flowing particles along routes
- Intensity based on accumulated traffic
- Danger indicators for heavy traffic (50%+)

Added `_draw_zone_detection_labels()`:
- Shows detection probability [X%] at each zone
- Color-coded: green (safe) → yellow → orange → red (dangerous)
- Pulses when danger is high

### 3. Timeline Pressure Display (Phase 2)

**File:** `fcw_main.gd`

Redesigned header with urgency:
```
WEEK 4, DAY 3 - 14:00 | Herald → Mars: 23d | EVAC: 2.3M [HEROIC] | THREAT: ELEVATED
```

Added threat level system (0-3):
- **LOW** (0) - Standard colors
- **ELEVATED** (1) - Yellow tint, Herald within 2 zones
- **HIGH** (2) - Orange tint, zone falling
- **CRITICAL** (3) - Red pulse, Earth threatened

Header colors change dynamically based on threat level.

### 4. Route Selection UI (Phase 3)

**File:** `fcw_solar_map.gd`

Entity selection system:
- Click detection for entities (`_get_entity_at_position`)
- Selection highlighting (blue pulsing ring)
- Hover highlighting

Capital ship callouts (`_draw_capital_ship_callout`):
- Line pointing from ship to label
- Shows: Name, Combat Power, Status (STATIONED/IN TRANSIT/COASTING)
- "→ CLICK DESTINATION" instruction when selected

Route cost previews (`_draw_route_cost_previews`):
- When ship selected, all destinations show:
  - Travel time (fastest route)
  - Detection risk (LOW/MED/HIGH)
  - Faint connection lines
  - "CLICK" prompt on hover

Route options popup (`_draw_route_options_popup`):
- **FAST BURN** (orange) - Quick but 100% visible
- **STEALTH COAST** (green) - Slow but low visibility
- **GRAVITY ASSIST** (blue) - Balanced via waypoints
- Shows travel time and exposure % for each

### 5. Capital Ship Entity System

**File:** `fcw_types.gd`

Added `create_capital_ship()` - Creates named warship entities

Added `_create_initial_fleet_entities()` - Spawns starting fleet:
| Ship | Type | Location |
|------|------|----------|
| UNN Defiant | Cruiser | Earth |
| UNN Resolute | Cruiser | Earth |
| CVN Prometheus | Carrier | Earth |
| UNN Valiant | Cruiser | Mars |
| UNN Vigilant | Cruiser | Jupiter |

Updated `create_initial_state()` to include capital ships in entities array.

### 6. Integration

**File:** `fcw_main.gd`

Connected `entity_destination_selected` signal to dispatch route changes:
- Calls `store.dispatch_set_entity_destination()`
- Logs departure events
- Triggers warp effect on launch

---

## What's Working Well

### Strengths to Expand

1. **Visual Feedback Loop**
   - Detection zones make invisible mechanics visible
   - Route cost previews enable informed decisions
   - Callout labels make capital ships feel important

2. **Unified Entity System**
   - Capital ships are real entities with positions
   - Same physics/detection rules as everything else
   - Foundation for more entity types (transports, weapons)

3. **Route Options Architecture**
   - `FCWOrbital.gd` already calculates multiple route types
   - Clean separation: calculation vs visualization vs dispatch

4. **Urgency Through Color**
   - Header threat levels create ambient tension
   - No need for popups or interruptions

### What Could Be Simpler → SIMPLIFIED

1. **~~Too Many Detection Indicators~~** ✅ FIXED
   - Removed: tendrils, scanning beam, layered circles, particles
   - Kept: Clean observation radius circle, discrete [X%] labels at zones, simple traffic lines

2. **~~Route Popup Redundancy~~** ✅ FIXED
   - Left-click now uses default route (stealth coast)
   - Right-click shows options popup (only when needed)

3. **~~Capital Ship Selection Flow~~** ✅ FIXED
   - Was: Click ship → Click destination → Click route option (3 clicks)
   - Now: Click ship → Left-click destination (2 clicks for default route)

---

## What's Missing / Next Steps

### High Priority

1. **~~Entity Movement Execution~~** ✅ VERIFIED
   - `_reduce_set_entity_destination` correctly sets velocity and movement state
   - `_process_entity_movement_hourly` updates positions every tick
   - `_handle_entity_arrival` transitions back to ORBITING on arrival

2. **Go Dark Command**
   - One-click to halt all traffic
   - The "abandon colonies to save Earth" choice

3. **Evacuation Visibility**
   - Lives saved is THE win condition
   - Should be more prominent than current counter

### Medium Priority

4. **Herald Interest Indicator**
   - What is Herald currently tracking?
   - Visual beam/focus on detected activity

5. **Trajectory Rendering**
   - Show projected paths as curved lines
   - Intercept prediction

6. **Split Fleet Command**
   - Divide escorts to create decoys
   - Tactical depth

### Lower Priority

7. **Transmission System Enhancement**
   - Context-sensitive narrative ("Mars requesting evac")
   - Emotional pressure through radio chatter

8. **Sound Design**
   - Ambient tension audio
   - Alert sounds for threat level changes

---

## Files Modified This Session

| File | Changes |
|------|---------|
| `CLAUDE.md` | Added FCW Design Philosophy section |
| `docs/expansions/fcw-architecture.md` | Added UI Implementation Plan (sections 13-18), updated status |
| `scripts/first_contact_war/fcw_types.gd` | Capital ship creation, initial fleet entities |
| `scripts/first_contact_war/fcw_solar_map.gd` | Detection viz, route selection UI, callouts, **SIMPLIFIED** |
| `scripts/first_contact_war/fcw_main.gd` | Header urgency, entity destination handler |

---

## Simplification Pass (Late Dec 2025)

### Route Selection: 3 clicks → 2 clicks
- Left-click destination = stealth coast (default, safer)
- Right-click destination = show route options popup
- Updated callout instruction: "L-CLICK: STEALTH / R-CLICK: OPTIONS"

### Detection Visualization: Complex → Clean
- Removed: Layered circles, scanning beam, energy tendrils, particles
- Kept: Single observation radius circle with subtle pulse
- Kept: Discrete [X%] labels at each zone (color-coded)
- Simplified: Traffic lanes are now simple lines (no particles/glow)

---

## Design Principles Established

1. **Show the Tradeoffs** - Every action has visible cost
2. **Movement IS the Game** - Not production chains or economy
3. **Physics Creates Desperation** - Orbital mechanics, not timers
4. **Detection is the Core Loop** - Herald follows activity
5. **Resources are Ships, People, Time** - Not ore/steel/energy
6. **Simplicity Over Spectacle** - Clear information beats visual noise

---

## Testing Checklist

- [ ] Capital ships appear at game start with callout labels
- [ ] Clicking ship selects it with blue highlight
- [ ] Route cost previews appear at all destination zones
- [ ] Left-clicking destination sends ship via stealth coast
- [ ] Right-clicking destination shows route options popup
- [ ] Selecting route triggers warp effect and dispatches command
- [ ] Ship actually moves after route selection
- [ ] Header changes color based on threat level
- [ ] Detection radius shows as clean circle around Herald
- [ ] Zone labels show detection [X%] with color coding
- [ ] Traffic lanes show as simple lines between zones
