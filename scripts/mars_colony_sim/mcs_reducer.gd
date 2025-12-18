class_name MCSReducer
extends RefCounted

## Redux-style reducer for MCS (Mars Colony Sim) state
## All functions are pure: (state, action) -> new_state
## No side effects, fully deterministic with provided random values

# ============================================================================
# ACTION TYPES
# ============================================================================

enum ActionType {
	# Game flow
	START_NEW_COLONY,
	ADVANCE_YEAR,

	# Population
	ADD_COLONIST,
	REMOVE_COLONIST,
	UPDATE_COLONIST,

	# Buildings
	START_CONSTRUCTION,
	COMPLETE_CONSTRUCTION,
	DEMOLISH_BUILDING,
	REPAIR_BUILDING,

	# Resources
	UPDATE_RESOURCE,
	APPLY_PRODUCTION,
	APPLY_CONSUMPTION,

	# Workers
	ASSIGN_WORKER,
	UNASSIGN_WORKER,
	AUTO_ASSIGN_WORKERS,

	# Politics
	HOLD_ELECTION,
	CHANGE_GOVERNMENT,
	UPDATE_FACTION_STANDINGS,
	HOLD_INDEPENDENCE_VOTE,

	# Events
	TRIGGER_EVENT,
	RESOLVE_EVENT_CHOICE,

	# Logging
	ADD_COLONY_LOG,

	# Win/Loss
	CHECK_VICTORY_CONDITIONS,
	END_COLONY
}

# ============================================================================
# MAIN REDUCER
# ============================================================================

## Main reducer function - dispatches to specific handlers
static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	match action.type:
		ActionType.START_NEW_COLONY:
			return _reduce_start_new_colony(state, action)
		ActionType.ADVANCE_YEAR:
			return _reduce_advance_year(state, action)
		ActionType.ADD_COLONIST:
			return _reduce_add_colonist(state, action)
		ActionType.REMOVE_COLONIST:
			return _reduce_remove_colonist(state, action)
		ActionType.UPDATE_COLONIST:
			return _reduce_update_colonist(state, action)
		ActionType.START_CONSTRUCTION:
			return _reduce_start_construction(state, action)
		ActionType.COMPLETE_CONSTRUCTION:
			return _reduce_complete_construction(state, action)
		ActionType.DEMOLISH_BUILDING:
			return _reduce_demolish_building(state, action)
		ActionType.REPAIR_BUILDING:
			return _reduce_repair_building(state, action)
		ActionType.UPDATE_RESOURCE:
			return _reduce_update_resource(state, action)
		ActionType.APPLY_PRODUCTION:
			return _reduce_apply_production(state, action)
		ActionType.APPLY_CONSUMPTION:
			return _reduce_apply_consumption(state, action)
		ActionType.ASSIGN_WORKER:
			return _reduce_assign_worker(state, action)
		ActionType.UNASSIGN_WORKER:
			return _reduce_unassign_worker(state, action)
		ActionType.AUTO_ASSIGN_WORKERS:
			return _reduce_auto_assign_workers(state, action)
		ActionType.HOLD_ELECTION:
			return _reduce_hold_election(state, action)
		ActionType.CHANGE_GOVERNMENT:
			return _reduce_change_government(state, action)
		ActionType.UPDATE_FACTION_STANDINGS:
			return _reduce_update_faction_standings(state, action)
		ActionType.HOLD_INDEPENDENCE_VOTE:
			return _reduce_hold_independence_vote(state, action)
		ActionType.TRIGGER_EVENT:
			return _reduce_trigger_event(state, action)
		ActionType.RESOLVE_EVENT_CHOICE:
			return _reduce_resolve_event_choice(state, action)
		ActionType.ADD_COLONY_LOG:
			return _reduce_add_log(state, action)
		ActionType.CHECK_VICTORY_CONDITIONS:
			return _reduce_check_victory(state, action)
		ActionType.END_COLONY:
			return _reduce_end_colony(state, action)
		_:
			return state

# ============================================================================
# ACTION CREATORS (pure functions that create action dictionaries)
# ============================================================================

static func action_start_new_colony(founders: Array, seed_value: int = 0) -> Dictionary:
	return {
		"type": ActionType.START_NEW_COLONY,
		"founders": founders,
		"seed": seed_value if seed_value > 0 else int(Time.get_unix_time_from_system())
	}

static func action_advance_year(random_values: Array) -> Dictionary:
	return {
		"type": ActionType.ADVANCE_YEAR,
		"random_values": random_values
	}

static func action_add_colonist(colonist: Dictionary) -> Dictionary:
	return {
		"type": ActionType.ADD_COLONIST,
		"colonist": colonist
	}

static func action_remove_colonist(colonist_id: String, reason: String = "death") -> Dictionary:
	return {
		"type": ActionType.REMOVE_COLONIST,
		"colonist_id": colonist_id,
		"reason": reason
	}

static func action_update_colonist(colonist_id: String, updates: Dictionary) -> Dictionary:
	return {
		"type": ActionType.UPDATE_COLONIST,
		"colonist_id": colonist_id,
		"updates": updates
	}

static func action_start_construction(building_type: int, priority: int = 1) -> Dictionary:
	return {
		"type": ActionType.START_CONSTRUCTION,
		"building_type": building_type,
		"priority": priority
	}

static func action_complete_construction(building_id: String) -> Dictionary:
	return {
		"type": ActionType.COMPLETE_CONSTRUCTION,
		"building_id": building_id
	}

static func action_demolish_building(building_id: String) -> Dictionary:
	return {
		"type": ActionType.DEMOLISH_BUILDING,
		"building_id": building_id
	}

static func action_repair_building(building_id: String) -> Dictionary:
	return {
		"type": ActionType.REPAIR_BUILDING,
		"building_id": building_id
	}

static func action_update_resource(resource_type: int, delta: float) -> Dictionary:
	return {
		"type": ActionType.UPDATE_RESOURCE,
		"resource_type": resource_type,
		"delta": delta
	}

static func action_apply_production(random_values: Array) -> Dictionary:
	return {
		"type": ActionType.APPLY_PRODUCTION,
		"random_values": random_values
	}

static func action_apply_consumption() -> Dictionary:
	return {
		"type": ActionType.APPLY_CONSUMPTION
	}

static func action_assign_worker(colonist_id: String, building_id: String) -> Dictionary:
	return {
		"type": ActionType.ASSIGN_WORKER,
		"colonist_id": colonist_id,
		"building_id": building_id
	}

static func action_unassign_worker(colonist_id: String) -> Dictionary:
	return {
		"type": ActionType.UNASSIGN_WORKER,
		"colonist_id": colonist_id
	}

static func action_auto_assign_workers() -> Dictionary:
	return {
		"type": ActionType.AUTO_ASSIGN_WORKERS
	}

static func action_hold_election(random_values: Array) -> Dictionary:
	return {
		"type": ActionType.HOLD_ELECTION,
		"random_values": random_values
	}

static func action_change_government(new_system: int) -> Dictionary:
	return {
		"type": ActionType.CHANGE_GOVERNMENT,
		"new_system": new_system
	}

static func action_update_faction_standings() -> Dictionary:
	return {
		"type": ActionType.UPDATE_FACTION_STANDINGS
	}

static func action_hold_independence_vote(random_value: float) -> Dictionary:
	return {
		"type": ActionType.HOLD_INDEPENDENCE_VOTE,
		"random_value": random_value
	}

static func action_trigger_event(event: Dictionary) -> Dictionary:
	return {
		"type": ActionType.TRIGGER_EVENT,
		"event": event
	}

static func action_resolve_event_choice(event_id: String, choice_index: int, random_value: float) -> Dictionary:
	return {
		"type": ActionType.RESOLVE_EVENT_CHOICE,
		"event_id": event_id,
		"choice_index": choice_index,
		"random_value": random_value
	}

static func action_add_log(message: String, log_type: String = "info", year: int = -1) -> Dictionary:
	return {
		"type": ActionType.ADD_COLONY_LOG,
		"message": message,
		"log_type": log_type,
		"year": year
	}

static func action_check_victory() -> Dictionary:
	return {
		"type": ActionType.CHECK_VICTORY_CONDITIONS
	}

static func action_end_colony(reason: String, is_victory: bool) -> Dictionary:
	return {
		"type": ActionType.END_COLONY,
		"reason": reason,
		"is_victory": is_victory
	}

# ============================================================================
# REDUCER IMPLEMENTATIONS (all pure)
# ============================================================================

static func _reduce_start_new_colony(_state: Dictionary, action: Dictionary) -> Dictionary:
	var new_state = MCSTypes.create_colony_state()
	new_state.random_seed = action.seed
	new_state.colony_phase = MCSTypes.ColonyPhase.ACT_1_FOUNDERS
	new_state.current_year = 1

	# Add founders
	for founder in action.founders:
		new_state.colonists.append(founder)

	# Create starting buildings
	var hab = MCSTypes.create_building({
		"type": MCSTypes.BuildingType.HAB_POD,
		"id": "hab_001",
		"is_operational": true,
		"construction_progress": 1.0,
		"housing_capacity": 16
	})
	new_state.buildings.append(hab)

	var farm = MCSTypes.create_building({
		"type": MCSTypes.BuildingType.GREENHOUSE,
		"id": "farm_001",
		"is_operational": true,
		"construction_progress": 1.0
	})
	new_state.buildings.append(farm)

	var power = MCSTypes.create_building({
		"type": MCSTypes.BuildingType.SOLAR_ARRAY,
		"id": "solar_001",
		"is_operational": true,
		"construction_progress": 1.0
	})
	new_state.buildings.append(power)

	var power2 = MCSTypes.create_building({
		"type": MCSTypes.BuildingType.SOLAR_ARRAY,
		"id": "solar_002",
		"is_operational": true,
		"construction_progress": 1.0
	})
	new_state.buildings.append(power2)

	# Second hab for population growth
	var hab2 = MCSTypes.create_building({
		"type": MCSTypes.BuildingType.HAB_POD,
		"id": "hab_002",
		"is_operational": true,
		"construction_progress": 1.0,
		"housing_capacity": 16
	})
	new_state.buildings.append(hab2)

	# Second greenhouse for food security
	var farm2 = MCSTypes.create_building({
		"type": MCSTypes.BuildingType.GREENHOUSE,
		"id": "farm_002",
		"is_operational": true,
		"construction_progress": 1.0
	})
	new_state.buildings.append(farm2)

	# Starting resources (generous for AI spectate mode)
	new_state.resources.food = 2000.0  # 2-3 years supply
	new_state.resources.water = 1000.0
	new_state.resources.oxygen = 500.0
	new_state.resources.fuel = 200.0
	new_state.resources.building_materials = 300.0
	new_state.resources.machine_parts = 100.0
	new_state.resources.medicine = 50.0

	# Initialize log
	new_state.mission_log = [{
		"year": 1,
		"message": "Colony founded on Mars. %d pioneers begin humanity's greatest adventure." % action.founders.size(),
		"log_type": "milestone"
	}]

	return new_state

static func _reduce_advance_year(state: Dictionary, action: Dictionary) -> Dictionary:
	var current_year = state.get("current_year", 1)
	var new_year = current_year + 1
	var updates: Dictionary = {"current_year": new_year}
	var new_log = state.get("mission_log", []).duplicate()
	var rand_idx = 0

	var colonists = state.get("colonists", [])
	var resources = state.get("resources", {})
	var buildings = state.get("buildings", [])
	var random_values = action.get("random_values", [])

	# === POPULATION PHASE ===
	var pop_result = MCSPopulation.advance_year(
		colonists,
		new_year,
		resources,
		buildings,
		random_values.slice(rand_idx, rand_idx + colonists.size() * 5)
	)
	rand_idx += colonists.size() * 5

	updates["colonists"] = pop_result.colonists

	# Log births
	for birth in pop_result.births:
		new_log.append({
			"year": new_year,
			"message": "%s was born to the colony!" % birth.display_name,
			"log_type": "birth"
		})

	# Log deaths
	for death in pop_result.deaths:
		new_log.append({
			"year": new_year,
			"message": "%s has passed away. %s" % [death.name, death.cause],
			"log_type": "death"
		})

	# Log coming of age
	for adult in pop_result.new_adults:
		new_log.append({
			"year": new_year,
			"message": "%s has come of age and joined the workforce." % adult.display_name,
			"log_type": "milestone"
		})

	# === ECONOMY PHASE ===
	var production = MCSEconomy.calc_yearly_production(
		buildings,
		updates["colonists"],
		resources
	)
	var consumption = MCSEconomy.calc_yearly_consumption(
		updates["colonists"],
		buildings
	)

	var resource_result = MCSEconomy.apply_yearly_resources(
		resources,
		production,
		consumption
	)
	updates["resources"] = resource_result.resources

	# Log shortages (creates drama!)
	for shortage in resource_result.shortages:
		new_log.append({
			"year": new_year,
			"message": "SHORTAGE: %s supplies critically low!" % shortage.to_upper(),
			"log_type": "crisis"
		})

	# === BUILDING MAINTENANCE ===
	var maint_rand_count = buildings.size() + 5
	var maint_rand_values = random_values.slice(rand_idx, rand_idx + maint_rand_count)
	rand_idx += maint_rand_count
	var maint_result = MCSEconomy.apply_building_maintenance(
		buildings,
		updates["resources"],
		new_year,
		maint_rand_values
	)
	updates["buildings"] = maint_result.buildings
	updates["resources"] = maint_result.resources

	for breakdown in maint_result.breakdowns:
		new_log.append({
			"year": new_year,
			"message": "%s has broken down and needs repair!" % breakdown,
			"log_type": "crisis"
		})

	# === POLITICS PHASE ===
	var politics = state.get("politics", {})
	var pol_result = MCSPolitics.update_faction_standings(
		politics,
		updates["colonists"],
		updates["resources"]
	)
	updates["politics"] = pol_result

	# Check for election year (every 4 years after year 5)
	if new_year >= 5 and (new_year - 5) % 4 == 0:
		var election_rand = random_values.slice(rand_idx, rand_idx + 10)
		rand_idx += 10
		var election_result = MCSPolitics.hold_election(
			updates["politics"],
			updates["colonists"],
			election_rand
		)
		updates["politics"] = election_result.politics

		new_log.append({
			"year": new_year,
			"message": "Colony election held. %s" % election_result.summary,
			"log_type": "politics"
		})

	# Update stability
	updates["politics"] = MCSPolitics.update_stability(
		updates["politics"],
		updates["colonists"],
		updates["resources"],
		resource_result.shortages.size() > 0
	)

	# === PHASE TRANSITIONS ===
	var colony_phase = state.get("colony_phase", 0)
	updates["colony_phase"] = _check_phase_transition(colony_phase, updates, new_year)
	if updates["colony_phase"] != colony_phase:
		new_log.append({
			"year": new_year,
			"message": "Colony has entered a new era: %s" % MCSTypes.get_phase_name(updates["colony_phase"]),
			"log_type": "milestone"
		})

	updates["mission_log"] = new_log

	return _with_fields(state, updates)

static func _reduce_add_colonist(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_colonists = state.get("colonists", []).duplicate()
	var colonist = action.get("colonist", {})
	new_colonists.append(colonist)

	var new_log = state.get("mission_log", []).duplicate()
	new_log.append({
		"year": state.get("current_year", 1),
		"message": "%s has joined the colony." % colonist.get("display_name", "Unknown"),
		"log_type": "info"
	})

	return _with_fields(state, {
		"colonists": new_colonists,
		"mission_log": new_log
	})

static func _reduce_remove_colonist(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_colonists: Array = []
	var removed_name = ""

	for colonist in state.get("colonists", []):
		if colonist.get("id", "") != action.get("colonist_id", ""):
			new_colonists.append(colonist)
		else:
			removed_name = colonist.get("display_name", "Unknown")

	if removed_name.is_empty():
		return state

	var new_log = state.get("mission_log", []).duplicate()
	new_log.append({
		"year": state.get("current_year", 1),
		"message": "%s has left the colony. Reason: %s" % [removed_name, action.get("reason", "")],
		"log_type": "info"
	})

	return _with_fields(state, {
		"colonists": new_colonists,
		"mission_log": new_log
	})

static func _reduce_update_colonist(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_colonists: Array = []
	for colonist in state.get("colonists", []):
		if colonist.get("id", "") == action.get("colonist_id", ""):
			new_colonists.append(_with_fields(colonist, action.get("updates", {})))
		else:
			new_colonists.append(colonist)

	return _with_field(state, "colonists", new_colonists)

static func _reduce_start_construction(state: Dictionary, action: Dictionary) -> Dictionary:
	var result = MCSEconomy.start_construction(
		state.get("buildings", []),
		state.get("resources", {}),
		action.get("building_type", 0),
		action.get("priority", 1)
	)

	if not result.get("success", false):
		return state

	var new_log = state.get("mission_log", []).duplicate()
	new_log.append({
		"year": state.get("current_year", 1),
		"message": "Construction started: %s" % MCSTypes.get_building_name(action.get("building_type", 0)),
		"log_type": "info"
	})

	return _with_fields(state, {
		"buildings": result.get("buildings", []),
		"resources": result.get("resources", {}),
		"mission_log": new_log
	})

static func _reduce_complete_construction(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_buildings: Array = []
	var completed_name = ""

	for building in state.get("buildings", []):
		if building.get("id", "") == action.get("building_id", ""):
			var updated = building.duplicate(true)
			updated["is_operational"] = true
			updated["construction_progress"] = 1.0
			new_buildings.append(updated)
			completed_name = MCSTypes.get_building_name(building.get("type", 0))
		else:
			new_buildings.append(building)

	if completed_name.is_empty():
		return state

	var new_log = state.get("mission_log", []).duplicate()
	new_log.append({
		"year": state.get("current_year", 1),
		"message": "Construction complete: %s is now operational!" % completed_name,
		"log_type": "success"
	})

	return _with_fields(state, {
		"buildings": new_buildings,
		"mission_log": new_log
	})

static func _reduce_demolish_building(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_buildings: Array = []
	var demolished_name = ""

	for building in state.get("buildings", []):
		if building.get("id", "") != action.get("building_id", ""):
			new_buildings.append(building)
		else:
			demolished_name = MCSTypes.get_building_name(building.get("type", 0))

	if demolished_name.is_empty():
		return state

	# Return some materials
	var new_resources = state.get("resources", {}).duplicate(true)
	new_resources["building_materials"] = new_resources.get("building_materials", 0.0) + 25.0  # Salvage value

	var new_log = state.get("mission_log", []).duplicate()
	new_log.append({
		"year": state.get("current_year", 1),
		"message": "%s has been demolished. Materials salvaged." % demolished_name,
		"log_type": "info"
	})

	return _with_fields(state, {
		"buildings": new_buildings,
		"resources": new_resources,
		"mission_log": new_log
	})

static func _reduce_repair_building(state: Dictionary, action: Dictionary) -> Dictionary:
	var result = MCSEconomy.repair_building(
		state.get("buildings", []),
		state.get("resources", {}),
		action.get("building_id", "")
	)

	if not result.get("success", false):
		return state

	var new_log = state.get("mission_log", []).duplicate()
	new_log.append({
		"year": state.get("current_year", 1),
		"message": "Building repaired and back online.",
		"log_type": "success"
	})

	return _with_fields(state, {
		"buildings": result.get("buildings", []),
		"resources": result.get("resources", {}),
		"mission_log": new_log
	})

static func _reduce_update_resource(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_resources = state.get("resources", {}).duplicate(true)
	var resource_name = MCSTypes.get_resource_name(action.get("resource_type", 0))
	new_resources[resource_name] = maxf(0, new_resources.get(resource_name, 0) + action.get("delta", 0))

	return _with_field(state, "resources", new_resources)

static func _reduce_apply_production(state: Dictionary, _action: Dictionary) -> Dictionary:
	var buildings = state.get("buildings", [])
	var colonists = state.get("colonists", [])
	var resources = state.get("resources", {})
	var production = MCSEconomy.calc_yearly_production(buildings, colonists, resources)

	var new_resources = resources.duplicate(true)
	for key in production.keys():
		new_resources[key] = new_resources.get(key, 0) + production[key]

	return _with_field(state, "resources", new_resources)

static func _reduce_apply_consumption(state: Dictionary, _action: Dictionary) -> Dictionary:
	var colonists = state.get("colonists", [])
	var buildings = state.get("buildings", [])
	var consumption = MCSEconomy.calc_yearly_consumption(colonists, buildings)

	var new_resources = state.get("resources", {}).duplicate(true)
	for key in consumption.keys():
		new_resources[key] = maxf(0, new_resources.get(key, 0) - consumption[key])

	return _with_field(state, "resources", new_resources)

static func _reduce_assign_worker(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_buildings: Array = []

	for building in state.get("buildings", []):
		if building.get("id", "") == action.get("building_id", ""):
			var updated = building.duplicate(true)
			var workers = updated.get("assigned_workers", [])
			if action.get("colonist_id", "") not in workers:
				workers.append(action.get("colonist_id", ""))
			updated["assigned_workers"] = workers
			new_buildings.append(updated)
		else:
			new_buildings.append(building)

	return _with_field(state, "buildings", new_buildings)

static func _reduce_unassign_worker(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_buildings: Array = []
	var colonist_id = action.get("colonist_id", "")

	for building in state.get("buildings", []):
		var updated = building.duplicate(true)
		var workers = updated.get("assigned_workers", [])
		updated["assigned_workers"] = workers.filter(func(id): return id != colonist_id)
		new_buildings.append(updated)

	return _with_field(state, "buildings", new_buildings)

static func _reduce_auto_assign_workers(state: Dictionary, _action: Dictionary) -> Dictionary:
	var colonists = state.get("colonists", [])
	var buildings = state.get("buildings", [])
	var result = MCSEconomy.auto_assign_workers(colonists, buildings)
	return _with_field(state, "buildings", result.get("buildings", buildings))

static func _reduce_hold_election(state: Dictionary, action: Dictionary) -> Dictionary:
	var politics = state.get("politics", {})
	var colonists = state.get("colonists", [])
	var result = MCSPolitics.hold_election(politics, colonists, action.get("random_values", []))

	var new_log = state.get("mission_log", []).duplicate()
	new_log.append({
		"year": state.get("current_year", 1),
		"message": "Colony election: %s" % result.get("summary", ""),
		"log_type": "politics"
	})

	return _with_fields(state, {
		"politics": result.get("politics", {}),
		"mission_log": new_log
	})

static func _reduce_change_government(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_politics = state.get("politics", {}).duplicate(true)
	new_politics["government_type"] = action.get("new_system", 0)

	var new_log = state.get("mission_log", []).duplicate()
	new_log.append({
		"year": state.get("current_year", 1),
		"message": "Government changed to: %s" % MCSTypes.get_political_system_name(action.get("new_system", 0)),
		"log_type": "politics"
	})

	return _with_fields(state, {
		"politics": new_politics,
		"mission_log": new_log
	})

static func _reduce_update_faction_standings(state: Dictionary, _action: Dictionary) -> Dictionary:
	var politics = state.get("politics", {})
	var colonists = state.get("colonists", [])
	var resources = state.get("resources", {})
	var new_politics = MCSPolitics.update_faction_standings(politics, colonists, resources)
	return _with_field(state, "politics", new_politics)

static func _reduce_hold_independence_vote(state: Dictionary, action: Dictionary) -> Dictionary:
	var politics = state.get("politics", {})
	var colonists = state.get("colonists", [])
	var result = MCSPolitics.hold_independence_vote(politics, colonists, action.get("random_value", 0.5))

	var new_log = state.get("mission_log", []).duplicate()

	var current_year = state.get("current_year", 1)
	if result.get("passed", false):
		new_log.append({
			"year": current_year,
			"message": "INDEPENDENCE DECLARED! Mars is now a sovereign world!",
			"log_type": "milestone"
		})
	else:
		new_log.append({
			"year": current_year,
			"message": "Independence vote failed. The colony remains tied to Earth.",
			"log_type": "politics"
		})

	return _with_fields(state, {
		"politics": result.get("politics", {}),
		"is_independent": result.get("passed", false),
		"mission_log": new_log
	})

static func _reduce_trigger_event(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_active_events = state.get("active_events", []).duplicate()
	var event = action.get("event", {})
	new_active_events.append(event)

	var new_log = state.get("mission_log", []).duplicate()
	new_log.append({
		"year": state.get("current_year", 1),
		"message": "EVENT: %s" % event.get("title", "Unknown"),
		"log_type": "event"
	})

	return _with_fields(state, {
		"active_events": new_active_events,
		"mission_log": new_log
	})

static func _reduce_resolve_event_choice(state: Dictionary, action: Dictionary) -> Dictionary:
	var active_events = state.get("active_events", [])
	var event = null
	var event_index = -1

	for i in range(active_events.size()):
		var e = active_events[i]
		if e.get("id", "") == action.get("event_id", ""):
			event = e
			event_index = i
			break

	if event == null:
		return state

	# Apply choice effects
	var result = MCSEvents.apply_event_choice(
		state,
		event,
		action.get("choice_index", 0),
		action.get("random_value", 0.5)
	)

	# Remove from active events
	var new_active = active_events.duplicate()
	new_active.remove_at(event_index)

	# Add to resolved
	var new_resolved = state.get("resolved_events", []).duplicate()
	new_resolved.append({
		"event_id": event.get("id", ""),
		"choice_index": action.get("choice_index", 0),
		"year": state.get("current_year", 1),
		"outcome": result.get("outcome", "")
	})

	# Merge result state with event removal
	var final_state = _with_fields(result.get("state", state), {
		"active_events": new_active,
		"resolved_events": new_resolved
	})

	# Add outcome to log
	var new_log = final_state.get("mission_log", []).duplicate()
	new_log.append({
		"year": state.get("current_year", 1),
		"message": result.get("outcome", ""),
		"log_type": "event"
	})
	final_state["mission_log"] = new_log

	return final_state

static func _reduce_add_log(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_log = state.get("mission_log", []).duplicate()
	var action_year = action.get("year", -1)
	new_log.append({
		"year": action_year if action_year >= 0 else state.get("current_year", 1),
		"message": action.get("message", ""),
		"log_type": action.get("log_type", "info")
	})

	return _with_field(state, "mission_log", new_log)

static func _reduce_check_victory(state: Dictionary, _action: Dictionary) -> Dictionary:
	var updates: Dictionary = {}
	var colonists = state.get("colonists", [])
	var politics = state.get("politics", {})
	var stability = politics.get("stability", 75.0)
	var is_independent = state.get("is_independent", false)
	var current_year = state.get("current_year", 1)

	# Check loss conditions
	if colonists.size() == 0:
		updates["game_over"] = true
		updates["victory"] = false
		updates["end_reason"] = "Colony has perished. No survivors remain."
	elif stability <= 0:
		updates["game_over"] = true
		updates["victory"] = false
		updates["end_reason"] = "Colony collapsed due to civil unrest."

	# Check victory conditions
	elif is_independent and colonists.size() >= 1000:
		updates["game_over"] = true
		updates["victory"] = true
		updates["end_reason"] = "Mars is free! A thriving nation of %d souls has secured humanity's future." % colonists.size()
	elif current_year >= 100 and colonists.size() >= 500:
		updates["game_over"] = true
		updates["victory"] = true
		updates["end_reason"] = "After 100 years, the colony stands strong. Humanity has become a multi-planetary species."

	if updates.is_empty():
		return state

	var new_log = state.get("mission_log", []).duplicate()
	new_log.append({
		"year": current_year,
		"message": updates.get("end_reason", ""),
		"log_type": "milestone" if updates.get("victory", false) else "crisis"
	})
	updates["mission_log"] = new_log

	return _with_fields(state, updates)

static func _reduce_end_colony(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_log = state.get("mission_log", []).duplicate()
	var is_victory = action.get("is_victory", false)
	var reason = action.get("reason", "")
	new_log.append({
		"year": state.get("current_year", 1),
		"message": reason,
		"log_type": "milestone" if is_victory else "crisis"
	})

	return _with_fields(state, {
		"game_over": true,
		"victory": is_victory,
		"end_reason": reason,
		"mission_log": new_log
	})

# ============================================================================
# HELPERS
# ============================================================================

static func _check_phase_transition(current_phase: int, state_updates: Dictionary, year: int) -> int:
	var pop_count = state_updates.get("colonists", []).size()

	match current_phase:
		MCSTypes.ColonyPhase.ACT_1_FOUNDERS:
			# Transition to ACT_2_SETTLEMENT when stable food + 30 pop + year 5
			if year >= 5 and pop_count >= 30:
				var resources = state_updates.get("resources", {})
				if resources.get("food", 0) >= 100:
					return MCSTypes.ColonyPhase.ACT_2_SETTLEMENT

		MCSTypes.ColonyPhase.ACT_2_SETTLEMENT:
			# Transition to ACT_3_COLONY when 100 pop + year 20
			if year >= 20 and pop_count >= 100:
				return MCSTypes.ColonyPhase.ACT_3_COLONY

		MCSTypes.ColonyPhase.ACT_3_COLONY:
			# Transition to ACT_4_INDEPENDENCE when 300 pop + year 50
			if year >= 50 and pop_count >= 300:
				return MCSTypes.ColonyPhase.ACT_4_INDEPENDENCE

	return current_phase

## Immutable-style field update
static func _with_field(dict: Dictionary, key: String, value) -> Dictionary:
	var new_dict = dict.duplicate(true)
	new_dict[key] = value
	return new_dict

## Immutable-style multi-field update
static func _with_fields(dict: Dictionary, updates: Dictionary) -> Dictionary:
	var new_dict = dict.duplicate(true)
	for key in updates.keys():
		new_dict[key] = updates[key]
	return new_dict
