# Phase 4: Return Trip - Implementation Spec

> **Core Fantasy:** Desperate Survivor
> **Primary Tension:** Degraded Systems vs Hope
> **Visual Mode:** Scale Distortion - the worn ship and the growing home

---

## Emotional Arc

### The Journey Home

Phase 4 is **exhausted hope**. Everything is worn, everyone is tired, but Earth is calling.

```
EMOTION
   ↑
   │  Departure    Worn        Scarcity    Crisis     Earth       Reentry
   │  Weariness    Routine     Fear        Peak       Visible     Triumph
   │  ┌────┐       ┌────┐      ┌────┐      ┌────┐     ┌────┐      ┌────┐
   │  │    │       │    │      │   ↘│      │  ↗ │     │  ↗ │      │  ↗ │
   │  │────│→→→→→→→│──↘─│→→→→→→│    │→→→→→→│ ↗  │→→→→→│ ↗  │→→→→→→│ ↗  │
   │  │    │       │   ↘│      │     ↘     │↗   │     │↗   │      │↗   │
   └──┴────┴───────┴────┴──────┴─────┴─────┴────┴─────┴────┴──────┴────┴──→
      FATIGUE      DECAY       DESPERATION TURNAROUND HOPE        RESOLUTION
      Day 1        Day 50      Day 100     Day 140    Day 180     Day 210
```

### The Narrative Shift from Phase 2

Phase 4 is **structurally similar** to Phase 2 but **emotionally different**:

| Aspect | Phase 2 (Outbound) | Phase 4 (Return) |
|--------|-------------------|------------------|
| Ship state | Fresh, untested | Worn, proven |
| Supplies | Full cargo | Whatever remains |
| Crew | Healthy, eager | Tired, scarred |
| Dangers | Unknown | Known fears |
| Destination | Alien world | Home |
| Emotion | **Excitement** | **Exhausted hope** |
| Visual tone | Clean, bright | Degraded, flickering |
| Music | Adventure | Melancholy → triumph |

---

## Story Beats

### Act 1: Departure (Days 1-30)

| Beat | Day | Visual | Audio | Emotion |
|------|-----|--------|-------|---------|
| **MAV Rendezvous** | 1 | Ship in Mars orbit, MAV approaching | Docking clunks | Relief |
| **Crew Reunion** | 1 | Crew floating in airlock, embracing | Quiet joy | Connection |
| **Ship Assessment** | 2 | Camera tours ship, damage visible | Creaking, systems groaning | Concern |
| **Trans-Earth Injection** | 3 | Engine burn, Mars shrinking | Roar, then silence | Commitment |
| **Last Mars View** | 5 | Mars becoming dot, crew watching | Reflective music | Farewell |
| **Taking Stock** | 10 | Inventory of remaining supplies | Quiet counting | Scarcity awareness |
| **Ship Rattles** | 15 | Component shudders, warning flickers | Mechanical protest | Worry |
| **The Long Haul Begins** | 30 | Routine established, weariness setting in | Tired silence | Resignation |

### Act 2: The Worn Journey (Days 31-100)

| Beat | Day | Visual | Audio | Emotion |
|------|-----|--------|-------|---------|
| **First Major Failure** | 40 | Component goes critical, sparks fly | Alarm, urgent repair sounds | Crisis |
| **Improvised Repair** | 41 | Jury-rigged fix, duct tape visible | Tools, determination | Resourcefulness |
| **Rationing Decision** | 50 | Crew looking at dwindling supplies | Difficult conversation | Sacrifice |
| **Crew Exhaustion** | 60 | Hollow eyes, slow movements | Fatigue sounds | Weariness |
| **Second Crisis** | 75 | Another system failing, cascade risk | Layered alarms | Desperation |
| **Crew Conflict** | 80 | Tension exploding, angry words | Sharp voices | Fracture |
| **Reconciliation** | 85 | Crew making up, shared purpose | Quiet understanding | Unity |
| **Half Way Home** | 100 | "MIDPOINT" display, Earth and Mars equidistant | Somber marker | Determination |

### Act 3: The Descent (Days 101-160)

| Beat | Day | Visual | Audio | Emotion |
|------|-----|--------|-------|---------|
| **Systems Critical** | 110 | Multiple yellow/orange indicators | Constant low alarm | Tension |
| **Resource Reckoning** | 120 | Will we make it? Calculations | Nervous math | Anxiety |
| **Personal Mission Resolution** | 130 | Crew member's arc completes | Character music | Closure |
| **Crew Illness** | 140 | Someone sick, medical depleted | Coughing, worry | Vulnerability |
| **Recovery** | 145 | Sick crew member improving | Relief sounds | Hope |
| **First Earth Light** | 150 | Blue-white dot visible | Musical hint | Hope swelling |
| **The Fuel Question** | 160 | "Do we have enough?" displayed | Tension music | Anxiety |

### Act 4: The Approach (Days 161-210)

| Beat | Day | Visual | Audio | Emotion |
|------|-----|--------|-------|---------|
| **Earth Visible** | 165 | Blue marble, growing daily | Rising hope music | Longing |
| **Lunar Passage** | 180 | Moon visible, familiar | Almost home | Recognition |
| **Deceleration Burn** | 190 | Engine firing, ship shuddering | Roar, shake | Commitment |
| **Earth Fills Screen** | 200 | Blue planet dominating view | Crescendo | Overwhelming |
| **Orbit Achieved** | 205 | Stable Earth orbit | Relief swell | Safety (almost) |
| **Reentry Prep** | 208 | Checklist, systems check, crew strapping in | Focused tension | Final hurdle |
| **The Blackout** | 209 | Plasma flames, communication lost | Roar, then silence | Terror |
| **Landing** | 210 | Parachute, touchdown, stillness | Impact, then peace | Completion |

---

## The Degraded Aesthetic

Phase 4's defining visual is **worn technology**:

### Visual Degradation Elements

| Element | Fresh (Phase 2) | Worn (Phase 4) |
|---------|-----------------|----------------|
| UI panels | Clean, crisp | Flickering, glitchy |
| Status lights | Steady glow | Occasional flicker |
| Component icons | Full color | Desaturated, cracks |
| Text displays | Clear | Occasional artifacts |
| Background hum | Smooth | Rattling undertone |
| Color palette | Vibrant | Muted, yellowed |

### Degradation Implementation

```gdscript
# Visual wear system
func apply_degradation(element: Control, wear_level: float):
    # wear_level: 0.0 (fresh) to 1.0 (critical)

    # Color desaturation
    element.modulate.s = lerp(1.0, 0.5, wear_level)

    # Occasional flicker
    if wear_level > 0.3:
        start_flicker_timer(element, 1.0 - wear_level)

    # Scan line effect at high wear
    if wear_level > 0.7:
        apply_scanline_shader(element)

    # Screen tear at critical
    if wear_level > 0.9:
        apply_tear_shader(element)
```

### UI Degradation Over Time

```
Day 1:    [████████████████████] Clean, bright
Day 50:   [██████████████████░░] Slight wear, occasional flicker
Day 100:  [████████████░░░░░░░░] Visible degradation, more flickers
Day 150:  [██████░░░░░░░░░░░░░░] Significant wear, constant flickers
Day 200:  [████░░░░░░░░░░░░░░░░] Critical wear, scan lines, tears
```

---

## Minimum Observable Loop (MOL)

Phase 4 reuses the Phase 2 loop with **degradation overlay**:

### Core Loop

```
┌─────────────────────────────────────────────────────────────────┐
│                    ONE DAY (PHASE 4)                            │
├─────────────────────────────────────────────────────────────────┤
│  1. MORNING STATUS (2s)                                         │
│     - Day counter (flickering if worn)                          │
│     - Resource bars (showing scarcity)                          │
│     - Crew status (fatigue prominent)                           │
│     - Degradation pulse on worn elements                        │
│                                                                 │
│  2. DAILY TICK (1s)                                             │
│     - Resources deplete (more precious now)                     │
│     - Components degrade FASTER                                 │
│     - Crew fatigue accumulates                                  │
│     - Random chance of system hiccup                            │
│                                                                 │
│  3. EVENT CHECK (0-5s)                                          │
│     - Higher chance of component failures                       │
│     - Crew events more likely (exhaustion)                      │
│     - Hope events as Earth approaches                           │
│                                                                 │
│  4. PROGRESS UPDATE (1s)                                        │
│     - Ship moves toward Earth                                   │
│     - Earth grows larger                                        │
│     - Mars shrinks (farewell)                                   │
│                                                                 │
│  5. NIGHT TRANSITION (0.5s)                                     │
│     - Lights dim (but some flicker)                             │
│     - Systems creak                                             │
│     - Loop to next day                                          │
└─────────────────────────────────────────────────────────────────┘
```

### Additional MOL Elements for Phase 4

| System | Purpose | Phase 4 Specific |
|--------|---------|------------------|
| **Degradation overlay** | Show wear | Flickering, desaturation |
| **Earth approach visual** | Hope grows | Blue dot → marble → world |
| **Scarcity indicators** | Tension | Red zones on resource bars |
| **Reentry sequence** | Climax | Plasma, blackout, landing |
| **Ending cinematics** | Resolution | Victory tier presentation |

---

## Visual Spectacle Spec

### The Worn Ship

The hero visual of Phase 4 is **the ship that made it**.

**Rendering Layers:**
```
Layer 12: UI (degraded, flickering)
Layer 11: Event popups (worn aesthetic)
Layer 10: Warning overlays (more frequent)
Layer 9:  Ship interior (damage visible)
Layer 8:  Ship exterior (scars, patches)
Layer 7:  Engine trail (sputtering)
Layer 6:  Earth (growing)
Layer 5:  Moon (as approached)
Layer 4:  Sun (from different angle)
Layer 3:  Nebulae (familiar from Phase 2)
Layer 2:  Star field (same stars, coming home)
Layer 1:  Deep black
```

### Scale Distortion Moments

| Moment | Technique | Implementation |
|--------|-----------|----------------|
| **MAV rendezvous** | Micro-Macro | Interior → airlock → ships docking → Mars orbit |
| **Earth first visible** | The Vast Intimate | Blue dot fills screen, reveal it's a sensor reading |
| **Fuel question** | Focus Pull | Fuel gauge → star field → Earth in distance |
| **Reentry** | Time Distortion | Extreme slow motion on plasma forming |
| **Landing** | Micro-Macro | Capsule → parachute → landscape → touchdown |

### Earth Approach Sequence

The **emotional crescendo** of the entire game:

| Day | Earth Size | Visual Details | Emotional Peak |
|-----|------------|----------------|----------------|
| 150 | 2px dot | Blue-white, distinct from stars | "There it is" |
| 160 | 5px dot | Clearly a planet | Hope confirmed |
| 170 | 15px disk | Continents hinted | Getting close |
| 180 | 30px disk | Moon visible nearby | Lunar passage |
| 190 | 60px disk | Weather patterns visible | Deceleration |
| 200 | 150px disk | Fills significant screen | Overwhelming beauty |
| 205 | 300px disk | Orbit achieved | Almost home |
| 208 | Screen | Reentry approach | Final hurdle |

### The Reentry Sequence

The **most spectacular moment** of Phase 4:

**Reentry Phases:**

| Phase | Duration | Visual | Audio |
|-------|----------|--------|-------|
| **Approach** | 2s | Earth growing, trajectory line | Focused tension music |
| **Angle Check** | 1s | "Entry angle: NOMINAL" | Confirmation beeps |
| **Interface** | 1s | First wisps of atmosphere | Hiss begins |
| **Plasma Onset** | 2s | Orange glow building around capsule | Roar building |
| **Full Plasma** | 5s | Capsule engulfed in fire, brilliant orange-white | Deafening roar |
| **The Blackout** | 4s | Communication lost, screen static/black | Silence. Heartbeat |
| **Signal Return** | 1s | Static clears, "SIGNAL ACQUIRED" | Relief surge |
| **Chute Deploy** | 2s | Parachute bursting open, jerk | Fabric snap, tension |
| **Descent** | 3s | Drifting down, landscape visible | Wind, anticipation |
| **Touchdown** | 1s | Impact, dust/water, stillness | Thud, then silence |
| **Hatch Open** | 3s | Light flooding in, first breath | Birds, wind, life |

**Reentry Visual Elements:**
- Plasma: Particle system, 200+ particles, orange-white gradient
- Heat shimmer: Distortion shader around capsule
- Vibration: Intense screen shake, decay during chute
- Blackout: Actual black screen with only heartbeat audio
- Earth: Landscape revealed during descent (ocean or land)
- Recovery: Helicopters, boats, depending on landing type

---

## The Endings

### Victory Tiers

| Tier | Requirement | Visual Treatment | Music | Emotion |
|------|-------------|------------------|-------|---------|
| **Gold** | 4 crew, all science, under budget | Brilliant sunlight, cheering crowds | Triumphant fanfare | Pure joy |
| **Silver** | 3+ crew, primary science | Warm light, relieved smiles | Hopeful swell | Satisfaction |
| **Bronze** | 1+ crew returns | Single figure, exhausted but alive | Somber triumph | Survival |
| **Pyrrhic** | No crew, data transmitted | Empty capsule, but data received | Bittersweet | Sacrifice honored |
| **Failure** | Total loss | Black screen, memorial text | Silence, then elegy | Grief |

### Ending Cinematics

**Gold Ending:**
```
[Hatch opens]
→ [4 crew members emerge, one by one]
→ [Cheering crowd, waving flags]
→ [Family reunions, tears of joy]
→ [Mission logo, "MISSION: COMPLETE"]
→ [Score breakdown with achievements]
→ [Credits with crew epilogues]
```

**Bronze Ending:**
```
[Hatch opens]
→ [Single crew member, barely able to stand]
→ [Medical team rushing in]
→ [Stretcher, but they're alive]
→ [Hospital bed, looking out window at sky]
→ [Text: "Against all odds, [Name] came home."]
→ [Score breakdown]
```

**Pyrrhic Ending:**
```
[Empty capsule on ocean]
→ [Data drives being recovered]
→ [Scientists in lab, reviewing data]
→ [Breakthrough discovery moment]
→ [Memorial wall with crew portraits]
→ [Text: "Their sacrifice opened the door to the stars."]
→ [Score breakdown]
```

### Score Breakdown Display

```
┌─────────────────────────────────────────────────────────────────┐
│                     MISSION COMPLETE                            │
│                        ★★★ GOLD ★★★                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  CREW SURVIVAL                                                  │
│  ████████████████████████████████████████ 4/4    +400 pts      │
│                                                                 │
│  SCIENCE COMPLETED                                              │
│  ██████████████████████████████████░░░░░░ 85%    +340 pts      │
│                                                                 │
│  BUDGET EFFICIENCY                                              │
│  ████████████████████████████░░░░░░░░░░░░ 72%    +216 pts      │
│                                                                 │
│  MISSION DURATION                                               │
│  ██████████████████████████████████████░░ 190d   +95 pts       │
│                                                                 │
│  PERSONAL MISSIONS                                              │
│  ████████████████████████░░░░░░░░░░░░░░░░ 2/4    +100 pts      │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│                     TOTAL SCORE: 1,151                          │
│                                                                 │
│                    [PLAY AGAIN]  [MAIN MENU]                    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## AI Playability

### Decision Framework

The AI plays **optimally but tired**:

```gdscript
func ai_make_decision_phase4(event: Dictionary) -> int:
    var optimal_choice = calculate_optimal_choice(event)

    # Higher chance of hesitation (exhaustion)
    var hesitation_chance = 0.25  # vs 0.15 in Phase 2
    if randf() < hesitation_chance:
        await visual_consideration_delay(1.5)  # Longer delays
    else:
        await visual_consideration_delay(0.5)

    # Slightly higher chance of suboptimal (fatigue errors)
    # But NEVER on truly critical decisions
    var error_chance = 0.12  # vs 0.10 in Phase 2
    if randf() < error_chance and not is_life_threatening(event):
        return get_fatigue_choice(event, optimal_choice)

    return optimal_choice
```

### Observable Exhaustion

The AI's decisions should **feel tired**:
- Longer pauses before decisions
- Occasional hesitation on obvious choices
- Relief visible when crisis passes
- Determination on critical moments

---

## Scene Structure

Phase 4 **reuses Phase 2 structure** with modifications:

### Main Scene: `phase4_main.tscn`

```
Phase4Main (extends Phase2Main)
├── [All Phase 2 elements]
├── DegradationSystem
│   ├── FlickerController
│   ├── DesaturationShader
│   └── ScanlineOverlay
├── EarthApproach (replaces MarsApproach)
│   └── EarthSprite (with Moon)
├── ReentrySequence
│   ├── PlasmaParticles
│   ├── HeatShimmer
│   ├── BlackoutOverlay
│   ├── ChuteAnimation
│   └── LandingSequence
└── EndingCinematics
    ├── GoldEnding
    ├── SilverEnding
    ├── BronzeEnding
    ├── PyrrhicEnding
    ├── FailureEnding
    └── ScoreBreakdown
```

---

## Implementation Checklist

### Phase 1: Reuse Phase 2
- [ ] Clone Phase 2 scene structure
- [ ] Adjust journey direction (Mars → Earth)
- [ ] Replace Mars approach with Earth approach
- [ ] Update state initialization (degraded start)

### Phase 2: Degradation System
- [ ] Flicker controller for UI elements
- [ ] Desaturation shader
- [ ] Scan line effect
- [ ] Screen tear effect
- [ ] Component wear visualization

### Phase 3: Earth Approach
- [ ] Earth sprite with growth animation
- [ ] Moon passage visualization
- [ ] Lunar orbit option (if damaged)
- [ ] Deceleration burn effects

### Phase 4: Reentry Sequence
- [ ] Plasma particle system
- [ ] Heat shimmer shader
- [ ] Screen shake (intense)
- [ ] Blackout with heartbeat
- [ ] Parachute deployment
- [ ] Landing animation (ocean/land)

### Phase 5: Endings
- [ ] Victory tier calculation
- [ ] Gold ending cinematic
- [ ] Silver ending cinematic
- [ ] Bronze ending cinematic
- [ ] Pyrrhic ending cinematic
- [ ] Failure ending cinematic
- [ ] Score breakdown display

### Phase 6: Audio
- [ ] Degraded system sounds (creaking, sputtering)
- [ ] Reentry audio design
- [ ] Ending music for each tier
- [ ] Heartbeat during blackout

---

## File Structure

```
scenes/mars_odyssey_trek/
├── phase4_main.tscn
├── phase4_main.gd
├── components/
│   ├── degradation_system.tscn
│   ├── earth_approach.tscn
│   ├── reentry_sequence.tscn
│   └── ending_cinematics.tscn
└── effects/
    ├── plasma_effect.gd
    ├── degradation_shader.gdshader
    └── landing_sequence.gd

scripts/mars_odyssey_trek/
├── phase4/
│   ├── phase4_controller.gd
│   ├── phase4_ai.gd
│   ├── phase4_degradation.gd
│   ├── phase4_reentry.gd
│   └── phase4_endings.gd
```

---

## Summary

Phase 4 is **exhausted triumph**. The visual language is degradation—showing that everything is worn, but still working. The ship that left fresh and new now creaks and flickers, but it carries its crew home.

**Key spectacle moments:**
1. **Earth first visible** - the blue dot that means everything
2. **Degraded UI** - every flicker tells the story of the journey
3. **The fuel question** - do we have enough? (tension held to the end)
4. **Reentry plasma** - the ship on fire, one last trial
5. **The blackout** - silence, heartbeat, will they survive?
6. **Landing** - the hatch opens, Earth air floods in
7. **Endings** - every tier earns its emotional payoff

The question isn't "will you reach Earth?" It's "who will reach Earth, and in what condition?"

**Every decision in Phase 1 echoes here. Every crisis in Phase 2 matters. Every discovery in Phase 3 is at risk. Phase 4 is the payoff for the entire journey.**

**This is 12/10. This is coming home.**
