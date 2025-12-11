class_name HexGrid
extends Node2D

## Hex grid view component - renders the grid and handles input
## Pure rendering based on provided state, emits events for interactions

signal cell_clicked(hex_pos: Vector2i)
signal cell_hovered(hex_pos: Vector2i)

const HEX_SIZE = 40.0
const GRID_WIDTH = 15
const GRID_HEIGHT = 11

# View state (not game state)
var _grid_data: Dictionary = {}
var _hovered_cell: Vector2i = Vector2i(-999, -999)
var _selected_component: Dictionary = {}
var _valid_positions: Array = []

func _ready():
	_init_valid_positions()

func _init_valid_positions():
	for q in range(-GRID_WIDTH / 2, GRID_WIDTH / 2 + 1):
		for r in range(-GRID_HEIGHT / 2, GRID_HEIGHT / 2 + 1):
			_valid_positions.append(Vector2i(q, r))

func _process(_delta):
	queue_redraw()

# ============================================================================
# PUBLIC API
# ============================================================================

func sync_grid(grid_data: Dictionary):
	_grid_data = grid_data

func set_selected_component(component: Dictionary):
	_selected_component = component

func clear_selection():
	_selected_component = {}

# ============================================================================
# INPUT HANDLING
# ============================================================================

func _input(event):
	if event is InputEventMouseMotion:
		var local_pos = get_local_mouse_position()
		var hex_pos = ShipLogic.pixel_to_hex(local_pos, HEX_SIZE)
		if _valid_positions.has(hex_pos) and hex_pos != _hovered_cell:
			_hovered_cell = hex_pos
			cell_hovered.emit(hex_pos)

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var local_pos = get_local_mouse_position()
			var hex_pos = ShipLogic.pixel_to_hex(local_pos, HEX_SIZE)
			if _valid_positions.has(hex_pos):
				cell_clicked.emit(hex_pos)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			var local_pos = get_local_mouse_position()
			var hex_pos = ShipLogic.pixel_to_hex(local_pos, HEX_SIZE)
			if _valid_positions.has(hex_pos):
				# Right click to remove
				GameStore.remove_component(hex_pos)

# ============================================================================
# RENDERING (pure - based on state)
# ============================================================================

func _draw():
	_draw_grid()
	_draw_components()

func _draw_grid():
	for hex_pos in _valid_positions:
		var center = ShipLogic.hex_to_pixel(hex_pos, HEX_SIZE)
		var color = _get_cell_color(hex_pos)
		_draw_hex(center, HEX_SIZE - 2, color)
		_draw_hex_outline(center, HEX_SIZE - 2, Color(0.4, 0.5, 0.6, 0.8))

func _get_cell_color(hex_pos: Vector2i) -> Color:
	var is_occupied = _grid_data.has(hex_pos) and not _grid_data[hex_pos].is_empty()

	if hex_pos == _hovered_cell:
		if not _selected_component.is_empty():
			var can_place = ShipLogic.can_place_component(
				_grid_data,
				hex_pos,
				_selected_component.hex_size,
				_valid_positions
			)
			if can_place:
				return Color(0.2, 0.8, 0.2, 0.7)  # Green - valid placement
			else:
				return Color(0.8, 0.2, 0.2, 0.7)  # Red - invalid placement
		else:
			return Color(0.4, 0.5, 0.6, 0.7)  # Neutral hover

	if is_occupied:
		return Color(0.3, 0.5, 0.7, 0.8)  # Occupied

	return Color(0.2, 0.3, 0.4, 0.5)  # Empty

func _draw_components():
	var drawn_origins: Dictionary = {}

	for hex_pos in _grid_data.keys():
		var component = _grid_data[hex_pos]
		if component.is_empty():
			continue

		var origin = component.get("hex_position", hex_pos)
		if drawn_origins.has(origin):
			continue
		drawn_origins[origin] = true

		_draw_component(origin, component)

func _draw_component(hex_pos: Vector2i, component: Dictionary):
	var center = ShipLogic.hex_to_pixel(hex_pos, HEX_SIZE)
	var bg_color = _get_component_color(component.id)

	# Darken color if under construction
	if not component.is_built:
		bg_color = bg_color.darkened(0.3)

	# Draw component hexes
	var positions = ShipLogic.get_component_hexes(hex_pos, component.hex_size, _valid_positions)
	for pos in positions:
		var pos_center = ShipLogic.hex_to_pixel(pos, HEX_SIZE)
		_draw_hex(pos_center, HEX_SIZE - 4, bg_color)

	# Draw procedural icon
	_draw_component_icon(center, component.id, component.quality)

	# Draw quality bar at bottom
	var bar_width = 30.0
	var bar_height = 4.0
	var quality_pct = component.quality / 100.0
	var quality_color = Color.RED.lerp(Color.GREEN, quality_pct)

	# Background bar
	draw_rect(Rect2(center.x - bar_width/2, center.y + 20, bar_width, bar_height), Color(0.2, 0.2, 0.2, 0.8))
	# Quality bar
	draw_rect(Rect2(center.x - bar_width/2, center.y + 20, bar_width * quality_pct, bar_height), quality_color)

	# Draw construction indicator if not built
	if not component.is_built:
		# Construction progress ring
		var progress = 1.0 - (float(component.days_remaining) / float(component.build_days))
		_draw_progress_arc(center, 25.0, progress, Color.YELLOW)
		draw_string(
			ThemeDB.fallback_font,
			center + Vector2(-8, 5),
			"%dd" % component.days_remaining,
			HORIZONTAL_ALIGNMENT_CENTER,
			16,
			11,
			Color.YELLOW
		)

func _draw_component_icon(center: Vector2, id: String, quality: float):
	var icon_color = Color.WHITE
	if quality < 50.0:
		icon_color = Color(1, 0.8, 0.8)  # Slightly red tint if damaged

	match id:
		"cockpit":
			# Cockpit: window/viewport shape
			_draw_cockpit_icon(center, icon_color)
		"engine_mount":
			# Engine: flame/thrust shape
			_draw_engine_icon(center, icon_color)
		"life_support":
			# Life support: lungs/air symbol
			_draw_life_support_icon(center, icon_color)
		"crew_room":
			# Crew: person silhouette
			_draw_person_icon(center, icon_color)
		"cargo":
			# Cargo: box shape
			_draw_cargo_icon(center, icon_color)
		"science_lab":
			# Science: flask/beaker
			_draw_science_icon(center, icon_color)
		"medical_bay":
			# Medical: cross
			_draw_medical_icon(center, icon_color)
		"fuel_tank":
			# Fuel: cylinder
			_draw_fuel_icon(center, icon_color)
		"solar_array":
			# Solar: sun rays
			_draw_solar_icon(center, icon_color)
		"comms":
			# Comms: antenna/signal
			_draw_comms_icon(center, icon_color)
		"gym":
			# Gym: dumbbell
			_draw_gym_icon(center, icon_color)
		"cafeteria":
			# Cafeteria: utensils
			_draw_cafeteria_icon(center, icon_color)
		"hangar":
			# Hangar: vehicle shape
			_draw_hangar_icon(center, icon_color)
		"mav_dock":
			# MAV: rocket shape
			_draw_mav_icon(center, icon_color)
		_:
			# Default: generic shape or engine icon for propulsion
			if component_is_engine(id):
				_draw_thruster_icon(center, icon_color)

func component_is_engine(id: String) -> bool:
	return id in ["traditional", "hermes", "hall_thruster", "nuclear", "solar_sail", "laser_sail", "pulsed_plasma", "mpd", "vasimr"]

# ============================================================================
# PROCEDURAL ICON DRAWING
# ============================================================================

func _draw_cockpit_icon(center: Vector2, color: Color):
	# Viewport/window shape
	var points = PackedVector2Array([
		center + Vector2(-10, -8),
		center + Vector2(10, -8),
		center + Vector2(12, 0),
		center + Vector2(10, 8),
		center + Vector2(-10, 8),
		center + Vector2(-12, 0)
	])
	draw_colored_polygon(points, color.darkened(0.3))
	draw_polyline(points + PackedVector2Array([points[0]]), color, 2.0)
	# Inner glow
	draw_circle(center, 4.0, Color(0.5, 0.8, 1.0, 0.6))

func _draw_engine_icon(center: Vector2, color: Color):
	# Thrust/flame shape
	var points = PackedVector2Array([
		center + Vector2(-8, -10),
		center + Vector2(8, -10),
		center + Vector2(6, 0),
		center + Vector2(10, 8),
		center + Vector2(0, 4),
		center + Vector2(-10, 8),
		center + Vector2(-6, 0)
	])
	draw_colored_polygon(points, Color(1, 0.5, 0.2, 0.8))
	draw_polyline(points + PackedVector2Array([points[0]]), color, 1.5)

func _draw_life_support_icon(center: Vector2, color: Color):
	# Air/oxygen symbol - two circles
	draw_arc(center + Vector2(-5, 0), 7.0, -PI/2, PI/2, 12, color, 2.0)
	draw_arc(center + Vector2(5, 0), 7.0, PI/2, PI*1.5, 12, color, 2.0)
	draw_line(center + Vector2(-5, -7), center + Vector2(-5, 7), color, 2.0)
	draw_line(center + Vector2(5, -7), center + Vector2(5, 7), color, 2.0)

func _draw_person_icon(center: Vector2, color: Color):
	# Simple person silhouette
	draw_circle(center + Vector2(0, -8), 5.0, color)  # Head
	draw_line(center + Vector2(0, -3), center + Vector2(0, 6), color, 3.0)  # Body
	draw_line(center + Vector2(-8, 2), center + Vector2(8, 2), color, 2.0)  # Arms
	draw_line(center + Vector2(0, 6), center + Vector2(-5, 14), color, 2.0)  # Left leg
	draw_line(center + Vector2(0, 6), center + Vector2(5, 14), color, 2.0)  # Right leg

func _draw_cargo_icon(center: Vector2, color: Color):
	# Box shape
	draw_rect(Rect2(center.x - 10, center.y - 8, 20, 16), color.darkened(0.2))
	draw_rect(Rect2(center.x - 10, center.y - 8, 20, 16), color, false, 2.0)
	# Box lines
	draw_line(center + Vector2(-10, 0), center + Vector2(10, 0), color, 1.0)

func _draw_science_icon(center: Vector2, color: Color):
	# Flask/beaker shape
	var points = PackedVector2Array([
		center + Vector2(-3, -10),
		center + Vector2(3, -10),
		center + Vector2(3, -4),
		center + Vector2(10, 8),
		center + Vector2(-10, 8),
		center + Vector2(-3, -4)
	])
	draw_colored_polygon(points, Color(0.3, 0.6, 0.8, 0.5))
	draw_polyline(points + PackedVector2Array([points[0]]), color, 2.0)

func _draw_medical_icon(center: Vector2, color: Color):
	# Medical cross
	draw_rect(Rect2(center.x - 3, center.y - 10, 6, 20), color)
	draw_rect(Rect2(center.x - 10, center.y - 3, 20, 6), color)

func _draw_fuel_icon(center: Vector2, color: Color):
	# Fuel cylinder
	draw_rect(Rect2(center.x - 6, center.y - 10, 12, 20), color.darkened(0.3))
	draw_arc(center + Vector2(0, -10), 6.0, 0, PI, 8, color, 2.0)
	draw_arc(center + Vector2(0, 10), 6.0, PI, TAU, 8, color, 2.0)
	draw_line(center + Vector2(-6, -10), center + Vector2(-6, 10), color, 2.0)
	draw_line(center + Vector2(6, -10), center + Vector2(6, 10), color, 2.0)

func _draw_solar_icon(center: Vector2, color: Color):
	# Sun with rays
	draw_circle(center, 5.0, color)
	for i in range(8):
		var angle = TAU * i / 8.0
		var inner = center + Vector2(cos(angle), sin(angle)) * 7.0
		var outer = center + Vector2(cos(angle), sin(angle)) * 12.0
		draw_line(inner, outer, color, 2.0)

func _draw_comms_icon(center: Vector2, color: Color):
	# Antenna with signal arcs
	draw_line(center + Vector2(0, 10), center + Vector2(0, -5), color, 2.0)
	draw_circle(center + Vector2(0, -7), 3.0, color)
	# Signal arcs
	draw_arc(center + Vector2(0, -7), 8.0, -PI/3, PI/3, 6, color, 1.5)
	draw_arc(center + Vector2(0, -7), 12.0, -PI/4, PI/4, 6, color, 1.5)

func _draw_gym_icon(center: Vector2, color: Color):
	# Dumbbell
	draw_line(center + Vector2(-10, 0), center + Vector2(10, 0), color, 3.0)
	draw_rect(Rect2(center.x - 12, center.y - 6, 4, 12), color)
	draw_rect(Rect2(center.x + 8, center.y - 6, 4, 12), color)

func _draw_cafeteria_icon(center: Vector2, color: Color):
	# Fork and plate
	draw_circle(center, 8.0, color.darkened(0.3))
	draw_arc(center, 8.0, 0, TAU, 16, color, 2.0)
	# Fork tines
	draw_line(center + Vector2(-4, -10), center + Vector2(-4, -2), color, 1.5)
	draw_line(center + Vector2(0, -10), center + Vector2(0, -2), color, 1.5)
	draw_line(center + Vector2(4, -10), center + Vector2(4, -2), color, 1.5)

func _draw_hangar_icon(center: Vector2, color: Color):
	# Vehicle/rover shape
	draw_rect(Rect2(center.x - 10, center.y - 4, 20, 8), color.darkened(0.2))
	draw_rect(Rect2(center.x - 10, center.y - 4, 20, 8), color, false, 2.0)
	# Wheels
	draw_circle(center + Vector2(-6, 6), 3.0, color)
	draw_circle(center + Vector2(6, 6), 3.0, color)

func _draw_mav_icon(center: Vector2, color: Color):
	# Small rocket shape
	var points = PackedVector2Array([
		center + Vector2(0, -12),
		center + Vector2(5, -4),
		center + Vector2(5, 8),
		center + Vector2(8, 12),
		center + Vector2(-8, 12),
		center + Vector2(-5, 8),
		center + Vector2(-5, -4)
	])
	draw_colored_polygon(points, color.darkened(0.2))
	draw_polyline(points + PackedVector2Array([points[0]]), color, 2.0)

func _draw_thruster_icon(center: Vector2, color: Color):
	# Generic thruster/engine for propulsion systems
	draw_rect(Rect2(center.x - 8, center.y - 8, 16, 12), color.darkened(0.2))
	draw_rect(Rect2(center.x - 8, center.y - 8, 16, 12), color, false, 2.0)
	# Exhaust
	var exhaust = PackedVector2Array([
		center + Vector2(-6, 4),
		center + Vector2(6, 4),
		center + Vector2(4, 12),
		center + Vector2(-4, 12)
	])
	draw_colored_polygon(exhaust, Color(1, 0.6, 0.2, 0.7))

func _draw_progress_arc(center: Vector2, radius: float, progress: float, color: Color):
	if progress > 0:
		draw_arc(center, radius, -PI/2, -PI/2 + TAU * progress, 24, color, 3.0)

func _get_component_color(id: String) -> Color:
	match id:
		"cockpit": return Color(0.8, 0.6, 0.2, 0.9)
		"engine_mount": return Color(0.7, 0.3, 0.3, 0.9)
		"gym": return Color(0.3, 0.7, 0.5, 0.9)
		"cafeteria": return Color(0.6, 0.5, 0.3, 0.9)
		"crew_room": return Color(0.4, 0.5, 0.7, 0.9)
		"cargo": return Color(0.5, 0.5, 0.5, 0.9)
		"hangar": return Color(0.4, 0.4, 0.6, 0.9)
		"mav_dock": return Color(0.7, 0.4, 0.4, 0.9)
		"science_lab": return Color(0.3, 0.6, 0.7, 0.9)
		"medical_bay": return Color(0.7, 0.3, 0.5, 0.9)
		"life_support": return Color(0.3, 0.7, 0.7, 0.9)
		"fuel_tank": return Color(0.6, 0.6, 0.3, 0.9)
		"solar_array": return Color(0.7, 0.7, 0.2, 0.9)
		"comms": return Color(0.5, 0.4, 0.7, 0.9)
		# Engines
		"traditional": return Color(0.6, 0.3, 0.2, 0.9)
		"hermes": return Color(0.2, 0.5, 0.8, 0.9)
		"hall_thruster": return Color(0.3, 0.6, 0.6, 0.9)
		"nuclear": return Color(0.8, 0.2, 0.2, 0.9)
		"solar_sail": return Color(0.9, 0.8, 0.2, 0.9)
		"laser_sail": return Color(0.9, 0.4, 0.4, 0.9)
		"pulsed_plasma": return Color(0.5, 0.3, 0.7, 0.9)
		"mpd": return Color(0.4, 0.4, 0.8, 0.9)
		"vasimr": return Color(0.3, 0.7, 0.4, 0.9)
		_: return Color(0.5, 0.5, 0.5, 0.9)

# ============================================================================
# DRAWING HELPERS
# ============================================================================

func _draw_hex(center: Vector2, size: float, color: Color):
	var points = PackedVector2Array()
	for i in range(6):
		var angle = deg_to_rad(60 * i - 30)
		points.append(center + Vector2(cos(angle), sin(angle)) * size)
	draw_colored_polygon(points, color)

func _draw_hex_outline(center: Vector2, size: float, color: Color):
	var points = PackedVector2Array()
	for i in range(6):
		var angle = deg_to_rad(60 * i - 30)
		points.append(center + Vector2(cos(angle), sin(angle)) * size)
	points.append(points[0])
	draw_polyline(points, color, 2.0)
