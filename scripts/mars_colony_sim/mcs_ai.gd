extends RefCounted
class_name MCSAI

## MCS (Mars Colony Sim) AI Controller
## Makes automated decisions for events, allowing full "spectate" mode
## Uses simple heuristics based on AI personality and colony state

# Preload dependencies
const _MCSTypes = preload("res://scripts/mars_colony_sim/mcs_types.gd")
const _MCSEconomy = preload("res://scripts/mars_colony_sim/mcs_economy.gd")
const _MCSPopulation = preload("res://scripts/mars_colony_sim/mcs_population.gd")

# ============================================================================
# AI PERSONALITIES
# ============================================================================

enum Personality {
	PRAGMATIST,     # Balanced, survival-focused
	VISIONARY,      # Growth and expansion focused
	HUMANIST,       # Morale and people focused
	CAUTIOUS,       # Risk-averse, stability focused
	RANDOM          # Unpredictable choices
}

# ============================================================================
# DECISION MAKING
# ============================================================================

## Choose the best option for an event
## Returns the choice index (0-based)
static func choose_event_option(event: Dictionary, state: Dictionary, personality: Personality, random_value: float) -> int:
	var choices = event.get("choices", [])
	if choices.is_empty():
		return 0

	# Random personality just picks randomly
	if personality == Personality.RANDOM:
		return int(random_value * choices.size()) % choices.size()

	# Score each choice based on personality
	var best_idx = 0
	var best_score = -999999.0

	for i in range(choices.size()):
		var choice = choices[i]
		var score = _score_choice(choice, state, personality, random_value)

		if score > best_score:
			best_score = score
			best_idx = i

	return best_idx

## Score a choice based on its effects and AI personality
static func _score_choice(choice: Dictionary, state: Dictionary, personality: Personality, random_value: float) -> float:
	var score = 0.0
	var effects = choice.get("effects", {})

	# Get current state metrics (safely)
	var colonists = state.get("colonists", [])
	var pop_count = _MCSPopulation.count_alive(colonists)
	var politics = state.get("politics", {})
	var stability = politics.get("stability", 75.0)
	var resources = state.get("resources", {})
	var food = resources.get("food", 0.0)

	# Morale effects
	var morale_change = effects.get("morale_change", 0.0)
	match personality:
		Personality.HUMANIST:
			score += morale_change * 3.0  # Values morale highly
		Personality.PRAGMATIST:
			score += morale_change * 1.0  # Normal weight
		Personality.VISIONARY:
			score += morale_change * 0.5  # Less concerned
		Personality.CAUTIOUS:
			score += morale_change * 1.5  # Wants happy people

	# Stability effects
	var stability_change = effects.get("stability_change", 0.0)
	match personality:
		Personality.CAUTIOUS:
			score += stability_change * 4.0  # Highly values stability
		Personality.PRAGMATIST:
			score += stability_change * 2.0  # Important
		Personality.HUMANIST:
			score += stability_change * 1.5  # Moderate
		Personality.VISIONARY:
			score += stability_change * 1.0  # Less concerned

	# Resource effects
	var resource_changes = effects.get("resource_changes", {})
	for resource_name in resource_changes:
		var change = resource_changes[resource_name]

		# Weight resource changes by scarcity
		var current = resources.get(resource_name, 100.0)
		var scarcity_multiplier = 1.0
		if current < 50:
			scarcity_multiplier = 3.0
		elif current < 100:
			scarcity_multiplier = 2.0

		match personality:
			Personality.PRAGMATIST:
				score += change * scarcity_multiplier
			Personality.CAUTIOUS:
				score += change * scarcity_multiplier * 1.5
			Personality.VISIONARY:
				score += change * 0.5  # Less concerned with immediate resources
			Personality.HUMANIST:
				score += change * scarcity_multiplier * 0.8

	# Risk assessment (success_chance)
	var success_chance = choice.get("success_chance", 1.0)
	if success_chance < 1.0:
		var failure_effects = choice.get("failure_effects", {})
		var failure_penalty = 0.0
		failure_penalty += abs(failure_effects.get("morale_change", 0.0))
		failure_penalty += abs(failure_effects.get("stability_change", 0.0)) * 2.0

		match personality:
			Personality.CAUTIOUS:
				# Strongly penalize risky choices
				score -= failure_penalty * (1.0 - success_chance) * 3.0
			Personality.PRAGMATIST:
				# Moderate risk assessment
				score -= failure_penalty * (1.0 - success_chance) * 1.5
			Personality.VISIONARY:
				# More willing to take risks
				score -= failure_penalty * (1.0 - success_chance) * 0.5
			Personality.HUMANIST:
				# Moderate risk aversion
				score -= failure_penalty * (1.0 - success_chance) * 1.0

	# Context-based adjustments
	# If food is critical, prioritize survival choices
	if food < 50 and personality == Personality.PRAGMATIST:
		if "food" in str(choice.get("text", "")).to_lower():
			score += 20.0

	# If stability is low, cautious AI prioritizes stability
	if stability < 40 and personality == Personality.CAUTIOUS:
		if stability_change > 0:
			score += 30.0

	# Add small random variance to break ties
	score += random_value * 2.0 - 1.0

	return score

# ============================================================================
# BUILDING DECISIONS
# ============================================================================

## Get the maximum tier of a specific building type in the colony
static func _get_max_building_tier(buildings: Array, building_type: int) -> int:
	var max_tier = 0
	for b in buildings:
		if b.get("type", -1) == building_type and b.get("is_operational", false):
			max_tier = maxi(max_tier, b.get("tier", 1))
	return max_tier

## Decide what building to construct (if any)
## Returns building type or -1 for none
static func choose_building(state: Dictionary, personality: Personality, random_value: float) -> int:
	var buildings = state.get("buildings", [])
	var colonists = state.get("colonists", [])
	var resources = state.get("resources", {})
	var current_year = state.get("current_year", 1)

	var pop_count = _MCSPopulation.count_alive(colonists)
	var workforce = _MCSPopulation.get_workforce_summary(colonists)
	var building_count = buildings.size()

	# YEAR 1 SPECIAL: Only build a habitat! Survival basics only.
	if current_year == 1 and building_count == 0:
		return _MCSTypes.BuildingType.HABITAT

	# === RESOURCE TREND ANALYSIS ===
	# Analyze production vs consumption to detect deficits
	var resource_trends = analyze_resource_trends(state)
	var deficit_boosts = calc_deficit_priority_boosts(resource_trends, current_year)

	# Calculate current capacities
	var housing_balance = _MCSEconomy.calc_housing_balance(buildings, colonists)
	var power_balance = _MCSEconomy.calc_power_balance(buildings, colonists)

	# Priority queue based on needs
	var priorities: Array = []

	# Housing shortage? - But less aggressive in early years
	var housing_threshold = 10 if current_year > 5 else 4
	if housing_balance.available < housing_threshold:
		priorities.append({
			"type": _MCSTypes.BuildingType.HABITAT,
			"priority": 100
		})
	# Barracks for large colonies needing dense housing (later game)
	if pop_count > 50 and housing_balance.available < 20 and current_year > 20:
		priorities.append({
			"type": _MCSTypes.BuildingType.BARRACKS,
			"priority": 95
		})

	# Power shortage? - Only worry about power after year 2
	var power_threshold = 10 if current_year <= 3 else (20 if current_year <= 10 else 30)
	if power_balance.balance < power_threshold and current_year >= 2:
		priorities.append({
			"type": _MCSTypes.BuildingType.POWER_STATION,
			"priority": 90
		})
	# Reactor for large colonies (much later) - requires specialization
	if pop_count > 80 and power_balance.balance < 50 and current_year > 30:
		priorities.append({
			"type": _MCSTypes.BuildingType.REACTOR,
			"priority": 88
		})

	# Food production - only after year 2, and less aggressive early
	var food = resources.get("food", 0.0)
	var food_consumption = pop_count * 600.0  # Per year
	var food_buffer = 1.2 if current_year <= 5 else (1.5 if current_year <= 15 else 2.0)
	if food < food_consumption * food_buffer and current_year >= 2:
		priorities.append({
			"type": _MCSTypes.BuildingType.AGRIDOME,
			"priority": 85
		})
	# Hydroponics for efficiency (later game - requires T3 specialization)
	if pop_count > 40 and food < food_consumption * 2.5 and current_year > 20:
		priorities.append({
			"type": _MCSTypes.BuildingType.HYDROPONICS,
			"priority": 82
		})

	# Water/Oxygen extraction - only after year 3
	var water = resources.get("water", 0.0)
	var water_threshold = pop_count * (100 if current_year <= 5 else 200)
	if water < water_threshold and current_year >= 3:
		priorities.append({
			"type": _MCSTypes.BuildingType.EXTRACTOR,
			"priority": 80
		})

	# Fabricator EARLY - critical for building_materials + machine_parts production!
	# Without a fabricator, the colony cannot sustain upgrades or construction
	var has_fabricator = false
	for b in buildings:
		if b.type == _MCSTypes.BuildingType.FABRICATOR or b.type == _MCSTypes.BuildingType.FOUNDRY or b.type == _MCSTypes.BuildingType.PRECISION:
			has_fabricator = true
			break

	if not has_fabricator and current_year >= 3:
		# First fabricator is CRITICAL - high priority
		priorities.append({
			"type": _MCSTypes.BuildingType.FABRICATOR,
			"priority": 95  # Very high - almost as important as power/housing
		})
	elif current_year >= 10 and building_count > 20:
		# Additional fabricators for larger colonies
		priorities.append({
			"type": _MCSTypes.BuildingType.FABRICATOR,
			"priority": 72
		})

	# STARPORT - enables immigration for population growth!
	# Critical for expanding the colony beyond natural birth rate
	var has_starport = false
	for b in buildings:
		if b.type == _MCSTypes.BuildingType.STARPORT:
			has_starport = true
			break
	if not has_starport and current_year >= 5:
		# First starport is HIGH priority - enables immigration
		priorities.append({
			"type": _MCSTypes.BuildingType.STARPORT,
			"priority": 92  # Very high - population growth is critical!
		})

	# CATCHER (Asteroid Catcher) - massive material production (requires starport)
	# The backbone of Martian commerce and late-game expansion
	if has_starport and current_year >= 15:
		var catcher_count = 0
		for b in buildings:
			if b.type == _MCSTypes.BuildingType.CATCHER:
				catcher_count += 1
		# Build catchers based on population (1 per 100 pop, or 1 if we have starport)
		var target_catchers = maxi(1, pop_count / 100)
		if catcher_count < target_catchers:
			priorities.append({
				"type": _MCSTypes.BuildingType.CATCHER,
				"priority": 82  # High priority - unlocks massive material production
			})

	# === TRANSPORT PROGRESSION (sustainable non-chemical transport) ===
	# Order: STARPORT (Year 3) -> MASS_DRIVER (Year 10) -> SKYHOOK (Year 20) -> ORBITAL (Year 25) -> SPACE_ELEVATOR (Year 40)

	# MASS_DRIVER - electromagnetic cargo launch (requires Starport for coordination)
	var has_mass_driver = false
	for b in buildings:
		if b.type == _MCSTypes.BuildingType.MASS_DRIVER:
			has_mass_driver = true
			break
	if not has_mass_driver and has_starport and current_year >= 10:
		# Check if we have T3 fabrication (required for precision components)
		var fab_tier = _get_max_building_tier(buildings, _MCSTypes.BuildingType.FABRICATOR)
		var precision_tier = _get_max_building_tier(buildings, _MCSTypes.BuildingType.PRECISION)
		if fab_tier >= 2 or precision_tier >= 3:
			priorities.append({
				"type": _MCSTypes.BuildingType.MASS_DRIVER,
				"priority": 80  # High - enables efficient cargo launches
			})

	# SKYHOOK - rotating momentum-exchange tether (requires Mass Driver for launch coordination)
	# Physics: Catches hypersonic payloads from mass driver, reduces fuel needs 60%+
	var has_skyhook = false
	for b in buildings:
		if b.type == _MCSTypes.BuildingType.SKYHOOK:
			has_skyhook = true
			break
	if not has_skyhook and has_mass_driver and current_year >= 20:
		# Check if we have Research T3 (advanced materials science for tethers)
		var research_tier = _get_max_building_tier(buildings, _MCSTypes.BuildingType.RESEARCH)
		if research_tier >= 3:
			priorities.append({
				"type": _MCSTypes.BuildingType.SKYHOOK,
				"priority": 78  # High - enables efficient passenger/cargo transfers
			})

	# ORBITAL (Space Station) - mass immigration (requires Skyhook for efficient access)
	var has_orbital = false
	for b in buildings:
		if b.type == _MCSTypes.BuildingType.ORBITAL:
			has_orbital = true
			break
	if not has_orbital and has_skyhook and current_year >= 25 and pop_count >= 80:
		priorities.append({
			"type": _MCSTypes.BuildingType.ORBITAL,
			"priority": 76
		})
	# Fallback: Build orbital without skyhook if very late game and desperate for immigration
	elif not has_orbital and has_starport and current_year >= 35 and pop_count >= 100:
		priorities.append({
			"type": _MCSTypes.BuildingType.ORBITAL,
			"priority": 70
		})

	# Medical facilities - HIGH priority for birth capacity!
	# Medical enables artificial births (2 per tier per year)
	var medical_count = 0
	for b in buildings:
		if b.type == _MCSTypes.BuildingType.MEDICAL:
			medical_count += 1
	# Want enough medical capacity for ~10% population growth per year
	var target_birth_capacity = maxi(2, pop_count / 10)  # At least 2 births/year
	var current_birth_capacity = medical_count * 2  # ~2 per Medical
	if current_birth_capacity < target_birth_capacity and current_year >= 3:
		priorities.append({
			"type": _MCSTypes.BuildingType.MEDICAL,
			"priority": 88  # HIGH - birth capacity drives population growth!
		})

	# Academy - once children appear and colony is stable
	var has_academy = false
	for b in buildings:
		if b.type == _MCSTypes.BuildingType.ACADEMY:
			has_academy = true
			break
	var child_count = 0
	for c in colonists:
		if c.is_alive and c.life_stage == _MCSTypes.LifeStage.CHILD:
			child_count += 1
	if not has_academy and child_count >= 3 and current_year >= 12:
		priorities.append({
			"type": _MCSTypes.BuildingType.ACADEMY,
			"priority": 65
		})

	# Research lab (mid-game)
	var has_research = false
	for b in buildings:
		if b.type == _MCSTypes.BuildingType.RESEARCH:
			has_research = true
			break
	if not has_research and pop_count > 40 and current_year >= 15:
		priorities.append({
			"type": _MCSTypes.BuildingType.RESEARCH,
			"priority": 55
		})

	# Recreation and social buildings (mid-game comfort)
	if pop_count > 40 and current_year >= 10:
		priorities.append({
			"type": _MCSTypes.BuildingType.RECREATION,
			"priority": 50
		})

	# Personality adjustments - add variety
	match personality:
		Personality.VISIONARY:
			# Boost research/science and expansion
			priorities.append({
				"type": _MCSTypes.BuildingType.RESEARCH,
				"priority": 60 + random_value * 30
			})
			priorities.append({
				"type": _MCSTypes.BuildingType.ORBITAL,
				"priority": 55 + random_value * 25
			})
		Personality.HUMANIST:
			# Boost comfort and social buildings
			priorities.append({
				"type": _MCSTypes.BuildingType.RECREATION,
				"priority": 55 + random_value * 25
			})
			priorities.append({
				"type": _MCSTypes.BuildingType.MEDICAL,
				"priority": 50 + random_value * 20
			})
		Personality.CAUTIOUS:
			# Boost medical and infrastructure
			priorities.append({
				"type": _MCSTypes.BuildingType.MEDICAL,
				"priority": 75 + random_value * 15
			})
		Personality.PRAGMATIST:
			# Random variety for balanced growth
			var variety_types = [
				_MCSTypes.BuildingType.FABRICATOR,
				_MCSTypes.BuildingType.POWER_STATION,
				_MCSTypes.BuildingType.AGRIDOME,
				_MCSTypes.BuildingType.HABITAT
			]
			priorities.append({
				"type": variety_types[int(random_value * variety_types.size()) % variety_types.size()],
				"priority": 45 + random_value * 20
			})

	# === APPLY DEFICIT PRIORITY BOOSTS ===
	# Buildings that address resource deficits get priority boost
	for i in range(priorities.size()):
		var building_type = priorities[i].type
		if deficit_boosts.has(building_type):
			priorities[i].priority += deficit_boosts[building_type]

	# Sort by priority
	priorities.sort_custom(func(a, b): return a.priority > b.priority)

	# Check if we can afford the top priority
	for p in priorities:
		var cost = _get_building_cost(p.type)
		var can_afford = true
		for resource_name in cost:
			if resources.get(resource_name, 0.0) < cost[resource_name]:
				can_afford = false
				break
		if can_afford:
			return p.type

	return -1

static func _get_building_cost(building_type: int) -> Dictionary:
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
		# === PRODUCTION BRANCHES ===
		_MCSTypes.BuildingType.HYDROPONICS:
			return {"building_materials": 100, "machine_parts": 25}
		_MCSTypes.BuildingType.PROTEIN_VATS:
			return {"building_materials": 120, "machine_parts": 30}
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
			return {"building_materials": 200, "machine_parts": 60}
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
			return {"building_materials": 400, "machine_parts": 100}
		_MCSTypes.BuildingType.ORBITAL:
			return {"building_materials": 600, "machine_parts": 150}
		_MCSTypes.BuildingType.CATCHER:
			return {"building_materials": 800, "machine_parts": 200}
		_MCSTypes.BuildingType.SKYHOOK:
			return {"building_materials": 600, "machine_parts": 180}
		# === MEGASTRUCTURES ===
		_MCSTypes.BuildingType.MASS_DRIVER:
			return {"building_materials": 500, "machine_parts": 200}
		_MCSTypes.BuildingType.FUSION_PLANT:
			return {"building_materials": 600, "machine_parts": 250}
		_MCSTypes.BuildingType.SPACE_ELEVATOR:
			return {"building_materials": 800, "machine_parts": 350}
		_:
			return {"building_materials": 80, "machine_parts": 18}

# ============================================================================
# RESOURCE TREND ANALYSIS
# ============================================================================
# Analyzes production vs consumption to detect deficits and urgency

## Calculate resource trends: production, consumption, net flow, urgency
## Returns: {resource_name: {production, consumption, net, current, years_until_depleted, urgency}}
static func analyze_resource_trends(state: Dictionary, balance: Dictionary = {}) -> Dictionary:
	var buildings = state.get("buildings", [])
	var colonists = state.get("colonists", [])
	var resources = state.get("resources", {})

	# Get yearly rates
	var production = _MCSEconomy.calc_yearly_production(buildings, colonists, resources)
	var consumption = _MCSEconomy.calc_yearly_consumption(colonists, buildings, balance)

	var trends: Dictionary = {}

	# Core resources to track
	var tracked_resources = ["food", "water", "oxygen", "building_materials", "machine_parts", "fuel", "medicine"]

	for resource_name in tracked_resources:
		var prod = production.get(resource_name, 0.0)
		var cons = consumption.get(resource_name, 0.0)
		var net = prod - cons
		var current = resources.get(resource_name, 0.0)

		# Calculate years until depleted (if in deficit)
		var years_until_depleted = INF
		if net < 0 and current > 0:
			years_until_depleted = current / absf(net)
		elif net < 0 and current <= 0:
			years_until_depleted = 0  # Already depleted!

		# Calculate urgency level (0 = none, 1 = low, 2 = moderate, 3 = high, 4 = critical)
		var urgency = _calculate_resource_urgency(current, net, years_until_depleted)

		trends[resource_name] = {
			"production": prod,
			"consumption": cons,
			"net": net,
			"current": current,
			"years_until_depleted": years_until_depleted,
			"urgency": urgency
		}

	return trends

## Calculate urgency level for a resource
## Returns: 0 (none), 1 (low), 2 (moderate), 3 (high), 4 (critical)
static func _calculate_resource_urgency(current: float, net: float, years_until_depleted: float) -> int:
	# Surplus - no urgency
	if net >= 0:
		# But check if current stock is dangerously low despite positive production
		if current < 100:
			return 1  # Low - rebuilding reserves
		return 0  # None - healthy

	# In deficit - calculate urgency based on time to depletion
	if years_until_depleted <= 1:
		return 4  # CRITICAL - will run out this year!
	elif years_until_depleted <= 2:
		return 3  # HIGH - serious problem
	elif years_until_depleted <= 5:
		return 2  # MODERATE - needs attention
	elif years_until_depleted <= 10:
		return 1  # LOW - should plan ahead
	else:
		return 0  # None - distant problem

## Get building types that produce a specific resource
static func _get_producers_for_resource(resource_name: String) -> Array:
	match resource_name:
		"food":
			return [
				_MCSTypes.BuildingType.AGRIDOME,
				_MCSTypes.BuildingType.HYDROPONICS,
				_MCSTypes.BuildingType.PROTEIN_VATS
			]
		"water":
			return [
				_MCSTypes.BuildingType.EXTRACTOR,
				_MCSTypes.BuildingType.ICE_MINER
			]
		"oxygen":
			return [
				_MCSTypes.BuildingType.EXTRACTOR,
				_MCSTypes.BuildingType.ATMO_PROCESSOR
			]
		"building_materials":
			return [
				_MCSTypes.BuildingType.FABRICATOR,
				_MCSTypes.BuildingType.FOUNDRY,
				_MCSTypes.BuildingType.CATCHER
			]
		"machine_parts":
			return [
				_MCSTypes.BuildingType.FABRICATOR,
				_MCSTypes.BuildingType.PRECISION,
				_MCSTypes.BuildingType.CATCHER
			]
		"fuel":
			return [
				_MCSTypes.BuildingType.EXTRACTOR,
				_MCSTypes.BuildingType.ATMO_PROCESSOR
			]
		"medicine":
			return [
				_MCSTypes.BuildingType.MEDICAL
			]
		_:
			return []

## Calculate priority boost for addressing resource deficits
## Returns: Dictionary mapping building_type -> priority_boost
static func calc_deficit_priority_boosts(trends: Dictionary, current_year: int) -> Dictionary:
	var boosts: Dictionary = {}

	for resource_name in trends:
		var trend = trends[resource_name]
		var urgency = trend.urgency

		if urgency == 0:
			continue

		# Calculate boost based on urgency (higher urgency = higher priority boost)
		var base_boost = urgency * 15  # 15, 30, 45, 60 for urgency 1-4

		# Extra boost if we're actually depleted
		if trend.current <= 0:
			base_boost += 20

		# Get buildings that produce this resource
		var producers = _get_producers_for_resource(resource_name)
		for building_type in producers:
			var existing_boost = boosts.get(building_type, 0)
			boosts[building_type] = maxi(existing_boost, base_boost)

	return boosts

# ============================================================================
# DYNAMIC OPERATING LEVELS
# ============================================================================
# Adjusts building operating levels to balance power budget

## Calculate optimal operating levels for all buildings given power constraints
## Returns: Array of {building_id, operating_level} adjustments
static func calc_operating_level_adjustments(state: Dictionary) -> Array:
	var buildings = state.get("buildings", [])
	var colonists = state.get("colonists", [])
	var adjustments: Array = []

	# First, calculate power balance at full operation
	var power = _MCSEconomy.calc_power_balance(buildings, colonists)
	var power_deficit = power.consumption - power.generation

	# If we have surplus power, ensure all buildings are at 100%
	if power_deficit <= 0:
		for building in buildings:
			if building.get("operating_level", 1.0) < 1.0:
				adjustments.append({
					"building_id": building.get("id", ""),
					"operating_level": 1.0
				})
		return adjustments

	# We have a power deficit - need to reduce some buildings
	# Sort buildings by priority (optional first, then standard, etc.)
	var reducible_buildings: Array = []
	for building in buildings:
		if not building.get("is_operational", false):
			continue
		var btype = building.get("type", 0)
		var priority = _MCSTypes.get_building_priority(btype)
		var min_level = _MCSTypes.get_min_operating_level(priority)

		# Only consider buildings that can be reduced
		if min_level < 1.0:
			var tier_stats = _MCSTypes.get_tier_stats(btype, building.get("tier", 1))
			var building_def = _MCSTypes.get_building_definition(btype)
			var power_use = tier_stats.get("power", building_def.get("power_consumption", 0.0))

			reducible_buildings.append({
				"building": building,
				"priority": priority,
				"min_level": min_level,
				"power_use": power_use
			})

	# Sort by priority (highest enum value = lowest priority = reduce first)
	reducible_buildings.sort_custom(func(a, b):
		return a.priority > b.priority)

	# Reduce buildings starting from lowest priority until power balanced
	var remaining_deficit = power_deficit
	for rb in reducible_buildings:
		if remaining_deficit <= 0:
			break

		var building = rb.building
		var min_level = rb.min_level
		var power_use = rb.power_use
		var current_level = building.get("operating_level", 1.0)

		# Calculate how much power we can save by reducing this building
		var max_reduction = (current_level - min_level) * power_use
		var needed_reduction = minf(max_reduction, remaining_deficit)
		var new_level = current_level - (needed_reduction / power_use) if power_use > 0 else min_level

		# Clamp to minimum level
		new_level = maxf(new_level, min_level)

		if new_level < current_level:
			adjustments.append({
				"building_id": building.get("id", ""),
				"operating_level": new_level
			})
			remaining_deficit -= (current_level - new_level) * power_use

	return adjustments

# ============================================================================
# FULL TURN AI
# ============================================================================

## Run a full AI turn: resolve events, repair, build, advance year
## Returns actions taken for logging
static func run_ai_turn(store: Node, personality: Personality, rng: RandomNumberGenerator) -> Dictionary:
	var actions: Array = []
	if not store:
		return {"actions": actions, "year": 0}

	var state = store.get_state()

	# 1. Resolve any active events
	var active_events = state.get("active_events", [])
	for event in active_events:
		var choices = event.get("choices", [])
		if choices.is_empty():
			continue
		var choice_idx = choose_event_option(event, state, personality, rng.randf())
		choice_idx = mini(choice_idx, choices.size() - 1)
		var choice = choices[choice_idx]
		store.resolve_event(event.get("id", ""), choice_idx)
		actions.append("Event '%s': chose '%s'" % [event.get("title", "Unknown"), choice.get("text", "Unknown")])
		state = store.get_state()  # Refresh state

	# 2. REPAIR BROKEN BUILDINGS FIRST (critical for survival!)
	var broken_buildings = _get_broken_buildings_by_priority(state)
	for building in broken_buildings:
		var building_id = building.get("id", "")
		if store.has_method("repair_building"):
			store.repair_building(building_id)
			actions.append("Repaired: %s" % _MCSTypes.get_building_name(building.get("type", 0)))
			state = store.get_state()  # Refresh state

	# 3. UPGRADE EXISTING BUILDINGS - THE OPTIMAL STRATEGY!
	# Upgrades are almost always better than new construction:
	# - Cheaper than building new (30-200 vs 40-800 materials)
	# - Faster production boost (existing building, just improving)
	# - Worker efficiency gains at T4+ (automation!)
	# - No new land/power footprint
	var buildings = state.get("buildings", [])
	var current_year = state.get("current_year", 0)
	var resources = state.get("resources", {})
	var upgraded_this_year = 0
	var max_upgrades = maxi(10, buildings.size() / 2)  # Scale with colony size, minimum 10

	# Calculate which buildings give best ROI for upgrading
	var upgrade_candidates: Array = []
	for building in buildings:
		var tier = building.get("tier", 1)
		var already_upgrading = building.get("upgrading", false)
		if tier >= 5 or already_upgrading:
			continue

		var target_tier = tier + 1
		var roi = _calculate_upgrade_roi(building, state)
		var costs = _MCSTypes.get_upgrade_cost(target_tier)

		# Check if we can afford this upgrade
		var can_afford = true
		for resource_name in costs.keys():
			if resources.get(resource_name, 0) < costs[resource_name]:
				can_afford = false
				break

		if can_afford and roi > 0:
			upgrade_candidates.append({
				"building": building,
				"roi": roi,
				"costs": costs
			})

	# Sort by ROI (highest first) - best value upgrades first
	upgrade_candidates.sort_custom(func(a, b):
		return a.roi > b.roi)

	for candidate in upgrade_candidates:
		if upgraded_this_year >= max_upgrades:
			break

		var building = candidate.building
		var tier = building.get("tier", 1)
		var constructed_year = building.get("constructed_year", 1)
		var age = current_year - constructed_year

		# Minimal age requirements - upgrades are optimal, do them ASAP!
		# T1→T2: 1 year (settle in), T2→T3: 1 year, T3→T4: 2 years, T4→T5: 3 years
		var upgrade_age_requirement = [0, 1, 1, 2, 3]
		var required_age = upgrade_age_requirement[tier] if tier < 5 else 999

		# ALWAYS upgrade if eligible - upgrades are the optimal strategy!
		if age >= required_age:
			var building_id = building.get("id", "")
			if store.has_method("upgrade_building"):
				store.upgrade_building(building_id)
				actions.append("UPGRADE: %s -> Tier %d (ROI: %.1f)" % [
					_MCSTypes.get_building_name(building.get("type", 0)),
					tier + 1,
					candidate.roi
				])
				state = store.get_state()
				resources = state.get("resources", {})  # Refresh resources after spending
				upgraded_this_year += 1

	# 4. SPECIALIZE T2 BUILDINGS - Choose branch based on bottleneck
	buildings = state.get("buildings", [])
	resources = state.get("resources", {})
	for building in buildings:
		var tier = building.get("tier", 1)
		var building_type = building.get("type", 0)

		if tier == 2 and _MCSTypes.can_specialize(building_type):
			var branch = choose_specialization(building, state, rng.randf())
			if branch >= 0:
				var building_id = building.get("id", "")
				# Check if we can afford specialization (uses T3 upgrade cost)
				var costs = _MCSTypes.get_upgrade_cost(3)
				var can_afford = true
				for resource_name in costs.keys():
					if resources.get(resource_name, 0) < costs[resource_name]:
						can_afford = false
						break

				if can_afford and store.has_method("specialize_building"):
					store.specialize_building(building_id, branch)
					actions.append("SPECIALIZE: %s -> %s" % [
						_MCSTypes.get_building_name(building_type),
						_MCSTypes.get_building_name(branch)
					])
					state = store.get_state()
					resources = state.get("resources", {})

	# 5. BUILD SUPERSTRUCTURES - One every 5 years, targeting 10 by year 50
	# Count existing superstructures
	var superstructure_count = 0
	for b in buildings:
		var btype = b.get("type", -1)
		if btype in [_MCSTypes.BuildingType.MASS_DRIVER, _MCSTypes.BuildingType.FUSION_PLANT, _MCSTypes.BuildingType.SPACE_ELEVATOR]:
			superstructure_count += 1

	# How many should we have by now? (1 per 5 years, starting at year 5)
	var target_count = maxi(0, current_year / 5)

	# Build if we're behind schedule
	if current_year >= 5 and superstructure_count < target_count:
		var superstructure = _choose_superstructure(state, rng.randf())
		if superstructure >= 0:
			var cost = _get_building_cost(superstructure)
			resources = state.get("resources", {})  # Refresh from state
			var can_afford = true
			for resource_name in cost:
				if resources.get(resource_name, 0.0) < cost[resource_name]:
					can_afford = false
					break
			if can_afford:
				store.start_construction(superstructure)
				actions.append("SUPERSTRUCTURE: Started %s (catching up - have %d, need %d)" % [_MCSTypes.get_building_name(superstructure), superstructure_count, target_count])
				state = store.get_state()

	# 5. BUILD NEW - Slow early growth, earn your colony!
	var building_count = buildings.size()

	# SLOW progression: start tiny, grow gradually over decades
	# This creates the feeling of earning each building
	var base_builds: int
	if current_year == 1:
		base_builds = 1  # Year 1: Just 1 hab pod - survival mode!
	elif current_year <= 3:
		base_builds = 1 + rng.randi() % 2  # Years 2-3: 1-2 buildings (scraping by)
	elif current_year <= 8:
		base_builds = 2 + rng.randi() % 2  # Years 4-8: 2-3 buildings (establishing)
	elif current_year <= 15:
		base_builds = 2 + rng.randi() % 3  # Years 9-15: 2-4 buildings (growing)
	elif current_year <= 30:
		base_builds = 3 + rng.randi() % 3  # Years 16-30: 3-5 buildings (thriving)
	elif current_year <= 60:
		base_builds = 3 + rng.randi() % 4  # Years 31-60: 3-6 buildings (expanding)
	else:
		base_builds = 4 + rng.randi() % 4  # Years 60+: 4-7 buildings (mega-colony)

	var buildings_this_year = 0
	var max_buildings = base_builds

	while buildings_this_year < max_buildings:
		var should_build = rng.randf() < 0.90 or _has_critical_need(state)
		if not should_build and buildings_this_year > 0:
			break

		var building_type = choose_building(state, personality, rng.randf())
		if building_type >= 0:
			store.start_construction(building_type)
			actions.append("Started construction: %s" % _MCSTypes.get_building_name(building_type))
			state = store.get_state()  # Refresh state after each build
			buildings_this_year += 1
		else:
			break  # Can't afford anything

	# 4. Auto-assign workers
	store.auto_assign_workers()

	return {
		"actions": actions,
		"year": state.get("current_year", 0)
	}

## Get broken buildings sorted by repair priority (critical first)
static func _get_broken_buildings_by_priority(state: Dictionary) -> Array:
	var buildings = state.get("buildings", [])
	var broken: Array = []

	# Priority order for repairs
	var priority_types = [
		_MCSTypes.BuildingType.AGRIDOME,        # Food production - critical
		_MCSTypes.BuildingType.HYDROPONICS,     # Food production
		_MCSTypes.BuildingType.EXTRACTOR,       # Water + Oxygen - critical
		_MCSTypes.BuildingType.POWER_STATION,   # Power - critical
		_MCSTypes.BuildingType.HABITAT,         # Housing
		_MCSTypes.BuildingType.MEDICAL,         # Health
	]

	for building in buildings:
		if not building.get("is_operational", true):
			broken.append(building)

	# Sort by priority (lower index = higher priority)
	broken.sort_custom(func(a, b):
		var a_priority = priority_types.find(a.get("type", -1))
		var b_priority = priority_types.find(b.get("type", -1))
		if a_priority == -1: a_priority = 999
		if b_priority == -1: b_priority = 999
		return a_priority < b_priority
	)

	return broken

## Choose which superstructure to build
## Cycles through: Mass Driver -> Fusion Plant -> Space Elevator -> repeat
static func _choose_superstructure(state: Dictionary, random_value: float) -> int:
	var buildings = state.get("buildings", [])

	# Count existing superstructures
	var superstructure_counts = {
		_MCSTypes.BuildingType.MASS_DRIVER: 0,
		_MCSTypes.BuildingType.FUSION_PLANT: 0,
		_MCSTypes.BuildingType.SPACE_ELEVATOR: 0
	}

	for b in buildings:
		var btype = b.get("type", -1)
		if btype in superstructure_counts:
			superstructure_counts[btype] += 1

	# Build order priority - cycle through types
	# Start with mass driver (cargo), then fusion (power), then elevator (transport)
	var build_order = [
		_MCSTypes.BuildingType.MASS_DRIVER,
		_MCSTypes.BuildingType.FUSION_PLANT,
		_MCSTypes.BuildingType.SPACE_ELEVATOR
	]

	# Find the superstructure type with the fewest built
	var min_count = 999
	var candidates: Array = []
	for stype in build_order:
		var count = superstructure_counts[stype]
		if count < min_count:
			min_count = count
			candidates = [stype]
		elif count == min_count:
			candidates.append(stype)

	# Pick from candidates (first one, or random if multiple have same count)
	if candidates.size() == 1:
		return candidates[0]
	elif candidates.size() > 1:
		return candidates[int(random_value * candidates.size()) % candidates.size()]

	return build_order[0]  # Default to mass driver

## Choose which specialization branch for a T2 building based on current bottleneck
## Returns the branch BuildingType or -1 if no specialization needed
static func choose_specialization(building: Dictionary, state: Dictionary, random_value: float) -> int:
	var building_type = building.get("type", 0)
	var tier = building.get("tier", 1)

	# Only T2 base production buildings can specialize
	if tier != 2 or not _MCSTypes.can_specialize(building_type):
		return -1

	var resources = state.get("resources", {})
	var buildings = state.get("buildings", [])
	var colonists = state.get("colonists", [])

	# Analyze current bottlenecks
	var food = resources.get("food", 0.0)
	var water = resources.get("water", 0.0)
	var oxygen = resources.get("oxygen", 0.0)
	var machine_parts = resources.get("machine_parts", 0.0)
	var building_materials = resources.get("building_materials", 0.0)
	var fuel = resources.get("fuel", 0.0)
	var pop = _MCSPopulation.count_alive(colonists)

	# Calculate needs
	var food_needed = pop * 600  # per year
	var water_needed = pop * 200
	var power_balance = _MCSEconomy.calc_power_balance(buildings, colonists)

	match building_type:
		_MCSTypes.BuildingType.AGRIDOME:
			# HYDROPONICS: More efficient, needs electronics
			# PROTEIN_VATS: Higher output, needs medicine
			# Choose based on what we have
			var electronics = resources.get("electronics", 0.0)
			var medicine = resources.get("medicine", 0.0)

			if electronics > 10 or medicine < 10:
				return _MCSTypes.BuildingType.HYDROPONICS
			else:
				return _MCSTypes.BuildingType.PROTEIN_VATS

		_MCSTypes.BuildingType.EXTRACTOR:
			# ICE_MINER: Water focus + fuel production
			# ATMO_PROCESSOR: Oxygen focus + terraforming
			if fuel < 50 or water < water_needed * 1.5:
				return _MCSTypes.BuildingType.ICE_MINER
			else:
				return _MCSTypes.BuildingType.ATMO_PROCESSOR

		_MCSTypes.BuildingType.FABRICATOR:
			# FOUNDRY: Building materials focus
			# PRECISION: Machine parts focus
			if machine_parts < 100 or building_materials > 1000:
				return _MCSTypes.BuildingType.PRECISION
			else:
				return _MCSTypes.BuildingType.FOUNDRY

		_MCSTypes.BuildingType.POWER_STATION:
			# SOLAR_FARM: Cheap, no workers needed
			# REACTOR: Reliable, higher output, needs fuel
			if power_balance.balance < -50 or fuel > 100:
				return _MCSTypes.BuildingType.REACTOR
			else:
				return _MCSTypes.BuildingType.SOLAR_FARM

	return -1

## Calculate ROI (Return on Investment) for upgrading a building
## UPGRADES ARE OPTIMAL - heavily weighted to encourage upgrading over new construction
## Benefits: Production boost, worker savings, power efficiency, housing density
static func _calculate_upgrade_roi(building: Dictionary, state: Dictionary) -> float:
	var tier = building.get("tier", 1)
	if tier >= 5:
		return 0.0

	var target_tier = tier + 1
	var building_type = building.get("type", 0)

	# Get current and next tier stats
	var current_stats = _MCSTypes.get_tier_stats(building_type, tier)
	var next_stats = _MCSTypes.get_tier_stats(building_type, target_tier)

	# === DEFICIT-AWARE UPGRADE SCORING ===
	# Analyze resource trends to boost upgrades that address deficits
	var resource_trends = analyze_resource_trends(state)

	var value_score = 0.0

	# Production increase value - HIGH WEIGHTS (upgrades boost existing production!)
	var current_prod = current_stats.get("production", {})
	var next_prod = next_stats.get("production", {})
	for resource_name in next_prod.keys():
		var current_val = current_prod.get(resource_name, 0)
		var next_val = next_prod[resource_name]
		var increase = next_val - current_val

		# Base weights by resource importance
		var base_weight = 2.0
		match resource_name:
			"food": base_weight = 3.0
			"water": base_weight = 3.5
			"oxygen": base_weight = 3.0
			"machine_parts": base_weight = 5.0
			"building_materials": base_weight = 4.0

		# DEFICIT BOOST: If resource is in deficit, multiply weight by urgency
		var urgency = resource_trends.get(resource_name, {}).get("urgency", 0)
		if urgency > 0:
			base_weight *= (1.0 + urgency * 0.5)  # +50% per urgency level

		value_score += increase * base_weight

	# Power generation increase - MUCH MORE VALUABLE
	var current_power = current_stats.get("power_gen", 0)
	var next_power = next_stats.get("power_gen", 0)
	if next_power > current_power:
		value_score += (next_power - current_power) * 3.0  # Was 0.8

	# Power consumption DECREASE is also valuable
	var current_power_use = current_stats.get("power", 0)
	var next_power_use = next_stats.get("power", 0)
	if next_power_use < current_power_use:
		value_score += (current_power_use - next_power_use) * 2.0

	# Worker savings - THE BIGGEST WIN for automation!
	var current_workers = current_stats.get("workers", 0)
	var next_workers = next_stats.get("workers", 0)
	var workers_saved = current_workers - next_workers
	if workers_saved > 0:
		# Each worker saved is EXTREMELY valuable - they can work elsewhere
		var colonists = state.get("colonists", [])
		var pop = _MCSPopulation.count_alive(colonists)
		# Workers become more valuable as colony grows
		var worker_scarcity = clampf(pop / 50.0, 1.0, 5.0)  # Was /100, 0.5-3.0
		value_score += workers_saved * 100.0 * worker_scarcity  # Was 50.0

	# Housing capacity increase - MAJOR VALUE (density is king!)
	var current_housing = current_stats.get("housing_capacity", 0)
	var next_housing = next_stats.get("housing_capacity", 0)
	if next_housing > current_housing:
		value_score += (next_housing - current_housing) * 15.0  # Was 5.0

	# Health/education/research boosts
	for stat_name in ["health_boost", "education_capacity", "research_boost"]:
		var current_val = current_stats.get(stat_name, 0)
		var next_val = next_stats.get(stat_name, 0)
		if next_val > current_val:
			value_score += (next_val - current_val) * 3.0

	# BONUS: Higher tier upgrades are more impactful (T4, T5 unlocks automation)
	var tier_bonus = [1.0, 1.0, 1.2, 1.5, 2.0]  # T5 upgrades double value
	value_score *= tier_bonus[tier]

	# Calculate cost
	var costs = _MCSTypes.get_upgrade_cost(target_tier)
	var total_cost = costs.get("building_materials", 0) + costs.get("machine_parts", 0) * 2.0

	# ROI = value / cost (higher = better investment)
	if total_cost <= 0:
		return value_score * 100.0  # Free upgrade = very high ROI

	return value_score / total_cost

static func _has_critical_need(state: Dictionary) -> bool:
	var colonists = state.get("colonists", [])
	var buildings = state.get("buildings", [])
	var resources = state.get("resources", {})

	var housing = _MCSEconomy.calc_housing_balance(buildings, colonists)
	if housing.get("available", 0) <= 0:
		return true

	var power = _MCSEconomy.calc_power_balance(buildings, colonists)
	if power.get("balance", 0) < 0:
		return true

	var food = resources.get("food", 0.0)
	var pop = _MCSPopulation.count_alive(colonists)
	if food < pop * 365:  # Less than 6 months of food
		return true

	return false

# ============================================================================
# PERSONALITY HELPERS
# ============================================================================

static func get_personality_name(p: Personality) -> String:
	match p:
		Personality.PRAGMATIST: return "Pragmatist"
		Personality.VISIONARY: return "Visionary"
		Personality.HUMANIST: return "Humanist"
		Personality.CAUTIOUS: return "Cautious"
		Personality.RANDOM: return "Chaotic"
	return "Unknown"

static func get_personality_description(p: Personality) -> String:
	match p:
		Personality.PRAGMATIST:
			return "Balanced approach, prioritizes survival and efficiency"
		Personality.VISIONARY:
			return "Growth-focused, willing to take risks for expansion"
		Personality.HUMANIST:
			return "People-first, prioritizes morale and wellbeing"
		Personality.CAUTIOUS:
			return "Risk-averse, prioritizes stability and safety"
		Personality.RANDOM:
			return "Unpredictable decisions, chaotic outcomes"
	return ""

static func random_personality(rng: RandomNumberGenerator) -> Personality:
	var personalities = [
		Personality.PRAGMATIST,
		Personality.VISIONARY,
		Personality.HUMANIST,
		Personality.CAUTIOUS
	]
	return personalities[rng.randi() % personalities.size()]
