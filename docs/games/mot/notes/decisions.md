# MOT Decisions Log

Append-only log of significant design and implementation decisions.

---

## 2024-12-23: Documentation Restructure

**Context**: Documentation was scattered across multiple directories with inconsistent organization.

**Decision**: Adopted new documentation governance with per-game directories containing `design.md`, `research/`, `projects/`, and `notes/`.

**Consequences**: All MOT docs now live under `docs/games/mot/`. Phase docs remain as detailed references, with new `design.md` as the high-level source of truth.

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
