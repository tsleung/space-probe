## Travel Phase Reducer
## Handles state changes during journey to/from Mars.
##
## All functions are static and pure.
class_name TravelReducer
extends RefCounted


## ============================================================================
## MAIN REDUCER
## ============================================================================

## Route action to appropriate handler
static func reduce(
	state: Dictionary,
	action: Dictionary,
	balance: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var action_type = action.get("type", "")

	match action_type:
		ActionTypes.ADVANCE_DAY:
			return _reduce_advance_day(state, action, balance, rng)
		ActionTypes.ASSIGN_TASK:
			return _reduce_assign_task(state, action, balance, rng)
		ActionTypes.REPAIR_COMPONENT:
			return _reduce_repair_component(state, action, balance, rng)
		ActionTypes.TREAT_CREW:
			return _reduce_treat_crew(state, action, balance, rng)
		ActionTypes.SET_RATIONING:
			return ResourceSystem.set_rationing(state, action.get("level", "none"))
		ActionTypes.RESOLVE_EVENT:
			return _reduce_resolve_event(state, action, balance, rng)
		_:
			return state


## ============================================================================
## TIME ADVANCEMENT
## ============================================================================

## Advance one travel day
static func _reduce_advance_day(
	state: Dictionary,
	action: Dictionary,
	balance: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var new_state = state.duplicate(true)

	# Increment days
	new_state["current_day"] = state.get("current_day", 0) + 1
	new_state["travel_day"] = state.get("travel_day", 0) + 1

	# Reset crew daily hours
	var crew = new_state.get("crew", [])
	for i in range(crew.size()):
		crew[i]["hours_used_today"] = 0
	new_state["crew"] = crew

	# Apply daily systems
	new_state = ResourceSystem.consume_daily(new_state, balance, rng)
	new_state = ResourceSystem.apply_deprivation(new_state, balance, rng)
	new_state = CrewSystem.apply_daily_update(new_state, balance, rng)
	new_state = ComponentSystem.apply_daily_wear(new_state, balance, rng)

	# Check for deaths
	new_state = _check_crew_deaths(new_state, balance)

	# Check game over
	if _is_game_over(new_state):
		new_state["phase"] = "game_over"
		new_state["game_over_reason"] = _get_game_over_reason(new_state)
		return new_state

	# Check for random events
	var event_roll = rng.randf()
	if EventSystem.check_event_trigger(new_state, balance, event_roll):
		new_state["pending_event_check"] = true

	# Add degradation warnings
	new_state = _add_degradation_warnings(new_state, balance)

	# Check for arrival
	var travel_day = new_state.get("travel_day", 0)
	var total_days = new_state.get("travel_total_days", 180)

	if travel_day >= total_days:
		new_state = _handle_arrival(new_state, balance)

	return new_state


## Check for crew deaths
static func _check_crew_deaths(state: Dictionary, balance: Dictionary) -> Dictionary:
	var new_state = state.duplicate(true)
	var crew = new_state.get("crew", [])
	var deaths_today: Array = []

	for i in range(crew.size()):
		if crew[i].get("health", 100) <= 0 and crew[i].get("status") != GameTypes.CrewStatus.DEAD:
			crew[i]["status"] = GameTypes.CrewStatus.DEAD
			deaths_today.append(crew[i])

	new_state["crew"] = crew

	for dead in deaths_today:
		new_state = _add_log(new_state, "%s has died. The crew mourns their loss." % dead.get("name", "Crew member"), "error")
		new_state["crew_deaths"] = new_state.get("crew_deaths", 0) + 1

	return new_state


## Check if game is over
static func _is_game_over(state: Dictionary) -> bool:
	var crew = state.get("crew", [])
	var alive_count = 0

	for member in crew:
		if member.get("status") != GameTypes.CrewStatus.DEAD:
			alive_count += 1

	return alive_count == 0


## Get game over reason
static func _get_game_over_reason(state: Dictionary) -> String:
	var crew = state.get("crew", [])
	var all_dead = true

	for member in crew:
		if member.get("status") != GameTypes.CrewStatus.DEAD:
			all_dead = false
			break

	if all_dead:
		return "total_crew_loss"

	return "unknown"


## Handle arrival at destination
static func _handle_arrival(state: Dictionary, balance: Dictionary) -> Dictionary:
	var new_state = state.duplicate(true)
	var phase = state.get("phase", "")

	var arrival_status = _check_arrival_status(new_state, balance)

	if not arrival_status.can_arrive:
		new_state["phase"] = "game_over"
		new_state["game_over_reason"] = "arrival_failure"
		for issue in arrival_status.issues:
			new_state = _add_log(new_state, issue, "error")
		return new_state

	if phase == "travel_to_mars":
		new_state["phase"] = "mars_arrival"
		new_state["arrival_status"] = arrival_status
		new_state = _add_log(new_state, "Mars orbit achieved! Preparing for landing sequence.", "success")
	elif phase == "travel_to_earth":
		new_state["phase"] = "earth_arrival"
		new_state["arrival_status"] = arrival_status
		new_state = _add_log(new_state, "Earth orbit achieved! Preparing for reentry.", "success")

	return new_state


## Check arrival status
static func _check_arrival_status(state: Dictionary, balance: Dictionary) -> Dictionary:
	var crew = state.get("crew", [])
	var alive_count = 0
	var healthy_count = 0

	for member in crew:
		if member.get("status") != GameTypes.CrewStatus.DEAD:
			alive_count += 1
			if member.get("status") == GameTypes.CrewStatus.HEALTHY:
				healthy_count += 1

	var avg_quality = ComponentSystem.get_average_quality(state)
	var min_quality = balance.get("minimum_arrival_quality", 20)

	var can_arrive = alive_count > 0 and avg_quality >= min_quality

	var issues: Array = []
	if alive_count == 0:
		issues.append("No surviving crew members")
	if avg_quality < min_quality:
		issues.append("Ship too damaged for orbital insertion (quality: %.0f%%)" % avg_quality)

	return {
		"can_arrive": can_arrive,
		"alive_crew": alive_count,
		"healthy_crew": healthy_count,
		"ship_quality": avg_quality,
		"issues": issues
	}


## Add degradation warnings to log
static func _add_degradation_warnings(state: Dictionary, balance: Dictionary) -> Dictionary:
	var new_state = state
	var crew = state.get("crew", [])
	var ship = state.get("ship", {})
	var resources = state.get("resources", {})

	# Component warnings
	var components = HexGridSystem.get_all_components(ship)
	for comp in components:
		var quality = comp.get("quality", 100)
		var state_level = ComponentSystem.get_component_state(quality)

		if state_level == ComponentSystem.ComponentState.CRITICAL:
			new_state = _add_log(new_state, "%s is failing! Repairs urgently needed." % comp.get("name", "Component"), "warning")
		elif state_level == ComponentSystem.ComponentState.DAMAGED:
			new_state = _add_log(new_state, "%s is showing signs of wear." % comp.get("name", "Component"), "warning")

	# Crew warnings
	for member in crew:
		if member.get("status") == GameTypes.CrewStatus.DEAD:
			continue

		if member.get("health", 100) < 30:
			new_state = _add_log(new_state, "%s is in critical condition!" % member.get("name", "Crew"), "warning")
		if member.get("morale", 75) < 20:
			new_state = _add_log(new_state, "%s is on the verge of breakdown." % member.get("name", "Crew"), "warning")

	# Resource warnings
	for resource_id in ["food", "water", "oxygen"]:
		var status = ResourceSystem.get_resource_status(state, resource_id, balance)
		if status == "emergency":
			new_state = _add_log(new_state, "%s supplies critical!" % resource_id.capitalize(), "error")
		elif status == "critical":
			new_state = _add_log(new_state, "%s supplies low." % resource_id.capitalize(), "warning")

	return new_state


## ============================================================================
## CREW ACTIVITIES
## ============================================================================

## Assign a task to a crew member
static func _reduce_assign_task(
	state: Dictionary,
	action: Dictionary,
	balance: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var crew_id = action.get("crew_id", "")
	var task = action.get("task", "")

	return CrewSystem.assign_task(state, crew_id, task)


## Repair a component
static func _reduce_repair_component(
	state: Dictionary,
	action: Dictionary,
	balance: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var position = action.get("position", Vector2i.ZERO)
	var crew_id = action.get("crew_id", "")

	return ComponentSystem.repair_component(state, position, crew_id, balance, rng)


## Treat a crew member
static func _reduce_treat_crew(
	state: Dictionary,
	action: Dictionary,
	balance: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var patient_id = action.get("patient_id", "")
	var medic_id = action.get("medic_id", "")

	var new_state = state.duplicate(true)
	var crew = new_state.get("crew", [])
	var resources = new_state.get("resources", {})

	# Check medical supplies
	var medical_supplies = resources.get("medical_supplies", {}).get("current", 0)
	if medical_supplies < 1:
		return state

	# Find patient and medic
	var patient_idx = -1
	var medic_idx = -1
	for i in range(crew.size()):
		if crew[i].get("id") == patient_id:
			patient_idx = i
		if crew[i].get("id") == medic_id:
			medic_idx = i

	if patient_idx < 0:
		return state
	if medic_idx < 0:
		medic_idx = patient_idx  # Self-treatment

	var patient = crew[patient_idx]
	var medic = crew[medic_idx]

	# Calculate healing
	var medical_skill = medic.get("skills", {}).get("medical", 50)
	var base_heal = balance.get("base_heal_amount", 20)
	var skill_bonus = (medical_skill / 100.0) * base_heal

	# Specialty bonus
	if medic.get("specialty") == "medic" or medic.get("role") == "medic":
		skill_bonus *= 1.25

	var heal_amount = (base_heal + skill_bonus) * (0.8 + rng.randf() * 0.4)

	# Apply healing
	crew[patient_idx]["health"] = min(100, patient.get("health", 0) + heal_amount)

	# Check for condition cure
	var conditions = patient.get("conditions", [])
	var new_conditions: Array = []
	for condition in conditions:
		var cure_chance = balance.get("base_cure_chance", 0.4) + (medical_skill / 200.0)
		if rng.randf() >= cure_chance:
			new_conditions.append(condition)
	crew[patient_idx]["conditions"] = new_conditions

	# Update status if healthy
	if crew[patient_idx]["health"] >= 50 and new_conditions.is_empty():
		crew[patient_idx]["status"] = GameTypes.CrewStatus.HEALTHY

	# Consume supplies
	resources["medical_supplies"]["current"] = medical_supplies - 1

	new_state["crew"] = crew
	new_state["resources"] = resources
	new_state = _add_log(new_state, "%s treated %s (restored %.0f health)" % [
		medic.get("name", "Medic"),
		patient.get("name", "Patient"),
		heal_amount
	])

	return new_state


## ============================================================================
## EVENT RESOLUTION
## ============================================================================

## Resolve a player choice in an event
static func _reduce_resolve_event(
	state: Dictionary,
	action: Dictionary,
	balance: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var event = action.get("event", {})
	var choice_id = action.get("choice_id", "")

	# Resolve the choice
	var resolution = EventSystem.resolve_choice(state, event, choice_id, rng)

	if not resolution.success:
		return state

	# Apply effects
	var effects = resolution.get("effects", [])
	var new_state = EventSystem.apply_effects(state, effects, balance, rng)

	# Record event
	new_state = EventSystem.record_event(new_state, event.get("id", ""))

	# Add to log
	var description = resolution.get("description", "Event resolved")
	new_state = _add_log(new_state, description, "event")

	# Clear pending event
	new_state["current_event"] = null

	return new_state


## ============================================================================
## HELPERS
## ============================================================================

## Add a log entry
static func _add_log(state: Dictionary, message: String, entry_type: String = "info") -> Dictionary:
	var new_state = state.duplicate(true)
	var log = new_state.get("event_log", [])

	# Avoid duplicate recent messages
	if log.size() > 0:
		var last = log[-1]
		if last.get("message") == message:
			return state

	log.append({
		"day": state.get("current_day", 0),
		"message": message,
		"type": entry_type,
		"timestamp": Time.get_unix_time_from_system()
	})
	new_state["event_log"] = log
	return new_state
