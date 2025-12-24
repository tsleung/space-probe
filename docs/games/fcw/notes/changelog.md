# FCW Changelog

Append-only log of changes to the FCW game.

---

## 2025-12-24 (Second Session)
- Added: Map zoom with mouse wheel/trackpad - zoom toward cursor position, zoom out returns to default (1.0-4.0x range)
- Changed: Battle duration doubled from 1.0 to 2.0 seconds per phase for smaller fleet sizes
- Fixed: Zone signature display bug - was showing 7699% due to unbounded population accumulation in `fcw_herald_ai.gd:update_zone_signatures()`, now properly clamped (population max 0.15 baseline, final signature 0.0-1.0)
- Fixed: Click handling in route selection mode - clicking Mars was selecting ships at Mars instead of the zone, entity clicks now skipped when in route selection mode
- Fixed: "UNDER ATTACK" label showing prematurely - now shows "INCOMING" when Herald is approaching vs "UNDER ATTACK" when Herald has arrived
- Fixed: ORDERS system (GO DARK, MAX EVAC, BLOCKADE) - was using old `zone.assigned_fleet` system incompatible with capital ship entities:
  - GO DARK: Now switches all burning entities to COASTING (slower but stealthy)
  - MAX EVAC: Now finds Carrier entities and dispatches them to Earth using entity system
  - BLOCKADE: Now finds Cruiser/Dreadnought entities and dispatches them to Mars using entity system

## 2025-12-24 (First Session)
- Added: Capital ship fleet transfer mechanic - ships take portion of frigates when departing
- Added: Fleet roster click-to-select UI - click ship name to select, click zone to send
- Added: Ship location/destination display in roster (`@ Mars`, `→ Earth`)
- Added: Escort count display in roster (`+5` frigates)
- Added: Route preview bezier curves for selected entities
- Added: Detection probability zone visualization (concentric rings around Herald)
- Changed: Ships now orbit within zone visual (0.7x radius instead of outside)
- Fixed: Speed label width prevents UI layout shift
- Removed: "Assign" buttons - ships now travel with capital ships instead of teleporting
- Updated: GUT tests for combat, evacuation, and victory tier systems
- Updated: balance.json aligned with design doc victory tiers

---

## 2024-12-23
- Added: Core design philosophy in CLAUDE.md
- Added: Detection visualization with multi-layered energy field
- Added: Timeline pressure display in header
- Added: Traffic pattern visualization with flowing particles
- Added: Zone detection labels with color-coded probability
- Changed: Reorganized documentation under `docs/games/fcw/`
- Added: `decisions.md` and `changelog.md` in notes/

---

## Template for New Entries

```markdown
## YYYY-MM-DD
- Added: {new feature or content}
- Changed: {modifications to existing functionality}
- Fixed: {bug fixes}
- Removed: {deprecated or deleted features}
```
