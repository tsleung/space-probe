# MCS Decisions Log

Append-only log of significant design and implementation decisions.

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
