## Validates actions before dispatch.
##
## Every action passes through validation before reaching reducers.
## This catches errors early with clear messages.
##
## Validation levels:
## 1. Structure: Does action have required fields?
## 2. Types: Are field values the correct types?
## 3. References: Do referenced IDs exist?
## 4. Business: Is this action allowed in current state?
class_name ActionValidator
extends RefCounted

var _game_data: Dictionary = {}
var _game_validators: Dictionary = {}  # game_id -> GameValidator


func set_game_data(data: Dictionary) -> void:
	_game_data = data


## Register a game-specific validator
func register_game_validator(game_id: String, validator: RefCounted) -> void:
	_game_validators[game_id] = validator


## Validate an action against current state
func validate(action: Dictionary, state: Dictionary) -> Result:
	# 1. Structural validation
	var structural = _validate_structure(action)
	if not structural.is_ok():
		return structural

	# 2. Type validation
	var types = _validate_types(action)
	if not types.is_ok():
		return types

	# 3. Reference validation
	var refs = _validate_references(action, state)
	if not refs.is_ok():
		return refs

	# 4. Business rule validation
	var business = _validate_business_rules(action, state)
	if not business.is_ok():
		return business

	# 5. Game-specific validation
	var game_id = state.get("game_id", "mars_mission")
	if _game_validators.has(game_id):
		var game_result = _game_validators[game_id].validate(action, state, _game_data)
		if not game_result.is_ok():
			return game_result

	return Result.ok(action)


## ============================================================================
## STRUCTURAL VALIDATION
## ============================================================================

func _validate_structure(action: Dictionary) -> Result:
	# Must have type field
	if not action.has("type"):
		return Result.error(
			"MISSING_ACTION_TYPE",
			"Action must have a 'type' field",
			{"action": action}
		)

	var action_type = action.type

	# Type must be a string
	if not action_type is String:
		return Result.error(
			"INVALID_ACTION_TYPE",
			"Action type must be a string, got: %s" % typeof(action_type),
			{"action": action}
		)

	# Type must be known (optional - allow custom types)
	if not ActionTypes.is_valid_type(action_type):
		push_warning("Unknown action type: %s (allowing custom type)" % action_type)

	# Check required fields for known types
	var required = ActionTypes.get_required_fields(action_type)
	for field in required:
		if not action.has(field):
			return Result.error(
				"MISSING_REQUIRED_FIELD",
				"Action '%s' requires field '%s'" % [action_type, field],
				{"action_type": action_type, "missing_field": field, "action": action}
			)

	return Result.ok(action)


## ============================================================================
## TYPE VALIDATION
## ============================================================================

func _validate_types(action: Dictionary) -> Result:
	var action_type = action.get("type", "")

	match action_type:
		ActionTypes.PLACE_COMPONENT:
			return _validate_place_component_types(action)
		ActionTypes.HIRE_CREW, ActionTypes.FIRE_CREW:
			return _validate_crew_action_types(action)
		ActionTypes.CONSUME_RESOURCE, ActionTypes.ADD_RESOURCE:
			return _validate_resource_action_types(action)
		ActionTypes.ADVANCE_TIME:
			return _validate_advance_time_types(action)
		_:
			return Result.ok(action)


func _validate_place_component_types(action: Dictionary) -> Result:
	if not action.component_id is String:
		return Result.error(
			"INVALID_TYPE",
			"component_id must be a string",
			{"field": "component_id", "value": action.component_id}
		)

	if not action.position is Dictionary:
		return Result.error(
			"INVALID_TYPE",
			"position must be a dictionary with q and r fields",
			{"field": "position", "value": action.position}
		)

	var pos = action.position
	if not pos.has("q") or not pos.has("r"):
		return Result.error(
			"INVALID_POSITION",
			"position must have 'q' and 'r' fields",
			{"position": pos}
		)

	return Result.ok(action)


func _validate_crew_action_types(action: Dictionary) -> Result:
	if not action.crew_id is String:
		return Result.error(
			"INVALID_TYPE",
			"crew_id must be a string",
			{"field": "crew_id", "value": action.crew_id}
		)
	return Result.ok(action)


func _validate_resource_action_types(action: Dictionary) -> Result:
	if not action.resource_id is String:
		return Result.error(
			"INVALID_TYPE",
			"resource_id must be a string",
			{"field": "resource_id", "value": action.resource_id}
		)

	if not (action.amount is int or action.amount is float):
		return Result.error(
			"INVALID_TYPE",
			"amount must be a number",
			{"field": "amount", "value": action.amount}
		)

	return Result.ok(action)


func _validate_advance_time_types(action: Dictionary) -> Result:
	if action.has("amount") and not action.amount is int:
		return Result.error(
			"INVALID_TYPE",
			"amount must be an integer",
			{"field": "amount", "value": action.amount}
		)
	return Result.ok(action)


## ============================================================================
## REFERENCE VALIDATION
## ============================================================================

func _validate_references(action: Dictionary, state: Dictionary) -> Result:
	var action_type = action.get("type", "")

	match action_type:
		ActionTypes.PLACE_COMPONENT:
			return _validate_component_reference(action)
		ActionTypes.REMOVE_COMPONENT:
			return _validate_position_has_component(action, state)
		ActionTypes.HIRE_CREW:
			return _validate_crew_exists_in_roster(action)
		ActionTypes.FIRE_CREW, ActionTypes.ASSIGN_CREW_TASK:
			return _validate_crew_is_hired(action, state)
		ActionTypes.CONSUME_RESOURCE, ActionTypes.ADD_RESOURCE:
			return _validate_resource_exists(action, state)
		_:
			return Result.ok(action)


func _validate_component_reference(action: Dictionary) -> Result:
	var component_id = action.component_id
	var components = _game_data.get("components", [])

	# Find component in game data
	var found = false
	for comp in components:
		if comp.get("id") == component_id:
			found = true
			break

	if not found:
		return Result.error(
			"UNKNOWN_COMPONENT",
			"Component '%s' does not exist in game data" % component_id,
			{"component_id": component_id}
		)

	return Result.ok(action)


func _validate_position_has_component(action: Dictionary, state: Dictionary) -> Result:
	var pos = action.position
	var hex_key = GameTypes.hex_key(pos.q, pos.r)

	var ship = state.get("ship", {})
	var components = ship.get("components", {})

	if not components.has(hex_key):
		return Result.error(
			"NO_COMPONENT_AT_POSITION",
			"No component at position (%d, %d)" % [pos.q, pos.r],
			{"position": pos}
		)

	return Result.ok(action)


func _validate_crew_exists_in_roster(action: Dictionary) -> Result:
	var crew_id = action.crew_id
	var roster = _game_data.get("crew_roster", [])

	var found = false
	for crew in roster:
		if crew.get("id") == crew_id:
			found = true
			break

	if not found:
		return Result.error(
			"UNKNOWN_CREW",
			"Crew member '%s' does not exist in roster" % crew_id,
			{"crew_id": crew_id}
		)

	return Result.ok(action)


func _validate_crew_is_hired(action: Dictionary, state: Dictionary) -> Result:
	var crew_id = action.crew_id
	var crew = state.get("crew", [])

	var found = false
	for member in crew:
		if member.get("id") == crew_id:
			found = true
			break

	if not found:
		return Result.error(
			"CREW_NOT_HIRED",
			"Crew member '%s' is not on the team" % crew_id,
			{"crew_id": crew_id}
		)

	return Result.ok(action)


func _validate_resource_exists(action: Dictionary, state: Dictionary) -> Result:
	var resource_id = action.resource_id
	var resources = state.get("resources", {})

	if not resources.has(resource_id):
		return Result.error(
			"UNKNOWN_RESOURCE",
			"Resource '%s' does not exist" % resource_id,
			{"resource_id": resource_id}
		)

	return Result.ok(action)


## ============================================================================
## BUSINESS RULE VALIDATION
## ============================================================================

func _validate_business_rules(action: Dictionary, state: Dictionary) -> Result:
	var action_type = action.get("type", "")

	match action_type:
		ActionTypes.PLACE_COMPONENT:
			return _validate_can_place_component(action, state)
		ActionTypes.HIRE_CREW:
			return _validate_can_hire_crew(action, state)
		ActionTypes.CONSUME_RESOURCE:
			return _validate_has_resource(action, state)
		ActionTypes.START_LAUNCH:
			return _validate_can_launch(state)
		_:
			return Result.ok(action)


func _validate_can_place_component(action: Dictionary, state: Dictionary) -> Result:
	var pos = action.position
	var hex_key = GameTypes.hex_key(pos.q, pos.r)

	var ship = state.get("ship", {})
	var components = ship.get("components", {})

	# Check if position is already occupied
	if components.has(hex_key):
		return Result.error(
			"POSITION_OCCUPIED",
			"Position (%d, %d) is already occupied" % [pos.q, pos.r],
			{"position": pos, "occupying_component": components[hex_key].get("id")}
		)

	# TODO: Check budget
	# TODO: Check placement rules (adjacency, etc.)

	return Result.ok(action)


func _validate_can_hire_crew(action: Dictionary, state: Dictionary) -> Result:
	var crew_id = action.crew_id
	var crew = state.get("crew", [])

	# Check if already hired
	for member in crew:
		if member.get("id") == crew_id:
			return Result.error(
				"CREW_ALREADY_HIRED",
				"Crew member '%s' is already on the team" % crew_id,
				{"crew_id": crew_id}
			)

	# Check crew limit (4 for mars_mission)
	var max_crew = _game_data.get("balance", {}).get("max_crew", 4)
	if crew.size() >= max_crew:
		return Result.error(
			"CREW_LIMIT_REACHED",
			"Cannot hire more than %d crew members" % max_crew,
			{"current_crew": crew.size(), "max_crew": max_crew}
		)

	return Result.ok(action)


func _validate_has_resource(action: Dictionary, state: Dictionary) -> Result:
	var resource_id = action.resource_id
	var amount = action.amount
	var resources = state.get("resources", {})

	if not resources.has(resource_id):
		return Result.ok(action)  # Will be caught by reference validation

	var current = resources[resource_id].get("current", 0)

	if current < amount:
		return Result.error(
			"INSUFFICIENT_RESOURCE",
			"Not enough %s: have %.1f, need %.1f" % [resource_id, current, amount],
			{"resource_id": resource_id, "current": current, "required": amount}
		)

	return Result.ok(action)


func _validate_can_launch(state: Dictionary) -> Result:
	# Check required components
	var ship = state.get("ship", {})

	if ship.get("selected_engine") == null:
		return Result.error(
			"NO_ENGINE_SELECTED",
			"Must select an engine before launch",
			{}
		)

	# Check crew
	var crew = state.get("crew", [])
	if crew.is_empty():
		return Result.error(
			"NO_CREW",
			"Must have at least one crew member before launch",
			{}
		)

	# Check supplies
	var resources = state.get("resources", {})
	for resource_id in ["food", "water", "oxygen"]:
		var resource = resources.get(resource_id, {})
		if resource.get("current", 0) <= 0:
			return Result.error(
				"NO_SUPPLIES",
				"Must have %s before launch" % resource_id,
				{"resource_id": resource_id}
			)

	return Result.ok(state)
