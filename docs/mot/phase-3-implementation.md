# Phase 3: Mars Base - Implementation Spec

> **Core Fantasy:** Colony Governor
> **Primary Tension:** Scientific Goals vs Survival
> **Visual Mode:** Scale Distortion - the alien vastness and the fragile bubble of life

---

## Emotional Arc

### The Journey of Achievement

Phase 3 is a **builder's arc** interrupted by **survival horror**:

```
EMOTION
   ↑
   │  Landing   Base        First       The         Storm       Departure
   │  Triumph   Building    Science     Great       Ends        Prep
   │  ┌────┐    ┌────┐      ┌────┐      Storm       ┌────┐      ┌────┐
   │  │  ↗ │    │ ↗  │      │  ↗ │      ┌────┐      │  ↗ │      │ ↗  │
   │  │ ↗  │→→→→│↗   │→→→→→→│ ↗  │→→→→→→│  ↘ │→→→→→→│ ↗  │→→→→→→│↗   │
   │  │↗   │    │    │      │↗   │      │   ↘│      │↗   │      │    │
   └──┴────┴────┴────┴──────┴────┴──────┴────┴──────┴────┴──────┴────┴──→
      WONDER    CREATION    PURPOSE     SIEGE       SURVIVAL    BITTERSWEET
      Sol 1     Sol 10      Sol 30      Sol 60      Sol 90      Sol 120
```

### The Four Acts

| Act | Sols | Emotion | Visual Tone | Key Events |
|-----|------|---------|-------------|------------|
| **ACT 1: Arrival** | 1-15 | Wonder, accomplishment | Mars rust, blue sky edges | Landing, first steps, base deployment |
| **ACT 2: Building** | 16-45 | Purpose, progress | Warm base glow against red dust | Construction, first experiments, growth |
| **ACT 3: The Great Dust Storm** | 46-80 | Siege, despair, endurance | Dark rust, no sun, flickering lights | Storm hits, confinement, crisis management |
| **ACT 4: Departure** | 81-120 | Recovery, bittersweet | Clearing skies, golden light | Storm clears, final science, leaving the base |

---

## Story Beats

### Act 1: Arrival (Sols 1-15)

| Beat | Sol | Visual | Audio | Emotion |
|------|-----|--------|-------|---------|
| **Descent** | 1 | Fiery reentry, parachutes, retro-rockets | Roar, then silence | Terror to relief |
| **First Steps** | 1 | Boot print in Martian soil, slow motion | Crunch of regolith, breathing | History |
| **Panorama** | 1 | Slow 360° pan of Martian landscape | Wind, emptiness | Awe |
| **Base Inflation** | 2 | Hab modules inflating, popping into shape | Hiss of pressure, thrum | Creation |
| **Systems Online** | 3 | Lights flickering on, status screens green | Beeps, hum of life support | Safety |
| **First Night** | 5 | Two moons rising, stars different from Earth | Alien ambience | Otherness |
| **Base Complete** | 10 | Camera pulls back to show full base layout | Triumphant swell | Accomplishment |
| **Earth Call** | 15 | Delayed message from home, pixelated video | Loved one's voice (delayed) | Connection |

### Act 2: Building (Sols 16-45)

| Beat | Sol | Visual | Audio | Emotion |
|------|-----|--------|-------|---------|
| **First EVA** | 16 | Suited figure against vast landscape | Breathing, footsteps | Courage |
| **Sample Collection** | 20 | Geologist picking up rocks, bagging them | Scientific chatter | Purpose |
| **Greenhouse Sprout** | 25 | First green shoots in Martian soil | Quiet wonder | Hope |
| **Solar Expansion** | 30 | New panels unfolding, power bar growing | Mechanical unfurling | Progress |
| **Deep Discovery** | 35 | Anomalous reading, investigation | Curiosity music | Mystery |
| **Crew Celebration** | 40 | Gathered in hab, milestone reached | Laughter, music | Community |
| **Weather Warning** | 45 | Dust devil in distance, atmospheric readings spike | Ominous rumble | Foreboding |

### Act 3: The Great Dust Storm (Sols 46-80)

This is the **visual centerpiece** of Phase 3.

| Beat | Sol | Visual | Audio | Emotion |
|------|-----|--------|-------|---------|
| **Storm Approaches** | 46 | Wall of dust on horizon, growing | Distant roar, building | Dread |
| **Impact** | 47 | Dust engulfs base, visibility zero | Roar, sand against hull | Overwhelm |
| **Darkness Falls** | 48 | Solar panels buried, power dropping | Alarms, failing systems | Panic |
| **Rationing Begins** | 50 | Power being cut to non-essentials, lights dim | Quiet desperation | Sacrifice |
| **Confinement** | 55 | Crew in cramped quarters, faces strained | Silence, tension | Claustrophobia |
| **System Failure** | 60 | Critical component fails, emergency repair | Sparks, urgent voices | Crisis |
| **The Low Point** | 65 | Everything at worst, crew exhausted | Near-silence, breathing | Despair |
| **Storm Weakens** | 70 | Dust less dense, glimmers of light | Hope music begins | Relief |
| **Breakthrough** | 75 | First sunlight through dust, panels recharging | Cheers, systems beeping | Joy |
| **Storm Clears** | 80 | Dust settling, Mars visible again | Wind dying, calm | Survival |

### Act 4: Departure (Sols 81-120)

| Beat | Sol | Visual | Audio | Emotion |
|------|-----|--------|-------|---------|
| **Damage Assessment** | 81 | Survey of storm damage, repairs beginning | Determined activity | Resolve |
| **Science Rush** | 90 | Intensive sample collection, experiments | Busy energy | Purpose |
| **Greenhouse Harvest** | 100 | Food gathered from garden, packed for return | Satisfaction sounds | Accomplishment |
| **Fuel Production** | 105 | MAV fuel tanks filling (if ISRU equipped) | Rising tone | Preparation |
| **Last Sunset** | 115 | Crew watching Martian sunset together | Reflective music | Bittersweet |
| **Base Shutdown** | 118 | Systems powering down one by one | Fading hums | Leaving |
| **MAV Launch** | 120 | Ascent from surface, base shrinking below | Roar, then silence | Farewell |
| **Orbit Achieved** | 120 | Reunited with ship, Phase 4 transition | Relief, anticipation | Continuation |

---

## Minimum Observable Loop (MOL)

### Core Loop

```
┌─────────────────────────────────────────────────────────────────┐
│                         ONE SOL                                  │
├─────────────────────────────────────────────────────────────────┤
│  1. MORNING (2s)                                                │
│     - Sol counter increments, sun rises                         │
│     - Weather forecast displays                                 │
│     - Resource status updates                                   │
│                                                                 │
│  2. OPERATIONS (2s)                                             │
│     - Crew assigned to tasks                                    │
│     - EVAs visualized if occurring                              │
│     - Experiments progress                                      │
│                                                                 │
│  3. EVENT CHECK (0-5s)                                          │
│     - Random roll for events                                    │
│     - Storm progression if active                               │
│     - Discovery moments                                         │
│                                                                 │
│  4. EVENING (1s)                                                │
│     - Sun sets, Phobos/Deimos rise                              │
│     - Power switches to battery                                 │
│     - Crew status update                                        │
│                                                                 │
│  5. NIGHT (0.5s)                                                │
│     - Base glows against dark landscape                         │
│     - Stars (different constellations than Earth)               │
│     - Loop to next sol                                          │
└─────────────────────────────────────────────────────────────────┘
```

### MOL Systems Required

| System | Required For | Complexity |
|--------|--------------|------------|
| **Sol Counter** | Time progression | Low |
| **Weather System** | Storm/normal cycles | Medium |
| **Base View** | Colony visualization | Medium |
| **EVA System** | Surface operations | Medium |
| **Science Tracker** | Experiment progress | Low |
| **Storm System** | The Great Dust Storm | High |

---

## Visual Spectacle Spec

### The Base on Mars

The hero visual is the **fragile bubble of life on an alien world**.

**Rendering Layers:**
```
Layer 12: UI (resource bars, sol counter, alerts)
Layer 11: Event popups
Layer 10: Weather overlay (dust, particles)
Layer 9:  EVA figures (when on surface)
Layer 8:  Base structures (habs, solar, greenhouse)
Layer 7:  Base glow/lights
Layer 6:  Foreground terrain (rocks, dunes)
Layer 5:  Midground landscape
Layer 4:  Background mountains/horizon
Layer 3:  Sky gradient (changes with time/weather)
Layer 2:  Dust/atmosphere particles
Layer 1:  Sun/moons position
Layer 0:  Deep sky (stars at night)
```

### Scale Distortion Moments

| Moment | Technique | Implementation |
|--------|-----------|----------------|
| **First steps** | Time Distortion | Boot hitting ground in extreme slow motion |
| **Base reveal** | Micro-Macro | Component → module → base → landscape → planet |
| **Storm approach** | The Vast Intimate | Wall of dust fills screen → reveal it's through hab window |
| **Storm confinement** | The Intimate Vast | Crew faces in cramped hab, cut to base as tiny dot in dust |
| **MAV launch** | Micro-Macro | Interior → rocket → Mars shrinking → ship approaching |

### The Great Dust Storm Sequence

The **most spectacular visual moment** of Phase 3:

**Storm Phases:**

| Phase | Duration | Visual | Audio |
|-------|----------|--------|-------|
| **Warning** | 2 sols | Distant orange wall, growing | Distant rumble |
| **Approach** | 1 sol | Wall fills horizon, blocks sun | Building roar |
| **Impact** | Instant | Screen goes orange-brown | Deafening roar |
| **Full Storm** | 30+ sols | Near-zero visibility, base as dim glow | Constant wind |
| **Peak** | 5 sols | Complete darkness, only base lights | Howling |
| **Weakening** | 5 sols | Dust thins, light returns | Wind fading |
| **Clearing** | 2 sols | Blue sky visible, sun returns | Calm |

**Storm Visual Elements:**
- Particles: 500+ dust particles at all times during storm
- Visibility: Ranges from 100% (clear) to 5% (peak storm)
- Color overlay: Orange-brown wash, intensity varies
- Solar efficiency: Drops to 10-30% during storm
- Screen shake: Constant low-level during storm
- Base lights: Flicker, strain, some go out

**Storm Sound Design:**
- Wind: Layered frequencies, shifting intensity
- Sand impact: Constant patter on hull
- Creaking: Structure under stress
- Alarms: Periodic system warnings
- Silence: Brief moments for maximum impact

### Mars Day/Night Cycle

Unlike Earth, Mars has:
- 24h 37m sol (slightly longer days)
- Blue-tinted sunsets (opposite of Earth)
- Two moons (Phobos, Deimos) - fast-moving
- Different constellations

**Visual implementation:**
```gdscript
# Sol cycle timing (12 real seconds = 1 sol)
const SOL_DURATION = 12.0

# Sky colors by time
const SKY_DAWN = Color(0.8, 0.4, 0.3)      # Rust/salmon
const SKY_DAY = Color(0.7, 0.5, 0.4)       # Butterscotch
const SKY_DUSK = Color(0.3, 0.4, 0.6)      # Blue-tinted (Mars magic)
const SKY_NIGHT = Color(0.05, 0.05, 0.1)   # Near-black

# Sun color at horizon (blue on Mars!)
const SUN_HORIZON = Color(0.4, 0.5, 0.8)
const SUN_HIGH = Color(1.0, 0.95, 0.9)
```

### EVA Visualization

Crew members outside the base:

**EVA Elements:**
- Suited figures (scaled to show human vs landscape)
- Footprint trails in dust
- Sample collection animations
- Dust kicked up by movement
- Suit status indicators (O2, power)
- Distance from base indicator

**Scale Distortion:**
Single human figure against massive Martian landscape. The intimate vast in action.

### Greenhouse/ISRU Visualization

Life support on Mars:

**Greenhouse:**
- Green interior glow
- Plants visible through transparent panels
- Growth progress (sprouts → mature plants)
- Harvest animation
- Failure state: plants wilting, brown

**Water/Fuel Production (ISRU):**
- Extraction equipment with moving parts
- Resource tanks filling over time
- Steam/vapor effects
- Progress bars for production

---

## AI Playability

### Decision Framework

The AI manages **survival vs science balance**:

```gdscript
func ai_decide_priority():
    var survival_risk = calculate_survival_risk()
    var science_opportunity = calculate_science_value()

    if survival_risk > 0.7:
        return "SURVIVAL_FOCUS"  # All crew to maintenance/repair
    elif storm_active:
        return "HUNKER_DOWN"     # Minimize activity
    elif science_opportunity > 0.8:
        return "SCIENCE_PUSH"    # Extra EVAs, experiments
    else:
        return "BALANCED"        # Normal operations
```

### Observable Decision Moments

During the storm:
1. Power dropping - which systems to shut down?
2. Crew conflict - how to resolve tension?
3. Emergency repair - risk EVA in storm?
4. Rationing - how severe?

Each decision gets the popup treatment with AI consideration animation.

---

## Scene Structure

### Main Scene: `phase3_main.tscn`

```
Phase3Main (Control)
├── EnvironmentLayer
│   ├── Sky (ColorRect with gradient)
│   ├── Sun (Sprite2D)
│   ├── Moons (Phobos, Deimos)
│   ├── Stars (night only)
│   ├── Mountains (parallax background)
│   └── Terrain (foreground)
├── WeatherLayer
│   ├── DustParticles
│   ├── WindLines
│   └── StormOverlay
├── BaseLayer
│   ├── BaseGrid (hex layout)
│   ├── Modules (hab, lab, greenhouse, etc.)
│   ├── SolarPanels
│   ├── Connections (airlocks, tunnels)
│   └── BaseLighting
├── CrewLayer
│   ├── EVAFigures (when outside)
│   └── InteriorCrew (when inside)
├── UILayer
│   ├── SolCounter
│   ├── WeatherForecast
│   ├── ResourcePanel
│   ├── ScienceTracker
│   ├── CrewPanel
│   └── StormMeter (when applicable)
├── EventLayer
│   └── EventPopup
└── EffectsLayer
    ├── ScreenShake
    ├── ColorOverlay
    └── TransitionFade
```

---

## Implementation Checklist

### Phase 1: Core Loop (MVP)
- [ ] Sol counter with day/night cycle
- [ ] Basic base visualization (top-down or isometric)
- [ ] Resource bars (power, food, water, oxygen)
- [ ] Weather display (clear/storm)
- [ ] Auto-advance timer

### Phase 2: Mars Environment
- [ ] Sky gradient with time-of-day changes
- [ ] Sun path across sky
- [ ] Moons rising/setting
- [ ] Stars at night
- [ ] Martian terrain background

### Phase 3: Base Systems
- [ ] Module placement on grid
- [ ] Solar panel efficiency visualization
- [ ] Power generation/consumption display
- [ ] Greenhouse growth progress
- [ ] Base lights (on at night)

### Phase 4: The Great Dust Storm
- [ ] Storm warning sequence
- [ ] Storm approach animation
- [ ] Full storm dust particles
- [ ] Visibility reduction
- [ ] Solar efficiency drop
- [ ] Storm sound design
- [ ] Storm clearing sequence

### Phase 5: EVA and Science
- [ ] EVA crew figures on surface
- [ ] Sample collection animation
- [ ] Science experiment progress
- [ ] Discovery event popups
- [ ] Greenhouse harvest

### Phase 6: Departure
- [ ] MAV preparation sequence
- [ ] Base shutdown animation
- [ ] MAV launch sequence
- [ ] Transition to Phase 4

---

## File Structure

```
scenes/mars_odyssey_trek/
├── phase3_main.tscn
├── phase3_main.gd
├── components/
│   ├── base_grid.tscn
│   ├── weather_system.tscn
│   ├── mars_environment.tscn
│   ├── storm_effects.tscn
│   ├── eva_system.tscn
│   └── science_tracker.tscn
└── effects/
    ├── dust_storm.gd
    ├── day_night_cycle.gd
    └── mars_sky.gd

scripts/mars_odyssey_trek/
├── phase3/
│   ├── phase3_controller.gd
│   ├── phase3_ai.gd
│   ├── phase3_weather.gd
│   ├── phase3_storm.gd
│   └── phase3_visuals.gd
```

---

## Summary

Phase 3 is **creation under siege**. The visual language contrasts the warm glow of human life against the cold hostility of Mars. The Great Dust Storm is the dramatic centerpiece - a weeks-long siege that tests everything.

**Key spectacle moments:**
1. **First steps** on Mars in extreme slow motion
2. **Base reveal** as camera pulls back to show the completed colony
3. **Storm approach** as wall of dust fills the horizon
4. **Storm survival** with flickering lights and howling wind
5. **MAV launch** leaving the base behind forever

The emotional core: **You built something beautiful on Mars. You have to leave it behind.**

**This is 12/10. This is poetry on an alien world.**
