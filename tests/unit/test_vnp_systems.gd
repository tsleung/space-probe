extends GutTest
## Unit tests for VnpSystems pure functions
## Run in editor via GUT panel, or via CLI

const VnpSystems = preload("res://scripts/von_neumann_probe/vnp_systems.gd")
const VnpTypes = preload("res://scripts/von_neumann_probe/vnp_types.gd")


# =============================================================================
# MOVEMENT TESTS
# =============================================================================

func test_apply_thrust_from_stationary():
	var v = VnpSystems.apply_thrust(Vector2.ZERO, Vector2.RIGHT, 100.0, 2.0, 0.1)
	assert_gt(v.x, 0, "thrust increases velocity in direction")
	assert_almost_eq(v.x, 20.0, 0.1, "thrust magnitude correct (100 * 2 * 0.1)")


func test_apply_thrust_adds_to_existing():
	var v = VnpSystems.apply_thrust(Vector2(50, 0), Vector2.RIGHT, 100.0, 2.0, 0.1)
	assert_almost_eq(v.x, 70.0, 0.1, "thrust adds to existing velocity")


func test_apply_thrust_braking():
	var v = VnpSystems.apply_thrust(Vector2(50, 0), Vector2.LEFT, 100.0, 2.0, 0.1)
	assert_almost_eq(v.x, 30.0, 0.1, "opposite thrust reduces velocity")


func test_apply_drag_reduces_velocity():
	var v = VnpSystems.apply_drag(Vector2(100, 0), 0.5, 0.1)
	assert_lt(v.x, 100, "drag reduces velocity")
	assert_gt(v.x, 0, "drag doesn't reverse velocity")


func test_apply_drag_high_drag():
	var v = VnpSystems.apply_drag(Vector2(100, 0), 10.0, 1.0)
	assert_lt(v.x, 10, "high drag significantly reduces velocity")


func test_clamp_velocity_above_max():
	var v = VnpSystems.clamp_velocity(Vector2(200, 0), 100.0)
	assert_almost_eq(v.length(), 100.0, 0.1, "velocity clamped to max")


func test_clamp_velocity_below_max():
	var v = VnpSystems.clamp_velocity(Vector2(50, 0), 100.0)
	assert_almost_eq(v.length(), 50.0, 0.1, "velocity below max unchanged")


func test_clamp_velocity_diagonal():
	var v = VnpSystems.clamp_velocity(Vector2(200, 200), 100.0)
	assert_almost_eq(v.length(), 100.0, 0.1, "diagonal velocity clamped correctly")


func test_calculate_movement_produces_velocity():
	var v = VnpSystems.calculate_movement(
		Vector2.ZERO, Vector2.RIGHT, 100.0, 2.0, 0.3, 0.1
	)
	assert_gt(v.x, 0, "movement produces velocity in direction")
	assert_lte(v.length(), 120.0, "velocity within max (with overspeed)")


# =============================================================================
# TARGETING TESTS
# =============================================================================

func test_score_target_distance():
	var near_score = VnpSystems.score_target(
		Vector2.ZERO, Vector2(100, 0), 100, 100, 200, Vector2.ZERO
	)
	var far_score = VnpSystems.score_target(
		Vector2.ZERO, Vector2(500, 0), 100, 100, 200, Vector2.ZERO
	)
	assert_gt(near_score, far_score, "nearer targets score higher")


func test_score_target_rally_alignment():
	var rally = Vector2(1000, 0)  # Rally to the right

	# Enemy in rally direction
	var aligned_score = VnpSystems.score_target(
		Vector2.ZERO, Vector2(200, 0), 100, 100, 200, rally
	)
	# Enemy opposite to rally
	var opposite_score = VnpSystems.score_target(
		Vector2.ZERO, Vector2(-200, 0), 100, 100, 200, rally
	)

	assert_gt(aligned_score, opposite_score, "enemies toward rally score higher")


func test_score_target_wounded_bonus():
	var healthy_score = VnpSystems.score_target(
		Vector2.ZERO, Vector2(100, 0), 100, 100, 200, Vector2.ZERO
	)
	var wounded_score = VnpSystems.score_target(
		Vector2.ZERO, Vector2(100, 0), 30, 100, 200, Vector2.ZERO
	)

	assert_gt(wounded_score, healthy_score, "wounded targets score higher")


func test_find_best_target():
	var ships = {
		1: {"team": 0, "position": Vector2(100, 0), "health": 100, "type": VnpTypes.ShipType.FRIGATE},
		2: {"team": 1, "position": Vector2(200, 0), "health": 100, "type": VnpTypes.ShipType.FRIGATE},
		3: {"team": 1, "position": Vector2(500, 0), "health": 100, "type": VnpTypes.ShipType.FRIGATE},
	}

	var best = VnpSystems.find_best_target(
		Vector2.ZERO, 0, 300.0, Vector2.ZERO, ships
	)
	assert_eq(best, 2, "selects nearest enemy (not ally)")


# =============================================================================
# CLUSTER TESTS
# =============================================================================

func test_calculate_centroid():
	var centroid = VnpSystems.calculate_centroid([
		Vector2(0, 0), Vector2(100, 0), Vector2(50, 100)
	])
	assert_almost_eq(centroid.x, 50.0, 1.0, "centroid x correct")
	assert_almost_eq(centroid.y, 33.33, 1.0, "centroid y correct")


func test_calculate_centroid_empty():
	var centroid = VnpSystems.calculate_centroid([])
	assert_eq(centroid, Vector2.ZERO, "empty array returns zero")


func test_calculate_cluster_score_tighter_is_higher():
	# Tight cluster
	var tight = VnpSystems.calculate_cluster_score([
		Vector2(0, 0), Vector2(10, 0), Vector2(5, 10)
	])
	# Spread cluster
	var spread = VnpSystems.calculate_cluster_score([
		Vector2(0, 0), Vector2(200, 0), Vector2(100, 200)
	])

	assert_gt(tight, spread, "tighter clusters score higher")


func test_calculate_cluster_score_single_point():
	var single = VnpSystems.calculate_cluster_score([Vector2(0, 0)])
	assert_almost_eq(single, 0.0, 0.1, "single point has zero cluster score")


func test_find_enemy_cluster():
	var ships = {
		1: {"team": 0, "position": Vector2(0, 0)},
		2: {"team": 1, "position": Vector2(100, 0)},
		3: {"team": 1, "position": Vector2(120, 0)},
		4: {"team": 1, "position": Vector2(1000, 0)},  # Out of range
	}

	var cluster = VnpSystems.find_enemy_cluster(Vector2.ZERO, 0, 500.0, ships)
	assert_almost_eq(cluster.x, 110.0, 1.0, "cluster center of enemies in range")


func test_count_enemies_in_range():
	var ships = {
		1: {"team": 0, "position": Vector2(0, 0)},
		2: {"team": 1, "position": Vector2(100, 0)},
		3: {"team": 1, "position": Vector2(200, 0)},
		4: {"team": 1, "position": Vector2(500, 0)},
	}

	var count = VnpSystems.count_enemies_in_range(Vector2.ZERO, 0, 250.0, ships)
	assert_eq(count, 2, "counts enemies within range")


# =============================================================================
# FLEET CENTER TESTS
# =============================================================================

func test_fleet_center_basic():
	var ships = {
		1: {"team": 0, "position": Vector2(100, 0), "type": VnpTypes.ShipType.FRIGATE},
		2: {"team": 0, "position": Vector2(200, 0), "type": VnpTypes.ShipType.FRIGATE},
		3: {"team": 1, "position": Vector2(500, 0), "type": VnpTypes.ShipType.FRIGATE},  # Enemy
	}

	var center = VnpSystems.calculate_fleet_center(
		0, ships, Vector2.ZERO, Vector2.ZERO, false
	)
	assert_gt(center.x, 100, "fleet center past first ship")
	assert_lt(center.x, 200, "fleet center before last ship")


func test_fleet_center_with_rally():
	var ships = {
		1: {"team": 0, "position": Vector2(100, 0), "type": VnpTypes.ShipType.FRIGATE},
	}

	# Without rally
	var no_rally = VnpSystems.calculate_fleet_center(
		0, ships, Vector2.ZERO, Vector2.ZERO, false
	)
	# With rally far right
	var with_rally = VnpSystems.calculate_fleet_center(
		0, ships, Vector2.ZERO, Vector2(1000, 0), false
	)

	assert_gt(with_rally.x, no_rally.x, "rally point pulls fleet center")


# =============================================================================
# BASE WEAPON TESTS
# =============================================================================

func test_weapon_range_scaling_x1():
	var r1 = VnpSystems.get_weapon_range(1)
	assert_almost_eq(r1, 350.0, 1.0, "x1 charge has base range")


func test_weapon_range_scaling_x5():
	var r5 = VnpSystems.get_weapon_range(5)
	assert_almost_eq(r5, 1400.0, 1.0, "x5 charge has max range")


func test_weapon_range_scaling_increases():
	var r1 = VnpSystems.get_weapon_range(1)
	var r5 = VnpSystems.get_weapon_range(5)
	assert_gt(r5, r1, "higher charges have more range")


func test_weapon_damage_scaling_x1():
	var d1 = VnpSystems.get_weapon_damage(1)
	assert_almost_eq(d1, 80.0, 1.0, "x1 charge has base damage")


func test_weapon_damage_scaling_x5():
	var d5 = VnpSystems.get_weapon_damage(5)
	assert_almost_eq(d5, 240.0, 1.0, "x5 charge has max damage")


func test_evaluate_base_weapon_fire_no_charges():
	var result = VnpSystems.evaluate_base_weapon_fire(0, 5, 2.0)
	assert_false(result.should_fire, "no fire with zero charges")


func test_evaluate_base_weapon_fire_max_charges():
	var result = VnpSystems.evaluate_base_weapon_fire(5, 1, 0.5)
	assert_true(result.should_fire, "always fire at max charges")
	assert_true(result.burst, "burst at max charges")


func test_evaluate_base_weapon_fire_no_enemies():
	var result = VnpSystems.evaluate_base_weapon_fire(3, 0, 0.0)
	assert_false(result.should_fire, "no fire without enemies")


# =============================================================================
# GEOMETRY TESTS
# =============================================================================

func test_point_to_line_distance_perpendicular():
	# Point directly above line
	var dist = VnpSystems.point_to_line_distance(
		Vector2(50, 50), Vector2(0, 0), Vector2(100, 0)
	)
	assert_almost_eq(dist, 50.0, 0.1, "perpendicular distance correct")


func test_point_to_line_distance_beyond_end():
	# Point beyond line end
	var dist = VnpSystems.point_to_line_distance(
		Vector2(150, 0), Vector2(0, 0), Vector2(100, 0)
	)
	assert_almost_eq(dist, 50.0, 0.1, "distance to line endpoint")


func test_point_to_line_distance_on_line():
	# Point on line
	var dist = VnpSystems.point_to_line_distance(
		Vector2(50, 0), Vector2(0, 0), Vector2(100, 0)
	)
	assert_almost_eq(dist, 0.0, 0.1, "point on line has zero distance")


func test_is_in_beam_path_inside():
	var in_beam = VnpSystems.is_in_beam_path(
		Vector2(50, 20), Vector2(0, 0), Vector2(100, 0), 30.0
	)
	assert_true(in_beam, "point within beam width")


func test_is_in_beam_path_outside():
	var outside = VnpSystems.is_in_beam_path(
		Vector2(50, 50), Vector2(0, 0), Vector2(100, 0), 30.0
	)
	assert_false(outside, "point outside beam width")


func test_damage_falloff_zero_distance():
	var full = VnpSystems.apply_damage_falloff(100.0, 0.0, 200.0)
	assert_almost_eq(full, 100.0, 0.1, "zero distance = full damage")


func test_damage_falloff_mid_distance():
	var half = VnpSystems.apply_damage_falloff(100.0, 100.0, 200.0)
	assert_lt(half, 100.0, "mid distance = reduced damage")
	assert_gt(half, 40.0, "mid distance still has significant damage")


func test_damage_falloff_max_distance():
	var edge = VnpSystems.apply_damage_falloff(100.0, 200.0, 200.0)
	assert_almost_eq(edge, 40.0, 0.1, "max distance = min damage (40%)")


# =============================================================================
# STRATEGIC POINT TESTS
# =============================================================================

func test_team_health_bonus():
	var points = {
		"relay_0": {"type": VnpTypes.PointType.RELAY, "owner": 0},
		"center": {"type": VnpTypes.PointType.CENTER, "owner": 0},
		"asteroid": {"type": VnpTypes.PointType.ASTEROID_FIELD, "owner": 1},
	}

	var health_bonus = VnpSystems.get_team_health_bonus(0, points)
	assert_gt(health_bonus, 0, "relay gives health bonus")


func test_team_damage_bonus():
	var points = {
		"relay_0": {"type": VnpTypes.PointType.RELAY, "owner": 0},
		"center": {"type": VnpTypes.PointType.CENTER, "owner": 0},
		"asteroid": {"type": VnpTypes.PointType.ASTEROID_FIELD, "owner": 1},
	}

	var damage_bonus = VnpSystems.get_team_damage_bonus(0, points)
	assert_gt(damage_bonus, 0, "center gives damage bonus")


func test_team_bonus_unowned():
	var points = {
		"relay_0": {"type": VnpTypes.PointType.RELAY, "owner": 0},
		"center": {"type": VnpTypes.PointType.CENTER, "owner": 0},
	}

	# Team 1 doesn't own relay or center
	var enemy_health = VnpSystems.get_team_health_bonus(1, points)
	assert_almost_eq(enemy_health, 0.0, 0.1, "no bonus from unowned points")
