extends Node2D
class_name ControlSurfacesContainer

## Container for all control surface visuals
## Connects to ControlSurfaceManager and renders all surfaces on the ship

const ControlSurface = preload("res://scripts/mars_odyssey_trek/phase2/ship/control_surface.gd")
const ControlSurfaceVisual = preload("res://scripts/mars_odyssey_trek/phase2/ship/control_surface_visual.gd")
const ShipTypes = preload("res://scripts/mars_odyssey_trek/phase2/ship/ship_types.gd")

# ============================================================================
# SIGNALS
# ============================================================================

signal surface_clicked(surface_id: int)
signal surface_hovered(surface_id: int, is_hovered: bool)

# ============================================================================
# STATE
# ============================================================================

var surface_visuals: Dictionary = {}  # SurfaceId -> ControlSurfaceVisual
var manager: Node  # ControlSurfaceManager reference

# Tile to world position conversion
const TILE_SIZE = 16
var grid_origin: Vector2 = Vector2(0, 0)

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	z_index = 5  # Above rooms, below crew

var ship_view: Node2D  # Reference to ShipView for room positions

func setup(surface_manager: Node, origin: Vector2) -> void:
	manager = surface_manager
	grid_origin = origin
	_connect_manager_signals()
	_create_all_surface_visuals()

func setup_with_ship_view(surface_manager: Node, view: Node2D) -> void:
	## Setup with ShipView - positions surfaces within their rooms
	manager = surface_manager
	ship_view = view
	_connect_manager_signals()
	_create_surfaces_in_rooms()

func _connect_manager_signals() -> void:
	if manager:
		manager.surface_state_changed.connect(_on_surface_state_changed)
		manager.surface_level_changed.connect(_on_surface_level_changed)
		manager.surface_broken.connect(_on_surface_broken)
		manager.surface_repaired.connect(_on_surface_repaired)
		manager.surface_interaction_started.connect(_on_surface_interaction_started)
		manager.surface_interaction_completed.connect(_on_surface_interaction_completed)

func _create_all_surface_visuals() -> void:
	for surface_id in ControlSurface.get_all_surface_ids():
		var visual = ControlSurfaceVisual.new()
		visual.setup(surface_id)
		visual.name = "Surface_" + ControlSurface.get_short_name(surface_id)

		# Position based on tile
		var tile = ControlSurface.get_tile(surface_id)
		visual.position = _tile_to_world(tile)

		# Connect signals
		visual.clicked.connect(_on_visual_clicked)
		visual.hover_started.connect(_on_visual_hover_started)
		visual.hover_ended.connect(_on_visual_hover_ended)

		add_child(visual)
		surface_visuals[surface_id] = visual

		# Set initial state from manager
		if manager:
			var state = manager.get_surface_state(surface_id)
			if not state.is_empty():
				visual.set_state(state.get("state", ControlSurface.SurfaceState.WORKING))
				visual.set_level(state.get("level", 0))

func _create_surfaces_in_rooms() -> void:
	## Create surfaces and position them within their respective rooms
	# Track offset within each room for multiple surfaces
	var room_surface_count: Dictionary = {}

	for surface_id in ControlSurface.get_all_surface_ids():
		var visual = ControlSurfaceVisual.new()
		visual.setup(surface_id)
		visual.name = "Surface_" + ControlSurface.get_short_name(surface_id)

		# Get room for this surface
		var room_type = ControlSurface.get_room(surface_id)

		# Position within the room
		visual.position = _get_surface_position_in_room(surface_id, room_type, room_surface_count)

		# Connect signals
		visual.clicked.connect(_on_visual_clicked)
		visual.hover_started.connect(_on_visual_hover_started)
		visual.hover_ended.connect(_on_visual_hover_ended)

		add_child(visual)
		surface_visuals[surface_id] = visual

		# Set initial state from manager
		if manager:
			var state = manager.get_surface_state(surface_id)
			if not state.is_empty():
				visual.set_state(state.get("state", ControlSurface.SurfaceState.WORKING))
				visual.set_level(state.get("level", 0))

func _get_surface_position_in_room(surface_id: int, room_type: int, count_tracker: Dictionary) -> Vector2:
	## Get position for a surface within its room
	if not ship_view or not ship_view.has_method("get_room_position"):
		return Vector2.ZERO

	var room_pos = ship_view.get_room_position(room_type)
	var room_size = Vector2(100, 80)  # Default room size

	# Track how many surfaces we've placed in this room
	var index = count_tracker.get(room_type, 0)
	count_tracker[room_type] = index + 1

	# Position surfaces in a row within the room
	# Offset from room center based on index
	var offset_x = (index - 1) * 30  # 30px spacing between surfaces
	var offset_y = 20  # Slightly below center

	return room_pos + Vector2(offset_x, offset_y)

func _tile_to_world(tile: Vector2i) -> Vector2:
	return grid_origin + Vector2(tile) * TILE_SIZE + Vector2(TILE_SIZE / 2, TILE_SIZE / 2)

# ============================================================================
# MANAGER SIGNAL HANDLERS
# ============================================================================

func _on_surface_state_changed(surface_id: int, _old_state: int, new_state: int) -> void:
	var visual = surface_visuals.get(surface_id)
	if visual:
		visual.set_state(new_state)

func _on_surface_level_changed(surface_id: int, _old_level: int, new_level: int) -> void:
	var visual = surface_visuals.get(surface_id)
	if visual:
		visual.set_level(new_level)

func _on_surface_broken(surface_id: int, _cause: String) -> void:
	var visual = surface_visuals.get(surface_id)
	if visual:
		visual.set_state(ControlSurface.SurfaceState.BROKEN)
		visual.trigger_break_effect()

func _on_surface_repaired(surface_id: int) -> void:
	var visual = surface_visuals.get(surface_id)
	if visual:
		visual.set_state(ControlSurface.SurfaceState.WORKING)
		visual.trigger_repair_effect()

func _on_surface_interaction_started(surface_id: int, _crew_role: String) -> void:
	var visual = surface_visuals.get(surface_id)
	if visual:
		visual.set_state(ControlSurface.SurfaceState.USING)
		visual.trigger_interaction_flash()

func _on_surface_interaction_completed(surface_id: int, _crew_role: String) -> void:
	var visual = surface_visuals.get(surface_id)
	if visual:
		visual.set_state(ControlSurface.SurfaceState.WORKING)

# ============================================================================
# VISUAL SIGNAL HANDLERS
# ============================================================================

func _on_visual_clicked(surface_id: int) -> void:
	surface_clicked.emit(surface_id)

func _on_visual_hover_started(surface_id: int) -> void:
	surface_hovered.emit(surface_id, true)

func _on_visual_hover_ended(surface_id: int) -> void:
	surface_hovered.emit(surface_id, false)

# ============================================================================
# QUERIES
# ============================================================================

func get_surface_visual(surface_id: int) -> ControlSurfaceVisual:
	return surface_visuals.get(surface_id)

func get_surface_position(surface_id: int) -> Vector2:
	var visual = surface_visuals.get(surface_id)
	if visual:
		return visual.global_position
	return Vector2.ZERO

func get_surfaces_in_room(room_type: ShipTypes.RoomType) -> Array:
	var result = []
	for surface_id in ControlSurface.get_surfaces_in_room(room_type):
		var visual = surface_visuals.get(surface_id)
		if visual:
			result.append(visual)
	return result

# ============================================================================
# VISUAL EFFECTS
# ============================================================================

func flash_all_surfaces(color: Color) -> void:
	## Flash all surfaces (for ship-wide alerts)
	for visual in surface_visuals.values():
		var tween = create_tween()
		tween.tween_property(visual, "modulate", color, 0.1)
		tween.tween_property(visual, "modulate", Color.WHITE, 0.3)

func trigger_room_damage_effect(room_type: ShipTypes.RoomType) -> void:
	## Trigger damage effect on all surfaces in a room
	for surface_id in ControlSurface.get_surfaces_in_room(room_type):
		var visual = surface_visuals.get(surface_id)
		if visual:
			visual.trigger_break_effect()

func show_power_balance_warning(is_deficit: bool) -> void:
	## Visual warning when power is in deficit
	if is_deficit:
		for visual in surface_visuals.values():
			var tween = create_tween()
			tween.set_loops(3)
			tween.tween_property(visual, "modulate", Color(1.0, 0.6, 0.6), 0.2)
			tween.tween_property(visual, "modulate", Color.WHITE, 0.2)
