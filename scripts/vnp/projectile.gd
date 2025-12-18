extends Area2D

const VnpTypes = preload("res://scripts/vnp/vnp_types.gd")
const ImpactFxScene = preload("res://scenes/vnp/impact_fx.tscn")

var speed = 800
var damage = 0
var team = -1
var weapon_type = null
var target_id = -1 # For homing missiles
var direction = Vector2.RIGHT

var lifetime = 2.0 # seconds

# Railgun piercing - tracks which ships we've already hit
var pierced_ships = []
var max_pierces = 3  # Can hit up to 3 enemies

# Missile explosion
var explosion_radius = 80.0

# Missile arc trajectory
var arc_height = 0.0
var arc_progress = 0.0
var arc_start_pos = Vector2.ZERO
var arc_peak_offset = Vector2.ZERO
var initial_target_pos = Vector2.ZERO
var smoke_trail: GPUParticles2D = null
var initialized = false  # Guard against physics running before init

var lifetime_timer: Timer = null

func _ready():
	# Create timer but don't start - init() will start it with correct lifetime
	lifetime_timer = Timer.new()
	lifetime_timer.name = "ProjectileLifetime"
	lifetime_timer.one_shot = true
	lifetime_timer.connect("timeout", Callable(self, "queue_free"))
	add_child(lifetime_timer)

	self.connect("area_entered", Callable(self, "_on_area_entered"))

func init(init_data):
	self.damage = init_data.get("damage", 0)
	self.team = init_data.get("team", -1)
	self.weapon_type = init_data.get("weapon_type", null)
	self.target_id = init_data.get("target_id", -1)
	self.position = init_data.get("start_position", Vector2.ZERO)
	self.rotation = init_data.get("start_rotation", 0)
	self.direction = Vector2.RIGHT.rotated(self.rotation)
	
	# Apply faction-specific weapon colors
	var weapon_color = VnpTypes.get_weapon_color(team, weapon_type)
	$Polygon2D.color = weapon_color

	# Create gradient for trail
	var trail_gradient = Gradient.new()
	trail_gradient.set_color(0, weapon_color)
	trail_gradient.set_color(1, Color(weapon_color.r, weapon_color.g, weapon_color.b, 0))
	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = trail_gradient
	$Trail2D.gradient = gradient_tex

	if weapon_type == VnpTypes.WeaponType.MISSILE:
		speed = 300  # Missiles arc, so effective speed varies
		lifetime = 5.0  # Longer flight time for arc
		explosion_radius = 120.0

		# Store starting position for arc calculation - use init_data directly!
		arc_start_pos = init_data.get("start_position", Vector2.ZERO)
		arc_progress = 0.0

		# Get initial target position for arc
		var store = get_tree().root.get_node("VnpMain").store
		if store:
			var state = store.get_state()
			if state.ships.has(target_id):
				initial_target_pos = state.ships[target_id].position
			else:
				initial_target_pos = arc_start_pos + direction * 500

		# Calculate arc height based on distance
		var dist = arc_start_pos.distance_to(initial_target_pos)
		arc_height = dist * 0.35  # Arc rises 35% of distance

		# Perpendicular offset for the arc peak - randomize left/right for variety
		var to_target = (initial_target_pos - arc_start_pos).normalized()
		var perp = Vector2(-to_target.y, to_target.x)
		# Randomly arc left or right
		if randf() > 0.5:
			perp = -perp
		arc_peak_offset = perp * arc_height

		# Set initial position explicitly
		global_position = arc_start_pos

		# Make missiles chunky and visible - rocket shape
		$Polygon2D.polygon = PackedVector2Array([
			Vector2(-10, -4), Vector2(6, -4), Vector2(10, -2), Vector2(12, 0),
			Vector2(10, 2), Vector2(6, 4), Vector2(-10, 4), Vector2(-8, 0)
		])
		$Polygon2D.scale = Vector2(1.5, 1.5)

		# Remove default trail entirely - we use smoke particles instead
		$Trail2D.queue_free()

		# Create smoke trail particles
		_create_smoke_trail()
	else:  # RAILGUN - fast piercing projectiles
		speed = 1200  # Very fast
		lifetime = 1.5
		max_pierces = 3
		# Long thin railgun slug
		$Polygon2D.polygon = PackedVector2Array([
			Vector2(-12, -2), Vector2(12, -1), Vector2(14, 0), Vector2(12, 1), Vector2(-12, 2)
		])
		$Polygon2D.scale = Vector2(1.0, 1.0)
		$Trail2D.width = 4.0

	# Start lifetime timer with correct duration
	lifetime_timer.wait_time = lifetime
	lifetime_timer.start()

	# Mark as initialized - safe for physics to run now
	initialized = true


func _create_smoke_trail():
	smoke_trail = GPUParticles2D.new()
	smoke_trail.name = "SmokeTrail"
	smoke_trail.amount = 40
	smoke_trail.lifetime = 0.8
	smoke_trail.explosiveness = 0.0
	smoke_trail.emitting = true

	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(-1, 0, 0)
	mat.spread = 25.0
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 50.0
	mat.gravity = Vector3(0, -20, 0)  # Smoke rises slightly
	mat.damping_min = 10.0
	mat.damping_max = 20.0
	mat.scale_min = 1.0
	mat.scale_max = 3.0

	# Smoke color gradient - starts bright, fades to gray
	var color_gradient = Gradient.new()
	color_gradient.set_color(0, Color(1.0, 0.8, 0.3, 0.9))  # Bright exhaust
	color_gradient.add_point(0.2, Color(1.0, 0.5, 0.1, 0.7))  # Orange
	color_gradient.add_point(0.5, Color(0.5, 0.5, 0.5, 0.5))  # Gray smoke
	color_gradient.set_color(1, Color(0.3, 0.3, 0.3, 0.0))  # Fades out
	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = color_gradient
	mat.color_ramp = gradient_tex

	smoke_trail.process_material = mat

	# Draw as soft circles
	var mesh = QuadMesh.new()
	mesh.size = Vector2(8, 8)
	smoke_trail.draw_pass_1 = mesh

	smoke_trail.position = Vector2(-12, 0)  # At rear of missile
	add_child(smoke_trail)

func _physics_process(delta):
	if not initialized:
		return

	if weapon_type == VnpTypes.WeaponType.MISSILE:
		# ARC TRAJECTORY - quadratic bezier curve
		var main_node = get_tree().root.get_node_or_null("VnpMain")
		if not main_node:
			queue_free()
			return

		var store = main_node.store
		if not store:
			queue_free()
			return

		var state = store.get_state()

		# Update target position if target still exists (for homing)
		var current_target_pos = initial_target_pos
		if state.ships.has(target_id):
			current_target_pos = state.ships[target_id].position

		# Progress along the arc (0 to 1)
		var dist_to_target = arc_start_pos.distance_to(current_target_pos)
		arc_progress += (speed * delta) / max(dist_to_target, 50.0)

		# Safety: force completion if arc_progress exceeds 1
		if arc_progress >= 1.0:
			_explode_missile(store, main_node)
			queue_free()
			return

		# Quadratic bezier: start -> peak -> target
		var peak_pos = (arc_start_pos + current_target_pos) / 2 + arc_peak_offset
		var t = arc_progress

		# Bezier formula: (1-t)²*P0 + 2(1-t)*t*P1 + t²*P2
		var new_pos = (1-t)*(1-t)*arc_start_pos + 2*(1-t)*t*peak_pos + t*t*current_target_pos

		# Calculate direction for rotation (derivative of bezier)
		var tangent = 2*(1-t)*(peak_pos - arc_start_pos) + 2*t*(current_target_pos - peak_pos)
		if tangent.length() > 0:
			rotation = tangent.angle()
			direction = tangent.normalized()

		global_position = new_pos

		# Check if we've reached the target
		if arc_progress >= 0.95 or global_position.distance_to(current_target_pos) < 40:
			_explode_missile(store, main_node)
			queue_free()
			return
	else:
		# Normal linear movement for railgun
		position += direction * speed * delta

func _on_area_entered(area):
	var ship = area.get_parent()
	if not ship.is_in_group("ships"):
		return

	# Don't hit ships on the same team
	if ship.ship_data.team == self.team:
		return

	var store = get_tree().root.get_node("VnpMain").store
	var main_node = get_tree().root.get_node("VnpMain")

	match weapon_type:
		VnpTypes.WeaponType.MISSILE:
			# MISSILE: Explodes with area damage!
			_explode_missile(store, main_node)
			queue_free()

		VnpTypes.WeaponType.GUN:
			# RAILGUN: Pierces through enemies
			if ship.ship_data.id in pierced_ships:
				return  # Already hit this ship

			pierced_ships.append(ship.ship_data.id)

			# Deal damage with armor-piercing effect (ignores some defense)
			store.dispatch({
				"type": "DAMAGE_SHIP",
				"ship_id": ship.ship_data.id,
				"damage": damage
			})

			# Sparks fly off but projectile continues
			var impact = ImpactFxScene.instantiate()
			get_parent().add_child(impact)
			impact.global_position = global_position
			impact.emitting = true
			impact.scale = Vector2(0.5, 0.5)  # Smaller sparks for pierce

			# Check if we've pierced enough
			if pierced_ships.size() >= max_pierces:
				queue_free()

		_:
			# Default behavior
			store.dispatch({
				"type": "DAMAGE_SHIP",
				"ship_id": ship.ship_data.id,
				"damage": damage
			})
			var impact = ImpactFxScene.instantiate()
			get_parent().add_child(impact)
			impact.global_position = global_position
			impact.emitting = true
			queue_free()

func _explode_missile(store, main_node):
	var parent = get_parent()
	if not parent:
		parent = get_tree().root

	# === MASSIVE EXPLOSION ===

	# Layer 1: Bright flash (instant, white-hot center)
	var flash = _create_explosion_layer(parent, {
		"amount": 30,
		"lifetime": 0.15,
		"velocity_min": 200,
		"velocity_max": 400,
		"scale_min": 2.0,
		"scale_max": 4.0,
		"color_start": Color(1.0, 1.0, 1.0, 1.0),
		"color_end": Color(1.0, 0.9, 0.5, 0.0),
	})

	# Layer 2: Fire burst (orange/red expanding)
	var fire = _create_explosion_layer(parent, {
		"amount": 60,
		"lifetime": 0.4,
		"velocity_min": 150,
		"velocity_max": 350,
		"scale_min": 3.0,
		"scale_max": 6.0,
		"color_start": Color(1.0, 0.6, 0.1, 1.0),
		"color_end": Color(1.0, 0.2, 0.0, 0.0),
	})

	# Layer 3: Smoke cloud (lingers)
	var smoke = _create_explosion_layer(parent, {
		"amount": 40,
		"lifetime": 1.2,
		"velocity_min": 50,
		"velocity_max": 120,
		"scale_min": 4.0,
		"scale_max": 10.0,
		"color_start": Color(0.4, 0.3, 0.2, 0.8),
		"color_end": Color(0.2, 0.2, 0.2, 0.0),
		"gravity": -30,  # Rises
	})

	# Layer 4: Debris/sparks (fast outward)
	var debris = _create_explosion_layer(parent, {
		"amount": 25,
		"lifetime": 0.6,
		"velocity_min": 300,
		"velocity_max": 500,
		"scale_min": 1.0,
		"scale_max": 2.0,
		"color_start": Color(1.0, 0.8, 0.3, 1.0),
		"color_end": Color(1.0, 0.4, 0.0, 0.0),
	})

	# Layer 5: Shockwave ring (expanding circle)
	_create_shockwave_ring(parent)

	# BIG screen shake!
	main_node.shake_screen(35.0)

	# Deal area damage to all enemies in radius
	var state = store.get_state()
	for ship_id in state.ships:
		var ship_data = state.ships[ship_id]
		if ship_data.team == self.team:
			continue  # Don't hurt friendlies

		var dist = global_position.distance_to(ship_data.position)
		if dist <= explosion_radius:
			# Damage falls off with distance
			var falloff = 1.0 - (dist / explosion_radius) * 0.5
			var explosion_damage = int(damage * falloff)
			store.dispatch({
				"type": "DAMAGE_SHIP",
				"ship_id": ship_id,
				"damage": explosion_damage
			})

func _create_explosion_layer(parent, params: Dictionary) -> GPUParticles2D:
	var particles = GPUParticles2D.new()
	particles.global_position = global_position
	particles.amount = params.get("amount", 30)
	particles.lifetime = params.get("lifetime", 0.5)
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true

	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 5.0
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = params.get("velocity_min", 100)
	mat.initial_velocity_max = params.get("velocity_max", 200)
	mat.gravity = Vector3(0, params.get("gravity", 0), 0)
	mat.damping_min = 50.0
	mat.damping_max = 100.0
	mat.scale_min = params.get("scale_min", 1.0)
	mat.scale_max = params.get("scale_max", 2.0)

	var gradient = Gradient.new()
	gradient.set_color(0, params.get("color_start", Color.WHITE))
	gradient.set_color(1, params.get("color_end", Color.TRANSPARENT))
	var gradient_tex = GradientTexture1D.new()
	gradient_tex.gradient = gradient
	mat.color_ramp = gradient_tex

	particles.process_material = mat

	var mesh = QuadMesh.new()
	mesh.size = Vector2(6, 6)
	particles.draw_pass_1 = mesh

	parent.add_child(particles)

	# Auto-cleanup
	var timer = get_tree().create_timer(params.get("lifetime", 0.5) + 0.5)
	timer.timeout.connect(particles.queue_free)

	return particles

func _create_shockwave_ring(parent):
	var ring = Line2D.new()
	ring.global_position = global_position
	ring.width = 8.0
	ring.default_color = Color(1.0, 0.8, 0.4, 0.8)

	# Create circle points
	var points = []
	for i in range(33):
		var angle = i * (PI * 2 / 32)
		points.append(Vector2(cos(angle), sin(angle)) * 10)
	ring.points = PackedVector2Array(points)

	parent.add_child(ring)

	# Animate expanding ring
	var tween = parent.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(15, 15), 0.4).from(Vector2(1, 1)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.4)
	tween.tween_property(ring, "width", 2.0, 0.4)
	tween.tween_callback(ring.queue_free)