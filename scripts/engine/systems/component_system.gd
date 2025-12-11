## Component management system.
## Handles quality degradation, testing, repair, and failure checks.
##
## All functions are static and pure.
class_name ComponentSystem
extends RefCounted


## ============================================================================
## COMPONENT STATE
## ============================================================================

## Component state enum for clarity
enum ComponentState {
	OPERATIONAL,  # quality > 70
	DEGRADED,     # quality 50-70
	DAMAGED,      # quality 30-50
	CRITICAL,     # quality 10-30
	DESTROYED     # quality <= 10
}


## Get component state from quality
static func get_component_state(quality: float) -> ComponentState:
	if quality > 70:
		return ComponentState.OPERATIONAL
	elif quality > 50:
		return ComponentState.DEGRADED
	elif quality > 30:
		return ComponentState.DAMAGED
	elif quality > 10:
		return ComponentState.CRITICAL
	else:
		return ComponentState.DESTROYED


## Get human-readable state name
static func get_state_name(state: ComponentState) -> String:
	match state:
		ComponentState.OPERATIONAL:
			return "Operational"
		ComponentState.DEGRADED:
			return "Degraded"
		ComponentState.DAMAGED:
			return "Damaged"
		ComponentState.CRITICAL:
			return "Critical"
		ComponentState.DESTROYED:
			return "Destroyed"
		_:
			return "Unknown"


## ============================================================================
## DAILY UPDATES
## ============================================================================

## Apply daily wear to all components
static func apply_daily_wear(
	state: Dictionary,
	balance: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var new_state = state.duplicate(true)
	var ship = new_state.get("ship", {})
	var components = HexGridSystem.get_all_components(ship)

	if components.is_empty():
		return new_state

	var base_wear = balance.get("base_component_wear_per_day", 0.02)
	var wear_variation = balance.get("component_wear_variation", 0.4)

	for comp in components:
		var position = comp.get("position", {})
		var key = HexMath.hex_key(position.get("q", 0), position.get("r", 0))

		# Calculate wear for this component
		var type_multiplier = _get_type_wear_multiplier(comp, balance)
		var random_factor = 1.0 - wear_variation + (rng.randf() * wear_variation * 2.0)
		var wear_amount = base_wear * type_multiplier * random_factor

		# Apply wear
		var new_quality = max(0.0, comp.get("quality", 100) - wear_amount)
		ship.components[key]["quality"] = new_quality

	new_state["ship"] = ship
	return new_state


## Get wear multiplier based on component type
static func _get_type_wear_multiplier(component: Dictionary, balance: Dictionary) -> float:
	var component_id = component.get("id", component.get("definition_id", ""))
	var wear_multipliers = balance.get("component_wear_multipliers", {})

	# Check for specific component multiplier
	if wear_multipliers.has(component_id):
		return wear_multipliers[component_id]

	# Default multipliers by category
	var category = component.get("category", "")
	match category:
		"propulsion":
			return 0.5  # Only active during burns
		"life_support":
			return 1.5  # Constant stress
		"power":
			return 1.2  # Radiation exposure
		"cargo":
			return 0.8  # Static storage
		"crew":
			return 1.0  # Normal use
		_:
			return 1.0


## ============================================================================
## TESTING AND QUALITY
## ============================================================================

## Run a test cycle on a component (increases quality)
static func test_component(
	state: Dictionary,
	component_position: Vector2i,
	balance: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var new_state = state.duplicate(true)
	var ship = new_state.get("ship", {})
	var key = HexMath.hex_key_v(component_position)

	if not ship.components.has(key):
		return new_state

	var component = ship.components[key]
	var current_quality = component.get("quality", 50)
	var max_quality = component.get("max_quality", 95)

	if current_quality >= max_quality:
		return new_state

	# Calculate quality gain
	var base_gain = balance.get("test_quality_gain_base", 8.0)
	var gain_variation = balance.get("test_quality_gain_variation", 0.4)
	var random_factor = 1.0 - gain_variation + (rng.randf() * gain_variation * 2.0)

	var quality_gain = base_gain * random_factor
	var new_quality = min(max_quality, current_quality + quality_gain)

	ship.components[key]["quality"] = new_quality
	ship.components[key]["is_tested"] = true
	ship.components[key]["test_count"] = component.get("test_count", 0) + 1

	new_state["ship"] = ship

	# Apply cost
	var test_cost = component.get("test_cost", balance.get("default_test_cost", 1000000))
	new_state["budget"] = max(0, new_state.get("budget", 0) - test_cost)

	return new_state


## Calculate failure probability for a component
static func calculate_failure_chance(component: Dictionary, balance: Dictionary) -> float:
	var quality = component.get("quality", 50)
	var base_failure = balance.get("component_base_failure_rate", 0.01)

	# Failure increases exponentially as quality drops
	# 100 quality = 0% base, 0 quality = 100% base
	var quality_factor = pow((100.0 - quality) / 100.0, 2)

	# Critical components have higher stakes
	if component.get("critical", false):
		quality_factor *= 1.5

	return base_failure * quality_factor


## Check for component failure
static func check_failure(
	component: Dictionary,
	balance: Dictionary,
	roll: float
) -> bool:
	var failure_chance = calculate_failure_chance(component, balance)
	return roll < failure_chance


## ============================================================================
## REPAIR
## ============================================================================

## Repair a component using spare parts
static func repair_component(
	state: Dictionary,
	component_position: Vector2i,
	crew_id: String,
	balance: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var new_state = state.duplicate(true)
	var ship = new_state.get("ship", {})
	var key = HexMath.hex_key_v(component_position)

	if not ship.components.has(key):
		return new_state

	# Check spare parts
	var resources = new_state.get("resources", {})
	var spare_parts = resources.get("spare_parts", {}).get("current", 0)

	if spare_parts < 1:
		return new_state

	var component = ship.components[key]
	var current_quality = component.get("quality", 50)

	# Get repair effectiveness from crew skill
	var crew = new_state.get("crew", [])
	var repair_bonus = 1.0
	for member in crew:
		if member.get("id") == crew_id:
			var engineering_skill = member.get("skills", {}).get("engineering", 50)
			repair_bonus = 0.5 + (engineering_skill / 100.0)  # 0.5 to 1.5

			# Specialty bonus
			if member.get("specialty") == "engineer" or member.get("role") == "engineer":
				repair_bonus *= 1.25
			break

	# Calculate repair amount
	var base_repair = balance.get("repair_base_amount", 15.0)
	var repair_variation = balance.get("repair_variation", 0.4)
	var random_factor = 1.0 - repair_variation + (rng.randf() * repair_variation * 2.0)

	var repair_amount = base_repair * repair_bonus * random_factor
	var new_quality = min(100.0, current_quality + repair_amount)

	# Apply changes
	ship.components[key]["quality"] = new_quality
	new_state["ship"] = ship

	# Consume spare parts
	resources["spare_parts"]["current"] = spare_parts - 1
	new_state["resources"] = resources

	return new_state


## Get components that need repair (quality below threshold)
static func get_components_needing_repair(
	state: Dictionary,
	threshold: float = 50.0
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ship = state.get("ship", {})
	var components = HexGridSystem.get_all_components(ship)

	for comp in components:
		if comp.get("quality", 100) < threshold:
			result.append(comp)

	# Sort by quality (worst first)
	result.sort_custom(func(a, b): return a.get("quality", 0) < b.get("quality", 0))

	return result


## ============================================================================
## COMPONENT QUERIES
## ============================================================================

## Get components in critical state
static func get_critical_components(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var ship = state.get("ship", {})
	var components = HexGridSystem.get_all_components(ship)

	for comp in components:
		var component_state = get_component_state(comp.get("quality", 100))
		if component_state == ComponentState.CRITICAL or component_state == ComponentState.DESTROYED:
			result.append(comp)

	return result


## Get average component quality
static func get_average_quality(state: Dictionary) -> float:
	var ship = state.get("ship", {})
	var components = HexGridSystem.get_all_components(ship)

	if components.is_empty():
		return 0.0

	var total: float = 0.0
	for comp in components:
		total += comp.get("quality", 0)

	return total / components.size()


## Get quality of a specific component type
static func get_component_quality(state: Dictionary, component_id: String) -> float:
	var ship = state.get("ship", {})
	var comp = HexGridSystem.get_component_by_id(ship, component_id)

	if comp.is_empty():
		return 0.0

	return comp.get("quality", 0)


## Check if a required component exists and is functional
static func has_functional_component(state: Dictionary, component_id: String) -> bool:
	var ship = state.get("ship", {})
	var comp = HexGridSystem.get_component_by_id(ship, component_id)

	if comp.is_empty():
		return false

	var component_state = get_component_state(comp.get("quality", 0))
	return component_state != ComponentState.DESTROYED


## ============================================================================
## EFFECTIVENESS CALCULATIONS
## ============================================================================

## Calculate component effectiveness (0.0 to 1.0)
static func calculate_effectiveness(component: Dictionary) -> float:
	var quality = component.get("quality", 50)
	var component_state = get_component_state(quality)

	match component_state:
		ComponentState.OPERATIONAL:
			return 1.0
		ComponentState.DEGRADED:
			return 0.85
		ComponentState.DAMAGED:
			return 0.6
		ComponentState.CRITICAL:
			return 0.3
		ComponentState.DESTROYED:
			return 0.0
		_:
			return 0.0


## Calculate life support effectiveness (affects resource recycling)
static func calculate_life_support_effectiveness(state: Dictionary) -> float:
	var ship = state.get("ship", {})
	var life_support = HexGridSystem.get_component_by_id(ship, "life_support")

	if life_support.is_empty():
		return 0.0

	return calculate_effectiveness(life_support)


## Calculate power generation capacity
static func calculate_power_capacity(state: Dictionary) -> float:
	var ship = state.get("ship", {})
	var components = HexGridSystem.get_all_components(ship)

	var total_power: float = 0.0

	for comp in components:
		var power_gen = comp.get("stats", {}).get("power_generation", 0)
		if power_gen > 0:
			var effectiveness = calculate_effectiveness(comp)
			total_power += power_gen * effectiveness

	return total_power


## Calculate power consumption
static func calculate_power_consumption(state: Dictionary) -> float:
	var ship = state.get("ship", {})
	var components = HexGridSystem.get_all_components(ship)

	var total_draw: float = 0.0

	for comp in components:
		var power_draw = comp.get("stats", {}).get("power_draw", 0)
		total_draw += power_draw

	return total_draw


## Check if ship has enough power
static func has_sufficient_power(state: Dictionary) -> bool:
	var capacity = calculate_power_capacity(state)
	var consumption = calculate_power_consumption(state)
	return capacity >= consumption
