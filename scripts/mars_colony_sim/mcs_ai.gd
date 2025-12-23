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

	# YEAR 1 SPECIAL: Only build a hab pod! Survival basics only.
	if current_year == 1 and building_count == 0:
		return _MCSTypes.BuildingType.HAB_POD

	# Calculate current capacities
	var housing_balance = _MCSEconomy.calc_housing_balance(buildings, colonists)
	var power_balance = _MCSEconomy.calc_power_balance(buildings, colonists)

	# Priority queue based on needs
	var priorities: Array = []

	# Housing shortage? - But less aggressive in early years
	var housing_threshold = 10 if current_year > 5 else 4
	if housing_balance.available < housing_threshold:
		priorities.append({
			"type": _MCSTypes.BuildingType.HAB_POD,
			"priority": 100
		})
	# Upgrade to apartments for large colonies (later game)
	if pop_count > 50 and housing_balance.available < 20 and current_year > 20:
		priorities.append({
			"type": _MCSTypes.BuildingType.APARTMENT_BLOCK,
			"priority": 95
		})

	# Power shortage? - Only worry about power after year 2
	var power_threshold = 10 if current_year <= 3 else (20 if current_year <= 10 else 30)
	if power_balance.balance < power_threshold and current_year >= 2:
		priorities.append({
			"type": _MCSTypes.BuildingType.SOLAR_ARRAY,
			"priority": 90
		})
	# Fission reactor for large colonies (much later)
	if pop_count > 80 and power_balance.balance < 50 and current_year > 30:
		priorities.append({
			"type": _MCSTypes.BuildingType.FISSION_REACTOR,
			"priority": 88
		})

	# Food production - only after year 2, and less aggressive early
	var food = resources.get("food", 0.0)
	var food_consumption = pop_count * 600.0  # Per year
	var food_buffer = 1.2 if current_year <= 5 else (1.5 if current_year <= 15 else 2.0)
	if food < food_consumption * food_buffer and current_year >= 2:
		priorities.append({
			"type": _MCSTypes.BuildingType.GREENHOUSE,
			"priority": 85
		})
	# Hydroponics for efficiency (later game)
	if pop_count > 40 and food < food_consumption * 2.5 and current_year > 20:
		priorities.append({
			"type": _MCSTypes.BuildingType.HYDROPONICS,
			"priority": 82
		})

	# Water extraction - only after year 3
	var water = resources.get("water", 0.0)
	var water_threshold = pop_count * (100 if current_year <= 5 else 200)
	if water < water_threshold and current_year >= 3:
		priorities.append({
			"type": _MCSTypes.BuildingType.WATER_EXTRACTOR,
			"priority": 80
		})

	# Workshop for production - need more buildings first
	var has_workshop = false
	for b in buildings:
		if b.type == _MCSTypes.BuildingType.WORKSHOP:
			has_workshop = true
			break
	if not has_workshop and building_count >= 12 and current_year >= 8:
		priorities.append({
			"type": _MCSTypes.BuildingType.WORKSHOP,
			"priority": 75
		})

	# Factory for large colonies (requires industrial base)
	if pop_count > 60 and building_count > 25 and current_year > 25:
		priorities.append({
			"type": _MCSTypes.BuildingType.FACTORY,
			"priority": 72
		})

	# Medical facilities - not until colony is established
	var has_medical = false
	for b in buildings:
		if b.type == _MCSTypes.BuildingType.MEDICAL_BAY:
			has_medical = true
			break
	if not has_medical and pop_count > 30 and current_year >= 8:
		priorities.append({
			"type": _MCSTypes.BuildingType.MEDICAL_BAY,
			"priority": 70
		})
	# Hospital upgrade (late game)
	if pop_count > 100 and current_year > 40:
		priorities.append({
			"type": _MCSTypes.BuildingType.HOSPITAL,
			"priority": 68
		})

	# School - once children appear and colony is stable
	var has_school = false
	for b in buildings:
		if b.type == _MCSTypes.BuildingType.SCHOOL:
			has_school = true
			break
	var child_count = 0
	for c in colonists:
		if c.is_alive and c.life_stage == _MCSTypes.LifeStage.CHILD:
			child_count += 1
	if not has_school and child_count >= 3 and current_year >= 12:
		priorities.append({
			"type": _MCSTypes.BuildingType.SCHOOL,
			"priority": 65
		})
	# University for advanced colony (late game)
	if pop_count > 80 and current_year > 35:
		priorities.append({
			"type": _MCSTypes.BuildingType.UNIVERSITY,
			"priority": 60
		})

	# Lab for research (mid-game)
	var has_lab = false
	for b in buildings:
		if b.type == _MCSTypes.BuildingType.LAB:
			has_lab = true
			break
	if not has_lab and pop_count > 40 and current_year >= 15:
		priorities.append({
			"type": _MCSTypes.BuildingType.LAB,
			"priority": 55
		})
	# Research center (late game)
	if pop_count > 100 and current_year > 40:
		priorities.append({
			"type": _MCSTypes.BuildingType.RESEARCH_CENTER,
			"priority": 52
		})

	# Recreation and social buildings (mid-game comfort)
	if pop_count > 40 and current_year >= 10:
		priorities.append({
			"type": _MCSTypes.BuildingType.RECREATION_CENTER,
			"priority": 50
		})

	# Government hall for large colony (late game)
	if pop_count > 80 and current_year > 35:
		priorities.append({
			"type": _MCSTypes.BuildingType.GOVERNMENT_HALL,
			"priority": 45
		})

	# Temple for culture (mid-late game)
	if pop_count > 60 and current_year > 25:
		priorities.append({
			"type": _MCSTypes.BuildingType.TEMPLE,
			"priority": 40
		})

	# Personality adjustments - add variety
	match personality:
		Personality.VISIONARY:
			# Boost research/science and expansion
			priorities.append({
				"type": _MCSTypes.BuildingType.LAB,
				"priority": 60 + random_value * 30
			})
			priorities.append({
				"type": _MCSTypes.BuildingType.RESEARCH_CENTER,
				"priority": 55 + random_value * 25
			})
		Personality.HUMANIST:
			# Boost comfort and social buildings
			priorities.append({
				"type": _MCSTypes.BuildingType.RECREATION_CENTER,
				"priority": 55 + random_value * 25
			})
			priorities.append({
				"type": _MCSTypes.BuildingType.HOSPITAL,
				"priority": 50 + random_value * 20
			})
		Personality.CAUTIOUS:
			# Boost medical and infrastructure
			priorities.append({
				"type": _MCSTypes.BuildingType.MEDICAL_BAY,
				"priority": 75 + random_value * 15
			})
		Personality.PRAGMATIST:
			# Random variety for balanced growth
			var variety_types = [
				_MCSTypes.BuildingType.WORKSHOP,
				_MCSTypes.BuildingType.SOLAR_ARRAY,
				_MCSTypes.BuildingType.GREENHOUSE,
				_MCSTypes.BuildingType.HAB_POD
			]
			priorities.append({
				"type": variety_types[int(random_value * variety_types.size()) % variety_types.size()],
				"priority": 45 + random_value * 20
			})

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
		# Housing
		_MCSTypes.BuildingType.HAB_POD:
			return {"building_materials": 40, "machine_parts": 8}
		_MCSTypes.BuildingType.APARTMENT_BLOCK:
			return {"building_materials": 120, "machine_parts": 25}
		_MCSTypes.BuildingType.LUXURY_QUARTERS:
			return {"building_materials": 180, "machine_parts": 40}
		_MCSTypes.BuildingType.BARRACKS:
			return {"building_materials": 60, "machine_parts": 10}
		# Food
		_MCSTypes.BuildingType.GREENHOUSE:
			return {"building_materials": 80, "machine_parts": 15}
		_MCSTypes.BuildingType.HYDROPONICS:
			return {"building_materials": 120, "machine_parts": 30}
		_MCSTypes.BuildingType.PROTEIN_VATS:
			return {"building_materials": 150, "machine_parts": 45}
		# Power
		_MCSTypes.BuildingType.SOLAR_ARRAY:
			return {"building_materials": 35, "machine_parts": 5}
		_MCSTypes.BuildingType.WIND_TURBINE:
			return {"building_materials": 50, "machine_parts": 12}
		_MCSTypes.BuildingType.RTG:
			return {"building_materials": 80, "machine_parts": 35}
		_MCSTypes.BuildingType.FISSION_REACTOR:
			return {"building_materials": 200, "machine_parts": 60}
		# Medical
		_MCSTypes.BuildingType.MEDICAL_BAY:
			return {"building_materials": 70, "machine_parts": 25}
		_MCSTypes.BuildingType.HOSPITAL:
			return {"building_materials": 150, "machine_parts": 50}
		# Science
		_MCSTypes.BuildingType.SCHOOL:
			return {"building_materials": 50, "machine_parts": 12}
		_MCSTypes.BuildingType.UNIVERSITY:
			return {"building_materials": 140, "machine_parts": 40}
		_MCSTypes.BuildingType.LAB:
			return {"building_materials": 80, "machine_parts": 22}
		_MCSTypes.BuildingType.RESEARCH_CENTER:
			return {"building_materials": 160, "machine_parts": 55}
		# Industry
		_MCSTypes.BuildingType.WORKSHOP:
			return {"building_materials": 60, "machine_parts": 20}
		_MCSTypes.BuildingType.FACTORY:
			return {"building_materials": 180, "machine_parts": 60}
		# Water
		_MCSTypes.BuildingType.WATER_EXTRACTOR:
			return {"building_materials": 45, "machine_parts": 15}
		# Social
		_MCSTypes.BuildingType.RECREATION_CENTER:
			return {"building_materials": 55, "machine_parts": 12}
		_MCSTypes.BuildingType.TEMPLE:
			return {"building_materials": 80, "machine_parts": 15}
		_MCSTypes.BuildingType.GOVERNMENT_HALL:
			return {"building_materials": 130, "machine_parts": 35}
		# Superstructures - expensive mega-projects
		_MCSTypes.BuildingType.MASS_DRIVER:
			return {"building_materials": 500, "machine_parts": 200}
		_MCSTypes.BuildingType.FUSION_REACTOR:
			return {"building_materials": 600, "machine_parts": 250}
		_MCSTypes.BuildingType.SPACE_ELEVATOR:
			return {"building_materials": 800, "machine_parts": 350}
		_:
			return {"building_materials": 80, "machine_parts": 18}

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

	# 3. UPGRADE EXISTING BUILDINGS - Taller, more impressive!
	var upgraded_this_year = 0
	var max_upgrades = 3 + rng.randi() % 4  # 3-6 upgrades per year (more aggressive!)
	var buildings = state.get("buildings", [])
	var current_year = state.get("current_year", 0)

	for building in buildings:
		if upgraded_this_year >= max_upgrades:
			break
		var tier = building.get("tier", 1)
		# Default constructed_year to year 1 if not set (legacy buildings)
		var constructed_year = building.get("constructed_year", 1)
		var age = current_year - constructed_year
		# Upgrade every 3 years per tier (faster upgrades for visual impact)
		if tier < 5 and age >= (tier * 3) and rng.randf() < 0.6:
			var building_id = building.get("id", "")
			if store.has_method("upgrade_building"):
				store.upgrade_building(building_id)
				actions.append("Upgraded: %s to Tier %d" % [_MCSTypes.get_building_name(building.get("type", 0)), tier + 1])
				state = store.get_state()
				upgraded_this_year += 1

	# 4. BUILD SUPERSTRUCTURES - One every 5 years, targeting 10 by year 50
	if current_year >= 5 and current_year % 5 == 0:
		var superstructure = _choose_superstructure(state, rng.randf())
		if superstructure >= 0:
			var cost = _get_building_cost(superstructure)
			var resources = state.get("resources", {})
			var can_afford = true
			for resource_name in cost:
				if resources.get(resource_name, 0.0) < cost[resource_name]:
					can_afford = false
					break
			if can_afford:
				store.start_construction(superstructure)
				actions.append("SUPERSTRUCTURE: Started %s (Year %d milestone)" % [_MCSTypes.get_building_name(superstructure), current_year])
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
		_MCSTypes.BuildingType.GREENHOUSE,      # Food production - critical
		_MCSTypes.BuildingType.HYDROPONICS,     # Food production
		_MCSTypes.BuildingType.WATER_EXTRACTOR, # Water - critical
		_MCSTypes.BuildingType.SOLAR_ARRAY,     # Power - critical
		_MCSTypes.BuildingType.OXYGENATOR,      # Life support
		_MCSTypes.BuildingType.HAB_POD,         # Housing
		_MCSTypes.BuildingType.MEDICAL_BAY,     # Health
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
## Cycles through: Mass Driver -> Fusion Reactor -> Space Elevator -> repeat
static func _choose_superstructure(state: Dictionary, random_value: float) -> int:
	var buildings = state.get("buildings", [])

	# Count existing superstructures
	var superstructure_counts = {
		_MCSTypes.BuildingType.MASS_DRIVER: 0,
		_MCSTypes.BuildingType.FUSION_REACTOR: 0,
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
		_MCSTypes.BuildingType.FUSION_REACTOR,
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
