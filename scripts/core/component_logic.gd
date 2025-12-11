class_name ComponentLogic
extends RefCounted

## Pure functions for component operations
## All functions are static, take inputs, return outputs, no side effects

# ============================================================================
# COMPONENT CALCULATIONS
# ============================================================================

## Calculate failure chance based on quality (pure)
static func calc_failure_chance(quality: float) -> float:
	return maxf(0.0, (100.0 - quality) / 100.0)

## Calculate quality gain from a test (pure, deterministic with seed)
static func calc_test_quality_gain(
	base_gain: float,
	random_value: float  # Pass in random value for determinism
) -> float:
	# random_value should be 0.0-1.0, we map to 0.8-1.2 multiplier
	var multiplier = 0.8 + (random_value * 0.4)
	return base_gain * multiplier

## Run a test on a component, returns new component state and result (pure)
static func apply_test(
	component: Dictionary,
	random_value: float
) -> Dictionary:
	var quality_gained = calc_test_quality_gain(
		component.quality_per_test,
		random_value
	)
	var new_quality = minf(component.quality + quality_gained, component.max_quality)

	var new_component = GameTypes.with_fields(component, {
		"quality": new_quality,
		"is_tested": true
	})

	var result = GameTypes.create_test_result(
		quality_gained,
		new_quality,
		component.test_cost_per_cycle,
		component.test_days_per_cycle
	)

	return {
		"component": new_component,
		"result": result
	}

## Advance construction by one day (pure)
static func advance_construction(component: Dictionary) -> Dictionary:
	if component.is_built:
		return component

	var new_days = component.days_remaining - 1
	var is_now_built = new_days <= 0

	return GameTypes.with_fields(component, {
		"days_remaining": maxi(0, new_days),
		"is_built": is_now_built
	})

## Start construction on a component (pure)
static func start_construction(component: Dictionary) -> Dictionary:
	return GameTypes.with_fields(component, {
		"days_remaining": component.build_days,
		"is_built": false
	})

# ============================================================================
# COMPONENT FACTORY FUNCTIONS (pure data creation)
# ============================================================================

static func create_cockpit() -> Dictionary:
	return GameTypes.create_component({
		"id": "cockpit",
		"display_name": "Cockpit",
		"description": "Command center for piloting the spacecraft. Required for launch.",
		"base_cost": 50_000_000,  # Balance: $50M per design doc
		"build_days": 8,
		"mass_kg": 2000.0,
		"hex_size": 2,
		"quality": 55.0,  # Starting quality per balance doc
		"test_cost_per_cycle": 2_500_000,
		"test_days_per_cycle": 2,
		"quality_per_test": 8.0
	})

static func create_engine_mount() -> Dictionary:
	return GameTypes.create_component({
		"id": "engine_mount",
		"display_name": "Engine Mount",
		"description": "Structural mounting point for the main engine. Required for launch.",
		"base_cost": 30_000_000,
		"build_days": 6,
		"mass_kg": 1500.0,
		"hex_size": 2,
		"quality": 60.0,
		"test_cost_per_cycle": 1_500_000,
		"test_days_per_cycle": 2,
		"quality_per_test": 10.0
	})

static func create_gym() -> Dictionary:
	return GameTypes.create_component({
		"id": "gym",
		"display_name": "Exercise Facility",
		"description": "Prevents muscle atrophy. Reduces health loss during travel.",
		"base_cost": 20_000_000,
		"build_days": 5,
		"mass_kg": 800.0,
		"hex_size": 1,
		"quality": 70.0,
		"test_cost_per_cycle": 500_000,
		"test_days_per_cycle": 1,
		"quality_per_test": 15.0
	})

static func create_cafeteria() -> Dictionary:
	return GameTypes.create_component({
		"id": "cafeteria",
		"display_name": "Cafeteria",
		"description": "Food preparation and dining. Improves crew morale.",
		"base_cost": 30_000_000,
		"build_days": 6,
		"mass_kg": 600.0,
		"hex_size": 1,
		"quality": 65.0,
		"test_cost_per_cycle": 500_000,
		"test_days_per_cycle": 1,
		"quality_per_test": 15.0
	})

static func create_crew_room() -> Dictionary:
	return GameTypes.create_component({
		"id": "crew_room",
		"display_name": "Crew Quarters",
		"description": "Private sleeping quarters for one crew member.",
		"base_cost": 25_000_000,
		"build_days": 5,
		"mass_kg": 400.0,
		"hex_size": 1,
		"quality": 60.0,
		"test_cost_per_cycle": 300_000,
		"test_days_per_cycle": 1,
		"quality_per_test": 15.0
	})

static func create_cargo_bay() -> Dictionary:
	return GameTypes.create_component({
		"id": "cargo",
		"display_name": "Cargo Bay",
		"description": "Storage for supplies. More cargo = more supplies for the journey.",
		"base_cost": 20_000_000,
		"build_days": 4,
		"mass_kg": 1000.0,
		"hex_size": 2,
		"quality": 70.0,
		"test_cost_per_cycle": 500_000,
		"test_days_per_cycle": 1,
		"quality_per_test": 12.0
	})

static func create_hangar() -> Dictionary:
	return GameTypes.create_component({
		"id": "hangar",
		"display_name": "Hangar Bay",
		"description": "Storage for rovers. Enables surface exploration on Mars.",
		"base_cost": 60_000_000,
		"build_days": 10,
		"mass_kg": 3000.0,
		"hex_size": 3,
		"quality": 60.0,
		"test_cost_per_cycle": 2_000_000,
		"test_days_per_cycle": 2,
		"quality_per_test": 8.0
	})

static func create_mav_dock() -> Dictionary:
	return GameTypes.create_component({
		"id": "mav_dock",
		"display_name": "MAV Docking Bay",
		"description": "Mars Ascent Vehicle dock. REQUIRED to return from Mars.",
		"base_cost": 150_000_000,
		"build_days": 15,
		"mass_kg": 4000.0,
		"hex_size": 3,
		"quality": 50.0,
		"test_cost_per_cycle": 5_000_000,
		"test_days_per_cycle": 3,
		"quality_per_test": 6.0
	})

static func create_science_lab() -> Dictionary:
	return GameTypes.create_component({
		"id": "science_lab",
		"display_name": "Science Laboratory",
		"description": "Analyze samples during transit. Improves experiment success.",
		"base_cost": 45_000_000,
		"build_days": 8,
		"mass_kg": 2000.0,
		"hex_size": 2,
		"quality": 55.0,
		"test_cost_per_cycle": 1_500_000,
		"test_days_per_cycle": 2,
		"quality_per_test": 10.0
	})

static func create_medical_bay() -> Dictionary:
	return GameTypes.create_component({
		"id": "medical_bay",
		"display_name": "Medical Bay",
		"description": "Treat injuries and illness. Essential for crew survival.",
		"base_cost": 40_000_000,
		"build_days": 7,
		"mass_kg": 1000.0,
		"hex_size": 1,
		"quality": 55.0,
		"test_cost_per_cycle": 1_500_000,
		"test_days_per_cycle": 2,
		"quality_per_test": 10.0
	})

static func create_life_support() -> Dictionary:
	return GameTypes.create_component({
		"id": "life_support",
		"display_name": "Life Support System",
		"description": "Air/water recycling. Higher quality = less supply consumption.",
		"base_cost": 80_000_000,
		"build_days": 12,
		"mass_kg": 2500.0,
		"hex_size": 2,
		"quality": 50.0,  # Starts low - needs testing!
		"test_cost_per_cycle": 3_000_000,
		"test_days_per_cycle": 2,
		"quality_per_test": 8.0
	})

static func create_fuel_tank() -> Dictionary:
	return GameTypes.create_component({
		"id": "fuel_tank",
		"display_name": "Fuel Tank",
		"description": "Stores propellant for the main engine.",
		"base_cost": 15_000_000,
		"build_days": 4,
		"mass_kg": 500.0,
		"hex_size": 1,
		"quality": 65.0,
		"test_cost_per_cycle": 500_000,
		"test_days_per_cycle": 1,
		"quality_per_test": 12.0
	})

static func create_solar_array() -> Dictionary:
	return GameTypes.create_component({
		"id": "solar_array",
		"display_name": "Solar Array",
		"description": "Generates power from sunlight. Required for all systems.",
		"base_cost": 25_000_000,
		"build_days": 5,
		"mass_kg": 600.0,
		"hex_size": 1,
		"quality": 65.0,
		"test_cost_per_cycle": 500_000,
		"test_days_per_cycle": 1,
		"quality_per_test": 12.0
	})

static func create_comms_array() -> Dictionary:
	return GameTypes.create_component({
		"id": "comms",
		"display_name": "Communications Array",
		"description": "Deep space communication with Earth.",
		"base_cost": 30_000_000,
		"build_days": 6,
		"mass_kg": 500.0,
		"hex_size": 1,
		"quality": 60.0,
		"test_cost_per_cycle": 800_000,
		"test_days_per_cycle": 1,
		"quality_per_test": 12.0
	})

static func get_all_components() -> Array:
	return [
		create_cockpit(),
		create_engine_mount(),
		create_gym(),
		create_cafeteria(),
		create_crew_room(),
		create_cargo_bay(),
		create_hangar(),
		create_mav_dock(),
		create_science_lab(),
		create_medical_bay(),
		create_life_support(),
		create_fuel_tank(),
		create_solar_array(),
		create_comms_array()
	]

static func get_component_by_id(id: String) -> Dictionary:
	for comp in get_all_components():
		if comp.id == id:
			return comp
	return {}
