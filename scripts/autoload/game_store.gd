extends Node

## Game Store - The ONLY place with side effects
## Wraps the pure reducer and provides:
## 1. Signal emissions for UI reactivity
## 2. Random number generation
## 3. Persistence (save/load)
##
## Think of this like a Redux store - it holds state and dispatches actions

# ============================================================================
# SIGNALS (for UI reactivity)
# ============================================================================

signal state_changed(new_state: Dictionary)
signal day_advanced(day: int)
signal budget_changed(budget: int)
signal phase_changed(phase: GameTypes.GamePhase)
signal component_placed(component: Dictionary, position: Vector2i)
signal component_removed(component: Dictionary, position: Vector2i)
signal crew_updated(crew: Array)
signal log_entry_added(entry: Dictionary)

# ============================================================================
# STATE
# ============================================================================

var _state: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready():
	_state = GameTypes.create_game_state()

## Get current state (read-only copy)
func get_state() -> Dictionary:
	return _state.duplicate(true)

## Get specific state slice
func get_budget() -> int:
	return _state.budget

func get_current_day() -> int:
	return _state.current_day

func get_launch_window_day() -> int:
	return _state.launch_window_day

func get_days_until_launch() -> int:
	return _state.launch_window_day - _state.current_day

func get_phase() -> GameTypes.GamePhase:
	return _state.current_phase

func get_components() -> Array:
	return _state.ship_components.duplicate(true)

func get_hex_grid() -> Dictionary:
	return _state.ship_hex_grid.duplicate(true)

func get_crew() -> Array:
	return _state.crew.duplicate(true)

func get_engine() -> Dictionary:
	return _state.selected_engine.duplicate(true) if _state.selected_engine else {}

func get_cargo() -> Dictionary:
	return _state.cargo_manifest.duplicate(true)

func get_log() -> Array:
	return _state.mission_log.duplicate(true)

func get_readiness() -> float:
	return ShipLogic.calc_readiness(_state.ship_components)

func get_launch_check() -> Dictionary:
	return ShipLogic.check_launch_readiness(
		_state.ship_components,
		_state.selected_engine if _state.selected_engine else {},
		_state.crew,
		_state.cargo_manifest
	)

# ============================================================================
# DISPATCH (the only way to modify state)
# ============================================================================

func dispatch(action: Dictionary) -> void:
	var old_state = _state
	_state = GameReducer.reduce(_state, action)

	# Emit appropriate signals based on what changed
	_emit_change_signals(old_state, _state, action)
	state_changed.emit(_state)

## Helper to dispatch with auto-generated random values
func dispatch_with_random(action: Dictionary) -> void:
	# Inject random values where needed
	if action.type == GameReducer.ActionType.ADVANCE_DAY:
		var random_values: Array = []
		for i in range(_state.crew.size() + 10):  # Extra for events
			random_values.append(_rng.randf())
		action["random_values"] = random_values
	elif action.type == GameReducer.ActionType.COMPLETE_COMPONENT_TEST:
		action["random_value"] = _rng.randf()

	dispatch(action)

# ============================================================================
# HIGH-LEVEL ACTIONS (convenience methods that dispatch)
# ============================================================================

func start_new_game() -> void:
	_rng.seed = int(Time.get_unix_time_from_system())
	dispatch(GameReducer.action_start_new_game(_rng.seed))
	_initialize_hex_grid()

func _initialize_hex_grid() -> void:
	# Initialize empty hex grid positions
	var grid: Dictionary = {}
	for q in range(-7, 8):
		for r in range(-5, 6):
			grid[Vector2i(q, r)] = {}
	_state = GameTypes.with_field(_state, "ship_hex_grid", grid)

func advance_day(days: int = 1) -> void:
	dispatch_with_random(GameReducer.action_advance_day(days))

	# Check for random events
	_check_random_events()

func place_component(component: Dictionary, position: Vector2i) -> bool:
	var old_components = _state.ship_components.size()
	dispatch(GameReducer.action_place_component(component, position))
	return _state.ship_components.size() > old_components

func remove_component(position: Vector2i) -> Dictionary:
	var component = ShipLogic.get_component_at(_state.ship_hex_grid, position)
	if component.is_empty():
		return {}
	dispatch(GameReducer.action_remove_component(position))
	return component

func test_component(position: Vector2i) -> bool:
	var component = ShipLogic.get_component_at(_state.ship_hex_grid, position)
	if component.is_empty() or not component.is_built:
		return false

	dispatch(GameReducer.action_start_test(position))
	dispatch_with_random(GameReducer.action_complete_test(position, 0))

	# Advance time for testing
	var test_days = component.test_days_per_cycle
	for i in range(test_days):
		advance_day(1)

	return true

func select_engine(engine: Dictionary) -> void:
	dispatch(GameReducer.action_select_engine(engine))

func add_crew_member(crew: Dictionary) -> bool:
	if _state.crew.size() >= 4:
		return false
	dispatch(GameReducer.action_add_crew(crew))
	return true

func remove_crew_member(crew_id: String) -> void:
	dispatch(GameReducer.action_remove_crew(crew_id))

func update_cargo(key: String, value) -> void:
	dispatch(GameReducer.action_update_cargo(key, value))

func add_log(message: String, event_type: String = "info") -> void:
	dispatch(GameReducer.action_add_log(message, event_type))

func launch_ship() -> bool:
	var check = get_launch_check()
	if not check.can_launch:
		return false

	dispatch(GameReducer.action_change_phase(GameTypes.GamePhase.TRAVEL_TO_MARS))
	return true

func change_phase(phase: GameTypes.GamePhase) -> void:
	dispatch(GameReducer.action_change_phase(phase))

# ============================================================================
# TRAVEL PHASE ACTIONS
# ============================================================================

func start_travel() -> void:
	var engine = get_engine()
	var ship_mass = ShipLogic.calc_total_mass(_state.ship_components)
	var days_past = maxi(0, _state.current_day - _state.launch_window_day)
	var travel_days = TravelLogic.calc_travel_days(engine, ship_mass, days_past)

	dispatch(GameReducer.action_start_travel(travel_days))

func advance_travel_day() -> void:
	var random_values: Array = []
	for i in range(_state.crew.size() + 10):
		random_values.append(_rng.randf())

	dispatch(GameReducer.action_advance_travel_day(random_values))

func assign_crew_activity(crew_id: String, activity_id: String) -> void:
	dispatch(GameReducer.action_assign_activity(crew_id, activity_id))

func get_travel_progress() -> Dictionary:
	var travel_day = _state.get("travel_day", 0)
	var travel_total = _state.get("travel_total_days", 180)
	return TravelLogic.calc_distance_progress(travel_day, travel_total)

func get_available_activities() -> Array:
	return TravelLogic.get_available_activities()

# ============================================================================
# MARS BASE ACTIONS
# ============================================================================

func start_mars_operations() -> void:
	dispatch(GameReducer.action_start_mars_operations())

func conduct_experiment(experiment_id: String, crew_id: String) -> void:
	dispatch(GameReducer.action_conduct_experiment(experiment_id, crew_id, _rng.randf()))

func get_mars_sol() -> int:
	return _state.get("mars_sol", 0)

func get_experiments_completed() -> Array:
	return _state.get("experiments_completed", []).duplicate()

func get_samples_collected() -> Dictionary:
	return _state.get("samples_collected", {}).duplicate()

# ============================================================================
# RANDOM EVENT CHECKING (side effect: uses RNG)
# ============================================================================

func _check_random_events() -> void:
	if _state.current_phase == GameTypes.GamePhase.SHIP_BUILDING:
		var event_result = EventLogic.check_delay_events(
			_state,
			_rng.randf(),
			_rng.randf(),
			_rng.randf()
		)
		if event_result.should_trigger and event_result.event:
			dispatch(GameReducer.action_apply_event(event_result.event))

	elif _state.current_phase == GameTypes.GamePhase.TRAVEL_TO_MARS:
		var event_result = EventLogic.generate_travel_event(
			_state,
			_rng.randf(),
			_rng.randf(),
			_rng.randf()
		)
		if event_result.should_trigger and event_result.event:
			dispatch(GameReducer.action_apply_event(event_result.event))

# ============================================================================
# SIGNAL EMISSION HELPERS
# ============================================================================

func _emit_change_signals(old_state: Dictionary, new_state: Dictionary, action: Dictionary) -> void:
	if old_state.current_day != new_state.current_day:
		day_advanced.emit(new_state.current_day)

	if old_state.budget != new_state.budget:
		budget_changed.emit(new_state.budget)

	if old_state.current_phase != new_state.current_phase:
		phase_changed.emit(new_state.current_phase)

	if old_state.crew != new_state.crew:
		crew_updated.emit(new_state.crew)

	if new_state.mission_log.size() > old_state.mission_log.size():
		var new_entry = new_state.mission_log[-1]
		log_entry_added.emit(new_entry)

	# Component-specific signals
	if action.type == GameReducer.ActionType.PLACE_COMPONENT:
		var placed = ShipLogic.get_component_at(new_state.ship_hex_grid, action.position)
		if not placed.is_empty():
			component_placed.emit(placed, action.position)

	if action.type == GameReducer.ActionType.REMOVE_COMPONENT:
		var removed = ShipLogic.get_component_at(old_state.ship_hex_grid, action.position)
		if not removed.is_empty():
			component_removed.emit(removed, action.position)

# ============================================================================
# PERSISTENCE (side effects: file I/O)
# ============================================================================

func save_game(slot: int = 0) -> bool:
	var save_path = "user://save_%d.json" % slot
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		return false

	# Convert state to JSON-safe format
	var save_data = _state_to_json(_state)
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	return true

func load_game(slot: int = 0) -> bool:
	var save_path = "user://save_%d.json" % slot
	if not FileAccess.file_exists(save_path):
		return false

	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return false

	var json = JSON.new()
	var error = json.parse(file.get_as_text())
	file.close()

	if error != OK:
		return false

	_state = _json_to_state(json.data)
	state_changed.emit(_state)
	return true

func _state_to_json(state: Dictionary) -> Dictionary:
	# Convert Vector2i keys to strings for JSON
	var json_state = state.duplicate(true)

	# Convert hex_grid Vector2i keys
	var hex_grid_json = {}
	for key in state.ship_hex_grid.keys():
		var key_str = "%d,%d" % [key.x, key.y]
		var value = state.ship_hex_grid[key]
		if not value.is_empty():
			if value.has("hex_position"):
				var pos = value.hex_position
				value = value.duplicate(true)
				value["hex_position"] = "%d,%d" % [pos.x, pos.y]
		hex_grid_json[key_str] = value
	json_state["ship_hex_grid"] = hex_grid_json

	# Convert component hex_positions
	var components_json = []
	for comp in state.ship_components:
		var comp_json = comp.duplicate(true)
		if comp.has("hex_position"):
			comp_json["hex_position"] = "%d,%d" % [comp.hex_position.x, comp.hex_position.y]
		components_json.append(comp_json)
	json_state["ship_components"] = components_json

	return json_state

func _json_to_state(json_data: Dictionary) -> Dictionary:
	var state = json_data.duplicate(true)

	# Convert hex_grid string keys back to Vector2i
	var hex_grid = {}
	for key_str in json_data.ship_hex_grid.keys():
		var parts = key_str.split(",")
		var key = Vector2i(int(parts[0]), int(parts[1]))
		var value = json_data.ship_hex_grid[key_str]
		if not value.is_empty() and value.has("hex_position"):
			var pos_parts = value.hex_position.split(",")
			value["hex_position"] = Vector2i(int(pos_parts[0]), int(pos_parts[1]))
		hex_grid[key] = value
	state["ship_hex_grid"] = hex_grid

	# Convert component hex_positions back
	var components = []
	for comp in json_data.ship_components:
		if comp.has("hex_position") and comp.hex_position is String:
			var parts = comp.hex_position.split(",")
			comp["hex_position"] = Vector2i(int(parts[0]), int(parts[1]))
		components.append(comp)
	state["ship_components"] = components

	return state
