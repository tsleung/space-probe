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

## 2025-12-24: GO DARK Complete Invisibility Design

**Context**: GO DARK mechanic needed to truly protect Earth from Herald detection, not just reduce its signature. The detection dilemma required Earth to be completely invisible when isolated, creating the central tragic choice.

**Options Considered**:
1. Reduced signature - GO DARK lowers Earth signature by 90% but not to zero
2. Complete invisibility - GO DARK sets Earth signature to 0, Herald cannot detect or target it
3. Probabilistic detection - GO DARK gives Herald a small chance to find Earth anyway

**Decision**: Complete invisibility (Option 2).

**Implementation**:
```gdscript
# In fcw_herald_ai.gd:update_zone_signatures()
if zone_id == FCWTypes.ZoneId.EARTH and earth_isolated:
    sigs[zone_id] = 0.0
    continue  # Skip all signature calculations

# In fcw_herald_ai.gd:choose_next_target()
if zone_id == FCWTypes.ZoneId.EARTH and earth_isolated:
    continue  # Herald cannot target Earth

# Even default path cannot lead to isolated Earth:
if default_next == FCWTypes.ZoneId.EARTH and earth_isolated:
    best_target = -1  # Herald is lost - nowhere to go

# In fcw_reducer.gd:_reduce_go_dark_earth()
new_state.earth_isolated = true
sigs[FCWTypes.ZoneId.EARTH] = 0.0  # Immediate signature suppression
```

**Why Complete Invisibility**:

1. **Thematic Consistency**: "If you don't fly to/from Earth, Herald doesn't know it's there" - this requires zero signature, not reduced signature

2. **Threshold Math Works**: Population baselines total ~0.19 (Earth 0.08, Mars 0.0005, etc.). Herald's minimum attraction threshold is 0.1 per zone, but total system activity threshold is 0.2. If Earth goes to 0.0, the remaining baseline is ~0.11. While individual zones may be above 0.1, the total system activity check (< 0.2) means Herald holds position when humanity goes mostly dark. This means:
   - GO DARK + minimal outer activity = Herald cannot find Earth (Earth signature is 0.0, Herald excludes it from targeting)
   - Total system activity < 0.2 = Herald holds position (nowhere to go)

3. **Herald Cannot Default to Earth**: The Herald's fallback behavior (following the default inward path when confused) explicitly checks for `earth_isolated`. If Earth is isolated, Herald has no valid target and stays put. This prevents Herald from stumbling onto Earth by accident.

4. **Tragic Choice Matters**: For GO DARK to be a meaningful choice, it must work. If it only reduces signature, players would never use it (risk vs reward doesn't make sense). Complete invisibility creates the dilemma:
   - **Use GO DARK**: Save Earth's 8 billion, abandon everyone else (TRAGIC tier: 5-15M evacuated)
   - **Don't use GO DARK**: Try to save everyone, risk Herald finding Earth (HEROIC tier: 40-80M if skilled)

**Consequences**:
- GO DARK is now a viable endgame strategy for preserving Earth's core population
- Creates emergent player realization: "Wait, if I go completely dark..."
- Reinforces the detection dilemma as the core mechanic
- Herald AI remains observation-limited (doesn't cheat with omniscient planet knowledge)
- Players must choose: save many (risky) or save Earth (guaranteed but costly)

**Edge Case**: If Herald is already at Mars when GO DARK activates, Herald stays at Mars (no valid targets). Earth survives as long as system activity stays below threshold.

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
