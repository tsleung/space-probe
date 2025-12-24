extends Area2D
## Projectile - Handles all projectile types: Railgun, Laser (instant), Missile
## Each type has unique behavior and visuals

const VnpTypes = preload("res://scripts/von_neumann_probe/vnp_types.gd")
const ImpactFxScene = preload("res://scenes/von_neumann_probe/impact_fx.tscn")

# Static cached textures (shared across all projectiles)
static var _cached_glow_texture_small: GradientTexture2D = null
static var _cached_glow_texture_medium: GradientTexture2D = null
static var _active_particle_count: int = 0
const MAX_ACTIVE_PARTICLES = 30  # Limit simultaneous particle effects

# Core properties
var team: int = -1
var weapon_type: int = -1
var damage: float = 0
var target_id = -1  # Can be int (ship) or String (factory)
var is_factory_target: bool = false  # True if targeting a factory
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
var active: bool = false  # For object pooling

# Trail system (Line2D based)
var trail_line: Line2D = null
var trail_points: Array[Vector2] = []
const MAX_TRAIL_POINTS = 8  # Shorter, more subtle trails

# Resource tracking for cleanup (prevents texture leaks)
var _trail_gradient: Gradient = null
var _smoke_material: ParticleProcessMaterial = null
var _glow_material: ParticleProcessMaterial = null


func init(data: Dictionary):
	# Reset state for pooling
	_reset_state()

	team = data.get("team", -1)
	weapon_type = data.get("weapon_type", VnpTypes.WeaponType.GUN)
	damage = data.get("damage", 10)
	target_id = data.get("target_id", -1)
	is_factory_target = data.get("is_factory_target", false)
	store = data.get("store", null)
	vnp_main = data.get("vnp_main", null)

	var start_pos: Vector2 = data.get("start_position", Vector2.ZERO)
	var start_rot: float = data.get("start_rotation", 0.0)

	# Warn if spawning at origin (likely a bug)
	if start_pos == Vector2.ZERO:
		push_warning("[PROJECTILE] Spawning at origin (0,0) - missing start_position? Skipping.")
		deactivate()
		return

	global_position = start_pos
	rotation = start_rot
	direction = Vector2.RIGHT.rotated(start_rot)

	active = true
	visible = true
	set_physics_process(true)

	# Setup weapon-specific behavior
	_setup_projectile(data)


func _reset_state():
	# Reset all state for pooling reuse
	pierced_ships.clear()
	arc_t = 0.0
	is_ready = false
	active = false
	lifetime = 2.0
	is_factory_target = false

	# Clear trail
	trail_points.clear()
	if trail_line and is_instance_valid(trail_line):
		trail_line.clear_points()

	# Remove any metadata
	if has_meta("deflection_checked"):
		remove_meta("deflection_checked")


func deactivate():
	# Return to pool instead of queue_free
	active = false
	visible = false
	set_physics_process(false)
	is_ready = false

	# Clean up trail (it's added to scene root, not as child)
	if trail_line and is_instance_valid(trail_line):
		trail_line.gradient = null
		trail_line.queue_free()
		trail_line = null
	trail_points.clear()

	# Clean up any child visual elements and timers added during setup
	for child in get_children():
		if child.name in ["RailGlow", "RailCore", "TurboGlow", "TurboCore", "MissileEngine"]:
			child.queue_free()
		elif child is Timer:
			child.stop()
			child.queue_free()

	# Remove from missiles group if applicable
	if is_in_group("missiles"):
		remove_from_group("missiles")

	# Move off-screen
	global_position = Vector2(-9999, -9999)


func _return_to_pool():
	# Use pool if vnp_main exists, otherwise fallback to queue_free
	if vnp_main and is_instance_valid(vnp_main):
		vnp_main.return_projectile(self)
	else:
		queue_free()


func _setup_projectile(data: Dictionary):
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

	# Larger, more visible sharp elongated slug
	$Polygon2D.polygon = PackedVector2Array([
		Vector2(-14, -3), Vector2(18, -2), Vector2(24, 0), Vector2(18, 2), Vector2(-14, 3)
	])

	# Add bright glow outline - more visible
	var rail_color = VnpTypes.get_weapon_color(team, VnpTypes.WeaponType.GUN)
	var glow = Line2D.new()
	glow.name = "RailGlow"
	glow.width = 8.0  # Wider glow
	glow.default_color = Color(rail_color.r, rail_color.g, rail_color.b, 0.6)
	glow.add_point(Vector2(-14, 0))
	glow.add_point(Vector2(24, 0))
	glow.z_index = -1
	add_child(glow)

	# Add a bright core line
	var core = Line2D.new()
	core.name = "RailCore"
	core.width = 3.0
	core.default_color = Color(rail_color.r * 1.5, rail_color.g * 1.5, rail_color.b * 1.5, 1.0)
	core.add_point(Vector2(-14, 0))
	core.add_point(Vector2(24, 0))
	add_child(core)

	_create_line_trail(4.0)  # Thicker trail


func _setup_missile(data: Dictionary):
	speed = 500  # Faster missiles
	lifetime = 3.5

	# Store arc parameters
	arc_start = global_position
	arc_t = 0.0

	# Get target position
	var local_store = _get_store()
	if local_store:
		var state = local_store.get_state()
		if is_factory_target and state.has("factories") and state.factories.has(target_id):
			arc_target = state.factories[target_id].position
		elif state.ships.has(target_id):
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

	# Larger, more visible missile shape
	$Polygon2D.polygon = PackedVector2Array([
		Vector2(-12, -3), Vector2(8, -2), Vector2(14, 0),
		Vector2(8, 2), Vector2(-12, 3), Vector2(-8, 0)
	])
	$Polygon2D.scale = Vector2(1.2, 1.2)

	# Add engine glow at back of missile
	var missile_color = VnpTypes.get_weapon_color(team, VnpTypes.WeaponType.MISSILE)
	var engine_glow = Polygon2D.new()
	engine_glow.name = "MissileEngine"
	engine_glow.polygon = PackedVector2Array([
		Vector2(-14, -2), Vector2(-10, 0), Vector2(-14, 2), Vector2(-18, 0)
	])
	engine_glow.color = Color(missile_color.r * 1.5, missile_color.g * 1.2, missile_color.b * 0.8, 0.9)
	add_child(engine_glow)

	# Smaller explosion radius for salvo missiles
	explosion_radius = 80.0

	# Missiles use smoke trail - thicker for visibility
	_create_smoke_trail()


func _setup_turbolaser(data: Dictionary):
	# TURBOLASER: Slow, huge, devastating bolt - Star Destroyer style
	turbolaser_speed = data.get("turbolaser_speed", 180)
	turbolaser_size = data.get("turbolaser_size", 12) * 1.5  # 50% larger
	speed = turbolaser_speed
	lifetime = 4.0  # Long lifetime since slow

	# Big elongated bolt shape - larger for visibility
	$Polygon2D.polygon = PackedVector2Array([
		Vector2(-turbolaser_size, -turbolaser_size * 0.5),
		Vector2(turbolaser_size * 0.6, -turbolaser_size * 0.3),
		Vector2(turbolaser_size, 0),
		Vector2(turbolaser_size * 0.6, turbolaser_size * 0.3),
		Vector2(-turbolaser_size, turbolaser_size * 0.5),
	])

	# Make the bolt glow brightly
	$Polygon2D.modulate = Color(1.4, 1.4, 1.4, 1.0)

	# Thicker trail for visibility
	_create_line_trail(turbolaser_size * 0.6)

	# Add a trailing glow effect
	_create_turbolaser_glow()


func _create_turbolaser_glow():
	# Bright glow halo
	var turbo_color = VnpTypes.get_weapon_color(team, VnpTypes.WeaponType.TURBOLASER)

	# Outer glow ring - larger and brighter
	var glow = Line2D.new()
	glow.name = "TurboGlow"
	glow.width = turbolaser_size * 1.2
	glow.default_color = Color(turbo_color.r, turbo_color.g, turbo_color.b, 0.5)
	var points = []
	for i in range(9):
		var angle = i * (PI * 2 / 8)
		points.append(Vector2(cos(angle), sin(angle)) * turbolaser_size * 0.8)
	glow.points = PackedVector2Array(points)
	glow.z_index = -1
	add_child(glow)

	# Add a bright core glow
	var core_glow = Polygon2D.new()
	core_glow.name = "TurboCore"
	var core_points = []
	for i in range(9):
		var angle = i * (PI * 2 / 8)
		core_points.append(Vector2(cos(angle), sin(angle)) * turbolaser_size * 0.4)
	core_glow.polygon = PackedVector2Array(core_points)
	core_glow.color = Color(turbo_color.r * 1.5, turbo_color.g * 1.5, turbo_color.b * 1.5, 0.8)
	add_child(core_glow)


func _create_glow_texture(radius: float) -> GradientTexture2D:
	# Use cached textures to avoid creating new ones constantly
	if radius <= 2.0:
		if _cached_glow_texture_small == null:
			_cached_glow_texture_small = _make_glow_texture(2.5)
		return _cached_glow_texture_small
	else:
		if _cached_glow_texture_medium == null:
			_cached_glow_texture_medium = _make_glow_texture(4.0)
		return _cached_glow_texture_medium


static func _make_glow_texture(radius: float) -> GradientTexture2D:
	var texture = GradientTexture2D.new()
	texture.width = int(radius * 4)
	texture.height = int(radius * 4)
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	var gradient = Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	texture.gradient = gradient
	return texture


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
	# Thicker, more visible line trail for missiles
	_create_line_trail(6.0)


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
	_return_to_pool()


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
	var local_store = _get_store()
	if not local_store:
		_return_to_pool()
		return

	var state = local_store.get_state()

	# Update target if still alive
	if is_factory_target and state.has("factories") and state.factories.has(target_id):
		arc_target = state.factories[target_id].position
	elif state.ships.has(target_id):
		arc_target = state.ships[target_id].position

	# Progress along arc
	var dist = arc_start.distance_to(arc_target)
	arc_t += (speed * delta) / max(dist, 50.0)

	if arc_t >= 1.0:
		_explode()
		_return_to_pool()
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
		_return_to_pool()


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
			_return_to_pool()
		VnpTypes.WeaponType.TURBOLASER:
			_hit_turbolaser(ship)
			_return_to_pool()


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
	_spawn_railgun_sparks(global_position)

	if pierced_ships.size() >= max_pierces:
		_return_to_pool()


func _spawn_railgun_sparks(pos: Vector2):
	# Impact sparks for railgun hits - small metallic debris
	var rail_color = VnpTypes.get_weapon_color(team, VnpTypes.WeaponType.GUN)
	var spark_count = 6

	for i in range(spark_count):
		var angle = randf() * TAU
		var length = randf_range(8, 18)

		# Spark line
		var spark = Line2D.new()
		spark.width = 2.0
		spark.default_color = Color(1.0, 0.95, 0.85, 0.9)  # Hot metal white
		spark.add_point(Vector2.ZERO)
		spark.add_point(Vector2(cos(angle), sin(angle)) * length)
		spark.global_position = pos
		get_tree().root.add_child(spark)

		# Animate flying outward
		var end_pos = pos + Vector2(cos(angle), sin(angle)) * randf_range(25, 50)
		var spark_tween = create_tween()
		spark_tween.set_parallel(true)
		spark_tween.tween_property(spark, "global_position", end_pos, randf_range(0.12, 0.22))
		spark_tween.tween_property(spark, "modulate:a", 0.0, randf_range(0.15, 0.25))
		spark_tween.tween_callback(func(): spark.queue_free())

	# Small flash at impact point
	var flash = Polygon2D.new()
	flash.polygon = PackedVector2Array([
		Vector2(-8, 0), Vector2(0, -8), Vector2(8, 0), Vector2(0, 8)
	])
	flash.color = Color(rail_color.r * 1.3, rail_color.g * 1.2, rail_color.b, 0.9)
	flash.global_position = pos
	flash.scale = Vector2(0.3, 0.3)
	get_tree().root.add_child(flash)

	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "scale", Vector2(1.2, 1.2), 0.06)
	flash_tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.08)
	flash_tween.tween_callback(func(): flash.queue_free())


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

	# Area damage to ships
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

	# Area damage to factories
	if state.has("factories"):
		for factory_id in state.factories:
			var factory_data = state.factories[factory_id]
			if factory_data.team == team:
				continue
			var dist = global_position.distance_to(factory_data.position)
			if dist <= explosion_radius:
				var falloff = 1.0 - (dist / explosion_radius) * 0.5
				store.dispatch({
					"type": "DAMAGE_FACTORY",
					"factory_id": factory_id,
					"damage": int(damage * falloff * 1.5)  # Bonus damage vs structures
				})


func _spawn_explosion_particles(parent, amount, life, vel_min, vel_max, scale_min, scale_max, color_start, color_end):
	# Skip effects if vnp_main is in skip mode (post alt-tab)
	if vnp_main != null and vnp_main.skip_effects_frames > 0:
		return
	# Rate limit particle effects to prevent performance issues
	if _active_particle_count >= MAX_ACTIVE_PARTICLES:
		return  # Skip this effect

	_active_particle_count += 1

	# Reduce particle count when many effects active
	var actual_amount = amount
	if _active_particle_count > MAX_ACTIVE_PARTICLES / 2:
		actual_amount = max(5, amount / 2)

	var particles = GPUParticles2D.new()
	particles.global_position = global_position
	particles.amount = actual_amount
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
	particles.texture = _create_glow_texture(2.5)

	parent.add_child(particles)

	# Cleanup - free material and texture to prevent leaks
	get_tree().create_timer(life + 0.5).timeout.connect(func():
		_active_particle_count = max(0, _active_particle_count - 1)
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

	# Small deflection ring (no GPU particles for performance)
	var ring = Line2D.new()
	ring.global_position = global_position
	ring.width = 3.0
	ring.default_color = Color(0.8, 0.6, 1.0, 0.8)
	var ring_points = []
	for i in range(9):
		var angle = i * (PI * 2 / 8)
		ring_points.append(Vector2(cos(angle), sin(angle)) * 6)
	ring.points = PackedVector2Array(ring_points)
	get_tree().root.add_child(ring)

	var ring_tween = get_tree().create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector2(4, 4), 0.2)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.2)
	ring_tween.tween_callback(func(): ring.queue_free())
