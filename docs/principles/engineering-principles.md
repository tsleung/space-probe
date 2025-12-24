# Engineering Principles

Core principles that guide all code decisions in SpaceProbe. These principles enable safe, rapid iteration with LLM-assisted development.

---

## The Prime Directive

> **Stability enables velocity.**

We invest in robust infrastructure so we can move fast during game design sessions. Every principle below serves this goal.

---

## 0. Reproducible Simulation

> **We understand our games through deterministic math.**

### The Philosophy

Every SpaceProbe game is fundamentally a **simulation** that we must be able to reproduce, analyze, and understand. Even when randomness creates variety, we must be able to:

1. **Reproduce any run** - Given a seed and player inputs, recreate the exact game state
2. **Simulate outcomes** - Run thousands of games to understand probability distributions
3. **Analyze emergent behavior** - See how systems interact at scale
4. **Validate balance** - Prove mathematically that the game is fair and tunable

### Why This Matters

| Capability | What It Enables |
|------------|-----------------|
| **Seeded Replay** | Debug any bug by replaying the exact sequence |
| **Monte Carlo Simulation** | Balance the game by running 10,000 simulated playthroughs |
| **Story Pacing** | Tune event probabilities to create narrative arcs |
| **Visual Calibration** | Scale visual effects proportional to actual impact |
| **Regression Testing** | Verify balance changes don't break edge cases |

### The Mathematical Contract

Every system that involves chance must:

```gdscript
# 1. Accept RNG as a parameter (never create internally)
static func resolve_combat(attacker: Dictionary, defender: Dictionary, rng: RNGManager) -> Dictionary:
    var hit_roll = rng.randf()  # Reproducible with same seed
    var damage_roll = rng.randf()
    # ...

# 2. Document the probability model
## Hit chance: base_accuracy * (1 - evasion/100)
## Damage: base_damage * (0.8 + roll * 0.4) for ±20% variance
## Critical: 5% chance for 2x damage

# 3. Be simulatable in isolation
func test_combat_balance():
    var results = []
    for seed in range(10000):
        var rng = RNGManager.new(seed)
        var result = CombatSystem.resolve_combat(attacker, defender, rng)
        results.append(result)

    var win_rate = calculate_win_rate(results)
    assert_between(win_rate, 0.45, 0.55, "Combat should be roughly balanced")
```

### Simulation-First Design

When designing a new system, ask:

1. **Can I write the formula?** - If you can't express it mathematically, you don't understand it
2. **Can I simulate 10,000 runs?** - If not, you can't balance it
3. **Can I reproduce a specific outcome?** - If not, you can't debug it
4. **Can I explain the variance?** - Players should understand why outcomes differ

### Visual Effects Follow Math

Visual spectacle must be **proportional to mechanical impact**:

```gdscript
# Effect intensity scales with actual damage dealt
var damage_ratio = actual_damage / target_max_health
var effect_scale = lerp(0.5, 2.0, damage_ratio)  # 50% to 200% intensity

# A 5% health hit gets subtle effects
# A 50% health hit gets dramatic effects
# Players learn to read visual language
```

This prevents:
- Underwhelming critical hits (big number, small effect)
- Misleading minor damage (small number, big effect)
- Visual fatigue from constant maximum effects

### The Simulation Toolkit

Every game should have:

1. **Headless mode** - Run without rendering for fast simulation
2. **Seed logging** - Record seeds for every playthrough
3. **Replay system** - Reconstruct game from seed + inputs
4. **Balance scripts** - Monte Carlo analysis tools

---

## 1. Pure Functions Everywhere

### What It Means

A pure function:
- Given the same inputs, always returns the same output
- Has no side effects (doesn't modify external state)
- Doesn't read from or write to anything outside its parameters

### Why It Matters

- **Testable**: Pure functions can be unit tested in isolation
- **Predictable**: No hidden state means no surprises
- **Parallelizable**: Safe to call from anywhere
- **LLM-friendly**: Claude can reason about inputs → outputs without context

### The Rule

All game logic MUST be pure. Side effects (RNG, I/O, signals) are isolated to the Store layer.

```gdscript
# GOOD: Pure function
static func calculate_damage(attacker_skill: int, defender_armor: int, random_roll: float) -> int:
    var base_damage = attacker_skill * 2
    var reduction = defender_armor * 0.5
    var variance = random_roll * 0.2 + 0.9  # 0.9 to 1.1
    return int((base_damage - reduction) * variance)

# BAD: Impure function (uses external RNG)
static func calculate_damage(attacker_skill: int, defender_armor: int) -> int:
    var base_damage = attacker_skill * 2
    var reduction = defender_armor * 0.5
    var variance = randf() * 0.2 + 0.9  # Side effect!
    return int((base_damage - reduction) * variance)
```

### Deterministic Randomness

Random values are generated in the Store and passed INTO pure functions:

```gdscript
# Store (side effects allowed)
func dispatch_advance_day():
    var random_values = _rng.randf_array(5)
    dispatch({
        "type": "ADVANCE_DAY",
        "random_values": random_values
    })

# Reducer (pure)
static func reduce_advance_day(state: Dictionary, action: Dictionary) -> Dictionary:
    var event_roll = action.random_values[0]
    var damage_roll = action.random_values[1]
    # ... use rolls deterministically
```

This enables:
- **Replay**: Same seed + actions = same game
- **Testing**: Fixed random values = predictable tests
- **Debugging**: Can reproduce any bug with the action history

---

## 2. Immutable State Updates

### What It Means

Never mutate state directly. Always create new state objects.

### Why It Matters

- **Change detection**: Can compare old vs new state
- **Time travel**: Can undo/redo by keeping state history
- **Debugging**: Can inspect state at any point
- **Safety**: Prevents accidental corruption

### The Rule

Use `duplicate(true)` and helper functions for all state updates.

```gdscript
# GOOD: Immutable update
static func reduce_damage_crew(state: Dictionary, action: Dictionary) -> Dictionary:
    var new_state = state.duplicate(true)
    var crew_index = _find_crew_index(new_state.crew, action.crew_id)
    new_state.crew[crew_index].health -= action.damage
    return new_state

# BAD: Mutating state directly
static func reduce_damage_crew(state: Dictionary, action: Dictionary) -> Dictionary:
    var crew = state.crew.filter(func(c): return c.id == action.crew_id)[0]
    crew.health -= action.damage  # Mutates original!
    return state
```

### Helper Pattern

Use `with_field` and `with_fields` for clean immutable updates:

```gdscript
static func with_field(dict: Dictionary, key: String, value) -> Dictionary:
    var new_dict = dict.duplicate(true)
    new_dict[key] = value
    return new_dict

static func with_fields(dict: Dictionary, updates: Dictionary) -> Dictionary:
    var new_dict = dict.duplicate(true)
    for key in updates:
        new_dict[key] = updates[key]
    return new_dict

# Usage
return with_fields(state, {
    "current_day": state.current_day + 1,
    "resources": updated_resources
})
```

---

## 3. Explicit Error Handling

### What It Means

Every operation that can fail returns a Result type. No silent failures.

### Why It Matters

- **Debuggable**: Know exactly what failed and why
- **Recoverable**: UI can handle errors gracefully
- **LLM-friendly**: Claude sees clear success/failure paths

### The Rule

Use Result<T, E> for all fallible operations. Never return null or -1 to indicate failure.

```gdscript
# GOOD: Explicit Result
func validate_placement(component_id: String, position: Vector2i) -> Result:
    if not _components.has(component_id):
        return Result.err({
            "code": "UNKNOWN_COMPONENT",
            "message": "Component '%s' does not exist" % component_id,
            "component_id": component_id
        })

    if _is_occupied(position):
        return Result.err({
            "code": "POSITION_OCCUPIED",
            "message": "Position %s is already occupied" % position,
            "position": position,
            "occupying_component": _grid[position].component_id
        })

    return Result.ok({"valid": true})

# BAD: Silent failure
func validate_placement(component_id: String, position: Vector2i) -> bool:
    if not _components.has(component_id):
        return false  # Why did it fail?
    if _is_occupied(position):
        return false  # Caller has no context
    return true
```

### Error Structure

All errors include:
- `code`: Machine-readable identifier (for programmatic handling)
- `message`: Human-readable description (for logging/display)
- Context fields: Whatever is relevant to debug

---

## 4. Single Source of Truth

### What It Means

All game state lives in ONE place: the Store. No duplicate state.

### Why It Matters

- **Consistency**: No sync bugs between duplicate state
- **Debuggable**: One place to inspect
- **Reactive**: UI subscribes to changes

### The Rule

- Store owns all mutable game state
- UI components are stateless (or only have local UI state like selections)
- Logic functions never access global state

```gdscript
# GOOD: UI reads from Store
func _on_state_changed(old_state, new_state):
    _update_resource_display(new_state.resources)
    _update_crew_list(new_state.crew)

# BAD: UI maintains its own state
var _cached_resources = {}  # Now out of sync risk

func _on_resource_change(resource_id, amount):
    _cached_resources[resource_id] += amount  # Duplicate state!
```

### What Can Have Local State

- **UI selections**: Currently selected item, hover state
- **Animations**: Tween progress, particle state
- **View state**: Scroll position, collapsed panels
- **Transient input**: Text being typed before submit

These are explicitly NOT game state and don't need to persist.

---

## 5. Data Over Code

### What It Means

Game content (components, events, balance numbers) lives in data files, not code.

### Why It Matters

- **LLM-safe**: Claude can edit JSON without risking code stability
- **Designer-friendly**: Balance tuning without programming
- **Moddable**: Players can customize
- **Testable**: Can validate data against schemas

### The Rule

If it's a game design decision, it's data. If it's how the engine works, it's code.

```
DATA (JSON files):
- Component definitions (name, cost, stats)
- Event text and choices
- Balance numbers (damage values, costs, durations)
- Crew roster (names, backgrounds, traits)
- Phase definitions (what phases exist, transitions)

CODE (GDScript):
- How components are placed on grid
- How events are triggered and resolved
- How damage is calculated (the formula)
- How state transitions work
- Validation logic
```

### The Formula Engine

For complex formulas, define them in data but evaluate in code:

```json
{
  "formulas": {
    "damage": "base_damage * (1 - armor/100) * (0.9 + random_roll * 0.2)"
  }
}
```

```gdscript
var damage = FormulaEngine.evaluate(
    balance.formulas.damage,
    {"base_damage": 50, "armor": 30, "random_roll": 0.7}
)
```

---

## 6. Validate Early, Validate Often

### What It Means

Check inputs at system boundaries. Fail fast with clear errors.

### Why It Matters

- **Debugging**: Errors point to the source, not symptoms
- **Safety**: Invalid state never enters the system
- **LLM-friendly**: Claude gets immediate feedback on mistakes

### The Rule

Every action is validated before dispatch. Every data file is validated on load.

```gdscript
# Action Validation Layer
func dispatch(action: Dictionary) -> Result:
    # 1. Structural validation
    var structural = _validate_structure(action)
    if not structural.is_ok():
        return structural

    # 2. Type validation
    var types = _validate_types(action)
    if not types.is_ok():
        return types

    # 3. Business logic validation
    var business = _validate_business_rules(action, _state)
    if not business.is_ok():
        return business

    # 4. Now safe to dispatch
    return _execute_dispatch(action)
```

### Validation Levels

1. **Structural**: Does the action have required fields?
2. **Type**: Are field values the right types?
3. **Reference**: Do referenced IDs exist?
4. **Business**: Is this action allowed in current state?

---

## 7. Composition Over Inheritance

### What It Means

Build complex behavior by combining simple pieces, not by extending classes.

### Why It Matters

- **Flexible**: Easy to mix and match behaviors
- **Testable**: Each piece testable in isolation
- **LLM-friendly**: Smaller, focused functions are easier to reason about

### The Rule

Prefer static functions and data composition. Use classes for organization, not polymorphism.

```gdscript
# GOOD: Composition
static func process_daily_update(state: Dictionary, balance: Dictionary, rng: RNGManager) -> Dictionary:
    var new_state = state.duplicate(true)
    new_state = ResourceSystem.consume_daily(new_state, balance, rng)
    new_state = CrewSystem.apply_daily_decay(new_state, balance, rng)
    new_state = ComponentSystem.check_failures(new_state, balance, rng)
    new_state = EventSystem.check_random_event(new_state, balance, rng)
    return new_state

# BAD: Deep inheritance
class DailyUpdateProcessor extends BaseProcessor:
    func process(state):
        state = super.process(state)  # What does this do?
        # ... hard to follow inheritance chain
```

---

## 8. Explicit Dependencies

### What It Means

Every function declares what it needs via parameters. No global access.

### Why It Matters

- **Testable**: Can provide mock dependencies
- **Traceable**: Can see data flow
- **Refactorable**: No hidden coupling

### The Rule

Pass dependencies as parameters. No singletons in logic code.

```gdscript
# GOOD: Explicit dependencies
static func generate_event(
    state: Dictionary,
    event_catalog: Array,
    balance: Dictionary,
    rng: RNGManager
) -> Dictionary:
    var roll = rng.randf()
    var threshold = balance.event_chance
    # ...

# BAD: Global access
static func generate_event(state: Dictionary) -> Dictionary:
    var roll = GameStore.get_rng().randf()  # Hidden dependency!
    var threshold = GameStore.get_balance().event_chance  # Another one!
```

### The Autoload Exception

Only ONE autoload: `GameManager`. It owns the Store and provides entry points. Logic code never accesses it directly.

---

## 9. Small, Focused Functions

### What It Means

Each function does one thing. If you need "and" to describe it, split it.

### Why It Matters

- **Readable**: Easy to understand at a glance
- **Testable**: One thing to test
- **LLM-friendly**: Fits in context window

### The Rule

Functions should be <50 lines. If longer, extract subfunctions.

```gdscript
# GOOD: Focused functions
static func check_component_failure(component: Dictionary, balance: Dictionary, roll: float) -> Dictionary:
    var failure_chance = calculate_failure_chance(component, balance)
    if roll < failure_chance:
        return create_failure_result(component)
    return create_success_result(component)

static func calculate_failure_chance(component: Dictionary, balance: Dictionary) -> float:
    var base_rate = balance.base_failure_rate
    var quality_factor = (100 - component.quality) / 50.0
    return base_rate * quality_factor

# BAD: Multi-purpose function
static func update_component_and_maybe_fail_and_log(component, balance, roll, log):
    # 80 lines doing multiple things...
```

---

## 10. Document Assumptions

### What It Means

When code assumes something about inputs or state, document it.

### Why It Matters

- **Maintainable**: Future readers (including Claude) understand constraints
- **Debuggable**: Know when assumptions are violated
- **Safe**: Assertions catch assumption violations early

```gdscript
## Consumes daily resources for all living crew members.
##
## Assumptions:
## - state.crew contains only living crew (dead removed)
## - state.resources exists with food, water, oxygen
## - balance contains daily consumption rates
## - Returns new state; original unchanged (immutable)
static func consume_daily(state: Dictionary, balance: Dictionary, rng: RNGManager) -> Dictionary:
    assert(state.has("crew"), "State must have crew")
    assert(state.has("resources"), "State must have resources")
    # ...
```

---

## Summary: The Checklist

Before committing code, verify:

- [ ] **Reproducible**: RNG injected, never created inline; can simulate 10K runs
- [ ] All logic functions are pure (no side effects)
- [ ] State updates are immutable (duplicate, don't mutate)
- [ ] Errors return Result, not null/-1/false
- [ ] Game state only in Store (no duplicate state)
- [ ] Content in data files, logic in code
- [ ] Inputs validated before processing
- [ ] Functions composed, not inherited
- [ ] Dependencies passed as parameters
- [ ] Functions focused (<50 lines)
- [ ] Assumptions documented
- [ ] Visual effects scale with mechanical impact
