extends Control
class_name FCWSolarMap

## Visual Solar System Map for First Contact War
## Shows zones as planets, Herald fleet movement, and player fleets

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

# Animation
var _herald_travel_progress: float = 1.0  # 0 = at origin, 1 = at target
const HERALD_TRAVEL_SPEED = 0.5  # Progress per second

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Initialize herald position
	_herald_position = _get_zone_pixel_pos(FCWTypes.ZoneId.KUIPER)
	_herald_target_position = _herald_position

func _process(delta: float) -> void:
	# Animate herald movement
	if _herald_travel_progress < 1.0:
		_herald_travel_progress = minf(_herald_travel_progress + delta * HERALD_TRAVEL_SPEED, 1.0)
		_herald_position = _herald_position.lerp(_herald_target_position, _herald_travel_progress)
		queue_redraw()

	# Flash when attacking
	if _is_attacking:
		_attack_flash_timer += delta * 5.0
		queue_redraw()

func _draw() -> void:
	var rect = get_rect()

	# Draw starfield background
	_draw_starfield(rect)

	# Draw zone connections
	_draw_connections(rect)

	# Draw zones
	for zone_id in FCWTypes.ZoneId.values():
		_draw_zone(zone_id, rect)

	# Draw player fleets at zones
	_draw_player_fleets(rect)

	# Draw Herald fleet
	_draw_herald(rect)

	# Draw attack indicator if attacking
	if _is_attacking:
		_draw_attack_indicator(rect)

# ============================================================================
# DRAWING
# ============================================================================

func _draw_starfield(rect: Rect2) -> void:
	# Simple dark background with some stars
	draw_rect(rect, Color(0.02, 0.02, 0.05))

	# Draw some static stars
	var rng = RandomNumberGenerator.new()
	rng.seed = 12345  # Consistent star pattern
	for i in range(50):
		var pos = Vector2(rng.randf() * rect.size.x, rng.randf() * rect.size.y)
		var brightness = rng.randf_range(0.3, 1.0)
		draw_circle(pos, 1.0, Color(brightness, brightness, brightness * 0.9))

func _draw_connections(rect: Rect2) -> void:
	# Draw lines between connected zones
	for zone_id in FCWTypes.ZONE_CONNECTIONS:
		var pos1 = _get_zone_pixel_pos(zone_id)
		for connected_zone in FCWTypes.ZONE_CONNECTIONS[zone_id]:
			if connected_zone > zone_id:  # Avoid double-drawing
				var pos2 = _get_zone_pixel_pos(connected_zone)
				draw_line(pos1, pos2, Color(0.2, 0.25, 0.3, 0.5), 1.0)

func _draw_zone(zone_id: int, _rect: Rect2) -> void:
	var pos = _get_zone_pixel_pos(zone_id)
	var base_size = ZONE_SIZES.get(zone_id, 20.0)
	var color = ZONE_COLORS.get(zone_id, Color.WHITE)

	var zone_data = _zones.get(zone_id, {})
	var status = zone_data.get("status", FCWTypes.ZoneStatus.CONTROLLED)

	# Status-based modifications
	match status:
		FCWTypes.ZoneStatus.FALLEN:
			color = color.darkened(0.6)
		FCWTypes.ZoneStatus.UNDER_ATTACK:
			# Pulse effect
			var pulse = sin(_attack_flash_timer * 3.0) * 0.3 + 0.7
			color = color.lerp(Color.RED, 0.5 * pulse)

	# Selection/hover highlight
	if zone_id == _selected_zone:
		draw_circle(pos, base_size + 8, Color(1.0, 1.0, 0.5, 0.4))
	elif zone_id == _hovered_zone:
		draw_circle(pos, base_size + 5, Color(1.0, 1.0, 1.0, 0.2))

	# Herald target indicator
	if zone_id == _herald_target_zone and status != FCWTypes.ZoneStatus.FALLEN:
		var target_pulse = sin(_attack_flash_timer * 2.0) * 0.3 + 0.7
		draw_arc(pos, base_size + 12, 0, TAU, 32, Color(1.0, 0.3, 0.2, target_pulse * 0.8), 2.0)

	# Draw the planet
	draw_circle(pos, base_size, color)

	# Draw zone name
	var font = ThemeDB.fallback_font
	var font_size = 12
	var name = FCWTypes.get_zone_name(zone_id)
	var text_size = font.get_string_size(name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, pos + Vector2(-text_size.x / 2, base_size + 16), name, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)

	# Draw defense value under name if controlled
	if status != FCWTypes.ZoneStatus.FALLEN:
		var defense = zone_data.get("defense", 0)
		var def_text = "DEF: %d" % defense
		var def_color = Color.GREEN if defense >= _herald_strength else Color.RED
		draw_string(font, pos + Vector2(-25, base_size + 28), def_text, HORIZONTAL_ALIGNMENT_CENTER, 50, 10, def_color)

func _draw_player_fleets(rect: Rect2) -> void:
	# Draw small fleet icons at each zone with assigned ships
	for zone_id in _fleet_assignments:
		var assignment = _fleet_assignments[zone_id]
		var total_ships = 0
		for ship_type in assignment:
			total_ships += assignment[ship_type]

		if total_ships <= 0:
			continue

		var pos = _get_zone_pixel_pos(zone_id)
		var zone_size = ZONE_SIZES.get(zone_id, 20.0)
		var fleet_pos = pos + Vector2(zone_size + 10, -10)

		# Draw fleet icon (triangle pointing right)
		var points = PackedVector2Array([
			fleet_pos + Vector2(0, -6),
			fleet_pos + Vector2(10, 0),
			fleet_pos + Vector2(0, 6)
		])
		draw_colored_polygon(points, Color(0.3, 0.8, 0.3))

		# Draw ship count
		var font = ThemeDB.fallback_font
		draw_string(font, fleet_pos + Vector2(12, 4), "x%d" % total_ships, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)

func _draw_herald(rect: Rect2) -> void:
	# Draw the Herald fleet as a menacing red icon
	var pos = _herald_position

	# Ominous glow
	var glow_pulse = sin(_attack_flash_timer * 2.0) * 0.2 + 0.8
	draw_circle(pos, 25 * glow_pulse, Color(1.0, 0.0, 0.0, 0.15))
	draw_circle(pos, 15 * glow_pulse, Color(1.0, 0.1, 0.0, 0.3))

	# Herald icon (inverted triangle - pointing down like descending doom)
	var size = 12.0
	var points = PackedVector2Array([
		pos + Vector2(-size, -size * 0.6),
		pos + Vector2(size, -size * 0.6),
		pos + Vector2(0, size)
	])
	draw_colored_polygon(points, Color(0.9, 0.1, 0.1))

	# Draw herald strength
	var font = ThemeDB.fallback_font
	var strength_text = "HERALD: %d" % _herald_strength
	draw_string(font, pos + Vector2(-30, -20), strength_text, HORIZONTAL_ALIGNMENT_CENTER, 60, 10, Color(1.0, 0.3, 0.3))

func _draw_attack_indicator(_rect: Rect2) -> void:
	# Draw attack lines from herald to target when attacking
	var target_pos = _get_zone_pixel_pos(_herald_target_zone)
	var flash = sin(_attack_flash_timer * 8.0) * 0.5 + 0.5

	# Draw jagged attack lines
	var rng = RandomNumberGenerator.new()
	rng.seed = int(_attack_flash_timer * 10) % 1000

	for i in range(3):
		var offset = Vector2(rng.randf_range(-15, 15), rng.randf_range(-15, 15))
		draw_line(_herald_position + offset, target_pos + offset * 0.5, Color(1.0, 0.5, 0.0, flash), 2.0)

# ============================================================================
# POSITIONING
# ============================================================================

func _get_zone_pixel_pos(zone_id: int) -> Vector2:
	var normalized_pos = ZONE_POSITIONS.get(zone_id, Vector2(0.5, 0.5))
	return normalized_pos * size

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
