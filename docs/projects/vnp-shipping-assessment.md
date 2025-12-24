# VNP Shipping Assessment

One-week sprint to ship. What's ready, what needs polish, what to cut.

---

## Current State

### Visual Effects: READY
- Multi-layer weapon visuals (railgun, missile, turbolaser, laser)
- Spectacular defensive effects (shield bubble, gravity well, PDC zone)
- 5-layer death explosions with secondary flashes
- Base weapon effects (Arc Storm, Hellstorm, Void Tear)
- Railgun impact sparks
- All effects at "12/10" spectacle level

### Audio: READY
- Procedural melodic sounds (pentatonic scale)
- All weapon sounds
- Base weapon sounds (hellstorm warning, arc storm, void tear)
- Explosion sounds (size-scaled)
- UI feedback sounds

### Core Gameplay: READY
- 3-faction automated combat
- 7 ship types with distinct roles
- Rock-paper-scissors weapon system
- Strategic point capture
- Fleet doctrine customization
- Base weapons with charge system

### The Cycle (Progenitor): NEEDS POLISH
- Convergence phases work
- Gravitational pull works
- Visual effects need verification
- Victory/defeat states need testing

---

## Polish Priorities (This Week)

### P0: Must Fix Before Ship

1. **Test The Progenitor sequence end-to-end**
   - Verify all phases trigger correctly
   - Check victory/defeat messaging
   - Ensure clean restart after cycle ends

2. **Performance check on stressed scenarios**
   - 50+ ships on screen
   - Multiple Hellstorm impacts
   - World expansion transitions

3. **Main menu flow**
   - Start game works cleanly
   - Return to menu works
   - Settings persist (audio volume)

### P1: Should Polish

1. **Victory screen enhancement**
   - Faction-colored tint
   - Win statistics (ships built, destroyed)
   - Clean transition to restart

2. **Tutorial/onboarding**
   - Brief text explaining the game on first launch
   - Highlight rally point mechanic
   - Explain base weapons

3. **Audio balance pass**
   - Mix volumes so nothing overpowers
   - Ensure no audio clipping on intense battles

### P2: Nice to Have

1. **Ambient mode toggle**
   - Hide UI with keypress
   - Pure spectacle viewing

2. **Speed controls**
   - 0.5x, 1x, 2x buttons
   - Pause functionality

3. **Battle statistics**
   - Ships lost per faction
   - Damage dealt
   - Post-battle summary

---

## What to Cut

If running out of time, cut these in order:

1. **Outpost building** - not critical to core loop
2. **Named ship deaths** - emotional but not gameplay
3. **Galaxy map** - future expansion content
4. **Speed controls** - can add post-launch

---

## Technical Checklist

### Before Ship

- [ ] Run on clean install (no dev dependencies)
- [ ] Test on target platforms
- [ ] Check memory usage over 10+ minute session
- [ ] Verify no orphaned nodes accumulating
- [ ] Confirm all audio plays correctly
- [ ] Test restart after victory/defeat cycles

### Known Issues to Track

| Issue | Severity | Workaround |
|-------|----------|------------|
| Hellstorm creates many nodes | Medium | Rate limiting exists |
| Camera can drift on long sessions | Low | Restart resets |
| PDC intercept visual sometimes delayed | Low | Gameplay works |

---

## Shipping Milestones

### Day 1-2: Core Testing
- Full playthrough testing
- Fix any blocking bugs
- Performance profiling

### Day 3-4: Polish Pass
- Victory/defeat flow
- Audio balance
- Visual consistency

### Day 5: Final Testing
- Fresh install test
- Platform compatibility
- Final bug fixes

### Day 6: Prep Release
- Build final executable
- Write release notes
- Prepare distribution

### Day 7: Ship
- Release
- Monitor for critical issues
- Celebrate

---

## Release Scope: "VNP 1.0 - The Spectacle"

**What it is:**
- Beautiful automated space battle viewer
- Three factions in endless conflict
- Player can influence via rally points and base weapons
- The Progenitor arrives to shake things up

**What it's NOT (yet):**
- Campaign mode
- Ship customization
- Multiplayer
- Roguelite progression

**Tagline:** "Watch the stars burn. Direct the carnage."

---

## Post-Launch Roadmap

### v1.1 - Quality of Life
- Speed controls
- Ambient mode
- Statistics tracking

### v1.2 - Emotional Depth
- Named ships
- Death notifications
- Memorial mode

### v1.3 - Strategic Expansion
- Outpost building
- Factory system
- Territory control

### v2.0 - The Campaign
- Galaxy map
- Roguelite progression
- Unlockable ships

---

*Created: December 2024*
*Target Ship: Within 1 week*
