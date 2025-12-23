# Phase 1: Ship Building - Implementation Spec

> **Core Fantasy:** NASA Project Manager
> **Primary Tension:** Budget vs Quality vs Time
> **Visual Mode:** Scale Distortion - component to ship to cosmos

---

## Current State

Phase 1 is **fully implemented** with all core mechanics. This document focuses on **spectacle enhancement** opportunities.

### What Exists

| Component | File | Status |
|-----------|------|--------|
| Main controller | `mot_main.gd` (436 lines) | Complete |
| Launch window selector | `orbital_selector.tscn` | Complete |
| Construction approach | `approach_selector.tscn` | Complete |
| Engine selection | `engine_selector.tscn` | Complete |
| Ship class selection | `ship_class_selector.tscn` | Complete |
| Life support selection | `life_support_selector.tscn` | Complete |
| Crew selection | `crew_selector.tscn` | Complete |
| Cargo loading | `cargo_loader.tscn` | Complete |
| Launch review | `launch_review.tscn` | Complete |
| Launch animation | `launch_animation.gd` (2012 lines) | Complete |

### Current Visual Quality

The launch animation is already **sophisticated**:
- 16 animation stages with timing
- Particle systems (sparks, confetti, smoke, stars)
- Star field with twinkling (180 stars)
- Nebula generation (6 clouds)
- Distant galaxies (4 objects)
- Camera shake system
- Progress tracking

---

## Emotional Arc

### The Journey of Ambition

Phase 1 builds from **anxiety to commitment**:

```
EMOTION
   ↑
   │   Budget     Component    Quality     Crew        Cargo       Launch
   │   Reveal     Choices      Testing     Selection   Loading     Commit
   │   ┌────┐     ┌────┐       ┌────┐      ┌────┐      ┌────┐      ┌────┐
   │   │ ↘  │     │ ↗↘ │       │ ↗↘ │      │  ↗ │      │  ↗ │      │  ↗ │
   │   │   ↘│→→→→→│↗  ↘│→→→→→→→│↗  ↘│→→→→→→│↗   │→→→→→→│↗   │→→→→→→│↗   │
   │   │    │     │    │       │    │      │    │      │    │      │    │
   └───┴────┴─────┴────┴───────┴────┴──────┴────┴──────┴────┴──────┴────┴──→
       ANXIETY    TRADE-OFFS   TENSION     ATTACHMENT  WEIGHT      RELEASE
```

### Story Beats by Step

| Step | Beat | Current Visual | Enhancement Opportunity |
|------|------|----------------|------------------------|
| 1. Launch Window | "When do we go?" | Orbital diagram | Animate Earth-Mars alignment, show Hohmann transfer path |
| 2. Construction | "How do we build?" | Card selection | Show shipyard scene, construction methods visually |
| 3. Engine | "What powers us?" | Card selection | Engine test firing visualization |
| 4. Ship Class | "What kind of ship?" | Card selection | Ship silhouette growing/morphing |
| 5. Life Support | "How do we breathe?" | Card selection | Life support system diagram, recycling visualization |
| 6. Crew | "Who comes with us?" | Portrait grid | Crew introduction cinematics, personality hints |
| 7. Cargo | "What do we bring?" | Sliders/inputs | Cargo bay filling, weight balance visualization |
| 8. Review | "Are we ready?" | Checklist | Full ship reveal, systems coming online |
| 9. Launch | "Here we go" | Full animation | Already spectacular - minor polish |

---

## Spectacle Enhancement Opportunities

### Priority 1: Scale Distortion Moments

Add these **Intimate Vast** / **Vast Intimate** moments:

#### Step 1: Launch Window
**Current:** Static orbital diagram
**Enhancement:**
- Animate the celestial mechanics
- Show Earth and Mars orbiting (time-lapse)
- Zoom from solar system view to Earth close-up
- Show the transfer orbit as a glowing arc
- **Scale moment:** Zoom from sun-sized view to spacecraft-sized commitment

```
[Solar System View] → [Earth Close-up] → [Your Ship at Dock] → [Launch Window Timer]
```

#### Step 3: Engine Selection
**Current:** Card-based selection
**Enhancement:**
- When engine is selected, show **test fire animation**
- Camera pulls back to reveal engine scale vs human
- Engine roar builds, flame signature establishes
- **Scale moment:** Tiny engineer adjusting massive engine

```
[Engine Card Selected] → [Zoom to Engine Bay] → [Test Fire Sequence] → [Pull Back to Ship Scale]
```

#### Step 6: Crew Selection
**Current:** Portrait grid
**Enhancement:**
- Each crew member gets a **micro-introduction**
- Show them in their element (lab, cockpit, medbay)
- Quick personality hint animation
- **Scale moment:** Individual human against the mission they're joining

```
[Portrait Selected] → [Scene of Their Expertise] → [Fade to Mission Briefing Room] → [They Join the Team]
```

#### Step 8: Launch Review
**Current:** Checklist summary
**Enhancement:**
- Full **ship reveal sequence**
- Camera orbits the completed ship
- Systems light up one by one
- **Scale moment:** The ship you built, complete, against the stars

```
[Checklist Complete] → [Dock Doors Open] → [Ship Reveal with Lighting] → [Camera Orbit] → [Ready for Launch]
```

### Priority 2: Budget Tension Visualization

Make the budget constraint **visceral**:

#### Budget Bar Enhancement
**Current:** Text display with color coding
**Enhancement:**
- Budget bar is a **fuel gauge metaphor**
- Each purchase shows money "draining"
- Low budget triggers **warning klaxon aesthetic**
- Over-budget shows **red zone, alarms**

```gdscript
# Budget visualization states
const BUDGET_HEALTHY = "green_glow"      # > 50% remaining
const BUDGET_CAUTIOUS = "yellow_pulse"   # 20-50% remaining
const BUDGET_LOW = "orange_flicker"      # 5-20% remaining
const BUDGET_CRITICAL = "red_alarm"      # < 5% remaining
const BUDGET_OVER = "red_flash_shake"    # Negative
```

#### Purchase Animation
When something is bought:
1. Item card glows with selection
2. Price number floats toward budget bar
3. Budget bar drains with liquid animation
4. If over budget: screen flash, warning sound

### Priority 3: Quality Testing Visualization

Show the **testing loop** dramatically:

**Current:** Implied in balance data
**Enhancement:**
- Add optional "test component" sequence
- Show diagnostic hologram overlay on component
- Quality meter fills as tests complete
- Defects revealed with dramatic "found problem" animation
- **Scale moment:** Microscopic defect → ship-scale consequence

```
[Component Selected] → [Diagnostic Scan Animation] → [Quality Meter Rising]
→ [Defect Found?] → [Zoom to Defect] → [Cost to Fix Display] → [Decision]
```

---

## Launch Animation Refinements

The launch animation is already 2012 lines of sophisticated code. Minor enhancements:

### Stage Timing Adjustments

| Stage | Current | Suggestion |
|-------|---------|------------|
| COUNTDOWN | 4.0s | Add heartbeat sound, increasingly rapid |
| IGNITION | 1.5s | Add "rumble" camera micro-shake before main shake |
| LIFTOFF | 2.5s | Perfect as-is |
| STAGE_SEP | 2.0s | Add debris particles from separation |
| CRUISE | 3.0s | Add **Intimate Vast** moment - ship tiny against nebula |

### New Scale Distortion Sequence

Add a post-launch reflection moment:

```
[CRUISE stage ends]
→ [Camera pulls back rapidly]
→ [Ship becomes dot]
→ [Star field fills screen]
→ [Hold 2 seconds on the vast]
→ [Text: "183 days to Mars"]
→ [Fade to Phase 2]
```

---

## AI Playability for Phase 1

### Decision Framework

The AI makes **optimal-ish decisions with personality**:

```gdscript
var ai_personality = {
    "risk_tolerance": 0.5,  # 0 = cautious, 1 = aggressive
    "budget_priority": 0.7, # 0 = quality first, 1 = budget first
    "crew_preference": "balanced"  # "specialists" or "balanced"
}

func ai_select_engine():
    # AI considers balance of speed, cost, risk
    # With some personality-driven weighting
    # And 10% chance of "dramatic choice"
```

### Observable Selection Moments

When AI picks options:
1. Options highlight sequentially (0.2s each)
2. "Considering..." pause on 2-3 options
3. Final selection with decisive animation
4. Brief pause before advancing

---

## Implementation Checklist

### Spectacle Enhancements (Not MVP)

- [ ] Launch window orbital animation
- [ ] Engine test fire sequence
- [ ] Crew micro-introductions
- [ ] Ship reveal sequence
- [ ] Budget drain animation
- [ ] Quality testing visualization
- [ ] Launch countdown heartbeat
- [ ] Post-launch scale distortion moment

### Polish Items

- [ ] Transition animations between steps (currently instant)
- [ ] Background ambient animation (shipyard activity)
- [ ] Sound design for selections
- [ ] Music swell for commitment moments

---

## Summary

Phase 1 is **complete and functional**. The spectacle enhancements listed here are **not MVP** but would elevate the experience from "good" to "12/10."

Key opportunities:
1. **Scale distortion** at each major decision
2. **Budget as visceral resource** with drain animations
3. **Quality testing** as dramatic mini-game
4. **Ship reveal** before launch
5. **Post-launch vastness** moment

The launch animation is already spectacular. The decision phases could match that quality with the enhancements above.
