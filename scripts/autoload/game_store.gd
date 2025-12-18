extends Node

## GameStore - The single source of truth for game state
##
## This autoload provides:
## 1. State management with Redux-like dispatch pattern
## 2. Signal emissions for UI reactivity
## 3. RNG management for deterministic gameplay
## 4. Backward-compatible API for existing UI code
##
## NOTE: This is an interim version that implements core logic inline
## to avoid circular dependency issues with the new engine.
## Once engine scripts are fixed, this will delegate to reducers.

# ============================================================================
# SIGNALS (for UI reactivity)
# ============================================================================

signal state_changed(new_state: Dictionary)
signal day_advanced(day: int)
signal budget_changed(budget: int)
signal phase_changed(phase)
signal component_placed(component: Dictionary, position: Vector2i)
signal component_removed(component: Dictionary, position: Vector2i)
signal crew_updated(crew: Array)
signal log_entry_added(entry: Dictionary)
signal action_dispatched(action: Dictionary)
signal error_occurred(error: Dictionary)

# ============================================================================
# STATE
# ============================================================================

var _state: Dictionary = {}
var _balance: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	_load_balance_data()

func _load_balance_data() -> void:
	var balance_path = "res://data/games/mars_odyssey_trek/balance.json"
	if FileAccess.file_exists(balance_path):
		var file = FileAccess.open(balance_path, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				_balance = json.data
			file.close()

# ============================================================================
# STATE ACCESS (backward compatible)
# ============================================================================

func get_state() -> Dictionary:
	return _state.duplicate(true)

func get_budget() -> int:
	return _state.get("budget", 0)

func get_current_day() -> int:
	return _state.get("current_day", 1)

func get_launch_window_day() -> int:
	return _state.get("launch_window_day", 75)

func get_days_until_launch() -> int:
	return get_launch_window_day() - get_current_day()

func get_phase():
	return _state.get("current_phase", _state.get("phase", "main_menu"))

func get_components() -> Array:
	var ship = _state.get("ship", {})
	var components = ship.get("components", _state.get("ship_components", []))
	if components is Dictionary:
		return components.values()
	return components if components is Array else []

func get_hex_grid() -> Dictionary:
	return _state.get("ship_hex_grid", {}).duplicate(true)

func get_crew() -> Array:
	return _state.get("crew", []).duplicate(true)

func get_engine() -> Dictionary:
	return _state.get("selected_engine", {}).duplicate(true)

func get_cargo() -> Dictionary:
	return _state.get("cargo_manifest", {}).duplicate(true)

func get_log() -> Array:
	return _state.get("event_log", _state.get("mission_log", [])).duplicate(true)

func get_readiness() -> float:
	var components = get_components()
	if components.is_empty():
		return 0.0
	var total_quality = 0.0
	for comp in components:
		if comp is Dictionary:
			total_quality += comp.get("quality", 50)
	return total_quality / max(1, components.size())

func get_launch_check() -> Dictionary:
	var issues: Array = []
	var crew = _state.get("crew", [])
	if crew.size() < 2:
		issues.append("Need at least 2 crew members")
	var engine = _state.get("selected_engine", {})
	if engine.is_empty():
		issues.append("No engine selected")
	return {
		"can_launch": issues.is_empty(),
		"issues": issues,
		"readiness": get_readiness()
	}

# ============================================================================
# DISPATCH - The only way to modify state
# ============================================================================

func dispatch(action: Dictionary) -> Dictionary:
	var action_type = action.get("type", "")
	var old_state = _state
	var new_state: Dictionary = _state

	# Route to appropriate handler
	match action_type:
		"NEW_GAME":
			new_state = _reduce_new_game(action)
		"ADVANCE_DAY":
			new_state = _reduce_advance_day(action)
		"CHANGE_PHASE":
			new_state = _reduce_change_phase(action)
		"ADD_LOG":
			new_state = _add_log(_state, action.get("message", ""), action.get("log_type", "info"))
		"PLACE_COMPONENT":
			new_state = _reduce_place_component(action)
		"REMOVE_COMPONENT":
			new_state = _reduce_remove_component(action)
		"SELECT_ENGINE":
			new_state = _reduce_select_engine(action)
		"HIRE_CREW":
			new_state = _reduce_hire_crew(action)
		"DISMISS_CREW":
			new_state = _reduce_dismiss_crew(action)
		"LOAD_CARGO":
			new_state = _reduce_load_cargo(action)
		"TEST_COMPONENT":
			new_state = _reduce_test_component(action)
		"LAUNCH":
			new_state = _reduce_launch(action)
		_:
			push_warning("Unknown action type: %s" % action_type)
			return {"ok": false, "error": {"code": "UNKNOWN_ACTION", "message": action_type}}

	# Update state if changed
	if new_state and new_state != _state:
		_state = new_state
		_emit_state_change_signals(old_state, new_state)

	action_dispatched.emit(action)
	return {"ok": true, "value": new_state}

func _emit_state_change_signals(old_state: Dictionary, new_state: Dictionary) -> void:
	if old_state.get("current_day") != new_state.get("current_day"):
		day_advanced.emit(new_state.get("current_day", 1))
	if old_state.get("budget") != new_state.get("budget"):
		budget_changed.emit(new_state.get("budget", 0))
	if old_state.get("current_phase") != new_state.get("current_phase"):
		phase_changed.emit(new_state.get("current_phase"))
	if old_state.get("crew") != new_state.get("crew"):
		crew_updated.emit(new_state.get("crew", []))
	var old_log = old_state.get("event_log", old_state.get("mission_log", []))
	var new_log = new_state.get("event_log", new_state.get("mission_log", []))
	if new_log.size() > old_log.size():
		log_entry_added.emit(new_log[-1])
	state_changed.emit(new_state)

# ============================================================================
# REDUCER IMPLEMENTATIONS (inline for now)
# ============================================================================

func _reduce_new_game(action: Dictionary) -> Dictionary:
	var game_id = action.get("game_id", "mot")
	var difficulty = action.get("difficulty", "normal")
	var difficulty_config = _balance.get("difficulties", {}).get(difficulty, {})
	var base_budget = _balance.get("starting_budget", 650000000)

	return {
		"game_id": game_id,
		"difficulty": difficulty,
		"current_phase": "ship_building",
		"phase": "ship_building",
		"current_day": 1,
		"current_sol": 0,
		"budget": int(base_budget * difficulty_config.get("budget_multiplier", 1.0)),
		"launch_window_day": _balance.get("optimal_launch_day", 75),
		"ship": {
			"components": {},
			"selected_engine": null,
		},
		"selected_engine": {},
		"crew": [],
		"resources": {
			"food": {"current": 0, "max": 10000},
			"water": {"current": 0, "max": 10000},
			"oxygen": {"current": 0, "max": 5000},
		},
		"event_log": [],
		"mission_log": [],
		"flags": {},
		"difficulty_modifiers": difficulty_config
	}

func _reduce_advance_day(action: Dictionary) -> Dictionary:
	var days = action.get("days", 1)
	var new_state = _state.duplicate(true)
	new_state["current_day"] = _state.get("current_day", 1) + days
	return new_state

func _reduce_change_phase(action: Dictionary) -> Dictionary:
	var new_state = _state.duplicate(true)
	new_state["current_phase"] = action.get("phase", "ship_building")
	new_state["phase"] = action.get("phase", "ship_building")
	return new_state

func _add_log(state: Dictionary, message: String, log_type: String = "info") -> Dictionary:
	var new_state = state.duplicate(true)
	var log = new_state.get("event_log", [])
	log.append({
		"day": state.get("current_day", 1),
		"message": message,
		"type": log_type,
		"timestamp": Time.get_unix_time_from_system()
	})
	new_state["event_log"] = log
	return new_state

func _reduce_place_component(action: Dictionary) -> Dictionary:
	var component = action.get("component", {})
	var pos = action.get("position", {})
	var q = pos.get("q", 0)
	var r = pos.get("r", 0)
	var key = "%d,%d" % [q, r]

	var new_state = _state.duplicate(true)
	var ship = new_state.get("ship", {"components": {}})
	var components = ship.get("components", {})

	# Create component instance
	var comp_instance = {
		"id": component.get("id", "unknown"),
		"name": component.get("name", "Unknown"),
		"category": component.get("category", "generic"),
		"quality": 50,
		"is_built": false,
		"is_tested": false,
		"position": {"q": q, "r": r}
	}

	components[key] = comp_instance
	ship["components"] = components
	new_state["ship"] = ship

	# Deduct cost
	var cost = component.get("base_cost", component.get("cost", 0))
	new_state["budget"] = new_state.get("budget", 0) - cost

	return _add_log(new_state, "Started construction of %s" % component.get("name", "component"))

func _reduce_remove_component(action: Dictionary) -> Dictionary:
	var pos = action.get("position", {})
	var q = pos.get("q", 0)
	var r = pos.get("r", 0)
	var key = "%d,%d" % [q, r]

	var new_state = _state.duplicate(true)
	var ship = new_state.get("ship", {"components": {}})
	var components = ship.get("components", {})

	if components.has(key):
		var removed = components[key]
		components.erase(key)
		ship["components"] = components
		new_state["ship"] = ship
		return _add_log(new_state, "Removed %s" % removed.get("name", "component"))

	return new_state

func _reduce_select_engine(action: Dictionary) -> Dictionary:
	var engine = action.get("engine", {})
	var new_state = _state.duplicate(true)
	new_state["selected_engine"] = engine
	return _add_log(new_state, "Selected %s as main propulsion" % engine.get("name", "engine"))

func _reduce_hire_crew(action: Dictionary) -> Dictionary:
	var crew_data = action.get("crew_member", {})
	var new_state = _state.duplicate(true)
	var crew = new_state.get("crew", [])

	if crew.size() >= 6:
		return new_state

	var new_member = {
		"id": crew_data.get("id", "crew_%d" % crew.size()),
		"name": crew_data.get("name", "Unknown"),
		"role": crew_data.get("role", "generic"),
		"health": 100,
		"morale": 75,
		"skills": crew_data.get("skills", {})
	}

	crew.append(new_member)
	new_state["crew"] = crew
	return _add_log(new_state, "%s joined the crew" % new_member.get("name"))

func _reduce_dismiss_crew(action: Dictionary) -> Dictionary:
	var crew_id = action.get("crew_id", "")
	var new_state = _state.duplicate(true)
	var crew = new_state.get("crew", [])
	var new_crew: Array = []
	var removed_name = ""

	for member in crew:
		if member.get("id") == crew_id:
			removed_name = member.get("name", "Unknown")
		else:
			new_crew.append(member)

	new_state["crew"] = new_crew
	if not removed_name.is_empty():
		return _add_log(new_state, "%s left the crew" % removed_name)
	return new_state

func _reduce_load_cargo(action: Dictionary) -> Dictionary:
	var resource_id = action.get("resource_id", "")
	var amount = action.get("amount", 0)
	var new_state = _state.duplicate(true)
	var resources = new_state.get("resources", {})

	if resources.has(resource_id):
		resources[resource_id]["current"] = resources[resource_id].get("current", 0) + amount
	else:
		resources[resource_id] = {"current": amount, "max": 10000}

	new_state["resources"] = resources
	return new_state

func _reduce_test_component(action: Dictionary) -> Dictionary:
	var pos = action.get("position", {})
	var q = pos.get("q", 0)
	var r = pos.get("r", 0)
	var key = "%d,%d" % [q, r]
	var random_value = action.get("random_value", _rng.randf())

	var new_state = _state.duplicate(true)
	var ship = new_state.get("ship", {"components": {}})
	var components = ship.get("components", {})

	if components.has(key):
		var comp = components[key]
		comp["is_tested"] = true
		# Quality improvement based on random value
		var improvement = int(random_value * 20)
		comp["quality"] = mini(95, comp.get("quality", 50) + improvement)
		components[key] = comp
		ship["components"] = components
		new_state["ship"] = ship
		return _add_log(new_state, "Tested %s - quality now %d%%" % [comp.get("name"), comp["quality"]])

	return new_state

func _reduce_launch(action: Dictionary) -> Dictionary:
	var new_state = _state.duplicate(true)
	new_state["current_phase"] = "travel_to_mars"
	new_state["phase"] = "travel_to_mars"
	new_state["travel_day"] = 0
	new_state["travel_total_days"] = 180
	return _add_log(new_state, "Launch successful! Beginning journey to Mars.")

# ============================================================================
# HIGH-LEVEL ACTIONS (convenience methods)
# ============================================================================

func start_new_game() -> void:
	_rng.seed = int(Time.get_unix_time_from_system())
	var result = dispatch({
		"type": "NEW_GAME",
		"game_id": "mot",
		"difficulty": "normal",
		"seed": _rng.seed
	})
	if result.get("ok", false):
		phase_changed.emit("ship_building")

func advance_day(days: int = 1) -> void:
	dispatch({"type": "ADVANCE_DAY", "days": days})
	if AudioManager:
		AudioManager.play_day_advance()

func place_component(component: Dictionary, position: Vector2i) -> bool:
	var result = dispatch({
		"type": "PLACE_COMPONENT",
		"component": component,
		"position": {"q": position.x, "r": position.y}
	})
	return result.get("ok", false)

func remove_component(position: Vector2i) -> Dictionary:
	var key = "%d,%d" % [position.x, position.y]
	var ship = _state.get("ship", {})
	var components = ship.get("components", {})
	var component = components.get(key, {})
	if component.is_empty():
		return {}
	dispatch({"type": "REMOVE_COMPONENT", "position": {"q": position.x, "r": position.y}})
	return component

func test_component(position: Vector2i) -> bool:
	var result = dispatch({
		"type": "TEST_COMPONENT",
		"position": {"q": position.x, "r": position.y},
		"random_value": _rng.randf()
	})
	return result.get("ok", false)

func select_engine(engine: Dictionary) -> void:
	dispatch({"type": "SELECT_ENGINE", "engine": engine})

func add_crew_member(crew: Dictionary) -> bool:
	if _state.get("crew", []).size() >= 4:
		return false
	var result = dispatch({"type": "HIRE_CREW", "crew_member": crew})
	return result.get("ok", false)

func remove_crew_member(crew_id: String) -> void:
	dispatch({"type": "DISMISS_CREW", "crew_id": crew_id})

func update_cargo(key: String, value) -> void:
	dispatch({
		"type": "LOAD_CARGO",
		"resource_id": key,
		"amount": value if value is int or value is float else (1 if value else 0)
	})

func add_log(message: String, event_type: String = "info") -> void:
	dispatch({"type": "ADD_LOG", "message": message, "log_type": event_type})
	if AudioManager:
		match event_type:
			"error": AudioManager.play_error()
			"success": AudioManager.play_success()

func launch_ship() -> bool:
	var check = get_launch_check()
	if not check.can_launch:
		return false
	var result = dispatch({"type": "LAUNCH"})
	return result.get("ok", false)

func change_phase(phase) -> void:
	var phase_str = phase if phase is String else _phase_enum_to_string(phase)
	dispatch({"type": "CHANGE_PHASE", "phase": phase_str})

# ============================================================================
# TRAVEL PHASE ACTIONS
# ============================================================================

func start_travel() -> void:
	dispatch({"type": "CHANGE_PHASE", "phase": "travel_to_mars"})

func advance_travel_day() -> void:
	var new_state = _state.duplicate(true)
	new_state["travel_day"] = _state.get("travel_day", 0) + 1
	_state = new_state
	state_changed.emit(_state)

func assign_crew_activity(crew_id: String, activity_id: String) -> void:
	pass  # To be implemented

func get_travel_progress() -> Dictionary:
	return {
		"current_day": _state.get("travel_day", 0),
		"total_days": _state.get("travel_total_days", 180),
		"progress": float(_state.get("travel_day", 0)) / max(1, _state.get("travel_total_days", 180)),
		"days_remaining": _state.get("travel_total_days", 180) - _state.get("travel_day", 0)
	}

func get_available_activities() -> Array:
	return [
		{"id": "rest", "name": "Rest", "hours": 8},
		{"id": "exercise", "name": "Exercise", "hours": 2},
		{"id": "repair", "name": "Repair", "hours": 4},
		{"id": "medical", "name": "Medical", "hours": 4},
		{"id": "social", "name": "Socialize", "hours": 2}
	]

# ============================================================================
# MARS BASE ACTIONS
# ============================================================================

func start_mars_operations() -> void:
	dispatch({"type": "CHANGE_PHASE", "phase": "mars_base"})

func conduct_experiment(experiment_id: String, crew_id: String) -> void:
	pass

func collect_samples(sample_type: String, amount: int) -> void:
	pass

func get_mars_sol() -> int:
	return _state.get("mars_sol", _state.get("current_sol", 0))

func advance_mars_sol() -> void:
	var new_state = _state.duplicate(true)
	new_state["current_sol"] = _state.get("current_sol", 0) + 1
	_state = new_state
	state_changed.emit(_state)

func get_experiments_completed() -> Array:
	return _state.get("experiments_completed", []).duplicate()

func get_samples_collected() -> Dictionary:
	return _state.get("samples_collected", {}).duplicate()

func get_supplies() -> Dictionary:
	return _state.get("supplies", _state.get("resources", {})).duplicate()

func set_supplies(supplies: Dictionary) -> void:
	var new_state = _state.duplicate(true)
	new_state["resources"] = supplies
	_state = new_state
	state_changed.emit(_state)

func set_supply_levels(food_mult: float, water_mult: float, oxygen_mult: float, spare_parts: int, medical_kits: int) -> void:
	_state["supply_multipliers"] = {
		"food": food_mult,
		"water": water_mult,
		"oxygen": oxygen_mult,
		"spare_parts": spare_parts,
		"medical_kits": medical_kits
	}
	state_changed.emit(_state)

func get_crew_deaths() -> int:
	return _state.get("crew_deaths", 0)

# ============================================================================
# PERSISTENCE
# ============================================================================

func save_game(slot: int = 0) -> bool:
	var save_path = "user://save_%d.json" % slot
	var save_data = {
		"state": _state,
		"rng_state": _rng.state,
		"version": "2.0.0",
		"saved_at": Time.get_datetime_string_from_system()
	}
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()
		return true
	return false

func load_game(slot: int = 0) -> bool:
	var save_path = "user://save_%d.json" % slot
	if not FileAccess.file_exists(save_path):
		return false
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var save_data = json.data
			_state = save_data.get("state", {})
			if save_data.has("rng_state"):
				_rng.state = save_data.rng_state
			state_changed.emit(_state)
			file.close()
			return true
		file.close()
	return false

# ============================================================================
# HELPERS
# ============================================================================

func _phase_enum_to_string(phase_enum) -> String:
	match phase_enum:
		0: return "main_menu"
		1: return "ship_building"
		2: return "travel_to_mars"
		3: return "mars_base"
		4: return "travel_to_earth"
		5: return "game_over"
		_: return "main_menu"

func dispatch_legacy(action: Dictionary) -> void:
	var type_map = {
		0: "NEW_GAME", 1: "ADVANCE_DAY", 2: "CHANGE_PHASE",
		3: "PLACE_COMPONENT", 4: "REMOVE_COMPONENT",
		5: "TEST_COMPONENT", 6: "TEST_COMPONENT",
		7: "SELECT_ENGINE", 8: "HIRE_CREW", 9: "DISMISS_CREW"
	}
	var new_action = action.duplicate()
	new_action["type"] = type_map.get(action.get("type", 0), "UNKNOWN")
	dispatch(new_action)
