## Resource management system.
## Handles consumption, production, and scarcity for all resource types.
##
## All functions are static and pure.
class_name ResourceSystem
extends RefCounted


## ============================================================================
## DAILY CONSUMPTION
## ============================================================================

## Apply daily resource consumption
static func consume_daily(
	state: Dictionary,
	balance: Dictionary,
	_rng: RNGManager
) -> Dictionary:
	var new_state = state.duplicate(true)
	var resources = new_state.get("resources", {})
	var crew = new_state.get("crew", [])
	var living_crew = _count_living_crew(crew)

	if living_crew == 0:
		return new_state

	# Get balance values
	var food_per_crew = balance.get("daily_food_per_crew", 2.0)
	var water_per_crew = balance.get("daily_water_per_crew", 3.0)
	var oxygen_per_crew = balance.get("daily_oxygen_per_crew", 0.84)

	# Get recycling efficiency from life support quality
	var life_support_quality = _get_life_support_quality(new_state)
	var water_recycling = balance.get("water_recycling_base_efficiency", 0.85) * (life_support_quality / 100.0)
	var oxygen_recycling = balance.get("oxygen_recycling_base_efficiency", 0.85) * (life_support_quality / 100.0)

	# Apply rationing modifier
	var rationing = new_state.get("rationing_level", "none")
	var rationing_multiplier = _get_rationing_multiplier(rationing, balance)

	# Calculate actual consumption
	var food_consumed = food_per_crew * living_crew * rationing_multiplier
	var water_consumed = water_per_crew * living_crew * (1.0 - water_recycling) * rationing_multiplier
	var oxygen_consumed = oxygen_per_crew * living_crew * (1.0 - oxygen_recycling)

	# Apply consumption
	resources = _consume_resource(resources, "food", food_consumed)
	resources = _consume_resource(resources, "water", water_consumed)
	resources = _consume_resource(resources, "oxygen", oxygen_consumed)

	new_state["resources"] = resources
	return new_state


## Consume a specific resource
static func _consume_resource(resources: Dictionary, resource_id: String, amount: float) -> Dictionary:
	var new_resources = resources.duplicate(true)

	if not new_resources.has(resource_id):
		return new_resources

	var resource = new_resources[resource_id]
	resource["current"] = max(0.0, resource.get("current", 0) - amount)
	new_resources[resource_id] = resource

	return new_resources


## Get life support quality from ship state
static func _get_life_support_quality(state: Dictionary) -> float:
	var ship = state.get("ship", {})
	var life_support = HexGridSystem.get_component_by_id(ship, "life_support")

	if life_support.is_empty():
		return 0.0

	return life_support.get("quality", 50.0)


## Get rationing multiplier
static func _get_rationing_multiplier(level: String, balance: Dictionary) -> float:
	var rationing_levels = balance.get("rationing_levels", {})
	var level_data = rationing_levels.get(level, {})
	return level_data.get("consumption", 1.0)


## Count living crew members
static func _count_living_crew(crew: Array) -> int:
	var count = 0
	for member in crew:
		if member.get("status") != GameTypes.CrewStatus.DEAD:
			count += 1
	return count


## ============================================================================
## STARVATION AND DEPRIVATION
## ============================================================================

## Apply effects of resource deprivation
static func apply_deprivation(
	state: Dictionary,
	balance: Dictionary,
	_rng: RNGManager
) -> Dictionary:
	var new_state = state.duplicate(true)
	var resources = new_state.get("resources", {})
	var crew = new_state.get("crew", [])

	# Check food
	var food = resources.get("food", {}).get("current", 0)
	if food <= 0:
		var health_loss = balance.get("starvation_health_loss", 5)
		var morale_loss = balance.get("starvation_morale_loss", 10)
		crew = _apply_crew_stat_change(crew, "health", -health_loss)
		crew = _apply_crew_stat_change(crew, "morale", -morale_loss)
		new_state["log_entry"] = "Crew is starving!"

	# Check water
	var water = resources.get("water", {}).get("current", 0)
	if water <= 0:
		var health_loss = balance.get("dehydration_health_loss", 10)
		var morale_loss = balance.get("dehydration_morale_loss", 15)
		crew = _apply_crew_stat_change(crew, "health", -health_loss)
		crew = _apply_crew_stat_change(crew, "morale", -morale_loss)
		new_state["log_entry"] = "Crew is dehydrated!"

	# Check oxygen (critical)
	var oxygen = resources.get("oxygen", {}).get("current", 0)
	if oxygen <= 0:
		var health_loss = balance.get("suffocation_health_loss", 25)
		crew = _apply_crew_stat_change(crew, "health", -health_loss)
		new_state["log_entry"] = "CRITICAL: Oxygen depleted!"

	new_state["crew"] = crew
	return new_state


## Apply stat change to all living crew
static func _apply_crew_stat_change(crew: Array, stat: String, amount: float) -> Array:
	var new_crew = crew.duplicate(true)

	for i in range(new_crew.size()):
		if new_crew[i].get("status") != GameTypes.CrewStatus.DEAD:
			var current = new_crew[i].get(stat, 100.0)
			new_crew[i][stat] = clamp(current + amount, 0.0, 100.0)

	return new_crew


## ============================================================================
## RESOURCE QUERIES
## ============================================================================

## Calculate days of supply remaining for a resource
static func days_remaining(state: Dictionary, resource_id: String, balance: Dictionary) -> float:
	var resources = state.get("resources", {})
	var resource = resources.get(resource_id, {})
	var current = resource.get("current", 0)

	var crew = state.get("crew", [])
	var living_crew = _count_living_crew(crew)

	if living_crew == 0:
		return INF

	var daily_rate: float
	match resource_id:
		"food":
			daily_rate = balance.get("daily_food_per_crew", 2.0) * living_crew
		"water":
			var life_support_quality = _get_life_support_quality(state)
			var recycling = balance.get("water_recycling_base_efficiency", 0.85) * (life_support_quality / 100.0)
			daily_rate = balance.get("daily_water_per_crew", 3.0) * living_crew * (1.0 - recycling)
		"oxygen":
			var life_support_quality = _get_life_support_quality(state)
			var recycling = balance.get("oxygen_recycling_base_efficiency", 0.85) * (life_support_quality / 100.0)
			daily_rate = balance.get("daily_oxygen_per_crew", 0.84) * living_crew * (1.0 - recycling)
		_:
			daily_rate = resource.get("daily_consumption", 1.0)

	if daily_rate <= 0:
		return INF

	return current / daily_rate


## Get resource status level
static func get_resource_status(state: Dictionary, resource_id: String, balance: Dictionary) -> String:
	var days = days_remaining(state, resource_id, balance)

	var warning = balance.get("warning_%s_days" % resource_id, 45)
	var critical = balance.get("critical_%s_days" % resource_id, 30)
	var emergency = balance.get("emergency_%s_days" % resource_id, 15)

	if days <= emergency:
		return "emergency"
	elif days <= critical:
		return "critical"
	elif days <= warning:
		return "warning"
	else:
		return "normal"


## Get all resource statuses
static func get_all_resource_statuses(state: Dictionary, balance: Dictionary) -> Dictionary:
	return {
		"food": get_resource_status(state, "food", balance),
		"water": get_resource_status(state, "water", balance),
		"oxygen": get_resource_status(state, "oxygen", balance),
		"fuel": get_resource_status(state, "fuel", balance)
	}


## ============================================================================
## RESOURCE MODIFICATION
## ============================================================================

## Add resources (from discovery, resupply, etc.)
static func add_resource(state: Dictionary, resource_id: String, amount: float) -> Dictionary:
	var new_state = state.duplicate(true)
	var resources = new_state.get("resources", {})

	if not resources.has(resource_id):
		resources[resource_id] = {"current": 0, "max": amount}

	var resource = resources[resource_id]
	var max_val = resource.get("max", 1000)
	resource["current"] = min(resource.get("current", 0) + amount, max_val)
	resources[resource_id] = resource

	new_state["resources"] = resources
	return new_state


## Remove resources
static func remove_resource(state: Dictionary, resource_id: String, amount: float) -> Dictionary:
	var new_state = state.duplicate(true)
	var resources = new_state.get("resources", {})

	if not resources.has(resource_id):
		return new_state

	var resource = resources[resource_id]
	resource["current"] = max(0, resource.get("current", 0) - amount)
	resources[resource_id] = resource

	new_state["resources"] = resources
	return new_state


## Set rationing level
static func set_rationing(state: Dictionary, level: String) -> Dictionary:
	var new_state = state.duplicate(true)
	new_state["rationing_level"] = level
	return new_state


## ============================================================================
## SUPPLY PLANNING
## ============================================================================

## Calculate recommended supplies for journey
static func calculate_recommended_supplies(
	crew_count: int,
	travel_days: int,
	life_support_quality: float,
	balance: Dictionary
) -> Dictionary:
	var safety_margin = balance.get("supply_safety_margin", 1.3)

	var food_per_day = balance.get("daily_food_per_crew", 2.0) * crew_count
	var water_recycling = balance.get("water_recycling_base_efficiency", 0.85) * (life_support_quality / 100.0)
	var oxygen_recycling = balance.get("oxygen_recycling_base_efficiency", 0.85) * (life_support_quality / 100.0)

	var water_per_day = balance.get("daily_water_per_crew", 3.0) * crew_count * (1.0 - water_recycling)
	var oxygen_per_day = balance.get("daily_oxygen_per_crew", 0.84) * crew_count * (1.0 - oxygen_recycling)

	return {
		"food": ceil(food_per_day * travel_days * safety_margin),
		"water": ceil(water_per_day * travel_days * safety_margin),
		"oxygen": ceil(oxygen_per_day * travel_days * safety_margin)
	}


## Calculate total supply mass
static func calculate_supply_mass(supplies: Dictionary) -> float:
	var mass: float = 0.0

	mass += supplies.get("food", 0)  # kg
	mass += supplies.get("water", 0)  # kg (L ~= kg for water)
	mass += supplies.get("oxygen", 0)  # kg

	return mass
