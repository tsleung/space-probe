class_name VnpSystems
## Pure functions for VNP game mechanics
## All functions are static, take inputs, return outputs, no side effects
## These are the stable, testable core of the game logic

const VnpTypes = preload("res://scripts/von_neumann_probe/vnp_types.gd")


# =============================================================================
# MOVEMENT SYSTEMS - Physics calculations for ship movement
# =============================================================================

## Calculate new velocity after applying thrust
## Returns: new velocity vector
static func apply_thrust(
	current_velocity: Vector2,
	direction: Vector2,
	speed: float,
	thrust_multiplier: float,
	delta: float
) -> Vector2:
	var thrust_force = direction.normalized() * speed * thrust_multiplier
	return current_velocity + thrust_force * delta


## Apply space drag to velocity
## Returns: new velocity after drag
static func apply_drag(velocity: Vector2, drag: float, delta: float) -> Vector2:
	return velocity.lerp(Vector2.ZERO, drag * delta)


## Clamp velocity to max speed
## Returns: clamped velocity
static func clamp_velocity(velocity: Vector2, max_speed: float) -> Vector2:
	if velocity.length() > max_speed:
		return velocity.normalized() * max_speed
	return velocity


## Complete movement update: thrust + drag + clamp
## Returns: new velocity
static func calculate_movement(
	current_velocity: Vector2,
	target_direction: Vector2,
	speed: float,
	thrust_multiplier: float,
	drag: float,
	delta: float
) -> Vector2:
	var v = apply_thrust(current_velocity, target_direction, speed, thrust_multiplier, delta)
	v = clamp_velocity(v, speed * 1.2)  # Allow slight overspeed
	v = apply_drag(v, drag, delta)
	return v


# =============================================================================
# TARGETING SYSTEMS - Enemy selection and scoring
# =============================================================================

## Score a potential target based on distance, rally alignment, and health
## Returns: float score (higher = better target)
static func score_target(
	my_position: Vector2,
	target_position: Vector2,
	target_health: float,
	target_max_health: float,
	weapon_range: float,
	rally_point: Vector2  # Vector2.ZERO if no rally
) -> float:
	var dist = my_position.distance_to(target_position)

	# Base score from distance - prefer nearby
	var score = 1000.0 - dist

	# Bonus for enemies within engagement range
	var engagement_range = weapon_range * 2.0
	if dist <= engagement_range:
		score += 500.0

	# Rally alignment bonus - prefer enemies toward objective
	if rally_point != Vector2.ZERO and dist > 0:
		var to_rally = (rally_point - my_position).normalized()
		var to_target = (target_position - my_position).normalized()
		var alignment = to_rally.dot(to_target)  # -1 to 1
		score += alignment * 225.0

	# Bonus for wounded targets
	var health_percent = target_health / max(target_max_health, 1.0)
	if health_percent < 0.5:
		score += 200.0

	return score


## Find best target from a list of candidates
## Returns: best target id or -1 if none
static func find_best_target(
	my_position: Vector2,
	my_team: int,
	weapon_range: float,
	rally_point: Vector2,
	ships: Dictionary  # ship_id -> {team, position, health, type}
) -> int:
	var best_id = -1
	var best_score = -INF

	for ship_id in ships:
		var ship = ships[ship_id]
		if ship.team == my_team:
			continue

		var ship_stats = VnpTypes.SHIP_STATS.get(ship.type, {})
		var max_health = ship_stats.get("health", 100)

		var score = score_target(
			my_position,
			ship.position,
			ship.health,
			max_health,
			weapon_range,
			rally_point
		)

		# Add randomness to prevent all ships targeting same enemy
		score += randf() * 50.0

		if score > best_score:
			best_score = score
			best_id = ship_id

	return best_id


## Check if a better target exists (for target re-evaluation)
## Returns: better target id or -1 if current is still best
static func find_better_target(
	my_position: Vector2,
	my_team: int,
	current_target_id: int,
	weapon_range: float,
	rally_point: Vector2,
	ships: Dictionary,
	improvement_threshold: float = 150.0
) -> int:
	if rally_point == Vector2.ZERO:
		return -1  # No rally, stick with current

	if not ships.has(current_target_id):
		return find_best_target(my_position, my_team, weapon_range, rally_point, ships)

	var current = ships[current_target_id]
	var current_stats = VnpTypes.SHIP_STATS.get(current.type, {})
	var current_score = score_target(
		my_position,
		current.position,
		current.health,
		current_stats.get("health", 100),
		weapon_range,
		rally_point
	)

	var best_id = -1
	var best_score = current_score + improvement_threshold

	for ship_id in ships:
		if ship_id == current_target_id:
			continue
		var ship = ships[ship_id]
		if ship.team == my_team:
			continue

		var ship_stats = VnpTypes.SHIP_STATS.get(ship.type, {})
		var score = score_target(
			my_position,
			ship.position,
			ship.health,
			ship_stats.get("health", 100),
			weapon_range,
			rally_point
		)

		if score > best_score:
			best_score = score
			best_id = ship_id

	return best_id


# =============================================================================
# CLUSTER ANALYSIS - Finding groups of ships
# =============================================================================

## Calculate centroid of positions
## Returns: center point
static func calculate_centroid(positions: Array) -> Vector2:
	if positions.is_empty():
		return Vector2.ZERO

	var sum = Vector2.ZERO
	for pos in positions:
		sum += pos
	return sum / positions.size()


## Calculate how clustered positions are (higher = tighter cluster)
## Returns: cluster score
static func calculate_cluster_score(positions: Array) -> float:
	if positions.size() < 2:
		return 0.0

	var centroid = calculate_centroid(positions)

	var total_dist = 0.0
	for pos in positions:
		total_dist += pos.distance_to(centroid)
	var avg_dist = total_dist / positions.size()

	# Convert to score: closer = higher
	var score = 100.0 / max(avg_dist, 50.0)

	# Bonus for more ships
	score *= sqrt(positions.size()) / 2.0

	return score


## Find enemy cluster center within range
## Returns: cluster center or Vector2.ZERO if none
static func find_enemy_cluster(
	from_position: Vector2,
	my_team: int,
	max_range: float,
	ships: Dictionary
) -> Vector2:
	var enemy_positions = []

	for ship_id in ships:
		var ship = ships[ship_id]
		if ship.team != my_team:
			var dist = ship.position.distance_to(from_position)
			if dist <= max_range:
				enemy_positions.append(ship.position)

	return calculate_centroid(enemy_positions)


## Count enemies in range
## Returns: count
static func count_enemies_in_range(
	from_position: Vector2,
	my_team: int,
	range_dist: float,
	ships: Dictionary
) -> int:
	var count = 0
	for ship_id in ships:
		var ship = ships[ship_id]
		if ship.team != my_team:
			if ship.position.distance_to(from_position) <= range_dist:
				count += 1
	return count


# =============================================================================
# FLEET CENTER - Weighted position calculations
# =============================================================================

## Calculate fleet center of mass with optional rally bias
## Returns: weighted center position
static func calculate_fleet_center(
	team: int,
	ships: Dictionary,
	base_position: Vector2,
	rally_point: Vector2,  # Vector2.ZERO if none
	include_base_anchor: bool = false,
	base_weight: float = 3.0,
	rally_weight_base: float = 4.0
) -> Vector2:
	var positions = []
	var total_weight = 0.0

	# Base anchor (for defensive formation)
	if include_base_anchor:
		positions.append({"pos": base_position, "weight": base_weight})
		total_weight += base_weight

	# Rally point attractor
	if rally_point != Vector2.ZERO:
		var ship_count = 0
		for ship_id in ships:
			if ships[ship_id].team == team:
				ship_count += 1
		var rally_weight = max(rally_weight_base, ship_count * 0.5)
		positions.append({"pos": rally_point, "weight": rally_weight})
		total_weight += rally_weight

	# Ship positions weighted by health/importance
	for ship_id in ships:
		var ship = ships[ship_id]
		if ship.team == team:
			var ship_stats = VnpTypes.SHIP_STATS.get(ship.type, {})
			var weight = ship_stats.get("health", 100) / 100.0
			positions.append({"pos": ship.position, "weight": weight})
			total_weight += weight

	if positions.is_empty():
		return base_position

	var center = Vector2.ZERO
	for p in positions:
		center += p.pos * p.weight
	return center / total_weight


# =============================================================================
# BASE WEAPON SCALING - Charge-based calculations
# =============================================================================

const BASE_RANGE = 350.0
const MAX_RANGE = 1400.0
const BASE_DAMAGE = 80.0
const DAMAGE_PER_CHARGE = 40.0

## Calculate weapon range for given charge count
## Returns: range in pixels
static func get_weapon_range(charges: int) -> float:
	var t = (clampi(charges, 1, 5) - 1) / 4.0
	return lerp(BASE_RANGE, MAX_RANGE, t)


## Calculate weapon damage for given charge count
## Returns: damage amount
static func get_weapon_damage(charges: int) -> float:
	return BASE_DAMAGE + (clampi(charges, 1, 5) - 1) * DAMAGE_PER_CHARGE


## Evaluate whether AI should fire base weapon
## Returns: {should_fire: bool, burst: bool}
static func evaluate_base_weapon_fire(
	charges: int,
	enemies_in_range: int,
	cluster_score: float,
	max_charges: int = 5
) -> Dictionary:
	if charges <= 0:
		return {"should_fire": false, "burst": false}

	# Always fire at max
	if charges >= max_charges:
		return {"should_fire": true, "burst": true}

	# No enemies = don't fire
	if enemies_in_range == 0:
		return {"should_fire": false, "burst": false}

	# Thresholds based on charge level
	var thresholds = {1: 2.5, 2: 3.5, 3: 5.0, 4: 6.0}
	var fire_threshold = thresholds.get(charges, 2.5)

	# Combined score
	var opportunity_score = enemies_in_range + cluster_score * 2.0

	# Random fire chance (lower for higher charges)
	var random_fire_chance = 0.15 / charges

	var should_fire = opportunity_score >= fire_threshold or randf() < random_fire_chance
	var should_burst = charges >= 3 and opportunity_score >= fire_threshold * 1.5

	return {"should_fire": should_fire, "burst": should_burst}


# =============================================================================
# GEOMETRY HELPERS - Pure math functions
# =============================================================================

## Distance from point to line segment
## Returns: distance
static func point_to_line_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var line_vec = line_end - line_start
	var point_vec = point - line_start
	var line_len = line_vec.length()

	if line_len == 0:
		return point.distance_to(line_start)

	var line_unit = line_vec / line_len
	var proj_length = clamp(point_vec.dot(line_unit), 0, line_len)
	var proj_point = line_start + line_unit * proj_length
	return point.distance_to(proj_point)


## Check if position is within range of line (for beam weapons)
## Returns: bool
static func is_in_beam_path(
	position: Vector2,
	beam_start: Vector2,
	beam_end: Vector2,
	beam_width: float
) -> bool:
	return point_to_line_distance(position, beam_start, beam_end) < beam_width


## Calculate damage with distance falloff
## Returns: final damage
static func apply_damage_falloff(
	base_damage: float,
	distance: float,
	max_distance: float,
	min_falloff: float = 0.4
) -> float:
	var falloff = 1.0 - (distance / max_distance) * (1.0 - min_falloff)
	return base_damage * max(falloff, min_falloff)


# =============================================================================
# STRATEGIC POINT BONUSES - Pure lookups
# =============================================================================

## Get health bonus from controlled points
## Returns: bonus multiplier (0.0 to N)
static func get_team_health_bonus(team: int, strategic_points: Dictionary) -> float:
	var bonus = 0.0
	for point_id in strategic_points:
		var point = strategic_points[point_id]
		if point.get("owner", null) == team:
			var point_type = point.get("type", -1)
			var point_bonuses = VnpTypes.POINT_BONUSES.get(point_type, {})
			bonus += point_bonuses.get("health_bonus", 0.0)
	return bonus


## Get damage bonus from controlled points
## Returns: bonus multiplier (0.0 to N)
static func get_team_damage_bonus(team: int, strategic_points: Dictionary) -> float:
	var bonus = 0.0
	for point_id in strategic_points:
		var point = strategic_points[point_id]
		if point.get("owner", null) == team:
			var point_type = point.get("type", -1)
			var point_bonuses = VnpTypes.POINT_BONUSES.get(point_type, {})
			bonus += point_bonuses.get("damage_bonus", 0.0)
	return bonus
