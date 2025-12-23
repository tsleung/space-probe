extends Node2D

## Ship hull - the exterior shell containing the cross-section view

# ============================================================================
# CONFIGURATION
# ============================================================================

@export var hull_color: Color = Color(0.25, 0.28, 0.32)
@export var hull_outline_color: Color = Color(0.4, 0.45, 0.5)
@export var hull_thickness: float = 8.0
@export var window_glow_color: Color = Color(0.6, 0.8, 1.0, 0.3)

# Ship dimensions - wraps around the interior rooms
var hull_rect: Rect2 = Rect2(160, 120, 480, 360)  # x, y, width, height
var nose_length: float = 60.0
var engine_length: float = 40.0

# ============================================================================
# DRAW
# ============================================================================

func _ready() -> void:
	z_index = -1  # Behind rooms

func _draw() -> void:
	_draw_hull_body()
	_draw_hull_details()
	_draw_engine_glow()

func _draw_hull_body() -> void:
	var points = PackedVector2Array()

	# Build ship shape - pointed nose on right (heading to Mars), engines on left
	var left = hull_rect.position.x - engine_length
	var right = hull_rect.position.x + hull_rect.size.x + nose_length
	var top = hull_rect.position.y
	var bottom = hull_rect.position.y + hull_rect.size.y
	var mid_y = (top + bottom) / 2

	# Nose (right side, pointed)
	points.append(Vector2(right, mid_y))  # Tip
	points.append(Vector2(right - nose_length, top))  # Top of nose

	# Top edge
	points.append(Vector2(hull_rect.position.x, top))

	# Engine section (left side)
	points.append(Vector2(left + 20, top))
	points.append(Vector2(left, top + 30))
	points.append(Vector2(left, bottom - 30))
	points.append(Vector2(left + 20, bottom))

	# Bottom edge
	points.append(Vector2(hull_rect.position.x, bottom))

	# Back to nose
	points.append(Vector2(right - nose_length, bottom))  # Bottom of nose

	# Draw filled hull
	draw_colored_polygon(points, hull_color)

	# Draw outline
	for i in range(points.size()):
		var next_i = (i + 1) % points.size()
		draw_line(points[i], points[next_i], hull_outline_color, hull_thickness * 0.5)

	# Draw inner cutaway border (where we "see inside")
	var cutaway_rect = hull_rect.grow(-hull_thickness)
	draw_rect(cutaway_rect, Color(0.05, 0.05, 0.08), true)  # Dark interior
	draw_rect(cutaway_rect, hull_outline_color, false, 2.0)  # Border

func _draw_hull_details() -> void:
	# Draw some hull panel lines
	var panel_color = Color(0.35, 0.38, 0.42)

	# Horizontal panel lines
	draw_line(
		Vector2(hull_rect.position.x, hull_rect.position.y + hull_rect.size.y * 0.33),
		Vector2(hull_rect.position.x + hull_rect.size.x, hull_rect.position.y + hull_rect.size.y * 0.33),
		panel_color, 1.0
	)
	draw_line(
		Vector2(hull_rect.position.x, hull_rect.position.y + hull_rect.size.y * 0.66),
		Vector2(hull_rect.position.x + hull_rect.size.x, hull_rect.position.y + hull_rect.size.y * 0.66),
		panel_color, 1.0
	)

	# Vertical panel lines
	for i in range(4):
		var x = hull_rect.position.x + hull_rect.size.x * (i + 1) / 5.0
		draw_line(
			Vector2(x, hull_rect.position.y - 5),
			Vector2(x, hull_rect.position.y + hull_rect.size.y + 5),
			panel_color, 1.0
		)

	# Nose window/cockpit glow
	var nose_center = Vector2(
		hull_rect.position.x + hull_rect.size.x + nose_length * 0.3,
		hull_rect.position.y + hull_rect.size.y / 2
	)
	draw_circle(nose_center, 8, window_glow_color)
	draw_circle(nose_center, 5, Color(0.8, 0.9, 1.0, 0.5))

func _draw_engine_glow() -> void:
	# Engine exhaust glow (left side)
	var engine_x = hull_rect.position.x - engine_length - 5
	var mid_y = hull_rect.position.y + hull_rect.size.y / 2

	# Draw 3 engine exhausts
	var engine_positions = [mid_y - 60, mid_y, mid_y + 60]

	for ey in engine_positions:
		# Outer glow
		var glow_points = PackedVector2Array([
			Vector2(engine_x, ey - 15),
			Vector2(engine_x - 30, ey),
			Vector2(engine_x, ey + 15)
		])
		draw_colored_polygon(glow_points, Color(0.2, 0.4, 1.0, 0.3))

		# Inner glow
		var inner_points = PackedVector2Array([
			Vector2(engine_x, ey - 8),
			Vector2(engine_x - 15, ey),
			Vector2(engine_x, ey + 8)
		])
		draw_colored_polygon(inner_points, Color(0.5, 0.7, 1.0, 0.6))

		# Core
		draw_circle(Vector2(engine_x - 5, ey), 4, Color(0.8, 0.9, 1.0, 0.8))

# ============================================================================
# API
# ============================================================================

func get_interior_rect() -> Rect2:
	return hull_rect.grow(-hull_thickness)
