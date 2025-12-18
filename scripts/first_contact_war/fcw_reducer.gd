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
	EVACUATE_ZONE
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

	# 3. Fleet transit - advance fleets in transit, complete arrivals
	new_state = _process_fleet_transit(new_state)

	# 4. Herald transit - advance Herald toward its target
	new_state = _process_herald_transit(new_state)

	# 5. Combat phase - resolve Herald attacks (only if Herald has arrived)
	var combat_result = _process_combat(new_state, random_values[random_idx] if random_idx < random_values.size() else 0.5)
	random_idx += 1
	new_state = combat_result.state

	# 6. Herald advance - pick next target after combat
	new_state = _process_herald_advance(new_state)

	# 7. Evacuation - process any escaping civilians (spawns colony ships)
	new_state = _process_evacuation(new_state)

	# 8. Colony ship transit - advance colony ships, check for interception
	new_state = _process_colony_ships(new_state)

	# 9. Check game over
	if new_state.zones[FCWTypes.ZoneId.EARTH].status == FCWTypes.ZoneStatus.FALLEN:
		new_state.game_over = true
		new_state.victory_tier = FCWTypes.get_victory_tier(new_state.lives_evacuated)

	# 10. Advance turn
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

static func _process_fleet_transit(state: Dictionary) -> Dictionary:
	## Advance fleets in transit and complete arrivals
	## Also handles: destination fell (redirect), interception by Herald
	var new_state = state.duplicate(true)
	var remaining_transit: Array = []
	var herald_zone = new_state.get("herald_current_zone", FCWTypes.ZoneId.KUIPER)
	var herald_transit = new_state.get("herald_transit", {})

	for transit in new_state.get("fleets_in_transit", []):
		var updated = transit.duplicate()
		var dest_zone = new_state.zones[transit.to_zone]

		# Check if destination fell - redirect immediately (don't wait for arrival)
		if dest_zone.status == FCWTypes.ZoneStatus.FALLEN:
			# Find nearest controlled zone to redirect to
			var redirect_zone = _find_nearest_controlled_zone(new_state, transit.from_zone)
			if redirect_zone >= 0:
				# Create new transit order to redirect zone
				var new_travel_time = FCWTypes.get_travel_time(transit.to_zone, redirect_zone)
				var speed_mod = FCWTypes.get_ship_speed_modifier(transit.ship_type)
				updated.to_zone = redirect_zone
				updated.turns_remaining = maxi(1, int(ceil(new_travel_time * speed_mod)))
				updated.total_turns = updated.turns_remaining
				remaining_transit.append(updated)

				new_state.event_log.append(FCWTypes.create_log_entry(
					new_state.turn,
					"%d %s(s) redirecting to %s - %s has fallen" % [
						transit.count,
						FCWTypes.get_ship_name(transit.ship_type),
						FCWTypes.get_zone_name(redirect_zone),
						FCWTypes.get_zone_name(transit.to_zone)
					],
					true
				))
			else:
				# No controlled zones left - ships lost
				new_state.event_log.append(FCWTypes.create_log_entry(
					new_state.turn,
					"%d %s(s) lost - no safe harbor remaining" % [
						transit.count,
						FCWTypes.get_ship_name(transit.ship_type)
					],
					true
				))
			continue

		# Check for Herald interception
		# Fleets can be intercepted if Herald is at a zone on their path or adjacent to their route
		var intercepted = _check_fleet_interception(new_state, transit, herald_zone, herald_transit)
		if intercepted.is_intercepted:
			# Interception battle - fleet takes losses or is destroyed
			var losses = _resolve_interception(new_state, transit, intercepted.interception_strength)
			if losses.survivors > 0:
				# Survivors continue
				updated.count = losses.survivors
				updated.turns_remaining -= 1
				if updated.turns_remaining > 0:
					remaining_transit.append(updated)
				else:
					# Arrived despite interception
					_complete_fleet_arrival(new_state, updated)
			new_state.event_log.append(FCWTypes.create_log_entry(
				new_state.turn,
				"INTERCEPTION: %d %s(s) attacked en route to %s - %d destroyed, %d continue" % [
					transit.count,
					FCWTypes.get_ship_name(transit.ship_type),
					FCWTypes.get_zone_name(transit.to_zone),
					losses.destroyed,
					losses.survivors
				],
				true
			))
			continue

		# Normal transit - advance by 1 week
		updated.turns_remaining -= 1

		if updated.turns_remaining <= 0:
			# Fleet arrived at destination
			_complete_fleet_arrival(new_state, updated)
			new_state.event_log.append(FCWTypes.create_log_entry(
				new_state.turn,
				"%d %s(s) arrived at %s" % [
					transit.count,
					FCWTypes.get_ship_name(transit.ship_type),
					FCWTypes.get_zone_name(transit.to_zone)
				]
			))
		else:
			remaining_transit.append(updated)

	new_state.fleets_in_transit = remaining_transit
	return new_state

static func _find_nearest_controlled_zone(state: Dictionary, from_zone: int) -> int:
	## Find the nearest controlled zone to redirect to
	## Prioritizes Earth, then Mars, then others by distance
	var controlled = get_controlled_zones(state)
	if controlled.is_empty():
		return -1

	# Prioritize Earth if controlled
	if FCWTypes.ZoneId.EARTH in controlled:
		return FCWTypes.ZoneId.EARTH

	# Otherwise find nearest
	var nearest = controlled[0]
	var nearest_dist = FCWTypes.get_travel_time(from_zone, nearest)
	for zone_id in controlled:
		var dist = FCWTypes.get_travel_time(from_zone, zone_id)
		if dist < nearest_dist:
			nearest = zone_id
			nearest_dist = dist
	return nearest

static func _check_fleet_interception(state: Dictionary, transit: Dictionary, herald_zone: int, herald_transit: Dictionary) -> Dictionary:
	## Check if a fleet in transit can be intercepted by Herald
	## Returns {is_intercepted: bool, interception_strength: int}

	# Can't intercept during peace period
	if state.turn <= 3:
		return {"is_intercepted": false, "interception_strength": 0}

	var from_zone = transit.from_zone
	var to_zone = transit.to_zone
	var herald_strength = state.herald_strength

	# Herald intercepts if:
	# 1. Herald is at the destination zone (blockade)
	# 2. Herald is at a zone adjacent to both from and to (ambush)
	# 3. Herald is in transit and paths cross

	# Case 1: Herald at destination - blockade
	if herald_zone == to_zone:
		# Full strength interception
		return {"is_intercepted": true, "interception_strength": herald_strength}

	# Case 2: Herald at adjacent zone to route
	var from_connections = FCWTypes.ZONE_CONNECTIONS.get(from_zone, [])
	var to_connections = FCWTypes.ZONE_CONNECTIONS.get(to_zone, [])
	if herald_zone in from_connections and herald_zone in to_connections:
		# Partial interception (Herald detaches raiding force)
		return {"is_intercepted": true, "interception_strength": int(herald_strength * 0.3)}

	# Case 3: Herald in transit crossing paths
	if not herald_transit.is_empty():
		var herald_from = herald_transit.from_zone
		var herald_to = herald_transit.to_zone
		# Paths cross if they share zones
		if (herald_from == to_zone or herald_to == from_zone or
			herald_from == from_zone or herald_to == to_zone):
			# Chance encounter - weaker interception
			return {"is_intercepted": true, "interception_strength": int(herald_strength * 0.2)}

	return {"is_intercepted": false, "interception_strength": 0}

static func _resolve_interception(state: Dictionary, transit: Dictionary, interception_strength: int) -> Dictionary:
	## Resolve an interception battle
	## Returns {survivors: int, destroyed: int}
	var ship_type = transit.ship_type
	var count = transit.count
	var combat_power = FCWTypes.get_ship_combat_power(ship_type)
	var fleet_strength = combat_power * count

	# Combat resolution - fleet vs interception force
	if fleet_strength >= interception_strength:
		# Fleet strong enough - minor losses (10-30%)
		var loss_ratio = 0.1 + randf() * 0.2
		var destroyed = int(count * loss_ratio)
		return {"survivors": count - destroyed, "destroyed": destroyed}
	elif fleet_strength >= interception_strength * 0.5:
		# Outgunned but not hopeless - heavy losses (40-70%)
		var loss_ratio = 0.4 + randf() * 0.3
		var destroyed = int(count * loss_ratio)
		return {"survivors": maxi(1, count - destroyed), "destroyed": destroyed}
	else:
		# Overwhelmed - devastating losses (70-100%)
		var loss_ratio = 0.7 + randf() * 0.3
		var destroyed = int(count * loss_ratio)
		return {"survivors": maxi(0, count - destroyed), "destroyed": destroyed}

static func _complete_fleet_arrival(state: Dictionary, transit: Dictionary) -> void:
	## Complete a fleet arrival at destination
	var dest_zone = state.zones[transit.to_zone]
	if dest_zone.status == FCWTypes.ZoneStatus.CONTROLLED:
		var fleet = dest_zone.assigned_fleet.duplicate()
		fleet[transit.ship_type] = fleet.get(transit.ship_type, 0) + transit.count
		dest_zone.assigned_fleet = fleet
		state.zones[transit.to_zone] = dest_zone

static func _process_herald_transit(state: Dictionary) -> Dictionary:
	## Advance Herald toward its target zone - Herald takes time to travel
	var new_state = state.duplicate(true)
	var transit = new_state.get("herald_transit", {})

	if transit.is_empty():
		# Herald is not in transit
		return new_state

	# Advance Herald travel
	transit = transit.duplicate()
	transit.turns_remaining -= 1

	if transit.turns_remaining <= 0:
		# Herald arrived at destination
		new_state.herald_current_zone = transit.to_zone
		new_state.herald_transit = {}

		new_state.event_log.append(FCWTypes.create_log_entry(
			new_state.turn,
			"HERALD FLEET arrived at %s" % FCWTypes.get_zone_name(transit.to_zone),
			true
		))
	else:
		new_state.herald_transit = transit
		# Log progress
		new_state.event_log.append(FCWTypes.create_log_entry(
			new_state.turn,
			"HERALD FLEET en route to %s (%d weeks remaining)" % [
				FCWTypes.get_zone_name(transit.to_zone),
				transit.turns_remaining
			]
		))

	return new_state

static func _process_combat(state: Dictionary, random_value: float) -> Dictionary:
	var new_state = state.duplicate(true)
	var target_zone_id = new_state.herald_attack_target
	var zone = new_state.zones[target_zone_id]

	# PEACE PERIOD: Herald doesn't attack for the first 3 turns
	# This gives players time to see civilian traffic, build up defenses, and understand the map
	const PEACE_TURNS = 3
	if new_state.turn <= PEACE_TURNS:
		return {"state": new_state, "battle_occurred": false, "peace_period": true}

	# IN TRANSIT: Herald can't attack while traveling between zones
	var herald_transit = new_state.get("herald_transit", {})
	if not herald_transit.is_empty():
		return {"state": new_state, "battle_occurred": false, "in_transit": true}

	# Herald must be at the target zone to attack
	var herald_zone = new_state.get("herald_current_zone", FCWTypes.ZoneId.KUIPER)
	if herald_zone != target_zone_id:
		return {"state": new_state, "battle_occurred": false, "wrong_zone": true}

	if zone.status == FCWTypes.ZoneStatus.FALLEN:
		return {"state": new_state, "battle_occurred": false}

	# Calculate defender strength
	var defender_strength = calc_zone_defense(new_state, target_zone_id)
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

static func calc_zone_defense(state: Dictionary, zone_id: int) -> int:
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
	## Herald picks next target and starts transit if needed
	var new_state = state.duplicate(true)

	# Don't advance if already in transit
	var herald_transit = new_state.get("herald_transit", {})
	if not herald_transit.is_empty():
		return new_state

	var current_zone = new_state.get("herald_current_zone", FCWTypes.ZoneId.KUIPER)
	var current_target = new_state.herald_attack_target

	# If current target zone hasn't fallen yet and Herald is there, keep attacking
	var target_zone = new_state.zones[current_target]
	if target_zone.status != FCWTypes.ZoneStatus.FALLEN and current_zone == current_target:
		return new_state

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
	var weakest_defense = calc_zone_defense(new_state, weakest_id)

	for target_id in potential_targets:
		var defense = calc_zone_defense(new_state, target_id)
		if defense < weakest_defense:
			weakest_defense = defense
			weakest_id = target_id

	new_state.herald_attack_target = weakest_id

	# If Herald needs to travel to the new target, start transit
	if current_zone != weakest_id:
		new_state.herald_transit = FCWTypes.create_herald_transit(current_zone, weakest_id)

		new_state.event_log.append(FCWTypes.create_log_entry(
			new_state.turn,
			"HERALD FLEET departing %s for %s (ETA: %d weeks)" % [
				FCWTypes.get_zone_name(current_zone),
				FCWTypes.get_zone_name(weakest_id),
				new_state.herald_transit.total_turns
			],
			true
		))

	return new_state

static func _process_evacuation(state: Dictionary) -> Dictionary:
	## Spawn colony ships carrying evacuees - they must reach safety to count
	var new_state = state.duplicate(true)

	# Ships assigned to Earth automatically help with evacuation
	# Each ship evacuates people based on its size (combat power / 10 * 100K)
	var earth = new_state.zones[FCWTypes.ZoneId.EARTH]
	if earth.status == FCWTypes.ZoneStatus.FALLEN:
		return new_state

	var evacuation_capacity = 0
	for ship_type in earth.assigned_fleet:
		var count = earth.assigned_fleet[ship_type]
		var ship_power = FCWTypes.get_ship_combat_power(ship_type)
		# Carriers are ESSENTIAL for evacuation - they're civilian transports
		# 8x multiplier makes carriers the key strategic choice for saving lives
		var multiplier = 8.0 if ship_type == FCWTypes.ShipType.CARRIER else 1.0
		evacuation_capacity += int(count * (ship_power / 10.0) * 100_000 * multiplier)

	if evacuation_capacity > 0:
		var evacuated = mini(evacuation_capacity, earth.population)
		earth.population -= evacuated
		new_state.zones[FCWTypes.ZoneId.EARTH] = earth

		if evacuated > 0:
			# Spawn colony ships carrying evacuees (500K per ship)
			const SOULS_PER_SHIP = 500_000
			var remaining = evacuated
			var colony_ships = new_state.get("colony_ships_in_transit", []).duplicate()

			while remaining > 0:
				var ship_souls = mini(SOULS_PER_SHIP, remaining)
				remaining -= ship_souls
				var ship = FCWTypes.create_colony_ship(ship_souls)
				colony_ships.append(ship)

				new_state.event_log.append(FCWTypes.create_log_entry(
					new_state.turn,
					"Colony ship '%s' departing with %s souls" % [
						ship.name,
						FCWTypes.format_population(ship_souls)
					]
				))

			new_state.colony_ships_in_transit = colony_ships

	return new_state

static func _process_colony_ships(state: Dictionary) -> Dictionary:
	## Advance colony ships toward safety, check for Herald interception
	var new_state = state.duplicate(true)
	var remaining_ships: Array = []
	var herald_zone = new_state.get("herald_current_zone", FCWTypes.ZoneId.KUIPER)
	var herald_transit = new_state.get("herald_transit", {})
	var herald_strength = new_state.herald_strength

	for ship in new_state.get("colony_ships_in_transit", []):
		var updated = ship.duplicate()

		# Check for Herald interception - colony ships leaving Earth can be caught
		# Herald intercepts if at Earth, Mars, or in transit near Earth corridor
		var is_intercepted = false
		if new_state.turn > 3:  # No interception during peace
			if herald_zone == FCWTypes.ZoneId.EARTH or herald_zone == FCWTypes.ZoneId.MARS:
				# High chance of interception near inner planets
				is_intercepted = randf() < 0.4
			elif not herald_transit.is_empty():
				# Check if Herald transit crosses escape corridor
				var herald_to = herald_transit.to_zone
				if herald_to == FCWTypes.ZoneId.EARTH or herald_to == FCWTypes.ZoneId.MARS:
					is_intercepted = randf() < 0.2

		if is_intercepted:
			# Colony ship destroyed - all souls lost
			var souls_lost = updated.souls_aboard
			new_state.lives_intercepted = new_state.get("lives_intercepted", 0) + souls_lost

			new_state.event_log.append(FCWTypes.create_log_entry(
				new_state.turn,
				"TRAGEDY: Colony ship '%s' intercepted - %s souls lost" % [
					updated.name,
					FCWTypes.format_population(souls_lost)
				],
				true
			))
			continue  # Ship destroyed, don't add to remaining

		# Advance toward safety
		updated.turns_remaining -= 1

		if updated.turns_remaining <= 0:
			# Ship reached safety! Add to evacuated count
			var souls_safe = updated.souls_aboard
			new_state.lives_evacuated += souls_safe
			new_state.colony_ships_safe = new_state.get("colony_ships_safe", 0) + 1

			new_state.event_log.append(FCWTypes.create_log_entry(
				new_state.turn,
				"Colony ship '%s' reached safety - %s souls saved" % [
					updated.name,
					FCWTypes.format_population(souls_safe)
				]
			))
		else:
			remaining_ships.append(updated)

	new_state.colony_ships_in_transit = remaining_ships
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

	# Get available ships (not assigned anywhere and not in transit)
	var available = get_available_ships(new_state).get(ship_type, 0)
	var to_assign = mini(count, available)

	if to_assign <= 0:
		return state

	# Ships originate from Earth (production hub) and must travel to destination
	var from_zone = FCWTypes.ZoneId.EARTH

	# If destination is Earth, assign immediately (no travel needed)
	if zone_id == FCWTypes.ZoneId.EARTH:
		var zone = new_state.zones[zone_id]
		var fleet = zone.assigned_fleet.duplicate()
		fleet[ship_type] = fleet.get(ship_type, 0) + to_assign
		zone.assigned_fleet = fleet
		new_state.zones[zone_id] = zone
	else:
		# Create transit order - ships will arrive after travel time
		var transit = new_state.fleets_in_transit.duplicate()
		transit.append(FCWTypes.create_transit_order(from_zone, zone_id, ship_type, to_assign))
		new_state.fleets_in_transit = transit

		# Log the departure
		var travel_time = FCWTypes.get_travel_time(from_zone, zone_id)
		new_state.event_log.append(FCWTypes.create_log_entry(
			new_state.turn,
			"%d %s(s) departing for %s (ETA: %d weeks)" % [
				to_assign,
				FCWTypes.get_ship_name(ship_type),
				FCWTypes.get_zone_name(zone_id),
				travel_time
			]
		))

	return new_state

static func _reduce_set_fleet_order(state: Dictionary, zone_id: int, order: int) -> Dictionary:
	var new_state = state.duplicate(true)
	var orders = new_state.fleet_orders.duplicate()
	orders[zone_id] = order
	new_state.fleet_orders = orders
	return new_state

static func _reduce_evacuate_zone(state: Dictionary, _zone_id: int) -> Dictionary:
	# NOTE: Manual evacuation is not currently implemented.
	# Evacuation happens automatically in _process_evacuation() based on
	# ships assigned to Earth. This action is reserved for future use
	# where players can manually trigger priority evacuation of specific zones.
	return state

# ============================================================================
# QUERY FUNCTIONS
# ============================================================================

static func get_available_ships(state: Dictionary) -> Dictionary:
	var available = state.fleet.duplicate()

	# Subtract ships assigned to zones
	for zone_id in state.zones:
		var zone = state.zones[zone_id]
		for ship_type in zone.assigned_fleet:
			available[ship_type] = available.get(ship_type, 0) - zone.assigned_fleet.get(ship_type, 0)

	# Subtract ships in transit
	for transit in state.get("fleets_in_transit", []):
		var ship_type = transit.ship_type
		available[ship_type] = available.get(ship_type, 0) - transit.count

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
