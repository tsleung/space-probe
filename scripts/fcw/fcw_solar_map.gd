extends Control
class_name FCWSolarMap

## Visual Solar System Map for First Contact War
## DRAMATIC EDITION - Explosions, lasers, warp jumps, and desperation

signal zone_clicked(zone_id: int)
signal zone_hovered(zone_id: int)

# ============================================================================
# CONSTANTS
# ============================================================================

# Zone positions in normalized coordinates (0-1 range, scaled to control size)
const ZONE_POSITIONS = {
	FCWTypes.ZoneId.EARTH: Vector2(0.85, 0.5),
	FCWTypes.ZoneId.MARS: Vector2(0.65, 0.5),
	FCWTypes.ZoneId.ASTEROID_BELT: Vector2(0.45, 0.3),
	FCWTypes.ZoneId.JUPITER: Vector2(0.45, 0.7),
	FCWTypes.ZoneId.SATURN: Vector2(0.25, 0.35),
	FCWTypes.ZoneId.KUIPER: Vector2(0.1, 0.5)
}

const ZONE_SIZES = {
	FCWTypes.ZoneId.EARTH: 40.0,
	FCWTypes.ZoneId.MARS: 25.0,
	FCWTypes.ZoneId.ASTEROID_BELT: 20.0,
	FCWTypes.ZoneId.JUPITER: 35.0,
	FCWTypes.ZoneId.SATURN: 30.0,
	FCWTypes.ZoneId.KUIPER: 15.0
}

const ZONE_COLORS = {
	FCWTypes.ZoneId.EARTH: Color(0.2, 0.5, 1.0),      # Blue
	FCWTypes.ZoneId.MARS: Color(0.9, 0.4, 0.2),       # Red-orange
	FCWTypes.ZoneId.ASTEROID_BELT: Color(0.6, 0.6, 0.6),  # Gray
	FCWTypes.ZoneId.JUPITER: Color(0.9, 0.7, 0.5),    # Orange-tan
	FCWTypes.ZoneId.SATURN: Color(0.9, 0.85, 0.6),    # Yellow-tan
	FCWTypes.ZoneId.KUIPER: Color(0.4, 0.5, 0.7)      # Cold blue
}

# ============================================================================
# PARTICLE TYPES
# ============================================================================

class Particle:
	var pos: Vector2
	var vel: Vector2
	var color: Color
	var life: float
	var max_life: float
	var size: float

class Ship:
	var pos: Vector2
	var target: Vector2
	var color: Color
	var progress: float = 0.0
	var trail: Array = []  # Trail positions

class Laser:
	var start: Vector2
	var end: Vector2
	var color: Color
	var life: float = 0.3
	var width: float = 2.0

class Explosion:
	var pos: Vector2
	var radius: float = 0.0
	var max_radius: float
	var life: float = 1.0
	var color: Color

# ============================================================================
# STATE
# ============================================================================

var _zones: Dictionary = {}
var _herald_position: Vector2 = Vector2.ZERO
var _herald_target_position: Vector2 = Vector2.ZERO
var _herald_current_zone: int = FCWTypes.ZoneId.KUIPER
var _herald_target_zone: int = FCWTypes.ZoneId.KUIPER
var _herald_strength: int = 50
var _selected_zone: int = -1
var _hovered_zone: int = -1
var _fleet_assignments: Dictionary = {}
var _attack_flash_timer: float = 0.0
var _is_attacking: bool = false
var _global_time: float = 0.0

# Animation
var _herald_travel_progress: float = 1.0  # 0 = at origin, 1 = at target
const HERALD_TRAVEL_SPEED = 0.5  # Progress per second

# Visual Effects
var _particles: Array = []  # Engine trails, debris, sparks
var _ships: Array = []  # Moving ship sprites
var _lasers: Array = []  # Active laser beams
var _explosions: Array = []  # Active explosions
var _screen_shake: Vector2 = Vector2.ZERO
var _screen_shake_intensity: float = 0.0
var _danger_pulse: float = 0.0  # Red vignette intensity
var _warp_flashes: Array = []  # [{pos, life}]
var _zone_damage_flash: Dictionary = {}  # zone_id -> flash intensity
var _fallen_zones: Array = []  # Track which zones have fallen for debris
var _nebula_offset: float = 0.0  # Slow drift

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Initialize herald position
	_herald_position = _get_zone_pixel_pos(FCWTypes.ZoneId.KUIPER)
	_herald_target_position = _herald_position

func _process(delta: float) -> void:
	_global_time += delta
	_nebula_offset += delta * 0.02  # Slow drift

	# Animate herald movement with trail particles
	if _herald_travel_progress < 1.0:
		_herald_travel_progress = minf(_herald_travel_progress + delta * HERALD_TRAVEL_SPEED, 1.0)
		var old_pos = _herald_position
		_herald_position = _herald_position.lerp(_herald_target_position, _herald_travel_progress)
		# Spawn menacing trail particles
		_spawn_herald_trail(old_pos)

	# Flash when attacking - spawn combat effects
	if _is_attacking:
		_attack_flash_timer += delta * 5.0
		_danger_pulse = minf(_danger_pulse + delta * 2.0, 1.0)
		# Spawn lasers and explosions during combat
		if randf() < delta * 15.0:
			_spawn_combat_laser()
		if randf() < delta * 8.0:
			_spawn_combat_explosion()
	else:
		_danger_pulse = maxf(_danger_pulse - delta * 1.5, 0.0)

	# Update screen shake
	if _screen_shake_intensity > 0:
		_screen_shake = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _screen_shake_intensity
		_screen_shake_intensity = maxf(_screen_shake_intensity - delta * 20.0, 0.0)
	else:
		_screen_shake = Vector2.ZERO

	# Update particles
	_update_particles(delta)

	# Update ships in transit
	_update_ships(delta)

	# Update lasers
	_update_lasers(delta)

	# Update explosions
	_update_explosions(delta)

	# Update warp flashes
	_update_warp_flashes(delta)

	# Update zone damage flashes
	for zone_id in _zone_damage_flash.keys():
		_zone_damage_flash[zone_id] = maxf(_zone_damage_flash[zone_id] - delta * 3.0, 0.0)

	# Ambient particles near zones with ships
	_spawn_ambient_particles(delta)

	queue_redraw()

func _draw() -> void:
	var rect = get_rect()

	# Apply screen shake offset
	var offset = _screen_shake

	# Draw nebula background
	_draw_nebula(rect, offset)

	# Draw starfield background
	_draw_starfield(rect, offset)

	# Draw zone connections with energy flow
	_draw_connections(rect, offset)

	# Draw fallen zone debris
	_draw_debris(rect, offset)

	# Draw particles (behind zones)
	_draw_particles(offset)

	# Draw zones
	for zone_id in FCWTypes.ZoneId.values():
		_draw_zone(zone_id, rect, offset)

	# Draw warp flashes
	_draw_warp_flashes(offset)

	# Draw ships in transit
	_draw_ships(offset)

	# Draw player fleets at zones
	_draw_player_fleets(rect, offset)

	# Draw lasers
	_draw_lasers(offset)

	# Draw explosions
	_draw_explosions(offset)

	# Draw Herald fleet
	_draw_herald(rect, offset)

	# Draw attack indicator if attacking
	if _is_attacking:
		_draw_attack_indicator(rect, offset)

	# Draw danger vignette
	if _danger_pulse > 0.01:
		_draw_danger_vignette(rect)

# ============================================================================
# DRAWING
# ============================================================================

func _draw_nebula(rect: Rect2, offset: Vector2) -> void:
	# Dark space with subtle colored nebula clouds
	draw_rect(rect, Color(0.01, 0.01, 0.03))

	# Draw subtle nebula patches
	var rng = RandomNumberGenerator.new()
	rng.seed = 54321
	for i in range(8):
		var base_pos = Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y)
		var nebula_pos = base_pos + Vector2(sin(_nebula_offset + i), cos(_nebula_offset * 0.7 + i)) * 10 + offset
		var nebula_color = Color(
			rng.randf_range(0.1, 0.3),
			rng.randf_range(0.0, 0.15),
			rng.randf_range(0.15, 0.4),
			0.03
		)
		var nebula_size = rng.randf_range(80, 200)
		# Multiple overlapping circles for cloud effect
		for j in range(5):
			var jitter = Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30))
			draw_circle(nebula_pos + jitter, nebula_size * (1.0 - j * 0.15), nebula_color)

func _draw_starfield(rect: Rect2, offset: Vector2) -> void:
	# Multi-layer starfield with twinkling
	var rng = RandomNumberGenerator.new()

	# Layer 1: Distant dim stars
	rng.seed = 12345
	for i in range(100):
		var pos = Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y) + offset * 0.3
		var twinkle = sin(_global_time * rng.randf_range(1.0, 3.0) + i) * 0.3 + 0.7
		var brightness = rng.randf_range(0.1, 0.4) * twinkle
		draw_circle(pos, 0.5, Color(brightness, brightness, brightness * 0.9))

	# Layer 2: Brighter stars
	rng.seed = 67890
	for i in range(40):
		var pos = Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y) + offset * 0.5
		var twinkle = sin(_global_time * rng.randf_range(2.0, 5.0) + i * 0.5) * 0.4 + 0.6
		var brightness = rng.randf_range(0.5, 1.0) * twinkle
		var star_color = Color(brightness, brightness * rng.randf_range(0.9, 1.0), brightness * rng.randf_range(0.8, 1.0))
		draw_circle(pos, rng.randf_range(0.8, 1.5), star_color)

	# Layer 3: Occasional bright stars with glow
	rng.seed = 11111
	for i in range(8):
		var pos = Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y) + offset * 0.7
		var twinkle = sin(_global_time * 1.5 + i * 2.0) * 0.3 + 0.7
		draw_circle(pos, 4, Color(1.0, 1.0, 0.9, 0.1 * twinkle))
		draw_circle(pos, 2, Color(1.0, 1.0, 0.95, 0.6 * twinkle))

func _draw_connections(rect: Rect2, offset: Vector2) -> void:
	# Draw lines between connected zones with energy flow effect
	for zone_id in FCWTypes.ZONE_CONNECTIONS:
		var pos1 = _get_zone_pixel_pos(zone_id) + offset
		for connected_zone in FCWTypes.ZONE_CONNECTIONS[zone_id]:
			if connected_zone > zone_id:  # Avoid double-drawing
				var pos2 = _get_zone_pixel_pos(connected_zone) + offset

				# Base connection line
				draw_line(pos1, pos2, Color(0.15, 0.2, 0.3, 0.4), 1.0)

				# Energy pulse traveling along the line (if both zones controlled)
				var zone1_data = _zones.get(zone_id, {})
				var zone2_data = _zones.get(connected_zone, {})
				if zone1_data.get("status", 0) == FCWTypes.ZoneStatus.CONTROLLED and zone2_data.get("status", 0) == FCWTypes.ZoneStatus.CONTROLLED:
					var pulse_pos = fmod(_global_time * 0.3 + zone_id * 0.1, 1.0)
					var pulse_point = pos1.lerp(pos2, pulse_pos)
					draw_circle(pulse_point, 2, Color(0.3, 0.6, 1.0, 0.6))

func _draw_debris(rect: Rect2, offset: Vector2) -> void:
	# Draw debris particles around fallen zones
	var rng = RandomNumberGenerator.new()
	for zone_id in _fallen_zones:
		var pos = _get_zone_pixel_pos(zone_id) + offset
		var base_size = ZONE_SIZES.get(zone_id, 20.0)
		rng.seed = zone_id * 1000 + int(_global_time * 2) % 100

		for i in range(15):
			var angle = rng.randf() * TAU + _global_time * 0.1
			var dist = base_size + rng.randf_range(5, 40)
			var debris_pos = pos + Vector2(cos(angle), sin(angle)) * dist
			var debris_size = rng.randf_range(1, 3)
			var alpha = rng.randf_range(0.2, 0.5)
			draw_circle(debris_pos, debris_size, Color(0.4, 0.3, 0.2, alpha))

func _draw_particles(offset: Vector2) -> void:
	for p in _particles:
		var alpha = p.life / p.max_life
		var color = Color(p.color.r, p.color.g, p.color.b, p.color.a * alpha)
		draw_circle(p.pos + offset, p.size * alpha, color)

func _draw_zone(zone_id: int, _rect: Rect2, offset: Vector2) -> void:
	var pos = _get_zone_pixel_pos(zone_id) + offset
	var base_size = ZONE_SIZES.get(zone_id, 20.0)
	var color = ZONE_COLORS.get(zone_id, Color.WHITE)

	var zone_data = _zones.get(zone_id, {})
	var status = zone_data.get("status", FCWTypes.ZoneStatus.CONTROLLED)

	# Status-based modifications
	match status:
		FCWTypes.ZoneStatus.FALLEN:
			color = color.darkened(0.7)
			# Draw cracked/damaged effect
			var crack_intensity = 0.3
			draw_circle(pos, base_size + 3, Color(0.3, 0.1, 0.0, crack_intensity))
		FCWTypes.ZoneStatus.UNDER_ATTACK:
			# Intense pulse effect
			var pulse = sin(_attack_flash_timer * 4.0) * 0.4 + 0.6
			color = color.lerp(Color.RED, 0.6 * pulse)
			# Shield flicker effect
			var shield_alpha = sin(_attack_flash_timer * 8.0) * 0.3 + 0.4
			draw_arc(pos, base_size + 5, 0, TAU, 32, Color(0.5, 0.8, 1.0, shield_alpha), 2.0)

	# Damage flash overlay
	var damage_flash = _zone_damage_flash.get(zone_id, 0.0)
	if damage_flash > 0:
		color = color.lerp(Color.WHITE, damage_flash)

	# Selection/hover highlight
	if zone_id == _selected_zone:
		draw_circle(pos, base_size + 10, Color(1.0, 1.0, 0.5, 0.3))
		draw_arc(pos, base_size + 10, 0, TAU, 32, Color(1.0, 1.0, 0.5, 0.8), 2.0)
	elif zone_id == _hovered_zone:
		draw_circle(pos, base_size + 6, Color(1.0, 1.0, 1.0, 0.15))

	# Herald target indicator - DANGER
	if zone_id == _herald_target_zone and status != FCWTypes.ZoneStatus.FALLEN:
		var target_pulse = sin(_attack_flash_timer * 3.0) * 0.4 + 0.6
		# Multiple warning rings
		draw_arc(pos, base_size + 15, 0, TAU, 32, Color(1.0, 0.2, 0.1, target_pulse * 0.9), 3.0)
		draw_arc(pos, base_size + 20, 0, TAU, 32, Color(1.0, 0.1, 0.0, target_pulse * 0.5), 2.0)
		# Rotating warning segments
		var rot = _global_time * 2.0
		for i in range(4):
			var start_angle = rot + i * TAU / 4
			draw_arc(pos, base_size + 25, start_angle, start_angle + 0.3, 8, Color(1.0, 0.3, 0.1, target_pulse * 0.7), 2.0)

	# Planet glow (atmospheric effect)
	if status != FCWTypes.ZoneStatus.FALLEN:
		draw_circle(pos, base_size + 3, Color(color.r, color.g, color.b, 0.2))

	# Draw the planet
	draw_circle(pos, base_size, color)

	# Planet shine highlight
	if status != FCWTypes.ZoneStatus.FALLEN:
		var highlight_pos = pos + Vector2(-base_size * 0.3, -base_size * 0.3)
		draw_circle(highlight_pos, base_size * 0.3, Color(1, 1, 1, 0.2))

	# Draw zone name
	var font = ThemeDB.fallback_font
	var font_size = 12
	var zone_name = FCWTypes.get_zone_name(zone_id)
	var text_size = font.get_string_size(zone_name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var name_color = Color.WHITE if status != FCWTypes.ZoneStatus.FALLEN else Color(0.5, 0.5, 0.5)
	draw_string(font, pos + Vector2(-text_size.x / 2, base_size + 18), zone_name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, name_color)

	# Draw defense value with color coding
	if status != FCWTypes.ZoneStatus.FALLEN:
		var defense = zone_data.get("defense", 0)
		var def_text = "DEF: %d" % defense
		var def_color: Color
		if defense >= _herald_strength * 1.3:
			def_color = Color(0.3, 1.0, 0.3)  # Strong
		elif defense >= _herald_strength:
			def_color = Color(1.0, 1.0, 0.3)  # Marginal
		else:
			def_color = Color(1.0, 0.3, 0.3)  # Weak
		draw_string(font, pos + Vector2(-25, base_size + 30), def_text, HORIZONTAL_ALIGNMENT_CENTER, 50, 10, def_color)

func _draw_warp_flashes(offset: Vector2) -> void:
	for flash in _warp_flashes:
		var alpha = flash.life
		var ring_size = (1.0 - flash.life) * 30 + 5
		draw_arc(flash.pos + offset, ring_size, 0, TAU, 16, Color(0.5, 0.8, 1.0, alpha), 2.0)
		draw_circle(flash.pos + offset, 5 * alpha, Color(0.8, 0.9, 1.0, alpha))

func _draw_ships(offset: Vector2) -> void:
	for ship in _ships:
		var pos = ship.pos + offset
		# Draw engine trail
		for i in range(ship.trail.size()):
			var trail_pos = ship.trail[i] + offset
			var trail_alpha = float(i) / ship.trail.size() * 0.5
			draw_circle(trail_pos, 2, Color(0.3, 0.6, 1.0, trail_alpha))

		# Draw ship
		var dir = (ship.target - ship.pos).normalized()
		var perp = Vector2(-dir.y, dir.x)
		var points = PackedVector2Array([
			pos + dir * 6,
			pos - dir * 4 + perp * 3,
			pos - dir * 4 - perp * 3
		])
		draw_colored_polygon(points, ship.color)
		# Engine glow
		draw_circle(pos - dir * 5, 3, Color(0.3, 0.6, 1.0, 0.6))

func _draw_player_fleets(rect: Rect2, offset: Vector2) -> void:
	# Draw fleet formations at each zone with assigned ships
	for zone_id in _fleet_assignments:
		var assignment = _fleet_assignments[zone_id]
		var total_ships = 0
		for ship_type in assignment:
			total_ships += assignment[ship_type]

		if total_ships <= 0:
			continue

		var pos = _get_zone_pixel_pos(zone_id) + offset
		var zone_size = ZONE_SIZES.get(zone_id, 20.0)

		# Draw multiple small ship icons in formation
		var fleet_center = pos + Vector2(zone_size + 20, 0)
		var ships_to_draw = mini(total_ships, 12)  # Cap visual ships

		for i in range(ships_to_draw):
			var angle = (float(i) / ships_to_draw) * TAU + _global_time * 0.5
			var orbit_radius = 8 + (i % 3) * 4
			var ship_pos = fleet_center + Vector2(cos(angle), sin(angle)) * orbit_radius

			# Tiny ship triangle
			var ship_dir = Vector2(cos(angle + PI/2), sin(angle + PI/2))
			var ship_perp = Vector2(-ship_dir.y, ship_dir.x)
			var points = PackedVector2Array([
				ship_pos + ship_dir * 3,
				ship_pos - ship_dir * 2 + ship_perp * 2,
				ship_pos - ship_dir * 2 - ship_perp * 2
			])
			draw_colored_polygon(points, Color(0.4, 0.9, 0.4))

		# Draw ship count
		var font = ThemeDB.fallback_font
		draw_string(font, fleet_center + Vector2(15, 4), "x%d" % total_ships, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 1.0, 0.5))

func _draw_lasers(offset: Vector2) -> void:
	for laser in _lasers:
		var alpha = laser.life / 0.3
		var glow_color = Color(laser.color.r, laser.color.g, laser.color.b, alpha * 0.3)
		var core_color = Color(laser.color.r, laser.color.g, laser.color.b, alpha)

		# Glow
		draw_line(laser.start + offset, laser.end + offset, glow_color, laser.width * 3)
		# Core
		draw_line(laser.start + offset, laser.end + offset, core_color, laser.width)
		# Bright center
		draw_line(laser.start + offset, laser.end + offset, Color(1, 1, 1, alpha * 0.8), laser.width * 0.5)

func _draw_explosions(offset: Vector2) -> void:
	for exp in _explosions:
		var progress = 1.0 - exp.life
		var current_radius = exp.max_radius * progress

		# Outer ring
		var ring_alpha = exp.life * 0.8
		draw_arc(exp.pos + offset, current_radius, 0, TAU, 24, Color(exp.color.r, exp.color.g * 0.5, 0, ring_alpha), 3.0)

		# Inner flash
		var flash_radius = current_radius * 0.6
		var flash_alpha = exp.life
		draw_circle(exp.pos + offset, flash_radius, Color(1, 1, 0.8, flash_alpha * 0.5))

		# Core
		var core_radius = current_radius * 0.3 * exp.life
		draw_circle(exp.pos + offset, core_radius, Color(1, 1, 1, exp.life))

func _draw_herald(rect: Rect2, offset: Vector2) -> void:
	var pos = _herald_position + offset

	# Ominous dark aura
	var aura_pulse = sin(_global_time * 1.5) * 0.2 + 0.8
	for i in range(5):
		var aura_size = 40 - i * 6
		var aura_alpha = 0.05 * aura_pulse * (5 - i) / 5.0
		draw_circle(pos, aura_size, Color(0.5, 0.0, 0.0, aura_alpha))

	# Menacing glow rings
	var glow_pulse = sin(_attack_flash_timer * 2.5) * 0.3 + 0.7
	draw_circle(pos, 28 * glow_pulse, Color(1.0, 0.0, 0.0, 0.1))
	draw_circle(pos, 20 * glow_pulse, Color(1.0, 0.05, 0.0, 0.2))
	draw_circle(pos, 12 * glow_pulse, Color(1.0, 0.1, 0.0, 0.3))

	# Herald icon - angular, threatening shape
	var size = 14.0
	var rot = _global_time * 0.3
	# Main body - hexagonal
	var hex_points = PackedVector2Array()
	for i in range(6):
		var angle = rot + i * TAU / 6
		hex_points.append(pos + Vector2(cos(angle), sin(angle)) * size)
	draw_colored_polygon(hex_points, Color(0.8, 0.05, 0.05))

	# Inner detail
	var inner_points = PackedVector2Array()
	for i in range(6):
		var angle = rot + i * TAU / 6 + TAU / 12
		inner_points.append(pos + Vector2(cos(angle), sin(angle)) * size * 0.5)
	draw_colored_polygon(inner_points, Color(0.3, 0.0, 0.0))

	# Eye/core
	draw_circle(pos, 4, Color(1.0, 0.3, 0.0))
	draw_circle(pos, 2, Color(1.0, 0.8, 0.0))

	# Draw herald strength
	var font = ThemeDB.fallback_font
	var strength_text = "HERALD"
	var strength_num = "%d" % _herald_strength
	draw_string(font, pos + Vector2(-22, -28), strength_text, HORIZONTAL_ALIGNMENT_CENTER, 44, 10, Color(1.0, 0.4, 0.4))
	draw_string(font, pos + Vector2(-15, -18), strength_num, HORIZONTAL_ALIGNMENT_CENTER, 30, 12, Color(1.0, 0.2, 0.2))

func _draw_attack_indicator(_rect: Rect2, offset: Vector2) -> void:
	var target_pos = _get_zone_pixel_pos(_herald_target_zone) + offset
	var herald_pos = _herald_position + offset

	# Multiple attack beams
	var rng = RandomNumberGenerator.new()
	for beam in range(5):
		rng.seed = int(_attack_flash_timer * 20 + beam * 100) % 10000
		var beam_offset = Vector2(rng.randf_range(-8, 8), rng.randf_range(-8, 8))
		var flash = sin(_attack_flash_timer * 10.0 + beam) * 0.5 + 0.5

		# Red attack beam
		draw_line(herald_pos + beam_offset, target_pos + beam_offset * 0.3, Color(1.0, 0.2, 0.0, flash * 0.8), 2.0)
		# Yellow core
		draw_line(herald_pos + beam_offset, target_pos + beam_offset * 0.3, Color(1.0, 0.8, 0.0, flash * 0.5), 1.0)

	# Impact flashes at target
	for i in range(3):
		rng.seed = int(_attack_flash_timer * 15 + i * 50) % 10000
		var impact_offset = Vector2(rng.randf_range(-20, 20), rng.randf_range(-20, 20))
		var impact_flash = sin(_attack_flash_timer * 12.0 + i * 2) * 0.5 + 0.5
		draw_circle(target_pos + impact_offset, 5 * impact_flash, Color(1.0, 0.5, 0.0, impact_flash * 0.7))

func _draw_danger_vignette(rect: Rect2) -> void:
	# Red vignette around edges during danger
	var center = rect.size / 2
	var max_dist = center.length()

	# Draw gradient rectangles on edges
	var edge_color = Color(0.8, 0.0, 0.0, _danger_pulse * 0.4)
	var edge_size = 60 * _danger_pulse

	# Top
	draw_rect(Rect2(0, 0, rect.size.x, edge_size), Color(edge_color.r, edge_color.g, edge_color.b, edge_color.a * 0.5))
	# Bottom
	draw_rect(Rect2(0, rect.size.y - edge_size, rect.size.x, edge_size), Color(edge_color.r, edge_color.g, edge_color.b, edge_color.a * 0.5))
	# Left
	draw_rect(Rect2(0, 0, edge_size, rect.size.y), Color(edge_color.r, edge_color.g, edge_color.b, edge_color.a * 0.3))
	# Right
	draw_rect(Rect2(rect.size.x - edge_size, 0, edge_size, rect.size.y), Color(edge_color.r, edge_color.g, edge_color.b, edge_color.a * 0.3))

# ============================================================================
# POSITIONING
# ============================================================================

func _get_zone_pixel_pos(zone_id: int) -> Vector2:
	var normalized_pos = ZONE_POSITIONS.get(zone_id, Vector2(0.5, 0.5))
	return normalized_pos * size

# ============================================================================
# EFFECTS - UPDATE FUNCTIONS
# ============================================================================

func _update_particles(delta: float) -> void:
	var i = 0
	while i < _particles.size():
		var p = _particles[i]
		p.pos += p.vel * delta
		p.life -= delta
		if p.life <= 0:
			_particles.remove_at(i)
		else:
			i += 1

func _update_ships(delta: float) -> void:
	var i = 0
	while i < _ships.size():
		var ship = _ships[i]
		ship.progress += delta * 0.8
		ship.pos = ship.pos.lerp(ship.target, ship.progress)

		# Add to trail
		ship.trail.append(ship.pos)
		if ship.trail.size() > 15:
			ship.trail.pop_front()

		if ship.progress >= 1.0:
			# Ship arrived - spawn warp flash
			_warp_flashes.append({"pos": ship.target, "life": 1.0})
			_ships.remove_at(i)
		else:
			i += 1

func _update_lasers(delta: float) -> void:
	var i = 0
	while i < _lasers.size():
		_lasers[i].life -= delta
		if _lasers[i].life <= 0:
			_lasers.remove_at(i)
		else:
			i += 1

func _update_explosions(delta: float) -> void:
	var i = 0
	while i < _explosions.size():
		_explosions[i].life -= delta
		if _explosions[i].life <= 0:
			_explosions.remove_at(i)
		else:
			i += 1

func _update_warp_flashes(delta: float) -> void:
	var i = 0
	while i < _warp_flashes.size():
		_warp_flashes[i].life -= delta * 2.0
		if _warp_flashes[i].life <= 0:
			_warp_flashes.remove_at(i)
		else:
			i += 1

# ============================================================================
# EFFECTS - SPAWN FUNCTIONS
# ============================================================================

func _spawn_herald_trail(from_pos: Vector2) -> void:
	# Spawn menacing red particles behind herald
	for j in range(2):
		var p = Particle.new()
		p.pos = from_pos + Vector2(randf_range(-5, 5), randf_range(-5, 5))
		p.vel = Vector2(randf_range(-20, 20), randf_range(-20, 20))
		p.color = Color(1.0, randf_range(0.0, 0.3), 0.0, 0.8)
		p.life = randf_range(0.3, 0.8)
		p.max_life = p.life
		p.size = randf_range(2, 5)
		_particles.append(p)

func _spawn_combat_laser() -> void:
	# Spawn laser between herald and target zone
	var target_pos = _get_zone_pixel_pos(_herald_target_zone)
	var zone_size = ZONE_SIZES.get(_herald_target_zone, 20.0)

	var laser = Laser.new()
	# From herald or from defenders
	if randf() > 0.4:
		# Herald attacking
		laser.start = _herald_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		laser.end = target_pos + Vector2(randf_range(-zone_size, zone_size), randf_range(-zone_size, zone_size))
		laser.color = Color(1.0, 0.3, 0.0)  # Red-orange
	else:
		# Defenders shooting back
		laser.start = target_pos + Vector2(randf_range(-zone_size, zone_size), randf_range(-zone_size, zone_size))
		laser.end = _herald_position + Vector2(randf_range(-15, 15), randf_range(-15, 15))
		laser.color = Color(0.3, 0.8, 1.0)  # Blue

	laser.life = 0.15 + randf() * 0.15
	laser.width = 1.0 + randf() * 2.0
	_lasers.append(laser)

func _spawn_combat_explosion() -> void:
	var target_pos = _get_zone_pixel_pos(_herald_target_zone)
	var zone_size = ZONE_SIZES.get(_herald_target_zone, 20.0)

	var exp = Explosion.new()
	# Explosions around the battle area
	exp.pos = target_pos + Vector2(randf_range(-zone_size - 20, zone_size + 20), randf_range(-zone_size - 20, zone_size + 20))
	exp.max_radius = randf_range(8, 25)
	exp.life = 0.4 + randf() * 0.3
	exp.color = Color(1.0, randf_range(0.3, 0.8), 0.0)
	_explosions.append(exp)

	# Screen shake on bigger explosions
	if exp.max_radius > 18:
		_screen_shake_intensity = maxf(_screen_shake_intensity, exp.max_radius * 0.3)

	# Spawn debris particles
	for j in range(5):
		var p = Particle.new()
		p.pos = exp.pos
		p.vel = Vector2(randf_range(-80, 80), randf_range(-80, 80))
		p.color = Color(1.0, 0.6, 0.2, 1.0)
		p.life = randf_range(0.3, 0.6)
		p.max_life = p.life
		p.size = randf_range(1, 3)
		_particles.append(p)

func _spawn_ambient_particles(_delta: float) -> void:
	# Engine glow particles near fleet formations
	if randf() < _delta * 3.0:
		for zone_id in _fleet_assignments:
			var assignment = _fleet_assignments[zone_id]
			var total_ships = 0
			for ship_type in assignment:
				total_ships += assignment[ship_type]

			if total_ships > 0 and randf() < 0.3:
				var pos = _get_zone_pixel_pos(zone_id)
				var zone_size = ZONE_SIZES.get(zone_id, 20.0)
				var fleet_center = pos + Vector2(zone_size + 20, 0)

				var p = Particle.new()
				p.pos = fleet_center + Vector2(randf_range(-15, 15), randf_range(-15, 15))
				p.vel = Vector2(randf_range(-10, 10), randf_range(-10, 10))
				p.color = Color(0.3, 0.7, 1.0, 0.6)
				p.life = randf_range(0.3, 0.6)
				p.max_life = p.life
				p.size = randf_range(1, 2)
				_particles.append(p)

func spawn_warp_in(zone_id: int) -> void:
	# Called when ships warp to a zone
	var pos = _get_zone_pixel_pos(zone_id)
	var zone_size = ZONE_SIZES.get(zone_id, 20.0)

	_warp_flashes.append({"pos": pos + Vector2(zone_size + 20, 0), "life": 1.0})

	# Spawn arrival particles
	for i in range(10):
		var p = Particle.new()
		p.pos = pos + Vector2(zone_size + 20, 0)
		p.vel = Vector2(randf_range(-50, 50), randf_range(-50, 50))
		p.color = Color(0.5, 0.8, 1.0, 1.0)
		p.life = randf_range(0.3, 0.6)
		p.max_life = p.life
		p.size = randf_range(2, 4)
		_particles.append(p)

func spawn_zone_destroyed(zone_id: int) -> void:
	# MASSIVE explosion when zone falls
	var pos = _get_zone_pixel_pos(zone_id)
	var zone_size = ZONE_SIZES.get(zone_id, 20.0)

	# Add to fallen zones for debris
	if zone_id not in _fallen_zones:
		_fallen_zones.append(zone_id)

	# Multiple large explosions
	for i in range(8):
		var exp = Explosion.new()
		exp.pos = pos + Vector2(randf_range(-zone_size, zone_size), randf_range(-zone_size, zone_size))
		exp.max_radius = randf_range(30, 60)
		exp.life = 0.8 + randf() * 0.5
		exp.color = Color(1.0, randf_range(0.2, 0.6), 0.0)
		_explosions.append(exp)

	# Big screen shake
	_screen_shake_intensity = 15.0

	# Damage flash on zone
	_zone_damage_flash[zone_id] = 1.0

	# LOTS of debris particles
	for i in range(40):
		var p = Particle.new()
		p.pos = pos + Vector2(randf_range(-zone_size, zone_size), randf_range(-zone_size, zone_size))
		p.vel = Vector2(randf_range(-100, 100), randf_range(-100, 100))
		p.color = Color(randf_range(0.8, 1.0), randf_range(0.3, 0.7), randf_range(0.0, 0.2), 1.0)
		p.life = randf_range(0.5, 1.5)
		p.max_life = p.life
		p.size = randf_range(2, 6)
		_particles.append(p)

func spawn_ship_transit(from_zone: int, to_zone: int) -> void:
	# Spawn a ship moving between zones
	var from_pos = _get_zone_pixel_pos(from_zone)
	var to_pos = _get_zone_pixel_pos(to_zone)
	var from_size = ZONE_SIZES.get(from_zone, 20.0)
	var to_size = ZONE_SIZES.get(to_zone, 20.0)

	var ship = Ship.new()
	ship.pos = from_pos + Vector2(from_size + 20, 0)
	ship.target = to_pos + Vector2(to_size + 20, 0)
	ship.color = Color(0.4, 0.9, 0.4)
	ship.progress = 0.0
	ship.trail = []
	_ships.append(ship)

	# Warp out flash
	_warp_flashes.append({"pos": ship.pos, "life": 1.0})

# ============================================================================
# INPUT
# ============================================================================

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_pos = event.position
		var new_hovered = _get_zone_at_position(mouse_pos)
		if new_hovered != _hovered_zone:
			_hovered_zone = new_hovered
			if _hovered_zone >= 0:
				zone_hovered.emit(_hovered_zone)
			queue_redraw()

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var clicked_zone = _get_zone_at_position(event.position)
			if clicked_zone >= 0:
				_selected_zone = clicked_zone
				zone_clicked.emit(clicked_zone)
				queue_redraw()

func _get_zone_at_position(pos: Vector2) -> int:
	for zone_id in FCWTypes.ZoneId.values():
		var zone_pos = _get_zone_pixel_pos(zone_id)
		var zone_size = ZONE_SIZES.get(zone_id, 20.0) + 10  # Some padding
		if pos.distance_to(zone_pos) <= zone_size:
			return zone_id
	return -1

# ============================================================================
# PUBLIC API
# ============================================================================

func update_state(state: Dictionary, zone_defenses: Dictionary) -> void:
	_zones = {}
	for zone_id in state.zones:
		var zone = state.zones[zone_id]
		_zones[zone_id] = {
			"status": zone.status,
			"population": zone.population,
			"defense": zone_defenses.get(zone_id, 0),
			"assigned_fleet": zone.assigned_fleet.duplicate()
		}

	_fleet_assignments = {}
	for zone_id in state.zones:
		var zone = state.zones[zone_id]
		if not zone.assigned_fleet.is_empty():
			_fleet_assignments[zone_id] = zone.assigned_fleet.duplicate()

	# Update herald
	var new_target = state.herald_attack_target
	if new_target != _herald_target_zone:
		# Herald is moving to a new target
		_herald_current_zone = _herald_target_zone
		_herald_target_zone = new_target
		_herald_target_position = _get_zone_pixel_pos(new_target)
		_herald_travel_progress = 0.0

	_herald_strength = state.herald_strength

	queue_redraw()

func set_selected_zone(zone_id: int) -> void:
	_selected_zone = zone_id
	queue_redraw()

func set_attacking(is_attacking: bool) -> void:
	_is_attacking = is_attacking
	if is_attacking:
		_attack_flash_timer = 0.0
	queue_redraw()

func get_selected_zone() -> int:
	return _selected_zone
