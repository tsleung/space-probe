extends RefCounted
class_name ColonySimEconomy

## Colony Sim Economy Logic - SIMPLIFIED
## Pure functions for resource production, consumption, and building operations
## All functions are static and deterministic

# ============================================================================
# CONSTANTS
# ============================================================================

# Per-colonist consumption per year
const FOOD_PER_COLONIST = 730.0  # 2kg/day * 365
const WATER_PER_COLONIST = 180.0  # Net after recycling
const OXYGEN_PER_COLONIST = 36.5  # Net after recycling
const POWER_PER_COLONIST = 5.0  # kW average

# ============================================================================
# RESOURCE PRODUCTION & CONSUMPTION
# ============================================================================

## Calculate yearly production from all buildings
static func calc_yearly_production(buildings: Array, colonists: Array, _resources: Dictionary = {}) -> Dictionary:
	var production: Dictionary = {}

	for building in buildings:
		if not building.is_operational or building.is_under_construction:
			continue

		var efficiency = calc_building_efficiency(building, colonists)
		var building_def = ColonySimTypes.get_building_definition(building.type)

		var produces = building_def.get("produces", {})
		for resource_name in produces:
			var base_amount = produces[resource_name]
			var actual = base_amount * efficiency
			production[resource_name] = production.get(resource_name, 0.0) + actual

		# Power generation
		if building_def.has("power_generation"):
			production["power"] = production.get("power", 0.0) + building_def.power_generation * efficiency

	return production

## Calculate yearly consumption from buildings and colonists
static func calc_yearly_consumption(colonists_or_buildings, buildings_or_none = null) -> Dictionary:
	var colonists: Array
	var buildings: Array

	# Handle both signatures: (colonists, buildings) and (buildings, colonists)
	if buildings_or_none == null:
		colonists = colonists_or_buildings
		buildings = []
	elif colonists_or_buildings is Array and colonists_or_buildings.size() > 0:
		if colonists_or_buildings[0].has("is_alive"):
			colonists = colonists_or_buildings
			buildings = buildings_or_none
		else:
			buildings = colonists_or_buildings
			colonists = buildings_or_none
	else:
		colonists = colonists_or_buildings
		buildings = buildings_or_none if buildings_or_none else []

	var consumption: Dictionary = {}

	# Colonist consumption
	var alive_count = ColonySimPopulation.count_alive(colonists)
	consumption["food"] = alive_count * FOOD_PER_COLONIST
	consumption["water"] = alive_count * WATER_PER_COLONIST
	consumption["oxygen"] = alive_count * OXYGEN_PER_COLONIST

	# Building power consumption
	var total_power = alive_count * POWER_PER_COLONIST
	for building in buildings:
		if not building.is_operational or building.is_under_construction:
			continue
		var building_def = ColonySimTypes.get_building_definition(building.type)
		total_power += building_def.get("power_consumption", 0.0)

	consumption["power"] = total_power

	return consumption

## Apply yearly resource changes
static func apply_yearly_resources(resources: Dictionary, production: Dictionary, consumption: Dictionary) -> Dictionary:
	var new_resources = resources.duplicate()
	var shortages: Array = []

	# Apply production first
	for resource_name in production:
		new_resources[resource_name] = new_resources.get(resource_name, 0.0) + production[resource_name]

	# Then apply consumption
	for resource_name in consumption:
		var current = new_resources.get(resource_name, 0.0)
		var consumed = consumption[resource_name]

		if current >= consumed:
			new_resources[resource_name] = current - consumed
		else:
			new_resources[resource_name] = 0.0
			shortages.append(resource_name)

	return {
		"resources": new_resources,
		"shortages": shortages
	}

# ============================================================================
# BUILDING OPERATIONS
# ============================================================================

## Calculate building efficiency (0.0 - 1.0)
static func calc_building_efficiency(building: Dictionary, colonists: Array) -> float:
	if not building.is_operational:
		return 0.0

	var efficiency = building.condition / 100.0

	# Worker staffing
	var building_def = ColonySimTypes.get_building_definition(building.type)
	var required = building_def.get("required_workers", 0)

	if required > 0:
		var assigned = building.assigned_workers.size()
		if assigned < required:
			efficiency *= maxf(0.5, float(assigned) / float(required))

	return clampf(efficiency, 0.0, 1.0)

## Apply yearly maintenance/degradation to buildings
static func apply_building_maintenance(buildings: Array, resources: Dictionary, _year: int, random_values: Array) -> Dictionary:
	var new_buildings: Array = []
	var breakdowns: Array = []
	var random_idx = 0

	for building in buildings:
		var updated = building.duplicate(true)

		if building.is_under_construction:
			# Advance construction
			updated.construction_progress += (1.0 / maxf(building.construction_years, 1))
			if updated.construction_progress >= 1.0:
				updated.is_under_construction = false
				updated.is_operational = true
				updated.construction_progress = 1.0
		else:
			# Degradation (2-5% per year)
			var rand = random_values[random_idx] if random_idx < random_values.size() else 0.5
			random_idx += 1
			var degradation = 2.0 + rand * 3.0
			updated.condition = maxf(0, updated.condition - degradation)

			# Check for failure
			if updated.condition < 30 and rand < 0.3:
				updated.is_operational = false
				breakdowns.append(ColonySimTypes.get_building_name(building.type))

		new_buildings.append(updated)

	return {
		"buildings": new_buildings,
		"resources": resources,
		"breakdowns": breakdowns
	}

## Start building construction
static func start_construction(buildings: Array, resources: Dictionary, building_type: int, _priority: int = 1) -> Dictionary:
	var build_cost = _get_construction_cost(building_type)

	# Check resources
	for resource_name in build_cost:
		if resources.get(resource_name, 0.0) < build_cost[resource_name]:
			return {"success": false, "buildings": buildings, "resources": resources}

	# Deduct resources
	var new_resources = resources.duplicate()
	for resource_name in build_cost:
		new_resources[resource_name] -= build_cost[resource_name]

	# Create building
	var building_def = ColonySimTypes.get_building_definition(building_type)
	var new_building = ColonySimTypes.create_building({
		"type": building_type,
		"is_operational": false,
		"is_under_construction": true,
		"construction_progress": 0.0,
		"construction_years": building_def.get("construction_years", 1)
	})

	var new_buildings = buildings.duplicate()
	new_buildings.append(new_building)

	return {
		"success": true,
		"buildings": new_buildings,
		"resources": new_resources
	}

## Repair a building
static func repair_building(buildings: Array, resources: Dictionary, building_id: String) -> Dictionary:
	var new_buildings: Array = []
	var found = false

	for building in buildings:
		if building.id == building_id:
			found = true
			var updated = building.duplicate(true)
			updated.condition = minf(100.0, updated.condition + 30.0)
			updated.is_operational = true
			new_buildings.append(updated)
		else:
			new_buildings.append(building)

	return {
		"success": found,
		"buildings": new_buildings,
		"resources": resources
	}

## Auto-assign workers to buildings
static func auto_assign_workers(colonists: Array, buildings: Array) -> Dictionary:
	var available_workers: Array = []

	for c in colonists:
		if c.is_alive and c.life_stage == ColonySimTypes.LifeStage.ADULT and c.health >= 40:
			available_workers.append(c)

	var new_buildings: Array = []

	for building in buildings:
		if building.is_under_construction or not building.is_operational:
			new_buildings.append(building)
			continue

		var building_def = ColonySimTypes.get_building_definition(building.type)
		var required = building_def.get("required_workers", 0)

		if required == 0 or available_workers.is_empty():
			new_buildings.append(building)
			continue

		var assigned: Array = []
		for i in range(mini(required, available_workers.size())):
			assigned.append(available_workers[i].id)

		available_workers = available_workers.slice(assigned.size())
		new_buildings.append(ColonySimTypes.with_field(building, "assigned_workers", assigned))

	return {
		"buildings": new_buildings,
		"colonists": colonists
	}

# ============================================================================
# BALANCE CALCULATIONS
# ============================================================================

## Calculate power balance
static func calc_power_balance(buildings: Array, colonists: Array) -> Dictionary:
	var generation = 0.0
	var consumption = ColonySimPopulation.count_alive(colonists) * POWER_PER_COLONIST

	for building in buildings:
		if not building.is_operational or building.is_under_construction:
			continue
		var building_def = ColonySimTypes.get_building_definition(building.type)
		generation += building_def.get("power_generation", 0.0) * calc_building_efficiency(building, colonists)
		consumption += building_def.get("power_consumption", 0.0)

	return {
		"generation": generation,
		"consumption": consumption,
		"balance": generation - consumption
	}

## Calculate housing balance
static func calc_housing_balance(buildings: Array, colonists: Array) -> Dictionary:
	var capacity = 0
	for building in buildings:
		if building.is_operational and not building.is_under_construction:
			capacity += building.housing_capacity

	var population = ColonySimPopulation.count_alive(colonists)
	return {
		"capacity": capacity,
		"used": population,
		"available": capacity - population
	}

# ============================================================================
# HELPERS
# ============================================================================

static func _get_construction_cost(building_type: int) -> Dictionary:
	match building_type:
		ColonySimTypes.BuildingType.HAB_POD:
			return {"building_materials": 50, "machine_parts": 10}
		ColonySimTypes.BuildingType.GREENHOUSE:
			return {"building_materials": 100, "machine_parts": 20}
		ColonySimTypes.BuildingType.SOLAR_ARRAY:
			return {"building_materials": 50}
		ColonySimTypes.BuildingType.MEDICAL_BAY:
			return {"building_materials": 80, "machine_parts": 30}
		_:
			return {"building_materials": 100, "machine_parts": 20}
