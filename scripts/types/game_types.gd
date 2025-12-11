class_name GameTypes
extends RefCounted

## Pure data types - no methods with side effects, just data containers
## These mirror TypeScript interfaces/types

# ============================================================================
# ENUMS
# ============================================================================

enum GamePhase {
	MAIN_MENU,
	SHIP_BUILDING,
	TRAVEL_TO_MARS,
	MARS_BASE,
	TRAVEL_TO_EARTH,
	GAME_OVER
}

enum EngineClass {
	TRADITIONAL,
	HERMES,
	HALL_THRUSTER,
	NUCLEAR,
	SOLAR_SAIL,
	LASER_SAIL,
	PULSED_PLASMA,
	MAGNETOPLASMADYNAMIC,
	VASIMR
}

enum CrewSpecialty {
	COMMANDER,
	PILOT,
	ENGINEER,
	SCIENTIST_GEOLOGY,
	SCIENTIST_BIOLOGY,
	SCIENTIST_CHEMISTRY,
	MEDIC
}

enum EventType {
	WEATHER_DAMAGE,
	CREW_SICKNESS,
	SUPPLY_LOSS,
	EQUIPMENT_MALFUNCTION,
	MORALE_BOOST,
	DISCOVERY
}

enum PersonalityTrait {
	OPTIMIST,      # Higher morale baseline, recovers faster
	PESSIMIST,     # Lower morale baseline, affects others negatively in crisis
	LEADER,        # Boosts team morale in crisis
	LONER,         # Works better alone, doesn't gain morale from social events
	CARETAKER,     # Boosts others' health/morale when assigned to help
	RISK_TAKER,    # Higher success in experiments, higher failure consequences
	CAUTIOUS,      # Lower success chance but fewer catastrophic failures
	STOIC,         # Morale doesn't swing much, good or bad
	HOMESICK,      # Morale decays faster, affected by Earth comms
	CURIOUS        # Science bonus, morale boost from discoveries
}

# ============================================================================
# DATA STRUCTURES (Dictionaries as immutable-style records)
# ============================================================================

## Creates a new ComponentData record
static func create_component(overrides: Dictionary = {}) -> Dictionary:
	var defaults = {
		"id": "",
		"display_name": "",
		"description": "",
		"base_cost": 0,
		"build_days": 1,
		"mass_kg": 0.0,
		"hex_size": 1,
		"quality": 0.0,
		"max_quality": 100.0,
		"test_cost_per_cycle": 1000,
		"test_days_per_cycle": 1,
		"quality_per_test": 5.0,
		"is_built": false,
		"is_tested": false,
		"hex_position": Vector2i(-1, -1),
		"days_remaining": 0
	}
	return _merge(defaults, overrides)

## Creates a new EngineData record (extends ComponentData)
static func create_engine(overrides: Dictionary = {}) -> Dictionary:
	var component_defaults = create_component()
	var engine_defaults = {
		"engine_class": EngineClass.TRADITIONAL,
		"thrust_n": 0.0,
		"specific_impulse_s": 0.0,
		"fuel_type": "",
		"fuel_consumption_kg_s": 0.0,
		"requires_space_assembly": false,
		"has_radiation_risk": false,
		"containment_leak_chance": 0.0
	}
	return _merge(_merge(component_defaults, engine_defaults), overrides)

## Creates a new CrewMember record
static func create_crew_member(overrides: Dictionary = {}) -> Dictionary:
	var defaults = {
		"id": "",
		"display_name": "",
		"specialty": CrewSpecialty.SCIENTIST_GEOLOGY,
		"age": 35,
		"health": 100.0,
		"morale": 100.0,
		"fatigue": 0.0,
		"skill_piloting": 50.0,
		"skill_engineering": 50.0,
		"skill_science": 50.0,
		"skill_medical": 50.0,
		"skill_leadership": 50.0,
		"is_sick": false,
		"is_injured": false,
		"sickness_type": "",
		"days_sick": 0,
		# TIME BUDGET - 16 hours available per day for activities
		"hours_used_today": 0,
		"hours_per_day": 16,
		# PERSONALITY - Makes crew feel like real people
		"personality": PersonalityTrait.OPTIMIST,  # Primary personality trait
		"backstory": "",                           # Short backstory snippet
		"personal_goal": "",                       # What they hope to achieve
		"quirk": "",                               # Memorable detail
		# RELATIONSHIPS - Connections with other crew
		"relationships": {},                       # crew_id -> trust level (-100 to 100)
		"had_conflict_with": [],                   # IDs of crew they've had conflicts with
		"bonded_with": []                          # IDs of crew they've bonded with
	}
	return _merge(defaults, overrides)

## Creates a new GameState record
static func create_game_state(overrides: Dictionary = {}) -> Dictionary:
	var defaults = {
		"current_phase": GamePhase.MAIN_MENU,
		"current_day": 1,
		"launch_window_day": 75,  # Normal difficulty: 75 days to launch window
		"budget": 650_000_000,    # Normal difficulty: $650M starting budget
		"total_spent": 0,
		"ship_components": [],  # Array of ComponentData
		"selected_engine": null,  # EngineData or null
		"ship_hex_grid": {},  # Dictionary<Vector2i, ComponentData>
		"crew": [],  # Array of CrewMember
		"building_queue": [],  # Array of {component, days_remaining}
		"cargo_manifest": {
			"habitation_module": false,
			"oxygenator": false,
			"food_storage": false,
			"equipment_storage": false,
			"dormitory": false,
			"solar_panels": 0,
			"wind_turbines": 0,
			"batteries": 0,
			"rovers": 0,
			"mav": false
		},
		# SUPPLIES - The core survival resources (kg)
		"supplies": {
			"food_kg": 0.0,        # Crew eats ~2kg/person/day
			"water_kg": 0.0,       # ~3kg/person/day (recycled to ~0.9kg)
			"oxygen_kg": 0.0,      # ~0.84kg/person/day (recycled to ~0.25kg)
			"fuel_kg": 0.0,        # For engine burns
			"spare_parts": 0,      # For repairs
			"medical_kits": 0      # For treating injuries/illness
		},
		"science_equipment": {
			"soil_analyzer": false,
			"ice_core_drill": false,
			"atmospheric_sampler": false,
			"spectrometer": false,
			"microscope": false
		},
		"mission_log": [],
		"random_seed": 0,
		# Track critical failures
		"crew_deaths": 0,
		"critical_failures": []
	}
	return _merge(defaults, overrides)

## Creates a LogEntry record
static func create_log_entry(day: int, message: String, event_type: String = "info") -> Dictionary:
	return {
		"day": day,
		"message": message,
		"event_type": event_type,
		"timestamp": Time.get_unix_time_from_system()
	}

## Creates an Event record
static func create_event(overrides: Dictionary = {}) -> Dictionary:
	var defaults = {
		"type": EventType.WEATHER_DAMAGE,
		"description": "",
		"effects": {}  # Dictionary of state changes to apply
	}
	return _merge(defaults, overrides)

## Creates a TestResult record
static func create_test_result(quality_gained: float, new_quality: float, cost: int, days: int) -> Dictionary:
	return {
		"quality_gained": quality_gained,
		"new_quality": new_quality,
		"cost": cost,
		"days": days
	}

## Creates a LaunchCheck record
static func create_launch_check(can_launch: bool, issues: Array, readiness: float) -> Dictionary:
	return {
		"can_launch": can_launch,
		"issues": issues,
		"readiness": readiness
	}

# ============================================================================
# UTILITY - Immutable merge (like spread operator in TS)
# ============================================================================

static func _merge(base: Dictionary, overrides: Dictionary) -> Dictionary:
	var result = base.duplicate(true)
	for key in overrides.keys():
		result[key] = overrides[key]
	return result

## Update a single field immutably
static func with_field(record: Dictionary, field: String, value) -> Dictionary:
	var result = record.duplicate(true)
	result[field] = value
	return result

## Update multiple fields immutably
static func with_fields(record: Dictionary, updates: Dictionary) -> Dictionary:
	return _merge(record, updates)

# ============================================================================
# UTILITY - Formatting
# ============================================================================

## Format money amount for display
static func format_money(amount: int) -> String:
	if amount >= 1_000_000_000:
		return "%.2fB" % (amount / 1_000_000_000.0)
	elif amount >= 1_000_000:
		return "%.1fM" % (amount / 1_000_000.0)
	elif amount >= 1_000:
		return "%.0fK" % (amount / 1_000.0)
	return str(amount)
