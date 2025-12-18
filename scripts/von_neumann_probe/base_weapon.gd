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
	var state = store.get_state()
	var max_range = _get_scaled_range()
	var scaled_damage = _get_scaled_damage()

	# Find all enemies in range
	var enemies_in_range = []
	for ship_id in state.ships:
		var ship = state.ships[ship_id]
		if ship.team != team:
			var dist = ship.position.distance_to(base_position)
			if dist <= max_range:
				enemies_in_range.append({"id": ship_id, "pos": ship.position, "dist": dist})

	if enemies_in_range.is_empty():
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
	# Electricity gathering at base before firing
	var gather_particles = []
	for i in range(8 + charge_count * 2):
		var angle = randf() * TAU
		var dist = randf_range(80, 150)
		var start = Vector2(cos(angle), sin(angle)) * dist
		var spark_line = Line2D.new()
		spark_line.width = 2.0
		spark_line.default_color = Color(0.5, 0.9, 1.0, 0.8)
		spark_line.add_point(start)
		spark_line.add_point(Vector2.ZERO)
		add_child(spark_line)
		gather_particles.append(spark_line)

		var tween = create_tween()
		tween.tween_property(spark_line, "modulate:a", 0.0, 0.25)

	await get_tree().create_timer(0.2).timeout


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
	# Electric burst at impact point
	var spark_count = 6 + charge_count * 2
	for i in range(spark_count):
		var angle = (float(i) / spark_count) * TAU + randf_range(-0.3, 0.3)
		var length = randf_range(20, 50) + charge_count * 8
		var spark = Line2D.new()
		spark.width = 2.0 + charge_count * 0.5
		spark.default_color = Color(0.6, 0.92, 1.0, 0.9)
		spark.add_point(pos)
		spark.add_point(pos + Vector2(cos(angle), sin(angle)) * length)
		add_child(spark)

		var tween = create_tween()
		tween.tween_property(spark, "modulate:a", 0.0, 0.2 + randf() * 0.15)


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

	# Meteor trail from "above" (off-screen)
	var trail_start = impact_pos + Vector2(randf_range(-100, 100), -400)
	var meteor = Node2D.new()
	meteor.position = trail_start
	add_child(meteor)

	# Meteor body - fiery rock
	var body = Polygon2D.new()
	var size = 8.0 + charge_count * 2
	body.polygon = PackedVector2Array([
		Vector2(-size, -size*0.5), Vector2(0, -size),
		Vector2(size, -size*0.5), Vector2(size*0.7, size*0.5),
		Vector2(-size*0.7, size*0.5)
	])
	body.color = Color(1.0, 0.7, 0.2)
	meteor.add_child(body)

	# Inner hot core
	var core = Polygon2D.new()
	core.polygon = PackedVector2Array([
		Vector2(-size*0.5, -size*0.3), Vector2(0, -size*0.6),
		Vector2(size*0.5, -size*0.3), Vector2(size*0.3, size*0.3),
		Vector2(-size*0.3, size*0.3)
	])
	core.color = Color(1.0, 1.0, 0.8)
	meteor.add_child(core)

	# Fire trail
	var trail = Line2D.new()
	trail.width = size * 1.5
	trail.default_color = Color(1.0, 0.5, 0.1, 0.7)
	trail.add_point(Vector2.ZERO)
	trail.add_point(Vector2(0, 80 + charge_count * 20))
	meteor.add_child(trail)

	# Outer glow trail
	var glow_trail = Line2D.new()
	glow_trail.width = size * 3
	glow_trail.default_color = Color(1.0, 0.3, 0.0, 0.25)
	glow_trail.add_point(Vector2.ZERO)
	glow_trail.add_point(Vector2(0, 120 + charge_count * 30))
	glow_trail.z_index = -1
	meteor.add_child(glow_trail)

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
		var ship = state.ships[ship_id]
		if ship.team != team:
			var dist = ship.position.distance_to(world_impact)
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
	# Explosion flash
	var flash = Polygon2D.new()
	flash.position = pos
	var flash_size = 30.0 + charge_count * 10
	var flash_points = []
	for i in range(12):
		var angle = i * (TAU / 12)
		var r = flash_size * (0.8 + randf() * 0.4)
		flash_points.append(Vector2(cos(angle), sin(angle)) * r)
	flash.polygon = PackedVector2Array(flash_points)
	flash.color = Color(1.0, 0.9, 0.5, 0.95)
	add_child(flash)

	# Expanding shockwave ring
	var ring = Line2D.new()
	ring.position = pos
	ring.width = 4.0 + charge_count
	ring.default_color = Color(1.0, 0.5, 0.1, 0.8)
	var ring_points = []
	for i in range(25):
		var angle = i * (TAU / 24)
		ring_points.append(Vector2(cos(angle), sin(angle)) * 15)
	ring.points = PackedVector2Array(ring_points)
	add_child(ring)

	# Fire particles spreading outward
	var fire_count = 8 + charge_count * 2
	for i in range(fire_count):
		var angle = (float(i) / fire_count) * TAU + randf_range(-0.2, 0.2)
		var fire_line = Line2D.new()
		fire_line.width = 6.0 + charge_count
		var start_color = Color(1.0, 0.8, 0.2, 0.9)
		var end_color = Color(1.0, 0.3, 0.0, 0.3)
		fire_line.gradient = Gradient.new()
		fire_line.gradient.set_color(0, start_color)
		fire_line.gradient.add_point(1.0, end_color)
		var length = randf_range(30, 70) + charge_count * 10
		fire_line.add_point(pos)
		fire_line.add_point(pos + Vector2(cos(angle), sin(angle)) * length)
		add_child(fire_line)

		var fire_tween = create_tween()
		fire_tween.tween_property(fire_line, "modulate:a", 0.0, 0.4 + randf() * 0.2)

	# Animate flash and ring
	var impact_tween = create_tween()
	impact_tween.set_parallel(true)
	impact_tween.tween_property(flash, "scale", Vector2(1.5, 1.5), 0.15)
	impact_tween.tween_property(flash, "modulate:a", 0.0, 0.2)
	impact_tween.tween_property(ring, "scale", Vector2(4.0, 4.0), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	impact_tween.tween_property(ring, "modulate:a", 0.0, 0.4)


# =============================================================================
# NEMESIS: VOID TEAR - Reality rift that pulls enemies in and implodes
# =============================================================================

func _fire_void_tear():
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
			var ship = current_state.ships[ship_id]
			if ship.team != team:
				var dist = ship.position.distance_to(world_target)
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
	# Reality cracks appearing before the tear opens
	var crack_count = 3 + charge_count
	for i in range(crack_count):
		var angle = randf() * TAU
		var dist = randf_range(30, 80)
		var start = pos + Vector2(cos(angle), sin(angle)) * dist
		var crack_angle = angle + PI + randf_range(-0.5, 0.5)
		var length = randf_range(20, 50)
		var end = start + Vector2(cos(crack_angle), sin(crack_angle)) * length

		var crack = _create_jagged_line(start, end, 2.0, 4)
		crack.default_color = Color(0.6, 0.1, 0.9, 0.8)
		add_child(crack)

		var tween = create_tween()
		tween.tween_property(crack, "modulate:a", 0.0, 0.3)

	await get_tree().create_timer(0.25).timeout


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
	# Particles spiraling into the void
	var particle_count = 15 + charge_count * 5
	for i in range(particle_count):
		var angle = randf() * TAU
		var dist = randf_range(radius * 0.5, radius)
		var start = Vector2(cos(angle), sin(angle)) * dist

		var particle = Polygon2D.new()
		var size = randf_range(2, 5)
		particle.polygon = PackedVector2Array([
			Vector2(-size, 0), Vector2(0, -size), Vector2(size, 0), Vector2(0, size)
		])
		particle.color = Color(0.6, 0.2, 0.9, randf_range(0.4, 0.8))
		particle.position = start
		container.add_child(particle)

		# Spiral inward
		var spiral_time = randf_range(0.5, 1.2)
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", Vector2(0, randf_range(-height*0.3, height*0.3)), spiral_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(particle, "scale", Vector2(0.1, 0.1), spiral_time)
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
	# Clean up pull lines
	for line in pull_lines:
		if is_instance_valid(line):
			line.queue_free()

	# Implosion - everything collapses to center
	var collapse_tween = create_tween()
	collapse_tween.tween_property(container, "scale", Vector2(0.01, 0.01), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await collapse_tween.finished
	container.queue_free()

	# Massive screen shake
	_shake_screen(40.0 + charge_count * 15)

	# Reverse shockwave - expanding from nothing
	var shockwave = Line2D.new()
	shockwave.position = pos
	shockwave.width = 8.0 + charge_count * 3
	shockwave.default_color = Color(0.8, 0.3, 1.0, 0.9)
	var wave_points = []
	for i in range(33):
		var angle = i * (TAU / 32)
		wave_points.append(Vector2(cos(angle), sin(angle)) * 5)
	shockwave.points = PackedVector2Array(wave_points)
	add_child(shockwave)

	# Inner shockwave
	var inner_wave = Line2D.new()
	inner_wave.position = pos
	inner_wave.width = 4.0 + charge_count
	inner_wave.default_color = Color(0.95, 0.8, 1.0, 0.8)
	inner_wave.points = PackedVector2Array(wave_points)
	add_child(inner_wave)

	# Residual void sparks
	var spark_count = 10 + charge_count * 4
	for i in range(spark_count):
		var angle = randf() * TAU
		var length = randf_range(40, 100) + charge_count * 15
		var spark = Line2D.new()
		spark.width = 2.0 + charge_count * 0.5
		spark.default_color = Color(0.7, 0.3, 1.0, 0.8)
		spark.add_point(pos)
		spark.add_point(pos + Vector2(cos(angle), sin(angle)) * length)
		add_child(spark)

		var spark_tween = create_tween()
		spark_tween.tween_property(spark, "modulate:a", 0.0, 0.3 + randf() * 0.2)

	# Expand shockwaves
	var expand_size = 200.0 + charge_count * 50
	var wave_tween = create_tween()
	wave_tween.set_parallel(true)
	wave_tween.tween_property(shockwave, "scale", Vector2(expand_size/5, expand_size/5), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	wave_tween.tween_property(shockwave, "modulate:a", 0.0, 0.5)
	wave_tween.tween_property(inner_wave, "scale", Vector2(expand_size/7, expand_size/7), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	wave_tween.tween_property(inner_wave, "modulate:a", 0.0, 0.4)
	await wave_tween.finished


# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

func _find_enemy_cluster_in_range(state, max_range: float) -> Vector2:
	var enemy_positions = []
	for ship_id in state.ships:
		var ship = state.ships[ship_id]
		if ship.team != team:
			var dist = ship.position.distance_to(base_position)
			if dist <= max_range:
				enemy_positions.append(ship.position)

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
