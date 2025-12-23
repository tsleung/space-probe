# VNP Future Directions

Research into game design inspirations for Von Neumann Probe's evolution.

---

## Inspirations Analyzed

### Journey (thatgamecompany)
- **Japanese Garden Philosophy**: "Design is perfect when you cannot remove anything else"
- **Emotional Arc**: Story follows Joseph Campbell's hero's journey / stages of life
- **Wordless Connection**: Players can only communicate via musical chimes
- **Minimalism**: Remove mechanics that don't serve the core emotional experience

### Nier: Automata (Yoko Taro)
- **Emotion-First Design**: Start with the feeling you want, build mechanics around it
- **Backwards Storytelling**: Design from the most gut-wrenching moment, work backwards
- **Mechanics as Narrative**: Saving = data upload, fast travel = consciousness transfer
- **Making Players Question**: Violence has consequences; enemies have humanity
- **Melancholy**: The core feeling pervading every design decision
- **Philosophical Depth**: Integrate real philosophy (existentialism, absurdism)

### Bobiverse (Dennis E. Taylor)
- **Self-Replication**: Probes copy themselves using local resources
- **Personality Drift**: Each clone is slightly different due to quantum fluctuations
- **Long Timescales**: Millions of years of exploration
- **Exponential Growth**: Quality of speed vs quantity of probes
- **Human Questions**: What makes you "you" when copies diverge?

### Autobattler Genre
- **Preparation vs Spectacle**: Strategic depth in setup, watch combat unfold
- **Idle Elements**: Progress continues while away
- **Synergies**: Unit combinations create emergent strategies
- **Economy Management**: Resource decisions drive composition

### Space Fleet Games
- **Gratuitous Space Battles**: Design ships, set orders, watch battles unfold
- **NEBULOUS: Fleet Command**: Deep tactics, every loss counts
- **Falling Frontier**: Logistics, reconnaissance, fleet customization

---

## Potential Directions

### Direction A: "The Melancholy Spectacle"
*Inspired by: Journey + Nier: Automata*

**Core Feeling**: Bittersweet wonder at endless war

**Additions**:
- **Named Ships**: Each ship gets a randomly generated name (Bob-47, Athena-12)
- **Death Notifications**: Brief text when named ships die ("Valor-7 was lost")
- **Victory Monologue**: Winning faction's AI reflects on the cost
- **Memorial Mode**: See all ships lost across all battles
- **Musical Progression**: Sound design evolves with battle state (calm → intense → melancholy)

**Philosophy**: Make the spectacle beautiful but sad. Every explosion is a loss.

---

### Direction B: "The Eternal War"
*Inspired by: Bobiverse + Gratuitous Space Battles*

**Core Feeling**: You are an immortal AI watching civilizations rise and fall

**Additions**:
- **Generations System**: After each battle, surviving ships "evolve" slightly
- **Trait Accumulation**: Victorious ships pass traits to new builds
- **Long-Term Meta**: Stats persist across sessions (total ships built, battles won)
- **Personality Drift**: Factions slowly change behavior based on history
- **Archive Mode**: Review past great battles

**Philosophy**: Make the player feel like they're watching eons unfold.

---

### Direction C: "The Preparation Game"
*Inspired by: Autobattlers + Fleet Command games*

**Core Feeling**: Satisfaction of a plan coming together

**Additions**:
- **Pre-Battle Setup Phase**: Design fleet composition before battle starts
- **Ship Customization**: Upgrade paths for each ship type
- **Formation Editor**: Set patrol patterns and engagement rules
- **Battle Analysis**: Post-battle breakdown of what worked
- **Challenge Modes**: "Win with only frigates" or "No base weapon"

**Philosophy**: Shift depth from passive watching to active planning.

---

### Direction D: "The Quiet Garden"
*Inspired by: Journey's minimalism*

**Core Feeling**: Meditative, almost zen watching

**Additions**:
- **Ambient Mode**: No UI, just ships and stars
- **Slower Pace Option**: 0.5x speed for contemplation
- **Procedural Music**: Generative soundtrack that responds to battle state
- **Screensaver Mode**: Run in background, beautiful at a glance
- **Color Palette Themes**: Dawn, Dusk, Deep Space, Nebula

**Philosophy**: Strip away everything except beauty.

---

### Direction E: "The Philosophical AI"
*Inspired by: Nier: Automata's philosophical depth*

**Core Feeling**: Question what you're watching

**Additions**:
- **AI Commentary**: Occasional text from each faction's AI reflecting on combat
- **Victory Philosophy**: Each faction has different views on winning
  - Player: "We endure because we must"
  - Enemy: "Strength is the only truth"
  - Nemesis: "All returns to entropy"
- **Existential Events**: Random philosophical questions appear
- **Memorial Wall**: Names of all fallen ships, questioning the point

**Philosophy**: Make players think about what endless war means.

---

### Direction F: "The Roguelite Campaign"
*Inspired by: Original VNP concept + Bobiverse*

**Core Feeling**: Building something across many runs

**Additions**:
- **Galaxy Map**: Multiple systems to conquer
- **Campaign Progression**: Win battles to expand territory
- **Unlockable Ships**: New ship types earned through play
- **Enemy Escalation**: Nemesis grows stronger if ignored
- **Self-Replication Theme**: Victory lets you "copy" fleet to new system

**Philosophy**: Give long-term meaning to individual battles.

---

## Recommended Starting Point

**Direction A + D Hybrid**: "The Beautiful Loss"

Combine:
1. Named ships with brief death notifications (melancholy)
2. Ambient mode toggle for pure spectacle (zen)
3. Musical progression tied to battle state (emotional arc)
4. Victory/defeat monologues (philosophical)

This adds emotional depth without changing core mechanics. Implementation:
- Add ship naming system (random generator)
- Add small death notification queue (3-4 recent losses)
- Create ambient mode (hide UI on keypress)
- Write 5-10 faction monologues

Estimated scope: Medium - adds feeling, not systems.

---

## Sources

- [GDC Vault: Designing Journey](https://gdcvault.com/play/1017700/Designing)
- [Narrative Design Analysis: NieR: Automata](https://www.rpgfan.com/feature/narrative-design-analysis-nier-automata/)
- [Bobiverse Wiki](https://bobiverse.fandom.com/wiki/Bobiverse_Wiki)
- [Gratuitous Space Battles on Steam](https://store.steampowered.com/app/41800/Gratuitous_Space_Battles/)
- [NEBULOUS: Fleet Command on Steam](https://store.steampowered.com/app/887570/NEBULOUS_Fleet_Command/)
- [iLogos: Auto Battler Game Development Guide](https://ilogos.biz/auto-battler-game-development-guide/)

---

*Document Version: 1.0*
*Created: December 2024*
