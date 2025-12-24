# MCS Decisions Log

Append-only log of significant design and implementation decisions.

---

## 2024-12-24: Smart AI Resource Management & Dynamic Operating Levels

**Context**: AI was using static thresholds for building decisions. No awareness of resource trends (surplus vs deficit). Buildings had binary on/off states with no graceful degradation during power shortages.

**Options Considered**:
1. Simple threshold tweaks - easy but doesn't solve trend awareness
2. Full resource forecasting - complex, hard to tune
3. Trend-based urgency with priority tiers - balanced complexity

**Decision**: Implemented three interconnected systems:

### 1. Resource Trend Analysis
- `analyze_resource_trends()` calculates production vs consumption for all resources
- Tracks: current amount, net flow, years until depleted
- Urgency levels: 0 (none) → 4 (critical, depletes within 1 year)

### 2. Deficit-Aware Prioritization
- `calc_deficit_priority_boosts()` boosts priority for buildings that produce scarce resources
- +15 to +60 priority based on urgency level
- Applied to both new construction and upgrade decisions

### 3. Dynamic Operating Levels
- Buildings have `operating_level` (0.0-1.0) that scales production and power consumption
- Priority tiers determine minimum levels during shortages:
  - CRITICAL (100%): Housing, Medical
  - ESSENTIAL (50%): Food, Water, Power, Oxygen
  - STANDARD (25%): Fabrication, Research
  - OPTIONAL (0%): Starport, Skyhook, Mass Driver
- `calc_operating_level_adjustments()` automatically reduces optional buildings first during power deficit

**Consequences**:
- AI proactively builds production for resources trending toward depletion
- Sandstorms/power outages cause graceful degradation instead of catastrophic failure
- Non-essential systems (immigration, expansion) scale down to protect life support
- More emergent "realistic" colony management behavior

**Files Modified**:
- `scripts/mars_colony_sim/mcs_ai.gd` - Trend analysis, deficit boosts, operating level adjustment
- `scripts/mars_colony_sim/mcs_types.gd` - OperatingPriority enum, priority functions
- `scripts/mars_colony_sim/mcs_economy.gd` - Operating level support in production/power calculations

---

## 2024-12-24: Transport Progression System (SKYHOOK)

**Context**: Needed sustainable non-chemical transport for early game access (not just late-game Space Elevator). Research showed skyhooks work on Mars with current materials due to 38% Earth gravity.

**Decision**: Added full transport building progression:
- STARPORT (Year 3): Chemical rockets, basic immigration
- MASS_DRIVER (Year 10): Electromagnetic cargo launch
- SKYHOOK (Year 20): Rotating momentum-exchange tether, catches hypersonic payloads
- ORBITAL (Year 25): Space station for staging
- SPACE_ELEVATOR (Year 40): Permanent frictionless access

**Consequences**: Population growth unlocks earlier through sustainable transport. Visual system shows rotating skyhook and mass driver launches.

---

## 2024-12-23: Documentation Restructure

**Context**: Documentation was scattered across multiple directories.

**Decision**: Adopted new documentation governance with per-game directories.

**Consequences**: MCS docs now live under `docs/games/mcs/`.

---

## 2024-12-22: Visual Progression System

**Context**: Needed visual feedback for colony growth over decades.

**Decision**: Implemented tiered visual progression:
- Act 1 (Years 1-5): Sparse outpost aesthetics
- Act 2 (Years 6-20): Settlement growth with modular expansion
- Act 3 (Years 21-50): City-scale with domes and infrastructure

**Consequences**: Visual state reflects colony development without explicit UI indicators.

---

## 2024-12: GDScript 4.x Compatibility

**Context**: Migrating from GDScript 3.x patterns to 4.x.

**Decision**:
- Replace all `trait` variables (reserved keyword)
- Use `.get("key", default)` pattern for all Dictionary access
- Update all reducers to pure function patterns

**Consequences**: Full compatibility with Godot 4.5, more robust error handling.

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
