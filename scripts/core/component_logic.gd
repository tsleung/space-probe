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

# ============================================================================
# COMPONENT DEGRADATION (for journey phases)
# ============================================================================

## Calculate daily wear on a component (pure)
## Base degradation is 0.02% per day, modified by component type and usage
static func calc_daily_degradation(component: Dictionary, is_active: bool = true) -> float:
	var base_rate = 0.02  # 0.02% per day base

	# Some components wear faster
	var type_multiplier = 1.0
	match component.id:
		"life_support":
			type_multiplier = 1.5  # Critical system under constant stress
		"engine_mount":
			type_multiplier = 0.5  # Only active during burns
		"solar_array":
			type_multiplier = 1.2  # Exposed to radiation
		"cockpit":
			type_multiplier = 0.8  # Well-protected

	if not is_active:
		type_multiplier *= 0.3  # Much slower when not in use

	return base_rate * type_multiplier

## Apply wear to a component (pure, deterministic)
static func apply_daily_wear(component: Dictionary, random_value: float, is_active: bool = true) -> Dictionary:
	var base_degradation = calc_daily_degradation(component, is_active)

	# Random variation: 50%-150% of base rate
	var variation = 0.5 + (random_value * 1.0)
	var actual_degradation = base_degradation * variation

	var new_quality = maxf(0.0, component.quality - actual_degradation)

	return GameTypes.with_field(component, "quality", new_quality)

## Apply wear to all components in a list (pure)
static func apply_wear_to_components(components: Array, random_values: Array) -> Array:
	var result = []
	for i in range(components.size()):
		var random_val = random_values[i] if i < random_values.size() else 0.5
		result.append(apply_daily_wear(components[i], random_val))
	return result

## Check if component has critically degraded (for events)
static func is_critically_degraded(component: Dictionary) -> bool:
	return component.quality < 30.0

## Get components that need repair (quality below threshold)
static func get_components_needing_repair(components: Array, threshold: float = 50.0) -> Array:
	var needs_repair = []
	for comp in components:
		if comp.quality < threshold:
			needs_repair.append(comp)
	return needs_repair

## Apply repair to a component (pure)
## Uses spare parts to restore quality
static func repair_component(component: Dictionary, spare_parts_used: int, random_value: float) -> Dictionary:
	# Each spare part restores 10-20% quality (random variation)
	var repair_per_part = 10.0 + (random_value * 10.0)
	var total_repair = repair_per_part * spare_parts_used
	var new_quality = minf(component.max_quality, component.quality + total_repair)

	return GameTypes.with_field(component, "quality", new_quality)
