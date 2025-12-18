extends CharacterBody2D

const VnpTypes = preload("res://scripts/von_neumann_probe/vnp_types.gd")
const VnpSystems = preload("res://scripts/von_neumann_probe/vnp_systems.gd")
const ProjectileScene = preload("res://scenes/von_neumann_probe/projectile.tscn")
const ImpactFxScene = preload("res://scenes/von_neumann_probe/impact_fx.tscn")

var store = null
var vnp_main = null  # Reference to VnpMain for screen shake
var ship_data = {}
var ship_stats = {}
var ai_controller = null  # Reference for fleet formation queries
var sound_manager = null  # Reference for playing weapon sounds

@onready var navigation_agent = $NavigationAgent2D
@onready var polygon = $Polygon2D
@onready var fire_rate_timer = $FireRateTimer
@onready var laser_beam = $LaserBeam
@onready var selection_indicator = $SelectionIndicator

# Engine trail particle system
var engine_trail: GPUParticles2D = null
var muzzle_flash: Polygon2D = null
var side_thruster_left: GPUParticles2D = null
var side_thruster_right: GPUParticles2D = null

# Defensive systems
var shield_bubble: Line2D = null
var pdc_cooldown: float = 0.0
var gravity_well: Node2D = null
var gravity_vortex_particles: GPUParticles2D = null
var gravity_ring_inner: Line2D = null
var gravity_ring_outer: Line2D = null

# Star Base visuals
var starbase_range_ring: Line2D = null
var starbase_structure: Node2D = null

# PDC kill zone visuals
var pdc_kill_zone: Node2D = null
var pdc_sweep_line: Line2D = null
var pdc_range_ring: Line2D = null
var pdc_sweep_angle: float = 0.0

# Prevent spamming state changes
var last_state_change_time: float = 0.0
const STATE_CHANGE_COOLDOWN: float = 0.1  # 100ms between state changes

# Strafing for small ships
var strafe_angle: float = 0.0
var strafe_direction: int = 1  # 1 or -1

# Tactical awareness
enum ThreatType { NONE, SLOW_HEAVY, FAST_SWARM, SNIPER, AOE_SPRAY, SUPPORT }
var current_threat: int = ThreatType.NONE
var threat_assessment_cooldown: float = 0.0

# Asteroids-style momentum physics
var current_velocity: Vector2 = Vector2.ZERO
const SPACE_DRAG: float = 0.3  # Slight drag to prevent infinite drift
const THRUST_MULTIPLIER: float = 2.5  # How responsive thrust feels

func init(vnp_store, initial_data, controller = null, snd_manager = null, main_ref = null):
	self.store = vnp_store
	self.vnp_main = main_ref
	self.ship_data = initial_data
	self.ship_stats = VnpTypes.SHIP_STATS[ship_data.type]
	self.ai_controller = controller
	self.sound_manager = snd_manager

	self.position = ship_data.position
	add_to_group("ships")  # For projectile collision detection
	_apply_styles()
	_setup_engine_trail()
	_setup_muzzle_flash()
	_setup_side_thrusters()

	# Setup defensive systems with striking visual effects
	if ship_data.type == VnpTypes.ShipType.SHIELDER:
		_setup_shield_bubble()
	elif ship_data.type == VnpTypes.ShipType.GRAVITON:
		_setup_gravity_well()
	elif ship_data.type == VnpTypes.ShipType.DEFENDER:
		_setup_pdc_kill_zone()
	elif ship_data.type == VnpTypes.ShipType.STARBASE:
		_setup_starbase_visuals()
	elif ship_data.type == VnpTypes.ShipType.BASE_TURRET:
		_setup_turret_visuals()

	var fire_rate = ship_stats.get("fire_rate", 1.0)
	if fire_rate > 0:
		fire_rate_timer.wait_time = 1.0 / fire_rate
		fire_rate_timer.connect("timeout", Callable(self, "_on_fire_rate_timer_timeout"))

func _setup_engine_trail():
	engine_trail = GPUParticles2D.new()
	engine_trail.name = "EngineTrail"

	var ship_size = VnpTypes.get_ship_size(ship_data.type)
	var team_color = VnpTypes.get_team_color(ship_data.team)

	# Ship-type specific trail configs - BOOSTED for visibility
	var trail_config = {
		VnpTypes.ShipType.FRIGATE: {
			"offset": -8, "amount": 35, "lifetime": 0.4,
			"velocity_min": 100.0, "velocity_max": 150.0,  # Fast, aggressive
			"scale_min": 1.2, "scale_max": 2.5, "spread": 15.0,
			"mesh_size": 4.0
		},
		VnpTypes.ShipType.DESTROYER: {
			"offset": -12, "amount": 40, "lifetime": 0.55,
			"velocity_min": 80.0, "velocity_max": 120.0,  # Steady, precise
			"scale_min": 1.5, "scale_max": 3.0, "spread": 12.0,
			"mesh_size": 4.5
		},
		VnpTypes.ShipType.CRUISER: {
			"offset": -14, "amount": 55, "lifetime": 0.75,
			"velocity_min": 60.0, "velocity_max": 100.0,  # Heavy, powerful
			"scale_min": 2.0, "scale_max": 4.5, "spread": 22.0,
			"mesh_size": 6.0
		},
		VnpTypes.ShipType.DEFENDER: {
			"offset": -10, "amount": 35, "lifetime": 0.5,
			"velocity_min": 70.0, "velocity_max": 110.0,
			"scale_min": 1.3, "scale_max": 2.8, "spread": 16.0,
			"mesh_size": 4.0
		},
		VnpTypes.ShipType.SHIELDER: {
			"offset": -10, "amount": 30, "lifetime": 0.55,
			"velocity_min": 60.0, "velocity_max": 100.0,
			"scale_min": 1.5, "scale_max": 3.2, "spread": 20.0,
			"mesh_size": 4.5
		},
		VnpTypes.ShipType.GRAVITON: {
			"offset": -16, "amount": 45, "lifetime": 0.65,
			"velocity_min": 50.0, "velocity_max": 80.0,  # Slow, ominous
			"scale_min": 2.0, "scale_max": 4.0, "spread": 28.0,
			"mesh_size": 5.5
		},
		VnpTypes.ShipType.HARVESTER: {
			"offset": -10, "amount": 25, "lifetime": 0.45,
			"velocity_min": 65.0, "velocity_max": 95.0,
			"scale_min": 1.0, "scale_max": 2.2, "spread": 16.0,
			"mesh_size": 3.5
		},
	}

	var config = trail_config.get(ship_data.type, trail_config[VnpTypes.ShipType.FRIGATE])

	engine_trail.position = Vector2(config.offset, 0)
	engine_trail.amount = config.amount
	engine_trail.lifetime = config.lifetime
	engine_trail.explosiveness = 0.0
	engine_trail.emitting = true

	# Create process material
	var material = ParticleProcessMaterial.new()
	material.direction = Vector3(-1, 0, 0)  # Emit backwards
	material.spread = config.spread
	material.initial_velocity_min = config.velocity_min
	material.initial_velocity_max = config.velocity_max
	material.damping_min = 25.0
	material.damping_max = 40.0
	material.scale_min = config.scale_min
	material.scale_max = config.scale_max
	material.color = team_color.lightened(0.5)

	# Brighter, more visible gradient
	var gradient = Gradient.new()
	gradient.set_color(0, Color.WHITE.lerp(team_color, 0.3))  # Start almost white
	gradient.add_point(0.2, team_color.lightened(0.5))
	gradient.add_point(0.5, team_color.lightened(0.2))
	gradient.set_color(1, Color(team_color.r * 0.2, team_color.g * 0.2, team_color.b * 0.2, 0))
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture

	engine_trail.process_material = material
	engine_trail.draw_pass_1 = _create_circle_mesh(config.mesh_size)

	add_child(engine_trail)

func _setup_muzzle_flash():
	muzzle_flash = Polygon2D.new()
	muzzle_flash.name = "MuzzleFlash"

	var weapon_type = ship_stats.get("weapon", VnpTypes.WeaponType.GUN)
	var flash_color = VnpTypes.get_weapon_color(ship_data.team, weapon_type)

	# Weapon-specific muzzle flash shapes and sizes
	match weapon_type:
		VnpTypes.WeaponType.GUN:
			# Railgun: Sharp, punchy burst
			muzzle_flash.polygon = PackedVector2Array([
				Vector2(0, -6), Vector2(18, 0), Vector2(0, 6)
			])
		VnpTypes.WeaponType.LASER:
			# Laser: Wide charging glow
			muzzle_flash.polygon = PackedVector2Array([
				Vector2(-4, -8), Vector2(14, -3), Vector2(16, 0),
				Vector2(14, 3), Vector2(-4, 8), Vector2(0, 0)
			])
		VnpTypes.WeaponType.MISSILE:
			# Missile: Fiery launch bloom
			muzzle_flash.polygon = PackedVector2Array([
				Vector2(-2, -10), Vector2(8, -5), Vector2(12, 0),
				Vector2(8, 5), Vector2(-2, 10), Vector2(2, 0)
			])
		VnpTypes.WeaponType.PDC:
			# PDC: Rapid small flash
			muzzle_flash.polygon = PackedVector2Array([
				Vector2(0, -3), Vector2(8, 0), Vector2(0, 3)
			])
		_:
			muzzle_flash.polygon = PackedVector2Array([
				Vector2(0, -4), Vector2(12, 0), Vector2(0, 4)
			])

	muzzle_flash.color = flash_color.lightened(0.6)
	muzzle_flash.visible = false

	# Position at front of ship based on type
	var flash_offsets = {
		VnpTypes.ShipType.FRIGATE: 16,
		VnpTypes.ShipType.DESTROYER: 22,
		VnpTypes.ShipType.CRUISER: 20,
		VnpTypes.ShipType.DEFENDER: 14,
		VnpTypes.ShipType.SHIELDER: 12,
		VnpTypes.ShipType.GRAVITON: 24,
		VnpTypes.ShipType.HARVESTER: 16,
	}
	muzzle_flash.position = Vector2(flash_offsets.get(ship_data.type, 15), 0)

	add_child(muzzle_flash)


func _setup_side_thrusters():
	var team_color = VnpTypes.get_team_color(ship_data.team)
	var ship_size = VnpTypes.get_ship_size(ship_data.type)

	# Thruster positions based on ship size
	var thruster_config = {
		VnpTypes.ShipSize.SMALL: {"offset_y": 8, "offset_x": -4, "amount": 8, "size": 2.0},
		VnpTypes.ShipSize.MEDIUM: {"offset_y": 10, "offset_x": -6, "amount": 12, "size": 2.5},
		VnpTypes.ShipSize.LARGE: {"offset_y": 14, "offset_x": -8, "amount": 15, "size": 3.0},
	}
	var config = thruster_config.get(ship_size, thruster_config[VnpTypes.ShipSize.SMALL])

	# Left thruster (fires when strafing right)
	side_thruster_left = _create_side_thruster(team_color, config)
	side_thruster_left.position = Vector2(config.offset_x, -config.offset_y)
	side_thruster_left.rotation = PI / 2  # Point downward (left side fires down to go right)
	side_thruster_left.emitting = false
	add_child(side_thruster_left)

	# Right thruster (fires when strafing left)
	side_thruster_right = _create_side_thruster(team_color, config)
	side_thruster_right.position = Vector2(config.offset_x, config.offset_y)
	side_thruster_right.rotation = -PI / 2  # Point upward (right side fires up to go left)
	side_thruster_right.emitting = false
	add_child(side_thruster_right)


func _create_side_thruster(color: Color, config: Dictionary) -> GPUParticles2D:
	var thruster = GPUParticles2D.new()
	thruster.amount = config.amount
	thruster.lifetime = 0.15
	thruster.explosiveness = 0.3

	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(1, 0, 0)  # Will be rotated by parent
	mat.spread = 25.0
	mat.initial_velocity_min = 60.0
	mat.initial_velocity_max = 100.0
	mat.damping_min = 30.0
	mat.damping_max = 50.0
	mat.scale_min = 0.5
	mat.scale_max = 1.2

	# Bright thruster color
	var grad = Gradient.new()
	grad.set_color(0, color.lightened(0.7))
	grad.set_color(1, Color(color.r, color.g, color.b, 0))
	var tex = GradientTexture1D.new()
	tex.gradient = grad
	mat.color_ramp = tex

	thruster.process_material = mat
	thruster.draw_pass_1 = QuadMesh.new()
	thruster.draw_pass_1.size = Vector2(config.size, config.size)

	return thruster


func _fire_side_thrusters(lateral_direction: float):
	# lateral_direction: positive = moving right, negative = moving left
	if abs(lateral_direction) < 0.2:
		# Not enough lateral movement
		if side_thruster_left:
			side_thruster_left.emitting = false
		if side_thruster_right:
			side_thruster_right.emitting = false
		return

	if lateral_direction > 0:
		# Moving right - fire left thruster
		if side_thruster_left:
			side_thruster_left.emitting = true
		if side_thruster_right:
			side_thruster_right.emitting = false
	else:
		# Moving left - fire right thruster
		if side_thruster_left:
			side_thruster_left.emitting = false
		if side_thruster_right:
			side_thruster_right.emitting = true


func _create_circle_mesh(radius: float) -> QuadMesh:
	var mesh = QuadMesh.new()
	mesh.size = Vector2(radius * 2, radius * 2)
	return mesh


func _setup_pdc_kill_zone():
	var pdc_color = VnpTypes.get_weapon_color(ship_data.team, VnpTypes.WeaponType.PDC)
	var pdc_range = ship_stats.get("range", 250)

	# Container for all PDC visuals
	pdc_kill_zone = Node2D.new()
	pdc_kill_zone.name = "PDCKillZone"
	add_child(pdc_kill_zone)

	# Outer range ring - dashed/segmented for "danger zone" feel
	pdc_range_ring = Line2D.new()
	pdc_range_ring.name = "RangeRing"
	pdc_range_ring.width = 2.0
	pdc_range_ring.default_color = Color(pdc_color.r, pdc_color.g, pdc_color.b, 0.3)

	# Create segmented ring (dashes)
	var ring_points = []
	var segments = 24
	for i in range(segments + 1):
		var angle = i * (PI * 2 / segments)
		# Skip every other segment for dashed effect
		if i % 2 == 0:
			ring_points.append(Vector2(cos(angle), sin(angle)) * pdc_range)
		else:
			ring_points.append(Vector2(cos(angle), sin(angle)) * pdc_range)
	pdc_range_ring.points = PackedVector2Array(ring_points)
	pdc_range_ring.antialiased = true
	pdc_kill_zone.add_child(pdc_range_ring)

	# Inner targeting ring
	var inner_ring = Line2D.new()
	inner_ring.name = "InnerRing"
	inner_ring.width = 1.5
	inner_ring.default_color = Color(pdc_color.r * 0.7, pdc_color.g * 0.7, pdc_color.b * 0.7, 0.25)
	var inner_points = []
	for i in range(33):
		var angle = i * (PI * 2 / 32)
		inner_points.append(Vector2(cos(angle), sin(angle)) * (pdc_range * 0.6))
	inner_ring.points = PackedVector2Array(inner_points)
	pdc_kill_zone.add_child(inner_ring)

	# Sweeping radar line - rotates continuously
	pdc_sweep_line = Line2D.new()
	pdc_sweep_line.name = "SweepLine"
	pdc_sweep_line.width = 3.0
	pdc_sweep_line.default_color = Color(pdc_color.r, pdc_color.g, pdc_color.b, 0.6)
	pdc_sweep_line.add_point(Vector2.ZERO)
	pdc_sweep_line.add_point(Vector2(pdc_range, 0))
	pdc_sweep_line.antialiased = true
	pdc_kill_zone.add_child(pdc_sweep_line)

	# Sweep trail (fading arc behind the sweep line)
	var sweep_trail = Polygon2D.new()
	sweep_trail.name = "SweepTrail"
	var trail_points = [Vector2.ZERO]
	var trail_arc = 0.4  # Radians of trail
	for i in range(9):
		var angle = -trail_arc + (trail_arc * i / 8)
		trail_points.append(Vector2(cos(angle), sin(angle)) * pdc_range)
	sweep_trail.polygon = PackedVector2Array(trail_points)
	sweep_trail.color = Color(pdc_color.r, pdc_color.g, pdc_color.b, 0.15)
	pdc_kill_zone.add_child(sweep_trail)

	# Cross-hairs at center
	var crosshair_h = Line2D.new()
	crosshair_h.width = 1.0
	crosshair_h.default_color = Color(pdc_color.r, pdc_color.g, pdc_color.b, 0.4)
	crosshair_h.add_point(Vector2(-15, 0))
	crosshair_h.add_point(Vector2(15, 0))
	pdc_kill_zone.add_child(crosshair_h)

	var crosshair_v = Line2D.new()
	crosshair_v.width = 1.0
	crosshair_v.default_color = Color(pdc_color.r, pdc_color.g, pdc_color.b, 0.4)
	crosshair_v.add_point(Vector2(0, -15))
	crosshair_v.add_point(Vector2(0, 15))
	pdc_kill_zone.add_child(crosshair_v)

	# Start sweep animation
	_animate_pdc_sweep()


func _animate_pdc_sweep():
	if not is_instance_valid(pdc_sweep_line):
		return

	# Continuous rotation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(pdc_sweep_line, "rotation", TAU, 2.0).from(0.0)

	# Also rotate the trail
	var trail = pdc_kill_zone.get_node_or_null("SweepTrail")
	if trail:
		var trail_tween = create_tween()
		trail_tween.set_loops()
		trail_tween.tween_property(trail, "rotation", TAU, 2.0).from(0.0)

	# Pulse the range ring
	var pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(pdc_range_ring, "modulate:a", 0.5, 1.0).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(pdc_range_ring, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE)


func _setup_shield_bubble():
	shield_bubble = Line2D.new()
	shield_bubble.name = "ShieldBubble"

	var shield_color = VnpTypes.get_weapon_color(ship_data.team, VnpTypes.WeaponType.SHIELD)
	var radius = ship_stats.get("shield_radius", 120)

	# Main shield ring - brighter, thicker
	shield_bubble.default_color = Color(shield_color.r, shield_color.g, shield_color.b, 0.6)
	shield_bubble.width = 4.0

	var points = []
	for i in range(49):  # More points for smoother circle
		var angle = i * (PI * 2 / 48)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	shield_bubble.points = PackedVector2Array(points)
	shield_bubble.antialiased = true
	add_child(shield_bubble)

	# Inner glow ring - softer, larger
	var inner_glow = Line2D.new()
	inner_glow.name = "ShieldInnerGlow"
	inner_glow.default_color = Color(shield_color.r, shield_color.g, shield_color.b, 0.25)
	inner_glow.width = 12.0
	inner_glow.points = shield_bubble.points
	inner_glow.antialiased = true
	add_child(inner_glow)

	# Hexagonal pattern overlay for tech feel
	var hex_pattern = Line2D.new()
	hex_pattern.name = "ShieldHexPattern"
	hex_pattern.default_color = Color(shield_color.r * 1.2, shield_color.g * 1.2, shield_color.b * 1.2, 0.3)
	hex_pattern.width = 1.5
	var hex_points = []
	for i in range(7):  # Hexagon
		var angle = i * (PI * 2 / 6)
		hex_points.append(Vector2(cos(angle), sin(angle)) * (radius * 0.7))
	hex_pattern.points = PackedVector2Array(hex_points)
	add_child(hex_pattern)

	# Pulse animation
	_animate_shield_pulse()


func _animate_shield_pulse():
	if not is_instance_valid(shield_bubble):
		return

	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(shield_bubble, "modulate:a", 0.3, 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(shield_bubble, "modulate:a", 0.7, 1.0).set_trans(Tween.TRANS_SINE)


func _setup_gravity_well():
	var gravity_color = VnpTypes.get_weapon_color(ship_data.team, VnpTypes.WeaponType.GRAVITY)
	var gravity_radius = ship_stats.get("gravity_radius", 140)

	# Container for all gravity well elements
	gravity_well = Node2D.new()
	gravity_well.name = "GravityWell"
	add_child(gravity_well)

	# Dark void center - smaller, tighter core
	var void_center = Polygon2D.new()
	var void_points = []
	for i in range(25):
		var angle = i * (PI * 2 / 24)
		void_points.append(Vector2(cos(angle), sin(angle)) * 22)  # Smaller void
	void_center.polygon = PackedVector2Array(void_points)
	void_center.color = Color(0, 0, 0, 0.6)
	gravity_well.add_child(void_center)

	# Outer ring - slowly rotating, subtler
	gravity_ring_outer = Line2D.new()
	gravity_ring_outer.name = "OuterRing"
	gravity_ring_outer.width = 3.0  # Thinner
	gravity_ring_outer.default_color = Color(gravity_color.r * 0.5, gravity_color.g * 0.5, gravity_color.b * 0.5, 0.4)
	var outer_points = []
	for i in range(49):
		var angle = i * (PI * 2 / 48)
		outer_points.append(Vector2(cos(angle), sin(angle)) * gravity_radius)
	gravity_ring_outer.points = PackedVector2Array(outer_points)
	gravity_ring_outer.antialiased = true
	gravity_well.add_child(gravity_ring_outer)

	# Inner ring - faster rotating, brighter but smaller
	gravity_ring_inner = Line2D.new()
	gravity_ring_inner.name = "InnerRing"
	gravity_ring_inner.width = 2.5  # Thinner
	gravity_ring_inner.default_color = Color(gravity_color.r, gravity_color.g, gravity_color.b, 0.6)
	var inner_points = []
	for i in range(33):
		var angle = i * (PI * 2 / 32)
		inner_points.append(Vector2(cos(angle), sin(angle)) * (gravity_radius * 0.55))
	gravity_ring_inner.points = PackedVector2Array(inner_points)
	gravity_ring_inner.antialiased = true
	gravity_well.add_child(gravity_ring_inner)

	# Swirling vortex particles - fewer, tighter spiral
	gravity_vortex_particles = GPUParticles2D.new()
	gravity_vortex_particles.name = "VortexParticles"
	gravity_vortex_particles.amount = 30  # Reduced from 60
	gravity_vortex_particles.lifetime = 1.5
	gravity_vortex_particles.emitting = true

	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = gravity_radius
	mat.emission_ring_inner_radius = gravity_radius * 0.75
	mat.emission_ring_height = 0.0

	# Particles spiral inward - tighter spiral
	mat.radial_accel_min = -120.0
	mat.radial_accel_max = -160.0
	mat.tangential_accel_min = 60.0
	mat.tangential_accel_max = 100.0
	mat.initial_velocity_min = 15.0
	mat.initial_velocity_max = 30.0
	mat.scale_min = 1.0
	mat.scale_max = 2.0

	# Color gradient - bright at edge, fade as pulled in
	var grad = Gradient.new()
	grad.set_color(0, Color(gravity_color.r * 1.3, gravity_color.g * 1.3, gravity_color.b * 1.3, 0.7))
	grad.add_point(0.5, gravity_color)
	grad.set_color(1, Color(0, 0, 0, 0))
	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex

	gravity_vortex_particles.process_material = mat
	gravity_vortex_particles.draw_pass_1 = QuadMesh.new()
	gravity_vortex_particles.draw_pass_1.size = Vector2(3, 3)  # Smaller particles
	gravity_well.add_child(gravity_vortex_particles)

	# Animate rings rotation
	_animate_gravity_well()

	# Add ship to graviton group for projectile detection
	add_to_group("gravitons")


func _animate_gravity_well():
	if not is_instance_valid(gravity_ring_outer) or not is_instance_valid(gravity_ring_inner):
		return

	# Continuous rotation animation
	var outer_tween = create_tween()
	outer_tween.set_loops()
	outer_tween.tween_property(gravity_ring_outer, "rotation", TAU, 8.0).from(0.0)

	var inner_tween = create_tween()
	inner_tween.set_loops()
	inner_tween.tween_property(gravity_ring_inner, "rotation", -TAU, 4.0).from(0.0)  # Counter-rotate

	# Pulsing intensity
	var pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(gravity_well, "modulate:a", 0.6, 1.5).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(gravity_well, "modulate:a", 1.0, 1.5).set_trans(Tween.TRANS_SINE)


func _setup_starbase_visuals():
	# Star Base: Massive structure with imposing visual presence
	var turbo_color = VnpTypes.get_weapon_color(ship_data.team, VnpTypes.WeaponType.TURBOLASER)
	var base_range = ship_stats.get("range", 600)

	# Container for starbase extra visuals
	starbase_structure = Node2D.new()
	starbase_structure.name = "StarbaseStructure"
	add_child(starbase_structure)

	# Danger zone range ring - pulsing warning
	starbase_range_ring = Line2D.new()
	starbase_range_ring.name = "RangeRing"
	starbase_range_ring.width = 3.0
	starbase_range_ring.default_color = Color(turbo_color.r, turbo_color.g, turbo_color.b, 0.25)
	var ring_points = []
	for i in range(65):
		var angle = i * (PI * 2 / 64)
		ring_points.append(Vector2(cos(angle), sin(angle)) * base_range)
	starbase_range_ring.points = PackedVector2Array(ring_points)
	starbase_range_ring.antialiased = true
	starbase_structure.add_child(starbase_range_ring)

	# Inner structure ring - hexagonal pattern for tech feel
	var inner_hex = Line2D.new()
	inner_hex.name = "InnerHex"
	inner_hex.width = 2.5
	inner_hex.default_color = Color(turbo_color.r * 0.8, turbo_color.g * 0.8, turbo_color.b * 0.8, 0.4)
	var hex_points = []
	for i in range(7):
		var angle = i * (PI * 2 / 6)
		hex_points.append(Vector2(cos(angle), sin(angle)) * 80)
	inner_hex.points = PackedVector2Array(hex_points)
	starbase_structure.add_child(inner_hex)

	# Weapon turret indicators (4 turrets around the structure)
	for i in range(4):
		var turret_angle = i * (PI / 2) + PI / 4  # 45, 135, 225, 315 degrees
		var turret_pos = Vector2(cos(turret_angle), sin(turret_angle)) * 50

		# Turret mount
		var turret = Polygon2D.new()
		turret.polygon = PackedVector2Array([
			Vector2(-6, -4), Vector2(6, -4), Vector2(8, 0), Vector2(6, 4), Vector2(-6, 4)
		])
		turret.position = turret_pos
		turret.rotation = turret_angle
		turret.color = VnpTypes.get_team_color(ship_data.team).darkened(0.3)
		starbase_structure.add_child(turret)

	# Animated sensor sweep
	var sweep = Line2D.new()
	sweep.name = "SensorSweep"
	sweep.width = 2.0
	sweep.default_color = Color(turbo_color.r, turbo_color.g, turbo_color.b, 0.5)
	sweep.add_point(Vector2.ZERO)
	sweep.add_point(Vector2(base_range, 0))
	starbase_structure.add_child(sweep)

	# Animate the sweep rotation
	var sweep_tween = create_tween()
	sweep_tween.set_loops()
	sweep_tween.tween_property(sweep, "rotation", TAU, 4.0).from(0.0)

	# Pulse the range ring
	var pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(starbase_range_ring, "modulate:a", 0.4, 1.5).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(starbase_range_ring, "modulate:a", 1.0, 1.5).set_trans(Tween.TRANS_SINE)


func _setup_turret_visuals():
	# Base Turret: Compact defensive emplacement with rotating gun barrel
	var team_color = VnpTypes.get_team_color(ship_data.team)
	var gun_color = VnpTypes.get_weapon_color(ship_data.team, VnpTypes.WeaponType.GUN)
	var base_range = ship_stats.get("range", 350)

	# Container for turret extra visuals
	var turret_structure = Node2D.new()
	turret_structure.name = "TurretStructure"
	add_child(turret_structure)

	# Range ring - subtle defensive perimeter indicator
	var range_ring = Line2D.new()
	range_ring.name = "RangeRing"
	range_ring.width = 2.0
	range_ring.default_color = Color(gun_color.r, gun_color.g, gun_color.b, 0.2)
	var ring_points = []
	for i in range(49):
		var angle = i * (PI * 2 / 48)
		ring_points.append(Vector2(cos(angle), sin(angle)) * base_range)
	range_ring.points = PackedVector2Array(ring_points)
	range_ring.antialiased = true
	turret_structure.add_child(range_ring)

	# Gun barrel - extends from center
	var barrel = Polygon2D.new()
	barrel.name = "GunBarrel"
	barrel.polygon = PackedVector2Array([
		Vector2(8, -3), Vector2(25, -2), Vector2(28, 0), Vector2(25, 2), Vector2(8, 3)
	])
	barrel.color = team_color.darkened(0.2)
	turret_structure.add_child(barrel)

	# Base platform ring - hexagonal
	var base_hex = Line2D.new()
	base_hex.name = "BasePlatform"
	base_hex.width = 2.5
	base_hex.default_color = team_color.darkened(0.3)
	var hex_points = []
	for i in range(7):
		var angle = i * (PI * 2 / 6)
		hex_points.append(Vector2(cos(angle), sin(angle)) * 20)
	base_hex.points = PackedVector2Array(hex_points)
	turret_structure.add_child(base_hex)

	# Slow pulse on range ring
	var pulse_tween = create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(range_ring, "modulate:a", 0.5, 2.0).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(range_ring, "modulate:a", 1.0, 2.0).set_trans(Tween.TRANS_SINE)


func _show_muzzle_flash():
	muzzle_flash.visible = true
	muzzle_flash.modulate = Color.WHITE

	var tween = create_tween()
	tween.tween_property(muzzle_flash, "modulate:a", 0.0, 0.1)
	tween.tween_callback(func(): muzzle_flash.visible = false)


func _show_railgun_power_surge():
	# Dramatic muzzle blast particles for railgun
	var blast = GPUParticles2D.new()
	blast.amount = 25
	blast.lifetime = 0.25
	blast.one_shot = true
	blast.explosiveness = 1.0
	blast.emitting = true

	var mat = ParticleProcessMaterial.new()
	mat.direction = Vector3(1, 0, 0)  # Forward
	mat.spread = 35.0
	mat.initial_velocity_min = 150.0
	mat.initial_velocity_max = 300.0
	mat.damping_min = 100.0
	mat.damping_max = 150.0
	mat.scale_min = 1.5
	mat.scale_max = 3.0

	# Bright flash color based on team
	var flash_color = VnpTypes.get_weapon_color(ship_data.team, VnpTypes.WeaponType.GUN)
	var grad = Gradient.new()
	grad.set_color(0, Color.WHITE)
	grad.add_point(0.2, flash_color.lightened(0.5))
	grad.set_color(1, Color(flash_color.r, flash_color.g, flash_color.b, 0))
	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = grad
	mat.color_ramp = grad_tex

	blast.process_material = mat
	blast.draw_pass_1 = QuadMesh.new()
	blast.draw_pass_1.size = Vector2(4, 4)

	# Position at muzzle
	blast.position = muzzle_flash.position
	add_child(blast)

	# Recoil flash ring
	var ring = Line2D.new()
	ring.width = 4.0
	ring.default_color = flash_color.lightened(0.3)
	var ring_points = []
	for i in range(17):
		var angle = i * (PI * 2 / 16)
		ring_points.append(Vector2(cos(angle), sin(angle)) * 8)
	ring.points = PackedVector2Array(ring_points)
	ring.position = muzzle_flash.position
	add_child(ring)

	# Animate ring expansion
	var ring_tween = create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector2(3.5, 3.5), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.15)
	ring_tween.tween_callback(func(): ring.queue_free())

	# Cleanup blast after particles finish
	get_tree().create_timer(0.5).timeout.connect(func():
		if is_instance_valid(blast):
			blast.queue_free()
	)

func select():
	selection_indicator.visible = true

func deselect():
	selection_indicator.visible = false

func _physics_process(delta):
	var current_state = store.get_state()
	if not current_state.ships.has(ship_data.id):
		queue_free()
		return

	var my_current_data = current_state.ships[ship_data.id]
	
	var target_ship_data = null
	if my_current_data.target and current_state.ships.has(my_current_data.target):
		target_ship_data = current_state.ships.get(my_current_data.target)

	# Rotate to look at target
	if my_current_data.state == "attacking" and target_ship_data:
		look_at(target_ship_data.position)
	elif my_current_data.state == "moving":
		if my_current_data.target is Vector2 and position.distance_to(my_current_data.target) > 1:
			look_at(my_current_data.target)
	
	# Defensive ships run PDC/shield/gravity continuously
	if ship_data.type == VnpTypes.ShipType.DEFENDER:
		_run_pdc_defense(delta)
	elif ship_data.type == VnpTypes.ShipType.SHIELDER:
		_run_shield_defense(delta, current_state)
	elif ship_data.type == VnpTypes.ShipType.GRAVITON:
		_run_gravity_defense(delta, current_state)

	match my_current_data.state:
		"idle":
			# Check adherence mode - LOOSE = old simple behavior, TIGHT = formation-aware
			var is_loose = true
			if ai_controller:
				is_loose = ai_controller.get_adherence(ship_data.team) == VnpTypes.FleetAdherence.LOOSE

			if is_loose:
				# LOOSE: Simple old behavior - attack nearest enemy or push to center
				# BUT: Defensive ships always try to stick with combat ships
				var is_support_ship = ship_data.type in [VnpTypes.ShipType.DEFENDER, VnpTypes.ShipType.SHIELDER, VnpTypes.ShipType.GRAVITON]

				if is_support_ship:
					# Support ships: Find nearby combat ship to escort
					var escort_target = _find_combat_ship_to_escort(current_state)
					if escort_target != -1:
						var ally_pos = current_state.ships[escort_target].position
						var dist_to_ally = position.distance_to(ally_pos)

						# Also check for enemies - attack if very close
						var target_id = _find_nearest_enemy(current_state)
						if target_id != -1 and current_state.ships.has(target_id):
							var enemy_pos = current_state.ships[target_id].position
							var dist_to_enemy = position.distance_to(enemy_pos)
							# Only attack if enemy is closer than ally AND within range
							if dist_to_enemy < ship_stats.get("range", 300) * 1.5:
								_dispatch_state_change("attacking", target_id)
								return

						# Move toward combat ship if too far
						if dist_to_ally > 150:  # Stay within 150 units of combat ships
							_dispatch_state_change("moving", ally_pos)
						else:
							# Close enough - match the combat ship's behavior
							# If they're attacking, help attack. Otherwise idle nearby.
							var ally_data = current_state.ships[escort_target]
							if ally_data.state == "attacking" and ally_data.target:
								_dispatch_state_change("attacking", ally_data.target)
							else:
								# Just drift near ally
								var offset = Vector2(randf_range(-80, 80), randf_range(-80, 80))
								_dispatch_state_change("moving", ally_pos + offset)
					else:
						# No combat ships to escort - fall back to normal behavior
						var target_id = _find_nearest_enemy(current_state)
						if target_id != -1:
							_dispatch_state_change("attacking", target_id)
						else:
							var viewport_size = get_viewport_rect().size
							var center = viewport_size * 0.75
							var push_target = center + Vector2(randf_range(-200, 200), randf_range(-200, 200))
							_dispatch_state_change("moving", push_target)
				else:
					# Combat ships: Normal LOOSE behavior
					var target_id = _find_nearest_enemy(current_state)
					var enemy_in_range = false
					if target_id != -1 and current_state.ships.has(target_id):
						var enemy_pos = current_state.ships[target_id].position
						var dist = position.distance_to(enemy_pos)
						if dist < ship_stats.get("range", 300) * 2.5:
							enemy_in_range = true

					if enemy_in_range and target_id != -1:
						_dispatch_state_change("attacking", target_id)
					else:
						# Check for rally point first
						var rally_target = _get_rally_point(current_state)
						if rally_target != Vector2.ZERO:
							# Move towards rally point with some spread
							var offset = Vector2(randf_range(-50, 50), randf_range(-50, 50))
							_dispatch_state_change("moving", rally_target + offset)
						else:
							# Push towards center
							var viewport_size = get_viewport_rect().size
							var center = viewport_size * 0.75
							var push_target = center + Vector2(randf_range(-200, 200), randf_range(-200, 200))
							_dispatch_state_change("moving", push_target)
			else:
				# TIGHT: Formation-aware behavior
				var target_id = _find_nearest_enemy_for_formation(current_state)
				if target_id != -1:
					_dispatch_state_change("attacking", target_id)
				else:
					var move_target = _get_formation_target()
					_dispatch_state_change("moving", move_target)

		"moving":
			var target_pos = my_current_data.target
			if target_pos is Vector2:
				# Check for enemies while moving - attack if close
				var nearby_enemy = _find_nearest_enemy(current_state)
				if nearby_enemy != -1 and current_state.ships.has(nearby_enemy):
					var enemy_pos = current_state.ships[nearby_enemy].position
					var dist = position.distance_to(enemy_pos)
					if dist < ship_stats.get("range", 300) * 1.5:
						# Enemy encountered! Attack!
						_dispatch_state_change("attacking", nearby_enemy)
						return

				_move_to(target_pos)
				if position.distance_to(target_pos) < 30.0:
					# Reached destination - go back to idle to find new objective
					_dispatch_state_change("idle", null)
			else: # Invalid target for moving
				_dispatch_state_change("idle", null)

		"supporting":
			# Defensive ships follow their supported ally (legacy, now all push)
			if my_current_data.target and current_state.ships.has(my_current_data.target):
				var ally_data = current_state.ships[my_current_data.target]
				var dist = position.distance_to(ally_data.position)
				if dist > ship_stats.get("range", 150):
					_move_to(ally_data.position)
				else:
					velocity = Vector2.ZERO
					move_and_slide()
			else:
				_dispatch_state_change("idle", null)

		"attacking":
			if not target_ship_data:
				_dispatch_state_change("idle", null)
				return

			# Only check fleet constraints in TIGHT adherence mode
			var is_loose = true
			if ai_controller:
				is_loose = ai_controller.get_adherence(ship_data.team) == VnpTypes.FleetAdherence.LOOSE

			if not is_loose and _should_return_to_fleet():
				_dispatch_state_change("idle", null)
				return

			var distance_to_target = position.distance_to(target_ship_data.position)
			var ship_size = VnpTypes.get_ship_size(ship_data.type)

			# Update threat assessment periodically
			threat_assessment_cooldown -= delta
			if threat_assessment_cooldown <= 0:
				current_threat = _assess_threat(target_ship_data, current_state)
				threat_assessment_cooldown = 0.5  # Re-assess every 0.5s

				# ATTACK-MOVE: Re-evaluate target based on rally point
				# Switch to better targets that are more aligned with our objective
				var better_target = _find_better_rally_target(current_state, my_current_data.target)
				if better_target != -1 and better_target != my_current_data.target:
					_dispatch_state_change("attacking", better_target)
					return

			# Get tactical behavior based on threat
			var tactics = _get_tactical_behavior(current_threat, ship_size)
			var effective_range = ship_stats.range * tactics.range_mult

			# Rush behavior - close distance aggressively
			if tactics.rush and distance_to_target > effective_range * 0.7:
				_rush_target(target_ship_data.position, delta)
			elif distance_to_target > ship_stats.range:
				_move_to(target_ship_data.position)
			else:
				# Size-based combat movement with tactical modifiers
				match ship_size:
					VnpTypes.ShipSize.SMALL:
						# Small ships: Constant strafing runs - never stop!
						_strafe_around_target_tactical(target_ship_data.position, delta, tactics, current_state)
					VnpTypes.ShipSize.MEDIUM:
						# Medium ships: Slow orbit while firing
						var orbit_speed = 0.4 if not tactics.rush else 0.6
						_orbit_target(target_ship_data.position, delta, orbit_speed)
					VnpTypes.ShipSize.LARGE:
						# Large ships: Brake to stop and fire (heavy with momentum)
						# Gradual brake rather than instant stop
						current_velocity = current_velocity.lerp(Vector2.ZERO, 2.0 * delta)
						if current_velocity.length() < 5:
							current_velocity = Vector2.ZERO
						velocity = current_velocity
						move_and_slide()
						_fire_side_thrusters(0)
					VnpTypes.ShipSize.MASSIVE:
						# Star Bases: Completely stationary - just rotate to face target
						current_velocity = Vector2.ZERO
						velocity = Vector2.ZERO
						# Slowly rotate turrets towards target
						var to_target = target_ship_data.position - position
						var target_angle = to_target.angle()
						rotation = lerp_angle(rotation, target_angle, 0.5 * delta)

				if fire_rate_timer.is_stopped():
					fire_rate_timer.start()

	if self.position != my_current_data.position:
		store.dispatch({
			"type": "UPDATE_SHIP_POSITION",
			"ship_id": ship_data.id,
			"position": self.position
		})

func _move_to(target_position):
	# Asteroids-style thrust movement
	var direction = position.direction_to(target_position)
	var thrust_force = direction * ship_stats.speed * THRUST_MULTIPLIER

	# Apply thrust as acceleration
	current_velocity += thrust_force * get_physics_process_delta_time()

	# Clamp to max speed
	var max_speed = ship_stats.speed * 1.2  # Slight overspeed allowed with momentum
	if current_velocity.length() > max_speed:
		current_velocity = current_velocity.normalized() * max_speed

	# Apply space drag (subtle friction)
	current_velocity = current_velocity.lerp(Vector2.ZERO, SPACE_DRAG * get_physics_process_delta_time())

	velocity = current_velocity
	move_and_slide()

	# Rotate to face movement direction (with smooth turning)
	if current_velocity.length() > 10:
		var target_angle = direction.angle()
		rotation = lerp_angle(rotation, target_angle, 5.0 * get_physics_process_delta_time())


func _rush_target(target_pos: Vector2, delta: float):
	# Aggressive close-distance maneuver with momentum
	var to_target = (target_pos - position).normalized()

	# Add slight evasive weaving while rushing
	var weave = Vector2(sin(Time.get_ticks_msec() * 0.012), cos(Time.get_ticks_msec() * 0.01)) * 0.15
	var thrust_dir = (to_target + weave).normalized()

	# Apply aggressive thrust (burst speed when rushing)
	var rush_thrust = thrust_dir * ship_stats.speed * THRUST_MULTIPLIER * 1.3
	current_velocity += rush_thrust * delta

	# Higher max speed when rushing
	var max_speed = ship_stats.speed * 1.4
	if current_velocity.length() > max_speed:
		current_velocity = current_velocity.normalized() * max_speed

	# Less drag when rushing (full burn)
	current_velocity = current_velocity.lerp(Vector2.ZERO, SPACE_DRAG * 0.5 * delta)

	velocity = current_velocity
	move_and_slide()

	# Smooth rotation towards target
	var target_angle = to_target.angle()
	rotation = lerp_angle(rotation, target_angle, 8.0 * delta)

	# Minimal side thrusters during rush
	var facing_dir = Vector2.RIGHT.rotated(rotation)
	var lateral = facing_dir.rotated(PI/2).dot(current_velocity.normalized())
	_fire_side_thrusters(lateral * 0.3)


func _strafe_around_target(target_pos: Vector2, delta: float):
	# Fast strafing runs with momentum - small ships dart around with drift
	var to_target = target_pos - position
	var distance = to_target.length()
	var optimal_range = ship_stats.range * 0.8

	# Update strafe angle continuously
	strafe_angle += strafe_direction * delta * 2.5

	# Occasionally reverse direction for unpredictable movement
	if randf() < 0.01:
		strafe_direction *= -1

	# Calculate strafe position - circle around target
	var strafe_offset = Vector2(cos(strafe_angle), sin(strafe_angle)) * optimal_range
	var desired_pos = target_pos + strafe_offset

	# Thrust towards strafe position
	var thrust_dir = (desired_pos - position).normalized()

	# Add weaving for evasive feel
	var weave = Vector2(sin(Time.get_ticks_msec() * 0.008), cos(Time.get_ticks_msec() * 0.006)) * 0.3
	thrust_dir = (thrust_dir + weave).normalized()

	# Apply thrust
	var strafe_thrust = thrust_dir * ship_stats.speed * THRUST_MULTIPLIER
	current_velocity += strafe_thrust * delta

	# Max speed
	if current_velocity.length() > ship_stats.speed * 1.2:
		current_velocity = current_velocity.normalized() * ship_stats.speed * 1.2

	# Light drag for drifty feel
	current_velocity = current_velocity.lerp(Vector2.ZERO, SPACE_DRAG * 0.7 * delta)

	velocity = current_velocity
	move_and_slide()

	# Face the target while strafing
	var target_angle = to_target.angle()
	rotation = lerp_angle(rotation, target_angle, 6.0 * delta)

	# Fire side thrusters based on lateral movement
	var facing_dir = Vector2.RIGHT.rotated(rotation)
	var lateral = facing_dir.rotated(PI/2).dot(current_velocity.normalized())
	_fire_side_thrusters(lateral)


func _strafe_around_target_tactical(target_pos: Vector2, delta: float, tactics: Dictionary, state: Dictionary):
	# Tactical strafing with momentum and scatter/flank behaviors
	var optimal_range = ship_stats.range * tactics.range_mult
	var orbit_speed = tactics.orbit_speed

	# Update strafe angle
	strafe_angle += strafe_direction * delta * orbit_speed

	# More frequent direction changes when evading AOE
	var direction_change_chance = 0.01
	if tactics.scatter:
		direction_change_chance = 0.03

	if randf() < direction_change_chance:
		strafe_direction *= -1

	# Calculate base strafe position
	var strafe_offset = Vector2(cos(strafe_angle), sin(strafe_angle)) * optimal_range
	var desired_pos = target_pos + strafe_offset

	# Apply scatter - push away from nearby allies
	if tactics.scatter:
		var scatter_force = _calculate_scatter_force(state)
		desired_pos += scatter_force * 50

	# Apply flank - try to get behind the target
	if tactics.flank:
		var flank_offset = _calculate_flank_position(target_pos, state)
		desired_pos = desired_pos.lerp(flank_offset, 0.3)

	# Thrust towards desired position
	var thrust_dir = (desired_pos - position).normalized()

	# Weaving intensity based on threat
	var weave_intensity = 0.3
	if tactics.scatter:
		weave_intensity = 0.5
	var weave = Vector2(sin(Time.get_ticks_msec() * 0.008), cos(Time.get_ticks_msec() * 0.006)) * weave_intensity
	thrust_dir = (thrust_dir + weave).normalized()

	# Apply thrust with momentum
	var strafe_thrust = thrust_dir * ship_stats.speed * THRUST_MULTIPLIER
	current_velocity += strafe_thrust * delta

	# Max speed
	if current_velocity.length() > ship_stats.speed * 1.2:
		current_velocity = current_velocity.normalized() * ship_stats.speed * 1.2

	# Drag - less when scattering for more drift
	var drag_mult = 0.5 if tactics.scatter else 0.7
	current_velocity = current_velocity.lerp(Vector2.ZERO, SPACE_DRAG * drag_mult * delta)

	velocity = current_velocity
	move_and_slide()

	# Face target
	var to_target = target_pos - position
	var target_angle = to_target.angle()
	rotation = lerp_angle(rotation, target_angle, 6.0 * delta)

	var facing_dir = Vector2.RIGHT.rotated(rotation)
	var lateral = facing_dir.rotated(PI/2).dot(current_velocity.normalized())
	_fire_side_thrusters(lateral)


func _calculate_scatter_force(state: Dictionary) -> Vector2:
	# Push away from nearby allies to avoid clustering (bad vs AOE)
	var scatter = Vector2.ZERO
	var ally_count = 0

	for ship_id in state.ships:
		var ship = state.ships[ship_id]
		if ship.team == ship_data.team and ship_id != ship_data.id:
			var to_ally = position - ship.position
			var dist = to_ally.length()
			if dist < 100 and dist > 0:  # Too close!
				scatter += to_ally.normalized() * (100 - dist) / 100
				ally_count += 1

	if ally_count > 0:
		scatter /= ally_count

	return scatter


func _calculate_flank_position(target_pos: Vector2, state: Dictionary) -> Vector2:
	# Try to position behind the target (opposite side from most allies)
	var ally_center = Vector2.ZERO
	var ally_count = 0

	for ship_id in state.ships:
		var ship = state.ships[ship_id]
		if ship.team == ship_data.team and ship_id != ship_data.id:
			ally_center += ship.position
			ally_count += 1

	if ally_count == 0:
		return target_pos + Vector2(cos(strafe_angle), sin(strafe_angle)) * ship_stats.range * 0.8

	ally_center /= ally_count

	# Position on opposite side of target from allies
	var target_to_allies = (ally_center - target_pos).normalized()
	var flank_dir = -target_to_allies  # Opposite side
	return target_pos + flank_dir * ship_stats.range * 0.8


func _orbit_target(target_pos: Vector2, delta: float, speed_mult: float = 0.5):
	# Slower orbit for medium ships with momentum - controlled but weighty
	var to_target = target_pos - position
	var distance = to_target.length()
	var optimal_range = ship_stats.range * 0.85

	# Slow orbit
	strafe_angle += strafe_direction * delta * 1.2

	# Calculate orbit position
	var orbit_offset = Vector2(cos(strafe_angle), sin(strafe_angle)) * optimal_range
	var desired_pos = target_pos + orbit_offset

	# Thrust towards orbit position
	var thrust_dir = (desired_pos - position).normalized()
	var orbit_thrust = thrust_dir * ship_stats.speed * THRUST_MULTIPLIER * speed_mult
	current_velocity += orbit_thrust * delta

	# Max speed for orbit (slower than strafing)
	var max_speed = ship_stats.speed * speed_mult * 1.2
	if current_velocity.length() > max_speed:
		current_velocity = current_velocity.normalized() * max_speed

	# More drag for controlled feel
	current_velocity = current_velocity.lerp(Vector2.ZERO, SPACE_DRAG * delta)

	velocity = current_velocity
	move_and_slide()

	# Face the target with smooth rotation
	var target_angle = to_target.angle()
	rotation = lerp_angle(rotation, target_angle, 4.0 * delta)

	# Fire side thrusters (less intense than strafing)
	var facing_dir = Vector2.RIGHT.rotated(rotation)
	var lateral = facing_dir.rotated(PI/2).dot(current_velocity.normalized())
	_fire_side_thrusters(lateral * 0.7)


func _assess_threat(target_ship_data: Dictionary, state: Dictionary) -> int:
	# Analyze the target and nearby enemies to determine tactical approach
	# Returns ThreatType enum

	if not target_ship_data:
		return ThreatType.NONE

	var target_type = target_ship_data.type
	var target_stats = VnpTypes.SHIP_STATS.get(target_type, {})
	var target_weapon = target_stats.get("weapon", -1)
	var target_size = VnpTypes.get_ship_size(target_type)

	# Count nearby enemies of each type for swarm detection
	var nearby_enemies = 0
	var nearby_frigates = 0
	var nearby_cruisers = 0

	for ship_id in state.ships:
		var ship = state.ships[ship_id]
		if ship.team != ship_data.team:
			var dist = position.distance_to(ship.position)
			if dist < 400:  # Tactical awareness range
				nearby_enemies += 1
				if ship.type == VnpTypes.ShipType.FRIGATE:
					nearby_frigates += 1
				elif ship.type == VnpTypes.ShipType.CRUISER:
					nearby_cruisers += 1

	# Determine threat type based on what we're facing

	# Fast swarm - multiple frigates nearby
	if nearby_frigates >= 3:
		return ThreatType.FAST_SWARM

	# AOE spray - facing Defender PDC or multiple cruisers
	if target_type == VnpTypes.ShipType.DEFENDER or nearby_cruisers >= 2:
		return ThreatType.AOE_SPRAY

	# Sniper - facing Destroyer (instant hit laser)
	if target_type == VnpTypes.ShipType.DESTROYER:
		return ThreatType.SNIPER

	# Slow heavy - facing Cruiser (slow missiles, can evade)
	if target_type == VnpTypes.ShipType.CRUISER:
		return ThreatType.SLOW_HEAVY

	# Support ships - Shielder, Graviton (priority targets)
	if target_type in [VnpTypes.ShipType.SHIELDER, VnpTypes.ShipType.GRAVITON]:
		return ThreatType.SUPPORT

	return ThreatType.NONE


func _get_tactical_behavior(threat: int, ship_size: int) -> Dictionary:
	# Returns tactical parameters based on threat and our ship size
	# User quote: "if they know they're attacking a ship that's slow and single fire capability,
	# close distance quickly and kill while evading the attack or swarm it if its worth the kill.
	# if it has short range AOE spray, scatter and stay back, or try to flank around"

	var behavior = {
		"range_mult": 0.8,      # How close to get (mult of weapon range)
		"orbit_speed": 2.5,     # How fast to circle
		"scatter": false,       # Should we spread out from allies?
		"rush": false,          # Should we close distance aggressively?
		"flank": false,         # Should we try to get behind?
		"keep_distance": false, # Should we maintain max range?
	}

	match threat:
		ThreatType.SLOW_HEAVY:
			# vs Cruisers: Rush in, swarm, evade slow missiles
			behavior.rush = true
			behavior.range_mult = 0.6  # Get close!
			behavior.orbit_speed = 3.0  # Fast evasive movement

		ThreatType.FAST_SWARM:
			# vs Frigate swarm: Tight formation, focused fire
			behavior.range_mult = 0.9
			behavior.orbit_speed = 2.0

		ThreatType.SNIPER:
			# vs Destroyers: Can't dodge lasers, need to close fast or use cover
			if ship_size == VnpTypes.ShipSize.SMALL:
				behavior.rush = true  # Close the gap fast
				behavior.range_mult = 0.5
			else:
				behavior.keep_distance = true  # Trade shots at range
				behavior.range_mult = 1.0

		ThreatType.AOE_SPRAY:
			# vs PDC/multiple cruisers: Scatter! Don't cluster!
			behavior.scatter = true
			behavior.keep_distance = true
			behavior.range_mult = 1.1  # Stay at max range
			behavior.flank = true  # Try to get around

		ThreatType.SUPPORT:
			# vs Shielders/Gravitons: Priority kill, rush them
			behavior.rush = true
			behavior.range_mult = 0.5
			behavior.orbit_speed = 3.5

	return behavior


func _get_formation_target() -> Vector2:
	# Get formation position from AI controller, or fallback to center push
	if ai_controller:
		return ai_controller.get_formation_position(
			ship_data.team,
			ship_data.type,
			position
		)

	# Fallback: Push towards center of map
	var viewport_size = get_viewport_rect().size
	var center = viewport_size * 0.75  # Center of 1.5x scaled world
	return center + Vector2(randf_range(-200, 200), randf_range(-200, 200))


func _find_nearest_enemy_for_formation(state: Dictionary) -> int:
	"""Find nearest enemy that is within formation constraints, biased toward rally"""
	var nearest_enemy_id = -1
	var best_score = -INF

	# Get formation constraints
	var max_chase_dist = 400.0  # Default
	var fleet_center = position  # Default to self
	if ai_controller:
		max_chase_dist = ai_controller.get_max_chase_distance(ship_data.team, ship_data.type)
		fleet_center = ai_controller.get_fleet_center(ship_data.team)

	var weapon_range = ship_stats.get("range", 300)

	# Get rally point for attack-move bias
	var rally_point = _get_rally_point(state)
	var has_rally = rally_point != Vector2.ZERO
	var to_rally_dir = Vector2.ZERO
	if has_rally:
		to_rally_dir = (rally_point - position).normalized()

	for other_ship_id in state.ships:
		var other_ship = state.ships[other_ship_id]
		if other_ship.team != ship_data.team:
			var dist_to_enemy = position.distance_to(other_ship.position)
			var enemy_dist_from_fleet = other_ship.position.distance_to(fleet_center)

			# In defensive mode, only attack enemies that are close to fleet
			# or if we're close enough to engage without leaving fleet
			var can_engage = true
			if ai_controller:
				var my_dist_from_fleet = position.distance_to(fleet_center)
				# Would engaging this enemy take us too far from fleet?
				if my_dist_from_fleet + dist_to_enemy > max_chase_dist * 1.5:
					# Only engage if enemy is very close (within weapon range)
					if dist_to_enemy > weapon_range * 2:
						can_engage = false

			if not can_engage:
				continue

			# Score based on distance - prefer nearby enemies
			var score = 1000.0 - dist_to_enemy

			# Bonus for enemies within engagement range
			if dist_to_enemy <= weapon_range * 2.5:
				score += 500.0

			# ATTACK-MOVE: Bonus for enemies in the direction of rally point
			if has_rally and dist_to_enemy > 0:
				var to_enemy_dir = (other_ship.position - position).normalized()
				var alignment = to_rally_dir.dot(to_enemy_dir)  # -1 to 1
				score += alignment * 225.0

			# Bonus for finishing off wounded enemies
			var other_stats = VnpTypes.SHIP_STATS.get(other_ship.type, {})
			var max_health = other_stats.get("health", 100)
			var health_percent = float(other_ship.health) / max_health
			if health_percent < 0.5:
				score += 200.0

			# Bonus for enemies closer to our fleet center (defending)
			if ai_controller:
				var formation = ai_controller.get_formation(ship_data.team)
				if formation == VnpTypes.FleetFormation.DEFENSIVE:
					# Prefer enemies threatening our fleet
					if enemy_dist_from_fleet < 300:
						score += 300.0

			# Slight randomness
			score += randf() * 50.0

			if score > best_score:
				best_score = score
				nearest_enemy_id = other_ship_id

	return nearest_enemy_id


func _should_return_to_fleet() -> bool:
	"""Check if ship should disengage and return to fleet formation"""
	if not ai_controller:
		return false

	var formation = ai_controller.get_formation(ship_data.team)
	if formation != VnpTypes.FleetFormation.DEFENSIVE:
		return false  # Offensive mode - chase freely

	var fleet_center = ai_controller.get_fleet_center(ship_data.team)
	var dist_from_fleet = position.distance_to(fleet_center)
	var max_chase = ai_controller.get_max_chase_distance(ship_data.team, ship_data.type)

	# Return to fleet if too far out
	return dist_from_fleet > max_chase


func _find_better_rally_target(state: Dictionary, current_target_id) -> int:
	"""Check if there's a significantly better target aligned with rally direction"""
	var rally_point = _get_rally_point(state)
	var weapon_range = ship_stats.get("range", 300)

	# Use pure function from VnpSystems
	return VnpSystems.find_better_target(
		position,
		ship_data.team,
		current_target_id,
		weapon_range,
		rally_point,
		state.ships
	)


func _dispatch_state_change(new_state: String, target = null):
	# Throttle state changes to prevent spam
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_state_change_time < STATE_CHANGE_COOLDOWN:
		return false

	last_state_change_time = current_time
	store.dispatch({
		"type": "SET_SHIP_STATE",
		"ship_id": ship_data.id,
		"state": new_state,
		"target": target
	})
	return true

func _find_nearest_enemy(state):
	# Use pure function from VnpSystems for targeting
	var rally_point = _get_rally_point(state)
	var weapon_range = ship_stats.get("range", 300)

	return VnpSystems.find_best_target(
		position,
		ship_data.team,
		weapon_range,
		rally_point,
		state.ships
	)


func _find_uncaptured_planet(state):
	# Find nearest planet not owned by our team
	var best_planet_id = -1
	var min_dist = INF

	for planet_id in state.planets:
		var planet = state.planets[planet_id]
		if planet.get("owner", -1) != ship_data.team:
			var dist = self.position.distance_to(planet.position)
			if dist < min_dist:
				min_dist = dist
				best_planet_id = planet_id

	return best_planet_id

func _on_fire_rate_timer_timeout():
	var current_state = store.get_state()
	var my_current_data = current_state.ships.get(ship_data.id)
	
	if not my_current_data or my_current_data.state != "attacking":
		return

	var target_id = my_current_data.target
	if current_state.ships.has(target_id):
		var target_data = current_state.ships[target_id]
		var target_stats = VnpTypes.SHIP_STATS[target_data.type]
		var damage_multiplier = VnpTypes.DAMAGE_MULTIPLIERS[ship_stats.weapon].get(target_stats.weapon, 1.0)

		# Apply damage bonus from controlled strategic points (e.g., Command Center)
		var point_damage_bonus = _get_strategic_point_damage_bonus(current_state, ship_data.team)
		var total_damage = ship_stats.damage * damage_multiplier * (1.0 + point_damage_bonus)

		# Show muzzle flash for all weapons
		_show_muzzle_flash()

		# Play weapon sound
		if sound_manager:
			match ship_stats.weapon:
				VnpTypes.WeaponType.LASER:
					sound_manager.play_laser()
				VnpTypes.WeaponType.GUN:
					sound_manager.play_railgun()
				VnpTypes.WeaponType.MISSILE:
					sound_manager.play_missile_launch()
				VnpTypes.WeaponType.TURBOLASER:
					sound_manager.play_turbolaser()

		match ship_stats.weapon:
			VnpTypes.WeaponType.LASER:
				# LASER: Instant hit with sustained burn effect
				var laser_color = VnpTypes.get_weapon_color(ship_data.team, VnpTypes.WeaponType.LASER)

				# Main beam - bright core
				laser_beam.default_color = laser_color
				laser_beam.clear_points()
				laser_beam.add_point(Vector2.ZERO)
				laser_beam.add_point(to_local(target_data.position))

				# Create glow beam (wider, more transparent) - add to root so it doesn't move with ship
				var glow_beam = Line2D.new()
				glow_beam.default_color = Color(laser_color.r, laser_color.g, laser_color.b, 0.4)
				glow_beam.width = 24.0
				glow_beam.add_point(global_position)
				glow_beam.add_point(target_data.position)
				get_tree().root.add_child(glow_beam)

				# Animate beam fade - use sequential tween with proper cleanup
				var tween = create_tween()
				tween.tween_property(laser_beam, "width", 0.0, 0.2).from(14.0)

				var glow_tween = get_tree().create_tween()
				glow_tween.tween_property(glow_beam, "modulate:a", 0.0, 0.2)
				glow_tween.tween_callback(func(): glow_beam.queue_free())

				# Burning impact at target
				var impact = ImpactFxScene.instantiate()
				get_tree().root.add_child(impact)
				impact.global_position = target_data.position
				impact.scale = Vector2(1.5, 1.5)  # Larger burn mark
				impact.emitting = true

				# Instant damage - lasers are precise
				store.dispatch({ "type": "DAMAGE_SHIP", "ship_id": target_id, "damage": total_damage })

			VnpTypes.WeaponType.GUN:
				# RAILGUN: Punchy power surge + piercing projectile
				_show_railgun_power_surge()
				var projectile = ProjectileScene.instantiate()
				get_tree().root.add_child(projectile)
				projectile.init({
					"team": ship_data.team,
					"weapon_type": ship_stats.weapon,
					"damage": total_damage,
					"start_position": self.global_position,
					"start_rotation": self.rotation,
					"target_id": target_id,
					"store": store,
					"vnp_main": vnp_main,
				})

			VnpTypes.WeaponType.MISSILE:
				# MISSILE SALVO: Fire 3 missiles in a shower pattern
				var missile_count = 3
				for i in range(missile_count):
					# Stagger launch slightly for shower effect
					var delay = i * 0.08
					var spread_index = i
					get_tree().create_timer(delay).timeout.connect(func():
						if not is_instance_valid(self):
							return
						var m_projectile = ProjectileScene.instantiate()
						get_tree().root.add_child(m_projectile)
						# Spread missiles with different arc offsets
						m_projectile.init({
							"team": ship_data.team,
							"weapon_type": ship_stats.weapon,
							"damage": total_damage / missile_count,  # Split damage across salvo
							"start_position": self.global_position,
							"start_rotation": self.rotation + (spread_index - 1) * 0.12,  # Slight angle spread
							"target_id": target_id,
							"arc_height_mult": 0.4 + randf() * 0.35,  # Varied arc heights
							"store": store,
							"vnp_main": vnp_main,
						})
					)

			VnpTypes.WeaponType.TURBOLASER:
				# TURBOLASER: Slow but devastating projectile - Star Destroyer style
				# Easy for small fast ships to dodge, deadly to capitals
				_show_turbolaser_charge()
				var turbo_projectile = ProjectileScene.instantiate()
				get_tree().root.add_child(turbo_projectile)
				turbo_projectile.init({
					"team": ship_data.team,
					"weapon_type": VnpTypes.WeaponType.TURBOLASER,
					"damage": total_damage,
					"start_position": self.global_position,
					"start_rotation": self.rotation,
					"target_id": target_id,
					"turbolaser_speed": ship_stats.get("turbolaser_speed", 180),
					"turbolaser_size": ship_stats.get("turbolaser_size", 12),
					"store": store,
					"vnp_main": vnp_main,
				})

func _show_turbolaser_charge():
	# Dramatic charging effect before turbolaser fires
	var turbo_color = VnpTypes.get_weapon_color(ship_data.team, VnpTypes.WeaponType.TURBOLASER)

	# Big charging glow at center
	var charge = Polygon2D.new()
	var charge_points = []
	for i in range(13):
		var angle = i * (PI * 2 / 12)
		charge_points.append(Vector2(cos(angle), sin(angle)) * 20)
	charge.polygon = PackedVector2Array(charge_points)
	charge.color = Color(turbo_color.r, turbo_color.g, turbo_color.b, 0.8)
	add_child(charge)

	# Expanding ring
	var ring = Line2D.new()
	ring.width = 6.0
	ring.default_color = turbo_color.lightened(0.3)
	var ring_points = []
	for i in range(25):
		var angle = i * (PI * 2 / 24)
		ring_points.append(Vector2(cos(angle), sin(angle)) * 30)
	ring.points = PackedVector2Array(ring_points)
	add_child(ring)

	# Animate charge and ring
	var charge_tween = create_tween()
	charge_tween.set_parallel(true)
	charge_tween.tween_property(charge, "scale", Vector2(2.0, 2.0), 0.2).from(Vector2(0.5, 0.5))
	charge_tween.tween_property(charge, "modulate:a", 0.0, 0.3)
	charge_tween.tween_callback(func(): charge.queue_free())

	var ring_tween = create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector2(3.0, 3.0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.25)
	ring_tween.tween_callback(func(): ring.queue_free())

func _apply_styles():
	# Ships scaled to 70% - makes effects relatively bigger and more dramatic
	var scale_factor = 0.7

	match ship_data.type:
		VnpTypes.ShipType.FRIGATE:
			polygon.polygon = _scale_polygon([Vector2(15, 0), Vector2(-10, -10), Vector2(-10, 10)], scale_factor)
		VnpTypes.ShipType.DESTROYER:
			polygon.polygon = _scale_polygon([Vector2(20, 0), Vector2(-15, -8), Vector2(-15, 8)], scale_factor)
		VnpTypes.ShipType.CRUISER:
			polygon.polygon = _scale_polygon([Vector2(18, 0), Vector2(9, -15), Vector2(-9, -15), Vector2(-18, 0), Vector2(-9, 15), Vector2(9, 15)], scale_factor)
		VnpTypes.ShipType.HARVESTER:
			polygon.polygon = _scale_polygon([Vector2(-15, -8), Vector2(15, -8), Vector2(15, 8), Vector2(-15, 8)], scale_factor)
		VnpTypes.ShipType.DEFENDER:
			# Bristling with guns shape - wide with turret bumps
			polygon.polygon = _scale_polygon([
				Vector2(12, 0), Vector2(8, -8), Vector2(-4, -10), Vector2(-8, -6),
				Vector2(-12, -8), Vector2(-14, 0), Vector2(-12, 8), Vector2(-8, 6),
				Vector2(-4, 10), Vector2(8, 8)
			], scale_factor)
		VnpTypes.ShipType.SHIELDER:
			# Rounded support ship - dome-like
			polygon.polygon = _scale_polygon([
				Vector2(10, 0), Vector2(8, -6), Vector2(2, -10), Vector2(-6, -8),
				Vector2(-10, -4), Vector2(-10, 4), Vector2(-6, 8), Vector2(2, 10), Vector2(8, 6)
			], scale_factor)
		VnpTypes.ShipType.GRAVITON:
			# Massive hulking gravity manipulator - imposing angular shape with core
			polygon.polygon = _scale_polygon([
				Vector2(22, 0), Vector2(16, -12), Vector2(4, -16), Vector2(-8, -14),
				Vector2(-18, -10), Vector2(-22, 0), Vector2(-18, 10), Vector2(-8, 14),
				Vector2(4, 16), Vector2(16, 12)
			], scale_factor)
		VnpTypes.ShipType.STARBASE:
			# Massive star base - like a Star Destroyer or space station
			# Much larger scale (no scaling factor applied)
			polygon.polygon = PackedVector2Array([
				Vector2(60, 0), Vector2(45, -20), Vector2(25, -35), Vector2(-10, -40),
				Vector2(-40, -30), Vector2(-55, -15), Vector2(-55, 15), Vector2(-40, 30),
				Vector2(-10, 40), Vector2(25, 35), Vector2(45, 20)
			])
		VnpTypes.ShipType.BASE_TURRET:
			# Defensive turret emplacement - compact gun platform
			# Octagonal base with forward-facing gun mount
			polygon.polygon = PackedVector2Array([
				Vector2(18, 0), Vector2(14, -8), Vector2(6, -14), Vector2(-6, -14),
				Vector2(-14, -8), Vector2(-14, 8), Vector2(-6, 14), Vector2(6, 14),
				Vector2(14, 8)
			])

	polygon.color = VnpTypes.get_team_color(ship_data.team)


func _scale_polygon(points: Array, scale: float) -> PackedVector2Array:
	var scaled = []
	for p in points:
		scaled.append(p * scale)
	return PackedVector2Array(scaled)


func _find_nearest_ally(state) -> int:
	var nearest_ally_id = -1
	var min_dist_sq = INF

	for other_ship_id in state.ships:
		var other_ship = state.ships[other_ship_id]
		if other_ship.team == ship_data.team and other_ship_id != ship_data.id:
			# Prefer protecting combat ships over other support ships
			if other_ship.type in [VnpTypes.ShipType.DEFENDER, VnpTypes.ShipType.SHIELDER]:
				continue
			var dist_sq = self.position.distance_squared_to(other_ship.position)
			if dist_sq < min_dist_sq:
				min_dist_sq = dist_sq
				nearest_ally_id = other_ship_id

	return nearest_ally_id


func _find_combat_ship_to_escort(state) -> int:
	"""Find the best combat ship for a support ship to escort"""
	var best_target = -1
	var best_score = -INF

	# Combat ship types that support ships should escort
	var combat_types = [VnpTypes.ShipType.FRIGATE, VnpTypes.ShipType.DESTROYER, VnpTypes.ShipType.CRUISER]

	for other_ship_id in state.ships:
		var other_ship = state.ships[other_ship_id]
		if other_ship.team != ship_data.team:
			continue
		if other_ship_id == ship_data.id:
			continue
		if not other_ship.type in combat_types:
			continue

		var dist = position.distance_to(other_ship.position)
		var score = 1000.0 - dist  # Prefer closer ships

		# Bonus for ships in combat (they need protection!)
		if other_ship.state == "attacking":
			score += 300.0

		# Bonus for larger ships (Cruisers > Destroyers > Frigates)
		match other_ship.type:
			VnpTypes.ShipType.CRUISER:
				score += 200.0  # High value target to protect
			VnpTypes.ShipType.DESTROYER:
				score += 100.0

		# Bonus for wounded ships
		var other_stats = VnpTypes.SHIP_STATS.get(other_ship.type, {})
		var max_health = other_stats.get("health", 100)
		var health_pct = float(other_ship.health) / max_health
		if health_pct < 0.7:
			score += 150.0  # Protect wounded ships

		if score > best_score:
			best_score = score
			best_target = other_ship_id

	return best_target


func _run_pdc_defense(delta):
	# PDC cooldown
	pdc_cooldown -= delta
	if pdc_cooldown > 0:
		return

	# Find enemy missiles in range
	var pdc_range = ship_stats.get("range", 250)
	var intercept_chance = ship_stats.get("intercept_chance", 0.4)

	for node in get_tree().get_nodes_in_group("missiles"):
		if not is_instance_valid(node):
			continue
		if node.team == ship_data.team:
			continue  # Don't shoot our own missiles

		var dist = global_position.distance_to(node.global_position)
		if dist <= pdc_range:
			# Fire PDC burst at missile
			_fire_pdc_burst(node.global_position)
			pdc_cooldown = 1.0 / ship_stats.get("fire_rate", 8.0)

			# Chance to intercept
			if randf() < intercept_chance:
				_intercept_missile(node)
			break  # One target per frame


func _fire_pdc_burst(target_pos: Vector2):
	# Play PDC sound
	if sound_manager:
		sound_manager.play_pdc()

	var pdc_color = VnpTypes.get_weapon_color(ship_data.team, VnpTypes.WeaponType.PDC)

	# Create 5-8 tracer lines for intimidating bullet wall
	var tracer_count = randi_range(5, 8)
	for i in range(tracer_count):
		var tracer = Line2D.new()
		tracer.width = 2.5  # Thicker tracers
		tracer.default_color = pdc_color

		# Wider spread pattern
		var spread = Vector2(randf_range(-25, 25), randf_range(-25, 25))
		var end_pos = target_pos + spread

		# Staggered start points for "wall of lead" effect
		var start_offset = Vector2(randf_range(-8, 8), randf_range(-8, 8))

		tracer.add_point(global_position + start_offset)
		tracer.add_point(end_pos)
		tracer.antialiased = true
		get_tree().root.add_child(tracer)

		# Slightly longer fade for visibility
		var tween = get_tree().create_tween()
		tween.tween_property(tracer, "modulate:a", 0.0, 0.12)
		tween.tween_callback(func(): tracer.queue_free())

	# Add small tracer sparks at origin
	var sparks = GPUParticles2D.new()
	sparks.global_position = global_position
	sparks.amount = 8
	sparks.lifetime = 0.15
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.emitting = true

	var mat = ParticleProcessMaterial.new()
	var to_target = (target_pos - global_position).normalized()
	mat.direction = Vector3(to_target.x, to_target.y, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 150.0
	mat.initial_velocity_max = 250.0
	mat.scale_min = 0.8
	mat.scale_max = 1.5
	mat.color = pdc_color.lightened(0.3)

	sparks.process_material = mat
	sparks.draw_pass_1 = QuadMesh.new()
	sparks.draw_pass_1.size = Vector2(2, 2)
	get_tree().root.add_child(sparks)

	get_tree().create_timer(0.3).timeout.connect(func():
		if is_instance_valid(sparks):
			sparks.queue_free()
	)

	# Muzzle flash
	_show_muzzle_flash()


func _intercept_missile(missile_node):
	# Create interception explosion
	var intercept_pos = missile_node.global_position

	# Small bright explosion
	var particles = GPUParticles2D.new()
	particles.global_position = intercept_pos
	particles.amount = 15
	particles.lifetime = 0.2
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.emitting = true

	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 3.0
	mat.spread = 180.0
	mat.initial_velocity_min = 80.0
	mat.initial_velocity_max = 150.0
	mat.scale_min = 1.0
	mat.scale_max = 2.0

	var pdc_color = VnpTypes.get_weapon_color(ship_data.team, VnpTypes.WeaponType.PDC)
	var grad = Gradient.new()
	grad.set_color(0, Color.WHITE)
	grad.set_color(1, Color(pdc_color.r, pdc_color.g, pdc_color.b, 0))
	var tex = GradientTexture1D.new()
	tex.gradient = grad
	mat.color_ramp = tex

	particles.process_material = mat
	particles.draw_pass_1 = QuadMesh.new()
	particles.draw_pass_1.size = Vector2(3, 3)

	get_tree().root.add_child(particles)

	# Cleanup
	get_tree().create_timer(0.5).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)

	# Destroy the missile
	missile_node.queue_free()


func _run_shield_defense(delta, state):
	if not is_instance_valid(shield_bubble):
		return

	# Shield provides damage reduction to nearby allies
	# This is handled in the damage reducer, we just update visual feedback here
	var shield_radius = ship_stats.get("shield_radius", 120)

	# Count protected allies for visual feedback
	var protected_count = 0
	for other_ship_id in state.ships:
		var other_ship = state.ships[other_ship_id]
		if other_ship.team == ship_data.team and other_ship_id != ship_data.id:
			var dist = global_position.distance_to(other_ship.position)
			if dist <= shield_radius:
				protected_count += 1

	# Brighten shield based on protection activity
	if protected_count > 0:
		shield_bubble.width = 4.0
	else:
		shield_bubble.width = 2.0


func _run_gravity_defense(delta, state):
	if not is_instance_valid(gravity_well):
		return

	var gravity_radius = ship_stats.get("gravity_radius", 200)

	# Count protected allies for visual feedback
	var protected_count = 0
	for other_ship_id in state.ships:
		var other_ship = state.ships[other_ship_id]
		if other_ship.team == ship_data.team and other_ship_id != ship_data.id:
			var dist = global_position.distance_to(other_ship.position)
			if dist <= gravity_radius:
				protected_count += 1

	# Intensify gravity well visuals when protecting allies
	if protected_count > 0:
		if is_instance_valid(gravity_ring_inner):
			gravity_ring_inner.width = 6.0
		if is_instance_valid(gravity_ring_outer):
			gravity_ring_outer.width = 8.0
	else:
		if is_instance_valid(gravity_ring_inner):
			gravity_ring_inner.width = 4.0
		if is_instance_valid(gravity_ring_outer):
			gravity_ring_outer.width = 6.0


func show_deflection_effect(projectile_pos: Vector2, deflect_direction: Vector2):
	# Visual feedback when a railgun is deflected
	var gravity_color = VnpTypes.get_weapon_color(ship_data.team, VnpTypes.WeaponType.GRAVITY)

	# Ripple wave from point of deflection
	var ripple = Line2D.new()
	ripple.global_position = projectile_pos
	ripple.width = 4.0
	ripple.default_color = Color(gravity_color.r * 1.5, gravity_color.g * 1.5, gravity_color.b * 1.5, 0.8)
	var ripple_points = []
	for i in range(33):
		var angle = i * (PI * 2 / 32)
		ripple_points.append(Vector2(cos(angle), sin(angle)) * 10)
	ripple.points = PackedVector2Array(ripple_points)
	get_tree().root.add_child(ripple)

	# Expand and fade
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(ripple, "scale", Vector2(6, 6), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ripple, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): ripple.queue_free())

	# Brief flash on gravity well
	if is_instance_valid(gravity_well):
		var flash_tween = create_tween()
		flash_tween.tween_property(gravity_well, "modulate", Color(1.5, 1.5, 1.5, 1.2), 0.05)
		flash_tween.tween_property(gravity_well, "modulate", Color.WHITE, 0.2)


func _get_strategic_point_damage_bonus(state: Dictionary, team: int) -> float:
	"""Calculate damage bonus from controlled strategic points (e.g., Command Center)"""
	var bonus = 0.0
	if not state.has("strategic_points"):
		return bonus

	for point_id in state.strategic_points:
		var point = state.strategic_points[point_id]
		if point.get("owner", null) == team:
			var point_type = point.get("type", -1)
			var point_bonuses = VnpTypes.POINT_BONUSES.get(point_type, {})
			bonus += point_bonuses.get("damage_bonus", 0.0)
	return bonus


func _get_rally_point(state: Dictionary) -> Vector2:
	"""Get rally point for this ship's team"""
	if not state.has("teams"):
		return Vector2.ZERO
	var team_data = state.teams.get(ship_data.team, {})
	var rally = team_data.get("rally_point", null)
	if rally is Vector2:
		return rally
	return Vector2.ZERO