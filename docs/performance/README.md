# Performance Optimization Tasks

This directory contains game-specific performance audits and optimization tasks for LLM coding agents.

## Quick Reference

| Game | Priority | Status | Primary Concern |
|------|----------|--------|-----------------|
| [VNP](./vnp-performance-tasks.md) | **HIGH** | 3 critical issues | O(N²) loops in real-time combat |
| [FCW](./fcw-performance-tasks.md) | MEDIUM | Audit needed | Solar map entity updates |
| [MCS](./mcs-performance-tasks.md) | LOW | No issues found | Turn-based, minimal risk |
| [MOT](./mot-performance-tasks.md) | LOW | No issues found | Turn-based, minimal risk |

## Principles

All games should follow the patterns in [`docs/principles/godot-performance.md`](../principles/godot-performance.md).

### Key Rules

1. **Nodes own their own data** - Don't sync positions to state every frame
2. **Cache everything** - Use @onready, cache targets with TTL
3. **Avoid O(N²)** - Use Area2D signals instead of iterating all entities
4. **Pool frequently-created objects** - Projectiles, particles, damage numbers
5. **Disable processing for inactive nodes** - set_physics_process(false)

## VNP Critical Issues Summary

These need immediate attention for VNP to scale beyond 50 ships:

```
1. O(N²) scatter force     → ship.gd:1002-1014  → Use Area2D for ally detection
2. O(N²) threat assessment → ship.gd:1095-1104  → Use Area2D for enemy detection
3. O(N²) flank calculation → ship.gd:1022-1026  → Precompute team centers
4. Group query per frame   → ship.gd:1670       → Maintain missile registry
```

## For LLM Agents

When working on a specific game, read the corresponding performance doc first:

```
Working on VNP? → Read vnp-performance-tasks.md
Working on FCW? → Read fcw-performance-tasks.md
Working on MCS? → Read mcs-performance-tasks.md
Working on MOT? → Read mot-performance-tasks.md
```

After implementing fixes:
1. Run stress test scenario described in the doc
2. Profile with Godot's built-in profiler
3. Update the doc with "FIXED" status and commit
