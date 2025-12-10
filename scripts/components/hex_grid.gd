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

	# Draw component hexes
	var positions = ShipLogic.get_component_hexes(hex_pos, component.hex_size, _valid_positions)
	for pos in positions:
		var pos_center = ShipLogic.hex_to_pixel(pos, HEX_SIZE)
		_draw_hex(pos_center, HEX_SIZE - 4, bg_color)

	# Draw component label
	var label = component.display_name.substr(0, 8) if component.display_name.length() > 8 else component.display_name
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-30, 5),
		label,
		HORIZONTAL_ALIGNMENT_CENTER,
		60,
		11,
		Color.WHITE
	)

	# Draw quality indicator
	var quality_color = Color.RED.lerp(Color.GREEN, component.quality / 100.0)
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(-15, 18),
		"%.0f%%" % component.quality,
		HORIZONTAL_ALIGNMENT_CENTER,
		30,
		10,
		quality_color
	)

	# Draw construction indicator if not built
	if not component.is_built:
		draw_string(
			ThemeDB.fallback_font,
			center + Vector2(-20, -15),
			"[%dd]" % component.days_remaining,
			HORIZONTAL_ALIGNMENT_CENTER,
			40,
			9,
			Color.YELLOW
		)

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
