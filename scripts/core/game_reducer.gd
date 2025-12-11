class_name GameReducer
extends RefCounted

## Redux-style reducer for game state
## All functions are pure: (state, action) -> new_state
## No side effects, fully deterministic with provided random values

# ============================================================================
# ACTION TYPES
# ============================================================================

enum ActionType {
	# Game flow
	START_NEW_GAME,
	ADVANCE_DAY,
	CHANGE_PHASE,

	# Ship building
	PLACE_COMPONENT,
	REMOVE_COMPONENT,
	START_COMPONENT_TEST,
	COMPLETE_COMPONENT_TEST,
	SELECT_ENGINE,

	# Crew
	ADD_CREW_MEMBER,
	REMOVE_CREW_MEMBER,
	UPDATE_CREW,
	ASSIGN_CREW_ACTIVITY,

	# Budget
	SPEND_BUDGET,
	ADD_BUDGET,

	# Cargo
	UPDATE_CARGO,

	# Travel
	START_TRAVEL,
	ADVANCE_TRAVEL_DAY,

	# Mars Base
	START_MARS_OPERATIONS,
	CONDUCT_EXPERIMENT,
	ADVANCE_MARS_SOL,

	# Events
	APPLY_EVENT,

	# Logging
	ADD_LOG_ENTRY,

	# Component updates
	UPDATE_COMPONENT
}

# ============================================================================
# MAIN REDUCER
# ============================================================================

## Main reducer function - dispatches to specific handlers
static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	match action.type:
		ActionType.START_NEW_GAME:
			return _reduce_start_new_game(state, action)
		ActionType.ADVANCE_DAY:
			return _reduce_advance_day(state, action)
		ActionType.CHANGE_PHASE:
			return _reduce_change_phase(state, action)
		ActionType.PLACE_COMPONENT:
			return _reduce_place_component(state, action)
		ActionType.REMOVE_COMPONENT:
			return _reduce_remove_component(state, action)
		ActionType.START_COMPONENT_TEST:
			return _reduce_start_test(state, action)
		ActionType.COMPLETE_COMPONENT_TEST:
			return _reduce_complete_test(state, action)
		ActionType.SELECT_ENGINE:
			return _reduce_select_engine(state, action)
		ActionType.ADD_CREW_MEMBER:
			return _reduce_add_crew(state, action)
		ActionType.REMOVE_CREW_MEMBER:
			return _reduce_remove_crew(state, action)
		ActionType.UPDATE_CREW:
			return _reduce_update_crew(state, action)
		ActionType.SPEND_BUDGET:
			return _reduce_spend_budget(state, action)
		ActionType.ADD_BUDGET:
			return _reduce_add_budget(state, action)
		ActionType.UPDATE_CARGO:
			return _reduce_update_cargo(state, action)
		ActionType.APPLY_EVENT:
			return _reduce_apply_event(state, action)
		ActionType.ADD_LOG_ENTRY:
			return _reduce_add_log(state, action)
		ActionType.ASSIGN_CREW_ACTIVITY:
			return _reduce_assign_activity(state, action)
		ActionType.START_TRAVEL:
			return _reduce_start_travel(state, action)
		ActionType.ADVANCE_TRAVEL_DAY:
			return _reduce_advance_travel_day(state, action)
		ActionType.START_MARS_OPERATIONS:
			return _reduce_start_mars_operations(state, action)
		ActionType.CONDUCT_EXPERIMENT:
			return _reduce_conduct_experiment(state, action)
		ActionType.ADVANCE_MARS_SOL:
			return _reduce_advance_mars_sol(state, action)
		ActionType.UPDATE_COMPONENT:
			return _reduce_update_component(state, action)
		_:
			return state

# ============================================================================
# ACTION CREATORS (pure functions that create action dictionaries)
# ============================================================================

static func action_start_new_game(seed_value: int = 0) -> Dictionary:
	return {
		"type": ActionType.START_NEW_GAME,
		"seed": seed_value if seed_value > 0 else int(Time.get_unix_time_from_system())
	}

static func action_advance_day(days: int = 1, random_values: Array = []) -> Dictionary:
	return {
		"type": ActionType.ADVANCE_DAY,
		"days": days,
		"random_values": random_values
	}

static func action_change_phase(new_phase: GameTypes.GamePhase) -> Dictionary:
	return {
		"type": ActionType.CHANGE_PHASE,
		"phase": new_phase
	}

static func action_place_component(component: Dictionary, position: Vector2i) -> Dictionary:
	return {
		"type": ActionType.PLACE_COMPONENT,
		"component": component,
		"position": position
	}

static func action_remove_component(position: Vector2i) -> Dictionary:
	return {
		"type": ActionType.REMOVE_COMPONENT,
		"position": position
	}

static func action_start_test(component_position: Vector2i) -> Dictionary:
	return {
		"type": ActionType.START_COMPONENT_TEST,
		"position": component_position
	}

static func action_complete_test(component_position: Vector2i, random_value: float) -> Dictionary:
	return {
		"type": ActionType.COMPLETE_COMPONENT_TEST,
		"position": component_position,
		"random_value": random_value
	}

static func action_select_engine(engine: Dictionary) -> Dictionary:
	return {
		"type": ActionType.SELECT_ENGINE,
		"engine": engine
	}

static func action_add_crew(crew_member: Dictionary) -> Dictionary:
	return {
		"type": ActionType.ADD_CREW_MEMBER,
		"crew_member": crew_member
	}

static func action_remove_crew(crew_id: String) -> Dictionary:
	return {
		"type": ActionType.REMOVE_CREW_MEMBER,
		"crew_id": crew_id
	}

static func action_update_crew(crew_id: String, updates: Dictionary) -> Dictionary:
	return {
		"type": ActionType.UPDATE_CREW,
		"crew_id": crew_id,
		"updates": updates
	}

static func action_spend_budget(amount: int) -> Dictionary:
	return {
		"type": ActionType.SPEND_BUDGET,
		"amount": amount
	}

static func action_add_budget(amount: int) -> Dictionary:
	return {
		"type": ActionType.ADD_BUDGET,
		"amount": amount
	}

static func action_update_cargo(key: String, value) -> Dictionary:
	return {
		"type": ActionType.UPDATE_CARGO,
		"key": key,
		"value": value
	}

static func action_apply_event(event: Dictionary) -> Dictionary:
	return {
		"type": ActionType.APPLY_EVENT,
		"event": event
	}

static func action_add_log(message: String, event_type: String = "info") -> Dictionary:
	return {
		"type": ActionType.ADD_LOG_ENTRY,
		"message": message,
		"event_type": event_type
	}

static func action_assign_activity(crew_id: String, activity_id: String, random_value: float = 0.5) -> Dictionary:
	return {
		"type": ActionType.ASSIGN_CREW_ACTIVITY,
		"crew_id": crew_id,
		"activity_id": activity_id,
		"random_value": random_value
	}

static func action_start_travel(travel_days: int) -> Dictionary:
	return {
		"type": ActionType.START_TRAVEL,
		"travel_days": travel_days
	}

static func action_advance_travel_day(random_values: Array) -> Dictionary:
	return {
		"type": ActionType.ADVANCE_TRAVEL_DAY,
		"random_values": random_values
	}

static func action_start_mars_operations() -> Dictionary:
	return {
		"type": ActionType.START_MARS_OPERATIONS
	}

static func action_conduct_experiment(experiment_id: String, crew_id: String, random_value: float) -> Dictionary:
	return {
		"type": ActionType.CONDUCT_EXPERIMENT,
		"experiment_id": experiment_id,
		"crew_id": crew_id,
		"random_value": random_value
	}

static func action_advance_mars_sol() -> Dictionary:
	return {
		"type": ActionType.ADVANCE_MARS_SOL
	}

static func action_update_component(position: Vector2i, component: Dictionary) -> Dictionary:
	return {
		"type": ActionType.UPDATE_COMPONENT,
		"position": position,
		"component": component
	}

# ============================================================================
# REDUCER IMPLEMENTATIONS (all pure)
# ============================================================================

static func _reduce_start_new_game(_state: Dictionary, action: Dictionary) -> Dictionary:
	return GameTypes.create_game_state({
		"current_phase": GameTypes.GamePhase.SHIP_BUILDING,
		"random_seed": action.seed,
		"mission_log": [
			GameTypes.create_log_entry(1, "Mission initialized. Construction begins on Luna Base.", "info")
		]
	})

static func _reduce_advance_day(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_day = state.current_day + action.days
	var updates = {"current_day": new_day}

	# Process construction queue
	var construction_result = ShipLogic.advance_construction_day(state.ship_components)
	updates["ship_components"] = construction_result.components

	# Process crew daily updates
	var new_crew: Array = []
	var random_idx = 0
	for crew in state.crew:
		var rand_val = action.random_values[random_idx] if random_idx < action.random_values.size() else 0.5
		new_crew.append(CrewLogic.apply_daily_update(crew, rand_val))
		random_idx += 1
	updates["crew"] = new_crew

	# Add completion log entries
	var new_log = state.mission_log.duplicate()
	for completed in construction_result.completed:
		new_log.append(GameTypes.create_log_entry(
			new_day,
			"%s construction complete!" % completed.display_name,
			"success"
		))
	updates["mission_log"] = new_log

	return GameTypes.with_fields(state, updates)

static func _reduce_change_phase(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_log = state.mission_log.duplicate()
	new_log.append(GameTypes.create_log_entry(
		state.current_day,
		"Phase changed to: %s" % GameTypes.GamePhase.keys()[action.phase],
		"info"
	))
	return GameTypes.with_fields(state, {
		"current_phase": action.phase,
		"mission_log": new_log
	})

static func _reduce_place_component(state: Dictionary, action: Dictionary) -> Dictionary:
	var valid_positions = state.ship_hex_grid.keys()
	if valid_positions.is_empty():
		valid_positions = _generate_default_grid_positions()

	# Check if we can afford it
	if action.component.base_cost > state.budget:
		return state

	# Check if we can place it
	if not ShipLogic.can_place_component(
		state.ship_hex_grid,
		action.position,
		action.component.hex_size,
		valid_positions
	):
		return state

	# Start construction
	var building_component = ComponentLogic.start_construction(action.component)

	# Place on grid
	var place_result = ShipLogic.place_component(
		state.ship_hex_grid,
		building_component,
		action.position,
		valid_positions
	)

	# Update components list
	var new_components = state.ship_components.duplicate()
	new_components.append(place_result.component)

	# Add log entry
	var new_log = state.mission_log.duplicate()
	new_log.append(GameTypes.create_log_entry(
		state.current_day,
		"Started building %s" % action.component.display_name,
		"info"
	))

	return GameTypes.with_fields(state, {
		"ship_hex_grid": place_result.grid,
		"ship_components": new_components,
		"budget": state.budget - action.component.base_cost,
		"total_spent": state.total_spent + action.component.base_cost,
		"mission_log": new_log
	})

static func _reduce_remove_component(state: Dictionary, action: Dictionary) -> Dictionary:
	var valid_positions = state.ship_hex_grid.keys()
	if valid_positions.is_empty():
		valid_positions = _generate_default_grid_positions()

	var remove_result = ShipLogic.remove_component(
		state.ship_hex_grid,
		action.position,
		valid_positions
	)

	if remove_result.component.is_empty():
		return state

	# Remove from components list
	var new_components: Array = []
	for comp in state.ship_components:
		if comp.hex_position != remove_result.component.hex_position:
			new_components.append(comp)

	# Calculate refund
	var refund = ShipLogic.calc_refund(remove_result.component)

	# Add log entry
	var new_log = state.mission_log.duplicate()
	new_log.append(GameTypes.create_log_entry(
		state.current_day,
		"Removed %s (refunded $%d)" % [remove_result.component.display_name, refund],
		"info"
	))

	return GameTypes.with_fields(state, {
		"ship_hex_grid": remove_result.grid,
		"ship_components": new_components,
		"budget": state.budget + refund,
		"mission_log": new_log
	})

static func _reduce_start_test(state: Dictionary, action: Dictionary) -> Dictionary:
	var component = ShipLogic.get_component_at(state.ship_hex_grid, action.position)
	if component.is_empty() or not component.is_built:
		return state

	if component.test_cost_per_cycle > state.budget:
		return state

	return GameTypes.with_fields(state, {
		"budget": state.budget - component.test_cost_per_cycle,
		"total_spent": state.total_spent + component.test_cost_per_cycle
	})

static func _reduce_complete_test(state: Dictionary, action: Dictionary) -> Dictionary:
	var component = ShipLogic.get_component_at(state.ship_hex_grid, action.position)
	if component.is_empty():
		return state

	var test_result = ComponentLogic.apply_test(component, action.random_value)

	# Update in grid
	var new_grid = state.ship_hex_grid.duplicate(true)
	var valid_positions = new_grid.keys()
	var hexes = ShipLogic.get_component_hexes(
		component.hex_position,
		component.hex_size,
		valid_positions
	)
	for hex in hexes:
		new_grid[hex] = test_result.component

	# Update in components list
	var new_components: Array = []
	for comp in state.ship_components:
		if comp.hex_position == component.hex_position:
			new_components.append(test_result.component)
		else:
			new_components.append(comp)

	# Add log entry
	var new_log = state.mission_log.duplicate()
	new_log.append(GameTypes.create_log_entry(
		state.current_day,
		"Tested %s: Quality +%.1f%% (now %.1f%%)" % [
			component.display_name,
			test_result.result.quality_gained,
			test_result.result.new_quality
		],
		"info"
	))

	return GameTypes.with_fields(state, {
		"ship_hex_grid": new_grid,
		"ship_components": new_components,
		"mission_log": new_log
	})

static func _reduce_select_engine(state: Dictionary, action: Dictionary) -> Dictionary:
	return GameTypes.with_field(state, "selected_engine", action.engine)

static func _reduce_add_crew(state: Dictionary, action: Dictionary) -> Dictionary:
	if state.crew.size() >= 4:
		return state

	var new_crew = state.crew.duplicate()
	new_crew.append(action.crew_member)

	var new_log = state.mission_log.duplicate()
	new_log.append(GameTypes.create_log_entry(
		state.current_day,
		"%s joined the crew as %s" % [
			action.crew_member.display_name,
			CrewLogic.get_specialty_name(action.crew_member.specialty)
		],
		"info"
	))

	return GameTypes.with_fields(state, {
		"crew": new_crew,
		"mission_log": new_log
	})

static func _reduce_remove_crew(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_crew: Array = []
	var removed_name = ""
	for crew in state.crew:
		if crew.id != action.crew_id:
			new_crew.append(crew)
		else:
			removed_name = crew.display_name

	if removed_name.is_empty():
		return state

	var new_log = state.mission_log.duplicate()
	new_log.append(GameTypes.create_log_entry(
		state.current_day,
		"%s left the crew" % removed_name,
		"info"
	))

	return GameTypes.with_fields(state, {
		"crew": new_crew,
		"mission_log": new_log
	})

static func _reduce_update_crew(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_crew: Array = []
	for crew in state.crew:
		if crew.id == action.crew_id:
			new_crew.append(GameTypes.with_fields(crew, action.updates))
		else:
			new_crew.append(crew)

	return GameTypes.with_field(state, "crew", new_crew)

static func _reduce_spend_budget(state: Dictionary, action: Dictionary) -> Dictionary:
	if action.amount > state.budget:
		return state

	return GameTypes.with_fields(state, {
		"budget": state.budget - action.amount,
		"total_spent": state.total_spent + action.amount
	})

static func _reduce_add_budget(state: Dictionary, action: Dictionary) -> Dictionary:
	return GameTypes.with_field(state, "budget", state.budget + action.amount)

static func _reduce_update_cargo(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_cargo = state.cargo_manifest.duplicate()
	new_cargo[action.key] = action.value

	return GameTypes.with_field(state, "cargo_manifest", new_cargo)

static func _reduce_apply_event(state: Dictionary, action: Dictionary) -> Dictionary:
	var event = action.event

	var new_log = state.mission_log.duplicate()
	new_log.append(GameTypes.create_log_entry(
		state.current_day,
		event.description,
		"event"
	))

	var updates = {"mission_log": new_log}

	# Apply event effects
	for key in event.effects.keys():
		updates[key] = event.effects[key]

	return GameTypes.with_fields(state, updates)

static func _reduce_add_log(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_log = state.mission_log.duplicate()
	new_log.append(GameTypes.create_log_entry(
		state.current_day,
		action.message,
		action.event_type
	))

	return GameTypes.with_field(state, "mission_log", new_log)

# ============================================================================
# HELPERS
# ============================================================================

static func _generate_default_grid_positions() -> Array:
	var positions: Array = []
	for q in range(-7, 8):
		for r in range(-5, 6):
			positions.append(Vector2i(q, r))
	return positions

# ============================================================================
# TRAVEL PHASE REDUCERS
# ============================================================================

static func _reduce_assign_activity(state: Dictionary, action: Dictionary) -> Dictionary:
	var activities = TravelLogic.get_available_activities()
	var activity = null
	for a in activities:
		if a.id == action.activity_id:
			activity = a
			break

	if activity == null:
		return state

	# Find the crew member performing the action
	var actor = null
	var actor_index = -1
	for i in range(state.crew.size()):
		if state.crew[i].id == action.crew_id:
			actor = state.crew[i]
			actor_index = i
			break

	if actor == null:
		return state

	# Check if crew member has enough hours for this activity
	var hours_needed = activity.get("hours", 0)
	var hours_used = actor.get("hours_used_today", 0)
	var hours_available = actor.get("hours_per_day", 16) - hours_used

	if hours_needed > hours_available:
		var new_log = state.mission_log.duplicate()
		new_log.append(GameTypes.create_log_entry(state.current_day,
			"%s doesn't have enough time today (%d hours needed, %d available)" % [actor.display_name, hours_needed, hours_available],
			"event"))
		return GameTypes.with_field(state, "mission_log", new_log)

	var updates = {}
	var new_log = state.mission_log.duplicate()
	var supplies = state.get("supplies", {}).duplicate()

	# Handle special activities that use resources
	if activity.id == "repair":
		var spare_parts = int(supplies.get("spare_parts", 0))
		var repair_result = TravelLogic.apply_repair_activity(
			actor, state.ship_components, spare_parts, action.get("random_value", 0.5)
		)
		if repair_result.success:
			updates["ship_components"] = repair_result.components
			supplies["spare_parts"] = spare_parts - repair_result.spare_parts_used
			updates["supplies"] = supplies
			var new_crew = state.crew.duplicate()
			new_crew[actor_index] = TravelLogic.apply_activity(actor, activity)
			updates["crew"] = new_crew
			new_log.append(GameTypes.create_log_entry(state.current_day,
				"%s repaired %s (+%.0f%%, now %.0f%%)" % [actor.display_name,
					repair_result.component_repaired, repair_result.quality_restored, repair_result.new_quality],
				"success"))
		else:
			new_log.append(GameTypes.create_log_entry(state.current_day,
				"Repair failed: %s" % repair_result.reason, "event"))

	elif activity.id == "medical":
		var medical_kits = int(supplies.get("medical_kits", 0))
		var patient = null
		var patient_index = -1
		var worst_health = 100.0
		for i in range(state.crew.size()):
			var c = state.crew[i]
			if c.health > 0 and (c.is_sick or c.is_injured or c.health < 80):
				if c.health < worst_health:
					worst_health = c.health
					patient = c
					patient_index = i
		if patient != null:
			var medical_result = TravelLogic.apply_medical_activity(
				patient, actor, medical_kits, action.get("random_value", 0.5))
			if medical_result.success:
				var new_crew = state.crew.duplicate()
				new_crew[patient_index] = GameTypes.with_fields(patient, medical_result.patient_updates)
				new_crew[actor_index] = TravelLogic.apply_activity(actor, activity)
				updates["crew"] = new_crew
				supplies["medical_kits"] = medical_kits - medical_result.medical_kits_used
				updates["supplies"] = supplies
				new_log.append(GameTypes.create_log_entry(state.current_day,
					"%s treated %s: %s" % [actor.display_name, patient.display_name, ", ".join(medical_result.results)],
					"success"))
			else:
				new_log.append(GameTypes.create_log_entry(state.current_day,
					"Treatment failed: %s" % medical_result.reason, "event"))
		else:
			new_log.append(GameTypes.create_log_entry(state.current_day, "No crew need treatment.", "info"))
	else:
		var new_crew = state.crew.duplicate()
		new_crew[actor_index] = TravelLogic.apply_activity(actor, activity)
		updates["crew"] = new_crew

	updates["mission_log"] = new_log
	return GameTypes.with_fields(state, updates)

static func _reduce_start_travel(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_log = state.mission_log.duplicate()
	new_log.append(GameTypes.create_log_entry(
		state.current_day,
		"Departure from lunar orbit. Beginning %d-day journey to Mars." % action.travel_days,
		"success"
	))

	# Calculate recommended supplies if not already set
	var supplies = state.get("supplies", {}).duplicate()
	var crew_count = state.crew.size()

	# Calculate supplies based on player settings or defaults
	if supplies.get("food_kg", 0.0) <= 0:
		# Get player's supply multipliers or use defaults
		var mults = state.get("supply_multipliers", {})
		var food_mult = mults.get("food", 1.15)
		var water_mult = mults.get("water", 1.15)
		var oxygen_mult = mults.get("oxygen", 1.15)
		var spare_parts = mults.get("spare_parts", 3)
		var medical_kits = mults.get("medical_kits", 2)

		# Calculate base supplies needed (100% = exactly enough for journey)
		var base = TravelLogic.calc_recommended_supplies(crew_count, action.travel_days, 1.0)
		supplies.food_kg = base.food_kg * food_mult
		supplies.water_kg = base.water_kg * water_mult
		supplies.oxygen_kg = base.oxygen_kg * oxygen_mult
		supplies.spare_parts = spare_parts
		supplies.medical_kits = medical_kits

		# Calculate how many days of supplies we have
		var daily = TravelLogic.calc_daily_consumption(crew_count, 70.0)
		var food_days = supplies.food_kg / daily.food_kg
		var water_days = supplies.water_kg / daily.water_kg
		var oxygen_days = supplies.oxygen_kg / daily.oxygen_kg

		new_log.append(GameTypes.create_log_entry(
			state.current_day,
			"Supplies loaded: %.0f kg food (%.0f days), %.0f kg water (%.0f days), %.0f kg oxygen (%.0f days)" % [
				supplies.food_kg, food_days, supplies.water_kg, water_days, supplies.oxygen_kg, oxygen_days
			],
			"info"
		))
		new_log.append(GameTypes.create_log_entry(
			state.current_day,
			"Spare parts: %d, Medical kits: %d" % [spare_parts, medical_kits],
			"info"
		))

		# Warning if supplies are tight
		if food_days < action.travel_days + 7:
			new_log.append(GameTypes.create_log_entry(
				state.current_day,
				"WARNING: Food supplies will be tight for this journey!",
				"event"
			))
		if food_days < action.travel_days:
			new_log.append(GameTypes.create_log_entry(
				state.current_day,
				"CRITICAL: Food supplies are INSUFFICIENT! Rationing will be required!",
				"error"
			))

	return GameTypes.with_fields(state, {
		"current_phase": GameTypes.GamePhase.TRAVEL_TO_MARS,
		"travel_day": 0,
		"travel_total_days": action.travel_days,
		"supplies": supplies,
		"mission_log": new_log
	})

static func _reduce_advance_travel_day(state: Dictionary, action: Dictionary) -> Dictionary:
	var travel_day = state.get("travel_day", 0) + 1
	var travel_total = state.get("travel_total_days", 180)
	var new_day = state.current_day + 1

	var updates = {
		"current_day": new_day,
		"travel_day": travel_day
	}

	# Update crew daily and reset their time budget
	var new_crew: Array = []
	var rand_idx = 0
	for crew in state.crew:
		var rand_val = action.random_values[rand_idx] if rand_idx < action.random_values.size() else 0.5
		var updated = CrewLogic.apply_daily_update(crew, rand_val)
		# Reset hours for new day
		updated = GameTypes.with_field(updated, "hours_used_today", 0)
		new_crew.append(updated)
		rand_idx += 1
	updates["crew"] = new_crew

	var new_log = updates.get("mission_log", state.mission_log).duplicate()

	# CONSUME SUPPLIES - The core survival mechanic
	var supplies = state.get("supplies", {})
	if not supplies.is_empty():
		var supply_result = TravelLogic.consume_daily_supplies(
			supplies,
			updates["crew"],
			state.ship_components
		)
		updates["supplies"] = supply_result.supplies

		# Apply crew damage from starvation/dehydration/suffocation
		if not supply_result.crew_updates.is_empty():
			var updated_crew: Array = []
			for member in updates["crew"]:
				if supply_result.crew_updates.has(member.id):
					updated_crew.append(GameTypes.with_fields(member, supply_result.crew_updates[member.id]))
				else:
					updated_crew.append(member)
			updates["crew"] = updated_crew

		# Log supply events
		for event in supply_result.events:
			new_log.append(GameTypes.create_log_entry(
				new_day,
				event.message,
				"error" if event.type == "critical" else "event"
			))

	# COMPONENT DEGRADATION - Wear and tear on ship systems
	var components = state.ship_components.duplicate(true)
	var degraded_components: Array = []
	for i in range(components.size()):
		var rand_val = action.random_values[rand_idx + i] if rand_idx + i < action.random_values.size() else 0.5
		var degraded = ComponentLogic.apply_daily_wear(components[i], rand_val)
		degraded_components.append(degraded)
	updates["ship_components"] = degraded_components

	# Also update hex grid with degraded components
	var new_hex_grid = state.ship_hex_grid.duplicate(true)
	for comp in degraded_components:
		if comp.has("hex_position"):
			new_hex_grid[comp.hex_position] = comp
	updates["ship_hex_grid"] = new_hex_grid

	# DEGRADATION WARNINGS - Build tension before things go critical
	new_log = _add_degradation_warnings(new_log, new_day, updates["crew"], degraded_components, updates.get("supplies", state.get("supplies", {})))

	# Check for crew deaths
	var deaths_this_day: Array = []
	var alive_crew: Array = []
	for member in updates["crew"]:
		if member.health <= 0:
			deaths_this_day.append(member)
		else:
			alive_crew.append(member)

	for dead_member in deaths_this_day:
		new_log.append(GameTypes.create_log_entry(
			new_day,
			"%s has died. The crew mourns their loss." % dead_member.display_name,
			"error"
		))
		updates["crew_deaths"] = state.get("crew_deaths", 0) + 1

	# Check for total crew loss
	if alive_crew.is_empty() and not updates["crew"].is_empty():
		new_log.append(GameTypes.create_log_entry(
			new_day,
			"ALL CREW LOST. The ship drifts silently toward Mars...",
			"error"
		))
		updates["current_phase"] = GameTypes.GamePhase.GAME_OVER
		updates["game_over_reason"] = "total_crew_loss"
		updates["mission_log"] = new_log
		return GameTypes.with_fields(state, updates)

	# Check for travel event
	if action.random_values.size() >= rand_idx + 3:
		var event_result = TravelLogic.check_daily_event(
			GameTypes.with_fields(state, updates),
			travel_day,
			action.random_values[rand_idx],
			action.random_values[rand_idx + 1],
			action.random_values[rand_idx + 2]
		)
		if event_result.triggered and event_result.event:
			# Apply event effects
			for key in event_result.event.effects.keys():
				updates[key] = event_result.event.effects[key]

			new_log.append(GameTypes.create_log_entry(
				new_day,
				event_result.event.description,
				"event"
			))

	updates["mission_log"] = new_log

	# Check for arrival
	if travel_day >= travel_total:
		var arrival_status = TravelLogic.check_arrival_status(GameTypes.with_fields(state, updates))

		if arrival_status.can_land:
			new_log.append(GameTypes.create_log_entry(
				new_day,
				"Mars orbit achieved! Preparing for landing sequence.",
				"success"
			))
			updates["current_phase"] = GameTypes.GamePhase.MARS_BASE
			updates["mars_arrival_status"] = arrival_status
		else:
			for issue in arrival_status.issues:
				new_log.append(GameTypes.create_log_entry(new_day, issue, "error"))
			new_log.append(GameTypes.create_log_entry(
				new_day,
				"Mission failed - unable to complete Mars orbital insertion.",
				"error"
			))
			updates["current_phase"] = GameTypes.GamePhase.GAME_OVER
			updates["game_over_reason"] = "arrival_failure"

		updates["mission_log"] = new_log

	return GameTypes.with_fields(state, updates)

# ============================================================================
# MARS BASE REDUCERS
# ============================================================================

static func _reduce_start_mars_operations(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_log = state.mission_log.duplicate()
	new_log.append(GameTypes.create_log_entry(
		state.current_day,
		"Landing successful! Mars surface operations begin.",
		"success"
	))

	return GameTypes.with_fields(state, {
		"mars_sol": 1,
		"base_established": true,
		"experiments_completed": [],
		"samples_collected": {
			"soil": 0,
			"ice": 0,
			"atmosphere": 0
		},
		"mission_log": new_log
	})

static func _reduce_conduct_experiment(state: Dictionary, action: Dictionary) -> Dictionary:
	var experiments_completed = state.get("experiments_completed", []).duplicate()

	if action.experiment_id in experiments_completed:
		return state  # Already done

	# Find crew member
	var crew_member = null
	for crew in state.crew:
		if crew.id == action.crew_id:
			crew_member = crew
			break

	if crew_member == null:
		return state

	# Calculate success based on crew effectiveness and random value
	var effectiveness = CrewLogic.calc_effectiveness(crew_member)
	var success_threshold = 0.3 + (effectiveness * 0.5)  # 30-80% base success
	var success = action.random_value < success_threshold

	var new_log = state.mission_log.duplicate()

	if success:
		experiments_completed.append(action.experiment_id)
		new_log.append(GameTypes.create_log_entry(
			state.current_day,
			"%s successfully completed %s experiment." % [crew_member.display_name, action.experiment_id],
			"success"
		))
	else:
		new_log.append(GameTypes.create_log_entry(
			state.current_day,
			"%s experiment failed. May retry tomorrow." % action.experiment_id,
			"error"
		))

	# Apply fatigue to crew
	var new_crew: Array = []
	for crew in state.crew:
		if crew.id == action.crew_id:
			new_crew.append(CrewLogic.apply_work(crew, 6.0))  # 6 hours work
		else:
			new_crew.append(crew)

	return GameTypes.with_fields(state, {
		"experiments_completed": experiments_completed,
		"crew": new_crew,
		"mission_log": new_log
	})

static func _reduce_advance_mars_sol(state: Dictionary, _action: Dictionary) -> Dictionary:
	var current_sol = state.get("mars_sol", 0)
	return GameTypes.with_field(state, "mars_sol", current_sol + 1)

static func _reduce_update_component(state: Dictionary, action: Dictionary) -> Dictionary:
	var new_components: Array = []
	for comp in state.ship_components:
		if comp.hex_position == action.position:
			new_components.append(action.component)
		else:
			new_components.append(comp)

	# Also update in hex grid
	var new_grid = state.ship_hex_grid.duplicate(true)
	var valid_positions = new_grid.keys()
	var hexes = ShipLogic.get_component_hexes(
		action.position,
		action.component.hex_size,
		valid_positions
	)
	for hex in hexes:
		new_grid[hex] = action.component

	return GameTypes.with_fields(state, {
		"ship_components": new_components,
		"ship_hex_grid": new_grid
	})

# ============================================================================
# DEGRADATION WARNING SYSTEM
# ============================================================================

## Add warning log entries when things start to degrade (builds narrative tension)
static func _add_degradation_warnings(
	log: Array,
	day: int,
	crew: Array,
	components: Array,
	supplies: Dictionary
) -> Array:
	var new_log = log.duplicate()

	# Track what we've already warned about to avoid spam (check last few entries)
	var recent_warnings: Array = []
	for i in range(maxi(0, log.size() - 10), log.size()):
		if log[i].event_type == "warning":
			recent_warnings.append(log[i].message)

	# Component warnings
	for comp in components:
		if comp.quality <= 50 and comp.quality > 30:
			var msg = "%s is showing signs of wear (%.0f%% integrity)." % [comp.display_name, comp.quality]
			if msg not in recent_warnings:
				new_log.append(GameTypes.create_log_entry(day, msg, "warning"))
		elif comp.quality <= 30 and comp.quality > 15:
			var msg = "%s is failing! Repairs urgently needed (%.0f%% integrity)." % [comp.display_name, comp.quality]
			if msg not in recent_warnings:
				new_log.append(GameTypes.create_log_entry(day, msg, "event"))

	# Crew warnings
	for member in crew:
		if member.health <= 0:
			continue

		# Health warnings
		if member.health <= 50 and member.health > 30:
			var msg = "%s is showing signs of malnutrition. Consider medical treatment." % member.display_name
			if msg not in recent_warnings:
				new_log.append(GameTypes.create_log_entry(day, msg, "warning"))
		elif member.health <= 30 and member.health > 15:
			var msg = "%s is in critical condition! Immediate medical attention required!" % member.display_name
			if msg not in recent_warnings:
				new_log.append(GameTypes.create_log_entry(day, msg, "event"))

		# Morale warnings
		if member.morale <= 40 and member.morale > 20:
			var msg = "%s's morale is concerning. The crew should talk." % member.display_name
			if msg not in recent_warnings:
				new_log.append(GameTypes.create_log_entry(day, msg, "warning"))
		elif member.morale <= 20:
			var msg = "%s is on the verge of a breakdown. Morale is critical!" % member.display_name
			if msg not in recent_warnings:
				new_log.append(GameTypes.create_log_entry(day, msg, "event"))

		# Fatigue warnings
		if member.fatigue >= 70 and member.fatigue < 90:
			var msg = "%s is exhausted. They need rest." % member.display_name
			if msg not in recent_warnings:
				new_log.append(GameTypes.create_log_entry(day, msg, "warning"))
		elif member.fatigue >= 90:
			var msg = "%s is dangerously exhausted! Rest is essential!" % member.display_name
			if msg not in recent_warnings:
				new_log.append(GameTypes.create_log_entry(day, msg, "event"))

	# Supply warnings (check if spare parts or medical kits are low)
	if supplies.get("spare_parts", 0) == 1:
		var msg = "Last spare part in storage. Any equipment failure could be catastrophic."
		if msg not in recent_warnings:
			new_log.append(GameTypes.create_log_entry(day, msg, "warning"))
	elif supplies.get("spare_parts", 0) == 0:
		var msg = "No spare parts remain! Pray nothing breaks."
		if msg not in recent_warnings:
			new_log.append(GameTypes.create_log_entry(day, msg, "event"))

	if supplies.get("medical_kits", 0) == 1:
		var msg = "Last medical kit in storage. Any injury could prove fatal."
		if msg not in recent_warnings:
			new_log.append(GameTypes.create_log_entry(day, msg, "warning"))
	elif supplies.get("medical_kits", 0) == 0:
		var msg = "Medical supplies exhausted. Crew injuries cannot be treated."
		if msg not in recent_warnings:
			new_log.append(GameTypes.create_log_entry(day, msg, "event"))

	return new_log
