# Accessibility

Making Space Probe playable by everyone. Good accessibility is good design.

---

## Design Philosophy

### Accessibility Is Not Optional

This game targets classroom use. That means:
- Students with disabilities will play this
- School computers may have assistive technology
- Teachers need all students to participate

**Our commitment:** The core game must be playable without relying on color alone, sound alone, or precise timing.

### Inclusive by Default

Many accessibility features benefit everyone:
- Clear text helps non-native speakers
- Keyboard navigation helps power users
- Colorblind modes help in bad lighting
- Pause features help busy teachers

---

## Visual Accessibility

### Colorblind Support

**The Problem:** ~8% of males and ~0.5% of females have color vision deficiency.

**Our Solution:**

1. **Never rely on color alone**
   - Status indicators use icons + color + position
   - Graphs use patterns + colors
   - Alerts have icons, not just red highlighting

2. **Colorblind Modes**
   - Deuteranopia (red-green, most common)
   - Protanopia (red-green)
   - Tritanopia (blue-yellow, rare)

3. **Implementation**
   ```
   Normal:     🟢 Healthy   🟡 Warning   🔴 Critical
   Colorblind: ✓ Healthy   ⚠ Warning    ✗ Critical

   Both use: icon + color + text label
   ```

### Status Indicators

**Every status uses three signals:**

| Status | Color | Icon | Shape |
|--------|-------|------|-------|
| Healthy/Good | Green | ✓ Checkmark | Filled circle |
| Warning | Yellow | ⚠ Triangle | Half-filled |
| Critical | Red | ✗ X mark | Empty/outline |
| Inactive | Gray | — Dash | Dotted |

### Text Readability

**Font Sizing:**
- Minimum text size: 14px (body text)
- Critical information: 16px+
- Never smaller than 12px anywhere

**Text Size Options:**
```
Small:   12/14/16/18px (for users who want more on screen)
Medium:  14/16/18/20px (default)
Large:   16/18/20/24px (for visibility needs)
X-Large: 18/20/24/28px (low vision support)
```

**Contrast:**
- All text meets WCAG AA contrast (4.5:1 minimum)
- Critical text meets AAA (7:1)
- No light gray text on white backgrounds

**Typography:**
- Sans-serif fonts only
- No decorative/script fonts
- Clear distinction between similar characters (I/l/1, O/0)

### High Contrast Mode

For users with low vision:

```
Standard:                     High Contrast:
┌─────────────────────┐      ┌─────────────────────┐
│ ▓▓ Panel Header     │      │ ██ PANEL HEADER ██  │
│                     │      │                     │
│ Subtle text here    │      │ BOLD TEXT HERE      │
│                     │      │                     │
│ [ Button ]          │      │ [[ BUTTON ]]        │
└─────────────────────┘      └─────────────────────┘
```

- Bolder borders
- Higher contrast colors
- Thicker lines
- Larger touch targets

### Reduced Motion

**Affects:**
- Progress bar animations → instant fill
- Panel transitions → instant show/hide
- Alert pulses → static highlight
- Background animations → static image

**Does NOT affect:**
- Essential gameplay feedback
- Time passing indicator
- Resource changes (still need to see these)

---

## Audio Accessibility

### Visual Alternatives for All Audio

**Principle:** Every sound has a visual equivalent.

| Sound Type | Visual Alternative |
|------------|-------------------|
| Alert beep | Icon flash + screen edge highlight |
| Event notification | Panel slides in + banner |
| Crew voice | Text bubble + portrait highlight |
| Ambient hum | Visual "status normal" indicator |
| Music mood | UI color temperature shift |

### Closed Captions

For any audio narration or voice:
- Timed text display
- Speaker identification
- Sound effect descriptions: *[alarm blaring]* *[radio static]*

### Volume Controls

```
Settings > Audio
├── Master Volume ────────●─── 80%
├── Music ────────●───────── 60%
├── Effects ──────────●───── 80%
├── Alerts ───────────────●─ 100%
└── [✓] Visual alerts for sounds
```

### Deaf/Hard of Hearing Mode

When enabled:
- All alerts have prominent visual component
- Screen flash for critical events (optional, with warning)
- Vibration support on mobile
- Sound-based timing becomes visual countdown

---

## Motor Accessibility

### Input Methods

**Supported inputs:**
- Mouse
- Keyboard (full game playable)
- Touch screen
- Controller (basic support)
- Switch access (planned)

### Keyboard Navigation

**Full keyboard support:**
```
Tab / Shift+Tab  - Navigate between elements
Enter / Space    - Select/confirm
Escape           - Cancel/back/close
Arrow keys       - Navigate within grids
1-9              - Quick select (components, crew)
? or F1          - Help
P or Space       - Pause
```

**Focus indicators:**
- Clear, visible focus ring
- High contrast in all modes
- Moves logically through interface

### No Time Pressure

**Core design decision:** No action requires quick reflexes.

- Pause available at any time
- No real-time action sequences
- Turn-based decisions
- Events wait for player input

**Auto-pause options:**
- Auto-pause on event
- Auto-pause on low resources
- Auto-pause on crew health critical

### Click/Touch Targets

```
Minimum touch targets:
├── Buttons: 44x44 pixels
├── List items: 44px height
├── Grid hexes: 48px minimum
└── Close buttons: 44x44 pixels

Spacing between targets: 8px minimum
```

### Hold vs Tap

No actions require holding a button. Everything is:
- Single click/tap
- Or toggle on/off

If drag-and-drop is used:
- Alternative click-to-select, click-to-place option
- Keyboard equivalent available

---

## Cognitive Accessibility

### Clear Information Hierarchy

**Principle:** Important things look important.

```
┌─────────────────────────────────────────────────┐
│ ⚠ CRITICAL: Life support failing!              │  ← Urgent: red, top
├─────────────────────────────────────────────────┤
│ Current Status: Day 47 of journey              │  ← Context: prominent
├─────────────────────────────────────────────────┤
│ Resources:                                      │  ← Resources: clear bars
│ Food ████████░░░░ 65%                          │
│ Water ██████░░░░░ 52%                          │
├─────────────────────────────────────────────────┤
│ Chen is repairing life support...              │  ← Activity: lower
└─────────────────────────────────────────────────┘
```

### Reading Level

**Target:** 8th grade reading level (age 13-14)

- Short sentences
- Common words
- Define jargon on first use
- Tooltips for technical terms

**Before:**
> "Initiate the thermal control subsystem diagnostic protocol."

**After:**
> "Run a check on the temperature control system."

### Memory Assistance

**Don't make players remember:**
- What they decided earlier → Mission log available
- What stats mean → Tooltips always available
- Complex sequences → Step-by-step guidance
- Optimal strategies → Help system suggests

**Mission Log:**
- Searchable
- Filterable by type
- Highlights key decisions
- Always accessible

### Consistent Layout

- Same elements in same places across phases
- Consistent button placement (confirm right, cancel left)
- Predictable menu structure
- No hidden interactions

### Tutorial Flexibility

```
Settings > Gameplay
├── Tutorial hints: [On / Off]
├── Tooltip delay: [Instant / 0.5s / 1s / 2s]
├── Reminder frequency: [Often / Sometimes / Rarely]
└── Help button visible: [Always / On hover / Hidden]
```

---

## Screen Reader Support

### Full Screen Reader Compatibility

**Target:** Works with common screen readers (NVDA, VoiceOver, TalkBack)

**Implementation:**
- Proper focus order
- Meaningful element labels
- State announcements
- Live region updates for dynamic content

### Element Labels

```gdscript
# Bad
button.name = "btn_1"

# Good
button.name = "Test Component Button"
button.hint_tooltip = "Test this component to improve quality. Costs $2M and 3 days."
```

### Announcements

When things change, announce them:
- "Day 48. Food at 60 percent. Warning: Water below 50 percent."
- "Event: Solar flare detected. 3 choices available."
- "Chen assigned to repair life support."

### Screen Reader Mode

When enabled:
- Extra verbose descriptions
- Slower auto-advance (if any)
- Enhanced keyboard navigation
- Skip decorative elements

---

## Difficulty as Accessibility

### Difficulty Isn't Just "Easy Mode"

Different players need different accommodations:

| Need | Accommodation |
|------|---------------|
| Learning disability | Simpler decisions, clearer feedback |
| Limited play time | Shorter sessions, better checkpoints |
| Anxiety | Lower stakes, forgiving failures |
| Physical disability | More time, fewer inputs |

### Relaxed Mode Features

Beyond just "more resources":
- Slower event timers (if any)
- More explicit guidance
- Reduced consequence severity
- More frequent checkpoints
- Gentler failure states

### Custom Difficulty

```
Custom Difficulty Options:
├── Resource abundance: [Scarce / Normal / Abundant]
├── Event severity: [Harsh / Normal / Gentle]
├── Failure consequences: [Permanent / Recoverable / Minimal]
├── Time pressure: [Tight / Normal / Relaxed]
└── Guidance level: [Minimal / Normal / Extensive]
```

---

## Implementation Checklist

### Visual
- [ ] Colorblind modes (3 types)
- [ ] Text size options (4 levels)
- [ ] High contrast mode
- [ ] Reduced motion option
- [ ] All status uses icon + color
- [ ] WCAG AA contrast minimum
- [ ] Clear focus indicators

### Audio
- [ ] Volume controls (4 channels)
- [ ] Visual alternatives for all sounds
- [ ] Closed captions for narration
- [ ] Deaf/HoH mode

### Motor
- [ ] Full keyboard navigation
- [ ] No time-critical actions
- [ ] 44px minimum touch targets
- [ ] No hold-to-activate
- [ ] Pause always available

### Cognitive
- [ ] 8th grade reading level
- [ ] Consistent layout
- [ ] Mission log available
- [ ] Tooltips everywhere
- [ ] Tutorial skip option

### Screen Reader
- [ ] Proper focus order
- [ ] Meaningful labels
- [ ] State announcements
- [ ] Screen reader mode option

### Testing
- [ ] Test with actual screen reader
- [ ] Test in colorblind simulation
- [ ] Test keyboard-only playthrough
- [ ] Test with users who have disabilities

---

## Testing Resources

### Simulation Tools
- **Colorblind:** Colorblindly browser extension, Sim Daltonism (Mac)
- **Screen reader:** NVDA (Windows, free), VoiceOver (Mac, built-in)
- **Motor:** Try playing with keyboard only

### Automated Testing
- aXe browser extension for web builds
- Godot accessibility plugin (if available)
- Contrast checker tools

### User Testing
- Partner with disability advocacy organizations
- Include accessibility in beta testing
- Listen to feedback from players with disabilities

---

## Standards Reference

### WCAG 2.1 Guidelines (Target: AA)

**Perceivable:**
- 1.1: Text alternatives for non-text content
- 1.3: Content adaptable to different presentations
- 1.4: Distinguishable (contrast, resize, audio control)

**Operable:**
- 2.1: Keyboard accessible
- 2.2: Enough time (pause, extend)
- 2.3: No seizure triggers
- 2.4: Navigable

**Understandable:**
- 3.1: Readable
- 3.2: Predictable
- 3.3: Input assistance

**Robust:**
- 4.1: Compatible with assistive technologies

### Game Accessibility Guidelines

Reference: [gameaccessibilityguidelines.com](https://gameaccessibilityguidelines.com/)

Categories we target:
- Motor: Basic + Intermediate
- Cognitive: Basic + Intermediate
- Vision: Basic + Intermediate
- Hearing: Basic + Intermediate
- Speech: Basic (if relevant)

---

## Priority Implementation

### Phase 1 (Must Have - Launch)
1. Keyboard navigation
2. Text size options
3. Colorblind modes
4. Pause anywhere
5. No time pressure
6. Clear visual status indicators

### Phase 2 (Should Have - Soon After)
1. High contrast mode
2. Screen reader basics
3. Reduced motion
4. Custom difficulty options
5. Closed captions

### Phase 3 (Nice to Have - Future)
1. Full screen reader support
2. Switch access
3. Controller support
4. Extensive cognitive aids
5. Multiple reading levels

