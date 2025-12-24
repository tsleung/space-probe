extends RefCounted
class_name FCWHeraldAI

## First Contact War - Herald AI System
##
## WEEKLY TIMELINE MODEL:
## Week 1: Herald attacks Kuiper (starting position)
## Week 2+: Herald evaluates zone signatures → moves toward highest detection
## Each week = attack current zone + evaluate + move toward next target
##
## Design principles:
## - Herald advances WEEKLY, always moving toward highest detection
## - Zone signatures accumulate from human activity (ships, burns, evacuation)
## - Signatures decay over time (going dark works!)
## - Players can create decoys, go stealth, or cut trails
## - Herald prefers moving inward but can be lured outward
##
## "Every number is a life. Every decision echoes in the void."

const FCWTypes = preload("res://scripts/first_contact_war/fcw_types.gd")

# ============================================================================
# CONSTANTS
# ============================================================================

# Herald observation and behavior
const OBSERVATION_RADIUS = 5.0          # AU - can detect burns within this range
const DRONE_SPEED = 0.15                # AU/week - much faster than human ships
const DRONE_COMBAT_POWER = 50.0         # Devastating against transports
const DRONE_RANGE = 10.0                # AU - max distance drones will pursue
const DRONES_PER_WAVE = 3               # Number of drones released per wave

# Response thresholds
const ACTIVITY_THRESHOLD_LOW = 0.2      # Minimum activity to notice
const ACTIVITY_THRESHOLD_HIGH = 0.6     # High activity triggers aggressive response
const ROUTE_KNOWN_THRESHOLD = 0.5       # Route traffic level to be "known"

# Pattern learning
const PATTERN_MEMORY_DURATION = 10.0    # Weeks before patterns fade significantly
const PREDICTION_CONFIDENCE_MIN = 0.3   # Minimum confidence to act on prediction

# ============================================================================
# HERALD DECISION MAKING
# ============================================================================

static func decide_herald_action(state: Dictionary, game_time: float) -> Dictionary:
	## Main AI decision function - determines what Herald does this turn
	## Returns action dictionary: {action_type, target, priority, reason}

	var herald_pos = _get_herald_position(state, game_time)
	var intel = state.get("herald_intel", {})

	# Gather all detected activity
	var detected_entities = _get_detected_entities(state, herald_pos, game_time)
	var activity_zones = intel.get("activity_zones", {})
	var known_routes = intel.get("known_routes", {})

	# Priority 1: Intercept high-value targets in range
	var intercept_target = _find_intercept_target(state, herald_pos, detected_entities)
	if intercept_target.valid:
		return {
			"action_type": "intercept",
			"target": intercept_target.entity,
			"priority": intercept_target.priority,
			"reason": "High-value target detected: %s" % intercept_target.reason
		}

	# Priority 2: Release drones at detected activity
	var drone_target = _find_drone_target(state, herald_pos, detected_entities, game_time)
	if drone_target.valid:
		return {
			"action_type": "release_drones",
			"target": drone_target.position,
			"direction": drone_target.direction,
			"priority": drone_target.priority,
			"reason": "Releasing drones toward: %s" % drone_target.reason
		}

	# Priority 3: Move toward highest activity zone
	var move_target = _find_movement_target(state, herald_pos, activity_zones, known_routes, game_time)
	if move_target.valid:
		return {
			"action_type": "move",
			"target": move_target.zone_id,
			"priority": move_target.priority,
			"reason": "Moving toward activity: %s" % move_target.reason
		}

	# Priority 4: Patrol known routes
	var patrol_target = _find_patrol_target(state, herald_pos, known_routes, game_time)
	if patrol_target.valid:
		return {
			"action_type": "patrol",
			"target": patrol_target.position,
			"priority": patrol_target.priority,
			"reason": "Patrolling route: %s" % patrol_target.reason
		}

	# Default: Continue current behavior
	return {
		"action_type": "hold",
		"priority": 0.0,
		"reason": "No activity detected"
	}

# ============================================================================
# DETECTION
# ============================================================================

static func _get_detected_entities(state: Dictionary, herald_pos: Vector2, game_time: float) -> Array:
	## Get all entities Herald can currently detect
	var detected = []

	for entity in state.get("entities", []):
		if entity.faction == FCWTypes.Faction.HERALD:
			continue
		if entity.movement_state == FCWTypes.MovementState.DESTROYED:
			continue

		var distance = herald_pos.distance_to(entity.position)
		var can_detect = false
		var detection_quality = 0.0

		# Burning ships are visible at longer range
		if entity.movement_state == FCWTypes.MovementState.BURNING:
			# Burning ships visible up to 2x observation radius
			if distance < OBSERVATION_RADIUS * 2.0:
				can_detect = true
				detection_quality = 1.0 - (distance / (OBSERVATION_RADIUS * 2.0))

		# Coasting ships only visible within observation radius
		elif entity.movement_state == FCWTypes.MovementState.COASTING:
			if distance < OBSERVATION_RADIUS:
				can_detect = true
				detection_quality = (1.0 - (distance / OBSERVATION_RADIUS)) * entity.signature

		# Orbiting ships at known locations
		elif entity.movement_state == FCWTypes.MovementState.ORBITING:
			if distance < OBSERVATION_RADIUS * 0.5:
				can_detect = true
				detection_quality = 0.5  # Can see but low confidence

		if can_detect:
			detected.append({
				"entity": entity,
				"distance": distance,
				"quality": detection_quality,
				"is_burning": entity.movement_state == FCWTypes.MovementState.BURNING
			})

	# Sort by detection quality (highest first)
	detected.sort_custom(func(a, b): return a.quality > b.quality)

	return detected

static func calc_detection_probability(entity_pos: Vector2, herald_pos: Vector2, is_burning: bool, traffic_level: float) -> float:
	## Calculate probability of detecting an entity per day
	## Exposed for UI visualization
	var distance = entity_pos.distance_to(herald_pos)

	# Base rate from traffic
	var base_rate = lerpf(
		FCWTypes.DETECTION_RATE_IDLE,
		FCWTypes.DETECTION_RATE_HIGH,
		clampf(traffic_level, 0.0, 1.0)
	)

	# Burning bonus
	if is_burning:
		base_rate = maxf(base_rate, FCWTypes.DETECTION_RATE_BURNING)

	# Distance modifier
	if distance < OBSERVATION_RADIUS:
		var proximity = 1.0 - (distance / OBSERVATION_RADIUS)
		base_rate = lerpf(base_rate, 1.0, proximity * 0.8)
	else:
		var falloff = OBSERVATION_RADIUS / distance
		base_rate *= falloff * falloff

	return clampf(base_rate, 0.0, 1.0)

# ============================================================================
# TARGET SELECTION
# ============================================================================

static func _find_intercept_target(state: Dictionary, herald_pos: Vector2, detected: Array) -> Dictionary:
	## Find the best target for direct intercept
	var best = {"valid": false}
	var best_score = 0.0

	for detection in detected:
		var entity = detection.entity
		var distance = detection.distance

		# Skip if too far for intercept
		if distance > DRONE_RANGE:
			continue

		# Calculate intercept score
		var score = 0.0
		var reason = ""

		# High priority: Transports with souls
		if entity.entity_type == FCWTypes.EntityType.TRANSPORT:
			var souls = entity.cargo.get("souls", 0)
			score = 100.0 + (souls / 100000.0)  # Higher score for more souls
			reason = "Transport with %d souls" % souls

		# Medium priority: Burning warships (visible threat)
		elif entity.entity_type == FCWTypes.EntityType.WARSHIP and detection.is_burning:
			score = 50.0 + entity.combat_power * 0.1
			reason = "Burning warship (combat power: %d)" % entity.combat_power

		# Lower priority: Coasting ships
		elif detection.quality > 0.5:
			score = 20.0 * detection.quality
			reason = "Detected vessel"

		# Adjust for distance (closer = better)
		score *= (1.0 - distance / DRONE_RANGE)

		if score > best_score:
			best_score = score
			best = {
				"valid": true,
				"entity": entity,
				"priority": score / 100.0,
				"reason": reason
			}

	return best

static func _find_drone_target(state: Dictionary, herald_pos: Vector2, detected: Array, game_time: float) -> Dictionary:
	## Find target direction for drone release
	var best = {"valid": false}

	# Only release drones if we detected burning ships
	var burning_targets = detected.filter(func(d): return d.is_burning)

	if burning_targets.is_empty():
		return best

	# Target the highest priority burning ship
	var target = burning_targets[0]
	var entity = target.entity

	# Predict where target will be
	var predicted_pos = entity.position + entity.velocity * 2.0  # 2 weeks ahead
	var direction = (predicted_pos - herald_pos).normalized()

	return {
		"valid": true,
		"position": predicted_pos,
		"direction": direction,
		"priority": target.quality,
		"reason": "Burning target at %.1f AU" % target.distance
	}

static func _find_movement_target(state: Dictionary, herald_pos: Vector2, activity_zones: Dictionary, known_routes: Dictionary, game_time: float) -> Dictionary:
	## Find best zone to move toward based on activity
	var best = {"valid": false}
	var best_score = ACTIVITY_THRESHOLD_LOW

	for zone_id in activity_zones:
		var activity = activity_zones[zone_id]
		if activity < ACTIVITY_THRESHOLD_LOW:
			continue

		var zone_pos = FCWTypes.get_zone_position(zone_id, game_time)
		var distance = herald_pos.distance_to(zone_pos)

		# Score based on activity and distance
		var score = activity * (1.0 - clampf(distance / 50.0, 0.0, 0.8))

		if score > best_score:
			best_score = score
			best = {
				"valid": true,
				"zone_id": zone_id,
				"priority": score,
				"reason": "%s (activity: %.0f%%)" % [FCWTypes.get_zone_name(zone_id), activity * 100]
			}

	return best

static func _find_patrol_target(state: Dictionary, herald_pos: Vector2, known_routes: Dictionary, game_time: float) -> Dictionary:
	## Find position along known route to patrol
	var best = {"valid": false}
	var best_traffic = ROUTE_KNOWN_THRESHOLD

	for route_key in known_routes:
		var traffic = known_routes[route_key]
		if traffic < ROUTE_KNOWN_THRESHOLD:
			continue

		# Parse route key to get zones
		var parts = route_key.split("_")
		if parts.size() != 2:
			continue

		var zone_a = int(parts[0])
		var zone_b = int(parts[1])

		var pos_a = FCWTypes.get_zone_position(zone_a, game_time)
		var pos_b = FCWTypes.get_zone_position(zone_b, game_time)

		# Patrol midpoint of route
		var midpoint = pos_a.lerp(pos_b, 0.5)

		if traffic > best_traffic:
			best_traffic = traffic
			best = {
				"valid": true,
				"position": midpoint,
				"priority": traffic,
				"reason": "%s - %s route (traffic: %.0f%%)" % [
					FCWTypes.get_zone_name(zone_a),
					FCWTypes.get_zone_name(zone_b),
					traffic * 100
				]
			}

	return best

# ============================================================================
# DRONE MANAGEMENT
# ============================================================================

static func create_herald_drone(spawn_pos: Vector2, target_direction: Vector2, combat_power: float = DRONE_COMBAT_POWER) -> Dictionary:
	## Create a fast Herald drone entity
	var drone = FCWTypes.create_entity({
		"entity_type": FCWTypes.EntityType.HERALD_SHIP,
		"faction": FCWTypes.Faction.HERALD,
		"position": spawn_pos,
		"velocity": target_direction * DRONE_SPEED,
		"acceleration": 0.2,  # Very high acceleration
		"combat_power": combat_power,
		"hull": 20.0,  # Fragile but fast
		"signature": FCWTypes.BURN_SIGNATURE,
		"movement_state": FCWTypes.MovementState.BURNING
	})
	drone["is_drone"] = true
	drone["lifetime"] = 8.0  # Weeks before running out of fuel/power
	return drone

static func spawn_drone_wave(state: Dictionary, herald_pos: Vector2, target_direction: Vector2, count: int = DRONES_PER_WAVE) -> Dictionary:
	## Spawn a wave of drones heading in target direction
	var new_state = state.duplicate(true)
	var entities = new_state.get("entities", []).duplicate()

	for i in range(count):
		# Spread drones slightly
		var spread_angle = (float(i) - float(count) / 2.0) * 0.1
		var spread_dir = target_direction.rotated(spread_angle)

		var drone = create_herald_drone(herald_pos, spread_dir)
		entities.append(drone)

	new_state.entities = entities

	new_state.event_log.append(FCWTypes.create_log_entry(
		new_state.turn,
		"HERALD: Released %d hunter-killer drones" % count,
		true
	))

	return new_state

static func update_drones(state: Dictionary) -> Dictionary:
	## Update drone lifetime and remove expired drones
	var new_state = state.duplicate(true)
	var entities = new_state.get("entities", []).duplicate()
	var updated = []

	for entity in entities:
		if entity.get("is_drone", false):
			var lifetime = entity.get("lifetime", 0.0) - 1.0
			if lifetime <= 0:
				# Drone expired
				continue
			entity = entity.duplicate()
			entity.lifetime = lifetime
		updated.append(entity)

	new_state.entities = updated
	return new_state

# ============================================================================
# PATTERN LEARNING
# ============================================================================

static func update_traffic_patterns(state: Dictionary, entity: Dictionary, game_time: float) -> Dictionary:
	## Update Herald's knowledge of traffic patterns based on detection
	var new_state = state.duplicate(true)
	var intel = new_state.get("herald_intel", {}).duplicate(true)

	# Update last detected position
	var last_detected = intel.get("last_detected", {}).duplicate()
	last_detected[entity.id] = {
		"position": entity.position,
		"velocity": entity.velocity,
		"time": game_time,
		"entity_type": entity.entity_type
	}
	intel.last_detected = last_detected

	# Update route traffic if moving between zones
	if entity.origin >= 0 and entity.destination >= 0:
		var routes = intel.get("known_routes", {}).duplicate()
		var key = FCWTypes.calc_route_traffic_key(entity.origin, entity.destination)
		routes[key] = minf(routes.get(key, 0.0) + FCWTypes.TRAFFIC_PER_TRANSIT, 1.0)
		intel.known_routes = routes

	# Update activity for destination zone
	if entity.destination >= 0:
		var activity = intel.get("activity_zones", {}).duplicate()
		activity[entity.destination] = minf(activity.get(entity.destination, 0.0) + 0.15, 1.0)
		intel.activity_zones = activity

	new_state.herald_intel = intel
	return new_state

static func predict_traffic(intel: Dictionary, game_time: float) -> Array:
	## Predict where traffic will be based on learned patterns
	## Returns array of {position, confidence, time}
	var predictions = []

	var last_detected = intel.get("last_detected", {})

	for entity_id in last_detected:
		var detection = last_detected[entity_id]
		var age = game_time - detection.time

		# Confidence decays with age
		var confidence = maxf(0.0, 1.0 - age / PATTERN_MEMORY_DURATION)

		if confidence < PREDICTION_CONFIDENCE_MIN:
			continue

		# Predict current position based on last known velocity
		var predicted_pos = detection.position + detection.velocity * age

		predictions.append({
			"position": predicted_pos,
			"confidence": confidence,
			"age": age,
			"entity_type": detection.entity_type
		})

	return predictions

# ============================================================================
# UTILITY
# ============================================================================

static func _get_herald_position(state: Dictionary, game_time: float) -> Vector2:
	## Get Herald's current position from entity system
	var herald = FCWTypes.get_herald_entity(state)
	if herald.is_empty():
		# Fallback to legacy zone-based position
		var herald_zone = state.get("herald_current_zone", FCWTypes.ZoneId.KUIPER)
		return FCWTypes.get_zone_position(herald_zone, game_time)
	return herald.position

static func get_observation_zone(herald_pos: Vector2) -> Dictionary:
	## Get the observation zone for visualization
	## Returns {center, radius, inner_radius}
	return {
		"center": herald_pos,
		"radius": OBSERVATION_RADIUS * 2.0,  # Extended range for burning ships
		"inner_radius": OBSERVATION_RADIUS,   # Standard range
		"drone_range": DRONE_RANGE
	}

static func format_intel_summary(intel: Dictionary) -> String:
	## Format intel for debug/UI display
	var summary = "HERALD INTEL:\n"

	var activity = intel.get("activity_zones", {})
	if not activity.is_empty():
		summary += "  Activity:\n"
		for zone_id in activity:
			if activity[zone_id] > 0.1:
				summary += "    %s: %.0f%%\n" % [FCWTypes.get_zone_name(zone_id), activity[zone_id] * 100]

	var routes = intel.get("known_routes", {})
	if not routes.is_empty():
		summary += "  Known Routes:\n"
		for route_key in routes:
			if routes[route_key] > 0.3:
				summary += "    %s: %.0f%%\n" % [route_key, routes[route_key] * 100]

	return summary

# ============================================================================
# WEEKLY TIMELINE SYSTEM
# ============================================================================
# The Herald advances every week, choosing its next target based on
# detection signatures. Players can manipulate signatures to control
# the Herald's path through the solar system.

static func process_weekly_herald_turn(state: Dictionary) -> Dictionary:
	## Main weekly Herald update - call this at the start of each week
	## Returns new state with Herald actions applied and dramatic messages
	var new_state = state.duplicate(true)
	var current_zone = new_state.herald_current_zone
	var turn = new_state.turn
	var messages: Array = []

	# Step 1: Update signatures from this week's activity
	new_state = update_zone_signatures(new_state)

	# Step 2: Attack current zone (if not already fallen)
	var zone = new_state.zones.get(current_zone, {})
	if zone.get("status", FCWTypes.ZoneStatus.CONTROLLED) == FCWTypes.ZoneStatus.CONTROLLED:
		new_state = _attack_zone(new_state, current_zone)
		messages.append_array(_get_attack_messages(current_zone, zone))

	# Step 3: Choose next target based on signatures
	var next_target = choose_next_target(new_state, current_zone)

	# Step 4: Begin transit to next target (if different from current)
	if next_target >= 0 and next_target != current_zone:
		new_state = _begin_transit(new_state, current_zone, next_target)
		messages.append_array(_get_movement_messages(new_state, current_zone, next_target))

	# Step 5: Decay signatures for next week
	new_state = decay_zone_signatures(new_state)

	# Step 6: Reset weekly activity tracking
	new_state = _reset_weekly_activity(new_state)

	# Add all messages to event log
	for msg in messages:
		new_state.event_log.append(FCWTypes.create_log_entry(turn, msg, true))

	return new_state

static func update_zone_signatures(state: Dictionary) -> Dictionary:
	## Calculate and update zone signatures based on weekly activity
	## Signatures are 0.0-1.0 representing detection likelihood
	## Population sets minimum baseline; activity adds on top
	var new_state = state.duplicate(true)
	var sigs = new_state.zone_signatures.duplicate()
	var activity = new_state.weekly_activity

	for zone_id in FCWTypes.ZoneId.values():
		var zone = new_state.zones.get(zone_id, {})

		# Calculate population baseline (minimum signature for inhabited zones)
		# Earth (8B) = 0.08, Mars (10M) = 0.0001
		var pop = zone.get("population", 0)
		var pop_baseline = clampf(pop * FCWTypes.SIG_POPULATION, 0.0, 0.15)

		# Calculate weekly activity contribution (does NOT accumulate)
		var activity_sig = 0.0

		# Stationed ships
		var stationed = zone.get("stationed_ships", {})
		var ship_count = 0
		for ship_type in stationed:
			ship_count += stationed[ship_type]
		activity_sig += ship_count * FCWTypes.SIG_STATIONED_SHIP

		# Production activity this week
		var built = activity.ships_built.get(zone_id, 0)
		activity_sig += built * FCWTypes.SIG_PRODUCTION

		# Transit traffic this week
		var transits = activity.ships_transited.get(zone_id, 0)
		activity_sig += transits * FCWTypes.SIG_TRANSIT

		# Active burns this week (very visible!)
		var burns = activity.burns_detected.get(zone_id, 0)
		activity_sig += burns * FCWTypes.SIG_ACTIVE_BURN

		# Combat events this week
		var combat = activity.combat_events.get(zone_id, 0)
		activity_sig += combat * FCWTypes.SIG_COMBAT

		# Evacuation activity
		var evac = activity.evacuations.get(zone_id, 0)
		activity_sig += (evac / 1_000_000.0) * FCWTypes.SIG_EVACUATION

		# Final signature = max(population baseline, decayed previous) + this week's activity
		# Note: decay is applied in decay_zone_signatures after this
		var prev_sig = sigs.get(zone_id, 0.0)
		var sig = maxf(pop_baseline, prev_sig) + activity_sig

		# Clamp to valid range (0.0-1.0)
		sigs[zone_id] = clampf(sig, 0.0, 1.0)

	new_state.zone_signatures = sigs
	return new_state

static func decay_zone_signatures(state: Dictionary) -> Dictionary:
	## Decay all zone signatures (going dark works!)
	var new_state = state.duplicate(true)
	var sigs = new_state.zone_signatures.duplicate()

	for zone_id in sigs:
		sigs[zone_id] = sigs[zone_id] * FCWTypes.HERALD_SIG_DECAY
		# Earth maintains minimum baseline (civilization is visible)
		if zone_id == FCWTypes.ZoneId.EARTH:
			sigs[zone_id] = maxf(sigs[zone_id], 0.05)

	new_state.zone_signatures = sigs
	return new_state

static func choose_next_target(state: Dictionary, current_zone: int) -> int:
	## Choose Herald's next target based on zone signatures
	## Returns zone_id of best target, or -1 if should hold position
	var sigs = state.zone_signatures
	var best_target = -1
	var best_score = 0.0

	# Get all reachable zones (adjacent + skip targets)
	var adjacent = FCWTypes.get_zone_adjacent(current_zone)
	var skippable = FCWTypes.get_zone_skip_targets(current_zone)
	var current_orbit = FCWTypes.get_zone_orbit_order(current_zone)

	# Evaluate adjacent zones
	for zone_id in adjacent:
		var sig = sigs.get(zone_id, 0.0)
		if sig < FCWTypes.HERALD_MIN_SIG_TO_ATTRACT:
			# Still consider for inward bias
			sig = 0.0

		var target_orbit = FCWTypes.get_zone_orbit_order(zone_id)
		var orbit_diff = current_orbit - target_orbit

		# Inward bias: prefer moving toward Sun
		var inward_bonus = 1.0 + (orbit_diff * FCWTypes.HERALD_INWARD_BIAS) if orbit_diff > 0 else 1.0

		var score = sig * inward_bonus + (0.05 if orbit_diff > 0 else 0.0)  # Small inward nudge

		if score > best_score:
			best_score = score
			best_target = zone_id

	# Evaluate skip zones (require higher threshold)
	for zone_id in skippable:
		var sig = sigs.get(zone_id, 0.0)
		if sig < FCWTypes.HERALD_SKIP_THRESHOLD:
			continue  # Not enough signature to skip

		var target_orbit = FCWTypes.get_zone_orbit_order(zone_id)
		var orbit_diff = current_orbit - target_orbit
		var inward_bonus = 1.0 + (orbit_diff * FCWTypes.HERALD_INWARD_BIAS) if orbit_diff > 0 else 1.0

		# Skip penalty: slightly prefer adjacent zones
		var score = sig * inward_bonus * 0.9

		if score > best_score:
			best_score = score
			best_target = zone_id

	# If no strong signal, follow default inward path
	if best_target < 0:
		best_target = FCWTypes.get_zone_default_next(current_zone)

	return best_target

static func _attack_zone(state: Dictionary, zone_id: int) -> Dictionary:
	## Herald attacks a zone - marks it as fallen
	var new_state = state.duplicate(true)
	var zones = new_state.zones.duplicate(true)
	var zone = zones.get(zone_id, {}).duplicate(true)

	zone.status = FCWTypes.ZoneStatus.FALLEN
	zones[zone_id] = zone
	new_state.zones = zones

	return new_state

static func _begin_transit(state: Dictionary, from_zone: int, to_zone: int) -> Dictionary:
	## Begin Herald transit to new zone
	var new_state = state.duplicate(true)

	new_state.herald_transit = {
		"from_zone": from_zone,
		"to_zone": to_zone,
		"turns_remaining": FCWTypes.HERALD_TRAVEL_TIME,
		"total_turns": FCWTypes.HERALD_TRAVEL_TIME
	}

	# Update current zone to destination immediately for next week's attack
	new_state.herald_current_zone = to_zone
	new_state.herald_attack_target = to_zone

	return new_state

static func _reset_weekly_activity(state: Dictionary) -> Dictionary:
	## Reset weekly activity counters
	var new_state = state.duplicate(true)
	new_state.weekly_activity = {
		"ships_built": {},
		"ships_transited": {},
		"burns_detected": {},
		"combat_events": {},
		"evacuations": {},
	}
	return new_state

# ============================================================================
# DRAMATIC EVENT MESSAGES
# ============================================================================
# These messages appear in the event log during major Herald events.
# They convey the human cost and stakes of each moment.

static func _get_attack_messages(zone_id: int, zone: Dictionary) -> Array:
	## Get dramatic messages for Herald attack on a zone
	var zone_name = FCWTypes.get_zone_name(zone_id)
	var pop = zone.get("population", 0)
	var messages: Array = []

	# Opening message
	messages.append("━━━ PRIORITY ALERT ━━━")

	match zone_id:
		FCWTypes.ZoneId.KUIPER:
			messages.append("KUIPER STATION: \"They're here. The Herald— it's not stopping to—\"")
			messages.append("TRANSMISSION LOST - Kuiper Belt monitoring stations offline.")
			if pop > 0:
				messages.append("%s souls unaccounted for in outer system." % FCWTypes.format_population(pop))

		FCWTypes.ZoneId.SATURN:
			messages.append("TITAN COLONY: \"Massive energy signature approaching! All stations, this is not a drill—\"")
			messages.append("SATURN COMMAND: \"Begin emergency evacuation! Get everyone to the—\" [SIGNAL LOST]")
			if pop > 0:
				messages.append("Saturn system population: %s. Evacuation status: UNKNOWN." % FCWTypes.format_population(pop))

		FCWTypes.ZoneId.JUPITER:
			messages.append("EUROPA BASE: \"God help us. It's bigger than the images showed.\"")
			messages.append("GANYMEDE STATION: \"All available ships, break orbit NOW! Do not engage!\"")
			messages.append("IO MINING CONSORTIUM: \"We can see it from here. The sky is burning.\"")
			if pop > 0:
				messages.append("Jupiter system: %s civilians in the engagement zone." % FCWTypes.format_population(pop))

		FCWTypes.ZoneId.ASTEROID_BELT:
			messages.append("CERES CONTROL: \"The Herald is sweeping through the belt. Stations are going dark one by one.\"")
			messages.append("MINING GUILD: \"There's nowhere to hide out here. Please... someone...\"")
			if pop > 0:
				messages.append("Belt colonies: %s miners and families." % FCWTypes.format_population(pop))

		FCWTypes.ZoneId.MARS:
			messages.append("OLYMPUS MONS COMMAND: \"This is it. Everyone we couldn't evacuate... they're counting on us.\"")
			messages.append("MARS COLONIAL AUTHORITY: \"To all ships: protect the transports at any cost.\"")
			messages.append("VALLES MARINERIS: \"Tell Earth we held the line as long as we could.\"")
			if pop > 0:
				messages.append("Mars population at risk: %s human beings." % FCWTypes.format_population(pop))

		FCWTypes.ZoneId.EARTH:
			messages.append("EARTH DEFENSE COMMAND: \"This is humanity's last stand.\"")
			messages.append("UNITED NATIONS: \"To everyone who made it out... carry our memory to the stars.\"")
			messages.append("GLOBAL BROADCAST: \"Stay with your families. We love you all.\"")
			if pop > 0:
				messages.append("Earth. Population: %s. Home." % FCWTypes.format_population(pop))

	return messages

static func _get_movement_messages(state: Dictionary, from_zone: int, to_zone: int) -> Array:
	## Get messages for Herald movement between zones
	var from_name = FCWTypes.get_zone_name(from_zone)
	var to_name = FCWTypes.get_zone_name(to_zone)
	var sig = state.zone_signatures.get(to_zone, 0.0)
	var messages: Array = []

	messages.append("━━━ HERALD MOVEMENT DETECTED ━━━")

	if sig >= FCWTypes.HERALD_SKIP_THRESHOLD:
		messages.append("DEEP SPACE NETWORK: \"It's changing course. Heading directly for %s.\"" % to_name)
		messages.append("INTELLIGENCE: \"It detected our activity. Signature level: %.0f%%\"" % (sig * 100))
	elif sig >= FCWTypes.HERALD_MIN_SIG_TO_ATTRACT:
		messages.append("TRACKING STATION: \"Herald departing %s. New heading: %s.\"" % [from_name, to_name])
		messages.append("ANALYSIS: \"It's following emissions from %s sector.\"" % to_name)
	else:
		messages.append("OBSERVATORY: \"Herald continuing inward from %s toward %s.\"" % [from_name, to_name])
		messages.append("COMMAND: \"Default trajectory. It hasn't detected our main operations... yet.\"")

	# Warning for high-value targets
	if to_zone == FCWTypes.ZoneId.MARS:
		messages.append("MARS DEFENSE: \"All hands, prepare for engagement. This is not a drill.\"")
	elif to_zone == FCWTypes.ZoneId.EARTH:
		messages.append("EARTH COMMAND: \"DEFCON 1. May God have mercy on us all.\"")

	return messages

static func get_signature_warning_messages(state: Dictionary) -> Array:
	## Get warning messages if signatures are dangerously high
	var messages: Array = []
	var sigs = state.zone_signatures
	var herald_zone = state.herald_current_zone

	# Check adjacent zones for high signatures
	var adjacent = FCWTypes.get_zone_adjacent(herald_zone)
	for zone_id in adjacent:
		var sig = sigs.get(zone_id, 0.0)
		var zone_name = FCWTypes.get_zone_name(zone_id)

		if sig >= 0.6:
			messages.append("⚠ CRITICAL: %s signature at %.0f%% - Herald will likely target next!" % [zone_name, sig * 100])
		elif sig >= 0.3:
			messages.append("⚠ WARNING: %s signature rising (%.0f%%) - reduce activity!" % [zone_name, sig * 100])

	# Check skip zones
	var skippable = FCWTypes.get_zone_skip_targets(herald_zone)
	for zone_id in skippable:
		var sig = sigs.get(zone_id, 0.0)
		var zone_name = FCWTypes.get_zone_name(zone_id)

		if sig >= FCWTypes.HERALD_SKIP_THRESHOLD:
			messages.append("⚠ DANGER: %s signature (%.0f%%) high enough for Herald to skip zones!" % [zone_name, sig * 100])

	return messages

static func format_signature_report(state: Dictionary) -> String:
	## Format zone signatures for UI display
	var report = "=== DETECTION SIGNATURES ===\n"
	var sigs = state.zone_signatures
	var herald_zone = state.herald_current_zone

	# Sort zones by signature (highest first)
	var zone_list: Array = []
	for zone_id in sigs:
		zone_list.append({"id": zone_id, "sig": sigs[zone_id]})
	zone_list.sort_custom(func(a, b): return a.sig > b.sig)

	for entry in zone_list:
		var zone_name = FCWTypes.get_zone_name(entry.id)
		var sig = entry.sig
		var bar = ""
		var bar_len = int(sig * 20)
		for i in range(bar_len):
			bar += "█"
		for i in range(20 - bar_len):
			bar += "░"

		var marker = ""
		if entry.id == herald_zone:
			marker = " ◄ HERALD"
		elif sig >= FCWTypes.HERALD_SKIP_THRESHOLD:
			marker = " ⚠ HIGH"
		elif sig >= FCWTypes.HERALD_MIN_SIG_TO_ATTRACT:
			marker = " !"

		report += "%s: [%s] %.0f%%%s\n" % [zone_name.substr(0, 8).pad_zeros(8), bar, sig * 100, marker]

	return report
