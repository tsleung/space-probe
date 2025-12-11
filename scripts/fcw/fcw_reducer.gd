extends RefCounted
class_name FCWReducer

## First Contact War - Pure Reducer
## All functions are static and deterministic

# ============================================================================
# ACTION TYPES
# ============================================================================

enum ActionType {
	END_TURN,
	BUILD_SHIP,
	ASSIGN_FLEET,
	SET_FLEET_ORDER,
	EVACUATE_ZONE,
	APPLY_EVENT_CHOICE
}

# ============================================================================
# ACTION CREATORS
# ============================================================================

static func action_end_turn(random_values: Array) -> Dictionary:
	return {"type": ActionType.END_TURN, "random_values": random_values}

static func action_build_ship(ship_type: int) -> Dictionary:
	return {"type": ActionType.BUILD_SHIP, "ship_type": ship_type}

static func action_assign_fleet(zone_id: int, ship_type: int, count: int) -> Dictionary:
	return {"type": ActionType.ASSIGN_FLEET, "zone_id": zone_id, "ship_type": ship_type, "count": count}

static func action_set_fleet_order(zone_id: int, order: int) -> Dictionary:
	return {"type": ActionType.SET_FLEET_ORDER, "zone_id": zone_id, "order": order}

static func action_evacuate_zone(zone_id: int) -> Dictionary:
	return {"type": ActionType.EVACUATE_ZONE, "zone_id": zone_id}

static func action_apply_event_choice(choice_id: String, random_value: float) -> Dictionary:
	return {"type": ActionType.APPLY_EVENT_CHOICE, "choice_id": choice_id, "random_value": random_value}

# ============================================================================
# MAIN REDUCER
# ============================================================================

static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	match action.type:
		ActionType.END_TURN:
			return _reduce_end_turn(state, action.random_values)
		ActionType.BUILD_SHIP:
			return _reduce_build_ship(state, action.ship_type)
		ActionType.ASSIGN_FLEET:
			return _reduce_assign_fleet(state, action.zone_id, action.ship_type, action.count)
		ActionType.SET_FLEET_ORDER:
			return _reduce_set_fleet_order(state, action.zone_id, action.order)
		ActionType.EVACUATE_ZONE:
			return _reduce_evacuate_zone(state, action.zone_id)
		_:
			return state

# ============================================================================
# TURN PROCESSING
# ============================================================================

static func _reduce_end_turn(state: Dictionary, random_values: Array) -> Dictionary:
	if state.game_over:
		return state

	var new_state = state.duplicate(true)
	var random_idx = 0

	# 1. Production phase - gather resources from controlled zones
	new_state = _process_production(new_state)

	# 2. Ship construction - advance queue
	new_state = _process_ship_construction(new_state)

	# 3. Combat phase - resolve Herald attacks
	var combat_result = _process_combat(new_state, random_values[random_idx] if random_idx < random_values.size() else 0.5)
	random_idx += 1
	new_state = combat_result.state

	# 4. Herald advance - pick next target
	new_state = _process_herald_advance(new_state)

	# 5. Evacuation - process any escaping civilians
	new_state = _process_evacuation(new_state)

	# 6. Check game over
	if new_state.zones[FCWTypes.ZoneId.EARTH].status == FCWTypes.ZoneStatus.FALLEN:
		new_state.game_over = true
		new_state.victory_tier = FCWTypes.get_victory_tier(new_state.lives_evacuated)

	# 7. Advance turn
	new_state.turn += 1
	new_state.herald_strength = FCWTypes.get_herald_strength_for_turn(new_state.turn)

	return new_state

static func _process_production(state: Dictionary) -> Dictionary:
	var new_state = state.duplicate(true)
	var resources = new_state.resources.duplicate()

	for zone_id in new_state.zones:
		var zone = new_state.zones[zone_id]
		if zone.status != FCWTypes.ZoneStatus.CONTROLLED:
			continue

		# Process each building in the zone
		for building_type in zone.buildings:
			var count = zone.buildings[building_type]
			var building_def = FCWTypes.BUILDING_DEFS[building_type]

			# Check if we have inputs
			var can_produce = true
			for input_res in building_def.input:
				if resources.get(input_res, 0) < building_def.input[input_res] * count:
					can_produce = false
					break

			if can_produce:
				# Consume inputs
				for input_res in building_def.input:
					resources[input_res] -= building_def.input[input_res] * count

				# Produce outputs
				for output_res in building_def.output:
					resources[output_res] = resources.get(output_res, 0) + building_def.output[output_res] * count

		# Zone bonuses
		match FCWTypes.ZONE_RESOURCES.get(zone_id, ""):
			"ore":
				resources["ore"] = resources.get("ore", 0) + 5
			"energy":
				resources["energy"] = resources.get("energy", 0) + 10
			"rare":
				resources["rare"] = resources.get("rare", 0) + 3

	new_state.resources = resources
	return new_state

static func _process_ship_construction(state: Dictionary) -> Dictionary:
	var new_state = state.duplicate(true)
	var new_queue: Array = []
	var fleet = new_state.fleet.duplicate()

	for order in new_state.production_queue:
		var updated = order.duplicate()
		updated.turns_remaining -= 1

		if updated.turns_remaining <= 0:
			# Ship completed
			fleet[order.ship_type] = fleet.get(order.ship_type, 0) + 1
			new_state.event_log.append(FCWTypes.create_log_entry(
				new_state.turn,
				"%s completed" % FCWTypes.get_ship_name(order.ship_type)
			))
		else:
			new_queue.append(updated)

	new_state.production_queue = new_queue
	new_state.fleet = fleet
	return new_state

static func _process_combat(state: Dictionary, random_value: float) -> Dictionary:
	var new_state = state.duplicate(true)
	var target_zone_id = new_state.herald_attack_target
	var zone = new_state.zones[target_zone_id]

	if zone.status == FCWTypes.ZoneStatus.FALLEN:
		return {"state": new_state, "battle_occurred": false}

	# Calculate defender strength
	var defender_strength = _calc_zone_defense(new_state, target_zone_id)
	var herald_strength = new_state.herald_strength

	# Mark zone as under attack
	zone.status = FCWTypes.ZoneStatus.UNDER_ATTACK
	new_state.zones[target_zone_id] = zone

	# Combat resolution (simple comparison with variance)
	var combat_roll = 0.8 + (random_value * 0.4)  # 0.8 - 1.2 variance
	var effective_defense = int(defender_strength * combat_roll)

	var log_entry: Dictionary

	if effective_defense >= herald_strength:
		# Defenders hold!
		zone.status = FCWTypes.ZoneStatus.CONTROLLED

		# Calculate losses (30-50% of defending fleet)
		var loss_ratio = 0.3 + (random_value * 0.2)
		new_state = _apply_fleet_losses(new_state, target_zone_id, loss_ratio)

		log_entry = FCWTypes.create_log_entry(
			new_state.turn,
			"%s HELD! Defense: %d vs Attack: %d" % [FCWTypes.get_zone_name(target_zone_id), effective_defense, herald_strength],
			true
		)
	else:
		# Zone falls
		zone.status = FCWTypes.ZoneStatus.FALLEN

		# All population in zone is lost
		var lives_lost = zone.population
		new_state.lives_lost += lives_lost

		# Fleet in zone is destroyed
		zone.assigned_fleet = {}

		log_entry = FCWTypes.create_log_entry(
			new_state.turn,
			"%s FALLEN. %s lives lost." % [FCWTypes.get_zone_name(target_zone_id), FCWTypes.format_population(lives_lost)],
			true
		)

	new_state.zones[target_zone_id] = zone
	new_state.event_log.append(log_entry)

	return {"state": new_state, "battle_occurred": true}

static func _calc_zone_defense(state: Dictionary, zone_id: int) -> int:
	var zone = state.zones[zone_id]
	var total = 0
	var carrier_bonus = 1.0

	for ship_type in zone.assigned_fleet:
		var count = zone.assigned_fleet[ship_type]
		var power = FCWTypes.get_ship_combat_power(ship_type)
		total += power * count

		# Carrier bonus
		if ship_type == FCWTypes.ShipType.CARRIER:
			carrier_bonus += FCWTypes.SHIP_DEFS[FCWTypes.ShipType.CARRIER].get("defense_bonus", 0) * count

	return int(total * carrier_bonus)

static func _apply_fleet_losses(state: Dictionary, zone_id: int, loss_ratio: float) -> Dictionary:
	var new_state = state.duplicate(true)
	var zone = new_state.zones[zone_id]
	var new_fleet = {}

	for ship_type in zone.assigned_fleet:
		var count = zone.assigned_fleet[ship_type]
		var losses = int(count * loss_ratio)
		var remaining = count - losses
		if remaining > 0:
			new_fleet[ship_type] = remaining

	zone.assigned_fleet = new_fleet
	new_state.zones[zone_id] = zone
	return new_state

static func _process_herald_advance(state: Dictionary) -> Dictionary:
	var new_state = state.duplicate(true)

	# Find next target - weakest adjacent zone to any fallen zone
	var potential_targets: Array = []

	for zone_id in new_state.zones:
		var zone = new_state.zones[zone_id]
		if zone.status == FCWTypes.ZoneStatus.FALLEN:
			# Check adjacent zones
			for adjacent_id in FCWTypes.ZONE_CONNECTIONS[zone_id]:
				var adjacent = new_state.zones[adjacent_id]
				if adjacent.status != FCWTypes.ZoneStatus.FALLEN:
					potential_targets.append(adjacent_id)

	# Also always can attack Kuiper if not fallen
	if new_state.zones[FCWTypes.ZoneId.KUIPER].status != FCWTypes.ZoneStatus.FALLEN:
		potential_targets.append(FCWTypes.ZoneId.KUIPER)

	if potential_targets.is_empty():
		return new_state

	# Pick weakest target
	var weakest_id = potential_targets[0]
	var weakest_defense = _calc_zone_defense(new_state, weakest_id)

	for target_id in potential_targets:
		var defense = _calc_zone_defense(new_state, target_id)
		if defense < weakest_defense:
			weakest_defense = defense
			weakest_id = target_id

	new_state.herald_attack_target = weakest_id
	return new_state

static func _process_evacuation(state: Dictionary) -> Dictionary:
	var new_state = state.duplicate(true)

	# Evacuation capacity based on escort fleet (ships on ESCORT order)
	var escort_capacity = 0

	for zone_id in new_state.fleet_orders:
		if new_state.fleet_orders[zone_id] == FCWTypes.FleetOrder.ESCORT:
			var zone = new_state.zones[zone_id]
			for ship_type in zone.assigned_fleet:
				var count = zone.assigned_fleet[ship_type]
				# Each ship can escort 100K people per turn
				escort_capacity += count * 100_000

	# Evacuate from Earth if possible
	var earth = new_state.zones[FCWTypes.ZoneId.EARTH]
	if earth.status != FCWTypes.ZoneStatus.FALLEN and escort_capacity > 0:
		var evacuated = mini(escort_capacity, earth.population)
		earth.population -= evacuated
		new_state.lives_evacuated += evacuated
		new_state.zones[FCWTypes.ZoneId.EARTH] = earth

		if evacuated > 0:
			new_state.event_log.append(FCWTypes.create_log_entry(
				new_state.turn,
				"Evacuated %s civilians" % FCWTypes.format_population(evacuated)
			))

	return new_state

# ============================================================================
# PLAYER ACTIONS
# ============================================================================

static func _reduce_build_ship(state: Dictionary, ship_type: int) -> Dictionary:
	var ship_def = FCWTypes.SHIP_DEFS[ship_type]
	var cost = ship_def.cost
	var resources = state.resources

	# Check if we can afford it
	for res_type in cost:
		if resources.get(res_type, 0) < cost[res_type]:
			return state  # Can't afford

	# Check shipyard capacity
	var shipyard_count = _count_shipyards(state)
	var in_production = state.production_queue.size()
	if in_production >= shipyard_count:
		return state  # No shipyard capacity

	var new_state = state.duplicate(true)
	var new_resources = new_state.resources.duplicate()

	# Deduct cost
	for res_type in cost:
		new_resources[res_type] -= cost[res_type]

	new_state.resources = new_resources

	# Add to queue
	new_state.production_queue.append(FCWTypes.create_production_order(ship_type))

	return new_state

static func _count_shipyards(state: Dictionary) -> int:
	var total = 0
	for zone_id in state.zones:
		var zone = state.zones[zone_id]
		if zone.status == FCWTypes.ZoneStatus.CONTROLLED:
			total += zone.buildings.get(FCWTypes.BuildingType.SHIPYARD, 0)
	return total

static func _reduce_assign_fleet(state: Dictionary, zone_id: int, ship_type: int, count: int) -> Dictionary:
	var new_state = state.duplicate(true)

	# Get available ships (not assigned anywhere)
	var assigned_total = 0
	for zid in new_state.zones:
		var zone = new_state.zones[zid]
		assigned_total += zone.assigned_fleet.get(ship_type, 0)

	var available = new_state.fleet.get(ship_type, 0) - assigned_total
	var to_assign = mini(count, available)

	if to_assign <= 0:
		return state

	var zone = new_state.zones[zone_id]
	var fleet = zone.assigned_fleet.duplicate()
	fleet[ship_type] = fleet.get(ship_type, 0) + to_assign
	zone.assigned_fleet = fleet
	new_state.zones[zone_id] = zone

	return new_state

static func _reduce_set_fleet_order(state: Dictionary, zone_id: int, order: int) -> Dictionary:
	var new_state = state.duplicate(true)
	var orders = new_state.fleet_orders.duplicate()
	orders[zone_id] = order
	new_state.fleet_orders = orders
	return new_state

static func _reduce_evacuate_zone(state: Dictionary, zone_id: int) -> Dictionary:
	# Move population to evacuation queue (requires escort ships)
	# Simplified: just mark zone for priority evacuation
	var new_state = state.duplicate(true)
	# For now, this is handled in _process_evacuation based on ESCORT orders
	return new_state

# ============================================================================
# QUERY FUNCTIONS
# ============================================================================

static func get_available_ships(state: Dictionary) -> Dictionary:
	var available = state.fleet.duplicate()

	for zone_id in state.zones:
		var zone = state.zones[zone_id]
		for ship_type in zone.assigned_fleet:
			available[ship_type] = available.get(ship_type, 0) - zone.assigned_fleet.get(ship_type, 0)

	return available

static func can_afford_ship(state: Dictionary, ship_type: int) -> bool:
	var ship_def = FCWTypes.SHIP_DEFS[ship_type]
	var cost = ship_def.cost

	for res_type in cost:
		if state.resources.get(res_type, 0) < cost[res_type]:
			return false

	return true

static func get_production_capacity(state: Dictionary) -> int:
	var shipyard_count = _count_shipyards(state)
	var in_production = state.production_queue.size()
	return shipyard_count - in_production

static func get_total_fleet_strength(state: Dictionary) -> int:
	var total = 0
	for ship_type in state.fleet:
		total += FCWTypes.get_ship_combat_power(ship_type) * state.fleet[ship_type]
	return total

static func get_controlled_zones(state: Dictionary) -> Array:
	var controlled: Array = []
	for zone_id in state.zones:
		if state.zones[zone_id].status == FCWTypes.ZoneStatus.CONTROLLED:
			controlled.append(zone_id)
	return controlled

static func estimate_turns_until_earth_attack(state: Dictionary) -> int:
	# Count zones between current target and Earth
	var current = state.herald_attack_target
	if current == FCWTypes.ZoneId.EARTH:
		return 0

	# Simple estimate based on zone depth
	match current:
		FCWTypes.ZoneId.KUIPER:
			return 8
		FCWTypes.ZoneId.JUPITER, FCWTypes.ZoneId.ASTEROID_BELT, FCWTypes.ZoneId.SATURN:
			return 5
		FCWTypes.ZoneId.MARS:
			return 2
		_:
			return 1
