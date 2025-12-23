# Godot Architecture Patterns

Scene composition, design patterns, and state management for SpaceProbe games.

Reference: [Official Best Practices](https://docs.godotengine.org/en/stable/tutorials/best_practices/index.html)

---

## Core Principle: Composition Over Inheritance

Godot's node system naturally favors composition. Nodes are components; scenes are prefabs.

> "Signals are the engine's version of the Observer pattern, and nodes and their tree-like relationships allow you to favor composition over inheritance." - [GDQuest](https://www.gdquest.com/tutorial/godot/design-patterns/intro-to-design-patterns/)

---

## Scene Organization

### Relational, Not Spatial

Organize the SceneTree by **relationships**, not **positions**. Use `top_level = true` for spatial decoupling.

```gdscript
# BAD: Deeply nested for visual hierarchy
Player
  └── Model
       └── Weapon
            └── MuzzleFlash
                 └── Particles

# GOOD: Flat, relational structure
Player
  ├── Model
  ├── Weapon (top_level = true if needed)
  ├── MuzzleFlash
  └── Particles
```

### Scene Composition Patterns

**Entity-Component Pattern** (Godot style):

```gdscript
# Components as child nodes
Entity (CharacterBody2D)
  ├── HealthComponent
  ├── MovementComponent
  ├── AIComponent (or InputComponent)
  └── CombatComponent
```

Components should work without knowing their parent:

```gdscript
# health_component.gd
extends Node
class_name HealthComponent

signal died
signal health_changed(new_health, max_health)

@export var max_health: int = 100
var current_health: int = max_health

func take_damage(amount: int) -> void:
    current_health = max(0, current_health - amount)
    health_changed.emit(current_health, max_health)
    if current_health <= 0:
        died.emit()
```

### When to Use Groups

Groups identify entities for systems:

```gdscript
# In _ready()
add_to_group("ships")
add_to_group("team_1")

# System queries groups
var all_ships = get_tree().get_nodes_in_group("ships")
```

**When to use groups:**
- Cross-cutting concerns (all damageable entities)
- System queries (AI controller finding all ships)
- Event broadcasting (notify all UI elements)

**When NOT to use groups:**
- Per-frame queries (use Area2D signals instead)
- Parent-child relationships (use direct references)

---

## Design Patterns in Godot

### 1. State Machine (Node-Based)

The recommended approach for character/entity states:

```
Character
  ├── StateMachine
  │   ├── IdleState
  │   ├── MoveState
  │   ├── AttackState
  │   └── DeadState
  └── ...other components
```

**Base State:**

```gdscript
# state.gd
extends Node
class_name State

signal transitioned(state_name: String)

func enter() -> void:
    pass

func exit() -> void:
    pass

func update(_delta: float) -> void:
    pass

func physics_update(_delta: float) -> void:
    pass

func handle_input(_event: InputEvent) -> void:
    pass
```

**State Machine:**

```gdscript
# state_machine.gd
extends Node
class_name StateMachine

@export var initial_state: State
var current_state: State

func _ready() -> void:
    for child in get_children():
        if child is State:
            child.transitioned.connect(_on_state_transitioned)

    if initial_state:
        initial_state.enter()
        current_state = initial_state

func _process(delta: float) -> void:
    if current_state:
        current_state.update(delta)

func _physics_process(delta: float) -> void:
    if current_state:
        current_state.physics_update(delta)

func _unhandled_input(event: InputEvent) -> void:
    if current_state:
        current_state.handle_input(event)

func _on_state_transitioned(state_name: String) -> void:
    var new_state = get_node_or_null(state_name)
    if not new_state or new_state == current_state:
        return

    current_state.exit()
    new_state.enter()
    current_state = new_state
```

**Concrete State Example:**

```gdscript
# idle_state.gd
extends State

@export var move_state: State

func physics_update(_delta: float) -> void:
    var input = Input.get_vector("left", "right", "up", "down")
    if input != Vector2.ZERO:
        transitioned.emit(move_state.name)
```

### 2. Simple Enum State (For Small State Sets)

When you only have 2-4 states:

```gdscript
enum State { IDLE, MOVING, ATTACKING, DEAD }
var current_state: State = State.IDLE

func _physics_process(delta: float) -> void:
    match current_state:
        State.IDLE:
            _process_idle(delta)
        State.MOVING:
            _process_moving(delta)
        State.ATTACKING:
            _process_attacking(delta)
        State.DEAD:
            pass  # No processing
```

### 3. Observer Pattern (Signals)

Godot's signals implement the Observer pattern:

```gdscript
# Emitter (knows nothing about receivers)
signal ship_destroyed(ship_data: Dictionary)

func _on_health_depleted() -> void:
    ship_destroyed.emit({"id": ship_id, "position": position})

# Receiver (connects to signal)
func _ready() -> void:
    ship.ship_destroyed.connect(_on_ship_destroyed)

func _on_ship_destroyed(ship_data: Dictionary) -> void:
    score += ship_data.value
```

### 4. Event Bus Pattern

For cross-system communication:

```gdscript
# game_events.gd (Autoload)
extends Node

signal game_started
signal game_paused
signal game_ended(result: Dictionary)
signal resource_changed(resource_type: String, amount: int)
signal entity_spawned(entity: Node)
signal entity_destroyed(entity: Node)
```

```gdscript
# Usage
GameEvents.resource_changed.emit("energy", 100)
GameEvents.game_ended.connect(_on_game_ended)
```

### 5. Flyweight Pattern (Resources)

Use Resources for shared data:

```gdscript
# ship_stats.gd
extends Resource
class_name ShipStats

@export var max_health: int = 100
@export var speed: float = 200.0
@export var damage: int = 10
@export var fire_rate: float = 0.5
```

Multiple ships reference the same resource:

```gdscript
@export var stats: ShipStats

func _ready() -> void:
    health = stats.max_health
    speed = stats.speed
```

### 6. Prototype Pattern (Scenes)

Clone scenes for spawning:

```gdscript
# spawner.gd
@export var entity_scene: PackedScene

func spawn(position: Vector2) -> Node:
    var entity = entity_scene.instantiate()
    entity.position = position
    add_child(entity)
    return entity
```

---

## Data Sharing Patterns

### Static Variables (Scene-Persistent)

```gdscript
# Shared across all instances of this class
static var total_kills: int = 0

# Access from anywhere
Ship.total_kills += 1
```

### Custom Resources (Flyweight)

```gdscript
# balance.gd
extends Resource
class_name Balance

@export var base_damage: int = 10
@export var crit_multiplier: float = 2.0
```

Load once, share everywhere:

```gdscript
var balance: Balance = preload("res://data/balance.tres")
```

### Autoloads (Cross-Cutting Concerns)

Best for:
- Event buses
- Audio managers
- Game state (if not using Redux pattern)
- Settings/configuration

```
Project Settings → Autoload:
- GameEvents (game_events.gd)
- AudioManager (audio_manager.gd)
- Settings (settings.gd)
```

---

## Memory Management

### Reference Counting

Godot uses reference counting for Resources and RefCounted objects:

```gdscript
# Automatically freed when no references remain
var resource = load("res://data/my_resource.tres")
# When resource goes out of scope or is reassigned, it may be freed
```

### Manual Freeing

Nodes require manual freeing:

```gdscript
# Free a node (and all children)
node.queue_free()

# Check validity before using
if is_instance_valid(cached_enemy):
    cached_enemy.take_damage(10)
```

### Object Pooling

For frequently created/destroyed objects:

```gdscript
class_name ObjectPool
extends Node

var _pool: Array[Node] = []
var _scene: PackedScene

func _init(scene: PackedScene, initial_size: int = 10) -> void:
    _scene = scene
    for i in initial_size:
        var obj = _scene.instantiate()
        obj.set_process(false)
        obj.visible = false
        _pool.append(obj)
        add_child(obj)

func acquire() -> Node:
    for obj in _pool:
        if not obj.visible:
            obj.set_process(true)
            obj.visible = true
            return obj
    # Pool exhausted - grow or return null
    return null

func release(obj: Node) -> void:
    obj.set_process(false)
    obj.visible = false
```

---

## SpaceProbe Game Architectures

### VNP (Real-Time Combat)

```
VNPMain
  ├── VNPStore (state management)
  ├── ShipContainer
  │   └── [Ship nodes - own their positions]
  ├── ProjectilePool
  ├── EffectPool
  ├── AIController
  └── VNPCamera
```

- Ships are CharacterBody2D (physics-based movement)
- Projectiles pooled (high-frequency creation)
- State stores team resources, not entity positions
- Area2D for detection (avoiding O(N²))

### FCW (Turn-Based Strategy + Real-Time Map)

```
FCWMain
  ├── FCWStore (all game state)
  ├── FCWSolarMap (visual representation)
  │   ├── PlanetNodes (visual only)
  │   └── EntitySprites (visual only)
  ├── FCWBattleView (battle rendering)
  └── FCWUI
```

- State dictionary owns all entity data
- Views render from state (no entity nodes)
- _draw() for particles/effects (lightweight)
- Signals for UI reactivity

### MCS (Colony Sim)

```
MCSMain
  ├── MCSStore (state management)
  ├── MCSView (isometric rendering)
  │   ├── BuildingSprites
  │   └── ColonistSprites
  ├── MCSUI
  └── MCSAIController
```

- Turn-based updates (yearly)
- Isometric sprites positioned once
- State owns building/colonist data
- Minimal per-frame processing

### MOT (Turn-Based Journey)

```
MOTMain
  ├── MOTStore (state management)
  ├── MOTView
  │   ├── StarField (parallax)
  │   └── ShipDisplay
  └── MOTUI
```

- Day-by-day advancement
- State owns all data
- Visual effects via Tweens
- Minimal real-time processing

---

## Anti-Patterns to Avoid

### 1. God Objects

```gdscript
# BAD: One script does everything
class_name GameManager
func spawn_enemy(): ...
func update_ui(): ...
func save_game(): ...
func play_sound(): ...
```

```gdscript
# GOOD: Separate concerns
class_name SpawnManager
class_name UIManager
class_name SaveManager
class_name AudioManager
```

### 2. Circular Dependencies

```gdscript
# BAD: A references B, B references A
# player.gd
var enemy_manager: EnemyManager
# enemy_manager.gd
var player: Player
```

```gdscript
# GOOD: Use signals or event bus
# player.gd
signal player_moved(position)
# enemy_manager.gd
func _ready():
    player.player_moved.connect(_on_player_moved)
```

### 3. Deep Inheritance Hierarchies

```gdscript
# BAD: Hard to follow, fragile
Enemy < Unit < Entity < Node2D

# GOOD: Composition
Entity (Node2D)
  ├── HealthComponent
  ├── MovementComponent
  └── EnemyAIComponent
```

---

## Quick Reference

| Pattern | Use When | SpaceProbe Example |
|---------|----------|-------------------|
| Entity-Component | Complex entities with shared behaviors | Ships with health, movement, weapons |
| State Machine | Distinct behavioral states | Ship combat states (idle, attacking, fleeing) |
| Event Bus | Cross-system communication | Game events, UI updates |
| Object Pool | High-frequency instantiation | Projectiles, particles |
| Flyweight (Resource) | Shared configuration data | Ship stats, balance values |
| Singleton (Autoload) | Global systems | Audio manager, settings |

---

## Sources

- [Godot Scene Organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html)
- [GDQuest Design Patterns](https://www.gdquest.com/tutorial/godot/design-patterns/intro-to-design-patterns/)
- [GDQuest Entity-Component Pattern](https://www.gdquest.com/tutorial/godot/design-patterns/entity-component-pattern/)
- [Shaggy Dev State Machines](https://shaggydev.com/2023/10/08/godot-4-state-machines/)
- [GDQuest Finite State Machine](https://www.gdquest.com/tutorial/godot/design-patterns/finite-state-machine/)
- [Heartbeast Easy Composition](https://heartgamedev.substack.com/p/easy-composition-in-godot-4)
- [GoTut Composition in Godot 4](https://www.gotut.net/composition-in-godot-4/)
