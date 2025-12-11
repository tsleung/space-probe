class_name VNPReducer
extends RefCounted

## Redux-style reducer for VNP game state
## All functions are pure: (state, action) -> new_state

# ============================================================================
# ACTION TYPES
# ============================================================================

enum ActionType {
	# Game flow
	START_RUN,
	ADVANCE_TURN,
	END_GAME,

	# Probe management
	CREATE_PROBE,
	UPDATE_PROBE,
	DESTROY_PROBE,

	# Probe commands
	MOVE_PROBE,
	START_MINING,
	START_REPLICATION,
	SET_IDLE,

	# Resources
	ADD_RESOURCES,
	SPEND_RESOURCES,
	MINE_RESOURCES,

	# Systems
	EXPLORE_SYSTEM,
	UPDATE_SYSTEM,

	# Events
	SET_EVENT,
	CLEAR_EVENT,
	ADD_LOG
}

# ============================================================================
# MAIN REDUCER
# ============================================================================

static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	match action.type:
		ActionType.START_RUN:
			return _reduce_start_run(state, action)
		ActionType.ADVANCE_TURN:
			return _reduce_advance_turn(state, action)
		ActionType.END_GAME:
			return _reduce_end_game(state, action)
		ActionType.CREATE_PROBE:
			return _reduce_create_probe(state, action)
		ActionType.UPDATE_PROBE:
			return _reduce_update_probe(state, action)
		ActionType.DESTROY_PROBE:
			return _reduce_destroy_probe(state, action)
		ActionType.MOVE_PROBE:
			return _reduce_move_probe(state, action)
		ActionType.START_MINING:
			return _reduce_start_mining(state, action)
		ActionType.START_REPLICATION:
			return _reduce_start_replication(state, action)
		ActionType.SET_IDLE:
			return _reduce_set_idle(state, action)
		ActionType.ADD_RESOURCES:
			return _reduce_add_resources(state, action)
		ActionType.SPEND_RESOURCES:
			return _reduce_spend_resources(state, action)
		ActionType.MINE_RESOURCES:
			return _reduce_mine_resources(state, action)
		ActionType.EXPLORE_SYSTEM:
			return _reduce_explore_system(state, action)
		ActionType.UPDATE_SYSTEM:
			return _reduce_update_system(state, action)
		ActionType.SET_EVENT:
			return _reduce_set_event(state, action)
		ActionType.CLEAR_EVENT:
			return _reduce_clear_event(state, action)
		ActionType.ADD_LOG:
			return _reduce_add_log(state, action)
		_:
			return state

# ============================================================================
# ACTION CREATORS
# ============================================================================

static func action_start_run(seed_value: int, galaxy_data: Dictionary) -> Dictionary:
	return {
		"type": ActionType.START_RUN,
		"seed": seed_value,
		"galaxy_data": galaxy_data
	}

static func action_advance_turn() -> Dictionary:
	return {"type": ActionType.ADVANCE_TURN}

static func action_end_game(victory: bool, reason: String) -> Dictionary:
	return {
		"type": ActionType.END_GAME,
		"victory": victory,
		"reason": reason
	}

static func action_create_probe(probe: Dictionary) -> Dictionary:
	return {
		"type": ActionType.CREATE_PROBE,
		"probe": probe
	}

static func action_update_probe(probe_id: String, updates: Dictionary) -> Dictionary:
	return {
		"type": ActionType.UPDATE_PROBE,
		"probe_id": probe_id,
		"updates": updates
	}

static func action_destroy_probe(probe_id: String) -> Dictionary:
	return {
		"type": ActionType.DESTROY_PROBE,
		"probe_id": probe_id
	}

static func action_move_probe(probe_id: String, target_system: String, travel_time: int) -> Dictionary:
	return {
		"type": ActionType.MOVE_PROBE,
		"probe_id": probe_id,
		"target_system": target_system,
		"travel_time": travel_time
	}

static func action_start_mining(probe_id: String) -> Dictionary:
	return {
		"type": ActionType.START_MINING,
		"probe_id": probe_id
	}

static func action_start_replication(probe_id: String) -> Dictionary:
	return {
		"type": ActionType.START_REPLICATION,
		"probe_id": probe_id
	}

static func action_set_idle(probe_id: String) -> Dictionary:
	return {
		"type": ActionType.SET_IDLE,
		"probe_id": probe_id
	}

static func action_add_resources(resources: Dictionary) -> Dictionary:
	return {
		"type": ActionType.ADD_RESOURCES,
		"resources": resources
	}

static func action_spend_resources(resources: Dictionary) -> Dictionary:
	return {
		"type": ActionType.SPEND_RESOURCES,
		"resources": resources
	}

static func action_mine_resources(system_id: String, amounts: Dictionary) -> Dictionary:
	return {
		"type": ActionType.MINE_RESOURCES,
		"system_id": system_id,
		"amounts": amounts
	}

static func action_explore_system(system_id: String) -> Dictionary:
	return {
		"type": ActionType.EXPLORE_SYSTEM,
		"system_id": system_id
	}

static func action_update_system(system_id: String, updates: Dictionary) -> Dictionary:
	return {
		"type": ActionType.UPDATE_SYSTEM,
		"system_id": system_id,
		"updates": updates
	}

static func action_set_event(event: Dictionary) -> Dictionary:
	return {
		"type": ActionType.SET_EVENT,
		"event": event
	}

static func action_clear_event() -> Dictionary:
	return {"type": ActionType.CLEAR_EVENT}

static func action_add_log(message: String, category: String = "info") -> Dictionary:
	return {
		"type": ActionType.ADD_LOG,
		"message": message,
		"category": category
	}

# ============================================================================
# REDUCER IMPLEMENTATIONS
# ============================================================================

static func _reduce_start_run(state: Dictionary, action: Dictionary) -> Dictionary:
	var galaxy_data = action.galaxy_data

	# Create initial probe
	var initial_probe = VNPTypes.create_probe({
		"id": "probe_1",
		"name": "Bob-1",
		"current_system": galaxy_data.home_system,
		"created_turn": 1
	})

	return VNPTypes.create_vnp_state({
		"random_seed": action.seed,
		"systems": galaxy_data.systems,
		"home_system": galaxy_data.home_system,
		"total_systems": galaxy_data.total_systems,
		"probes": {"probe_1": initial_probe},
		"event_log": [{
			"turn": 1,
			"message": "Probe Bob-1 activated in %s system. Mission: Explore and replicate." % galaxy_data.systems[galaxy_data.home_system].name,
			"category": "info"
		}]
	})

static func _reduce_advance_turn(state: Dictionary, _action: Dictionary) -> Dictionary:
	return VNPTypes.with_fields(state, {
		"current_turn": state.current_turn + 1,
		"year": state.year + 10  # Each turn = 10 years
	})

static func _reduce_end_game(state: Dictionary, action: Dictionary) -> Dictionary:
	var score = _calc_score(state, action.victory)
	return VNPTypes.with_fields(state, {
		"is_game_over": true,
		"victory": action.victory,
		"game_over_reason": action.reason,
		"final_score": score
	})

static func _reduce_create_probe(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_probes = state.probes.duplicate(true)
	new_probes[action.probe.id] = action.probe

	var active_count = 0
	for probe in new_probes.values():
		if probe.status != VNPTypes.ProbeStatus.DAMAGED or probe.health > 0:
			active_count += 1

	return VNPTypes.with_fields(state, {
		"probes": new_probes,
		"next_probe_id": state.next_probe_id + 1,
		"total_probes_built": state.total_probes_built + 1,
		"peak_probes": maxi(state.peak_probes, active_count)
	})

static func _reduce_update_probe(state: Dictionary, action: Dictionary) -> Dictionary:
	if not state.probes.has(action.probe_id):
		return state

	var new_probes = state.probes.duplicate(true)
	new_probes[action.probe_id] = VNPTypes.with_fields(
		new_probes[action.probe_id],
		action.updates
	)

	return VNPTypes.with_field(state, "probes", new_probes)

static func _reduce_destroy_probe(state: Dictionary, action: Dictionary) -> Dictionary:
	if not state.probes.has(action.probe_id):
		return state

	var new_probes = state.probes.duplicate(true)
	new_probes.erase(action.probe_id)

	return VNPTypes.with_fields(state, {
		"probes": new_probes,
		"probes_lost": state.probes_lost + 1
	})

static func _reduce_move_probe(state: Dictionary, action: Dictionary) -> Dictionary:
	if not state.probes.has(action.probe_id):
		return state

	var new_probes = state.probes.duplicate(true)
	new_probes[action.probe_id] = VNPTypes.with_fields(
		new_probes[action.probe_id],
		{
			"status": VNPTypes.ProbeStatus.TRAVELING,
			"target_system": action.target_system,
			"travel_progress": action.travel_time
		}
	)

	return VNPTypes.with_field(state, "probes", new_probes)

static func _reduce_start_mining(state: Dictionary, action: Dictionary) -> Dictionary:
	if not state.probes.has(action.probe_id):
		return state

	var new_probes = state.probes.duplicate(true)
	new_probes[action.probe_id] = VNPTypes.with_field(
		new_probes[action.probe_id],
		"status",
		VNPTypes.ProbeStatus.MINING
	)

	return VNPTypes.with_field(state, "probes", new_probes)

static func _reduce_start_replication(state: Dictionary, action: Dictionary) -> Dictionary:
	if not state.probes.has(action.probe_id):
		return state

	var new_probes = state.probes.duplicate(true)
	new_probes[action.probe_id] = VNPTypes.with_fields(
		new_probes[action.probe_id],
		{
			"status": VNPTypes.ProbeStatus.REPLICATING,
			"task_progress": VNPTypes.REPLICATION_TURNS
		}
	)

	return VNPTypes.with_field(state, "probes", new_probes)

static func _reduce_set_idle(state: Dictionary, action: Dictionary) -> Dictionary:
	if not state.probes.has(action.probe_id):
		return state

	var new_probes = state.probes.duplicate(true)
	new_probes[action.probe_id] = VNPTypes.with_fields(
		new_probes[action.probe_id],
		{
			"status": VNPTypes.ProbeStatus.IDLE,
			"task_progress": 0
		}
	)

	return VNPTypes.with_field(state, "probes", new_probes)

static func _reduce_add_resources(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_resources = state.resources.duplicate()
	for key in action.resources.keys():
		new_resources[key] = new_resources.get(key, 0) + action.resources[key]

	return VNPTypes.with_field(state, "resources", new_resources)

static func _reduce_spend_resources(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_resources = state.resources.duplicate()
	for key in action.resources.keys():
		new_resources[key] = maxi(0, new_resources.get(key, 0) - action.resources[key])

	return VNPTypes.with_field(state, "resources", new_resources)

static func _reduce_mine_resources(state: Dictionary, action: Dictionary) -> Dictionary:
	if not state.systems.has(action.system_id):
		return state

	var system = state.systems[action.system_id]
	var new_system_resources = system.resources.duplicate()
	var new_global_resources = state.resources.duplicate()
	var mined_iron = 0
	var mined_rare = 0

	for key in action.amounts.keys():
		var available = new_system_resources.get(key, 0)
		var wanted = action.amounts[key]
		var actual = mini(available, wanted)

		new_system_resources[key] = available - actual
		new_global_resources[key] = new_global_resources.get(key, 0) + actual

		if key == "iron":
			mined_iron = actual
		elif key == "rare":
			mined_rare = actual

	var new_systems = state.systems.duplicate(true)
	new_systems[action.system_id] = VNPTypes.with_field(system, "resources", new_system_resources)

	return VNPTypes.with_fields(state, {
		"systems": new_systems,
		"resources": new_global_resources,
		"total_iron_mined": state.total_iron_mined + mined_iron,
		"total_rare_mined": state.total_rare_mined + mined_rare
	})

static func _reduce_explore_system(state: Dictionary, action: Dictionary) -> Dictionary:
	if not state.systems.has(action.system_id):
		return state

	var system = state.systems[action.system_id]
	if system.is_explored:
		return state

	var new_systems = state.systems.duplicate(true)
	new_systems[action.system_id] = VNPTypes.with_field(system, "is_explored", true)

	return VNPTypes.with_fields(state, {
		"systems": new_systems,
		"systems_explored": state.systems_explored + 1
	})

static func _reduce_update_system(state: Dictionary, action: Dictionary) -> Dictionary:
	if not state.systems.has(action.system_id):
		return state

	var new_systems = state.systems.duplicate(true)
	new_systems[action.system_id] = VNPTypes.with_fields(
		new_systems[action.system_id],
		action.updates
	)

	return VNPTypes.with_field(state, "systems", new_systems)

static func _reduce_set_event(state: Dictionary, action: Dictionary) -> Dictionary:
	return VNPTypes.with_field(state, "pending_event", action.event)

static func _reduce_clear_event(state: Dictionary, _action: Dictionary) -> Dictionary:
	return VNPTypes.with_field(state, "pending_event", {})

static func _reduce_add_log(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_log = state.event_log.duplicate()
	new_log.append({
		"turn": state.current_turn,
		"message": action.message,
		"category": action.category
	})

	# Keep log manageable
	if new_log.size() > 100:
		new_log = new_log.slice(-100)

	return VNPTypes.with_field(state, "event_log", new_log)

# ============================================================================
# HELPERS
# ============================================================================

static func _calc_score(state: Dictionary, victory: bool) -> int:
	var score = 0

	# Systems explored
	score += state.systems_explored * 100

	# Probes built
	score += state.total_probes_built * 50

	# Peak probe count
	score += state.peak_probes * 100

	# Resources mined
	score += state.total_iron_mined
	score += state.total_rare_mined * 5

	# Turns survived
	score += state.current_turn * 10

	# Victory bonus
	if victory:
		score = int(score * 1.5)

	return score
