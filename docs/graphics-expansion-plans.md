# Graphics & Expansion Plans

Current state and planned visual improvements for all game modes.

---

## Design Principles (All Games)

### Real-Time First, Pause Optional

All games support:
- **Real-time play** as the default experience
- **AI Spectate mode** for hands-off viewing
- **Pause** available for players who prefer turn-based

### Visual Requirements for Spectate Mode

When AI is playing, visuals must:
1. Clearly show what's happening without player input
2. Log AI decisions visibly in the UI
3. Animate state changes smoothly
4. Support variable speed (1x to 10x)

---

## Game-Specific Graphics Plans

### Von Neumann Probe (VNP)

**Current State:** Basic shapes, functional combat

**Planned Improvements:**

| Element | Current | Planned |
|---------|---------|---------|
| Ships | Colored rectangles | Distinct silhouettes per class |
| Projectiles | Simple lines | Trail effects, weapon-specific visuals |
| Explosions | Basic particles | Impact FX with screen shake |
| Galaxy map | Dots for stars | Procedural star fields, nebulae hints |
| UI | Text-heavy | Resource bars with icons |

**Visual Priorities:**
1. Ship class silhouettes (Frigate, Destroyer, Cruiser, Harvester)
2. Weapon type differentiation (Gun=yellow, Laser=red, Missile=blue trails)
3. Mining beam effects
4. Fleet formation indicators
5. Threat proximity warnings

**Spectate Mode Enhancements:**
- Camera auto-follows action
- Battle highlights with zoomed view
- Fleet status overlay
- Resource flow visualization

---

### First Contact War (FCW)

**Current State:** Solar system map, zone indicators

**Planned Improvements:**

| Element | Current | Planned |
|---------|---------|---------|
| Solar map | 2D circles | Orbital paths, planet icons |
| Zones | Colored regions | Strategic overlays, threat indicators |
| Fleets | Numbers | Fleet icons with composition preview |
| Herald invasion | Red markers | Animated approach vectors |
| Battles | Text results | Mini battle view with ship counts |

**Visual Priorities:**
1. Distinct zone icons (Earth=blue, Mars=rust, Jupiter=orange stripes)
2. Fleet composition pie charts
3. Herald wave approach animation
4. Building icons per type
5. Victory/defeat zone transitions

**Spectate Mode Enhancements:**
- Animated turn transitions
- Casualty counters with visual weight
- "News ticker" style event log
- Population evacuation visualization

---

### Colony Simulator

**Current State:** UI panels, text-based

**Planned Improvements:**

| Element | Current | Planned |
|---------|---------|---------|
| Colony view | No visual | Top-down base layout |
| Buildings | Item list | Building icons in grid |
| Colonists | Text list | Population wheel/tree |
| Events | Text panels | Illustrated event cards |
| Timeline | Year counter | Visual timeline with milestones |

**Visual Priorities:**
1. Building type icons (Hab, Greenhouse, Solar, Medical, etc.)
2. Resource flow diagram
3. Population demographic visualization (generations as rings)
4. Colony growth timeline
5. Faction loyalty indicators

**Spectate Mode Enhancements:**
- Year-over-year comparison graphs
- Population tree growth animation
- Event cards with AI choice highlighted
- "Documentary style" narrative overlays

---

### Mars Mission (Core Game)

**Current State:** Phase-based UI, hex ship builder

**Planned Improvements:**

| Element | Current | Planned |
|---------|---------|---------|
| Ship builder | Hex grid | 3D-ish isometric view option |
| Travel | Progress bar | Animated ship traversing space |
| Crew | Portrait list | Crew quarters visualization |
| Events | Text panels | Illustrated event scenes |
| Mars base | N/A | Top-down base view |

**Visual Priorities:**
1. Ship component icons with quality indicators
2. Journey progress visualization (Earth-Mars transit)
3. Crew portrait states (healthy, stressed, injured)
4. Mars surface panorama
5. Weather/dust storm effects

---

## Shared Visual Systems

### Resource Indicators (All Games)

Consistent across all game modes:

```
┌────────────────────────────────────┐
│ FOOD ████████████░░░░░░ 65%    ↓2  │
│      Green > Yellow > Red          │
│      Arrow shows trend             │
└────────────────────────────────────┘
```

### Status Colors (Global)

| State | Color | Usage |
|-------|-------|-------|
| Healthy/Good | `#4ADE80` | Full resources, stable |
| Warning | `#FACC15` | Declining, attention needed |
| Critical | `#EF4444` | Immediate action required |
| AI Decision | `#A78BFA` | Purple highlight for AI actions |

### Speed Controls (All Real-Time Games)

```
[▶ 1x] [▶▶ 2x] [▶▶▶ 5x] [⏩ 10x] [⏸ Pause]

With AI: [🤖 AI Spectate] [Personality: Pragmatist ▼]
```

---

## Animation Guidelines for Real-Time

### Frame Rates

| Element | Target FPS | Notes |
|---------|------------|-------|
| UI updates | 60 | Smooth counters, bars |
| Game state | 30 | State changes, combat |
| Background | 15-30 | Stars, ambient effects |
| Effects | 60 | Explosions, transitions |

### Speed Scaling

When speed > 1x:
- Skip intermediate animations
- Batch visual updates
- Keep critical alerts visible
- Smooth value interpolation

### AI Action Visibility

When AI makes decisions:
1. Brief highlight on affected element (300ms)
2. Log entry appears with purple AI icon
3. Optional: "AI thought bubble" showing reasoning

---

## Asset Pipeline Recommendations

### Tool Suggestions

| Asset Type | Tool | Notes |
|------------|------|-------|
| UI icons | Figma/Inkscape | Vector, export to PNG |
| Ship sprites | Aseprite | Pixel art option |
| Portraits | Procreate/Krita | Illustrated style |
| Effects | Godot Particles | Built-in particle system |
| Shaders | Godot Shader | Screen effects, transitions |

### Resolution Targets

| Platform | Resolution | UI Scale |
|----------|------------|----------|
| Desktop (1080p) | 1920x1080 | 1.0x |
| Desktop (1440p) | 2560x1440 | 1.0x |
| Desktop (4K) | 3840x2160 | 1.5x-2.0x |
| Tablet | 1024x768+ | Touch-friendly |

### Asset Sizes

| Element | Size | Format |
|---------|------|--------|
| Ship sprites | 64x64 | PNG with alpha |
| Building icons | 32x32 | PNG with alpha |
| Portraits | 128x128 | PNG |
| Backgrounds | 1920x1080 | JPG (tiled) |
| UI icons | 24x24 | SVG or PNG |

---

## Expansion Roadmap

### Phase 1: Functional (Current)

- [x] Basic UI for all games
- [x] Text-based feedback
- [x] Color coding for status
- [x] Real-time speed controls
- [x] AI Spectate mode

### Phase 2: Visual Polish (Next)

- [ ] Ship/building icons for all games
- [ ] Resource bar standardization
- [ ] Event illustration placeholders
- [ ] Basic particle effects
- [ ] Screen transitions

### Phase 3: Immersion

- [ ] Animated backgrounds
- [ ] Sound effects integration
- [ ] Music per game mode
- [ ] Crew portrait system
- [ ] Weather/environmental effects

### Phase 4: Complete

- [ ] Full illustration set for events
- [ ] Dynamic music system
- [ ] Accessibility options (colorblind, reduced motion)
- [ ] Localization support for all text
- [ ] Mobile adaptation

---

## Technical Considerations

### Performance Targets

| Game | Min FPS | Target FPS | Notes |
|------|---------|------------|-------|
| Colony Sim | 30 | 60 | UI-heavy, low action |
| VNP | 30 | 60 | Combat particles |
| FCW | 30 | 60 | Turn-based core |
| Mars Mission | 30 | 60 | Event-driven |

### Spectate Mode Performance

When running at 10x speed:
- Limit particle count
- Batch state updates
- Use simplified animations
- Maintain readable UI

### Memory Budget

| Asset Type | Target | Max |
|------------|--------|-----|
| Sprites/Icons | 20MB | 50MB |
| Backgrounds | 10MB | 30MB |
| Sound/Music | 30MB | 100MB |
| Total | 60MB | 180MB |

---

## Quick Reference: Game Mode Summary

| Game | Primary View | Key Visual | Spectate Focus |
|------|-------------|------------|----------------|
| VNP | Space combat | Ship battles | Fleet growth |
| FCW | Solar system | Zone control | Wave defense |
| Colony Sim | Settlement | Population | Generations |
| Mars Mission | Ship/Journey | Crew survival | Mission progress |

All games share:
- Real-time play with pause
- AI Spectate mode
- Variable speed (1x-10x)
- Consistent status colors
- Log-based feedback
