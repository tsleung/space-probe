extends RefCounted
class_name FCWHeraldAI

## First Contact War - Herald AI System
## Observation-limited predator that follows human activity
##
## Design principles:
## - Herald only sees what's near it (local observation radius)
## - Follows activity (responds to detected burns)
## - Doesn't care about planets - only human signatures
## - Can release fast drones to intercept targets
## - Learns traffic patterns over time

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
