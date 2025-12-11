## Event management system.
## Handles event triggering, selection, resolution, and effect application.
##
## All functions are static and pure.
class_name EventSystem
extends RefCounted


## ============================================================================
## EVENT TRIGGERING
## ============================================================================

## Check if an event should trigger this day/sol
static func check_event_trigger(
	state: Dictionary,
	balance: Dictionary,
	roll: float
) -> bool:
	var phase = state.get("phase", "")
	var base_chance = _get_phase_event_chance(phase, balance)

	# Modify by current conditions
	var modifier = _calculate_trigger_modifier(state, balance)
	var final_chance = base_chance * modifier

	return roll < final_chance


## Get base event trigger chance for a phase
static func _get_phase_event_chance(phase: String, balance: Dictionary) -> float:
	var phase_chances = balance.get("event_trigger_chances", {})

	if phase_chances.has(phase):
		return phase_chances[phase]

	# Defaults
	match phase:
		"ship_building":
			return 0.08  # 8% per day
		"travel_to_mars":
			return 0.12  # 12% per day - travel is eventful
		"mars_base":
			return 0.10  # 10% per sol
		"travel_to_earth":
			return 0.15  # 15% per day - worn systems
		_:
			return 0.05


## Calculate modifier based on state
static func _calculate_trigger_modifier(state: Dictionary, balance: Dictionary) -> float:
	var modifier = 1.0

	# Low morale increases event chance
	var avg_morale = CrewSystem.get_average_morale(state)
	if avg_morale < 40:
		modifier += 0.3
	elif avg_morale < 60:
		modifier += 0.1

	# Low resources increase event chance
	var resources = state.get("resources", {})
	for resource_id in ["food", "water", "oxygen"]:
		var status = ResourceSystem.get_resource_status(state, resource_id, balance)
		if status == "emergency":
			modifier += 0.2
		elif status == "critical":
			modifier += 0.1

	# Component damage increases event chance
	var avg_quality = ComponentSystem.get_average_quality(state)
	if avg_quality < 30:
		modifier += 0.3
	elif avg_quality < 50:
		modifier += 0.15

	return modifier


## ============================================================================
## EVENT SELECTION
## ============================================================================

## Select an event from available events for the current phase
static func select_event(
	state: Dictionary,
	events: Array,
	balance: Dictionary,
	rng: RNGManager
) -> Dictionary:
	if events.is_empty():
		return {}

	# Filter events by trigger conditions
	var valid_events = _filter_valid_events(state, events, balance)

	if valid_events.is_empty():
		return {}

	# Build weighted list
	var weighted_events: Array = []
	var total_weight: float = 0.0

	for event in valid_events:
		var weight = _calculate_event_weight(state, event, balance)
		weighted_events.append({"event": event, "weight": weight})
		total_weight += weight

	# Select by weight
	var roll = rng.randf() * total_weight
	var cumulative: float = 0.0

	for entry in weighted_events:
		cumulative += entry.weight
		if roll <= cumulative:
			return entry.event

	# Fallback to last event
	return weighted_events[-1].event if not weighted_events.is_empty() else {}


## Filter events that can trigger
static func _filter_valid_events(
	state: Dictionary,
	events: Array,
	balance: Dictionary
) -> Array:
	var valid: Array = []
	var current_day = state.get("current_day", 0)

	for event in events:
		var trigger = event.get("trigger", {})

		# Check day range
		var day_range = trigger.get("day_range", [0, 999])
		if current_day < day_range[0] or current_day > day_range[1]:
			continue

		# Check conditions
		var conditions = trigger.get("conditions", [])
		if not _check_conditions(state, conditions):
			continue

		# Check cooldown
		var event_id = event.get("id", "")
		var last_triggered = state.get("event_cooldowns", {}).get(event_id, -999)
		var cooldown = trigger.get("cooldown_days", 0)
		if current_day - last_triggered < cooldown:
			continue

		# Check max occurrences
		var max_occur = trigger.get("max_occurrences", -1)
		if max_occur >= 0:
			var occur_count = state.get("event_counts", {}).get(event_id, 0)
			if occur_count >= max_occur:
				continue

		valid.append(event)

	return valid


## Check all conditions for an event
static func _check_conditions(state: Dictionary, conditions: Array) -> bool:
	for condition in conditions:
		if not _check_single_condition(state, condition):
			return false
	return true


## Check a single condition
static func _check_single_condition(state: Dictionary, condition: Dictionary) -> bool:
	var condition_type = condition.get("type", "")

	match condition_type:
		"crew_count":
			var min_count = condition.get("min", 0)
			var max_count = condition.get("max", 999)
			var living_crew = CrewSystem.get_living_crew(state)
			var count = living_crew.size()
			return count >= min_count and count <= max_count

		"morale_above":
			var threshold = condition.get("threshold", 0)
			return CrewSystem.get_average_morale(state) > threshold

		"morale_below":
			var threshold = condition.get("threshold", 100)
			return CrewSystem.get_average_morale(state) < threshold

		"has_component":
			var component_id = condition.get("component_id", "")
			return ComponentSystem.has_functional_component(state, component_id)

		"resource_above":
			var resource_id = condition.get("resource_id", "")
			var min_val = condition.get("min", 0)
			var resources = state.get("resources", {})
			var current = resources.get(resource_id, {}).get("current", 0)
			return current > min_val

		"resource_below":
			var resource_id = condition.get("resource_id", "")
			var max_val = condition.get("max", 999999)
			var resources = state.get("resources", {})
			var current = resources.get(resource_id, {}).get("current", 0)
			return current < max_val

		"has_flag":
			var flag = condition.get("flag", "")
			return state.get("flags", {}).get(flag, false)

		"not_flag":
			var flag = condition.get("flag", "")
			return not state.get("flags", {}).get(flag, false)

		_:
			return true


## Calculate event weight for selection
static func _calculate_event_weight(
	state: Dictionary,
	event: Dictionary,
	balance: Dictionary
) -> float:
	var trigger = event.get("trigger", {})
	var base_weight = trigger.get("base_probability", 0.5)

	# Category modifiers
	var category = event.get("category", "")
	var category_weights = balance.get("event_category_weights", {})
	var category_mult = category_weights.get(category, 1.0)

	return base_weight * category_mult


## ============================================================================
## CHOICE VALIDATION
## ============================================================================

## Check if a choice is available
static func is_choice_available(
	state: Dictionary,
	choice: Dictionary
) -> bool:
	var requirements = choice.get("requirements", [])

	for req in requirements:
		if not _check_requirement(state, req):
			return false

	return true


## Check a single requirement
static func _check_requirement(state: Dictionary, requirement: Dictionary) -> bool:
	var req_type = requirement.get("type", "")

	match req_type:
		"has_component":
			var component_id = requirement.get("component_id", "")
			return ComponentSystem.has_functional_component(state, component_id)

		"resource":
			var resource_id = requirement.get("resource_id", "")
			var min_val = requirement.get("min", 0)
			var resources = state.get("resources", {})
			var current = resources.get(resource_id, {}).get("current", 0)
			return current >= min_val

		"crew_skill":
			var skill = requirement.get("skill", "")
			var min_val = requirement.get("min", 0)
			var crew = state.get("crew", [])
			for member in crew:
				if member.get("status") == GameTypes.CrewStatus.DEAD:
					continue
				if member.get("skills", {}).get(skill, 0) >= min_val:
					return true
			return false

		"crew_specialty":
			var specialty = requirement.get("specialty", "")
			var crew = state.get("crew", [])
			for member in crew:
				if member.get("status") == GameTypes.CrewStatus.DEAD:
					continue
				if member.get("specialty") == specialty or member.get("role") == specialty:
					return true
			return false

		_:
			return true


## Get available choices for an event
static func get_available_choices(state: Dictionary, event: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var choices = event.get("choices", [])

	for choice in choices:
		var available = is_choice_available(state, choice)
		var choice_copy = choice.duplicate(true)
		choice_copy["available"] = available
		result.append(choice_copy)

	return result


## ============================================================================
## OUTCOME RESOLUTION
## ============================================================================

## Resolve a choice and select outcome
static func resolve_choice(
	state: Dictionary,
	event: Dictionary,
	choice_id: String,
	rng: RNGManager
) -> Dictionary:
	var choice = _find_choice(event, choice_id)
	if choice.is_empty():
		return {"success": false, "error": "Choice not found"}

	if not is_choice_available(state, choice):
		return {"success": false, "error": "Choice not available"}

	var outcomes = choice.get("outcomes", [])
	if outcomes.is_empty():
		return {"success": true, "outcome": {}, "effects": []}

	# Select outcome by weight
	var outcome = _select_outcome(outcomes, rng)

	return {
		"success": true,
		"choice": choice,
		"outcome": outcome,
		"description": outcome.get("description", ""),
		"effects": outcome.get("effects", [])
	}


## Find a choice by ID
static func _find_choice(event: Dictionary, choice_id: String) -> Dictionary:
	for choice in event.get("choices", []):
		if choice.get("id") == choice_id:
			return choice
	return {}


## Select outcome based on weights
static func _select_outcome(outcomes: Array, rng: RNGManager) -> Dictionary:
	if outcomes.is_empty():
		return {}

	if outcomes.size() == 1:
		return outcomes[0]

	var total_weight: float = 0.0
	for outcome in outcomes:
		total_weight += outcome.get("weight", 1.0)

	var roll = rng.randf() * total_weight
	var cumulative: float = 0.0

	for outcome in outcomes:
		cumulative += outcome.get("weight", 1.0)
		if roll <= cumulative:
			return outcome

	return outcomes[-1]


## ============================================================================
## EFFECT APPLICATION
## ============================================================================

## Apply all effects from an outcome
static func apply_effects(
	state: Dictionary,
	effects: Array,
	balance: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var new_state = state.duplicate(true)

	for effect in effects:
		new_state = _apply_single_effect(new_state, effect, balance, rng)

	return new_state


## Apply a single effect
static func _apply_single_effect(
	state: Dictionary,
	effect: Dictionary,
	balance: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var effect_type = effect.get("type", "")

	match effect_type:
		"crew_health":
			return _apply_crew_health_effect(state, effect, rng)

		"crew_morale":
			return _apply_crew_morale_effect(state, effect, rng)

		"crew_fatigue":
			return _apply_crew_fatigue_effect(state, effect, rng)

		"crew_status":
			return _apply_crew_status_effect(state, effect, rng)

		"resource":
			return _apply_resource_effect(state, effect)

		"component_damage":
			return _apply_component_damage_effect(state, effect, rng)

		"component_repair":
			return _apply_component_repair_effect(state, effect)

		"relationship":
			return _apply_relationship_effect(state, effect, balance, rng)

		"time":
			return _apply_time_effect(state, effect)

		"set_flag":
			return _apply_flag_effect(state, effect)

		"log":
			return _apply_log_effect(state, effect)

		_:
			return state


## Apply crew health effect
static func _apply_crew_health_effect(
	state: Dictionary,
	effect: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var target = effect.get("target", "all")
	var amount = effect.get("amount", 0)

	var new_state = state.duplicate(true)
	var crew = new_state.get("crew", [])

	if target == "all":
		for i in range(crew.size()):
			if crew[i].get("status") != GameTypes.CrewStatus.DEAD:
				var current = crew[i].get("health", 100)
				crew[i]["health"] = clamp(current + amount, 0, 100)

	elif target == "random":
		var living = []
		for i in range(crew.size()):
			if crew[i].get("status") != GameTypes.CrewStatus.DEAD:
				living.append(i)

		if not living.is_empty():
			var idx = living[int(rng.randf() * living.size()) % living.size()]
			var current = crew[idx].get("health", 100)
			crew[idx]["health"] = clamp(current + amount, 0, 100)

	new_state["crew"] = crew
	return new_state


## Apply crew morale effect
static func _apply_crew_morale_effect(
	state: Dictionary,
	effect: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var target = effect.get("target", "all")
	var amount = effect.get("amount", 0)

	var new_state = state.duplicate(true)
	var crew = new_state.get("crew", [])

	if target == "all":
		for i in range(crew.size()):
			if crew[i].get("status") != GameTypes.CrewStatus.DEAD:
				var current = crew[i].get("morale", 75)
				crew[i]["morale"] = clamp(current + amount, 0, 100)

	elif target == "random":
		var living = []
		for i in range(crew.size()):
			if crew[i].get("status") != GameTypes.CrewStatus.DEAD:
				living.append(i)

		if not living.is_empty():
			var idx = living[int(rng.randf() * living.size()) % living.size()]
			var current = crew[idx].get("morale", 75)
			crew[idx]["morale"] = clamp(current + amount, 0, 100)

	new_state["crew"] = crew
	return new_state


## Apply crew fatigue effect
static func _apply_crew_fatigue_effect(
	state: Dictionary,
	effect: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var target = effect.get("target", "all")
	var amount = effect.get("amount", 0)

	var new_state = state.duplicate(true)
	var crew = new_state.get("crew", [])

	if target == "all":
		for i in range(crew.size()):
			if crew[i].get("status") != GameTypes.CrewStatus.DEAD:
				var current = crew[i].get("fatigue", 0)
				crew[i]["fatigue"] = clamp(current + amount, 0, 100)

	elif target == "random":
		var living = []
		for i in range(crew.size()):
			if crew[i].get("status") != GameTypes.CrewStatus.DEAD:
				living.append(i)

		if not living.is_empty():
			var idx = living[int(rng.randf() * living.size()) % living.size()]
			var current = crew[idx].get("fatigue", 0)
			crew[idx]["fatigue"] = clamp(current + amount, 0, 100)

	new_state["crew"] = crew
	return new_state


## Apply crew status effect
static func _apply_crew_status_effect(
	state: Dictionary,
	effect: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var target = effect.get("target", "random")
	var status = effect.get("status", "healthy")

	var new_state = state.duplicate(true)
	var crew = new_state.get("crew", [])

	var target_idx = -1
	if target == "random":
		var living = []
		for i in range(crew.size()):
			if crew[i].get("status") != GameTypes.CrewStatus.DEAD:
				living.append(i)
		if not living.is_empty():
			target_idx = living[int(rng.randf() * living.size()) % living.size()]
	else:
		# target is crew ID
		for i in range(crew.size()):
			if crew[i].get("id") == target:
				target_idx = i
				break

	if target_idx >= 0:
		# Map status string to enum
		match status:
			"sick":
				crew[target_idx]["status"] = GameTypes.CrewStatus.SICK
			"injured":
				crew[target_idx]["status"] = GameTypes.CrewStatus.INJURED
			"critical":
				crew[target_idx]["status"] = GameTypes.CrewStatus.CRITICAL
			"recovering":
				crew[target_idx]["status"] = GameTypes.CrewStatus.SICK
			"healthy":
				crew[target_idx]["status"] = GameTypes.CrewStatus.HEALTHY

	new_state["crew"] = crew
	return new_state


## Apply resource effect
static func _apply_resource_effect(state: Dictionary, effect: Dictionary) -> Dictionary:
	var resource_id = effect.get("resource_id", "")
	var amount = effect.get("amount", 0)
	var percent = effect.get("percent", 0)

	var new_state = state.duplicate(true)
	var resources = new_state.get("resources", {})

	if not resources.has(resource_id):
		return new_state

	var resource = resources[resource_id]
	var current = resource.get("current", 0)

	if percent != 0:
		var change = current * (percent / 100.0)
		resource["current"] = max(0, current + change)
	else:
		resource["current"] = max(0, current + amount)

	resources[resource_id] = resource
	new_state["resources"] = resources
	return new_state


## Apply component damage effect
static func _apply_component_damage_effect(
	state: Dictionary,
	effect: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var target = effect.get("target", "random")
	var amount = effect.get("amount", 0)

	var new_state = state.duplicate(true)
	var ship = new_state.get("ship", {})
	var components = HexGridSystem.get_all_components(ship)

	if components.is_empty():
		return new_state

	var target_comp: Dictionary = {}
	if target == "random":
		var idx = int(rng.randf() * components.size()) % components.size()
		target_comp = components[idx]
	else:
		target_comp = HexGridSystem.get_component_by_id(ship, target)

	if target_comp.is_empty():
		return new_state

	var position = target_comp.get("position", {})
	var key = HexMath.hex_key(position.get("q", 0), position.get("r", 0))

	if ship.components.has(key):
		var current_quality = ship.components[key].get("quality", 100)
		ship.components[key]["quality"] = max(0, current_quality - amount)

	new_state["ship"] = ship
	return new_state


## Apply component repair effect
static func _apply_component_repair_effect(state: Dictionary, effect: Dictionary) -> Dictionary:
	var target = effect.get("target", "")
	var amount = effect.get("amount", 0)

	var new_state = state.duplicate(true)
	var ship = new_state.get("ship", {})
	var target_comp = HexGridSystem.get_component_by_id(ship, target)

	if target_comp.is_empty():
		return new_state

	var position = target_comp.get("position", {})
	var key = HexMath.hex_key(position.get("q", 0), position.get("r", 0))

	if ship.components.has(key):
		var current_quality = ship.components[key].get("quality", 100)
		ship.components[key]["quality"] = min(100, current_quality + amount)

	new_state["ship"] = ship
	return new_state


## Apply relationship effect
static func _apply_relationship_effect(
	state: Dictionary,
	effect: Dictionary,
	balance: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var crew1 = effect.get("crew1", "random")
	var crew2 = effect.get("crew2", "random")
	var amount = effect.get("amount", 0)

	var crew = state.get("crew", [])
	var living = []
	for member in crew:
		if member.get("status") != GameTypes.CrewStatus.DEAD:
			living.append(member.get("id"))

	if living.size() < 2:
		return state

	var crew1_id = crew1
	var crew2_id = crew2

	if crew1 == "random":
		var idx = int(rng.randf() * living.size()) % living.size()
		crew1_id = living[idx]

	if crew2 == "random":
		var remaining = living.filter(func(id): return id != crew1_id)
		if remaining.is_empty():
			return state
		var idx = int(rng.randf() * remaining.size()) % remaining.size()
		crew2_id = remaining[idx]

	return CrewSystem.update_relationship(state, crew1_id, crew2_id, amount, balance)


## Apply time effect
static func _apply_time_effect(state: Dictionary, effect: Dictionary) -> Dictionary:
	var days = effect.get("days", 0)

	var new_state = state.duplicate(true)
	new_state["current_day"] = state.get("current_day", 0) + days

	return new_state


## Apply flag effect
static func _apply_flag_effect(state: Dictionary, effect: Dictionary) -> Dictionary:
	var flag = effect.get("flag", "")
	var value = effect.get("value", true)

	var new_state = state.duplicate(true)
	var flags = new_state.get("flags", {})
	flags[flag] = value
	new_state["flags"] = flags

	return new_state


## Apply log effect
static func _apply_log_effect(state: Dictionary, effect: Dictionary) -> Dictionary:
	var message = effect.get("message", "")

	var new_state = state.duplicate(true)
	var log = new_state.get("event_log", [])
	log.append({
		"day": state.get("current_day", 0),
		"message": message,
		"timestamp": Time.get_unix_time_from_system()
	})
	new_state["event_log"] = log

	return new_state


## ============================================================================
## EVENT TRACKING
## ============================================================================

## Record that an event occurred
static func record_event(state: Dictionary, event_id: String) -> Dictionary:
	var new_state = state.duplicate(true)

	# Update cooldown
	var cooldowns = new_state.get("event_cooldowns", {})
	cooldowns[event_id] = state.get("current_day", 0)
	new_state["event_cooldowns"] = cooldowns

	# Update count
	var counts = new_state.get("event_counts", {})
	counts[event_id] = counts.get(event_id, 0) + 1
	new_state["event_counts"] = counts

	return new_state
