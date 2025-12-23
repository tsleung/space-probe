extends Control
class_name MCSView

## MCS Visual Colony Renderer - Isometric 2.5D
## Unified coordinate system: everything goes through _iso_transform()
## Ground is a diamond, buildings are hex prisms with height

const _MCSTypes = preload("res://scripts/mars_colony_sim/mcs_types.gd")

# =============================================================================
# ISOMETRIC CONFIGURATION
# =============================================================================

# The ground plane is a square in world space, viewed at 30° isometric angle
# World coords: (0,0) to (WORLD_SIZE, WORLD_SIZE), height Z goes up
const WORLD_SIZE = 400.0
const WORLD_CENTER_X = 200.0
const WORLD_CENTER_Y = 200.0

# Isometric projection matrix components
# Standard 2:1 isometric: for every 2 pixels horizontal, 1 pixel vertical
const ISO_TILE_WIDTH = 2.0    # How wide a 1x1 world tile appears
const ISO_TILE_HEIGHT = 1.0   # How tall a 1x1 world tile appears (depth)
const ISO_HEIGHT_SCALE = 2.5  # How much Z height translates to screen Y (taller = more dramatic)

# Visual sizes in world units
const LIFEPOD_RADIUS = 20.0
const BUILDING_RADIUS = 15.0  # Bigger hex footprint
const COLONIST_SIZE = 2.5

# =============================================================================
# BUILDING HEIGHTS (world units) - Scale with colony tier
# =============================================================================

const BUILDING_HEIGHTS = {
	# Basic structures (Era: Survival)
	"hab_pod": 12.0,
	"greenhouse": 14.0,
	"solar_array": 4.0,
	"water_extractor": 10.0,
	"oxygenator": 12.0,
	"medical_bay": 18.0,
	"workshop": 16.0,
	# Mid-tier (Era: Growth)
	"hydroponics": 24.0,
	"factory": 30.0,
	"lab": 28.0,
	"fission_reactor": 22.0,
	"storage": 18.0,
	# High-tier (Era: Society)
	"apartment_block": 50.0,
	"hospital": 42.0,
	"research_center": 48.0,
	"university": 55.0,
	# Mega-structures (Era: Independence)
	"arcology": 120.0,
	"mega_tower": 100.0,
	"admin_spire": 80.0,
	# Superstructures (transcendence)
	"space_elevator": 300.0,
	"orbital_tether": 250.0,
}

const TIER_MULTIPLIERS = {
	"survival": 0.7,
	"growth": 1.0,
	"society": 1.4,
	"independence": 1.8,
	"transcendence": 2.5,
}

# =============================================================================
# COLORS
# =============================================================================

const COLOR_SKY = Color(0.75, 0.50, 0.42)
const COLOR_GROUND_LIGHT = Color(0.58, 0.30, 0.20)
const COLOR_GROUND_DARK = Color(0.45, 0.22, 0.14)
const COLOR_GROUND_EDGE = Color(0.35, 0.16, 0.10)
const COLOR_SHADOW = Color(0.0, 0.0, 0.0, 0.3)

const COLOR_LIFEPOD_TOP = Color(0.4, 0.6, 0.8)
const COLOR_LIFEPOD_LEFT = Color(0.25, 0.42, 0.58)
const COLOR_LIFEPOD_RIGHT = Color(0.32, 0.50, 0.68)

const COLOR_TUNNEL = Color(0.2, 0.15, 0.12)
const COLOR_TUNNEL_GLOW = Color(1.0, 0.8, 0.5, 0.5)

const BUILDING_COLORS = {
	"housing": {"top": Color(0.4, 0.6, 0.85), "left": Color(0.28, 0.42, 0.62), "right": Color(0.34, 0.52, 0.72)},
	"food": {"top": Color(0.4, 0.75, 0.4), "left": Color(0.28, 0.55, 0.28), "right": Color(0.34, 0.65, 0.34)},
	"power": {"top": Color(0.95, 0.78, 0.3), "left": Color(0.72, 0.58, 0.18), "right": Color(0.82, 0.68, 0.24)},
	"water": {"top": Color(0.35, 0.7, 0.9), "left": Color(0.22, 0.5, 0.68), "right": Color(0.28, 0.6, 0.78)},
	"industry": {"top": Color(0.65, 0.5, 0.38), "left": Color(0.45, 0.32, 0.24), "right": Color(0.55, 0.42, 0.32)},
	"medical": {"top": Color(0.85, 0.4, 0.4), "left": Color(0.62, 0.28, 0.28), "right": Color(0.72, 0.34, 0.34)},
	"research": {"top": Color(0.68, 0.4, 0.78), "left": Color(0.48, 0.28, 0.58), "right": Color(0.58, 0.34, 0.68)},
	"mega": {"top": Color(0.92, 0.92, 0.95), "left": Color(0.65, 0.68, 0.72), "right": Color(0.78, 0.80, 0.84)},
}

# =============================================================================
# STATE
# =============================================================================

var _buildings: Array = []
var _colonists: Array = []
var _year: int = 1
var _stability: float = 1.0
var _colony_tier: String = "survival"

var _time: float = 0.0
var _camera_zoom: float = 1.0
var _camera_pan: Vector2 = Vector2.ZERO
var _time_scale: float = 1.0  # Synced with game speed for animations

# Cached building layout: id -> {world_x, world_y, height, category}
var _building_layout: Dictionary = {}

var _dust_particles: Array = []
var _sandstorm_active: bool = false
var _sandstorm_intensity: float = 0.0
var _force_field_active: bool = false
var _force_field_strength: float = 1.0

# =============================================================================
# CORE ISOMETRIC TRANSFORM
# =============================================================================

func _iso_transform(world_x: float, world_y: float, world_z: float = 0.0) -> Vector2:
	"""
	THE core transform. All world coordinates go through here.
	World: X+ is east, Y+ is south, Z+ is up
	Screen: Standard 2:1 isometric projection
	"""
	# Offset from world center
	var dx = world_x - WORLD_CENTER_X
	var dy = world_y - WORLD_CENTER_Y

	# Isometric projection (2:1 ratio)
	var screen_x = (dx - dy) * ISO_TILE_WIDTH
	var screen_y = (dx + dy) * ISO_TILE_HEIGHT - world_z * ISO_HEIGHT_SCALE

	# Apply camera zoom and pan, center on control
	var result = Vector2(screen_x, screen_y)
	result = result * _camera_zoom + _camera_pan
	result += size / 2

	return result

func _iso_v2(pos: Vector2, z: float = 0.0) -> Vector2:
	"""Convenience for Vector2 + height"""
	return _iso_transform(pos.x, pos.y, z)

func _get_depth(world_x: float, world_y: float, world_z: float = 0.0) -> float:
	"""Depth for sorting: higher = draw first (further from camera)"""
	# In isometric, things with larger X+Y are further back
	# Higher Z should be drawn later (on top)
	return -(world_x + world_y) + world_z * 0.01

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready():
	clip_contents = true  # IMPORTANT: Clip to our bounds
	for i in range(30):
		_dust_particles.append({
			"x": randf() * WORLD_SIZE,
			"y": randf() * WORLD_SIZE,
			"z": randf() * 15.0,
			"vx": randf_range(-8, 8),
			"vy": randf_range(-4, 4),
			"vz": randf_range(-1, 1),
			"size": randf_range(1.5, 3.5),
			"alpha": randf_range(0.15, 0.35)
		})

func _process(delta: float):
	# Scale animation time with game speed (capped for sanity)
	var anim_scale = clampf(_time_scale / 30.0, 0.5, 4.0)
	_time += delta * anim_scale
	_update_dust(delta * anim_scale)
	queue_redraw()

func _draw():
	# Background sky with atmospheric gradient
	_draw_sky()

	# Orbital elements (behind everything)
	_draw_orbital_elements()

	# Draw isometric ground diamond
	_draw_ground()

	# Collect and sort all objects
	var objects = _collect_all_objects()
	objects.sort_custom(func(a, b): return a.depth > b.depth)

	# Draw in order
	for obj in objects:
		match obj.type:
			"tunnel": _draw_tunnel_obj(obj)
			"shadow": _draw_shadow_obj(obj)
			"building": _draw_building_obj(obj)
			"lifepod": _draw_lifepod_obj(obj)
			"colonist": _draw_colonist_obj(obj)

	# Force field dome over colony
	_draw_force_field()

	# Energy beams between major structures
	_draw_energy_network()

	# Dust on top
	_draw_dust()

	# Atmospheric effects
	_draw_atmosphere_effects()

# =============================================================================
# SKY AND ATMOSPHERE
# =============================================================================

func _draw_sky():
	"""Draw Mars sky with gradient and celestial bodies"""
	# Gradient from horizon (dusty orange) to zenith (darker rust)
	var horizon_color = Color(0.82, 0.55, 0.45)
	var zenith_color = Color(0.45, 0.28, 0.22)

	# Simple gradient via rectangles
	var bands = 8
	for i in range(bands):
		var t1 = float(i) / bands
		var t2 = float(i + 1) / bands
		var c1 = horizon_color.lerp(zenith_color, t1)
		var c2 = horizon_color.lerp(zenith_color, t2)
		var y1 = size.y * (1.0 - t1) * 0.4  # Top 40% of screen
		var y2 = size.y * (1.0 - t2) * 0.4
		draw_rect(Rect2(0, y2, size.x, y1 - y2), c1.lerp(c2, 0.5))

	# Fill rest with ground color
	draw_rect(Rect2(0, size.y * 0.4, size.x, size.y * 0.6), COLOR_SKY)

	# Phobos (small, fast moon)
	var phobos_t = fmod(_time * 0.3, 1.0)
	var phobos_x = size.x * (0.1 + phobos_t * 0.8)
	var phobos_y = size.y * (0.08 + sin(phobos_t * PI) * 0.1)
	draw_circle(Vector2(phobos_x, phobos_y), 4, Color(0.7, 0.65, 0.6))

	# Deimos (tiny, slower moon)
	var deimos_t = fmod(_time * 0.15, 1.0)
	var deimos_x = size.x * (0.9 - deimos_t * 0.7)
	var deimos_y = size.y * (0.12 + sin(deimos_t * PI) * 0.05)
	draw_circle(Vector2(deimos_x, deimos_y), 2, Color(0.65, 0.6, 0.55))

	# Stars (visible during dust-free moments)
	if not _sandstorm_active:
		for i in range(20):
			var sx = fmod(i * 137.5 + 50, size.x)
			var sy = fmod(i * 89.3 + 20, size.y * 0.35)
			var twinkle = 0.3 + sin(_time * 2.0 + i * 0.7) * 0.2
			draw_circle(Vector2(sx, sy), 1.0, Color(1.0, 1.0, 0.95, twinkle))

func _draw_orbital_elements():
	"""Draw satellites, space stations, and orbital ring in the sky"""
	# Only show orbital stuff in later tiers
	if _colony_tier == "survival":
		return

	var sky_center = Vector2(size.x * 0.5, size.y * 0.15)

	# Satellites orbiting
	var num_sats = 3 if _colony_tier == "growth" else 6
	for i in range(num_sats):
		var orbit_t = fmod(_time * 0.2 + i * (1.0 / num_sats), 1.0)
		var orbit_r = 80 + i * 15
		var sat_x = sky_center.x + cos(orbit_t * TAU) * orbit_r
		var sat_y = sky_center.y + sin(orbit_t * TAU) * orbit_r * 0.3  # Flattened orbit
		# Solar panel glint
		var glint = max(0, sin(orbit_t * TAU * 4 + i))
		draw_circle(Vector2(sat_x, sat_y), 2, Color(0.8, 0.85, 0.9, 0.5 + glint * 0.5))

	# Space station (independence tier)
	if _colony_tier in ["independence", "transcendence"]:
		var station_t = fmod(_time * 0.08, 1.0)
		var station_x = sky_center.x + cos(station_t * TAU) * 120
		var station_y = sky_center.y + sin(station_t * TAU) * 40
		# Station body
		draw_rect(Rect2(station_x - 8, station_y - 2, 16, 4), Color(0.7, 0.72, 0.75, 0.7))
		# Solar arrays
		draw_rect(Rect2(station_x - 20, station_y - 1, 10, 2), Color(0.3, 0.4, 0.6, 0.6))
		draw_rect(Rect2(station_x + 10, station_y - 1, 10, 2), Color(0.3, 0.4, 0.6, 0.6))

	# ORBITAL RING (transcendence only) - the ultimate flex
	if _colony_tier == "transcendence":
		var ring_center = Vector2(size.x * 0.5, size.y * 0.2)
		var ring_rx = 200
		var ring_ry = 30
		# Ring segments
		var segments = 32
		for i in range(segments):
			var a1 = i * TAU / segments
			var a2 = (i + 1) * TAU / segments
			var p1 = ring_center + Vector2(cos(a1) * ring_rx, sin(a1) * ring_ry)
			var p2 = ring_center + Vector2(cos(a2) * ring_rx, sin(a2) * ring_ry)
			# Shimmer effect
			var shimmer = 0.4 + sin(_time * 2.0 + a1 * 3) * 0.2
			draw_line(p1, p2, Color(0.6, 0.8, 1.0, shimmer), 3)
		# Energy nodes on ring
		for i in range(8):
			var node_a = i * TAU / 8 + _time * 0.1
			var node_pos = ring_center + Vector2(cos(node_a) * ring_rx, sin(node_a) * ring_ry)
			draw_circle(node_pos, 4, Color(0.5, 0.9, 1.0, 0.8))

func _draw_energy_network():
	"""Draw energy beams connecting power sources to major buildings"""
	# Only in later tiers
	if _colony_tier == "survival" or _building_layout.size() < 5:
		return

	var center = _iso_transform(WORLD_CENTER_X, WORLD_CENTER_Y, 20)

	# Find power buildings and major structures
	var power_buildings = []
	var consumers = []

	for bid in _building_layout:
		var layout = _building_layout[bid]
		# Find matching building data
		for b in _buildings:
			if b.get("id", "") == bid:
				var btype = b.get("type", 0)
				var is_operational = b.get("is_operational", false)
				if not is_operational:
					continue
				# Categorize
				if btype in [_MCSTypes.BuildingType.SOLAR_ARRAY, _MCSTypes.BuildingType.FISSION_REACTOR, _MCSTypes.BuildingType.RTG]:
					power_buildings.append({"pos": _iso_transform(layout.world_x, layout.world_y, layout.height * 0.5), "type": btype})
				elif btype in [_MCSTypes.BuildingType.FACTORY, _MCSTypes.BuildingType.RESEARCH_CENTER]:
					consumers.append(_iso_transform(layout.world_x, layout.world_y, layout.height * 0.5))
				break

	# Draw energy beams from power to center hub
	for power in power_buildings:
		var beam_color = Color(0.3, 0.7, 1.0, 0.3)
		if power.type == _MCSTypes.BuildingType.FISSION_REACTOR:
			beam_color = Color(0.3, 1.0, 0.5, 0.3)  # Green for nuclear

		# Pulsing beam
		var pulse = fmod(_time * 2.0, 1.0)
		var mid_point = power.pos.lerp(center, pulse)

		draw_line(power.pos, center, beam_color, 2.0)
		draw_circle(mid_point, 4, Color(beam_color.r, beam_color.g, beam_color.b, 0.8))

func _draw_atmosphere_effects():
	"""Draw aurora, meteor showers, and other atmospheric phenomena"""
	# Aurora (rare, beautiful)
	if sin(_time * 0.05) > 0.9:
		_draw_aurora()

	# Occasional meteor
	if fmod(_time, 15.0) < 0.5:
		_draw_meteor()

func _draw_aurora():
	"""Draw northern lights effect"""
	var aurora_colors = [
		Color(0.2, 0.8, 0.4, 0.15),
		Color(0.3, 0.6, 0.9, 0.12),
		Color(0.5, 0.3, 0.8, 0.1)
	]

	for band in range(3):
		var base_y = size.y * (0.05 + band * 0.08)
		var points = PackedVector2Array()
		for i in range(20):
			var x = size.x * i / 19.0
			var wave = sin(_time * 0.5 + i * 0.3 + band) * 15
			points.append(Vector2(x, base_y + wave))

		for i in range(19):
			var p1 = points[i]
			var p2 = points[i + 1]
			var p3 = Vector2(p2.x, p2.y + 30)
			var p4 = Vector2(p1.x, p1.y + 30)
			draw_polygon(PackedVector2Array([p1, p2, p3, p4]), [aurora_colors[band]])

func _draw_meteor():
	"""Draw a shooting star/meteor"""
	var meteor_t = fmod(_time, 15.0) / 0.5
	var start = Vector2(size.x * 0.8, size.y * 0.05)
	var end_pos = Vector2(size.x * 0.3, size.y * 0.25)
	var pos = start.lerp(end_pos, meteor_t)

	# Trail
	for i in range(5):
		var trail_pos = start.lerp(end_pos, max(0, meteor_t - i * 0.05))
		var trail_alpha = (1.0 - i * 0.2) * (1.0 - meteor_t)
		draw_circle(trail_pos, 3 - i * 0.5, Color(1.0, 0.9, 0.7, trail_alpha))

	# Head
	draw_circle(pos, 3, Color(1.0, 0.95, 0.8, 1.0 - meteor_t))

# =============================================================================
# GROUND PLANE (Isometric Diamond)
# =============================================================================

func _draw_ground():
	# The ground is a square in world space, which becomes a diamond in isometric
	# Four corners of the world
	var nw = _iso_transform(0, 0, 0)              # Top (north-west corner)
	var ne = _iso_transform(WORLD_SIZE, 0, 0)     # Right (north-east corner)
	var se = _iso_transform(WORLD_SIZE, WORLD_SIZE, 0)  # Bottom (south-east corner)
	var sw = _iso_transform(0, WORLD_SIZE, 0)     # Left (south-west corner)

	# Main ground fill
	var ground_poly = PackedVector2Array([nw, ne, se, sw])
	draw_polygon(ground_poly, [COLOR_GROUND_LIGHT])

	# Subtle grid for depth perception
	var grid_step = 50.0
	var grid_color = COLOR_GROUND_DARK
	grid_color.a = 0.25

	for i in range(int(WORLD_SIZE / grid_step) + 1):
		var t = i * grid_step
		# Lines parallel to Y axis (going NE-SW on screen)
		var line_start = _iso_transform(t, 0, 0)
		var line_end = _iso_transform(t, WORLD_SIZE, 0)
		draw_line(line_start, line_end, grid_color, 1.0)

		# Lines parallel to X axis (going NW-SE on screen)
		line_start = _iso_transform(0, t, 0)
		line_end = _iso_transform(WORLD_SIZE, t, 0)
		draw_line(line_start, line_end, grid_color, 1.0)

	# Edge highlight
	draw_line(nw, ne, COLOR_GROUND_EDGE, 2.0)
	draw_line(nw, sw, COLOR_GROUND_EDGE, 2.0)

# =============================================================================
# OBJECT COLLECTION
# =============================================================================

func _collect_all_objects() -> Array:
	var objects = []
	var tier_mult = TIER_MULTIPLIERS.get(_colony_tier, 1.0)

	# Lifepod at center
	var lp_height = 15.0 * tier_mult
	objects.append({
		"type": "lifepod",
		"x": WORLD_CENTER_X,
		"y": WORLD_CENTER_Y,
		"height": lp_height,
		"depth": _get_depth(WORLD_CENTER_X, WORLD_CENTER_Y, lp_height)
	})

	# Buildings
	for building in _buildings:
		var bid = building.get("id", "")
		if not _building_layout.has(bid):
			continue

		var layout = _building_layout[bid]
		var bx = layout.world_x
		var by = layout.world_y
		var bh = layout.height

		# Tunnel (underground, drawn first)
		objects.append({
			"type": "tunnel",
			"from_x": WORLD_CENTER_X,
			"from_y": WORLD_CENTER_Y,
			"to_x": bx,
			"to_y": by,
			"is_operational": building.get("is_operational", false),
			"depth": _get_depth(bx, by, -5)  # Underground = very far back
		})

		# Shadow (on ground)
		objects.append({
			"type": "shadow",
			"x": bx,
			"y": by,
			"height": bh,
			"depth": _get_depth(bx, by, 0) + 0.001
		})

		# Building
		objects.append({
			"type": "building",
			"x": bx,
			"y": by,
			"height": bh,
			"building": building,
			"category": layout.category,
			"depth": _get_depth(bx, by, bh)
		})

	# Colonists
	for colonist in _colonists:
		if not colonist.get("is_alive", true):
			continue
		var cpos = _get_colonist_world_pos(colonist)
		objects.append({
			"type": "colonist",
			"x": cpos.x,
			"y": cpos.y,
			"depth": _get_depth(cpos.x, cpos.y, 2)
		})

	return objects

# =============================================================================
# DRAWING FUNCTIONS
# =============================================================================

func _draw_tunnel_obj(obj: Dictionary):
	var from_screen = _iso_transform(obj.from_x, obj.from_y, -3)
	var to_screen = _iso_transform(obj.to_x, obj.to_y, -3)

	# Dark tunnel line
	draw_line(from_screen, to_screen, COLOR_TUNNEL, 5.0 * _camera_zoom)

	# Glow if operational
	if obj.is_operational:
		draw_line(from_screen, to_screen, COLOR_TUNNEL_GLOW, 2.0 * _camera_zoom)

func _draw_shadow_obj(obj: Dictionary):
	# Shadow is an ellipse on the ground, offset by height
	var shadow_offset_x = obj.height * 0.2
	var shadow_offset_y = obj.height * 0.1
	var shadow_center = _iso_transform(obj.x + shadow_offset_x, obj.y + shadow_offset_y, 0)

	var shadow_rx = (BUILDING_RADIUS + obj.height * 0.15) * _camera_zoom
	var shadow_ry = shadow_rx * 0.5  # Isometric compression

	_draw_ellipse(shadow_center, shadow_rx, shadow_ry, COLOR_SHADOW)

func _draw_building_obj(obj: Dictionary):
	var bx = obj.x
	var by = obj.y
	var height = obj.height
	var building = obj.building
	var category = obj.category
	var building_type = building.get("type", 0)

	var colors = BUILDING_COLORS.get(category, BUILDING_COLORS["housing"])
	var is_operational = building.get("is_operational", false)
	var progress = building.get("construction_progress", 1.0)

	# Adjust for construction/broken state
	var draw_height = height * progress if progress < 1.0 else height
	var alpha = 0.6 if progress < 1.0 else 1.0

	var top_color = colors.top
	var left_color = colors.left
	var right_color = colors.right

	if not is_operational and progress >= 1.0:
		# Broken - red tint
		top_color = top_color.lerp(Color.RED, 0.4)
		left_color = left_color.lerp(Color.RED, 0.4)
		right_color = right_color.lerp(Color.RED, 0.4)

	if alpha < 1.0:
		top_color.a = alpha
		left_color.a = alpha
		right_color.a = alpha

	# Draw based on building shape type
	var shape = _get_building_shape(building_type)
	match shape:
		BuildingShape.TOWER:
			_draw_tower(bx, by, BUILDING_RADIUS * 1.8, draw_height, top_color)
		BuildingShape.DOME:
			_draw_dome(bx, by, BUILDING_RADIUS, draw_height * 0.7, top_color)
		BuildingShape.ARCOLOGY:
			_draw_arcology(bx, by, BUILDING_RADIUS * 2.5, draw_height * 0.8)
		BuildingShape.GREENHOUSE:
			_draw_greenhouse(bx, by, BUILDING_RADIUS * 1.2, draw_height * 0.8)
		BuildingShape.SOLAR_ARRAY:
			_draw_solar_array(bx, by, BUILDING_RADIUS * 2.0)
		BuildingShape.REACTOR:
			_draw_reactor(bx, by, draw_height)
		BuildingShape.TERRAFORMING_TOWER:
			_draw_terraforming_tower(bx, by, draw_height * 1.2)
		BuildingShape.LANDING_PAD:
			_draw_landing_pad(bx, by, BUILDING_RADIUS * 2.0)
		BuildingShape.COMMS_TOWER:
			_draw_comms_tower(bx, by, draw_height * 1.5)
		BuildingShape.SPACE_ELEVATOR:
			_draw_space_elevator(bx, by, draw_height * 3.0)
		_:  # HEX_PRISM (default)
			_draw_hex_prism(bx, by, BUILDING_RADIUS, draw_height, top_color, left_color, right_color)

	# Status light on top (skip for solar arrays - they're flat)
	if progress >= 1.0 and shape != BuildingShape.SOLAR_ARRAY:
		var light_z = draw_height + 3
		if shape == BuildingShape.DOME:
			light_z = 4.0 + draw_height * 0.7 + 3  # Dome has base + dome height
		elif shape == BuildingShape.TOWER:
			light_z = draw_height + 12  # Tower has antenna
		var light_pos = _iso_transform(bx, by, light_z)
		var light_color = Color.GREEN if is_operational else Color.RED
		if not is_operational and fmod(_time, 0.8) < 0.4:
			light_color.a = 0.2
		draw_circle(light_pos, 3.0 * _camera_zoom, light_color)

	# Label
	var label = _get_building_label(building_type)
	var label_z = draw_height + 1
	if shape == BuildingShape.DOME:
		label_z = 4.0 + draw_height * 0.7 + 1
	var label_pos = _iso_transform(bx, by, label_z)
	draw_string(ThemeDB.fallback_font, label_pos - Vector2(4, -2) * _camera_zoom, label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 * _camera_zoom), Color.WHITE)

func _draw_lifepod_obj(obj: Dictionary):
	var lx = obj.x
	var ly = obj.y
	var lh = obj.height

	# Glow on ground
	var glow_center = _iso_transform(lx, ly, 0)
	var glow_pulse = 0.6 + sin(_time * 2.0) * 0.2
	var glow_color = Color(0.4, 0.7, 1.0, glow_pulse * 0.3)
	var glow_r = LIFEPOD_RADIUS * 1.5 * _camera_zoom
	_draw_ellipse(glow_center, glow_r, glow_r * 0.5, glow_color)

	# Hex prism
	_draw_hex_prism(lx, ly, LIFEPOD_RADIUS, lh, COLOR_LIFEPOD_TOP, COLOR_LIFEPOD_LEFT, COLOR_LIFEPOD_RIGHT)

	# Label
	var label_pos = _iso_transform(lx, ly, lh + 2)
	draw_string(ThemeDB.fallback_font, label_pos - Vector2(7, -2) * _camera_zoom, "LP",
		HORIZONTAL_ALIGNMENT_LEFT, -1, int(11 * _camera_zoom), Color.WHITE)

	# Beacon
	var beacon_pos = _iso_transform(lx, ly, lh + 6)
	var beacon_alpha = 0.4 + sin(_time * 3.0) * 0.3
	draw_circle(beacon_pos, 4.0 * _camera_zoom, Color(0.5, 0.8, 1.0, beacon_alpha))

func _draw_colonist_obj(obj: Dictionary):
	var screen_pos = _iso_transform(obj.x, obj.y, 1)
	draw_circle(screen_pos, COLONIST_SIZE * _camera_zoom, Color.WHITE)
	# Tiny shadow
	var shadow_pos = _iso_transform(obj.x + 1, obj.y + 0.5, 0)
	draw_circle(shadow_pos, COLONIST_SIZE * 0.7 * _camera_zoom, Color(0, 0, 0, 0.2))

# =============================================================================
# HEX PRISM DRAWING
# =============================================================================

func _draw_hex_prism(cx: float, cy: float, radius: float, height: float,
		top_color: Color, left_color: Color, right_color: Color):
	"""Draw a hexagonal prism at world position (cx, cy) with given height"""

	# Generate hex vertices in world space, then transform
	var base_verts: Array[Vector2] = []
	var top_verts: Array[Vector2] = []

	for i in range(6):
		var angle = PI / 6.0 + i * PI / 3.0  # Flat-top hex
		var wx = cx + cos(angle) * radius
		var wy = cy + sin(angle) * radius
		base_verts.append(_iso_transform(wx, wy, 0))
		top_verts.append(_iso_transform(wx, wy, height))

	# Draw sides - we draw all 6 but the back ones get occluded naturally
	# Draw in order: back sides first (indices 2,3,4), then front (5,0,1)
	var side_order = [2, 3, 4, 5, 0, 1]

	for i in side_order:
		var next_i = (i + 1) % 6

		var side_poly = PackedVector2Array([
			base_verts[i], base_verts[next_i],
			top_verts[next_i], top_verts[i]
		])

		# Left-facing sides (indices 2,3,4) get left_color, right-facing get right_color
		var side_color = left_color if i in [2, 3, 4] else right_color
		draw_polygon(side_poly, [side_color])

		# Vertical edge
		draw_line(base_verts[i], top_verts[i], side_color.darkened(0.2), 1.0)

	# Top face
	var top_poly = PackedVector2Array(top_verts)
	draw_polygon(top_poly, [top_color])

	# Top edge highlight
	for i in range(6):
		draw_line(top_verts[i], top_verts[(i + 1) % 6], top_color.lightened(0.25), 1.5)

func _draw_ellipse(center: Vector2, rx: float, ry: float, color: Color):
	var points = PackedVector2Array()
	for i in range(20):
		var angle = i * TAU / 20.0
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * ry))
	draw_polygon(points, [color])

# =============================================================================
# BUILDING SHAPE VARIANTS
# =============================================================================

func _draw_tower(cx: float, cy: float, width: float, height: float,
		base_color: Color, window_color: Color = Color(0.9, 0.95, 1.0, 0.8)):
	"""Draw a rectangular tower with windows - for apartments, factories"""
	var hw = width * 0.5

	# 4 corners at base and top
	var bl = _iso_transform(cx - hw, cy - hw, 0)
	var br = _iso_transform(cx + hw, cy - hw, 0)
	var fl = _iso_transform(cx - hw, cy + hw, 0)
	var fr = _iso_transform(cx + hw, cy + hw, 0)

	var tbl = _iso_transform(cx - hw, cy - hw, height)
	var tbr = _iso_transform(cx + hw, cy - hw, height)
	var tfl = _iso_transform(cx - hw, cy + hw, height)
	var tfr = _iso_transform(cx + hw, cy + hw, height)

	var left_color = base_color.darkened(0.25)
	var right_color = base_color.darkened(0.1)
	var top_color = base_color.lightened(0.1)

	# Left face (back-left to front-left)
	draw_polygon(PackedVector2Array([bl, tbl, tfl, fl]), [left_color])
	# Right face (front-left to front-right)
	draw_polygon(PackedVector2Array([fl, tfl, tfr, fr]), [right_color])
	# Top face
	draw_polygon(PackedVector2Array([tbl, tbr, tfr, tfl]), [top_color])

	# Windows on right face
	var window_rows = int(height / 8.0)
	var window_cols = 2
	for row in range(window_rows):
		for col in range(window_cols):
			var wz = 4 + row * 8.0
			var wy = cy + hw * 0.3 - col * hw * 0.5
			var wx = cx + hw * 0.9
			var win_pos = _iso_transform(wx, wy, wz)
			var win_lit = (hash(row * 10 + col + int(cx)) % 3) != 0  # 66% lit
			var wc = window_color if win_lit else window_color.darkened(0.6)
			draw_rect(Rect2(win_pos - Vector2(2, 3) * _camera_zoom, Vector2(4, 6) * _camera_zoom), wc)

	# Windows on left face
	for row in range(window_rows):
		for col in range(window_cols):
			var wz = 4 + row * 8.0
			var wy = cy - hw * 0.9
			var wx = cx - hw * 0.3 + col * hw * 0.5
			var win_pos = _iso_transform(wx, wy, wz)
			var win_lit = (hash(row * 10 + col + 100 + int(cy)) % 3) != 0
			var wc = window_color if win_lit else window_color.darkened(0.6)
			draw_rect(Rect2(win_pos - Vector2(2, 3) * _camera_zoom, Vector2(4, 6) * _camera_zoom), wc)

	# Roof antenna/spire
	var spire_base = _iso_transform(cx, cy, height)
	var spire_top = _iso_transform(cx, cy, height + 8)
	draw_line(spire_base, spire_top, Color.GRAY, 2.0 * _camera_zoom)
	# Blinking light
	var blink = fmod(_time, 1.0) < 0.5
	if blink:
		draw_circle(spire_top, 3 * _camera_zoom, Color.RED)

func _draw_dome(cx: float, cy: float, radius: float, height: float, base_color: Color):
	"""Draw a hemispherical dome - for arcologies, research centers"""
	var dome_color = Color(0.4, 0.7, 0.9, 0.6)  # Translucent cyan
	var frame_color = base_color.lightened(0.2)

	# Draw base hex
	_draw_hex_prism(cx, cy, radius, 4.0, base_color, base_color.darkened(0.2), base_color.darkened(0.1))

	# Draw dome as series of rings
	var rings = 6
	for ring in range(rings):
		var t = float(ring) / rings
		var ring_z = 4.0 + sin(t * PI * 0.5) * height
		var ring_r = radius * cos(t * PI * 0.5)

		var points = PackedVector2Array()
		for i in range(16):
			var angle = i * TAU / 16.0
			var wx = cx + cos(angle) * ring_r
			var wy = cy + sin(angle) * ring_r
			points.append(_iso_transform(wx, wy, ring_z))

		# Draw ring outline
		for i in range(16):
			draw_line(points[i], points[(i + 1) % 16], frame_color, 1.5 * _camera_zoom)

	# Dome fill (top portion)
	var apex = _iso_transform(cx, cy, 4.0 + height)
	draw_circle(apex, radius * 0.3 * _camera_zoom, dome_color)

	# Apex light
	var glow_alpha = 0.5 + sin(_time * 2.0) * 0.3
	draw_circle(apex, 5 * _camera_zoom, Color(0.5, 0.9, 1.0, glow_alpha))

func _draw_space_elevator(cx: float, cy: float, height: float):
	"""Draw space elevator - THE CENTERPIECE megastructure"""
	var base_color = Color(0.3, 0.4, 0.5)

	# Hexagonal base platform
	_draw_hex_prism(cx, cy, 25.0, 8.0, base_color.lightened(0.1), base_color.darkened(0.2), base_color)

	# Three cables going up
	var cable_offsets = [Vector2(-8, 0), Vector2(4, -7), Vector2(4, 7)]
	var cable_colors = [Color(0.6, 0.8, 1.0), Color(0.5, 0.7, 0.9), Color(0.7, 0.85, 1.0)]

	for i in range(3):
		var offset = cable_offsets[i]
		var color = cable_colors[i]

		# Cable with wave motion
		var prev_pos = _iso_transform(cx + offset.x, cy + offset.y, 8.0)
		var segments = 20
		for seg in range(1, segments + 1):
			var t = float(seg) / segments
			var z = 8.0 + t * height
			var wave = sin(_time * 3.0 + t * 8.0 + i * 2.0) * 2.0
			var wx = cx + offset.x + wave * (1.0 - t)  # Wave diminishes with height
			var wy = cy + offset.y
			var pos = _iso_transform(wx, wy, z)
			draw_line(prev_pos, pos, color, (3.0 - t * 2.0) * _camera_zoom)
			prev_pos = pos

		# Energy pulses traveling up
		var pulse_t = fmod(_time * 0.5 + i * 0.33, 1.0)
		var pulse_z = 8.0 + pulse_t * height
		var pulse_pos = _iso_transform(cx + offset.x, cy + offset.y, pulse_z)
		draw_circle(pulse_pos, (6 - pulse_t * 4) * _camera_zoom, Color(0.5, 0.9, 1.0, 1.0 - pulse_t))

	# Counterweight at top
	var top_pos = _iso_transform(cx, cy, 8.0 + height)
	draw_circle(top_pos, 12 * _camera_zoom, Color(0.4, 0.5, 0.6))
	draw_circle(top_pos, 8 * _camera_zoom, Color(0.5, 0.6, 0.7))

	# Glow ring at base
	var base_center = _iso_transform(cx, cy, 8.0)
	var glow_alpha = 0.3 + sin(_time * 4.0) * 0.2
	_draw_ellipse(base_center, 30 * _camera_zoom, 15 * _camera_zoom, Color(0.3, 0.6, 1.0, glow_alpha))

func _draw_solar_array(cx: float, cy: float, width: float):
	"""Draw flat solar panel array"""
	var panel_color = Color(0.15, 0.2, 0.35)
	var frame_color = Color(0.4, 0.45, 0.5)
	var highlight = Color(0.3, 0.5, 0.8, 0.3)

	# Low base
	_draw_hex_prism(cx, cy, width * 0.3, 2.0, frame_color, frame_color.darkened(0.2), frame_color)

	# Angled panels (2x2 grid)
	var panel_w = width * 0.8
	var panel_h = 3.0  # Slight tilt

	for px in [-0.5, 0.5]:
		for py in [-0.5, 0.5]:
			var pcx = cx + px * panel_w * 0.6
			var pcy = cy + py * panel_w * 0.6

			var p1 = _iso_transform(pcx - panel_w * 0.25, pcy - panel_w * 0.25, 2.0)
			var p2 = _iso_transform(pcx + panel_w * 0.25, pcy - panel_w * 0.25, 2.0 + panel_h)
			var p3 = _iso_transform(pcx + panel_w * 0.25, pcy + panel_w * 0.25, 2.0 + panel_h)
			var p4 = _iso_transform(pcx - panel_w * 0.25, pcy + panel_w * 0.25, 2.0)

			draw_polygon(PackedVector2Array([p1, p2, p3, p4]), [panel_color])
			# Grid lines
			draw_line(p1, p3, frame_color, 1.0)
			draw_line(p2, p4, frame_color, 1.0)
			# Sun reflection
			var reflect_pos = (p1 + p3) * 0.5
			draw_circle(reflect_pos, 4 * _camera_zoom, highlight)

func _draw_terraforming_tower(cx: float, cy: float, height: float):
	"""Draw atmospheric processor with vapor plume"""
	var tower_color = Color(0.5, 0.55, 0.6)

	# Tapered tower body
	var base_r = 15.0
	var top_r = 8.0
	var segments = 8

	for seg in range(segments):
		var t1 = float(seg) / segments
		var t2 = float(seg + 1) / segments
		var r1 = lerp(base_r, top_r, t1)
		var r2 = lerp(base_r, top_r, t2)
		var z1 = t1 * height
		var z2 = t2 * height

		# Draw ring segment
		for i in range(6):
			var angle1 = i * TAU / 6.0
			var angle2 = (i + 1) * TAU / 6.0

			var b1 = _iso_transform(cx + cos(angle1) * r1, cy + sin(angle1) * r1, z1)
			var b2 = _iso_transform(cx + cos(angle2) * r1, cy + sin(angle2) * r1, z1)
			var t1p = _iso_transform(cx + cos(angle1) * r2, cy + sin(angle1) * r2, z2)
			var t2p = _iso_transform(cx + cos(angle2) * r2, cy + sin(angle2) * r2, z2)

			var shade = 0.8 + 0.2 * cos(angle1)  # Simple shading
			draw_polygon(PackedVector2Array([b1, b2, t2p, t1p]), [tower_color * shade])

	# Processing rings
	for ring_z in [height * 0.3, height * 0.6, height * 0.9]:
		var ring_r = lerp(base_r, top_r, ring_z / height) + 3.0
		var ring_center = _iso_transform(cx, cy, ring_z)
		_draw_ellipse(ring_center, ring_r * _camera_zoom, ring_r * 0.5 * _camera_zoom, Color(0.6, 0.65, 0.7))

	# Vapor plume
	var plume_particles = 8
	for i in range(plume_particles):
		var pt = fmod(_time * 0.3 + i * 0.125, 1.0)
		var pz = height + pt * 40.0
		var spread = pt * 15.0
		var px = cx + sin(_time + i * 2.0) * spread
		var py = cy + cos(_time * 0.7 + i * 1.5) * spread
		var ppos = _iso_transform(px, py, pz)
		var palpha = (1.0 - pt) * 0.4
		draw_circle(ppos, (8 + pt * 12) * _camera_zoom, Color(0.8, 0.85, 0.9, palpha))

func _draw_arcology(cx: float, cy: float, radius: float, height: float):
	"""Draw MASSIVE arcology - a city under a giant dome"""
	# Multi-level base structure
	var levels = 4
	for level in range(levels):
		var level_r = radius * (1.0 - level * 0.15)
		var level_z = level * 12.0
		var level_h = 10.0
		var shade = 0.6 + level * 0.1
		var level_color = Color(0.5 * shade, 0.55 * shade, 0.65 * shade)
		_draw_hex_prism(cx, cy, level_r, level_h, level_color.lightened(0.1), level_color.darkened(0.1), level_color)
		# Windows on each level
		for i in range(12):
			var angle = i * TAU / 12.0
			var wx = cx + cos(angle) * level_r * 0.85
			var wy = cy + sin(angle) * level_r * 0.85
			var wpos = _iso_transform(wx, wy, level_z + 5)
			var lit = (hash(level * 20 + i) % 3) != 0
			var wcolor = Color(1.0, 0.95, 0.7, 0.9) if lit else Color(0.2, 0.25, 0.3, 0.6)
			draw_circle(wpos, 3 * _camera_zoom, wcolor)

	# Giant transparent dome over everything
	var dome_base_z = levels * 12.0
	var dome_color = Color(0.4, 0.7, 0.9, 0.25)
	var frame_color = Color(0.6, 0.8, 1.0, 0.6)

	# Dome rings
	var dome_rings = 8
	for ring in range(dome_rings):
		var t = float(ring) / dome_rings
		var ring_z = dome_base_z + sin(t * PI * 0.5) * height
		var ring_r = radius * cos(t * PI * 0.5)

		var points = PackedVector2Array()
		for i in range(24):
			var angle = i * TAU / 24.0
			points.append(_iso_transform(cx + cos(angle) * ring_r, cy + sin(angle) * ring_r, ring_z))

		for i in range(24):
			draw_line(points[i], points[(i + 1) % 24], frame_color, 1.5 * _camera_zoom)

	# Vertical dome struts
	for i in range(8):
		var angle = i * TAU / 8.0
		var prev_pos = _iso_transform(cx + cos(angle) * radius, cy + sin(angle) * radius, dome_base_z)
		for seg in range(1, dome_rings + 1):
			var t = float(seg) / dome_rings
			var seg_z = dome_base_z + sin(t * PI * 0.5) * height
			var seg_r = radius * cos(t * PI * 0.5)
			var pos = _iso_transform(cx + cos(angle) * seg_r, cy + sin(angle) * seg_r, seg_z)
			draw_line(prev_pos, pos, frame_color, 2.0 * _camera_zoom)
			prev_pos = pos

	# Glowing apex
	var apex = _iso_transform(cx, cy, dome_base_z + height)
	var glow_pulse = 0.5 + sin(_time * 2.0) * 0.3
	draw_circle(apex, 12 * _camera_zoom, Color(0.5, 0.8, 1.0, glow_pulse * 0.5))
	draw_circle(apex, 6 * _camera_zoom, Color(0.7, 0.9, 1.0, glow_pulse))

func _draw_greenhouse(cx: float, cy: float, radius: float, height: float):
	"""Draw glass greenhouse dome with visible plants"""
	var glass_color = Color(0.5, 0.8, 0.5, 0.35)
	var frame_color = Color(0.4, 0.5, 0.4)
	var plant_green = Color(0.2, 0.7, 0.3)

	# Low base
	_draw_hex_prism(cx, cy, radius, 3.0, frame_color, frame_color.darkened(0.2), frame_color)

	# Glass dome panels
	var panels = 6
	for i in range(panels):
		var angle1 = i * TAU / panels
		var angle2 = (i + 1) * TAU / panels
		var mid_angle = (angle1 + angle2) * 0.5

		# Panel corners
		var b1 = _iso_transform(cx + cos(angle1) * radius, cy + sin(angle1) * radius, 3.0)
		var b2 = _iso_transform(cx + cos(angle2) * radius, cy + sin(angle2) * radius, 3.0)
		var apex = _iso_transform(cx, cy, 3.0 + height)

		# Draw triangular glass panel
		draw_polygon(PackedVector2Array([b1, b2, apex]), [glass_color])
		draw_line(b1, apex, frame_color, 2.0 * _camera_zoom)
		draw_line(b2, apex, frame_color, 2.0 * _camera_zoom)

	# Plants inside (visible through glass)
	for i in range(8):
		var px = cx + randf_range(-radius * 0.6, radius * 0.6)
		var py = cy + randf_range(-radius * 0.6, radius * 0.6)
		# Use deterministic "random" based on position
		var plant_h = 4.0 + sin(px * 0.5 + py * 0.3) * 3.0
		var plant_pos = _iso_transform(px, py, 3.0 + plant_h)
		var plant_color = plant_green.lerp(Color(0.3, 0.8, 0.2), sin(px + py) * 0.5 + 0.5)
		draw_circle(plant_pos, (3 + sin(px) * 1.5) * _camera_zoom, plant_color)

	# Sunlight reflection on glass
	var sun_pos = _iso_transform(cx - radius * 0.3, cy - radius * 0.3, 3.0 + height * 0.6)
	draw_circle(sun_pos, 8 * _camera_zoom, Color(1.0, 1.0, 0.9, 0.4))

func _draw_reactor(cx: float, cy: float, height: float):
	"""Draw fission/fusion reactor with glowing core"""
	var shell_color = Color(0.4, 0.45, 0.5)
	var core_color = Color(0.3, 0.8, 1.0)
	var warning_color = Color(1.0, 0.8, 0.0)

	# Containment building (cylindrical)
	var base_r = 18.0
	_draw_hex_prism(cx, cy, base_r, height * 0.7, shell_color, shell_color.darkened(0.2), shell_color.darkened(0.1))

	# Cooling towers (two smaller cylinders)
	for offset in [Vector2(-15, -10), Vector2(15, 10)]:
		var tx = cx + offset.x
		var ty = cy + offset.y
		_draw_hex_prism(tx, ty, 8.0, height * 0.5, shell_color.darkened(0.1), shell_color.darkened(0.3), shell_color.darkened(0.2))
		# Steam from cooling towers
		for i in range(3):
			var st = fmod(_time * 0.4 + i * 0.33, 1.0)
			var steam_z = height * 0.5 + st * 20.0
			var steam_pos = _iso_transform(tx + sin(_time + i) * st * 5, ty, steam_z)
			draw_circle(steam_pos, (4 + st * 6) * _camera_zoom, Color(0.9, 0.92, 0.95, (1.0 - st) * 0.4))

	# Glowing core visible through top
	var core_z = height * 0.4
	var core_pos = _iso_transform(cx, cy, core_z)
	var pulse = 0.6 + sin(_time * 4.0) * 0.4
	draw_circle(core_pos, 14 * _camera_zoom, Color(core_color.r, core_color.g, core_color.b, pulse * 0.3))
	draw_circle(core_pos, 8 * _camera_zoom, Color(core_color.r, core_color.g, core_color.b, pulse * 0.6))
	draw_circle(core_pos, 4 * _camera_zoom, Color(1.0, 1.0, 1.0, pulse))

	# Energy arcs (occasional)
	if fmod(_time, 2.0) < 0.3:
		var arc_angle = _time * 5.0
		var arc_end = _iso_transform(cx + cos(arc_angle) * 12, cy + sin(arc_angle) * 12, core_z + 5)
		draw_line(core_pos, arc_end, core_color, 2.0 * _camera_zoom)

	# Warning stripes on base
	var stripe_pos = _iso_transform(cx, cy + base_r * 0.8, height * 0.35)
	draw_circle(stripe_pos, 5 * _camera_zoom, warning_color)

func _draw_landing_pad(cx: float, cy: float, width: float):
	"""Draw landing pad with rocket/ship"""
	var pad_color = Color(0.35, 0.38, 0.4)
	var marking_color = Color(0.9, 0.9, 0.2)
	var ship_color = Color(0.7, 0.72, 0.75)

	# Flat hexagonal pad
	_draw_hex_prism(cx, cy, width, 2.0, pad_color.lightened(0.1), pad_color.darkened(0.1), pad_color)

	# Landing circle markings
	var circle_center = _iso_transform(cx, cy, 2.1)
	_draw_ellipse(circle_center, width * 0.7 * _camera_zoom, width * 0.35 * _camera_zoom, Color(marking_color.r, marking_color.g, marking_color.b, 0.5))
	_draw_ellipse(circle_center, width * 0.5 * _camera_zoom, width * 0.25 * _camera_zoom, Color(marking_color.r, marking_color.g, marking_color.b, 0.3))

	# "H" marking
	var h_pos = _iso_transform(cx, cy, 2.2)
	draw_string(ThemeDB.fallback_font, h_pos - Vector2(6, 4) * _camera_zoom, "H", HORIZONTAL_ALIGNMENT_LEFT, -1, int(16 * _camera_zoom), marking_color)

	# Landed rocket/ship (sometimes)
	var has_ship = sin(_time * 0.1 + cx * 0.01) > -0.3  # Ship present most of time
	if has_ship:
		# Rocket body
		var rocket_h = 35.0
		var rocket_r = 6.0

		# Main body (tapered cylinder approximated with hex)
		for seg in range(4):
			var t1 = float(seg) / 4
			var t2 = float(seg + 1) / 4
			var r1 = rocket_r * (1.0 - t1 * 0.3)
			var r2 = rocket_r * (1.0 - t2 * 0.3)
			var z1 = 2.0 + t1 * rocket_h
			var z2 = 2.0 + t2 * rocket_h

			for i in range(6):
				var angle1 = i * TAU / 6.0
				var angle2 = (i + 1) * TAU / 6.0
				var b1 = _iso_transform(cx + cos(angle1) * r1, cy + sin(angle1) * r1, z1)
				var b2 = _iso_transform(cx + cos(angle2) * r1, cy + sin(angle2) * r1, z1)
				var t1p = _iso_transform(cx + cos(angle1) * r2, cy + sin(angle1) * r2, z2)
				var t2p = _iso_transform(cx + cos(angle2) * r2, cy + sin(angle2) * r2, z2)
				var shade = ship_color * (0.8 + 0.2 * cos(angle1))
				draw_polygon(PackedVector2Array([b1, b2, t2p, t1p]), [shade])

		# Nose cone
		var nose_base = _iso_transform(cx, cy, 2.0 + rocket_h)
		var nose_tip = _iso_transform(cx, cy, 2.0 + rocket_h + 10)
		for i in range(6):
			var angle = i * TAU / 6.0
			var base_pt = _iso_transform(cx + cos(angle) * rocket_r * 0.7, cy + sin(angle) * rocket_r * 0.7, 2.0 + rocket_h)
			draw_polygon(PackedVector2Array([base_pt, _iso_transform(cx + cos(angle + TAU/6) * rocket_r * 0.7, cy + sin(angle + TAU/6) * rocket_r * 0.7, 2.0 + rocket_h), nose_tip]), [Color(0.85, 0.2, 0.2)])

		# Engine glow (if recently landed - pulsing)
		var engine_glow = max(0, sin(_time * 0.5) * 0.5)
		if engine_glow > 0:
			var glow_pos = _iso_transform(cx, cy, 3.0)
			draw_circle(glow_pos, (8 + engine_glow * 4) * _camera_zoom, Color(1.0, 0.6, 0.2, engine_glow * 0.6))

func _draw_comms_tower(cx: float, cy: float, height: float):
	"""Draw communications tower with satellite dish"""
	var tower_color = Color(0.5, 0.52, 0.55)
	var dish_color = Color(0.7, 0.72, 0.75)
	var signal_color = Color(0.3, 0.8, 1.0)

	# Lattice tower (simplified as tapered hex)
	var base_r = 8.0
	var top_r = 4.0

	for seg in range(6):
		var t1 = float(seg) / 6
		var t2 = float(seg + 1) / 6
		var r1 = lerp(base_r, top_r, t1)
		var r2 = lerp(base_r, top_r, t2)
		var z1 = t1 * height
		var z2 = t2 * height

		# Just draw the edges for lattice effect
		for i in range(6):
			var angle = i * TAU / 6.0
			var b = _iso_transform(cx + cos(angle) * r1, cy + sin(angle) * r1, z1)
			var t = _iso_transform(cx + cos(angle) * r2, cy + sin(angle) * r2, z2)
			draw_line(b, t, tower_color, 2.0 * _camera_zoom)

		# Horizontal rings
		if seg % 2 == 0:
			for i in range(6):
				var angle1 = i * TAU / 6.0
				var angle2 = (i + 1) * TAU / 6.0
				var p1 = _iso_transform(cx + cos(angle1) * r1, cy + sin(angle1) * r1, z1)
				var p2 = _iso_transform(cx + cos(angle2) * r1, cy + sin(angle2) * r1, z1)
				draw_line(p1, p2, tower_color, 1.5 * _camera_zoom)

	# Satellite dish at top
	var dish_z = height * 0.85
	var dish_r = 12.0
	var dish_center = _iso_transform(cx + 8, cy, dish_z)

	# Dish (ellipse facing up-right)
	_draw_ellipse(dish_center, dish_r * _camera_zoom, dish_r * 0.6 * _camera_zoom, dish_color)
	# Dish rim
	var rim_points = PackedVector2Array()
	for i in range(16):
		var angle = i * TAU / 16.0
		rim_points.append(dish_center + Vector2(cos(angle) * dish_r, sin(angle) * dish_r * 0.6) * _camera_zoom)
	for i in range(16):
		draw_line(rim_points[i], rim_points[(i + 1) % 16], tower_color, 1.5 * _camera_zoom)

	# Feed horn
	var feed_pos = _iso_transform(cx + 8 + 6, cy, dish_z + 4)
	draw_line(dish_center, feed_pos, tower_color, 2.0 * _camera_zoom)
	draw_circle(feed_pos, 3 * _camera_zoom, tower_color)

	# Signal waves (animated)
	for wave in range(3):
		var wt = fmod(_time * 0.8 + wave * 0.33, 1.0)
		var wave_r = 5 + wt * 20
		var wave_pos = feed_pos + Vector2(wt * 15, -wt * 8) * _camera_zoom
		draw_arc(wave_pos, wave_r * _camera_zoom, -PI * 0.3, PI * 0.3, 8, Color(signal_color.r, signal_color.g, signal_color.b, (1.0 - wt) * 0.6), 2.0 * _camera_zoom)

	# Blinking light at very top
	var top_pos = _iso_transform(cx, cy, height)
	var blink = fmod(_time, 1.5) < 0.3
	if blink:
		draw_circle(top_pos, 4 * _camera_zoom, Color.RED)

func _draw_force_field():
	"""Draw colony-wide force field dome (called separately, not per-building)"""
	if not _force_field_active:
		return

	var field_color = Color(0.3, 0.6, 1.0, 0.15)
	var grid_color = Color(0.4, 0.7, 1.0, 0.3)
	var field_radius = 180.0  # Covers most of the colony
	var field_height = 120.0

	# Hexagonal grid on the dome surface
	var rings = 6
	for ring in range(rings):
		var t = float(ring) / rings
		var ring_z = sin(t * PI * 0.5) * field_height
		var ring_r = field_radius * cos(t * PI * 0.5)

		var points = PackedVector2Array()
		var segments = 24
		for i in range(segments):
			var angle = i * TAU / segments
			# Add shimmer
			var shimmer = sin(_time * 3.0 + angle * 4.0 + ring * 2.0) * 2.0
			var wx = WORLD_CENTER_X + cos(angle) * (ring_r + shimmer)
			var wy = WORLD_CENTER_Y + sin(angle) * (ring_r + shimmer)
			points.append(_iso_transform(wx, wy, ring_z))

		for i in range(segments):
			var alpha = 0.2 + sin(_time * 2.0 + i * 0.5) * 0.1
			draw_line(points[i], points[(i + 1) % segments], Color(grid_color.r, grid_color.g, grid_color.b, alpha), 1.5 * _camera_zoom)

	# Vertical energy lines
	for i in range(12):
		var angle = i * TAU / 12.0
		var prev_pos = _iso_transform(WORLD_CENTER_X + cos(angle) * field_radius, WORLD_CENTER_Y + sin(angle) * field_radius, 0)
		for seg in range(1, rings + 1):
			var t = float(seg) / rings
			var seg_z = sin(t * PI * 0.5) * field_height
			var seg_r = field_radius * cos(t * PI * 0.5)
			var pos = _iso_transform(WORLD_CENTER_X + cos(angle) * seg_r, WORLD_CENTER_Y + sin(angle) * seg_r, seg_z)
			var alpha = 0.15 + sin(_time * 2.5 + i + seg) * 0.1
			draw_line(prev_pos, pos, Color(grid_color.r, grid_color.g, grid_color.b, alpha), 1.0 * _camera_zoom)
			prev_pos = pos

	# Impact flickers (random)
	if fmod(_time, 3.0) < 0.15:
		var impact_angle = fmod(_time * 7.0, TAU)
		var impact_h = 0.3 + fmod(_time * 3.0, 0.4)
		var impact_z = sin(impact_h * PI * 0.5) * field_height
		var impact_r = field_radius * cos(impact_h * PI * 0.5)
		var impact_pos = _iso_transform(
			WORLD_CENTER_X + cos(impact_angle) * impact_r,
			WORLD_CENTER_Y + sin(impact_angle) * impact_r,
			impact_z
		)
		draw_circle(impact_pos, 15 * _camera_zoom, Color(0.5, 0.8, 1.0, 0.6))
		draw_circle(impact_pos, 8 * _camera_zoom, Color(0.7, 0.9, 1.0, 0.8))

# =============================================================================
# DUST / WEATHER
# =============================================================================

func _update_dust(delta: float):
	for p in _dust_particles:
		p.x += p.vx * delta
		p.y += p.vy * delta
		p.z += p.vz * delta

		# Wrap
		if p.x < 0: p.x = WORLD_SIZE
		if p.x > WORLD_SIZE: p.x = 0
		if p.y < 0: p.y = WORLD_SIZE
		if p.y > WORLD_SIZE: p.y = 0
		if p.z < 0: p.z = 15
		if p.z > 15: p.z = 0

		if _sandstorm_active:
			p.vx = lerp(p.vx, 40.0, delta * 0.5)

func _draw_dust():
	for p in _dust_particles:
		var screen = _iso_transform(p.x, p.y, p.z)
		var dust_color = COLOR_GROUND_LIGHT
		dust_color.a = p.alpha * (2.0 if _sandstorm_active else 1.0)
		draw_circle(screen, p.size * _camera_zoom, dust_color)

	if _sandstorm_active:
		var overlay = COLOR_GROUND_LIGHT
		overlay.a = _sandstorm_intensity * 0.2
		draw_rect(Rect2(Vector2.ZERO, size), overlay)

# =============================================================================
# HELPERS
# =============================================================================

func _get_colonist_world_pos(colonist: Dictionary) -> Vector2:
	var id_hash = hash(colonist.get("id", ""))
	var t = fmod(_time * 0.08 + float(id_hash) * 0.0001, 1.0)

	if _building_layout.size() > 0:
		var keys = _building_layout.keys()
		var idx = id_hash % keys.size()
		var layout = _building_layout[keys[idx]]
		var bpos = Vector2(layout.world_x, layout.world_y)
		var center = Vector2(WORLD_CENTER_X, WORLD_CENTER_Y)
		return center.lerp(bpos, sin(t * PI))

	return Vector2(WORLD_CENTER_X, WORLD_CENTER_Y)

func _get_building_category(building_type: int) -> String:
	match building_type:
		_MCSTypes.BuildingType.HAB_POD, _MCSTypes.BuildingType.APARTMENT_BLOCK:
			return "housing"
		_MCSTypes.BuildingType.GREENHOUSE, _MCSTypes.BuildingType.HYDROPONICS:
			return "food"
		_MCSTypes.BuildingType.SOLAR_ARRAY, _MCSTypes.BuildingType.FISSION_REACTOR:
			return "power"
		_MCSTypes.BuildingType.WATER_EXTRACTOR:
			return "water"
		_MCSTypes.BuildingType.WORKSHOP, _MCSTypes.BuildingType.FACTORY:
			return "industry"
		_MCSTypes.BuildingType.MEDICAL_BAY, _MCSTypes.BuildingType.HOSPITAL:
			return "medical"
		_MCSTypes.BuildingType.LAB, _MCSTypes.BuildingType.RESEARCH_CENTER:
			return "research"
		_:
			return "housing"

func _get_building_height_key(building_type: int) -> String:
	match building_type:
		_MCSTypes.BuildingType.HAB_POD: return "hab_pod"
		_MCSTypes.BuildingType.APARTMENT_BLOCK: return "apartment_block"
		_MCSTypes.BuildingType.GREENHOUSE: return "greenhouse"
		_MCSTypes.BuildingType.HYDROPONICS: return "hydroponics"
		_MCSTypes.BuildingType.SOLAR_ARRAY: return "solar_array"
		_MCSTypes.BuildingType.WATER_EXTRACTOR: return "water_extractor"
		_MCSTypes.BuildingType.OXYGENATOR: return "oxygenator"
		_MCSTypes.BuildingType.WORKSHOP: return "workshop"
		_MCSTypes.BuildingType.FACTORY: return "factory"
		_MCSTypes.BuildingType.MEDICAL_BAY: return "medical_bay"
		_MCSTypes.BuildingType.HOSPITAL: return "hospital"
		_MCSTypes.BuildingType.LAB: return "lab"
		_MCSTypes.BuildingType.RESEARCH_CENTER: return "research_center"
		_MCSTypes.BuildingType.FISSION_REACTOR: return "fission_reactor"
		_MCSTypes.BuildingType.STORAGE: return "storage"
		_: return "hab_pod"

func _get_building_label(building_type: int) -> String:
	match building_type:
		_MCSTypes.BuildingType.HAB_POD: return "H"
		_MCSTypes.BuildingType.APARTMENT_BLOCK: return "A"
		_MCSTypes.BuildingType.GREENHOUSE: return "G"
		_MCSTypes.BuildingType.HYDROPONICS: return "HY"
		_MCSTypes.BuildingType.SOLAR_ARRAY: return "S"
		_MCSTypes.BuildingType.WATER_EXTRACTOR: return "W"
		_MCSTypes.BuildingType.WORKSHOP: return "WS"
		_MCSTypes.BuildingType.FACTORY: return "F"
		_MCSTypes.BuildingType.MEDICAL_BAY: return "M"
		_MCSTypes.BuildingType.HOSPITAL: return "H+"
		_MCSTypes.BuildingType.LAB: return "L"
		_MCSTypes.BuildingType.RESEARCH_CENTER: return "R"
		_MCSTypes.BuildingType.FISSION_REACTOR: return "FR"
		_MCSTypes.BuildingType.OXYGENATOR: return "O2"
		_MCSTypes.BuildingType.STORAGE: return "ST"
		_: return "?"

enum BuildingShape {
	HEX_PRISM, TOWER, DOME, SOLAR_ARRAY, TERRAFORMING_TOWER,
	ARCOLOGY, GREENHOUSE, REACTOR, LANDING_PAD, COMMS_TOWER, SPACE_ELEVATOR
}

func _get_building_shape(building_type: int) -> BuildingShape:
	"""Determine which visual shape to use for a building type"""
	match building_type:
		# TOWER - rectangular buildings with windows
		_MCSTypes.BuildingType.APARTMENT_BLOCK, _MCSTypes.BuildingType.FACTORY, \
		_MCSTypes.BuildingType.WORKSHOP, _MCSTypes.BuildingType.HOSPITAL, \
		_MCSTypes.BuildingType.UNIVERSITY, _MCSTypes.BuildingType.BARRACKS, \
		_MCSTypes.BuildingType.STORAGE, _MCSTypes.BuildingType.GOVERNMENT_HALL, \
		_MCSTypes.BuildingType.PRISON:
			return BuildingShape.TOWER
		# DOME - hemispherical structures (small/medium)
		_MCSTypes.BuildingType.LAB, _MCSTypes.BuildingType.RECREATION_CENTER, \
		_MCSTypes.BuildingType.TEMPLE:
			return BuildingShape.DOME
		# ARCOLOGY - mega domes for research centers and luxury
		_MCSTypes.BuildingType.RESEARCH_CENTER, _MCSTypes.BuildingType.LUXURY_QUARTERS:
			return BuildingShape.ARCOLOGY
		# GREENHOUSE - glass domes with plants
		_MCSTypes.BuildingType.GREENHOUSE, _MCSTypes.BuildingType.HYDROPONICS, \
		_MCSTypes.BuildingType.PROTEIN_VATS:
			return BuildingShape.GREENHOUSE
		# SOLAR_ARRAY - flat panel arrays
		_MCSTypes.BuildingType.SOLAR_ARRAY, _MCSTypes.BuildingType.WIND_TURBINE:
			return BuildingShape.SOLAR_ARRAY
		# REACTOR - glowing core power plants
		_MCSTypes.BuildingType.FISSION_REACTOR, _MCSTypes.BuildingType.RTG:
			return BuildingShape.REACTOR
		# TERRAFORMING - tall processing towers
		_MCSTypes.BuildingType.CO2_SCRUBBER, _MCSTypes.BuildingType.OXYGENATOR, \
		_MCSTypes.BuildingType.WASTE_PROCESSOR:
			return BuildingShape.TERRAFORMING_TOWER
		# LANDING_PAD - flat pads with ships
		_MCSTypes.BuildingType.LANDING_PAD, _MCSTypes.BuildingType.AIRLOCK:
			return BuildingShape.LANDING_PAD
		# COMMS_TOWER - lattice towers with dishes
		_MCSTypes.BuildingType.COMMUNICATIONS:
			return BuildingShape.COMMS_TOWER
		# Default: hex prism for hab pods, medical, etc.
		_:
			return BuildingShape.HEX_PRISM

# =============================================================================
# PUBLIC API
# =============================================================================

func set_store(_store: Node):
	pass  # Not needed currently

func update_from_state(state: Dictionary):
	_buildings = state.get("buildings", [])
	_colonists = state.get("colonists", [])
	_year = state.get("year", 1)
	_stability = state.get("stability", 1.0)

	var phase = state.get("phase", 0)
	match phase:
		0: _colony_tier = "survival"
		1: _colony_tier = "growth"
		2: _colony_tier = "society"
		3: _colony_tier = "independence"
		_: _colony_tier = "survival"

	_layout_buildings()

func _layout_buildings():
	"""Arrange buildings in rings around the lifepod"""
	_building_layout.clear()

	if _buildings.size() == 0:
		return

	var tier_mult = TIER_MULTIPLIERS.get(_colony_tier, 1.0)
	var ring_radius = 55.0
	var ring_spacing = 45.0
	var per_ring = 6

	var idx = 0
	var ring = 0

	while idx < _buildings.size():
		var r = ring_radius + ring * ring_spacing
		var slots = per_ring + ring * 2

		for slot in range(slots):
			if idx >= _buildings.size():
				break

			var angle = (float(slot) / slots) * TAU
			if ring % 2 == 1:
				angle += PI / slots

			var wx = WORLD_CENTER_X + cos(angle) * r
			var wy = WORLD_CENTER_Y + sin(angle) * r

			var building = _buildings[idx]
			var bid = building.get("id", "building_%d" % idx)
			var btype = building.get("type", 0)

			var height_key = _get_building_height_key(btype)
			var base_h = BUILDING_HEIGHTS.get(height_key, 8.0)

			_building_layout[bid] = {
				"world_x": wx,
				"world_y": wy,
				"height": base_h * tier_mult,
				"category": _get_building_category(btype)
			}

			idx += 1

		ring += 1

# Compatibility API
func update_state(buildings: Array, colonists: Array):
	_buildings = buildings
	_colonists = colonists
	_layout_buildings()

func set_game_time(days: float, ts: float):
	_year = int(days / 365) + 1
	_time_scale = ts  # Sync animation speed with game speed

func set_robot_count(_c: int): pass
func set_priority_alerts(_a: Array): pass
func trigger_event_effect(_e: String, _d: float = 1.0): pass
func trigger_building_crisis(_b: String): pass

func start_sandstorm(intensity: float = 1.0):
	_sandstorm_active = true
	_sandstorm_intensity = intensity

func stop_sandstorm():
	_sandstorm_active = false
	_sandstorm_intensity = 0.0

func activate_force_field(strength: float = 1.0):
	_force_field_active = true
	_force_field_strength = strength

func deactivate_force_field():
	_force_field_active = false

func set_colony_tier(tier: String):
	"""Manually set tier for testing: survival, growth, society, independence, transcendence"""
	_colony_tier = tier

func set_camera_zoom(z: float):
	_camera_zoom = clamp(z, 0.4, 3.0)

func set_camera_offset(offset: Vector2):
	_camera_pan = offset
