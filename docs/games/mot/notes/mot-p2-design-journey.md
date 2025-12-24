# MOT Phase 2: Design Journey

**Document Created:** December 22, 2024
**Purpose:** Capture the story of how we arrived at "Overcooked meets Apollo 13"

---

## The Starting Point

We had a working MOT Phase 2 - a 183-day journey to Mars with:
- Resource management (food, water, oxygen, power, fuel)
- Storage container system (4 cargo bays with accessibility states)
- Event system (solar flares, malfunctions, crew issues)
- Repair mechanics (2-4 day repairs, EVA retrieval)
- Crew system (4 members with health, morale, fatigue)

The code was solid. The Store/Reducer architecture was clean. The game worked.

**But something was missing.**

---

## The Question That Changed Everything

> "What would make someone want to stream this?"

The text-based resource bars and event popups weren't creating *moments*. Nobody was going to clip "I clicked option 2 on the solar flare event."

We started analyzing what makes games watchable:

| Game | Why People Watch |
|------|------------------|
| Oregon Trail | The death messages, the spiral you can see coming |
| FTL | Close calls, hull at 1HP, "we're going to die... no wait" |
| Overcooked | Frantic coordination, chaos, yelling at teammates |
| Helldivers 2 | Everything going wrong spectacularly together |
| Among Us | People running around suspiciously |

The common thread: **visible action, not just numbers.**

---

## Key Insight #1: The Ship as Stage

> "Following a character around the ship, even if you're spectating it being controlled by AI, could be kinda nice."

What if you could *see* the ship? Not as an icon on a progress bar, but as a living thing with:
- Rooms you can look into
- Crew members you can watch
- Damage you can see
- Repairs happening in real-time

This led to the **cutaway ship view** - like FTL, but you're watching AI crew respond autonomously.

---

## Key Insight #2: Crew as Actors

> "We can way way way way in the future make it a team game of keeping a ship together while we fly."

The crew shouldn't just be stats. They should be **characters on stage**:
- You watch the engineer sprint to a hull breach
- You see the medical officer rushing to sick bay
- You notice the commander making decisions

The tension isn't in the numbers - it's in watching someone run toward danger.

---

## Key Insight #3: The Void as Antagonist

We deliberately avoided "reality show drama" - no crew members getting hissy with each other. Instead:

> "No villain, just physics."

The enemy is:
- The 55 million miles of empty space
- The equipment that breaks
- The resources that deplete
- Time itself

This is The Martian philosophy: competent people vs. an indifferent universe.

---

## The Tagline Emerges

After exploring FTL, Oregon Trail, Darkest Dungeon, Helldivers 2, Among Us...

> **"Overcooked meets Apollo 13"**

That captures it:
- **Overcooked**: Frantic coordination, visible chaos, streamable moments
- **Apollo 13**: Competent crew, cascading problems, man vs. physics

---

## What We Built

### December 22, 2024 - Ship View MVP

We built a working proof of concept:

**The Ship:**
```
[MEDICAL]---[QUARTERS]---[CORRIDOR]---[BRIDGE]  (nose)
                             |
[CARGO ]---[LIFE SUP]---[ENGINEERING]
```

**The Crew:**
- 4 colored dots (Commander, Engineer, Scientist, Medical)
- Real pathfinding between rooms
- States: Idle, Moving, Working, Emergency

**The Chaos:**
- Random damage events
- Rooms flash red when damaged
- Crew AI automatically responds
- Timers count down to disaster
- Critical failures end the game

**The Context:**
- Parallax star field
- Ship hull with engine glow
- Earth → Mars journey indicator

### It Works

When you run the "Ship Auto" scene:
- Days tick by
- Random rooms get damaged
- Crew dots sprint to fix them
- Crisis timers count down
- Sometimes they make it, sometimes they don't

It's not polished. But you can *watch* it. You can root for the engineer to make it in time.

---

## The Integration Plan

Now we're merging this visual system with the existing game mechanics:

**Keep from P2:**
- 183-day journey
- Storage containers with blocking/damage
- Repair system (2-4 days, not seconds)
- EVA retrieval mechanics
- Full event system
- Resource consumption
- Crew stats (health, morale, fatigue)

**Add from Ship View:**
- Visual ship cutaway
- Crew pathfinding
- Room damage effects
- Crisis visualization
- Journey indicator

**Bridge them together:**
- When P2 triggers a section blockage → room shows damage
- When P2 starts repair → engineer moves to room
- When P2 fires event → relevant crew responds visually
- When P2 advances day → journey indicator updates

---

## Design Principles Established

### 1. Show, Don't Tell
Numbers matter, but watching someone run to fix a problem matters more.

### 2. Competence, Not Drama
The crew is professional. The tension comes from the situation, not personality conflicts.

### 3. The Math is Clear
Players should be able to see their margins: "We'll make it with 3 days of food... if nothing else goes wrong."

### 4. Events Create Moments
Every event should be something you could describe later: "Remember when the oxygen system failed on day 47?"

### 5. The Journey Itself is the Story
Mars getting larger. Earth getting smaller. The countdown continues.

---

## What Makes It Streamable

After this design journey, we identified the key elements:

### Decisions Viewers Argue About
"I would have sent the scientist!"
"Why didn't they rest first?"
"That EVA was too risky!"

### Visible Tension
- Crew running
- Timers counting down
- Rooms flashing
- Resources depleting

### Near-Miss Moments
"They fixed it with 5 seconds left!"
"The engineer barely made it!"
"We're going to arrive with 2 days of food!"

### The Arrival
183 days of building tension → the final approach → did we make it?

---

## Lessons Learned

1. **Start with the feeling** - What emotion do we want? Then work backward to mechanics.

2. **Reference widely** - FTL, Overcooked, The Martian, Apollo 13, Oregon Trail all informed this.

3. **Visible > Abstract** - A running crew member is more compelling than a stat change.

4. **AI can be entertainment** - Watching AI respond to crises is itself compelling if the stakes are clear.

5. **Keep game logic separate** - The Store/Reducer architecture meant we could add visuals without touching game logic.

---

## Future Vision

What this could become:

### Solo Experience (Current)
Watch your AI crew survive (or not). Make priority decisions. Experience the journey.

### Cooperative Multiplayer
Each player IS a crew member. Voice chat chaos. "Someone get to Engineering!" "I'm stuck in Medical!"

### Streaming Integration
Twitch chat votes on event choices. Chat can trigger bonus events. Collaborative survival.

### The Ultimate "Overcooked in Space"
A genre-defining experience where the chaos is the fun.

---

## Credits

This design emerged from collaborative exploration - discussing games we loved, identifying what made them work, and finding the intersection of what we could build and what would be compelling.

**Key References:**
- FTL: Faster Than Light (ship management, cutaway view)
- Overcooked (frantic coordination, streamability)
- The Martian (competence porn, man vs. physics)
- Apollo 13 (crew professionalism, cascading problems)
- Oregon Trail (resource depletion, random death)
- Helldivers 2 (cooperative chaos)
- Among Us (people running around a ship)
- Darkest Dungeon (stress mechanics, atmosphere)

---

*"Overcooked meets Apollo 13" - that's the game we're building.*
