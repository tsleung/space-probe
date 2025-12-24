extends RefCounted
class_name MCSTypes

## MCS (Mars Colony Sim) Data Types
## Defines all data structures for the colony simulation expansion
## Uses Dictionary factories following existing GameTypes pattern

# ============================================================================
# ENUMS
# ============================================================================

enum ColonyPhase {
	ACT_1_FOUNDERS,      # Years 1-5: Desperate survival
	ACT_2_SETTLEMENT,    # Years 6-20: Growth and politics
	ACT_3_COLONY,        # Years 21-50: Mature colony
	ACT_4_INDEPENDENCE   # Years 51-100: Nation building
}

enum Generation {
	EARTH_BORN,          # Born on Earth, immigrated
	FIRST_GEN,           # Born on Mars, parents from Earth
	SECOND_GEN,          # Parents born on Mars
	THIRD_GEN_PLUS       # Grandparents+ born on Mars
}

enum LifeStage {
	INFANT,      # 0-2
	CHILD,       # 3-12
	ADOLESCENT,  # 13-17
	ADULT,       # 18-60
	ELDER        # 61+
}

enum ColonistTrait {
	# Disposition
	OPTIMIST, PESSIMIST, STOIC, PASSIONATE,
	# Social
	INTROVERT, EXTROVERT, EMPATHETIC, RESERVED,
	# Work Style
	PERFECTIONIST, PRAGMATIST, METHODICAL, CREATIVE,
	# Stress Response
	STEADY_HANDS, TUNNEL_VISION, ADRENALINE_JUNKIE, FREEZE_PRONE,
	# Moral Framework
	UTILITARIAN, PROTECTOR, BY_THE_BOOK, ENDS_JUSTIFY,
	# Special
	FOUNDERS_BLOOD, MARS_ADAPTED, EARTH_LONGING, VISIONARY
}

enum Specialty {
	NONE,
	ENGINEER,
	SCIENTIST,
	MEDIC,
	FARMER,
	ADMINISTRATOR,
	EDUCATOR,
	ARTIST,
	SECURITY,
	PILOT
}

enum Faction {
	NONE,
	EARTHERS,        # Strong Earth connection
	FOUNDERS,        # Original mission values
	MARTIANS,        # Mars independence
	PRAGMATISTS,     # Whatever works
	VISIONARIES      # Long-term terraforming
}

enum BuildingCategory {
	HOUSING,
	PRODUCTION,
	SERVICES,
	INFRASTRUCTURE,
	SPACE_ECONOMY,
	MEGASTRUCTURE
}

enum BuildingType {
	# === HOUSING (3) ===
	HABITAT,            # Standard living quarters (was HAB_POD + APARTMENT_BLOCK)
	BARRACKS,           # Dense but spartan housing
	QUARTERS,           # Luxury expensive housing

	# === PRODUCTION - Base Types (4) ===
	AGRIDOME,           # Food production (base, branches at T3)
	EXTRACTOR,          # Water + Oxygen (base, branches at T3)
	FABRICATOR,         # Materials + Parts (base, branches at T3)
	POWER_STATION,      # Energy (base, branches at T3)

	# === PRODUCTION - T3 Branches (8) ===
	# AGRIDOME branches:
	HYDROPONICS,        # Efficient food, needs electronics
	PROTEIN_VATS,       # Dense food, needs medicine
	# EXTRACTOR branches:
	ICE_MINER,          # Water focus, can produce fuel
	ATMO_PROCESSOR,     # Oxygen focus, terraforming
	# FABRICATOR branches:
	FOUNDRY,            # Building materials focus
	PRECISION,          # Machine parts focus
	# POWER_STATION branches:
	SOLAR_FARM,         # Cheap, weather-dependent
	REACTOR,            # Reliable, needs fuel, T5 fusion

	# === SERVICES (4) ===
	MEDICAL,            # Health + birth capacity (was MEDICAL_BAY + HOSPITAL)
	ACADEMY,            # Education + skills (was SCHOOL + UNIVERSITY)
	RESEARCH,           # Science + tech unlock (was LAB + RESEARCH_CENTER)
	RECREATION,         # Morale + culture (was RECREATION_CENTER + TEMPLE + etc)

	# === INFRASTRUCTURE (3) ===
	STORAGE,            # Resource stockpile
	COMMS,              # Earth connection, trade info (was COMMUNICATIONS)
	LOGISTICS,          # Transport hub, construction speed (was AIRLOCK + LANDING_PAD)

	# === SPACE ECONOMY (3) ===
	STARPORT,           # Gateway to orbit, immigration, trade
	ORBITAL,            # Space station, mass immigration (was SPACE_STATION)
	CATCHER,            # Asteroid mining, massive materials (was ASTEROID_CATCHER)

	# === MEGASTRUCTURES (3) ===
	MASS_DRIVER,        # Electromagnetic launcher
	FUSION_PLANT,       # Massive power (was FUSION_REACTOR)
	SPACE_ELEVATOR,     # Ultimate transport
}

# Specialization branch mappings: base type -> [branch1, branch2]
const SPECIALIZATION_BRANCHES = {
	BuildingType.AGRIDOME: [BuildingType.HYDROPONICS, BuildingType.PROTEIN_VATS],
	BuildingType.EXTRACTOR: [BuildingType.ICE_MINER, BuildingType.ATMO_PROCESSOR],
	BuildingType.FABRICATOR: [BuildingType.FOUNDRY, BuildingType.PRECISION],
	BuildingType.POWER_STATION: [BuildingType.SOLAR_FARM, BuildingType.REACTOR],
}

# Reverse mapping: branch -> base type
const BRANCH_TO_BASE = {
	BuildingType.HYDROPONICS: BuildingType.AGRIDOME,
	BuildingType.PROTEIN_VATS: BuildingType.AGRIDOME,
	BuildingType.ICE_MINER: BuildingType.EXTRACTOR,
	BuildingType.ATMO_PROCESSOR: BuildingType.EXTRACTOR,
	BuildingType.FOUNDRY: BuildingType.FABRICATOR,
	BuildingType.PRECISION: BuildingType.FABRICATOR,
	BuildingType.SOLAR_FARM: BuildingType.POWER_STATION,
	BuildingType.REACTOR: BuildingType.POWER_STATION,
}

# Category lookup
static func get_building_category(type: BuildingType) -> BuildingCategory:
	match type:
		BuildingType.HABITAT, BuildingType.BARRACKS, BuildingType.QUARTERS:
			return BuildingCategory.HOUSING
		BuildingType.AGRIDOME, BuildingType.EXTRACTOR, BuildingType.FABRICATOR, BuildingType.POWER_STATION, \
		BuildingType.HYDROPONICS, BuildingType.PROTEIN_VATS, BuildingType.ICE_MINER, BuildingType.ATMO_PROCESSOR, \
		BuildingType.FOUNDRY, BuildingType.PRECISION, BuildingType.SOLAR_FARM, BuildingType.REACTOR:
			return BuildingCategory.PRODUCTION
		BuildingType.MEDICAL, BuildingType.ACADEMY, BuildingType.RESEARCH, BuildingType.RECREATION:
			return BuildingCategory.SERVICES
		BuildingType.STORAGE, BuildingType.COMMS, BuildingType.LOGISTICS:
			return BuildingCategory.INFRASTRUCTURE
		BuildingType.STARPORT, BuildingType.ORBITAL, BuildingType.CATCHER:
			return BuildingCategory.SPACE_ECONOMY
		BuildingType.MASS_DRIVER, BuildingType.FUSION_PLANT, BuildingType.SPACE_ELEVATOR:
			return BuildingCategory.MEGASTRUCTURE
	return BuildingCategory.INFRASTRUCTURE

# Check if building type is a specialization branch
static func is_branch_type(type: BuildingType) -> bool:
	return BRANCH_TO_BASE.has(type)

# Check if building type can specialize at T3
static func can_specialize(type: BuildingType) -> bool:
	return SPECIALIZATION_BRANCHES.has(type)

enum ResourceType {
	# Primary (extracted)
	WATER_ICE, REGOLITH, IRON_ORE, ALUMINUM_ORE, RARE_EARTH, CO2,
	# Secondary (processed)
	WATER, OXYGEN, HYDROGEN, METHANE, IRON, ALUMINUM, PLASTIC,
	# Tertiary (manufactured)
	FOOD, MEDICINE, ELECTRONICS, MACHINE_PARTS, BUILDING_MATERIALS, FUEL,
	# Quaternary (luxury)
	ART, ENTERTAINMENT, COMFORT_ITEMS,
	# Economy
	CREDITS  # Trade currency with Earth
}

enum EventSeverity {
	MINOR,
	MODERATE,
	MAJOR,
	CRITICAL
}

enum PoliticalSystem {
	MISSION_COMMAND,     # Autocratic, early game
	ADVISORY_COUNCIL,    # Commander + advisors
	REPRESENTATIVE,      # Elected council
	CONSTITUTIONAL,      # Full democracy
	INDEPENDENT_STATE    # Sovereign nation
}

# ============================================================================
# BUILDING TIER SYSTEM - Production scales with tier, workers decrease
# ============================================================================

## Upgrade costs per tier transition (building_materials, machine_parts)
## Costs balanced to be achievable with 1-2 factories
const UPGRADE_COSTS = {
	2: {"building_materials": 25, "machine_parts": 10},
	3: {"building_materials": 50, "machine_parts": 20},
	4: {"building_materials": 80, "machine_parts": 40},
	5: {"building_materials": 120, "machine_parts": 60},  # Was 200/100 - too expensive!
}

## Time in years to complete each tier upgrade - FAST for optimal play
const UPGRADE_DURATIONS = {
	2: 1,   # 1 year to reach tier 2 (was 2)
	3: 1,   # 1 year to reach tier 3 (was 2)
	4: 2,   # 2 years to reach tier 4 (was 3)
	5: 2,   # 2 years to reach tier 5 (was 4)
}

## Tier-based stats: production scales UP, workers scale DOWN
## Key insight: Worker efficiency is the main driver for upgrades
## T3 is branching point for production buildings - choose specialization
const BUILDING_TIER_STATS = {
	# === HOUSING ===
	BuildingType.HABITAT: {  # Standard housing (was HAB_POD + APARTMENT_BLOCK)
		1: {"housing_capacity": 6, "power": 8},
		2: {"housing_capacity": 10, "power": 8},
		3: {"housing_capacity": 16, "power": 10},
		4: {"housing_capacity": 24, "power": 12},
		5: {"housing_capacity": 30, "power": 15},
	},
	BuildingType.BARRACKS: {  # Dense but spartan
		1: {"housing_capacity": 12, "morale_penalty": -5, "power": 10},
		2: {"housing_capacity": 20, "morale_penalty": -5, "power": 12},
		3: {"housing_capacity": 30, "morale_penalty": -3, "power": 14},
		4: {"housing_capacity": 40, "morale_penalty": -2, "power": 16},
		5: {"housing_capacity": 50, "morale_penalty": 0, "power": 18},
	},
	BuildingType.QUARTERS: {  # Luxury expensive
		1: {"housing_capacity": 3, "morale_boost": 5, "power": 12},
		2: {"housing_capacity": 5, "morale_boost": 8, "power": 12},
		3: {"housing_capacity": 8, "morale_boost": 12, "power": 14},
		4: {"housing_capacity": 12, "morale_boost": 18, "power": 15},
		5: {"housing_capacity": 15, "morale_boost": 25, "power": 15},
	},

	# === PRODUCTION BASE TYPES (T1-T2 only, must specialize at T3) ===
	BuildingType.AGRIDOME: {  # Food production base
		1: {"production": {"food": 600}, "power": 15, "workers": 2},
		2: {"production": {"food": 800}, "power": 14, "workers": 2},
		# T3+ requires specialization to HYDROPONICS or PROTEIN_VATS
	},
	BuildingType.EXTRACTOR: {  # Water + Oxygen base
		1: {"production": {"water": 400, "oxygen": 150}, "power": 20, "workers": 2},
		2: {"production": {"water": 550, "oxygen": 200}, "power": 19, "workers": 2},
		# T3+ requires specialization to ICE_MINER or ATMO_PROCESSOR
	},
	BuildingType.FABRICATOR: {  # Materials + Parts base
		1: {"production": {"machine_parts": 30, "building_materials": 40}, "power": 35, "workers": 3},
		2: {"production": {"machine_parts": 45, "building_materials": 60}, "power": 33, "workers": 3},
		# T3+ requires specialization to FOUNDRY or PRECISION
	},
	BuildingType.POWER_STATION: {  # Energy base
		1: {"power_gen": 60, "workers": 1},
		2: {"power_gen": 90, "workers": 1},
		# T3+ requires specialization to SOLAR_FARM or REACTOR
	},

	# === AGRIDOME BRANCHES ===
	BuildingType.HYDROPONICS: {  # Efficient food, needs electronics
		3: {"production": {"food": 1200}, "power": 20, "workers": 2, "consumes": {"electronics": 2}},
		4: {"production": {"food": 1800}, "power": 18, "workers": 1, "consumes": {"electronics": 3}},
		5: {"production": {"food": 2800}, "power": 15, "workers": 0, "consumes": {"electronics": 4}},
	},
	BuildingType.PROTEIN_VATS: {  # Dense food, needs medicine
		3: {"production": {"food": 1000}, "power": 18, "workers": 2, "consumes": {"medicine": 2}},
		4: {"production": {"food": 1600}, "power": 16, "workers": 1, "consumes": {"medicine": 2}},
		5: {"production": {"food": 2400}, "power": 14, "workers": 1, "consumes": {"medicine": 3}},
	},

	# === EXTRACTOR BRANCHES ===
	BuildingType.ICE_MINER: {  # Water focus, can produce fuel
		3: {"production": {"water": 900, "oxygen": 100, "fuel": 20}, "power": 22, "workers": 2},
		4: {"production": {"water": 1400, "oxygen": 120, "fuel": 40}, "power": 20, "workers": 1},
		5: {"production": {"water": 2200, "oxygen": 150, "fuel": 80}, "power": 18, "workers": 0},
	},
	BuildingType.ATMO_PROCESSOR: {  # Oxygen focus, terraforming
		3: {"production": {"water": 200, "oxygen": 500}, "power": 25, "workers": 2, "terraforming": 1},
		4: {"production": {"water": 250, "oxygen": 800}, "power": 22, "workers": 1, "terraforming": 2},
		5: {"production": {"water": 300, "oxygen": 1200}, "power": 20, "workers": 0, "terraforming": 5},
	},

	# === FABRICATOR BRANCHES ===
	BuildingType.FOUNDRY: {  # Building materials focus
		3: {"production": {"building_materials": 150, "machine_parts": 20}, "power": 40, "workers": 3},
		4: {"production": {"building_materials": 280, "machine_parts": 30}, "power": 38, "workers": 2},
		5: {"production": {"building_materials": 500, "machine_parts": 50}, "power": 35, "workers": 1},
	},
	BuildingType.PRECISION: {  # Machine parts focus
		3: {"production": {"machine_parts": 100, "building_materials": 30}, "power": 40, "workers": 3},
		4: {"production": {"machine_parts": 180, "building_materials": 40}, "power": 38, "workers": 2},
		5: {"production": {"machine_parts": 300, "building_materials": 60}, "power": 35, "workers": 1},
	},

	# === POWER_STATION BRANCHES ===
	BuildingType.SOLAR_FARM: {  # Cheap, weather-dependent
		3: {"power_gen": 140, "workers": 0, "weather_dependent": true},
		4: {"power_gen": 220, "workers": 0, "weather_dependent": true},
		5: {"power_gen": 350, "workers": 0, "weather_dependent": false},  # Orbital collection
	},
	BuildingType.REACTOR: {  # Reliable, needs fuel
		3: {"power_gen": 200, "workers": 2, "consumes": {"fuel": 10}},
		4: {"power_gen": 400, "workers": 1, "consumes": {"fuel": 15}},
		5: {"power_gen": 800, "workers": 1, "consumes": {"fuel": 0}},  # Fusion - no fuel!
	},

	# === SERVICES ===
	BuildingType.MEDICAL: {  # Health + birth capacity (was MEDICAL_BAY + HOSPITAL)
		1: {"health_boost": 8, "birth_capacity": 2, "power": 15, "workers": 2},
		2: {"health_boost": 15, "birth_capacity": 4, "power": 18, "workers": 2},
		3: {"health_boost": 25, "birth_capacity": 6, "power": 20, "workers": 2},
		4: {"health_boost": 40, "birth_capacity": 10, "power": 22, "workers": 1},
		5: {"health_boost": 60, "birth_capacity": 15, "power": 25, "workers": 1},
	},
	BuildingType.ACADEMY: {  # Education + skills (was SCHOOL + UNIVERSITY)
		1: {"education_capacity": 12, "skill_boost": 5, "power": 10, "workers": 2},
		2: {"education_capacity": 20, "skill_boost": 10, "power": 12, "workers": 2},
		3: {"education_capacity": 32, "skill_boost": 18, "power": 14, "workers": 2},
		4: {"education_capacity": 50, "skill_boost": 30, "power": 16, "workers": 1},
		5: {"education_capacity": 80, "skill_boost": 50, "power": 18, "workers": 1},
	},
	BuildingType.RESEARCH: {  # Science + tech unlock (was LAB + RESEARCH_CENTER)
		1: {"research_boost": 15, "power": 25, "workers": 2},
		2: {"research_boost": 28, "power": 28, "workers": 2},
		3: {"research_boost": 50, "power": 32, "workers": 2},
		4: {"research_boost": 85, "power": 35, "workers": 2},
		5: {"research_boost": 150, "power": 40, "workers": 1},
	},
	BuildingType.RECREATION: {  # Morale + culture (was RECREATION_CENTER + TEMPLE)
		1: {"morale_boost": 12, "power": 12, "workers": 1},
		2: {"morale_boost": 20, "power": 12, "workers": 1},
		3: {"morale_boost": 32, "power": 14, "workers": 1},
		4: {"morale_boost": 50, "power": 14, "workers": 0},
		5: {"morale_boost": 80, "power": 15, "workers": 0},
	},

	# === INFRASTRUCTURE ===
	BuildingType.STORAGE: {  # Resource stockpile
		1: {"storage_capacity": 2000, "power": 5, "workers": 0},
		2: {"storage_capacity": 4000, "power": 6, "workers": 0},
		3: {"storage_capacity": 8000, "power": 7, "workers": 0},
		4: {"storage_capacity": 15000, "power": 8, "workers": 0},
		5: {"storage_capacity": 30000, "power": 10, "workers": 0},
	},
	BuildingType.COMMS: {  # Earth connection (was COMMUNICATIONS)
		1: {"research_boost": 5, "morale_boost": 3, "trade_capacity": 50, "power": 12, "workers": 1},
		2: {"research_boost": 10, "morale_boost": 5, "trade_capacity": 100, "power": 12, "workers": 1},
		3: {"research_boost": 18, "morale_boost": 8, "trade_capacity": 180, "power": 14, "workers": 1},
		4: {"research_boost": 30, "morale_boost": 12, "trade_capacity": 300, "power": 14, "workers": 0},
		5: {"research_boost": 50, "morale_boost": 18, "trade_capacity": 500, "power": 15, "workers": 0},
	},
	BuildingType.LOGISTICS: {  # Transport hub (was AIRLOCK + LANDING_PAD)
		1: {"construction_speed": 1.1, "power": 15, "workers": 1},
		2: {"construction_speed": 1.2, "power": 16, "workers": 1},
		3: {"construction_speed": 1.35, "power": 18, "workers": 1},
		4: {"construction_speed": 1.5, "power": 20, "workers": 1},
		5: {"construction_speed": 1.8, "power": 22, "workers": 0},
	},

	# === SPACE ECONOMY ===
	BuildingType.STARPORT: {  # Gateway to orbit
		1: {"immigration_capacity": 3, "trade_capacity": 100, "power": 35, "workers": 2},
		2: {"immigration_capacity": 5, "trade_capacity": 180, "power": 35, "workers": 2},
		3: {"immigration_capacity": 8, "trade_capacity": 300, "power": 38, "workers": 2},
		4: {"immigration_capacity": 12, "trade_capacity": 500, "power": 40, "workers": 1},
		5: {"immigration_capacity": 18, "trade_capacity": 800, "power": 42, "workers": 1},
	},
	BuildingType.ORBITAL: {  # Space station (was SPACE_STATION)
		1: {"immigration_capacity": 8, "production": {"machine_parts": 30}, "power": 60, "workers": 3},
		2: {"immigration_capacity": 15, "production": {"machine_parts": 50}, "power": 58, "workers": 3},
		3: {"immigration_capacity": 25, "production": {"machine_parts": 80}, "power": 55, "workers": 2},
		4: {"immigration_capacity": 40, "production": {"machine_parts": 120}, "power": 50, "workers": 2},
		5: {"immigration_capacity": 60, "production": {"machine_parts": 180}, "power": 45, "workers": 1},
	},
	BuildingType.CATCHER: {  # Asteroid mining (was ASTEROID_CATCHER)
		1: {"production": {"building_materials": 350, "machine_parts": 60}, "power": 85, "workers": 4},
		2: {"production": {"building_materials": 600, "machine_parts": 100}, "power": 80, "workers": 4},
		3: {"production": {"building_materials": 1000, "machine_parts": 180}, "power": 75, "workers": 3},
		4: {"production": {"building_materials": 1600, "machine_parts": 300}, "power": 65, "workers": 2},
		5: {"production": {"building_materials": 2500, "machine_parts": 500}, "power": 55, "workers": 1},
	},

	# === MEGASTRUCTURES ===
	BuildingType.MASS_DRIVER: {  # Electromagnetic launcher
		1: {"export_capacity": 120, "power": 100, "workers": 4},
		2: {"export_capacity": 200, "power": 95, "workers": 4},
		3: {"export_capacity": 320, "power": 90, "workers": 3},
		4: {"export_capacity": 500, "power": 85, "workers": 2},
		5: {"export_capacity": 800, "power": 80, "workers": 1},
	},
	BuildingType.FUSION_PLANT: {  # Massive power (was FUSION_REACTOR)
		1: {"power_gen": 600, "workers": 3},
		2: {"power_gen": 900, "workers": 3},
		3: {"power_gen": 1400, "workers": 2},
		4: {"power_gen": 2200, "workers": 2},
		5: {"power_gen": 3500, "workers": 1},
	},
	BuildingType.SPACE_ELEVATOR: {  # Ultimate transport
		1: {"export_capacity": 250, "import_capacity": 80, "immigration_capacity": 10, "power": 160, "workers": 6},
		2: {"export_capacity": 400, "import_capacity": 130, "immigration_capacity": 18, "power": 150, "workers": 5},
		3: {"export_capacity": 600, "import_capacity": 200, "immigration_capacity": 30, "power": 140, "workers": 4},
		4: {"export_capacity": 900, "import_capacity": 300, "immigration_capacity": 50, "power": 125, "workers": 3},
		5: {"export_capacity": 1400, "import_capacity": 500, "immigration_capacity": 80, "power": 110, "workers": 2},
	},
}

## Get tier stats for a building type at a specific tier
static func get_tier_stats(building_type: BuildingType, tier: int) -> Dictionary:
	if not BUILDING_TIER_STATS.has(building_type):
		# Fallback for buildings without tier progression
		return {"tier": tier}

	var tier_data = BUILDING_TIER_STATS[building_type]
	tier = clampi(tier, 1, 5)
	if tier_data.has(tier):
		return tier_data[tier].duplicate(true)
	return {"tier": tier}

## Get upgrade cost for transitioning to a specific tier
static func get_upgrade_cost(target_tier: int) -> Dictionary:
	if UPGRADE_COSTS.has(target_tier):
		return UPGRADE_COSTS[target_tier].duplicate(true)
	return {}

## Get upgrade duration in years for transitioning to a specific tier
static func get_upgrade_duration(target_tier: int) -> int:
	if UPGRADE_DURATIONS.has(target_tier):
		return UPGRADE_DURATIONS[target_tier]
	return 2  # Default 2 years

## Check if a building type has tier progression defined
static func has_tier_progression(building_type: BuildingType) -> bool:
	return BUILDING_TIER_STATS.has(building_type)

# ============================================================================
# FACTORY FUNCTIONS - Colonist
# ============================================================================

static func create_colonist(overrides: Dictionary = {}) -> Dictionary:
	var colonist = {
		# Identity
		"id": _generate_id(),
		"first_name": "",
		"last_name": "",
		"nickname": "",
		"display_name": "",  # Full name for display (first + last or nickname)
		"age": 30,
		"birth_year": 0,
		"generation": Generation.EARTH_BORN,
		"life_stage": LifeStage.ADULT,

		# Stats (0-100)
		"health": 80.0,
		"morale": 70.0,
		"fatigue": 20.0,
		"radiation_exposure": 0.0,

		# Skills (0-100)
		"specialty": Specialty.NONE,
		"skill_level": 50.0,
		"secondary_skills": {},  # Specialty -> level
		"learning_rate": 1.0,

		# Personality
		"traits": [],  # Array of ColonistTrait
		"faction": Faction.NONE,
		"faction_loyalty": 50.0,

		# Relationships
		"spouse_id": "",
		"parent_ids": [],
		"child_ids": [],
		"relationships": {},  # colonist_id -> relationship value (-100 to 100)

		# Status
		"is_alive": true,
		"is_pregnant": false,
		"pregnancy_months": 0,
		"is_working": true,
		"current_job": "",
		"death_year": -1,
		"death_cause": "",

		# Story
		"backstory": "",
		"personal_goal": "",
		"secrets": [],
		"memories": [],  # Array of memory entries

		# Flags
		"is_founder": false,
		"is_leader": false,
		"has_had_quiet_moment": false
	}

	for key in overrides:
		colonist[key] = overrides[key]

	colonist.life_stage = _calc_life_stage(colonist.age)

	return colonist

static func _calc_life_stage(age: int) -> LifeStage:
	if age < 3:
		return LifeStage.INFANT
	elif age < 13:
		return LifeStage.CHILD
	elif age < 18:
		return LifeStage.ADOLESCENT
	elif age < 61:
		return LifeStage.ADULT
	else:
		return LifeStage.ELDER

# ============================================================================
# FACTORY FUNCTIONS - Buildings
# ============================================================================

static func create_building(overrides: Dictionary = {}) -> Dictionary:
	var building = {
		"id": _generate_id(),
		"type": BuildingType.HABITAT,
		"name": "",
		"position": Vector2i.ZERO,
		"hex_size": 1,

		# Stats
		"condition": 100.0,
		"efficiency": 100.0,
		"power_consumption": 0.0,
		"power_generation": 0.0,
		"tier": 1,  # 1-5, buildings upgrade over time (bigger, taller)

		# Capacity
		"housing_capacity": 0,
		"worker_capacity": 0,
		"storage_capacity": 0,

		# Production
		"produces": {},  # ResourceType -> amount per year
		"consumes": {},  # ResourceType -> amount per year

		# Status
		"is_operational": true,
		"is_under_construction": false,
		"construction_progress": 0.0,
		"construction_years": 1,

		# Workers
		"assigned_workers": [],  # colonist IDs
		"required_workers": 0,

		# Maintenance
		"maintenance_cost": {},  # ResourceType -> amount per year
		"last_maintained_year": 0
	}

	for key in overrides:
		building[key] = overrides[key]

	return building

# ============================================================================
# FACTORY FUNCTIONS - Resources
# ============================================================================

static func create_resource_stockpile(overrides: Dictionary = {}) -> Dictionary:
	# MINIMAL starting resources - you landed with supplies for ~1 year
	# Must build production infrastructure to survive!
	var stockpile = {
		# Primary (raw materials - must extract from Mars)
		"water_ice": 0.0,
		"regolith": 0.0,
		"iron_ore": 0.0,
		"aluminum_ore": 0.0,
		"rare_earth": 0.0,
		"co2": 0.0,

		# Secondary (basic processed - small landing cache)
		"water": 200.0,      # ~1 year for small crew (was 1000)
		"oxygen": 150.0,     # Emergency reserves (was 500)
		"hydrogen": 20.0,    # Minimal (was 100)
		"methane": 0.0,
		"iron": 0.0,
		"aluminum": 0.0,
		"plastic": 0.0,

		# Tertiary (goods - survival rations only)
		"food": 150.0,       # ~1 year emergency rations (was 500)
		"medicine": 15.0,    # First aid kit (was 50)
		"electronics": 5.0,  # Spare parts only (was 20)
		"machine_parts": 12.0,  # Just enough for 1 hab pod (was 30)
		"building_materials": 50.0,  # Enough for 1 hab pod (was 100)
		"fuel": 50.0,        # Landing reserves (was 200)

		# Quaternary (luxury - none at start!)
		"art": 0.0,
		"entertainment": 0.0,   # No luxuries (was 10)
		"comfort_items": 0.0,   # Survival mode (was 20)

		# Economy
		"credits": 0.0  # Trade currency (earned via exports)
	}

	for key in overrides:
		stockpile[key] = overrides[key]

	return stockpile

# ============================================================================
# FACTORY FUNCTIONS - Politics
# ============================================================================

static func create_political_state(overrides: Dictionary = {}) -> Dictionary:
	var politics = {
		"system": PoliticalSystem.MISSION_COMMAND,
		"authority_level": 10,  # 1-10, 10 = full autocracy
		"stability": 70.0,

		# Leadership
		"current_leader": "",
		"ruling_faction": Faction.FOUNDERS,

		# Factions
		"faction_standings": {
			Faction.EARTHERS: 50.0,
			Faction.FOUNDERS: 70.0,
			Faction.MARTIANS: 30.0,
			Faction.PRAGMATISTS: 50.0,
			Faction.VISIONARIES: 40.0
		},

		# Elections
		"next_election_year": -1,
		"election_cycle_years": 4,
		"current_council": [],  # colonist IDs
		"council_size": 5,

		# Laws & Policies
		"policies": {
			"food_rationing": 1.0,      # 0.6 - 1.2
			"work_hours": 45,           # 30-60
			"immigration": "selective", # closed, selective, open
			"earth_relations": "partnership" # dependent, partnership, autonomous, independent
		},

		# Independence track
		"independence_sentiment": 0.0,  # 0-100
		"independence_declared": false,
		"independence_year": -1
	}

	for key in overrides:
		politics[key] = overrides[key]

	return politics

# ============================================================================
# FACTORY FUNCTIONS - Colony State
# ============================================================================

static func create_colony_state(overrides: Dictionary = {}) -> Dictionary:
	var state = {
		# Time
		"current_year": 1,
		"current_week": 1,  # Week within the year (1-52)
		"current_month": 1,
		"total_sols": 0,
		"colony_phase": ColonyPhase.ACT_1_FOUNDERS,

		# Population
		"colonists": [],  # Array of colonist dictionaries
		"total_population": 0,
		"births_this_year": 0,
		"deaths_this_year": 0,
		"immigrants_this_year": 0,

		# Demographics
		"earth_born_count": 0,
		"first_gen_count": 0,
		"second_gen_count": 0,
		"third_gen_plus_count": 0,

		# Infrastructure
		"buildings": [],  # Array of building dictionaries
		"power_capacity": 0.0,
		"power_consumption": 0.0,
		"housing_capacity": 0,
		"housing_used": 0,

		# Resources
		"resources": create_resource_stockpile(),
		"production_rates": {},  # ResourceType -> per year
		"consumption_rates": {},

		# Politics
		"politics": create_political_state(),

		# Culture
		"culture": {
			"traditions": [],
			"holidays": [],
			"art_pieces": 0,
			"cultural_identity": 0.0,  # 0-100, Mars vs Earth identity
			"language_drift": 0.0      # 0-100, how different from Earth languages
		},

		# Earth relations
		"earth": {
			"communication_active": true,
			"supply_ships_received": 0,
			"next_supply_year": 2,
			"earth_collapsed": false,
			"last_message_year": 0
		},

		# History
		"timeline": [],  # Array of historical events
		"achievements": [],
		"mission_log": [],

		# Statistics
		"stats": {
			"total_births": 0,
			"total_deaths": 0,
			"total_immigrants": 0,
			"experiments_completed": 0,
			"buildings_constructed": 0,
			"crises_survived": 0,
			"elections_held": 0
		},

		# Victory tracking
		"victory_state": {
			"survival_secured": false,
			"self_sufficient": false,
			"independence_achieved": false,
			"highest_population": 0,
			"science_score": 0
		},

		# Random seed for determinism
		"random_seed": 0,

		# Active events
		"active_events": [],
		"resolved_events": [],  # History of resolved events with outcomes
		"event_cooldowns": {}  # event_type -> year when can trigger again
	}

	for key in overrides:
		state[key] = overrides[key]

	return state

# ============================================================================
# FACTORY FUNCTIONS - Events
# ============================================================================

static func create_colony_event(overrides: Dictionary = {}) -> Dictionary:
	var event = {
		"id": _generate_id(),
		"type": "",
		"title": "",
		"description": "",
		"severity": EventSeverity.MINOR,
		"year_triggered": 0,

		# Requirements
		"min_year": 0,
		"max_year": 100,
		"min_population": 0,
		"required_phase": ColonyPhase.ACT_1_FOUNDERS,
		"required_buildings": [],
		"required_flags": [],

		# Choices
		"choices": [],  # Array of choice dictionaries

		# Effects (if no choices)
		"effects": {},

		# Callbacks
		"triggers_event": "",  # event ID to chain to
		"sets_flags": [],
		"removes_flags": []
	}

	for key in overrides:
		event[key] = overrides[key]

	return event

static func create_event_choice(overrides: Dictionary = {}) -> Dictionary:
	var choice = {
		"id": "",
		"text": "",
		"description": "",

		# Requirements
		"requires_skill": Specialty.NONE,
		"requires_skill_level": 0,
		"requires_resource": {},

		# Effects
		"effects": {
			"morale_change": 0.0,
			"resource_changes": {},
			"relationship_changes": {},
			"faction_changes": {},
			"colonist_effects": [],
			"flag_changes": []
		},

		# Outcomes (for skill checks)
		"success_chance": 1.0,
		"success_effects": {},
		"failure_effects": {},

		# Chaining
		"triggers_event": ""
	}

	for key in overrides:
		choice[key] = overrides[key]

	return choice

# ============================================================================
# FACTORY FUNCTIONS - Timeline Entry
# ============================================================================

static func create_timeline_entry(year: int, title: String, description: String, category: String = "general") -> Dictionary:
	return {
		"year": year,
		"title": title,
		"description": description,
		"category": category,  # general, birth, death, political, discovery, crisis, milestone
		"colonists_involved": [],
		"importance": 1  # 1-5, affects display
	}

# ============================================================================
# FACTORY FUNCTIONS - Memory Entry
# ============================================================================

static func create_memory(year: int, description: String, emotional_weight: float = 0.0) -> Dictionary:
	return {
		"year": year,
		"description": description,
		"emotional_weight": emotional_weight,  # -1.0 (trauma) to 1.0 (joy)
		"related_colonists": [],
		"related_event": ""
	}

# ============================================================================
# IMMUTABLE UPDATE HELPERS (matching GameTypes pattern)
# ============================================================================

static func with_field(record: Dictionary, field: String, value) -> Dictionary:
	var new_record = record.duplicate(true)
	new_record[field] = value
	return new_record

static func with_fields(record: Dictionary, updates: Dictionary) -> Dictionary:
	var new_record = record.duplicate(true)
	for key in updates:
		new_record[key] = updates[key]
	return new_record

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

static var _id_counter: int = 0

static func _generate_id() -> String:
	_id_counter += 1
	return "col_%d_%d" % [Time.get_ticks_msec(), _id_counter]

static func get_life_stage_name(stage: LifeStage) -> String:
	match stage:
		LifeStage.INFANT: return "Infant"
		LifeStage.CHILD: return "Child"
		LifeStage.ADOLESCENT: return "Adolescent"
		LifeStage.ADULT: return "Adult"
		LifeStage.ELDER: return "Elder"
	return "Unknown"

static func get_generation_name(gen: Generation) -> String:
	match gen:
		Generation.EARTH_BORN: return "Earth-Born"
		Generation.FIRST_GEN: return "First Generation"
		Generation.SECOND_GEN: return "Second Generation"
		Generation.THIRD_GEN_PLUS: return "Third Generation+"
	return "Unknown"

static func get_faction_name(faction: Faction) -> String:
	match faction:
		Faction.NONE: return "Unaffiliated"
		Faction.EARTHERS: return "Earthers"
		Faction.FOUNDERS: return "Founders"
		Faction.MARTIANS: return "Martians"
		Faction.PRAGMATISTS: return "Pragmatists"
		Faction.VISIONARIES: return "Visionaries"
	return "Unknown"

static func get_specialty_name(spec: Specialty) -> String:
	match spec:
		Specialty.NONE: return "General"
		Specialty.ENGINEER: return "Engineer"
		Specialty.SCIENTIST: return "Scientist"
		Specialty.MEDIC: return "Medic"
		Specialty.FARMER: return "Farmer"
		Specialty.ADMINISTRATOR: return "Administrator"
		Specialty.EDUCATOR: return "Educator"
		Specialty.ARTIST: return "Artist"
		Specialty.SECURITY: return "Security"
		Specialty.PILOT: return "Pilot"
	return "Unknown"

static func get_building_name(type: BuildingType) -> String:
	match type:
		# Housing
		BuildingType.HABITAT: return "Habitat"
		BuildingType.BARRACKS: return "Barracks"
		BuildingType.QUARTERS: return "Quarters"
		# Production - Base
		BuildingType.AGRIDOME: return "Agridome"
		BuildingType.EXTRACTOR: return "Extractor"
		BuildingType.FABRICATOR: return "Fabricator"
		BuildingType.POWER_STATION: return "Power Station"
		# Production - Branches
		BuildingType.HYDROPONICS: return "Hydroponics"
		BuildingType.PROTEIN_VATS: return "Protein Vats"
		BuildingType.ICE_MINER: return "Ice Miner"
		BuildingType.ATMO_PROCESSOR: return "Atmosphere Processor"
		BuildingType.FOUNDRY: return "Foundry"
		BuildingType.PRECISION: return "Precision Works"
		BuildingType.SOLAR_FARM: return "Solar Farm"
		BuildingType.REACTOR: return "Reactor"
		# Services
		BuildingType.MEDICAL: return "Medical Center"
		BuildingType.ACADEMY: return "Academy"
		BuildingType.RESEARCH: return "Research Lab"
		BuildingType.RECREATION: return "Recreation Center"
		# Infrastructure
		BuildingType.STORAGE: return "Storage Depot"
		BuildingType.COMMS: return "Communications Hub"
		BuildingType.LOGISTICS: return "Logistics Center"
		# Space Economy
		BuildingType.STARPORT: return "Starport"
		BuildingType.ORBITAL: return "Orbital Station"
		BuildingType.CATCHER: return "Asteroid Catcher"
		# Megastructures
		BuildingType.MASS_DRIVER: return "Mass Driver"
		BuildingType.FUSION_PLANT: return "Fusion Plant"
		BuildingType.SPACE_ELEVATOR: return "Space Elevator"
	return "Unknown"

static func get_trait_name(t: ColonistTrait) -> String:
	match t:
		ColonistTrait.OPTIMIST: return "Optimist"
		ColonistTrait.PESSIMIST: return "Pessimist"
		ColonistTrait.STOIC: return "Stoic"
		ColonistTrait.PASSIONATE: return "Passionate"
		ColonistTrait.INTROVERT: return "Introvert"
		ColonistTrait.EXTROVERT: return "Extrovert"
		ColonistTrait.EMPATHETIC: return "Empathetic"
		ColonistTrait.RESERVED: return "Reserved"
		ColonistTrait.PERFECTIONIST: return "Perfectionist"
		ColonistTrait.PRAGMATIST: return "Pragmatist"
		ColonistTrait.METHODICAL: return "Methodical"
		ColonistTrait.CREATIVE: return "Creative"
		ColonistTrait.STEADY_HANDS: return "Steady Hands"
		ColonistTrait.TUNNEL_VISION: return "Tunnel Vision"
		ColonistTrait.ADRENALINE_JUNKIE: return "Adrenaline Junkie"
		ColonistTrait.FREEZE_PRONE: return "Freeze-Prone"
		ColonistTrait.UTILITARIAN: return "Utilitarian"
		ColonistTrait.PROTECTOR: return "Protector"
		ColonistTrait.BY_THE_BOOK: return "By-The-Book"
		ColonistTrait.ENDS_JUSTIFY: return "Ends Justify Means"
		ColonistTrait.FOUNDERS_BLOOD: return "Founder's Blood"
		ColonistTrait.MARS_ADAPTED: return "Mars-Adapted"
		ColonistTrait.EARTH_LONGING: return "Earth Longing"
		ColonistTrait.VISIONARY: return "Visionary"
	return "Unknown"

# ============================================================================
# BUILDING DEFINITIONS
# ============================================================================

static func get_phase_name(phase: ColonyPhase) -> String:
	match phase:
		ColonyPhase.ACT_1_FOUNDERS: return "Survival"
		ColonyPhase.ACT_2_SETTLEMENT: return "Growth"
		ColonyPhase.ACT_3_COLONY: return "Society"
		ColonyPhase.ACT_4_INDEPENDENCE: return "Legacy"
	return "Unknown"

static func get_political_system_name(system: PoliticalSystem) -> String:
	match system:
		PoliticalSystem.MISSION_COMMAND: return "Mission Command"
		PoliticalSystem.ADVISORY_COUNCIL: return "Advisory Council"
		PoliticalSystem.REPRESENTATIVE: return "Representative Democracy"
		PoliticalSystem.CONSTITUTIONAL: return "Constitutional Government"
		PoliticalSystem.INDEPENDENT_STATE: return "Independent State"
	return "Unknown"

static func get_resource_name(resource_type: ResourceType) -> String:
	match resource_type:
		ResourceType.WATER_ICE: return "water_ice"
		ResourceType.REGOLITH: return "regolith"
		ResourceType.IRON_ORE: return "iron_ore"
		ResourceType.ALUMINUM_ORE: return "aluminum_ore"
		ResourceType.RARE_EARTH: return "rare_earth"
		ResourceType.CO2: return "co2"
		ResourceType.WATER: return "water"
		ResourceType.OXYGEN: return "oxygen"
		ResourceType.HYDROGEN: return "hydrogen"
		ResourceType.METHANE: return "methane"
		ResourceType.IRON: return "iron"
		ResourceType.ALUMINUM: return "aluminum"
		ResourceType.PLASTIC: return "plastic"
		ResourceType.FOOD: return "food"
		ResourceType.MEDICINE: return "medicine"
		ResourceType.ELECTRONICS: return "electronics"
		ResourceType.MACHINE_PARTS: return "machine_parts"
		ResourceType.BUILDING_MATERIALS: return "building_materials"
		ResourceType.FUEL: return "fuel"
		ResourceType.ART: return "art"
		ResourceType.ENTERTAINMENT: return "entertainment"
		ResourceType.COMFORT_ITEMS: return "comfort_items"
		ResourceType.CREDITS: return "credits"
	return "unknown"

static func get_building_definition(type: BuildingType) -> Dictionary:
	match type:
		# === HOUSING ===
		BuildingType.HABITAT:
			return {
				"housing_capacity": 6,
				"power_consumption": 8.0,
				"construction_years": 1,
				"required_workers": 0,
				"maintenance_cost": {"machine_parts": 1}
			}
		BuildingType.BARRACKS:
			return {
				"housing_capacity": 12,
				"power_consumption": 10.0,
				"construction_years": 1,
				"required_workers": 0,
				"maintenance_cost": {"machine_parts": 1}
			}
		BuildingType.QUARTERS:
			return {
				"housing_capacity": 3,
				"power_consumption": 12.0,
				"construction_years": 1,
				"required_workers": 0,
				"maintenance_cost": {"machine_parts": 2}
			}
		# === PRODUCTION BASE ===
		BuildingType.AGRIDOME:
			return {
				"housing_capacity": 0,
				"power_consumption": 15.0,
				"construction_years": 1,
				"required_workers": 2,
				"produces": {"food": 600.0},
				"maintenance_cost": {"machine_parts": 1}
			}
		BuildingType.EXTRACTOR:
			return {
				"housing_capacity": 0,
				"power_consumption": 20.0,
				"construction_years": 1,
				"required_workers": 2,
				"produces": {"water": 400.0, "oxygen": 150.0},
				"maintenance_cost": {"machine_parts": 2}
			}
		BuildingType.FABRICATOR:
			return {
				"housing_capacity": 0,
				"power_consumption": 35.0,
				"construction_years": 1,
				"required_workers": 3,
				"produces": {"machine_parts": 30.0, "building_materials": 40.0},
				"maintenance_cost": {"machine_parts": 2}
			}
		BuildingType.POWER_STATION:
			return {
				"housing_capacity": 0,
				"power_generation": 60.0,
				"construction_years": 1,
				"required_workers": 1,
				"maintenance_cost": {"machine_parts": 1}
			}
		# === PRODUCTION BRANCHES (T3+) ===
		BuildingType.HYDROPONICS:
			return {
				"housing_capacity": 0,
				"power_consumption": 20.0,
				"construction_years": 1,
				"required_workers": 2,
				"produces": {"food": 1200.0},
				"consumes": {"electronics": 2},
				"maintenance_cost": {"machine_parts": 2}
			}
		BuildingType.PROTEIN_VATS:
			return {
				"housing_capacity": 0,
				"power_consumption": 18.0,
				"construction_years": 1,
				"required_workers": 2,
				"produces": {"food": 1000.0},
				"consumes": {"medicine": 2},
				"maintenance_cost": {"machine_parts": 2}
			}
		BuildingType.ICE_MINER:
			return {
				"housing_capacity": 0,
				"power_consumption": 22.0,
				"construction_years": 1,
				"required_workers": 2,
				"produces": {"water": 900.0, "oxygen": 100.0, "fuel": 20.0},
				"maintenance_cost": {"machine_parts": 2}
			}
		BuildingType.ATMO_PROCESSOR:
			return {
				"housing_capacity": 0,
				"power_consumption": 25.0,
				"construction_years": 1,
				"required_workers": 2,
				"produces": {"water": 200.0, "oxygen": 500.0},
				"maintenance_cost": {"machine_parts": 2}
			}
		BuildingType.FOUNDRY:
			return {
				"housing_capacity": 0,
				"power_consumption": 40.0,
				"construction_years": 1,
				"required_workers": 3,
				"produces": {"building_materials": 150.0, "machine_parts": 20.0},
				"maintenance_cost": {"machine_parts": 3}
			}
		BuildingType.PRECISION:
			return {
				"housing_capacity": 0,
				"power_consumption": 40.0,
				"construction_years": 1,
				"required_workers": 3,
				"produces": {"machine_parts": 100.0, "building_materials": 30.0},
				"maintenance_cost": {"machine_parts": 3}
			}
		BuildingType.SOLAR_FARM:
			return {
				"housing_capacity": 0,
				"power_generation": 140.0,
				"construction_years": 1,
				"required_workers": 0,
				"maintenance_cost": {"machine_parts": 1}
			}
		BuildingType.REACTOR:
			return {
				"housing_capacity": 0,
				"power_generation": 200.0,
				"construction_years": 2,
				"required_workers": 2,
				"consumes": {"fuel": 10},
				"maintenance_cost": {"machine_parts": 4}
			}
		# === SERVICES ===
		BuildingType.MEDICAL:
			return {
				"housing_capacity": 0,
				"power_consumption": 15.0,
				"construction_years": 1,
				"required_workers": 2,
				"consumes": {"medicine": 5.0},
				"maintenance_cost": {"machine_parts": 2}
			}
		BuildingType.ACADEMY:
			return {
				"housing_capacity": 0,
				"power_consumption": 10.0,
				"construction_years": 1,
				"required_workers": 2,
				"maintenance_cost": {"machine_parts": 1}
			}
		BuildingType.RESEARCH:
			return {
				"housing_capacity": 0,
				"power_consumption": 25.0,
				"construction_years": 1,
				"required_workers": 2,
				"consumes": {"electronics": 2},
				"maintenance_cost": {"machine_parts": 2}
			}
		BuildingType.RECREATION:
			return {
				"housing_capacity": 0,
				"power_consumption": 12.0,
				"construction_years": 1,
				"required_workers": 1,
				"maintenance_cost": {"machine_parts": 1}
			}
		# === INFRASTRUCTURE ===
		BuildingType.STORAGE:
			return {
				"housing_capacity": 0,
				"power_consumption": 5.0,
				"construction_years": 1,
				"required_workers": 0,
				"maintenance_cost": {"machine_parts": 0}
			}
		BuildingType.COMMS:
			return {
				"housing_capacity": 0,
				"power_consumption": 12.0,
				"construction_years": 1,
				"required_workers": 1,
				"maintenance_cost": {"machine_parts": 1}
			}
		BuildingType.LOGISTICS:
			return {
				"housing_capacity": 0,
				"power_consumption": 15.0,
				"construction_years": 1,
				"required_workers": 1,
				"maintenance_cost": {"machine_parts": 1}
			}
		# === SPACE ECONOMY ===
		BuildingType.STARPORT:
			return {
				"housing_capacity": 0,
				"power_consumption": 35.0,
				"construction_years": 2,
				"required_workers": 2,
				"maintenance_cost": {"machine_parts": 4, "fuel": 5}
			}
		BuildingType.ORBITAL:
			return {
				"housing_capacity": 0,
				"power_consumption": 60.0,
				"construction_years": 3,
				"required_workers": 3,
				"produces": {"machine_parts": 30.0},
				"maintenance_cost": {"machine_parts": 6, "fuel": 10}
			}
		BuildingType.CATCHER:
			return {
				"housing_capacity": 0,
				"power_consumption": 85.0,
				"construction_years": 3,
				"required_workers": 4,
				"produces": {"building_materials": 350.0, "machine_parts": 60.0},
				"maintenance_cost": {"machine_parts": 10, "fuel": 20}
			}
		# === MEGASTRUCTURES ===
		BuildingType.MASS_DRIVER:
			return {
				"housing_capacity": 0,
				"power_consumption": 100.0,
				"construction_years": 4,
				"required_workers": 4,
				"maintenance_cost": {"machine_parts": 8, "fuel": 10}
			}
		BuildingType.FUSION_PLANT:
			return {
				"housing_capacity": 0,
				"power_generation": 600.0,
				"construction_years": 5,
				"required_workers": 3,
				"maintenance_cost": {"machine_parts": 10}
			}
		BuildingType.SPACE_ELEVATOR:
			return {
				"housing_capacity": 0,
				"power_consumption": 160.0,
				"construction_years": 6,
				"required_workers": 6,
				"maintenance_cost": {"machine_parts": 15, "fuel": 15}
			}
		_:
			return {
				"housing_capacity": 0,
				"power_consumption": 10.0,
				"construction_years": 1,
				"required_workers": 1,
				"maintenance_cost": {"machine_parts": 1}
			}
