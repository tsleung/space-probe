# Balance & Numbers

All the math that makes Space Probe feel right. These numbers are starting points for playtesting - expect iteration.

---

## Design Philosophy

### Target Session Length
- **Phase 1:** 15-25 minutes
- **Phase 2:** 20-30 minutes
- **Phase 3:** 25-35 minutes
- **Phase 4:** 15-25 minutes
- **Total Mission:** 75-115 minutes (~2 hours typical)

### Difficulty Curve
- **Phase 1:** Learning, low pressure, consequences feel distant
- **Phase 2:** Rising tension, consequences become real
- **Phase 3:** Peak complexity, survival + objectives balance
- **Phase 4:** Desperate tension, everything matters

### Resource Tension Targets
At any moment, players should feel:
- At least one resource is "tight" (needs attention)
- No resource is "desperate" (unless something went wrong)
- Trade-offs are available (can sacrifice one thing to save another)

---

## Phase 1: Ship Building

### Starting Budget

| Difficulty | Starting Budget | Contingency Recommended |
|------------|-----------------|------------------------|
| Easy | $800M | $80M (10%) |
| Normal | $650M | $100M (15%) |
| Hard | $500M | $100M (20%) |

### Time Until Launch Window

| Difficulty | Days to Window | Grace Period |
|------------|----------------|--------------|
| Easy | 90 days | 14 days (minor penalty) |
| Normal | 75 days | 7 days (moderate penalty) |
| Hard | 60 days | 3 days (severe penalty) |

### Component Costs

| Component | Base Cost | Build Time | Base Quality | Weight |
|-----------|-----------|------------|--------------|--------|
| **Cockpit** | $50M | 8 days | 55% | 2t |
| **Engine (Traditional)** | $40M | 10 days | 60% | 15t |
| **Engine (Ion/Hermes)** | $120M | 18 days | 50% | 5t |
| **Engine (Hall Thruster)** | $100M | 15 days | 45% | 4t |
| **Engine (Nuclear)** | $200M | 25 days | 40% | 12t |
| **Engine (Solar Sail)** | $80M | 12 days | 55% | 1t |
| **Engine (VASIMR)** | $180M | 20 days | 45% | 6t |
| **Crew Room** (each) | $25M | 5 days | 60% | 3t |
| **Cafeteria** | $30M | 6 days | 65% | 4t |
| **Cargo Bay** (per 10t capacity) | $20M | 4 days | 70% | 2t |
| **Hangar** | $60M | 10 days | 60% | 8t |
| **MAV** | $150M | 15 days | 50% | 10t |
| **Gym** | $20M | 5 days | 70% | 3t |
| **Medical Bay** | $40M | 7 days | 55% | 4t |
| **Laboratory** | $45M | 8 days | 55% | 5t |
| **Observation Deck** | $15M | 4 days | 75% | 2t |
| **Backup Life Support** | $35M | 6 days | 60% | 3t |

### Quality Testing

**Cost per test cycle:**
```
test_cost = base_cost × 0.05 × (1 + current_quality/100)
```

**Quality gain per test:**
```
quality_gain = 8 - (current_quality / 20)

Examples:
- At 50% quality: gain 5.5% per test
- At 70% quality: gain 4.5% per test
- At 90% quality: gain 3.5% per test
```

**Time per test cycle:** 2 days

**Defect discovery chance per test:**
```
defect_chance = (100 - current_quality) × 0.3%

At 60% quality: 12% chance to find defect
At 80% quality: 6% chance to find defect
```

**Defect repair:** +3 days, +$5M, quality gain doubled for this cycle

### Launch Window Penalties

| Days Late | Travel Time Added | Fuel Penalty |
|-----------|-------------------|--------------|
| 0 | 0 days | 0% |
| 1-7 | +3 days each | +2% each |
| 8-14 | +5 days each | +4% each |
| 15-21 | +8 days each | +6% each |
| 22+ | +12 days each | +10% each |

**Example:** 10 days late = 7×3 + 3×5 = 36 extra travel days

### Early Completion (Holding) Risks

| Risk | Probability/Day | Consequence |
|------|-----------------|-------------|
| Component degradation | 1.5% per component | -3% quality |
| Supply spoilage | 1% | -5% cargo capacity |
| Crew illness | 0.5% per crew | -10 health |
| Micrometeorite damage | 0.1% | -5% hull integrity |
| Budget holding costs | 5% | -$2M |

---

## Phase 2: Travel to Mars

### Travel Duration by Engine

| Engine Type | Base Duration | Fuel Efficiency | Adjustable |
|-------------|---------------|-----------------|------------|
| Traditional | 260 days | 1.0x | No |
| Ion/Hermes | 200 days | 2.5x | No |
| Hall Thruster | 170 days | 2.0x | No |
| Nuclear | 150 days | 1.5x | No |
| Solar Sail | 220-300 days | N/A (no fuel) | Yes (solar dependent) |
| VASIMR | 160-240 days | 1.5-3.0x | Yes (player choice) |

### Daily Resource Consumption

| Resource | Per Crew/Day | Total (4 crew) |
|----------|--------------|----------------|
| Food | 2.0 kg | 8.0 kg |
| Water | 3.0 L | 12.0 L |
| Oxygen | 0.84 kg | 3.36 kg |

**With recycling (if systems functional):**
- Water recycling: 90% recovery (net: 1.2 L/day total)
- Oxygen recycling: 85% recovery (net: 0.5 kg/day total)

### Power Budget

| System | Power Draw | Priority |
|--------|------------|----------|
| Life Support | 20 kW | CRITICAL |
| Navigation | 5 kW | CRITICAL |
| Communications | 3 kW | HIGH |
| Lighting | 2 kW | MEDIUM |
| Heating | 8 kW | MEDIUM |
| Medical Bay | 4 kW | LOW |
| Gym | 2 kW | LOW |
| Laboratory | 5 kW | LOW |

**Power generation:**
- Solar panels: 50 kW at 1 AU, decreases with distance
- At Mars distance: ~25 kW
- Battery storage: 200 kWh baseline

### Component Failure Rates

**Daily failure check formula:**
```
failure_chance = base_rate × (100 - quality) / 50 × stress_modifier

Where:
- base_rate = 0.5% (per component per day)
- stress_modifier = 1.0 normally, 2.0 during events, 0.5 if backup exists
```

**Examples:**
| Quality | Daily Failure Chance | Expected Days to Fail |
|---------|---------------------|----------------------|
| 50% | 0.5% | ~200 days |
| 70% | 0.3% | ~333 days |
| 85% | 0.15% | ~667 days |
| 95% | 0.05% | ~2000 days |

### Crew Stat Changes

**Daily baseline changes:**
| Stat | Change/Day | Mitigating Factors |
|------|------------|-------------------|
| Health | -0.5 | Medical Bay: -0.25, Gym: -0.25 |
| Morale | -0.3 | Events, relationships, crew room quality |
| Fatigue | +0.5 (cap 100) | Rest days: -5 |

**Event-based changes (typical ranges):**
| Event Type | Health | Morale | Fatigue |
|------------|--------|--------|---------|
| Positive (quiet moment) | 0 | +10 to +20 | -5 |
| Minor negative | -5 | -5 to -10 | +10 |
| Major negative | -10 to -30 | -15 to -30 | +20 |
| Crisis | -20 to -50 | -20 to -40 | +30 |

### Event Probability

**Base event check:** Once per day

**Event probability:**
```
event_chance = 15% + (stress_modifier × 5%)

Where stress_modifier =
  (average_crew_morale < 50 ? +1 : 0) +
  (any_component < 60% quality ? +1 : 0) +
  (resources < 30 days ? +1 : 0)
```

**Event type distribution:**
| Category | Weight |
|----------|--------|
| Ship events | 30% |
| Crew events | 35% |
| Space events | 20% |
| Quiet moments | 15% (only if morale > 50) |

---

## Phase 3: Mars Base

### Daily Survival Requirements

| Resource | Per Crew/Sol | Total (4 crew) | Source |
|----------|--------------|----------------|--------|
| Food | 2.0 kg | 8.0 kg | Cargo, Greenhouse |
| Water | 3.0 L | 12.0 L | Cargo, Ice extraction |
| Oxygen | 0.84 kg | 3.36 kg | Oxygenator |
| Power | - | 40-60 kW | Solar, Wind |

### Power Generation

| Source | Output | Notes |
|--------|--------|-------|
| Solar panel (each) | 5 kW | Reduced by dust accumulation |
| Wind turbine (each) | 2 kW | Consistent but lower |
| RTG (if brought) | 4 kW | Constant, reduces over mission |
| Battery | 100 kWh storage | Buffer for night/storms |

**Dust accumulation on solar:**
```
efficiency = 100% - (sols_since_cleaning × 0.5%)
Cleaning: 1 crew, 0.5 sol
```

**During dust storms:**
| Storm Severity | Solar Efficiency |
|----------------|------------------|
| Minor | 70% |
| Moderate | 40% |
| Major | 10% |
| Global | 5% |

### Greenhouse Production

```
food_per_sol = base_yield × water_factor × power_factor × crew_factor

Where:
- base_yield = 1.0 kg/sol (per growing module)
- water_factor = min(1.0, water_available / water_needed)
- power_factor = min(1.0, power_available / power_needed)
- crew_factor = 0.8 + (assigned_crew_skill / 500)
```

**Growth cycle:** 30 sols from planting to harvest

### EVA Risk

**Base EVA success rate:** 95%

**Modifiers:**
| Factor | Modifier |
|--------|----------|
| Crew skill > 80 | +3% |
| Crew health < 50 | -5% |
| Dust storm active | -15% |
| Night EVA | -5% |
| Long duration (>4 hours) | -3% |
| Second EVA same sol | -5% |

**EVA failure consequences:**
- 70%: Minor injury (-10 health)
- 25%: Major injury (-30 health, requires medical)
- 5%: Critical (-50 health, possible death)

### Science Experiments

| Experiment | Sols Required | Crew Skill Min | Points |
|------------|---------------|----------------|--------|
| Soil composition | 5 | 40 | 50 |
| Atmospheric analysis | 7 | 50 | 75 |
| Ice core sample | 10 | 60 | 100 |
| Seismic monitoring | 14 (continuous) | 30 | 150 |
| Biological search | 21 | 70 | 300 |
| Deep drilling | 30 | 60 | 250 |

**Experiment quality formula:**
```
final_points = base_points × quality_factor

quality_factor = 0.5 + (crew_skill / 200) + (equipment_quality / 200)
```

### Mission Duration

| Difficulty | Minimum Stay | Optimal Stay | Maximum Stay |
|------------|--------------|--------------|--------------|
| Easy | 60 sols | 90 sols | 150 sols |
| Normal | 90 sols | 120 sols | 180 sols |
| Hard | 120 sols | 150 sols | 200 sols |

**Each sol past optimal:** +0.5 days to return trip

---

## Phase 4: Return Trip

### System Degradation

All components start Phase 4 at their Phase 2 end quality minus accumulated damage.

**Additional degradation rate:**
```
daily_degradation = 0.1% × (1 + (total_journey_days / 300))

For 200-day return after 120-sol stay:
degradation = 0.1% × (1 + 0.73) ≈ 0.17% per day
```

### Resource Scarcity Thresholds

| Resource | Warning Level | Critical Level | Emergency |
|----------|---------------|----------------|-----------|
| Food | 45 days | 30 days | 15 days |
| Water | 30 days | 20 days | 10 days |
| Oxygen | 14 days | 7 days | 3 days |
| Power | 80% gen | 60% gen | 40% gen |

### Rationing Effects

| Rationing Level | Consumption | Health/Day | Morale/Day |
|-----------------|-------------|------------|------------|
| None | 100% | -0.5 | -0.3 |
| Light (80%) | 80% | -1.0 | -0.5 |
| Moderate (60%) | 60% | -2.0 | -1.0 |
| Severe (40%) | 40% | -4.0 | -2.0 |
| Starvation (20%) | 20% | -8.0 | -3.0 |

### Reentry Checks

**Heat shield check:**
```
success_chance = heat_shield_quality × 1.1

If < 50%: catastrophic failure risk
If 50-70%: rough reentry, crew injuries possible
If > 70%: normal reentry
```

**Navigation check:**
```
success_chance = 0.5 + (pilot_skill / 200) + (navigation_quality / 200)

If < 60%: wide miss, emergency procedures
If 60-80%: off-target landing
If > 80%: on-target landing
```

**Parachute check:**
```
success_chance = parachute_quality

If < 40%: failure (fatal unless backup)
If 40-70%: partial deployment, injuries
If > 70%: normal deployment
```

---

## Cross-Phase Systems

### Crew Health

| Health Range | Status | Effects |
|--------------|--------|---------|
| 80-100 | Healthy | Normal operations |
| 60-79 | Minor issues | -10% task efficiency |
| 40-59 | Impaired | -25% efficiency, medical attention needed |
| 20-39 | Critical | Cannot work, requires constant care |
| 1-19 | Dying | Will die without intervention |
| 0 | Dead | - |

**Death threshold:** Health reaches 0

**Natural recovery:** +1 health/day if resting, +2 if in medical bay

### Crew Morale

| Morale Range | Status | Effects |
|--------------|--------|---------|
| 80-100 | Excellent | +10% task efficiency, positive events |
| 60-79 | Good | Normal operations |
| 40-59 | Strained | -10% efficiency, conflict risk |
| 20-39 | Low | -25% efficiency, breakdown risk |
| 1-19 | Critical | May refuse tasks, breakdown likely |

**Morale recovery:**
- Quiet moments: +10 to +20
- Positive events: +5 to +15
- Rest: +2/day
- Reaching milestones: +10 to +25

### Skill Checks

**Formula:**
```
success = random(0, 100) < (crew_skill + modifiers)

Base success ranges:
- Easy task: skill + 30
- Normal task: skill + 0
- Hard task: skill - 20
- Critical task: skill - 40
```

**Skill range:** 20 (rookie) to 100 (expert)

**Skill improvement:**
- Successful task: +1 to relevant skill
- Failed task: +0.5 to relevant skill (learning from failure)
- Training: +5 per training session (Phase 1)

### Relationship System

**Trust range:** 0-100 (starts at 50)

**Trust changes:**
| Action | Change |
|--------|--------|
| Shared positive event | +5 |
| Supported in conflict | +10 |
| Opposed in conflict | -10 |
| Saved from danger | +20 |
| Blamed for failure | -15 |
| Shared quiet moment | +8 |
| Crew death (close relationship) | -20 to survivor morale |

---

## Scoring System

### Victory Tier Thresholds

| Tier | Crew Survival | Science | Budget | Total Score |
|------|---------------|---------|--------|-------------|
| Gold | 4/4 | >80% | <90% used | >8000 |
| Silver | 3/4 | >60% | <100% used | >5000 |
| Bronze | 2/4 | >40% | any | >2500 |
| Pyrrhic | 0/4 | any | any | >1000 |
| Failure | - | - | - | <1000 |

### Score Calculation

```
base_score = 1000

crew_bonus = surviving_crew × 1500
   (max: 6000)

science_bonus = science_points_earned
   (typical range: 500-2000)

efficiency_bonus = (budget_remaining / starting_budget) × 2000
   (max: 2000)

time_bonus = max(0, (optimal_mission_days - actual_days) × 10)
   (can be 0 or positive)

penalty_events = critical_failures × -200

final_score = base_score + crew_bonus + science_bonus + efficiency_bonus + time_bonus + penalty_events
```

**Example (good mission):**
- 4 crew survive: +6000
- 1200 science points: +1200
- 30% budget remaining: +600
- 10 days under optimal: +100
- 2 critical failures: -400
- **Total: 1000 + 6000 + 1200 + 600 + 100 - 400 = 8500 (Gold)**

---

## Difficulty Settings

### What Changes

| Setting | Easy | Normal | Hard |
|---------|------|--------|------|
| Starting budget | $800M | $650M | $500M |
| Days to window | 90 | 75 | 60 |
| Event frequency | 0.7x | 1.0x | 1.3x |
| Failure rates | 0.7x | 1.0x | 1.5x |
| Resource consumption | 0.9x | 1.0x | 1.1x |
| Skill check bonus | +15 | +0 | -10 |
| Starting crew skills | 60-80 | 50-70 | 40-60 |

### What Stays Constant

- Core mechanics and formulas
- Event content and choices
- Score thresholds
- Phase structure
- Crew personalities and arcs

---

## Playtesting Notes

### Red Flags to Watch For

1. **Resource never tight:** Increase consumption or reduce starting supplies
2. **Always runs out:** Reduce consumption or add recovery options
3. **One strategy dominates:** Buff alternatives or nerf dominant
4. **No hard choices:** Increase trade-off stakes
5. **Phase too short:** Add content or slow pace
6. **Phase too long:** Speed up or allow skipping

### Key Metrics to Track

- Average phase completion time
- Resource levels at phase transitions
- Most/least chosen event options
- Failure/success rates by difficulty
- Player-reported "tension points"
- Crew death rates

### Balance Iteration Process

1. Playtest with current numbers
2. Record metrics
3. Identify outliers
4. Adjust by 10-20% (not more)
5. Playtest again
6. Repeat until metrics match targets
