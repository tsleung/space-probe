extends Area2D
## Projectile - Handles all projectile types: Railgun, Laser (instant), Missile
## Each type has unique behavior and visuals

const VnpTypes = preload("res://scripts/von_neumann_probe/vnp_types.gd")
const ImpactFxScene = preload("res://scenes/von_neumann_probe/impact_fx.tscn")

# Core properties
var team: int = -1
var weapon_type: int = -1
var damage: float = 0
var target_id: int = -1
var store = null      # Passed via init for dispatch
var vnp_main = null   # Passed via init for screen shake

# Movement
var speed: float = 800
var direction: Vector2 = Vector2.RIGHT
var lifetime: float = 2.0

# Railgun specific
var pierced_ships: Array = []
var max_pierces: int = 3

# Missile specific
var arc_start: Vector2 = Vector2.ZERO
var arc_target: Vector2 = Vector2.ZERO
var arc_peak: Vector2 = Vector2.ZERO
var arc_t: float = 0.0
var explosion_radius: float = 120.0

# Turbolaser specific - slow, big, devastating
var turbolaser_speed: float = 180
var turbolaser_size: float = 12

# State
var is_ready: bool = false

# Trail system (Line2D based)
var trail_line: Line2D = null
var trail_points: Array[Vector2] = []
const MAX_TRAIL_POINTS = 15

# Resource tracking for cleanup (prevents texture leaks)
var _trail_gradient: Gradient = null
var _smoke_material: ParticleProcessMaterial = null
var _glow_material: ParticleProcessMaterial = null


func init(data: Dictionary):
	team = data.get("team", -1)
	weapon_type = data.get("weapon_type", VnpTypes.WeaponType.GUN)
	damage = data.get("damage", 10)
	target_id = data.get("target_id", -1)
	store = data.get("store", null)
	vnp_main = data.get("vnp_main", null)

	var start_pos: Vector2 = data.get("start_position", Vector2.ZERO)
	var start_rot: float = data.get("start_rotation", 0.0)

	global_position = start_pos
	rotation = start_rot
	direction = Vector2.RIGHT.rotated(start_rot)

	# Apply weapon-specific setup
	match weapon_type:
		VnpTypes.WeaponType.GUN:
			_setup_railgun()
		VnpTypes.WeaponType.MISSILE:
			_setup_missile(data)
		VnpTypes.WeaponType.TURBOLASER:
			_setup_turbolaser(data)

	# Apply faction color
	var color = VnpTypes.get_weapon_color(team, weapon_type)
	$Polygon2D.color = color

	# Start lifetime timer
	_start_lifetime_timer()

	# Add missiles to group for PDC targeting
	if weapon_type == VnpTypes.WeaponType.MISSILE:
		add_to_group("missiles")

	is_ready = true


func _setup_railgun():
	speed = 1200
	lifetime = 1.5
	max_pierces = 3

	# Long thin slug shape
	$Polygon2D.polygon = PackedVector2Array([
		Vector2(-12, -2), Vector2(12, -1), Vector2(14, 0), Vector2(12, 1), Vector2(-12, 2)
	])
	_create_line_trail(4.0)


func _setup_missile(data: Dictionary):
	speed = 500  # Faster missiles
	lifetime = 3.5

	# Store arc parameters
	arc_start = global_position
	arc_t = 0.0

	# Get target position
	var store = _get_store()
	if store:
		var state = store.get_state()
		if state.ships.has(target_id):
			arc_target = state.ships[target_id].position
		else:
			arc_target = arc_start + direction * 400
	else:
		arc_target = arc_start + direction * 400

	# Calculate arc peak (perpendicular offset) - use varied arc height
	var arc_height_mult = data.get("arc_height_mult", 0.35)
	var dist = arc_start.distance_to(arc_target)
	var to_target = (arc_target - arc_start).normalized()
	var perp = Vector2(-to_target.y, to_target.x)
	if randf() > 0.5:
		perp = -perp
	arc_peak = (arc_start + arc_target) / 2 + perp * dist * arc_height_mult

	# Thinner, sleeker missile shape
	$Polygon2D.polygon = PackedVector2Array([
		Vector2(-8, -2), Vector2(6, -1.5), Vector2(10, 0),
		Vector2(6, 1.5), Vector2(-8, 2), Vector2(-6, 0)
	])
	$Polygon2D.scale = Vector2(1.0, 1.0)

	# Smaller explosion radius for salvo missiles
	explosion_radius = 80.0

	# Missiles use particle smoke trail instead of line trail
	_create_smoke_trail()


func _setup_turbolaser(data: Dictionary):
	# TURBOLASER: Slow, huge, devastating bolt - Star Destroyer style
	turbolaser_speed = data.get("turbolaser_speed", 180)
	turbolaser_size = data.get("turbolaser_size", 12)
	speed = turbolaser_speed
	lifetime = 4.0  # Long lifetime since slow

	# Big elongated bolt shape
	$Polygon2D.polygon = PackedVector2Array([
		Vector2(-turbolaser_size, -turbolaser_size * 0.4),
		Vector2(turbolaser_size * 0.6, -turbolaser_size * 0.25),
		Vector2(turbolaser_size, 0),
		Vector2(turbolaser_size * 0.6, turbolaser_size * 0.25),
		Vector2(-turbolaser_size, turbolaser_size * 0.4),
	])

	# Make the bolt glow bright
	$Polygon2D.modulate = Color(1.5, 1.5, 1.5, 1.0)  # Overbright

	# Thick bright trail
	_create_line_trail(turbolaser_size * 0.8)

	# Add a trailing glow effect
	_create_turbolaser_glow()


func _create_turbolaser_glow():
	# Particle glow trailing behind the bolt
	var glow = GPUParticles2D.new()
	glow.name = "TurboGlow"
	glow.amount = 30
	glow.lifetime = 0.4
	glow.emitting = true

	_glow_material = ParticleProcessMaterial.new()
	_glow_material.direction = Vector3(-1, 0, 0)
	_glow_material.spread = 20.0
	_glow_material.initial_velocity_min = 20.0
	_glow_material.initial_velocity_max = 50.0
	_glow_material.damping_min = 20.0
	_glow_material.damping_max = 40.0
	_glow_material.scale_min = 2.0
	_glow_material.scale_max = 4.0

	# Bright faction-colored glow
	var turbo_color = VnpTypes.get_weapon_color(team, VnpTypes.WeaponType.TURBOLASER)
	var grad = Gradient.new()
	grad.set_color(0, Color(turbo_color.r * 1.5, turbo_color.g * 1.5, turbo_color.b * 1.5, 0.9))
	grad.set_color(1, Color(turbo_color.r, turbo_color.g, turbo_color.b, 0))
	var tex = GradientTexture1D.new()
	tex.gradient = grad
	_glow_material.color_ramp = tex

	glow.process_material = _glow_material
	var mesh = QuadMesh.new()
	mesh.size = Vector2(8, 8)
	glow.draw_pass_1 = mesh
	glow.position = Vector2(-turbolaser_size, 0)

	add_child(glow)


func _create_line_trail(width: float):
	# Create Line2D-based trail (replaces Trail2D addon)
	trail_line = Line2D.new()
	trail_line.name = "TrailLine"
	trail_line.width = width
	trail_line.antialiased = true
	trail_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	trail_line.z_index = -1

	# Gradient from solid to transparent
	var color = VnpTypes.get_weapon_color(team, weapon_type)
	_trail_gradient = Gradient.new()
	_trail_gradient.set_color(0, Color(color.r, color.g, color.b, 0))  # Tail (old positions)
	_trail_gradient.set_color(1, color)  # Head (current position)
	trail_line.gradient = _trail_gradient

	# Add to scene root so trail stays in world space
	get_tree().root.add_child(trail_line)
	trail_points.clear()


func _update_trail():
	if trail_line == null or not is_instance_valid(trail_line):
		return

	# Add current position
	trail_points.push_back(global_position)

	# Limit trail length
	while trail_points.size() > MAX_TRAIL_POINTS:
		trail_points.pop_front()

	# Update line points
	trail_line.clear_points()
	for point in trail_points:
		trail_line.add_point(point)


func _create_smoke_trail():
	var smoke = GPUParticles2D.new()
	smoke.name = "SmokeTrail"
	smoke.amount = 20  # Fewer particles for sleeker missiles
	smoke.lifetime = 0.4  # Shorter trail
	smoke.emitting = true

	_smoke_material = ParticleProcessMaterial.new()
	_smoke_material.direction = Vector3(-1, 0, 0)
	_smoke_material.spread = 15.0
	_smoke_material.initial_velocity_min = 30.0
	_smoke_material.initial_velocity_max = 60.0
	_smoke_material.gravity = Vector3(0, -10, 0)
	_smoke_material.damping_min = 15.0
	_smoke_material.damping_max = 25.0
	_smoke_material.scale_min = 0.8
	_smoke_material.scale_max = 1.8

	# Use team-colored exhaust
	var exhaust_color = VnpTypes.get_weapon_color(team, VnpTypes.WeaponType.MISSILE)
	var grad = Gradient.new()
	grad.set_color(0, exhaust_color.lightened(0.4))
	grad.add_point(0.3, exhaust_color)
	grad.set_color(1, Color(0.3, 0.3, 0.3, 0.0))
	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = grad
	_smoke_material.color_ramp = grad_tex

	smoke.process_material = _smoke_material
	var mesh = QuadMesh.new()
	mesh.size = Vector2(4, 4)  # Smaller particles
	smoke.draw_pass_1 = mesh
	smoke.position = Vector2(-8, 0)

	add_child(smoke)


func _start_lifetime_timer():
	var timer = Timer.new()
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(_on_lifetime_expired)
	add_child(timer)
	timer.start()


func _on_lifetime_expired():
	if weapon_type == VnpTypes.WeaponType.MISSILE:
		_explode()
	queue_free()


func _ready():
	area_entered.connect(_on_area_entered)


func _physics_process(delta):
	if not is_ready:
		return

	match weapon_type:
		VnpTypes.WeaponType.GUN:
			_move_railgun(delta)
		VnpTypes.WeaponType.MISSILE:
			_move_missile(delta)
		VnpTypes.WeaponType.TURBOLASER:
			_move_turbolaser(delta)

	# Update trail
	_update_trail()


func _exit_tree():
	# Clean up trail when projectile is destroyed
	if trail_line != null and is_instance_valid(trail_line):
		trail_line.gradient = null  # Detach before freeing
		trail_line.queue_free()

	# Free tracked resources to prevent texture leaks
	if _trail_gradient != null:
		_trail_gradient = null
	if _smoke_material != null:
		if _smoke_material.color_ramp != null:
			_smoke_material.color_ramp = null
		_smoke_material = null
	if _glow_material != null:
		if _glow_material.color_ramp != null:
			_glow_material.color_ramp = null
		_glow_material = null


func _move_railgun(delta):
	# Check for graviton deflection
	if _check_graviton_deflection():
		return  # Projectile was deflected away

	global_position += direction * speed * delta


func _move_missile(delta):
	var store = _get_store()
	if not store:
		queue_free()
		return

	var state = store.get_state()

	# Update target if still alive
	if state.ships.has(target_id):
		arc_target = state.ships[target_id].position

	# Progress along arc
	var dist = arc_start.distance_to(arc_target)
	arc_t += (speed * delta) / max(dist, 50.0)

	if arc_t >= 1.0:
		_explode()
		queue_free()
		return

	# Quadratic bezier
	var t = arc_t
	var new_pos = (1-t)*(1-t)*arc_start + 2*(1-t)*t*arc_peak + t*t*arc_target

	# Rotate to face direction
	var tangent = 2*(1-t)*(arc_peak - arc_start) + 2*t*(arc_target - arc_peak)
	if tangent.length() > 1:
		rotation = tangent.angle()

	global_position = new_pos

	# Check arrival
	if global_position.distance_to(arc_target) < 35:
		_explode()
		queue_free()


func _move_turbolaser(delta):
	# Turbolaser: Slow, straight line - easy to dodge for fast ships
	global_position += direction * speed * delta


func _on_area_entered(area):
	var ship = area.get_parent()
	if not ship.is_in_group("ships"):
		return
	if ship.ship_data.team == team:
		return

	match weapon_type:
		VnpTypes.WeaponType.GUN:
			_hit_railgun(ship)
		VnpTypes.WeaponType.MISSILE:
			_explode()
			queue_free()
		VnpTypes.WeaponType.TURBOLASER:
			_hit_turbolaser(ship)
			queue_free()


func _hit_railgun(ship):
	if ship.ship_data.id in pierced_ships:
		return

	pierced_ships.append(ship.ship_data.id)

	var store = _get_store()
	if store:
		store.dispatch({
			"type": "DAMAGE_SHIP",
			"ship_id": ship.ship_data.id,
			"damage": damage
		})

	_spawn_impact(global_position, 0.5)

	if pierced_ships.size() >= max_pierces:
		queue_free()


func _hit_turbolaser(ship):
	# Turbolaser: Massive damage with dramatic impact
	var store = _get_store()
	var main = _get_main()

	if store:
		store.dispatch({
			"type": "DAMAGE_SHIP",
			"ship_id": ship.ship_data.id,
			"damage": damage
		})

	# Dramatic turbolaser impact explosion
	var turbo_color = VnpTypes.get_weapon_color(team, VnpTypes.WeaponType.TURBOLASER)
	var parent = get_tree().root

	# Bright flash
	_spawn_explosion_particles(parent, 20, 0.15, 250, 400, 2, 4, Color.WHITE, Color(turbo_color.r, turbo_color.g, turbo_color.b, 0))

	# Main explosion
	_spawn_explosion_particles(parent, 40, 0.4, 150, 300, 3, 6, turbo_color.lightened(0.5), Color(turbo_color.r * 0.3, turbo_color.g * 0.3, turbo_color.b * 0.3, 0))

	# Sparks
	_spawn_explosion_particles(parent, 25, 0.5, 300, 500, 1.5, 2.5, turbo_color, Color(turbo_color.r, turbo_color.g, turbo_color.b, 0))

	# Big shockwave
	_spawn_shockwave_colored(parent, 1.2, Color(turbo_color.r, turbo_color.g, turbo_color.b, 0.9))

	# Strong screen shake for turbolaser hit
	if main:
		main.shake_screen(30.0)


func _explode():
	var store = _get_store()
	var main = _get_main()
	if not store or not main:
		return

	# Visual explosion layers with faction-distinctive colors
	var parent = get_tree().root

	# Get faction-specific explosion palette
	var flash_color: Color
	var fire_start: Color
	var fire_end: Color
	var spark_color: Color
	var ring_color: Color

	match team:
		VnpTypes.Team.PLAYER:
			# Blue-white plasma explosions
			flash_color = Color(0.8, 0.9, 1.0)  # Ice white
			fire_start = Color(0.3, 0.7, 1.0)   # Bright cyan
			fire_end = Color(0.1, 0.3, 0.8, 0)  # Deep blue fade
			spark_color = Color(0.5, 0.8, 1.0)  # Electric blue
			ring_color = Color(0.4, 0.7, 1.0, 0.8)
		VnpTypes.Team.ENEMY_1:
			# Orange-red fire explosions
			flash_color = Color(1.0, 0.95, 0.8)  # Hot white
			fire_start = Color(1.0, 0.6, 0.1)    # Bright orange
			fire_end = Color(0.8, 0.2, 0.0, 0)   # Deep red fade
			spark_color = Color(1.0, 0.8, 0.2)   # Yellow sparks
			ring_color = Color(1.0, 0.5, 0.2, 0.8)
		VnpTypes.Team.NEMESIS:
			# Purple-magenta void explosions
			flash_color = Color(1.0, 0.7, 1.0)   # Pink-white
			fire_start = Color(0.9, 0.2, 0.9)    # Hot magenta
			fire_end = Color(0.4, 0.0, 0.6, 0)   # Deep purple fade
			spark_color = Color(1.0, 0.4, 1.0)   # Pink sparks
			ring_color = Color(0.8, 0.3, 0.9, 0.8)
		_:
			flash_color = Color.WHITE
			fire_start = Color(1.0, 0.5, 0.1)
			fire_end = Color(0.5, 0.1, 0.0, 0)
			spark_color = Color(1.0, 0.8, 0.3)
			ring_color = Color(1.0, 0.7, 0.3, 0.7)

	# Flash
	_spawn_explosion_particles(parent, 15, 0.1, 200, 350, 1.5, 3, flash_color, Color(flash_color.r, flash_color.g, flash_color.b, 0))
	# Fire - faction colored
	_spawn_explosion_particles(parent, 35, 0.35, 120, 280, 2.5, 5, fire_start, fire_end)
	# Smoke
	_spawn_explosion_particles(parent, 20, 0.8, 40, 80, 3, 5, Color(0.4, 0.3, 0.2, 0.6), Color(0.2, 0.2, 0.2, 0))
	# Sparks - faction colored
	_spawn_explosion_particles(parent, 15, 0.45, 280, 450, 1, 2, spark_color, Color(spark_color.r, spark_color.g, spark_color.b, 0))

	# Shockwave ring with faction color
	_spawn_shockwave_colored(parent, 0.65, ring_color)

	# Smaller screen shake per missile (3 missiles = cumulative effect)
	main.shake_screen(12.0)

	# Area damage
	var state = store.get_state()
	for ship_id in state.ships:
		var ship_data = state.ships[ship_id]
		if ship_data.team == team:
			continue
		var dist = global_position.distance_to(ship_data.position)
		if dist <= explosion_radius:
			var falloff = 1.0 - (dist / explosion_radius) * 0.5
			store.dispatch({
				"type": "DAMAGE_SHIP",
				"ship_id": ship_id,
				"damage": int(damage * falloff)
			})


func _spawn_explosion_particles(parent, amount, life, vel_min, vel_max, scale_min, scale_max, color_start, color_end):
	var particles = GPUParticles2D.new()
	particles.global_position = global_position
	particles.amount = amount
	particles.lifetime = life
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true

	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 5.0
	mat.spread = 180.0
	mat.initial_velocity_min = vel_min
	mat.initial_velocity_max = vel_max
	mat.damping_min = 50.0
	mat.damping_max = 100.0
	mat.scale_min = scale_min
	mat.scale_max = scale_max

	var grad = Gradient.new()
	grad.set_color(0, color_start)
	grad.set_color(1, color_end)
	var tex = GradientTexture1D.new()
	tex.gradient = grad
	mat.color_ramp = tex

	particles.process_material = mat
	var mesh = QuadMesh.new()
	mesh.size = Vector2(5, 5)
	particles.draw_pass_1 = mesh

	parent.add_child(particles)

	# Cleanup - free material and texture to prevent leaks
	get_tree().create_timer(life + 0.5).timeout.connect(func():
		if is_instance_valid(particles):
			# Clear references before freeing to prevent texture leaks
			if particles.process_material != null:
				var m = particles.process_material as ParticleProcessMaterial
				if m != null and m.color_ramp != null:
					m.color_ramp = null
				particles.process_material = null
			particles.queue_free()
	)


func _spawn_shockwave(parent, scale_mult: float = 1.0):
	var missile_color = VnpTypes.get_weapon_color(team, VnpTypes.WeaponType.MISSILE)
	_spawn_shockwave_colored(parent, scale_mult, Color(missile_color.r, missile_color.g, missile_color.b * 0.5, 0.7))


func _spawn_shockwave_colored(parent, scale_mult: float, ring_color: Color):
	var ring = Line2D.new()
	ring.global_position = global_position
	ring.width = 6.0 * scale_mult
	ring.default_color = ring_color

	var points = []
	for i in range(33):
		var angle = i * (PI * 2 / 32)
		points.append(Vector2(cos(angle), sin(angle)) * 10)
	ring.points = PackedVector2Array(points)

	parent.add_child(ring)

	var final_scale = 10 * scale_mult
	var tween = parent.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(final_scale, final_scale), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): ring.queue_free())


func _spawn_impact(pos: Vector2, scale_mult: float = 1.0):
	var impact = ImpactFxScene.instantiate()
	get_tree().root.add_child(impact)
	impact.global_position = pos
	impact.scale = Vector2.ONE * scale_mult
	impact.emitting = true


func _get_store():
	# Use injected store reference if available
	if store:
		return store
	# Fallback to getting from main (for compatibility)
	var main = _get_main()
	if main:
		return main.store
	return null


func _get_main():
	# Use injected reference if available
	if vnp_main:
		return vnp_main
	# Fallback for compatibility (not recommended)
	return get_tree().root.get_node_or_null("VnpMain")


func _check_graviton_deflection() -> bool:
	# Only check once per projectile - use a flag
	if has_meta("deflection_checked"):
		return false

	# Find enemy gravitons
	for node in get_tree().get_nodes_in_group("gravitons"):
		if not is_instance_valid(node):
			continue
		if node.ship_data.team == team:
			continue  # Don't deflect friendly railguns

		var graviton_stats = VnpTypes.SHIP_STATS.get(VnpTypes.ShipType.GRAVITON, {})
		var gravity_radius = graviton_stats.get("gravity_radius", 200)
		var deflect_strength = graviton_stats.get("deflect_strength", 0.9)

		var dist = global_position.distance_to(node.global_position)
		if dist <= gravity_radius:
			# Mark as checked to avoid repeated rolls
			set_meta("deflection_checked", true)

			# Roll for deflection
			if randf() < deflect_strength:
				_deflect_around_graviton(node)
				return true

	return false


func _deflect_around_graviton(graviton_ship):
	# Calculate deflection direction - curve around the graviton
	var to_graviton = graviton_ship.global_position - global_position
	var perp = Vector2(-to_graviton.y, to_graviton.x).normalized()

	# Pick random side to deflect
	if randf() > 0.5:
		perp = -perp

	# New direction curves around
	var deflect_dir = (direction + perp * 1.5).normalized()

	# Show dramatic deflection visual
	graviton_ship.show_deflection_effect(global_position, deflect_dir)

	# Create curved deflection trail
	_spawn_deflection_trail(deflect_dir)

	# Change projectile direction sharply
	direction = deflect_dir
	rotation = deflect_dir.angle()

	# Reduce damage after deflection (energy loss)
	damage *= 0.3


func _spawn_deflection_trail(new_direction: Vector2):
	# Create a curved line showing the bend in trajectory
	var trail = Line2D.new()
	trail.width = 6.0

	# Color matches projectile with gravity tint
	var base_color = VnpTypes.get_weapon_color(team, VnpTypes.WeaponType.GUN)
	trail.default_color = Color(base_color.r * 0.7, base_color.g * 0.5, base_color.b * 1.2, 0.9)

	# Create curved path from old direction to new
	var start = global_position - direction * 30  # Where it was coming from
	var bend = global_position  # The bend point
	var end_dir = global_position + new_direction * 50  # Where it's going

	trail.add_point(start)
	trail.add_point(bend)
	trail.add_point(end_dir)
	trail.antialiased = true

	get_tree().root.add_child(trail)

	# Fade out
	var tween = get_tree().create_tween()
	tween.tween_property(trail, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func(): trail.queue_free())

	# Sparks at deflection point
	var sparks = GPUParticles2D.new()
	sparks.global_position = global_position
	sparks.amount = 12
	sparks.lifetime = 0.25
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.emitting = true

	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(new_direction.x, new_direction.y, 0)
	mat.spread = 45.0
	mat.initial_velocity_min = 100.0
	mat.initial_velocity_max = 200.0
	mat.scale_min = 1.0
	mat.scale_max = 2.0

	# Purple-tinted sparks from gravity interaction
	var grad = Gradient.new()
	grad.set_color(0, Color(0.8, 0.6, 1.0, 1.0))
	grad.set_color(1, Color(0.4, 0.2, 0.6, 0.0))
	var tex = GradientTexture1D.new()
	tex.gradient = grad
	mat.color_ramp = tex

	sparks.process_material = mat
	var spark_mesh = QuadMesh.new()
	spark_mesh.size = Vector2(3, 3)
	sparks.draw_pass_1 = spark_mesh

	get_tree().root.add_child(sparks)

	# Cleanup - free material and texture to prevent leaks
	get_tree().create_timer(0.5).timeout.connect(func():
		if is_instance_valid(sparks):
			if sparks.process_material != null:
				var m = sparks.process_material as ParticleProcessMaterial
				if m != null and m.color_ramp != null:
					m.color_ramp = null
				sparks.process_material = null
			sparks.queue_free()
	)
