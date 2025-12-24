# Documentation Governance & Audit Process

**Version:** 1.0
**Status:** Active
**Owner:** Development Team

## 1.0 Philosophy

This document outlines the official process for maintaining the health, accuracy, and relevance of SpaceProbe's documentation. Our documentation is treated as a living part of the codebase ("Docs as Code"). It is not a static artifact but a dynamic resource that must evolve with the project.

The primary goals are:
1. **Document before implementing** - Force clarity of thought before coding
2. **Update after implementing** - Preserve what was actually built
3. **Combat documentation entropy** - Prevent docs from becoming outdated and untrustworthy

A clean, timely, and well-governed documentation repository is critical for LLM session continuity, design iteration, and maintaining the "Documentation First" development philosophy.

## 2.0 Information Architecture

All documentation lives within `/docs`. A document's location signals its purpose and expected "liveness."

```
docs/
├── DOCUMENTATION.md              # This file - governance guide
├── game-design.md                # Cross-game vision (Evergreen)
│
├── games/                        # Per-game documentation
│   ├── mot/                      # Mars Odyssey Trek
│   │   ├── design.md             # Source of truth (Living)
│   │   ├── research/             # Exploration (Evergreen)
│   │   ├── projects/             # Active work (Transient)
│   │   └── notes/                # Decisions, sessions (Immutable)
│   ├── fcw/                      # First Contact War
│   ├── vnp/                      # Von Neumann Probe
│   └── mcs/                      # Mars Colony Sim
│
├── shared/                       # Cross-game documentation
│   ├── research/                 # Multi-game research (Evergreen)
│   ├── projects/                 # Engine/infrastructure (Transient)
│   └── architecture/             # System architecture (Living)
│
├── principles/                   # How we work (Evergreen)
├── reference/                    # Lookup tables (Living)
└── archive/                      # Historical artifacts (Immutable)
```

### 2.1 Directory Definitions

#### `docs/games/{game}/` (Per-Game)

Each game has its own documentation home with consistent subdirectories:

| Subdirectory | Content | Liveness |
|--------------|---------|----------|
| `design.md` | Single source of truth for how the game works NOW | **Living** - must reflect current implementation |
| `research/` | Exploration before decisions, external references, competitive analysis | **Evergreen** - stable once written |
| `projects/` | Active implementation work from design through completion | **Transient** - archived when complete |
| `notes/` | Decisions log, session notes, changelog | **Immutable** - append-only, never edited |

#### `docs/shared/` (Cross-Game)

| Subdirectory | Content | Liveness |
|--------------|---------|----------|
| `research/` | Research applicable to multiple games or engine-level concerns | **Evergreen** |
| `projects/` | Engine infrastructure, shared systems, tooling | **Transient** |
| `architecture/` | System architecture, data flow, technical patterns | **Living** |

#### `docs/principles/` (Evergreen)

Foundational standards and philosophies that define how we work.
- `engineering-principles.md`
- `godot-performance.md`
- `llm-development.md`
- `godot-architecture.md`

Reviewed annually or when core principles evolve. Changes require explicit justification.

#### `docs/reference/` (Living)

Lookup tables, catalogs, and schema documentation.
- `events-catalog.md`
- `crew-roster.md`
- `data-schema.md`

Must be updated when referenced content changes.

#### `docs/archive/` (Immutable)

Read-only library of historically significant but now-obsolete documents.
- Completed project plans
- Superseded architectural docs
- Historical audit reports
- Subdirectories: `archive/projects/`, `archive/notes/`, `archive/research/`

Documents here are frozen and must not be modified.

### 2.2 Liveness Definitions

| Level | Meaning | Update Frequency |
|-------|---------|------------------|
| **Evergreen** | Stable foundational content | Rarely; when principles change |
| **Living** | Must reflect current reality | Whenever implementation changes |
| **Transient** | Active during specific work | Daily during active work; archived when done |
| **Immutable** | Historical record | Never modified after creation |

## 3.0 Document Templates

### 3.1 Research Document (`research/`)

**Purpose**: Explore ideas before committing to a direction.
**When to create**: When you need to understand something before designing.
**Naming**: `{topic}-research.md`

```markdown
# {Topic} Research

**Created:** YYYY-MM-DD
**Status:** [Active | Incorporated | Archived]

## Question
What are we trying to understand?

## Findings
- Finding 1
- Finding 2

## Sources
- [Source 1](url)
- [Source 2](url)

## Implications
What does this mean for our design?

## Recommendation
Based on this research, we should...
```

### 3.2 Project Document (`projects/`)

**Purpose**: Track active implementation work from design through completion.
**When to create**: When starting any work touching 3+ files or taking more than an hour.
**Naming**: `{feature-name}.md` or `YYYY-MM-DD_{feature-name}.md`

```markdown
# {Project Name}

**Status:** [Planning | In Progress | Blocked | Complete | Archived]
**Created:** YYYY-MM-DD
**Last Updated:** YYYY-MM-DD

## Dependencies
- **Blocked by:** [List projects that must complete first, or "Nothing"]
- **Enables:** [List projects that depend on this completing]
- **Related:** [List related projects]

---

## Goal
One sentence describing what we're building and why.

## Design

### Requirements
- Requirement 1
- Requirement 2

### Approach
How we'll implement this.

### Files Affected
- `path/to/file.gd` - What changes

## Implementation Log

### YYYY-MM-DD
- What was done
- Decisions made
- Issues encountered

## Completion Checklist
- [ ] Code implemented
- [ ] Tests written (if applicable)
- [ ] Design doc updated
- [ ] balance.json updated (if applicable)
- [ ] Archived project doc
```

### 3.3 Design Document (`design.md`)

**Purpose**: Single source of truth for how a game works RIGHT NOW.
**One per game**: This is the canonical reference.
**When to update**: After implementing changes, never before.

```markdown
# {Game Name} Design

**Last Updated:** YYYY-MM-DD

## Overview
What is this game? Core loop in one paragraph.

## Core Mechanics

### {Mechanic 1}
How it works (not how to implement it).

### {Mechanic 2}
...

## Systems Reference

### {System 1}
Current behavior, values, formulas.

## UI/UX
What the player sees and does.

## Balance
Key numbers and their rationale.

## Known Issues / Future Work
What's not working or planned (brief - details in projects/).
```

**Key rule**: Design docs describe WHAT IS, not what might be.

### 3.4 Notes (`notes/`)

**Purpose**: Capture decisions and session context as immutable records.

#### `decisions.md` (append-only)

```markdown
# Decisions Log

## YYYY-MM-DD: {Decision Title}

**Context**: What situation prompted this decision?

**Options Considered**:
1. Option A - pros/cons
2. Option B - pros/cons

**Decision**: We chose Option A because...

**Consequences**: What this means going forward.

---

## YYYY-MM-DD: {Next Decision}
...
```

#### `changelog.md` (append-only)

```markdown
# Changelog

## YYYY-MM-DD
- Added: {feature}
- Changed: {what and why}
- Fixed: {bug}
- Removed: {feature}

## YYYY-MM-DD
...
```

#### `session-{date}.md` (optional)

For preserving LLM session context or meeting notes.

## 4.0 Documentation Workflow

### 4.1 Starting New Work

1. **Check research**: Is there existing research on this topic?
2. **Create project doc**: Document the design BEFORE coding
3. **Get alignment**: Review design (explicit approval or LLM prompt review)
4. **Implement**: Write code
5. **Update design doc**: Record what was actually built
6. **Log decision**: Add significant choices to `notes/decisions.md`
7. **Archive project**: Move completed project doc to `archive/projects/`

### 4.2 During Implementation

- Update project doc's Implementation Log as you go
- Note any deviations from original design
- Record blockers and how they were resolved

### 4.3 After Implementation

1. Mark project status as Complete
2. Update `design.md` with new/changed mechanics
3. Update `notes/changelog.md`
4. Move project doc to `archive/projects/`
5. Archive any research that's now fully incorporated

## 5.0 Documentation Audit Process

To ensure "Living" documents remain accurate, periodic audits should be conducted.

### 5.1 Identify Stale Documents

A document is "stale" if:
- It's in a Living directory (`design.md`, `reference/`, `architecture/`)
- It hasn't been modified in 30+ days
- Code it references has changed

### 5.2 Review and Validate ("Reality Check")

For each stale document, validate:
1. **Existence**: Do the described systems/mechanics still exist?
2. **Accuracy**: Does the description match current implementation?
3. **Completeness**: Is anything missing that's been added?
4. **Relevance**: Is this still strategically relevant?

### 5.3 Take Action

| Action | When | How |
|--------|------|-----|
| **UPDATE** | Document is relevant but inaccurate | Update to reflect current state |
| **ARCHIVE** | Document is complete/superseded but historically valuable | Move to `archive/` |
| **DEPRECATE** | Document describes replaced system but may still be referenced | Add deprecation banner, link to replacement |
| **DELETE** | Document is ephemeral with no lasting value | Remove from repository |

**Deprecation Banner**:
```markdown
---
**⚠️ DEPRECATED:** This document describes a legacy system. See [{new-doc}]({link}) instead.
---
```

## 6.0 Responsibilities

- **Document Owner**: Feature/system owner also owns its documentation
- **Author/Committer**: Code changes require corresponding doc updates in the same commit/session
- **LLM Sessions**: Update docs as part of completing any implementation task

**Docs are part of the Definition of Done.**

## 7.0 Migration Plan

Current docs need reorganization to match this structure:

### Phase 1: Create Structure
```bash
mkdir -p docs/games/{mot,fcw,vnp,mcs}/{research,projects,notes}
mkdir -p docs/shared/{research,projects,architecture}
mkdir -p docs/archive/{projects,notes,research}
```

### Phase 2: Migrate Existing Docs

| From | To |
|------|-----|
| `docs/mot/*` | `docs/games/mot/` |
| `docs/vnp/*` | `docs/games/vnp/` |
| `docs/expansions/first-contact-war.md` | `docs/games/fcw/design.md` |
| `docs/expansions/fcw-*.md` | `docs/games/fcw/` |
| `docs/expansions/von-neumann-probe.md` | `docs/games/vnp/design.md` |
| `docs/expansions/mars-colony-sim.md` | `docs/games/mcs/design.md` |
| `docs/expansions/mcs-*.md` | `docs/games/mcs/` |
| `docs/projects/vnp-*.md` | `docs/games/vnp/projects/` |
| `docs/projects/mcs-*.md` | `docs/games/mcs/projects/` |
| `docs/projects/phase-*.md` | `docs/shared/projects/` |
| `docs/architecture/*` | `docs/shared/architecture/` |
| `docs/design-research/*` | `docs/shared/research/` |
| `docs/research/*` | `docs/shared/research/` |

### Phase 3: Update CLAUDE.md
Update key documentation table to reference new locations.

## 8.0 Quick Reference

| I want to... | Create/Update |
|--------------|---------------|
| Explore an idea | `games/{game}/research/{topic}-research.md` |
| Start implementing | `games/{game}/projects/{feature}.md` |
| Record current state | `games/{game}/design.md` |
| Log a decision | `games/{game}/notes/decisions.md` |
| Track changes | `games/{game}/notes/changelog.md` |
| Document engine work | `shared/projects/{feature}.md` |
| Archive completed work | `archive/projects/{feature}.md` |

## 9.0 Anti-Patterns

| Don't | Do |
|-------|-----|
| Write design docs describing aspirational features as if they exist | Mark sections as "Planned" or keep in project docs until implemented |
| Let research docs rot | Incorporate findings into design, then archive |
| Create docs for trivial changes | Use project docs for 3+ files or 1+ hour work |
| Forget to update design.md after shipping | Make "update design doc" part of completion checklist |
| Edit immutable docs (notes, archive) | Create new entries; append, don't modify |
