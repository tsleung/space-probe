# Space Probe - Game Design Document

## Overview

A game similar to Oregon Trail set in near-future space exploration, using technology comparable to the movie "The Martian". Players manage a mission to Mars across four distinct phases.

## Core Design Philosophy

Drawing from legendary game designers:

**Sid Meier (Civilization):** "A game is a series of interesting decisions." Every phase should present meaningful choices with clear trade-offs. No optimal path - multiple viable strategies.

**Will Wright (SimCity):** Systems should be interconnected. Decisions in Phase 1 ripple through all subsequent phases. The ship you build determines what's possible on Mars.

**Hideo Kojima (Metal Gear):** Narrative tension through resource scarcity and time pressure. The crew aren't just stats - they're people with stories.

**Shigeru Miyamoto (Nintendo):** Easy to learn, difficult to master. Each phase should have simple core mechanics but deep optimization potential.

**Frank Lantz (Universal Paperclips):** Incremental progression creates compulsive engagement. Numbers going up feels good. Unlocking new systems through accumulated progress keeps players invested through longer play sessions.

**Bungie (Halo: Combat Evolved / Halo: Reach):** Epic scope through intimate moments. Reach especially - knowing the ending (the planet falls) doesn't diminish the journey. Every small victory matters even in a doomed scenario. The weight of sacrifice, camaraderie under pressure, and humanity's reach exceeding its grasp.

**Fantasy Flight (Star Wars: Rebellion):** Asymmetric objectives and hidden information create tension. The Empire hunts, the Rebels hide. Mission-based gameplay where sending the right crew on the right mission matters more than raw stats. Strategic depth from character placement and timing.

**Ironclad Games (Sins of a Solar Empire):** Real-time space opera at scale. The weight and momentum of capital ships. Combat as a consequence of strategic positioning, not the core loop - but when it happens, it feels consequential. Gravity wells and orbital mechanics as gameplay.

**Gas Powered Games (Supreme Commander):** Strategic zoom - seamlessly pulling from individual units to theater-wide view. Economy as warfare: the battle is won or lost in the production queue before the first shot fires. Experimental units as high-risk investments that change the nature of conflict.

## Why Mars?

Mars is currently the closest available planet and relevant to current events. The mission involves landing on the planet, setting up a base, conducting scientific research, launching back into space, and returning to Earth.

## The Four Phases

| Phase | Core Fantasy | Primary Tension |
|-------|--------------|-----------------|
| [1. Ship Building](phase-1-ship-building.md) | NASA Project Manager | Budget vs Quality vs Time |
| [2. Travel to Mars](phase-2-travel-to-mars.md) | Submarine Captain | Resource Management vs Crew Morale |
| [3. Base Management](phase-3-base-management.md) | Colony Governor | Scientific Goals vs Survival |
| [4. Return Trip](phase-4-return-trip.md) | Desperate Survivor | Degraded Systems vs Hope |

See also: [Phase Transitions](phase-transitions.md)

## Win/Lose Conditions

### Victory Tiers (Sid Meier style - multiple win states)

| Tier | Name | Requirements |
|------|------|--------------|
| Gold | Perfect Mission | All 4 crew return, all experiments complete, under budget |
| Silver | Successful Mission | 3+ crew return, primary experiments complete |
| Bronze | Survival | At least 1 crew returns to Earth |
| Pyrrhic | Data Salvaged | Crew lost but scientific data transmitted to Earth |

### Failure States

- Ship fails to launch (Phase 1)
- Total crew loss en route (Phase 2)
- Base becomes unsustainable (Phase 3)
- Unable to return (Phase 4)

## Overarching Systems

### The Ripple Effect

Every phase inherits consequences from previous phases:

```
Ship Quality → Travel Reliability → Base Capability → Return Viability
     ↓              ↓                    ↓                  ↓
  Budget         Crew Health      Scientific Output    Final Score
```

### Cross-Session Consequence Design

**Problem:** If a player completes Phase 1 on Monday and plays Phase 3 on Wednesday, how do they *feel* the impact of their Phase 1 decisions? The game state carries forward, but the player's memory may not.

**Design Solutions:**

1. **Phase Recap Screen**
   - When loading a save, show a "Previously on your mission..." summary
   - Highlight key decisions: "You chose the VASIMR engine (efficient but slow)"
   - Show current consequences: "Your ship's 73% average quality means higher failure rates"

2. **Visible Scars**
   - Damaged components show visually degraded in later phases
   - Crew who got sick in Phase 2 might have "recovered from radiation exposure" in their status
   - The ship layout from Phase 1 remains visible in Phase 2-4 interfaces

3. **Contextual Reminders**
   - When an event fires, reference its cause: "The life support falters - quality was only 61% after rushed testing"
   - Crew dialogue: "Good thing we packed extra oxygen" or "I told you we should have tested the backup systems"

4. **Mission Log as Memory**
   - Searchable log persists across all phases
   - Key decisions auto-tagged: [SHIP BUILD] [CREW CHOICE] [CRITICAL EVENT]
   - Players can review why they're in their current situation

### Meta-Progression (Across Playthroughs)

Beyond single-mission consequences, players who replay gain *knowledge*, not stats:

**What carries across playthroughs:**
- Player skill and system understanding
- Unlocked "Mission Archives" entries explaining mechanics
- Knowledge of which component combinations work well
- Understanding of event patterns and optimal responses

**What does NOT carry across:**
- No permanent stat boosts or unlocks that change difficulty
- No "pay to skip" or accumulated advantages
- Each mission starts fresh - your knowledge is your advantage

This mirrors real astronaut training: the ship doesn't remember your last mission, but *you* do.

### Engineering Investment System (Design Vision)

> **RESOLVED:** This is our philosophy for creating a deep, replayable experience that honors our core tenets of fairness, consequence, and emergent storytelling. We are not just making a game; we are building a story generator.

**1. On Mastery and Depth: Beyond "Research Trees"**

Sid Meier taught us that a game is a series of interesting decisions. A simple "+5% to Engines" is not an interesting decision. It's an illusion of choice. We can do better.

We will not have traditional research trees. They suggest a linear path to being "better," which is a trap. As with *EU4*, there should be no single "right" way to play. Instead, we will offer players a choice of **Mission Philosophy** at the start of each new playthrough. This is a narrative choice that shapes the tools available to them.

-   **Example Philosophies:**
    -   **"The Pioneer's Pragmatism":** Focus on robust, simple systems. Unlocks components that are reliable and easy to repair, but less efficient. For the player who believes in survival above all.
    -   **"The Visionary's Gambit":** Focus on experimental, high-reward technology. Unlocks the exotic VASIMR engine or advanced lab modules. These are powerful but riskier and harder to maintain. For the player who wants to push the boundaries.
    -   **"The Humanist's Touch":** Focus on crew well-being. Unlocks advanced medical bays, psychological support systems, and better recreation facilities. For the player who believes the crew *is* the mission.

This isn't a talent tree. It's a declaration of intent for that specific story. It gives veteran players new strategic avenues to explore, but a first-time player choosing the default, balanced approach is still getting the pure, intended experience. Mastery comes from understanding which philosophy best handles the trials you anticipate.

**2. On Consequence: Making the Past a Character**

Will Wright showed us the beauty of interconnected systems. For a choice to be meaningful, the player must *feel* its consequences, even days later. Our solution is to make the past a living, breathing character in the present.

-   **The Ship as a Historian:** The ship you build in Phase 1 is not a collection of stats; it's a character with a history. We will use the "Visible Scars" idea and elevate it. A cheaply made component doesn't just have a lower stat; in Phase 3, it might flicker on the UI, or its sound effect might have a slight, worrying rattle.
-   **The Crew as Storytellers:** The crew are the most powerful vessel for memory. Drawing from the deep character systems in *crew-and-narrative.md*, their dialogue will constantly echo past decisions.
    -   An Engineer, sitting in the mess hall you almost cut from the budget: "You know, Commander, I'm glad we built this. Seeing something other than a bulkhead does wonders for the soul."
    -   A Scientist, after a breakthrough: "This high-fidelity spectrometer we splurged on? It just paid for the whole mission. The data is revolutionary."
-   **The "Quiet Moments" of The Last of Us:** These moments will be where consequences truly land. A crew member looking at a rattling life support system, not as an alert, but with a quiet, fearful expression. That's more powerful than any pop-up. They will remember your choices, so you will too.

**3. On Progression: The Astronaut vs. The Program**

Hidetaka Miyazaki's work teaches us that triumph must be earned. Giving players permanent stat boosts across playthroughs cheapens their achievements. The astronaut doesn't get a +5% bonus to their piloting skill on their second mission; they are simply wiser. That is our model.

-   **The Astronaut (The Player) Carries Only Knowledge:** The player's progression is their own growing expertise. The core game does not get easier. This is the only way to maintain "classroom fairness" and honor the spirit of *Oregon Trail*.
-   **The Program (The Meta-Game) Carries the Story:** To reward players for their time and investment, we will build the **Mission Archives**. As you encounter failures, successes, and unique events, you unlock beautifully written, in-universe documents:
    -   See a component fail? Unlock the classified engineering report on its flaws.
    -   Witness a crew member's psychological break? Unlock a researcher's paper on deep-space psychosis.
    -   Discover an anomaly on Mars? Unlock the speculative scientific paper about its origin.
    This rewards players with lore, context, and deeper strategic understanding—the kind of knowledge that makes the next playthrough richer, without ever touching a stat. It's a system for those who love the world we're building.
-   **Campaign Mode:** For players at home who crave the legacy of the *Bobiverse* or *Helldivers 2*, we will offer a separate "Campaign Mode." Here, the actions of one mission can leave a permanent mark on the world of the next, like leaving a communications relay in orbit. This keeps the pure, single-mission experience pristine while offering a deeper narrative for those who want it.

**4. On Satisfaction: The Joy of Building Engines of Hope**

Frank Lantz proved that "numbers go up" is a deeply compelling loop. We will provide this satisfaction, but in a way that serves the narrative of desperation and survival, inspired by *The Martian*. Our "numbers" are contained within each mission.

-   **Phase 1: The Engine of Ambition.** The player converts `Budget` into `Ship Quality`. You are literally building your vessel of hope.
-   **Phase 3: The Engine of Survival.** On Mars, the player builds their masterpiece. They transform `Ice` and `Regolith` into `Water`, `Oxygen`, and `Rocket Fuel`. Watching the fuel tank for the return journey fill up, drop by precious drop, *is the game*. This is the ultimate "numbers go up" fantasy, earned through ingenuity against impossible odds.

The beauty, and the bittersweet genius of this, is that **you must leave it all behind.** That magnificent, sprawling base you built in Phase 3? It stays on Mars, a monument to your struggle. You don't take the power with you, only the *fruits* of that power—the full fuel tanks, the scientific data, the crew you kept alive. This provides the satisfaction of building something incredible, while reinforcing the core tension of the game and elegantly avoiding any form of power creep. You get the joy of building, the tension of losing it, and the motivation to do it all again, but better, on the next journey.

### Crew System

4 crew members, each with:
- **Specialty:** Engineer, Scientist, Pilot, Medical
- **Stats:** Health, Morale, Skill Level
- **Relationships:** Bonds with other crew affect morale events
- **Personal Mission:** Optional side objective for bonus points

### Resource Categories

| Category | Phases Active | Description |
|----------|---------------|-------------|
| Budget | 1, 3 | Money for construction and resupply |
| Time | All | Days until launch window / mission milestones |
| Supplies | 2, 3, 4 | Food, water, oxygen, medical |
| Power | 2, 3, 4 | Solar/battery/reactor capacity |
| Morale | 2, 3, 4 | Crew mental state |
| Hull Integrity | 2, 4 | Ship structural health |

### The "Oregon Trail" DNA

What made Oregon Trail timeless:
1. **Meaningful preparation** - Buying supplies mattered
2. **Random events with player agency** - Events had choices, not just outcomes
3. **Permanent consequences** - Death was real, resources didn't respawn
4. **Clear progress indicator** - Always knew how far you'd come and how far to go
5. **Replayability through randomness** - Each playthrough felt different

We preserve all five in each phase.

## Technical Scope

- **Engine:** Godot
- **Art Style:** TBD
- **Target Platform:** TBD
- **Estimated Playtime:** 2-4 hours per complete mission

### Core Requirement: Classroom Play

**This game must be playable in classroom settings.** This is not optional - it's a fundamental design constraint that honors Oregon Trail's legacy as an educational game.

Requirements:
- **~20 minute phases:** Each phase completable in a single class period or lunch break
- **Clean save/resume:** Players can stop at any phase transition and continue later
- **No account required:** Works offline, no login walls
- **School-appropriate content:** No gore, excessive violence, or inappropriate themes
- **Educational value:** Real science concepts (orbital mechanics, life support, resource management)
- **Low system requirements:** Runs on school computers and Chromebooks

The phase structure creates natural stopping points. A teacher can assign "complete Phase 1" as homework, or run Phase 2 as a classroom activity with discussion afterward.

This constraint improves the game for all players - accessible pacing, clear progression, and respect for player time.

## Document Index

### Core Game Design
- [Phase 1: Ship Building](phase-1-ship-building.md)
- [Phase 2: Travel to Mars](phase-2-travel-to-mars.md)
- [Phase 3: Base Management](phase-3-base-management.md)
- [Phase 4: Return Trip](phase-4-return-trip.md)
- [Phase Transitions](phase-transitions.md)

### Systems & Content
- [Events Catalog](events-catalog.md) - All events with triggers, choices, consequences
- [Balance & Numbers](balance-and-numbers.md) - Formulas, probabilities, resource rates
- [Crew Roster](crew-roster.md) - Default crew stats, traits, relationships, arcs
- [Data Schema](data-schema.md) - JSON structures for components, events, saves

### User Experience
- [UI Wireframes](ui-wireframes.md) - Screen layouts and interaction patterns
- [Tutorial & Onboarding](tutorial-onboarding.md) - How players learn the game
- [Audio & Visual Direction](audio-visual-direction.md) - Art style, sound design, aesthetics
- [Accessibility](accessibility.md) - Colorblind modes, keyboard navigation, screen readers
- [Localization](localization.md) - Multi-language support plan

### Design Research
- [Inspirations](design-research/inspirations.md) - Analysis of game and media influences
- [Crew & Narrative](design-research/crew-and-narrative.md) - Deep character systems
- [Strategy & Meta](design-research/strategy-and-meta.md) - Factions, progression, resources
- [Expanded Systems Vision](design-research/expanded-systems.md) - Future feature roadmap
