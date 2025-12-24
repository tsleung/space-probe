# Phase 6: UI Migration

## Status: COMPLETE

## Overview

Phase 6 provides infrastructure for UI components to bind to the new Store system with automatic change detection and cleanup. This enables a gradual migration of existing UI code.

## Components Created

### StoreBinding (`scripts/engine/ui/store_binding.gd`)

A utility class that simplifies binding UI components to Store state.

**Features:**
- Automatic change detection
- Path-based property binding
- Computed value binding
- Automatic cleanup on node destruction
- Value comparison optimization

## Usage Examples

### Basic Property Binding

```gdscript
extends Control

var _binding: StoreBinding

func _ready():
    _binding = StoreBinding.new(self, GameStore)

    # Bind to a specific path in state
    _binding.bind_property("resources.food.current", _on_food_changed)
    _binding.bind_property("current_day", _on_day_changed)

func _on_food_changed(food_amount: float):
    $FoodLabel.text = "Food: %.0f kg" % food_amount

func _on_day_changed(day: int):
    $DayLabel.text = "Day %d" % day
```

### Computed Values

```gdscript
func _ready():
    _binding = StoreBinding.new(self, GameStore)

    # Bind to a computed value
    _binding.bind_computed(
        func(): return GameStore.get_state().crew.filter(func(c): return c.status != "DEAD").size(),
        _on_living_crew_changed
    )

func _on_living_crew_changed(count: int):
    $CrewCountLabel.text = "Crew: %d" % count
```

### Derived Values

```gdscript
func _ready():
    _binding = StoreBinding.new(self, GameStore)

    # Derive a value from multiple paths
    _binding.derive(
        ["resources.food.current", "crew"],
        func(values): return values[0] / max(1, values[1].size()),
        _on_food_per_crew_changed
    )

func _on_food_per_crew_changed(food_per_crew: float):
    $FoodPerCrewLabel.text = "Food/Crew: %.1f" % food_per_crew
```

### Array Binding

```gdscript
func _ready():
    _binding = StoreBinding.new(self, GameStore)

    # Bind to array length
    _binding.bind_array_length("crew", _on_crew_count_changed)

    # Bind to full array for list updates
    _binding.bind_property("crew", _on_crew_list_changed)

func _on_crew_count_changed(count: int):
    $CrewHeader.text = "Crew (%d)" % count

func _on_crew_list_changed(crew: Array):
    # Rebuild crew list UI
    _rebuild_crew_list(crew)
```

### Any Change

```gdscript
func _ready():
    _binding = StoreBinding.new(self, GameStore)

    # Called on every state change
    _binding.bind_any(_on_any_change)

func _on_any_change(state: Dictionary):
    # Update based on full state
    _sync_ui_to_state(state)
```

## Migration Strategy

### Step 1: Add Binding to Existing UI

```gdscript
# Before (polling or manual signal handling)
func _process(_delta):
    var state = GameStore.get_state()
    $Label.text = str(state.resources.food.current)

# After (reactive binding)
func _ready():
    _binding = StoreBinding.new(self, GameStore)
    _binding.bind_property("resources.food.current", func(v): $Label.text = str(v))
```

### Step 2: Remove Manual Signal Connections

```gdscript
# Before
func _ready():
    GameStore.state_changed.connect(_on_state_changed)

func _on_state_changed(state):
    # Update everything, even if only one thing changed
    _update_food(state.resources.food)
    _update_crew(state.crew)
    _update_components(state.ship.components)

# After
func _ready():
    _binding = StoreBinding.new(self, GameStore)
    _binding.bind_property("resources.food", _update_food)
    _binding.bind_property("crew", _update_crew)
    _binding.bind_property("ship.components", _update_components)
```

### Step 3: Move to Computed Values for Complex State

```gdscript
# Before
func _on_state_changed(state):
    var total_quality = 0.0
    for comp in state.ship.components.values():
        total_quality += comp.quality
    var avg = total_quality / max(1, state.ship.components.size())
    $QualityLabel.text = "Avg Quality: %.0f%%" % avg

# After
func _ready():
    _binding = StoreBinding.new(self, GameStore)
    _binding.bind_computed(
        func(): return ComponentSystem.get_average_quality(GameStore.get_state()),
        func(avg): $QualityLabel.text = "Avg Quality: %.0f%%" % avg
    )
```

## Benefits

### 1. Automatic Cleanup

When the UI node is freed, all bindings are automatically disconnected:

```gdscript
# No need for manual cleanup!
func _ready():
    _binding = StoreBinding.new(self, GameStore)
    _binding.bind_property("current_day", _update_day)
    # Binding auto-disconnects when this node is freed
```

### 2. Change Detection

Only callbacks for changed values are called:

```gdscript
# Before: All handlers called on every change
GameStore.state_changed.connect(func(s):
    _update_food(s.resources.food)  # Called even if food didn't change
    _update_day(s.current_day)       # Called even if day didn't change
)

# After: Only changed values trigger callbacks
_binding.bind_property("resources.food", _update_food)
_binding.bind_property("current_day", _update_day)
```

### 3. Deep Path Access

Access nested state easily:

```gdscript
_binding.bind_property("ship.components.cockpit.quality", _on_cockpit_quality)
_binding.bind_property("crew.0.health", _on_commander_health)
```

## File Structure

```
scripts/engine/ui/
└── store_binding.gd   # UI-Store binding utility
```

## Integration with Existing Code

The StoreBinding is additive - existing UI code continues to work. Migration can happen gradually:

1. **Immediate**: New UI components use StoreBinding
2. **Gradual**: Existing components migrated as they're touched
3. **Optional**: Some components may remain using direct signals

## Testing UI Bindings

```gdscript
func test_binding_updates_on_change():
    var mock_store = MockStore.new()
    var ui_node = Node.new()
    var binding = StoreBinding.new(ui_node, mock_store)

    var captured_value = null
    binding.bind_property("test.value", func(v): captured_value = v)

    mock_store.update_state({"test": {"value": 42}})

    assert(captured_value == 42)
```

## Next Phase

Phase 7: Cleanup - Remove deprecated code, update CLAUDE.md, and finalize documentation.
