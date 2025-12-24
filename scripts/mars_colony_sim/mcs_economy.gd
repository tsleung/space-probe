extends RefCounted
class_name MCSEconomy

## MCS (Mars Colony Sim) Economy Logic - SIMPLIFIED
## Pure functions for resource production, consumption, and building operations
## All functions are static and deterministic

# Preload dependencies
const _MCSTypes = preload("res://scripts/mars_colony_sim/mcs_types.gd")
const _MCSPopulation = preload("res://scripts/mars_colony_sim/mcs_population.gd")

# ============================================================================
# DEFAULT CONSTANTS (used if no balance dict provided)
# ============================================================================

# Per-colonist consumption per year (with advanced recycling/efficiency tech)
const DEFAULT_FOOD_PER_COLONIST = 50.0  # Highly efficient future farming
const DEFAULT_WATER_PER_COLONIST = 20.0  # 90% recycling
const DEFAULT_OXYGEN_PER_COLONIST = 5.0  # Closed-loop life support
const DEFAULT_POWER_PER_COLONIST = 2.0  # Efficient systems

# ============================================================================
# SYNERGY SYSTEM CONSTANTS
# ============================================================================

## Adjacency bonus range (hex distance)
const ADJACENCY_RANGE = 2

## Diversity bonus range (hex distance)
const DIVERSITY_RANGE = 3

## Adjacency synergy pairs: {[type1, type2]: {"bonus": multiplier, "resource": affected_resource}}
## These bonuses apply when buildings are within ADJACENCY_RANGE of each other
const ADJACENCY_SYNERGIES = {
	# Food synergy: Agridome near water source = better crops
	"agridome_extractor": {"bonus": 0.15, "resource": "food"},
	# Industry synergy: Fabricator near power = more output
	"fabricator_power_station": {"bonus": 0.20, "resource": "all"},
	# Research synergy: Research near Academy = better science
	"research_academy": {"bonus": 0.25, "resource": "research"},
	# Health synergy: Medical near Housing = healthier colonists
	"medical_habitat": {"bonus": 0.10, "resource": "health"},
	# Space synergy: Orbital near Starport = better coordination
	"orbital_starport": {"bonus": 0.15, "resource": "immigration"},
	# Refining synergy: Foundry near Extractor = material efficiency
	"foundry_extractor": {"bonus": 0.15, "resource": "building_materials"},
	# Parts synergy: Precision near Research = better parts
	"precision_research": {"bonus": 0.15, "resource": "machine_parts"},
}

## Diversity bonuses based on unique building categories nearby
const DIVERSITY_BONUSES = {
	2: 0.05,   # 2 unique categories = +5%
	3: 0.10,   # 3 unique categories = +10%
	4: 0.15,   # 4 unique categories = +15%
	5: 0.20,   # 5+ unique categories = +20%
}

## Clustering penalties for same category buildings nearby
const CLUSTERING_PENALTIES = {
	2: -0.05,  # 2 same-category neighbors = -5%
	3: -0.10,  # 3+ same-category neighbors = -10%
}

# ============================================================================
# TRADE SYSTEM CONSTANTS
# ============================================================================

## Export prices (credits per unit)
const EXPORT_PRICES = {
	"building_materials": 0.8,   # Bulk, low value
	"machine_parts": 2.5,        # High value manufactured goods
	"fuel": 1.2,                 # Useful for Earth orbital operations
	"rare_earth": 5.0,           # Very valuable to Earth
	"electronics": 3.0,          # High-tech goods (if we can spare)
}

## Import prices (credits per unit) - Mars pays premium for imports
const IMPORT_PRICES = {
	"medicine": 8.0,             # Critical, expensive to ship
	"electronics": 4.0,          # High-tech, fragile
	"machine_parts": 3.5,        # Backup supply
	"fuel": 2.0,                 # Emergency supplies
	"comfort_items": 2.0,        # Luxury goods
}

## Minimum resource buffer before allowing exports
const EXPORT_BUFFER = {
	"building_materials": 500,   # Keep 500 for construction
	"machine_parts": 200,        # Keep 200 for maintenance
	"fuel": 100,                 # Keep 100 for operations
	"rare_earth": 50,
	"electronics": 20,
}

# ============================================================================
# SYNERGY CALCULATION FUNCTIONS
# ============================================================================

## Calculate hex distance between two positions (axial coordinates)
static func calc_hex_distance(pos1: Vector2i, pos2: Vector2i) -> int:
	var dx = abs(pos1.x - pos2.x)
	var dy = abs(pos1.y - pos2.y)
	# For offset coordinates, approximate hex distance
	return maxi(dx, dy) + int(mini(dx, dy) / 2)

## Get all operational buildings within a given hex range of target building
static func get_buildings_in_range(target: Dictionary, buildings: Array, hex_range: int) -> Array:
	var nearby: Array = []
	var target_pos = target.get("position", Vector2i.ZERO)

	for building in buildings:
		if building.id == target.id:
			continue
		if not building.is_operational or building.is_under_construction:
			continue

		var building_pos = building.get("position", Vector2i.ZERO)
		if calc_hex_distance(target_pos, building_pos) <= hex_range:
			nearby.append(building)

	return nearby

## Calculate adjacency synergy bonus for a building based on nearby complementary buildings
## Returns a dictionary of {resource_type: bonus_multiplier}
static func calc_adjacency_bonus(building: Dictionary, buildings: Array) -> Dictionary:
	var bonuses: Dictionary = {}
	var building_type = building.get("type", 0)
	var nearby = get_buildings_in_range(building, buildings, ADJACENCY_RANGE)

	# Get type name for synergy lookup
	var type_name = _get_type_key(building_type)

	for neighbor in nearby:
		var neighbor_type = neighbor.get("type", 0)
		var neighbor_name = _get_type_key(neighbor_type)

		# Check both orderings of the pair
		var key1 = type_name + "_" + neighbor_name
		var key2 = neighbor_name + "_" + type_name

		var synergy_data = null
		if ADJACENCY_SYNERGIES.has(key1):
			synergy_data = ADJACENCY_SYNERGIES[key1]
		elif ADJACENCY_SYNERGIES.has(key2):
			synergy_data = ADJACENCY_SYNERGIES[key2]

		if synergy_data:
			var resource = synergy_data.resource
			var bonus = synergy_data.bonus
			# Stack bonuses from multiple adjacent synergy buildings (diminishing)
			var existing = bonuses.get(resource, 0.0)
			bonuses[resource] = existing + bonus * (1.0 - existing * 0.5)  # Diminishing returns

	return bonuses

## Calculate diversity bonus based on unique building categories nearby
## Returns a multiplier (1.0 = no bonus, 1.2 = 20% bonus)
static func calc_diversity_bonus(building: Dictionary, buildings: Array) -> float:
	var nearby = get_buildings_in_range(building, buildings, DIVERSITY_RANGE)

	# Count unique categories
	var categories: Dictionary = {}
	for neighbor in nearby:
		var cat = _MCSTypes.get_building_category(neighbor.type)
		categories[cat] = true

	var unique_count = categories.size()

	# Find the highest bonus that applies
	var bonus = 0.0
	for threshold in DIVERSITY_BONUSES:
		if unique_count >= threshold:
			bonus = DIVERSITY_BONUSES[threshold]

	return 1.0 + bonus

## Calculate clustering penalty for having too many same-category buildings nearby
## Returns a multiplier (1.0 = no penalty, 0.9 = 10% penalty)
static func calc_clustering_penalty(building: Dictionary, buildings: Array) -> float:
	var nearby = get_buildings_in_range(building, buildings, ADJACENCY_RANGE)
	var building_category = _MCSTypes.get_building_category(building.type)

	# Count same-category neighbors
	var same_category_count = 0
	for neighbor in nearby:
		if _MCSTypes.get_building_category(neighbor.type) == building_category:
			same_category_count += 1

	# Find the worst penalty that applies
	var penalty = 0.0
	for threshold in CLUSTERING_PENALTIES:
		if same_category_count >= threshold:
			penalty = CLUSTERING_PENALTIES[threshold]

	return 1.0 + penalty  # Penalty is negative, so this reduces the multiplier

## Calculate total synergy multiplier for a building
## Returns {multiplier: float, adjacency_bonuses: Dictionary, diversity_bonus: float, clustering_penalty: float}
static func calc_synergy_multiplier(building: Dictionary, buildings: Array) -> Dictionary:
	var adjacency = calc_adjacency_bonus(building, buildings)
	var diversity = calc_diversity_bonus(building, buildings)
	var clustering = calc_clustering_penalty(building, buildings)

	# Base multiplier is diversity * clustering (multiplicative)
	var base_multiplier = diversity * clustering

	return {
		"multiplier": base_multiplier,
		"adjacency_bonuses": adjacency,  # Applied per-resource
		"diversity_bonus": diversity - 1.0,  # Just the bonus portion
		"clustering_penalty": clustering - 1.0  # Just the penalty portion
	}

## Helper: Get lowercase type key for synergy lookup
static func _get_type_key(building_type: int) -> String:
	match building_type:
		_MCSTypes.BuildingType.HABITAT: return "habitat"
		_MCSTypes.BuildingType.BARRACKS: return "barracks"
		_MCSTypes.BuildingType.QUARTERS: return "quarters"
		_MCSTypes.BuildingType.AGRIDOME: return "agridome"
		_MCSTypes.BuildingType.EXTRACTOR: return "extractor"
		_MCSTypes.BuildingType.FABRICATOR: return "fabricator"
		_MCSTypes.BuildingType.POWER_STATION: return "power_station"
		_MCSTypes.BuildingType.HYDROPONICS: return "hydroponics"
		_MCSTypes.BuildingType.PROTEIN_VATS: return "protein_vats"
		_MCSTypes.BuildingType.ICE_MINER: return "ice_miner"
		_MCSTypes.BuildingType.ATMO_PROCESSOR: return "atmo_processor"
		_MCSTypes.BuildingType.FOUNDRY: return "foundry"
		_MCSTypes.BuildingType.PRECISION: return "precision"
		_MCSTypes.BuildingType.SOLAR_FARM: return "solar_farm"
		_MCSTypes.BuildingType.REACTOR: return "reactor"
		_MCSTypes.BuildingType.MEDICAL: return "medical"
		_MCSTypes.BuildingType.ACADEMY: return "academy"
		_MCSTypes.BuildingType.RESEARCH: return "research"
		_MCSTypes.BuildingType.RECREATION: return "recreation"
		_MCSTypes.BuildingType.STORAGE: return "storage"
		_MCSTypes.BuildingType.COMMS: return "comms"
		_MCSTypes.BuildingType.LOGISTICS: return "logistics"
		_MCSTypes.BuildingType.STARPORT: return "starport"
		_MCSTypes.BuildingType.ORBITAL: return "orbital"
		_MCSTypes.BuildingType.CATCHER: return "catcher"
		_MCSTypes.BuildingType.MASS_DRIVER: return "mass_driver"
		_MCSTypes.BuildingType.FUSION_PLANT: return "fusion_plant"
		_MCSTypes.BuildingType.SPACE_ELEVATOR: return "space_elevator"
		_: return "unknown"

## Get consumption rates from balance dict or use defaults
static func get_consumption_rates(balance: Dictionary = {}) -> Dictionary:
	var consumption = balance.get("consumption", {})
	var difficulty = balance.get("difficulty", {})
	var multiplier = difficulty.get("consumption_multiplier", 1.0)

	return {
		"food": consumption.get("food_per_colonist_per_year", DEFAULT_FOOD_PER_COLONIST) * multiplier,
		"water": consumption.get("water_per_colonist_per_year", DEFAULT_WATER_PER_COLONIST) * multiplier,
		"oxygen": consumption.get("oxygen_per_colonist_per_year", DEFAULT_OXYGEN_PER_COLONIST) * multiplier,
		"power": consumption.get("power_per_colonist", DEFAULT_POWER_PER_COLONIST) * multiplier
	}

# ============================================================================
# RESOURCE PRODUCTION & CONSUMPTION
# ============================================================================

## Calculate yearly production from all buildings (TIER-AWARE + SYNERGY)
## Higher tiers = more production, fewer workers needed
## Synergies apply: adjacency bonuses, diversity bonuses, clustering penalties
static func calc_yearly_production(buildings: Array, colonists: Array, _resources: Dictionary = {}) -> Dictionary:
	var production: Dictionary = {}

	for building in buildings:
		if not building.is_operational or building.is_under_construction:
			continue

		var efficiency = calc_building_efficiency(building, colonists)
		var tier = building.get("tier", 1)
		var building_type = building.get("type", 0)

		# Calculate synergy bonuses for this building
		var synergy = calc_synergy_multiplier(building, buildings)
		var base_multiplier = synergy.multiplier  # diversity * clustering
		var adjacency_bonuses = synergy.adjacency_bonuses  # per-resource bonuses

		# Get tier-based stats if available, otherwise fall back to base definition
		var tier_stats = _MCSTypes.get_tier_stats(building_type, tier)

		# Tier-based production (from BUILDING_TIER_STATS)
		var produces = tier_stats.get("production", {})
		for resource_name in produces:
			var base_amount = produces[resource_name]
			# Apply efficiency + synergy multiplier + per-resource adjacency bonus
			var synergy_mult = base_multiplier
			if adjacency_bonuses.has(resource_name):
				synergy_mult += adjacency_bonuses[resource_name]
			elif adjacency_bonuses.has("all"):
				synergy_mult += adjacency_bonuses["all"]
			var actual = base_amount * efficiency * synergy_mult
			production[resource_name] = production.get(resource_name, 0.0) + actual

		# Fall back to building definition if no tier production defined
		if produces.is_empty():
			var building_def = _MCSTypes.get_building_definition(building_type)
			var base_produces = building_def.get("produces", {})
			for resource_name in base_produces:
				var base_amount = base_produces[resource_name]
				# Apply efficiency + synergy multiplier + per-resource adjacency bonus
				var synergy_mult = base_multiplier
				if adjacency_bonuses.has(resource_name):
					synergy_mult += adjacency_bonuses[resource_name]
				elif adjacency_bonuses.has("all"):
					synergy_mult += adjacency_bonuses["all"]
				var actual = base_amount * efficiency * synergy_mult
				production[resource_name] = production.get(resource_name, 0.0) + actual

		# Tier-based power generation (synergy applies)
		if tier_stats.has("power_gen"):
			var power_synergy = base_multiplier
			if adjacency_bonuses.has("power"):
				power_synergy += adjacency_bonuses["power"]
			elif adjacency_bonuses.has("all"):
				power_synergy += adjacency_bonuses["all"]
			production["power"] = production.get("power", 0.0) + tier_stats.power_gen * efficiency * power_synergy
		else:
			# Fall back to building definition
			var building_def = _MCSTypes.get_building_definition(building_type)
			if building_def.has("power_generation"):
				var power_synergy = base_multiplier
				if adjacency_bonuses.has("power"):
					power_synergy += adjacency_bonuses["power"]
				elif adjacency_bonuses.has("all"):
					power_synergy += adjacency_bonuses["all"]
				production["power"] = production.get("power", 0.0) + building_def.power_generation * efficiency * power_synergy

	return production

## Calculate yearly consumption from buildings and colonists
## balance: Optional balance dict - if provided, uses those rates with difficulty multiplier
static func calc_yearly_consumption(colonists_or_buildings, buildings_or_none = null, balance: Dictionary = {}) -> Dictionary:
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
	var rates = get_consumption_rates(balance)

	# Colonist consumption (with difficulty multiplier applied via rates)
	var alive_count = _MCSPopulation.count_alive(colonists)
	consumption["food"] = alive_count * rates.food
	consumption["water"] = alive_count * rates.water
	consumption["oxygen"] = alive_count * rates.oxygen

	# Building power consumption
	var total_power = alive_count * rates.power
	for building in buildings:
		if not building.is_operational or building.is_under_construction:
			continue
		var building_def = _MCSTypes.get_building_definition(building.type)
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

## Calculate building efficiency (0.0 - 1.0) - TIER-AWARE
## Higher tiers need fewer workers for same efficiency
static func calc_building_efficiency(building: Dictionary, colonists: Array) -> float:
	if not building.is_operational:
		return 0.0

	var efficiency = building.condition / 100.0

	# Get tier-based worker requirements (higher tiers = fewer workers)
	var tier = building.get("tier", 1)
	var building_type = building.get("type", 0)
	var tier_stats = _MCSTypes.get_tier_stats(building_type, tier)

	# Use tier-based workers if defined, otherwise fall back to building definition
	var required: int
	if tier_stats.has("workers"):
		required = tier_stats.workers
	else:
		var building_def = _MCSTypes.get_building_definition(building_type)
		required = building_def.get("required_workers", 0)

	# Worker staffing efficiency
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
				breakdowns.append(_MCSTypes.get_building_name(building.type))

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
	var building_def = _MCSTypes.get_building_definition(building_type)
	var new_building = _MCSTypes.create_building({
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
		if c.is_alive and c.life_stage == _MCSTypes.LifeStage.ADULT and c.health >= 40:
			available_workers.append(c)

	var new_buildings: Array = []

	for building in buildings:
		if building.is_under_construction or not building.is_operational:
			new_buildings.append(building)
			continue

		var building_def = _MCSTypes.get_building_definition(building.type)
		var required = building_def.get("required_workers", 0)

		if required == 0 or available_workers.is_empty():
			new_buildings.append(building)
			continue

		var assigned: Array = []
		for i in range(mini(required, available_workers.size())):
			assigned.append(available_workers[i].id)

		available_workers = available_workers.slice(assigned.size())
		new_buildings.append(_MCSTypes.with_field(building, "assigned_workers", assigned))

	return {
		"buildings": new_buildings,
		"colonists": colonists
	}

# ============================================================================
# BALANCE CALCULATIONS
# ============================================================================

## Calculate power balance (TIER-AWARE)
## Higher tiers generate more power and use less power
static func calc_power_balance(buildings: Array, colonists: Array, balance: Dictionary = {}) -> Dictionary:
	var rates = get_consumption_rates(balance)
	var generation = 0.0
	var consumption = _MCSPopulation.count_alive(colonists) * rates.power

	for building in buildings:
		if not building.is_operational or building.is_under_construction:
			continue

		var tier = building.get("tier", 1)
		var building_type = building.get("type", 0)
		var tier_stats = _MCSTypes.get_tier_stats(building_type, tier)
		var building_def = _MCSTypes.get_building_definition(building_type)
		var efficiency = calc_building_efficiency(building, colonists)

		# Tier-based power generation
		if tier_stats.has("power_gen"):
			generation += tier_stats.power_gen * efficiency
		elif building_def.has("power_generation"):
			generation += building_def.power_generation * efficiency

		# Tier-based power consumption (higher tiers use less power)
		if tier_stats.has("power"):
			consumption += tier_stats.power
		else:
			consumption += building_def.get("power_consumption", 0.0)

	return {
		"generation": generation,
		"consumption": consumption,
		"balance": generation - consumption
	}

## Calculate housing balance (TIER-AWARE)
## Higher tiers have more housing capacity
static func calc_housing_balance(buildings: Array, colonists: Array) -> Dictionary:
	var capacity = 0
	for building in buildings:
		if building.is_operational and not building.is_under_construction:
			var tier = building.get("tier", 1)
			var building_type = building.get("type", 0)
			var tier_stats = _MCSTypes.get_tier_stats(building_type, tier)

			# Use tier-based housing capacity if defined
			if tier_stats.has("housing_capacity"):
				capacity += tier_stats.housing_capacity
			else:
				capacity += building.get("housing_capacity", 0)

	var population = _MCSPopulation.count_alive(colonists)
	return {
		"capacity": capacity,
		"used": population,
		"available": capacity - population
	}

# ============================================================================
# TRADE SYSTEM FUNCTIONS
# ============================================================================

## Calculate total trade capacity from buildings (export + import)
static func calc_trade_capacity(buildings: Array, colonists: Array) -> Dictionary:
	var export_capacity = 0.0
	var import_capacity = 0.0

	for building in buildings:
		if not building.is_operational or building.is_under_construction:
			continue

		var efficiency = calc_building_efficiency(building, colonists)
		var tier = building.get("tier", 1)
		var building_type = building.get("type", 0)
		var tier_stats = _MCSTypes.get_tier_stats(building_type, tier)

		# Export capacity from Mass Driver, Space Elevator
		if tier_stats.has("export_capacity"):
			export_capacity += tier_stats.export_capacity * efficiency

		# Import capacity from Space Elevator
		if tier_stats.has("import_capacity"):
			import_capacity += tier_stats.import_capacity * efficiency

		# Trade capacity from Starport, Comms (bidirectional but limited)
		if tier_stats.has("trade_capacity"):
			var trade_cap = tier_stats.trade_capacity * efficiency
			export_capacity += trade_cap * 0.3  # 30% can be used for exports
			import_capacity += trade_cap * 0.5  # 50% for imports

	return {
		"export_capacity": export_capacity,
		"import_capacity": import_capacity
	}

## Calculate what can be exported this year (respecting buffers)
## Returns {resource: amount} for each exportable resource
static func calc_available_exports(resources: Dictionary) -> Dictionary:
	var exports: Dictionary = {}

	for resource_name in EXPORT_PRICES.keys():
		var current = resources.get(resource_name, 0.0)
		var buffer = EXPORT_BUFFER.get(resource_name, 0)
		var exportable = maxf(0, current - buffer)

		if exportable > 0:
			exports[resource_name] = exportable

	return exports

## Calculate potential credits from exporting given resources
static func calc_export_value(export_amounts: Dictionary) -> float:
	var total_credits = 0.0

	for resource_name in export_amounts.keys():
		var amount = export_amounts[resource_name]
		var price = EXPORT_PRICES.get(resource_name, 0.0)
		total_credits += amount * price

	return total_credits

## Execute a trade: export resources for credits, optionally import goods
## Returns the updated resources dictionary and a trade report
static func execute_trade(resources: Dictionary, buildings: Array, colonists: Array, trade_policy: Dictionary = {}) -> Dictionary:
	var capacity = calc_trade_capacity(buildings, colonists)
	var new_resources = resources.duplicate(true)
	var trade_report = {
		"exports": {},
		"imports": {},
		"credits_earned": 0.0,
		"credits_spent": 0.0
	}

	# === EXPORTS ===
	var export_capacity = capacity.export_capacity
	if export_capacity > 0:
		var available = calc_available_exports(new_resources)
		var exported_volume = 0.0

		# Export priority: rare_earth > machine_parts > building_materials > fuel
		var export_priority = ["rare_earth", "machine_parts", "building_materials", "fuel", "electronics"]

		for resource_name in export_priority:
			if exported_volume >= export_capacity:
				break

			var available_amount = available.get(resource_name, 0.0)
			if available_amount <= 0:
				continue

			# Apply trade policy caps if set
			var policy_cap = trade_policy.get("max_export_" + resource_name, INF)
			available_amount = minf(available_amount, policy_cap)

			var to_export = minf(available_amount, export_capacity - exported_volume)

			if to_export > 0:
				var price = EXPORT_PRICES.get(resource_name, 0.0)
				var credits = to_export * price

				new_resources[resource_name] = new_resources.get(resource_name, 0) - to_export
				new_resources["credits"] = new_resources.get("credits", 0) + credits

				trade_report.exports[resource_name] = to_export
				trade_report.credits_earned += credits
				exported_volume += to_export

	# === IMPORTS ===
	var import_capacity = capacity.import_capacity
	var available_credits = new_resources.get("credits", 0.0)

	if import_capacity > 0 and available_credits > 0:
		var imported_volume = 0.0

		# Import priority: medicine > electronics > machine_parts (for critical shortages)
		var import_priority = ["medicine", "electronics", "machine_parts", "comfort_items"]

		for resource_name in import_priority:
			if imported_volume >= import_capacity:
				break
			if available_credits <= 0:
				break

			# Check if we need this resource
			var current = new_resources.get(resource_name, 0.0)
			var threshold = trade_policy.get("import_threshold_" + resource_name, 50.0)

			if current >= threshold:
				continue

			# Calculate import amount
			var price = IMPORT_PRICES.get(resource_name, 10.0)
			var want_amount = threshold - current
			var can_afford = available_credits / price
			var can_import = import_capacity - imported_volume

			var to_import = minf(want_amount, minf(can_afford, can_import))

			if to_import > 0:
				var cost = to_import * price
				new_resources[resource_name] = new_resources.get(resource_name, 0) + to_import
				new_resources["credits"] = new_resources.get("credits", 0) - cost
				available_credits -= cost

				trade_report.imports[resource_name] = to_import
				trade_report.credits_spent += cost
				imported_volume += to_import

	return {
		"resources": new_resources,
		"report": trade_report
	}

## Get trade balance summary for UI
static func get_trade_summary(resources: Dictionary, buildings: Array, colonists: Array) -> Dictionary:
	var capacity = calc_trade_capacity(buildings, colonists)
	var available_exports = calc_available_exports(resources)
	var potential_credits = calc_export_value(available_exports)

	return {
		"export_capacity": capacity.export_capacity,
		"import_capacity": capacity.import_capacity,
		"credits": resources.get("credits", 0.0),
		"potential_export_value": potential_credits,
		"exportable_resources": available_exports
	}

# ============================================================================
# HELPERS
# ============================================================================

static func _get_construction_cost(building_type: int) -> Dictionary:
	match building_type:
		# === HOUSING ===
		_MCSTypes.BuildingType.HABITAT:
			return {"building_materials": 40, "machine_parts": 8}
		_MCSTypes.BuildingType.BARRACKS:
			return {"building_materials": 60, "machine_parts": 10}
		_MCSTypes.BuildingType.QUARTERS:
			return {"building_materials": 100, "machine_parts": 25}
		# === PRODUCTION BASE ===
		_MCSTypes.BuildingType.AGRIDOME:
			return {"building_materials": 80, "machine_parts": 15}
		_MCSTypes.BuildingType.EXTRACTOR:
			return {"building_materials": 50, "machine_parts": 18}
		_MCSTypes.BuildingType.FABRICATOR:
			return {"building_materials": 150, "machine_parts": 50}
		_MCSTypes.BuildingType.POWER_STATION:
			return {"building_materials": 40, "machine_parts": 8}
		# === PRODUCTION BRANCHES (only available via specialization, but include costs) ===
		_MCSTypes.BuildingType.HYDROPONICS:
			return {"building_materials": 100, "machine_parts": 25, "electronics": 5}
		_MCSTypes.BuildingType.PROTEIN_VATS:
			return {"building_materials": 120, "machine_parts": 30, "medicine": 5}
		_MCSTypes.BuildingType.ICE_MINER:
			return {"building_materials": 80, "machine_parts": 25}
		_MCSTypes.BuildingType.ATMO_PROCESSOR:
			return {"building_materials": 100, "machine_parts": 30}
		_MCSTypes.BuildingType.FOUNDRY:
			return {"building_materials": 150, "machine_parts": 40}
		_MCSTypes.BuildingType.PRECISION:
			return {"building_materials": 140, "machine_parts": 50}
		_MCSTypes.BuildingType.SOLAR_FARM:
			return {"building_materials": 50, "machine_parts": 10}
		_MCSTypes.BuildingType.REACTOR:
			return {"building_materials": 200, "machine_parts": 60, "fuel": 20}
		# === SERVICES ===
		_MCSTypes.BuildingType.MEDICAL:
			return {"building_materials": 80, "machine_parts": 30}
		_MCSTypes.BuildingType.ACADEMY:
			return {"building_materials": 60, "machine_parts": 15}
		_MCSTypes.BuildingType.RESEARCH:
			return {"building_materials": 100, "machine_parts": 35}
		_MCSTypes.BuildingType.RECREATION:
			return {"building_materials": 55, "machine_parts": 12}
		# === INFRASTRUCTURE ===
		_MCSTypes.BuildingType.STORAGE:
			return {"building_materials": 30, "machine_parts": 5}
		_MCSTypes.BuildingType.COMMS:
			return {"building_materials": 50, "machine_parts": 20}
		_MCSTypes.BuildingType.LOGISTICS:
			return {"building_materials": 70, "machine_parts": 25}
		# === SPACE ECONOMY ===
		_MCSTypes.BuildingType.STARPORT:
			return {"building_materials": 400, "machine_parts": 100, "fuel": 50}
		_MCSTypes.BuildingType.ORBITAL:
			return {"building_materials": 600, "machine_parts": 150, "fuel": 80}
		_MCSTypes.BuildingType.CATCHER:
			return {"building_materials": 800, "machine_parts": 200, "fuel": 100}
		# === MEGASTRUCTURES ===
		_MCSTypes.BuildingType.MASS_DRIVER:
			return {"building_materials": 500, "machine_parts": 200}
		_MCSTypes.BuildingType.FUSION_PLANT:
			return {"building_materials": 600, "machine_parts": 250}
		_MCSTypes.BuildingType.SPACE_ELEVATOR:
			return {"building_materials": 800, "machine_parts": 350}
		_:
			return {"building_materials": 80, "machine_parts": 18}
