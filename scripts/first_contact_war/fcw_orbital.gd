extends RefCounted
class_name FCWOrbital

## First Contact War - Orbital Mechanics
## Calculates routes, travel times, and gravity assists
## All positions in AU, times in hours (converted from legacy weeks)

const FCWTypes = preload("res://scripts/first_contact_war/fcw_types.gd")

# ============================================================================
# ROUTE CALCULATION
# ============================================================================

class RouteOption:
	## Represents one possible route between two points
	var travel_time: float      # Weeks
	var waypoints: Array        # Array of zone IDs for gravity assists
	var departure_burn: bool    # True if starts with burn (visible)
	var arrival_burn: bool      # True if ends with burn (visible)
	var detection_windows: Array  # Array of {position, time, duration} where detectable
	var route_type: String      # "direct", "gravity_assist", "coast"

	func _init():
		travel_time = 0.0
		waypoints = []
		departure_burn = true
		arrival_burn = true
		detection_windows = []
		route_type = "direct"

static func get_route_options(from_zone: int, to_zone: int, game_time: float, ship_thrust: float) -> Array:
	## Get all available route options between two zones
	## Returns array of RouteOption objects with different tradeoffs
	var options = []

	var from_pos = FCWTypes.get_zone_position(from_zone, game_time)
	var to_pos = FCWTypes.get_zone_position(to_zone, game_time)

	# Option 1: Direct burn (fastest, most visible)
	var direct = _calc_direct_route(from_pos, to_pos, ship_thrust, game_time)
	direct.route_type = "direct"
	options.append(direct)

	# Option 2: Coast route (slower, less visible)
	var coast = _calc_coast_route(from_pos, to_pos, ship_thrust, game_time)
	coast.route_type = "coast"
	options.append(coast)

	# Option 3+: Gravity assist routes (if applicable)
	var assists = _get_gravity_assist_routes(from_zone, to_zone, game_time, ship_thrust)
	for assist_route in assists:
		assist_route.route_type = "gravity_assist"
		options.append(assist_route)

	return options

static func _calc_direct_route(from_pos: Vector2, to_pos: Vector2, thrust: float, game_time: float) -> RouteOption:
	## Calculate direct burn route - fastest but most visible
	## Burn halfway, flip, burn to stop (brachistochrone trajectory)
	var route = RouteOption.new()

	var distance = from_pos.distance_to(to_pos)

	# Brachistochrone travel time: t = 2 * sqrt(d / a)
	# where d is distance in AU and a is acceleration in AU/week^2
	if thrust > 0:
		route.travel_time = 2.0 * sqrt(distance / thrust)
	else:
		route.travel_time = 999.0  # Can't move without thrust

	route.departure_burn = true
	route.arrival_burn = true

	# Detection windows: visible entire journey (burning throughout)
	route.detection_windows = [{
		"position": from_pos.lerp(to_pos, 0.5),
		"time": game_time + route.travel_time * 0.5,
		"duration": route.travel_time
	}]

	return route

static func _calc_coast_route(from_pos: Vector2, to_pos: Vector2, thrust: float, game_time: float) -> RouteOption:
	## Calculate coast route - burn to velocity, coast, burn to stop
	## Longer travel time but only visible at start and end
	var route = RouteOption.new()

	var distance = from_pos.distance_to(to_pos)

	# Coast route: short burn to cruise velocity, long coast, short burn to stop
	# Cruise velocity is slower than constant burn (Hohmann-like efficiency)
	var cruise_velocity = 0.3  # AU/week - slower cruise for stealth

	# Burn time is capped - ships do a quick burst then coast
	# Even with low thrust, they don't burn for weeks
	var theoretical_burn = cruise_velocity / thrust if thrust > 0 else 1.0
	var burn_time = minf(theoretical_burn, 0.5)  # Cap at 0.5 weeks (3.5 days) per burn

	# Actual achieved cruise velocity based on capped burn
	var actual_cruise = minf(cruise_velocity, burn_time * thrust)

	var coast_time = distance / actual_cruise if actual_cruise > 0 else distance / 0.1

	route.travel_time = burn_time * 2 + coast_time
	route.departure_burn = true
	route.arrival_burn = true

	# Detection windows: only at departure and arrival burns (brief!)
	route.detection_windows = [
		{
			"position": from_pos,
			"time": game_time,
			"duration": burn_time
		},
		{
			"position": to_pos,
			"time": game_time + route.travel_time - burn_time,
			"duration": burn_time
		}
	]

	return route

static func _get_gravity_assist_routes(from_zone: int, to_zone: int, game_time: float, thrust: float) -> Array:
	## Find gravity assist opportunities
	## Returns routes that use planetary bodies to change trajectory
	var routes = []

	# Check each potential assist body
	var assist_bodies = _get_assist_candidates(from_zone, to_zone)

	for assist_zone in assist_bodies:
		var assist_route = _calc_gravity_assist_route(from_zone, to_zone, assist_zone, game_time, thrust)
		if assist_route:
			routes.append(assist_route)

	return routes

static func _get_assist_candidates(from_zone: int, to_zone: int) -> Array:
	## Get zones that could provide gravity assists between two points
	var candidates = []

	# Planets that make sense as assist points based on orbital mechanics
	# Generally, outer planets can sling toward inner, inner can brake toward outer
	var all_zones = [
		FCWTypes.ZoneId.JUPITER,
		FCWTypes.ZoneId.SATURN,
		FCWTypes.ZoneId.MARS,
		FCWTypes.ZoneId.ASTEROID_BELT
	]

	for zone in all_zones:
		if zone != from_zone and zone != to_zone:
			candidates.append(zone)

	return candidates

static func _calc_gravity_assist_route(from_zone: int, to_zone: int, assist_zone: int, game_time: float, thrust: float) -> RouteOption:
	## Calculate route using gravity assist at a specific body
	var route = RouteOption.new()

	var from_pos = FCWTypes.get_zone_position(from_zone, game_time)
	var assist_pos = FCWTypes.get_zone_position(assist_zone, game_time)

	# Estimate when we'd reach the assist body
	var leg1_distance = from_pos.distance_to(assist_pos)
	var leg1_time = 2.0 * sqrt(leg1_distance / thrust) if thrust > 0 else 10.0

	# Get assist body position when we arrive
	var assist_arrival_time = game_time + leg1_time
	var assist_pos_arrival = FCWTypes.get_zone_position(assist_zone, assist_arrival_time)

	# Get destination position when we'd arrive (estimate)
	var to_pos_future = FCWTypes.get_zone_position(to_zone, assist_arrival_time)
	var leg2_distance = assist_pos_arrival.distance_to(to_pos_future)

	# Gravity assist reduces effective thrust requirement on leg 2
	# (simplification: assume ~30% velocity boost from assist)
	var effective_thrust_leg2 = thrust * 1.3
	var leg2_time = 2.0 * sqrt(leg2_distance / effective_thrust_leg2) if effective_thrust_leg2 > 0 else 10.0

	route.travel_time = leg1_time + leg2_time
	route.waypoints = [assist_zone]
	route.departure_burn = true
	route.arrival_burn = true

	# Detection windows: burns at start, at assist point (course correction), and at end
	route.detection_windows = [
		{
			"position": from_pos,
			"time": game_time,
			"duration": leg1_time * 0.3  # Initial burn
		},
		{
			"position": assist_pos_arrival,
			"time": assist_arrival_time,
			"duration": 0.5  # Course correction at assist
		},
		{
			"position": to_pos_future,
			"time": game_time + route.travel_time,
			"duration": leg2_time * 0.3  # Arrival burn
		}
	]

	return route

# ============================================================================
# TRAVEL TIME QUERIES
# ============================================================================

static func get_fastest_travel_time(from_zone: int, to_zone: int, game_time: float, ship_type: int) -> float:
	## Get the fastest possible travel time for a ship type
	var thrust = FCWTypes.SHIP_THRUST.get(ship_type, 0.05)
	var options = get_route_options(from_zone, to_zone, game_time, thrust)

	var fastest = 999.0
	for option in options:
		if option.travel_time < fastest:
			fastest = option.travel_time

	return fastest

static func get_stealthiest_route(from_zone: int, to_zone: int, game_time: float, ship_type: int) -> RouteOption:
	## Get the route with minimum detection exposure
	var thrust = FCWTypes.SHIP_THRUST.get(ship_type, 0.05)
	var options = get_route_options(from_zone, to_zone, game_time, thrust)

	var best_route = null
	var min_exposure = 999.0

	for option in options:
		var exposure = 0.0
		for window in option.detection_windows:
			exposure += window.duration

		if exposure < min_exposure:
			min_exposure = exposure
			best_route = option

	return best_route

static func get_route_summary(from_zone: int, to_zone: int, game_time: float, ship_type: int) -> Array:
	## Get a summary of all route options for UI display
	## Returns array of {type, travel_time, exposure_time, waypoints}
	var thrust = FCWTypes.SHIP_THRUST.get(ship_type, 0.05)
	var options = get_route_options(from_zone, to_zone, game_time, thrust)

	var summaries = []
	for option in options:
		var exposure = 0.0
		for window in option.detection_windows:
			exposure += window.duration

		summaries.append({
			"type": option.route_type,
			"travel_time": option.travel_time,
			"exposure_time": exposure,
			"waypoints": option.waypoints,
			"detection_windows": option.detection_windows
		})

	# Sort by travel time
	summaries.sort_custom(func(a, b): return a.travel_time < b.travel_time)

	return summaries

# ============================================================================
# INTERCEPT CALCULATIONS
# ============================================================================

static func can_intercept(pursuer_pos: Vector2, pursuer_thrust: float, target_pos: Vector2, target_velocity: Vector2, max_time: float) -> Dictionary:
	## Check if pursuer can intercept target within max_time
	## Returns {can_intercept: bool, intercept_time: float, intercept_pos: Vector2}

	# Simplified intercept calculation
	# Real orbital mechanics would use Lambert's problem, but this is good enough

	var result = {
		"can_intercept": false,
		"intercept_time": 0.0,
		"intercept_pos": Vector2.ZERO
	}

	# Check intercept at various future times
	for t in range(1, int(max_time) + 1):
		var future_target_pos = target_pos + target_velocity * t
		var distance = pursuer_pos.distance_to(future_target_pos)

		# Can we reach that position in time t?
		var required_time = 2.0 * sqrt(distance / pursuer_thrust) if pursuer_thrust > 0 else 999.0

		if required_time <= t:
			result.can_intercept = true
			result.intercept_time = required_time
			result.intercept_pos = future_target_pos
			return result

	return result

static func calc_intercept_difficulty(target_velocity: float, target_signature: float, distance: float) -> float:
	## Calculate how hard it is to intercept a target
	## Returns 0.0 (easy) to 1.0 (nearly impossible)

	# Factors:
	# - Higher velocity = harder to catch
	# - Lower signature = harder to track
	# - Greater distance = harder to reach in time

	var velocity_factor = clampf(target_velocity / 1.0, 0.0, 1.0)  # 1 AU/week = max difficulty
	var signature_factor = 1.0 - clampf(target_signature, 0.0, 1.0)  # Low sig = high difficulty
	var distance_factor = clampf(distance / 10.0, 0.0, 1.0)  # 10 AU = max difficulty

	# Combined difficulty
	return clampf((velocity_factor * 0.4 + signature_factor * 0.4 + distance_factor * 0.2), 0.0, 1.0)

# ============================================================================
# UTILITY
# ============================================================================

static func format_travel_time(weeks: float) -> String:
	## Format travel time for display
	if weeks < 1.0:
		var days = int(weeks * 7)
		return "%d days" % days
	elif weeks < 4.0:
		return "%.1f weeks" % weeks
	else:
		var months = weeks / 4.0
		return "%.1f months" % months

static func get_orbital_period_weeks(zone_id: int) -> float:
	## Get orbital period in weeks for a zone
	var orbital = FCWTypes.ZONE_ORBITAL_DATA.get(zone_id)
	if orbital:
		return orbital.orbital_period * 52.0  # Years to weeks
	return 52.0  # Default 1 year
