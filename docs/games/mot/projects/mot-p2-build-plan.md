# MOT Phase 2: Build Plan

**Document Created:** December 2024
**Last Updated:** December 22, 2024
**Status:** FEATURE COMPLETE - Full Polish Pass Done

---

## The Vision

**Tagline:** Overcooked meets Apollo 13

**One Line:** Watch your AI crew frantically keep a ship together while the void tries to kill you.

**The Hook:** You're not clicking menus. You're watching crew sprint to a hull breach as oxygen ticks down. You're yelling at your screen. Chat is screaming. They fix it with 30 seconds to spare. THAT'S a clip.

---

## Design Inspirations

| Game/Media | What We're Taking |
|------------|-------------------|
| **FTL** | Ship cutaway view, room-based crew management |
| **Overcooked** | Frantic coordination, visible chaos, streamable moments |
| **Helldivers 2** | Cooperative chaos, things going wrong spectacularly |
| **Among Us** | Ship interior, crew running around |
| **The Martian** | Competence porn, math-is-clear survival, man vs physics |
| **Apollo 13** | Crew professionalism under pressure, problem-solving cascade |
| **Oregon Trail** | Resource depletion, random events, "will we make it?" tension |
| **Darkest Dungeon** | Stress as mechanic, the slow decline, atmosphere |

---

## Core Pillars

1. **The Ship is the Stage** - You see the interior, the crew, the chaos
2. **Crew are Actors** - AI-controlled, running between stations, visibly working
3. **The Void is the Antagonist** - Things break, not because of drama, but physics
4. **Commander Directs** - Player sets priorities, crew executes
5. **Tension is Visible** - Timers, damage, crew running, alarms

---

## Current Status: FEATURE COMPLETE

### ✅ COMPLETE: Full Polish Pass (December 22, 2024)

All planned features have been implemented:

**Main Entry Point:**
- Menu: "Mars Odyssey Trek: Travel to Mars" → `phase2_integrated.tscn`

**Visual Components:**
- `space_background.gd` - Full-screen parallax star field (300/150/60 stars)
- `ship_hull.gd` - Sleek ship exterior with configurable engines
- `ship_view.gd` - Interior rooms with crew pathfinding
- `journey_indicator.gd` - Earth → Mars progress with growing Mars

**Game Logic (Store/Reducer):**
- `phase2_store.gd` - State management, 13 event types, special milestone events
- `phase2_reducer.gd` - Pure state mutations
- `phase2_controller.gd` - Input handling, spacebar pause

**Integration Layer:**
- `ship_view_bridge.gd` - Connects store signals to visual actions
- `phase2_integrated_hud.gd` - Combined HUD with resources, events, & arrival ceremony
- `phase2_integrated_ui.gd` - Speed controls, navigation

**New in Polish Pass:**
- `phase2_sound_manager.gd` - Procedural audio (alarms, footsteps, engine hum)
- `phase2_effects.gd` - Screen shake, particles, camera focus, arrival ceremony

---

## Ship Hull Design

### Configurable Engine Types

The ship hull supports 4 engine configurations (can be tied to Phase 1 choices):

```gdscript
enum EngineConfig {
    SINGLE_MASSIVE,     # One huge engine - simple, powerful
    DUAL_SYMMETRIC,     # Two large engines - balanced (default)
    TRI_CLUSTER,        # Three engines in triangle - versatile
    QUAD_ARRAY          # Four engines - maximum thrust
}
```

### Visual Features

| Feature | Description |
|---------|-------------|
| **Sleek Hull** | Curved aerodynamic shape with racing stripe accent |
| **Engine Glow** | Animated flickering blue engine flames |
| **Solar Panels** | Top/bottom arrays with grid detail |
| **Radiator Fins** | Heat dissipation fins on hull |
| **Bridge Windows** | Glowing observation windows |
| **Docking Port** | Green indicator on nose |
| **Antenna** | Communication antenna on nose |

### Ship Layout

```
     ★  ·    ·      ★           ·        ★    [MARS →]
  ·        ★     ·        ·          ★

      ▲▲▲  [Solar Panels]
        ╭─────────────────────────────────────────────╮
   ═══╱  ┌─────┐   ┌─────┐   ┌─────┐                   ╲───●
  ═══╱   │MED  │───│QUART│───│CORR │───[BRIDGE]         ╲──●
 ═══╱    └─────┘   └─────┘   └──┬──┘                     ╲─●
════╲    ┌─────┐   ┌─────┐   ┌──┴──┐                     ╱
  ═══╲   │CARGO│───│LIFE │───│ ENG │                    ╱
   ═══╲  └─────┘   └─────┘   └─────┘                   ╱
        ╰─────────────────────────────────────────────╯
      ▼▼▼  [Solar Panels]

  ·         ★    ·        ·    ★       ·
     ★           ·   ★            ★         ·
[← EARTH]
```

---

## Event Visual Feedback System

### How It Works

1. **Event Triggers** → Store emits `event_triggered` signal
2. **Bridge Receives** → `ship_view_bridge.gd` stores event type
3. **Player Chooses** → HUD shows options, player picks
4. **Visual Feedback** → Based on event type + choice, crew move and rooms flash
5. **Return to Stations** → After 1.5s delay, crew return home

### Event-Choice Visual Mapping

| Event | Choice | Crew Action | Room Flash |
|-------|--------|-------------|------------|
| **Solar Flare** | Shelter in cargo | All 4 crew → Cargo Bay | Blue |
| | Continue with shielding | Stay at stations | Ship flashes yellow |
| | Emergency power | Engineer → Engineering | Yellow |
| **Component Malfunction** | Assign engineer | Engineer → Life Support | Green |
| | Monitor for now | Commander checks bridge | - |
| **Message from Earth** | Share immediately | 3 crew → Quarters | Blue |
| | Save for later | Commander → Bridge | - |
| **Micrometeorite** | Full inspection | Engineer + Scientist inspect | Orange |
| | Quick check | Engineer → Corridor | - |
| **Cargo Loose** | Secure everything | Engineer + Scientist → Cargo | Green |
| | Catch what you can | Random crew → Cargo | - |
| **Crew Conflict** | Commander intervenes | Commander → Quarters | - |
| | Let them work it out | Crew separate | - |
| **Medical Emergency** | Full medical workup | Medical + patient → Medical | Red |
| **Power Surge** | Reroute/Stabilize | Engineer → Engineering | Yellow |
| **Midpoint Crisis** | All hands repair | ALL crew scramble + alarm | Red flash |

### Special Milestone Events

| Day | Event | Visual |
|-----|-------|--------|
| **90-95** | Midpoint Crisis | Screen shake, alarms, all crew emergency |
| **140** | Mars Sighted! | All crew gather at bridge windows |
| **173-176** | Final Approach | Crew to stations, anticipation |
| **183** | Mars Orbit Achieved | Arrival ceremony with stats |

### Room Flash Effect

Rooms flash with color to indicate activity:
- Flash in (0.16s): Room brightens to specified color
- Flash out (0.64s): Room returns to original color
- Modulate effect: Additional brightness boost

### Sound Design

All sounds are procedurally generated (no audio files needed):

| Sound Type | Trigger |
|------------|---------|
| **Ambient hum** | Always playing (engine room noise) |
| **Engine rumble** | Always playing, intensity varies with speed |
| **Warning beep** | Solar flare, oxygen issues |
| **Alarm klaxon** | Midpoint crisis, critical events |
| **Impact thud** | Micrometeorite |
| **Malfunction buzz** | Component malfunction |
| **Radio chime** | Message from Earth |
| **Click** | UI button press |
| **Resolution chime** | Event resolved |
| **Arrival fanfare** | Mars orbit achieved |

### Screen Shake & Effects

| Effect | When Used |
|--------|-----------|
| **Light shake (0.3s)** | Micrometeorite impact |
| **Heavy shake (0.5s)** | Midpoint crisis |
| **Red flash** | Damage, crisis |
| **Yellow flash** | Solar flare, power issues |
| **Sparks** | Damage effects |
| **Steam** | Life support issues |

### Crew Visual State

Crew appearance changes based on their stats:
- **Low Health (<60)**: Crew dims by 20%
- **Low Health (<30)**: Crew dims by 40%
- **Low Morale (<40)**: Slight blue tint
- **Resting**: 60% brightness
- **Emergency**: Red flashing
- **Working**: Pulse effect

---

## Controls

| Input | Action |
|-------|--------|
| **Spacebar** | Toggle pause |
| **Escape** | Toggle pause |
| **1** | Set speed: Slow |
| **2** | Set speed: Normal |
| **3** | Set speed: Fast |
| **UI Buttons** | Slow / Normal / Fast / Pause / ← Menu |

---

## Architecture

```
phase2_integrated.tscn
├── Phase2Store (Node) - Game state, 13 event types, signals
├── Phase2Controller (Node) - Input, timing
├── SoundManager (Node) - Procedural audio generation
├── Effects (Node2D) - Screen shake, particles, camera focus
├── SpaceBackground (Node2D) - z=-10, parallax stars
├── ShipHull (Node2D) - z=-1, exterior hull + engines
├── ShipView (Node2D) - z=0, interior rooms + crew
├── ShipViewBridge (Node) - Store→Visual translation + effects
├── JourneyIndicator (Node2D) - z=5, progress display + Mars growth
├── HUD (CanvasLayer) - Resources, crew, events, arrival ceremony
├── SpeedControls (HBoxContainer) - Bottom buttons
└── UIController (Node) - Button wiring
```

### Data Flow

```
User Input / Time
       ↓
Phase2Controller
       ↓
Phase2Store.dispatch(action)
       ↓
Phase2Reducer.reduce(state, action)
       ↓
Phase2Store emits signals
       ↓
  ┌────┴────┐
  ↓         ↓
ShipViewBridge    HUD
  ↓               ↓
ShipView       UI Updates
(crew move,    (bars, popups)
rooms flash)
```

---

## Files

### Integration Layer
- `scripts/mars_odyssey_trek/phase2/ship_view_bridge.gd` - Store↔Visual bridge + effects
- `scripts/mars_odyssey_trek/phase2/phase2_integrated_hud.gd` - HUD + arrival ceremony
- `scripts/mars_odyssey_trek/phase2/phase2_integrated_ui.gd` - UI wiring
- `scenes/mars_odyssey_trek/phase2_integrated.tscn` - Main scene

### Polish Systems (New)
- `scripts/mars_odyssey_trek/phase2/phase2_sound_manager.gd` - Procedural audio
- `scripts/mars_odyssey_trek/phase2/phase2_effects.gd` - Screen shake, particles

### Visual Components
- `scripts/mars_odyssey_trek/phase2/ship/ship_types.gd` - Enums, constants
- `scripts/mars_odyssey_trek/phase2/ship/ship_view.gd` - Room orchestrator + EVA
- `scripts/mars_odyssey_trek/phase2/ship/ship_room.gd` - Individual rooms
- `scripts/mars_odyssey_trek/phase2/ship/crew_member.gd` - Crew AI + health visuals
- `scripts/mars_odyssey_trek/phase2/ship/space_background.gd` - Star field
- `scripts/mars_odyssey_trek/phase2/ship/ship_hull.gd` - Hull + engines
- `scripts/mars_odyssey_trek/phase2/ship/journey_indicator.gd` - Progress + Mars growth

### Game Logic
- `scripts/mars_odyssey_trek/phase2/phase2_store.gd` - State + 13 events + milestones
- `scripts/mars_odyssey_trek/phase2/phase2_reducer.gd` - Pure functions
- `scripts/mars_odyssey_trek/phase2/phase2_types.gd` - Types + 17 event types
- `scripts/mars_odyssey_trek/phase2/phase2_controller.gd` - Input

---

## Completed Features

### ✅ Polish (All Complete)
- [x] Sound design (alarms, footsteps, engine hum, ambient) - procedural audio
- [x] Screen shake on impacts (micrometeorite, crisis)
- [x] Particle effects (sparks, steam, debris)
- [x] Mars growing as approach nears (quadratic growth in journey_indicator)

### ✅ Features (All Complete)
- [x] EVA retrieval visual - crew exits hull, inspects ship, returns
- [x] 13 event types with unique visuals
- [x] Camera follow modes (focus on room, follow crew)
- [x] Crew health/morale affecting visuals (dim, color shift)

### ✅ Content (All Complete)
- [x] 8 new event types (crew conflict, medical, power surge, etc.)
- [x] Special midpoint crisis event (day 90-95)
- [x] Mars visible celebration event (day 140)
- [x] Final approach event (last 10 days)
- [x] Mars arrival ceremony with stats summary

### Remaining Work

### Future Vision
- [ ] 4-player co-op (each player IS a crew member)
- [ ] Voice chat chaos coordination
- [ ] Phase 1 ship building → visual ship configuration
- [ ] The ultimate "Overcooked in space"
- [ ] Game over death animations

---

## Success Metrics

**It's Working When:**
- [x] Ship is visible with rooms and crew dots ✅
- [x] Crew pathfind between rooms ✅
- [x] Rooms show damage visually ✅
- [x] Events trigger and resolve ✅
- [x] Crew responds to choices visually ✅
- [x] Rooms flash on activity ✅
- [x] Screen shakes on impacts ✅
- [x] Sound effects play for events ✅
- [x] Midpoint crisis creates tension ✅
- [x] Mars arrival feels triumphant ✅
- [ ] You watch crew run to a breach and feel tension
- [ ] You yell at your screen during a close call
- [ ] A 5-minute clip would be interesting to watch

**It's NOT Working If:**
- Crew movement feels random or meaningless
- Events are just timers without visual stakes
- Player feels disconnected from the action
- It's more interesting to read the log than watch

---

## Key Decisions Made

1. **Art Style:** Minimal colored rectangles (rooms) and dots (crew) - readable, achievable
2. **Camera:** Fixed showing full ship - can add follow modes later
3. **Layout:** Horizontal ship, nose toward Mars, cutaway interior
4. **Time Scale:** ~2 seconds per day (Normal speed), events pause for choices
5. **Failure States:** Critical resource depletion = game over
6. **Engine Config:** Dual symmetric default, can be changed in scene
7. **Visual Feedback:** Every choice shows crew movement + room flash
