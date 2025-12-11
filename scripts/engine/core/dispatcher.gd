## Action dispatcher - routes actions to the correct reducer.
##
## The dispatcher:
## - Determines which reducer handles an action based on game/phase
## - Invokes the reducer with state and action
## - Returns the new state
##
## Reducers are pure functions that take (state, action, game_data, rng)
## and return new state.
class_name Dispatcher
extends RefCounted

var _game_data: Dictionary = {}
var _reducers: Dictionary = {}  # game_id -> phase -> reducer instance
var _global_reducers: Array = []  # Reducers that handle all actions


func set_game_data(data: Dictionary) -> void:
	_game_data = data


## Register a reducer for a specific game and phase
func register_reducer(game_id: String, phase: String, reducer: RefCounted) -> void:
	if not _reducers.has(game_id):
		_reducers[game_id] = {}
	_reducers[game_id][phase] = reducer


## Register a reducer that handles actions for all phases
func register_global_reducer(reducer: RefCounted) -> void:
	_global_reducers.append(reducer)


## Dispatch an action and return new state
func dispatch(action: Dictionary, state: Dictionary, rng: RNGManager) -> Result:
	var action_type = action.get("type", "")

	# Get game-specific reducer
	var game_id = state.get("game_id", "mars_mission")
	var current_phase = state.get("current_phase", "ship_building")

	# Try phase-specific reducer first
	var reducer = _get_reducer(game_id, current_phase)

	if reducer and reducer.has_method("can_handle") and reducer.can_handle(action_type):
		return _invoke_reducer(reducer, state, action, rng)

	# Try game-level reducer (handles cross-phase actions)
	var game_reducer = _get_reducer(game_id, "_game")
	if game_reducer and game_reducer.has_method("can_handle") and game_reducer.can_handle(action_type):
		return _invoke_reducer(game_reducer, state, action, rng)

	# Try global reducers
	for global_reducer in _global_reducers:
		if global_reducer.has_method("can_handle") and global_reducer.can_handle(action_type):
			return _invoke_reducer(global_reducer, state, action, rng)

	# No reducer found - this might be okay for some actions
	# Return state unchanged with a warning
	push_warning("No reducer found for action: %s" % action_type)
	return Result.ok(state)


## Get reducer for game and phase
func _get_reducer(game_id: String, phase: String) -> RefCounted:
	if _reducers.has(game_id) and _reducers[game_id].has(phase):
		return _reducers[game_id][phase]
	return null


## Invoke a reducer and handle errors
func _invoke_reducer(reducer: RefCounted, state: Dictionary, action: Dictionary, rng: RNGManager) -> Result:
	if not reducer.has_method("reduce"):
		return Result.error(
			"REDUCER_NO_METHOD",
			"Reducer does not have reduce method",
			{"reducer": reducer.get_class()}
		)

	# Call the reducer - it should return a Dictionary (new state) or Result
	var result = reducer.reduce(state, action, _game_data, rng)

	# Handle both Dictionary and Result return types
	if result is Dictionary:
		return Result.ok(result)
	elif result is Result:
		return result
	else:
		return Result.error(
			"REDUCER_INVALID_RETURN",
			"Reducer returned invalid type: %s" % typeof(result),
			{"action_type": action.get("type", "unknown")}
		)


## ============================================================================
## BUILT-IN ACTION HANDLERS
## These handle core actions that work across all games
## ============================================================================

## Handle core actions that don't need game-specific reducers
func _handle_core_action(action: Dictionary, state: Dictionary, _rng: RNGManager) -> Result:
	var action_type = action.get("type", "")

	match action_type:
		ActionTypes.INITIALIZE_GAME:
			return _reduce_initialize_game(state, action)
		ActionTypes.CHANGE_PHASE:
			return _reduce_change_phase(state, action)
		ActionTypes.ADD_LOG_ENTRY:
			return _reduce_add_log_entry(state, action)
		_:
			return Result.ok(state)


static func _reduce_initialize_game(state: Dictionary, action: Dictionary) -> Result:
	var new_state = state.duplicate(true)
	new_state["initialized"] = true
	new_state["game_id"] = action.get("game_id", new_state.get("game_id", "mars_mission"))
	new_state["difficulty"] = action.get("difficulty", new_state.get("difficulty", "normal"))
	return Result.ok(new_state)


static func _reduce_change_phase(state: Dictionary, action: Dictionary) -> Result:
	var new_phase = action.get("new_phase", "")
	if new_phase.is_empty():
		return Result.error("INVALID_PHASE", "new_phase cannot be empty")

	var new_state = GameTypes.with_field(state, "current_phase", new_phase)

	# Add log entry for phase change
	var log_entry = GameTypes.create_log_entry(
		new_state.get("current_day", 1),
		new_phase,
		"Entered phase: %s" % new_phase,
		"phase_change"
	)
	new_state = GameTypes.with_field(
		new_state,
		"mission_log",
		GameTypes.with_array_append(new_state.get("mission_log", []), log_entry)
	)

	return Result.ok(new_state)


static func _reduce_add_log_entry(state: Dictionary, action: Dictionary) -> Result:
	var log_entry = GameTypes.create_log_entry(
		state.get("current_day", 1),
		state.get("current_phase", "unknown"),
		action.get("message", ""),
		action.get("entry_type", "general")
	)

	var new_state = GameTypes.with_field(
		state,
		"mission_log",
		GameTypes.with_array_append(state.get("mission_log", []), log_entry)
	)

	return Result.ok(new_state)
