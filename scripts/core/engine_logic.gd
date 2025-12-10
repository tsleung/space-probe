class_name EngineLogic
extends RefCounted

## Pure functions for engine operations
## All functions are static, take inputs, return outputs, no side effects

# ============================================================================
# ENGINE FACTORY FUNCTIONS
# ============================================================================

static func create_traditional() -> Dictionary:
	return GameTypes.create_engine({
		"id": "traditional",
		"display_name": "Traditional Chemical Engine",
		"description": "Pressurized explosive gas propulsion. Reliable but heavy and fuel-hungry.",
		"engine_class": GameTypes.EngineClass.TRADITIONAL,
		"base_cost": 50_000_000,
		"build_days": 30,
		"mass_kg": 5000.0,
		"hex_size": 2,
		"thrust_n": 2_000_000.0,
		"specific_impulse_s": 450.0,
		"fuel_type": "Liquid Hydrogen/Oxygen",
		"fuel_consumption_kg_s": 500.0,
		"requires_space_assembly": false,
		"test_cost_per_cycle": 10_000_000,
		"test_days_per_cycle": 5,
		"quality_per_test": 6.0
	})

static func create_hermes() -> Dictionary:
	return GameTypes.create_engine({
		"id": "hermes",
		"display_name": "HERMES Ion Engine",
		"description": "Xenon ion propulsion. 2mm/s² acceleration, highly efficient for long journeys.",
		"engine_class": GameTypes.EngineClass.HERMES,
		"base_cost": 200_000_000,
		"build_days": 90,
		"mass_kg": 2000.0,
		"hex_size": 2,
		"thrust_n": 5.0,
		"specific_impulse_s": 3000.0,
		"fuel_type": "Xenon Gas",
		"fuel_consumption_kg_s": 0.001,
		"requires_space_assembly": true,
		"test_cost_per_cycle": 15_000_000,
		"test_days_per_cycle": 7,
		"quality_per_test": 5.0
	})

static func create_hall_thruster() -> Dictionary:
	return GameTypes.create_engine({
		"id": "hall_thruster",
		"display_name": "Hall Effect Thruster",
		"description": "40 km/s exhaust velocity. 10x more fuel efficient than chemical rockets.",
		"engine_class": GameTypes.EngineClass.HALL_THRUSTER,
		"base_cost": 150_000_000,
		"build_days": 60,
		"mass_kg": 1500.0,
		"hex_size": 2,
		"thrust_n": 2.0,
		"specific_impulse_s": 4000.0,
		"fuel_type": "Xenon/Krypton",
		"fuel_consumption_kg_s": 0.0005,
		"requires_space_assembly": true,
		"test_cost_per_cycle": 12_000_000,
		"test_days_per_cycle": 5,
		"quality_per_test": 6.0
	})

static func create_nuclear() -> Dictionary:
	return GameTypes.create_engine({
		"id": "nuclear",
		"display_name": "Nuclear Thermal Engine",
		"description": "Fission-powered propulsion. Powerful but risks containment leaks.",
		"engine_class": GameTypes.EngineClass.NUCLEAR,
		"base_cost": 500_000_000,
		"build_days": 180,
		"mass_kg": 8000.0,
		"hex_size": 3,
		"thrust_n": 250_000.0,
		"specific_impulse_s": 900.0,
		"fuel_type": "Liquid Hydrogen",
		"fuel_consumption_kg_s": 30.0,
		"has_radiation_risk": true,
		"containment_leak_chance": 0.02,
		"requires_space_assembly": true,
		"test_cost_per_cycle": 25_000_000,
		"test_days_per_cycle": 10,
		"quality_per_test": 4.0
	})

static func create_solar_sail() -> Dictionary:
	return GameTypes.create_engine({
		"id": "solar_sail",
		"display_name": "Solar Sail",
		"description": "Uses solar radiation pressure. No fuel required but very slow acceleration.",
		"engine_class": GameTypes.EngineClass.SOLAR_SAIL,
		"base_cost": 80_000_000,
		"build_days": 45,
		"mass_kg": 500.0,
		"hex_size": 2,
		"thrust_n": 0.01,
		"specific_impulse_s": INF,
		"fuel_type": "None (Solar Radiation)",
		"fuel_consumption_kg_s": 0.0,
		"requires_space_assembly": true,
		"test_cost_per_cycle": 5_000_000,
		"test_days_per_cycle": 3,
		"quality_per_test": 8.0
	})

static func create_laser_sail() -> Dictionary:
	return GameTypes.create_engine({
		"id": "laser_sail",
		"display_name": "Laser Sail",
		"description": "Ground-based lasers push the sail. Fast but requires Earth infrastructure.",
		"engine_class": GameTypes.EngineClass.LASER_SAIL,
		"base_cost": 300_000_000,
		"build_days": 60,
		"mass_kg": 600.0,
		"hex_size": 2,
		"thrust_n": 1.0,
		"specific_impulse_s": INF,
		"fuel_type": "None (Ground Laser)",
		"fuel_consumption_kg_s": 0.0,
		"requires_space_assembly": true,
		"test_cost_per_cycle": 20_000_000,
		"test_days_per_cycle": 5,
		"quality_per_test": 5.0
	})

static func create_pulsed_plasma() -> Dictionary:
	return GameTypes.create_engine({
		"id": "pulsed_plasma",
		"display_name": "Pulsed Plasma Thruster",
		"description": "Electromagnetic pulses accelerate plasma. Good balance of thrust and efficiency.",
		"engine_class": GameTypes.EngineClass.PULSED_PLASMA,
		"base_cost": 120_000_000,
		"build_days": 50,
		"mass_kg": 1200.0,
		"hex_size": 2,
		"thrust_n": 0.5,
		"specific_impulse_s": 1500.0,
		"fuel_type": "Teflon/PTFE",
		"fuel_consumption_kg_s": 0.0001,
		"requires_space_assembly": true,
		"test_cost_per_cycle": 8_000_000,
		"test_days_per_cycle": 4,
		"quality_per_test": 7.0
	})

static func create_magnetoplasmadynamic() -> Dictionary:
	return GameTypes.create_engine({
		"id": "mpd",
		"display_name": "Magnetoplasmadynamic Thruster",
		"description": "High-power electromagnetic propulsion. Requires significant power supply.",
		"engine_class": GameTypes.EngineClass.MAGNETOPLASMADYNAMIC,
		"base_cost": 250_000_000,
		"build_days": 90,
		"mass_kg": 3000.0,
		"hex_size": 2,
		"thrust_n": 20.0,
		"specific_impulse_s": 5000.0,
		"fuel_type": "Lithium/Argon",
		"fuel_consumption_kg_s": 0.004,
		"requires_space_assembly": true,
		"test_cost_per_cycle": 18_000_000,
		"test_days_per_cycle": 6,
		"quality_per_test": 5.0
	})

static func create_vasimr() -> Dictionary:
	return GameTypes.create_engine({
		"id": "vasimr",
		"display_name": "VASIMR Engine",
		"description": "Variable Specific Impulse Magnetoplasma Rocket. Adjustable thrust/efficiency ratio.",
		"engine_class": GameTypes.EngineClass.VASIMR,
		"base_cost": 400_000_000,
		"build_days": 120,
		"mass_kg": 2500.0,
		"hex_size": 2,
		"thrust_n": 6.0,
		"specific_impulse_s": 5000.0,
		"fuel_type": "Argon/Hydrogen",
		"fuel_consumption_kg_s": 0.001,
		"requires_space_assembly": true,
		"test_cost_per_cycle": 22_000_000,
		"test_days_per_cycle": 8,
		"quality_per_test": 4.0
	})

static func get_all_engines() -> Array:
	return [
		create_traditional(),
		create_hermes(),
		create_hall_thruster(),
		create_nuclear(),
		create_solar_sail(),
		create_laser_sail(),
		create_pulsed_plasma(),
		create_magnetoplasmadynamic(),
		create_vasimr()
	]

static func get_engine_by_id(id: String) -> Dictionary:
	for engine in get_all_engines():
		if engine.id == id:
			return engine
	return {}

# ============================================================================
# ENGINE CALCULATIONS (pure)
# ============================================================================

## Calculate delta-v capacity (Tsiolkovsky rocket equation)
static func calc_delta_v(
	specific_impulse_s: float,
	dry_mass_kg: float,
	fuel_mass_kg: float
) -> float:
	if specific_impulse_s == INF:
		return INF  # Solar/laser sails
	var g0 = 9.80665  # Standard gravity
	var mass_ratio = (dry_mass_kg + fuel_mass_kg) / dry_mass_kg
	return specific_impulse_s * g0 * log(mass_ratio)

## Calculate burn time for a given delta-v
static func calc_burn_time_seconds(
	delta_v_needed: float,
	thrust_n: float,
	ship_mass_kg: float
) -> float:
	if thrust_n <= 0:
		return INF
	var acceleration = thrust_n / ship_mass_kg
	return delta_v_needed / acceleration

## Calculate fuel needed for a burn
static func calc_fuel_needed_kg(
	burn_time_s: float,
	fuel_consumption_kg_s: float
) -> float:
	return burn_time_s * fuel_consumption_kg_s

## Estimate travel time to Mars based on engine and timing
static func calc_mars_travel_days(
	engine: Dictionary,
	ship_mass_kg: float,
	days_past_window: int
) -> int:
	var base_days = 180  # Optimal Hohmann transfer

	# Penalty for missing launch window
	var window_penalty = maxi(0, days_past_window) * 0.5

	# Engine efficiency bonus (higher specific impulse = faster)
	var efficiency_factor = 1.0
	if engine.specific_impulse_s < INF:
		efficiency_factor = 3000.0 / maxf(engine.specific_impulse_s, 100.0)
		efficiency_factor = clampf(efficiency_factor, 0.5, 2.0)

	# Thrust affects acceleration (higher thrust = can do faster transfers)
	var thrust_factor = 1.0
	if engine.thrust_n > 0:
		var twr = engine.thrust_n / (ship_mass_kg * 9.8)
		thrust_factor = 1.0 / clampf(twr * 10, 0.5, 2.0)

	var total_days = base_days * efficiency_factor * thrust_factor + window_penalty
	return int(total_days)

## Check if engine has radiation risk event (pure, deterministic)
static func check_radiation_event(
	engine: Dictionary,
	random_value: float
) -> Dictionary:
	if not engine.has_radiation_risk:
		return {"occurred": false}

	var occurred = random_value < engine.containment_leak_chance
	return {
		"occurred": occurred,
		"severity": random_value * 100 if occurred else 0.0,
		"description": "Containment leak detected in nuclear engine!" if occurred else ""
	}
