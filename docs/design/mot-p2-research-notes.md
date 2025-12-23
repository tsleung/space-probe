# MOT Phase 2: Research & Design Exploration

*Raw notes from design session - December 2024*

---

## Starting Point: Crew Roles

**Initial Question:** What's the deal with crew messages? We're only using the Engineer.

**Current State:**
- 4 roles defined: Commander, Engineer, Scientist, Medical
- Only Engineer is used (gets fatigued during repairs)
- No crew-specific tasks, messages, or personality

**The Problem:** How do we make crew meaningful without "reality show drama"?

---

## Exploring Crew Differentiation

**User Direction:**
> "I'm interested in how we can make this compelling without dialing up reality show drama - I don't want them to get hissy with each other. I'm trying to think of Andy Weir's The Martian - what the different roles on the ship do. Also Star Trek, except we don't have an advanced ship enough like Star Trek."

**Key Insight from User:**
> "If anything is REALLY going wrong, no one is going to say 'not my job description'"

**Apollo Reality:**
- Everyone does everything
- Roles = who leads which phase, who has deepest expertise
- Redundancy - if one person down, others take over

---

## The First Design Direction: Monitoring + Expertise + Fatigue

**Monitoring Domains:**
Each crew watches different aspects (not because others CAN'T, but can't watch everything):
- Commander: Mission timeline, Earth comms, crew scheduling
- Engineer: Power, propulsion, structural integrity
- Scientist: Sensors, radiation, trajectory analysis
- Medical: Crew vitals, supplies, life support quality

**Gameplay Effect:** Person monitoring can notice problems BEFORE they become events.

**Expertise Modifiers (Not Locks):**
Anyone can attempt anything. Expertise affects:
- How long it takes
- How much it costs (supplies, fatigue)
- Chance of complications

**Example:**
```
Repair bulkhead breach:
- Engineer leads: 2 days, 1 spare part, low risk
- Anyone else leads: 4 days, 2 spare parts, medium risk
```

**Fatigue as Constraint:**
Not "who can do what" but "everyone is tired and you can't do everything"

**User Response:** "Yes let's do that for now."

---

## The Bigger Question: What Makes P2 Compelling?

**User Challenge:**
> "We need to keep pushing to see what would make MOT:P2 a compelling spectacle and narrative that people would replay, stream, and watch others play it"

**What Made Oregon Trail Work:**
- Scarcity pressure - never enough resources
- Pacing trade-offs - fast (risk breakdown) vs slow (run out of food)
- Random disaster - cholera doesn't care about your plans
- Irreversible loss - people die, they stay dead
- Simple decisions with weight - ford, caulk, or pay for ferry?

Party members were basically hit points with names. No personalities. And it worked.

**What The Martian Does Right:**
- Competence porn - smart people solving problems
- The math is clear - X days of food, Y days to rescue
- Cascading failures - one thing leads to another
- Man vs. environment - no villain, just physics

**What Creates Watchability:**
1. Decisions viewers argue about
2. Tension they can feel
3. Moments that become clips
4. Not too slow, not too complex

**The Core Tension Loop:**
```
Supplies deplete daily
        ↓
Events create crises
        ↓
Crises demand resources (parts, power, crew time)
        ↓
Spending resources accelerates depletion
        ↓
Distance remains constant
        ↓
Can you make it?
```

---

## What's Missing From Current P2

- No visual journey (progress bar doesn't create immersion)
- No voice/personality (events are text blobs)
- No cascade (events are isolated incidents)
- No close calls (binary outcomes)
- No variety (same events each run)

---

## Exploring Directions

**Direction A: The Ship as Stage**
You SEE the ship interior. Crew at stations. When things break, you see it.
*Streamable moment: "Oh god the lights are flickering in cargo bay 3"*

**Direction B: The Void as Terror**
The vastness of space. Earth shrinking. Mars a dot. You feel how alone you are.
*Streamable moment: "We're 90 million miles from anyone who could help"*

**Direction C: The Narrator as Personality**
A voice that makes everything hit harder. Mission control, or retrospective narration.
*Streamable moment: "They did not know this would be their last meal together."*

**Direction D: The Mechanics as Spectacle**
Decisions are visual. Flipping switches, routing power, physically selecting what to sacrifice.
*Streamable moment: Dragging food rations into the airlock to jettison mass*

**Direction E: The Documentary**
Frame as documentary about a Mars mission. Interview snippets. Found footage.
*Streamable moment: Shift between PR footage and reality*

---

## The Breakthrough

**User Response:**
> "I see Direction A, B, D as really good. It reminds me of Helldivers 2, Among Us, and Overcooked. Not the aliens or imposter, but the idea of running around frantically trying to get things done before doom finds you."

**The Key Insight:**
> "Following a character around the ship, even if you're spectating it being controlled by AI, could be kinda nice."

**The Future Vision:**
> "We can way way way way in the future make it a team game of keeping a ship together while we fly."

---

## The Final Direction: Ship as Stage + Frantic Crew

**The Core Concept:**
You're watching your crew scramble around the ship trying to not die. Things break. Alarms blare. Someone's running to the hull breach while someone else is rerouting power. The ship shakes. Sparks fly. They fix it. Everyone exhales.

Then something else breaks.

**Reference Games:**
- **Overcooked** - frantic cooperation, everything's on fire
- **Among Us** - the ship layout, running between rooms
- **Helldivers 2** - chaos, things going wrong, frantic competence
- **Apollo 13 / The Martian** - not anyone's fault, just the void trying to kill you

**What Makes It Streamable:**
The streamer isn't clicking through menus - they're watching their crew sprint down a corridor as the oxygen timer ticks down. They're yelling "GO GO GO" at the engineer. The chat is screaming. The repair happens with 30 seconds to spare.

THAT'S a clip.

**The Player Role:**
You're the Commander. You don't directly control crew - you direct priorities.
Or maybe you CAN take direct control of one crew member in emergencies?

**The Progression:**
```
Phase 1: MVP
- Top-down or isometric ship view
- AI crew running between stations
- Visual events (sparks, alarms, decompression)
- Player gives high-level orders
- Watch crew execute

Phase 2: Polish
- Camera follows specific crew member
- Crew has animations, personality in movement
- Ship feels alive
- Sound design

Phase 3: Future Dream
- 4-player co-op
- Each player IS a crew member
- Voice chat chaos
- The ultimate Overcooked-in-space
```

---

## Key Quotes

> "I don't want them to get hissy with each other"

> "If anything is REALLY going wrong, no one is going to say 'not my job description'"

> "Following a character around the ship, even if you're spectating it being controlled by AI, could be kinda nice"

> "We can way way way way in the future make it a team game"

> "Things are breaking and calamity is happening, not because of anyone's fault, but something explodes or debris, like The Martian or Apollo 13"

---

## Summary

Started with: "How do we use all 4 crew roles?"

Ended with: "We need to rebuild P2 as a visual spectacle where you watch AI crew frantically keeping a ship together, with future potential for 4-player co-op."

The crew roles question is still valid, but now it's in service of a bigger vision: the ship as stage, the crew as actors, the void as antagonist.
