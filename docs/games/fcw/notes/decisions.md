# FCW Decisions Log

Append-only log of significant design and implementation decisions.

---

## 2024-12-23: Core Design Philosophy Established

**Context**: FCW needed a clear identity that distinguished it from traditional RTS games.

**Options Considered**:
1. Production-chain economy (Mindustry-style) - complex but felt generic
2. Pure fleet tactics (Homeworld-style) - too focused on combat
3. Movement-as-gameplay with detection mechanics - unique, fits "desperate last stand" theme

**Decision**: Adopted "Movement IS the game. Desperation comes from physics."

Core principles:
- You cannot win - Earth will fall
- Show, don't tell - narrative through logistics
- Every number is a life
- Physics creates desperation

**Consequences**: Removed fake resources (ore/steel/energy). Detection mechanics become central. Herald observation radius creates the core dilemma.

---

## 2024-12-23: Detection Dilemma Mechanic

**Context**: Needed a mechanism that creates meaningful player choices around movement.

**Decision**: Herald is observation-limited:
- 5 AU observation radius (10 AU for burning ships)
- Follows activity (responds to detected burns)
- Only sees human signatures, not planets

**Consequences**: Creates the tragic choice:
- Help outer colonies → draws Herald inward
- Go dark → abandon everyone
- Evacuate → massive activity, definitely draws Herald

---

## 2025-12-24: ORDERS System Migration to Entity System

**Context**: ORDERS system (GO DARK, MAX EVAC, BLOCKADE) stopped working after migration to capital ship entity system. Orders were still using old `zone.assigned_fleet` dictionary which is now deprecated.

**Options Considered**:
1. Keep dual systems - maintain both `assigned_fleet` and entity system
2. Migrate ORDERS to use entity system directly
3. Remove ORDERS system entirely

**Decision**: Migrate ORDERS to use entity system (Option 2).

**Implementation**:
- GO DARK: Iterate all entities, switch BURNING to COASTING (reduce signature)
- MAX EVAC: Find all Carrier entities, dispatch to Earth for evacuation
- BLOCKADE: Find all Cruiser/Dreadnought entities, dispatch to Mars chokepoint

**Consequences**:
- ORDERS now work with capital ship entities instead of abstract fleet counts
- More realistic - you're ordering specific ships, not abstract fleets
- Maintains strategic preset functionality while being compatible with new architecture
- No dual system to maintain, cleaner codebase

---

## 2025-12-24: Zone Signature Calculation Bug Fix

**Context**: Zone signatures were displaying as 7699%, causing visual confusion and breaking Herald detection visualization.

**Root Cause**: `fcw_herald_ai.gd:update_zone_signatures()` was accumulating population contribution without bounds. Each tick was *adding* population instead of *setting* it, causing exponential growth.

**Options Considered**:
1. Cap display at 100% but keep underlying value unbounded (hide the problem)
2. Fix accumulation logic - population sets baseline, other factors add on top
3. Redesign entire signature system

**Decision**: Fix accumulation logic (Option 2).

**Implementation**:
```gdscript
# Before (wrong):
signature += population * 0.0001  # Accumulates forever

# After (correct):
var pop_baseline = min(population * 0.0001, 0.15)  # Capped contribution
signature = pop_baseline + traffic + burning_ships
signature = clamp(signature, 0.0, 1.0)  # Final clamp
```

**Consequences**:
- Zone signatures now correctly represent detection probability (0-100%)
- Herald detection visualization works properly
- Population contributes a baseline but doesn't dominate
- Traffic and burning ships can push signature higher
- More balanced detection mechanics overall

---

## 2025-12-24: Map Zoom Implementation

**Context**: Players wanted ability to zoom in on specific regions during intense moments.

**Options Considered**:
1. Fixed zoom levels (1x, 2x, 4x) with buttons
2. Smooth zoom with mouse wheel toward cursor
3. Picture-in-picture only (already implemented)

**Decision**: Smooth zoom with mouse wheel toward cursor (Option 2).

**Implementation**:
- Zoom range: 1.0-4.0x
- Zoom toward mouse cursor position using transform math
- Zoom out beyond 1.0x returns to default centered view
- Uses `_apply_map_zoom()` and `_inverse_map_zoom()` transforms

**Consequences**:
- More intuitive than buttons
- Allows precise focus on critical areas
- Complements picture-in-picture system
- Adds strategic value - can see detailed positions during crisis

---

## 2024-12-23: Documentation Restructure

**Context**: Documentation was scattered across multiple directories.

**Decision**: Adopted new documentation governance with per-game directories.

**Consequences**: FCW docs now live under `docs/games/fcw/`.

---

## Template for New Entries

```markdown
## YYYY-MM-DD: {Decision Title}

**Context**: What situation prompted this decision?

**Options Considered**:
1. Option A - pros/cons
2. Option B - pros/cons

**Decision**: We chose X because...

**Consequences**: What this means going forward.
```
