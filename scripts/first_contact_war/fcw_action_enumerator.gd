extends RefCounted
class_name FCWActionEnumerator

## FCW Action Enumerator - Enumerate all valid player actions at any state
##
## Use cases:
## - AI decision making (enumerate options, evaluate, choose)
## - Game tree search (MCTS, minimax)
## - Decision space analysis
## - Balancing (is the decision space too large/small?)

const FCWTypes = preload("res://scripts/first_contact_war/fcw_types.gd")
const FCWReducer = preload("res://scripts/first_contact_war/fcw_reducer.gd")

# ============================================================================
# ACTION ENUMERATION
# ============================================================================

static func get_valid_actions(state: Dictionary) -> Array:
	## Get all valid player actions at the current state
	## Returns array of action dictionaries

	if state.game_over:
		return []

	var actions: Array = []

	# Build ship actions
	actions.append_array(_enumerate_build_actions(state))

	# Fleet assignment actions
	actions.append_array(_enumerate_assign_actions(state))

	# Fleet recall actions
	actions.append_array(_enumerate_recall_actions(state))

	# Fleet order actions
	actions.append_array(_enumerate_order_actions(state))

	# Entity movement actions
	actions.append_array(_enumerate_entity_movement_actions(state))

	return actions

static func get_action_categories(state: Dictionary) -> Dictionary:
	## Get valid actions grouped by category
	## Returns {build: [], assign: [], recall: [], order: [], entity: []}
	return {
		"build": _enumerate_build_actions(state),
		"assign": _enumerate_assign_actions(state),
		"recall": _enumerate_recall_actions(state),
		"order": _enumerate_order_actions(state),
		"entity": _enumerate_entity_movement_actions(state)
	}

static func get_action_count(state: Dictionary) -> int:
	## Get total number of valid actions
	return get_valid_actions(state).size()

static func get_decision_space_size(state: Dictionary) -> Dictionary:
	## Analyze the decision space at current state
	var categories = get_action_categories(state)
	return {
		"total": get_action_count(state),
		"build": categories.build.size(),
		"assign": categories.assign.size(),
		"recall": categories.recall.size(),
		"order": categories.order.size(),
		"entity": categories.entity.size()
	}

# ============================================================================
# BUILD ACTIONS
# ============================================================================

static func _enumerate_build_actions(state: Dictionary) -> Array:
	## Enumerate all valid BUILD_SHIP actions
	var actions = []

	var capacity = FCWReducer.get_production_capacity(state)
	var queue_size = state.production_queue.size()

	if queue_size >= capacity:
		return actions  # Queue full

	# Check each ship type
	for ship_type in FCWTypes.ShipType.values():
		if FCWReducer.can_afford_ship(state, ship_type):
			actions.append(FCWReducer.action_build_ship(ship_type))

	return actions

# ============================================================================
# ASSIGN ACTIONS
# ============================================================================

static func _enumerate_assign_actions(state: Dictionary) -> Array:
	## Enumerate all valid ASSIGN_FLEET actions
	var actions = []

	var available = FCWReducer.get_available_ships(state)
	var controlled = FCWReducer.get_controlled_zones(state)

	for zone_id in controlled:
		for ship_type in available:
			var count = available[ship_type]
			if count > 0:
				# Can assign 1 to all ships
				for n in range(1, count + 1):
					actions.append(FCWReducer.action_assign_fleet(zone_id, ship_type, n))

	return actions

# ============================================================================
# RECALL ACTIONS
# ============================================================================

static func _enumerate_recall_actions(state: Dictionary) -> Array:
	## Enumerate all valid RECALL_FLEET actions
	var actions = []

	var controlled = FCWReducer.get_controlled_zones(state)

	for from_zone in controlled:
		var zone = state.zones.get(from_zone, {})
		var stationed = zone.get("stationed_ships", {})

		for ship_type in stationed:
			var count = stationed[ship_type]
			if count > 0:
				# Recall to reserve pool (-1)
				for n in range(1, count + 1):
					actions.append(FCWReducer.action_recall_fleet(from_zone, -1, ship_type, n))

				# Recall to other zones
				for to_zone in controlled:
					if to_zone != from_zone:
						for n in range(1, count + 1):
							actions.append(FCWReducer.action_recall_fleet(from_zone, to_zone, ship_type, n))

	return actions

# ============================================================================
# ORDER ACTIONS
# ============================================================================

static func _enumerate_order_actions(state: Dictionary) -> Array:
	## Enumerate all valid SET_FLEET_ORDER actions
	var actions = []

	var controlled = FCWReducer.get_controlled_zones(state)

	for zone_id in controlled:
		var zone = state.zones.get(zone_id, {})
		var current_order = zone.get("fleet_order", FCWTypes.FleetOrder.DEFEND)

		# Can set to any order different from current
		for order in FCWTypes.FleetOrder.values():
			if order != current_order:
				actions.append(FCWReducer.action_set_fleet_order(zone_id, order))

	return actions

# ============================================================================
# ENTITY MOVEMENT ACTIONS
# ============================================================================

static func _enumerate_entity_movement_actions(state: Dictionary) -> Array:
	## Enumerate movement actions for player-controlled entities
	var actions = []

	var entities = state.get("entities", [])
	var controlled = FCWReducer.get_controlled_zones(state)

	for entity in entities:
		# Only enumerate for human faction entities
		if entity.get("faction") != FCWTypes.Faction.HUMAN:
			continue

		# Skip weapons (they're fire-and-forget)
		if entity.get("entity_type") == FCWTypes.EntityType.WEAPON:
			continue

		# Skip entities already in transit (simplification)
		if entity.movement_state != FCWTypes.MovementState.ORBITING:
			continue

		var entity_id = entity.id

		# Can set destination to any zone
		for zone_id in state.zones.keys():
			# Skip current location
			var current_zone = entity.get("origin", -1)
			if current_zone < 0:
				current_zone = entity.get("destination", -1)
			if zone_id == current_zone:
				continue

			# Add both route types
			actions.append(FCWReducer.action_set_destination(entity_id, zone_id, "direct"))
			actions.append(FCWReducer.action_set_destination(entity_id, zone_id, "coast"))

	return actions

# ============================================================================
# ACTION FILTERING
# ============================================================================

static func filter_actions_by_type(actions: Array, action_type: String) -> Array:
	## Filter actions to only those of a specific type
	return actions.filter(func(a): return a.get("type") == action_type)

static func filter_high_impact_actions(state: Dictionary) -> Array:
	## Get only "high impact" actions (skip micro-optimizations)
	var actions = []

	# Building ships is always high impact
	actions.append_array(_enumerate_build_actions(state))

	# Assigning full fleet to key zones
	var available = FCWReducer.get_available_ships(state)
	var controlled = FCWReducer.get_controlled_zones(state)

	# Key zones: Earth, Mars, and outermost controlled
	var key_zones = [FCWTypes.ZoneId.EARTH]
	if FCWTypes.ZoneId.MARS in controlled:
		key_zones.append(FCWTypes.ZoneId.MARS)

	# Add outermost zone
	var outer_zone = -1
	var max_radius = 0.0
	for zone_id in controlled:
		var radius = FCWTypes.get_zone_orbital_radius(zone_id)
		if radius > max_radius:
			max_radius = radius
			outer_zone = zone_id
	if outer_zone >= 0 and outer_zone not in key_zones:
		key_zones.append(outer_zone)

	# Only enumerate full fleet assignments to key zones
	for zone_id in key_zones:
		for ship_type in available:
			if available[ship_type] > 0:
				actions.append(FCWReducer.action_assign_fleet(zone_id, ship_type, available[ship_type]))

	return actions

# ============================================================================
# DECISION ANALYSIS
# ============================================================================

static func analyze_decision_complexity(state: Dictionary, depth: int = 1) -> Dictionary:
	## Analyze decision tree complexity at given depth
	## depth=1: immediate actions
	## depth=2: actions + one tick + actions
	## etc.

	if depth <= 0:
		return {"depth": 0, "branches": 1, "terminal": true}

	var actions = get_valid_actions(state)

	if actions.is_empty() or state.game_over:
		return {"depth": depth, "branches": 0, "terminal": true}

	if depth == 1:
		return {"depth": 1, "branches": actions.size(), "terminal": false}

	# For depth > 1, would need to simulate each action
	# This gets exponentially expensive, so just estimate
	var avg_branching = actions.size()
	var estimated_nodes = 1
	for _i in range(depth):
		estimated_nodes *= avg_branching

	return {
		"depth": depth,
		"immediate_branches": actions.size(),
		"estimated_nodes": estimated_nodes,
		"warning": "Depth > 1 is estimated, not computed"
	}

static func get_action_description(action: Dictionary) -> String:
	## Get human-readable description of an action
	var action_type = action.get("type", "UNKNOWN")

	match action_type:
		"BUILD_SHIP":
			var ship_type = action.get("ship_type", 0)
			return "Build %s" % FCWTypes.get_ship_name(ship_type)

		"ASSIGN_FLEET":
			var zone_id = action.get("zone_id", 0)
			var ship_type = action.get("ship_type", 0)
			var count = action.get("count", 1)
			return "Assign %d %s to %s" % [count, FCWTypes.get_ship_name(ship_type), FCWTypes.get_zone_name(zone_id)]

		"RECALL_FLEET":
			var from_zone = action.get("from_zone", 0)
			var to_zone = action.get("to_zone", -1)
			var ship_type = action.get("ship_type", 0)
			var count = action.get("count", 1)
			var dest = "reserve" if to_zone < 0 else FCWTypes.get_zone_name(to_zone)
			return "Recall %d %s from %s to %s" % [count, FCWTypes.get_ship_name(ship_type), FCWTypes.get_zone_name(from_zone), dest]

		"SET_FLEET_ORDER":
			var zone_id = action.get("zone_id", 0)
			var order = action.get("order", 0)
			return "Set %s to %s" % [FCWTypes.get_zone_name(zone_id), FCWTypes.FleetOrder.keys()[order]]

		"SET_DESTINATION":
			var entity_id = action.get("entity_id", "")
			var zone_id = action.get("zone_id", 0)
			var route_type = action.get("route_type", "direct")
			return "Send %s to %s via %s" % [entity_id, FCWTypes.get_zone_name(zone_id), route_type]

		_:
			return "%s: %s" % [action_type, str(action)]
