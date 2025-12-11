class_name ColonySimReducer
extends RefCounted

## Redux-style reducer for colony simulation state
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
	var new_state = ColonySimTypes.create_colony_state()
	new_state.random_seed = action.seed
	new_state.colony_phase = ColonySimTypes.ColonyPhase.ACT_1_FOUNDERS
	new_state.current_year = 1

	# Add founders
	for founder in action.founders:
		new_state.colonists.append(founder)

	# Create starting buildings
	var hab = ColonySimTypes.create_building(ColonySimTypes.BuildingType.HAB_POD)
	hab.id = "hab_001"
	hab.is_operational = true
	hab.construction_progress = 1.0
	new_state.buildings.append(hab)

	var farm = ColonySimTypes.create_building(ColonySimTypes.BuildingType.GREENHOUSE)
	farm.id = "farm_001"
	farm.is_operational = true
	farm.construction_progress = 1.0
	new_state.buildings.append(farm)

	var power = ColonySimTypes.create_building(ColonySimTypes.BuildingType.SOLAR_ARRAY)
	power.id = "solar_001"
	power.is_operational = true
	power.construction_progress = 1.0
	new_state.buildings.append(power)

	# Starting resources (tight margins for tension!)
	new_state.resources.food = 200.0  # ~1 year for small crew
	new_state.resources.water = 150.0
	new_state.resources.oxygen = 100.0
	new_state.resources.fuel = 50.0
	new_state.resources.building_materials = 100.0

	# Initialize log
	new_state.mission_log = [{
		"year": 1,
		"message": "Colony founded on Mars. %d pioneers begin humanity's greatest adventure." % action.founders.size(),
		"log_type": "milestone"
	}]

	return new_state

static func _reduce_advance_year(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_year = state.current_year + 1
	var updates: Dictionary = {"current_year": new_year}
	var new_log = state.mission_log.duplicate()
	var rand_idx = 0

	# === POPULATION PHASE ===
	var pop_result = ColonySimPopulation.advance_year(
		state.colonists,
		state.resources,
		state.buildings,
		action.random_values.slice(rand_idx, rand_idx + state.colonists.size() * 5)
	)
	rand_idx += state.colonists.size() * 5

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
	var production = ColonySimEconomy.calc_yearly_production(
		state.buildings,
		updates["colonists"],
		state.resources
	)
	var consumption = ColonySimEconomy.calc_yearly_consumption(
		updates["colonists"],
		state.buildings
	)

	var resource_result = ColonySimEconomy.apply_yearly_resources(
		state.resources,
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
	var maint_rand = action.random_values[rand_idx] if rand_idx < action.random_values.size() else 0.5
	rand_idx += 1
	var maint_result = ColonySimEconomy.apply_building_maintenance(
		state.buildings,
		updates["resources"],
		maint_rand
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
	var pol_result = ColonySimPolitics.update_faction_standings(
		state.politics,
		updates["colonists"],
		updates["resources"]
	)
	updates["politics"] = pol_result

	# Check for election year (every 4 years after year 5)
	if new_year >= 5 and (new_year - 5) % 4 == 0:
		var election_rand = action.random_values.slice(rand_idx, rand_idx + 10)
		rand_idx += 10
		var election_result = ColonySimPolitics.hold_election(
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
	updates["politics"] = ColonySimPolitics.update_stability(
		updates["politics"],
		updates["colonists"],
		updates["resources"],
		resource_result.shortages.size() > 0
	)

	# === PHASE TRANSITIONS ===
	updates["colony_phase"] = _check_phase_transition(state.colony_phase, updates, new_year)
	if updates["colony_phase"] != state.colony_phase:
		new_log.append({
			"year": new_year,
			"message": "Colony has entered a new era: %s" % ColonySimTypes.get_phase_name(updates["colony_phase"]),
			"log_type": "milestone"
		})

	updates["mission_log"] = new_log

	return _with_fields(state, updates)

static func _reduce_add_colonist(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_colonists = state.colonists.duplicate()
	new_colonists.append(action.colonist)

	var new_log = state.mission_log.duplicate()
	new_log.append({
		"year": state.current_year,
		"message": "%s has joined the colony." % action.colonist.display_name,
		"log_type": "info"
	})

	return _with_fields(state, {
		"colonists": new_colonists,
		"mission_log": new_log
	})

static func _reduce_remove_colonist(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_colonists: Array = []
	var removed_name = ""

	for colonist in state.colonists:
		if colonist.id != action.colonist_id:
			new_colonists.append(colonist)
		else:
			removed_name = colonist.display_name

	if removed_name.is_empty():
		return state

	var new_log = state.mission_log.duplicate()
	new_log.append({
		"year": state.current_year,
		"message": "%s has left the colony. Reason: %s" % [removed_name, action.reason],
		"log_type": "info"
	})

	return _with_fields(state, {
		"colonists": new_colonists,
		"mission_log": new_log
	})

static func _reduce_update_colonist(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_colonists: Array = []
	for colonist in state.colonists:
		if colonist.id == action.colonist_id:
			new_colonists.append(_with_fields(colonist, action.updates))
		else:
			new_colonists.append(colonist)

	return _with_field(state, "colonists", new_colonists)

static func _reduce_start_construction(state: Dictionary, action: Dictionary) -> Dictionary:
	var result = ColonySimEconomy.start_construction(
		state.buildings,
		state.resources,
		action.building_type,
		action.priority
	)

	if not result.success:
		return state

	var new_log = state.mission_log.duplicate()
	new_log.append({
		"year": state.current_year,
		"message": "Construction started: %s" % ColonySimTypes.get_building_name(action.building_type),
		"log_type": "info"
	})

	return _with_fields(state, {
		"buildings": result.buildings,
		"resources": result.resources,
		"mission_log": new_log
	})

static func _reduce_complete_construction(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_buildings: Array = []
	var completed_name = ""

	for building in state.buildings:
		if building.id == action.building_id:
			var updated = building.duplicate(true)
			updated.is_operational = true
			updated.construction_progress = 1.0
			new_buildings.append(updated)
			completed_name = ColonySimTypes.get_building_name(building.type)
		else:
			new_buildings.append(building)

	if completed_name.is_empty():
		return state

	var new_log = state.mission_log.duplicate()
	new_log.append({
		"year": state.current_year,
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

	for building in state.buildings:
		if building.id != action.building_id:
			new_buildings.append(building)
		else:
			demolished_name = ColonySimTypes.get_building_name(building.type)

	if demolished_name.is_empty():
		return state

	# Return some materials
	var new_resources = state.resources.duplicate(true)
	new_resources.materials += 25.0  # Salvage value

	var new_log = state.mission_log.duplicate()
	new_log.append({
		"year": state.current_year,
		"message": "%s has been demolished. Materials salvaged." % demolished_name,
		"log_type": "info"
	})

	return _with_fields(state, {
		"buildings": new_buildings,
		"resources": new_resources,
		"mission_log": new_log
	})

static func _reduce_repair_building(state: Dictionary, action: Dictionary) -> Dictionary:
	var result = ColonySimEconomy.repair_building(
		state.buildings,
		state.resources,
		action.building_id
	)

	if not result.success:
		return state

	var new_log = state.mission_log.duplicate()
	new_log.append({
		"year": state.current_year,
		"message": "Building repaired and back online.",
		"log_type": "success"
	})

	return _with_fields(state, {
		"buildings": result.buildings,
		"resources": result.resources,
		"mission_log": new_log
	})

static func _reduce_update_resource(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_resources = state.resources.duplicate(true)
	var resource_name = ColonySimTypes.get_resource_name(action.resource_type)
	new_resources[resource_name] = maxf(0, new_resources.get(resource_name, 0) + action.delta)

	return _with_field(state, "resources", new_resources)

static func _reduce_apply_production(state: Dictionary, action: Dictionary) -> Dictionary:
	var production = ColonySimEconomy.calc_yearly_production(
		state.buildings,
		state.colonists,
		state.resources
	)

	var new_resources = state.resources.duplicate(true)
	for key in production.keys():
		new_resources[key] = new_resources.get(key, 0) + production[key]

	return _with_field(state, "resources", new_resources)

static func _reduce_apply_consumption(state: Dictionary, _action: Dictionary) -> Dictionary:
	var consumption = ColonySimEconomy.calc_yearly_consumption(state.colonists, state.buildings)

	var new_resources = state.resources.duplicate(true)
	for key in consumption.keys():
		new_resources[key] = maxf(0, new_resources.get(key, 0) - consumption[key])

	return _with_field(state, "resources", new_resources)

static func _reduce_assign_worker(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_buildings: Array = []

	for building in state.buildings:
		if building.id == action.building_id:
			var updated = building.duplicate(true)
			if action.colonist_id not in updated.assigned_workers:
				updated.assigned_workers.append(action.colonist_id)
			new_buildings.append(updated)
		else:
			new_buildings.append(building)

	return _with_field(state, "buildings", new_buildings)

static func _reduce_unassign_worker(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_buildings: Array = []

	for building in state.buildings:
		var updated = building.duplicate(true)
		updated.assigned_workers = updated.assigned_workers.filter(
			func(id): return id != action.colonist_id
		)
		new_buildings.append(updated)

	return _with_field(state, "buildings", new_buildings)

static func _reduce_auto_assign_workers(state: Dictionary, _action: Dictionary) -> Dictionary:
	var result = ColonySimEconomy.auto_assign_workers(state.colonists, state.buildings)
	return _with_field(state, "buildings", result)

static func _reduce_hold_election(state: Dictionary, action: Dictionary) -> Dictionary:
	var result = ColonySimPolitics.hold_election(
		state.politics,
		state.colonists,
		action.random_values
	)

	var new_log = state.mission_log.duplicate()
	new_log.append({
		"year": state.current_year,
		"message": "Colony election: %s" % result.summary,
		"log_type": "politics"
	})

	return _with_fields(state, {
		"politics": result.politics,
		"mission_log": new_log
	})

static func _reduce_change_government(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_politics = state.politics.duplicate(true)
	new_politics.government_type = action.new_system

	var new_log = state.mission_log.duplicate()
	new_log.append({
		"year": state.current_year,
		"message": "Government changed to: %s" % ColonySimTypes.get_politics_system_name(action.new_system),
		"log_type": "politics"
	})

	return _with_fields(state, {
		"politics": new_politics,
		"mission_log": new_log
	})

static func _reduce_update_faction_standings(state: Dictionary, _action: Dictionary) -> Dictionary:
	var new_politics = ColonySimPolitics.update_faction_standings(
		state.politics,
		state.colonists,
		state.resources
	)
	return _with_field(state, "politics", new_politics)

static func _reduce_hold_independence_vote(state: Dictionary, action: Dictionary) -> Dictionary:
	var result = ColonySimPolitics.hold_independence_vote(
		state.politics,
		state.colonists,
		action.random_value
	)

	var new_log = state.mission_log.duplicate()

	if result.passed:
		new_log.append({
			"year": state.current_year,
			"message": "INDEPENDENCE DECLARED! Mars is now a sovereign world!",
			"log_type": "milestone"
		})
	else:
		new_log.append({
			"year": state.current_year,
			"message": "Independence vote failed. The colony remains tied to Earth.",
			"log_type": "politics"
		})

	return _with_fields(state, {
		"politics": result.politics,
		"is_independent": result.passed,
		"mission_log": new_log
	})

static func _reduce_trigger_event(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_active_events = state.active_events.duplicate()
	new_active_events.append(action.event)

	var new_log = state.mission_log.duplicate()
	new_log.append({
		"year": state.current_year,
		"message": "EVENT: %s" % action.event.title,
		"log_type": "event"
	})

	return _with_fields(state, {
		"active_events": new_active_events,
		"mission_log": new_log
	})

static func _reduce_resolve_event_choice(state: Dictionary, action: Dictionary) -> Dictionary:
	var event = null
	var event_index = -1

	for i in range(state.active_events.size()):
		if state.active_events[i].id == action.event_id:
			event = state.active_events[i]
			event_index = i
			break

	if event == null:
		return state

	# Apply choice effects
	var result = ColonySimEvents.apply_event_choice(
		state,
		event,
		action.choice_index,
		action.random_value
	)

	# Remove from active events
	var new_active = state.active_events.duplicate()
	new_active.remove_at(event_index)

	# Add to resolved
	var new_resolved = state.resolved_events.duplicate()
	new_resolved.append({
		"event_id": event.id,
		"choice_index": action.choice_index,
		"year": state.current_year,
		"outcome": result.outcome
	})

	# Merge result state with event removal
	var final_state = _with_fields(result.state, {
		"active_events": new_active,
		"resolved_events": new_resolved
	})

	# Add outcome to log
	var new_log = final_state.mission_log.duplicate()
	new_log.append({
		"year": state.current_year,
		"message": result.outcome,
		"log_type": "event"
	})
	final_state.mission_log = new_log

	return final_state

static func _reduce_add_log(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_log = state.mission_log.duplicate()
	new_log.append({
		"year": action.year if action.year >= 0 else state.current_year,
		"message": action.message,
		"log_type": action.log_type
	})

	return _with_field(state, "mission_log", new_log)

static func _reduce_check_victory(state: Dictionary, _action: Dictionary) -> Dictionary:
	var updates: Dictionary = {}

	# Check loss conditions
	if state.colonists.size() == 0:
		updates["game_over"] = true
		updates["victory"] = false
		updates["end_reason"] = "Colony has perished. No survivors remain."
	elif state.politics.stability <= 0:
		updates["game_over"] = true
		updates["victory"] = false
		updates["end_reason"] = "Colony collapsed due to civil unrest."

	# Check victory conditions
	elif state.is_independent and state.colonists.size() >= 1000:
		updates["game_over"] = true
		updates["victory"] = true
		updates["end_reason"] = "Mars is free! A thriving nation of %d souls has secured humanity's future." % state.colonists.size()
	elif state.current_year >= 100 and state.colonists.size() >= 500:
		updates["game_over"] = true
		updates["victory"] = true
		updates["end_reason"] = "After 100 years, the colony stands strong. Humanity has become a multi-planetary species."

	if updates.is_empty():
		return state

	var new_log = state.mission_log.duplicate()
	new_log.append({
		"year": state.current_year,
		"message": updates.end_reason,
		"log_type": "milestone" if updates.victory else "crisis"
	})
	updates["mission_log"] = new_log

	return _with_fields(state, updates)

static func _reduce_end_colony(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_log = state.mission_log.duplicate()
	new_log.append({
		"year": state.current_year,
		"message": action.reason,
		"log_type": "milestone" if action.is_victory else "crisis"
	})

	return _with_fields(state, {
		"game_over": true,
		"victory": action.is_victory,
		"end_reason": action.reason,
		"mission_log": new_log
	})

# ============================================================================
# HELPERS
# ============================================================================

static func _check_phase_transition(current_phase: int, state_updates: Dictionary, year: int) -> int:
	var pop_count = state_updates.get("colonists", []).size()

	match current_phase:
		ColonySimTypes.ColonyPhase.SURVIVAL:
			# Transition to GROWTH when stable food + 50 pop + year 5
			if year >= 5 and pop_count >= 50:
				var resources = state_updates.get("resources", {})
				if resources.get("food", 0) >= 100:
					return ColonySimTypes.ColonyPhase.GROWTH

		ColonySimTypes.ColonyPhase.GROWTH:
			# Transition to SOCIETY when 200 pop + year 20
			if year >= 20 and pop_count >= 200:
				return ColonySimTypes.ColonyPhase.SOCIETY

		ColonySimTypes.ColonyPhase.SOCIETY:
			# Transition to LEGACY when 500 pop + year 50
			if year >= 50 and pop_count >= 500:
				return ColonySimTypes.ColonyPhase.LEGACY

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
