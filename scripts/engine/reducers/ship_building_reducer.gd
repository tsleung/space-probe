## Ship Building Phase Reducer
## Handles all state changes during ship construction.
##
## All functions are static and pure.
class_name ShipBuildingReducer
extends RefCounted


## ============================================================================
## MAIN REDUCER
## ============================================================================

## Route action to appropriate handler
static func reduce(
	state: Dictionary,
	action: Dictionary,
	balance: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var action_type = action.get("type", "")

	match action_type:
		ActionTypes.PLACE_COMPONENT:
			return _reduce_place_component(state, action, balance)
		ActionTypes.REMOVE_COMPONENT:
			return _reduce_remove_component(state, action, balance)
		ActionTypes.TEST_COMPONENT:
			return _reduce_test_component(state, action, balance, rng)
		ActionTypes.SELECT_ENGINE:
			return _reduce_select_engine(state, action)
		ActionTypes.HIRE_CREW:
			return _reduce_hire_crew(state, action, balance)
		ActionTypes.DISMISS_CREW:
			return _reduce_dismiss_crew(state, action)
		ActionTypes.LOAD_CARGO:
			return _reduce_load_cargo(state, action, balance)
		ActionTypes.ADVANCE_DAY:
			return _reduce_advance_day(state, action, balance, rng)
		ActionTypes.LAUNCH:
			return _reduce_launch(state, action, balance)
		ActionTypes.SET_RATIONING:
			return ResourceSystem.set_rationing(state, action.get("level", "none"))
		_:
			return state


## ============================================================================
## COMPONENT ACTIONS
## ============================================================================

## Place a component on the ship grid
static func _reduce_place_component(
	state: Dictionary,
	action: Dictionary,
	balance: Dictionary
) -> Dictionary:
	var component_def = action.get("component", {})
	var position = action.get("position", Vector2i.ZERO)
	var rotation = action.get("rotation", 0)

	var ship = state.get("ship", {})

	# Validate placement
	var validation = HexGridSystem.can_place_component(ship, component_def, position, rotation)
	if not validation.is_ok():
		return state

	# Check budget
	var cost = component_def.get("base_cost", 0)
	var budget = state.get("budget", 0)
	if cost > budget:
		return state

	# Create component instance
	var component = _create_component_instance(component_def, balance)

	# Place on grid
	var new_ship = HexGridSystem.place_component(ship, component, position, rotation)

	# Update state
	var new_state = state.duplicate(true)
	new_state["ship"] = new_ship
	new_state["budget"] = budget - cost
	new_state["total_spent"] = state.get("total_spent", 0) + cost

	# Add log entry
	new_state = _add_log(new_state, "Started construction of %s" % component_def.get("name", "component"))

	return new_state


## Create a component instance from definition
static func _create_component_instance(definition: Dictionary, balance: Dictionary) -> Dictionary:
	var stats = definition.get("stats", {})
	var build_days = balance.get("component_build_time_multiplier", 1.0) * definition.get("build_days", 5)

	return {
		"id": definition.get("id", ""),
		"definition_id": definition.get("id", ""),
		"name": definition.get("name", ""),
		"category": definition.get("category", ""),
		"quality": stats.get("base_quality", 50),
		"max_quality": stats.get("max_quality", 95),
		"is_built": false,
		"days_remaining": int(build_days),
		"is_tested": false,
		"test_count": 0,
		"stats": stats,
		"placement": definition.get("placement", {}),
		"critical": definition.get("critical", false)
	}


## Remove a component from the ship grid
static func _reduce_remove_component(
	state: Dictionary,
	action: Dictionary,
	balance: Dictionary
) -> Dictionary:
	var position = action.get("position", Vector2i.ZERO)

	var ship = state.get("ship", {})
	var component = HexGridSystem.get_component_at(ship, position)

	if component.is_empty():
		return state

	# Calculate refund
	var refund_rate = balance.get("component_refund_rate", 0.5)
	var base_cost = component.get("stats", {}).get("base_cost", 0)
	var refund = int(base_cost * refund_rate)

	# Remove from grid
	var new_ship = HexGridSystem.remove_component(ship, position)

	# Update state
	var new_state = state.duplicate(true)
	new_state["ship"] = new_ship
	new_state["budget"] = state.get("budget", 0) + refund

	# Add log entry
	new_state = _add_log(new_state, "Removed %s (refunded $%s)" % [
		component.get("name", "component"),
		GameTypes.format_money(refund) if GameTypes.has_method("format_money") else str(refund)
	])

	return new_state


## Test a component to improve quality
static func _reduce_test_component(
	state: Dictionary,
	action: Dictionary,
	balance: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var position = action.get("position", Vector2i.ZERO)

	return ComponentSystem.test_component(state, position, balance, rng)


## ============================================================================
## ENGINE SELECTION
## ============================================================================

## Select the main propulsion engine
static func _reduce_select_engine(state: Dictionary, action: Dictionary) -> Dictionary:
	var engine = action.get("engine", {})

	var new_state = state.duplicate(true)
	new_state["selected_engine"] = engine

	new_state = _add_log(new_state, "Selected %s as main propulsion" % engine.get("name", "engine"))

	return new_state


## ============================================================================
## CREW MANAGEMENT
## ============================================================================

## Hire a crew member
static func _reduce_hire_crew(
	state: Dictionary,
	action: Dictionary,
	balance: Dictionary
) -> Dictionary:
	var crew_data = action.get("crew_member", {})

	var crew = state.get("crew", [])
	var max_crew = balance.get("max_crew_size", 6)

	if crew.size() >= max_crew:
		return state

	# Check if already hired
	for member in crew:
		if member.get("id") == crew_data.get("id"):
			return state

	# Create crew member instance
	var new_member = _create_crew_instance(crew_data, balance)

	var new_crew = crew.duplicate()
	new_crew.append(new_member)

	var new_state = state.duplicate(true)
	new_state["crew"] = new_crew

	new_state = _add_log(new_state, "%s joined the crew as %s" % [
		crew_data.get("name", "Unknown"),
		crew_data.get("role", "crew")
	])

	return new_state


## Create crew member instance from data
static func _create_crew_instance(data: Dictionary, balance: Dictionary) -> Dictionary:
	return {
		"id": data.get("id", "crew_%d" % Time.get_unix_time_from_system()),
		"name": data.get("name", "Unknown"),
		"role": data.get("role", "generic"),
		"specialty": data.get("specialty", ""),
		"health": 100,
		"morale": data.get("starting_morale", balance.get("crew_starting_morale", 75)),
		"fatigue": 0,
		"status": GameTypes.CrewStatus.HEALTHY,
		"skills": data.get("skills", {}),
		"traits": data.get("traits", []),
		"conditions": [],
		"relationships": {},
		"current_task": "",
		"backstory": data.get("backstory", "")
	}


## Dismiss a crew member
static func _reduce_dismiss_crew(state: Dictionary, action: Dictionary) -> Dictionary:
	var crew_id = action.get("crew_id", "")

	var crew = state.get("crew", [])
	var new_crew: Array = []
	var removed_name = ""

	for member in crew:
		if member.get("id") == crew_id:
			removed_name = member.get("name", "Unknown")
		else:
			new_crew.append(member)

	if removed_name.is_empty():
		return state

	var new_state = state.duplicate(true)
	new_state["crew"] = new_crew

	new_state = _add_log(new_state, "%s left the crew" % removed_name)

	return new_state


## ============================================================================
## CARGO MANAGEMENT
## ============================================================================

## Load cargo onto the ship
static func _reduce_load_cargo(
	state: Dictionary,
	action: Dictionary,
	balance: Dictionary
) -> Dictionary:
	var resource_id = action.get("resource_id", "")
	var amount = action.get("amount", 0)

	if amount == 0:
		return state

	var resources = state.get("resources", {})
	var budget = state.get("budget", 0)

	# Get resource cost
	var resource_costs = balance.get("resource_costs", {})
	var cost_per_unit = resource_costs.get(resource_id, 100)
	var total_cost = int(amount * cost_per_unit)

	if total_cost > budget and amount > 0:
		return state

	# Update resource
	var new_state = state
	if amount > 0:
		new_state = ResourceSystem.add_resource(state, resource_id, amount)
		new_state["budget"] = budget - total_cost
		new_state["total_spent"] = state.get("total_spent", 0) + total_cost
	else:
		new_state = ResourceSystem.remove_resource(state, resource_id, -amount)
		# Partial refund for removal
		var refund = int(-amount * cost_per_unit * balance.get("cargo_refund_rate", 0.5))
		new_state["budget"] = budget + refund

	return new_state


## ============================================================================
## TIME ADVANCEMENT
## ============================================================================

## Advance one day during ship building
static func _reduce_advance_day(
	state: Dictionary,
	action: Dictionary,
	balance: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var days = action.get("days", 1)
	var new_state = state.duplicate(true)

	for i in range(days):
		new_state = _advance_single_day(new_state, balance, rng)

	return new_state


## Advance a single construction day
static func _advance_single_day(
	state: Dictionary,
	balance: Dictionary,
	rng: RNGManager
) -> Dictionary:
	var new_state = state.duplicate(true)
	var current_day = state.get("current_day", 0) + 1
	new_state["current_day"] = current_day

	# Advance construction on all components
	var ship = new_state.get("ship", {})
	var components = HexGridSystem.get_all_components(ship)

	for comp in components:
		if comp.get("is_built", true):
			continue

		var days_remaining = comp.get("days_remaining", 0) - 1
		var position = comp.get("position", {})
		var key = HexMath.hex_key(position.get("q", 0), position.get("r", 0))

		if ship.components.has(key):
			ship.components[key]["days_remaining"] = max(0, days_remaining)
			if days_remaining <= 0:
				ship.components[key]["is_built"] = true
				new_state = _add_log(new_state, "%s construction complete!" % comp.get("name", "Component"))

	new_state["ship"] = ship

	# Apply crew daily updates (morale decay in training)
	new_state = CrewSystem.apply_daily_update(new_state, balance, rng)

	# Check for random events
	var event_roll = rng.randf()
	if EventSystem.check_event_trigger(new_state, balance, event_roll):
		# Would trigger event - mark as pending
		new_state["pending_event_check"] = true

	return new_state


## ============================================================================
## LAUNCH
## ============================================================================

## Attempt to launch the ship
static func _reduce_launch(
	state: Dictionary,
	action: Dictionary,
	balance: Dictionary
) -> Dictionary:
	var ship = state.get("ship", {})

	# Check launch readiness
	var required = balance.get("required_components", ["cockpit", "engine_mount", "life_support"])
	var readiness = HexGridSystem.check_launch_readiness(ship, required)

	if not readiness.is_ok():
		return state

	# Check crew
	var crew = state.get("crew", [])
	var min_crew = balance.get("minimum_crew", 2)
	if crew.size() < min_crew:
		return state

	# Calculate travel time
	var engine = state.get("selected_engine", {})
	var launch_penalty = TimeSystem.calculate_launch_penalty(state, balance)

	var base_travel_days = balance.get("base_travel_days", 180)
	var travel_days = base_travel_days + launch_penalty.travel_days_added

	# Transition to travel phase
	var new_state = state.duplicate(true)
	new_state["phase"] = "travel_to_mars"
	new_state["travel_day"] = 0
	new_state["travel_total_days"] = travel_days
	new_state["launch_penalty"] = launch_penalty

	new_state = _add_log(new_state, "Launch successful! Beginning %d-day journey to Mars." % travel_days)

	return new_state


## ============================================================================
## HELPERS
## ============================================================================

## Add a log entry
static func _add_log(state: Dictionary, message: String, entry_type: String = "info") -> Dictionary:
	var new_state = state.duplicate(true)
	var log = new_state.get("event_log", [])
	log.append({
		"day": state.get("current_day", 0),
		"message": message,
		"type": entry_type,
		"timestamp": Time.get_unix_time_from_system()
	})
	new_state["event_log"] = log
	return new_state
