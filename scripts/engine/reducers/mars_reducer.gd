## Mars Base Phase Reducer
## Handles state changes during Mars surface operations.
##
## All functions are static and pure.
class_name MarsReducer
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
		ActionTypes.ADVANCE_DAY:  # Actually advance sol on Mars
			return _reduce_advance_sol(state, action, balance, rng)
		ActionTypes.CONDUCT_EXPERIMENT:
			return _reduce_conduct_experiment(state, action, balance, rng)
		ActionTypes.COLLECT_SAMPLE:
			return _reduce_collect_sample(state, action, balance, rng)
		ActionTypes.EVA:
			return _reduce_eva(state, action, balance, rng)
		ActionTypes.REPAIR_COMPONENT:
			return _reduce_repair_component(state, action, balance, rng)
		ActionTypes.PREPARE_DEPARTURE:
			return _reduce_prepare_departure(state, action, balance)
		ActionTypes.DEPART_MARS:
			return _reduce_depart_mars(state, action, balance)
		ActionTypes.RESOLVE_EVENT:
			return _reduce_resolve_event(state, action, balance, rng)
		_:
			return state


## ============================================================================
## SOL ADVANCEMENT
## ============================================================================

## Advance one Mars sol
static func _reduce_advance_sol(
	state: Dictionary,
	action: Dictionary,
	balance: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var new_state = state.duplicate(true)

	# Increment sol
	new_state["current_sol"] = state.get("current_sol", 0) + 1
	new_state["current_day"] = state.get("current_day", 0) + 1  # Also track Earth days

	# Reset crew daily hours
	var crew = new_state.get("crew", [])
	for i in range(crew.size()):
		crew[i]["hours_used_today"] = 0
	new_state["crew"] = crew

	# Apply daily systems (different balance on Mars)
	new_state = ResourceSystem.consume_daily(new_state, balance, rng)
	new_state = CrewSystem.apply_daily_update(new_state, balance, rng)

	# Mars-specific effects
	new_state = _apply_mars_environment(new_state, balance, rng)

	# Check departure window
	var departure_status = TimeSystem.calculate_mars_departure_penalty(new_state, balance)
	new_state["departure_status"] = departure_status

	if departure_status.penalty_level == "critical":
		new_state = _add_log(new_state, "Orbital mechanics severely degraded. Departure highly inadvisable!", "warning")

	# Check for events
	var event_roll = rng.randf()
	if EventSystem.check_event_trigger(new_state, balance, event_roll):
		new_state["pending_event_check"] = true

	return new_state


## Apply Mars-specific environmental effects
static func _apply_mars_environment(
	state: Dictionary,
	balance: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var new_state = state.duplicate(true)

	# Dust accumulation on equipment
	var dust_rate = balance.get("mars_dust_accumulation_rate", 0.1)
	var dust_roll = rng.randf()

	if dust_roll < dust_rate:
		# Solar array efficiency reduced
		var ship = new_state.get("ship", {})
		var solar = HexGridSystem.get_component_by_id(ship, "solar_array")

		if not solar.is_empty():
			var position = solar.get("position", {})
			var key = HexMath.hex_key(position.get("q", 0), position.get("r", 0))
			if ship.components.has(key):
				var quality = ship.components[key].get("quality", 100)
				ship.components[key]["quality"] = max(0, quality - 2)
				new_state["ship"] = ship
				new_state = _add_log(new_state, "Dust accumulation reducing solar panel efficiency.", "warning")

	# Radiation exposure (weaker than deep space, Mars has thin atmosphere)
	var radiation_chance = balance.get("mars_radiation_chance", 0.02)
	if rng.randf() < radiation_chance:
		var crew = new_state.get("crew", [])
		var exposure = balance.get("mars_radiation_exposure", 2)

		for i in range(crew.size()):
			if crew[i].get("status") != GameTypes.CrewStatus.DEAD:
				crew[i]["health"] = max(0, crew[i].get("health", 100) - exposure)

		new_state["crew"] = crew
		new_state = _add_log(new_state, "Minor radiation exposure from solar activity.", "info")

	return new_state


## ============================================================================
## SCIENCE OPERATIONS
## ============================================================================

## Conduct a scientific experiment
static func _reduce_conduct_experiment(
	state: Dictionary,
	action: Dictionary,
	balance: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var experiment_id = action.get("experiment_id", "")
	var crew_id = action.get("crew_id", "")

	var new_state = state.duplicate(true)

	# Check if already completed
	var completed = new_state.get("experiments_completed", [])
	if experiment_id in completed:
		return state

	# Find crew member
	var crew = new_state.get("crew", [])
	var crew_idx = -1
	for i in range(crew.size()):
		if crew[i].get("id") == crew_id:
			crew_idx = i
			break

	if crew_idx < 0:
		return state

	var scientist = crew[crew_idx]

	# Check if crew has hours available
	var hours_needed = balance.get("experiment_hours", 6)
	var hours_used = scientist.get("hours_used_today", 0)
	var hours_available = balance.get("hours_per_sol", 16) - hours_used

	if hours_needed > hours_available:
		return state

	# Calculate success chance
	var science_skill = scientist.get("skills", {}).get("science", 50)
	var base_chance = balance.get("experiment_base_success", 0.5)
	var skill_bonus = (science_skill / 100.0) * 0.4

	# Specialty bonus
	if scientist.get("specialty") == "scientist" or scientist.get("role") == "scientist":
		skill_bonus += 0.15

	var success_chance = base_chance + skill_bonus
	var success = rng.randf() < success_chance

	# Apply fatigue
	crew[crew_idx]["hours_used_today"] = hours_used + hours_needed
	crew[crew_idx]["fatigue"] = min(100, scientist.get("fatigue", 0) + 15)

	if success:
		completed.append(experiment_id)
		new_state["experiments_completed"] = completed

		# Science points
		var points = balance.get("experiment_science_points", 50)
		new_state["science_points"] = new_state.get("science_points", 0) + points

		new_state = _add_log(new_state, "%s successfully completed the %s experiment." % [
			scientist.get("name", "Scientist"),
			experiment_id
		], "success")

		# Morale boost for scientist
		crew[crew_idx]["morale"] = min(100, scientist.get("morale", 75) + 5)
	else:
		new_state = _add_log(new_state, "%s experiment inconclusive. May retry tomorrow." % experiment_id, "info")

	new_state["crew"] = crew
	return new_state


## Collect a geological sample
static func _reduce_collect_sample(
	state: Dictionary,
	action: Dictionary,
	balance: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var sample_type = action.get("sample_type", "soil")
	var crew_id = action.get("crew_id", "")
	var location = action.get("location", "")

	var new_state = state.duplicate(true)

	# Find crew member
	var crew = new_state.get("crew", [])
	var crew_idx = -1
	for i in range(crew.size()):
		if crew[i].get("id") == crew_id:
			crew_idx = i
			break

	if crew_idx < 0:
		return state

	var collector = crew[crew_idx]

	# Apply EVA fatigue
	var eva_fatigue = balance.get("eva_fatigue", 20)
	crew[crew_idx]["fatigue"] = min(100, collector.get("fatigue", 0) + eva_fatigue)
	crew[crew_idx]["hours_used_today"] = collector.get("hours_used_today", 0) + 4

	# Collect sample
	var samples = new_state.get("samples_collected", {})
	var current = samples.get(sample_type, 0)
	samples[sample_type] = current + 1
	new_state["samples_collected"] = samples

	# Science points for collection
	var points = balance.get("sample_science_points", {}).get(sample_type, 20)
	new_state["science_points"] = new_state.get("science_points", 0) + points

	new_state["crew"] = crew
	new_state = _add_log(new_state, "%s collected a %s sample from %s." % [
		collector.get("name", "Crew"),
		sample_type,
		location if location else "the surface"
	])

	return new_state


## ============================================================================
## EVA OPERATIONS
## ============================================================================

## Conduct an EVA (Extra-Vehicular Activity)
static func _reduce_eva(
	state: Dictionary,
	action: Dictionary,
	balance: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var crew_id = action.get("crew_id", "")
	var activity = action.get("activity", "")
	var duration_hours = action.get("duration", 4)

	var new_state = state.duplicate(true)

	# Find crew member
	var crew = new_state.get("crew", [])
	var crew_idx = -1
	for i in range(crew.size()):
		if crew[i].get("id") == crew_id:
			crew_idx = i
			break

	if crew_idx < 0:
		return state

	var astronaut = crew[crew_idx]

	# Check health
	if astronaut.get("health", 100) < 50:
		new_state = _add_log(new_state, "%s is too weak for EVA." % astronaut.get("name", "Crew"), "warning")
		return state

	# Apply EVA effects
	var fatigue_per_hour = balance.get("eva_fatigue_per_hour", 5)
	crew[crew_idx]["fatigue"] = min(100, astronaut.get("fatigue", 0) + fatigue_per_hour * duration_hours)
	crew[crew_idx]["hours_used_today"] = astronaut.get("hours_used_today", 0) + duration_hours

	# EVA risk
	var risk_chance = balance.get("eva_accident_chance", 0.05)
	if rng.randf() < risk_chance:
		var injury_amount = balance.get("eva_accident_damage", 15)
		crew[crew_idx]["health"] = max(0, astronaut.get("health", 100) - injury_amount)
		new_state = _add_log(new_state, "%s had an EVA accident! Minor injury sustained." % astronaut.get("name", "Crew"), "warning")
	else:
		new_state = _add_log(new_state, "%s completed EVA: %s" % [astronaut.get("name", "Crew"), activity])

	new_state["crew"] = crew
	return new_state


## Repair a component (Mars surface)
static func _reduce_repair_component(
	state: Dictionary,
	action: Dictionary,
	balance: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var position = action.get("position", Vector2i.ZERO)
	var crew_id = action.get("crew_id", "")

	return ComponentSystem.repair_component(state, position, crew_id, balance, rng)


## ============================================================================
## DEPARTURE
## ============================================================================

## Prepare for departure (checklist)
static func _reduce_prepare_departure(
	state: Dictionary,
	action: Dictionary,
	balance: Dictionary
) -> Dictionary:
	var new_state = state.duplicate(true)

	# Check departure window
	var departure_status = TimeSystem.calculate_mars_departure_penalty(new_state, balance)

	if not departure_status.can_depart:
		new_state = _add_log(new_state, departure_status.message, "warning")
		return state

	# Check minimum requirements
	var issues: Array = []

	# Crew check
	var living_crew = CrewSystem.get_living_crew(new_state)
	if living_crew.size() == 0:
		issues.append("No surviving crew")

	# Fuel check
	var resources = new_state.get("resources", {})
	var fuel = resources.get("fuel", {}).get("current", 0)
	var min_fuel = balance.get("mars_departure_min_fuel", 1000)
	if fuel < min_fuel:
		issues.append("Insufficient fuel for departure")

	# Component check
	var avg_quality = ComponentSystem.get_average_quality(new_state)
	if avg_quality < 30:
		issues.append("Ship too damaged for departure")

	if not issues.is_empty():
		for issue in issues:
			new_state = _add_log(new_state, "Departure blocked: %s" % issue, "error")
		new_state["departure_ready"] = false
	else:
		new_state["departure_ready"] = true
		new_state = _add_log(new_state, "Departure checklist complete. Ready for ascent.", "success")

	return new_state


## Depart Mars and begin return journey
static func _reduce_depart_mars(
	state: Dictionary,
	action: Dictionary,
	balance: Dictionary
) -> Dictionary:
	if not state.get("departure_ready", false):
		return state

	var new_state = state.duplicate(true)

	# Calculate return travel time
	var departure_penalty = TimeSystem.calculate_mars_departure_penalty(new_state, balance)
	var base_return_days = balance.get("base_return_travel_days", 180)
	var return_days = base_return_days + departure_penalty.get("travel_days_added", 0)

	# Transition to return travel phase
	new_state["phase"] = "travel_to_earth"
	new_state["return_travel_day"] = 0
	new_state["return_travel_total_days"] = return_days
	new_state["travel_day"] = 0
	new_state["travel_total_days"] = return_days
	new_state["departure_penalty"] = departure_penalty

	new_state = _add_log(new_state, "Ascent successful! Beginning %d-day journey to Earth." % return_days, "success")

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

	var resolution = EventSystem.resolve_choice(state, event, choice_id, rng)

	if not resolution.success:
		return state

	var effects = resolution.get("effects", [])
	var new_state = EventSystem.apply_effects(state, effects, balance, rng)

	new_state = EventSystem.record_event(new_state, event.get("id", ""))

	var description = resolution.get("description", "Event resolved")
	new_state = _add_log(new_state, description, "event")

	new_state["current_event"] = null

	return new_state


## ============================================================================
## HELPERS
## ============================================================================

## Add a log entry
static func _add_log(state: Dictionary, message: String, entry_type: String = "info") -> Dictionary:
	var new_state = state.duplicate(true)
	var log = new_state.get("event_log", [])

	log.append({
		"sol": state.get("current_sol", 0),
		"day": state.get("current_day", 0),
		"message": message,
		"type": entry_type,
		"timestamp": Time.get_unix_time_from_system()
	})
	new_state["event_log"] = log
	return new_state
