## Main Game Reducer
## Handles global actions (new game, phase change, logging, flags).
## Phase-specific reducers are called by GameStore directly.
##
## All functions are static and pure.
class_name GameReducerV2
extends RefCounted


## ============================================================================
## MAIN REDUCER
## ============================================================================

## Main reducer entry point - handles global actions only
## Phase routing is done by GameStore
static func reduce(
	state: Dictionary,
	action: Dictionary,
	balance: Dictionary,
	rng  # RandomNumberGenerator or RNGManager
) -> Dictionary:
	var action_type = action.get("type", "")

	# Handle global actions
	if _is_global_action(action_type):
		return _reduce_global(state, action, balance, rng)

	# If not a global action, return state unchanged
	# (GameStore handles phase-specific routing)
	return state


## Check if action is global (not phase-specific)
static func _is_global_action(action_type: String) -> bool:
	return action_type in [
		"NEW_GAME",
		"INITIALIZE_GAME",
		"LOAD_GAME",
		"SAVE_GAME",
		"CHANGE_PHASE",
		"ADD_LOG",
		"SET_FLAG",
		"CLEAR_FLAG",
		"UPDATE_SETTINGS",
		"RESTART_GAME"
	]


## ============================================================================
## GLOBAL ACTIONS
## ============================================================================

## Handle global actions
static func _reduce_global(
	state: Dictionary,
	action: Dictionary,
	balance: Dictionary,
	rng  # RandomNumberGenerator
) -> Dictionary:
	var action_type = action.get("type", "")

	match action_type:
		"NEW_GAME", "INITIALIZE_GAME":
			return _reduce_new_game(action, balance, rng)

		"LOAD_GAME":
			return _reduce_load_game(action)

		"CHANGE_PHASE":
			return _reduce_change_phase(state, action)

		"ADD_LOG":
			return _add_log(state, action.get("message", ""), action.get("log_type", "info"))

		"SET_FLAG":
			return _set_flag(state, action.get("flag", ""), action.get("value", true))

		"CLEAR_FLAG":
			return _set_flag(state, action.get("flag", ""), false)

		"RESTART_GAME":
			return {}  # Return empty state to trigger new game

		_:
			return state


## Start a new game
static func _reduce_new_game(
	action: Dictionary,
	balance: Dictionary,
	_rng  # RandomNumberGenerator
) -> Dictionary:
	var game_id = action.get("game_id", "mars_mission")
	var difficulty = action.get("difficulty", "normal")

	# Create initial state inline (no external dependencies)
	var state = {
		"game_id": game_id,
		"difficulty": difficulty,
		"current_phase": "ship_building",
		"phase": "ship_building",
		"current_day": 1,
		"current_sol": 0,
		"total_travel_days": 0,
		"travel_day": 0,
		"meta": {
			"created_at": Time.get_datetime_string_from_system(),
			"last_saved": null,
			"play_time_seconds": 0
		}
	}

	# Apply difficulty modifiers from balance.json
	var difficulty_config = balance.get("difficulties", {}).get(difficulty, {})
	state["difficulty_modifiers"] = difficulty_config

	# Set initial budget (from balance or default)
	var base_budget = balance.get("starting_budget", 650000000)
	state["budget"] = int(base_budget * difficulty_config.get("budget_multiplier", 1.0))

	# Set launch window (from balance or default)
	state["launch_window_day"] = balance.get("optimal_launch_day", 75)

	# Initialize ship structure
	state["ship"] = {
		"components": {},
		"selected_engine": null,
		"total_mass": 0.0,
		"power_capacity": 0.0,
		"power_draw": 0.0,
		"cargo_capacity": 0.0,
		"cargo_used": 0.0,
		"average_quality": 0.0,
		"grid_bounds": {
			"min_q": -7,
			"max_q": 7,
			"min_r": -5,
			"max_r": 5
		}
	}

	# Initialize resources (default capacities from balance)
	var resource_caps = balance.get("resource_capacities", {})
	state["resources"] = {
		"food": {"current": 0, "max": resource_caps.get("food", 10000)},
		"water": {"current": 0, "max": resource_caps.get("water", 10000)},
		"oxygen": {"current": 0, "max": resource_caps.get("oxygen", 5000)},
		"fuel": {"current": 0, "max": resource_caps.get("fuel", 50000)},
		"spare_parts": {"current": 0, "max": resource_caps.get("spare_parts", 20)},
		"medical_supplies": {"current": 0, "max": resource_caps.get("medical_supplies", 10)}
	}

	# Initialize empty arrays/dicts
	state["crew"] = []
	state["event_log"] = []
	state["mission_log"] = []
	state["flags"] = {}
	state["event_cooldowns"] = {}
	state["event_counts"] = {}

	# Set phase to ship_building
	state["current_phase"] = "ship_building"
	state["phase"] = "ship_building"

	state = _add_log(state, "Mission initialized. Construction begins on Luna Base.", "info")

	return state


## Load a saved game
static func _reduce_load_game(action: Dictionary) -> Dictionary:
	var save_data = action.get("save_data", {})

	if save_data.is_empty():
		return {}

	# Validate save data
	if not save_data.has("phase") or not save_data.has("current_day"):
		return {}

	return save_data


## Change game phase
static func _reduce_change_phase(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_phase = action.get("phase", "")

	if new_phase.is_empty():
		return state

	var new_state = state.duplicate(true)
	new_state["phase"] = new_phase

	new_state = _add_log(new_state, "Entered %s phase" % new_phase.replace("_", " "), "info")

	return new_state


## ============================================================================
## EARTH ARRIVAL (Final Phase)
## ============================================================================

## Handle Earth arrival and reentry
static func _reduce_earth_arrival(
	state: Dictionary,
	action: Dictionary,
	balance: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var action_type = action.get("type", "")

	match action_type:
		ActionTypes.BEGIN_REENTRY:
			return _reduce_begin_reentry(state, action, balance, rng)
		ActionTypes.RESOLVE_EVENT:
			return _reduce_resolve_event(state, action, balance, rng)
		_:
			return state


## Begin atmospheric reentry
static func _reduce_begin_reentry(
	state: Dictionary,
	action: Dictionary,
	balance: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var new_state = state.duplicate(true)

	# Calculate reentry success based on ship quality
	var avg_quality = ComponentSystem.get_average_quality(new_state)

	# Heat shield check
	var heat_shield = HexGridSystem.get_component_by_id(new_state.get("ship", {}), "heat_shield")
	var heat_shield_quality = heat_shield.get("quality", 50) if not heat_shield.is_empty() else 50

	# Reentry chance
	var base_success = balance.get("reentry_base_success", 0.7)
	var quality_bonus = (avg_quality / 100.0) * 0.2
	var heat_shield_bonus = (heat_shield_quality / 100.0) * 0.1

	var success_chance = base_success + quality_bonus + heat_shield_bonus

	var reentry_roll = rng.randf()
	var success = reentry_roll < success_chance

	if success:
		new_state["phase"] = "game_over"
		new_state["game_over_reason"] = "mission_complete"

		# Calculate ending tier
		var ending = _calculate_ending_tier(new_state, balance)
		new_state["ending_tier"] = ending.tier
		new_state["ending_score"] = ending.score

		new_state = _add_log(new_state, "Reentry successful! Welcome home.", "success")
		new_state = _add_log(new_state, "Mission complete with %s ending (Score: %d)" % [ending.tier, ending.score], "success")
	else:
		# Partial success or failure
		var partial_roll = rng.randf()
		if partial_roll < 0.5:
			# Rough landing, injuries
			var crew = new_state.get("crew", [])
			for i in range(crew.size()):
				if crew[i].get("status") != GameTypes.CrewStatus.DEAD:
					crew[i]["health"] = max(10, crew[i].get("health", 100) - 30)
			new_state["crew"] = crew

			new_state["phase"] = "game_over"
			new_state["game_over_reason"] = "rough_landing"

			var ending = _calculate_ending_tier(new_state, balance)
			ending.tier = "Bronze"  # Downgrade for rough landing
			new_state["ending_tier"] = ending.tier
			new_state["ending_score"] = ending.score

			new_state = _add_log(new_state, "Rough landing! Crew survived with injuries.", "warning")
		else:
			# Catastrophic failure
			new_state["phase"] = "game_over"
			new_state["game_over_reason"] = "reentry_failure"
			new_state["ending_tier"] = "Failure"
			new_state["ending_score"] = 0

			new_state = _add_log(new_state, "Reentry failure. The mission ends in tragedy.", "error")

	return new_state


## Calculate ending tier based on mission performance
static func _calculate_ending_tier(state: Dictionary, balance: Dictionary) -> Dictionary:
	var score: int = 0

	# Surviving crew
	var living_crew = CrewSystem.get_living_crew(state)
	score += living_crew.size() * balance.get("points_per_survivor", 100)

	# Science points
	score += state.get("science_points", 0)

	# Experiments completed
	var experiments = state.get("experiments_completed", [])
	score += experiments.size() * balance.get("points_per_experiment", 50)

	# Samples collected
	var samples = state.get("samples_collected", {})
	for sample_type in samples:
		score += samples[sample_type] * balance.get("points_per_sample", 25)

	# Ship quality (bonus for well-maintained ship)
	var avg_quality = ComponentSystem.get_average_quality(state)
	score += int(avg_quality) * balance.get("points_per_quality_percent", 2)

	# Time efficiency (bonus for quick return)
	var total_days = state.get("current_day", 365)
	var expected_days = balance.get("expected_mission_days", 600)
	if total_days < expected_days:
		score += (expected_days - total_days) * balance.get("points_per_day_saved", 5)

	# Determine tier
	var tier = "Failure"
	var thresholds = balance.get("ending_thresholds", {
		"Gold": 1000,
		"Silver": 700,
		"Bronze": 400,
		"Pyrrhic": 200
	})

	if score >= thresholds.get("Gold", 1000):
		tier = "Gold"
	elif score >= thresholds.get("Silver", 700):
		tier = "Silver"
	elif score >= thresholds.get("Bronze", 400):
		tier = "Bronze"
	elif score >= thresholds.get("Pyrrhic", 200):
		tier = "Pyrrhic"

	return {"tier": tier, "score": score}


## ============================================================================
## GAME OVER
## ============================================================================

## Handle game over state
static func _reduce_game_over(
	state: Dictionary,
	action: Dictionary,
	balance: Dictionary
) -> Dictionary:
	var action_type = action.get("type", "")

	match action_type:
		ActionTypes.RESTART_GAME:
			return {}  # Return empty to trigger new game
		_:
			return state


## ============================================================================
## EVENT RESOLUTION (shared)
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
	new_state = _add_log(new_state, resolution.get("description", ""), "event")
	new_state["current_event"] = null

	return new_state


## ============================================================================
## HELPERS
## ============================================================================

## Add a log entry
static func _add_log(state: Dictionary, message: String, log_type: String = "info") -> Dictionary:
	var new_state = state.duplicate(true)
	var log = new_state.get("event_log", [])

	log.append({
		"day": state.get("current_day", 0),
		"sol": state.get("current_sol", 0),
		"message": message,
		"type": log_type,
		"timestamp": Time.get_unix_time_from_system()
	})

	new_state["event_log"] = log
	return new_state


## Set or clear a flag
static func _set_flag(state: Dictionary, flag: String, value: bool) -> Dictionary:
	var new_state = state.duplicate(true)
	var flags = new_state.get("flags", {})
	flags[flag] = value
	new_state["flags"] = flags
	return new_state
