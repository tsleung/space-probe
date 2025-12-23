extends Node2D

## Ship hull - sleek interplanetary vessel with impressive engines
## Designed for the "Overcooked meets Apollo 13" aesthetic

# ============================================================================
# CONFIGURATION
# ============================================================================

enum EngineConfig {
	SINGLE_MASSIVE,     # One huge engine - simple, powerful
	DUAL_SYMMETRIC,     # Two large engines - balanced
	TRI_CLUSTER,        # Three engines in triangle - versatile
	QUAD_ARRAY          # Four engines - maximum thrust
}

@export var engine_config: EngineConfig = EngineConfig.DUAL_SYMMETRIC
@export var hull_rect: Rect2 = Rect2(720, 190, 480, 360)

# Colors
var hull_primary: Color = Color(0.22, 0.24, 0.28)
var hull_secondary: Color = Color(0.18, 0.20, 0.24)
var hull_accent: Color = Color(0.35, 0.38, 0.45)
var hull_outline: Color = Color(0.45, 0.48, 0.55)
var engine_housing: Color = Color(0.15, 0.16, 0.20)
var engine_glow_inner: Color = Color(0.9, 0.95, 1.0)
var engine_glow_mid: Color = Color(0.4, 0.6, 1.0)
var engine_glow_outer: Color = Color(0.2, 0.35, 0.9, 0.4)
var solar_panel_color: Color = Color(0.15, 0.2, 0.35)
var solar_panel_grid: Color = Color(0.25, 0.35, 0.5)
var radiator_color: Color = Color(0.6, 0.55, 0.5)
var window_glow: Color = Color(0.7, 0.85, 1.0, 0.8)

# Animation
var time: float = 0.0
var engine_flicker: float = 1.0

# Burn effect state
var burn_active: bool = false
var burn_intensity: float = 0.0
var burn_timer: float = 0.0
var burn_duration: float = 2.5

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	z_index = -1

func _process(delta: float) -> void:
	time += delta
	# Engine flicker effect
	engine_flicker = 0.85 + 0.15 * sin(time * 15.0) + 0.1 * sin(time * 23.0)

	# Handle correction burn effect
	if burn_active:
		burn_timer += delta
		# Ramp up quickly, sustain, then fade
		if burn_timer < 0.3:
			# Ramp up
			burn_intensity = burn_timer / 0.3
		elif burn_timer < burn_duration - 0.5:
			# Sustain with slight pulse
			burn_intensity = 1.0 + 0.2 * sin(burn_timer * 8.0)
		elif burn_timer < burn_duration:
			# Fade out
			burn_intensity = (burn_duration - burn_timer) / 0.5
		else:
			# Done
			burn_active = false
			burn_intensity = 0.0
			burn_timer = 0.0

	queue_redraw()

# ============================================================================
# DRAW
# ============================================================================

func _draw() -> void:
	_draw_solar_panels()
	_draw_radiators()
	_draw_engine_section()
	_draw_main_hull()
	_draw_nose_section()
	_draw_hull_details()
	_draw_engine_glow()
	_draw_windows()

func _draw_main_hull() -> void:
	var left = hull_rect.position.x
	var right = hull_rect.position.x + hull_rect.size.x
	var top = hull_rect.position.y
	var bottom = hull_rect.position.y + hull_rect.size.y
	var mid_y = (top + bottom) / 2.0
	var height = hull_rect.size.y

	# Sleek curved hull body
	var points = PackedVector2Array()

	# Top curve (from engine section to nose)
	points.append(Vector2(left - 20, top + 20))
	points.append(Vector2(left + 40, top - 15))  # Slight upward curve
	points.append(Vector2(left + 150, top - 25))
	points.append(Vector2(right - 100, top - 20))
	points.append(Vector2(right, top + 30))

	# Nose taper
	points.append(Vector2(right + 80, mid_y - 30))
	points.append(Vector2(right + 120, mid_y))  # Nose tip
	points.append(Vector2(right + 80, mid_y + 30))

	# Bottom curve (nose back to engine)
	points.append(Vector2(right, bottom - 30))
	points.append(Vector2(right - 100, bottom + 20))
	points.append(Vector2(left + 150, bottom + 25))
	points.append(Vector2(left + 40, bottom + 15))
	points.append(Vector2(left - 20, bottom - 20))

	# Draw main hull
	draw_colored_polygon(points, hull_primary)

	# Hull outline
	for i in range(points.size()):
		var next_i = (i + 1) % points.size()
		draw_line(points[i], points[next_i], hull_outline, 3.0)

	# Secondary hull stripe (racing stripe effect)
	var stripe_points = PackedVector2Array([
		Vector2(left, mid_y - 40),
		Vector2(right + 60, mid_y - 25),
		Vector2(right + 60, mid_y + 25),
		Vector2(left, mid_y + 40)
	])
	draw_colored_polygon(stripe_points, hull_secondary)
	draw_line(stripe_points[0], stripe_points[1], hull_accent, 2.0)
	draw_line(stripe_points[2], stripe_points[3], hull_accent, 2.0)

	# Interior cutaway (where we see inside)
	var cutaway = Rect2(
		hull_rect.position.x + 15,
		hull_rect.position.y + 15,
		hull_rect.size.x - 30,
		hull_rect.size.y - 30
	)
	draw_rect(cutaway, Color(0.03, 0.03, 0.05), true)
	draw_rect(cutaway, hull_outline, false, 2.0)

func _draw_nose_section() -> void:
	var right = hull_rect.position.x + hull_rect.size.x
	var mid_y = hull_rect.position.y + hull_rect.size.y / 2.0

	# Nose cone detail
	var nose_detail = PackedVector2Array([
		Vector2(right + 40, mid_y - 20),
		Vector2(right + 100, mid_y),
		Vector2(right + 40, mid_y + 20)
	])
	draw_colored_polygon(nose_detail, hull_accent)

	# Antenna
	draw_line(Vector2(right + 110, mid_y), Vector2(right + 140, mid_y - 30), hull_outline, 2.0)
	draw_circle(Vector2(right + 140, mid_y - 30), 4, Color(0.8, 0.8, 0.9))

	# Docking port indicator
	draw_circle(Vector2(right + 115, mid_y), 6, hull_secondary)
	draw_circle(Vector2(right + 115, mid_y), 4, Color(0.3, 0.8, 0.4, 0.6))

func _draw_engine_section() -> void:
	var left = hull_rect.position.x
	var mid_y = hull_rect.position.y + hull_rect.size.y / 2.0
	var height = hull_rect.size.y

	# Engine housing based on configuration
	match engine_config:
		EngineConfig.SINGLE_MASSIVE:
			_draw_single_engine_housing(left, mid_y)
		EngineConfig.DUAL_SYMMETRIC:
			_draw_dual_engine_housing(left, mid_y, height)
		EngineConfig.TRI_CLUSTER:
			_draw_tri_engine_housing(left, mid_y, height)
		EngineConfig.QUAD_ARRAY:
			_draw_quad_engine_housing(left, mid_y, height)

func _draw_single_engine_housing(left: float, mid_y: float) -> void:
	# Massive single engine bell
	var bell_points = PackedVector2Array([
		Vector2(left - 30, mid_y - 80),
		Vector2(left - 100, mid_y - 120),
		Vector2(left - 100, mid_y + 120),
		Vector2(left - 30, mid_y + 80)
	])
	draw_colored_polygon(bell_points, engine_housing)

	# Engine bell rim
	draw_line(Vector2(left - 100, mid_y - 120), Vector2(left - 100, mid_y + 120), hull_outline, 4.0)

	# Engine detail rings
	for i in range(3):
		var x = left - 40 - i * 20
		draw_line(Vector2(x, mid_y - 70 - i * 15), Vector2(x, mid_y + 70 + i * 15), hull_accent, 2.0)

func _draw_dual_engine_housing(left: float, mid_y: float, height: float) -> void:
	var offset = height * 0.28
	for sign in [-1, 1]:
		var ey = mid_y + sign * offset

		# Engine nacelle
		var nacelle = PackedVector2Array([
			Vector2(left - 20, ey - 50),
			Vector2(left - 80, ey - 70),
			Vector2(left - 80, ey + 70),
			Vector2(left - 20, ey + 50)
		])
		draw_colored_polygon(nacelle, engine_housing)

		# Engine bell
		draw_line(Vector2(left - 80, ey - 70), Vector2(left - 80, ey + 70), hull_outline, 3.0)

		# Detail rings
		draw_line(Vector2(left - 50, ey - 55), Vector2(left - 50, ey + 55), hull_accent, 2.0)
		draw_line(Vector2(left - 65, ey - 62), Vector2(left - 65, ey + 62), hull_accent, 1.5)

	# Center fuel tank/connector
	var tank = PackedVector2Array([
		Vector2(left - 30, mid_y - 40),
		Vector2(left - 60, mid_y - 30),
		Vector2(left - 60, mid_y + 30),
		Vector2(left - 30, mid_y + 40)
	])
	draw_colored_polygon(tank, hull_secondary)

func _draw_tri_engine_housing(left: float, mid_y: float, height: float) -> void:
	var positions = [
		mid_y - height * 0.35,
		mid_y,
		mid_y + height * 0.35
	]

	for ey in positions:
		var nacelle = PackedVector2Array([
			Vector2(left - 15, ey - 35),
			Vector2(left - 60, ey - 50),
			Vector2(left - 60, ey + 50),
			Vector2(left - 15, ey + 35)
		])
		draw_colored_polygon(nacelle, engine_housing)
		draw_line(Vector2(left - 60, ey - 50), Vector2(left - 60, ey + 50), hull_outline, 3.0)
		draw_line(Vector2(left - 40, ey - 42), Vector2(left - 40, ey + 42), hull_accent, 1.5)

func _draw_quad_engine_housing(left: float, mid_y: float, height: float) -> void:
	var offsets = [-0.38, -0.13, 0.13, 0.38]

	for off in offsets:
		var ey = mid_y + height * off
		var nacelle = PackedVector2Array([
			Vector2(left - 10, ey - 28),
			Vector2(left - 50, ey - 38),
			Vector2(left - 50, ey + 38),
			Vector2(left - 10, ey + 28)
		])
		draw_colored_polygon(nacelle, engine_housing)
		draw_line(Vector2(left - 50, ey - 38), Vector2(left - 50, ey + 38), hull_outline, 2.5)

func _draw_engine_glow() -> void:
	var left = hull_rect.position.x
	var mid_y = hull_rect.position.y + hull_rect.size.y / 2.0
	var height = hull_rect.size.y

	match engine_config:
		EngineConfig.SINGLE_MASSIVE:
			_draw_engine_flame(left - 100, mid_y, 100, 200)
		EngineConfig.DUAL_SYMMETRIC:
			var offset = height * 0.28
			_draw_engine_flame(left - 80, mid_y - offset, 60, 120)
			_draw_engine_flame(left - 80, mid_y + offset, 60, 120)
		EngineConfig.TRI_CLUSTER:
			for ey in [mid_y - height * 0.35, mid_y, mid_y + height * 0.35]:
				_draw_engine_flame(left - 60, ey, 45, 90)
		EngineConfig.QUAD_ARRAY:
			for off in [-0.38, -0.13, 0.13, 0.38]:
				_draw_engine_flame(left - 50, mid_y + height * off, 35, 70)

func _draw_engine_flame(x: float, y: float, width: float, length: float) -> void:
	var flicker = engine_flicker

	# During correction burn, flames are MUCH bigger and brighter
	var burn_scale = 1.0 + burn_intensity * 2.5  # Up to 3.5x longer
	var burn_width_scale = 1.0 + burn_intensity * 0.5  # Slightly wider too
	var flame_length = length * flicker * burn_scale

	# Burn adds orange/yellow tint to the normally blue flames
	var burn_color_shift = burn_intensity * 0.6

	# During heavy burn, add extra outer corona
	if burn_intensity > 0.3:
		var corona = PackedVector2Array([
			Vector2(x, y - width * 1.2 * burn_width_scale),
			Vector2(x - flame_length * 1.5, y),
			Vector2(x, y + width * 1.2 * burn_width_scale)
		])
		var corona_color = Color(1.0, 0.6, 0.2, 0.15 * burn_intensity)
		draw_colored_polygon(corona, corona_color)

	# Outer glow (large, transparent) - shifts orange during burn
	var outer = PackedVector2Array([
		Vector2(x, y - width * 0.8 * burn_width_scale),
		Vector2(x - flame_length * 1.2, y),
		Vector2(x, y + width * 0.8 * burn_width_scale)
	])
	var outer_r = lerp(engine_glow_outer.r, 1.0, burn_color_shift)
	var outer_g = lerp(engine_glow_outer.g, 0.5, burn_color_shift)
	var outer_b = lerp(engine_glow_outer.b, 0.2, burn_color_shift)
	draw_colored_polygon(outer, Color(outer_r, outer_g, outer_b, (0.25 + burn_intensity * 0.3) * flicker))

	# Middle glow - shifts more orange during burn
	var mid = PackedVector2Array([
		Vector2(x, y - width * 0.5 * burn_width_scale),
		Vector2(x - flame_length * 0.8, y),
		Vector2(x, y + width * 0.5 * burn_width_scale)
	])
	var mid_r = lerp(engine_glow_mid.r, 1.0, burn_color_shift)
	var mid_g = lerp(engine_glow_mid.g, 0.7, burn_color_shift)
	var mid_b = lerp(engine_glow_mid.b, 0.3, burn_color_shift)
	draw_colored_polygon(mid, Color(mid_r, mid_g, mid_b, (0.5 + burn_intensity * 0.4) * flicker))

	# Inner core (bright) - stays bright white/yellow during burn
	var inner = PackedVector2Array([
		Vector2(x, y - width * 0.25 * burn_width_scale),
		Vector2(x - flame_length * 0.5, y),
		Vector2(x, y + width * 0.25 * burn_width_scale)
	])
	var inner_r = lerp(engine_glow_inner.r, 1.0, burn_color_shift)
	var inner_g = lerp(engine_glow_inner.g, 0.95, burn_color_shift)
	var inner_b = lerp(engine_glow_inner.b, 0.7, burn_color_shift)
	draw_colored_polygon(inner, Color(inner_r, inner_g, inner_b, (0.8 + burn_intensity * 0.2) * flicker))

	# Hot core - pulses brighter during burn
	var core_size = width * 0.15 * (1.0 + burn_intensity * 0.5)
	draw_circle(Vector2(x - 5, y), core_size, Color(1.0, 1.0, 1.0, 0.9))

func _draw_solar_panels() -> void:
	var top = hull_rect.position.y - 60
	var bottom = hull_rect.position.y + hull_rect.size.y + 60
	var panel_x = hull_rect.position.x + 200

	# Top solar array
	_draw_solar_array(panel_x, top - 80, 180, 60, -1)

	# Bottom solar array
	_draw_solar_array(panel_x, bottom + 20, 180, 60, 1)

func _draw_solar_array(x: float, y: float, width: float, height: float, direction: int) -> void:
	# Panel support strut
	draw_line(
		Vector2(x + width/2, y + height/2 - direction * height),
		Vector2(x + width/2, y + height/2),
		hull_outline, 3.0
	)

	# Main panel
	var panel = Rect2(x, y, width, height)
	draw_rect(panel, solar_panel_color, true)
	draw_rect(panel, hull_outline, false, 2.0)

	# Panel grid lines
	for i in range(1, 6):
		var px = x + width * i / 6.0
		draw_line(Vector2(px, y), Vector2(px, y + height), solar_panel_grid, 1.0)
	for i in range(1, 3):
		var py = y + height * i / 3.0
		draw_line(Vector2(x, py), Vector2(x + width, py), solar_panel_grid, 1.0)

func _draw_radiators() -> void:
	var left = hull_rect.position.x + 50
	var top = hull_rect.position.y - 40
	var bottom = hull_rect.position.y + hull_rect.size.y + 40

	# Top radiator fins
	for i in range(3):
		var fin_x = left + i * 40
		var fin = PackedVector2Array([
			Vector2(fin_x, top),
			Vector2(fin_x + 15, top - 35),
			Vector2(fin_x + 30, top)
		])
		draw_colored_polygon(fin, radiator_color)
		draw_line(fin[0], fin[1], hull_outline, 1.5)
		draw_line(fin[1], fin[2], hull_outline, 1.5)

	# Bottom radiator fins
	for i in range(3):
		var fin_x = left + i * 40
		var fin = PackedVector2Array([
			Vector2(fin_x, bottom),
			Vector2(fin_x + 15, bottom + 35),
			Vector2(fin_x + 30, bottom)
		])
		draw_colored_polygon(fin, radiator_color)
		draw_line(fin[0], fin[1], hull_outline, 1.5)
		draw_line(fin[1], fin[2], hull_outline, 1.5)

func _draw_hull_details() -> void:
	var left = hull_rect.position.x
	var right = hull_rect.position.x + hull_rect.size.x
	var top = hull_rect.position.y
	var bottom = hull_rect.position.y + hull_rect.size.y

	# Hull panel lines
	for i in range(1, 5):
		var x = left + hull_rect.size.x * i / 5.0
		draw_line(Vector2(x, top - 20), Vector2(x, bottom + 20), hull_accent, 1.0)

	# Horizontal accent lines
	draw_line(Vector2(left - 10, top + 30), Vector2(right + 50, top + 20), hull_accent, 1.5)
	draw_line(Vector2(left - 10, bottom - 30), Vector2(right + 50, bottom - 20), hull_accent, 1.5)

	# Hull identification markings
	_draw_ship_name()

func _draw_ship_name() -> void:
	# Simple geometric "MOT-01" marking near nose
	var x = hull_rect.position.x + hull_rect.size.x - 80
	var y = hull_rect.position.y - 10

	# Just draw a simple accent bar for now (text would require font)
	draw_rect(Rect2(x, y, 60, 8), hull_accent, true)
	draw_rect(Rect2(x + 70, y, 20, 8), Color(0.8, 0.3, 0.2), true)

func _draw_windows() -> void:
	var right = hull_rect.position.x + hull_rect.size.x
	var mid_y = hull_rect.position.y + hull_rect.size.y / 2.0

	# Bridge windows (near nose)
	for i in range(3):
		var wx = right + 30 + i * 15
		var wy = mid_y - 15 + i * 5
		draw_circle(Vector2(wx, wy), 5, window_glow)
		draw_circle(Vector2(wx, wy), 3, Color(1.0, 1.0, 1.0, 0.6))

	# Side observation windows
	var top = hull_rect.position.y
	var bottom = hull_rect.position.y + hull_rect.size.y

	for i in range(4):
		var wx = hull_rect.position.x + 80 + i * 100
		draw_circle(Vector2(wx, top - 8), 4, window_glow)
		draw_circle(Vector2(wx, bottom + 8), 4, window_glow)

# ============================================================================
# API
# ============================================================================

func get_interior_rect() -> Rect2:
	return Rect2(
		hull_rect.position.x + 15,
		hull_rect.position.y + 15,
		hull_rect.size.x - 30,
		hull_rect.size.y - 30
	)

func set_engine_configuration(config: EngineConfig) -> void:
	engine_config = config
	queue_redraw()

func trigger_correction_burn(duration: float = 2.5) -> void:
	## Trigger a visible engine burn for course correction
	## Flames become much larger and shift orange for the duration
	burn_active = true
	burn_timer = 0.0
	burn_duration = duration
	burn_intensity = 0.0  # Will ramp up in _process
