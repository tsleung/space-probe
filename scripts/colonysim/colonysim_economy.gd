extends RefCounted
class_name ColonySimEconomy

## Colony Sim Economy Logic
## Pure functions for resource production, consumption, and building operations
## All functions are static and deterministic

# ============================================================================
# CONSTANTS
# ============================================================================

# Per-colonist consumption per year
const FOOD_PER_COLONIST = 730.0  # 2kg/day * 365
const WATER_PER_COLONIST = 180.0  # Net after recycling (0.5L/day)
const OXYGEN_PER_COLONIST = 36.5  # Net after recycling
const POWER_PER_COLONIST = 5.0  # kW average

# Building efficiency thresholds
const MIN_WORKER_EFFICIENCY = 0.5
const MAINTENANCE_FAILURE_THRESHOLD = 50.0

# ============================================================================
# RESOURCE PRODUCTION & CONSUMPTION
# ============================================================================

## Calculate yearly production from all buildings
## Returns: Dictionary of resource_type -> amount
static func calc_yearly_production(buildings: Array, colonists: Array) -> Dictionary:
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
## Returns: Dictionary of resource_type -> amount
static func calc_yearly_consumption(buildings: Array, colonists: Array) -> Dictionary:
	var consumption: Dictionary = {}

	# Colonist consumption
	var alive_count = ColonySimPopulation.count_alive(colonists)
	consumption["food"] = alive_count * FOOD_PER_COLONIST
	consumption["water"] = alive_count * WATER_PER_COLONIST
	consumption["oxygen"] = alive_count * OXYGEN_PER_COLONIST

	# Building consumption
	var total_power = 0.0
	for building in buildings:
		if not building.is_operational or building.is_under_construction:
			continue

		var building_def = ColonySimTypes.get_building_definition(building.type)

		# Power consumption
		total_power += building_def.get("power_consumption", 0.0)

		# Resource consumption
		var consumes = building_def.get("consumes", {})
		for resource_name in consumes:
			consumption[resource_name] = consumption.get(resource_name, 0.0) + consumes[resource_name]

		# Maintenance costs
		var maintenance = building_def.get("maintenance_cost", {})
		for resource_name in maintenance:
			consumption[resource_name] = consumption.get(resource_name, 0.0) + maintenance[resource_name]

	consumption["power"] = total_power

	return consumption

## Apply yearly resource changes
## Returns: { resources: Dictionary, events: Array, shortages: Array }
static func apply_yearly_resources(resources: Dictionary, production: Dictionary, consumption: Dictionary) -> Dictionary:
	var new_resources = resources.duplicate()
	var events: Array = []
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
			# Shortage!
			new_resources[resource_name] = 0.0
			var shortage_amount = consumed - current
			shortages.append({
				"resource": resource_name,
				"needed": consumed,
				"had": current,
				"shortage": shortage_amount
			})
			events.append({
				"type": "shortage",
				"resource": resource_name,
				"severity": _calc_shortage_severity(resource_name, shortage_amount, consumed)
			})

	return {
		"resources": new_resources,
		"events": events,
		"shortages": shortages
	}

static func _calc_shortage_severity(resource: String, shortage: float, needed: float) -> ColonySimTypes.EventSeverity:
	var ratio = shortage / maxf(needed, 1.0)

	# Critical resources
	if resource in ["food", "water", "oxygen"]:
		if ratio > 0.5:
			return ColonySimTypes.EventSeverity.CRITICAL
		elif ratio > 0.3:
			return ColonySimTypes.EventSeverity.MAJOR
		elif ratio > 0.1:
			return ColonySimTypes.EventSeverity.MODERATE
		else:
			return ColonySimTypes.EventSeverity.MINOR
	else:
		if ratio > 0.5:
			return ColonySimTypes.EventSeverity.MODERATE
		else:
			return ColonySimTypes.EventSeverity.MINOR

# ============================================================================
# BUILDING OPERATIONS
# ============================================================================

## Calculate building efficiency (0.0 - 1.0+)
static func calc_building_efficiency(building: Dictionary, colonists: Array) -> float:
	if not building.is_operational:
		return 0.0

	var efficiency = 1.0

	# Condition affects efficiency
	efficiency *= (building.condition / 100.0)

	# Worker staffing
	var building_def = ColonySimTypes.get_building_definition(building.type)
	var required = building_def.get("required_workers", 0)

	if required > 0:
		var assigned = building.assigned_workers.size()
		if assigned < required:
			efficiency *= maxf(MIN_WORKER_EFFICIENCY, float(assigned) / float(required))

		# Worker skill bonus
		var avg_effectiveness = 0.0
		for worker_id in building.assigned_workers:
			var worker = ColonySimPopulation.find_colonist_by_id(colonists, worker_id)
			if not worker.is_empty():
				avg_effectiveness += ColonySimPopulation.calc_effectiveness(worker)

		if assigned > 0:
			avg_effectiveness /= assigned
			efficiency *= (0.7 + avg_effectiveness * 0.6)  # Range: 0.7 - 1.3

	return clampf(efficiency, 0.0, 1.5)

## Apply yearly maintenance/degradation to buildings
## Returns: { buildings: Array, events: Array }
static func apply_building_maintenance(buildings: Array, resources: Dictionary, year: int, random_values: Array) -> Dictionary:
	var new_buildings: Array = []
	var events: Array = []
	var random_idx = 0

	for building in buildings:
		var updated = building.duplicate(true)

		if building.is_under_construction:
			# Advance construction
			updated.construction_progress += (1.0 / building.construction_years)
			if updated.construction_progress >= 1.0:
				updated.is_under_construction = false
				updated.is_operational = true
				updated.construction_progress = 1.0
				events.append({
					"type": "construction_complete",
					"building_id": building.id,
					"building_name": ColonySimTypes.get_building_name(building.type)
				})
		else:
			# Degradation
			var rand = _get_random(random_values, random_idx)
			random_idx += 1

			var degradation = 2.0 + rand * 3.0  # 2-5% per year
			updated.condition = maxf(0, updated.condition - degradation)

			# Check for failure
			if updated.condition < MAINTENANCE_FAILURE_THRESHOLD:
				var failure_chance = (MAINTENANCE_FAILURE_THRESHOLD - updated.condition) / 100.0
				if rand < failure_chance:
					updated.is_operational = false
					events.append({
						"type": "building_failure",
						"building_id": building.id,
						"building_name": ColonySimTypes.get_building_name(building.type),
						"condition": updated.condition
					})

		new_buildings.append(updated)

	return {
		"buildings": new_buildings,
		"events": events
	}

## Repair a building
static func repair_building(building: Dictionary, resources: Dictionary, colonists: Array) -> Dictionary:
	var repair_cost = _calc_repair_cost(building)

	# Check if we have resources
	for resource_name in repair_cost:
		if resources.get(resource_name, 0.0) < repair_cost[resource_name]:
			return {
				"success": false,
				"building": building,
				"resources": resources,
				"reason": "Insufficient %s" % resource_name
			}

	# Deduct resources
	var new_resources = resources.duplicate()
	for resource_name in repair_cost:
		new_resources[resource_name] -= repair_cost[resource_name]

	# Repair building
	var new_building = ColonySimTypes.with_fields(building, {
		"condition": minf(100.0, building.condition + 30.0),
		"is_operational": true
	})

	return {
		"success": true,
		"building": new_building,
		"resources": new_resources,
		"reason": ""
	}

static func _calc_repair_cost(building: Dictionary) -> Dictionary:
	var damage = 100.0 - building.condition
	var cost = {
		"machine_parts": ceili(damage / 20.0),
		"building_materials": ceili(damage / 30.0)
	}
	return cost

# ============================================================================
# BUILDING CONSTRUCTION
# ============================================================================

## Start building construction
## Returns: { success: bool, buildings: Array, resources: Dictionary, reason: String }
static func start_construction(buildings: Array, resources: Dictionary, building_type: ColonySimTypes.BuildingType, position: Vector2i) -> Dictionary:
	var build_cost = get_construction_cost(building_type)

	# Check resources
	for resource_name in build_cost:
		if resources.get(resource_name, 0.0) < build_cost[resource_name]:
			return {
				"success": false,
				"buildings": buildings,
				"resources": resources,
				"reason": "Insufficient %s" % resource_name
			}

	# Check position not occupied
	for b in buildings:
		if b.position == position:
			return {
				"success": false,
				"buildings": buildings,
				"resources": resources,
				"reason": "Position already occupied"
			}

	# Deduct resources
	var new_resources = resources.duplicate()
	for resource_name in build_cost:
		new_resources[resource_name] -= build_cost[resource_name]

	# Create building
	var building_def = ColonySimTypes.get_building_definition(building_type)
	var new_building = ColonySimTypes.create_building({
		"type": building_type,
		"name": ColonySimTypes.get_building_name(building_type),
		"position": position,
		"is_operational": false,
		"is_under_construction": true,
		"construction_progress": 0.0,
		"construction_years": building_def.get("construction_years", 1),
		"housing_capacity": building_def.get("housing_capacity", 0),
		"required_workers": building_def.get("required_workers", 0),
		"power_consumption": building_def.get("power_consumption", 0.0),
		"power_generation": building_def.get("power_generation", 0.0)
	})

	var new_buildings = buildings.duplicate()
	new_buildings.append(new_building)

	return {
		"success": true,
		"buildings": new_buildings,
		"resources": new_resources,
		"building": new_building,
		"reason": ""
	}

static func get_construction_cost(building_type: ColonySimTypes.BuildingType) -> Dictionary:
	match building_type:
		ColonySimTypes.BuildingType.HAB_POD:
			return {"building_materials": 50, "machine_parts": 10}
		ColonySimTypes.BuildingType.APARTMENT_BLOCK:
			return {"building_materials": 200, "machine_parts": 30, "electronics": 10}
		ColonySimTypes.BuildingType.GREENHOUSE:
			return {"building_materials": 100, "machine_parts": 20, "electronics": 5}
		ColonySimTypes.BuildingType.SOLAR_ARRAY:
			return {"building_materials": 50, "electronics": 20}
		ColonySimTypes.BuildingType.MEDICAL_BAY:
			return {"building_materials": 80, "machine_parts": 30, "electronics": 20, "medicine": 20}
		ColonySimTypes.BuildingType.SCHOOL:
			return {"building_materials": 60, "machine_parts": 10}
		_:
			return {"building_materials": 100, "machine_parts": 20}

# ============================================================================
# POWER MANAGEMENT
# ============================================================================

## Calculate power balance
static func calc_power_balance(buildings: Array, colonists: Array) -> Dictionary:
	var generation = 0.0
	var consumption = 0.0

	for building in buildings:
		if not building.is_operational or building.is_under_construction:
			continue

		var building_def = ColonySimTypes.get_building_definition(building.type)
		var efficiency = calc_building_efficiency(building, colonists)

		generation += building_def.get("power_generation", 0.0) * efficiency
		consumption += building_def.get("power_consumption", 0.0)

	# Colonist power consumption
	var alive = ColonySimPopulation.count_alive(colonists)
	consumption += alive * POWER_PER_COLONIST

	return {
		"generation": generation,
		"consumption": consumption,
		"balance": generation - consumption,
		"surplus_ratio": generation / maxf(consumption, 1.0)
	}

# ============================================================================
# HOUSING MANAGEMENT
# ============================================================================

## Calculate housing balance
static func calc_housing_balance(buildings: Array, colonists: Array) -> Dictionary:
	var capacity = 0

	for building in buildings:
		if not building.is_operational or building.is_under_construction:
			continue
		capacity += building.housing_capacity

	var population = ColonySimPopulation.count_alive(colonists)

	return {
		"capacity": capacity,
		"used": population,
		"available": capacity - population,
		"occupancy_ratio": float(population) / maxf(float(capacity), 1.0)
	}

# ============================================================================
# WORKFORCE ALLOCATION
# ============================================================================

## Assign workers to a building
## Returns: { buildings: Array, colonists: Array, success: bool }
static func assign_workers(buildings: Array, colonists: Array, building_id: String, worker_ids: Array) -> Dictionary:
	var new_buildings: Array = []
	var new_colonists = colonists.duplicate(true)
	var found = false

	for building in buildings:
		if building.id == building_id:
			found = true
			var updated = ColonySimTypes.with_field(building, "assigned_workers", worker_ids)
			new_buildings.append(updated)

			# Update colonist job assignments
			for i in range(new_colonists.size()):
				var c = new_colonists[i]
				if c.id in worker_ids:
					new_colonists[i] = ColonySimTypes.with_field(c, "current_job", building_id)
				elif c.current_job == building_id:
					new_colonists[i] = ColonySimTypes.with_field(c, "current_job", "")
		else:
			new_buildings.append(building)

	return {
		"buildings": new_buildings,
		"colonists": new_colonists,
		"success": found
	}

## Auto-assign workers to buildings based on skills
static func auto_assign_workers(buildings: Array, colonists: Array) -> Dictionary:
	var available_workers: Array = []

	# Get available adult workers
	for c in colonists:
		if c.is_alive and c.is_working and c.life_stage == ColonySimTypes.LifeStage.ADULT:
			if c.health >= 40:
				available_workers.append(c)

	var new_buildings: Array = []
	var assignments: Dictionary = {}  # colonist_id -> building_id

	# Sort buildings by priority (essential first)
	var sorted_buildings = buildings.duplicate()
	sorted_buildings.sort_custom(func(a, b): return _get_building_priority(a.type) > _get_building_priority(b.type))

	for building in sorted_buildings:
		if building.is_under_construction or not building.is_operational:
			new_buildings.append(building)
			continue

		var building_def = ColonySimTypes.get_building_definition(building.type)
		var required = building_def.get("required_workers", 0)

		if required == 0:
			new_buildings.append(building)
			continue

		# Find best available workers
		var assigned: Array = []
		var preferred_specialty = _get_building_specialty(building.type)

		# Sort available by specialty match
		available_workers.sort_custom(func(a, b):
			var a_score = 1.0 if a.specialty == preferred_specialty else 0.5
			var b_score = 1.0 if b.specialty == preferred_specialty else 0.5
			return a_score * ColonySimPopulation.calc_effectiveness(a) > b_score * ColonySimPopulation.calc_effectiveness(b)
		)

		for i in range(mini(required, available_workers.size())):
			var worker = available_workers[i]
			assigned.append(worker.id)
			assignments[worker.id] = building.id

		# Remove assigned from available
		available_workers = available_workers.filter(func(w): return w.id not in assigned)

		var updated = ColonySimTypes.with_field(building, "assigned_workers", assigned)
		new_buildings.append(updated)

	# Update colonist job assignments
	var new_colonists: Array = []
	for c in colonists:
		if assignments.has(c.id):
			new_colonists.append(ColonySimTypes.with_field(c, "current_job", assignments[c.id]))
		else:
			new_colonists.append(ColonySimTypes.with_field(c, "current_job", ""))

	return {
		"buildings": new_buildings,
		"colonists": new_colonists
	}

static func _get_building_priority(type: ColonySimTypes.BuildingType) -> int:
	match type:
		# Life support - highest priority
		ColonySimTypes.BuildingType.OXYGENATOR, ColonySimTypes.BuildingType.WATER_EXTRACTOR:
			return 100
		# Food
		ColonySimTypes.BuildingType.GREENHOUSE, ColonySimTypes.BuildingType.HYDROPONICS:
			return 90
		# Medical
		ColonySimTypes.BuildingType.MEDICAL_BAY, ColonySimTypes.BuildingType.HOSPITAL:
			return 80
		# Power
		ColonySimTypes.BuildingType.SOLAR_ARRAY, ColonySimTypes.BuildingType.FISSION_REACTOR:
			return 70
		# Education
		ColonySimTypes.BuildingType.SCHOOL, ColonySimTypes.BuildingType.UNIVERSITY:
			return 50
		# Research
		ColonySimTypes.BuildingType.LAB, ColonySimTypes.BuildingType.RESEARCH_CENTER:
			return 40
		# Manufacturing
		ColonySimTypes.BuildingType.WORKSHOP, ColonySimTypes.BuildingType.FACTORY:
			return 30
		_:
			return 10

static func _get_building_specialty(type: ColonySimTypes.BuildingType) -> ColonySimTypes.Specialty:
	match type:
		ColonySimTypes.BuildingType.GREENHOUSE, ColonySimTypes.BuildingType.HYDROPONICS:
			return ColonySimTypes.Specialty.FARMER
		ColonySimTypes.BuildingType.MEDICAL_BAY, ColonySimTypes.BuildingType.HOSPITAL:
			return ColonySimTypes.Specialty.MEDIC
		ColonySimTypes.BuildingType.LAB, ColonySimTypes.BuildingType.RESEARCH_CENTER:
			return ColonySimTypes.Specialty.SCIENTIST
		ColonySimTypes.BuildingType.WORKSHOP, ColonySimTypes.BuildingType.FACTORY, ColonySimTypes.BuildingType.OXYGENATOR, ColonySimTypes.BuildingType.WATER_EXTRACTOR:
			return ColonySimTypes.Specialty.ENGINEER
		ColonySimTypes.BuildingType.SCHOOL, ColonySimTypes.BuildingType.UNIVERSITY:
			return ColonySimTypes.Specialty.EDUCATOR
		ColonySimTypes.BuildingType.GOVERNMENT_HALL:
			return ColonySimTypes.Specialty.ADMINISTRATOR
		_:
			return ColonySimTypes.Specialty.NONE

# ============================================================================
# RESOURCE PROJECTIONS
# ============================================================================

## Project resources X years into the future
static func project_resources(resources: Dictionary, buildings: Array, colonists: Array, years: int) -> Array:
	var projections: Array = []
	var current = resources.duplicate()

	for year in range(years):
		var production = calc_yearly_production(buildings, colonists)
		var consumption = calc_yearly_consumption(buildings, colonists)

		var year_result = apply_yearly_resources(current, production, consumption)
		current = year_result.resources

		projections.append({
			"year": year + 1,
			"resources": current.duplicate(),
			"shortages": year_result.shortages
		})

	return projections

## Get days of supplies remaining for critical resources
static func get_supply_days(resources: Dictionary, colonists: Array) -> Dictionary:
	var alive = ColonySimPopulation.count_alive(colonists)
	if alive == 0:
		return {"food": INF, "water": INF, "oxygen": INF}

	var food_days = (resources.get("food", 0.0) / (alive * 2.0))  # 2kg/day
	var water_days = (resources.get("water", 0.0) / (alive * 0.5))  # 0.5L/day net
	var oxygen_days = (resources.get("oxygen", 0.0) / (alive * 0.1))  # 0.1kg/day net

	return {
		"food": food_days,
		"water": water_days,
		"oxygen": oxygen_days
	}

# ============================================================================
# HELPERS
# ============================================================================

static func _get_random(arr: Array, idx: int) -> float:
	if idx < arr.size():
		return arr[idx]
	return 0.5
