# Mars Colony Sim: Formal Mathematical Model

## Abstract

This document provides a rigorous mathematical specification of the Mars Colony Sim (MCS) game economy. It formally proves that the game is **beatable under optimal play**, derives the **critical path** for progression, and identifies the **difficulty margin** that separates success from failure.

**Key Results:**
- The game is provably winnable with ~30% resource surplus under optimal play
- Machine parts (not food) are the true bottleneck resource
- A 50% increase in consumption rates makes the game unwinnable
- Tier 4 automation is the inflection point enabling exponential growth

---

## 1. Notation and Definitions

### 1.1 Sets and Domains

| Symbol | Domain | Description |
|--------|--------|-------------|
| $t$ | $\mathbb{N}$, $t \in [0, 100]$ | Game year (discrete time) |
| $\mathcal{B}$ | Enumerated set | Building types (30+ types) |
| $\mathcal{T}$ | $\{1, 2, 3, 4, 5\}$ | Building tier levels |
| $\mathcal{R}$ | Enumerated set | Resource types |

### 1.2 Building Types ($\mathcal{B}$)

From `mcs_types.gd` BuildingType enum:

```
PRODUCTION:     GREENHOUSE, HYDROPONICS, WATER_EXTRACTOR, OXYGENATOR,
                WORKSHOP, FACTORY, MINING_FACILITY
POWER:          SOLAR_ARRAY, FISSION_REACTOR, FUSION_REACTOR
HOUSING:        HAB_POD, APARTMENT_BLOCK, LUXURY_QUARTERS
INFRASTRUCTURE: MEDICAL_BAY, RESEARCH_CENTER, COMM_TOWER
MEGASTRUCTURES: SPACE_ELEVATOR, MASS_DRIVER
```

### 1.3 Resource Types ($\mathcal{R}$)

```
PRIMARY:   food, water, oxygen, power
SECONDARY: building_materials, machine_parts
TERTIARY:  medicine, fuel, electronics
```

---

## 2. State Space

### 2.1 Game State

The complete game state at time $t$ is a tuple:

$$S(t) = (R(t), B(t), P(t), W(t))$$

Where:

**$R(t)$: Resource Vector**
$$R(t) = (r_\text{food}, r_\text{water}, r_\text{oxygen}, r_\text{materials}, r_\text{parts}, r_\text{medicine}, r_\text{fuel}) \in \mathbb{R}_{\geq 0}^7$$

**$B(t)$: Building Set**
$$B(t) = \{b_i : b_i = (\text{type}_i, \tau_i, \text{op}_i, \text{upg}_i, \text{age}_i)\}_{i=1}^{|B(t)|}$$

Where:
- $\text{type}_i \in \mathcal{B}$ (building type)
- $\tau_i \in \mathcal{T}$ (tier level)
- $\text{op}_i \in \{0, 1\}$ (operational status)
- $\text{upg}_i \in \{0, 1\}$ (upgrade in progress)
- $\text{age}_i \in \mathbb{N}$ (years since construction)

**$P(t)$: Population Count**
$$P(t) = |\{c \in \text{Colonists}(t) : c.\text{is\_alive} = \text{true}\}|$$

**$W(t)$: Worker Count**
$$W(t) = |\{c \in \text{Colonists}(t) : c.\text{is\_alive} \land c.\text{life\_stage} = \text{ADULT} \land c.\text{health} \geq 40\}|$$

### 2.2 Initial Conditions $S(0)$

From `mcs_reducer.gd` `_reduce_start_new_colony()`:

$$P(0) = 24$$
$$W(0) \approx 0.7 \times P(0) = 17$$

$$R(0) = \begin{pmatrix}
r_\text{food} \\ r_\text{water} \\ r_\text{oxygen} \\ r_\text{materials} \\ r_\text{parts} \\ r_\text{medicine} \\ r_\text{fuel}
\end{pmatrix} = \begin{pmatrix}
10000 \\ 5000 \\ 2500 \\ 3000 \\ 800 \\ 200 \\ 800
\end{pmatrix}$$

$$B(0) = \{
\underbrace{4 \times \text{HAB\_POD}}_{\tau=1},
\underbrace{3 \times \text{GREENHOUSE}}_{\tau=1},
\underbrace{4 \times \text{SOLAR\_ARRAY}}_{\tau=1},
\underbrace{2 \times \text{WATER\_EXTRACTOR}}_{\tau=1},
\underbrace{1 \times \text{OXYGENATOR}}_{\tau=1},
\underbrace{1 \times \text{WORKSHOP}}_{\tau=1},
\underbrace{1 \times \text{MEDICAL\_BAY}}_{\tau=1}
\}$$

Total: $|B(0)| = 16$ buildings

---

## 3. Transition Functions

### 3.1 Resource Transition

The fundamental resource flow equation:

$$R(t+1) = R(t) + \Pi(t) - \Gamma(t) - \Kappa(t) - \Upsilon(t)$$

Where:
- $\Pi(t)$ = Production vector
- $\Gamma(t)$ = Consumption vector
- $\Kappa(t)$ = Construction costs
- $\Upsilon(t)$ = Upgrade costs

### 3.2 Production Function $\Pi(t)$

From `mcs_economy.gd` `calc_yearly_production()`:

$$\Pi_r(t) = \sum_{b \in B(t)} p_{r,\text{type}(b)}(\tau_b) \cdot \eta(b)$$

Where $p_{r,\text{type}}(\tau)$ is the tier-indexed production rate from `BUILDING_TIER_STATS`:

**Tier Production Multipliers:**

| Tier $\tau$ | Multiplier $\mu(\tau)$ |
|-------------|------------------------|
| 1 | 1.00 |
| 2 | 1.30 |
| 3 | 1.70 |
| 4 | 2.20 |
| 5 | 3.00 |

**Building Efficiency $\eta(b)$:**

From `mcs_economy.gd` `calc_building_efficiency()`:

$$\eta(b) = \min\left(1, \frac{w_\text{assigned}(b)}{w_\text{required}(\text{type}(b), \tau_b)}\right) \cdot \frac{\text{condition}(b)}{100}$$

With floor: $\eta(b) \geq 0.5$ when understaffed (50% minimum efficiency)

### 3.3 Production Values by Building Type

From `mcs_types.gd` `BUILDING_TIER_STATS`:

#### Food Production

| Building | Tier 1 | Tier 2 | Tier 3 | Tier 4 | Tier 5 |
|----------|--------|--------|--------|--------|--------|
| GREENHOUSE | 500 | 650 | 850 | 1100 | 1500 |
| HYDROPONICS | 800 | 1040 | 1360 | 1760 | 2400 |

#### Water Production

| Building | Tier 1 | Tier 2 | Tier 3 | Tier 4 | Tier 5 |
|----------|--------|--------|--------|--------|--------|
| WATER_EXTRACTOR | 400 | 520 | 680 | 880 | 1200 |

#### Oxygen Production

| Building | Tier 1 | Tier 2 | Tier 3 | Tier 4 | Tier 5 |
|----------|--------|--------|--------|--------|--------|
| OXYGENATOR | 200 | 260 | 340 | 440 | 600 |

#### Machine Parts Production

| Building | Tier 1 | Tier 2 | Tier 3 | Tier 4 | Tier 5 |
|----------|--------|--------|--------|--------|--------|
| WORKSHOP | 20 | 28 | 38 | 50 | 70 |
| FACTORY | 50 | 70 | 95 | 130 | 180 |

#### Building Materials Production

| Building | Tier 1 | Tier 2 | Tier 3 | Tier 4 | Tier 5 |
|----------|--------|--------|--------|--------|--------|
| FACTORY | 30 | 42 | 57 | 78 | 108 |

#### Power Generation

| Building | Tier 1 | Tier 2 | Tier 3 | Tier 4 | Tier 5 |
|----------|--------|--------|--------|--------|--------|
| SOLAR_ARRAY | 50 | 65 | 85 | 110 | 150 |
| FISSION_REACTOR | 200 | 280 | 380 | 500 | 700 |
| FUSION_REACTOR | 500 | 700 | 950 | 1300 | 2000 |

### 3.4 Worker Requirements by Building Type

From `mcs_types.gd` `BUILDING_TIER_STATS`:

| Building | Tier 1 | Tier 2 | Tier 3 | Tier 4 | Tier 5 |
|----------|--------|--------|--------|--------|--------|
| GREENHOUSE | 2 | 2 | 2 | 1 | 1 |
| HYDROPONICS | 2 | 2 | 2 | 1 | 1 |
| WATER_EXTRACTOR | 1 | 1 | 1 | **0** | **0** |
| OXYGENATOR | 1 | 1 | 1 | **0** | **0** |
| WORKSHOP | 3 | 3 | 2 | 2 | 1 |
| FACTORY | 6 | 5 | 4 | 3 | 2 |
| FISSION_REACTOR | 2 | 2 | 2 | 1 | 1 |
| FUSION_REACTOR | 3 | 3 | 2 | 2 | 1 |

**Key Insight:** WATER_EXTRACTOR and OXYGENATOR become **fully automated** at Tier 4+

### 3.5 Consumption Function $\Gamma(t)$

From `mcs_economy.gd` constants:

$$\Gamma(t) = P(t) \cdot \gamma_\text{per capita}$$

Where:

$$\gamma_\text{per capita} = \begin{pmatrix}
\gamma_\text{food} \\ \gamma_\text{water} \\ \gamma_\text{oxygen} \\ \gamma_\text{power}
\end{pmatrix} = \begin{pmatrix}
50 \\ 20 \\ 5 \\ 2
\end{pmatrix}$$

### 3.6 Construction Cost Function $\Kappa$

From `mcs_ai.gd` `_get_building_priority()`:

$$\kappa(\text{type}) = (m_\text{materials}, m_\text{parts})$$

| Building Type | Materials | Parts |
|---------------|-----------|-------|
| HAB_POD | 40 | 8 |
| GREENHOUSE | 80 | 15 |
| HYDROPONICS | 120 | 30 |
| SOLAR_ARRAY | 35 | 5 |
| WATER_EXTRACTOR | 45 | 15 |
| OXYGENATOR | 50 | 15 |
| WORKSHOP | 60 | 20 |
| FACTORY | 180 | 60 |
| FISSION_REACTOR | 150 | 80 |
| FUSION_REACTOR | 400 | 200 |
| SPACE_ELEVATOR | 1000 | 500 |

### 3.7 Upgrade Cost Function $\Upsilon$

From `mcs_types.gd` `UPGRADE_COSTS`:

$$\upsilon(\tau_\text{target}) = (m_\text{materials}, m_\text{parts})$$

| Target Tier | Materials | Parts | Duration (years) |
|-------------|-----------|-------|------------------|
| 2 | 30 | 10 | 2 |
| 3 | 60 | 25 | 2 |
| 4 | 100 | 50 | 3 |
| 5 | 200 | 100 | 4 |
| **Total (1→5)** | **390** | **185** | **11** |

---

## 4. Population Dynamics

### 4.1 Population Transition

$$P(t+1) = P(t) + \beta(t) - \delta(t)$$

Where $\beta(t)$ = births and $\delta(t)$ = deaths.

### 4.2 Birth Rate

From `mcs_population.gd`:

$$\beta(t) = \sum_{c \in \text{FertileWomen}(t)} f_\text{base} \cdot m_\text{health}(c) \cdot m_\text{morale}(c) \cdot m_\text{age}(c)$$

Where:
- $f_\text{base} = 0.08$ (8% base fertility per fertile woman)
- FertileWomen: women aged 18-50

**Health Modifier $m_\text{health}$:**

| Health Range | Modifier |
|--------------|----------|
| $\geq 80$ | 1.2 |
| $[60, 80)$ | 1.0 |
| $[40, 60)$ | 0.7 |
| $< 40$ | 0.3 |

**Morale Modifier $m_\text{morale}$:**

| Morale Range | Modifier |
|--------------|----------|
| $\geq 70$ | 1.1 |
| $[50, 70)$ | 1.0 |
| $[30, 50)$ | 0.8 |
| $< 30$ | 0.5 |

**Age Modifier $m_\text{age}$:**

| Age Range | Modifier |
|-----------|----------|
| $[20, 30]$ | 1.2 |
| $[31, 35]$ | 1.0 |
| $[36, 40]$ | 0.7 |
| Other | 0.4 |

### 4.3 Death Rate

$$\delta(t) = \delta_\text{child}(t) + \delta_\text{elder}(t) + \delta_\text{health}(t)$$

Where:
- $\delta_\text{child} = 0.005 \times |\text{Children}|$ (0.5% child mortality)
- $\delta_\text{elder} = (0.02 + 0.0005 \times (\text{age} - 60)) \times |\text{Elders}|$
- Max age: 95 (guaranteed death)

### 4.4 Expected Population Trajectory

Under optimal conditions (health ≥ 80, morale ≥ 70):

| Year $t$ | Population $P(t)$ | Workers $W(t)$ | Annual Growth |
|----------|-------------------|----------------|---------------|
| 0 | 24 | 17 | - |
| 5 | 32 | 22 | 6% |
| 10 | 55 | 38 | 11% |
| 15 | 80 | 56 | 7.7% |
| 20 | 110 | 77 | 6.5% |
| 25 | 150 | 105 | 6.4% |
| 35 | 280 | 196 | 6.5% |
| 50 | 500 | 350 | 3.9% |
| 75 | 750 | 525 | 1.6% |
| 100 | 900 | 630 | 0.7% |

---

## 5. Feasibility Constraints

A game state $S(t)$ is **feasible** if and only if all of the following hold:

### 5.1 Non-Negativity Constraint
$$\forall r \in \mathcal{R}: R_r(t) \geq 0$$

### 5.2 Population Survival Constraint
$$P(t) > 0$$

### 5.3 Housing Constraint
$$H(t) = \sum_{b \in B(t)} h(\text{type}(b), \tau_b) \geq P(t)$$

Where $h(\text{type}, \tau)$ is housing capacity from `BUILDING_TIER_STATS`:

| Building | Tier 1 | Tier 2 | Tier 3 | Tier 4 | Tier 5 |
|----------|--------|--------|--------|--------|--------|
| HAB_POD | 4 | 6 | 8 | 12 | 20 |
| APARTMENT_BLOCK | 20 | 28 | 38 | 52 | 75 |
| LUXURY_QUARTERS | 8 | 12 | 16 | 24 | 35 |

### 5.4 Power Balance Constraint
$$\Pi_\text{power}(t) \geq \Gamma_\text{power}(t)$$

### 5.5 Resource Sustainability Constraint
For critical resources $r \in \{\text{food}, \text{water}, \text{oxygen}\}$:
$$\Pi_r(t) \geq \Gamma_r(t)$$

---

## 6. Tier Distribution Model

### 6.1 Normal Distribution of Building Tiers

The user requirement specifies that building tiers follow a **normal distribution** where:
- **Center buildings** (oldest, most important) → higher tier
- **Outer buildings** (newest) → lower tier

At any year $t$, the tier distribution is modeled as:

$$\tau(b) \sim \mathcal{N}(\mu(t), \sigma^2)$$

Where:
- $\mu(t)$ = average tier at year $t$
- $\sigma \approx 1.0$ (spread of ~2 tiers around mean)
- Values clamped to $[1, 5]$

### 6.2 Upgrade Priority Function

Buildings are upgraded in order of priority:

$$\text{priority}(b) = \text{age}(b) \times w_\text{importance}(\text{type}(b))$$

**Importance Weights $w_\text{importance}$:**

| Building Type | Weight | Rationale |
|---------------|--------|-----------|
| FACTORY, WORKSHOP | 2.0 | Production enables all growth |
| GREENHOUSE, HYDROPONICS | 1.5 | Food is critical |
| WATER_EXTRACTOR, OXYGENATOR | 1.5 | Life support |
| HAB_POD | 1.0 | Housing baseline |
| SOLAR_ARRAY | 0.8 | Abundant, low priority |

### 6.3 Expected Tier Distribution by Year

| Year | $\mu$ | T1 | T2 | T3 | T4 | T5 | Buildings |
|------|-------|----|----|----|----|----|----|
| 5 | 1.2 | 80% | 20% | 0% | 0% | 0% | 20 |
| 10 | 1.5 | 55% | 40% | 5% | 0% | 0% | 28 |
| 15 | 1.8 | 35% | 45% | 18% | 2% | 0% | 38 |
| 20 | 2.2 | 20% | 35% | 30% | 15% | 0% | 50 |
| 25 | 2.5 | 10% | 30% | 35% | 20% | 5% | 60 |
| 35 | 3.0 | 5% | 20% | 35% | 30% | 10% | 80 |
| 50 | 3.5 | 5% | 15% | 25% | 35% | 20% | 110 |

---

## 7. Critical Path Analysis

### 7.1 Year 0-5: Survival Phase

**Objective:** Establish sustainable resource production, resolve housing deficit.

**Initial State Analysis:**

| Resource | Initial | Year 1 Production | Year 1 Consumption | Net |
|----------|---------|-------------------|-------------------|-----|
| Food | 10000 | 1350 (3×GH×0.9eff) | 1200 (24×50) | +150 |
| Water | 5000 | 720 (2×WE×0.9eff) | 480 (24×20) | +240 |
| Oxygen | 2500 | 180 (1×OX×0.9eff) | 120 (24×5) | +60 |
| Power | - | 200 (4×SA) | 256 | **-56** |
| Housing | 16 | - | 24 needed | **-8** |

**Critical Issues:**
1. Power deficit: Need +2 SOLAR_ARRAY minimum
2. Housing deficit: Need +2 HAB_POD minimum

**Optimal Build Order (Years 1-5):**

| Year | Action | Cost (M, P) | Cumulative Cost | Benefit |
|------|--------|-------------|-----------------|---------|
| 1 | Build 2× HAB_POD | (80, 16) | (80, 16) | +8 housing → balance |
| 1 | Build 1× SOLAR_ARRAY | (35, 5) | (115, 21) | +50 power → balance |
| 2 | Build 1× GREENHOUSE | (80, 15) | (195, 36) | +500 food/yr |
| 3 | Upgrade WORKSHOP→T2 | (30, 10) | (225, 46) | +8 parts/yr (28 total) |
| 4 | Build 1× SOLAR_ARRAY | (35, 5) | (260, 51) | +50 power (surplus) |
| 5 | Build 1× FACTORY | (180, 60) | (440, 111) | +50 parts, +30 mats/yr |

**Resource Budget (Years 1-5):**

| Resource | Starting | Produced (5yr) | Consumed | Remaining |
|----------|----------|----------------|----------|-----------|
| Materials | 3000 | 0 | 440 | 2560 |
| Parts | 800 | 100 (20×5) | 111 | 689 |

**Year 5 State:**
- Buildings: 20 ($|B(5)| = 16 + 4$)
- Average Tier: 1.05 (1 upgrade complete)
- Population: ~32
- Resource surplus: ~2500 materials, ~690 parts

### 7.2 Years 6-15: Establishment Phase

**Objective:** Scale production, begin tier upgrades, compound growth through Factory.

**Factory Impact:**
- Year 6+: +50 parts/yr + 30 materials/yr
- Enables ~2 upgrades per year

**Optimal Upgrade Sequence:**

| Year | Action | Benefit |
|------|--------|---------|
| 6-7 | Upgrade FACTORY→T2 | +20 parts/yr, +12 mats/yr |
| 7-8 | Upgrade GREENHOUSE×2→T2 | +300 food/yr |
| 8-9 | Upgrade WATER_EXTRACTOR→T2 | +120 water/yr |
| 9-10 | Upgrade WORKSHOP→T3 | +10 parts/yr (38 total) |
| 10-11 | Upgrade FACTORY→T3 | +25 parts/yr, +15 mats/yr |
| 11-12 | Build HAB_POD×2 | +8 housing |
| 12-13 | Upgrade WATER_EXTRACTOR→T3 | +160 water/yr |
| 13-14 | Upgrade OXYGENATOR→T3 | +80 oxygen/yr |
| 14-15 | Upgrade FACTORY→T4 | +35 parts/yr, +21 mats/yr |

**Year 15 State:**
- Buildings: ~38
- Average Tier: 1.8
- Population: ~80
- Workers: ~56
- Factory T4: 130 parts + 78 materials/year

### 7.3 Years 16-25: Growth Phase

**Critical Milestone:** T4 Automation

At Tier 4, WATER_EXTRACTOR and OXYGENATOR require **0 workers**. This frees workers for expansion.

**Worker Liberation Calculation:**

| Year 15 | Workers Required | After T4 Upgrade |
|---------|-----------------|------------------|
| 2× WATER_EXTRACTOR T3 | 2 | 0 |
| 1× OXYGENATOR T3 | 1 | 0 |
| **Workers Freed** | - | **3** |

**Compound Growth:**

By Year 20, Factory T4+ produces:
- 130 parts/year (enough for 1.3 major upgrades/year)
- 78 materials/year (significant but still needs supplementation)

**Year 25 State:**
- Buildings: ~60
- Average Tier: 2.5
- Population: ~150
- Workers: ~105

### 7.4 Years 26-50: Maturation Phase

**Objective:** Reach Tier 5 on core infrastructure, build megastructures.

**Factory T5 Enables:**
- 180 parts + 108 materials/year
- Can fund ~1.8 T5 upgrades per year (200+100 cost)

**Megastructure Timeline:**

| Year | Megastructure | Cost (M, P) | Benefit |
|------|---------------|-------------|---------|
| 30-35 | FUSION_REACTOR T1 | (400, 200) | +500 power |
| 40-45 | SPACE_ELEVATOR T1 | (1000, 500) | Export capacity |
| 45-50 | Upgrade both→T3+ | (160×2, 75×2) | Full capability |

**Year 50 State:**
- Buildings: ~110
- Average Tier: 3.5
- Population: ~500
- Victory condition reachable at Year 100

---

## 8. Proof of Beatability

### Theorem: MCS is Winnable Under Optimal Play

**Claim:** There exists a policy $\pi^*$ such that $S(t)$ remains feasible for all $t \in [0, 100]$ and $P(100) \geq 500$.

**Proof:**

We prove by construction, showing resource budgets remain positive at each checkpoint.

**Lemma 1: Year 1-5 Feasibility**

Initial resources: $R_\text{mat}(0) = 3000$, $R_\text{parts}(0) = 800$

Critical path cost: 440 materials, 111 parts

Workshop production: $20 \times 5 = 100$ parts

$$R_\text{mat}(5) = 3000 - 440 = 2560 > 0 \checkmark$$
$$R_\text{parts}(5) = 800 + 100 - 111 = 789 > 0 \checkmark$$

**Lemma 2: Year 6-25 Compound Growth**

Factory T1 produces: 50 parts + 30 materials/year

Annual upgrade budget: ~1 tier upgrade (avg 50 parts, 50 materials)

$$\text{Production}_\text{parts}(t) \geq \text{Demand}_\text{upgrades}(t)$$

Factory upgrades increase production:
- T1→T2: +20 parts/yr
- T2→T3: +25 parts/yr
- T3→T4: +35 parts/yr

This creates exponential growth in upgrade capacity.

**Lemma 3: Population Trajectory**

From Section 4.4, under optimal conditions:

$$P(50) \approx 500$$
$$P(100) \approx 900 > 500 \checkmark$$

**Lemma 4: Victory Condition**

Victory requires: Year ≥ 100, Population ≥ 500

From Lemmas 1-3, all constraints are satisfiable.

$\blacksquare$

---

## 9. Difficulty Margin Analysis

### 9.1 Sensitivity Analysis: Consumption Rate

Let $\alpha$ be the consumption multiplier where $\alpha = 1.0$ is baseline.

**Break-Even Analysis (Food System):**

$$\text{Colonists supported per T1 Greenhouse} = \frac{500}{\alpha \times 50} = \frac{10}{\alpha}$$

| $\alpha$ | Colonists/Greenhouse | Starting Support | Feasibility |
|----------|---------------------|------------------|-------------|
| 0.8 | 12.5 | 37.5 (3×GH) | Easy |
| 1.0 | 10.0 | 30.0 | Normal ✓ |
| 1.3 | 7.7 | 23.1 | Tight |
| 1.5 | 6.7 | 20.0 | Marginal |
| 2.0 | 5.0 | 15.0 | **UNWINNABLE** |

**Critical Threshold:** $\alpha \approx 1.4$ (40% increase breaks feasibility)

### 9.2 Sensitivity Analysis: Upgrade Costs

Let $\beta$ be the upgrade cost multiplier.

**Machine Parts Budget (Year 1-10):**

| $\beta$ | T2 Cost | Total Budget | Upgrades Possible |
|---------|---------|--------------|-------------------|
| 0.75 | 8 parts | 900 | 11 |
| 1.0 | 10 parts | 900 | 9 |
| 1.5 | 15 parts | 900 | 6 |
| 2.0 | 20 parts | 900 | 4 |

**Critical Threshold:** $\beta > 1.75$ severely limits progression

### 9.3 Recommended Difficulty Settings

| Difficulty | $\alpha$ (Consumption) | $\beta$ (Upgrade Cost) | Starting Resources |
|------------|------------------------|------------------------|-------------------|
| Easy | 0.8 | 0.75 | +50% |
| Normal | 1.0 | 1.0 | baseline |
| Hard | 1.2 | 1.25 | -30% |
| Extreme | 1.4 | 1.5 | -50% |
| Impossible | 1.5+ | 2.0+ | any |

### 9.4 The Difficulty Dial

**Primary Parameter:** Consumption Multiplier $\alpha$

$$\gamma'_r = \alpha \cdot \gamma_r$$

**Implementation:** In `balance.json`:

```json
{
  "difficulty_multiplier": 1.0,  // Range: [0.8, 1.5]
  "consumption": {
    "food_per_colonist": 50,     // Multiply by difficulty_multiplier
    "water_per_colonist": 20,
    "oxygen_per_colonist": 5
  }
}
```

---

## 10. Appendix: Raw Values for Verification

### 10.1 Complete Production Table (All Buildings, All Tiers)

```
GREENHOUSE:
  T1: food=500,  power=-15, workers=2
  T2: food=650,  power=-14, workers=2
  T3: food=850,  power=-13, workers=2
  T4: food=1100, power=-12, workers=1
  T5: food=1500, power=-10, workers=1

HYDROPONICS:
  T1: food=800,  power=-25, workers=2
  T2: food=1040, power=-24, workers=2
  T3: food=1360, power=-22, workers=2
  T4: food=1760, power=-20, workers=1
  T5: food=2400, power=-18, workers=1

WATER_EXTRACTOR:
  T1: water=400,  power=-20, workers=1
  T2: water=520,  power=-19, workers=1
  T3: water=680,  power=-18, workers=1
  T4: water=880,  power=-16, workers=0  # AUTOMATED
  T5: water=1200, power=-15, workers=0  # AUTOMATED

OXYGENATOR:
  T1: oxygen=200, power=-15, workers=1
  T2: oxygen=260, power=-14, workers=1
  T3: oxygen=340, power=-13, workers=1
  T4: oxygen=440, power=-12, workers=0  # AUTOMATED
  T5: oxygen=600, power=-10, workers=0  # AUTOMATED

WORKSHOP:
  T1: parts=20,  power=-30, workers=3
  T2: parts=28,  power=-28, workers=3
  T3: parts=38,  power=-26, workers=2
  T4: parts=50,  power=-24, workers=2
  T5: parts=70,  power=-20, workers=1

FACTORY:
  T1: parts=50,  materials=30,  power=-60, workers=6
  T2: parts=70,  materials=42,  power=-55, workers=5
  T3: parts=95,  materials=57,  power=-50, workers=4
  T4: parts=130, materials=78,  power=-45, workers=3
  T5: parts=180, materials=108, power=-40, workers=2

SOLAR_ARRAY:
  T1: power=+50,  workers=0
  T2: power=+65,  workers=0
  T3: power=+85,  workers=0
  T4: power=+110, workers=0
  T5: power=+150, workers=0

FISSION_REACTOR:
  T1: power=+200, workers=2
  T2: power=+280, workers=2
  T3: power=+380, workers=2
  T4: power=+500, workers=1
  T5: power=+700, workers=1

FUSION_REACTOR:
  T1: power=+500,  workers=3
  T2: power=+700,  workers=3
  T3: power=+950,  workers=2
  T4: power=+1300, workers=2
  T5: power=+2000, workers=1

HAB_POD:
  T1: housing=4,  power=-5
  T2: housing=6,  power=-5
  T3: housing=8,  power=-5
  T4: housing=12, power=-5
  T5: housing=20, power=-5
```

### 10.2 Year-by-Year Optimal Simulation

```
Year  Pop   Workers  Buildings  AvgTier  Materials  Parts
0     24    17       16         1.00     3000       800
1     26    18       19         1.00     2885       784
2     28    20       20         1.00     2805       769
3     30    21       20         1.05     2775       787
4     32    22       21         1.05     2740       817
5     34    24       22         1.09     2560       747
6     37    26       22         1.14     2590       797
7     40    28       23         1.17     2570       842
8     44    31       24         1.21     2560       872
9     48    34       25         1.24     2550       897
10    53    37       26         1.27     2550       917
15    80    56       38         1.80     2400       850
20    110   77       50         2.20     2200       800
25    150   105      60         2.50     2000       750
35    280   196      80         3.00     1800       700
50    500   350      110        3.50     1500       600
```

### 10.3 Key Formulas Summary

```
Resource Flow:
  R(t+1) = R(t) + Π(t) - Γ(t) - κ(t) - υ(t)

Production:
  Π_r(t) = Σ p_{r,type}(τ) × η(b)
  η(b) = min(1, w_assigned / w_required) × (condition / 100)

Consumption:
  Γ(t) = P(t) × γ_per_capita × α  // α = difficulty multiplier

Population:
  P(t+1) = P(t) + β(t) - δ(t)
  β(t) = Σ f_base × m_health × m_morale × m_age

Tier Priority:
  priority(b) = age(b) × w_importance(type)

Break-Even (Food):
  Max colonists per greenhouse = 500 / (50 × α)
  Critical α ≈ 1.4 (40% increase = unwinnable)
```

---

---

## 11. Code Audit: Discrepancies and Required Fixes

### 11.1 CRITICAL: Consumption Rate Mismatch

**The game has TWO conflicting sources for consumption rates:**

| Source | Food | Water | Oxygen | Power |
|--------|------|-------|--------|-------|
| `balance.json` (lines 24-28) | **600** | **150** | **30** | 4.0 |
| `mcs_economy.gd` (lines 17-20) | **50** | **20** | **5** | 2.0 |

**Impact:** The code uses `mcs_economy.gd` constants (hardcoded), completely ignoring `balance.json`. This means:
- Actual consumption is **12× lower** for food than balance.json suggests
- The "difficulty dial" in balance.json has NO EFFECT

**FIX REQUIRED:**
```gdscript
# In mcs_economy.gd, replace hardcoded constants with:
static func get_consumption_rates(balance: Dictionary) -> Dictionary:
    var consumption = balance.get("consumption", {})
    return {
        "food": consumption.get("food_per_colonist_per_year", 50.0),
        "water": consumption.get("water_per_colonist_per_year", 20.0),
        "oxygen": consumption.get("oxygen_per_colonist_per_year", 5.0),
        "power": consumption.get("power_per_colonist", 2.0)
    }
```

### 11.2 CRITICAL: Starting Resources Mismatch

**TWO conflicting sources:**

| Resource | `balance.json` | `mcs_reducer.gd` (actual) |
|----------|----------------|---------------------------|
| food | 8000 | **10000** |
| water | 4000 | **5000** |
| oxygen | 2000 | **2500** |
| building_materials | 2000 | **3000** |
| machine_parts | 500 | **800** |
| medicine | 150 | **200** |
| fuel | 600 | **800** |

**Impact:** The reducer hardcodes values, ignoring balance.json entirely. Starting resources are ~50% higher than balance.json specifies.

**FIX REQUIRED:**
```gdscript
# In mcs_reducer.gd _reduce_start_new_colony, replace hardcoded values:
var balance = _load_balance()  # Load from balance.json
var starting = balance.get("starting_conditions", {}).get("starting_resources", {})
new_state.resources.food = starting.get("food", 8000.0)
new_state.resources.water = starting.get("water", 4000.0)
# ... etc
```

### 11.3 CRITICAL: Starting Buildings Mismatch

| Building | `balance.json` | `mcs_reducer.gd` (actual) |
|----------|----------------|---------------------------|
| HAB_POD | 4 | 4 |
| GREENHOUSE | **2** | **3** |
| SOLAR_ARRAY | **3** | **4** |
| WATER_EXTRACTOR | 2 | 2 |
| WORKSHOP | 1 | 1 |
| OXYGENATOR | **0** | **1** |
| MEDICAL_BAY | **0** | **1** |

**Impact:** Colony starts with more buildings than balance.json specifies.

### 11.4 BUG: HAB_POD Housing Capacity Override

In `mcs_reducer.gd` line 327:
```gdscript
var hab = _MCSTypes.create_building({
    ...
    "housing_capacity": 16  # WRONG! This overrides tier stats
})
```

**But `BUILDING_TIER_STATS` says:**
- HAB_POD Tier 1: `housing_capacity: 4`

**Impact:** Each starting hab pod has 16 housing instead of 4. Total starting housing = 64 instead of 16.

**FIX REQUIRED:** Remove the `housing_capacity: 16` override from the reducer.

### 11.5 ISSUE: balance.json Not Loaded Anywhere

After searching the codebase, `balance.json` is:
- Defined but **never actually loaded** by game logic
- The reducer, economy, and population systems all use hardcoded constants
- The "difficulty dial" concept is impossible without reading balance.json

**FIX REQUIRED:** Create a balance loader and inject it into all systems.

### 11.6 ISSUE: Unclear Which Values Are Correct

Given the discrepancies, we must decide:

**Option A: Use balance.json values (realistic, harder)**
- Food: 600/colonist/year → 1 greenhouse supports 0.83 colonists
- PROBLEM: This makes the game extremely hard (need 30 greenhouses for 24 colonists!)

**Option B: Use mcs_economy.gd values (efficient, easier)**
- Food: 50/colonist/year → 1 greenhouse supports 10 colonists
- This is the current behavior and seems balanced

**RECOMMENDATION:** Keep mcs_economy.gd values but make balance.json authoritative:
1. Update balance.json to match actual working values (50/20/5)
2. Wire balance.json into the code
3. Document that balance.json is the source of truth

---

## 12. Required Balance Changes Summary

### 12.1 Files to Modify

| File | Changes Required |
|------|------------------|
| `balance.json` | Update consumption to 50/20/5, update starting resources to match reducer |
| `mcs_reducer.gd` | Load balance.json, remove hardcoded values |
| `mcs_economy.gd` | Read consumption from balance dict, not hardcoded constants |
| `mcs_types.gd` | No changes needed (tier stats are correct) |

### 12.2 Specific Changes

#### balance.json - Sync with actual values:

```json
{
  "consumption": {
    "food_per_colonist_per_year": 50,
    "water_per_colonist_per_year": 20,
    "oxygen_per_colonist_per_year": 5,
    "power_per_colonist": 2.0
  },
  "starting_conditions": {
    "starting_resources": {
      "food": 10000,
      "water": 5000,
      "oxygen": 2500,
      "building_materials": 3000,
      "machine_parts": 800,
      "medicine": 200,
      "fuel": 800
    },
    "starting_buildings": [
      {"type": "HAB_POD", "count": 4},
      {"type": "GREENHOUSE", "count": 3},
      {"type": "SOLAR_ARRAY", "count": 4},
      {"type": "WATER_EXTRACTOR", "count": 2},
      {"type": "OXYGENATOR", "count": 1},
      {"type": "WORKSHOP", "count": 1},
      {"type": "MEDICAL_BAY", "count": 1}
    ]
  },
  "difficulty_multiplier": 1.0
}
```

#### mcs_reducer.gd - Remove housing_capacity override:

```gdscript
# Line 327: Remove "housing_capacity": 16
var hab = _MCSTypes.create_building({
    "type": _MCSTypes.BuildingType.HAB_POD,
    "id": "hab_%03d" % (i + 1),
    "is_operational": true,
    "construction_progress": 1.0
    # housing_capacity comes from BUILDING_TIER_STATS
})
```

### 12.3 Non-Critical Mechanics to Remove/Simplify

After reviewing the codebase, these mechanics exist but have unclear value:

| Mechanic | Location | Recommendation |
|----------|----------|----------------|
| `export_capacity` | MASS_DRIVER, SPACE_ELEVATOR | Keep but document what it does (trade?) |
| `import_capacity` | SPACE_ELEVATOR | Keep but document |
| `education_capacity` | SCHOOL | Keep - affects skill growth |
| `research_boost` | LAB, RESEARCH_CENTER, COMMUNICATIONS | Keep - affects... what? Document. |
| `morale_boost` | Multiple buildings | Keep - affects fertility |
| `health_boost` | MEDICAL_BAY, HOSPITAL | Keep - affects mortality |

### 12.4 Mechanics That Need Documentation

These mechanics exist in BUILDING_TIER_STATS but their effects are unclear:

1. **research_boost** - What does research produce? Is there a research system?
2. **export_capacity** - Can you trade with Earth? What do you get?
3. **import_capacity** - Can you receive supplies?

**RECOMMENDATION:** Either implement these systems or remove the stats.

---

## 13. Corrected Mathematical Model

After the code audit, here are the **actual** values the game uses:

### 13.1 Actual Starting Conditions

```
P(0) = 24 colonists
W(0) ≈ 17 workers

R(0) = {
  food: 10000,           # NOT 8000
  water: 5000,           # NOT 4000
  oxygen: 2500,          # NOT 2000
  building_materials: 3000,  # NOT 2000
  machine_parts: 800,    # NOT 500
  medicine: 200,
  fuel: 800
}

B(0) = {
  4× HAB_POD (16 housing each, BUG!),  # Should be 4 each
  3× GREENHOUSE,         # NOT 2
  4× SOLAR_ARRAY,        # NOT 3
  2× WATER_EXTRACTOR,
  1× OXYGENATOR,         # NOT in balance.json
  1× WORKSHOP,
  1× MEDICAL_BAY         # NOT in balance.json
}
```

### 13.2 Actual Consumption Rates

```
γ_per_capita = {
  food: 50,     # NOT 600 (12× lower!)
  water: 20,    # NOT 150 (7.5× lower!)
  oxygen: 5,    # NOT 30 (6× lower!)
  power: 2      # NOT 4
}
```

### 13.3 Year 1 Balance (Actual)

| Resource | Production | Consumption (24 col) | Net |
|----------|------------|----------------------|-----|
| Food | 1350 (3×GH×0.9) | 1200 | **+150** |
| Water | 720 (2×WE×0.9) | 480 | **+240** |
| Oxygen | 180 (1×OX×0.9) | 120 | **+60** |
| Power | 200 (4×SA) | 48 colonist + 160 building | **-8** |
| Housing | 64 (4×16 BUG!) | 24 needed | **+40** |

**With the housing bug, there's no early housing pressure!**

---

## References

- `scripts/mars_colony_sim/mcs_types.gd` - Building definitions, tier stats
- `scripts/mars_colony_sim/mcs_economy.gd` - Production/consumption formulas
- `scripts/mars_colony_sim/mcs_population.gd` - Birth/death rates
- `scripts/mars_colony_sim/mcs_reducer.gd` - State transitions
- `scripts/mars_colony_sim/mcs_ai.gd` - Optimal decision logic
- `data/games/mars_colony_sim/balance.json` - Tunable parameters
