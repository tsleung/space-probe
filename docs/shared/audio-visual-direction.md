# Audio & Visual Direction

The aesthetic vision for Space Probe. Grounded sci-fi that feels real enough to touch.

---

## Visual Philosophy

### Core Principle: "NASA, Not NASA"

We're inspired by real space programs but not bound by them. Think:
- The Martian's practical, lived-in technology
- For All Mankind's alternate-history authenticity
- Apollo 13's control room tension

**NOT:**
- Star Trek's sleek futurism
- Alien's industrial horror
- Star Wars' fantasy space opera

### Art Style: Clean Information Design

**Why:** Classroom-friendly, readable on low-end hardware, timeless rather than trendy.

**Approach:**
- Clean lines, muted colors
- Information-forward UI
- Minimal but meaningful animation
- Icons over textures

```
Style Reference Scale:

Realistic ←──────────────────────→ Stylized
          NASA photos    ★ WE ARE HERE    Kerbal
```

---

## Color Palette

### Primary Colors

| Color | Hex | Use |
|-------|-----|-----|
| Space Black | `#0A0E14` | Backgrounds, space |
| Panel Gray | `#1E2530` | UI panels, ship interior |
| Steel Blue | `#4A6B8A` | Interactive elements, buttons |
| Earth Blue | `#3B82C4` | Highlights, Earth-related |
| Mars Rust | `#C45C3B` | Mars surface, warnings |

### Status Colors

| Color | Hex | Meaning |
|-------|-----|---------|
| System Green | `#4ADE80` | Healthy, good status |
| Caution Yellow | `#FACC15` | Warning, attention needed |
| Alert Orange | `#F97316` | Problem, action required |
| Critical Red | `#EF4444` | Danger, immediate action |
| Disabled Gray | `#6B7280` | Unavailable, inactive |

### Phase Accents

Each phase has a subtle accent color to reinforce mood:

| Phase | Accent | Feeling |
|-------|--------|---------|
| 1: Ship Building | Steel Blue | Professional, technical |
| 2: Travel | Deep Purple `#6366F1` | Vast, alone |
| 3: Mars Base | Mars Rust | Alien, frontier |
| 4: Return | Earth Blue → Golden `#FBBF24` | Hope, home |

---

## Typography

### Font Choices (Free, Readable)

**Primary UI:** Inter or IBM Plex Sans
- Clean, modern sans-serif
- Excellent screen readability
- Wide language support

**Data/Numbers:** IBM Plex Mono or JetBrains Mono
- Fixed-width for tables and stats
- Clear distinction between similar characters (0/O, 1/l)

**Headers:** Inter Bold or system bold
- No decorative fonts
- Readability over style

### Text Hierarchy

```
┌─────────────────────────────────────────────┐
│ PHASE TITLE                    24px Bold    │
│ Section Header                 18px Bold    │
│ Body text is readable          14px Regular │
│ Small labels and hints         12px Regular │
│ TINY STATUS TEXT               10px Bold    │
└─────────────────────────────────────────────┘
```

---

## Visual Elements

### Ship Components

**Style:** Technical diagram aesthetic
- Clean outlines, visible on dark backgrounds
- Color fills indicate status (green=healthy, red=damaged)
- Simple iconography inside shapes

```
Component Visual States:
┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐
│  ████   │  │  ████   │  │  ▒▒▒▒   │  │  ░░░░   │
│  ████   │  │  ▓▓▓▓   │  │  ▒▒▒▒   │  │  ░░░░   │
│ HEALTHY │  │ WORN    │  │ DAMAGED │  │ FAILED  │
│  100%   │  │  75%    │  │  40%    │  │   0%    │
└─────────┘  └─────────┘  └─────────┘  └─────────┘
```

### Crew Portraits

**Style:** Illustrated portraits, not photographs
- Consistent art style across all crew
- Shows personality through expression/pose
- Grayscale base with color highlights

**States:**
- Healthy: Full color, warm lighting
- Stressed: Desaturated, shadows
- Injured: Muted colors, visible concern
- Critical: Harsh shadows, urgent
- Dead: Grayscale, memorial style

### Space & Planets

**Space:**
- Deep black with subtle star field
- Minimal cosmic dust/nebulae (not distracting)
- Occasional distant objects for scale

**Earth:**
- Familiar, comforting blue
- Appears at start and end (bookends)
- Gets smaller as you travel, larger on return

**Mars:**
- Rust and ochre palette
- Visible surface features
- Feels alien but not hostile

### Hex Grid

**Ship Building Grid:**
```
  ╱─╲   ╱─╲   ╱─╲
 ╱   ╲ ╱   ╲ ╱   ╲
│     │     │     │
 ╲   ╱ ╲   ╱ ╲   ╱
  ╲─╱   ╲─╱   ╲─╱
```
- Subtle grid lines (not overwhelming)
- Valid placement hexes glow softly
- Invalid hexes dim
- Placed components fill hex cleanly

---

## Animation Guidelines

### Principle: Functional, Not Flashy

Animations serve information, not decoration.

**Do:**
- Progress bars fill smoothly
- Status changes pulse once for attention
- Transitions fade briefly (150-300ms)
- Events slide in from edge

**Don't:**
- Bouncing, spinning, excessive motion
- Long animation sequences
- Anything that delays player action
- Particle effects everywhere

### Key Animations

**Component Placement:**
- Slight scale up on hover
- Snap to grid when placed
- Brief flash on valid placement

**Time Advance:**
- Day counter ticks forward
- Resource bars adjust smoothly
- Event panel slides in if triggered

**Alerts:**
- Warning icon pulses 3 times
- Critical alerts shake briefly
- New events highlight for 2 seconds

**Crew Actions:**
- Assignment shows brief line from crew to task
- Completion shows checkmark
- Failure shows brief red flash

---

## Audio Philosophy

### Core Principle: "Ambient, Not Intrusive"

Sound should feel like being inside a spacecraft: quiet hums, distant clicks, occasional alerts. Not constant noise.

### Music

**When:** Phase transitions, major events, menus
**Style:** Ambient electronic, orchestral undertones
**Feeling:** Wonder, tension, loneliness, triumph

**Per Phase:**

| Phase | Music Style | Reference |
|-------|-------------|-----------|
| 1: Building | Focused, technical | SimCity building music |
| 2: Travel | Vast, isolated | Interstellar ambience |
| 3: Mars | Alien, frontier | The Martian vibes |
| 4: Return | Tense → triumphant | Apollo 13 reentry |

**Dynamic Music:**
- Intensity increases with crew stress
- Softens during quiet moments
- Swells during achievements
- Silence during death/failure (powerful)

### Sound Effects

**Environment:**
- Ship hum (constant, barely audible)
- Life support cycling (periodic)
- Airlock seals (on EVA)
- Mars wind (surface operations)

**UI Feedback:**
- Click: Subtle mechanical
- Confirm: Soft positive tone
- Cancel: Brief negative blip
- Error: Clear but not harsh warning

**Events:**
- Alert: Attention-getting but not alarming
- Crisis: Urgent, prompts action
- Death: Silence, then somber tone
- Victory: Restrained triumph

**Crew:**
- No voice acting (too expensive, limits localization)
- Text beeps/boops for dialogue (optional)
- Ambient murmurs in background (not words)

### Audio Accessibility

- All sounds have visual alternatives
- Volume controls: Master, Music, Effects, Alerts
- "Reduced audio" mode for minimal sounds
- Critical alerts always have visual component

---

## UI Visual Standards

### Panels

```
┌─────────────────────────────────────────────┐
│ PANEL HEADER                            [X] │
├─────────────────────────────────────────────┤
│                                             │
│  Panel content goes here.                   │
│                                             │
│  • Bullet points for lists                  │
│  • Consistent padding                       │
│                                             │
│         [ CANCEL ]    [ CONFIRM ]           │
│                                             │
└─────────────────────────────────────────────┘

- Rounded corners: 4-8px
- Border: 1px subtle highlight
- Background: Panel Gray with slight transparency
- Shadow: Minimal drop shadow for depth
```

### Buttons

```
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│   NORMAL    │  │   HOVER     │  │  DISABLED   │
│  Steel Blue │  │  Lighter    │  │  Gray       │
└─────────────┘  └─────────────┘  └─────────────┘

- Height: 32-40px
- Padding: 12-16px horizontal
- Text: Bold, uppercase for primary actions
- Icons: Optional, left of text
```

### Resource Bars

```
FOOD ████████████░░░░░░░░ 65%
      └─ Green when healthy, yellow < 40%, red < 20%

- Height: 8-12px
- Background: Dark gray
- Fill: Gradient for polish
- Label: Left-aligned above
- Value: Right-aligned
```

### Progress Indicators

```
Journey: Earth ●───────●───────○───────○ Mars
               Day 1    Day 50   Day 100  Day 180

- Clear start and end points
- Current position highlighted
- Milestones marked
- Fills as progress is made
```

---

## Responsive Considerations

### Desktop (Primary Target)
- Full UI visible
- All panels accessible
- Keyboard shortcuts

### Tablet
- Larger touch targets
- Panels may stack
- Essential info always visible

### Mobile (Stretch Goal)
- Simplified views
- Swipe navigation
- Portrait optimization

### Low-End Hardware
- Disable animations option
- Reduce particle effects
- Simple backgrounds
- Still fully playable

---

## Asset Requirements Summary

### Art Assets

| Category | Count | Priority |
|----------|-------|----------|
| Crew portraits (per character) | 4-5 states | High |
| Component icons | 20-25 | High |
| Background (space, Earth, Mars) | 3 | Medium |
| Event illustrations | 20-30 | Medium |
| UI icons (status, actions) | 30-40 | High |
| Title screen | 1 | Low |

### Audio Assets

| Category | Count | Priority |
|----------|-------|----------|
| Music tracks (per phase + menu) | 5-6 | Medium |
| UI sounds | 15-20 | High |
| Ambient loops | 4-5 | Medium |
| Alert sounds | 5-6 | High |
| Event stingers | 10-15 | Low |

---

## Reference Touchstones

### Visual Inspiration
- **The Martian (film):** Practical technology, NASA aesthetic
- **For All Mankind:** Alternate-history space program
- **Papers, Please:** Clean information design under pressure
- **FTL:** Spaceship as readable diagram
- **Into the Breach:** Clear tactical visual language

### Audio Inspiration
- **Interstellar (soundtrack):** Epic loneliness
- **The Martian (soundtrack):** Disco-meets-tension
- **Kerbal Space Program:** Celebratory achievements
- **Firewatch:** Ambient environmental audio

---

## Implementation Priority

**Phase 1 (Core):**
1. Color palette and typography
2. Basic UI panels and buttons
3. Essential sound effects
4. Component placeholder icons

**Phase 2 (Polish):**
1. Crew portraits
2. Background art
3. Music tracks
4. Animation refinement

**Phase 3 (Complete):**
1. Event illustrations
2. Full sound design
3. Visual effects
4. Final polish pass

