# FCW Changelog

Append-only log of changes to the FCW game.

---

## 2025-12-24
- Added: Capital ship fleet transfer mechanic - ships take portion of frigates when departing
- Added: Fleet roster click-to-select UI - click ship name to select, click zone to send
- Added: Ship location/destination display in roster (`@ Mars`, `→ Earth`)
- Added: Escort count display in roster (`+5` frigates)
- Added: Route preview bezier curves for selected entities
- Added: Detection probability zone visualization (concentric rings around Herald)
- Changed: Ships now orbit within zone visual (0.7x radius instead of outside)
- Fixed: Speed label width prevents UI layout shift
- Fixed: Zone signature calculation bug - was accumulating unbounded (showed 7699%), now clamped 0-100%
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
