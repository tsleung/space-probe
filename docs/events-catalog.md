# Events Catalog

This document contains all events for the core game experience. Events are the primary way players interact with the narrative and make meaningful decisions.

---

## Event Design Principles

### The Oregon Trail Rule
Every event should offer **choices**, not just outcomes. The player should feel agency even when bad things happen.

### Consequence Clarity
Players should understand the trade-offs before choosing. Hidden consequences feel unfair; clear trade-offs feel strategic.

### No "Right" Answers
The best events have choices where reasonable players disagree. If one choice is obviously correct, the event needs redesign.

### Callbacks Welcome
Events can reference earlier events or decisions. "Remember when you skipped that test cycle? Well..."

### Tone Consistency
Events should match the phase mood:
- Phase 1: Professional, planning-focused
- Phase 2: Tension, uncertainty, isolation
- Phase 3: Discovery, survival, hope
- Phase 4: Exhaustion, desperation, homecoming

---

## Event Format

```
EVENT: [event_id]

TITLE: [Display title]

TRIGGER:
- Phase: [which phase]
- Conditions: [when this can fire]
- Probability: [chance per day/check]

DESCRIPTION:
[What the player sees]

CHOICES:
A) [Choice text]
   → [Consequences]

B) [Choice text]
   → [Consequences]

C) [Choice text] (if applicable)
   → [Consequences]

FOLLOW-UP: [event_id] (if this triggers another event)
```

---

## Phase 1: Ship Building Events

### Budget Events

---

**EVENT: congressional_review**

TITLE: Congressional Budget Review

TRIGGER:
- Phase: 1
- Day: 15-45
- Probability: 25% once per game

DESCRIPTION:
Senator Williams has called for a review of the Mars program spending. The committee wants answers about cost overruns in similar programs.

CHOICES:
A) Present detailed justification (costs 2 days)
   → Budget protected, +5% bonus funding if successful
   → Skill check: Leadership. Failure = -10% budget anyway

B) Accept a 10% budget cut to avoid scrutiny
   → Immediate -10% budget
   → No time lost, no risk

C) Invite media coverage of the review
   → High risk/reward: 50% chance of +15% budget (public support), 50% chance of -15% (scandal)

---

**EVENT: contractor_delay**

TITLE: Contractor Supply Delay

TRIGGER:
- Phase: 1
- After ordering any component
- Probability: 15% per component

DESCRIPTION:
[Component name] delivery has been delayed. The contractor cites supply chain issues. They offer options.

CHOICES:
A) Wait for original order (+5 days)
   → No extra cost, delays construction

B) Pay rush fee (-$2M, no delay)
   → Immediate cost, stays on schedule

C) Source from alternate supplier (-$1M, -10% starting quality)
   → Cheaper rush, but lower initial quality

---

**EVENT: tech_breakthrough**

TITLE: Technology Breakthrough

TRIGGER:
- Phase: 1
- Day: 20+
- Probability: 10% once per game

DESCRIPTION:
Engineers at JPL have made a breakthrough in [random system: life support/propulsion/power]. The new technology is available for integration.

CHOICES:
A) Integrate new tech (+3 days, +15% quality to affected component)
   → Better component, costs time

B) Document for future missions (no effect this mission)
   → No benefit now, narrative satisfaction

C) Sell research data to private sector (+$3M)
   → Cash now, ethical question

---

**EVENT: budget_surplus**

TITLE: End-of-Quarter Surplus

TRIGGER:
- Phase: 1
- Day: 30-50
- Budget remaining > 40%
- Probability: 20% once per game

DESCRIPTION:
NASA accounting found unused funds that must be allocated before end of quarter. You have 48 hours to spend an additional $5M or lose it.

CHOICES:
A) Extra testing across all components
   → +5% quality to all components

B) Crew training bonus
   → +10 to all crew skill ratings

C) Contingency reserve
   → Money held for Phase 2-3 emergencies

---

### Construction Events

---

**EVENT: construction_accident**

TITLE: Construction Bay Accident

TRIGGER:
- Phase: 1
- During component construction
- Probability: 5% per component

DESCRIPTION:
An accident in the construction bay. A support beam failed during [component] installation. No serious injuries, but there's damage.

CHOICES:
A) Full inspection and repair (+4 days, -$1M)
   → Component quality unaffected, thorough approach

B) Patch and continue (+1 day, -$0.5M)
   → Component starts at -15% quality

C) Replace component entirely (+7 days, full component cost again)
   → Fresh start, significant delay

---

**EVENT: quality_discovery**

TITLE: Quality Issue Discovered

TRIGGER:
- Phase: 1
- After testing any component
- Probability: 20% per test cycle

DESCRIPTION:
Testing revealed a manufacturing defect in [component]. The issue affects reliability but can be addressed.

CHOICES:
A) Full remediation (+3 days, -$1.5M)
   → Issue fully resolved, quality restored

B) Documented workaround (+1 day)
   → Quality capped at 85% for this component
   → Crew will need to monitor during mission

C) Accept risk
   → No time/cost, but -20% quality permanently

---

**EVENT: crew_training_incident**

TITLE: Training Simulation Failure

TRIGGER:
- Phase: 1
- Day: 10+
- Probability: 15% once per game

DESCRIPTION:
During an EVA simulation, [crew member] made a critical error that would have been fatal in real conditions. They're shaken but uninjured.

CHOICES:
A) Additional training for entire crew (+5 days, -$1M)
   → All crew +5 skill, affected crew member faces their weakness

B) Additional training for affected crew member only (+2 days)
   → That crew member +10 skill, others unchanged

C) Debrief and move on
   → Crew member -10 morale, but saves time
   → Creates "training_gap" flag for potential Phase 2 event

---

**EVENT: component_exceeds_specs**

TITLE: Exceeds Specifications

TRIGGER:
- Phase: 1
- After testing any component to 80%+ quality
- Probability: 10% per qualifying test

DESCRIPTION:
Testing shows [component] is performing above specifications. The manufacturing team did exceptional work.

EFFECT: (No choice - positive event)
- Component quality +10% (can exceed 100%, capped at 105%)
- Team morale boost

---

### Countdown Events

---

**EVENT: solar_storm_warning**

TITLE: Solar Storm Forecast

TRIGGER:
- Phase: 1
- Days remaining: 10-30
- Probability: 20% once per game

DESCRIPTION:
Space weather forecasters predict elevated solar activity during your planned launch window. The storm could delay launch or damage equipment in transit.

CHOICES:
A) Accelerate launch to beat the storm (if possible)
   → Must launch within 5 days or miss window
   → Skip remaining tests on incomplete components

B) Delay launch until after storm
   → +14 days to travel time
   → All components can complete testing

C) Launch on schedule with enhanced shielding (-$3M)
   → +10% to hull integrity
   → Risk: 30% chance of component damage during Phase 2 transit

---

**EVENT: launch_window_optimal**

TITLE: Exceptional Launch Window

TRIGGER:
- Phase: 1
- Days remaining: 5-15
- Probability: 10% once per game

DESCRIPTION:
Orbital mechanics have aligned favorably. A brief window in the next 3 days would reduce travel time significantly.

CHOICES:
A) Seize the window (must launch within 3 days)
   → -21 days travel time
   → Whatever isn't ready, isn't ready

B) Stick to planned window
   → No change, but know you passed up efficiency

---

**EVENT: crew_family_emergency**

TITLE: Family Emergency

TRIGGER:
- Phase: 1
- Day: 20+
- Probability: 10% once per game

DESCRIPTION:
[Crew member]'s family member has been hospitalized with a serious illness. They're asking if they can delay departure or be replaced.

CHOICES:
A) Grant leave, replace crew member
   → Replacement crew member has -20% skill
   → Original crew member removed from mission

B) Deny request, maintain crew
   → Crew member -30 morale
   → Potential relationship damage with other crew

C) Delay launch by 2 weeks for family time
   → Crew member morale restored
   → +14 days to timeline

---

**EVENT: media_coverage**

TITLE: Documentary Crew Request

TRIGGER:
- Phase: 1
- Day: 30+
- Probability: 15% once per game

DESCRIPTION:
A major streaming service wants to embed a documentary team with your mission. They'd film everything, including setbacks.

CHOICES:
A) Accept full access
   → +$5M budget
   → All events become "public" - consequences for failures amplified
   → Potential morale boost from fame

B) Accept limited access (construction only)
   → +$2M budget
   → Phase 1 events public, Phases 2-4 private

C) Decline
   → No budget bonus
   → Complete privacy

---

## Phase 2: Travel to Mars Events

### Ship Events

---

**EVENT: component_malfunction**

TITLE: [Component] Malfunction

TRIGGER:
- Phase: 2
- Any day
- Probability: Based on component quality (see Balance doc)

DESCRIPTION:
Warning lights indicate [component] is malfunctioning. Diagnostics suggest [issue based on component type].

CHOICES:
A) Full diagnostic and repair (Engineer task, 1 day)
   → Component restored to current quality - 5%
   → Engineer unavailable for other tasks

B) Quick fix (Engineer task, 4 hours)
   → Component at 50% effectiveness until proper repair
   → Risk: 20% chance of secondary failure

C) Reroute through backup systems (if backup installed)
   → Backup takes over, original offline
   → Backup quality now determines reliability

---

**EVENT: power_fluctuation**

TITLE: Power Grid Instability

TRIGGER:
- Phase: 2
- Day: 30+
- Probability: 15% once per game

DESCRIPTION:
The power grid is showing fluctuations. Solar panel efficiency has dropped, and the battery system is working harder than expected.

CHOICES:
A) Reduce power consumption (crew discomfort)
   → -10 morale to all crew
   → Power stabilized

B) EVA to inspect solar panels (risk)
   → Skill check: Engineering
   → Success: Power restored to full
   → Failure: Crew injury + power at 80%

C) Accept reduced power budget
   → Some systems must be rationed
   → Player chooses what to reduce

---

**EVENT: hull_micrometeorite**

TITLE: Micrometeorite Impact

TRIGGER:
- Phase: 2
- Any day
- Probability: 2% per day

DESCRIPTION:
A small impact detected on the hull. Sensors show minor damage but no breach... yet.

CHOICES:
A) Immediate EVA repair
   → Hull fully repaired
   → EVA risk: 5% chance of crew injury

B) Internal patch (temporary)
   → Hull integrity -10% permanently
   → No EVA risk

C) Monitor and assess
   → 70% nothing happens
   → 30% escalates to EVENT: hull_breach

---

**EVENT: hull_breach**

TITLE: Hull Breach

TRIGGER:
- Phase: 2
- Follows EVENT: hull_micrometeorite if monitoring fails
- Or independent: 1% per day if hull integrity < 70%

DESCRIPTION:
EMERGENCY. Hull breach in [section]. Air is venting. Crew has minutes to respond.

CHOICES:
A) Emergency seal (crew in section seals from inside)
   → Section sealed, crew member trapped until EVA repair
   → Crew member: -20 health, -30 morale

B) Evacuate and seal (crew exits, seal remotely)
   → Section sealed and depressurized
   → Cargo/equipment in section lost
   → No crew injury

C) Attempt repair under pressure (heroic)
   → Skill check: Engineering (difficult)
   → Success: Minimal damage
   → Failure: Crew injury, section lost anyway

---

### Crew Events

---

**EVENT: space_sickness**

TITLE: Space Adaptation Syndrome

TRIGGER:
- Phase: 2
- Day: 1-14
- Probability: 30% per crew member (once each)

DESCRIPTION:
[Crew member] is experiencing severe space sickness. Nausea, disorientation, inability to work.

CHOICES:
A) Bed rest and medication (Medical task, 3 days)
   → Full recovery
   → Crew member unavailable during recovery

B) Push through with medication only
   → -20 health, returns to duty immediately
   → Risk: 25% chance of complication requiring medical attention

C) Assign light duties only
   → Crew member at 50% effectiveness for 7 days
   → Natural recovery

---

**EVENT: crew_conflict**

TITLE: Crew Disagreement

TRIGGER:
- Phase: 2
- Day: 30+
- Probability: 20% once per game (higher if morale low)

DESCRIPTION:
[Crew member A] and [Crew member B] are in a heated disagreement about [resource allocation/task priority/personal space]. The tension is affecting the whole crew.

CHOICES:
A) Mediate directly (Commander intervention)
   → Skill check: Leadership
   → Success: Conflict resolved, relationships stable
   → Failure: Both crew members -15 morale, commander -10 respect

B) Let them work it out
   → 50% natural resolution (minor morale hit)
   → 50% escalation (major morale hit, ongoing tension)

C) Separate them (reassign duties)
   → Conflict suppressed
   → Efficiency reduced (they worked well together before)

---

**EVENT: crew_illness**

TITLE: Medical Emergency

TRIGGER:
- Phase: 2
- Day: 20+
- Probability: 10% per crew member (reduced by Medical Bay quality)

DESCRIPTION:
[Crew member] has developed [appendicitis/kidney stones/infection]. Without treatment, their condition will worsen.

CHOICES:
A) Medical intervention (Medical Officer task, uses supplies)
   → -1 medical supply unit
   → Skill check: Medical
   → Success: Full recovery after 5 days rest
   → Failure: Partial recovery, -20 max health permanently

B) Conservative treatment (rest and monitoring)
   → No supply cost
   → Crew member at 30% capacity for 14 days
   → Risk: 20% chance of emergency requiring option A anyway

---

**EVENT: morale_celebration**

TITLE: Milestone Celebration

TRIGGER:
- Phase: 2
- Day: 90 (halfway point)
- Automatic

DESCRIPTION:
The crew has reached the halfway point. Despite everything, they've made it this far. Someone suggests a small celebration.

CHOICES:
A) Full celebration (use some luxury rations)
   → -5 food units
   → All crew +20 morale
   → "Halfway" memory created

B) Brief acknowledgment
   → All crew +5 morale
   → No resource cost

C) Focus on the mission
   → No morale change
   → "Commander is all business" perception

---

### Space Events

---

**EVENT: solar_flare**

TITLE: Solar Particle Event

TRIGGER:
- Phase: 2
- Any day
- Probability: 5% per week

DESCRIPTION:
Warning: Coronal mass ejection detected. High-energy particles will reach the ship in [4-8] hours. Radiation levels will spike dangerously.

CHOICES:
A) Full shelter protocol (everyone to shielded areas)
   → 12 hours lost productivity
   → No health impact

B) Rotate shelter (maintain some operations)
   → 6 hours lost productivity
   → All crew: -5 health (minor radiation exposure)

C) Emergency shielding boost (uses power reserves)
   → Normal operations continue
   → Power reserves depleted by 30%
   → If power reserves < 30%, not available

---

**EVENT: communication_blackout**

TITLE: Communication Loss

TRIGGER:
- Phase: 2
- Day: 60+
- Probability: 10% once per game

DESCRIPTION:
Solar interference has disrupted communications with Earth. You're on your own for the next [7-14] days.

EFFECT: (No choice - situation event)
- No Earth contact for duration
- All crew: -5 morale
- Any events during blackout have no "consult Earth" option

---

**EVENT: earth_message**

TITLE: Message from Home

TRIGGER:
- Phase: 2
- Any day
- Probability: 10% per week

DESCRIPTION:
A batch of personal messages has arrived from Earth. The crew gathers to watch.

EFFECT: (No choice - positive event)
- All crew: +10 morale
- Specific crew may get +15 if family content is positive

VARIANT (5% chance):
- One crew member receives bad news
- That crew member: -20 morale
- Others: +5 morale (relief their news was good)

---

**EVENT: asteroid_proximity**

TITLE: Asteroid Proximity Alert

TRIGGER:
- Phase: 2
- Day: 50+
- Probability: 5% once per game

DESCRIPTION:
Tracking shows a small asteroid will pass within 500km of your trajectory. No collision risk, but it's close enough to study... or avoid more aggressively.

CHOICES:
A) Adjust course for wider margin (-fuel)
   → Uses 5% fuel reserve
   → Complete safety

B) Maintain course, take measurements
   → Science bonus for Phase 3
   → Very small (1%) chance of debris damage

C) Adjust course for closer observation
   → Major science bonus
   → 10% chance of debris damage

---

### Quiet Moments

---

**EVENT: quiet_stargazing**

TITLE: Night Watch

TRIGGER:
- Phase: 2
- Crew morale average > 50
- Probability: Once per game

DESCRIPTION:
You find [crew member] alone at the observation window during night cycle. Earth is visible as a bright star.

CHOICES:
A) "Can't sleep either?"
   → Opens conversation about their fears/hopes
   → Relationship building, learn crew backstory

B) "Beautiful, isn't it?"
   → Shared moment of wonder
   → Both characters: +5 morale

C) [Return to duties]
   → No interaction
   → Crew member noted you were there

---

**EVENT: quiet_birthday**

TITLE: Birthday in Space

TRIGGER:
- Phase: 2
- Specific day (set at game start based on crew)
- Automatic

DESCRIPTION:
Today is [crew member]'s birthday. They haven't mentioned it, but the crew manifest shows the date.

CHOICES:
A) Surprise celebration
   → Uses luxury rations
   → Birthday crew: +25 morale
   → All others: +10 morale

B) Quiet acknowledgment
   → Birthday crew: +10 morale
   → "Commander remembered" positive note

C) Don't mention it
   → If crew member has "private" trait: no effect
   → Otherwise: -5 morale (felt forgotten)

---

**EVENT: quiet_movie_night**

TITLE: Movie Night

TRIGGER:
- Phase: 2
- Day: 40+
- Crew morale average > 40
- Probability: Once per game

DESCRIPTION:
Someone found the entertainment archive. The crew is debating what to watch. Suggestions include an old sci-fi film, a comedy, and a documentary about Mars.

CHOICES:
A) Sci-fi classic
   → All crew: +10 morale
   → Dialogue: "At least our ship is better than that one"

B) Comedy
   → All crew: +15 morale
   → Lightest option

C) Mars documentary
   → All crew: +5 morale
   → Science bonus: Crew discusses actual Mars conditions

D) Let crew vote
   → Highest morale crew member's preference wins
   → +5 relationship with that crew member

---

## Phase 3: Mars Base Events

### Environmental Events

---

**EVENT: dust_storm_warning**

TITLE: Dust Storm Approaching

TRIGGER:
- Phase: 3
- Any sol
- Probability: 10% per week

DESCRIPTION:
Satellite imagery shows a dust storm forming. Estimated arrival: 2 sols. Estimated duration: [3-14] sols. Severity: [Minor/Moderate/Major].

CHOICES:
A) Full lockdown preparation
   → 1 sol to prepare
   → All EVA cancelled during storm
   → Solar power reduced by [20%/50%/90%] based on severity

B) Selective preparation (protect critical systems)
   → Quick prep
   → Some risk to non-critical equipment

C) Continue operations until storm arrives
   → Maximize time
   → Risk: Caught outside when storm hits

---

**EVENT: dust_storm_active**

TITLE: Dust Storm in Progress

TRIGGER:
- Phase: 3
- During dust storm
- Per-sol effects

DESCRIPTION:
Sol [X] of the dust storm. Solar panels at [Y]% efficiency. Battery reserves at [Z]%.

CHOICES (if power critical):
A) Reduce life support to minimum
   → All crew: -5 health per sol
   → Power consumption reduced 40%

B) Shut down non-essential systems
   → No science/manufacturing during storm
   → Maintains life support fully

C) Use emergency power reserves
   → Maintains normal operations
   → Risk: If storm outlasts reserves...

---

**EVENT: temperature_extreme**

TITLE: Temperature Alert

TRIGGER:
- Phase: 3
- Any sol
- Probability: 5% per week

DESCRIPTION:
External temperature has dropped to [extreme value]. Heating systems are working overtime.

CHOICES:
A) Increase heating (uses extra power)
   → Normal operations
   → +20% power consumption for 3 sols

B) Crew bunks together in central module
   → Saves power
   → Morale hit from cramped conditions

C) Rotate heating between modules
   → Moderate power use
   → Some areas cold, affects equipment in those areas

---

### Science Events

---

**EVENT: unusual_reading**

TITLE: Anomalous Sensor Reading

TRIGGER:
- Phase: 3
- Sol: 20+
- Probability: 15% once per game

DESCRIPTION:
The atmospheric sensors are showing something unusual. Methane readings that shouldn't be there. It could be equipment error, geological activity, or... something else.

CHOICES:
A) Investigate thoroughly (EVA + lab time)
   → 3 sols, uses science resources
   → Result: [See outcomes below]

B) Log and note for future missions
   → Minor science credit
   → Mystery unresolved

C) Recalibrate sensors and dismiss
   → No time spent
   → Possible missed discovery

INVESTIGATION OUTCOMES (if A chosen):
- 60% Geological source (interesting, moderate science)
- 30% Equipment error (minor science for methodology)
- 10% Unexplained (major science, ongoing mystery)

---

**EVENT: sample_discovery**

TITLE: Remarkable Sample

TRIGGER:
- Phase: 3
- After any successful EVA sample collection
- Probability: 20% per collection

DESCRIPTION:
Analysis of the collected sample reveals unexpected properties. This could be significant.

EFFECT: (Positive event)
- +30% science points for this experiment
- Sample flagged for priority return

---

**EVENT: experiment_failure**

TITLE: Experiment Contamination

TRIGGER:
- Phase: 3
- During any experiment
- Probability: 10% per experiment (reduced by lab quality)

DESCRIPTION:
Cross-contamination detected in the [experiment name] samples. The data is compromised.

CHOICES:
A) Recollect samples and restart
   → +5 sols to experiment
   → Full science value recovered

B) Attempt to salvage data
   → Skill check: Science
   → Success: 70% science value
   → Failure: 30% science value

C) Abandon experiment
   → No time cost
   → No science value

---

### Crew Events (Mars)

---

**EVENT: eva_incident**

TITLE: EVA Emergency

TRIGGER:
- Phase: 3
- During any EVA
- Probability: 5% per EVA (reduced by crew skill)

DESCRIPTION:
[Crew member] has signaled emergency during EVA. [Suit leak/Fall/Equipment failure].

CHOICES:
A) Immediate rescue EVA
   → Second crew member goes out
   → High chance of saving first crew member
   → Risk: Now two people outside

B) Talk them through self-rescue
   → Skill check: affected crew member
   → Success: They make it back, shaken
   → Failure: Escalates to critical

C) Remote rover assistance
   → If rover available and nearby
   → Medium chance of success, no additional risk

---

**EVENT: cabin_fever**

TITLE: Isolation Effects

TRIGGER:
- Phase: 3
- Sol: 60+
- Probability: 20% once per game

DESCRIPTION:
[Crew member] is showing signs of psychological strain. They've become withdrawn, irritable, and mentioned feeling "trapped."

CHOICES:
A) Mandatory psychological support (Medical Officer)
   → 5 sols of reduced duty
   → Crew member recovers, +20 morale

B) Assign outdoor EVA work
   → "Getting outside" helps
   → Crew member +10 morale, but EVA risk

C) Give them space
   → 50% natural recovery
   → 50% worsening (leads to EVENT: breakdown)

---

**EVENT: mars_sunrise**

TITLE: First Martian Sunrise

TRIGGER:
- Phase: 3
- Sol: 1
- Automatic

DESCRIPTION:
The crew gathers at the habitat window for their first Martian sunrise. The light is different here - colder, more distant, but undeniably beautiful.

EFFECT: (Narrative moment)
- All crew: +15 morale
- "We're really here" realization
- Photo opportunity (logged in mission record)

---

### Resource Events

---

**EVENT: equipment_breakdown**

TITLE: [Equipment] Failure

TRIGGER:
- Phase: 3
- Based on equipment quality
- Probability: Varies by quality

DESCRIPTION:
The [water reclaimer/oxygenator/power system] has failed. Without repair, [consequence].

CHOICES:
A) Full repair (Engineer, spare parts)
   → Uses spare parts
   → System restored to quality - 10%

B) Jury-rig repair
   → No spare parts used
   → System at 50% capacity until proper repair

C) Cannibalize other equipment
   → Sacrifice non-critical system
   → Main system restored

---

**EVENT: supply_audit**

TITLE: Supply Inventory

TRIGGER:
- Phase: 3
- Sol: 30
- Automatic

DESCRIPTION:
Mandatory supply audit complete. Current status: [Food: X sols, Water: Y sols, Oxygen: Z sols, Medical: N units]

EFFECT: (Information event)
- Player sees clear supply status
- May trigger follow-up events if supplies critical

FOLLOW-UP (if any resource < 30 sols):
→ EVENT: supply_rationing

---

**EVENT: supply_rationing**

TITLE: Rationing Decision

TRIGGER:
- Phase: 3
- Any resource < 30 sols remaining

DESCRIPTION:
[Resource] supplies are running low. At current consumption, you'll run out before the return window.

CHOICES:
A) Implement rationing now
   → -10 morale to all
   → Consumption reduced 30%

B) Increase production/recycling
   → Uses power and crew time
   → Consumption reduced 20%

C) Wait and reassess in 10 sols
   → Delay decision
   → Risk: May be too late

---

## Phase 4: Return Trip Events

### Degradation Events

---

**EVENT: worn_system_failure**

TITLE: [System] Showing Wear

TRIGGER:
- Phase: 4
- Any day
- Probability: Higher than Phase 2, based on accumulated damage

DESCRIPTION:
The [system], already stressed from the journey out, is failing. Quality has degraded to [X]%.

CHOICES:
A) Attempt full repair
   → If spare parts available: restore to quality - 15%
   → If no spare parts: jury-rig at 60% capacity

B) Minimize use of this system
   → System preserved
   → Reduced capability for rest of journey

C) Push through
   → No immediate change
   → Risk: 30% chance of complete failure

---

**EVENT: cascade_failure**

TITLE: System Cascade

TRIGGER:
- Phase: 4
- When any system fails completely
- Automatic follow-on

DESCRIPTION:
The [failed system]'s failure has affected connected systems. [Secondary system] is now at risk.

CHOICES:
A) Emergency isolation
   → Lose failed system entirely
   → Protect secondary system

B) Attempt to save both
   → Engineering skill check
   → Success: Both systems at reduced capacity
   → Failure: Both systems severely damaged

---

### Scarcity Events

---

**EVENT: food_critical**

TITLE: Food Supplies Critical

TRIGGER:
- Phase: 4
- Food < 30 days remaining

DESCRIPTION:
At current consumption, food will run out before Earth arrival. The crew knows.

CHOICES:
A) Severe rationing (half portions)
   → All crew: -3 health per day, -20 morale
   → Food consumption halved

B) Moderate rationing
   → All crew: -1 health per day, -10 morale
   → Food consumption reduced 30%

C) Maintain rations, hope for the best
   → Morale maintained
   → Risk: Running out entirely

---

**EVENT: air_quality_degrading**

TITLE: Air Quality Alert

TRIGGER:
- Phase: 4
- If life support quality < 70%
- Probability: 20% once per game

DESCRIPTION:
CO2 scrubbing efficiency is declining. Air quality is degrading. Crew experiencing headaches and fatigue.

CHOICES:
A) Reduce activity (lower CO2 output)
   → All tasks take 50% longer
   → Air quality stabilizes

B) Chemical scrubber supplement (uses supplies)
   → Uses medical/chemical supplies
   → Air quality restored temporarily

C) Accept degraded conditions
   → All crew: -5 health per week
   → Full activity maintained

---

### Crew Events (Return)

---

**EVENT: return_anticipation**

TITLE: Earth Visible

TRIGGER:
- Phase: 4
- Day: When Earth becomes visible dot
- Automatic

DESCRIPTION:
Earth is now visible through the telescope - a pale blue dot in the darkness. The crew takes turns looking.

EFFECT: (Narrative moment)
- All crew: +20 morale
- "We might actually make it" feeling
- Dialogue based on crew personalities

---

**EVENT: exhaustion_breakdown**

TITLE: Breaking Point

TRIGGER:
- Phase: 4
- If any crew morale < 20
- Probability: 50% once per game

DESCRIPTION:
[Crew member] has reached their limit. They're refusing to leave their quarters, barely eating.

CHOICES:
A) Intervention (all crew)
   → Full day lost for entire crew
   → Crew member restored to 40 morale
   → Relationship test with all crew

B) Medical intervention
   → Medical officer handles alone
   → Crew member sedated for 3 days
   → Returns at 30 morale

C) Give them time
   → 50% natural recovery
   → 50% worsening to incapacitation

---

**EVENT: death_in_transit**

TITLE: Final Moments

TRIGGER:
- Phase: 4
- When crew health reaches 0

DESCRIPTION:
[Crew member]'s condition has become critical. Despite all efforts, they are dying.

EFFECT: (Narrative moment)
- Other crew gather
- Final words based on crew relationships and arc
- Remaining crew: -30 morale
- Body must be stored or space burial

CHOICES:
A) Space burial
   → Brief ceremony
   → Body released to space
   → "Proper farewell" for some crew

B) Preserve for Earth
   → Uses power for storage
   → Family will receive remains
   → Some crew find this disturbing

---

### Approach Events

---

**EVENT: earth_contact_restored**

TITLE: Houston, We're Coming Home

TRIGGER:
- Phase: 4
- When within direct communication range
- Automatic

DESCRIPTION:
"Artemis, this is Houston. We read you. Welcome back to the neighborhood."

EFFECT: (Narrative moment)
- All crew: +25 morale
- Mission control support for remaining journey
- News from Earth about what's happened

---

**EVENT: reentry_preparation**

TITLE: Reentry Checklist

TRIGGER:
- Phase: 4
- 3 days before Earth arrival
- Automatic

DESCRIPTION:
Final preparations for atmospheric reentry. All systems must be checked.

EFFECT: (Gameplay event)
- Player reviews all system statuses
- Each critical system gets final quality check
- Any system below 50% quality = warning
- Any system below 30% quality = danger

CHOICES:
A) Proceed as planned
   → Normal reentry sequence

B) Request rescue option (if available)
   → If Earth has rescue capability: safe but expensive
   → If not: must proceed anyway

---

**EVENT: reentry**

TITLE: Reentry

TRIGGER:
- Phase: 4
- Final event
- Automatic

DESCRIPTION:
The moment of truth. Atmospheric interface in T-minus 60 seconds.

EFFECT: (Final resolution)
- Heat shield check (quality → success rate)
- Navigation check (crew skill → accuracy)
- Parachute check (quality → deployment)

OUTCOMES:
- All pass: Safe landing
- Partial failure: Rough landing, injuries possible
- Multiple failures: Catastrophic

---

## Crisis Chains

### Chain: The Cascade (Phase 2)

**Stage 1: Warning Signs**
- Trigger: Day 50+, any component below 60% quality
- Description: Subtle warnings in ship systems

**Stage 2: First Failure**
- Follows Stage 1 by 5-10 days
- Major component failure

**Stage 3: Chain Reaction**
- Follows Stage 2 if not properly addressed
- Multiple systems affected

**Stage 4: Critical Decision**
- Life or death choice
- Crew sacrifice option possible

---

### Chain: The Storm (Phase 3)

**Stage 1: Dust Storm Warning**
- Major storm approaching

**Stage 2: Storm Arrives**
- Power crisis begins

**Stage 3: The Long Night**
- Extended darkness, moral testing

**Stage 4: Storm Breaks**
- Resolution, consequences

---

### Chain: The Return Crisis (Phase 4)

**Stage 1: Discovery**
- Problem identified (fuel/air/food/health)

**Stage 2: Rationing**
- Conservation measures begin

**Stage 3: Desperate Measures**
- Extreme choices required

**Stage 4: Resolution**
- Survival or failure
