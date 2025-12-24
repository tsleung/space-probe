# Control Surface Design Research

> **Purpose:** Document research and design decisions for MOT Phase 2 control surfaces.
> **Date:** December 2024

## Design Question

How many interactive ship systems should we have, and what makes each one worth including?

---

## External Research

### FTL: Faster Than Light

**Source:** [FTL Analysis](http://www.vigaroe.com/2020/04/ftl-analysis-systems-and-subsystems.html), [FTL Wiki](https://ftl.fandom.com/wiki/Systems)

FTL has ~8 main systems + 4 subsystems:

| Main Systems | Subsystems |
|--------------|------------|
| Shields, Engines, Oxygen, Weapons | Piloting, Sensors, Doors, Backup Battery |
| Medbay/Clone Bay, Drone Control | |
| Cloaking, Hacking, Mind Control, Teleporter | |

**Key Design Decisions:**

1. **Deliberate cuts**: Developers explicitly cut "managing food and morale, worrying about traitors and mutiny" to focus on "crew movement and power management"

2. **Power as constraint**: Power management only becomes interesting when there's genuine scarcity. Critics noted that early game, power feels like "shields cost more scrap" - the real tension comes late game when you're forced to divert power from X to Y.

3. **Systems interact**: Fires consume oxygen. Doors control fire spread. Breaches drain O2. This creates emergent gameplay.

4. **Clear categories**: Main systems need power allocation. Subsystems work automatically but can be damaged.

**Criticism of FTL's power system:**
> "The need to upgrade the Reactor to power your upgraded Shields isn't meaningfully different from just making Shields cost more Scrap."

The lesson: Power management must create **active trade-offs**, not just be another upgrade currency.

---

### Barotrauma

**Source:** [Barotrauma Discussions](https://github.com/FakeFishGames/Barotrauma/discussions/4971)

**Key Insights:**

1. **Physical consequences matter**: "Class identity should arise from the ingenuity of sub builders when faced with practical challenges... a physical consequence of specific design choices."

2. **Avoid single-responsibility boredom**: Players don't want to feel "stuck in the reactor room with one job." Systems should create variety in moment-to-moment gameplay.

3. **Emergent gameplay over scripted**: Inspired by Space Station 13's emergent chaos. Systems should interact in ways that create unexpected situations.

---

### Meaningful Choice Theory

**Source:** [Fewer Options, More Meaningful Choices](https://www.gamedeveloper.com/design/fewer-options-more-meaningful-choices), [Meaningful Choices in Game Design](https://medium.com/@doandaniel/gamedev-thoughts-the-power-of-meaningful-choices-in-game-design-50dbdeb0348a)

**Core Principles:**

1. **Constraints create meaning**: "Restrictions on items allow them to be powerful, and thus the choice of which item to take becomes incredibly meaningful."

2. **Avoid dominant strategies**: If one option is always best, the choice is fake. Players will find the optimal path and the "choice" becomes rote.

3. **Permanence matters**: Meaningful choices have consequences that can't be easily undone.

4. **Overcomplication is a trap**: "One of the most common mistakes in resource management design is overcomplicating the mechanics without a clear purpose."

**Anti-patterns:**

- **Final Fantasy's cure items**: Unlimited inventory space means players carry everything. Status ailments never feel threatening because you always have the cure.

- **League of Legends runes**: 30 rune slots makes each individual rune negligible. Weak individual impact = irrelevant to strategy.

---

## Analysis of Original 15 Surfaces

We initially designed 15 control surfaces. Here's the critical analysis:

### Surfaces with Real Trade-offs (Keep)

| Surface | Why It Works |
|---------|--------------|
| **Shield Emitter** | OFF/LOW/HIGH creates genuine choice. High shields = high drain. |
| **Engine Throttle** | Speed vs fuel is a core journey decision with long-term consequences. |
| **Reactor Core** | OVERDRIVE risk/reward. More power but heat → explosion creates tension. |
| **Emergency Power** | Limited use crisis tool. Scarcity creates drama. |

### Surfaces with Dominant Strategies (Problem)

| Surface | Problem |
|---------|---------|
| **O2 Recycler** | BOOSTED is always better when you have power. No trade-off. |
| **Water Recycler** | Binary working/broken. No player agency. |
| **Medical Console** | INTENSIVE is always better when crew hurt. No trade-off. |
| **Nav Computer** | AUTOPILOT is strictly better than MANUAL. Fake choice. |
| **Comms Array** | "Morale bonus" is vague. When wouldn't you boost? |
| **External Sensors** | BOOSTED is always better. No trade-off. |

### Surfaces That Aren't Really "Controls"

| Surface | Problem |
|---------|---------|
| **Solar Panels** | Passive generation. No interaction. |
| **Cargo Loader** | Automatic during retrieval. No choice. |
| **Hull Monitor** | Display only. Information, not control. |
| **Coolant System** | Only exists to service reactor. Could be merged. |
| **Bulkhead Doors** | No fires or intruders in our game. What's the purpose? |

### Summary

- **4 surfaces** have genuine trade-offs
- **6 surfaces** have dominant strategies (fake choices)
- **5 surfaces** aren't interactive controls

**Conclusion:** 15 surfaces is cognitive overload with too few meaningful decisions.

---

## Design Principles (Derived)

Based on research, our control surfaces should follow these rules:

### 1. Every Surface Must Have a Trade-off

Bad: "BOOSTED mode is better, costs more power"
Good: "BOOSTED mode gives X but prevents Y" or "choosing A means giving up B"

### 2. No Dominant Strategies

If players always choose the same option when power is available, the choice is fake. Each option should be situationally optimal.

### 3. Fewer Systems, More Depth

6 meaningful systems > 15 shallow ones. Each system should be worth thinking about.

### 4. Systems Should Interact

Reactor heat → needs cooldown → can't overdrive constantly
Shields ON → less power for engines → slower travel
This creates emergent decision-making.

### 5. Clear Consequences

Players should understand what each choice costs them. Vague "morale bonus" fails this test.

### 6. Situational Relevance

Not every system matters all the time. Medical Bay only matters when crew is hurt. This is good - it means the player focuses on what's relevant.

---

## Revised Design: 6 Core Systems

### The Systems

| System | Location | Type | States |
|--------|----------|------|--------|
| **Power Core** | Engineering | Lever | NORMAL / OVERDRIVE |
| **Shields** | Bridge | Lever | OFF / ON |
| **Engine** | Engineering | Lever | IDLE / CRUISE / BURN |
| **Life Support** | Life Support | Lever | MINIMAL / NORMAL / BOOSTED |
| **Medical Bay** | Medical | Lever | OFF / ON |
| **Sensors** | Bridge | Lever | OFF / ON |

Plus: **Emergency Power** (Button, one-time use per crisis)

### Trade-off Analysis

| System | Trade-off | When Each State is Optimal |
|--------|-----------|---------------------------|
| **Power Core** | Power vs explosion risk | OVERDRIVE when you need burst power, NORMAL for safety |
| **Shields** | Protection vs power drain | ON during events/combat, OFF during safe travel |
| **Engine** | Speed vs fuel | BURN to escape danger, CRUISE for efficiency, IDLE to conserve |
| **Life Support** | O2/Water vs power | MINIMAL in crisis (power elsewhere), BOOSTED when low on supplies |
| **Medical Bay** | Healing vs power | ON when crew hurt, OFF otherwise (no dominant strategy!) |
| **Sensors** | Warning vs power | ON before events, OFF during known-safe periods |

### Why Each State Can Be Optimal

**Power Core:**
- NORMAL: Safe default, sustainable power
- OVERDRIVE: When you NEED shields + burn + medical simultaneously. Risk of explosion if heat not managed.

**Shields:**
- OFF: Cruising safely between events. Save power for life support.
- ON: Event incoming, asteroid field, combat. Worth the drain.

**Engine:**
- IDLE: Conserving fuel for Mars braking. Events are manageable.
- CRUISE: Standard travel. Balanced.
- BURN: Escaping a cascade failure. Need distance NOW.

**Life Support:**
- MINIMAL: Crisis mode - divert power to shields/engines. Crew can survive briefly.
- NORMAL: Standard operations.
- BOOSTED: Running low on O2/water reserves. Need to build buffer.

**Medical Bay:**
- OFF: No one is hurt. Why waste power?
- ON: Crew injured. Get them healed.

**Sensors:**
- OFF: Already in a crisis. Power needed elsewhere.
- ON: Watching for incoming events. Preparation time is valuable.

---

## Power Budget

### Generation

| Source | Output | Notes |
|--------|--------|-------|
| Solar Panels | +5/hr | Passive, decreases with distance from sun |
| Power Core NORMAL | +10/hr | Base output |
| Power Core OVERDRIVE | +15/hr | +50%, but generates heat |

**Total sustainable:** 15/hr (with solar) or 25/hr (overdrive, risky)

### Consumption

| System | State | Drain |
|--------|-------|-------|
| Life Support | MINIMAL | 2/hr |
| Life Support | NORMAL | 4/hr |
| Life Support | BOOSTED | 8/hr |
| Shields | ON | 6/hr |
| Engine | IDLE | 1/hr |
| Engine | CRUISE | 3/hr |
| Engine | BURN | 8/hr |
| Medical Bay | ON | 4/hr |
| Sensors | ON | 2/hr |

### Scenario Analysis

**Safe Cruising:**
```
Life Support NORMAL (4) + Engine CRUISE (3) + Sensors ON (2) = 9/hr
Generation: 15/hr
Surplus: +6/hr (comfortable)
```

**Alert Mode:**
```
Life Support NORMAL (4) + Shields ON (6) + Engine CRUISE (3) + Sensors ON (2) = 15/hr
Generation: 15/hr
Balance: 0 (sustainable but tight)
```

**Combat/Crisis:**
```
Life Support MINIMAL (2) + Shields ON (6) + Engine BURN (8) + Medical ON (4) = 20/hr
Generation: 15/hr
Deficit: -5/hr (draining batteries, need OVERDRIVE)
```

**Emergency Escape:**
```
Life Support MINIMAL (2) + Shields ON (6) + Engine BURN (8) = 16/hr
Generation OVERDRIVE: 25/hr
Surplus: +9/hr BUT heat building toward explosion
```

The tension: **You can't have everything.** Each crisis forces prioritization.

---

## What Was Removed

| Old Surface | Disposition | Reasoning |
|-------------|-------------|-----------|
| Coolant System | Merged | Part of Power Core heat management |
| Nav Computer | Removed | Autopilot was always better (dominant strategy) |
| Comms Array | Removed | "Morale bonus" too vague, no clear trade-off |
| O2 Recycler | Merged | Combined into Life Support |
| Water Recycler | Merged | Combined into Life Support |
| Solar Panels | Background | Power generation, not a control |
| Cargo Loader | Removed | Automatic, not a player choice |
| Bulkhead Doors | Removed | No fires/intruders, no purpose in our game |
| Hull Monitor | UI element | Display, not a control |

---

## Heat Mechanic (Power Core)

When Power Core is OVERDRIVE:

```
Heat accumulates: +2 per hour in OVERDRIVE
Heat dissipates: -1 per hour in NORMAL

Heat levels:
0-5: Safe (no indicator)
6-7: Warning (yellow, steam particles)
8-9: Danger (orange, alarms)
10+: CRITICAL (10 seconds to explosion)
```

**Explosion consequences:**
- Power Core → BROKEN (no power generation)
- Fire in Engineering room
- 50% chance Engine damaged

**Counter-play:**
- Switch to NORMAL to cool down
- Can't stay in OVERDRIVE indefinitely
- Creates pulse pattern: OVERDRIVE → NORMAL → OVERDRIVE

---

## Implementation Checklist

- [ ] Update control_surface.gd to 6 systems
- [ ] Update control_surface_manager.gd with new power math
- [ ] Remove unused surface definitions
- [ ] Update control-surfaces.md documentation
- [ ] Update phase-2-systems.md documentation
- [ ] Balance test power scenarios
- [ ] Add heat mechanic to Power Core

---

## References

- [FTL Analysis: Systems and Subsystems](http://www.vigaroe.com/2020/04/ftl-analysis-systems-and-subsystems.html)
- [FTL Wiki: Systems](https://ftl.fandom.com/wiki/Systems)
- [Fewer Options, More Meaningful Choices - Game Developer](https://www.gamedeveloper.com/design/fewer-options-more-meaningful-choices)
- [The Power of Meaningful Choices - Medium](https://medium.com/@doandaniel/gamedev-thoughts-the-power-of-meaningful-choices-in-game-design-50dbdeb0348a)
- [Barotrauma: Better Class Identity Discussion](https://github.com/FakeFishGames/Barotrauma/discussions/4971)
