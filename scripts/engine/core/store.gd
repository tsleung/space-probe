## Central state container for the game.
## This is the single source of truth - all game state lives here.
##
## Responsibilities:
## - Hold current game state
## - Validate and dispatch actions
## - Emit signals on state changes
## - Manage RNG
## - Handle persistence
##
## This class has side effects (signals, RNG, I/O).
## All game LOGIC is in pure reducers.
class_name Store
extends RefCounted

## Emitted when state changes
signal state_changed(old_state: Dictionary, new_state: Dictionary)

## Emitted after every action dispatch (for debugging/logging)
signal action_dispatched(action: Dictionary)

## Emitted when an error occurs during dispatch
signal error_occurred(error: Dictionary)

## Emitted when game is saved
signal game_saved(path: String)

## Emitted when game is loaded
signal game_loaded(path: String)


var _state: Dictionary = {}
var _rng: RNGManager
var _dispatcher: Dispatcher
var _validator: ActionValidator
var _persistence: Persistence
var _game_data: Dictionary = {}  # Loaded game definition
var _middleware: Array[Callable] = []


func _init():
	_rng = RNGManager.new()
	_dispatcher = Dispatcher.new()
	_validator = ActionValidator.new()
	_persistence = Persistence.new()


## ============================================================================
## STATE ACCESS
## ============================================================================

## Get a deep copy of current state (prevents external mutation)
func get_state() -> Dictionary:
	return _state.duplicate(true)


## Get state without copying (for read-only access in UI)
## WARNING: Do not modify the returned dictionary!
func get_state_readonly() -> Dictionary:
	return _state


## Get a specific field from state
func get_field(path: String, default = null):
	var parts = path.split(".")
	var current = _state

	for part in parts:
		if current is Dictionary and current.has(part):
			current = current[part]
		elif current is Array and part.is_valid_int():
			var index = int(part)
			if index >= 0 and index < current.size():
				current = current[index]
			else:
				return default
		else:
			return default

	return current


## ============================================================================
## GAME DATA ACCESS
## ============================================================================

## Get loaded game data (components, events, balance, etc.)
func get_game_data() -> Dictionary:
	return _game_data


## Set game data (called by GameLoader)
func set_game_data(data: Dictionary) -> void:
	_game_data = data
	_dispatcher.set_game_data(data)
	_validator.set_game_data(data)


## ============================================================================
## RNG ACCESS
## ============================================================================

## Get RNG manager (for generating random values before dispatch)
func get_rng() -> RNGManager:
	return _rng


## Get RNG seed (for save/load)
func get_rng_seed() -> int:
	return _rng.get_seed()


## Set RNG seed (for deterministic replay)
func set_rng_seed(seed: int) -> void:
	_rng.reset_with_seed(seed)


## ============================================================================
## DISPATCH
## ============================================================================

## Dispatch an action to update state
## Returns Result - check is_ok() before assuming success
func dispatch(action: Dictionary) -> Result:
	# Validate action structure
	var validation = _validator.validate(action, _state)
	if not validation.is_ok():
		var error = validation.get_error()
		error_occurred.emit(error)
		return validation

	# Run middleware (logging, etc.)
	for middleware in _middleware:
		action = middleware.call(action, _state)

	# Get old state for comparison
	var old_state = _state

	# Dispatch to reducer
	var reduce_result = _dispatcher.dispatch(action, _state, _rng)
	if not reduce_result.is_ok():
		var error = reduce_result.get_error()
		error_occurred.emit(error)
		return reduce_result

	# Update state
	_state = reduce_result.get_value()

	# Record action in history (optional, for debugging)
	if _state.has("action_history"):
		_state.action_history.append({
			"action": action,
			"timestamp": Time.get_ticks_msec()
		})

	# Emit signals
	action_dispatched.emit(action)
	state_changed.emit(old_state, _state)

	return Result.ok(_state)


## Dispatch action with automatic random values
## Use this for actions that need randomness
func dispatch_with_random(action: Dictionary, random_count: int = 5) -> Result:
	action["random_values"] = _rng.randf_array(random_count)
	return dispatch(action)


## Dispatch multiple actions in sequence
## Stops on first error
func dispatch_batch(actions: Array[Dictionary]) -> Result:
	for action in actions:
		var result = dispatch(action)
		if not result.is_ok():
			return result
	return Result.ok(_state)


## ============================================================================
## INITIALIZATION
## ============================================================================

## Initialize new game
func initialize(game_id: String, difficulty: String = "normal", seed: int = -1) -> Result:
	# Set up RNG
	if seed != -1:
		_rng.reset_with_seed(seed)
	else:
		_rng = RNGManager.new()

	# Create initial state
	_state = GameTypes.create_game_state(game_id, difficulty)
	_state["rng_seed"] = _rng.get_seed()

	# Dispatch initialization action
	return dispatch(ActionTypes.initialize_game(game_id, difficulty, _rng.get_seed()))


## Reset to initial state
func reset() -> void:
	_state = {}
	_rng = RNGManager.new()


## ============================================================================
## PERSISTENCE
## ============================================================================

## Save game to file
func save_game(path: String) -> Result:
	var save_data = {
		"state": _state,
		"rng": _rng.get_state(),
		"game_id": _state.get("game_id", "unknown"),
		"version": "1.0.0",
		"saved_at": Time.get_datetime_string_from_system()
	}

	var result = _persistence.save(path, save_data)
	if result.is_ok():
		_state = GameTypes.with_nested_field(_state, ["meta", "last_saved"], Time.get_datetime_string_from_system())
		game_saved.emit(path)

	return result


## Load game from file
func load_game(path: String) -> Result:
	var result = _persistence.load_file(path)
	if not result.is_ok():
		return result

	var save_data = result.get_value()

	# Restore state
	_state = save_data.get("state", {})

	# Restore RNG
	if save_data.has("rng"):
		_rng.set_state(save_data.rng)

	game_loaded.emit(path)
	state_changed.emit({}, _state)

	return Result.ok(_state)


## ============================================================================
## MIDDLEWARE
## ============================================================================

## Add middleware function
## Middleware receives (action, state) and returns modified action
func add_middleware(middleware: Callable) -> void:
	_middleware.append(middleware)


## Remove middleware function
func remove_middleware(middleware: Callable) -> void:
	_middleware.erase(middleware)


## ============================================================================
## DEBUG / DEVELOPMENT
## ============================================================================

## Get action history (if enabled)
func get_action_history() -> Array:
	return _state.get("action_history", [])


## Replay actions from history (for debugging)
func replay_actions(actions: Array) -> Result:
	reset()
	for action_record in actions:
		var action = action_record.get("action", action_record)
		var result = dispatch(action)
		if not result.is_ok():
			return result
	return Result.ok(_state)


## Force state (for testing only!)
func _force_state(new_state: Dictionary) -> void:
	var old_state = _state
	_state = new_state
	state_changed.emit(old_state, _state)
