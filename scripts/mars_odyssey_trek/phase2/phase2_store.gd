extends Node
class_name Phase2Store

## Phase 2: Travel to Mars - Store
## The ONLY place with side effects for Phase 2 simulation
## Wraps the pure reducer and provides:
## 1. Signal emissions for UI reactivity
## 2. Random number generation
## 3. Event selection and triggering
## 4. Persistence (save/load)
##
## Think of this like a Redux store - it holds state and dispatches actions

const Phase2Types = preload("res://scripts/mars_odyssey_trek/phase2/phase2_types.gd")
const Phase2Reducer = preload("res://scripts/mars_odyssey_trek/phase2/phase2_reducer.gd")

# ============================================================================
# SIGNALS (for UI reactivity)
# ============================================================================

signal state_changed(new_state: Dictionary)
signal day_advanced(day: int)
signal speed_changed(speed: int)
signal resources_changed(resources: Dictionary)
signal crew_changed(crew: Array)
signal container_blocked(container: Dictionary)
signal container_restored(container: Dictionary)
signal repair_started(container_id: String, days: int)
signal repair_completed(container_id: String)
signal event_triggered(event: Dictionary)
signal event_resolved(choice_index: int)
signal mars_visible()
signal arrival()
signal log_added(entry: Dictionary)
signal game_over(reason: String)

# ============================================================================
# STATE
# ============================================================================

var _state: Dictionary = Phase2Types.create_phase2_state()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Standard event pool (can be extended with data-driven events)
var _event_pool: Array = []

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init():
	if _state.is_empty():
		_state = Phase2Types.create_phase2_state()
	_setup_event_pool()

func _ready():
	pass  # State already initialized in _init

func _setup_event_pool() -> void:
	## Set up the standard event pool
	_event_pool = [
		Phase2Types.create_event({
			"type": Phase2Types.EventType.SOLAR_FLARE,
			"title": "SOLAR FLARE DETECTED",
			"description": "A solar flare will reach the ship in 6 hours. Radiation levels will spike.",
			"options": [
				Phase2Types.create_event_option({
					"label": "Shelter in cargo hold",
					"effect": "morale_loss",
					"effect_value": 5,
					"description": "Lose productivity but stay safe."
				}),
				Phase2Types.create_event_option({
					"label": "Continue with shielding",
					"effect": "minor_radiation",
					"effect_value": 5,
					"description": "Accept minor radiation exposure."
				}),
				Phase2Types.create_event_option({
					"label": "Emergency power to shields",
					"effect": "power_drain",
					"effect_value": 10,
					"description": "Drain power reserves."
				})
			]
		}),
		Phase2Types.create_event({
			"type": Phase2Types.EventType.COMPONENT_MALFUNCTION,
			"title": "COMPONENT MALFUNCTION",
			"description": "The oxygenator is showing erratic readings. It may need attention.",
			"options": [
				Phase2Types.create_event_option({
					"label": "Assign engineer to repair",
					"effect": "morale_boost",
					"effect_value": 5,
					"description": "Fix it properly."
				}),
				Phase2Types.create_event_option({
					"label": "Monitor for now",
					"effect": "morale_loss",
					"effect_value": 3,
					"description": "Hope it resolves itself."
				})
			]
		}),
		Phase2Types.create_event({
			"type": Phase2Types.EventType.MESSAGE_FROM_EARTH,
			"title": "MESSAGE FROM EARTH",
			"description": "A personal message has arrived for one of the crew members.",
			"options": [
				Phase2Types.create_event_option({
					"label": "Share immediately",
					"effect": "morale_boost",
					"effect_value": 10,
					"description": "Boost morale now."
				}),
				Phase2Types.create_event_option({
					"label": "Save for a difficult day",
					"effect": "morale_boost",
					"effect_value": 3,
					"description": "Small boost now, save for later."
				})
			]
		}),
		Phase2Types.create_event({
			"type": Phase2Types.EventType.MICROMETEORITE,
			"title": "MICROMETEORITE IMPACT",
			"description": "A small impact registered on the hull. No breach detected, but sensors are recalibrating.",
			"options": [
				Phase2Types.create_event_option({
					"label": "Full hull inspection",
					"effect": "thorough_check",
					"description": "Takes time but ensures safety."
				}),
				Phase2Types.create_event_option({
					"label": "Quick visual check",
					"effect": "quick_check",
					"description": "Faster but might miss something."
				})
			]
		}),
		Phase2Types.create_event({
			"type": Phase2Types.EventType.CARGO_LOOSE,
			"title": "EQUIPMENT FLOATING",
			"description": "Some supplies have come loose and are drifting in the cargo area. Nothing critical.",
			"options": [
				Phase2Types.create_event_option({
					"label": "Secure everything properly",
					"effect": "secure_cargo",
					"description": "No losses."
				}),
				Phase2Types.create_event_option({
					"label": "Catch what you can, continue",
					"effect": "minor_loss",
					"effect_value": 5,
					"description": "Lose some supplies."
				})
			]
		})
	]

# ============================================================================
# STATE GETTERS
# ============================================================================

func get_state() -> Dictionary:
	return _state.duplicate(true)

func get_current_day() -> int:
	return _state.get("current_day", 1)

func get_total_days() -> int:
	return _state.get("total_days", Phase2Types.TOTAL_TRAVEL_DAYS)

func get_days_remaining() -> int:
	return Phase2Reducer.get_days_remaining(_state)

func get_journey_progress() -> float:
	return Phase2Reducer.get_journey_progress(_state)

func get_speed() -> int:
	return _state.get("speed", Phase2Types.Speed.NORMAL)

func is_auto_advancing() -> bool:
	return _state.get("auto_advance", true)

func get_resources() -> Dictionary:
	return _state.get("resources", {}).duplicate(true)

func get_crew() -> Array:
	return _state.get("crew", []).duplicate(true)

func get_crew_count() -> int:
	return _state.get("crew", []).size()

func get_storage_containers() -> Array:
	return _state.get("storage_containers", []).duplicate(true)

func get_accessible_containers() -> Array:
	return Phase2Types.get_accessible_containers(_state)

func get_blocked_containers() -> Array:
	return Phase2Types.get_blocked_containers(_state)

func get_active_container_index() -> int:
	return _state.get("active_container_index", 0)

func get_repair_state() -> Dictionary:
	return _state.get("repair", {}).duplicate(true)

func is_repair_in_progress() -> bool:
	return Phase2Reducer.is_repair_in_progress(_state)

func get_active_event() -> Dictionary:
	return _state.get("active_event", {}).duplicate(true)

func has_active_event() -> bool:
	return Phase2Reducer.has_active_event(_state)

func is_mars_visible() -> bool:
	return _state.get("mars_visible", false)

func has_arrived() -> bool:
	return Phase2Reducer.has_arrived(_state)

func is_game_over() -> bool:
	return Phase2Reducer.is_game_over(_state)

func get_log() -> Array:
	return _state.get("log", []).duplicate(true)

func get_average_morale() -> float:
	return Phase2Reducer.get_average_morale(_state)

func get_average_health() -> float:
	return Phase2Reducer.get_average_health(_state)

func get_accessible_food() -> float:
	return Phase2Reducer.get_accessible_food(_state)

func get_accessible_water() -> float:
	return Phase2Reducer.get_accessible_water(_state)

func get_trapped_food() -> float:
	return Phase2Reducer.get_trapped_food(_state)

func get_trapped_water() -> float:
	return Phase2Reducer.get_trapped_water(_state)

# ============================================================================
# DISPATCH (the only way to modify state)
# ============================================================================

func dispatch(action: Dictionary) -> void:
	var old_state = _state
	_state = Phase2Reducer.reduce(_state, action)

	# Emit appropriate signals based on what changed
	_emit_change_signals(old_state, _state, action)
	state_changed.emit(_state)

func dispatch_with_random(action: Dictionary, random_count: int = 10) -> void:
	var random_values: Array = []
	for i in range(random_count):
		random_values.append(_rng.randf())

	action["random_values"] = random_values
	dispatch(action)

# ============================================================================
# HIGH-LEVEL ACTIONS (convenience methods that dispatch)
# ============================================================================

func start_new_journey(seed_value: int = 0) -> void:
	if seed_value > 0:
		_rng.seed = seed_value
	else:
		_rng.seed = int(Time.get_unix_time_from_system())

	_state = Phase2Types.create_phase2_state({
		"random_seed": _rng.seed
	})
	state_changed.emit(_state)

func advance_day() -> void:
	if is_game_over() or has_arrived():
		return

	if has_active_event():
		return  # Can't advance while event is active

	# Generate random values for the day
	dispatch_with_random(Phase2Reducer.action_advance_day([]), 10)

	# Check if we need to trigger a random event from the queue
	_process_event_queue()

	# Check for arrival
	if has_arrived():
		arrival.emit()

	# Check for game over
	if is_game_over():
		game_over.emit("All crew lost")

func set_speed(speed: int) -> void:
	dispatch(Phase2Reducer.action_set_speed(speed))

func pause() -> void:
	dispatch(Phase2Reducer.action_set_speed(Phase2Types.Speed.PAUSED))

func resume() -> void:
	if get_speed() == Phase2Types.Speed.PAUSED:
		dispatch(Phase2Reducer.action_set_speed(Phase2Types.Speed.NORMAL))

func toggle_pause() -> void:
	if get_speed() == Phase2Types.Speed.PAUSED:
		resume()
	else:
		pause()

func resolve_event(choice_index: int) -> void:
	if not has_active_event():
		return

	var event = get_active_event()
	var choice = event.options[choice_index] if choice_index < event.options.size() else {}

	# Handle special effects
	var effect = choice.get("effect", "")

	if effect == "repair_section":
		# Start repair
		var container_id = event.get("blocked_container_id", "")
		var repair_days = _rng.randi_range(Phase2Types.REPAIR_MIN_DAYS, Phase2Types.REPAIR_MAX_DAYS)
		dispatch(Phase2Reducer.action_start_repair(container_id, repair_days))
	elif effect == "eva_retrieval":
		# Attempt EVA retrieval
		var container_id = event.get("blocked_container_id", "")
		dispatch(Phase2Reducer.action_eva_retrieval(container_id, _rng.randf()))
	else:
		# Standard event resolution
		dispatch(Phase2Reducer.action_resolve_event(choice_index, _rng.randf()))

func trigger_event(event: Dictionary) -> void:
	dispatch(Phase2Reducer.action_trigger_event(event))

# ============================================================================
# EVENT PROCESSING
# ============================================================================

func _process_event_queue() -> void:
	## Process any pending events in the queue
	var event_queue = _state.get("event_queue", [])
	if event_queue.is_empty():
		return

	# Get the first queued event request
	var request = event_queue[0]

	if request.get("type") == "random_event":
		# Pick a random event from the pool
		if not _event_pool.is_empty():
			var event = _event_pool[_rng.randi() % _event_pool.size()].duplicate(true)
			trigger_event(event)

	# Clear the queue (the event is now active)
	var new_state = _state.duplicate(true)
	new_state.event_queue = []
	_state = new_state

# ============================================================================
# SIGNAL EMISSION HELPERS
# ============================================================================

func _emit_change_signals(old_state: Dictionary, new_state: Dictionary, action: Dictionary) -> void:
	# Day advancement
	var old_day = old_state.get("current_day", 1)
	var new_day = new_state.get("current_day", 1)
	if old_day != new_day:
		day_advanced.emit(new_day)

	# Speed change
	var old_speed = old_state.get("speed", Phase2Types.Speed.NORMAL)
	var new_speed = new_state.get("speed", Phase2Types.Speed.NORMAL)
	if old_speed != new_speed:
		speed_changed.emit(new_speed)

	# Resources change
	var old_resources = old_state.get("resources", {})
	var new_resources = new_state.get("resources", {})
	if old_resources != new_resources:
		resources_changed.emit(new_resources)

	# Crew change
	var old_crew = old_state.get("crew", [])
	var new_crew = new_state.get("crew", [])
	if old_crew != new_crew:
		crew_changed.emit(new_crew)

	# Container accessibility changes
	var old_containers = old_state.get("storage_containers", [])
	var new_containers = new_state.get("storage_containers", [])
	for i in range(min(old_containers.size(), new_containers.size())):
		var old_c = old_containers[i]
		var new_c = new_containers[i]
		if old_c.get("accessible", true) and not new_c.get("accessible", true):
			container_blocked.emit(new_c)
		elif not old_c.get("accessible", true) and new_c.get("accessible", true):
			container_restored.emit(new_c)

	# Repair state changes
	var old_repair = old_state.get("repair", {})
	var new_repair = new_state.get("repair", {})
	if not old_repair.get("in_progress", false) and new_repair.get("in_progress", false):
		repair_started.emit(new_repair.get("target_container_id", ""), new_repair.get("days_remaining", 0))
	elif old_repair.get("in_progress", false) and not new_repair.get("in_progress", false):
		repair_completed.emit(old_repair.get("target_container_id", ""))

	# Mars visibility
	var old_mars = old_state.get("mars_visible", false)
	var new_mars = new_state.get("mars_visible", false)
	if not old_mars and new_mars:
		mars_visible.emit()

	# Log additions
	var old_log = old_state.get("log", [])
	var new_log = new_state.get("log", [])
	if new_log.size() > old_log.size():
		var new_entry = new_log[-1]
		log_added.emit(new_entry)

	# Action-specific signals
	match action.get("type", -1):
		Phase2Reducer.ActionType.TRIGGER_EVENT:
			event_triggered.emit(action.get("event", {}))

		Phase2Reducer.ActionType.RESOLVE_EVENT, Phase2Reducer.ActionType.START_REPAIR, Phase2Reducer.ActionType.EVA_RETRIEVAL:
			if old_state.get("active_event", {}) != {} and new_state.get("active_event", {}) == {}:
				event_resolved.emit(action.get("choice_index", 0))

# ============================================================================
# PERSISTENCE
# ============================================================================

func save_journey(slot: int = 0) -> bool:
	var save_path = "user://phase2_save_%d.json" % slot
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		return false

	var save_data = _state.duplicate(true)
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	return true

func load_journey(slot: int = 0) -> bool:
	var save_path = "user://phase2_save_%d.json" % slot
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

	_state = json.data
	state_changed.emit(_state)
	return true

func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists("user://phase2_save_%d.json" % slot)

func delete_save(slot: int = 0) -> bool:
	var save_path = "user://phase2_save_%d.json" % slot
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
		return true
	return false

# ============================================================================
# DEBUG HELPERS
# ============================================================================

func debug_advance_days(count: int) -> void:
	for i in range(count):
		advance_day()
		if has_active_event():
			resolve_event(0)  # Auto-resolve with first choice

func debug_block_container(container_id: String) -> void:
	dispatch(Phase2Reducer.action_block_section(
		container_id,
		Phase2Types.ContainerStatus.BLOCKED,
		_rng.randf()
	))

func debug_trigger_random_event() -> void:
	if not _event_pool.is_empty():
		var event = _event_pool[_rng.randi() % _event_pool.size()].duplicate(true)
		trigger_event(event)

func debug_set_day(day: int) -> void:
	var new_state = _state.duplicate(true)
	new_state.current_day = day
	_state = new_state
	state_changed.emit(_state)
