extends RefCounted
class_name MOTTypes

## Mars Odyssey Trek - Type Definitions
## Enums, constants, and factory functions for MOT state

# ============================================================================
# ENUMS
# ============================================================================

enum Phase {
	SHIP_BUILDING,
	TRAVEL_TO_MARS,
	MARS_ARRIVAL,
	MARS_BASE,
	MARS_DEPARTURE,
	TRAVEL_TO_EARTH,
	EARTH_ARRIVAL,
	GAME_OVER
}

enum ConstructionApproach {
	EARTH_BUILT,      # Traditional: build on Earth, launch assembled
	ORBITAL_ASSEMBLY, # Launch components, assemble in orbit
	LUNAR_SHIPYARD    # Build at Moon base
}

enum EngineType {
	CHEMICAL,        # Reliable workhorse
	ION_DRIVE,       # Efficient, needs space assembly
	NUCLEAR_THERMAL, # Fast, radiation risk
	SOLAR_SAIL       # No fuel, slow
}

enum ShipClass {
	CAPSULE,   # Cramped, tough, 3000 kg cargo
	STANDARD,  # Balanced, 5000 kg cargo
	CRUISER    # Comfortable, fragile, 8000 kg cargo
}

enum LifeSupportTier {
	BASIC,     # 80% recycling, high risk
	STANDARD,  # 90% recycling, medium risk
	REDUNDANT  # 95% recycling, low risk
}

enum WindowQuality {
	OPTIMAL,
	GOOD,
	POOR,
	RUSH
}

# ============================================================================
# CONSTRUCTION APPROACH DATA
# ============================================================================

const CONSTRUCTION_APPROACHES = {
	ConstructionApproach.EARTH_BUILT: {
		"id": "earth_built",
		"name": "Earth-Built",
		"description": "Traditional approach: build everything on Earth, launch assembled.",
		"layman": "Like driving uphill with a full backpack - proven but heavy.",
		"power_user": "9.4 km/s delta-v to LEO. Higher mass penalty but 95% assembly reliability.",
		"fuel_multiplier": 1.3,
		"reliability": 0.95,
		"cost_multiplier": 1.0,
		"prep_days": 30
	},
	ConstructionApproach.ORBITAL_ASSEMBLY: {
		"id": "orbital_assembly",
		"name": "Orbital Assembly",
		"description": "Launch components separately, assemble at space station.",
		"layman": "Assembling furniture in a swimming pool - lighter but trickier.",
		"power_user": "Lower mass penalty. 3-5% failure rate per component during EVA integration.",
		"fuel_multiplier": 1.0,
		"reliability": 0.85,
		"cost_multiplier": 1.3,
		"prep_days": 45
	},
	ConstructionApproach.LUNAR_SHIPYARD: {
		"id": "lunar_shipyard",
		"name": "Lunar Shipyard",
		"description": "Build at Moon base, launch from lower gravity.",
		"layman": "Building on the Moon means less gravity to fight when launching.",
		"power_user": "2.4 km/s to escape. Lightest option but newest technology.",
		"fuel_multiplier": 0.8,
		"reliability": 0.80,
		"cost_multiplier": 1.6,
		"prep_days": 60
	}
}

# ============================================================================
# ENGINE DATA
# ============================================================================

const ENGINES = {
	EngineType.CHEMICAL: {
		"id": "chemical",
		"name": "Chemical Rocket",
		"nickname": "The Reliable Workhorse",
		"description": "Proven and reliable. The workhorse of early space exploration.",
		"layman": "Like a sprint - lots of power, burns fuel fast. What got us to the Moon.",
		"power_user": "Isp ~450s, high thrust. Enables faster Hohmann transfers but requires ~60% more propellant mass.",
		"travel_time_modifier": 1.0,
		"fuel_efficiency": 0.6,
		"risk": 0.1,
		"cost": 40000000,
		"requires_space_assembly": false
	},
	EngineType.ION_DRIVE: {
		"id": "ion_drive",
		"name": "Ion Drive",
		"nickname": "The Patient Sipper",
		"description": "High efficiency, low thrust. Ideal for patient crews.",
		"layman": "A gentle push for months - sips fuel like a marathon runner.",
		"power_user": "Isp ~3000s, millinewton thrust. Requires continuous operation over transfer.",
		"travel_time_modifier": 0.85,
		"fuel_efficiency": 0.9,
		"risk": 0.2,
		"cost": 120000000,
		"requires_space_assembly": true
	},
	EngineType.NUCLEAR_THERMAL: {
		"id": "nuclear_thermal",
		"name": "Nuclear Thermal",
		"nickname": "The Hot Rod",
		"description": "Powerful and efficient, but requires careful handling.",
		"layman": "Splits atoms to heat propellant. Fast, but radiation is no joke.",
		"power_user": "Isp ~900s. Enables faster transfers. 0.1% containment leak risk per month.",
		"travel_time_modifier": 0.7,
		"fuel_efficiency": 0.75,
		"risk": 0.35,
		"cost": 200000000,
		"requires_space_assembly": true,
		"has_radiation_risk": true
	},
	EngineType.SOLAR_SAIL: {
		"id": "solar_sail",
		"name": "Solar Sail",
		"nickname": "The Sun Rider",
		"description": "No fuel required, but slow. Free energy from the sun.",
		"layman": "A giant mirror pushed by sunlight. Slow but never runs out of fuel.",
		"power_user": "Infinite Isp, but acceleration falls with 1/r² from Sun. Weather dependent.",
		"travel_time_modifier": 1.3,
		"fuel_efficiency": 1.0,  # No fuel needed
		"risk": 0.25,
		"cost": 80000000,
		"requires_space_assembly": true,
		"no_fuel": true
	}
}

# ============================================================================
# SHIP CLASS DATA
# ============================================================================

const SHIP_CLASSES = {
	ShipClass.CAPSULE: {
		"id": "capsule",
		"name": "Capsule",
		"description": "Apollo-style. Tight but tough.",
		"layman": "A camping trip in a tent - cramped but reliable.",
		"cargo_capacity": 3000,
		"crew_comfort": 0.6,  # Morale decay multiplier (higher = faster decay)
		"durability": 1.2,
		"cost": 150000000
	},
	ShipClass.STANDARD: {
		"id": "standard",
		"name": "Standard",
		"description": "Balanced approach for a long journey.",
		"layman": "An RV - reasonable space, reasonable weight.",
		"cargo_capacity": 5000,
		"crew_comfort": 1.0,
		"durability": 1.0,
		"cost": 250000000
	},
	ShipClass.CRUISER: {
		"id": "cruiser",
		"name": "Cruiser",
		"description": "Comfortable but fragile. More room, more to break.",
		"layman": "Bringing the whole house - comfortable but complex.",
		"cargo_capacity": 8000,
		"crew_comfort": 0.7,  # Lower = slower morale decay
		"durability": 0.8,
		"cost": 400000000
	}
}

# ============================================================================
# SHIP UPGRADES
# ============================================================================

const SHIP_UPGRADES = {
	"medical_bay": {
		"id": "medical_bay",
		"name": "Enhanced Medical Bay",
		"description": "Better healing and sickness recovery.",
		"cost": 40000000,
		"mass": 800,
		"effects": {"healing_bonus": 0.5, "sickness_recovery_bonus": 0.3}
	},
	"science_lab": {
		"id": "science_lab",
		"name": "Science Laboratory",
		"description": "Bonus to Phase 3 experiments.",
		"cost": 45000000,
		"mass": 1000,
		"effects": {"experiment_bonus": 0.15}
	},
	"observation_deck": {
		"id": "observation_deck",
		"name": "Observation Deck",
		"description": "Morale bonus during travel.",
		"cost": 30000000,
		"mass": 600,
		"effects": {"morale_bonus": 0.2}
	},
	"exercise_facility": {
		"id": "exercise_facility",
		"name": "Exercise Facility",
		"description": "Reduces health decay during travel.",
		"cost": 20000000,
		"mass": 400,
		"effects": {"health_decay_reduction": 0.3}
	},
	"backup_life_support": {
		"id": "backup_life_support",
		"name": "Backup Life Support",
		"description": "Redundancy for critical systems.",
		"cost": 35000000,
		"mass": 500,
		"effects": {"life_support_redundancy": true}
	},
	"extra_cargo": {
		"id": "extra_cargo",
		"name": "Extra Cargo Module",
		"description": "+1,500 kg cargo capacity.",
		"cost": 25000000,
		"mass": 300,
		"effects": {"cargo_bonus": 1500}
	}
}

# ============================================================================
# LIFE SUPPORT DATA
# ============================================================================

const LIFE_SUPPORT_TIERS = {
	LifeSupportTier.BASIC: {
		"id": "basic",
		"name": "Basic",
		"description": "Single system. One failure = crisis.",
		"recycling_efficiency": 0.80,
		"failure_risk": 0.15,
		"mass": 800,
		"cost": 30000000
	},
	LifeSupportTier.STANDARD: {
		"id": "standard",
		"name": "Standard",
		"description": "Primary + manual backup. Survivable failure.",
		"recycling_efficiency": 0.90,
		"failure_risk": 0.08,
		"mass": 1200,
		"cost": 50000000
	},
	LifeSupportTier.REDUNDANT: {
		"id": "redundant",
		"name": "Redundant",
		"description": "Triple redundancy. Can lose two systems.",
		"recycling_efficiency": 0.95,
		"failure_risk": 0.02,
		"mass": 1800,
		"cost": 80000000
	}
}

# ============================================================================
# STATE FACTORIES
# ============================================================================

static func create_phase1_state(difficulty: String = "normal") -> Dictionary:
	## Create initial state for Phase 1 (Ship Building)
	var budget = 650000000  # $650M default
	match difficulty:
		"easy":
			budget = 800000000
		"hard":
			budget = 500000000

	return {
		"phase": Phase.SHIP_BUILDING,
		"difficulty": difficulty,
		"current_day": 0,
		"start_year": 2040,

		# Budget
		"budget_total": budget,
		"budget_spent": 0,
		"budget_remaining": budget,

		# Selections (null until chosen)
		"launch_window": null,  # MOTOrbital.LaunchWindow data
		"construction_approach": null,
		"engine": null,
		"ship_class": null,
		"life_support": null,
		"upgrades": [],  # Array of upgrade IDs
		"crew": [],  # Array of crew IDs (4 required)

		# Cargo
		"cargo_capacity": 0,  # Set when ship class chosen
		"cargo_used": 0,
		"cargo_manifest": {
			"food_days": 0,
			"water_reserve": 0,
			"spare_parts": 0,
			"medical_kits": 0,
			"equipment": 0
		},

		# Computed values
		"fuel_required": 0,
		"travel_days_estimate": 180,
		"reliability_estimate": 0.9,

		# Readiness
		"is_ready_to_launch": false,
		"readiness_issues": []
	}

static func calculate_budget_breakdown(state: Dictionary) -> Dictionary:
	## Calculate where budget is being spent
	var breakdown = {
		"engine": 0,
		"ship_class": 0,
		"life_support": 0,
		"upgrades": 0,
		"cargo": 0,
		"total": 0,
		"remaining": state.budget_total
	}

	if state.engine != null:
		breakdown.engine = ENGINES[state.engine].cost

	if state.ship_class != null:
		breakdown.ship_class = SHIP_CLASSES[state.ship_class].cost

	if state.life_support != null:
		breakdown.life_support = LIFE_SUPPORT_TIERS[state.life_support].cost

	for upgrade_id in state.upgrades:
		if SHIP_UPGRADES.has(upgrade_id):
			breakdown.upgrades += SHIP_UPGRADES[upgrade_id].cost

	# Cargo costs would be calculated separately
	breakdown.total = breakdown.engine + breakdown.ship_class + breakdown.life_support + breakdown.upgrades
	breakdown.remaining = state.budget_total - breakdown.total

	return breakdown

static func check_launch_readiness(state: Dictionary) -> Dictionary:
	## Check if all requirements are met for launch
	var issues = []

	if state.launch_window == null:
		issues.append("No launch window selected")

	if state.engine == null:
		issues.append("No engine selected")

	if state.ship_class == null:
		issues.append("No ship class selected")

	if state.life_support == null:
		issues.append("No life support tier selected")

	if state.crew.size() < 4:
		issues.append("Need 4 crew members (have %d)" % state.crew.size())

	# Check cargo minimums
	if state.cargo_manifest.food_days < 400:
		issues.append("Insufficient food (need 400+ days)")

	# Check budget
	var breakdown = calculate_budget_breakdown(state)
	if breakdown.remaining < 0:
		issues.append("Over budget by $%d" % abs(breakdown.remaining))

	return {
		"is_ready": issues.size() == 0,
		"issues": issues
	}
