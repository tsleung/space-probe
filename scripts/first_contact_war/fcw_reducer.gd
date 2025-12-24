extends RefCounted
class_name FCWReducer

## First Contact War - Pure Reducer
## All functions are static and deterministic

const FCWTime = preload("res://scripts/first_contact_war/fcw_time.gd")
const FCWTypes = preload("res://scripts/first_contact_war/fcw_types.gd")
const FCWHeraldAI = preload("res://scripts/first_contact_war/fcw_herald_ai.gd")
const FCWOrbital = preload("res://scripts/first_contact_war/fcw_orbital.gd")

# ============================================================================
# ACTION TYPES
# ============================================================================

enum ActionType {
	END_TURN,       # Legacy: advance 1 full week
	TICK,           # NEW: advance 1 hour (primary time advancement)
	BUILD_SHIP,
	ASSIGN_FLEET,
	RECALL_FLEET,   # Move ships from one zone to another (or back to pool)
	SET_FLEET_ORDER,
	EVACUATE_ZONE,
	# New entity-based actions
	SPAWN_ENTITY,
	SET_ENTITY_DESTINATION,
	SET_ENTITY_MOVEMENT_STATE,
	SPLIT_ENTITY,
	LAUNCH_WEAPON  # Fire torpedo/missile from entity
}

# ============================================================================
# ACTION CREATORS
# ============================================================================

static func action_end_turn(random_values: Array) -> Dictionary:
	## DEPRECATED: Use action_tick() instead
	return {"type": ActionType.END_TURN, "random_values": random_values}

static func action_tick(random_values: Array) -> Dictionary:
	## Advance time by 1 hour (the base time unit)
	return {"type": ActionType.TICK, "random_values": random_values}

static func action_build_ship(ship_type: int) -> Dictionary:
	return {"type": ActionType.BUILD_SHIP, "ship_type": ship_type}

static func action_assign_fleet(zone_id: int, ship_type: int, count: int) -> Dictionary:
	return {"type": ActionType.ASSIGN_FLEET, "zone_id": zone_id, "ship_type": ship_type, "count": count}

static func action_recall_fleet(from_zone: int, to_zone: int, ship_type: int, count: int) -> Dictionary:
	## Recall ships from one zone to another (to_zone=-1 means return to reserve pool)
	return {"type": ActionType.RECALL_FLEET, "from_zone": from_zone, "to_zone": to_zone, "ship_type": ship_type, "count": count}

static func action_set_fleet_order(zone_id: int, order: int) -> Dictionary:
	return {"type": ActionType.SET_FLEET_ORDER, "zone_id": zone_id, "order": order}

static func action_evacuate_zone(zone_id: int) -> Dictionary:
	return {"type": ActionType.EVACUATE_ZONE, "zone_id": zone_id}

# New entity-based action creators
static func action_spawn_entity(entity: Dictionary) -> Dictionary:
	return {"type": ActionType.SPAWN_ENTITY, "entity": entity}

static func action_set_destination(entity_id: String, zone_id: int, route_type: String = "direct") -> Dictionary:
	return {"type": ActionType.SET_ENTITY_DESTINATION, "entity_id": entity_id, "zone_id": zone_id, "route_type": route_type}

static func action_set_movement_state(entity_id: String, movement_state: int) -> Dictionary:
	return {"type": ActionType.SET_ENTITY_MOVEMENT_STATE, "entity_id": entity_id, "movement_state": movement_state}

static func action_split_entity(entity_id: String, split_count: int, new_destination: int) -> Dictionary:
	return {"type": ActionType.SPLIT_ENTITY, "entity_id": entity_id, "split_count": split_count, "new_destination": new_destination}

static func action_launch_weapon(entity_id: String, target_entity_id: String, weapon_power: float, powered: bool = false) -> Dictionary:
	## Launch a weapon from an entity toward a target
	## powered = false: unpowered/ballistic launch (stealthy, relies on inherited velocity)
	## powered = true: powered launch (visible, can track target)
	return {
		"type": ActionType.LAUNCH_WEAPON,
		"entity_id": entity_id,
		"target_entity_id": target_entity_id,
		"weapon_power": weapon_power,
		"powered": powered
	}

# ============================================================================
# MAIN REDUCER
# ============================================================================

static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
	match action.type:
		ActionType.END_TURN:
			return _reduce_end_turn(state, action.random_values)
		ActionType.TICK:
			return _reduce_tick(state, action.random_values)
		ActionType.BUILD_SHIP:
			return _reduce_build_ship(state, action.ship_type)
		ActionType.ASSIGN_FLEET:
			return _reduce_assign_fleet(state, action.zone_id, action.ship_type, action.count)
		ActionType.RECALL_FLEET:
			return _reduce_recall_fleet(state, action.from_zone, action.to_zone, action.ship_type, action.count)
		ActionType.SET_FLEET_ORDER:
			return _reduce_set_fleet_order(state, action.zone_id, action.order)
		ActionType.EVACUATE_ZONE:
			return _reduce_evacuate_zone(state, action.zone_id)
		# New entity-based actions
		ActionType.SPAWN_ENTITY:
			return _reduce_spawn_entity(state, action.entity)
		ActionType.SET_ENTITY_DESTINATION:
			return _reduce_set_entity_destination(state, action.entity_id, action.zone_id, action.route_type)
		ActionType.SET_ENTITY_MOVEMENT_STATE:
			return _reduce_set_entity_movement_state(state, action.entity_id, action.movement_state)
		ActionType.SPLIT_ENTITY:
			return _reduce_split_entity(state, action.entity_id, action.split_count, action.new_destination)
		ActionType.LAUNCH_WEAPON:
			return _reduce_launch_weapon(state, action.entity_id, action.target_entity_id, action.weapon_power, action.powered)
		_:
			return state

# ============================================================================
# TURN PROCESSING
# ============================================================================

const MAX_EVENT_LOG_SIZE = 100  # Prevent unbounded growth

static func _reduce_tick(state: Dictionary, random_values: Array) -> Dictionary:
	## Advance time by 1 hour - the primary time advancement action
	## Runs hourly, daily, and weekly updates as appropriate
	if state.game_over:
		return state

	var new_state = state.duplicate(true)
	var old_time = new_state.get("game_time", 0.0)
	var random_idx = 0

	# 0. CLEAR TICK EVENTS: Reset event tracking for this tick
	new_state.tick_events = {
		"intercepts": [],
		"detections": [],
		"arrivals": []
	}

	# Trim event log to prevent memory leak
	while new_state.event_log.size() > MAX_EVENT_LOG_SIZE:
		new_state.event_log.pop_front()

	# 1. SNAPSHOT: Save current positions for interpolation
	new_state = _snapshot_positions(new_state)

	# 2. ADVANCE TIME by 1 hour
	new_state.game_time = old_time + 1.0

	# 3. HOURLY UPDATES (every tick)
	# Entity movement - 1/168th of a week's movement per hour
	new_state = _process_entity_movement_hourly(new_state)

	# Detection checks (simplified hourly)
	new_state = _process_detection_hourly(new_state, random_values[random_idx] if random_idx < random_values.size() else 0.5)
	random_idx += 1

	# 4. DAILY UPDATES (every 24 hours)
	if FCWTime.is_day_boundary(old_time, new_state.game_time):
		# Daily production (1/7th of weekly production)
		new_state = _process_production_daily(new_state)

		# Daily detection update
		new_state = _process_detection(new_state, random_values[random_idx] if random_idx < random_values.size() else 0.5)
		random_idx += 1

	# 5. WEEKLY UPDATES (every 168 hours)
	if FCWTime.is_week_boundary(old_time, new_state.game_time):
		# Full weekly processing
		new_state = _process_weekly_update(new_state, random_values, random_idx)

	# 6. Check game over
	if new_state.zones[FCWTypes.ZoneId.EARTH].status == FCWTypes.ZoneStatus.FALLEN:
		new_state.game_over = true
		new_state.victory_tier = FCWTypes.get_victory_tier(new_state.lives_evacuated)

	return new_state

static func _snapshot_positions(state: Dictionary) -> Dictionary:
	## Save current positions for interpolation before advancing time
	var new_state = state.duplicate(true)

	# Snapshot entity positions
	var entity_positions = {}
	for entity in new_state.get("entities", []):
		entity_positions[entity.id] = entity.position
	new_state.prev_entity_positions = entity_positions

	# Snapshot zone positions
	var zone_positions = {}
	var game_time = new_state.get("game_time", 0.0)
	for zone_id in FCWTypes.ZoneId.values():
		zone_positions[zone_id] = FCWTypes.get_zone_position(zone_id, game_time)
	new_state.prev_zone_positions = zone_positions

	return new_state

static func _process_entity_movement_hourly(state: Dictionary) -> Dictionary:
	## Advance entity positions by 1 hour (1/168th of weekly movement)
	var new_state = state.duplicate(true)
	var game_time = new_state.get("game_time", 0.0)
	var entities = new_state.get("entities", []).duplicate()

	const HOURS_PER_WEEK = 168.0

	for i in range(entities.size()):
		var entity = entities[i].duplicate()

		if entity.movement_state == FCWTypes.MovementState.DESTROYED:
			continue
		if entity.movement_state == FCWTypes.MovementState.ORBITING:
			continue

		# Move entity by 1 hour's worth of velocity
		# Velocity is in AU/week, so divide by hours per week
		entity.position += entity.velocity / HOURS_PER_WEEK

		# Update signature
		if entity.movement_state == FCWTypes.MovementState.BURNING:
			entity.signature = FCWTypes.BURN_SIGNATURE
			# Burning entities accelerate toward destination
			if entity.destination >= 0:
				var dest_pos = FCWTypes.get_zone_position(entity.destination, game_time)
				var direction = (dest_pos - entity.position).normalized()
				entity.velocity += direction * entity.acceleration / HOURS_PER_WEEK
		else:
			entity.signature = FCWTypes.COAST_SIGNATURE

		# Check for arrival (simplified - full check in weekly update)
		if entity.destination >= 0:
			var dest_pos = FCWTypes.get_zone_position(entity.destination, game_time)
			var distance = entity.position.distance_to(dest_pos)
			if distance < 0.1:  # Within 0.1 AU
				entity = _handle_entity_arrival(entity, new_state, game_time)

		entities[i] = entity

	new_state.entities = entities
	return new_state

static func _handle_entity_arrival(entity: Dictionary, state: Dictionary, _game_time: float) -> Dictionary:
	## Handle entity arriving at destination
	var arrived = entity.duplicate()

	# Transports escaping count as saved
	if arrived.get("entity_type") == FCWTypes.EntityType.TRANSPORT:
		# This will be properly counted in weekly update
		arrived.movement_state = FCWTypes.MovementState.ORBITING
		arrived.velocity = Vector2.ZERO
		arrived.origin = arrived.destination
		return arrived

	# Other entities enter orbit
	arrived.movement_state = FCWTypes.MovementState.ORBITING
	arrived.velocity = Vector2.ZERO
	arrived.origin = arrived.destination

	return arrived

static func _process_detection_hourly(state: Dictionary, _random_value: float) -> Dictionary:
	## Lightweight hourly detection check
	## Full detection processing happens daily
	return state

static func _process_production_daily(state: Dictionary) -> Dictionary:
	## Run 1/7th of weekly production
	## For now, just return state - full production happens weekly
	return state

static func _process_weekly_update(state: Dictionary, random_values: Array, random_idx: int) -> Dictionary:
	## Full weekly processing - combat, evacuation, turn advancement
	## Key change: Herald now uses detection-based targeting (see FCWHeraldAI)
	var new_state = state.duplicate(true)

	# Ship construction - advance queue (also tracks activity)
	new_state = _process_ship_construction(new_state)

	# Combat phase - resolve Herald attacks (tracks combat activity)
	var combat_result = _process_combat(new_state, random_values[random_idx] if random_idx < random_values.size() else 0.5)
	new_state = combat_result.state

	# Entity intercepts
	new_state = _process_entity_intercepts(new_state, random_values[random_idx + 1] if random_idx + 1 < random_values.size() else 0.5)

	# Weapon processing
	new_state = _process_weapons(new_state, random_values[random_idx + 2] if random_idx + 2 < random_values.size() else 0.5)

	# *** HERALD WEEKLY TURN ***
	# This is the core of the new timeline model:
	# 1. Updates zone signatures from this week's activity
	# 2. Attacks current zone
	# 3. Chooses next target based on signatures
	# 4. Decays signatures for next week
	# 5. Generates dramatic event messages
	new_state = FCWHeraldAI.process_weekly_herald_turn(new_state)

	# Evacuation
	new_state = _process_evacuation(new_state)

	# Weekly production
	new_state = _process_production(new_state)

	# Advance turn and herald strength
	new_state.turn += 1
	new_state.herald_strength = FCWTypes.get_herald_strength_for_turn(new_state.turn)

	# Traffic decay
	new_state = _process_traffic_decay(new_state)

	return new_state

static func _reduce_end_turn(state: Dictionary, random_values: Array) -> Dictionary:
	## DEPRECATED: Legacy weekly advancement
	## Advances time by 168 hours (1 week) all at once
	if state.game_over:
		return state

	var new_state = state.duplicate(true)
	var random_idx = 0

	# 1. Production phase - gather resources from controlled zones
	new_state = _process_production(new_state)

	# 2. Ship construction - advance queue
	new_state = _process_ship_construction(new_state)

	# 3. Entity movement - advance all entities based on physics
	# (Handles warships, transports, AND Herald entity)
	new_state = _process_entity_movement(new_state, random_values)

	# 4. Detection update - Herald observes signatures, builds intel
	new_state = _process_detection(new_state, random_values[random_idx] if random_idx < random_values.size() else 0.5)
	random_idx += 1

	# 5. Combat phase - resolve Herald attacks (only if Herald has arrived)
	var combat_result = _process_combat(new_state, random_values[random_idx] if random_idx < random_values.size() else 0.5)
	random_idx += 1
	new_state = combat_result.state

	# 5b. Entity intercepts - resolve entity-vs-entity encounters (NEW)
	new_state = _process_entity_intercepts(new_state, random_values[random_idx] if random_idx < random_values.size() else 0.5)
	random_idx += 1

	# 5c. Weapon processing - terminal burns, impacts (NEW)
	new_state = _process_weapons(new_state, random_values[random_idx] if random_idx < random_values.size() else 0.5)
	random_idx += 1

	# 6. Herald advance - pick next target after combat
	new_state = _process_herald_advance(new_state)

	# 7. Evacuation - process any escaping civilians (spawns transport entities)
	# Transport movement and interception handled by entity movement (step 3)
	new_state = _process_evacuation(new_state)

	# 8. Check game over
	if new_state.zones[FCWTypes.ZoneId.EARTH].status == FCWTypes.ZoneStatus.FALLEN:
		new_state.game_over = true
		new_state.victory_tier = FCWTypes.get_victory_tier(new_state.lives_evacuated)

	# 10. Advance turn and game time (by 1 week = 168 hours)
	new_state.turn += 1
	new_state.game_time = new_state.get("game_time", 0.0) + FCWTime.HOURS_PER_WEEK
	new_state.herald_strength = FCWTypes.get_herald_strength_for_turn(new_state.turn)

	# 11. Traffic decay - known routes fade over time
	new_state = _process_traffic_decay(new_state)

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
	var ships_built_this_week = 0

	for order in new_state.production_queue:
		var updated = order.duplicate()
		updated.turns_remaining -= 1

		if updated.turns_remaining <= 0:
			# Ship completed
			fleet[order.ship_type] = fleet.get(order.ship_type, 0) + 1
			ships_built_this_week += 1
			new_state.event_log.append(FCWTypes.create_log_entry(
				new_state.turn,
				"%s completed" % FCWTypes.get_ship_name(order.ship_type)
			))
		else:
			new_queue.append(updated)

	new_state.production_queue = new_queue
	new_state.fleet = fleet

	# Track ship production activity (production happens at Earth)
	if ships_built_this_week > 0:
		new_state = _track_activity(new_state, "ships_built", FCWTypes.ZoneId.EARTH, ships_built_this_week)

	return new_state

# ============================================================================
# ACTIVITY TRACKING (for Herald detection signatures)
# ============================================================================

static func _track_activity(state: Dictionary, activity_type: String, zone_id: int, amount: int = 1) -> Dictionary:
	## Track activity that contributes to zone detection signatures
	## activity_type: "ships_built", "ships_transited", "burns_detected", "combat_events", "evacuations"
	var new_state = state.duplicate(true)
	var activity = new_state.weekly_activity.duplicate(true)

	if not activity.has(activity_type):
		activity[activity_type] = {}

	var zone_activity = activity[activity_type].duplicate()
	zone_activity[zone_id] = zone_activity.get(zone_id, 0) + amount
	activity[activity_type] = zone_activity
	new_state.weekly_activity = activity

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

static func _redirect_entity_from_fallen_zone(entity: Dictionary, state: Dictionary, game_time: float, fallen_zone: int) -> Dictionary:
	## Redirect an entity away from a fallen zone to the nearest safe zone
	## Sets new destination and begins burning toward it
	var redirected = entity.duplicate()

	# Find nearest controlled zone
	var redirect_zone = _find_nearest_controlled_zone(state, fallen_zone)
	if redirect_zone < 0:
		# No safe zones left - entity is stranded
		redirected.destination = -1
		return redirected

	# Set new destination
	redirected.destination = redirect_zone

	# Calculate new velocity toward safe zone
	var to_pos = FCWTypes.get_zone_position(redirect_zone, game_time)
	var direction = (to_pos - redirected.position).normalized()

	# Start burning toward new destination (emergency escape)
	redirected.movement_state = FCWTypes.MovementState.BURNING
	redirected.velocity = direction * redirected.acceleration * 2.0  # Emergency burn
	redirected.signature = FCWTypes.BURN_SIGNATURE

	return redirected


static func _process_combat(state: Dictionary, random_value: float) -> Dictionary:
	var new_state = state.duplicate(true)
	var target_zone_id = new_state.herald_attack_target
	var zone = new_state.zones[target_zone_id]

	# PEACE PERIOD: Herald doesn't attack for the first 3 turns
	# This gives players time to see civilian traffic, build up defenses, and understand the map
	const PEACE_TURNS = 3
	if new_state.turn <= PEACE_TURNS:
		return {"state": new_state, "battle_occurred": false, "peace_period": true}

	# Get Herald entity
	var herald = FCWTypes.get_herald_entity(new_state)
	if herald.is_empty():
		return {"state": new_state, "battle_occurred": false, "no_herald": true}

	# IN TRANSIT: Herald can't attack while traveling between zones
	if herald.movement_state == FCWTypes.MovementState.BURNING:
		return {"state": new_state, "battle_occurred": false, "in_transit": true}

	# Herald must be at the target zone to attack (check origin after orbiting)
	var herald_zone = herald.get("origin", FCWTypes.ZoneId.KUIPER)
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

	# Track combat activity (battles are VERY visible - explosions across the system!)
	new_state = _track_activity(new_state, "combat_events", target_zone_id, 1)

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
	## Herald AI decision making - uses observation-limited predator model
	## "The Herald doesn't care about planets - only human signatures"
	## Herald now uses the entity system for movement
	var new_state = state.duplicate(true)
	var game_time = new_state.get("game_time", 0.0)

	# Find Herald entity
	var herald = FCWTypes.get_herald_entity(new_state)
	if herald.is_empty():
		return new_state  # No Herald entity

	# Don't make new decisions if Herald is in transit
	if herald.movement_state == FCWTypes.MovementState.BURNING:
		return new_state

	# Get current zone from Herald entity's origin
	var current_zone = herald.get("origin", FCWTypes.ZoneId.KUIPER)
	var current_target = new_state.herald_attack_target

	# If current target zone hasn't fallen yet and Herald is there:
	# Check if we should try a different (weaker) target
	var target_zone = new_state.zones[current_target]
	if target_zone.status != FCWTypes.ZoneStatus.FALLEN and current_zone == current_target:
		# Herald was repelled - look for an easier target
		# Find weakest adjacent zone that isn't the current one
		var adjacent_zones = FCWTypes.ZONE_CONNECTIONS.get(current_zone, [])
		var weakest_adjacent = -1
		var weakest_defense = 999999
		for adj_id in adjacent_zones:
			var adj_zone = new_state.zones.get(adj_id)
			if adj_zone and adj_zone.status != FCWTypes.ZoneStatus.FALLEN:
				var defense = calc_zone_defense(new_state, adj_id)
				if defense < weakest_defense:
					weakest_defense = defense
					weakest_adjacent = adj_id

		# If there's a weaker adjacent zone, move there
		if weakest_adjacent >= 0 and weakest_adjacent != current_target:
			var current_defense = calc_zone_defense(new_state, current_target)
			# Move if adjacent zone is weaker OR if we've been attacking this zone for a while
			if weakest_defense < current_defense * 0.8:
				new_state = _set_herald_destination(new_state, weakest_adjacent, game_time)
				new_state.herald_attack_target = weakest_adjacent
				new_state.event_log.append(FCWTypes.create_log_entry(
					new_state.turn,
					"HERALD: Seeking weaker target - moving to %s" % FCWTypes.get_zone_name(weakest_adjacent),
					true
				))
				return new_state

		# Otherwise keep attacking current target
		return new_state

	# Use Herald AI to decide next action
	var ai_decision = FCWHeraldAI.decide_herald_action(new_state, game_time)

	match ai_decision.action_type:
		"intercept":
			# Herald moves to intercept a detected target
			var target_entity = ai_decision.target
			# Find closest zone to intercept position
			var intercept_zone = _find_closest_zone_to_position(target_entity.position, game_time)
			if intercept_zone >= 0 and intercept_zone != current_zone:
				new_state = _set_herald_destination(new_state, intercept_zone, game_time)
				new_state.herald_attack_target = intercept_zone
				new_state.event_log.append(FCWTypes.create_log_entry(
					new_state.turn,
					"HERALD: Pursuing detected target toward %s" % FCWTypes.get_zone_name(intercept_zone),
					true
				))

		"release_drones":
			# Herald releases hunter-killer drones
			var herald_pos = herald.position
			new_state = FCWHeraldAI.spawn_drone_wave(new_state, herald_pos, ai_decision.direction)

		"move":
			# Herald moves toward activity zone
			var target_zone_id = ai_decision.target
			if target_zone_id != current_zone:
				new_state = _set_herald_destination(new_state, target_zone_id, game_time)
				new_state.herald_attack_target = target_zone_id
				new_state.event_log.append(FCWTypes.create_log_entry(
					new_state.turn,
					"HERALD: Moving toward activity at %s" % FCWTypes.get_zone_name(target_zone_id),
					true
				))

		"patrol":
			# Herald patrols a known traffic route
			var patrol_pos = ai_decision.target
			var patrol_zone = _find_closest_zone_to_position(patrol_pos, game_time)
			if patrol_zone >= 0 and patrol_zone != current_zone:
				new_state = _set_herald_destination(new_state, patrol_zone, game_time)
				new_state.event_log.append(FCWTypes.create_log_entry(
					new_state.turn,
					"HERALD: Patrolling known route - %s" % ai_decision.reason
				))

		"hold", _:
			# No activity detected - fall back to legacy targeting
			new_state = _process_herald_advance_legacy(new_state, game_time)

	return new_state

static func _set_herald_destination(state: Dictionary, target_zone: int, game_time: float) -> Dictionary:
	## Set Herald entity's destination and begin movement
	var new_state = state.duplicate(true)
	var entities = new_state.get("entities", []).duplicate()

	for i in range(entities.size()):
		if entities[i].get("id") == FCWTypes.HERALD_ENTITY_ID:
			var herald = entities[i].duplicate()
			var dest_pos = FCWTypes.get_zone_position(target_zone, game_time)
			var direction = (dest_pos - herald.position).normalized()

			herald.destination = target_zone
			herald.movement_state = FCWTypes.MovementState.BURNING
			herald.velocity = direction * herald.acceleration * 2.0
			herald.signature = FCWTypes.BURN_SIGNATURE
			entities[i] = herald
			break

	new_state.entities = entities
	return new_state

static func _process_herald_advance_legacy(state: Dictionary, game_time: float) -> Dictionary:
	## Legacy Herald targeting - picks weakest adjacent zone
	## Used when no activity detected by Herald AI
	var new_state = state.duplicate(true)

	# Get current zone from Herald entity
	var herald = FCWTypes.get_herald_entity(new_state)
	var current_zone = herald.get("origin", FCWTypes.ZoneId.KUIPER) if not herald.is_empty() else FCWTypes.ZoneId.KUIPER

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

	# If Herald needs to travel to the new target, start movement
	if current_zone != weakest_id:
		var travel_time = FCWTypes.get_travel_time(current_zone, weakest_id)
		new_state = _set_herald_destination(new_state, weakest_id, game_time)

		new_state.event_log.append(FCWTypes.create_log_entry(
			new_state.turn,
			"HERALD FLEET departing %s for %s (ETA: ~%d weeks)" % [
				FCWTypes.get_zone_name(current_zone),
				FCWTypes.get_zone_name(weakest_id),
				travel_time
			],
			true
		))

	return new_state

static func _find_closest_zone_to_position(pos: Vector2, game_time: float) -> int:
	## Find the zone closest to a given position
	var closest_zone = -1
	var closest_dist = 999.0

	for zone_id in FCWTypes.ZoneId.values():
		var zone_pos = FCWTypes.get_zone_position(zone_id, game_time)
		var dist = pos.distance_to(zone_pos)
		if dist < closest_dist:
			closest_dist = dist
			closest_zone = zone_id

	return closest_zone

static func _process_evacuation(state: Dictionary) -> Dictionary:
	## Spawn transport entities carrying evacuees - they must reach safety to count
	## Transports now use the unified entity system and are visualized on the solar map
	var new_state = state.duplicate(true)
	var game_time = new_state.get("game_time", 0.0)

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
			# Spawn transport entities carrying evacuees (500K per ship)
			const SOULS_PER_SHIP = 500_000
			var remaining = evacuated
			var entities = new_state.get("entities", []).duplicate()
			var earth_pos = FCWTypes.get_zone_position(FCWTypes.ZoneId.EARTH, game_time)
			# Transports flee toward Kuiper Belt (escaping the solar system)
			var escape_destination = FCWTypes.ZoneId.KUIPER
			var escape_pos = FCWTypes.get_zone_position(escape_destination, game_time)
			var escape_direction = (escape_pos - earth_pos).normalized()

			while remaining > 0:
				var ship_souls = mini(SOULS_PER_SHIP, remaining)
				remaining -= ship_souls

				# Create transport entity with position and destination
				var transport = FCWTypes.create_transport(earth_pos, ship_souls)
				transport.destination = escape_destination
				transport.origin = FCWTypes.ZoneId.EARTH
				transport.movement_state = FCWTypes.MovementState.BURNING
				# Set initial velocity toward escape destination
				transport.velocity = escape_direction * transport.acceleration * 2.0
				entities.append(transport)

				new_state.event_log.append(FCWTypes.create_log_entry(
					new_state.turn,
					"Transport '%s' departing with %s souls" % [
						transport.name,
						FCWTypes.format_population(ship_souls)
					]
				))

			new_state.entities = entities

			# Track evacuation activity (transports departing = visible!)
			new_state = _track_activity(new_state, "evacuations", FCWTypes.ZoneId.EARTH, evacuated)
			# Also track burns from departing transports
			var num_transports = ceili(float(evacuated) / 500_000.0)
			new_state = _track_activity(new_state, "burns_detected", FCWTypes.ZoneId.EARTH, num_transports)

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
	var game_time = new_state.get("game_time", 0.0)

	# Get available ships (not assigned anywhere and not in transit)
	var available = get_available_ships(new_state).get(ship_type, 0)
	var to_assign = mini(count, available)

	if to_assign <= 0:
		return state

	# Ships originate from Earth (production hub) and must travel to destination
	var from_zone = FCWTypes.ZoneId.EARTH
	var earth_pos = FCWTypes.get_zone_position(from_zone, game_time)

	# If destination is Earth, create orbiting entity (no travel needed)
	if zone_id == FCWTypes.ZoneId.EARTH:
		var entity = FCWTypes.create_warship(ship_type, earth_pos, to_assign)
		entity.destination = zone_id
		entity.origin = zone_id
		entity.movement_state = FCWTypes.MovementState.ORBITING
		var entities = new_state.get("entities", []).duplicate()
		entities.append(entity)
		new_state.entities = entities

		# Also update legacy zone.assigned_fleet for backwards compatibility
		var zone = new_state.zones[zone_id]
		var fleet = zone.assigned_fleet.duplicate()
		fleet[ship_type] = fleet.get(ship_type, 0) + to_assign
		zone.assigned_fleet = fleet
		new_state.zones[zone_id] = zone
	else:
		# Create warship entity heading to destination
		var entity = FCWTypes.create_warship(ship_type, earth_pos, to_assign)
		entity.destination = zone_id
		entity.origin = from_zone
		entity.movement_state = FCWTypes.MovementState.BURNING

		# Calculate initial velocity toward destination
		var dest_pos = FCWTypes.get_zone_position(zone_id, game_time)
		var direction = (dest_pos - earth_pos).normalized()
		entity.velocity = direction * entity.acceleration * 2.0  # Initial burn

		var entities = new_state.get("entities", []).duplicate()
		entities.append(entity)
		new_state.entities = entities

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

		# Track burn activity (ships leaving Earth are visible!)
		new_state = _track_activity(new_state, "burns_detected", from_zone, to_assign)

	return new_state

static func _reduce_set_fleet_order(state: Dictionary, zone_id: int, order: int) -> Dictionary:
	var new_state = state.duplicate(true)
	var orders = new_state.fleet_orders.duplicate()
	orders[zone_id] = order
	new_state.fleet_orders = orders
	return new_state

static func _reduce_recall_fleet(state: Dictionary, from_zone: int, to_zone: int, ship_type: int, count: int) -> Dictionary:
	## Recall ships from one zone to another
	## If to_zone=-1, ships return to reserve pool (instant, for simplicity)
	## If to_zone>=0, ships travel to the new destination
	var new_state = state.duplicate(true)
	var game_time = new_state.get("game_time", 0.0)

	# Get ships from source zone
	var from_zone_data = new_state.zones.get(from_zone, {})
	if from_zone_data.is_empty():
		return state  # Invalid source zone

	var from_fleet = from_zone_data.get("assigned_fleet", {}).duplicate()
	var available = from_fleet.get(ship_type, 0)
	var to_recall = mini(count, available)

	if to_recall <= 0:
		return state  # No ships to recall

	# Remove from source zone
	from_fleet[ship_type] = available - to_recall
	if from_fleet[ship_type] <= 0:
		from_fleet.erase(ship_type)
	from_zone_data.assigned_fleet = from_fleet
	new_state.zones[from_zone] = from_zone_data

	# If returning to reserve pool (to_zone=-1), just add to fleet count
	if to_zone < 0:
		var fleet = new_state.fleet.duplicate()
		# Ships return to available pool - they're not "created", they were assigned before
		# Actually, the fleet count already includes them, so we don't need to add
		# We just removed them from the zone, making them "available" again
		new_state.fleet = fleet

		new_state.event_log.append(FCWTypes.create_log_entry(
			new_state.turn,
			"%d %s(s) recalled from %s to reserve" % [
				to_recall,
				FCWTypes.get_ship_name(ship_type),
				FCWTypes.get_zone_name(from_zone)
			]
		))
	else:
		# Create entity to travel to new zone
		var from_pos = FCWTypes.get_zone_position(from_zone, game_time)
		var entity = FCWTypes.create_warship(ship_type, from_pos, to_recall)
		entity.destination = to_zone
		entity.origin = from_zone
		entity.movement_state = FCWTypes.MovementState.BURNING

		# Calculate initial velocity toward destination
		var dest_pos = FCWTypes.get_zone_position(to_zone, game_time)
		var direction = (dest_pos - from_pos).normalized()
		entity.velocity = direction * entity.acceleration * 2.0  # Initial burn

		var entities = new_state.get("entities", []).duplicate()
		entities.append(entity)
		new_state.entities = entities

		# Log the transfer
		var travel_time = FCWTypes.get_travel_time(from_zone, to_zone)
		new_state.event_log.append(FCWTypes.create_log_entry(
			new_state.turn,
			"%d %s(s) transferring %s -> %s (ETA: %d weeks)" % [
				to_recall,
				FCWTypes.get_ship_name(ship_type),
				FCWTypes.get_zone_name(from_zone),
				FCWTypes.get_zone_name(to_zone),
				travel_time
			]
		))

		# Track burn activity (ships departing are visible!)
		new_state = _track_activity(new_state, "burns_detected", from_zone, to_recall)

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

	# Subtract ships in transit (legacy array)
	for transit in state.get("fleets_in_transit", []):
		var ship_type = transit.ship_type
		available[ship_type] = available.get(ship_type, 0) - transit.count

	# Subtract warship entities currently in transit (burning or coasting)
	# This prevents AI from deploying the same ships multiple times
	for entity in state.get("entities", []):
		if entity.get("entity_type") == FCWTypes.EntityType.WARSHIP:
			if entity.get("faction") == FCWTypes.Faction.HUMAN:
				var move_state = entity.get("movement_state", FCWTypes.MovementState.ORBITING)
				if move_state == FCWTypes.MovementState.BURNING or move_state == FCWTypes.MovementState.COASTING:
					var ship_type = entity.get("ship_type", FCWTypes.ShipType.FRIGATE)
					var count = entity.get("count", 1)
					available[ship_type] = available.get(ship_type, 0) - count

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

# ============================================================================
# ENTITY MOVEMENT SYSTEM (NEW)
# ============================================================================

static func _process_entity_movement(state: Dictionary, random_values: Array = []) -> Dictionary:
	## Advance all entities based on their physics state
	## Position updates, signature changes, arrival detection
	## Handles redirect when destination falls
	var new_state = state.duplicate(true)
	var game_time = new_state.get("game_time", 0.0)
	var random_idx = 0
	var entities = new_state.get("entities", []).duplicate()
	var updated_entities: Array = []

	for i in range(entities.size()):
		var entity = entities[i].duplicate()

		# Skip destroyed entities
		if entity.movement_state == FCWTypes.MovementState.DESTROYED:
			continue

		# Check for entities at fallen zones - they need to redirect
		if entity.movement_state == FCWTypes.MovementState.ORBITING:
			var current_zone = entity.get("origin", -1)
			if current_zone < 0:
				current_zone = entity.get("destination", -1)

			# Check if the zone we're orbiting has fallen
			if current_zone >= 0:
				var zone = new_state.zones.get(current_zone, {})
				if zone.get("status") == FCWTypes.ZoneStatus.FALLEN:
					# Zone fell! Redirect to nearest safe zone
					entity = _redirect_entity_from_fallen_zone(entity, new_state, game_time, current_zone)
					if entity.movement_state != FCWTypes.MovementState.ORBITING:
						new_state.event_log.append(FCWTypes.create_log_entry(
							new_state.turn,
							"Entity %s fleeing fallen %s for %s" % [
								entity.id,
								FCWTypes.get_zone_name(current_zone),
								FCWTypes.get_zone_name(entity.destination)
							],
							true
						))

			# Still orbiting (either safe or no redirect available)
			if entity.movement_state == FCWTypes.MovementState.ORBITING:
				updated_entities.append(entity)
				continue

		# Check if destination fell while en route - redirect immediately
		if entity.destination >= 0:
			var dest_zone = new_state.zones.get(entity.destination, {})
			if dest_zone.get("status") == FCWTypes.ZoneStatus.FALLEN:
				# Destination fell! Find new safe destination
				var old_dest = entity.destination
				entity = _redirect_entity_from_fallen_zone(entity, new_state, game_time, entity.destination)
				new_state.event_log.append(FCWTypes.create_log_entry(
					new_state.turn,
					"Entity %s rerouting - %s has fallen, now heading to %s" % [
						entity.id,
						FCWTypes.get_zone_name(old_dest),
						FCWTypes.get_zone_name(entity.destination) if entity.destination >= 0 else "nowhere"
					],
					true
				))

		# Update position based on velocity (1 week timestep)
		entity.position += entity.velocity

		# Update signature based on movement state
		if entity.movement_state == FCWTypes.MovementState.BURNING:
			entity.signature = FCWTypes.BURN_SIGNATURE
			# Burning entities accelerate toward destination
			if entity.destination >= 0:
				var dest_pos = FCWTypes.get_zone_position(entity.destination, game_time)
				var direction = (dest_pos - entity.position).normalized()
				entity.velocity += direction * entity.acceleration
		else:  # COASTING
			entity.signature = FCWTypes.COAST_SIGNATURE

		# Check for Herald interception of transports
		if entity.get("entity_type") == FCWTypes.EntityType.TRANSPORT:
			var herald_pos = _get_herald_position(new_state, game_time)
			var dist_to_herald = entity.position.distance_to(herald_pos)

			# Herald can intercept transports within 1.5 AU and after turn 3
			if dist_to_herald < 1.5 and new_state.turn > 3:
				# Interception chance based on proximity (closer = higher chance)
				var intercept_chance = 0.4 * (1.0 - dist_to_herald / 1.5)
				# Use deterministic random from array (fall back to 0.5 if no values)
				var roll = random_values[random_idx % maxi(1, random_values.size())] if random_values.size() > 0 else 0.5
				random_idx += 1
				if roll < intercept_chance:
					# Transport destroyed - all souls lost
					var souls_lost = entity.get("cargo", {}).get("souls", 0)
					new_state.lives_intercepted = new_state.get("lives_intercepted", 0) + souls_lost
					entity.movement_state = FCWTypes.MovementState.DESTROYED

					new_state.event_log.append(FCWTypes.create_log_entry(
						new_state.turn,
						"TRAGEDY: Transport '%s' intercepted - %s souls lost" % [
							entity.get("name", entity.id),
							FCWTypes.format_population(souls_lost)
						],
						true
					))
					continue  # Don't add destroyed transport to updated list

		# Check for arrival at destination
		if entity.destination >= 0:
			var dest_pos = FCWTypes.get_zone_position(entity.destination, game_time)
			var distance = entity.position.distance_to(dest_pos)

			# Arrival radius (within 0.1 AU of body)
			if distance < 0.1:
				# Special handling for transports - they escape to safety
				if entity.get("entity_type") == FCWTypes.EntityType.TRANSPORT:
					var souls_saved = entity.get("cargo", {}).get("souls", 0)
					new_state.lives_evacuated = new_state.get("lives_evacuated", 0) + souls_saved
					new_state.colony_ships_safe = new_state.get("colony_ships_safe", 0) + 1
					entity.movement_state = FCWTypes.MovementState.DESTROYED  # Remove from simulation

					new_state.event_log.append(FCWTypes.create_log_entry(
						new_state.turn,
						"Transport '%s' reached safety - %s souls saved" % [
							entity.get("name", entity.id),
							FCWTypes.format_population(souls_saved)
						]
					))
					continue  # Don't add to updated entities

				entity.movement_state = FCWTypes.MovementState.ORBITING
				entity.velocity = Vector2.ZERO
				entity.signature = FCWTypes.COAST_SIGNATURE
				entity.position = dest_pos
				entity.origin = entity.destination

				# Update zone.assigned_fleet for warships
				if entity.get("entity_type") == FCWTypes.EntityType.WARSHIP:
					var dest_zone = new_state.zones.get(entity.destination, {})
					if dest_zone.get("status") != FCWTypes.ZoneStatus.FALLEN:
						var fleet = dest_zone.get("assigned_fleet", {}).duplicate()
						var ship_type = entity.get("ship_type", FCWTypes.ShipType.FRIGATE)
						var count = entity.get("count", 1)
						fleet[ship_type] = fleet.get(ship_type, 0) + count

						# Also deposit any escorting fleet
						var escorting = entity.get("escorting_fleet", {})
						for escort_type in escorting:
							fleet[escort_type] = fleet.get(escort_type, 0) + escorting[escort_type]

						dest_zone.assigned_fleet = fleet
						new_state.zones[entity.destination] = dest_zone

					# Clear escorting fleet after depositing
					entity["escorting_fleet"] = {}

				# Log arrival with special message for Herald
				if entity.get("id") == FCWTypes.HERALD_ENTITY_ID:
					new_state.event_log.append(FCWTypes.create_log_entry(
						new_state.turn,
						"HERALD FLEET arrived at %s" % FCWTypes.get_zone_name(entity.destination),
						true
					))
				else:
					new_state.event_log.append(FCWTypes.create_log_entry(
						new_state.turn,
						"Entity %s arrived at %s" % [entity.id, FCWTypes.get_zone_name(entity.destination)]
					))

		# Update ETA
		if entity.destination >= 0 and entity.movement_state != FCWTypes.MovementState.ORBITING:
			var dest_pos = FCWTypes.get_zone_position(entity.destination, game_time)
			var distance = entity.position.distance_to(dest_pos)
			var speed = entity.velocity.length()
			entity.eta = distance / speed if speed > 0.01 else 999.0

		updated_entities.append(entity)

	new_state.entities = updated_entities
	return new_state

static func _process_detection(state: Dictionary, random_value: float) -> Dictionary:
	## Herald observes burning ships and builds intel about traffic patterns
	## This implements the observation-limited predator model
	var new_state = state.duplicate(true)
	var game_time = new_state.get("game_time", 0.0)
	var herald_pos = _get_herald_position(new_state, game_time)
	var herald_intel = new_state.get("herald_intel", {
		"known_routes": {},
		"last_detected": {},
		"activity_zones": {}
	}).duplicate(true)

	# Check each entity for detection using Herald AI
	for entity in new_state.get("entities", []):
		if entity.faction == FCWTypes.Faction.HERALD:
			continue  # Don't detect own ships

		if entity.movement_state == FCWTypes.MovementState.DESTROYED:
			continue

		# Get traffic level for this entity's route
		var traffic_level = 0.0
		if entity.origin >= 0 and entity.destination >= 0:
			var route_key = FCWTypes.calc_route_traffic_key(entity.origin, entity.destination)
			traffic_level = herald_intel.known_routes.get(route_key, 0.0)

		# Calculate detection probability using Herald AI
		var detection_rate = FCWHeraldAI.calc_detection_probability(
			entity.position,
			herald_pos,
			entity.movement_state == FCWTypes.MovementState.BURNING,
			traffic_level
		)

		# Roll for detection (daily rate converted to weekly)
		var weekly_detection_chance = 1.0 - pow(1.0 - detection_rate, 7.0)
		if random_value < weekly_detection_chance:
			# Entity detected! Update intel using Herald AI
			new_state = FCWHeraldAI.update_traffic_patterns(new_state, entity, game_time)
			herald_intel = new_state.get("herald_intel", herald_intel)

			# Log significant detections
			if entity.movement_state == FCWTypes.MovementState.BURNING:
				new_state.event_log.append(FCWTypes.create_log_entry(
					new_state.turn,
					"HERALD DETECTION: Burning signature detected at %.1f AU" % herald_pos.distance_to(entity.position)
				))

	new_state.herald_intel = herald_intel

	# Update drone lifetimes
	new_state = FCWHeraldAI.update_drones(new_state)

	return new_state

static func _process_entity_intercepts(state: Dictionary, random_value: float) -> Dictionary:
	## Resolve intercepts between entities
	## Herald ships and drones can intercept human ships based on trajectory intersection
	## Implements: "Bombers can slingshot torpedos without power and stealth"
	## and "Herald drones show how outmatched humanity is"
	var new_state = state.duplicate(true)
	var game_time = new_state.get("game_time", 0.0)
	var entities = new_state.get("entities", []).duplicate()

	# Categorize entities
	var herald_attackers: Array = []  # Herald ships and drones
	var human_warships: Array = []     # Can escort
	var human_transports: Array = []   # Need protection
	var human_others: Array = []       # Weapons, etc

	for i in range(entities.size()):
		var entity = entities[i]
		if entity.movement_state == FCWTypes.MovementState.DESTROYED:
			continue

		if entity.faction == FCWTypes.Faction.HERALD:
			# Include both main ships and drones
			if entity.movement_state != FCWTypes.MovementState.ORBITING or entity.get("is_drone", false):
				herald_attackers.append({"entity": entity, "index": i})
		else:
			match entity.entity_type:
				FCWTypes.EntityType.WARSHIP:
					human_warships.append({"entity": entity, "index": i})
				FCWTypes.EntityType.TRANSPORT:
					human_transports.append({"entity": entity, "index": i})
				_:
					human_others.append({"entity": entity, "index": i})

	var random_idx = 0
	var souls_lost_total = 0

	# Process each Herald attacker
	for attacker_data in herald_attackers:
		var attacker = attacker_data.entity
		var is_drone = attacker.get("is_drone", false)

		# Drones are more aggressive - prioritize transports (souls!)
		var targets: Array = []
		if is_drone:
			targets = human_transports + human_warships  # Drones go for transports first
		else:
			targets = human_warships + human_transports  # Main fleet engages warships

		for target_data in targets:
			var target = target_data.entity
			if target.movement_state == FCWTypes.MovementState.DESTROYED:
				continue

			var distance = attacker.position.distance_to(target.position)

			# Drones have shorter intercept range but are faster
			var intercept_range = FCWHeraldAI.DRONE_RANGE if is_drone else 8.0

			if distance > intercept_range:
				continue

			# Check if trajectories intersect
			var intercept = FCWOrbital.can_intercept(
				attacker.position,
				attacker.acceleration,
				target.position,
				target.velocity,
				2.0 if is_drone else 4.0  # Drones commit faster
			)

			if not intercept.can_intercept:
				continue

			# Calculate intercept difficulty
			var difficulty = FCWOrbital.calc_intercept_difficulty(
				target.velocity.length(),
				target.signature,
				distance
			)

			# Drones are better at tracking (purpose-built hunters)
			if is_drone:
				difficulty *= 0.7

			# Roll for intercept (use array of random values for variety)
			var roll = random_value + float(random_idx) * 0.13
			roll = fmod(roll, 1.0)
			random_idx += 1

			if roll > difficulty:
				# Check for escort protection (warships can protect transports)
				var escort = _find_escort(target, human_warships, distance)

				if escort.has_escort:
					# Escort intercepts instead!
					var combat_result = _resolve_entity_combat(attacker, escort.escort_entity, roll, new_state)
					entities[escort.escort_index] = combat_result.defender
					entities[attacker_data.index] = combat_result.attacker

					new_state.event_log.append(FCWTypes.create_log_entry(
						new_state.turn,
						"ESCORT: %s protected %s from %s" % [
							escort.escort_entity.id,
							target.id,
							"drone" if is_drone else "Herald ship"
						]
					))
				else:
					# No escort - target takes the hit
					var combat_result = _resolve_entity_combat(attacker, target, roll, new_state)
					entities[target_data.index] = combat_result.defender
					entities[attacker_data.index] = combat_result.attacker
					souls_lost_total += combat_result.souls_lost

					var outcome = "destroyed" if combat_result.defender.movement_state == FCWTypes.MovementState.DESTROYED else "damaged"
					var souls_msg = ""
					if combat_result.souls_lost > 0:
						souls_msg = " - %s souls lost" % FCWTypes.format_population(combat_result.souls_lost)

					# Track intercept event for signal emission
					var tick_events = new_state.get("tick_events", {})
					var intercepts = tick_events.get("intercepts", []).duplicate()
					intercepts.append({
						"pursuer_id": attacker.id,
						"target_id": target.id,
						"souls_lost": combat_result.souls_lost,
						"target_destroyed": combat_result.defender.movement_state == FCWTypes.MovementState.DESTROYED
					})
					tick_events.intercepts = intercepts
					new_state.tick_events = tick_events

					new_state.event_log.append(FCWTypes.create_log_entry(
						new_state.turn,
						"INTERCEPT: %s engaged %s - %s%s" % [
							"Drone" if is_drone else "Herald",
							target.id,
							outcome,
							souls_msg
						],
						true
					))

					# If drone killed target, it might self-destruct from impact
					if is_drone and combat_result.defender.movement_state == FCWTypes.MovementState.DESTROYED:
						# High closing velocity = drone destroyed too
						var closing_vel = (attacker.velocity - target.velocity).length()
						if closing_vel > 0.3:  # High-speed intercept
							entities[attacker_data.index].movement_state = FCWTypes.MovementState.DESTROYED

				break  # One engagement per attacker per turn

	# Track souls lost
	new_state.lives_intercepted = new_state.get("lives_intercepted", 0) + souls_lost_total

	# Filter out destroyed entities
	var updated_entities: Array = []
	for entity in entities:
		if entity.movement_state != FCWTypes.MovementState.DESTROYED:
			updated_entities.append(entity)

	new_state.entities = updated_entities
	return new_state

static func _find_escort(target: Dictionary, warships: Array, threat_distance: float) -> Dictionary:
	## Find a warship that can escort (protect) the target
	## Escort must be within 1 AU of target and have combat power
	const ESCORT_RANGE = 1.0  # AU

	for ws_data in warships:
		var warship = ws_data.entity
		if warship.movement_state == FCWTypes.MovementState.DESTROYED:
			continue

		var dist_to_target = warship.position.distance_to(target.position)
		if dist_to_target < ESCORT_RANGE and warship.combat_power > 0:
			return {
				"has_escort": true,
				"escort_entity": warship,
				"escort_index": ws_data.index
			}

	return {"has_escort": false}

static func _resolve_entity_combat(attacker: Dictionary, defender: Dictionary, random_value: float, state: Dictionary) -> Dictionary:
	## Resolve combat between two entities
	## "Attack vectors matter a lot... closing velocity affects damage"
	## Returns {attacker, defender, souls_lost} with updated stats
	var result = {
		"attacker": attacker.duplicate(),
		"defender": defender.duplicate(),
		"souls_lost": 0
	}

	# Closing velocity bonus - inspired by Expanse attack vectors
	# "allows conventional mass weapons to have massive impact"
	var closing_velocity = (attacker.velocity - defender.velocity).length()
	var velocity_bonus = 1.0 + closing_velocity * 2.0  # Massive bonus for high closing speed

	var attack_power = attacker.combat_power * velocity_bonus
	var defense_power = defender.combat_power

	# Attacker damage
	var damage_to_defender = attack_power * (0.5 + random_value * 0.5)
	result.defender.hull -= damage_to_defender

	# Defender fights back (if has combat power)
	if defense_power > 0:
		var damage_to_attacker = defense_power * (0.3 + random_value * 0.2)
		result.attacker.hull -= damage_to_attacker

		if result.attacker.hull <= 0:
			result.attacker.movement_state = FCWTypes.MovementState.DESTROYED

	# Check defender destruction
	if result.defender.hull <= 0:
		result.defender.movement_state = FCWTypes.MovementState.DESTROYED

		# If transport, count souls lost
		if defender.entity_type == FCWTypes.EntityType.TRANSPORT:
			result.souls_lost = defender.cargo.get("souls", 0)

	return result

static func _process_traffic_decay(state: Dictionary) -> Dictionary:
	## Decay traffic knowledge over time - routes are forgotten
	var new_state = state.duplicate(true)
	var herald_intel = new_state.get("herald_intel", {}).duplicate(true)

	# Decay known routes
	var known_routes = herald_intel.get("known_routes", {}).duplicate()
	for route_key in known_routes:
		known_routes[route_key] = maxf(0.0, known_routes[route_key] - FCWTypes.TRAFFIC_DECAY_RATE)
	herald_intel.known_routes = known_routes

	# Decay activity zones
	var activity_zones = herald_intel.get("activity_zones", {}).duplicate()
	for zone_id in activity_zones:
		activity_zones[zone_id] = maxf(0.0, activity_zones[zone_id] - FCWTypes.TRAFFIC_DECAY_RATE * 0.5)
	herald_intel.activity_zones = activity_zones

	new_state.herald_intel = herald_intel
	return new_state

static func _get_herald_position(state: Dictionary, _game_time: float) -> Vector2:
	## Get Herald's current position from entity system
	var herald = FCWTypes.get_herald_entity(state)
	if herald.is_empty():
		# Fallback to legacy zone-based position
		var herald_zone = state.get("herald_current_zone", FCWTypes.ZoneId.KUIPER)
		return FCWTypes.get_zone_position(herald_zone, _game_time)
	return herald.position

# ============================================================================
# ENTITY ACTION REDUCERS (NEW)
# ============================================================================

static func _reduce_spawn_entity(state: Dictionary, entity: Dictionary) -> Dictionary:
	## Add a new entity to the game
	var new_state = state.duplicate(true)
	var entities = new_state.get("entities", []).duplicate()
	entities.append(entity.duplicate())
	new_state.entities = entities
	return new_state

static func _reduce_set_entity_destination(state: Dictionary, entity_id: String, zone_id: int, route_type: String) -> Dictionary:
	## Set an entity's destination and begin movement
	## Capital ships take a portion of the zone's fleet with them (1/N where N = capital ships at zone)
	var new_state = state.duplicate(true)
	var game_time = new_state.get("game_time", 0.0)
	var entities = new_state.get("entities", []).duplicate()

	for i in range(entities.size()):
		if entities[i].id == entity_id:
			var entity = entities[i].duplicate()

			# Store origin if we're starting from orbiting
			var origin_zone = -1
			if entity.movement_state == FCWTypes.MovementState.ORBITING:
				origin_zone = entity.get("origin", -1)
				if origin_zone < 0:
					origin_zone = entity.get("destination", -1)
				entity.origin = origin_zone

			entity.destination = zone_id

			# Capital ships take a portion of the zone's fleet with them
			# Count capital ships at origin zone to determine portion
			if origin_zone >= 0 and _is_capital_ship(entity):
				var capital_ships_at_zone = _count_capital_ships_at_zone(entities, origin_zone)
				if capital_ships_at_zone > 0:
					var portion = 1.0 / float(capital_ships_at_zone)
					var zone_data = new_state.zones.get(origin_zone, {})
					var zone_fleet = zone_data.get("assigned_fleet", {}).duplicate()
					var escorting = {}

					# Take portion of each ship type (frigates primarily - not other capitals)
					for ship_type in zone_fleet:
						if ship_type == FCWTypes.ShipType.FRIGATE:
							var count = zone_fleet[ship_type]
							var to_take = int(ceil(count * portion))
							if to_take > 0:
								escorting[ship_type] = to_take
								zone_fleet[ship_type] = count - to_take
								if zone_fleet[ship_type] <= 0:
									zone_fleet.erase(ship_type)

					# Store escorting fleet on entity and update zone
					entity["escorting_fleet"] = escorting
					zone_data.assigned_fleet = zone_fleet
					new_state.zones[origin_zone] = zone_data

			# Get route options and select based on route_type
			var from_pos = entity.position
			var to_pos = FCWTypes.get_zone_position(zone_id, game_time)

			# Calculate initial velocity toward destination
			var direction = (to_pos - from_pos).normalized()

			# Set movement state based on route type
			match route_type:
				"direct":
					# Full burn - fast but visible
					entity.movement_state = FCWTypes.MovementState.BURNING
					entity.velocity = direction * entity.acceleration * 2.0  # Initial burn
					entity.signature = FCWTypes.BURN_SIGNATURE
				"coast":
					# Initial burn then coast - slower but stealthy
					entity.movement_state = FCWTypes.MovementState.COASTING
					entity.velocity = direction * 0.3  # Slower cruise velocity
					entity.signature = FCWTypes.COAST_SIGNATURE
				_:
					entity.movement_state = FCWTypes.MovementState.BURNING
					entity.velocity = direction * entity.acceleration

			# Record traffic on route
			if entity.origin >= 0:
				var intel = new_state.get("herald_intel", {}).duplicate(true)
				var routes = intel.get("known_routes", {}).duplicate()
				var route_key = FCWTypes.calc_route_traffic_key(entity.origin, zone_id)
				routes[route_key] = minf(routes.get(route_key, 0.0) + FCWTypes.TRAFFIC_PER_TRANSIT, 1.0)
				intel.known_routes = routes
				new_state.herald_intel = intel

			entities[i] = entity
			break

	new_state.entities = entities
	return new_state

static func _is_capital_ship(entity: Dictionary) -> bool:
	## Check if entity is a capital ship (Cruiser, Carrier, or Dreadnought)
	if entity.get("entity_type") != FCWTypes.EntityType.WARSHIP:
		return false
	var ship_type = entity.get("ship_type", FCWTypes.ShipType.FRIGATE)
	return ship_type in [FCWTypes.ShipType.CRUISER, FCWTypes.ShipType.CARRIER, FCWTypes.ShipType.DREADNOUGHT]

static func _count_capital_ships_at_zone(entities: Array, zone_id: int) -> int:
	## Count capital ships currently orbiting at a zone
	var count = 0
	for entity in entities:
		if entity.get("entity_type") != FCWTypes.EntityType.WARSHIP:
			continue
		if entity.get("movement_state") != FCWTypes.MovementState.ORBITING:
			continue
		var origin = entity.get("origin", -1)
		if origin < 0:
			origin = entity.get("destination", -1)
		if origin != zone_id:
			continue
		if _is_capital_ship(entity):
			count += 1
	return count

static func _reduce_set_entity_movement_state(state: Dictionary, entity_id: String, movement_state: int) -> Dictionary:
	## Change an entity's movement state (e.g., switch from burning to coasting)
	var new_state = state.duplicate(true)
	var entities = new_state.get("entities", []).duplicate()

	for i in range(entities.size()):
		if entities[i].id == entity_id:
			var entity = entities[i].duplicate()
			entity.movement_state = movement_state

			# Update signature
			match movement_state:
				FCWTypes.MovementState.BURNING:
					entity.signature = FCWTypes.BURN_SIGNATURE
				FCWTypes.MovementState.COASTING:
					entity.signature = FCWTypes.COAST_SIGNATURE
				FCWTypes.MovementState.ORBITING:
					entity.signature = FCWTypes.COAST_SIGNATURE
					entity.velocity = Vector2.ZERO

			entities[i] = entity
			break

	new_state.entities = entities
	return new_state

static func _reduce_split_entity(state: Dictionary, entity_id: String, split_count: int, new_destination: int) -> Dictionary:
	## Split a fleet entity into two - one continues, one goes to new destination
	## Enables decoy tactics: send part of fleet to draw Herald attention
	var new_state = state.duplicate(true)
	var game_time = new_state.get("game_time", 0.0)
	var entities = new_state.get("entities", []).duplicate()

	for i in range(entities.size()):
		if entities[i].id == entity_id:
			var original = entities[i].duplicate()

			# Can only split if count > split_count
			if original.count <= split_count:
				return state

			# Reduce original count
			original.count -= split_count
			original.combat_power = original.combat_power * (float(original.count) / float(original.count + split_count))
			entities[i] = original

			# Create new entity for split portion
			var split_entity = FCWTypes.create_warship(
				original.ship_type,
				original.position,
				split_count
			)
			split_entity.velocity = original.velocity  # Inherit velocity
			split_entity.movement_state = original.movement_state
			split_entity.origin = original.origin

			# Set new destination
			if new_destination >= 0:
				var to_pos = FCWTypes.get_zone_position(new_destination, game_time)
				var direction = (to_pos - split_entity.position).normalized()
				split_entity.destination = new_destination
				split_entity.velocity = direction * split_entity.acceleration
				split_entity.movement_state = FCWTypes.MovementState.BURNING

			entities.append(split_entity)

			new_state.event_log.append(FCWTypes.create_log_entry(
				new_state.turn,
				"Fleet split: %d ships diverted to %s" % [split_count, FCWTypes.get_zone_name(new_destination)]
			))

			break

	new_state.entities = entities
	return new_state

static func _reduce_launch_weapon(state: Dictionary, entity_id: String, target_entity_id: String, weapon_power: float, powered: bool) -> Dictionary:
	## Launch a weapon from an entity toward a target
	## "Bombers can slingshot torpedos without power and stealth"
	## Unpowered: inherits launcher velocity, coasts silently, terminal burn later
	## Powered: burns toward target immediately, highly visible
	var new_state = state.duplicate(true)
	var entities = new_state.get("entities", []).duplicate()

	# Find launcher entity
	var launcher = null
	for entity in entities:
		if entity.id == entity_id:
			launcher = entity
			break

	if launcher == null:
		return state

	# Find target entity
	var target = null
	for entity in entities:
		if entity.id == target_entity_id:
			target = entity
			break

	if target == null:
		return state

	# Create weapon entity
	# Inherit launcher's velocity for unpowered launch ("slingshot torpedoes")
	var weapon_velocity = launcher.velocity
	var movement_state = FCWTypes.MovementState.COASTING

	if powered:
		# Powered launch: burn toward target
		var direction = (target.position - launcher.position).normalized()
		weapon_velocity = direction * 0.2  # Fast initial burn
		movement_state = FCWTypes.MovementState.BURNING

	var weapon = FCWTypes.create_weapon(launcher.position, weapon_velocity, weapon_power)
	weapon.movement_state = movement_state
	weapon.target_id = target_entity_id  # Track what we're aiming at
	weapon.terminal_burn = false  # Will activate close to target
	weapon.faction = launcher.faction  # Inherit faction

	entities.append(weapon)

	new_state.event_log.append(FCWTypes.create_log_entry(
		new_state.turn,
		"Weapon launched from %s toward %s (%s)" % [
			entity_id,
			target_entity_id,
			"powered" if powered else "unpowered/ballistic"
		]
	))

	new_state.entities = entities
	return new_state

# ============================================================================
# WEAPON PROCESSING
# ============================================================================

static func _process_weapons(state: Dictionary, random_value: float) -> Dictionary:
	## Process weapon entities: terminal burns, impacts
	## "Unpowered launch: low signature, ballistic trajectory"
	## "Terminal burn: high signature, homing"
	var new_state = state.duplicate(true)
	var entities = new_state.get("entities", []).duplicate()

	for i in range(entities.size()):
		var entity = entities[i]
		if entity.entity_type != FCWTypes.EntityType.WEAPON:
			continue
		if entity.movement_state == FCWTypes.MovementState.DESTROYED:
			continue

		var target_id = entity.get("target_id", "")
		if target_id.is_empty():
			continue

		# Find target
		var target = null
		for other in entities:
			if other.id == target_id:
				target = other
				break

		if target == null or target.movement_state == FCWTypes.MovementState.DESTROYED:
			# Target destroyed or gone - weapon continues ballistic
			continue

		var distance = entity.position.distance_to(target.position)

		# Terminal burn activation - when close to target
		const TERMINAL_BURN_RANGE = 0.5  # AU
		if distance < TERMINAL_BURN_RANGE and not entity.get("terminal_burn", false):
			# Activate terminal burn!
			entity = entity.duplicate()
			entity.terminal_burn = true
			entity.movement_state = FCWTypes.MovementState.BURNING
			entity.signature = FCWTypes.BURN_SIGNATURE

			# Burn toward target's predicted position
			var predicted_pos = target.position + target.velocity * 0.5
			var direction = (predicted_pos - entity.position).normalized()
			entity.velocity = direction * 0.3  # High terminal velocity

			entities[i] = entity

			new_state.event_log.append(FCWTypes.create_log_entry(
				new_state.turn,
				"WEAPON: Terminal burn activated - targeting %s" % target_id
			))

		# Impact check - weapon hits target
		const IMPACT_RANGE = 0.05  # AU
		if distance < IMPACT_RANGE:
			# IMPACT! Resolve damage
			var closing_velocity = (entity.velocity - target.velocity).length()
			var kinetic_bonus = 1.0 + closing_velocity * 3.0  # Massive kinetic damage

			var damage = entity.combat_power * kinetic_bonus * (0.8 + random_value * 0.4)

			# Apply damage to target
			for j in range(entities.size()):
				if entities[j].id == target_id:
					var damaged_target = entities[j].duplicate()
					damaged_target.hull -= damage

					if damaged_target.hull <= 0:
						damaged_target.movement_state = FCWTypes.MovementState.DESTROYED

						# Count souls if transport
						if damaged_target.entity_type == FCWTypes.EntityType.TRANSPORT:
							var souls = damaged_target.cargo.get("souls", 0)
							new_state.lives_intercepted = new_state.get("lives_intercepted", 0) + souls

					entities[j] = damaged_target
					break

			# Weapon destroyed on impact
			entity = entity.duplicate()
			entity.movement_state = FCWTypes.MovementState.DESTROYED
			entities[i] = entity

			new_state.event_log.append(FCWTypes.create_log_entry(
				new_state.turn,
				"IMPACT: Weapon hit %s for %.0f damage (closing velocity: %.2f AU/week)" % [
					target_id,
					damage,
					closing_velocity
				],
				true
			))

	# Filter destroyed entities
	var updated = []
	for entity in entities:
		if entity.movement_state != FCWTypes.MovementState.DESTROYED:
			updated.append(entity)

	new_state.entities = updated
	return new_state
