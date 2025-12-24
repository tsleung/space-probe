extends Node2D

const VnpTypes = preload("res://scripts/von_neumann_probe/vnp_types.gd")

var store = null
var vnp_main = null  # Reference to VnpMain for screen shake
var team: int = -1
var weapon_type: int = -1
var base_position: Vector2 = Vector2.ZERO
var charge_count: int = 1  # Number of charges fired (1-5)

# Charge scaling constants
const BASE_RANGE = 350.0       # x1 range - close/desperation
const MAX_RANGE = 1400.0       # x5 range - reaches center and beyond
const BASE_DAMAGE = 80.0       # x1 damage
const DAMAGE_PER_CHARGE = 40.0 # Additional damage per charge

func init(vnp_store, firing_team: int, from_pos: Vector2, charges: int = 1, main_ref = null):
	self.store = vnp_store
	self.vnp_main = main_ref
	self.team = firing_team
	self.base_position = from_pos
	self.charge_count = clampi(charges, 1, 5)
	self.weapon_type = VnpTypes.BASE_WEAPONS[team]
	self.position = from_pos

	match weapon_type:
		VnpTypes.BaseWeapon.ARC_STORM:
			_fire_arc_storm()
		VnpTypes.BaseWeapon.HELLSTORM:
			_fire_hellstorm()
		VnpTypes.BaseWeapon.VOID_TEAR:
			_fire_void_tear()


func _get_scaled_range() -> float:
	var t = (charge_count - 1) / 4.0
	return lerp(BASE_RANGE, MAX_RANGE, t)


func _get_scaled_damage() -> float:
	return BASE_DAMAGE + (charge_count - 1) * DAMAGE_PER_CHARGE


func _shake_screen(intensity: float):
	if vnp_main and vnp_main.has_method("shake_screen"):
		vnp_main.shake_screen(intensity)


# =============================================================================
# PLAYER: ARC STORM - Chain lightning that jumps between enemies
# =============================================================================

func _fire_arc_storm():
	# Play Arc Storm sound
	if vnp_main and vnp_main.sound_manager:
		vnp_main.sound_manager.play_arc_storm()

	var state = store.get_state()
	var max_range = _get_scaled_range()
	var scaled_damage = _get_scaled_damage()

	print("[ARC STORM] Firing with %d charges, range: %.0f, from base at %s" % [charge_count, max_range, base_position])

	# Find all enemies in range - use REAL ship node positions, not stale state
	var enemies_in_range = []
	var total_enemies = 0
	for ship_id in state.ships:
		var ship_data = state.ships[ship_id]
		if ship_data.team != team:
			total_enemies += 1
			# Get real position from ship node if available
			var ship_pos = ship_data.position  # Fallback to state position
			if vnp_main and vnp_main.ship_nodes.has(ship_id):
				var ship_node = vnp_main.ship_nodes[ship_id]
				if is_instance_valid(ship_node):
					ship_pos = ship_node.global_position
			var dist = ship_pos.distance_to(base_position)
			if dist <= max_range:
				enemies_in_range.append({"id": ship_id, "pos": ship_pos, "dist": dist})

	print("[ARC STORM] Found %d enemies total, %d in range" % [total_enemies, enemies_in_range.size()])

	if enemies_in_range.is_empty():
		print("[ARC STORM] No enemies in range! Closest enemy might be too far.")
		queue_free()
		return

	# Sort by distance for initial target
	enemies_in_range.sort_custom(func(a, b): return a.dist < b.dist)

	# Screen shake scales with charges
	var shake_intensity = 20.0 + charge_count * 15.0
	_shake_screen(shake_intensity)

	# Number of chain targets scales with charges
	var max_chains = 3 + charge_count * 2  # 5 to 13 chains
	var chain_range = 200.0 + charge_count * 40.0  # How far lightning can jump

	# Build the chain - start from base, jump to enemies
	var chain_targets = []
	var hit_enemies = {}  # Track which enemies we've hit

	# First arc goes to nearest enemy
	var current_pos = Vector2.ZERO  # Local position (relative to base)
	chain_targets.append(current_pos)

	for i in range(max_chains):
		# Find nearest unhit enemy within chain range
		var best_target = null
		var best_dist = INF

		for enemy in enemies_in_range:
			if hit_enemies.has(enemy.id):
				continue
			var local_pos = enemy.pos - base_position
			var dist = current_pos.distance_to(local_pos)
			# First jump can be longer (from base), subsequent jumps limited
			var effective_range = max_range if i == 0 else chain_range
			if dist < best_dist and dist <= effective_range:
				best_dist = dist
				best_target = enemy

		if best_target == null:
			break  # No more valid targets

		var target_local = best_target.pos - base_position
		chain_targets.append(target_local)
		hit_enemies[best_target.id] = true
		current_pos = target_local

		# Deal damage
		var chain_damage = scaled_damage * (1.0 - i * 0.08)  # Slight falloff per jump
		store.dispatch({
			"type": "DAMAGE_SHIP",
			"ship_id": best_target.id,
			"damage": chain_damage
		})

	# Now create the visual lightning chain
	if chain_targets.size() < 2:
		queue_free()
		return

	# Charge-up effect
	if charge_count >= 3:
		await _arc_storm_charge_up()

	# Create main lightning arcs between all chain points
	var all_visuals = []
	for i in range(chain_targets.size() - 1):
		var start = chain_targets[i]
		var end = chain_targets[i + 1]
		var arc_visuals = _create_lightning_arc(start, end, i == 0)
		all_visuals.append_array(arc_visuals)

	# Add secondary arcs branching off randomly for extra spectacle
	var secondary_arc_count = charge_count * 2
	for i in range(secondary_arc_count):
		if chain_targets.size() < 2:
			break
		var source_idx = randi() % (chain_targets.size() - 1) + 1  # Skip base
		var source = chain_targets[source_idx]
		var angle = randf() * TAU
		var length = randf_range(40, 100) + charge_count * 15
		var end = source + Vector2(cos(angle), sin(angle)) * length
		var secondary = _create_lightning_arc(source, end, false, 0.5)
		all_visuals.append_array(secondary)

	# Add impact sparks at each hit point
	for i in range(1, chain_targets.size()):
		_spawn_arc_impact(chain_targets[i])

	# Fade out all visuals
	var fade_time = 0.4 + charge_count * 0.1
	var tween = create_tween()
	tween.set_parallel(true)
	for visual in all_visuals:
		if is_instance_valid(visual):
			tween.tween_property(visual, "modulate:a", 0.0, fade_time * randf_range(0.7, 1.0))
	await tween.finished
	queue_free()


func _arc_storm_charge_up():
	# SPECTACULAR CHARGE-UP - Electricity gathering with corona effect

	# Create pulsing corona around base
	var corona_ring = Line2D.new()
	corona_ring.width = 12.0 + charge_count * 4
	corona_ring.default_color = Color(0.3, 0.7, 1.0, 0.4)
	var ring_points = []
	for i in range(33):
		var angle = i * (TAU / 32)
		ring_points.append(Vector2(cos(angle), sin(angle)) * (100 + charge_count * 20))
	corona_ring.points = PackedVector2Array(ring_points)
	add_child(corona_ring)

	# Inner bright corona
	var inner_corona = Line2D.new()
	inner_corona.width = 6.0 + charge_count * 2
	inner_corona.default_color = Color(0.6, 0.9, 1.0, 0.7)
	inner_corona.points = PackedVector2Array(ring_points)
	add_child(inner_corona)

	# Pulsing animation on corona
	var corona_tween = create_tween()
	corona_tween.set_parallel(true)
	corona_tween.tween_property(corona_ring, "scale", Vector2(0.7, 0.7), 0.3).set_trans(Tween.TRANS_SINE)
	corona_tween.tween_property(inner_corona, "scale", Vector2(0.5, 0.5), 0.3).set_trans(Tween.TRANS_SINE)
	corona_tween.tween_property(corona_ring, "modulate:a", 0.0, 0.35)
	corona_tween.tween_property(inner_corona, "modulate:a", 0.0, 0.35)

	# Electricity tendrils gathering toward center
	var tendril_count = 12 + charge_count * 4
	for i in range(tendril_count):
		var angle = randf() * TAU
		var dist = randf_range(100, 180 + charge_count * 20)
		var start = Vector2(cos(angle), sin(angle)) * dist

		# Multi-layer tendril
		var glow = _create_jagged_line(start, Vector2.ZERO, 8.0, 5)
		glow.default_color = Color(0.2, 0.5, 1.0, 0.3)
		add_child(glow)

		var main = _create_jagged_line(start, Vector2.ZERO, 3.0, 6)
		main.default_color = Color(0.5, 0.9, 1.0, 0.85)
		add_child(main)

		var core = _create_jagged_line(start, Vector2.ZERO, 1.5, 6)
		core.default_color = Color(0.95, 0.98, 1.0, 0.95)
		add_child(core)

		var delay = randf() * 0.15
		var tween = create_tween()
		tween.tween_interval(delay)
		tween.tween_property(glow, "modulate:a", 0.0, 0.2)

		var tween2 = create_tween()
		tween2.tween_interval(delay)
		tween2.tween_property(main, "modulate:a", 0.0, 0.25)

		var tween3 = create_tween()
		tween3.tween_interval(delay)
		tween3.tween_property(core, "modulate:a", 0.0, 0.25)

	# Central energy buildup - bright growing orb
	var energy_core = Polygon2D.new()
	var core_points = []
	for i in range(12):
		var angle = i * (TAU / 12)
		core_points.append(Vector2(cos(angle), sin(angle)) * 15)
	energy_core.polygon = PackedVector2Array(core_points)
	energy_core.color = Color(0.7, 0.95, 1.0, 0.9)
	energy_core.scale = Vector2(0.1, 0.1)
	add_child(energy_core)

	var core_tween = create_tween()
	core_tween.tween_property(energy_core, "scale", Vector2(1.5 + charge_count * 0.3, 1.5 + charge_count * 0.3), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	core_tween.tween_property(energy_core, "modulate:a", 0.0, 0.1)

	await get_tree().create_timer(0.3).timeout


func _create_lightning_arc(start: Vector2, end: Vector2, is_main: bool, alpha_mult: float = 1.0) -> Array:
	var visuals = []
	var width = 8.0 if is_main else 4.0
	width += charge_count * 2

	# Outer glow
	var glow = _create_jagged_line(start, end, width * 3, 6)
	glow.default_color = Color(0.3, 0.6, 1.0, 0.2 * alpha_mult)
	add_child(glow)
	visuals.append(glow)

	# Main arc
	var main = _create_jagged_line(start, end, width, 8 + charge_count)
	main.default_color = Color(0.4, 0.85, 1.0, 0.9 * alpha_mult)
	add_child(main)
	visuals.append(main)

	# Hot core
	var core = _create_jagged_line(start, end, width * 0.4, 8 + charge_count)
	core.default_color = Color(0.95, 0.98, 1.0, 0.95 * alpha_mult)
	add_child(core)
	visuals.append(core)

	return visuals


func _create_jagged_line(start: Vector2, end: Vector2, width: float, segments: int) -> Line2D:
	var line = Line2D.new()
	line.width = width
	line.antialiased = true

	var direction = end - start
	var perpendicular = direction.normalized().rotated(PI/2)
	var jag_amount = width * 1.2

	line.add_point(start)
	for i in range(1, segments):
		var t = float(i) / segments
		var base_pos = start + direction * t
		var offset = perpendicular * randf_range(-jag_amount, jag_amount)
		line.add_point(base_pos + offset)
	line.add_point(end)

	return line


func _spawn_arc_impact(pos: Vector2):
	# SPECTACULAR IMPACT - Electric burst with EMP rings and residual static

	# Central flash
	var flash = Polygon2D.new()
	flash.position = pos
	var flash_size = 20.0 + charge_count * 8
	var flash_points = []
	for i in range(16):
		var angle = i * (TAU / 16)
		var r = flash_size * (0.7 + randf() * 0.6)
		flash_points.append(Vector2(cos(angle), sin(angle)) * r)
	flash.polygon = PackedVector2Array(flash_points)
	flash.color = Color(0.8, 0.95, 1.0, 0.95)
	add_child(flash)

	var flash_tween = create_tween()
	flash_tween.set_parallel(true)
	flash_tween.tween_property(flash, "scale", Vector2(1.5, 1.5), 0.12)
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.15)

	# EMP shockwave rings
	for ring_i in range(2):
		var ring = Line2D.new()
		ring.position = pos
		ring.width = 4.0 + charge_count - ring_i * 2
		ring.default_color = Color(0.5, 0.85, 1.0, 0.7 - ring_i * 0.2)
		var ring_points = []
		for i in range(25):
			var angle = i * (TAU / 24)
			ring_points.append(Vector2(cos(angle), sin(angle)) * 10)
		ring.points = PackedVector2Array(ring_points)
		add_child(ring)

		var ring_tween = create_tween()
		ring_tween.set_parallel(true)
		ring_tween.tween_property(ring, "scale", Vector2(4 + ring_i * 2, 4 + ring_i * 2), 0.25 + ring_i * 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ring_tween.tween_property(ring, "modulate:a", 0.0, 0.25 + ring_i * 0.1)

	# Main electric sparks
	var spark_count = 10 + charge_count * 3
	for i in range(spark_count):
		var angle = (float(i) / spark_count) * TAU + randf_range(-0.3, 0.3)
		var length = randf_range(30, 70) + charge_count * 12

		# Outer glow spark
		var glow_spark = Line2D.new()
		glow_spark.width = 6.0 + charge_count
		glow_spark.default_color = Color(0.3, 0.6, 1.0, 0.3)
		glow_spark.add_point(pos)
		glow_spark.add_point(pos + Vector2(cos(angle), sin(angle)) * length)
		add_child(glow_spark)

		# Main spark
		var spark = Line2D.new()
		spark.width = 2.5 + charge_count * 0.5
		spark.default_color = Color(0.6, 0.92, 1.0, 0.9)
		spark.add_point(pos)
		spark.add_point(pos + Vector2(cos(angle), sin(angle)) * length)
		add_child(spark)

		# Hot core spark
		var core_spark = Line2D.new()
		core_spark.width = 1.0
		core_spark.default_color = Color(0.95, 0.98, 1.0, 0.95)
		core_spark.add_point(pos)
		core_spark.add_point(pos + Vector2(cos(angle), sin(angle)) * length * 0.8)
		add_child(core_spark)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(glow_spark, "modulate:a", 0.0, 0.15 + randf() * 0.1)
		tween.tween_property(spark, "modulate:a", 0.0, 0.2 + randf() * 0.15)
		tween.tween_property(core_spark, "modulate:a", 0.0, 0.25 + randf() * 0.1)

	# Residual static - lingering electricity
	var static_count = 4 + charge_count
	for i in range(static_count):
		var angle = randf() * TAU
		var dist = randf_range(15, 40)
		var start = pos + Vector2(cos(angle), sin(angle)) * dist
		var end_angle = angle + randf_range(-1.0, 1.0)
		var end = start + Vector2(cos(end_angle), sin(end_angle)) * randf_range(10, 25)

		var static_arc = _create_jagged_line(start, end, 1.5, 3)
		static_arc.default_color = Color(0.5, 0.85, 1.0, 0.6)
		add_child(static_arc)

		var static_tween = create_tween()
		static_tween.tween_interval(randf() * 0.3)
		static_tween.tween_property(static_arc, "modulate:a", 0.0, 0.2)


# =============================================================================
# ENEMY: HELLSTORM - Orbital bombardment raining fire from above
# =============================================================================

func _fire_hellstorm():
	var state = store.get_state()
	var max_range = _get_scaled_range()
	var scaled_damage = _get_scaled_damage()

	# Find target cluster
	var target_center = _find_enemy_cluster_in_range(state, max_range)
	if target_center == Vector2.ZERO:
		queue_free()
		return

	var local_target = target_center - base_position

	# Number of impacts scales with charges
	var impact_count = 4 + charge_count * 3  # 7 to 19 impacts
	var spread_radius = 80.0 + charge_count * 30.0  # How spread out the bombardment is
	var damage_per_impact = scaled_damage / impact_count * 2.5

	# Screen shake - massive for bombardment
	var shake_intensity = 30.0 + charge_count * 20.0
	_shake_screen(shake_intensity)

	# Warning effect - target zone
	if charge_count >= 2:
		await _hellstorm_warning(local_target, spread_radius)

	# Rain down the bombardment
	var hit_ships = {}
	for i in range(impact_count):
		var delay = i * 0.08 + randf() * 0.05
		var offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf() * spread_radius
		var impact_pos = local_target + offset
		_spawn_hellstorm_meteor(impact_pos, delay, damage_per_impact, hit_ships, state)

	# Cleanup after bombardment
	await get_tree().create_timer(2.5).timeout
	queue_free()


func _hellstorm_warning(target: Vector2, radius: float):
	# Play warning sound
	if vnp_main and vnp_main.sound_manager:
		vnp_main.sound_manager.play_hellstorm_warning()

	# Pulsing target zone warning
	var warning_ring = Line2D.new()
	warning_ring.width = 3.0
	warning_ring.default_color = Color(1.0, 0.4, 0.1, 0.6)
	var ring_points = []
	for i in range(33):
		var angle = i * (TAU / 32)
		ring_points.append(target + Vector2(cos(angle), sin(angle)) * radius)
	warning_ring.points = PackedVector2Array(ring_points)
	add_child(warning_ring)

	# Pulse animation
	var tween = create_tween()
	tween.set_loops(2)
	tween.tween_property(warning_ring, "modulate:a", 0.2, 0.15)
	tween.tween_property(warning_ring, "modulate:a", 0.8, 0.15)
	await tween.finished
	warning_ring.queue_free()


func _spawn_hellstorm_meteor(impact_pos: Vector2, delay: float, damage: float, hit_ships: Dictionary, state: Dictionary):
	await get_tree().create_timer(delay).timeout

	# SPECTACULAR METEOR - Multi-layered falling destruction

	# Meteor trail from "above" (off-screen)
	var trail_start = impact_pos + Vector2(randf_range(-100, 100), -500 - charge_count * 50)
	var meteor = Node2D.new()
	meteor.position = trail_start
	add_child(meteor)

	# Outer corona glow
	var corona = Polygon2D.new()
	var corona_size = 25.0 + charge_count * 8
	var corona_points = []
	for i in range(12):
		var angle = i * (TAU / 12)
		var r = corona_size * (0.8 + randf() * 0.4)
		corona_points.append(Vector2(cos(angle), sin(angle)) * r)
	corona.polygon = PackedVector2Array(corona_points)
	corona.color = Color(1.0, 0.4, 0.1, 0.3)
	meteor.add_child(corona)

	# Meteor body - fiery rock with more detail
	var body = Polygon2D.new()
	var size = 12.0 + charge_count * 3
	body.polygon = PackedVector2Array([
		Vector2(-size, -size*0.4), Vector2(-size*0.6, -size),
		Vector2(size*0.3, -size*0.9), Vector2(size, -size*0.3),
		Vector2(size*0.8, size*0.6), Vector2(0, size*0.7),
		Vector2(-size*0.8, size*0.5)
	])
	body.color = Color(1.0, 0.6, 0.15)
	meteor.add_child(body)

	# Inner hot core - white hot
	var core = Polygon2D.new()
	core.polygon = PackedVector2Array([
		Vector2(-size*0.4, -size*0.2), Vector2(0, -size*0.5),
		Vector2(size*0.4, -size*0.2), Vector2(size*0.3, size*0.3),
		Vector2(-size*0.3, size*0.3)
	])
	core.color = Color(1.0, 1.0, 0.9, 0.95)
	meteor.add_child(core)

	# Main fire trail - gradient
	var trail = Line2D.new()
	trail.width = size * 2.5
	trail.gradient = Gradient.new()
	trail.gradient.set_color(0, Color(1.0, 0.8, 0.3, 0.9))
	trail.gradient.add_point(0.5, Color(1.0, 0.4, 0.1, 0.6))
	trail.gradient.add_point(1.0, Color(0.8, 0.2, 0.0, 0.0))
	trail.add_point(Vector2.ZERO)
	trail.add_point(Vector2(0, 120 + charge_count * 30))
	meteor.add_child(trail)

	# Outer glow trail
	var glow_trail = Line2D.new()
	glow_trail.width = size * 5
	glow_trail.gradient = Gradient.new()
	glow_trail.gradient.set_color(0, Color(1.0, 0.3, 0.0, 0.35))
	glow_trail.gradient.add_point(1.0, Color(0.5, 0.1, 0.0, 0.0))
	glow_trail.add_point(Vector2.ZERO)
	glow_trail.add_point(Vector2(0, 180 + charge_count * 40))
	glow_trail.z_index = -1
	meteor.add_child(glow_trail)

	# Smoke trail
	var smoke_trail = Line2D.new()
	smoke_trail.width = size * 4
	smoke_trail.gradient = Gradient.new()
	smoke_trail.gradient.set_color(0, Color(0.3, 0.3, 0.3, 0.0))
	smoke_trail.gradient.add_point(0.3, Color(0.2, 0.2, 0.2, 0.4))
	smoke_trail.gradient.add_point(1.0, Color(0.1, 0.1, 0.1, 0.0))
	smoke_trail.add_point(Vector2(0, 50))
	smoke_trail.add_point(Vector2(randf_range(-20, 20), 200 + charge_count * 50))
	smoke_trail.z_index = -2
	meteor.add_child(smoke_trail)

	# Trailing debris/sparks
	var debris_count = 4 + charge_count
	for i in range(debris_count):
		var debris = Polygon2D.new()
		var d_size = randf_range(2, 4)
		debris.polygon = PackedVector2Array([
			Vector2(-d_size, 0), Vector2(0, -d_size), Vector2(d_size, 0), Vector2(0, d_size)
		])
		debris.color = Color(1.0, 0.7, 0.2, 0.8)
		debris.position = Vector2(randf_range(-size, size), randf_range(20, 80))
		meteor.add_child(debris)

	# Animate meteor falling
	var fall_time = 0.3 + randf() * 0.1
	var tween = create_tween()
	tween.tween_property(meteor, "position", impact_pos, fall_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished

	# IMPACT!
	meteor.queue_free()
	_spawn_hellstorm_impact(impact_pos)

	# Deal damage to nearby ships
	var impact_radius = 60.0 + charge_count * 10
	var world_impact = base_position + impact_pos
	for ship_id in state.ships:
		var ship_data = state.ships[ship_id]
		if ship_data.team != team:
			# Get real position from ship node (state may be stale)
			var ship_pos = ship_data.position
			if vnp_main and vnp_main.ship_nodes.has(ship_id):
				var ship_node = vnp_main.ship_nodes[ship_id]
				if is_instance_valid(ship_node):
					ship_pos = ship_node.global_position
			var dist = ship_pos.distance_to(world_impact)
			if dist < impact_radius:
				var falloff = 1.0 - (dist / impact_radius) * 0.5
				store.dispatch({
					"type": "DAMAGE_SHIP",
					"ship_id": ship_id,
					"damage": damage * falloff
				})

	# Small screen shake per impact
	_shake_screen(8.0 + charge_count * 2)


func _spawn_hellstorm_impact(pos: Vector2):
	# SPECTACULAR IMPACT - Multi-layer fiery explosion with ground fire

	# Initial blinding flash
	var initial_flash = Polygon2D.new()
	initial_flash.position = pos
	initial_flash.polygon = PackedVector2Array([
		Vector2(-60, 0), Vector2(0, -60), Vector2(60, 0), Vector2(0, 60)
	])
	initial_flash.color = Color(1.0, 1.0, 0.95, 0.98)
	initial_flash.scale = Vector2(0.5, 0.5)
	add_child(initial_flash)

	var init_tween = create_tween()
	init_tween.set_parallel(true)
	init_tween.tween_property(initial_flash, "scale", Vector2(2.0 + charge_count * 0.3, 2.0 + charge_count * 0.3), 0.08)
	init_tween.tween_property(initial_flash, "modulate:a", 0.0, 0.1)

	# Explosion fireball
	var flash = Polygon2D.new()
	flash.position = pos
	var flash_size = 40.0 + charge_count * 12
	var flash_points = []
	for i in range(16):
		var angle = i * (TAU / 16)
		var r = flash_size * (0.7 + randf() * 0.6)
		flash_points.append(Vector2(cos(angle), sin(angle)) * r)
	flash.polygon = PackedVector2Array(flash_points)
	flash.color = Color(1.0, 0.85, 0.4, 0.95)
	add_child(flash)

	# Inner fire core
	var fire_core = Polygon2D.new()
	fire_core.position = pos
	var core_size = flash_size * 0.6
	var core_points = []
	for i in range(12):
		var angle = i * (TAU / 12)
		var r = core_size * (0.8 + randf() * 0.4)
		core_points.append(Vector2(cos(angle), sin(angle)) * r)
	fire_core.polygon = PackedVector2Array(core_points)
	fire_core.color = Color(1.0, 0.95, 0.85, 0.9)
	add_child(fire_core)

	# Multiple expanding shockwave rings
	for ring_i in range(3):
		var ring = Line2D.new()
		ring.position = pos
		ring.width = (5.0 + charge_count * 2) - ring_i * 1.5
		ring.default_color = Color(1.0, 0.5 + ring_i * 0.1, 0.1, 0.85 - ring_i * 0.15)
		var ring_points = []
		for i in range(33):
			var angle = i * (TAU / 32)
			ring_points.append(Vector2(cos(angle), sin(angle)) * (15 + ring_i * 5))
		ring.points = PackedVector2Array(ring_points)
		add_child(ring)

		var ring_tween = create_tween()
		ring_tween.set_parallel(true)
		var ring_scale = (5.0 - ring_i * 0.8) + charge_count * 0.5
		ring_tween.tween_property(ring, "scale", Vector2(ring_scale, ring_scale), 0.35 + ring_i * 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ring_tween.tween_property(ring, "modulate:a", 0.0, 0.4 + ring_i * 0.1)

	# Fire jets spreading outward
	var fire_count = 12 + charge_count * 3
	for i in range(fire_count):
		var angle = (float(i) / fire_count) * TAU + randf_range(-0.15, 0.15)
		var length = randf_range(50, 100) + charge_count * 15

		# Outer glow
		var glow_line = Line2D.new()
		glow_line.width = 12.0 + charge_count * 2
		glow_line.gradient = Gradient.new()
		glow_line.gradient.set_color(0, Color(1.0, 0.5, 0.1, 0.4))
		glow_line.gradient.add_point(1.0, Color(0.8, 0.2, 0.0, 0.0))
		glow_line.add_point(pos)
		glow_line.add_point(pos + Vector2(cos(angle), sin(angle)) * length * 1.2)
		add_child(glow_line)

		# Main fire jet
		var fire_line = Line2D.new()
		fire_line.width = 6.0 + charge_count
		fire_line.gradient = Gradient.new()
		fire_line.gradient.set_color(0, Color(1.0, 0.9, 0.4, 0.95))
		fire_line.gradient.add_point(0.3, Color(1.0, 0.6, 0.1, 0.8))
		fire_line.gradient.add_point(1.0, Color(1.0, 0.3, 0.0, 0.0))
		fire_line.add_point(pos)
		fire_line.add_point(pos + Vector2(cos(angle), sin(angle)) * length)
		add_child(fire_line)

		var fire_tween = create_tween()
		fire_tween.set_parallel(true)
		fire_tween.tween_property(glow_line, "modulate:a", 0.0, 0.3 + randf() * 0.15)
		fire_tween.tween_property(fire_line, "modulate:a", 0.0, 0.4 + randf() * 0.2)

	# Flying debris
	var debris_count = 8 + charge_count * 2
	for i in range(debris_count):
		var angle = randf() * TAU
		var debris = Polygon2D.new()
		var d_size = randf_range(3, 6)
		debris.polygon = PackedVector2Array([
			Vector2(-d_size, -d_size*0.5), Vector2(d_size*0.5, -d_size),
			Vector2(d_size, d_size*0.3), Vector2(-d_size*0.3, d_size)
		])
		debris.color = Color(0.4, 0.35, 0.3, 0.9)
		debris.position = pos
		add_child(debris)

		var fly_dist = randf_range(60, 120) + charge_count * 15
		var debris_tween = create_tween()
		debris_tween.set_parallel(true)
		debris_tween.tween_property(debris, "position", pos + Vector2(cos(angle), sin(angle)) * fly_dist, 0.5 + randf() * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		debris_tween.tween_property(debris, "rotation", randf() * TAU * 2, 0.6)
		debris_tween.tween_property(debris, "modulate:a", 0.0, 0.6 + randf() * 0.2)

	# Lingering ground fire
	var ground_fire_count = 3 + charge_count
	for i in range(ground_fire_count):
		var offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
		var flame = Polygon2D.new()
		flame.position = pos + offset
		var f_size = randf_range(8, 15)
		flame.polygon = PackedVector2Array([
			Vector2(-f_size*0.6, f_size*0.3), Vector2(-f_size*0.3, -f_size),
			Vector2(f_size*0.2, -f_size*0.8), Vector2(f_size*0.5, f_size*0.3)
		])
		flame.color = Color(1.0, 0.6, 0.1, 0.7)
		add_child(flame)

		var flame_tween = create_tween()
		flame_tween.set_loops(2)
		flame_tween.tween_property(flame, "scale", Vector2(1.3, 1.5), 0.15)
		flame_tween.tween_property(flame, "scale", Vector2(0.8, 1.2), 0.15)

		var fade_tween = create_tween()
		fade_tween.tween_interval(0.5)
		fade_tween.tween_property(flame, "modulate:a", 0.0, 0.4)

	# Smoke plume
	var smoke = Polygon2D.new()
	smoke.position = pos + Vector2(0, -10)
	var smoke_points = []
	for i in range(8):
		var angle = i * (TAU / 8)
		smoke_points.append(Vector2(cos(angle), sin(angle)) * 20)
	smoke.polygon = PackedVector2Array(smoke_points)
	smoke.color = Color(0.2, 0.2, 0.2, 0.5)
	smoke.z_index = -1
	add_child(smoke)

	var smoke_tween = create_tween()
	smoke_tween.set_parallel(true)
	smoke_tween.tween_property(smoke, "scale", Vector2(3.0, 4.0), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	smoke_tween.tween_property(smoke, "position", pos + Vector2(randf_range(-20, 20), -80), 1.0)
	smoke_tween.tween_property(smoke, "modulate:a", 0.0, 1.2)

	# Animate main flash and core
	var impact_tween = create_tween()
	impact_tween.set_parallel(true)
	impact_tween.tween_property(flash, "scale", Vector2(1.8, 1.8), 0.2)
	impact_tween.tween_property(flash, "modulate:a", 0.0, 0.25)
	impact_tween.tween_property(fire_core, "scale", Vector2(1.5, 1.5), 0.15)
	impact_tween.tween_property(fire_core, "modulate:a", 0.0, 0.2)


# =============================================================================
# NEMESIS: VOID TEAR - Reality rift that pulls enemies in and implodes
# =============================================================================

func _fire_void_tear():
	# Play Void Tear sound
	if vnp_main and vnp_main.sound_manager:
		vnp_main.sound_manager.play_void_tear()

	var state = store.get_state()
	var max_range = _get_scaled_range()
	var scaled_damage = _get_scaled_damage()

	# Find enemy cluster
	var target_center = _find_enemy_cluster_in_range(state, max_range)
	if target_center == Vector2.ZERO:
		queue_free()
		return

	var local_target = target_center - base_position

	# Rift properties scale with charges
	var rift_width = 60.0 + charge_count * 25.0   # Width of the tear
	var rift_height = 120.0 + charge_count * 40.0  # Height of the tear
	var pull_radius = 150.0 + charge_count * 40.0  # How far the pull reaches
	var damage_radius = 100.0 + charge_count * 35.0

	# Screen shake
	var shake_intensity = 25.0 + charge_count * 18.0
	_shake_screen(shake_intensity)

	# Pre-tear warning - reality starting to crack
	if charge_count >= 2:
		await _void_tear_warning(local_target)

	# Create the rift visuals
	var rift_container = Node2D.new()
	rift_container.position = local_target
	add_child(rift_container)

	# The tear itself - jagged edges
	var tear_left = _create_rift_edge(rift_width, rift_height, -1)
	var tear_right = _create_rift_edge(rift_width, rift_height, 1)
	rift_container.add_child(tear_left)
	rift_container.add_child(tear_right)

	# Void center - pure darkness
	var void_center = Polygon2D.new()
	var void_points = []
	for i in range(12):
		var t = float(i) / 12
		var y = (t - 0.5) * rift_height
		var x_mult = 1.0 - abs(t - 0.5) * 2  # Diamond-ish shape
		var x = x_mult * rift_width * 0.3 * (1 if i < 6 else -1)
		void_points.append(Vector2(x, y))
	void_center.polygon = PackedVector2Array(void_points)
	void_center.color = Color(0.02, 0.0, 0.05, 0.98)
	rift_container.add_child(void_center)

	# Swirling void particles being sucked in
	_spawn_void_particles(rift_container, rift_height, pull_radius)

	# Distortion lines showing the pull
	var pull_lines = _create_pull_effect(local_target, pull_radius)

	# Opening animation
	var open_tween = create_tween()
	open_tween.set_parallel(true)
	open_tween.tween_property(rift_container, "scale", Vector2(1, 1), 0.3).from(Vector2(0.1, 0.1)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await open_tween.finished

	# Deal damage over time while rift is open
	var rift_duration = 0.8 + charge_count * 0.2
	var damage_ticks = 3
	var damage_per_tick = scaled_damage / damage_ticks

	for tick in range(damage_ticks):
		await get_tree().create_timer(rift_duration / damage_ticks).timeout
		# Refresh state and damage nearby enemies
		var current_state = store.get_state()
		var world_target = base_position + local_target
		for ship_id in current_state.ships:
			var ship_data = current_state.ships[ship_id]
			if ship_data.team != team:
				# Get real position from ship node (state may be stale)
				var ship_pos = ship_data.position
				if vnp_main and vnp_main.ship_nodes.has(ship_id):
					var ship_node = vnp_main.ship_nodes[ship_id]
					if is_instance_valid(ship_node):
						ship_pos = ship_node.global_position
				var dist = ship_pos.distance_to(world_target)
				if dist < damage_radius:
					var falloff = 1.0 - (dist / damage_radius) * 0.4
					store.dispatch({
						"type": "DAMAGE_SHIP",
						"ship_id": ship_id,
						"damage": damage_per_tick * falloff
					})
		_shake_screen(10.0 + charge_count * 3)

	# IMPLOSION - the rift collapses violently
	await _void_tear_implosion(rift_container, local_target, rift_height, pull_lines)
	queue_free()


func _void_tear_warning(pos: Vector2):
	# SPECTACULAR REALITY BREACH WARNING - Reality cracking and destabilizing

	# Pulsing event horizon warning ring
	var horizon_ring = Line2D.new()
	horizon_ring.width = 3.0
	horizon_ring.default_color = Color(0.5, 0.1, 0.8, 0.6)
	var ring_points = []
	for i in range(33):
		var angle = i * (TAU / 32)
		ring_points.append(pos + Vector2(cos(angle), sin(angle)) * (80 + charge_count * 20))
	horizon_ring.points = PackedVector2Array(ring_points)
	add_child(horizon_ring)

	var horizon_tween = create_tween()
	horizon_tween.set_loops(2)
	horizon_tween.tween_property(horizon_ring, "modulate:a", 0.2, 0.12)
	horizon_tween.tween_property(horizon_ring, "modulate:a", 0.8, 0.12)

	# Reality distortion - stars/particles being stretched toward center
	var distortion_count = 8 + charge_count * 3
	for i in range(distortion_count):
		var angle = randf() * TAU
		var dist = randf_range(100, 180 + charge_count * 30)
		var start = pos + Vector2(cos(angle), sin(angle)) * dist

		# Stretched star being pulled in
		var stretched_star = Line2D.new()
		stretched_star.width = 2.0
		stretched_star.gradient = Gradient.new()
		stretched_star.gradient.set_color(0, Color(0.9, 0.8, 1.0, 0.0))
		stretched_star.gradient.add_point(0.5, Color(0.7, 0.5, 1.0, 0.7))
		stretched_star.gradient.add_point(1.0, Color(0.5, 0.2, 0.9, 0.9))
		stretched_star.add_point(start + Vector2(cos(angle), sin(angle)) * 40)
		stretched_star.add_point(pos + Vector2(cos(angle), sin(angle)) * 30)
		add_child(stretched_star)

		var star_tween = create_tween()
		star_tween.tween_property(stretched_star, "modulate:a", 0.0, 0.4 + randf() * 0.2)

	# Reality cracks with multi-layer glow
	var crack_count = 5 + charge_count * 2
	for i in range(crack_count):
		var angle = randf() * TAU
		var dist = randf_range(40, 100)
		var start = pos + Vector2(cos(angle), sin(angle)) * dist
		var crack_angle = angle + PI + randf_range(-0.6, 0.6)
		var length = randf_range(30, 70) + charge_count * 10
		var end = start + Vector2(cos(crack_angle), sin(crack_angle)) * length

		# Outer glow
		var glow_crack = _create_jagged_line(start, end, 8.0, 5)
		glow_crack.default_color = Color(0.4, 0.0, 0.6, 0.3)
		add_child(glow_crack)

		# Main crack
		var crack = _create_jagged_line(start, end, 3.0, 6)
		crack.default_color = Color(0.7, 0.2, 1.0, 0.9)
		add_child(crack)

		# Hot core
		var core_crack = _create_jagged_line(start, end, 1.0, 6)
		core_crack.default_color = Color(0.95, 0.7, 1.0, 0.95)
		add_child(core_crack)

		var delay = randf() * 0.15
		var tween = create_tween()
		tween.tween_interval(delay)
		tween.set_parallel(true)
		tween.tween_property(glow_crack, "modulate:a", 0.0, 0.25)
		tween.tween_property(crack, "modulate:a", 0.0, 0.3)
		tween.tween_property(core_crack, "modulate:a", 0.0, 0.35)

	# Cleanup warning ring after loops complete
	var cleanup_tween = create_tween()
	cleanup_tween.tween_interval(0.5)
	cleanup_tween.tween_callback(horizon_ring.queue_free)

	await get_tree().create_timer(0.4).timeout


func _create_rift_edge(width: float, height: float, side: int) -> Line2D:
	# Create jagged glowing edge of the rift
	var edge = Line2D.new()
	edge.width = 6.0 + charge_count * 2
	edge.default_color = Color(0.7, 0.2, 1.0, 0.9)
	edge.antialiased = true

	var segments = 10 + charge_count * 2
	for i in range(segments + 1):
		var t = float(i) / segments
		var y = (t - 0.5) * height
		# Edge curves inward at top/bottom, outward in middle
		var x_base = sin(t * PI) * width * 0.4 * side
		var jag = randf_range(-8, 8)
		edge.add_point(Vector2(x_base + jag, y))

	return edge


func _spawn_void_particles(container: Node2D, height: float, radius: float):
	# DENSE particle field spiraling into the void
	var particle_count = 30 + charge_count * 10  # Doubled density

	for i in range(particle_count):
		var angle = randf() * TAU
		var dist = randf_range(radius * 0.3, radius * 1.2)  # Wider range
		var start = Vector2(cos(angle), sin(angle)) * dist

		var particle = Polygon2D.new()
		var size = randf_range(2, 6)

		# Variety of particle shapes
		if randf() < 0.3:
			# Diamond shape
			particle.polygon = PackedVector2Array([
				Vector2(-size, 0), Vector2(0, -size * 1.5),
				Vector2(size, 0), Vector2(0, size * 1.5)
			])
		elif randf() < 0.5:
			# Stretched horizontal
			particle.polygon = PackedVector2Array([
				Vector2(-size * 2, 0), Vector2(0, -size * 0.5),
				Vector2(size * 2, 0), Vector2(0, size * 0.5)
			])
		else:
			# Standard diamond
			particle.polygon = PackedVector2Array([
				Vector2(-size, 0), Vector2(0, -size),
				Vector2(size, 0), Vector2(0, size)
			])

		# Color variation - purples and magentas
		var color_var = randf()
		if color_var < 0.4:
			particle.color = Color(0.6, 0.2, 0.9, randf_range(0.5, 0.9))  # Purple
		elif color_var < 0.7:
			particle.color = Color(0.8, 0.3, 0.8, randf_range(0.4, 0.8))  # Magenta
		else:
			particle.color = Color(0.9, 0.7, 1.0, randf_range(0.3, 0.6))  # Light purple (distant stars)

		particle.position = start
		container.add_child(particle)

		# Spiral inward with rotation
		var spiral_time = randf_range(0.4, 1.4)
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", Vector2(0, randf_range(-height*0.3, height*0.3)), spiral_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(particle, "scale", Vector2(0.05, 0.05), spiral_time)
		tween.tween_property(particle, "rotation", randf_range(-TAU, TAU), spiral_time)
		tween.tween_property(particle, "modulate:a", 0.0, spiral_time)


func _create_pull_effect(center: Vector2, radius: float) -> Array:
	# Lines radiating inward showing gravitational pull
	var lines = []
	var line_count = 8 + charge_count * 2
	for i in range(line_count):
		var angle = (float(i) / line_count) * TAU
		var outer = center + Vector2(cos(angle), sin(angle)) * radius
		var inner = center + Vector2(cos(angle), sin(angle)) * 30

		var line = Line2D.new()
		line.width = 2.0
		line.default_color = Color(0.5, 0.1, 0.7, 0.4)
		line.add_point(outer)
		line.add_point(inner)
		add_child(line)
		lines.append(line)

		# Animate pulsing inward
		var tween = create_tween()
		tween.set_loops(0)
		tween.tween_property(line, "modulate:a", 0.1, 0.3)
		tween.tween_property(line, "modulate:a", 0.6, 0.3)

	return lines


func _void_tear_implosion(container: Node2D, pos: Vector2, height: float, pull_lines: Array):
	# SPECTACULAR REALITY COLLAPSE - Dramatic implosion with reality-shattering aftermath

	# Clean up pull lines
	for line in pull_lines:
		if is_instance_valid(line):
			line.queue_free()

	# Pre-collapse energy surge - rift brightens before collapsing
	var surge_tween = create_tween()
	surge_tween.tween_property(container, "modulate", Color(1.5, 1.5, 2.0, 1.0), 0.1)
	await surge_tween.finished

	# Implosion - everything collapses violently to center
	var collapse_tween = create_tween()
	collapse_tween.set_parallel(true)
	collapse_tween.tween_property(container, "scale", Vector2(0.01, 0.01), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	collapse_tween.tween_property(container, "modulate:a", 0.0, 0.15)
	await collapse_tween.finished
	container.queue_free()

	# Massive screen shake on collapse
	_shake_screen(50.0 + charge_count * 20)

	# SINGULARITY FLASH - brief intense core flash
	var singularity_flash = Polygon2D.new()
	singularity_flash.position = pos
	singularity_flash.polygon = PackedVector2Array([
		Vector2(-30, 0), Vector2(0, -30), Vector2(30, 0), Vector2(0, 30)
	])
	singularity_flash.color = Color(0.95, 0.8, 1.0, 0.98)
	singularity_flash.scale = Vector2(0.1, 0.1)
	add_child(singularity_flash)

	var flash_tween = create_tween()
	flash_tween.set_parallel(true)
	flash_tween.tween_property(singularity_flash, "scale", Vector2(2.0 + charge_count * 0.5, 2.0 + charge_count * 0.5), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	flash_tween.tween_property(singularity_flash, "modulate:a", 0.0, 0.12)

	# Multiple expanding shockwave rings with different colors
	for ring_i in range(4):
		var ring = Line2D.new()
		ring.position = pos
		ring.width = (10.0 + charge_count * 3) - ring_i * 2
		var ring_color = Color(0.8 - ring_i * 0.1, 0.3 + ring_i * 0.1, 1.0, 0.9 - ring_i * 0.15)
		ring.default_color = ring_color
		var wave_points = []
		for i in range(33):
			var angle = i * (TAU / 32)
			wave_points.append(Vector2(cos(angle), sin(angle)) * (5 + ring_i * 3))
		ring.points = PackedVector2Array(wave_points)
		add_child(ring)

		var expand_size = (250.0 + charge_count * 60) - ring_i * 30
		var ring_tween = create_tween()
		ring_tween.set_parallel(true)
		ring_tween.tween_property(ring, "scale", Vector2(expand_size/5, expand_size/5), 0.4 + ring_i * 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ring_tween.tween_property(ring, "modulate:a", 0.0, 0.45 + ring_i * 0.1)

	# Residual void energy sparks - multi-layered
	var spark_count = 16 + charge_count * 5
	for i in range(spark_count):
		var angle = randf() * TAU
		var length = randf_range(60, 140) + charge_count * 20

		# Outer glow spark
		var glow_spark = Line2D.new()
		glow_spark.width = 8.0 + charge_count
		glow_spark.gradient = Gradient.new()
		glow_spark.gradient.set_color(0, Color(0.5, 0.2, 0.8, 0.4))
		glow_spark.gradient.add_point(1.0, Color(0.3, 0.1, 0.5, 0.0))
		glow_spark.add_point(pos)
		glow_spark.add_point(pos + Vector2(cos(angle), sin(angle)) * length * 1.2)
		add_child(glow_spark)

		# Main void spark
		var spark = Line2D.new()
		spark.width = 3.0 + charge_count * 0.5
		spark.gradient = Gradient.new()
		spark.gradient.set_color(0, Color(0.8, 0.4, 1.0, 0.9))
		spark.gradient.add_point(1.0, Color(0.5, 0.2, 0.8, 0.0))
		spark.add_point(pos)
		spark.add_point(pos + Vector2(cos(angle), sin(angle)) * length)
		add_child(spark)

		# Core spark
		var core_spark = Line2D.new()
		core_spark.width = 1.0
		core_spark.default_color = Color(0.95, 0.85, 1.0, 0.95)
		core_spark.add_point(pos)
		core_spark.add_point(pos + Vector2(cos(angle), sin(angle)) * length * 0.7)
		add_child(core_spark)

		var spark_tween = create_tween()
		spark_tween.set_parallel(true)
		spark_tween.tween_property(glow_spark, "modulate:a", 0.0, 0.25 + randf() * 0.15)
		spark_tween.tween_property(spark, "modulate:a", 0.0, 0.3 + randf() * 0.2)
		spark_tween.tween_property(core_spark, "modulate:a", 0.0, 0.35 + randf() * 0.15)

	# Reality distortion ripples - space itself warping
	var ripple_count = 3 + charge_count
	for i in range(ripple_count):
		var ripple = Line2D.new()
		ripple.position = pos
		ripple.width = 2.0
		ripple.default_color = Color(0.6, 0.3, 0.9, 0.4)
		var ripple_points = []
		var ripple_segments = 24
		for j in range(ripple_segments + 1):
			var angle = j * (TAU / ripple_segments)
			var wobble = sin(angle * 4 + i * 1.5) * 5
			ripple_points.append(Vector2(cos(angle), sin(angle)) * (20 + wobble))
		ripple.points = PackedVector2Array(ripple_points)
		add_child(ripple)

		var delay = i * 0.08
		var ripple_tween = create_tween()
		ripple_tween.tween_interval(delay)
		ripple_tween.set_parallel(true)
		ripple_tween.tween_property(ripple, "scale", Vector2(8 + charge_count, 8 + charge_count), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		ripple_tween.tween_property(ripple, "modulate:a", 0.0, 0.7)

	# Void residue - lingering dark energy particles
	var residue_count = 6 + charge_count * 2
	for i in range(residue_count):
		var offset = Vector2(randf_range(-40, 40), randf_range(-40, 40))
		var residue = Polygon2D.new()
		residue.position = pos + offset
		var r_size = randf_range(4, 8)
		var r_points = []
		for j in range(6):
			var angle = j * (TAU / 6) + randf() * 0.3
			r_points.append(Vector2(cos(angle), sin(angle)) * r_size * randf_range(0.6, 1.0))
		residue.polygon = PackedVector2Array(r_points)
		residue.color = Color(0.15, 0.05, 0.25, 0.7)
		add_child(residue)

		var res_tween = create_tween()
		res_tween.set_parallel(true)
		res_tween.tween_property(residue, "position", residue.position + Vector2(randf_range(-30, 30), randf_range(-30, 30)), 1.5)
		res_tween.tween_property(residue, "scale", Vector2(0.1, 0.1), 1.5)
		res_tween.tween_property(residue, "modulate:a", 0.0, 1.5)

	await get_tree().create_timer(0.8).timeout


# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

func _find_enemy_cluster_in_range(state, max_range: float) -> Vector2:
	var enemy_positions = []
	for ship_id in state.ships:
		var ship_data = state.ships[ship_id]
		if ship_data.team != team:
			# Get real position from ship node if available (state positions may be stale)
			var ship_pos = ship_data.position  # Fallback
			if vnp_main and vnp_main.ship_nodes.has(ship_id):
				var ship_node = vnp_main.ship_nodes[ship_id]
				if is_instance_valid(ship_node):
					ship_pos = ship_node.global_position
			var dist = ship_pos.distance_to(base_position)
			if dist <= max_range:
				enemy_positions.append(ship_pos)

	if enemy_positions.is_empty():
		return Vector2.ZERO

	var sum = Vector2.ZERO
	for pos in enemy_positions:
		sum += pos
	return sum / enemy_positions.size()


func _create_circle_mesh(radius: float) -> QuadMesh:
	var mesh = QuadMesh.new()
	mesh.size = Vector2(radius * 2, radius * 2)
	return mesh
