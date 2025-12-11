# LLM-Assisted Development Principles

Guidelines for working effectively with Claude Code as the primary engineering tool.

---

## The Partnership Model

Claude Code is not a code generator - it's a pair programmer. The founder provides:
- Game design vision
- Feature requirements
- Acceptance criteria

Claude Code provides:
- Godot/GDScript expertise
- Architecture decisions
- Implementation
- Testing
- Refactoring

This works because of **clear boundaries** and **robust infrastructure**.

---

## Why Architecture Matters for LLMs

LLMs work best when:
1. **Context is clear**: Small, focused files fit in context windows
2. **Patterns are consistent**: Same patterns = predictable behavior
3. **Boundaries are explicit**: Know what can/can't be changed safely
4. **Feedback is immediate**: Validation catches errors before they propagate

Our architecture is designed specifically for these constraints.

---

## Safe Zones for LLM Editing

### Green Zone: Edit Freely

These files contain game content, not engine logic. Claude can edit without risk of breaking core systems.

```
data/
├── games/
│   └── */
│       ├── components.json    # Add/modify components
│       ├── events/*.json      # Add/modify events
│       ├── crew_roster.json   # Add/modify crew
│       ├── balance.json       # Tune numbers
│       └── manifest.json      # Configure game
├── shared/
│   ├── traits.json           # Add crew traits
│   └── conditions.json       # Add status conditions
└── difficulty.json           # Difficulty settings
```

**Guardrails:**
- Schema validation catches structural errors
- Type validation catches value errors
- Reference validation catches broken links
- Tests verify game still works

### Yellow Zone: Edit with Care

These files contain game-specific logic. Claude can edit but should run tests.

```
scripts/games/*/
├── reducers/                 # Phase-specific logic
├── validators/               # Game-specific validation
└── *_game.gd                 # Game coordinator
```

**Guardrails:**
- Unit tests for each reducer
- Integration tests for phase transitions
- Type hints catch signature errors

### Red Zone: Edit Rarely

These files are engine infrastructure. Changes affect all games.

```
scripts/engine/
├── core/                     # Store, RNG, persistence
├── validation/               # Validation framework
├── systems/                  # Shared systems
├── types/                    # Core types
└── utils/                    # Utilities
```

**Guardrails:**
- Extensive unit tests
- Breaking changes affect all games
- Require careful review

---

## Effective Prompting Patterns

### For Adding Content

```
Add a new event to Phase 2 for the Mars Mission game.

Event details:
- Title: "Water Recycler Malfunction"
- Trigger: Random, 5% chance per day after day 30
- Choices:
  1. "Attempt emergency repair" (requires Engineer, risky)
  2. "Ration water usage" (guaranteed, reduces water by 50%)
  3. "Cannibalize other systems" (guaranteed, damages another component)

Reference existing events in data/games/mars_mission/events/phase2.json
for the correct format.
```

**Why this works:**
- Clear requirements
- Points to reference files
- Specifies location
- Doesn't prescribe implementation

### For Tuning Balance

```
Players are finding Phase 2 too easy. Adjust balance.json to:
- Increase base event chance from 15% to 20%
- Increase daily resource consumption by 10%
- Keep other values the same

Run tests after to verify nothing breaks.
```

**Why this works:**
- Specific numbers
- Clear scope
- Explicit about what NOT to change
- Requests verification

### For Adding Features

```
Add a "Crew Relationships" system to the engine.

Requirements:
- Track trust level (0-100) between each crew pair
- Trust changes based on events (shared positive: +5, conflict: -10)
- Low trust (<30) can trigger conflict events
- High trust (>70) provides morale bonus

This should be a new engine system (scripts/engine/systems/relationship_system.gd)
usable by any game. Add unit tests.

Reference existing systems like crew_system.gd for patterns.
```

**Why this works:**
- Clear functional requirements
- Specifies location
- Requests tests
- Points to reference code

### For Debugging

```
Players report that crew health isn't updating correctly during Phase 2.

Symptoms:
- Health stays at 100 even without Medical Bay
- balance.json shows health_decay_per_day: 0.5

Find and fix the bug. The logic should be in either:
- scripts/engine/systems/crew_system.gd
- scripts/games/mars_mission/reducers/travel_reducer.gd
```

**Why this works:**
- Clear symptoms
- Provides relevant data
- Narrows search scope
- Doesn't assume cause

---

## Anti-Patterns to Avoid

### Don't: Vague Requirements

```
# BAD
Make the game more fun.

# GOOD
Add more variety to Phase 2 events. Currently there are only 10 events.
Add 5 new events with different categories (2 crew, 2 ship, 1 space).
```

### Don't: Prescribe Implementation

```
# BAD
Create a function called process_damage that takes a crew member
and subtracts health based on a random roll between 5 and 15.

# GOOD
Add damage handling to crew. Damage should vary (5-15 range typically)
and account for medical facilities. See existing patterns in crew_system.gd.
```

### Don't: Assume Context

```
# BAD
Fix the bug we discussed earlier.

# GOOD
Fix the bug where crew health doesn't decay. The issue is in
crew_system.gd line ~45 where the decay calculation returns early.
```

### Don't: Request Multiple Unrelated Changes

```
# BAD
Add a new component, fix the save system, and refactor the UI.

# GOOD (three separate requests)
1. Add a "Greenhouse" component to mars_mission/components.json
2. [separate session] Fix save system not persisting crew relationships
3. [separate session] Refactor ship_building_ui.gd to use shared components
```

---

## The Review Workflow

1. **Request**: Describe what you want
2. **Plan**: Claude proposes approach (for complex changes)
3. **Implement**: Claude writes code
4. **Test**: Claude runs tests
5. **Review**: You review changes
6. **Iterate**: Request adjustments if needed

### For Data Changes (Green Zone)

```
You: Add a "Solar Sail" engine to mars_mission
Claude: [adds to engines.json]
Claude: [runs schema validation]
Claude: "Added. Validation passed. Want me to adjust any stats?"
```

### For Logic Changes (Yellow Zone)

```
You: Events should consider crew morale in trigger chance
Claude: [proposes approach]
Claude: [implements in event_system.gd]
Claude: [adds/updates tests]
Claude: [runs full test suite]
Claude: "Done. Tests pass. Here's what changed..."
You: [review diff]
```

### For Engine Changes (Red Zone)

```
You: Add undo/redo capability to the Store
Claude: [proposes detailed architecture]
You: [approve/adjust approach]
Claude: [implements incrementally]
Claude: [extensive testing]
Claude: [documents changes]
You: [careful review]
```

---

## Regression Prevention

### Automated Guards

1. **Schema Validation**: All data files validated against schemas
2. **Unit Tests**: All pure functions tested
3. **Integration Tests**: Phase transitions tested
4. **Type Hints**: GDScript static typing catches errors

### Process Guards

1. **One Thing at a Time**: Don't bundle unrelated changes
2. **Test After Every Change**: Run tests, don't assume
3. **Review Diffs**: Understand what changed
4. **Document Decisions**: Future context for Claude

---

## Context Management

LLMs have limited context windows. Help Claude by:

### Providing References

```
The component schema is in data/games/mars_mission/components.json.
Use the existing "Nuclear Engine" as a template.
```

### Narrowing Scope

```
The bug is somewhere in scripts/engine/systems/crew_system.gd,
specifically in the apply_daily_update function.
```

### Summarizing History

```
We added relationships last session. The system is in
relationship_system.gd and tests are in test_relationship_system.gd.
```

### Breaking Up Large Tasks

```
Let's add the colony building system in phases:
1. First: data structures (this session)
2. Then: placement logic (next session)
3. Then: production system (after that)
4. Finally: UI (last)
```

---

## When Things Go Wrong

### If Tests Fail

```
Claude: Tests are failing. Here's the error: [error]
You: What's causing it?
Claude: [analyzes] The issue is X. I can fix by Y. Should I proceed?
```

### If Schema Validation Fails

```
Claude: Schema validation failed: "missing required field 'cost'"
       Line 45 in components.json
       I'll add the missing field. What should the cost be?
```

### If Logic Seems Wrong

```
You: This doesn't match the design. Events should only trigger
     once per day, not multiple times.
Claude: You're right. The check is in the wrong place. Let me
        move it to [location] and add a test for this case.
```

---

## Building Trust

Start small, build up:

1. **Week 1**: Data-only changes (events, balance)
2. **Week 2**: Simple logic changes (new reducers)
3. **Week 3**: New systems (with tests)
4. **Week 4**: Architecture improvements

Each successful iteration builds confidence in the partnership.

---

## Summary

1. **Clear boundaries** between content (data) and logic (code)
2. **Explicit requirements** in prompts
3. **Incremental changes** with tests
4. **Review everything** before committing
5. **Document decisions** for future context

The goal: Claude can ship features while you focus on game design.
