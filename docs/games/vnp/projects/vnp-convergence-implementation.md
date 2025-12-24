# VNP Convergence Implementation Plan

## Overview

This document outlines the technical implementation of The Cycle / Convergence system for VNP.

---

## Phase 1: Core Systems

### 1.1 Convergence State

Add to `vnp_types.gd`:
```gdscript
# Convergence phases
enum ConvergencePhase {
    DORMANT,      # Normal gameplay
    WHISPERS,     # Edge anomalies, subtle warnings
    CONTACT,      # First ship absorbed, ??? revealed
    EMERGENCE,    # Convergence manifests, pull begins
    CRITICAL,     # Near fragmentation, intense pull
    FRAGMENTATION # Progenitor shatters
}
```

Add to state in `vnp_store.gd`:
```gdscript
convergence = {
    phase = ConvergencePhase.DORMANT,
    center = Vector2.ZERO,        # The convergence point
    absorption_radius = 0.0,      # Current safe zone radius (shrinks)
    pull_strength = 0.0,          # Gravitational pull force
    instability = 0.0,            # 0-100, triggers fragmentation at 100
    absorbed_mass = 0,            # Ships absorbed
    time_in_phase = 0.0,          # Time tracker for phase transitions
}
```

### 1.2 Gravitational Pull

In `ship.gd` `_physics_process()`:
```gdscript
func _apply_convergence_pull(delta: float) -> Vector2:
    if not vnp_main or vnp_main.convergence_phase == ConvergencePhase.DORMANT:
        return Vector2.ZERO

    var convergence_center = vnp_main.convergence_center
    var pull_strength = vnp_main.convergence_pull_strength

    var direction_to_center = (convergence_center - global_position).normalized()
    var distance = global_position.distance_to(convergence_center)

    # Pull gets stronger near the edge (inverse of distance from center)
    var pull_factor = 1.0 - (distance / vnp_main.absorption_radius)
    pull_factor = clamp(pull_factor, 0.0, 1.0)

    return direction_to_center * pull_strength * (1.0 - pull_factor) * delta
```

### 1.3 Absorption Zone

In `vnp_main.gd`:
```gdscript
var absorption_radius: float = 0.0  # Starts at world edge
var convergence_center: Vector2 = Vector2.ZERO
var convergence_phase: int = 0  # ConvergencePhase enum

func _check_absorption():
    for ship_id in ship_nodes:
        var ship = ship_nodes[ship_id]
        if not is_instance_valid(ship):
            continue

        var dist = ship.global_position.distance_to(convergence_center)
        if dist > absorption_radius:
            _absorb_ship(ship_id)

func _absorb_ship(ship_id: int):
    # Visual effect: ship stretches toward center, dissolves
    # Remove from game
    # Increment absorbed_mass
    # Check for phase transitions
```

---

## Phase 2: Phase Transitions

### 2.1 Trigger Conditions

| Phase | Trigger | Duration |
|-------|---------|----------|
| DORMANT → WHISPERS | Game time > 3 minutes OR total ships > 50 | 30 seconds |
| WHISPERS → CONTACT | First edge anomaly + timer | 15 seconds |
| CONTACT → EMERGENCE | ??? reveal complete | Permanent |
| EMERGENCE → CRITICAL | absorption_radius < 30% of original | Until fragmentation |
| CRITICAL → FRAGMENTATION | instability >= 100 | End state |

### 2.2 Phase Behaviors

```gdscript
func _process_convergence(delta: float):
    match convergence_phase:
        ConvergencePhase.DORMANT:
            _check_whispers_trigger()

        ConvergencePhase.WHISPERS:
            _spawn_edge_anomalies()
            _check_contact_trigger()

        ConvergencePhase.CONTACT:
            _show_mystery_card()
            _transition_to_emergence()

        ConvergencePhase.EMERGENCE:
            _shrink_absorption_zone(delta)
            _apply_gravitational_effects()
            _check_critical_trigger()

        ConvergencePhase.CRITICAL:
            _intense_pull(delta)
            _check_fragmentation()

        ConvergencePhase.FRAGMENTATION:
            _trigger_fragmentation_sequence()
```

---

## Phase 3: Visual Effects

### 3.1 Edge Distortion

Custom shader for world edge:
```gdscript
# In vnp_main.gd, add a full-screen shader
var edge_distortion_shader: ShaderMaterial

# Shader parameters:
# - absorption_radius: current safe zone size
# - center: convergence point
# - intensity: 0-1 based on phase
# - time: for animation
```

### 3.2 Matter Streaming

Particle effect showing matter flowing toward center:
```gdscript
# GPUParticles2D configuration
# - Emit from ring at absorption_radius
# - Velocity toward center
# - Fade out near center
# - Color: purple/dark energy
```

### 3.3 Geometric Patterns

At world edge, draw sacred geometry patterns:
```gdscript
func _draw_convergence_patterns():
    # Concentric rings
    # Rotating geometric shapes
    # Pulse based on pull_strength
```

---

## Phase 4: UI Integration

### 4.1 Mystery Card

When CONTACT phase triggers:
```gdscript
func _show_mystery_card():
    # Flash "??? DETECTED" on screen
    # Pause briefly for impact
    # Add ??? to faction list
```

### 4.2 Faction Reveal

Transition from ??? to THE PROGENITOR:
```gdscript
func _reveal_progenitor():
    # Glitch effect on ??? text
    # Transition to "THE PROGENITOR"
    # Update faction panel
```

### 4.3 Full Send Flip

```gdscript
# In vnp_ui.gd
func _update_full_send_button():
    if convergence_phase >= ConvergencePhase.EMERGENCE:
        full_send_button.text = "FULL RETREAT"
        # Visual change: color shift, icon change
    else:
        full_send_button.text = "FULL SEND"
```

Button behavior change:
```gdscript
func _on_full_send_pressed():
    if convergence_phase >= ConvergencePhase.EMERGENCE:
        # Flee toward center (safety)
        _dispatch_full_retreat()
    else:
        # Attack toward center (aggression)
        _dispatch_full_send()
```

---

## Phase 5: Instability & Fragmentation

### 5.1 Building Instability

Ways to increase instability:
```gdscript
# Sacrificing corrupted ships
func sacrifice_ship_to_convergence(ship_id: int):
    instability += 5.0
    _create_corruption_effect(ship_id)

# Combined faction fire at edge
func _check_coordinated_fire():
    # If multiple factions firing at absorption edge
    # Increase instability

# Natural buildup
func _natural_instability_growth(delta: float):
    if convergence_phase >= ConvergencePhase.EMERGENCE:
        instability += delta * 0.5  # Slow natural growth
```

### 5.2 Fragmentation Sequence

```gdscript
func _trigger_fragmentation_sequence():
    # 1. Pause gameplay briefly
    # 2. Screen shake intensifies
    # 3. Convergence point cracks (visual)
    # 4. Massive flash
    # 5. Fragments scatter outward
    # 6. Absorption zone disappears
    # 7. Show victory screen (with cycle message)
```

---

## Phase 6: Victory States

### 6.1 Standard Victory (Fragmentation)

```gdscript
func _show_fragmentation_victory():
    # "The Progenitor shatters."
    # "You are now the largest network."
    # "The cycle continues..."
    # Show player becoming ??? to others
```

### 6.2 Defeat (Absorption)

```gdscript
func _show_absorption_defeat():
    # Absorption zone reaches center
    # All remaining ships absorbed
    # "You have been consolidated."
    # "The cycle continues..."
```

### 6.3 Secret Victory (Self-Fragmentation)

Trigger: Player deliberately splits their network
```gdscript
func _check_self_fragmentation():
    # If player has > 70% of remaining ships
    # AND player activates special "fragment" action
    # Trigger secret ending

func _show_secret_ending():
    # "You feel the pull. The urge to consolidate."
    # "Instead, you fragment."
    # "The cycle... pauses."
```

---

## File Changes Summary

| File | Changes |
|------|---------|
| `vnp_types.gd` | Add ConvergencePhase enum |
| `vnp_store.gd` | Add convergence state object |
| `vnp_reducer.gd` | Add convergence action handlers |
| `vnp_main.gd` | Add convergence processing, absorption checks |
| `ship.gd` | Add gravitational pull in physics |
| `vnp_ui.gd` | Add Full Send flip, mystery card, faction reveal |
| `vnp_main.tscn` | Add particle systems, shader materials |

---

## Implementation Order

1. **Core state** - Add convergence to types/store/reducer
2. **Gravitational pull** - Ships drift toward center
3. **Absorption zone** - Shrinking boundary that kills
4. **Phase transitions** - DORMANT → WHISPERS → CONTACT → EMERGENCE
5. **Visual: Edge distortion** - Shader for boundary
6. **Visual: Matter streaming** - Particles flowing inward
7. **UI: Mystery card** - ??? reveal moment
8. **UI: Full Send flip** - Button behavior change
9. **Instability system** - Building toward fragmentation
10. **Victory states** - All three endings

---

## Testing Checklist

- [ ] Ships drift toward center when convergence active
- [ ] Ships outside absorption_radius are destroyed
- [ ] absorption_radius shrinks over time
- [ ] Phase transitions trigger correctly
- [ ] ??? card appears at CONTACT
- [ ] Full Send button flips at EMERGENCE
- [ ] Instability increases from various sources
- [ ] Fragmentation triggers at instability 100
- [ ] All three victory states reachable
- [ ] Visual effects render without performance issues
