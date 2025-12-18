extends Node2D

const VnpTypes = preload("res://scripts/von_neumann_probe/vnp_types.gd")

var store = null
var team: int = -1
var weapon_type: int = -1
var base_position: Vector2 = Vector2.ZERO
var charge_count: int = 1  # Number of charges fired (1-5)

# Visual elements
var beam_line: Line2D = null
var particles: GPUParticles2D = null

# Charge scaling constants
const BASE_RANGE = 350.0       # x1 range - close/desperation
const MAX_RANGE = 1400.0       # x5 range - reaches center and beyond
const BASE_DAMAGE = 80.0       # x1 damage
const DAMAGE_PER_CHARGE = 40.0 # Additional damage per charge

func init(vnp_store, firing_team: int, from_pos: Vector2, charges: int = 1):
	self.store = vnp_store
	self.team = firing_team
	self.base_position = from_pos
	self.charge_count = clampi(charges, 1, 5)
	self.weapon_type = VnpTypes.BASE_WEAPONS[team]
	self.position = from_pos

	match weapon_type:
		VnpTypes.BaseWeapon.ION_CANNON:
			_fire_ion_cannon()
		VnpTypes.BaseWeapon.MISSILE_BARRAGE:
			_fire_missile_barrage()
		VnpTypes.BaseWeapon.SINGULARITY:
			_fire_singularity()


func _get_scaled_range() -> float:
	# Range scales from BASE_RANGE (x1) to MAX_RANGE (x5)
	var t = (charge_count - 1) / 4.0  # 0.0 to 1.0
	return lerp(BASE_RANGE, MAX_RANGE, t)


func _get_scaled_damage() -> float:
	return BASE_DAMAGE + (charge_count - 1) * DAMAGE_PER_CHARGE

func _fire_ion_cannon():
	# Beam weapon that damages all enemies in a line toward nearest enemy cluster
	# SCALES WITH CHARGES: x1 = short desperate burst, x5 = massive clearing beam
	var state = store.get_state()
	var target_pos = _find_enemy_cluster(state)
	if target_pos == Vector2.ZERO:
		queue_free()
		return

	var direction = (target_pos - base_position).normalized()
	var beam_length = _get_scaled_range()
	var end_pos = base_position + direction * beam_length
	var scaled_damage = _get_scaled_damage()

	# Visual scaling based on charges - MORE CHARGES = MORE SPECTACULAR
	var beam_width = 15.0 + charge_count * 8.0        # 23 to 55
	var glow_width = 30.0 + charge_count * 20.0       # 50 to 130
	var hitbox_width = 25.0 + charge_count * 10.0     # 35 to 75
	var shake_intensity = 15.0 + charge_count * 12.0  # 27 to 75

	# Pre-fire charge-up effect for higher charges
	if charge_count >= 3:
		await _show_charge_up_effect(direction, charge_count)

	# Create beam visual - MAIN BEAM
	beam_line = Line2D.new()
	beam_line.width = beam_width
	beam_line.default_color = Color(0.3, 0.8, 1.0, 0.95)  # Cyan ion beam
	beam_line.add_point(Vector2.ZERO)
	beam_line.add_point(end_pos - base_position)
	beam_line.antialiased = true
	add_child(beam_line)

	# Add glow effect - scales dramatically with charges
	var glow_beam = Line2D.new()
	glow_beam.width = glow_width
	glow_beam.default_color = Color(0.5, 0.9, 1.0, 0.25 + charge_count * 0.05)
	glow_beam.add_point(Vector2.ZERO)
	glow_beam.add_point(end_pos - base_position)
	add_child(glow_beam)

	# For high charges, add a CORE beam (white hot center)
	if charge_count >= 2:
		var core_beam = Line2D.new()
		core_beam.width = beam_width * 0.4
		core_beam.default_color = Color(0.9, 0.95, 1.0, 0.9)  # White-hot core
		core_beam.add_point(Vector2.ZERO)
		core_beam.add_point(end_pos - base_position)
		add_child(core_beam)

	# Add particle spray along beam for x3+
	if charge_count >= 3:
		_spawn_beam_particles(direction, beam_length)

	# Damage all enemies in the beam path
	for ship_id in state.ships:
		var ship = state.ships[ship_id]
		if ship.team != team:
			var dist_to_line = _point_to_line_distance(ship.position, base_position, end_pos)
			if dist_to_line < hitbox_width:
				store.dispatch({
					"type": "DAMAGE_SHIP",
					"ship_id": ship_id,
					"damage": scaled_damage
				})

	# Animate fade out - longer for bigger beams
	var fade_time = 0.4 + charge_count * 0.15
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(beam_line, "modulate:a", 0.0, fade_time)
	tween.tween_property(glow_beam, "modulate:a", 0.0, fade_time)
	await tween.finished
	queue_free()

	# Screen shake - MASSIVE for x5
	get_tree().root.get_node("VnpMain").shake_screen(shake_intensity)


func _show_charge_up_effect(direction: Vector2, charges: int):
	# Pre-fire charging visual for powerful shots
	var charge_ring = Line2D.new()
	charge_ring.width = 4.0
	charge_ring.default_color = Color(0.3, 0.9, 1.0, 0.8)
	var ring_points = []
	for i in range(33):
		var angle = i * (PI * 2 / 32)
		ring_points.append(Vector2(cos(angle), sin(angle)) * (20 + charges * 5))
	charge_ring.points = PackedVector2Array(ring_points)
	add_child(charge_ring)

	# Expanding ring effect
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(charge_ring, "scale", Vector2(2.5, 2.5), 0.3).from(Vector2(0.5, 0.5))
	tween.tween_property(charge_ring, "modulate:a", 0.0, 0.3)
	await tween.finished
	charge_ring.queue_free()


func _spawn_beam_particles(direction: Vector2, length: float):
	# Spawn particles along the beam path for dramatic effect
	var particle_count = charge_count * 3
	for i in range(particle_count):
		var t = randf()
		var offset_pos = direction * length * t
		var spark = GPUParticles2D.new()
		spark.position = offset_pos
		spark.amount = 15 + charge_count * 5
		spark.lifetime = 0.4
		spark.explosiveness = 0.9
		spark.one_shot = true
		spark.emitting = true

		var mat = ParticleProcessMaterial.new()
		mat.direction = Vector3(0, 0, 0)
		mat.spread = 180.0
		mat.initial_velocity_min = 50.0
		mat.initial_velocity_max = 150.0
		mat.damping_min = 100.0
		mat.damping_max = 200.0
		mat.color = Color(0.4, 0.9, 1.0)
		mat.scale_min = 1.5
		mat.scale_max = 3.0
		spark.process_material = mat
		spark.draw_pass_1 = _create_circle_mesh(2.0)
		add_child(spark)

		# Auto cleanup
		get_tree().create_timer(1.0).timeout.connect(func():
			if is_instance_valid(spark):
				spark.queue_free()
		)

func _fire_missile_barrage():
	# Launch multiple missiles at different targets
	# SCALES WITH CHARGES: x1 = few close missiles, x5 = massive swarm
	var state = store.get_state()
	var max_range = _get_scaled_range()
	var scaled_damage = _get_scaled_damage()
	var enemy_ships = []

	for ship_id in state.ships:
		var ship = state.ships[ship_id]
		if ship.team != team:
			# Only target ships within range
			var dist = ship.position.distance_to(base_position)
			if dist <= max_range:
				enemy_ships.append({"id": ship_id, "pos": ship.position, "dist": dist})

	if enemy_ships.is_empty():
		queue_free()
		return

	# Sort by distance - prioritize closer targets
	enemy_ships.sort_custom(func(a, b): return a.dist < b.dist)

	# Missile count scales with charges: 4 (x1) to 20 (x5)
	var base_missile_count = 4 + charge_count * 4  # 8 to 24
	var missile_count = mini(base_missile_count, enemy_ships.size() * 3)

	# Visual: show targeting lines for high charges
	if charge_count >= 3:
		_show_targeting_overlay(enemy_ships, missile_count)

	for i in range(missile_count):
		var target = enemy_ships[i % enemy_ships.size()]
		var per_missile_damage = scaled_damage / float(missile_count) * 2.0  # Adjusted for salvo
		_spawn_base_missile(target.id, target.pos, i * 0.08, per_missile_damage)

	# Screen shake scales with charges
	var shake_intensity = 10.0 + charge_count * 8.0
	get_tree().root.get_node("VnpMain").shake_screen(shake_intensity)

	# Clean up after missiles launched
	await get_tree().create_timer(2.0).timeout
	queue_free()


func _show_targeting_overlay(targets: Array, count: int):
	# Brief targeting lines to show where missiles will go
	for i in range(mini(count, targets.size())):
		var target = targets[i % targets.size()]
		var line = Line2D.new()
		line.width = 1.5
		line.default_color = Color(1.0, 0.5, 0.2, 0.4)
		line.add_point(Vector2.ZERO)
		line.add_point(target.pos - base_position)
		add_child(line)

		var tween = create_tween()
		tween.tween_property(line, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func(): line.queue_free())

func _spawn_base_missile(target_id: int, target_pos: Vector2, delay: float, damage: float = 30.0):
	await get_tree().create_timer(delay).timeout

	# Create missile visual - size scales slightly with charge
	var missile = Node2D.new()
	missile.position = Vector2.ZERO
	add_child(missile)

	var size_mult = 0.8 + charge_count * 0.15  # 0.95 to 1.55
	var polygon = Polygon2D.new()
	polygon.polygon = PackedVector2Array([
		Vector2(-6, -3) * size_mult, Vector2(6, -3) * size_mult,
		Vector2(10, 0) * size_mult, Vector2(6, 3) * size_mult, Vector2(-6, 3) * size_mult
	])
	polygon.color = Color(1.0, 0.5, 0.2)  # Orange missile
	missile.add_child(polygon)

	# Trail particles - more for higher charges
	var trail = GPUParticles2D.new()
	trail.amount = 15 + charge_count * 5
	trail.lifetime = 0.3 + charge_count * 0.05
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(-1, 0, 0)
	mat.spread = 20.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 60.0
	mat.color = Color(1.0, 0.6, 0.1)
	mat.scale_min = 1.0 + charge_count * 0.2
	mat.scale_max = 2.0 + charge_count * 0.3
	trail.process_material = mat
	trail.draw_pass_1 = _create_circle_mesh(2.0)
	missile.add_child(trail)

	# Animate missile to target
	var state = store.get_state()
	var current_target_pos = target_pos
	if state.ships.has(target_id):
		current_target_pos = state.ships[target_id].position

	missile.look_at(to_global(current_target_pos - base_position))

	# Speed scales slightly - faster for close targets
	var dist = base_position.distance_to(current_target_pos)
	var travel_time = clampf(dist / 600.0, 0.4, 1.2)

	var tween = create_tween()
	tween.tween_property(missile, "position", current_target_pos - base_position, travel_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished

	# Deal damage on impact
	store.dispatch({
		"type": "DAMAGE_SHIP",
		"ship_id": target_id,
		"damage": damage
	})

	missile.queue_free()

func _fire_singularity():
	# Area damage centered on enemy cluster
	# SCALES WITH CHARGES: x1 = small gravity well, x5 = massive black hole
	var state = store.get_state()
	var max_range = _get_scaled_range()
	var scaled_damage = _get_scaled_damage()

	# Find enemy cluster within range
	var target_pos = _find_enemy_cluster_in_range(state, max_range)
	if target_pos == Vector2.ZERO:
		queue_free()
		return

	var local_target = target_pos - base_position

	# Visual and damage scaling
	var particle_count = 60 + charge_count * 30       # 90 to 210
	var emission_radius = 60.0 + charge_count * 25.0  # 85 to 185
	var damage_radius = 100.0 + charge_count * 30.0   # 130 to 250
	var center_size = 20.0 + charge_count * 8.0       # 28 to 60
	var shake_intensity = 25.0 + charge_count * 15.0  # 40 to 100

	# Pre-formation warning for high charges
	if charge_count >= 3:
		await _show_singularity_warning(local_target, charge_count)

	# Create singularity visual - scales dramatically
	particles = GPUParticles2D.new()
	particles.position = local_target
	particles.amount = particle_count
	particles.lifetime = 1.5 + charge_count * 0.2
	particles.explosiveness = 0.7

	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = emission_radius
	mat.direction = Vector3(0, 0, 0)
	mat.gravity = Vector3(0, 0, 0)
	mat.radial_accel_min = -250.0 - charge_count * 30  # Stronger pull
	mat.radial_accel_max = -180.0 - charge_count * 20
	mat.color = Color(0.8, 0.2, 1.0)  # Purple
	mat.scale_min = 2.0 + charge_count * 0.5
	mat.scale_max = 4.0 + charge_count * 1.0

	particles.process_material = mat
	particles.draw_pass_1 = _create_circle_mesh(3.0)
	add_child(particles)
	particles.emitting = true

	# Black hole center - larger for more charges
	var center = Polygon2D.new()
	center.position = local_target
	var center_points = []
	for i in range(24):
		var angle = i * (PI * 2 / 24)
		center_points.append(Vector2(cos(angle), sin(angle)) * center_size)
	center.polygon = PackedVector2Array(center_points)
	center.color = Color(0.05, 0.0, 0.15)
	add_child(center)

	# Event horizon ring for x2+
	if charge_count >= 2:
		var horizon = Line2D.new()
		horizon.width = 3.0 + charge_count
		horizon.default_color = Color(0.6, 0.1, 0.9, 0.7)
		var horizon_points = []
		for i in range(33):
			var angle = i * (PI * 2 / 32)
			horizon_points.append(local_target + Vector2(cos(angle), sin(angle)) * (center_size + 15))
		horizon.points = PackedVector2Array(horizon_points)
		add_child(horizon)

		# Pulsing horizon
		var h_tween = create_tween()
		h_tween.set_loops(3)
		h_tween.tween_property(horizon, "modulate:a", 0.3, 0.3)
		h_tween.tween_property(horizon, "modulate:a", 1.0, 0.3)

	# Damage all enemies in radius
	for ship_id in state.ships:
		var ship = state.ships[ship_id]
		if ship.team != team:
			var dist = ship.position.distance_to(target_pos)
			if dist < damage_radius:
				var damage_multiplier = 1.0 - (dist / damage_radius) * 0.6  # Less falloff
				store.dispatch({
					"type": "DAMAGE_SHIP",
					"ship_id": ship_id,
					"damage": int(scaled_damage * 1.3 * damage_multiplier)
				})

	get_tree().root.get_node("VnpMain").shake_screen(shake_intensity)

	# Animate collapse - more dramatic for higher charges
	var collapse_time = 1.0 + charge_count * 0.2
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(center, "scale", Vector2(0.05, 0.05), collapse_time).from(Vector2(1.5 + charge_count * 0.2, 1.5 + charge_count * 0.2))
	tween.tween_property(particles, "modulate:a", 0.0, collapse_time)
	await tween.finished
	queue_free()


func _show_singularity_warning(pos: Vector2, charges: int):
	# Warning rings converging on target
	for i in range(charges):
		var ring = Line2D.new()
		ring.width = 2.0
		ring.default_color = Color(0.7, 0.2, 0.9, 0.6)
		var ring_points = []
		var radius = 150 + i * 40
		for j in range(33):
			var angle = j * (PI * 2 / 32)
			ring_points.append(pos + Vector2(cos(angle), sin(angle)) * radius)
		ring.points = PackedVector2Array(ring_points)
		add_child(ring)

		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(ring, "scale", Vector2(0.3, 0.3), 0.4).set_delay(i * 0.08)
		tween.tween_property(ring, "modulate:a", 0.0, 0.4).set_delay(i * 0.08)
		tween.tween_callback(func(): ring.queue_free())

	await get_tree().create_timer(0.3).timeout


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

	# Return centroid of enemy positions within range
	var sum = Vector2.ZERO
	for pos in enemy_positions:
		sum += pos
	return sum / enemy_positions.size()

func _find_enemy_cluster(state) -> Vector2:
	var enemy_positions = []
	for ship_id in state.ships:
		var ship = state.ships[ship_id]
		if ship.team != team:
			enemy_positions.append(ship.position)

	if enemy_positions.is_empty():
		return Vector2.ZERO

	# Return centroid of enemy positions
	var sum = Vector2.ZERO
	for pos in enemy_positions:
		sum += pos
	return sum / enemy_positions.size()

func _point_to_line_distance(point: Vector2, line_start: Vector2, line_end: Vector2) -> float:
	var line_vec = line_end - line_start
	var point_vec = point - line_start
	var line_len = line_vec.length()
	var line_unit = line_vec / line_len
	var proj_length = point_vec.dot(line_unit)
	proj_length = clamp(proj_length, 0, line_len)
	var proj_point = line_start + line_unit * proj_length
	return point.distance_to(proj_point)

func _create_circle_mesh(radius: float) -> QuadMesh:
	var mesh = QuadMesh.new()
	mesh.size = Vector2(radius * 2, radius * 2)
	return mesh
