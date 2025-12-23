# Phase 2: Travel to Mars - Implementation Spec

> **Core Fantasy:** Submarine Captain
> **Primary Tension:** Resource Management vs Crew Morale
> **Visual Mode:** Scale Distortion - the infinite void and the fragile ship

---

## Emotional Arc

### The Journey of Endurance

Phase 2 is a **slow burn**. The emotional arc follows a submarine voyage pattern:

```
EMOTION
   ↑
   │    Relief     Routine      Creeping     Midpoint    Crisis      Mars
   │      ↓          ↓          Dread          ↓        Peak       Visible
   │   ┌─────┐    ┌─────┐      ┌─────┐      ┌─────┐    ┌─────┐    ┌─────┐
   │   │  ↗  │    │     │      │   ↘ │      │  ↘  │    │ ↗↘  │    │  ↗  │
   │   │↗    │→→→→│─────│→→→→→→│     │→→→→→→│    ↘│→→→→│↗   ↘│→→→→│↗    │
   │   │     │    │     │      │      ↘     │     │    │     │    │     │
   └───┴─────┴────┴─────┴──────┴──────┴─────┴─────┴────┴─────┴────┴─────┴──→
       Day 1      Week 2       Month 1       Midpoint    Month 4     Final
       POST-      THE          THE           THE         THE         THE
       LAUNCH     ROUTINE      WEIGHT        ABYSS       TRIAL       APPROACH
```

### The Six Acts

| Act | Days | Emotion | Visual Tone | Key Events |
|-----|------|---------|-------------|------------|
| **ACT 1: Post-Launch** | 1-7 | Relief, excitement | Bright, Earth visible | Systems settling, crew optimistic |
| **ACT 2: The Routine** | 8-30 | Contentment, boredom | Neutral, stable | Daily tasks, minor events |
| **ACT 3: The Weight** | 31-60 | Creeping unease | Subtle darkening | First failures, resource awareness |
| **ACT 4: The Abyss** | 61-100 | Isolation, despair | Dark, cold | Midpoint blues, major crisis |
| **ACT 5: The Trial** | 101-150 | Tension, determination | Flickering, stressed | Systems failing, crew tested |
| **ACT 6: The Approach** | 151-183 | Hope rising | Mars light, warmth | Mars visible, final challenges |

---

## Story Beats

### Act 1: Post-Launch (Days 1-7)

| Beat | Day | Visual | Audio | Emotion |
|------|-----|--------|-------|---------|
| **Earth Shrinking** | 1 | Earth fills screen, then recedes to marble, then dot | Engines fade to hum | Awe, farewell |
| **Systems Green** | 2 | All status indicators pulse green, settle | Confirmation beeps | Relief |
| **First Meal** | 3 | Crew gathered, cafeteria warm light | Laughter, utensils | Community |
| **Last Earth Call** | 5 | Earth as distant blue dot, transmission crackle | Loved one's voice | Bittersweet |
| **Deep Space Begins** | 7 | Stars fill all directions, no planets visible | Silence grows | Isolation dawns |

### Act 2: The Routine (Days 8-30)

| Beat | Day | Visual | Audio | Emotion |
|------|-----|--------|-------|---------|
| **The Daily Cycle** | 8-20 | Day counter accelerating, tasks blur | Time compression sound | Routine |
| **Minor Malfunction** | 15 | Yellow warning, quick fix animation | Beep, relief sigh | Competence |
| **Crew Bonding** | 20 | Relationship lines strengthening (glow) | Warm music swell | Connection |
| **First Worry** | 25 | Resource bar dips slightly, noticed | Subtle warning tone | Awareness |
| **Routine Broken** | 30 | Unexpected event interrupts auto-advance | Jarring cut to real-time | Alertness |

### Act 3: The Weight (Days 31-60)

| Beat | Day | Visual | Audio | Emotion |
|------|-----|--------|-------|---------|
| **Component Failure** | 35 | First major component goes yellow/orange | Alarm, sparks | Concern |
| **Repair Attempt** | 36 | Engineer working, parts consumed | Tools, effort sounds | Tension |
| **Supplies Check** | 40 | Camera pans across cargo, gaps visible | Inventory sounds, silence | Scarcity awareness |
| **Crew Friction** | 45 | Relationship line flickers red | Sharp words, door slam | Conflict |
| **The Long Look** | 50 | Ship from outside, tiny against stars | Deep space ambience | Scale horror |
| **Halfway Point** | 60 | "MIDPOINT" display, Mars/Earth equally distant | Somber music | No turning back |

### Act 4: The Abyss (Days 61-100)

| Beat | Day | Visual | Audio | Emotion |
|------|-----|--------|-------|---------|
| **The Abyss** | 65 | Ship interior dimmer, crew faces shadowed | Quiet, hollow | Despair |
| **Major Crisis** | 75 | Red alerts, multiple systems failing | Alarms layered | Panic |
| **Desperate Repair** | 76 | Crew working frantically, sparks flying | Urgent voices, tools | Fight |
| **Loss** | 80 | Something precious destroyed/gone | Impact, silence | Grief |
| **Crew Breakdown** | 85 | One crew member isolated, health dropping | Ragged breathing | Breaking |
| **The Low Point** | 90 | Everything at worst state (visually dark) | Near-silence | Darkest hour |
| **Small Hope** | 100 | One thing goes right, tiny green light | Single positive beep | Spark |

### Act 5: The Trial (Days 101-150)

| Beat | Day | Visual | Audio | Emotion |
|------|-----|--------|-------|---------|
| **Recovery Begins** | 105 | Crew working together, systems stabilizing | Determined music | Resolve |
| **Resource Rationing** | 110 | Portions smaller, visible conservation | Quiet acceptance | Sacrifice |
| **Second Major Crisis** | 125 | Another threat, but crew responds faster | Controlled urgency | Competence |
| **Personal Mission** | 135 | Crew member's personal moment/resolution | Intimate music | Character |
| **First Mars Light** | 140 | Faint orange glow on one side of ship | Musical hint | Hope |
| **Systems Holding** | 150 | Yellow/green mostly, worn but functional | Steady hum | Endurance |

### Act 6: The Approach (Days 151-183)

| Beat | Day | Visual | Audio | Emotion |
|------|-----|--------|-------|---------|
| **Mars Visible** | 155 | Orange dot visible, growing each day | Rising music | Hope swelling |
| **Final Fuel Check** | 165 | Fuel gauge prominent, enough? | Tension music | Anxiety |
| **Deceleration Burn** | 175 | Engine ignition, ship shuddering | Roar, shake | Commitment |
| **Mars Fills Screen** | 180 | Mars growing from disk to world | Crescendo | Awe |
| **Orbit Achieved** | 182 | Ship curve into Mars orbit | Relief swell | Triumph |
| **Landing Sequence** | 183 | Transition animation to Phase 3 | Resolution music | Completion |

---

## Minimum Observable Loop (MOL)

The smallest implementation that creates a compelling spectacle:

### Core Loop

```
┌─────────────────────────────────────────────────────────────────┐
│                         ONE DAY                                  │
├─────────────────────────────────────────────────────────────────┤
│  1. MORNING STATUS (2s)                                         │
│     - Day counter increments with flourish                      │
│     - Resource bars update with animation                       │
│     - Crew status pulses                                        │
│                                                                 │
│  2. DAILY TICK (1s)                                             │
│     - Resources deplete (visible drain)                         │
│     - Components degrade (subtle color shift)                   │
│     - Crew stats adjust (mood indicators)                       │
│                                                                 │
│  3. EVENT CHECK (0-5s)                                          │
│     - Random roll determines if event occurs                    │
│     - If event: popup with choices, AI decides                  │
│     - Consequence animation plays                               │
│                                                                 │
│  4. PROGRESS UPDATE (1s)                                        │
│     - Ship moves along journey bar                              │
│     - Mars grows slightly larger                                │
│     - Star field parallax                                       │
│                                                                 │
│  5. NIGHT TRANSITION (0.5s)                                     │
│     - Subtle lighting dim                                       │
│     - Loop to next day                                          │
└─────────────────────────────────────────────────────────────────┘
```

### MOL Systems Required

| System | Required For | Complexity |
|--------|--------------|------------|
| **Day Counter** | Time progression | Low |
| **Resource Bars** | Visual feedback on depletion | Low |
| **Journey Progress** | Sense of advancement | Low |
| **Ship Exterior View** | Scale distortion, spectacle | Medium |
| **Event System** | Drama injection | Medium |
| **Crew Status Display** | Human connection | Medium |
| **Mars Approach Visual** | Hope/destination | Medium |

### MOL Visual Effects Required

| Effect | Purpose | Priority |
|--------|---------|----------|
| **Resource depletion animation** | Feel consumption | Critical |
| **Day/night cycle on ship** | Time passage | Critical |
| **Ship in space view** | Scale, beauty | Critical |
| **Event popup animation** | Drama moments | Critical |
| **Mars growing** | Hope, destination | Critical |
| **Star field parallax** | Motion, life | High |
| **Component status colors** | System health | High |
| **Crew mood indicators** | Human element | High |

---

## Visual Spectacle Spec

### The Ship in the Void

The hero visual of Phase 2 is the **ship against infinity**.

**Rendering Layers:**
```
Layer 10: UI (resource bars, day counter, alerts)
Layer 9:  Event popups
Layer 8:  Ship interior (if in interior view)
Layer 7:  Ship exterior (main subject)
Layer 6:  Engine trail particles
Layer 5:  Near space (Mars as it approaches)
Layer 4:  Sun (distant but present)
Layer 3:  Nebula wisps (subtle color)
Layer 2:  Star field (parallax layers)
Layer 1:  Deep black gradient
```

### Scale Distortion Moments

| Moment | Technique | Implementation |
|--------|-----------|----------------|
| **Daily exterior shot** | The Intimate Vast | Ship small against star field, 3-second hold |
| **Resource depletion** | Micro-Macro | Zoom to single food container, pull back to cargo hold |
| **Crisis peak** | Time Distortion | Slow motion during critical failure animation |
| **Mars approach** | The Vast Intimate | Mars fills screen, reveal it's through porthole |
| **Midpoint** | Focus Pull | Blur from instrument dial to infinite stars |

### The Journey Bar

Not a simple progress bar - a **living starscape**:

```
┌────────────────────────────────────────────────────────────────────┐
│ EARTH                          [SHIP]                         MARS │
│   ●━━━━━━━━━━━━━━━━━━━━━━━━━━━━━▲━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━●   │
│   ╰─ fading blue               │                    growing rust─╯  │
│                                │                                    │
│                         Day 47/183                                  │
│                      136 days remaining                             │
└────────────────────────────────────────────────────────────────────┘
```

**Visual Details:**
- Earth dot: Blue, shrinking, fading over time
- Mars dot: Rust, growing, brightening over time
- Ship icon: Detailed sprite, subtle engine glow
- Track: Star-like particles embedded, parallax with ship motion
- Background: Subtle nebula color wash, shifts with journey progress

### Resource Depletion Visualization

Each resource has a **distinctive drain animation**:

| Resource | Bar Style | Depletion Animation | Crisis Visual |
|----------|-----------|---------------------|---------------|
| **Food** | Segmented (meals) | Segment fades per consumption | Empty plate icon flashes |
| **Water** | Liquid fill | Ripple at surface, level drops | Droplet shrivels |
| **Oxygen** | Circular gauge | Sweep reduction with glow | Gauge pulses red, breathing sound |
| **Power** | Lightning segments | Segments flicker out | Static burst, lights dim |
| **Fuel** | Cylindrical tank | Liquid level with slosh | Tank rattles, empty echo |

### Crew Mood Visualization

Crew portraits shift based on emotional state:

| State | Portrait Effect | Background | Animation |
|-------|-----------------|------------|-----------|
| **Excellent** (80-100) | Bright, warm | Soft glow | Subtle smile shift |
| **Good** (60-79) | Normal | Neutral | Occasional blink |
| **Stressed** (40-59) | Slight shadow | Cooler tint | Tension in face |
| **Low** (20-39) | Hollow eyes | Gray wash | Slow, heavy motion |
| **Critical** (<20) | Pale, drawn | Red-tinged | Trembling, closing eyes |

### Event Popups

Events are **cinematic interrupts**:

```
┌─────────────────────────────────────────────────────────────────────┐
│                                                                     │
│     ╔═══════════════════════════════════════════════════════════╗   │
│     ║  ☀ SOLAR FLARE DETECTED                                  ║   │
│     ╟───────────────────────────────────────────────────────────╢   │
│     ║                                                           ║   │
│     ║  A solar flare will reach the ship in 6 hours.           ║   │
│     ║  Radiation levels will spike dramatically.                ║   │
│     ║                                                           ║   │
│     ║  ┌─────────────────────────────────────────────────────┐  ║   │
│     ║  │ [A] Shelter in cargo hold                           │  ║   │
│     ║  │     Crew safe. 12 hours productivity lost.          │  ║   │
│     ║  ├─────────────────────────────────────────────────────┤  ║   │
│     ║  │ [B] Continue with shielding                         │  ║   │
│     ║  │     Minor radiation. Equipment risk.                │  ║   │
│     ║  ├─────────────────────────────────────────────────────┤  ║   │
│     ║  │ [C] Emergency power to shields                      │  ║   │
│     ║  │     Full protection. 2 days battery drain.          │  ║   │
│     ║  └─────────────────────────────────────────────────────┘  ║   │
│     ╚═══════════════════════════════════════════════════════════╝   │
│                                                                     │
│     [Background: Solar flare approaching, ship in path]            │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

**Popup Animation:**
1. **Approach** (0.3s): Slides in from right with momentum
2. **Settle** (0.1s): Slight overshoot, bounce back
3. **Glow pulse** (looping): Border subtly pulses
4. **AI consideration** (0.5-1s): Options highlight sequentially
5. **Selection** (0.2s): Chosen option glows, others fade
6. **Exit** (0.3s): Slides out, consequence animation triggers

### Mars Approach Sequence

The crescendo of Phase 2:

| Day | Mars Size | Visual Details | Emotional Peak |
|-----|-----------|----------------|----------------|
| 140 | 2px dot | First visible orange glow | "There it is" |
| 150 | 8px dot | Clearly not a star | Hope confirmed |
| 160 | 20px disk | Surface features hint | Getting close |
| 170 | 50px disk | Polar caps visible | Almost there |
| 175 | 100px disk | Deceleration burn begins | Point of commitment |
| 180 | 200px disk | Fills significant screen area | Overwhelming presence |
| 182 | 400px disk | Orbital insertion | Arrival |
| 183 | Full screen | Landing transition | Phase complete |

---

## AI Playability

### Decision Framework

The AI plays **optimally with dramatic hesitation**:

```gdscript
func ai_make_decision(event: Dictionary) -> int:
    var optimal_choice = calculate_optimal_choice(event)

    # 15% chance to delay for tension
    if randf() < 0.15:
        await visual_consideration_delay(1.0)
    else:
        await visual_consideration_delay(0.3)

    # 10% chance to make suboptimal choice for drama
    # (never if it would cause guaranteed failure)
    if randf() < 0.10 and not is_critical_decision(event):
        return get_dramatic_alternative(event, optimal_choice)

    return optimal_choice
```

### Observable Decision Moments

When AI decides, the spectator sees:

1. **Event appears** with dramatic popup
2. **Options highlight** one by one (0.2s each)
3. **Consideration pause** (0.3-1s based on severity)
4. **Selection glow** on chosen option
5. **Consequence animation** plays
6. **Status updates** with visual feedback

### Auto-Advance Rules

| Condition | Behavior | Visual |
|-----------|----------|--------|
| **All green** | Fast advance (0.5s/day) | Days blur past |
| **Yellow warnings** | Normal advance (2s/day) | Standard pace |
| **Orange/Red** | Slow advance (4s/day) | Tension building |
| **Event triggered** | Full stop | Dramatic interrupt |
| **Crisis active** | No auto-advance | Real-time tension |

---

## Scene Structure

### Main Scene: `phase2_main.tscn`

```
Phase2Main (Control)
├── BackgroundLayer
│   ├── DeepSpace (ColorRect gradient)
│   ├── StarField (Node2D with _draw)
│   └── Nebula (Node2D with particles)
├── GameLayer
│   ├── JourneyBar
│   │   ├── EarthDot
│   │   ├── Track
│   │   ├── ShipIcon
│   │   └── MarsDot
│   ├── ShipView
│   │   ├── ShipExterior (main visual)
│   │   ├── EngineTrail (particles)
│   │   └── StatusOverlay
│   └── MarsApproach
│       └── MarsSprite (growing)
├── UILayer
│   ├── DayCounter
│   ├── ResourcePanel
│   │   ├── FoodBar
│   │   ├── WaterBar
│   │   ├── OxygenGauge
│   │   ├── PowerBar
│   │   └── FuelTank
│   ├── CrewPanel
│   │   ├── CrewPortrait1-4
│   │   └── MoodIndicators
│   └── EventLog
├── EventLayer
│   └── EventPopup (hidden until triggered)
└── EffectsLayer
    ├── ScreenShake
    ├── ColorOverlay
    └── TransitionFade
```

### State Management

Uses existing `travel_reducer.gd` with Phase 2 state shape:

```gdscript
var phase2_state = {
    "day": 1,
    "total_days": 183,
    "resources": {
        "food": { "current": 400, "max": 500, "daily_consumption": 4 },
        "water": { "current": 200, "max": 250, "daily_consumption": 2 },
        "oxygen": { "current": 100, "max": 100, "generation_rate": 99 },
        "power": { "current": 45, "max": 50, "consumption": 44 },
        "fuel": { "current": 100, "max": 100, "burn_rate": 0 }
    },
    "crew": [
        { "id": "commander", "health": 100, "morale": 85, "fatigue": 10, "task": "pilot_watch" },
        # ... other crew
    ],
    "components": {
        "engine": { "quality": 85, "state": "operational" },
        "life_support": { "quality": 72, "state": "operational" },
        # ... other components
    },
    "journey": {
        "progress": 0.0,  # 0 to 1
        "mars_visible": false,
        "in_deceleration": false
    },
    "events": {
        "active_event": null,
        "event_log": []
    }
}
```

---

## Implementation Checklist

### Phase 1: Core Loop (MVP)
- [ ] Scene structure created
- [ ] Day counter with increment animation
- [ ] Basic resource bars with depletion
- [ ] Journey progress bar
- [ ] Simple star field background
- [ ] Auto-advance timer

### Phase 2: Visual Foundation
- [ ] Ship exterior sprite/drawing
- [ ] Engine trail particles
- [ ] Mars dot (static, then growing)
- [ ] Earth dot (static, then shrinking)
- [ ] Day/night lighting cycle

### Phase 3: Resource Visualization
- [ ] Food segmented bar with consumption animation
- [ ] Water liquid fill with drain animation
- [ ] Oxygen circular gauge with sweep
- [ ] Power lightning segments
- [ ] Fuel tank with level and slosh

### Phase 4: Crew Display
- [ ] Crew portraits with mood states
- [ ] Mood indicator colors
- [ ] Task assignment display
- [ ] Relationship visualization (optional)

### Phase 5: Event System
- [ ] Event popup component
- [ ] Popup animation (slide, settle, pulse)
- [ ] AI decision visualization
- [ ] Consequence animations
- [ ] Event log feed

### Phase 6: Spectacle Polish
- [ ] Scale distortion moments
- [ ] Screen shake system
- [ ] Color overlay for emotions
- [ ] Mars approach crescendo
- [ ] Transition to Phase 3

### Phase 7: Audio Integration
- [ ] Engine hum (ambient)
- [ ] Resource consumption sounds
- [ ] Event alert sounds
- [ ] Crew mood sounds
- [ ] Mars approach music swell

---

## File Structure

```
scenes/mars_odyssey_trek/
├── phase2_main.tscn
├── phase2_main.gd
├── components/
│   ├── journey_bar.tscn
│   ├── resource_panel.tscn
│   ├── crew_panel.tscn
│   ├── event_popup.tscn
│   ├── ship_view.tscn
│   └── mars_approach.tscn
└── effects/
    ├── star_field.gd
    ├── engine_trail.gd
    └── screen_effects.gd

scripts/mars_odyssey_trek/
├── phase2/
│   ├── phase2_controller.gd
│   ├── phase2_ai.gd
│   ├── phase2_events.gd
│   └── phase2_visuals.gd
```

---

## Summary

Phase 2 is the **endurance test**. The visual language is scale distortion—showing the ship as infinitely small against the void, then intimate and human inside. The AI makes optimal decisions with dramatic timing, creating a compelling spectacle for observers.

Every day that passes should feel like survival. Every resource that depletes should feel like loss. And when Mars appears on the horizon, it should feel like salvation.

**This is cinema. This is poetry. This is 12/10.**
