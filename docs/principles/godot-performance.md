# Godot Performance Best Practices

This document captures canonical Godot performance patterns based on official documentation and community best practices. It applies to all games in SpaceProbe (MOT, FCW, VNP, MCS).

## Core Principle: Let Godot Do the Work

> "Every feature built into the engine relies on compiled, native, and fast C++ code. As a result, you can have much faster code by using Godot's built-in functions and objects instead of writing them yourself." - [GDQuest](https://www.gdquest.com/tutorial/godot/gdscript/optimization-engine/)

Godot nodes are interfaces to optimized C++ servers. Work *with* the engine, not against it.

---

## The Golden Rules

### 1. Nodes Own Their Own Data

Positions, rotations, and velocities belong on the node, not in a separate state dictionary.

```gdscript
# BAD: Syncing position to external state every frame
func _physics_process(delta):
    store.dispatch({"type": "UPDATE_POSITION", "pos": position})

# GOOD: Node owns its position, dispatch only for events
func _physics_process(delta):
    position += velocity * delta  # Node owns this

func take_damage(amount):
    health -= amount
    if health <= 0:
        died.emit()  # Signal the event, don't sync every frame
```

### 2. Cache Everything

```gdscript
# BAD: Repeated lookups
func _process(delta):
    var turret = $Turret  # Called 60x/second
    var target = find_nearest_enemy()  # O(N) every frame

# GOOD: Cache references and results
@onready var turret = $Turret

var cached_target = null
var target_cache_timer: float = 0.0
const TARGET_CACHE_DURATION: float = 0.3  # Re-evaluate every 300ms

func _process(delta):
    target_cache_timer -= delta
    if target_cache_timer <= 0:
        cached_target = find_nearest_enemy()
        target_cache_timer = TARGET_CACHE_DURATION
```

### 3. Avoid O(N²) Patterns

With N entities, iterating all entities from each entity = N² operations per frame.

```gdscript
# BAD: Every ship iterates all ships every frame
func _physics_process(delta):
    for other in get_tree().get_nodes_in_group("ships"):
        if other.team != team:
            # check distance, etc.

# GOOD: Use Godot's collision system
func _ready():
    $DetectionArea.body_entered.connect(_on_enemy_entered)
    $DetectionArea.body_exited.connect(_on_enemy_exited)

var enemies_in_range: Array = []

func _on_enemy_entered(body):
    if body.team != team:
        enemies_in_range.append(body)

func _on_enemy_exited(body):
    enemies_in_range.erase(body)
```

### 4. Disable Processing for Inactive Nodes

```gdscript
# Disable processing when not needed
func _on_screen_exited():
    set_physics_process(false)

func _on_screen_entered():
    set_physics_process(true)
```

---

## When to Use What

### State Management (Redux-like Store)

**Good for:**
- Team resources (energy, mass, food)
- Game phase / turn state
- Player choices and decisions
- Anything that needs save/load
- Anything UI needs to react to

**Not needed for:**
- Entity positions (Node2D.position exists)
- Entity velocities (CharacterBody2D.velocity exists)
- Transient combat state (targets, cooldowns)

### Signals vs Direct Calls

> "2300 signal emissions = 1ms of processing time" - [Godot Forum](https://forum.godotengine.org/t/performance-of-signals/116202)

Signals are NOT a performance concern. Choose based on architecture:

| Use Signals | Use Direct Calls |
|-------------|------------------|
| Events (died, captured, damaged) | Per-frame updates |
| Decoupled systems (UI reacting to game) | Tight coupling (projectile hitting ship) |
| When nodes might be destroyed | When you have a guaranteed reference |

### Object Pooling

> "Godot 4 has significantly improved node creation performance... Object Pooling still provides tremendous effects when dealing with high-frequency, short-lived objects." - [Uhiyama Lab](https://uhiyama-lab.com/en/notes/godot/godot-object-pooling-basics/)

**Pool these:**
- Projectiles (bullets, missiles, lasers)
- Particle effects
- Damage numbers / floating text

**Don't bother pooling:**
- Ships / units (created infrequently)
- UI elements
- Anything created < once per second

Simple pool pattern:
```gdscript
class_name ProjectilePool
extends Node

var pool: Array[Projectile] = []
var pool_size: int = 50

func _ready():
    for i in pool_size:
        var p = ProjectileScene.instantiate()
        p.set_physics_process(false)
        p.visible = false
        add_child(p)
        pool.append(p)

func get_projectile() -> Projectile:
    for p in pool:
        if not p.active:
            return p
    # Pool exhausted - create new (or return null)
    return null

func return_projectile(p: Projectile):
    p.active = false
    p.visible = false
    p.set_physics_process(false)
```

### ECS vs Nodes

> "ECS is powerful to process tens of thousands of objects every frame, as in triple-A titles. Unless you're writing a triple-A title, a simulation game, or a real-time strategy game where you have tons of tiny units on screen, it's unlikely that you will need something like this." - [Godot Engine](https://godotengine.org/article/why-isnt-godot-ecs-based-game-engine/)

**Stick with nodes unless** you have 10,000+ entities. For our games:
- VNP: ~50-200 ships = nodes are fine
- FCW: ~100-500 units = nodes are fine
- MOT: Turn-based = definitely nodes
- MCS: Colony sim = definitely nodes

---

## Performance Thresholds

From [Godot Forum research](https://forum.godotengine.org/t/collision-pairs-optimizing-performance-of-bullet-hell-enemy-hell-games/35027):

| Metric | Green | Yellow | Red |
|--------|-------|--------|-----|
| Collision pairs | < 2,000 | 2,000-5,000 | > 5,000 |
| Active nodes with `_process` | < 500 | 500-1,000 | > 1,000 |
| Entities iterating all entities | Never | Rarely | Every frame |

---

## Common Pitfalls

### 1. Dictionary Allocation in Loops

```gdscript
# BAD: Creates new dictionary every frame
func _process(delta):
    store.dispatch({"type": "UPDATE", "value": x})

# BETTER: Reuse or avoid if possible
var _update_action = {"type": "UPDATE", "value": 0}
func _process(delta):
    _update_action.value = x
    store.dispatch(_update_action)

# BEST: Don't dispatch every frame for transient data
```

### 2. Group Queries Every Frame

```gdscript
# BAD: Queries scene tree every frame
func _physics_process(delta):
    for missile in get_tree().get_nodes_in_group("missiles"):
        # ...

# GOOD: Cache or use signals
var missiles_in_range: Array = []
# Updated via Area2D signals
```

### 3. Timer Spam

```gdscript
# BAD: 5 separate timers all dispatching
energy_timer.timeout.connect(_regen_energy)
victory_timer.timeout.connect(_check_victory)
income_timer.timeout.connect(_calc_income)

# BETTER: Single game tick
game_tick_timer.timeout.connect(_on_game_tick)

func _on_game_tick():
    _regen_energy()
    _check_victory()
    _calc_income()
```

### 4. Creating Nodes in _process

```gdscript
# BAD: Instantiate in hot path
func _process(delta):
    if should_spawn:
        var effect = EffectScene.instantiate()
        add_child(effect)

# GOOD: Pool or throttle
func _process(delta):
    if should_spawn and effect_pool.has_available():
        var effect = effect_pool.get()
        effect.activate(position)
```

---

## Profiling

Always profile before optimizing. Godot's built-in profiler:

1. Run game
2. Debugger tab → Profiler
3. Look for:
   - Functions taking > 1ms
   - `_physics_process` time across all nodes
   - Physics time (collision pairs)

The profiler shows truth. Gut feelings about performance are often wrong.

---

## Quick Reference

| Do | Don't |
|----|-------|
| Let nodes own positions/velocities | Sync positions to external state |
| Cache targets with cooldown timers | Find targets every frame |
| Use Area2D signals for detection | Iterate all entities manually |
| Pool high-frequency short-lived objects | Pool everything |
| Disable processing for off-screen nodes | Process everything always |
| Profile first, then optimize | Optimize based on assumptions |

---

## Two Valid Architectures

Godot supports two different architectural patterns. Choose based on your game type:

### 1. Node-Based (Physics Games)

**Best for:** Platformers, shooters, action games

```
Nodes own their data (position, velocity, health)
Physics engine handles collision/movement
Signals for events, direct calls for per-frame
```

**Use when:**
- Real-time physics/collision needed
- Entities have complex visual hierarchies
- < 500 entities with individual behavior

**Games:** VNP (real-time combat)

### 2. Data-Driven (Strategy Games)

**Best for:** Strategy, turn-based, simulations

```
State dictionary owns all game data
_draw() renders from state (no entity nodes)
Reducer pattern for state transitions
Signals for UI reactivity
```

**Use when:**
- State must be serializable (save/load)
- Determinism required (replays, networking)
- No physics/collision needed
- Procedural/simple rendering

**Games:** FCW, MCS, MOT

### Why Both Are Valid

From [Godot Docs - When to avoid nodes](https://docs.godotengine.org/en/stable/tutorials/best_practices/node_alternatives.html):
> "Nodes are cheap to produce, but even they have their limits."

From [Godot Docs - Custom drawing in 2D](https://docs.godotengine.org/en/stable/tutorials/2d/custom_drawing_in_2d.html):
> Custom `_draw()` is recommended for "managing drawing logic of a large amount of simple objects"

From [GDQuest - Design Patterns](https://www.gdquest.com/tutorial/godot/design-patterns/intro-to-design-patterns/):
> "Implementing a separate ECS architecture typically adds unnecessary complexity unless you're developing triple-A titles with thousands of entities."

### Hybrid Approach

Some games benefit from both:
- **State dictionary** for resources, turn state, player decisions
- **Nodes** for player ship, complex enemies with physics
- **`_draw()`** for particles, projectiles, background elements

This is the recommended approach for VNP where the player ship needs physics but asteroids/projectiles can be data-driven.

---

## Sources

- [Godot Performance Documentation](https://docs.godotengine.org/en/stable/tutorials/performance/index.html)
- [GDQuest: Making the most of Godot's speed](https://www.gdquest.com/tutorial/godot/gdscript/optimization-engine/)
- [GDQuest: Optimizing GDScript code](https://www.gdquest.com/tutorial/godot/gdscript/optimization-code/)
- [Godot Forum: Collision Pairs Optimization](https://forum.godotengine.org/t/collision-pairs-optimizing-performance-of-bullet-hell-enemy-hell-games/35027)
- [Why isn't Godot an ECS-based engine?](https://godotengine.org/article/why-isnt-godot-ecs-based-game-engine/)
- [Godot Forum: Signal Performance](https://forum.godotengine.org/t/performance-of-signals/116202)
- [GDQuest: Best practices with signals](https://www.gdquest.com/tutorial/godot/best-practices/signals/)
