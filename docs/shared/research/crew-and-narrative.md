# Crew Depth & Narrative Systems

Deep design research for making the 4 crew members feel like real people, drawing from CK2, The Last of Us, State of Decay, and The Expanse.

---

## 1. Crew Depth System

### 1.1 The Goal

Transform crew from stat blocks into people the player genuinely cares about. When Dr. Chen dies on Sol 67, it shouldn't feel like losing a unit - it should feel like losing a friend.

### 1.2 Expanded Crew Data

Each crew member has:

**Identity:**
- Name, nickname (what crew calls them)
- Age, nationality, cultural background
- Pronouns
- Physical appearance, distinguishing features

**Professional:**
- Specialty (Pilot, Engineer, Scientist, Medical)
- Secondary skill
- Years of experience
- Previous missions
- Training background (military, academic, commercial)

**Personality Traits (3-5 per crew):**

| Category | Traits |
|----------|--------|
| Disposition | optimist, pessimist, stoic, passionate |
| Social | introvert, extrovert, empathetic, reserved |
| Work Style | perfectionist, pragmatist, methodical, creative |
| Stress Response | steady_hands, tunnel_vision, adrenaline_junkie, freeze_prone |
| Moral Framework | utilitarian, protector, by_the_book, ends_justify |

**Psychological:**
- Fears (claustrophobia, failure, abandonment, death)
- Coping mechanisms (humor, exercise, isolation, work)
- Stress response type (fight, flight, freeze, fawn)
- Attachment style (secure, anxious, avoidant)

**Backstory:**
- Defining moment (the event that shaped them)
- Primary ambition (what they want from this mission)
- Secrets (hidden information that can be revealed)
- Regrets (past failures that haunt them)
- Family status (married, children, estranged)

### 1.3 How Traits Affect Gameplay

Traits aren't just flavor - they mechanically change how characters behave:

**Optimist:**
- +15% morale recovery rate
- May miss warning signs (reduced crisis detection)
- Dialogue tends toward hope even in dark moments

**Perfectionist:**
- +20% work quality
- -10% work speed
- Gains stress when forced to rush
- Dialogue shows frustration with "good enough"

**Introvert:**
- Recovers morale when alone
- Loses morale in prolonged group situations
- Prefers solo tasks
- Deeper relationships with fewer people

**Steady Hands:**
- Performance doesn't degrade in crisis
- Can perform under pressure
- Others look to them in emergencies

**Protector:**
- Will volunteer for dangerous tasks to spare others
- Refuses to abandon anyone
- May make tactically poor decisions to save lives

---

## 2. Personal Arc System

### 2.1 The Five Stages

Each crew member has a personal story that unfolds across the mission:

**Stage 0 - FACADE (Days 1-30)**
Character presents their public self. You see competence, professionalism, maybe some quirks.

**Stage 1 - CRACKS (Days 31-60)**
Stress reveals hints of deeper issues. Small moments that don't quite fit their public persona.

**Stage 2 - REVELATION (Days 61-90)**
Secret or fear comes to light. Triggered by specific events or relationship trust levels.

**Stage 3 - CRISIS (Major Event)**
Character must face their core issue. The backstory becomes immediately relevant.

**Stage 4 - RESOLUTION (Variable)**
Growth, regression, or acceptance. Depends on player choices and mission events.

### 2.2 Example Arc: Dr. Sarah Chen (Geologist)

**Backstory:**
- Sister died in a mining accident she couldn't prevent
- Falsified a safety report early in career (the secret)
- Primary ambition: Prove value of safety protocols through perfect mission
- Defining moment: Standing at sister's grave, swearing to do better

**Stage 0 - FACADE:**
Chen appears confident, by-the-book, perhaps cold.
> "Protocols exist for a reason, Commander."

**Stage 1 - CRACKS:**
Equipment failures upset her more than warranted.
> Private moment with trusted crew: "I just... need things to work."

**Stage 2 - REVELATION (requires equipment failure + trust > 60):**
Confesses to falsified report.
> "I told myself it didn't matter. It was one number. But my sister..."

**Stage 3 - CRISIS (triggered by crew injury):**
Freezes when her expertise is needed most.
Must be pulled back by crew relationships.

**Stage 4 - RESOLUTION:**
- **Path A:** Accepts imperfection, becomes better leader
- **Path B:** Doubles down on control, becomes brittle
- **Path C:** If she caused death through inaction, may become reckless

---

## 3. Relationship System

### 3.1 Relationship Types

Relationships evolve over time:

```
STRANGERS
    ↓
COLLEAGUES (default start)
    ↓
    ├→ PROFESSIONAL RESPECT (high respect, medium trust)
    │       ↓
    │   MENTOR-MENTEE (skill differential + teaching)
    │
    ├→ FRIENDS (high affection, high trust)
    │       ↓
    │   CLOSE FRIENDS (shared secrets, high understanding)
    │       ↓
    │   ROMANTIC (if romantic_tension + compatible traits)
    │
    ├→ RIVALS (low trust, can have high respect)
    │       ↓
    │   ENEMIES (low everything, active antagonism)
    │
    └→ STRAINED (unresolved conflict)
```

### 3.2 Relationship Metrics

| Metric | Description | Affected By |
|--------|-------------|-------------|
| Trust | Will they rely on each other? | Kept/broken confidences, covered/exposed mistakes |
| Respect | Professional regard | Competence demonstrations, leadership moments |
| Affection | Personal warmth | Time together, vulnerability sharing, kindnesses |
| Understanding | Do they "get" each other? | Deep conversations, shared experiences |

### 3.3 Relationship Events

**Trust-Building:**
- Keeping a secret
- Covering for a mistake
- Volunteering for danger to protect them
- Supporting them in a conflict

**Trust-Breaking:**
- Revealing a secret
- Exposing a mistake publicly
- Letting them take risk alone
- Opposing them in a conflict

**Affection-Building:**
- Quiet moments together
- Sharing vulnerabilities
- Remembering important details
- Small kindnesses

### 3.4 Conflict System

When crew disagree, conflicts can escalate:

**Conflict Types:**
- Resource (who gets what)
- Authority (who decides)
- Method (how to do something)
- Values (what matters)
- Personal (hurt feelings, past grievances)
- Ideological (political, ethical)

**Escalation Levels:**
1. Professional disagreement (private)
2. Public argument
3. Refuse to work together
4. Other crew take sides
5. Threatens mission effectiveness

**Resolution Options:**
- **Mediation:** Commander facilitates, both share underlying issue
- **Compromise:** Neither fully satisfied, but workable
- **Authority:** Commander decides, damages relationship with one party
- **Avoidance:** Suppressed, will resurface worse

---

## 4. Quiet Moments System (The Last of Us)

### 4.1 Design Philosophy

Quiet moments are small, optional interactions that build character investment without plot pressure. They occur during low-stress periods and reward player attention.

### 4.2 Trigger Conditions

Quiet moments appear when:
- No active crisis
- Average crew stress < 30
- Specific crew member conditions met
- Event hasn't been triggered before
- Random chance passes (creates surprise)

### 4.3 Example Quiet Moments

**Stargazing:**
```
SCENE: Night cycle, observation window

Chen stands at the window, looking at Earth.
Chen: "It's strange. I've wanted this my whole life. Mars.
       The ultimate field work."
[Pause, looking at Earth]
Chen: "I didn't expect to miss the sky."

OPTIONS:
A) "What do you miss most?" → Deeper conversation, backstory reveal
B) "We'll see it again." → Increases hope, warm but generic
C) "Focus on the mission." → Slight relationship hit, Chen respects directness
D) [Say nothing, stand with her] → Strong relationship boost if player has empathetic trait
```

**Guitar in the Rec Room:**
```
SCENE: Player approaching recreation module at night

[Sound of guitar, slightly out of tune]
Rodriguez is sitting alone, playing softly.

OPTIONS:
A) Stop and listen → Rodriguez notices, offers to teach a chord
B) "Couldn't sleep either?" → Opens dialogue about what's keeping them both up
C) Keep walking → Rodriguez doesn't notice, no change
D) [If player has musical trait] "Mind if I join?" → Special bonding scene
```

**Movie Night:**
```
SCENE: Off-duty period, crew gathered

Someone found the classic film archive. Tonight: The Martian.
The crew crowds around the small screen.

Martinez: "If Watney could do it alone, we've got this."
Johanssen: "He had potatoes. We have each other."

[Crew laughter]

EFFECTS: All crew morale +15, may trigger trait reveal (someone admits they're scared)
```

**Overheard Conversation:**
```
SCENE: Player approaching hydroponics, hears voices

[Pauses at door]

Martinez: "---I keep thinking about Earth sunsets."
Dr. Park: "You've mentioned. The ones over the ocean?"
Martinez: "Yeah. I was thinking... when we get back..."
[Long pause]
Dr. Park: "Luis..."
Martinez: "I know. I know it's complicated. Your family,
          the mission, all of it. I just wanted you to know
          that I think about it. About after."
Dr. Park: "I think about it too."

OPTIONS:
A) Clear throat and enter → Breaks moment, they compose themselves
B) Walk away quietly → Let them have this
C) Wait and listen more → Voyeuristic, learn more but ethical cost
```

---

## 5. Permadeath with Meaning

### 5.1 Building Attachment Before Loss

**The Rule:** Never kill a character before the player has invested in them.

**Investment Factors:**
- Time together (minimum 30+ days before eligible for death)
- Shared experiences (memory bank)
- Revealed backstory (arc progression)
- Heroic moments
- Vulnerable moments

**Techniques:**
1. **Make them useful** - Their specialty should matter. When Chen's geology saves the mission, you remember.
2. **Give them opinions** - They should disagree with you sometimes. Conflict creates memory.
3. **Small kindnesses** - They bring you coffee. They notice when you're tired.
4. **Investment in their dreams** - If Rodriguez talks about seeing his daughter, his death costs more.
5. **Vulnerability before danger** - Show weakness before showing mortality.

### 5.2 Death Scene Design

Deaths should honor the character:

**Elements of a Death Scene:**
- Cause acknowledged
- Final words based on personality and relationships
- Witness reactions based on relationship types
- Legacy elements from backstory
- Time for the moment to land

**Example: Dr. Chen's Death (Radiation Exposure)**
```
CONTEXT: Chen shielded the reactor during solar storm.
         Lethal dose. 48 hours.

DAY 1 OF DYING:

Chen, lying in medical bay:
"I calculated it, you know. The moment I stepped in.
I knew the numbers. I always know the numbers."

[If player had high relationship]:
"Remember what I told you about my sister?
I think... I think I understand now why she did what she did.
Sometimes the numbers aren't the point."

DAY 2:

Crew gathers. Chen is weaker but lucid.

Chen: "Rodriguez - your daughter's drawing. The one of the rocket.
       Put it in my personal effects. I want it sent home."

[Rodriguez reaction based on relationship]:
HIGH: Weeping. "I'll bring her to your memorial. I promise."
MEDIUM: Nodding, unable to speak.
LOW: "I didn't know you noticed that."

FINAL REQUEST (varies by arc resolution):
IF ARC RESOLVED POSITIVELY:
"Scatter my ashes on the Martian soil. I wanted to touch Mars.
Now I'll be part of it forever."

IF ARC UNRESOLVED:
"Tell my parents I'm sorry. They'll know what for."

DEATH:
[Simple. Quiet. Someone is holding her hand.]
Dr. Sarah Chen, Mission Geologist, Sol 67.
She is survived by the data she gathered,
the protocols she improved,
and four people who will carry her to Earth.
```

### 5.3 Survivor Grief System

Death affects the living:

**Immediate Effects (based on relationship):**
| Relationship | Morale Hit | Stress Gain | Special |
|--------------|------------|-------------|---------|
| Friend | -30 | +25 | May trigger "grief" temporary trait |
| Romantic | -50 | +40 | May trigger "inconsolable" |
| Rival | -10 | +15 | Guilt, even if they didn't like them |
| Neutral | -15 | +10 | General grief |

**Behavioral Changes:**
- Stoic characters may suppress grief (delayed breakdown possible)
- Empathetic characters absorb others' grief
- Characters who could have prevented death gain "survivor's guilt"

**Long-term Effects:**
- Empty bunk becomes memorial
- Random memory moments ("Remember when Chen...")
- Crew references deceased in relevant situations
- Their work continues (experiments, protocols)

### 5.4 Legacy System

The dead contribute beyond their death:

**Skill Transfer:**
- Characters they mentored gain bonus to relevant skill
- "Chen taught me this" moments in later gameplay

**Research Continuation:**
- Their experiments can be completed by others
- Their notes provide completion bonuses

**Memorial Elements:**
- Personal effects become significant items
- Stories crew tells about them
- Their empty space felt on the ship

---

## 6. Dialogue System

### 6.1 Dialogue Node Structure

```
DIALOGUE NODE:
{
    id: "chen_earth_observation",
    speaker: "chen",
    text: "I didn't expect to miss the sky.",
    emotion: "melancholy",
    conditions: {
        phase: TRAVEL_TO_MARS,
        time: "night_shift",
        chen_morale: ">50",
        relationship_with_player: ">30",
        chen_arc_stage: 1,
        not_triggered: "chen_earth_observation"
    },
    responses: [
        {
            text: "What do you miss most?",
            effects: { relationship: +10 },
            leads_to: "chen_misses_home"
        },
        {
            text: "We'll see it again.",
            effects: { chen_hope: +5 },
            leads_to: null
        }
    ],
    tags: ["quiet_moment", "backstory"]
}
```

### 6.2 Conversation Flow

Conversations can be:
- **Linear:** One response leads to next
- **Branching:** Choice affects direction
- **Conditional:** Only available if conditions met
- **Interruptible:** Crisis can break conversation (return later?)

### 6.3 Player Witness Events

Sometimes the player observes without participating:

```
WITNESS EVENT: martinez_and_park_private

Player can:
A) Enter (breaks moment)
B) Leave quietly (let them have privacy)
C) Listen (learns information, ethical consideration)
D) Deliberately interrupt (if relationship goals require)

Effects vary by choice on:
- What player knows
- Whether participants know player knows
- Relationship with player
- Future event availability
```

---

## 7. Implementation Priority

**Phase 1 - Foundation:**
- Basic traits (3 per crew, 10 trait types)
- Simple relationships (trust only)
- Death with basic memorial

**Phase 2 - Depth:**
- Full trait library (25+ traits)
- Complete relationship metrics
- Personal arcs (5 stages)
- Quiet moments (10 events)

**Phase 3 - Polish:**
- Conflict system
- Grief mechanics
- Legacy effects
- Dialogue system

**Phase 4 - Dream:**
- Procedural backstories
- Dynamic arc generation
- 50+ quiet moments
- Full dialogue trees
