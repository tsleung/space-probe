# MOT Phase 2: Balance Mathematics

> **Purpose:** Precise mathematical analysis of pressure limits for difficulty tuning.
> **Goal:** Dial difficulty to "barely survivable" - challenging but fair.

## Design Philosophy

**The Pressure Equation:**
```
Difficulty = Demands / Capacity

If Difficulty < 1.0: Too easy (player has slack)
If Difficulty = 1.0: Perfect play = barely survive
If Difficulty > 1.0: Impossible (mathematically unwinnable)

Target: 0.85 - 0.95 for optimal challenge
```

---

## Power Balance System

### Generation Constants

| Source | Output | Notes |
|--------|--------|-------|
| Solar Panels | 5/hr | Passive, always on |
| Power Core NORMAL | 10/hr | Safe, sustainable |
| Power Core OVERDRIVE | 15/hr | +50%, but heat accumulates |
| Emergency Power | +10 | 30 seconds only, 5min cooldown |

**Sustainable Generation:** 15/hr (solar + normal)
**Maximum Generation:** 20/hr (solar + overdrive)
**Burst Generation:** 25/hr (overdrive + emergency, temporary)

### Drain Constants

| System | OFF | Level 1 | Level 2 | Level 3 |
|--------|-----|---------|---------|---------|
| Engine | - | IDLE: 1/hr | CRUISE: 3/hr | BURN: 8/hr |
| Life Support | - | MINIMAL: 2/hr | NORMAL: 4/hr | BOOSTED: 8/hr |
| Shields | 0 | ON: 6/hr | - | - |
| Medical Bay | 0 | ON: 4/hr | - | - |
| Sensors | 0 | ON: 2/hr | - | - |

**Minimum Viable Drain:** 3/hr (Engine IDLE + Life MINIMAL)
**Comfortable Cruise:** 9/hr (Engine CRUISE + Life NORMAL + Sensors ON)
**Maximum Drain:** 28/hr (Everything at max: 8+8+6+4+2)

### Power Pressure Analysis

```
Sustainable Capacity: 15/hr
Maximum Demand: 28/hr
Deficit at Max: -13/hr

IMPOSSIBLE: Running all systems at max levels
```

#### Scenario Analysis

| Scenario | Drain | Generation | Net | Sustainable? |
|----------|-------|------------|-----|--------------|
| **Minimal Survival** | 3/hr | 15/hr | +12/hr | Yes (boring) |
| **Safe Cruise** | 9/hr | 15/hr | +6/hr | Yes |
| **Alert Mode** | 15/hr | 15/hr | 0 | Yes (no buffer) |
| **Combat** | 20/hr | 15/hr | -5/hr | No (battery drain) |
| **Emergency** | 20/hr | 20/hr | 0 | Yes (with overdrive) |
| **Full Panic** | 24/hr | 25/hr | +1/hr | Barely (burst only) |

#### Battery Runway

```
Assume battery capacity: 50 units
At -5/hr deficit: 10 hours until failure
At -10/hr deficit: 5 hours until failure

In real gameplay terms (1 day = ~few seconds):
-5/hr deficit → ~100-200 days of gameplay buffer
```

**Conclusion:** Power pressure is a slow burn, not an immediate crisis. Battery provides substantial runway. The real pressure comes from *combined* power + resource depletion.

### Heat Mechanic Timing

```
Heat accumulation in OVERDRIVE: +2/hr
Heat dissipation in NORMAL: -1/hr

Time to Warning (6.0 heat): 3 hours in OVERDRIVE
Time to Danger (8.0 heat): 4 hours in OVERDRIVE
Time to Critical (10.0 heat): 5 hours in OVERDRIVE
Time to Explosion after Critical: 10 seconds

Cooldown from 10 to 0: 10 hours in NORMAL
```

**Safe OVERDRIVE Cycle:**
```
OVERDRIVE for 2.5 hours → Heat reaches 5.0 (safe)
NORMAL for 5 hours → Heat returns to 0

Effective output: (2.5 × 15 + 5 × 10) / 7.5 = 11.67/hr average
Only 17% better than staying in NORMAL (10/hr)
```

**Aggressive OVERDRIVE Cycle:**
```
OVERDRIVE for 4 hours → Heat reaches 8.0 (danger)
NORMAL for 8 hours → Heat returns to 0

Effective output: (4 × 15 + 8 × 10) / 12 = 11.67/hr average
Same efficiency, but more risk exposure
```

**Conclusion:** OVERDRIVE is a crisis tool, not a sustainable strategy. Use for burst needs.

---

## Crisis Mode Capacity

### Crew Performance Constants

```
Crew count: 4
Walk time: 0.4s per tile
Run time: 0.25s per tile
Pickup time: 0.5s
Work time: 3-5s depending on crisis

Average room distance: 8 tiles
Average cargo fetch distance: 12 tiles
```

### Task Time Analysis

**Station Task (no item needed):**
```
Walk to crisis: 8 tiles × 0.4s = 3.2s
Work on crisis: 4s (average)
Total: 7.2s per fix
```

**Fetch Task (item required):**
```
Walk to cargo: 12 tiles × 0.4s = 4.8s
Pickup item: 0.5s
Walk to crisis: 8 tiles × 0.4s = 3.2s
Work on crisis: 4s
Total: 12.5s per fix
```

**Weighted Average (60% fetch, 40% station):**
```
0.6 × 12.5 + 0.4 × 7.2 = 10.4s per fix
```

### Crew Capacity Calculation

```
4 crew × 60s / 10.4s per fix = 23 fixes per minute (theoretical max)

But account for:
- Travel inefficiency (20%): 23 × 0.8 = 18.4
- Corridor blocking (10%): 18.4 × 0.9 = 16.6
- Suboptimal assignment (10%): 16.6 × 0.9 = 14.9

Realistic crew capacity: ~15 fixes per minute
```

### Crisis Spawn Analysis

**Crisis Lifecycle:**
```
EMERGING: 6s (0.5x drain)
ACTIVE: 8s (1.0x drain)
CRITICAL: 8s (2.0x drain)
CATASTROPHIC: 6s (4.0x drain)
Total lifespan: 28 seconds from spawn to failure
```

**Time to Fix Before Failure:**
```
Need to start work before CATASTROPHIC ends: 28s window
But work takes 3-5s: effective window is 23-25s
```

### The Pressure Equation

```
Crisis Capacity = Crew Fixes per Minute ÷ Crisis Duration

At 15 fixes/min capacity:
- Can handle 15 × (28s/60s) = 7 concurrent crises
- With buffer for travel: ~5-6 concurrent crises safely
```

**Difficulty Levels:**

| Difficulty | Spawn Rate | Active Crises | Capacity Used |
|------------|------------|---------------|---------------|
| **Easy** | 1 per 8s | 3-4 | 50-65% |
| **Normal** | 1 per 5s | 5-6 | 80-95% |
| **Hard** | 1 per 4s | 7-8 | 110-130% (will fail) |
| **Impossible** | 1 per 3s | 9+ | 150%+ |

**Sweet Spot: 1 crisis per 5 seconds = Normal difficulty**

### CRISIS Mode Duration Analysis

```
Standard CRISIS: 45-60 seconds
At 1 per 5s spawn rate: 9-12 crises spawn
Crew can handle: ~11-15 fixes
Margin: 0-3 crises (barely positive)

Cascade CRISIS: 60-90 seconds
At 1 per 4s spawn rate: 15-22 crises spawn
Crew can handle: ~15-22 fixes
Margin: 0 to -7 crises (will lose some)

Storm CRISIS: 90-120 seconds
At 1 per 3s spawn rate: 30-40 crises spawn
Crew can handle: ~22-30 fixes
Margin: -8 to -10 crises (triage required)
```

---

## Resource Depletion Rates

### Base Consumption (per day per crew)

| Resource | Consumption | With 4 Crew |
|----------|-------------|-------------|
| Food | 2 units/day | 8 units/day |
| Water | 1.5 units/day | 6 units/day |
| Oxygen | 1 unit/day | 4 units/day |

### Life Support Production Multipliers

| Level | O2 Production | Water Production |
|-------|---------------|------------------|
| MINIMAL | 0.5x (2/day) | 0.5x (3/day) |
| NORMAL | 1.0x (4/day) | 1.0x (6/day) |
| BOOSTED | 1.5x (6/day) | 1.5x (9/day) |

### Resource Pressure Analysis

**At NORMAL Life Support:**
```
O2: Produces 4/day, Consumes 4/day → Net 0 (stable)
Water: Produces 6/day, Consumes 6/day → Net 0 (stable)
Food: No production → Depletes at 8/day
```

**At MINIMAL Life Support (crisis mode):**
```
O2: Produces 2/day, Consumes 4/day → Net -2/day
Water: Produces 3/day, Consumes 6/day → Net -3/day
```

**Reserve Runway at MINIMAL:**
```
Assume starting reserves: 50 O2, 50 Water
O2 runway: 50 ÷ 2 = 25 days in MINIMAL mode
Water runway: 50 ÷ 3 = 16.7 days in MINIMAL mode
```

**Conclusion:** MINIMAL is sustainable for several weeks of game-days, but not indefinitely.

---

## Combined Pressure Scenarios

### Scenario: Multi-System Failure

```
Situation: Solar flare damages Shields + Sensors

Power Impact:
- Lost 6+2 = 8/hr drain capacity (shields/sensors broken)
- Can't run shields for protection
- No early warning from sensors

Resource Impact:
- Taking full damage from events
- More crew injuries → need Medical ON (+4/hr drain)

Cascade: Less power for life support → resources deplete faster
```

### Scenario: Reactor Overheat During Crisis

```
Situation: CRISIS mode requires OVERDRIVE + high drain

Timeline:
- T+0: Crisis starts, switch to OVERDRIVE
- T+30s: Crisis ends, but forgot to switch back
- T+3hr: Heat warning at 6.0
- T+5hr: Heat critical at 10.0
- T+5hr 10s: EXPLOSION

Consequences:
- Power Core BROKEN (-10-15/hr generation)
- Engine 50% chance BROKEN (-1-8/hr drain, but no thrust!)
- Fire in Engineering (new crisis)

Recovery:
- Power Core repair: 15s
- Engine repair: 10s
- Fire extinguish: 3s + fetch time
```

---

## Difficulty Tuning Guidelines

### Power Balance Tuning

| Desired Pressure | Generation | Drain Target | Buffer |
|-----------------|------------|--------------|--------|
| **Relaxed** | 15/hr | ≤12/hr | +20% |
| **Normal** | 15/hr | 13-15/hr | 0-15% |
| **Tense** | 15/hr | 16-18/hr | -5 to -20% (battery drain) |
| **Crisis** | 20/hr (OD) | 18-22/hr | Requires OVERDRIVE |

### Crisis Mode Tuning

| Desired Pressure | Spawn Interval | Duration | Expected Losses |
|-----------------|----------------|----------|-----------------|
| **Relaxed** | 8s | 45s | 0 |
| **Normal** | 5s | 60s | 0-2 |
| **Tense** | 4s | 75s | 2-4 |
| **Overwhelming** | 3s | 90s | 5-8 (triage mode) |

### Combined Pressure Limits

```
SURVIVABLE (Difficulty ≤ 0.95):
- Power deficit ≤ 5/hr
- Crisis spawn ≥ 5s interval
- ≤ 2 broken systems
- Resources > 20% reserves

BARELY SURVIVABLE (Difficulty = 0.95-1.0):
- Power deficit ≤ 8/hr
- Crisis spawn ≥ 4s interval
- ≤ 3 broken systems
- Resources > 10% reserves

IMPOSSIBLE (Difficulty > 1.0):
- Power deficit > 10/hr with no OVERDRIVE available
- Crisis spawn < 3s interval
- > 4 broken systems
- Reactor CRITICAL with no crew available
```

---

## AI Optimal Play Reference

### Power Management AI

```
Priority order for power cuts:
1. Sensors OFF (2/hr saved) - if no events approaching
2. Medical OFF (4/hr saved) - if no crew injured
3. Shields OFF (6/hr saved) - if no threats
4. Life Support MINIMAL (2/hr saved) - if reserves > 30%
5. Engine IDLE (2/hr saved) - accept slower travel

Never cut:
- Life Support below MINIMAL
- Engine below IDLE
```

### Crisis Mode AI

```
Priority order for crisis assignment:
1. CATASTROPHIC > CRITICAL > ACTIVE > EMERGING
2. Within same severity: closest crew wins
3. Specialist bonus: +20 priority if matched
4. Fetch penalty: -15 priority if item needed

Reassignment threshold:
- Only steal crew if new crisis is 2+ severity levels higher
- Never abandon a crisis in WORKING state
```

### Optimal Resource Management

```
Target reserves:
- O2: 30 days buffer (120 units)
- Water: 25 days buffer (150 units)
- Food: Entire journey worth (1500+ units for 180 days)

Life Support mode switching:
- BOOSTED if reserves < 50%
- NORMAL if reserves 50-80%
- MINIMAL only during power crisis
```

---

## Margin for Error Analysis

> **Key Question:** How many wrong decisions can a player make before failure?

### Power Mistakes Budget

**Starting State:**
```
Battery: 50 units
Sustainable generation: 15/hr
Safe cruise drain: 9/hr
Buffer rate: +6/hr
```

**Mistake: Running shields unnecessarily (6/hr extra)**
```
New drain: 15/hr (shields + cruise)
Net: 0/hr (no buffer, no drain)
Runway: Infinite, but no safety margin

Conclusion: 1 unnecessary system = lose all buffer
```

**Mistake: BURN engine instead of CRUISE (5/hr extra)**
```
With shields + BURN: 20/hr drain
Net: -5/hr
Time to failure: 50 ÷ 5 = 10 hours

In game-days (1 hour ≈ 10 days):
Runway: 100 game-days before battery death
```

**Mistake: Forgot to turn off OVERDRIVE (heat)**
```
Heat builds at 2/hr in OVERDRIVE
Time to critical: 5 hours
Warning time before explosion: 10 seconds

Conclusion: One forgotten switch = potential explosion
But: 5 hours of warning before it matters
```

#### Power Mistake Budget Summary

| Mistake Type | Penalty | Time to Failure | Recoverable? |
|--------------|---------|-----------------|--------------|
| 1 extra system ON | -6/hr buffer | 8+ hours | Yes, easily |
| 2 extra systems ON | -5 to -10/hr | 5-10 hours | Yes |
| Everything on max | -13/hr | 4 hours | Barely |
| Forgot OVERDRIVE | Heat death | 5 hours | Yes if noticed |
| Reactor explosion | Total power loss | Immediate cascade | Maybe |

**Conclusion:** Player can make 2-3 power mistakes simultaneously and still have hours to notice and correct.

---

### Crisis Mode Mistake Budget

**Crew Capacity:** 15 fixes per minute

**Mistake: Wrong crew assignment (20% efficiency loss)**
```
With suboptimal assignments:
Effective capacity: 15 × 0.8 = 12 fixes/min

At Normal spawn rate (1 per 5s):
Expected crises: 12 per minute
Capacity: 12 fixes per minute

Net: 0 margin (will start losing)
```

**Mistake: Crew stuck in wrong room**
```
If 1 crew is mispositioned:
Effective crew: 3 (not 4)
Capacity: 11 fixes/min

At Normal spawn: Will lose 1 crisis per minute
In 60-second CRISIS: Lose 1 system
```

**Mistake: Ignoring EMERGING crises**
```
EMERGING → ACTIVE: 6 seconds
ACTIVE → CRITICAL: 8 seconds
CRITICAL → CATASTROPHIC: 8 seconds
CATASTROPHIC → FAILURE: 6 seconds

If player ignores EMERGING:
Loses 6 seconds of response window
28s total → 22s remaining
Still winnable, but tighter
```

#### Crisis Mistake Budget Summary

| Mistake Type | Impact | Tolerable Count |
|--------------|--------|-----------------|
| Suboptimal crew assignment | -20% efficiency | 2-3 per crisis |
| One crew mispositioned | -25% capacity | 1 per crisis |
| Ignoring EMERGING | -6s window | 3-4 per crisis |
| Ignoring ACTIVE | -14s window | 1-2 per crisis |
| Ignoring until CRITICAL | -22s window | 0 (will fail) |

**Conclusion:** Player can mismanage 2-3 crises per minute and still survive Normal difficulty.

---

### Resource Mistake Budget

**180-Day Journey to Mars**

**Starting Resources (assumed):**
```
Food: 1500 units (enough for 180 days at 8/day)
Water: 180 units (at NORMAL, net 0)
O2: 180 units (at NORMAL, net 0)
```

**Mistake: Running MINIMAL Life Support too long**
```
At MINIMAL:
O2: -2/day
Water: -3/day

If run for 30 days:
O2 lost: 60 units (33% of reserves)
Water lost: 90 units (50% of reserves)

Runway remaining:
O2: 120 ÷ 2 = 60 more days at MINIMAL
Water: 90 ÷ 3 = 30 more days at MINIMAL
```

**Mistake: Lost supplies to hull breach**
```
Event: Asteroid destroys cargo bay
Loses: 20% of all resources

Impact:
Food: 1200 → 960 (covers 120 days, need 180)
Must find 480 food or crew dies

Recovery:
- BOOSTED life support (+50% O2/water)
- Scavenging events
- Reduced crew (grim)
```

#### Resource Mistake Budget Summary

| Mistake Type | Impact | Days of Runway Lost |
|--------------|--------|---------------------|
| 1 day at MINIMAL | -2 O2, -3 water | ~0.5 days |
| 10 days at MINIMAL | -20 O2, -30 water | 5 days |
| Hull breach (20% loss) | All resources | 36 days |
| Crew death | -25% consumption | Negative (helps) |

**Conclusion:** Resources are forgiving over short periods. A single bad event can create 30-50 day deficits that require long-term recovery.

---

### Combined Mistake Tolerance

**Scenario: Cascade of Errors**

```
Mistake 1: Forgot shields OFF after combat (+6/hr drain)
Mistake 2: Life Support at MINIMAL during crisis (-2 O2/day)
Mistake 3: Assigned wrong crew to crises (-20% efficiency)

Combined effect:
- Power: Draining at -6/hr (8+ hours runway)
- Resources: Losing O2 slowly (25+ days runway)
- Crisis: Losing 1-2 crises per minute

Time to notice something is wrong: ~5 minutes
Time to total failure: ~2-3 hours

Verdict: SURVIVABLE if player notices within 10 minutes
```

**Scenario: Perfect Storm (Worst Case)**

```
Event: Solar flare breaks Shields + Sensors
Mistake 1: Panic, turn everything to max
Mistake 2: Forget to cool reactor after crisis
Mistake 3: Ignore CRITICAL heat warning

Combined effect:
- Power: Draining at -13/hr (4 hours to empty)
- Heat: Rising at 2/hr (5 hours to explosion)
- No sensors: Can't see next event coming

Time to failure: 4 hours (power death)
Time to explosion: 5 hours

Verdict: SURVIVABLE if player makes ANY correction within 2 hours
```

---

### Mistake Tolerance Summary Table

| Game Phase | Mistakes Tolerable | Time to Notice | Time to Fail |
|------------|-------------------|----------------|--------------|
| Cruise (no events) | 5-6 | Hours | Days |
| Alert (threats) | 3-4 | Minutes | Hours |
| CRISIS mode | 2-3 | Seconds | 1-2 minutes |
| Multi-crisis | 1-2 | Immediate | 30 seconds |
| Cascade failure | 0-1 | None | 10-15 seconds |

### Design Implications

```
For "barely survivable" difficulty:
- Normal cruise: Player can ignore game for minutes
- Alert mode: Player needs to check every 30-60 seconds
- CRISIS: Player must be fully engaged
- Cascade: Player must be perfect

This creates a natural attention curve:
BORING → CHECKING → ENGAGED → PANICKED
```

### Difficulty Slider Math

| Difficulty | Mistake Budget | AI Win Rate Target |
|------------|----------------|---------------------|
| Story | 10+ mistakes | 99% |
| Easy | 5-6 mistakes | 95% |
| Normal | 3-4 mistakes | 80% |
| Hard | 1-2 mistakes | 50% |
| Brutal | 0 mistakes | 20% |

**Normal difficulty = player can make 3-4 significant mistakes per journey and still complete the mission.**

---

## EVA Event Balance Analysis

EVA events are designed so that **EVA is the dominant strategy**. Non-EVA options have severe consequences that make them clearly inferior.

### ENGINE NOZZLE DEBRIS

| Option | Expected Outcomes | Net Value |
|--------|-------------------|-----------|
| **EVA to clear debris** | 70%: +5 morale, 15%: +8 morale + drift, 15%: -15 health | **+2.5 morale avg** |
| Remote burn (non-EVA) | 25%: -15 fuel, 45%: -20 fuel/-10 morale, 30%: -25 fuel/-15 morale/-10 health | **-20 fuel, -9 morale, -3 health avg** |
| [ENGINEER] Precision EVA | 90%: +10 morale, 10%: drift only | **+9 morale avg** |

**Dominance Margin:** EVA gives +2.5 morale vs non-EVA gives -9 morale = **11.5 morale swing**
Plus non-EVA loses 20 fuel and 3 health on average.

### ANTENNA MISALIGNMENT

| Option | Expected Outcomes | Net Value |
|--------|-------------------|-----------|
| **EVA to realign** | 65%: +8 morale, 20%: drift, 15%: partial | **+5.2 morale avg** |
| Backup antenna (non-EVA) | 20%: -10 morale, 40%: -20 morale, 40%: -30 morale/-5 health | **-22 morale, -2 health avg** |
| [SCIENTIST] Calibrated EVA | 95%: +12 morale, 5%: drift | **+11.4 morale avg** |

**Dominance Margin:** EVA gives +5.2 morale vs non-EVA gives -22 morale = **27.2 morale swing**
Plus non-EVA risks communications blackout.

### SOLAR PANEL DAMAGE

| Option | Expected Outcomes | Net Value |
|--------|-------------------|-----------|
| **EVA to repair** | 60%: +5 power/+5 morale, 20%: +3 power/drift, 20%: +2 power | **+4 power, +3 morale avg** |
| Reroute (non-EVA) | 15%: -8 power, 45%: -15 power/-10 morale, 40%: -20 power/-15 morale | **-16 power, -10.5 morale avg** |
| [ENGINEER] Precision EVA | 85%: +8 power/+8 morale, 15%: +5 power/drift | **+7.55 power, +6.8 morale avg** |

**Dominance Margin:** EVA gives +4 power vs non-EVA gives -16 power = **20 power swing**
Plus non-EVA loses 10.5 morale on average.

### EVA Risk Analysis

EVA has drift risk (15% chance after exterior work):

```
Drift Scenarios:
├── Another crew available (60% of cases)
│   └── Fast rescue (25 px/s) - minimal time loss
└── No rescue available (40% of cases)
    └── Slow self-rescue (8 px/s) - extended tension

Rescue Time Impact:
- Fast rescue: ~4-6 seconds total delay
- Self-rescue: ~12-20 seconds total delay
- Neither causes resource loss directly
```

### EVA Balance Conclusion

**EVA is mathematically dominant because:**

1. **Positive expected value:** EVA options give +2.5 to +11.4 morale/power
2. **Negative expected value for non-EVA:** Non-EVA options give -9 to -22 morale, lose fuel/power
3. **Swing magnitude:** 11-27 point swing between EVA and non-EVA
4. **Drift is recoverable:** 15% drift chance has no permanent cost, just time
5. **Blue EVA options are best:** Specialist bonuses give even better outcomes

**AI Preference:** AI scores EVA +50, blue EVA +60, non-EVA -40. This ensures AI always chooses EVA.

---

## Balance Validation Checklist

Before shipping, verify:

- [ ] Standard CRISIS is winnable with 0-2 failures
- [ ] Cascade CRISIS is winnable with 2-4 failures
- [ ] Storm CRISIS forces triage (5+ failures expected)
- [ ] Power can sustain Alert Mode indefinitely
- [ ] OVERDRIVE is useful but not required for normal play
- [ ] Resources don't deplete faster than player can notice
- [ ] Heat mechanic provides 3+ hours of warning
- [ ] No instant-death scenarios without warning
- [ ] AI can complete journey on Normal difficulty 80% of time
- [ ] EVA options are always dominant over non-EVA alternatives
- [ ] EVA drift risk is recoverable without permanent loss
