# SpaceProbe Domain Councils

**Version:** 1.0
**Status:** Active
**Purpose:** Parallel AI review of game features, mechanics, and technical decisions before implementation.

---

## Overview

Domain councils are specialized review perspectives that evaluate proposals from their area of expertise. Instead of one AI giving one opinion, spawn 5 councils that critique plans from different angles simultaneously.

**When to invoke councils:**
- New game mechanics or systems
- Balance changes affecting gameplay
- Architecture decisions touching multiple games
- Features spanning 3+ files
- Any change to `scripts/engine/` (Red Zone)

**When NOT to invoke councils:**
- Bug fixes with obvious solutions
- Data-only changes (Green Zone)
- Single-file refactors
- Documentation updates

---

## The Five Councils

| Council | Mandate | Key Question |
|---------|---------|--------------|
| **Game Design** | Is this fun and coherent? | "Does this serve the player experience?" |
| **Architecture** | Is this technically sound? | "Does this follow our patterns and scale?" |
| **Balance** | Do the numbers work? | "Is this mathematically fair and tunable?" |
| **Quality** | Is this reliable? | "How do we test this and what can break?" |
| **Performance** | Will this run well? | "What are the frame budget and memory costs?" |

---

## Council Definitions

### 1. Game Design Council

**Mandate:** Evaluate whether mechanics serve the player experience and fit the game's identity.

**Owned Artifacts:**
- `docs/games/{game}/design.md` - Game design documents
- `docs/game-design.md` - Cross-game philosophy
- Game-specific balance philosophy

**Assessment Questions:**
1. Does this mechanic create meaningful player choices?
2. Does it fit the game's emotional arc and fantasy?
3. Is the feedback loop clear (action → consequence → learning)?
4. Does it conflict with or undermine existing mechanics?
5. Will players understand what to do without tutorial text?

**Game-Specific Lenses:**

| Game | Core Question |
|------|---------------|
| MOT | "Does this create Oregon Trail tension between preparation and luck?" |
| FCW | "Does this reinforce desperation, physics-based movement, and tragic choices?" |
| VNP | "Is this visually spectacular and satisfying to watch?" |
| MCS | "Does this create generational consequences that echo forward?" |

**Interfaces With:**
- Balance Council (mechanics need numbers)
- Quality Council (mechanics need verification)

---

### 2. Architecture Council

**Mandate:** Ensure technical decisions follow established patterns and maintain codebase health.

**Owned Artifacts:**
- `CLAUDE.md` - Development instructions
- `docs/shared/architecture/` - System architecture
- `docs/principles/engineering-principles.md`
- `docs/principles/godot-architecture.md`

**Assessment Questions:**
1. Does this follow our Store/Reducer/System pattern?
2. Are functions pure where they should be pure?
3. Is state in the right place (Store vs Node)?
4. Does this create new patterns, or does it follow existing ones?
5. What's the impact on other games sharing this code?

**Pattern Checklist:**
- [ ] Pure functions in Systems (no side effects)
- [ ] State changes only through Reducers
- [ ] RNG injected, not created inline
- [ ] Result type for error handling
- [ ] Data-driven (magic numbers in balance.json)

**Red Flags:**
- Modifying `scripts/engine/` without cross-game consideration
- Global state outside Store
- Direct node manipulation from Reducers
- Hardcoded values that should be in JSON

**Interfaces With:**
- Performance Council (architecture affects performance)
- Quality Council (architecture affects testability)

---

### 3. Balance Council

**Mandate:** Verify mathematical models are correct, fair, and tunable.

**Owned Artifacts:**
- `data/games/*/balance.json` - Balance parameters
- `docs/games/*/balance-math.md` - Mathematical models
- Game economy documentation

**Assessment Questions:**
1. Is the math correct? (Show your work)
2. Are edge cases handled? (0, negative, overflow)
3. Is this tunable via balance.json or hardcoded?
4. What's the feedback loop for players to learn the system?
5. Are there degenerate strategies this enables?

**Mathematical Review Checklist:**
- [ ] Formulas documented with rationale
- [ ] Edge cases: zero, negative, very large values
- [ ] Floating point precision appropriate
- [ ] Randomness is fair (uniform vs weighted, disclosed to player)
- [ ] Economy closed-loop or intentionally leaky?

**Balance Philosophy by Game:**

| Game | Philosophy |
|------|------------|
| MOT | "Choices should feel meaningful but not punishing. Bad luck should be survivable with good planning." |
| FCW | "The math should be transparent. Players should be able to calculate outcomes. No hidden RNG on critical decisions." |
| VNP | "Rock-paper-scissors counters should feel impactful (2x/0.5x). Comeback mechanics should exist." |
| MCS | "Generational compounding should be visible. Early investments should have exponential returns." |

**Interfaces With:**
- Game Design Council (balance serves design intent)
- Quality Council (balance needs verification tests)

---

### 4. Quality Council

**Mandate:** Ensure features are testable, reliable, and handle edge cases.

**Owned Artifacts:**
- `tests/unit/` - Unit tests
- `.gutconfig.json` - Test configuration
- Test patterns and conventions

**Assessment Questions:**
1. How do we test this? (Unit, integration, manual)
2. What are the edge cases that could break?
3. What are the failure modes and how do we handle them?
4. Is the happy path obvious? Is the sad path handled?
5. Can this be tested with seeded RNG for determinism?

**Testability Checklist:**
- [ ] Pure functions → unit testable
- [ ] Seeded RNG → deterministic test runs
- [ ] State changes observable → integration testable
- [ ] Error states return Result type
- [ ] No hidden dependencies (everything injected)

**Common Edge Cases to Check:**
- Empty arrays/dictionaries
- Zero/negative values
- Missing keys in dictionaries
- Null/invalid node references
- Frame-dependent timing issues

**GUT Test Pattern:**
```gdscript
func test_[system]_[scenario]():
    # Arrange
    var state = create_test_state()
    var rng = RNGManager.new(12345)  # Fixed seed

    # Act
    var result = System.function(state, rng)

    # Assert
    assert_eq(result.value, expected)
```

**Interfaces With:**
- Architecture Council (patterns affect testability)
- Balance Council (math needs verification)

---

### 5. Performance Council

**Mandate:** Ensure features run within frame budget and follow Godot best practices.

**Owned Artifacts:**
- `docs/principles/godot-performance.md`
- `docs/games/*/projects/*-performance-tasks.md`

**Assessment Questions:**
1. What's the per-frame cost? (O(1), O(N), O(N²))
2. Are we caching what should be cached?
3. Are we pooling high-frequency objects?
4. Is state in the right place (Store vs Node)?
5. What's the memory footprint?

**Performance Checklist:**
- [ ] No O(N²) in _process()
- [ ] @onready for node references
- [ ] Object pooling for projectiles/particles
- [ ] Area2D signals instead of distance checks
- [ ] Positions on Nodes, not in state dictionaries

**Godot-Specific Concerns:**

| Pattern | Good | Bad |
|---------|------|-----|
| Node refs | `@onready var x = $Path` | `get_node()` every frame |
| Distance | Area2D signals | `position.distance_to()` in loop |
| Spawning | Object pool | `instantiate()` each time |
| State | Node owns position | Dictionary stores position |

**Per-Game Considerations:**

| Game | Concern |
|------|---------|
| MOT | Tile pathfinding during CRISIS mode (many crew, many crises) |
| FCW | Solar system with many entities, detection radius checks |
| VNP | Real-time combat with 50+ ships, projectiles, effects |
| MCS | Colonist simulation over decades (batching updates) |

**Interfaces With:**
- Architecture Council (architecture choices have perf implications)
- Quality Council (performance tests needed for regressions)

---

## Council Review Process

### Round 1: Initial Evaluation

```markdown
You are the **[COUNCIL NAME] Council** evaluating a proposal for SpaceProbe.

Read the proposal at `[FILE PATH]`

**Your Domain:** [Council mandate]

**Evaluate against these criteria:**
1. [Assessment question 1]
2. [Assessment question 2]
3. [Assessment question 3]

**For SpaceProbe specifically, also consider:**
- Does this follow our Store/Reducer/System pattern?
- Is this data-driven (values in balance.json)?
- Does this affect multiple games?

**Your verdict must be one of:**
- APPROVED (ready for implementation)
- APPROVED WITH CHANGES (specify changes)

Be rigorous. Reference specific files and line numbers where applicable.
```

### Round 2+: Follow-up

```markdown
You are the **[COUNCIL NAME] Council** reviewing V[N] of the proposal.

Read `[FILE PATH]`

**Your Round [N-1] concerns were:**
1. [SEVERITY]: [Issue]
2. [SEVERITY]: [Issue]

**Evaluate V[N]:**
1. Have ALL your concerns been addressed?
2. Are there NEW issues from your domain?

**Your verdict must be one of:**
- APPROVED (ready for implementation)
- APPROVED WITH CHANGES (specify changes)
```

### Synthesis Template

```markdown
# Council Review Synthesis - [Feature] Round [N]

**Date:** YYYY-MM-DD
**Proposal:** [Path to proposal doc]

## Summary

| Council | Verdict | Critical | Moderate | Minor |
|---------|---------|----------|----------|-------|
| Game Design | | | | |
| Architecture | | | | |
| Balance | | | | |
| Quality | | | | |
| Performance | | | | |

## Critical Issues (Must Fix)

### 1. [Issue Title]
**Council:** [Name]
**Quote:** "[Feedback]"
**Resolution:** [How to fix]

## Moderate Issues (Should Fix)
...

## Minor Issues (Nice to Have)
...

## Next Steps
- [ ] Address critical issues
- [ ] Re-submit for Round [N+1]
```

---

## When Councils Disagree

Conflicts between councils are valuable signals. Common tensions:

| Conflict | Resolution Approach |
|----------|---------------------|
| Design vs Performance | "Can we achieve 80% of the design at 20% of the cost?" |
| Balance vs Design | "Is the math serving the player fantasy or undermining it?" |
| Architecture vs Performance | "Is the performance gain worth the pattern violation?" |
| Quality vs All | "If we can't test it, we can't ship it." |

**Decision Authority:** The human (you) makes final calls. Councils advise, they don't block.

---

## Council Invocation Examples

### Example 1: New CRISIS Mode Mechanic (MOT)

**Proposal:** Add "cascade failures" where unresolved crises spawn additional crises.

**Councils to invoke:** All 5

**Expected concerns:**
- **Game Design:** Does cascade feel fair or frustrating?
- **Architecture:** How does crisis spawning integrate with event system?
- **Balance:** What's the cascade rate? Caps?
- **Quality:** How do we test cascades don't spiral infinitely?
- **Performance:** Many active crises = many pathfinding calculations

### Example 2: Base Weapon Charge System (VNP)

**Proposal:** Accumulated charges affect both power and range (x1=close, x5=map-wide).

**Councils to invoke:** All 5

**Expected concerns:**
- **Game Design:** Does waiting for x5 feel rewarding or boring?
- **Architecture:** Where does charge state live? Store or Node?
- **Balance:** Is x5 too powerful? Does x1 have a use case?
- **Quality:** Tests for charge accumulation, firing, reset
- **Performance:** Beam effects at max range

### Example 3: Balance.json Tuning

**Proposal:** Increase daily food consumption from 1.0 to 1.5 per crew.

**Councils to invoke:** Balance only (Green Zone change)

**Expected concerns:**
- **Balance:** Does this make Phase 2 too hard? Does it create meaningful scarcity or just frustration?

---

## Anti-Patterns

| Don't | Do |
|-------|-----|
| Invoke councils for trivial changes | Save for meaningful decisions |
| Run councils serially | Run all 5 in parallel |
| Ignore council conflicts | Treat conflicts as design signals |
| Iterate endlessly | 3 rounds max, then decide |
| Let councils block | They advise, human decides |

---

## Integration with Documentation Workflow

Councils fit into the documentation-first workflow:

```
1. Research (if needed) → docs/games/{game}/research/
2. Create proposal doc → docs/games/{game}/projects/
3. **Council Review** → Get verdicts, iterate
4. Implement → Write code
5. Update design doc → docs/games/{game}/design.md
6. Log decision → docs/games/{game}/notes/decisions.md
```

Council feedback often generates entries for `decisions.md`:

```markdown
## YYYY-MM-DD: Cascade Failure Rate

**Context:** Council review of CRISIS cascade mechanic.

**Options Considered:**
1. 50% cascade chance - Balance Council: "Too swingy"
2. 25% cascade chance - Game Design: "Feels fair"
3. 10% cascade chance - Game Design: "Barely noticeable"

**Decision:** 25% with 3-crisis cap per cascade event.

**Consequences:** Playtesting needed to verify feel.
```

---

## Quick Reference

| I want to... | Invoke |
|--------------|--------|
| Add a new mechanic | All 5 councils |
| Change balance numbers | Balance only |
| Refactor architecture | Architecture + Quality + Performance |
| Add visual effects | Performance + Game Design |
| Fix a bug | Usually none (just fix it) |
| Change engine code | All 5 (Red Zone) |
