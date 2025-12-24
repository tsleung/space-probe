extends CharacterBody2D

const VnpTypes = preload("res://scripts/von_neumann_probe/vnp_types.gd")
const VnpSystems = preload("res://scripts/von_neumann_probe/vnp_systems.gd")
const ImpactFxScene = preload("res://scenes/von_neumann_probe/impact_fx.tscn")
# ProjectileScene removed - using vnp_main.get_projectile() pool instead

# Static cached textures (shared across all ships)
static var _cached_circle_texture_small: GradientTexture2D = null
static var _cached_circle_texture_medium: GradientTexture2D = null

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
var engine_trail: Line2D = null
var muzzle_flash: Polygon2D = null
var side_thruster_left: GPUParticles2D = null
var side_thruster_right: GPUParticles2D = null

# Defensive systems
var shield_bubble: Node2D = null
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

# Position sync throttling - don't dispatch every frame
var last_position_sync_time: float = 0.0
const POSITION_SYNC_INTERVAL: float = 0.5  # Sync position every 500ms
var last_synced_position: Vector2 = Vector2.ZERO

# Target caching - don't search every frame
var cached_target_id: int = -1
var target_cache_timer: float = 0.0
const TARGET_CACHE_DURATION: float = 0.3  # Re-evaluate targets every 300ms

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

# Convergence pull tracking
var convergence_pull_applied: bool = false  # Track if pull was applied this frame

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
	elif ship_data.type == VnpTypes.ShipType.PROGENITOR_DRONE:
		_setup_progenitor_drone_visuals()

	var fire_rate = ship_stats.get("fire_rate", 1.0)
	if fire_rate > 0:
		fire_rate_timer.wait_time = 1.0 / fire_rate
		fire_rate_timer.connect("timeout", Callable(self, "_on_fire_rate_timer_timeout"))

func _setup_engine_trail():
	# Simple line trail + spark for performance
	var team_color = VnpTypes.get_team_color(ship_data.team)
	var ship_size = VnpTypes.get_ship_size(ship_data.type)

	# Progenitor drones have a special void trail
	if ship_data.type == VnpTypes.ShipType.PROGENITOR_DRONE:
		_setup_void_trail()
		return

	# Trail length based on ship size
	var trail_lengths = {
		VnpTypes.ShipType.FRIGATE: 20,
		VnpTypes.ShipType.DESTROYER: 28,
		VnpTypes.ShipType.CRUISER: 35,
		VnpTypes.ShipType.DEFENDER: 22,
		VnpTypes.ShipType.SHIELDER: 22,
		VnpTypes.ShipType.GRAVITON: 30,
		VnpTypes.ShipType.HARVESTER: 18,
	}
	var trail_length = trail_lengths.get(ship_data.type, 20)

	# Simple line for exhaust
	engine_trail = Line2D.new()
	engine_trail.name = "EngineTrail"
	engine_trail.width = 3.0 if ship_size >= VnpTypes.ShipSize.LARGE else 2.0
	engine_trail.default_color = team_color.lightened(0.3)
	engine_trail.add_point(Vector2(-6, 0))
	engine_trail.add_point(Vector2(-6 - trail_length, 0))

	# Gradient fade
	var grad = Gradient.new()
	grad.set_color(0, team_color)
	grad.set_color(1, Color(team_color.r, team_color.g, team_color.b, 0))
	engine_trail.gradient = grad

	add_child(engine_trail)

	# Single spark at exhaust point
	var spark = Polygon2D.new()
	spark.name = "ExhaustSpark"
	spark.polygon = PackedVector2Array([
		Vector2(-4, 0), Vector2(-8, -2), Vector2(-6, 0), Vector2(-8, 2)
	])
	spark.color = team_color.lightened(0.5)
	add_child(spark)


func _setup_void_trail():
	# Special trail for Progenitor drones - wisps of void energy
	var void_color = VnpTypes.PROGENITOR_ACCENT
	var dark_void = VnpTypes.PROGENITOR_COLOR

	# Main void trail - darker, more sinister
	engine_trail = Line2D.new()
	engine_trail.name = "VoidTrail"
	engine_trail.width = 4.0
	engine_trail.default_color = void_color
	engine_trail.add_point(Vector2(-8, 0))
	engine_trail.add_point(Vector2(-25, 0))

	# Gradient to dark void
	var grad = Gradient.new()
	grad.set_color(0, void_color)
	grad.set_color(1, Color(dark_void.r, dark_void.g, dark_void.b, 0))
	engine_trail.gradient = grad

	add_child(engine_trail)

	# Secondary wispy trails - adds ethereal quality
	for i in range(2):
		var wisp = Line2D.new()
		wisp.name = "VoidWisp_%d" % i
		wisp.width = 2.0
		var offset_y = (i * 2 - 1) * 4  # -4 and +4
		wisp.add_point(Vector2(-6, offset_y))
		wisp.add_point(Vector2(-18, offset_y * 1.5))
		wisp.default_color = Color(void_color.r, void_color.g, void_color.b, 0.5)

		var wisp_grad = Gradient.new()
		wisp_grad.set_color(0, void_color)
		wisp_grad.set_color(1, Color(dark_void.r, dark_void.g, dark_void.b, 0))
		wisp.gradient = wisp_grad

		add_child(wisp)


func _setup_muzzle_flash():
	muzzle_flash = Polygon2D.new()
	muzzle_flash.name = "MuzzleFlash"

	var weapon_type = ship_stats.get("weapon", null)
	# Ships without weapons (like PROGENITOR_DRONE) don't need muzzle flash
	if weapon_type == null:
		muzzle_flash.visible = false
		add_child(muzzle_flash)
		return

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
	thruster.texture = _create_circle_texture(config.size)

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


func _create_circle_texture(radius: float) -> GradientTexture2D:
	# Use cached textures to avoid creating new ones constantly
	if radius <= 2.0:
		if _cached_circle_texture_small == null:
			_cached_circle_texture_small = _make_circle_texture(2.0)
		return _cached_circle_texture_small
	else:
		if _cached_circle_texture_medium == null:
			_cached_circle_texture_medium = _make_circle_texture(3.0)
		return _cached_circle_texture_medium


static func _make_circle_texture(radius: float) -> GradientTexture2D:
	# Create a radial gradient texture for particle
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


var pdc_inner_ring: Line2D = null
var pdc_crosshairs: Node2D = null

func _setup_pdc_kill_zone():
	# SPECTACULAR PDC KILL ZONE - Radar sweep, crosshairs, threat indicator
	var pdc_color = VnpTypes.get_weapon_color(ship_data.team, VnpTypes.WeaponType.PDC)
	var pdc_range = ship_stats.get("range", 250)

	pdc_kill_zone = Node2D.new()
	pdc_kill_zone.name = "PDCKillZone"
	add_child(pdc_kill_zone)

	# OUTER RANGE RING - Main boundary
	pdc_range_ring = Line2D.new()
	pdc_range_ring.name = "RangeRing"
	pdc_range_ring.width = 3.0
	pdc_range_ring.default_color = Color(pdc_color.r, pdc_color.g, pdc_color.b, 0.4)
	var ring_points = []
	for i in range(33):
		var angle = i * (PI * 2 / 32)
		ring_points.append(Vector2(cos(angle), sin(angle)) * pdc_range)
	pdc_range_ring.points = PackedVector2Array(ring_points)
	pdc_kill_zone.add_child(pdc_range_ring)

	# INNER RING - Kill zone core
	pdc_inner_ring = Line2D.new()
	pdc_inner_ring.name = "InnerRing"
	pdc_inner_ring.width = 2.0
	pdc_inner_ring.default_color = Color(pdc_color.r * 1.2, pdc_color.g * 1.2, pdc_color.b * 1.2, 0.5)
	var inner_points = []
	for i in range(25):
		var angle = i * (PI * 2 / 24)
		inner_points.append(Vector2(cos(angle), sin(angle)) * (pdc_range * 0.6))
	pdc_inner_ring.points = PackedVector2Array(inner_points)
	pdc_kill_zone.add_child(pdc_inner_ring)

	# RADAR SWEEP LINE - Rotating scanner
	pdc_sweep_line = Line2D.new()
	pdc_sweep_line.name = "SweepLine"
	pdc_sweep_line.width = 2.0
	pdc_sweep_line.default_color = Color(pdc_color.r * 1.5, pdc_color.g * 1.5, pdc_color.b * 1.5, 0.6)
	pdc_sweep_line.add_point(Vector2.ZERO)
	pdc_sweep_line.add_point(Vector2(pdc_range, 0))

	# Gradient fade for sweep line
	var sweep_gradient = Gradient.new()
	sweep_gradient.set_color(0, Color(pdc_color.r, pdc_color.g, pdc_color.b, 0.8))
	sweep_gradient.set_color(1, Color(pdc_color.r, pdc_color.g, pdc_color.b, 0.1))
	pdc_sweep_line.gradient = sweep_gradient
	pdc_kill_zone.add_child(pdc_sweep_line)

	# CROSSHAIRS - Targeting reticle
	pdc_crosshairs = Node2D.new()
	pdc_crosshairs.name = "Crosshairs"
	var cross_color = Color(pdc_color.r, pdc_color.g, pdc_color.b, 0.2)
	for i in range(4):
		var crosshair = Line2D.new()
		crosshair.width = 1.5
		crosshair.default_color = cross_color
		var angle = i * (PI / 2)
		crosshair.add_point(Vector2(cos(angle), sin(angle)) * 30)
		crosshair.add_point(Vector2(cos(angle), sin(angle)) * pdc_range)
		pdc_crosshairs.add_child(crosshair)
	pdc_kill_zone.add_child(pdc_crosshairs)

	# Start sweep animation
	_animate_pdc_sweep()


func _animate_pdc_sweep():
	# Continuous radar sweep rotation
	var sweep_tween = create_tween()
	sweep_tween.set_loops(999)  # High number to avoid infinite loop detection
	sweep_tween.tween_property(pdc_sweep_line, "rotation", TAU, 2.0)
	sweep_tween.tween_callback(func(): pdc_sweep_line.rotation = 0)

	# Slow crosshair rotation (opposite direction)
	var cross_tween = create_tween()
	cross_tween.set_loops(999)  # High number to avoid infinite loop detection
	cross_tween.tween_property(pdc_crosshairs, "rotation", -TAU, 8.0)
	cross_tween.tween_callback(func(): pdc_crosshairs.rotation = 0)

	# Pulsing rings
	var pulse_tween = create_tween()
	pulse_tween.set_loops(999)  # High number to avoid infinite loop detection
	pulse_tween.tween_property(pdc_range_ring, "modulate:a", 0.6, 0.8).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(pdc_range_ring, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)


var shield_outer_ring: Line2D = null
var shield_inner_glow: Line2D = null
var shield_hex_pattern: Node2D = null
var shield_pulse_timer: float = 0.0

func _setup_shield_bubble():
	# SPECTACULAR SHIELD BUBBLE - Hexagonal energy field with shimmer
	var shield_color = VnpTypes.get_weapon_color(ship_data.team, VnpTypes.WeaponType.SHIELD)
	var radius = ship_stats.get("shield_radius", 120)

	# Container for all shield elements
	shield_bubble = Node2D.new()
	shield_bubble.name = "ShieldBubble"
	add_child(shield_bubble)

	# OUTER RING - Main visible boundary (thicker, brighter)
	shield_outer_ring = Line2D.new()
	shield_outer_ring.name = "OuterRing"
	shield_outer_ring.default_color = Color(shield_color.r, shield_color.g, shield_color.b, 0.6)
	shield_outer_ring.width = 4.0
	var outer_points = []
	for i in range(33):
		var angle = i * (PI * 2 / 32)
		outer_points.append(Vector2(cos(angle), sin(angle)) * radius)
	shield_outer_ring.points = PackedVector2Array(outer_points)
	shield_bubble.add_child(shield_outer_ring)

	# INNER GLOW - Soft protective aura
	shield_inner_glow = Line2D.new()
	shield_inner_glow.name = "InnerGlow"
	shield_inner_glow.default_color = Color(shield_color.r * 1.2, shield_color.g * 1.2, shield_color.b * 1.2, 0.25)
	shield_inner_glow.width = 12.0
	shield_inner_glow.points = PackedVector2Array(outer_points)
	shield_bubble.add_child(shield_inner_glow)

	# HEXAGONAL PATTERN - Energy field structure
	shield_hex_pattern = Node2D.new()
	shield_hex_pattern.name = "HexPattern"
	shield_bubble.add_child(shield_hex_pattern)

	# Create hex grid lines
	var hex_color = Color(shield_color.r, shield_color.g, shield_color.b, 0.15)
	for ring in range(3):
		var ring_radius = radius * (0.4 + ring * 0.25)
		for i in range(6):
			var angle = i * (PI / 3) + ring * (PI / 6)
			var hex_line = Line2D.new()
			hex_line.width = 1.5
			hex_line.default_color = hex_color
			var start = Vector2(cos(angle), sin(angle)) * ring_radius * 0.6
			var end = Vector2(cos(angle), sin(angle)) * ring_radius
			hex_line.add_point(start)
			hex_line.add_point(end)
			shield_hex_pattern.add_child(hex_line)

	# Start shimmer animation
	_animate_shield_pulse()


func _animate_shield_pulse():
	if not is_instance_valid(shield_bubble):
		return

	# Continuous breathing pulse
	var pulse_tween = create_tween()
	pulse_tween.set_loops(999)  # High number to avoid infinite loop detection

	pulse_tween.tween_property(shield_outer_ring, "modulate:a", 0.5, 1.2).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(shield_outer_ring, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE)

	# Rotate hex pattern slowly for shimmer effect
	var rotate_tween = create_tween()
	rotate_tween.set_loops(999)  # High number to avoid infinite loop detection
	rotate_tween.tween_property(shield_hex_pattern, "rotation", TAU, 8.0)
	rotate_tween.tween_callback(func(): shield_hex_pattern.rotation = 0)


var gravity_spiral_1: Line2D = null
var gravity_spiral_2: Line2D = null
var gravity_core: Polygon2D = null

func _setup_gravity_well():
	# SPECTACULAR GRAVITY VORTEX - Spinning cosmic singularity effect
	var gravity_color = VnpTypes.get_weapon_color(ship_data.team, VnpTypes.WeaponType.GRAVITY)
	var gravity_radius = ship_stats.get("gravity_radius", 140)

	gravity_well = Node2D.new()
	gravity_well.name = "GravityWell"
	add_child(gravity_well)

	# OUTER RING - Event horizon boundary (thick, menacing)
	gravity_ring_outer = Line2D.new()
	gravity_ring_outer.name = "OuterRing"
	gravity_ring_outer.width = 5.0
	gravity_ring_outer.default_color = Color(gravity_color.r, gravity_color.g, gravity_color.b, 0.5)
	var outer_points = []
	for i in range(33):
		var angle = i * (PI * 2 / 32)
		outer_points.append(Vector2(cos(angle), sin(angle)) * gravity_radius)
	gravity_ring_outer.points = PackedVector2Array(outer_points)
	gravity_well.add_child(gravity_ring_outer)

	# MIDDLE RING - Secondary boundary
	gravity_ring_inner = Line2D.new()
	gravity_ring_inner.name = "MiddleRing"
	gravity_ring_inner.width = 3.0
	gravity_ring_inner.default_color = Color(gravity_color.r * 1.2, gravity_color.g * 1.2, gravity_color.b * 1.2, 0.6)
	var middle_points = []
	for i in range(25):
		var angle = i * (PI * 2 / 24)
		middle_points.append(Vector2(cos(angle), sin(angle)) * (gravity_radius * 0.65))
	gravity_ring_inner.points = PackedVector2Array(middle_points)
	gravity_well.add_child(gravity_ring_inner)

	# SPIRAL ARMS - Spinning matter being sucked in
	gravity_spiral_1 = _create_gravity_spiral(gravity_radius, gravity_color, 0)
	gravity_spiral_2 = _create_gravity_spiral(gravity_radius, gravity_color, PI)
	gravity_well.add_child(gravity_spiral_1)
	gravity_well.add_child(gravity_spiral_2)

	# CORE - Dark center with bright rim
	gravity_core = Polygon2D.new()
	gravity_core.name = "Core"
	var core_points = []
	for i in range(13):
		var angle = i * (TAU / 12)
		core_points.append(Vector2(cos(angle), sin(angle)) * 20)
	gravity_core.polygon = PackedVector2Array(core_points)
	gravity_core.color = Color(0.05, 0.0, 0.1, 0.9)  # Near black
	gravity_well.add_child(gravity_core)

	# Core rim glow
	var core_rim = Line2D.new()
	core_rim.name = "CoreRim"
	core_rim.width = 4.0
	core_rim.default_color = Color(gravity_color.r * 1.5, gravity_color.g * 1.5, gravity_color.b * 1.5, 0.8)
	core_rim.points = PackedVector2Array(core_points + [core_points[0]])  # Close the loop
	gravity_well.add_child(core_rim)

	# Start spinning animation
	_animate_gravity_vortex()

	# Add ship to graviton group for projectile detection
	add_to_group("gravitons")


func _create_gravity_spiral(radius: float, color: Color, offset_angle: float) -> Line2D:
	var spiral = Line2D.new()
	spiral.width = 2.5
	spiral.default_color = Color(color.r, color.g, color.b, 0.4)

	# Create spiral arm - curves inward
	var points = []
	var spiral_turns = 1.5
	var segments = 20
	for i in range(segments):
		var t = float(i) / (segments - 1)
		var angle = offset_angle + t * TAU * spiral_turns
		var r = radius * (1.0 - t * 0.7)  # Spiral inward
		points.append(Vector2(cos(angle), sin(angle)) * r)
	spiral.points = PackedVector2Array(points)

	# Gradient from outer to inner
	var gradient = Gradient.new()
	gradient.set_color(0, Color(color.r, color.g, color.b, 0.1))
	gradient.set_color(1, Color(color.r * 1.5, color.g * 1.5, color.b * 1.5, 0.7))
	spiral.gradient = gradient

	return spiral


func _animate_gravity_vortex():
	if not is_instance_valid(gravity_well):
		return

	# Continuous rotation of spiral arms
	var spin_tween = create_tween()
	spin_tween.set_loops(999)  # High number to avoid infinite loop detection
	spin_tween.tween_property(gravity_spiral_1, "rotation", TAU, 3.0)
	spin_tween.tween_callback(func(): gravity_spiral_1.rotation = 0)

	var spin_tween2 = create_tween()
	spin_tween2.set_loops(999)  # High number to avoid infinite loop detection
	spin_tween2.tween_property(gravity_spiral_2, "rotation", TAU, 3.0)
	spin_tween2.tween_callback(func(): gravity_spiral_2.rotation = 0)

	# Pulsing outer ring
	var pulse_tween = create_tween()
	pulse_tween.set_loops(999)  # High number to avoid infinite loop detection
	pulse_tween.tween_property(gravity_ring_outer, "width", 7.0, 1.0).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(gravity_ring_outer, "width", 5.0, 1.0).set_trans(Tween.TRANS_SINE)


func _animate_gravity_well():
	# Simplified - no animation needed
	pass


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
	sweep_tween.set_loops(999)  # High number to avoid infinite loop detection
	sweep_tween.tween_property(sweep, "rotation", TAU, 4.0).from(0.0)

	# Pulse the range ring
	var pulse_tween = create_tween()
	pulse_tween.set_loops(999)  # High number to avoid infinite loop detection
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
	pulse_tween.set_loops(999)  # High number to avoid infinite loop detection
	pulse_tween.tween_property(range_ring, "modulate:a", 0.5, 2.0).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(range_ring, "modulate:a", 1.0, 2.0).set_trans(Tween.TRANS_SINE)


func _setup_progenitor_drone_visuals():
	# Progenitor Drone: Large alien hunter from the void
	# Distinctive sickly teal with pulsing glow - BIGGER and more threatening
	var void_color = VnpTypes.PROGENITOR_ACCENT
	var pulse_color = VnpTypes.PROGENITOR_PULSE
	var absorption_range = ship_stats.get("range", 150)
	var drone_scale = ship_stats.get("scale", 1.8)

	# Container for drone effects
	var drone_fx = Node2D.new()
	drone_fx.name = "DroneFX"
	add_child(drone_fx)

	# Attack range indicator - menacing ring
	var range_ring = Line2D.new()
	range_ring.name = "AbsorptionRange"
	range_ring.width = 2.5
	range_ring.default_color = Color(void_color.r, void_color.g, void_color.b, 0.2)
	var ring_points = []
	for i in range(25):
		var angle = i * (PI * 2 / 24)
		ring_points.append(Vector2(cos(angle), sin(angle)) * absorption_range)
	range_ring.points = PackedVector2Array(ring_points)
	drone_fx.add_child(range_ring)

	# Void core - larger inner pulsing glow
	var core_glow = Polygon2D.new()
	core_glow.name = "VoidCore"
	core_glow.polygon = PackedVector2Array([
		Vector2(12, 0), Vector2(6, -8), Vector2(-6, -8), Vector2(-12, 0),
		Vector2(-6, 8), Vector2(6, 8)
	])
	core_glow.color = pulse_color
	drone_fx.add_child(core_glow)

	# Larger tendrils extending from body - wispy lines
	for i in range(5):  # More tendrils for bigger creature
		var tendril = Line2D.new()
		tendril.name = "Tendril_%d" % i
		tendril.width = 3.0
		tendril.default_color = void_color
		var angle_offset = (i - 2) * 0.35  # Spread across front
		var tip = Vector2(28, 0).rotated(angle_offset)  # Longer tendrils
		tendril.add_point(Vector2.ZERO)
		tendril.add_point(tip * 0.4)
		tendril.add_point(tip * 0.7)
		tendril.add_point(tip)
		# Gradient fade
		var grad = Gradient.new()
		grad.set_color(0, void_color)
		grad.set_color(1, Color(void_color.r, void_color.g, void_color.b, 0.2))
		tendril.gradient = grad
		drone_fx.add_child(tendril)

	# Eerie pulsing effect on core - slower for larger creature
	var pulse_tween = create_tween()
	pulse_tween.set_loops(999)  # High number to avoid infinite loop detection
	pulse_tween.tween_property(core_glow, "modulate:a", 0.5, 0.8).set_trans(Tween.TRANS_SINE)
	pulse_tween.tween_property(core_glow, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)

	# Slow menacing pulse on range ring
	var range_tween = create_tween()
	range_tween.set_loops(999)  # High number to avoid infinite loop detection
	range_tween.tween_property(range_ring, "modulate:a", 0.2, 2.0).set_trans(Tween.TRANS_SINE)
	range_tween.tween_property(range_ring, "modulate:a", 0.8, 2.0).set_trans(Tween.TRANS_SINE)

	# Scale pulsing - slower, more ominous breathing
	var scale_tween = create_tween()
	scale_tween.set_loops(999)  # High number to avoid infinite loop detection
	scale_tween.tween_property(self, "scale", Vector2(1.08, 0.92), 1.2).set_trans(Tween.TRANS_SINE)
	scale_tween.tween_property(self, "scale", Vector2(0.92, 1.08), 1.2).set_trans(Tween.TRANS_SINE)


func _show_muzzle_flash():
	muzzle_flash.visible = true
	muzzle_flash.modulate = Color.WHITE
	muzzle_flash.scale = Vector2(2.0, 2.0)  # Start much bigger for visibility

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(muzzle_flash, "modulate:a", 0.0, 0.12)
	tween.tween_property(muzzle_flash, "scale", Vector2(0.6, 0.6), 0.12)
	tween.tween_callback(func():
		muzzle_flash.visible = false
		muzzle_flash.scale = Vector2.ONE
	)


func _show_railgun_power_surge():
	# Cool expanding ring effect - larger and more visible
	var flash_color = VnpTypes.get_weapon_color(ship_data.team, VnpTypes.WeaponType.GUN)

	# Bright core flash - larger
	var core = Polygon2D.new()
	core.polygon = PackedVector2Array([
		Vector2(-4, -10), Vector2(18, 0), Vector2(-4, 10)
	])
	core.color = Color.WHITE
	core.position = muzzle_flash.position
	add_child(core)

	# Inner bright line (the projectile origin)
	var line_flash = Line2D.new()
	line_flash.width = 5.0
	line_flash.default_color = flash_color.lightened(0.6)
	line_flash.add_point(muzzle_flash.position)
	line_flash.add_point(muzzle_flash.position + Vector2(30, 0))
	add_child(line_flash)

	# Expanding ring - larger
	var ring = Line2D.new()
	ring.width = 4.0
	ring.default_color = flash_color.lightened(0.4)
	var ring_points = []
	for i in range(13):
		var angle = i * (PI * 2 / 12)
		ring_points.append(Vector2(cos(angle), sin(angle)) * 10)
	ring.points = PackedVector2Array(ring_points)
	ring.position = muzzle_flash.position
	add_child(ring)

	# Animate
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(5, 5), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.15)
	tween.tween_property(core, "modulate:a", 0.0, 0.1)
	tween.tween_property(line_flash, "modulate:a", 0.0, 0.1)
	tween.tween_callback(func():
		ring.queue_free()
		core.queue_free()
		line_flash.queue_free()
	)

func select():
	selection_indicator.visible = true

func deselect():
	selection_indicator.visible = false

func _physics_process(delta):
	# Decrement target cache timer
	if target_cache_timer > 0:
		target_cache_timer -= delta

	var current_state = store.get_state()
	if current_state == null or not current_state.has("ships"):
		return
	if not current_state.ships.has(ship_data.id):
		queue_free()
		return

	var my_current_data = current_state.ships[ship_data.id]

	# === PROGENITOR DRONE SPECIAL BEHAVIOR ===
	if ship_data.type == VnpTypes.ShipType.PROGENITOR_DRONE:
		_process_progenitor_drone(delta, current_state)
		return  # Drones don't use normal ship AI

	var target_ship_data = null
	var is_factory_target = false
	if my_current_data.target:
		if current_state.ships.has(my_current_data.target):
			target_ship_data = current_state.ships.get(my_current_data.target)
		elif my_current_data.target is String and current_state.has("factories") and current_state.factories.has(my_current_data.target):
			# Target is a factory
			target_ship_data = current_state.factories.get(my_current_data.target)
			is_factory_target = true

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

			# PROGENITOR SURVIVAL MODE: When the Progenitor emerges, prioritize defense
			var progenitor_active = _is_progenitor_active(current_state)
			if progenitor_active and ship_data.type != VnpTypes.ShipType.HARVESTER:
				# Hunt Progenitor drones first - they're the real threat now
				var drone_target = _find_nearest_progenitor_drone(current_state)
				if drone_target != -1:
					_dispatch_state_change("attacking", drone_target)
					return

				# No drones visible - patrol between our factories
				var patrol_target = _get_factory_patrol_target(current_state)
				if patrol_target != Vector2.ZERO:
					_dispatch_state_change("moving", patrol_target)
					return

			if is_loose:
				# LOOSE: Simple old behavior - attack nearest enemy or push to center
				# HARVESTER: Special behavior - find location to build factory
				if ship_data.type == VnpTypes.ShipType.HARVESTER:
					var factory_target = _find_factory_build_location(current_state)
					if factory_target != Vector2.ZERO:
						var dist_to_target = position.distance_to(factory_target)
						if dist_to_target > 40:
							# Move to build location
							_dispatch_state_change("moving", factory_target)
						else:
							# At build location - ACTIVELY BRAKE to allow camping detection
							current_velocity = current_velocity.lerp(Vector2.ZERO, 5.0 * delta)
							if current_velocity.length() < 3:
								current_velocity = Vector2.ZERO
							velocity = current_velocity
							move_and_slide()
					else:
						# No good build location - just idle near base
						if vnp_main and vnp_main.base_nodes.has(ship_data.team):
							var base_pos = vnp_main.base_nodes[ship_data.team].position
							var offset = Vector2(randf_range(-100, 100), randf_range(-100, 100))
							_dispatch_state_change("moving", base_pos + offset)
					return

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
						# Use real position from ship node if available (state may be stale)
						var enemy_pos = current_state.ships[target_id].position
						if vnp_main and vnp_main.ship_nodes.has(target_id):
							var enemy_node = vnp_main.ship_nodes[target_id]
							if is_instance_valid(enemy_node):
								enemy_pos = enemy_node.global_position
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
				# But harvesters always seek factory build locations
				if ship_data.type == VnpTypes.ShipType.HARVESTER:
					var factory_target = _find_factory_build_location(current_state)
					if factory_target != Vector2.ZERO:
						var dist_to_target = position.distance_to(factory_target)
						if dist_to_target > 40:
							_dispatch_state_change("moving", factory_target)
						# else: Stay put - camping will handle building
					return

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
			# PROGENITOR_DRONE doesn't attack normally - it absorbs
			if ship_data.type == VnpTypes.ShipType.PROGENITOR_DRONE:
				return

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
			var base_range = ship_stats.get("range", 200)
			var effective_range = base_range * tactics.range_mult

			# Range-aware kiting/diving logic override
			var my_speed = ship_stats.get("speed", 100)
			var target_type = target_ship_data.get("type", -1)
			var target_stats = VnpTypes.SHIP_STATS.get(target_type, {})
			var target_range = target_stats.get("range", 200)
			var target_speed = target_stats.get("speed", 100)

			# KITING: If we outrange by 100+ units, maintain distance
			if base_range > target_range + 100:
				tactics.keep_distance = true
				# If slower, stay at max range; if faster, can close slightly
				tactics.range_mult = 1.0 if my_speed < target_speed else 0.9
				tactics.rush = false
			# DIVING: If outranged by 100+ units, close the gap fast
			elif target_range > base_range + 100:
				tactics.rush = true
				tactics.range_mult = 0.5  # Get to MY optimal range

			effective_range = base_range * tactics.range_mult  # Recalculate

			# Rush behavior - close distance aggressively
			if tactics.rush and distance_to_target > effective_range * 0.7:
				_rush_target(target_ship_data.position, delta)
			elif distance_to_target > base_range:
				_move_to(target_ship_data.position)
			else:
				# Size-based combat movement with tactical modifiers
				match ship_size:
					VnpTypes.ShipSize.SMALL:
						# Small ships: Constant strafing runs - never stop!
						_strafe_around_target_tactical(target_ship_data.position, delta, tactics, current_state)
					VnpTypes.ShipSize.MEDIUM:
						# Medium ships: Kite at max range OR orbit normally
						if tactics.keep_distance:
							# Kiting: strafe sideways at maximum range
							_strafe_at_max_range(target_ship_data.position, delta)
						else:
							# Normal combat: slow orbit while firing
							var orbit_speed = 0.4 if not tactics.rush else 0.6
							_orbit_target(target_ship_data.position, delta, orbit_speed)
					VnpTypes.ShipSize.LARGE:
						# Large ships (Cruiser): Always orbit at 85% range - never stop
						# Slower orbit for heavy ships, slightly faster when keeping distance
						var orbit_speed = 0.35 if not tactics.keep_distance else 0.45
						_orbit_target(target_ship_data.position, delta, orbit_speed)
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

	# Throttled position sync - only update state every POSITION_SYNC_INTERVAL
	# This reduces dispatch spam from 60/sec to 2/sec per ship
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_position_sync_time >= POSITION_SYNC_INTERVAL:
		if self.position.distance_squared_to(last_synced_position) > 100:  # Only if moved >10 units
			last_position_sync_time = current_time
			last_synced_position = self.position
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

	# Apply convergence pull (The Progenitor's gravity)
	_apply_convergence_pull(get_physics_process_delta_time())

	# Clamp to max speed
	var max_speed = ship_stats.speed * 1.2  # Slight overspeed allowed with momentum
	if current_velocity.length() > max_speed:
		current_velocity = current_velocity.normalized() * max_speed

	# Apply space drag (subtle friction)
	current_velocity = current_velocity.lerp(Vector2.ZERO, SPACE_DRAG * get_physics_process_delta_time())

	velocity = current_velocity
	move_and_slide()


func _apply_convergence_pull(delta: float):
	"""Apply gravitational pull toward The Progenitor's convergence point"""
	if not vnp_main:
		return

	var current_state = store.get_state()
	if current_state == null or not current_state.has("convergence"):
		return

	var convergence = current_state.convergence
	var phase = convergence.get("phase", VnpTypes.ConvergencePhase.DORMANT)

	# No pull during dormant, whispers, or contact phases
	if phase < VnpTypes.ConvergencePhase.EMERGENCE:
		return

	var pull_strength = convergence.get("pull_strength", 0.0)
	if pull_strength <= 0:
		return

	var convergence_center = convergence.get("center", Vector2.ZERO)
	var absorption_radius = convergence.get("absorption_radius", 1000.0)

	# Calculate pull direction and distance
	var to_center = convergence_center - global_position
	var distance = to_center.length()

	if distance < 10:
		return  # Already at center

	var direction = to_center.normalized()

	# Pull gets STRONGER near the edge (inverse relationship)
	# At center: minimal pull. At edge: maximum pull.
	var edge_factor = distance / absorption_radius
	edge_factor = clamp(edge_factor, 0.2, 1.5)  # 0.2 at center, up to 1.5 at edge

	# Calculate pull force
	var pull_force = direction * pull_strength * edge_factor * delta

	# Ships can resist with thrust, but the pull is always there
	current_velocity += pull_force

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

	# Apply convergence pull (The Progenitor's gravity)
	_apply_convergence_pull(delta)

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
	var optimal_range = ship_stats.get("range", 200) * 0.8

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

	# Apply convergence pull (The Progenitor's gravity)
	_apply_convergence_pull(delta)

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
	var optimal_range = ship_stats.get("range", 200) * tactics.range_mult
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

	# Apply convergence pull (The Progenitor's gravity)
	_apply_convergence_pull(delta)

	# Max speed
	if current_velocity.length() > ship_stats.speed * 1.2:
		current_velocity = current_velocity.normalized() * ship_stats.speed * 1.2

	# Drag - less when scattering for more drift
	var drag_mult = 0.5 if tactics.scatter else 0.7
	current_velocity = current_velocity.lerp(Vector2.ZERO, SPACE_DRAG * drag_mult * delta)

	velocity = current_velocity
	move_and_slide()

	# Face target
	var to_target_dir = target_pos - position
	var target_angle = to_target_dir.angle()
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

	var range_val = ship_stats.get("range", 200)
	if ally_count == 0:
		return target_pos + Vector2(cos(strafe_angle), sin(strafe_angle)) * range_val * 0.8

	ally_center /= ally_count

	# Position on opposite side of target from allies
	var target_to_allies = (ally_center - target_pos).normalized()
	var flank_dir = -target_to_allies  # Opposite side
	return target_pos + flank_dir * range_val * 0.8


func _orbit_target(target_pos: Vector2, delta: float, speed_mult: float = 0.5):
	# Slower orbit for medium ships with momentum - controlled but weighty
	var to_target = target_pos - position
	var distance = to_target.length()
	var optimal_range = ship_stats.get("range", 200) * 0.85

	# Slow orbit
	strafe_angle += strafe_direction * delta * 1.2

	# Calculate orbit position
	var orbit_offset = Vector2(cos(strafe_angle), sin(strafe_angle)) * optimal_range
	var desired_pos = target_pos + orbit_offset

	# Thrust towards orbit position
	var thrust_dir = (desired_pos - position).normalized()
	var orbit_thrust = thrust_dir * ship_stats.speed * THRUST_MULTIPLIER * speed_mult
	current_velocity += orbit_thrust * delta

	# Apply convergence pull (The Progenitor's gravity)
	_apply_convergence_pull(delta)

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


func _strafe_at_max_range(target_pos: Vector2, delta: float):
	# Max-range strafing for kiting ships (Destroyers)
	# Move sideways at weapon range edge - never get closer than necessary
	var to_target = target_pos - position
	var distance = to_target.length()
	var max_range = ship_stats.get("range", 200)
	var optimal_range = max_range * 0.95  # Small buffer to stay in range

	# Calculate perpendicular strafe direction
	var to_target_normalized = to_target.normalized()
	var strafe_dir = to_target_normalized.rotated(PI / 2) * strafe_direction

	# Occasionally reverse strafe direction
	strafe_angle += strafe_direction * delta * 1.5
	if randf() < 0.012:
		strafe_direction *= -1

	# Range correction: back away if too close, close in if too far
	var range_correction = Vector2.ZERO
	if distance < optimal_range * 0.9:
		# Too close - back away while strafing
		range_correction = -to_target_normalized * (optimal_range - distance) * 0.6
	elif distance > max_range:
		# Too far - close in slightly
		range_correction = to_target_normalized * (distance - max_range) * 0.4

	# Combined movement: strafe + range correction
	var thrust_dir = (strafe_dir + range_correction).normalized()
	var strafe_thrust = thrust_dir * ship_stats.speed * THRUST_MULTIPLIER * 0.7
	current_velocity += strafe_thrust * delta

	# Apply convergence pull
	_apply_convergence_pull(delta)

	# Max speed for controlled strafing
	var max_speed = ship_stats.speed * 0.85
	if current_velocity.length() > max_speed:
		current_velocity = current_velocity.normalized() * max_speed

	# Moderate drag for controlled feel
	current_velocity = current_velocity.lerp(Vector2.ZERO, SPACE_DRAG * 0.9 * delta)

	velocity = current_velocity
	move_and_slide()

	# Face target while strafing
	var target_angle = to_target.angle()
	rotation = lerp_angle(rotation, target_angle, 3.5 * delta)

	# Fire side thrusters based on lateral movement
	var facing_dir = Vector2.RIGHT.rotated(rotation)
	var lateral = facing_dir.rotated(PI/2).dot(current_velocity.normalized())
	_fire_side_thrusters(lateral * 0.8)


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
	# Use cached target if still valid (ships only - factories don't cache)
	if cached_target_id != -1 and target_cache_timer > 0:
		if state.ships.has(cached_target_id):
			return cached_target_id
		else:
			# Target died, clear cache
			cached_target_id = -1

	# Cache expired or no cached target - search for new one
	var rally_point = _get_rally_point(state)
	var weapon_range = ship_stats.get("range", 300)

	var target_id = VnpSystems.find_best_target(
		position,
		ship_data.team,
		weapon_range,
		rally_point,
		state.ships
	)

	# If no ships in range, look for enemy factories
	if target_id == -1 and state.has("factories"):
		var factory_target = _find_nearest_enemy_factory(state)
		if factory_target != "":
			return factory_target  # Factory ID is a string like "factory_1_0"

	# Cache the result
	if target_id != -1:
		cached_target_id = target_id
		target_cache_timer = TARGET_CACHE_DURATION

	return target_id


func _find_nearest_enemy_factory(state) -> String:
	"""Find nearest enemy factory to attack"""
	if not state.has("factories"):
		return ""

	var best_factory_id = ""
	var min_dist = INF

	for factory_id in state.factories:
		var factory = state.factories[factory_id]
		if factory.team == ship_data.team:
			continue  # Skip our own factories
		if not factory.get("complete", false):
			continue  # Only attack completed factories

		var dist = position.distance_to(factory.position)
		if dist < min_dist:
			min_dist = dist
			best_factory_id = factory_id

	return best_factory_id


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
	if current_state == null or not current_state.has("ships"):
		return
	var my_current_data = current_state.ships.get(ship_data.id)

	if not my_current_data or my_current_data.state != "attacking":
		return

	var target_id = my_current_data.target
	var target_data = null
	var is_factory_target = false
	var damage_multiplier = 1.0

	if current_state.ships.has(target_id):
		target_data = current_state.ships[target_id]
		var target_stats = VnpTypes.SHIP_STATS[target_data.type]
		# Get damage multiplier safely - some weapons (PDC, TURBOLASER, etc) don't have multipliers
		var weapon_multipliers = VnpTypes.DAMAGE_MULTIPLIERS.get(ship_stats.get("weapon", -1), {})
		damage_multiplier = weapon_multipliers.get(target_stats.get("weapon", -1), 1.0)
	elif target_id is String and current_state.has("factories") and current_state.factories.has(target_id):
		# Targeting a factory
		target_data = current_state.factories[target_id]
		is_factory_target = true
		damage_multiplier = 1.5  # Bonus damage vs structures

	if target_data == null:
		return

	# Skip firing for ships without weapons (like PROGENITOR_DRONE)
	var weapon = ship_stats.get("weapon", null)
	if weapon == null:
		return

	# Apply damage bonus from controlled strategic points (e.g., Command Center)
	var point_damage_bonus = _get_strategic_point_damage_bonus(current_state, ship_data.team)
	var base_damage = ship_stats.get("damage", 0)
	var total_damage = base_damage * damage_multiplier * (1.0 + point_damage_bonus)

	# Show muzzle flash for all weapons
	_show_muzzle_flash()

	# Play weapon sound
	if sound_manager:
		match weapon:
			VnpTypes.WeaponType.LASER:
				sound_manager.play_laser()
			VnpTypes.WeaponType.GUN:
				sound_manager.play_railgun()
			VnpTypes.WeaponType.MISSILE:
				sound_manager.play_missile_launch()
			VnpTypes.WeaponType.TURBOLASER:
				sound_manager.play_turbolaser()

	match weapon:
		VnpTypes.WeaponType.VOID_TENDRIL:
			# VOID TENDRIL: Ancient probe attack - reaching tendrils of void energy
			_fire_void_tendril(target_id, target_data, total_damage)
			return

		VnpTypes.WeaponType.LASER:
			# LASER: Instant hit with sustained burn effect - more visible
			var laser_color = VnpTypes.get_weapon_color(ship_data.team, VnpTypes.WeaponType.LASER)

			# Main beam - thick bright core
			laser_beam.default_color = Color(laser_color.r * 1.3, laser_color.g * 1.3, laser_color.b * 1.3, 1.0)
			laser_beam.clear_points()
			laser_beam.add_point(Vector2.ZERO)
			laser_beam.add_point(to_local(target_data.position))

			# Create wide outer glow beam - add to root so it doesn't move with ship
			var glow_beam = Line2D.new()
			glow_beam.default_color = Color(laser_color.r, laser_color.g, laser_color.b, 0.5)
			glow_beam.width = 36.0  # Wider glow
			glow_beam.add_point(global_position)
			glow_beam.add_point(target_data.position)
			get_tree().root.add_child(glow_beam)

			# Create inner bright core beam - static in world space
			var core_beam = Line2D.new()
			core_beam.default_color = Color(1.0, 1.0, 1.0, 0.9)  # White-hot core
			core_beam.width = 6.0
			core_beam.add_point(global_position)
			core_beam.add_point(target_data.position)
			get_tree().root.add_child(core_beam)

			# Animate beam fade - use sequential tween with proper cleanup
			var tween = create_tween()
			tween.tween_property(laser_beam, "width", 0.0, 0.25).from(18.0)

			var glow_tween = get_tree().create_tween()
			glow_tween.tween_property(glow_beam, "modulate:a", 0.0, 0.25)
			glow_tween.tween_callback(func(): glow_beam.queue_free())

			var core_tween = get_tree().create_tween()
			core_tween.tween_property(core_beam, "modulate:a", 0.0, 0.15)
			core_tween.tween_callback(func(): core_beam.queue_free())

			# Burning impact at target - larger
			var impact = ImpactFxScene.instantiate()
			get_tree().root.add_child(impact)
			impact.global_position = target_data.position
			impact.scale = Vector2(2.0, 2.0)  # Larger burn mark
			impact.emitting = true

			# Instant damage - lasers are precise (dispatch to factory or ship)
			if is_factory_target:
				store.dispatch({ "type": "DAMAGE_FACTORY", "factory_id": target_id, "damage": total_damage })
			else:
				store.dispatch({ "type": "DAMAGE_SHIP", "ship_id": target_id, "damage": total_damage })

		VnpTypes.WeaponType.GUN:
			# RAILGUN: Punchy power surge + piercing projectile
			_show_railgun_power_surge()
			var projectile = vnp_main.get_projectile()
			projectile.init({
				"team": ship_data.team,
				"weapon_type": weapon,
				"damage": total_damage,
				"start_position": self.global_position,
				"start_rotation": self.rotation,
				"target_id": target_id,
				"is_factory_target": is_factory_target,
				"store": store,
				"vnp_main": vnp_main,
			})

		VnpTypes.WeaponType.MISSILE:
			# MISSILE SALVO: Fire 3 missiles in a shower pattern
			var missile_count = 3
			var factory_flag = is_factory_target  # Capture for lambda
			for i in range(missile_count):
				# Stagger launch slightly for shower effect
				var delay = i * 0.08
				var spread_index = i
				var main_ref = vnp_main  # Capture reference for lambda
				get_tree().create_timer(delay).timeout.connect(func():
					if not is_instance_valid(self):
						return
					var m_projectile = main_ref.get_projectile()
					# Spread missiles with different arc offsets
					m_projectile.init({
						"team": ship_data.team,
						"weapon_type": weapon,
						"damage": total_damage / missile_count,  # Split damage across salvo
						"start_position": self.global_position,
						"start_rotation": self.rotation + (spread_index - 1) * 0.12,  # Slight angle spread
						"target_id": target_id,
						"is_factory_target": factory_flag,
						"arc_height_mult": 0.4 + randf() * 0.35,  # Varied arc heights
						"store": store,
						"vnp_main": main_ref,
					})
				)

		VnpTypes.WeaponType.TURBOLASER:
			# TURBOLASER: Slow but devastating projectile - Star Destroyer style
			# Easy for small fast ships to dodge, deadly to capitals
			_show_turbolaser_charge()
			var turbo_projectile = vnp_main.get_projectile()
			turbo_projectile.init({
				"team": ship_data.team,
				"weapon_type": VnpTypes.WeaponType.TURBOLASER,
				"damage": total_damage,
				"start_position": self.global_position,
				"start_rotation": self.rotation,
				"target_id": target_id,
				"is_factory_target": is_factory_target,
				"turbolaser_speed": ship_stats.get("turbolaser_speed", 180),
				"turbolaser_size": ship_stats.get("turbolaser_size", 12),
				"store": store,
				"vnp_main": vnp_main,
			})

func _fire_void_tendril(target_id: int, target_data: Dictionary, damage: float):
	"""Fire void tendril attack - reaching tendrils of ancient void energy - MORE VISIBLE"""
	var tendril_color = VnpTypes.get_weapon_color(ship_data.team, VnpTypes.WeaponType.VOID_TENDRIL)
	var target_pos = target_data.position

	# Create multiple wispy tendrils reaching toward target - thicker and brighter
	for i in range(4):  # More tendrils
		var tendril = Line2D.new()
		tendril.width = 5.0 + randf() * 3.0  # Thicker
		tendril.default_color = Color(tendril_color.r * 1.3, tendril_color.g * 1.3, tendril_color.b * 1.3, 0.85)
		tendril.z_index = 5

		# Create wavy tendril path
		var points = []
		var segments = 10  # More segments for smoother waves
		var local_target = to_local(target_pos)
		for j in range(segments + 1):
			var t = float(j) / segments
			var base_pos = Vector2.ZERO.lerp(local_target, t)
			# Add waviness that's perpendicular to direction
			var perp = local_target.normalized().orthogonal()
			var wave = sin(t * PI * 3 + i * PI / 4) * (30 - t * 20)  # Larger waves
			points.append(base_pos + perp * wave)
		tendril.points = PackedVector2Array(points)
		add_child(tendril)

		# Animate tendril - reaches out then fades
		var tendril_tween = create_tween()
		tendril_tween.tween_property(tendril, "modulate:a", 0.0, 0.4).set_delay(0.1 + i * 0.05)
		tendril_tween.tween_callback(func(): tendril.queue_free())

	# Add a bright core tendril through the center
	var core_tendril = Line2D.new()
	core_tendril.width = 3.0
	core_tendril.default_color = Color(1.0, 1.0, 0.9, 0.9)  # Bright white-yellow
	core_tendril.z_index = 6
	core_tendril.add_point(Vector2.ZERO)
	core_tendril.add_point(to_local(target_pos))
	add_child(core_tendril)

	var core_tween = create_tween()
	core_tween.tween_property(core_tendril, "modulate:a", 0.0, 0.2)
	core_tween.tween_callback(func(): core_tendril.queue_free())

	# Void pulse at our position - larger
	var pulse = Line2D.new()
	pulse.width = 6.0  # Thicker
	pulse.default_color = VnpTypes.PROGENITOR_PULSE
	var pulse_points = []
	for k in range(17):
		var angle = k * (PI * 2 / 16)
		pulse_points.append(Vector2(cos(angle), sin(angle)) * 20)  # Larger
	pulse.points = PackedVector2Array(pulse_points)
	add_child(pulse)

	var pulse_tween = create_tween()
	pulse_tween.set_parallel(true)
	pulse_tween.tween_property(pulse, "scale", Vector2(3.0, 3.0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pulse_tween.tween_property(pulse, "modulate:a", 0.0, 0.25)
	pulse_tween.tween_callback(func(): pulse.queue_free())

	# Absorption effect at target
	var impact = Line2D.new()
	impact.width = 3.0
	impact.default_color = VnpTypes.PROGENITOR_ACCENT
	var impact_points = []
	for m in range(13):
		var angle = m * (PI * 2 / 12)
		impact_points.append(Vector2(cos(angle), sin(angle)) * 25)
	impact.points = PackedVector2Array(impact_points)
	impact.position = to_local(target_pos)
	add_child(impact)

	var impact_tween = create_tween()
	impact_tween.set_parallel(true)
	impact_tween.tween_property(impact, "scale", Vector2(0.3, 0.3), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	impact_tween.tween_property(impact, "modulate:a", 0.0, 0.25)
	impact_tween.tween_callback(func(): impact.queue_free())

	# Deal damage
	store.dispatch({ "type": "DAMAGE_SHIP", "ship_id": target_id, "damage": damage })


func _show_turbolaser_charge():
	# Dramatic charging effect before turbolaser fires - MORE VISIBLE
	var turbo_color = VnpTypes.get_weapon_color(ship_data.team, VnpTypes.WeaponType.TURBOLASER)

	# Big charging glow at center - larger
	var charge = Polygon2D.new()
	var charge_points = []
	for i in range(13):
		var angle = i * (PI * 2 / 12)
		charge_points.append(Vector2(cos(angle), sin(angle)) * 30)  # Larger
	charge.polygon = PackedVector2Array(charge_points)
	charge.color = Color(turbo_color.r * 1.2, turbo_color.g * 1.2, turbo_color.b * 1.2, 0.9)
	add_child(charge)

	# Bright core flash
	var core = Polygon2D.new()
	var core_points = []
	for i in range(9):
		var angle = i * (PI * 2 / 8)
		core_points.append(Vector2(cos(angle), sin(angle)) * 12)
	core.polygon = PackedVector2Array(core_points)
	core.color = Color(1.0, 1.0, 1.0, 0.95)  # White-hot core
	add_child(core)

	# Expanding ring - larger
	var ring = Line2D.new()
	ring.width = 8.0
	ring.default_color = turbo_color.lightened(0.4)
	var ring_points = []
	for i in range(25):
		var angle = i * (PI * 2 / 24)
		ring_points.append(Vector2(cos(angle), sin(angle)) * 40)  # Larger
	ring.points = PackedVector2Array(ring_points)
	add_child(ring)

	# Animate charge and ring
	var charge_tween = create_tween()
	charge_tween.set_parallel(true)
	charge_tween.tween_property(charge, "scale", Vector2(2.5, 2.5), 0.25).from(Vector2(0.5, 0.5))
	charge_tween.tween_property(charge, "modulate:a", 0.0, 0.35)
	charge_tween.tween_callback(func(): charge.queue_free())

	var core_tween = create_tween()
	core_tween.tween_property(core, "modulate:a", 0.0, 0.15)
	core_tween.tween_callback(func(): core.queue_free())

	var ring_tween = create_tween()
	ring_tween.set_parallel(true)
	ring_tween.tween_property(ring, "scale", Vector2(3.5, 3.5), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ring_tween.tween_property(ring, "modulate:a", 0.0, 0.3)
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
		VnpTypes.ShipType.PROGENITOR_DRONE:
			# Large alien hunter - organic and terrifying
			# Massive tendrils reaching forward like grasping claws
			var drone_scale = ship_stats.get("scale", 1.8)
			polygon.polygon = _scale_polygon([
				Vector2(24, 0), Vector2(16, -5), Vector2(10, -14), Vector2(4, -8),
				Vector2(-4, -16), Vector2(-10, -6), Vector2(-16, -10), Vector2(-12, 0),
				Vector2(-16, 10), Vector2(-10, 6), Vector2(-4, 16), Vector2(4, 8),
				Vector2(10, 14), Vector2(16, 5)
			], drone_scale)

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

	# Create 4-5 tracer lines - more visible
	var tracer_count = randi_range(4, 5)
	for i in range(tracer_count):
		# Outer glow tracer
		var glow_tracer = Line2D.new()
		glow_tracer.width = 6.0  # Wide glow
		glow_tracer.default_color = Color(pdc_color.r, pdc_color.g, pdc_color.b, 0.4)

		# Bright core tracer
		var tracer = Line2D.new()
		tracer.width = 3.0  # Thicker core
		tracer.default_color = Color(pdc_color.r * 1.3, pdc_color.g * 1.3, pdc_color.b * 1.3, 1.0)

		# Spread pattern
		var spread = Vector2(randf_range(-25, 25), randf_range(-25, 25))
		var end_pos = target_pos + spread

		glow_tracer.add_point(global_position)
		glow_tracer.add_point(end_pos)
		tracer.add_point(global_position)
		tracer.add_point(end_pos)

		get_tree().root.add_child(glow_tracer)
		get_tree().root.add_child(tracer)

		# Quick fade
		var tween = get_tree().create_tween()
		tween.tween_property(tracer, "modulate:a", 0.0, 0.12)
		tween.tween_callback(func(): tracer.queue_free())

		var glow_tween = get_tree().create_tween()
		glow_tween.tween_property(glow_tracer, "modulate:a", 0.0, 0.15)
		glow_tween.tween_callback(func(): glow_tracer.queue_free())

	# Skip GPU particles for PDC - too expensive for high fire rate
	# Just use the muzzle flash instead
	_show_muzzle_flash()


func _intercept_missile(missile_node):
	# Create interception explosion - simplified using Line2D ring
	var intercept_pos = missile_node.global_position
	var pdc_color = VnpTypes.get_weapon_color(ship_data.team, VnpTypes.WeaponType.PDC)

	# Expanding ring effect (no GPU particles)
	var ring = Line2D.new()
	ring.global_position = intercept_pos
	ring.width = 4.0
	ring.default_color = Color(1.0, 1.0, 1.0, 0.9)

	var ring_points = []
	for i in range(13):
		var angle = i * (PI * 2 / 12)
		ring_points.append(Vector2(cos(angle), sin(angle)) * 8)
	ring.points = PackedVector2Array(ring_points)
	get_tree().root.add_child(ring)

	# Expand and fade
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2(5, 5), 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, 0.2)
	tween.tween_property(ring, "default_color", pdc_color, 0.1)
	tween.tween_callback(func(): ring.queue_free())

	# Destroy the missile
	missile_node.queue_free()


var shield_flare_cooldown: float = 0.0

func _run_shield_defense(delta, state):
	if not is_instance_valid(shield_bubble):
		return

	shield_flare_cooldown -= delta

	# Shield provides damage reduction to nearby allies
	var shield_radius = ship_stats.get("shield_radius", 120)
	var shield_color = VnpTypes.get_weapon_color(ship_data.team, VnpTypes.WeaponType.SHIELD)

	# Count protected allies for visual feedback
	var protected_count = 0
	for other_ship_id in state.ships:
		var other_ship = state.ships[other_ship_id]
		if other_ship.team == ship_data.team and other_ship_id != ship_data.id:
			var dist = global_position.distance_to(other_ship.position)
			if dist <= shield_radius:
				protected_count += 1

	# SPECTACULAR protection visuals
	if protected_count > 0:
		# Intensify shield when protecting
		if is_instance_valid(shield_outer_ring):
			shield_outer_ring.width = 6.0
			shield_outer_ring.default_color = Color(shield_color.r * 1.3, shield_color.g * 1.3, shield_color.b * 1.3, 0.8)
		if is_instance_valid(shield_inner_glow):
			shield_inner_glow.width = 18.0
			shield_inner_glow.default_color = Color(shield_color.r, shield_color.g, shield_color.b, 0.4)

		# Spawn protection flares occasionally
		if shield_flare_cooldown <= 0:
			shield_flare_cooldown = 0.3
			_spawn_shield_flare(shield_radius, shield_color)
	else:
		# Return to normal
		if is_instance_valid(shield_outer_ring):
			shield_outer_ring.width = 4.0
			shield_outer_ring.default_color = Color(shield_color.r, shield_color.g, shield_color.b, 0.6)
		if is_instance_valid(shield_inner_glow):
			shield_inner_glow.width = 12.0
			shield_inner_glow.default_color = Color(shield_color.r * 1.2, shield_color.g * 1.2, shield_color.b * 1.2, 0.25)


func _spawn_shield_flare(radius: float, color: Color):
	# Random position on shield perimeter
	var angle = randf() * TAU
	var flare_pos = Vector2(cos(angle), sin(angle)) * radius

	# Flare burst
	var flare = Polygon2D.new()
	var flare_points = []
	for i in range(7):
		var a = i * (TAU / 6)
		flare_points.append(Vector2(cos(a), sin(a)) * 8)
	flare.polygon = PackedVector2Array(flare_points)
	flare.color = Color(color.r * 1.5, color.g * 1.5, color.b * 1.5, 0.9)
	flare.position = flare_pos
	add_child(flare)

	# Animate flare
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(flare, "scale", Vector2(2.5, 2.5), 0.2).from(Vector2(0.5, 0.5))
	tween.tween_property(flare, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func(): flare.queue_free())


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
	# SPECTACULAR DEFLECTION - Ripples, sparks, and energy discharge
	var gravity_color = VnpTypes.get_weapon_color(ship_data.team, VnpTypes.WeaponType.GRAVITY)

	# === RIPPLE WAVE - Expanding shockwave from deflection point ===
	var ripple = Line2D.new()
	ripple.global_position = projectile_pos
	ripple.width = 6.0
	ripple.default_color = Color(gravity_color.r * 1.5, gravity_color.g * 1.5, gravity_color.b * 1.5, 0.9)
	var ripple_points = []
	for i in range(33):
		var angle = i * (PI * 2 / 32)
		ripple_points.append(Vector2(cos(angle), sin(angle)) * 10)
	ripple.points = PackedVector2Array(ripple_points)
	get_tree().root.add_child(ripple)

	# Expand and fade
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(ripple, "scale", Vector2(8, 8), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ripple, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func(): ripple.queue_free())

	# === SECOND RIPPLE - Delayed follow-up ===
	var ripple2 = Line2D.new()
	ripple2.global_position = projectile_pos
	ripple2.width = 3.0
	ripple2.default_color = Color(gravity_color.r, gravity_color.g, gravity_color.b, 0.6)
	ripple2.points = PackedVector2Array(ripple_points)
	get_tree().root.add_child(ripple2)

	var tween2 = get_tree().create_tween()
	tween2.set_parallel(true)
	tween2.tween_property(ripple2, "scale", Vector2(5, 5), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).set_delay(0.05)
	tween2.tween_property(ripple2, "modulate:a", 0.0, 0.25).set_delay(0.05)
	tween2.tween_callback(func(): ripple2.queue_free())

	# === SPARKS - Energy discharge flying outward ===
	for i in range(6):
		var spark = Line2D.new()
		spark.global_position = projectile_pos
		spark.width = 3.0
		spark.default_color = Color(1.0, 1.0, 0.9, 0.9)  # Bright white-yellow

		var spark_angle = randf() * TAU
		var spark_length = randf_range(15, 30)
		spark.add_point(Vector2.ZERO)
		spark.add_point(Vector2(cos(spark_angle), sin(spark_angle)) * spark_length)
		get_tree().root.add_child(spark)

		# Animate spark flying outward
		var spark_tween = get_tree().create_tween()
		spark_tween.set_parallel(true)
		var end_pos = projectile_pos + Vector2(cos(spark_angle), sin(spark_angle)) * randf_range(40, 80)
		spark_tween.tween_property(spark, "global_position", end_pos, 0.2)
		spark_tween.tween_property(spark, "modulate:a", 0.0, 0.2)
		spark_tween.tween_callback(func(): spark.queue_free())

	# === DEFLECTION ARC - Shows the bent trajectory ===
	var arc = Line2D.new()
	arc.global_position = projectile_pos
	arc.width = 4.0
	arc.default_color = Color(gravity_color.r * 1.3, gravity_color.g * 1.3, gravity_color.b * 1.3, 0.7)
	arc.add_point(Vector2.ZERO)
	arc.add_point(deflect_direction * 50)
	get_tree().root.add_child(arc)

	var arc_tween = get_tree().create_tween()
	arc_tween.tween_property(arc, "modulate:a", 0.0, 0.3)
	arc_tween.tween_callback(func(): arc.queue_free())

	# Brief flash on gravity well
	if is_instance_valid(gravity_well):
		var flash_tween = create_tween()
		flash_tween.tween_property(gravity_well, "modulate", Color(1.8, 1.8, 2.0, 1.3), 0.05)
		flash_tween.tween_property(gravity_well, "modulate", Color.WHITE, 0.25)


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


func _is_progenitor_active(state: Dictionary) -> bool:
	"""Check if Progenitor has emerged and is a threat"""
	if not state.has("convergence"):
		return false
	var phase = state.convergence.get("phase", VnpTypes.ConvergencePhase.DORMANT)
	return phase >= VnpTypes.ConvergencePhase.EMERGENCE


func _find_nearest_progenitor_drone(state: Dictionary) -> int:
	"""Find the nearest Progenitor drone to attack"""
	var nearest_id = -1
	var nearest_dist = INF

	for other_id in state.ships:
		var other = state.ships[other_id]
		if other.type != VnpTypes.ShipType.PROGENITOR_DRONE:
			continue

		var other_pos = other.position
		if vnp_main and vnp_main.ship_nodes.has(other_id):
			var node = vnp_main.ship_nodes[other_id]
			if is_instance_valid(node):
				other_pos = node.global_position

		var dist = position.distance_to(other_pos)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_id = other_id

	return nearest_id


# ==============================================================================
# STRATEGIC COMMAND SYSTEM
# ==============================================================================
#
# This system manages fleet allocation and offensive targeting across factories.
# It runs periodically (every 3 seconds) to avoid per-frame overhead.
#
# ALGORITHM OVERVIEW:
# ==================
#
# PHASE 1: STRATEGIC ASSESSMENT (every 3 seconds)
# -----------------------------------------------
# 1. Calculate CENTER OF MASS of all team factories
# 2. For each factory, calculate ATTACK PROBABILITY based on:
#    a) Distance from center of mass (further = more exposed)
#    b) Distance to world edge (closer = Progenitor threat)
#    c) Proximity to enemy factories (closer = faction threat)
#    d) Proximity to unclaimed strategic points (opportunity cost)
#
# 3. Normalize probabilities so they sum to 1.0
#
# PHASE 2: FLEET ALLOCATION
# -------------------------
# 1. Each ship is assigned to a factory based on attack probability weights
# 2. Higher probability factories get proportionally more defenders
# 3. Assignment is deterministic (ship ID based) for stability
#
# PHASE 3: OFFENSIVE TARGETING (per factory)
# ------------------------------------------
# Each factory garrison has an OFFENSIVE TARGET priority:
#
# IF Progenitor active:
#   - Primary: Hunt Progenitor drones near this factory
#   - Secondary: Defend factory perimeter
#
# IF normal gameplay:
#   - Primary: Nearest enemy factory (destroy enemy production)
#   - Secondary: Nearest unclaimed strategic point (expand territory)
#   - Tertiary: Patrol factory perimeter
#
# Ships oscillate between defending their factory and pushing toward
# their factory's offensive target, creating a "breathing" defense.
#
# ==============================================================================

# Strategic command cache - recalculated periodically
var _strategic_cache = {
	"center_of_mass": Vector2.ZERO,
	"factories": {},        # factory_id -> FactoryTactics
	"last_update": 0.0,
}
const STRATEGIC_RECALC_INTERVAL = 3.0  # Recalculate every 3 seconds

# FactoryTactics structure:
# {
#   "position": Vector2,
#   "attack_probability": float (0-1),
#   "cumulative_weight": float (for weighted selection),
#   "offensive_target": Vector2 or null,
#   "offensive_target_type": "enemy_factory" | "strategic_point" | "progenitor" | "patrol"
# }


func _get_factory_patrol_target(state: Dictionary) -> Vector2:
	"""Get patrol/attack target for this ship based on strategic allocation"""
	_update_strategic_cache_if_needed(state)

	if _strategic_cache["factories"].is_empty():
		# No factories - fall back to base
		if vnp_main and vnp_main.base_nodes.has(ship_data.team):
			return vnp_main.base_nodes[ship_data.team].position
		return Vector2.ZERO

	# Get this ship's assigned factory
	var assigned = _get_ship_factory_assignment()
	if assigned.is_empty():
		return Vector2.ZERO

	var factory_pos = assigned["position"]
	var offensive_target = assigned.get("offensive_target", null)

	# Determine behavior: defend or push toward offensive target
	var progenitor_active = _is_progenitor_active(state)

	if progenitor_active:
		# During Progenitor: Stay closer to factory, hunt nearby drones
		var drone_target = _find_nearest_progenitor_drone(state)
		if drone_target != -1:
			# Found a drone - this will be handled by attacking state
			return Vector2.ZERO  # Signal to attack instead

		# No drones - patrol around factory
		return _get_patrol_position(factory_pos, 80.0)

	else:
		# Normal gameplay: Oscillate between defense and offense
		# Use time-based oscillation so ships "breathe" between positions
		var cycle_time = Time.get_ticks_msec() / 1000.0
		var oscillation = sin(cycle_time * 0.5 + ship_data.id * 0.3)  # -1 to 1

		if offensive_target and oscillation > 0.2:
			# Push toward offensive target (but not too far from factory)
			var push_distance = 150.0 * oscillation
			var direction = (offensive_target - factory_pos).normalized()
			return factory_pos + direction * push_distance
		else:
			# Defend factory perimeter
			return _get_patrol_position(factory_pos, 100.0)


func _update_strategic_cache_if_needed(state: Dictionary):
	"""Recalculate strategic cache if interval elapsed"""
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - _strategic_cache["last_update"] < STRATEGIC_RECALC_INTERVAL:
		return

	_recalculate_strategic_cache(state)
	_strategic_cache["last_update"] = current_time


func _recalculate_strategic_cache(state: Dictionary):
	"""
	PHASE 1 & 2: Calculate attack probabilities and offensive targets
	"""
	_strategic_cache["factories"].clear()

	if not state.has("factories"):
		return

	# Collect our team's factories
	var our_factories = []
	for factory_id in state.factories:
		var factory = state.factories[factory_id]
		if factory.get("team", -1) == ship_data.team and factory.get("complete", false):
			our_factories.append({
				"id": factory_id,
				"position": factory["position"]
			})

	if our_factories.is_empty():
		return

	# === PHASE 1A: Calculate Center of Mass ===
	var center_of_mass = Vector2.ZERO
	for f in our_factories:
		center_of_mass += f["position"]
	center_of_mass /= our_factories.size()
	_strategic_cache["center_of_mass"] = center_of_mass

	# Get world parameters
	var world_size = vnp_main.world_size if vnp_main else Vector2(1200, 800)
	var progenitor_active = _is_progenitor_active(state)

	# Collect enemy factories and unclaimed strategic points
	var enemy_factories = []
	for factory_id in state.factories:
		var factory = state.factories[factory_id]
		var factory_team = factory.get("team", -1)
		if factory_team != ship_data.team and factory_team != VnpTypes.Team.PROGENITOR:
			enemy_factories.append(factory["position"])

	var unclaimed_points = []
	if state.has("strategic_points"):
		for point_id in state.strategic_points:
			var point = state.strategic_points[point_id]
			if point.get("owner", null) == null:
				unclaimed_points.append(point["position"])

	# === PHASE 1B: Calculate Attack Probability for Each Factory ===
	var total_threat = 0.0
	var factory_data = []

	for f in our_factories:
		var pos = f["position"]
		var threat = _calculate_factory_threat(pos, center_of_mass, world_size,
			enemy_factories, progenitor_active)

		# Find offensive target for this factory
		var offensive_target = null
		var target_type = "patrol"

		if progenitor_active:
			# During Progenitor: No offensive target, pure defense
			target_type = "progenitor"
		else:
			# Find nearest enemy factory
			var nearest_enemy = _find_nearest_position(pos, enemy_factories)
			if nearest_enemy != Vector2.ZERO:
				offensive_target = nearest_enemy
				target_type = "enemy_factory"
			else:
				# No enemy factories - target unclaimed points
				var nearest_point = _find_nearest_position(pos, unclaimed_points)
				if nearest_point != Vector2.ZERO:
					offensive_target = nearest_point
					target_type = "strategic_point"

		factory_data.append({
			"id": f["id"],
			"position": pos,
			"threat": threat,
			"offensive_target": offensive_target,
			"offensive_target_type": target_type
		})
		total_threat += threat

	# === PHASE 2: Normalize to Probabilities and Build Cache ===
	var cumulative = 0.0
	for fd in factory_data:
		var probability = fd["threat"] / total_threat if total_threat > 0 else 1.0 / factory_data.size()
		cumulative += probability

		_strategic_cache["factories"][fd["id"]] = {
			"position": fd["position"],
			"attack_probability": probability,
			"cumulative_weight": cumulative,
			"offensive_target": fd["offensive_target"],
			"offensive_target_type": fd["offensive_target_type"]
		}


func _calculate_factory_threat(pos: Vector2, center_of_mass: Vector2,
	world_size: Vector2, enemy_factories: Array, progenitor_active: bool) -> float:
	"""
	Calculate attack probability for a single factory.
	Higher value = more likely to be attacked = needs more defense.
	"""
	var threat = 0.0

	# Factor 1: Distance from Center of Mass (30% weight)
	# Factories further from our center are more exposed
	var dist_from_com = pos.distance_to(center_of_mass)
	threat += dist_from_com * 0.3

	# Factor 2: Edge Exposure (40% weight during Progenitor, 20% otherwise)
	# Factories near world edges are vulnerable to Progenitor drones
	var dist_to_edge = min(
		pos.x,
		world_size.x - pos.x,
		pos.y,
		world_size.y - pos.y
	)
	var edge_weight = 0.4 if progenitor_active else 0.2
	var edge_exposure = max(0, 300 - dist_to_edge)
	threat += edge_exposure * edge_weight

	# Factor 3: Enemy Factory Proximity (30% weight)
	# Factories near enemy production are under threat
	for enemy_pos in enemy_factories:
		var dist = pos.distance_to(enemy_pos)
		if dist < 400:
			threat += (400 - dist) * 0.3

	# Minimum threat ensures every factory gets some defense
	return max(threat, 50.0)


func _get_ship_factory_assignment() -> Dictionary:
	"""Get the factory this ship is assigned to defend"""
	if _strategic_cache["factories"].is_empty():
		return {}

	# Deterministic assignment based on ship ID
	var ship_hash = (ship_data.id * 7919) % 10000
	var pick_value = ship_hash / 10000.0

	# Find factory based on cumulative probability distribution
	for factory_id in _strategic_cache["factories"]:
		var data = _strategic_cache["factories"][factory_id]
		if pick_value <= data["cumulative_weight"]:
			return data

	# Fallback to last factory
	var keys = _strategic_cache["factories"].keys()
	if keys.size() > 0:
		return _strategic_cache["factories"][keys.back()]
	return {}


func _get_patrol_position(center: Vector2, radius: float) -> Vector2:
	"""Get a patrol position orbiting around a center point"""
	var angle = (ship_data.id * 0.7) + (Time.get_ticks_msec() / 3000.0)
	var offset = Vector2(cos(angle), sin(angle)) * radius
	return center + offset


func _find_nearest_position(from: Vector2, positions: Array) -> Vector2:
	"""Find the nearest position from an array of positions"""
	var nearest = Vector2.ZERO
	var nearest_dist = INF

	for pos in positions:
		var dist = from.distance_to(pos)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = pos

	return nearest


func _find_factory_build_location(state: Dictionary) -> Vector2:
	"""Find a good location for harvester to build a factory.
	Target: unclaimed points OR our team's points that don't have factories yet."""
	var my_team = ship_data.team
	var my_pos = position
	var min_factory_distance = 150.0  # Don't build too close to existing factories

	# Get COMPLETE factory positions only (ignore ones being built)
	var factory_positions = []
	if state.has("factories"):
		for factory_id in state.factories:
			var factory = state.factories[factory_id]
			if factory.get("complete", false):
				factory_positions.append(factory["position"])

	if state.has("strategic_points"):
		var best_point = Vector2.ZERO
		var best_dist = INF

		for point_id in state.strategic_points:
			var point = state.strategic_points[point_id]
			var point_owner = point.get("owner", null)
			var point_pos = point["position"]

			# Target: unclaimed points OR our team's points without factories
			var is_valid_target = false
			if point_owner == null:
				# Unclaimed - go claim it
				is_valid_target = true
			elif point_owner == my_team:
				# Our point - check if it needs a factory
				var has_factory_nearby = false
				for fac_pos in factory_positions:
					if point_pos.distance_to(fac_pos) < min_factory_distance:
						has_factory_nearby = true
						break
				if not has_factory_nearby:
					is_valid_target = true

			if not is_valid_target:
				continue

			# Check factory distance for unclaimed points too
			if point_owner == null:
				var has_factory_nearby = false
				for fac_pos in factory_positions:
					if point_pos.distance_to(fac_pos) < min_factory_distance:
						has_factory_nearby = true
						break
				if has_factory_nearby:
					continue

			var dist = my_pos.distance_to(point_pos)
			if dist < best_dist:
				best_dist = dist
				best_point = point_pos

		if best_point != Vector2.ZERO:
			return best_point

	# No valid points available - return zero (harvester will idle near base)
	return Vector2.ZERO


# === PROGENITOR DRONE BEHAVIOR ===

func _process_progenitor_drone(delta: float, state: Dictionary):
	"""Progenitor drones hunt ships, fire void tendrils at range, and absorb on close contact"""
	# Find nearest non-Progenitor ship to hunt
	var nearest_target = null
	var nearest_dist = INF

	for ship_id in state.ships:
		var ship = state.ships[ship_id]
		if ship.team == VnpTypes.Team.PROGENITOR:
			continue  # Don't target other drones

		var target_pos = ship.position
		var dist = global_position.distance_to(target_pos)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_target = {"id": ship_id, "position": target_pos}

	if nearest_target == null:
		# No targets - drift toward center
		var convergence = state.get("convergence", {})
		var center = convergence.get("center", Vector2(500, 400))
		_move_drone_toward(center, delta)
		return

	var attack_range = ship_stats.get("range", 100)
	var absorption_range = 40.0  # Very close for melee absorption

	# Check for absorption (VERY close - melee grab)
	if nearest_dist <= absorption_range:
		# ABSORB THE TARGET - instant kill
		_absorb_target(nearest_target.id)
		return

	# If in attack range, set as target so we can fire void tendrils
	if nearest_dist <= attack_range:
		# Update ship state to attacking so fire timer works
		if ship_data.state != "attacking" or ship_data.get("target") != nearest_target.id:
			_dispatch_state_change("attacking", nearest_target.id)
		# Start fire rate timer if not already running
		if fire_rate_timer and fire_rate_timer.is_stopped():
			fire_rate_timer.start()

	# Move toward target with swarm behavior
	var target_pos = nearest_target.position

	# Add swarm cohesion - slightly attract toward other nearby drones
	var swarm_offset = _calculate_swarm_offset(state)
	var adjusted_target = target_pos + swarm_offset * 0.3

	_move_drone_toward(adjusted_target, delta)

	# Look menacing - face the target
	look_at(target_pos)


func _move_drone_toward(target_pos: Vector2, delta: float):
	"""Move drone toward target with blob-like smooth motion"""
	var to_target = target_pos - global_position
	var direction = to_target.normalized()
	var distance = to_target.length()

	# Slow, relentless movement
	var speed = ship_stats.get("speed", 120)

	# Blob-like wobble
	var wobble = Vector2(
		sin(Time.get_ticks_msec() * 0.003 + ship_data.id * 0.7),
		cos(Time.get_ticks_msec() * 0.004 + ship_data.id * 1.1)
	) * 30

	var move_dir = direction
	if distance > 100:
		move_dir = (direction + wobble.normalized() * 0.2).normalized()

	# Apply movement with smooth acceleration
	current_velocity = current_velocity.lerp(move_dir * speed, 3.0 * delta)

	# Apply velocity
	velocity = current_velocity
	move_and_slide()


func _calculate_swarm_offset(state: Dictionary) -> Vector2:
	"""Calculate offset to stay somewhat close to other drones (swarm cohesion)"""
	var nearby_drones = []
	var cohesion_radius = 150.0

	for ship_id in state.ships:
		var ship = state.ships[ship_id]
		if ship.team != VnpTypes.Team.PROGENITOR:
			continue
		if ship_id == ship_data.id:
			continue

		var dist = global_position.distance_to(ship.position)
		if dist < cohesion_radius:
			nearby_drones.append(ship.position)

	if nearby_drones.is_empty():
		return Vector2.ZERO

	# Calculate center of nearby drones
	var center = Vector2.ZERO
	for pos in nearby_drones:
		center += pos
	center /= nearby_drones.size()

	# Offset toward the group center
	return (center - global_position).normalized() * 50


func _absorb_target(target_id: int):
	"""Absorb a ship - drone sacrifices itself to consume the target.
	Note: Instability is added when the DRONE dies, not when it absorbs.
	This creates correct incentive: players must KILL drones to win."""
	# Dispatch absorption - removes BOTH the target and this drone
	store.dispatch({
		"type": "CONVERGENCE_ABSORB_SHIP",
		"ship_id": target_id
	})

	# Drone self-destructs - instability added via _on_drone_death when this damage kills us
	store.dispatch({
		"type": "DAMAGE_SHIP",
		"ship_id": ship_data.id,
		"damage": 9999  # Self-destruct
	})