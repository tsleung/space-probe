# MOT Phase 2: Build Plan

## The Vision

**One Line:** Overcooked meets Apollo 13 - watch your AI crew frantically keep a ship together while the void tries to kill you.

**The Hook:** You're not clicking menus. You're watching crew sprint to a hull breach as oxygen ticks down. You're yelling at your screen. Chat is screaming. They fix it with 30 seconds to spare. THAT'S a clip.

---

## Core Pillars

1. **The Ship is the Stage** - You see the interior, the crew, the chaos
2. **Crew are Actors** - AI-controlled, running between stations, visibly working
3. **The Void is the Antagonist** - Things break, not because of drama, but physics
4. **Commander Directs** - Player sets priorities, crew executes
5. **Tension is Visible** - Timers, damage, crew running, alarms

---

## MVP Scope

### The Ship View

```
┌─────────────────────────────────────────────────┐
│                    BRIDGE                        │
│                   [Controls]                     │
│                      ●Cmd                        │
├──────────────┬─────────────────┬────────────────┤
│   QUARTERS   │   CORRIDOR      │  LIFE SUPPORT  │
│    ●  ●      │                 │    [O2] [H2O]  │
│   (rest)     │    ←Eng         │       ●Sci     │
├──────────────┤                 ├────────────────┤
│   MEDICAL    │                 │   ENGINEERING  │
│    [Beds]    │                 │   [Power] [Sys]│
│      ●Med    │                 │                │
├──────────────┴─────────────────┴────────────────┤
│                  CARGO BAY                       │
│        [Food] [Water] [Parts] [Supplies]        │
│                    ⚠️ BREACH                     │
└─────────────────────────────────────────────────┘
```

- Top-down or isometric view
- ~6-8 rooms connected by corridors
- Crew visible as dots/sprites moving between rooms
- Systems visible in each room (power, O2, cargo, etc.)

### Crew Behavior

**Movement:**
- Crew pathfind between rooms
- Walking speed, running speed (when urgent)
- Visible destination (where are they headed?)

**States:**
- Idle at station (monitoring)
- Moving to task
- Working on task (progress visible)
- Resting (in quarters)
- Emergency response (running)

**Roles:**
- Each crew has a home station they return to
- Commander: Bridge
- Engineer: Engineering
- Scientist: Life Support / Sensors
- Medical: Medical Bay

### Events as Spectacle

**When debris hits:**
1. Impact sound + screen shake
2. Sparks fly in affected room
3. Alarm starts
4. Crew nearest to breach starts running
5. Timer appears: "HULL BREACH - 2:00 to seal"
6. Watch crew work
7. Success: sparks stop, alarm silences
8. Failure: room decompresses, door seals

**Visual Feedback:**
- Sparks for electrical damage
- Flashing red for critical
- Flickering lights for power issues
- Frost for thermal problems
- Crew animations match urgency

### Player Controls

**Priority System:**
```
[1] HULL INTEGRITY  ← Currently selected
[2] LIFE SUPPORT
[3] POWER SYSTEMS
[4] CREW HEALTH
[5] CONSERVATION MODE
```

Player selects priority → AI crew responds accordingly

**Direct Orders (Maybe):**
- Click on crew → Click on room → "Go there"
- Override AI for specific situations
- Costs: breaks optimal AI behavior

**Speed Controls:**
- Pause (for decisions)
- Normal (watch the action)
- Fast (routine periods)
- Events auto-pause

### The HUD

```
┌────────────────────────────────────────────────┐
│ DAY 47 / 183                     MARS: 136 DAYS│
├────────────────────────────────────────────────┤
│ O2 ████████░░ 78%    FOOD ██████████ 94 DAYS   │
│ PWR █████████░ 91%   H2O  █████████░ 87 DAYS   │
├────────────────────────────────────────────────┤
│ CMD [Monitoring]  ENG [Repairing Hull - 45s]   │
│ SCI [Analyzing]   MED [Resting]                │
└────────────────────────────────────────────────┘
```

- Day counter always visible
- Resources as bars AND days remaining
- Crew status at a glance
- Active tasks with timers

---

## Technical Approach

### Ship Scene Structure

```
Phase2Ship (Node2D)
├── Tilemap or Rooms (visual layout)
├── NavigationRegion2D (pathfinding)
├── Rooms/
│   ├── Bridge
│   ├── Engineering
│   ├── LifeSupport
│   ├── Medical
│   ├── Quarters
│   └── CargoBay
├── Crew/
│   ├── Commander (CharacterBody2D)
│   ├── Engineer (CharacterBody2D)
│   ├── Scientist (CharacterBody2D)
│   └── Medical (CharacterBody2D)
├── Systems/
│   ├── HullSystem
│   ├── PowerSystem
│   ├── O2System
│   └── etc.
└── EffectsLayer (sparks, alarms, etc.)
```

### Crew AI (Simple State Machine)

```gdscript
enum CrewState {
    IDLE,           # At home station, monitoring
    MOVING,         # Walking/running to destination
    WORKING,        # Performing task
    RESTING,        # In quarters
    EMERGENCY       # Responding to crisis
}
```

### Event System Integration

Current Phase2 events trigger visual responses:
```gdscript
# When reducer processes HULL_BREACH action:
signal hull_breach(room_id: String, severity: float)

# Ship scene responds:
func _on_hull_breach(room_id, severity):
    rooms[room_id].start_breach_effect()
    alarms.play()
    crew_ai.dispatch_to_breach(room_id)
    ui.show_breach_timer(severity)
```

---

## Build Phases

### Phase 1: The Ship Exists (Week 1)
- [ ] Create ship tilemap/layout
- [ ] Add room nodes with collision
- [ ] Basic navigation mesh
- [ ] Crew as moving dots
- [ ] Crew can pathfind between rooms
- [ ] Camera shows full ship

### Phase 2: Crew Has Purpose (Week 2)
- [ ] Crew state machine (idle, moving, working)
- [ ] Home stations per role
- [ ] Basic task system (go to room, work, return)
- [ ] Visual feedback (crew doing something)

### Phase 3: Things Break (Week 3)
- [ ] Hook events to visual effects
- [ ] Sparks, alarms, screen shake
- [ ] Breach timer system
- [ ] Crew responds to emergencies
- [ ] Success/failure visual feedback

### Phase 4: Player Agency (Week 4)
- [ ] Priority system UI
- [ ] Crew responds to priorities
- [ ] Direct order system (maybe)
- [ ] Speed controls work with new view

### Phase 5: Polish (Week 5+)
- [ ] Sound design (alarms, footsteps, hissing)
- [ ] Better crew sprites/animations
- [ ] Room detail art
- [ ] Camera follow modes
- [ ] Particle effects

---

## Key Decisions to Make

1. **Art Style:** Pixel art? Vector? What's achievable?
2. **Camera:** Fixed top-down? Follow crew? Player controlled?
3. **Direct Control:** Can player take over a crew member? Or just direct?
4. **Time Scale:** How fast do days pass? When do events hit?
5. **Failure States:** What happens when crew can't fix in time?

---

## Success Metrics

**It's Working When:**
- [ ] You watch crew run to a breach and feel tension
- [ ] You yell at your screen during a close call
- [ ] You want to show someone what happened
- [ ] A 5-minute clip would be interesting to watch
- [ ] You want to try again after failure

**It's NOT Working If:**
- Crew movement feels random or meaningless
- Events are just timers without visual stakes
- Player feels disconnected from the action
- It's more interesting to read the log than watch

---

## Future Vision (Not Now)

- 4-player co-op (each player IS a crew member)
- Voice chat chaos coordination
- More complex ship layouts
- Procedural events and runs
- Leaderboards (furthest with least deaths)
- The ultimate "Overcooked in space"

---

## Next Action

**Start with:** A ship you can see, with 4 dots that move between rooms.

That's it. Get that working. Everything builds from there.
