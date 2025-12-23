extends Node2D

## Journey indicator - shows Earth → Ship → Mars progress

# ============================================================================
# CONFIGURATION
# ============================================================================

@export var journey_y: float = 560.0  # Y position of the journey line
@export var earth_x: float = 50.0
@export var mars_x: float = 750.0
@export var total_days: int = 183

# ============================================================================
# STATE
# ============================================================================

var current_day: int = 1
var mars_visible: bool = false  # Mars becomes visible partway through

# ============================================================================
# DRAW
# ============================================================================

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	_draw_journey_line()
	_draw_earth()
	_draw_ship_marker()
	_draw_mars()
	_draw_day_markers()

func _draw_journey_line() -> void:
	# Background line
	draw_line(
		Vector2(earth_x, journey_y),
		Vector2(mars_x, journey_y),
		Color(0.2, 0.2, 0.3),
		2.0
	)

	# Progress line (traveled portion)
	var progress = float(current_day) / float(total_days)
	var ship_x = lerp(earth_x, mars_x, progress)
	draw_line(
		Vector2(earth_x, journey_y),
		Vector2(ship_x, journey_y),
		Color(0.3, 0.5, 0.7),
		2.0
	)

func _draw_earth() -> void:
	# Earth - blue marble
	var earth_pos = Vector2(earth_x, journey_y)

	# Glow
	draw_circle(earth_pos, 18, Color(0.2, 0.4, 0.8, 0.2))

	# Earth body
	draw_circle(earth_pos, 12, Color(0.2, 0.4, 0.9))

	# Continents hint
	draw_circle(earth_pos + Vector2(-3, -2), 4, Color(0.3, 0.6, 0.3))
	draw_circle(earth_pos + Vector2(3, 3), 3, Color(0.3, 0.6, 0.3))

	# Atmosphere rim
	draw_arc(earth_pos, 12, 0, TAU, 32, Color(0.5, 0.7, 1.0, 0.5), 1.5)

	# Label
	draw_string(
		ThemeDB.fallback_font,
		Vector2(earth_x - 20, journey_y + 28),
		"EARTH",
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		10,
		Color(0.5, 0.6, 0.7)
	)

func _draw_mars() -> void:
	var mars_pos = Vector2(mars_x, journey_y)

	# Calculate apparent size based on distance (grows as we approach)
	var progress = float(current_day) / float(total_days)
	var base_size = 8.0
	var max_size = 14.0
	var size = lerp(base_size, max_size, progress * progress)  # Quadratic growth

	# Mars visibility (becomes visible around day 90)
	var alpha = 1.0
	if current_day < 60:
		alpha = 0.2
	elif current_day < 90:
		alpha = lerp(0.2, 0.6, (current_day - 60) / 30.0)
	elif current_day < 120:
		alpha = lerp(0.6, 1.0, (current_day - 90) / 30.0)

	# Glow (more visible as we approach)
	if alpha > 0.5:
		draw_circle(mars_pos, size + 6, Color(0.8, 0.3, 0.2, 0.2 * alpha))

	# Mars body
	draw_circle(mars_pos, size, Color(0.8 * alpha, 0.3 * alpha, 0.2 * alpha))

	# Surface features
	if alpha > 0.4:
		draw_circle(mars_pos + Vector2(-2, -1), size * 0.2, Color(0.6 * alpha, 0.2 * alpha, 0.15 * alpha))
		# Polar cap hint
		draw_circle(mars_pos + Vector2(0, -size * 0.7), size * 0.25, Color(0.9 * alpha, 0.85 * alpha, 0.8 * alpha))

	# Label
	var label_alpha = alpha if current_day > 30 else 0.3
	draw_string(
		ThemeDB.fallback_font,
		Vector2(mars_x - 15, journey_y + 28),
		"MARS",
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		10,
		Color(0.7, 0.4, 0.3, label_alpha)
	)

func _draw_ship_marker() -> void:
	var progress = float(current_day) / float(total_days)
	var ship_x = lerp(earth_x, mars_x, progress)
	var ship_pos = Vector2(ship_x, journey_y - 15)

	# Ship icon (simple triangle pointing right)
	var ship_points = PackedVector2Array([
		ship_pos + Vector2(8, 0),   # Nose
		ship_pos + Vector2(-6, -5), # Top rear
		ship_pos + Vector2(-6, 5)   # Bottom rear
	])
	draw_colored_polygon(ship_points, Color(0.7, 0.8, 0.9))

	# Engine glow
	draw_circle(ship_pos + Vector2(-8, 0), 3, Color(0.4, 0.6, 1.0, 0.6))

	# Day counter
	var day_text = "Day %d" % current_day
	draw_string(
		ThemeDB.fallback_font,
		Vector2(ship_x - 15, journey_y - 28),
		day_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		-1,
		11,
		Color(0.8, 0.85, 0.9)
	)

func _draw_day_markers() -> void:
	# Draw milestone markers
	var milestones = [30, 60, 90, 120, 150]

	for day in milestones:
		var progress = float(day) / float(total_days)
		var x = lerp(earth_x, mars_x, progress)

		# Small tick mark
		draw_line(
			Vector2(x, journey_y - 4),
			Vector2(x, journey_y + 4),
			Color(0.3, 0.3, 0.4),
			1.0
		)

# ============================================================================
# API
# ============================================================================

func set_current_day(day: int) -> void:
	current_day = clampi(day, 1, total_days)

func set_mars_visible(visible: bool) -> void:
	mars_visible = visible
