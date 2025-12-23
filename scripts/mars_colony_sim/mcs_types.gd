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

enum BuildingType {
	# Housing
	HAB_POD, APARTMENT_BLOCK, LUXURY_QUARTERS, BARRACKS,
	# Production
	GREENHOUSE, HYDROPONICS, PROTEIN_VATS, WORKSHOP, FACTORY,
	# Power
	SOLAR_ARRAY, WIND_TURBINE, RTG, FISSION_REACTOR,
	# Life Support
	WATER_EXTRACTOR, OXYGENATOR, WASTE_PROCESSOR, CO2_SCRUBBER,
	# Services
	MEDICAL_BAY, HOSPITAL, SCHOOL, UNIVERSITY, LAB, RESEARCH_CENTER,
	# Social
	RECREATION_CENTER, TEMPLE, GOVERNMENT_HALL, PRISON,
	# Infrastructure
	STORAGE, AIRLOCK, LANDING_PAD, COMMUNICATIONS
}

enum ResourceType {
	# Primary (extracted)
	WATER_ICE, REGOLITH, IRON_ORE, ALUMINUM_ORE, RARE_EARTH, CO2,
	# Secondary (processed)
	WATER, OXYGEN, HYDROGEN, METHANE, IRON, ALUMINUM, PLASTIC,
	# Tertiary (manufactured)
	FOOD, MEDICINE, ELECTRONICS, MACHINE_PARTS, BUILDING_MATERIALS, FUEL,
	# Quaternary (luxury)
	ART, ENTERTAINMENT, COMFORT_ITEMS
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
		"type": BuildingType.HAB_POD,
		"name": "",
		"position": Vector2i.ZERO,
		"hex_size": 1,

		# Stats
		"condition": 100.0,
		"efficiency": 100.0,
		"power_consumption": 0.0,
		"power_generation": 0.0,

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
	var stockpile = {
		# Primary
		"water_ice": 0.0,
		"regolith": 0.0,
		"iron_ore": 0.0,
		"aluminum_ore": 0.0,
		"rare_earth": 0.0,
		"co2": 0.0,

		# Secondary
		"water": 1000.0,
		"oxygen": 500.0,
		"hydrogen": 100.0,
		"methane": 0.0,
		"iron": 0.0,
		"aluminum": 0.0,
		"plastic": 0.0,

		# Tertiary
		"food": 500.0,
		"medicine": 50.0,
		"electronics": 20.0,
		"machine_parts": 30.0,
		"building_materials": 100.0,
		"fuel": 200.0,

		# Quaternary
		"art": 0.0,
		"entertainment": 10.0,
		"comfort_items": 20.0
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
		BuildingType.HAB_POD: return "Hab Pod"
		BuildingType.APARTMENT_BLOCK: return "Apartment Block"
		BuildingType.LUXURY_QUARTERS: return "Luxury Quarters"
		BuildingType.BARRACKS: return "Barracks"
		BuildingType.GREENHOUSE: return "Greenhouse"
		BuildingType.HYDROPONICS: return "Hydroponics Bay"
		BuildingType.PROTEIN_VATS: return "Protein Vats"
		BuildingType.WORKSHOP: return "Workshop"
		BuildingType.FACTORY: return "Factory"
		BuildingType.SOLAR_ARRAY: return "Solar Array"
		BuildingType.WIND_TURBINE: return "Wind Turbine"
		BuildingType.RTG: return "RTG"
		BuildingType.FISSION_REACTOR: return "Fission Reactor"
		BuildingType.WATER_EXTRACTOR: return "Water Extractor"
		BuildingType.OXYGENATOR: return "Oxygenator"
		BuildingType.WASTE_PROCESSOR: return "Waste Processor"
		BuildingType.CO2_SCRUBBER: return "CO2 Scrubber"
		BuildingType.MEDICAL_BAY: return "Medical Bay"
		BuildingType.HOSPITAL: return "Hospital"
		BuildingType.SCHOOL: return "School"
		BuildingType.UNIVERSITY: return "University"
		BuildingType.LAB: return "Laboratory"
		BuildingType.RESEARCH_CENTER: return "Research Center"
		BuildingType.RECREATION_CENTER: return "Recreation Center"
		BuildingType.TEMPLE: return "Temple"
		BuildingType.GOVERNMENT_HALL: return "Government Hall"
		BuildingType.PRISON: return "Prison"
		BuildingType.STORAGE: return "Storage"
		BuildingType.AIRLOCK: return "Airlock"
		BuildingType.LANDING_PAD: return "Landing Pad"
		BuildingType.COMMUNICATIONS: return "Communications"
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
	return "unknown"

static func get_building_definition(type: BuildingType) -> Dictionary:
	match type:
		BuildingType.HAB_POD:
			return {
				"housing_capacity": 4,
				"power_consumption": 5.0,
				"construction_years": 1,
				"required_workers": 0,
				"maintenance_cost": {"machine_parts": 1}
			}
		BuildingType.APARTMENT_BLOCK:
			return {
				"housing_capacity": 20,
				"power_consumption": 25.0,
				"construction_years": 2,
				"required_workers": 0,
				"maintenance_cost": {"machine_parts": 3}
			}
		BuildingType.GREENHOUSE:
			return {
				"housing_capacity": 0,
				"power_consumption": 15.0,
				"construction_years": 1,
				"required_workers": 2,
				"produces": {"food": 500.0},
				"consumes": {"water": 20.0},
				"maintenance_cost": {"machine_parts": 1}
			}
		BuildingType.SOLAR_ARRAY:
			return {
				"housing_capacity": 0,
				"power_generation": 50.0,
				"construction_years": 1,
				"required_workers": 0,
				"maintenance_cost": {"machine_parts": 1}
			}
		BuildingType.WATER_EXTRACTOR:
			return {
				"housing_capacity": 0,
				"power_consumption": 20.0,
				"construction_years": 1,
				"required_workers": 1,
				"produces": {"water": 400.0},  # 24 colonists × 20 = 480 water/yr needed
				"maintenance_cost": {"machine_parts": 2}
			}
		BuildingType.WORKSHOP:
			return {
				"housing_capacity": 0,
				"power_consumption": 30.0,
				"construction_years": 1,
				"required_workers": 3,
				"produces": {"machine_parts": 20.0},
				"consumes": {"building_materials": 15.0},
				"maintenance_cost": {"machine_parts": 1}
			}
		BuildingType.FACTORY:
			return {
				"housing_capacity": 0,
				"power_consumption": 60.0,
				"construction_years": 2,
				"required_workers": 6,
				"produces": {"machine_parts": 50.0, "building_materials": 30.0},
				"consumes": {"fuel": 10.0},
				"maintenance_cost": {"machine_parts": 5}
			}
		BuildingType.HYDROPONICS:
			return {
				"housing_capacity": 0,
				"power_consumption": 25.0,
				"construction_years": 1,
				"required_workers": 2,
				"produces": {"food": 800.0},
				"consumes": {"water": 30.0},
				"maintenance_cost": {"machine_parts": 2}
			}
		BuildingType.OXYGENATOR:
			return {
				"housing_capacity": 0,
				"power_consumption": 15.0,
				"construction_years": 1,
				"required_workers": 1,
				"produces": {"oxygen": 200.0},
				"consumes": {"water": 10.0},
				"maintenance_cost": {"machine_parts": 1}
			}
		BuildingType.MEDICAL_BAY:
			return {
				"housing_capacity": 0,
				"power_consumption": 10.0,
				"construction_years": 1,
				"required_workers": 2,
				"consumes": {"medicine": 10.0},
				"maintenance_cost": {"machine_parts": 2, "electronics": 1}
			}
		BuildingType.SCHOOL:
			return {
				"housing_capacity": 0,
				"power_consumption": 8.0,
				"construction_years": 1,
				"required_workers": 2,
				"maintenance_cost": {"machine_parts": 1}
			}
		_:
			return {
				"housing_capacity": 0,
				"power_consumption": 10.0,
				"construction_years": 1,
				"required_workers": 1,
				"maintenance_cost": {"machine_parts": 1}
			}
