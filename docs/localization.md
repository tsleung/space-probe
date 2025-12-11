# Localization Plan

How Space Probe will support multiple languages. Simple, scalable, classroom-ready.

---

## Design Principles

### Text-Only Localization (Core)

**What we localize:**
- All UI text
- Event descriptions and choices
- Crew dialogue
- Tutorial text
- Menu items

**What we DON'T localize (saves money/time):**
- Voice acting (we have none)
- Embedded text in images (avoid this in design)
- Sound effects
- Music

### Classroom Priority

Target languages based on:
1. US classroom demographics
2. Global educational markets
3. Feasibility of translation

### Design for Localization

Build localization-friendly from the start:
- No hardcoded strings
- Flexible UI layouts
- Avoid idioms and puns
- Use placeholder systems for variables

---

## Target Languages

### Tier 1: Launch Languages

| Language | Code | Reason |
|----------|------|--------|
| English (US) | en-US | Primary development language |
| Spanish | es | Large US student population, Latin America |
| French | fr | Canada, parts of US, Africa |
| German | de | Strong European market |
| Simplified Chinese | zh-CN | Large global market |

### Tier 2: Post-Launch Priority

| Language | Code | Reason |
|----------|------|--------|
| Portuguese (BR) | pt-BR | Large Brazilian market |
| Japanese | ja | Strong gaming market |
| Korean | ko | Strong gaming market |
| Italian | it | European coverage |
| Polish | pl | Large gaming audience |

### Tier 3: Community Interest

| Language | Code | Reason |
|----------|------|--------|
| Russian | ru | Large gaming community |
| Arabic | ar | Educational markets (RTL support needed) |
| Traditional Chinese | zh-TW | Taiwan, Hong Kong |
| Dutch | nl | Northern Europe |
| Turkish | tr | Growing market |

---

## Text Architecture

### String Key System

All text stored by key, not embedded:

```json
// data/text/en-US.json
{
  "ui": {
    "menu": {
      "new_game": "New Mission",
      "continue": "Continue",
      "settings": "Settings",
      "quit": "Quit"
    },
    "common": {
      "confirm": "Confirm",
      "cancel": "Cancel",
      "back": "Back",
      "help": "Help"
    }
  },
  "phase1": {
    "title": "Ship Construction",
    "budget_label": "Budget Remaining",
    "days_label": "Days Until Launch Window"
  }
}
```

### Variable Substitution

Use placeholders for dynamic content:

```json
{
  "events": {
    "resource_low": "{resource} is running low. Only {amount} {unit} remaining.",
    "crew_assigned": "{crew_name} has been assigned to {task}.",
    "days_remaining": "{count} days until {milestone}"
  }
}
```

**Code usage:**
```gdscript
var text = tr("events.resource_low").format({
    "resource": tr("resources.food"),
    "amount": 45,
    "unit": tr("units.kg")
})
```

### Pluralization

Handle singular/plural correctly:

```json
{
  "plurals": {
    "days": {
      "one": "{count} day",
      "other": "{count} days"
    },
    "crew_members": {
      "one": "{count} crew member",
      "other": "{count} crew members"
    }
  }
}
```

Different languages have different plural rules (Russian has 3 forms, Arabic has 6).

### Gendered Text

Some languages require gender agreement:

```json
{
  "crew": {
    "status_healthy": {
      "masculine": "{name} está sano",
      "feminine": "{name} está sana"
    }
  }
}
```

Crew data includes gender for proper agreement.

---

## UI Considerations

### Text Expansion

Translated text is often longer than English:

| Language | Expansion Factor |
|----------|-----------------|
| English | 1.0x (baseline) |
| German | 1.3x |
| French | 1.2x |
| Spanish | 1.25x |
| Russian | 1.3x |
| Japanese | 0.9x (but needs more height) |
| Chinese | 0.8x (but needs more height) |

**Design rules:**
- Buttons: Allow 30% extra width
- Labels: Allow 50% extra width
- Use truncation with tooltip for overflow
- Test layouts in German (longest common language)

### Font Support

**Requirements by language:**

| Script | Font Requirement |
|--------|------------------|
| Latin (EN, ES, FR, DE) | Standard fonts work |
| Cyrillic (RU) | Needs Cyrillic glyphs |
| Chinese/Japanese | CJK font (large file) |
| Korean | Hangul font |
| Arabic | RTL + Arabic glyphs |

**Strategy:**
- Use Unicode-capable fonts
- Load language-specific fonts on demand
- Consider separate builds for CJK (large fonts)

### Right-to-Left (RTL) Support

For Arabic, Hebrew:
- Mirror entire UI layout
- Text alignment flips
- Progress bars fill right-to-left
- Navigation order reverses

**Implementation:** Design with RTL in mind, use Godot's RTL support.

---

## Content Organization

### File Structure

```
data/
└── text/
    ├── en-US/
    │   ├── ui.json
    │   ├── events.json
    │   ├── crew.json
    │   ├── components.json
    │   └── tutorial.json
    ├── es/
    │   ├── ui.json
    │   ├── events.json
    │   └── ...
    └── [language]/
        └── ...
```

### String Categories

| Category | File | Example Content |
|----------|------|-----------------|
| UI | ui.json | Buttons, labels, menus |
| Events | events.json | Event text, choices |
| Crew | crew.json | Names, dialogue, traits |
| Components | components.json | Ship part descriptions |
| Tutorial | tutorial.json | Onboarding text |
| Help | help.json | Help topics, tooltips |

### Keeping Text in Sync

**Master file:** en-US is the source of truth

**Translation workflow:**
1. New text added to en-US
2. Automated tool flags missing keys in other languages
3. Translators fill in missing text
4. QA checks for completeness and fit

---

## Translation Process

### Who Translates

**Options (by quality/cost):**

| Method | Quality | Cost | Speed |
|--------|---------|------|-------|
| Professional agency | High | $$$ | Slow |
| Freelance translators | Medium-High | $$ | Medium |
| Community volunteers | Variable | Free | Slow |
| Machine + human edit | Medium | $ | Fast |

**Recommended:** Start with machine translation (DeepL/Google) for drafts, then professional review for Tier 1 languages.

### Translation Guidelines Document

Provide translators with:

```markdown
# Space Probe Translation Guide

## Tone
- Professional but accessible
- 8th grade reading level
- Serious about science, light in tone

## Technical Terms
- "EVA" = Extravehicular Activity (explain once, then use acronym)
- "Sol" = A day on Mars (don't translate)
- Keep unit abbreviations (kg, km, W)

## Character Voice
- Santos: Professional, clipped sentences
- Chen: Dry humor, technical
- Okonkwo: Warm, optimistic
- Kowalski: Eager, sometimes nervous

## Constraints
- Button text: Max 15 characters if possible
- Tooltips: Max 200 characters
- Event choices: Keep similar length for visual balance

## Context
Screenshots and gameplay videos provided for context.
```

### Review Process

1. **Translation:** Translator completes initial pass
2. **Technical Review:** Developer checks variables, length
3. **Native Review:** Native speaker checks naturalness
4. **In-Game Review:** Test in actual game context
5. **QA:** Bug testing with localized text

---

## Quality Assurance

### Automated Checks

```gdscript
# Run during build
func validate_localization():
    var master = load_language("en-US")
    var errors = []

    for lang in get_all_languages():
        var trans = load_language(lang)

        # Check for missing keys
        for key in master.keys():
            if not trans.has(key):
                errors.append("%s missing key: %s" % [lang, key])

        # Check for broken placeholders
        for key in trans.keys():
            if not validate_placeholders(master[key], trans[key]):
                errors.append("%s broken placeholder: %s" % [lang, key])

    return errors
```

### Manual Testing Checklist

- [ ] All text displays correctly (no missing glyphs)
- [ ] No text overflow/truncation issues
- [ ] Variables populate correctly
- [ ] Pluralization works
- [ ] Gender agreement correct (where applicable)
- [ ] Cultural references appropriate
- [ ] No embarrassing mistranslations

### Pseudo-Localization

For testing without real translations:

```
English: "Press Start to begin"
Pseudo:  "[Þŕêśś Śţàŕţ ţö ƀêĝïñ]" (adds 30% length + accents)
```

Helps find:
- Hardcoded strings (they won't have accents)
- Layout overflow issues
- Character encoding problems

---

## Cultural Considerations

### Date/Time Formats

| Region | Date | Time |
|--------|------|------|
| US | MM/DD/YYYY | 12-hour (AM/PM) |
| Europe | DD/MM/YYYY | 24-hour |
| ISO | YYYY-MM-DD | 24-hour |

**Solution:** Use "Day 47" and "Sol 23" format to avoid date confusion.

### Number Formats

| Region | Number | Currency |
|--------|--------|----------|
| US | 1,234.56 | $1,234 |
| Germany | 1.234,56 | 1.234 € |
| France | 1 234,56 | 1 234 € |

**Solution:**
- Use locale-aware formatting
- Budget displays adapt to locale
- Scientific notation where appropriate

### Cultural Sensitivity

**Review for:**
- Gestures that mean different things in different cultures
- Colors with cultural significance
- Historical/political sensitivities
- Religious considerations

**Our game's advantages:**
- Near-future setting (less historical baggage)
- International crew (built-in diversity)
- Space focus (universal human aspiration)

---

## Technical Implementation

### Godot Integration

```gdscript
# Setting language
TranslationServer.set_locale("es")

# Getting translated text
var text = tr("ui.menu.new_game")

# With formatting
var text = tr("events.days_remaining").format({"count": 5, "milestone": tr("milestones.mars")})
```

### Language Selection

```
Settings > Language
┌─────────────────────────────────────┐
│ Language / Idioma / 语言            │
├─────────────────────────────────────┤
│ ● English (US)                      │
│ ○ Español                           │
│ ○ Français                          │
│ ○ Deutsch                           │
│ ○ 简体中文                           │
│                                     │
│ [✓] Auto-detect from system         │
└─────────────────────────────────────┘
```

### Loading Strategy

**Small languages (Latin script):**
- Include all in base game
- Instant switching

**Large languages (CJK):**
- Download on first selection
- Cache locally
- Show download progress

---

## Maintenance

### Ongoing Translation

When new content is added:

1. Add to en-US files
2. Mark new keys as "needs translation" in tracker
3. Batch translation requests weekly
4. Review and integrate
5. Release with next update

### Community Contributions

**For Tier 3 languages:**
- Provide translation template
- Accept community submissions
- Credit contributors
- Have native speaker review before shipping

**Tools:**
- Crowdin, Lokalise, or similar platform
- Or simple spreadsheet for small scope

### Version Control

- Track all text changes in git
- Tag releases with language versions
- Maintain changelog for translators

---

## Budget Considerations

### Cost Estimates (Rough)

| Item | Cost per Word | Notes |
|------|---------------|-------|
| Professional translation | $0.10-0.20 | Per language |
| Native review | $0.05-0.10 | Per language |
| Machine + human edit | $0.03-0.05 | Per language |

**Word count estimate:** 15,000-25,000 words total

**Per language cost:** $750-5,000 depending on method

### Prioritization

1. **Launch:** English only (free)
2. **Month 1-3:** Spanish, French (highest ROI for US classrooms)
3. **Month 3-6:** German, Chinese (broader market)
4. **Ongoing:** Community translations for others

---

## Implementation Checklist

### Pre-Development
- [ ] Set up translation file structure
- [ ] Create string key convention
- [ ] Document translation guidelines
- [ ] Choose translation management tool

### During Development
- [ ] No hardcoded strings
- [ ] All UI allows text expansion
- [ ] Use placeholder variables
- [ ] Test with pseudo-localization

### Pre-Launch
- [ ] Complete Tier 1 translations
- [ ] QA all supported languages
- [ ] Test on different system locales
- [ ] Verify font rendering

### Post-Launch
- [ ] Monitor community requests
- [ ] Batch translation updates
- [ ] Accept community contributions
- [ ] Track language-specific bugs

---

## Reference

### Godot Localization Docs
- https://docs.godotengine.org/en/stable/tutorials/i18n/

### Tools
- **Lokalise:** Translation management platform
- **Crowdin:** Community translation platform
- **POEditor:** Affordable for indie projects
- **Google Sheets:** Simple, free option for small scope

### Standards
- **ICU Message Format:** For complex pluralization
- **CLDR:** Unicode locale data
- **BCP 47:** Language tag standard (en-US, zh-CN, etc.)

