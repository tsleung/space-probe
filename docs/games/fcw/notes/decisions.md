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
