extends Node2D

const VnpTypes = preload("res://scripts/vnp/vnp_types.gd")

var store = null
var team: int = -1
var weapon_type: int = -1
var base_position: Vector2 = Vector2.ZERO

# Visual elements
var beam_line: Line2D = null
var particles: GPUParticles2D = null

func init(vnp_store, firing_team: int, from_pos: Vector2):
	self.store = vnp_store
	self.team = firing_team
	self.base_position = from_pos
	self.weapon_type = VnpTypes.BASE_WEAPONS[team]
	self.position = from_pos

	match weapon_type:
		VnpTypes.BaseWeapon.ION_CANNON:
			_fire_ion_cannon()
		VnpTypes.BaseWeapon.MISSILE_BARRAGE:
			_fire_missile_barrage()
		VnpTypes.BaseWeapon.SINGULARITY:
			_fire_singularity()

func _fire_ion_cannon():
	# Beam weapon that damages all enemies in a line toward nearest enemy cluster
	var state = store.get_state()
	var target_pos = _find_enemy_cluster(state)
	if target_pos == Vector2.ZERO:
		queue_free()
		return

	var direction = (target_pos - base_position).normalized()
	var beam_length = 1200.0
	var end_pos = base_position + direction * beam_length

	# Create beam visual
	beam_line = Line2D.new()
	beam_line.width = 25.0
	beam_line.default_color = Color(0.3, 0.8, 1.0, 0.9)  # Cyan ion beam
	beam_line.add_point(Vector2.ZERO)
	beam_line.add_point(end_pos - base_position)
	add_child(beam_line)

	# Add glow effect
	var glow_beam = Line2D.new()
	glow_beam.width = 50.0
	glow_beam.default_color = Color(0.5, 0.9, 1.0, 0.3)
	glow_beam.add_point(Vector2.ZERO)
	glow_beam.add_point(end_pos - base_position)
	add_child(glow_beam)

	# Damage all enemies in the beam path
	for ship_id in state.ships:
		var ship = state.ships[ship_id]
		if ship.team != team:
			var dist_to_line = _point_to_line_distance(ship.position, base_position, end_pos)
			if dist_to_line < 40:  # Beam width hitbox
				store.dispatch({
					"type": "DAMAGE_SHIP",
					"ship_id": ship_id,
					"damage": VnpTypes.BASE_WEAPON_DAMAGE
				})

	# Animate fade out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(beam_line, "modulate:a", 0.0, 0.5)
	tween.tween_property(glow_beam, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

	# Screen shake
	get_tree().root.get_node("VnpMain").shake_screen(30.0)

func _fire_missile_barrage():
	# Launch multiple missiles at different targets
	var state = store.get_state()
	var enemy_ships = []

	for ship_id in state.ships:
		var ship = state.ships[ship_id]
		if ship.team != team:
			enemy_ships.append({"id": ship_id, "pos": ship.position})

	if enemy_ships.is_empty():
		queue_free()
		return

	# Fire 8 missiles at various targets
	var missile_count = mini(8, enemy_ships.size() * 2)
	for i in range(missile_count):
		var target = enemy_ships[i % enemy_ships.size()]
		_spawn_base_missile(target.id, target.pos, i * 0.1)

	get_tree().root.get_node("VnpMain").shake_screen(20.0)

	# Clean up after missiles launched
	await get_tree().create_timer(1.0).timeout
	queue_free()

func _spawn_base_missile(target_id: int, target_pos: Vector2, delay: float):
	await get_tree().create_timer(delay).timeout

	# Create missile visual
	var missile = Node2D.new()
	missile.position = Vector2.ZERO
	add_child(missile)

	var polygon = Polygon2D.new()
	polygon.polygon = PackedVector2Array([
		Vector2(-6, -3), Vector2(6, -3), Vector2(10, 0), Vector2(6, 3), Vector2(-6, 3)
	])
	polygon.color = Color(1.0, 0.5, 0.2)  # Orange missile
	missile.add_child(polygon)

	# Trail particles
	var trail = GPUParticles2D.new()
	trail.amount = 20
	trail.lifetime = 0.3
	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(-1, 0, 0)
	mat.spread = 20.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 60.0
	mat.color = Color(1.0, 0.6, 0.1)
	trail.process_material = mat
	trail.draw_pass_1 = _create_circle_mesh(2.0)
	missile.add_child(trail)

	# Animate missile to target
	var state = store.get_state()
	var current_target_pos = target_pos
	if state.ships.has(target_id):
		current_target_pos = state.ships[target_id].position

	missile.look_at(to_global(current_target_pos - base_position))

	var tween = create_tween()
	tween.tween_property(missile, "position", current_target_pos - base_position, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished

	# Deal damage on impact
	store.dispatch({
		"type": "DAMAGE_SHIP",
		"ship_id": target_id,
		"damage": VnpTypes.BASE_WEAPON_DAMAGE / 3  # Split damage across missiles
	})

	missile.queue_free()

func _fire_singularity():
	# Area damage centered on enemy cluster
	var state = store.get_state()
	var target_pos = _find_enemy_cluster(state)
	if target_pos == Vector2.ZERO:
		queue_free()
		return

	var local_target = target_pos - base_position

	# Create singularity visual
	particles = GPUParticles2D.new()
	particles.position = local_target
	particles.amount = 100
	particles.lifetime = 1.5
	particles.explosiveness = 0.8

	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 100.0
	mat.direction = Vector3(0, 0, 0)
	mat.gravity = Vector3(0, 0, 0)
	mat.radial_accel_min = -200.0  # Pulled inward
	mat.radial_accel_max = -150.0
	mat.color = Color(0.8, 0.2, 1.0)  # Purple
	mat.scale_min = 2.0
	mat.scale_max = 4.0

	particles.process_material = mat
	particles.draw_pass_1 = _create_circle_mesh(3.0)
	add_child(particles)
	particles.emitting = true

	# Black hole center
	var center = Polygon2D.new()
	center.position = local_target
	var center_points = []
	for i in range(20):
		var angle = i * (PI * 2 / 20)
		center_points.append(Vector2(cos(angle), sin(angle)) * 30)
	center.polygon = PackedVector2Array(center_points)
	center.color = Color(0.1, 0.0, 0.2)
	add_child(center)

	# Damage all enemies in radius
	var damage_radius = 150.0
	for ship_id in state.ships:
		var ship = state.ships[ship_id]
		if ship.team != team:
			var dist = ship.position.distance_to(target_pos)
			if dist < damage_radius:
				var damage_multiplier = 1.0 - (dist / damage_radius)
				store.dispatch({
					"type": "DAMAGE_SHIP",
					"ship_id": ship_id,
					"damage": int(VnpTypes.BASE_WEAPON_DAMAGE * 1.5 * damage_multiplier)
				})

	get_tree().root.get_node("VnpMain").shake_screen(40.0)

	# Animate collapse
	var tween = create_tween()
	tween.tween_property(center, "scale", Vector2(0.1, 0.1), 1.2).from(Vector2(1.5, 1.5))
	tween.tween_callback(queue_free)

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
