# MCS (Mars Colony Sim): Core Game Loop

**The One-Sentence Pitch:** *Every year brings a crisis, a choice, and a consequence that echoes through generations.*

---

## The Fundamental Loop

### The "One More Year" Engine

The game is structured around **Year Cycles**. Each year is a complete unit of gameplay that takes 3-5 minutes in early game, 5-10 minutes in late game. The loop creates compulsive "just one more year" engagement.

```
┌─────────────────────────────────────────────────────────┐
│                    YEAR START                           │
│   • State of Colony Summary                             │
│   • Major Events/Anniversaries                          │
│   • Resource Projections                                │
└───────────────────────┬─────────────────────────────────┘
                        ▼
┌─────────────────────────────────────────────────────────┐
│                    PLANNING PHASE                       │
│   • Allocate workforce (drag & drop)                    │
│   • Queue construction projects                         │
│   • Set policies (sliders)                              │
│   • Review requests from colonists                      │
└───────────────────────┬─────────────────────────────────┘
                        ▼
┌─────────────────────────────────────────────────────────┐
│                    EXECUTION PHASE                      │
│   • Watch the year play out (accelerated time)          │
│   • Events interrupt for decisions                      │
│   • Mini-crises require quick choices                   │
│   • Quiet moments build character attachment            │
└───────────────────────┬─────────────────────────────────┘
                        ▼
┌─────────────────────────────────────────────────────────┐
│                    YEAR END                             │
│   • Report card: What happened                          │
│   • Births, Deaths, Milestones                          │
│   • Resource changes (+/-  clear feedback)              │
│   • Preview next year's challenges                      │
└───────────────────────┬─────────────────────────────────┘
                        │
                        ▼
                 [NEXT YEAR]
```

---

## The Three Tensions

Every great strategy game has core tensions. Colony Sim has three:

### 1. SURVIVAL vs GROWTH
**The Question:** Do you secure what you have, or reach for more?

- **Survival Play:** Stockpile food, overbuild life support, cautious expansion
  - Pro: Weather crises easily
  - Con: Population stagnates, fall behind on development

- **Growth Play:** Push expansion, take risks, ambitious projects
  - Pro: Bigger colony = more capability
  - Con: Vulnerable to crises, stretched thin

**Mechanical Expression:**
- Resources can be CONSUMED (survival) or INVESTED (growth)
- Every resource has a "safety stockpile" threshold
- Going below triggers warnings and morale penalties
- But staying above 200% is "hoarding" - also has penalties (waste, political criticism)

### 2. PRESENT vs FUTURE
**The Question:** Help the living or build for the unborn?

- **Present Focus:** Good housing, recreation, healthcare NOW
  - Pro: High morale, productive workers, political stability
  - Con: Infrastructure ages, no capacity for future population

- **Future Focus:** Education, research, infrastructure investment
  - Pro: Next generation is better equipped, colony grows
  - Con: Current colonists suffer, potential unrest

**Mechanical Expression:**
- Every resource allocation is split: CONSUMPTION vs INVESTMENT
- Education quality affects future skill levels
- Infrastructure has maintenance costs AND replacement costs
- "Founders' Dilemma": Early sacrifice enables late prosperity

### 3. UNITY vs DIVERSITY
**The Question:** One colony, one vision? Or let factions flourish?

- **Unity Play:** Strong central authority, unified culture, suppress dissent
  - Pro: Efficient decisions, coordinated response to crises
  - Con: Resentment builds, no innovation from diversity

- **Diversity Play:** Allow factions, debate, multiple approaches
  - Pro: More ideas, higher morale for autonomy, resilience
  - Con: Slower decisions, risk of paralysis or conflict

**Mechanical Expression:**
- Political system has AUTHORITY slider (1-10)
- High authority = fast decisions, lower morale, risk of coup
- Low authority = slow decisions, higher morale, risk of gridlock
- Events force you to pick sides or attempt compromise

---

## Core Actions: The Verb Set

What does the player DO each year?

### ALLOCATE (Primary Action)
**Drag & drop workers to jobs**

Simple, tactile, satisfying. You see colonists as icons, drag them to facilities.

```
┌─────────────────────────────────────────────────────────┐
│  WORKFORCE ALLOCATION                    Year 23        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  AVAILABLE WORKERS: 47 ████████████████████            │
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ FOOD         │  │ POWER        │  │ CONSTRUCTION │  │
│  │ ████░░░░░░   │  │ ██████░░░░   │  │ ████░░░░░░   │  │
│  │ 12/20 (60%)  │  │ 8/10 (80%)   │  │ 10/25 (40%)  │  │
│  │ OUTPUT: 85%  │  │ OUTPUT: GOOD │  │ PROGRESS: 2/5│  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │ RESEARCH     │  │ HEALTHCARE   │  │ EDUCATION    │  │
│  │ ██░░░░░░░░   │  │ ████░░░░░░   │  │ ██░░░░░░░░   │  │
│  │ 4/15 (27%)   │  │ 6/8 (75%)    │  │ 5/12 (42%)   │  │
│  │ OUTPUT: SLOW │  │ QUALITY: OK  │  │ QUALITY: LOW │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│                                                         │
│  [AUTO-ASSIGN]  [OPTIMIZE]  [SAVE PRESET]  [CONFIRM]   │
└─────────────────────────────────────────────────────────┘
```

**Why This Is Fun:**
- Immediate feedback (bars fill, stats change)
- Meaningful trade-offs (can't fully staff everything)
- Skill expression (learning optimal ratios)
- Character attachment (you recognize individual colonists)

### BUILD (Secondary Action)
**Queue construction projects**

Not city-builder complexity. Simple choices with clear outcomes.

```
┌─────────────────────────────────────────────────────────┐
│  CONSTRUCTION QUEUE                                     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ACTIVE PROJECT: Greenhouse Expansion                   │
│  ████████████████░░░░ 80% complete (1 year remaining)   │
│  Workers: 10  │  Materials: 500/600  │  Power: 50 kW    │
│                                                         │
│  QUEUE:                                                 │
│  1. [Housing Block B] - 2 years - 20 capacity          │
│  2. [Medical Upgrade] - 1 year - +25% healthcare       │
│                                                         │
│  AVAILABLE PROJECTS:                                    │
│  ┌────────────────────────────────────────────────────┐ │
│  │ [Solar Farm Expansion] 🌟 RECOMMENDED              │ │
│  │ +30% power │ 2 years │ 15 workers │ 800 materials  │ │
│  │ "Power shortage predicted in 3 years"              │ │
│  └────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────┐ │
│  │ [Recreation Center]                                │ │
│  │ +15% morale │ 1 year │ 8 workers │ 300 materials   │ │
│  │ "Colonists requesting leisure facilities"          │ │
│  └────────────────────────────────────────────────────┘ │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Why This Is Fun:**
- Clear cause-and-effect ("build this, get that")
- Long-term planning (queue management)
- Reactive building (respond to events/requests)
- Visible progress (watch construction complete)

### DECIDE (Core Action)
**Make choices when events occur**

This is the heart of the game. Events present dilemmas. Choices have consequences.

```
┌─────────────────────────────────────────────────────────┐
│  ⚠️ EVENT: WATER SHORTAGE IMMINENT                      │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  The water extraction system is running at 60%         │
│  efficiency. At current consumption, reserves will      │
│  be depleted in 8 months.                              │
│                                                         │
│  Chief Engineer Rodriguez recommends immediate          │
│  rationing. Councilor Martinez argues we should         │
│  accelerate the new extraction facility instead.        │
│                                                         │
│  ┌────────────────────────────────────────────────────┐ │
│  │ A) IMPLEMENT RATIONING                             │ │
│  │    -15% colony morale │ Water consumption -30%     │ │
│  │    Rodriguez: "Prudent" │ Martinez: "Defeatist"    │ │
│  └────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────┐ │
│  │ B) RUSH NEW EXTRACTION FACILITY                    │ │
│  │    -500 materials │ Construction crew reassigned   │ │
│  │    Risky: 70% success │ Failure = crisis           │ │
│  └────────────────────────────────────────────────────┘ │
│  ┌────────────────────────────────────────────────────┐ │
│  │ C) DO BOTH (COMPROMISE)                            │ │
│  │    Mild rationing (-8% morale) + expedited build   │ │
│  │    Neither faction fully satisfied                 │ │
│  └────────────────────────────────────────────────────┘ │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Why This Is Fun:**
- Real dilemmas (no obvious correct answer)
- Character involvement (named NPCs with opinions)
- Visible consequences (see results next year)
- Memory (callbacks to past decisions)

### MANAGE (Background Action)
**Adjust policies via sliders**

Set-and-forget systems that create the backdrop.

```
┌─────────────────────────────────────────────────────────┐
│  COLONY POLICIES                                        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  FOOD RATIONING                                         │
│  Austere ○───────●───────○ Generous                    │
│  Currently: STANDARD (100% rations)                     │
│  Effect: Morale neutral, consumption normal             │
│                                                         │
│  WORK HOURS                                             │
│  Minimal ○───●───────────○ Maximum                     │
│  Currently: MODERATE (45 hrs/week)                      │
│  Effect: +10% productivity, -5% morale                  │
│                                                         │
│  IMMIGRATION POLICY                                     │
│  Closed ○───────────●───○ Open                         │
│  Currently: SELECTIVE                                   │
│  Effect: +8 colonists/year (skilled only)               │
│                                                         │
│  EARTH RELATIONS                                        │
│  Independent ○───────●───○ Dependent                   │
│  Currently: PARTNERSHIP                                 │
│  Effect: Moderate trade, shared research                │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## The Emotional Engine

### Why Players Care

The game must create **attachment** before it creates **stakes**.

#### Attachment Builders (Early Game)
1. **Naming Ceremonies:** Player names the first Mars-born child
2. **Quiet Moments:** Small scenes that humanize colonists
3. **Achievement Celebrations:** First greenhouse harvest, first wedding
4. **Personality Emergence:** Colonists develop distinct traits over time
5. **Relationship Web:** See families and friendships form

#### Stakes Creators (Mid-to-Late Game)
1. **Death of Known Characters:** People you've invested in can die
2. **Generational Succession:** The founders' children take over
3. **Legacy Threats:** Your early decisions come back to haunt
4. **Independence Question:** Do you stay connected to Earth?
5. **Crisis Convergence:** Multiple problems at once

### The "Story Factory" System

The game generates memorable narratives through system interactions:

**Example Emergent Story:**

> **Year 12:** Elena Rodriguez is born to Chief Engineer Maria Rodriguez.
>
> **Year 18:** Elena shows aptitude for engineering. You assign her to apprentice with her aging mother.
>
> **Year 23:** Maria dies. Elena takes over as Chief Engineer, youngest ever.
>
> **Year 24:** Major equipment failure. Elena is untested. Do you trust her?
> - **Option A:** Let Elena lead. Risky but builds her confidence.
> - **Option B:** Bring in an Earth consultant. Safer but undermines her.
>
> **Year 25 (if A):** Elena succeeds. She becomes a colony legend.
> **Year 25 (if B):** Elena resents you. She joins the independence faction.
>
> **Year 40:** Elena is elected Council Chair. Her relationship with you shapes the independence vote.

The player didn't plan this story. The systems created it.

---

## Pacing: The Rhythm of Play

### The Year Structure

```
YEAR START (30 seconds)
├── Year Summary (auto-displays key info)
├── Anniversary/Milestone check
└── "This Year Preview" (upcoming challenges)

PLANNING (1-2 minutes)
├── Workforce allocation
├── Construction review
├── Policy adjustments (if needed)
└── Pending decisions queue

EXECUTION (1-3 minutes)
├── Time accelerates through the year
├── Events interrupt when they occur
├── Player watches production, construction
└── Mini-events (quick decisions)

YEAR END (30 seconds)
├── Summary screen (what happened)
├── Demographics update (births, deaths)
├── Resource delta (clear +/- feedback)
└── Achievements unlocked
└── Tease next year ("Next year: supply ship arrives")
```

### Event Frequency

**Target: 2-4 meaningful events per year**

Too few = boring. Too many = exhausting.

```
Year Event Budget:
- 1 MAJOR event (dilemma requiring thought)
- 1-2 MINOR events (quick decisions)
- 0-1 QUIET moment (character building, no decision)
- 0-1 CRISIS (if bad luck/poor planning)

Event Cooldowns:
- Same event type: 3 year minimum
- Same character focus: 2 year minimum
- Major crisis: 5 year minimum
```

### Speed Controls

Player controls game speed:

| Speed | Time per Year | Use Case |
|-------|---------------|----------|
| Pause | Infinite | Reading, planning |
| Slow | 3-5 minutes | Learning, enjoying narrative |
| Normal | 2-3 minutes | Standard play |
| Fast | 1-2 minutes | Experienced players |
| Ultra | 30-60 seconds | Late game, skipping |

**Auto-Pause Triggers:**
- Major event appears
- Crisis begins
- Milestone reached
- Resource hits critical
- Character death

---

## Feedback Loops

### Positive Feedback (Snowball Success)

```
High morale → Better productivity → More resources
     ↓                                    ↓
More leisure facilities ← Budget surplus ←
```

**Danger:** Runaway success is boring. Introduce complications.

**Balancing Mechanisms:**
- Growth increases maintenance costs
- Success attracts more immigration (integration challenges)
- Political factions emerge when there's surplus to argue about
- Complacency events ("Nothing to struggle for")

### Negative Feedback (Death Spiral Prevention)

```
Crisis → Morale drop → Productivity drop → Worse crisis
```

**Danger:** Unrecoverable spirals feel unfair.

**Catch-Up Mechanisms:**
- Emergency Earth aid (costs independence points)
- "Rally together" morale events during crisis
- Reduced event frequency when struggling
- "Desperate measures" options (high risk, high reward)
- Clear early warnings before death spirals lock in

---

## Numbers That Feel Good

### The "3-5-10" Rule

- **3:** Number of major resources to track at once
- **5:** Number of significant decisions per play session
- **10:** Number of colonists you should "know by name"

### Visible Progress Targets

```
Year 5:   Population 15-25,  First Milestone (survival secured)
Year 10:  Population 40-60,  First Mars-born adults
Year 20:  Population 80-150, Self-sufficiency possible
Year 50:  Population 250-500, Independence question
Year 100: Population 500-1500, Victory possible
```

### Resource Sweet Spots

**Food:**
- Critical: <30 days reserve
- Warning: 30-60 days reserve
- Comfortable: 60-120 days reserve
- Excess: >120 days reserve (waste/hoarding)

**Power:**
- Critical: <70% demand met
- Warning: 70-90% demand met
- Comfortable: 90-110% demand met
- Excess: >130% capacity (mothball or expand)

**Population Capacity:**
- Critical: >110% housing capacity (overcrowding)
- Warning: >95% (need to build soon)
- Comfortable: 70-90% (room to grow)
- Excess: <50% (wasted infrastructure)

---

## Player Psychology

### The Slot Machine of Meaning

Each year has:
- **Known elements:** Your allocations, construction progress
- **Random elements:** Events, outcomes of risky choices
- **Emergent elements:** Character interactions, story beats

This creates anticipation: "What will happen this year?"

### Loss Aversion vs Growth Desire

Players feel losses more than gains. Design accordingly:

**Deaths:** Rare but impactful. Build attachment first.
**Setbacks:** Common but recoverable. Learning opportunities.
**Failures:** Possible but preventable with good play.

### The "Almost Lost It" Thrill

The best moments are near-disasters that you survive:
- Dust storm that almost killed the greenhouse... but you had reserves
- Political crisis that almost became civil war... but you mediated
- Epidemic that almost wiped out the colony... but Dr. Chen found the cure

Design systems to create these moments, not just pure victory or pure defeat.

---

## Testing Checklist

### Core Loop Validation

- [ ] Can complete a year in under 5 minutes?
- [ ] Does every year have at least one meaningful decision?
- [ ] Do players say "one more year" when they should stop?
- [ ] Can you name 5+ colonists after 30 minutes of play?
- [ ] Do players tell stories about their colonies?

### Tension Validation

- [ ] Survival vs Growth: Both viable strategies?
- [ ] Present vs Future: No obviously correct balance?
- [ ] Unity vs Diversity: Trade-offs clear?
- [ ] Are there moments of "I don't know what to do"?
- [ ] Are there moments of "That worked perfectly"?

### Pacing Validation

- [ ] Events feel meaningful, not spam?
- [ ] Quiet periods exist between crises?
- [ ] Speed controls feel right at all levels?
- [ ] Year-end summary is satisfying?
- [ ] Players know what to do next?

### Emotional Validation

- [ ] Do players care about colonist deaths?
- [ ] Are quiet moments appreciated or skipped?
- [ ] Does the founding crew feel special?
- [ ] Does independence feel earned?
- [ ] Do players want to replay?

---

## The GOTY Test

### Signs You've Succeeded

1. **Forum Stories:** Players posting "Let me tell you about my colony..."
2. **Named Attachments:** "My Chen bloodline has been engineers for 60 years"
3. **Difficult Choices Remembered:** "I still feel bad about the rationing decision"
4. **Replayability:** "This run I'm going full independence from the start"
5. **Emotional Resonance:** "When Commander Chen died, I actually felt sad"

### The Ultimate Validation

A player finishes a 100-year campaign. They scroll through the timeline.
They see the story they created—not the story you wrote.

They think: "I built that. Those were my people. That was my civilization."

And then they hit "New Game."

---

## Quick Reference: The Loop

```
1. YEAR START
   → See summary, understand situation

2. PLAN
   → Allocate workers (drag & drop)
   → Queue construction (simple choices)
   → Adjust policies (if needed)

3. EXECUTE
   → Watch year unfold
   → Respond to events (2-4 per year)
   → Make meaningful choices

4. YEAR END
   → See results
   → Feel progress (or consequences)
   → Get excited for next year

5. REPEAT (100 times)
   → Watch civilization emerge
   → Create stories
   → Win (or lose spectacularly)
```

**Total time per year:** 3-5 minutes
**Total time per campaign:** 5-10 hours
**Replayability:** High (different choices = different stories)
**Emotional investment:** Extreme (these are YOUR people)
