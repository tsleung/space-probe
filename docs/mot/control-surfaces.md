# MOT Phase 2: Control Surfaces Reference

> **Design Inspiration:** FTL's power system - fewer systems, deeper trade-offs
> **Research:** See [Control Surface Design Research](research/control-surface-design.md)

## Design Philosophy

**Fewer systems, more meaningful choices.**

We have 6 core systems + 1 emergency button. Each system has a genuine trade-off where different states are optimal in different situations. There are no "always boost when you have power" options.

Key principles:
- Every surface must have a **real trade-off**
- No **dominant strategies** (if one option is always best, it's a fake choice)
- Systems should **interact** (shields drain power needed for engines)
- **Clear consequences** (not vague "morale bonus")

---

## Surface Types

| Type | Interaction | Examples |
|------|-------------|----------|
| **Lever** | Toggle between 2-3 positions | Engine IDLE/CRUISE/BURN |
| **Button** | One-time activation | Emergency Power |

## Surface States

| State | Visual | Description |
|-------|--------|-------------|
| **WORKING** | Green glow, soft pulse | Normal operation |
| **USING** | Yellow glow, animation | Crew currently interacting |
| **BROKEN** | Red, sparks + smoke | Damaged, needs repair |

---

## Power System

### The Power Equation

```
Net Power = Generation - Drain

If Net > 0: Surplus charges batteries
If Net = 0: Balanced, no buffer
If Net < 0: Deficit drains batteries
If batteries empty: Systems start failing
```

### Generation Sources

| Source | Output | Notes |
|--------|--------|-------|
| Solar Panels | +5/hr | Passive, decreases far from sun |
| Power Core NORMAL | +10/hr | Safe, sustainable |
| Power Core OVERDRIVE | +15/hr | +50%, but generates heat |

**Sustainable generation:** 15/hr (solar + normal core)
**Maximum generation:** 20/hr (solar + overdrive, risky)

---

## The 6 Core Systems

### 1. Power Core
**Location:** Engineering | **Type:** Lever

| State | Output | Heat | Risk |
|-------|--------|------|------|
| NORMAL | 10/hr | None | Safe |
| OVERDRIVE | 15/hr | +2/hr | Explosion if heat reaches 10 |

**Trade-off:** More power vs explosion risk

**When each state is optimal:**
- NORMAL: Sustainable operations, no emergencies
- OVERDRIVE: Crisis requires shields + burn + medical simultaneously

**Heat Mechanic:**
```
Heat accumulates: +2/hr in OVERDRIVE
Heat dissipates: -1/hr in NORMAL

Heat 0-5: Safe
Heat 6-7: Warning (steam particles)
Heat 8-9: Danger (alarms)
Heat 10+: CRITICAL - 10 seconds to explosion
```

**Explosion damages:** Power Core (BROKEN), Engine (50% chance), Fire in Engineering

**Broken:** No power generation, emergency lights only

---

### 2. Shields
**Location:** Bridge | **Type:** Lever

| State | Drain | Effect |
|-------|-------|--------|
| OFF | 0 | No protection |
| ON | 6/hr | 50% damage reduction from events |

**Trade-off:** Protection vs significant power drain

**When each state is optimal:**
- OFF: Safe cruising between events. Save power for life support/engines.
- ON: Event incoming, asteroid field, solar flare. Worth the drain.

**Broken:** No shields available, sparking console

---

### 3. Engine
**Location:** Engineering | **Type:** Lever

| State | Drain | Speed | Fuel Use |
|-------|-------|-------|----------|
| IDLE | 1/hr | 0.5x | 0.25x |
| CRUISE | 3/hr | 1.0x | 1.0x |
| BURN | 8/hr | 1.5x | 2.0x |

**Trade-off:** Speed vs fuel consumption (and power drain)

**When each state is optimal:**
- IDLE: Conserving fuel for Mars braking. Events are manageable.
- CRUISE: Standard travel. Balanced efficiency.
- BURN: Escaping cascade failure. Need to reach Mars faster. Danger behind.

**Broken:** No thrust, ship drifts

---

### 4. Life Support
**Location:** Life Support Bay | **Type:** Lever

| State | Drain | O2 Production | Water Production |
|-------|-------|---------------|------------------|
| MINIMAL | 2/hr | 0.5x | 0.5x |
| NORMAL | 4/hr | 1.0x | 1.0x |
| BOOSTED | 8/hr | 1.5x | 1.5x |

**Trade-off:** Resource production vs power drain

**When each state is optimal:**
- MINIMAL: Crisis mode - divert power to shields/engines. Crew survives on reserves.
- NORMAL: Standard operations. Sustainable.
- BOOSTED: O2 or water reserves critically low. Need to rebuild buffer fast.

**Broken:** O2 and water deplete. Crew suffocates/dehydrates. Red warning, steam vents.

---

### 5. Medical Bay
**Location:** Medical | **Type:** Lever

| State | Drain | Healing Rate |
|-------|-------|--------------|
| OFF | 0 | None |
| ON | 4/hr | 1.0x |

**Trade-off:** Healing vs power (only relevant when crew injured)

**When each state is optimal:**
- OFF: No crew injured. Why waste 4/hr of power?
- ON: Crew hurt from event/crisis. Get them healed.

**No dominant strategy:** Unlike "NORMAL/INTENSIVE" design, OFF is correct when no one is hurt.

**Broken:** No healing possible, flatline beep

---

### 6. Sensors
**Location:** Bridge | **Type:** Lever

| State | Drain | Effect |
|-------|-------|--------|
| OFF | 0 | No early warning |
| ON | 2/hr | +1 day warning before events |

**Trade-off:** Preparation time vs power drain

**When each state is optimal:**
- OFF: Already in a crisis. Power needed for shields/engines. No point watching for next event.
- ON: Cruising safely. Early warning lets you prepare (boost shields, adjust course).

**Broken:** No early warning, worse event outcomes

---

### 7. Emergency Power (Button)
**Location:** Engineering | **Type:** Button

| State | Effect |
|-------|--------|
| STANDBY | Ready, yellow light |
| ACTIVE | +10 power for 30 seconds |
| DEPLETED | Must recharge (5 minute cooldown) |

**One-time crisis tool.** Press when you need burst power to survive.

---

## Power Budget Scenarios

### Safe Cruising
```
Life Support NORMAL: 4/hr
Engine CRUISE: 3/hr
Sensors ON: 2/hr
─────────────────────
Total drain: 9/hr
Generation: 15/hr
Surplus: +6/hr ✓
```

### Alert Mode (Event Approaching)
```
Life Support NORMAL: 4/hr
Shields ON: 6/hr
Engine CRUISE: 3/hr
Sensors ON: 2/hr
─────────────────────
Total drain: 15/hr
Generation: 15/hr
Balance: 0 (sustainable but tight)
```

### Combat/Crisis
```
Life Support MINIMAL: 2/hr
Shields ON: 6/hr
Engine BURN: 8/hr
Medical ON: 4/hr
─────────────────────
Total drain: 20/hr
Generation: 15/hr
Deficit: -5/hr (draining batteries!)
```
**Options:** Use Emergency Power, or switch to OVERDRIVE (risk explosion).

### Emergency Escape
```
Life Support MINIMAL: 2/hr
Shields ON: 6/hr
Engine BURN: 8/hr
─────────────────────
Total drain: 16/hr
Generation OVERDRIVE: 20/hr
Surplus: +4/hr BUT heat building
```
**Sustainable for ~2-3 hours before heat becomes critical.**

---

## Repair System

### Repair Times

| System | Repair Time | Notes |
|--------|-------------|-------|
| Sensors | 4s | Quick fix |
| Medical Bay | 5s | Standard |
| Shields | 6s | Standard |
| Life Support | 8s | Complex |
| Engine | 10s | Heavy machinery |
| Power Core | 15s | Critical system |

### Repair Requirements
- Crew member must travel to broken system
- Repair takes real time (above)
- Some repairs may require spare parts (CRISIS mode)

---

## Integration with CRISIS Mode

During CRISIS mode:
- Systems can be damaged by crisis events
- 30% chance of system damage on asteroid impact
- Power surge from solar flare can break electronics
- Broken systems add to crisis pressure

Systems most likely to break during CRISIS:
- Life Support (cascade from O2 crisis)
- Power Core (overheating during high demand)
- Shields (external damage)

---

## Visual Language

| State | Color | Particles | Sound |
|-------|-------|-----------|-------|
| WORKING | Green | Soft pulse | Ambient hum |
| OFF | Gray | None | Silent |
| USING | Yellow | Animation | Interaction sound |
| WARNING | Orange | Steam/flicker | Alarm beep |
| BROKEN | Red | Sparks, smoke | Harsh alarm |

---

## Implementation Status

- [x] 6 system definitions
- [x] Power balance calculation
- [x] Heat mechanic design
- [ ] Update control_surface.gd to match
- [ ] Update control_surface_manager.gd
- [ ] Visual representation
- [ ] Crew interaction commands
- [ ] Sound effects
