extends RefCounted
class_name MCSAI

## MCS (Mars Colony Sim) AI Controller
## Makes automated decisions for events, allowing full "spectate" mode
## Uses simple heuristics based on AI personality and colony state

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
	var pop_count = MCSPopulation.count_alive(colonists)
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

	var pop_count = MCSPopulation.count_alive(colonists)
	var workforce = MCSPopulation.get_workforce_summary(colonists)

	# Calculate current capacities
	var housing_balance = MCSEconomy.calc_housing_balance(buildings, colonists)
	var power_balance = MCSEconomy.calc_power_balance(buildings, colonists)

	# Priority queue based on needs
	var priorities: Array = []

	# Housing shortage?
	if housing_balance.available < 5:
		priorities.append({
			"type": MCSTypes.BuildingType.HAB_POD,
			"priority": 100
		})

	# Power shortage?
	if power_balance.balance < 20:
		priorities.append({
			"type": MCSTypes.BuildingType.SOLAR_ARRAY,
			"priority": 90
		})

	# Food production
	var food = resources.get("food", 0.0)
	var food_consumption = pop_count * 730.0  # Per year
	if food < food_consumption * 1.5:
		priorities.append({
			"type": MCSTypes.BuildingType.GREENHOUSE,
			"priority": 85
		})

	# Medical facilities (if population > 30 and no medical)
	var has_medical = false
	for b in buildings:
		if b.type == MCSTypes.BuildingType.MEDICAL_BAY:
			has_medical = true
			break
	if not has_medical and pop_count > 30:
		priorities.append({
			"type": MCSTypes.BuildingType.MEDICAL_BAY,
			"priority": 70
		})

	# School (if children exist and no school)
	var has_school = false
	for b in buildings:
		if b.type == MCSTypes.BuildingType.SCHOOL:
			has_school = true
			break
	var child_count = 0
	for c in colonists:
		if c.is_alive and c.life_stage == MCSTypes.LifeStage.CHILD:
			child_count += 1
	if not has_school and child_count >= 3:
		priorities.append({
			"type": MCSTypes.BuildingType.SCHOOL,
			"priority": 60
		})

	# Personality adjustments
	match personality:
		Personality.VISIONARY:
			# Boost research/science buildings
			priorities.append({
				"type": MCSTypes.BuildingType.LAB,
				"priority": 50 + random_value * 30
			})
		Personality.HUMANIST:
			# Boost comfort buildings
			priorities.append({
				"type": MCSTypes.BuildingType.RECREATION_CENTER,
				"priority": 40 + random_value * 20
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
		MCSTypes.BuildingType.HAB_POD:
			return {"building_materials": 50, "machine_parts": 10}
		MCSTypes.BuildingType.GREENHOUSE:
			return {"building_materials": 100, "machine_parts": 20}
		MCSTypes.BuildingType.SOLAR_ARRAY:
			return {"building_materials": 50}
		MCSTypes.BuildingType.MEDICAL_BAY:
			return {"building_materials": 80, "machine_parts": 30}
		MCSTypes.BuildingType.SCHOOL:
			return {"building_materials": 60, "machine_parts": 15}
		MCSTypes.BuildingType.LAB:
			return {"building_materials": 90, "machine_parts": 25}
		MCSTypes.BuildingType.RECREATION_CENTER:
			return {"building_materials": 70, "machine_parts": 15}
		_:
			return {"building_materials": 100, "machine_parts": 20}

# ============================================================================
# FULL TURN AI
# ============================================================================

## Run a full AI turn: resolve events, maybe build, advance year
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

	# 2. Maybe build something (30% chance per year, or if critical need)
	if rng.randf() < 0.3 or _has_critical_need(state):
		var building_type = choose_building(state, personality, rng.randf())
		if building_type >= 0:
			store.start_construction(building_type)
			actions.append("Started construction: %s" % MCSTypes.get_building_name(building_type))

	# 3. Auto-assign workers
	store.auto_assign_workers()

	return {
		"actions": actions,
		"year": state.get("current_year", 0)
	}

static func _has_critical_need(state: Dictionary) -> bool:
	var colonists = state.get("colonists", [])
	var buildings = state.get("buildings", [])
	var resources = state.get("resources", {})

	var housing = MCSEconomy.calc_housing_balance(buildings, colonists)
	if housing.get("available", 0) <= 0:
		return true

	var power = MCSEconomy.calc_power_balance(buildings, colonists)
	if power.get("balance", 0) < 0:
		return true

	var food = resources.get("food", 0.0)
	var pop = MCSPopulation.count_alive(colonists)
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
